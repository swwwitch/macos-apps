import AppKit
import SwiftUI

/// 「起動・常駐」タブのフルディスクアクセス。サンドボックスのアプリ（コンテナ内の設定）を起動時から照合するのに使う
struct FullDiskAccessSection: View {
    @State private var allowed = HotkeyScanners.hasFullDiskAccess
    @State private var failed = false

    var body: some View {
        SettingsSection(L("フルディスクアクセス")) {
            Text(L("サンドボックスのアプリ（Keystroke Pro、KeyboardShortcuts形式のアプリ）の設定を読むのに使います。未許可の場合、これらは［読み直す］を押すまで照合せず、押すと「ほかのアプリからのデータ」へのアクセスの確認が出ます（Macを再起動するたびに出ます）。"))
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Image(systemName: allowed ? "checkmark.circle.fill" : "minus.circle")
                    .foregroundStyle(allowed ? Color.green : Color.secondary)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text(allowed ? AccessibilityText.text("allowed") : AccessibilityText.text("denied"))
                    .accessibilityLabel(L("フルディスクアクセス") + ": " + (allowed ? AccessibilityText.text("allowed") : AccessibilityText.text("denied")))
            }
            Button(L("フルディスクアクセス設定を開く")) {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                failed = !NSWorkspace.shared.open(url)
            }
            Text(failed ? L("システム設定を開けませんでした。「プライバシーとセキュリティ」→「フルディスクアクセス」を手動で開いてください。")
                        : AccessibilityText.text("hint"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            allowed = HotkeyScanners.hasFullDiskAccess
        }
    }
}
