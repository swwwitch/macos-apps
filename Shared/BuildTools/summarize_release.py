#!/usr/bin/env python3
"""Combine initial and repaired release evidence without hiding original failures."""
import argparse,json,pathlib,plistlib
p=argparse.ArgumentParser();p.add_argument('output',type=pathlib.Path);a=p.parse_args();r=a.output.resolve()
def read(folder,name):
 try:return json.loads((folder/name).read_text())
 except (FileNotFoundError,json.JSONDecodeError):return []
index={}
for folder in [r]+sorted(r.glob('Retry-*')):
 for row in read(folder,'build-results.json'):
  index.setdefault(row['app'],{}).update(build=row,source_folder=str(folder))
 for row in read(folder,'notary-results.json'):
  index.setdefault(row['app'],{}).update(notary=row)
 for row in read(folder,'deployment-results.json'):
  index.setdefault(row['app'],{}).update(deployment=row)
for recovered in r.glob('*-deployment-recovered.json'):
 row=json.loads(recovered.read_text());index.setdefault(row['app'],{})['deployment']=row
lines=['# 全アプリ Developer ID・公証ビルド（2026年10月20日）','',
'証明書: Developer ID Application: masahiro takano (PL9S9PXX96)。全コードを内側から個別署名、Hardened Runtime・timestampを付与。署名に--deepは不使用。',
'指定のnotaryプロファイルが未登録だったため、ユーザー承認によりswwwitch-notaryでZIP公証。Accepted後、アプリへのstaple、stapler validate、spctlのNotarized Developer IDを確認。',
'配置は従来のdeploy_both.py。旧版バックアップ・Bundle ID照合・両配置先の全ファイル一致・/Applications版の起動プロセス確認を実施。',
'', '| アプリ | バージョン (build) | ビルド | test.sh | 公証 | 配置・起動 |','| --- | --- | --- | --- | --- | --- |']
for name,row in sorted(index.items()):
 b=row.get('build',{});n=row.get('notary',{});d=row.get('deployment',{})
 meta=pathlib.Path(row.get('source_folder',str(r)))/'SignedApps'/(name+'.app')/'Contents/Info.plist'
 info=plistlib.loads(meta.read_bytes()) if meta.exists() else {}
 row['version']=info.get('CFBundleShortVersionString');row['build_number']=info.get('CFBundleVersion')
 v=f"{row['version']} ({row['build_number']})"
 lines.append(f"| {name} | {v} | {'PASS' if b.get('build_exit')==0 else '未完了'} | {'PASS' if b.get('test_exit')==0 else '未実施' if b.get('test_exit') is None else 'FAIL'} | {n.get('status','待機')} | {d.get('status','待機')} |")
lines+=['','## 復旧と確認範囲','',
'CarmaChameleon: 8つの不足翻訳キーを4言語へ追加。NodeをPATHへ加え、再ビルドと変換・Markdown互換性テストを完了。初回の失敗ログは保持。PDFエンジン引数が必要な追加テストは未実施。',
'HotkeyHound・MarkdownKitchen: Latest Builds内のInfo.plist・実行ファイルが欠けた不完全フォルダをワークスペース内へ退避保持してから配置を復旧。',
'各機能の画面操作、再ログイン、Intel実機動作はこの一括配布確認では未実施。test.shを持たないアプリの独立したテスト実行は未実施（ビルド内の検証は各ログを参照）。',
'通常終了の要求に応答しないアプリは強制終了せず、起動したまま保持。設定の初期化は行っていない。',
'', '## note更新','',
'[BreaklineTrimmer個人記事](https://note.com/swwwitch/n/ne4a0fc0c1dd2)を1.3.2 (9)へ更新。新DMG添付、PNG/JPEG/PSD・背景反映・保存後動作の説明を更新。既存画像・埋め込み・タグ・マガジンと旧版を保持（旧版は明記）。ユーザー承認により記事末尾まで無料公開。']
(r/'FINAL-RESULTS.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n');(r/'STATUS.md').write_text('\n'.join(lines)+'\n')
print('builds',sum(x.get('build',{}).get('build_exit')==0 for x in index.values()),'notarized',sum(x.get('notary',{}).get('status')=='Accepted' for x in index.values()),'deployed',sum(x.get('deployment',{}).get('status')=='deployed_and_launch_verified' for x in index.values()))
