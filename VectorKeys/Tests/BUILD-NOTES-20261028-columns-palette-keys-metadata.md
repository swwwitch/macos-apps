# VectorKeys 1.8.0 (13)

- 開発担当: MacBook-Pro-14-2024-sw.local / main / 基点ad49af1。
- NSSplitViewの2境界で3カラムを調整。Mac固有のmainColumnWidthsに幅を保存し、最小幅を設ける。
- アプリ版はアイコン下に配置。
- Settings > Palettesにカテゴリ別HotkeyFieldを追加。既定未設定。グローバルの表示キー（スクリプト実行キーとは別）。全体オフに追従し、記録中の停止は共通HotkeySetを利用。実行キー・別カテゴリとの重複は回避、登録失敗を表示。ライブラリへ保存、カテゴリの改名・削除とUndoに追従。
- SCRIPTMETA v1.4のローカルScript-ID/Versionをファイル/直書きから読取。Description内の疑似キー、配布タグ、未閉鎖タグは除外。ファイル先頭256KiB・UTF-8、バイナリ除外。背景で読み、アプリ再アクティブ化・ライブラリ編集時に更新。タグなしは推測しない。
- 参照: https://github.com/Yamonov/SCRIPTMETA/blob/main/SCRIPTMETA.md (blob 01657faaec93b5304b51c3e171aa4b04a4ac38b3)。更新確認通信や自動ダウンロードは行わない。
- test.sh PASS。メタデータのCRLF・説明ブロック・タグ欠損・Script-ID欠損・配布タグ・ファイル読取、カテゴリキーのJSON保存・改名・削除の検証を追加。
- build.sh成功。署名deep/strict合格。共通StartupWindowの既存未使用変数警告のみ。
- 実機: 両方の境界をドラッグし130→155、220→368→343の幅変化を確認。アイコン下1.8.0 (13)、テーブル風に加工1.8.0など複数のタグ版、設定のパレットタブを確認。
- 未確認: 実キーによる表示、再起動後のキー登録・幅復元、ダークモード。実機確認後、版を名前の下へ移動し、初期カラム幅の復元を調整して再ビルド。
- 公証・配布配置・公開・GitHub push未実施。
