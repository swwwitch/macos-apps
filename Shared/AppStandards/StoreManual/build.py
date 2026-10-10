#!/usr/bin/env python3
"""Build isolated, ad-hoc App Store candidates; never deploy or upload."""
from pathlib import Path
import argparse, plistlib, shutil, subprocess, tempfile, platform
root = Path(__file__).resolve().parents[3]
p = argparse.ArgumentParser(); p.add_argument('app', choices=['MightyEdit','KakkoReplace','CommandDee']); p.add_argument('--build', required=True); a=p.parse_args()
name=a.app; project=root/name
sources={
'MightyEdit': ['Localization','LocalizationFallback','LineTools','HTMLMinifier','TextTransform','DateTransform','TypographyOption'],
'KakkoReplace': ['Transform'],
'CommandDee': ['Duplicator','Localization']}[name]
source_dir=project/('Source' if name=='MightyEdit' else 'Sources')
shared=root/'Shared'
files=[shared/'AppStandards/StoreManual/StoreHost.swift',project/'AppStore/StoreContent.swift']
files += [shared/'AppStandards'/f'{s}.swift' for s in ['AppSurface','StartupWindow','SettingsSection','HelpDocument']]
files += [shared/'LoginAtLaunch/LoginAtLaunch.swift',shared/'MenuBarPresence/MenuBarPresence.swift']
files += [source_dir/f'{s}.swift' for s in sources]
out=project/'AppStore/StoreBuild'/f'{name}-build{a.build}.app'
if out.exists(): raise SystemExit(f'Refusing existing output: {out}')
with tempfile.TemporaryDirectory(prefix='store-manual-') as temp:
    stage=Path(temp)/f'{name}.app'; contents=stage/'Contents'; (contents/'MacOS').mkdir(parents=True); resources=contents/'Resources'; resources.mkdir()
    subprocess.run(['xcrun','swiftc','-parse-as-library','-DAPP_STORE','-O','-target',platform.machine()+'-apple-macos13.0','-module-cache-path',temp+'/ModuleCache','-framework','AppKit','-framework','SwiftUI','-framework','Carbon','-framework','ServiceManagement',*map(str,files),'-o',str(contents/'MacOS'/name)],check=True)
    ids={'MightyEdit':'jp.local.TextPalette','KakkoReplace':'jp.local.SuperKakkoEdit','CommandDee':'jp.local.CommandDee'}
    info=dict(CFBundleExecutable=name,CFBundleIdentifier=ids[name],CFBundleName=name,CFBundleIconFile=name,CFBundlePackageType='APPL',CFBundleShortVersionString='1.0',CFBundleVersion=a.build,CFBundleDevelopmentRegion='en',CFBundleLocalizations=['ja','en','zh-Hans','ko'],LSMinimumSystemVersion='13.0',LSMultipleInstancesProhibited=True,NSHighResolutionCapable=True,SWNoteArticleURL='https://note.com/swwwitch/m/m057948d2fbeb')
    (contents/'Info.plist').write_bytes(plistlib.dumps(info))
    shutil.copy2(project/'Assets'/f'{name}.icns',resources)
    for src in (project/'Resources').glob('*.lproj'): shutil.copytree(src,resources/src.name)
    helptexts={
    'ja': '# '+name+' ヘルプ\n## 基本操作\n'+('フォルダーを選択し、項目と処理を選んで実行します。複製は原本を保持します。名前変更・入れ替えには取り消しがありません。処理結果とエラーを確認してください。' if name=='CommandDee' else '入力欄にテキストを貼り付け、処理を選んで変換します。結果をコピーして使用します。入力と他アプリの内容は自動で変更しません。')+'\n## 設定と終了\n⌘,で設定、⌘Wで閉じる、⌘0で再表示、⌘Qで終了。設定でログイン起動と起動時非表示を選べます。閉じた後もDockから再表示できます。\n## 権限と対処\nアクセシビリティ権限は不要です。ファイル処理にはフォルダーを選び直してください。App Store版はApp Storeから更新します。',
    'en': '# '+name+' Help\n## Usage\n'+('Choose a folder, select items and an operation, then Run. Copies preserve originals. Renaming and swapping have no Undo. Check each result and error.' if name=='CommandDee' else 'Paste text, choose an operation and Transform. Copy the result explicitly. Input and other apps are not changed automatically.')+'\n## Settings and Quit\n⌘, opens Settings; ⌘W closes; ⌘0 reopens; ⌘Q quits. Configure login launch and hidden startup in Settings. Reopen from the Dock.\n## Permissions and Troubleshooting\nAccessibility access is unnecessary. Reselect a folder if access fails. Updates come through the App Store.',
    'zh-Hans': '# '+name+' 帮助\n选择文本或文件夹，选择处理方式并执行。查看结果和错误。复制保留原文件，重命名不能撤销。\n⌘, 设置；⌘W 关闭；⌘0 打开；⌘Q 退出。可设置登录启动及启动时隐藏窗口。无需辅助功能权限。文件访问失败时重新选择文件夹。通过 App Store 更新。',
    'ko': '# '+name+' 도움말\n텍스트 또는 폴더를 선택하고 작업을 실행하세요. 결과와 오류를 확인하세요. 복제는 원본을 보존하며 이름 변경은 취소할 수 없습니다.\n⌘, 설정; ⌘W 닫기; ⌘0 다시 열기; ⌘Q 종료. 로그인 시작 및 시작 시 창 숨김을 설정할 수 있습니다. 손쉬운 사용 권한이 필요하지 않습니다. 파일 접근에 실패하면 폴더를 다시 선택하세요. App Store에서 업데이트합니다.'}
    for lang,text in helptexts.items():
        dest=resources/f'{lang}.lproj'; dest.mkdir(exist_ok=True); (dest/'StoreHelp.txt').write_text(text)
    ent={'com.apple.security.app-sandbox':True,'com.apple.security.files.user-selected.read-write':True}
    entfile=Path(temp)/'entitlements.plist'; entfile.write_bytes(plistlib.dumps(ent))
    subprocess.run(['codesign','--force','--sign','-','--timestamp=none','--entitlements',str(entfile),str(stage)],check=True)
    subprocess.run(['codesign','--verify','--deep','--strict',str(stage)],check=True)
    out.parent.mkdir(parents=True,exist_ok=True); shutil.copytree(stage,out)
print(out)
