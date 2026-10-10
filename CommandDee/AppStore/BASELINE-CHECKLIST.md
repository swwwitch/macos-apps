# 共通仕様の実装と確認

アプリ名：CommandDee App Store candidate
バージョン/build：1.0 / 37
確認OS/CPU：未記入
確認日：未記入

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 未確認 | |
| B02 | ログイン起動設定 | 未確認 | |
| B03 | ログイン時の非表示 | 未確認 | |
| B04 | 常駐と再表示 | 未確認 | |
| B05 | 終了と処理保護 | 未確認 | |
| B06 | 標準キー操作 | 未確認 | |
| B07 | ショートカット管理 | 未確認 | |
| B08 | 設定・位置の保持 | 未確認 | |
| B09 | 権限の案内と再判定 | 未確認 | |
| B10 | 原本保護・復元 | 未確認 | |
| B11 | 二重処理・中断対策 | 未確認 | |
| B12 | 成否・復旧表示 | 未確認 | |
| B13 | 待機負荷・復帰 | 未確認 | |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 未確認 | |
| B15 | 多言語 | 未確認 | |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 未確認 | |
| B17 | プライバシー | 未確認 | |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 未確認 | |
| B19 | マスタード基調の共通アイコン | 未確認 | |
| B20 | 共通UI統一・起動/常駐/起動ショートカットの同一グループ・アクセシビリティも同一タブ内の区画 | 未確認 | |
| B21 | 対象外アプリの設定・処理抑制・標準キー操作の保持 | 未確認 | |

## 確認記録

- ソース確認：未実施
- ビルド・自動テスト：未実施
- 実機で起動・閉じる・再表示・⌘Q：未実施
- 再ログイン・OS側で自動起動OFF：未実施
- 別コピー起動・引数/ファイル受け渡し：未実施
- 設定保持・更新・配布物確認：未実施
- /ApplicationsとLatest Buildsへの配置・既存版バックアップ・両配置先の版/build/署名・内容一致確認：未実施
- /Applicationsのアプリを起動して動作確認：未実施

| B22 | 起動時にメインウインドウを表示しない | 未確認 | 設定保存、OFF/ON起動、明示的再表示、ファイル受け渡しを確認 |

## 2026-10-08 verification
Compile and ad-hoc signature verification passed. Existing transformation/duplication tests passed. Runtime UI, sandbox file permissions, login launch and deployment remain unverified. No final distribution or upload.

Implementation: Shared/AppStandards/StoreManual/StoreHost.swift; AppStore/StoreContent.swift. LoginAtLaunch, StartupWindow, AppSurface, SettingsUI, HelpDocument and MenuBarPresence are reused.

B07: Store variant has no global operation hotkeys; launching via Shortcuts is documented. B21: not applicable; no external application input or key interception. B15: four language UI/help exist; string resource extraction and language QA remain pending. B08: window frame stored; off-screen recovery remains pending. B11: CommandDee busy/termination guards implemented; runtime validation remains pending. B18: only isolated ad-hoc candidates, signing identity unavailable.

## Runtime checks in this turn
CommandDee sandbox PowerBox folder selection: PASS
Original and duplicate content identical: f740f0d2623214b09389f7d248c02438b663e10070b35466d0515bec165fd25f
KakkoReplace UI transform: Japanese corner brackets -> full-width parentheses, PASS
KakkoReplace Settings, help, close/reopen: PASS
MightyEdit UI newline removal: PASS; Settings displayed
MightyEdit close/reopen interrupted by user interaction: UNVERIFIED
No final signed PKG or upload; 0 valid signing identities.
Remaining: all-language QA/resource extraction, large-file termination/copy tests, login launch, App Store signing/profile and release deployment.
MightyEdit 1.0 (86): ad-hoc signature + sandbox entitlements verified
KakkoReplace 1.0 (32): ad-hoc signature + sandbox entitlements verified
CommandDee 1.0 (37): ad-hoc signature + sandbox entitlements verified

## Distribution signing 2026-10-08
Existing Apple Distribution and Mac Installer Distribution identities verified outside the restricted execution environment. The previous zero-identities observation was caused by the environment restriction, not missing signing keys. Explicit App Store profile generated for the existing Bundle ID. Profile/certificate matching, codesign strict verification and pkgutil installer signature verification passed. Signed package: Shared/AppStore/Resubmission/20261008/Signed/CommandDee-37/CommandDee.pkg. No upload, App Review submission or final deployment performed. Remaining UI/language/login QA still applies.
