# VectorMate 2.22.1（86）ログイン起動の表示抑止

- 2026-11-02 JST、開発Mac MacBook-Pro-14-2024-sw.local。codex/vectorassist-build-20261101、入力8b637f7a、対象SHAは本記録を含む確定コミット。
- applicationWillFinishLaunchingで共通StartupWindowへ起動Apple Eventを早期捕捉。ログイン起動の抑止状態を保持。
- Shared/AppStandards/StartupWindow.swiftのAppSwitcherWindowRevealへactivationRevealAllowedフックを追加（既定true）。VectorMateだけ、ログイン起動の自動アクティブ化では主画面を再表示しない。明示的な手動起動・再オープン・メニュー・ホットキーでuserRequestedWindowを記録し、⌘TabのCommand保持時は再表示を許可。
- ログイン設定、Dock設定、アピアランス・正負反転の保存値を変更・リセットしない。85の機能を保持。
- 既存単体・4言語・49項目／88生成スクリプトに加え、合成Apple Eventのログイン判定と自動／手動／Command-Tabの判定テストPASS。
- 共通のtest-startup-window.sh（StartupWindow、Gate、DockPresence、AppSwitcherWindowReveal）PASS。遅延したアクティブ化を抑止する新しい回帰ケースと、既存の閉じた主画面・最小化・設定のみ・パレット・シート・補助画面の保護を確認。テストのアクティブ化は合成通知であり、実ログイン・物理⌘Tabの確認とは区別。
- SKIP_DEPLOY=1の既存経路でUniversalビルド・既存証明書署名・codesign deep/strict検証PASS。
- /Applicationsの2.21.1（84）が常駐していたため、CUAで通常終了。その後ワークスペース内の86を起動し、2.22.1（86）の主画面・アピアランスタブ・保存済み項目の表示を確認。手動起動では表示する。
- 実ログイン／再ログイン、OSのログイン項目での実起動、物理⌘Tab・全機能の回帰は未確認。ユーザーのセッション終了、ログイン設定・権限変更は行っていない。
- 公証・配布先配置・公開なし。/Applications・Dropboxは未更新。アプリマニフェストはBUILD-MANIFEST-20261102-login.json。
