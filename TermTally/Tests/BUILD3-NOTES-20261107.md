# TermTally 1.1.1（3）検証用ビルド — 2026-11-07

- 担当：開発Mac MacBook-Pro-14-2024-sw.local。ブランチcodex/filesorter-screenshot-rename-20261101。基点4c331bdc、対象SHAは本記録を含むコミット。
- main.swift：設定とメインのlevelを同一のalwaysOnTop設定に追従。設定を開く際にレベル適用・最小化解除・前面化。レベル変更時はキーウインドウを前面へ保持。
- test.sh：検索・辞書テスト、4言語キーとプレースホルダー、同梱ヘルプPASS。
- NO_DEPLOY=1 build.sh：コンパイル・証明書署名・deep/strict検証成功。成果物の版/buildを確認。
- 起動・実機クリック往復・ON/OFF切替・最小化復元：未実施。今回は検証用ビルド作成の依頼。公証・/Applications配置・Latest Builds配置・公開なし。
- 既存ビルドはbuild.shによりBackupsへ保全。マニフェストと署名記録はBUILD3-MANIFEST.json、BUILD3-SIGNATURE.txt。
- 他作業の既存Shared/SettingsSync/SettingsSync.swift差分（showsNotes既定true）を参照。未変更・コミット対象外。配布前は共通部品も確定したソースで再ビルドすること。
