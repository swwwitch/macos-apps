# 標準通知の共通設定（B32）

`NotificationPreferences.swift` と `Shared/AppStandards/StartupWindow.swift`、`SettingsSection.swift` をビルドに含める。QuickIconExporterのSwiftPM版は `python3 Shared/Notifications/sync.py` でチェックイン対象のコピーを更新する（通常ビルドから実行済み）。

- 設定に `NotificationPermissionView(enabled:toggleTitle:sound:)` を配置し、既存の保存済みBoolをBindingで渡す。
- 通知送信は `NotificationPreferences.shared.post`。enabledKeyと既存の既定値を渡し、送信直前にも選択を確認する。
- `request` は明示的なUI操作からだけ呼ぶ。`refresh` と `post` は許可を要求しない。
- 既存のUNUserNotificationCenterDelegateは各アプリが保持し、前面表示とクリック後の動作を定義する。
- `CompletionNotificationSettings` はFolderHopperのAppKit設定ページ用で、従来の既定ONを引き継ぐ。新規アプリの補助的な完了通知には既定OFFのBindingを用意する。
- OSの許可はMac固有の状態であり、設定同期やインポートで変更しない。
- 送信登録エラーは共通のerrorMessageに保持する。アプリの処理結果・失敗原因は通知に依存せず画面に残す。
