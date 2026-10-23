import AppKit
import SwiftUI

/// 「起動・常駐」タブのフルディスクアクセス。サンドボックスのアプリの設定を、確認なしで読むのに使う（HotkeyHound と同じ）
struct FullDiskAccessSection: View {
    @State private var allowed = hasFullDiskAccess
    @State private var failed = false

    var body: some View {
        SettingsSection(L("フルディスクアクセス")) {
            Text(L("サンドボックスのアプリ（App Storeのアプリなど）の設定を読むのに使います。未許可の場合は「設定を読む」・書き出し・取り込みのときに「ほかのアプリからのデータ」へのアクセスの確認が出ます（Macを再起動するたびに出ます）。"))
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Image(systemName: allowed ? "checkmark.circle.fill" : "minus.circle")
                    .foregroundStyle(allowed ? Color.green : Color.secondary)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text(allowed ? L("許可済み") : L("未許可"))
                    .accessibilityLabel(L("フルディスクアクセス") + ": " + (allowed ? L("許可済み") : L("未許可")))
            }
            Button(L("フルディスクアクセス設定を開く")) {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                failed = !NSWorkspace.shared.open(url)
            }
            Text(failed ? L("システム設定を開けませんでした。「プライバシーとセキュリティ」→「フルディスクアクセス」を手動で開いてください。")
                        : L("許可スイッチは手動で操作してください。この画面に戻ると状態を再確認します。"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            allowed = hasFullDiskAccess
        }
    }
}
