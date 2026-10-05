import AppKit
import SwiftUI
import ServiceManagement

@MainActor
final class LoginAtLaunchControl: NSStackView {
    private let toggle = NSButton(checkboxWithTitle: "ログイン時に起動", target: nil, action: nil)
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let settingsButton = NSButton(title: "ログイン項目を開く", target: nil, action: nil)
    private var activationObserver: LoginActivationObserver?

    init() {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 6
        toggle.target = self
        toggle.action = #selector(changed)
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        addArrangedSubview(toggle)
        addArrangedSubview(statusLabel)
        addArrangedSubview(settingsButton)
        activationObserver = LoginActivationObserver(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    func refresh() {
        let status = SMAppService.mainApp.status
        toggle.state = status == .enabled || status == .requiresApproval ? .on : .off
        settingsButton.isHidden = status != .requiresApproval
        switch status {
        case .enabled: statusLabel.stringValue = "Macへのログイン時に自動起動します。"
        case .requiresApproval: statusLabel.stringValue = "システム設定のログイン項目で許可してください。"
        case .notFound: statusLabel.stringValue = "アプリをアプリケーションフォルダに移動して再起動してください。"
        default: statusLabel.stringValue = "自動起動はOFFです。"
        }
    }
    @objc private func changed() {
        do {
            if toggle.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refresh()
        } catch {
            refresh()
            statusLabel.stringValue = "設定を変更できませんでした：\(error.localizedDescription)"
        }
    }
    @objc private func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

struct LoginAtLaunchView: NSViewRepresentable {
    func makeNSView(context: Context) -> LoginAtLaunchControl { LoginAtLaunchControl() }
    func updateNSView(_ view: LoginAtLaunchControl, context: Context) { view.refresh() }
}

private final class LoginActivationObserver: @unchecked Sendable {
    let token: NSObjectProtocol
    init(_ token: NSObjectProtocol) { self.token = token }
    deinit { NotificationCenter.default.removeObserver(token) }
}
