import AppKit
import SwiftUI
import ServiceManagement

@MainActor
final class LoginAtLaunchControl: NSStackView {
    private let toggle = NSButton(checkboxWithTitle: L("login"), target: nil, action: nil)
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let settingsButton = NSButton(title: L("loginOpen"), target: nil, action: nil)
    private var activationObserver: NSObjectProtocol?

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
        activationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    deinit { if let observer = activationObserver { NotificationCenter.default.removeObserver(observer) } }
    func refresh() {
        let status = SMAppService.mainApp.status
        toggle.state = status == .enabled || status == .requiresApproval ? .on : .off
        settingsButton.isHidden = status != .requiresApproval
        switch status {
        case .enabled: statusLabel.stringValue = L("loginOn")
        case .requiresApproval: statusLabel.stringValue = L("loginApproval")
        case .notFound: statusLabel.stringValue = L("loginMissing")
        default: statusLabel.stringValue = L("loginOff")
        }
    }
    @objc private func changed() {
        do {
            if toggle.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refresh()
        } catch {
            refresh()
            statusLabel.stringValue = L("loginError") + error.localizedDescription
        }
    }
    @objc private func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

struct LoginAtLaunchView: NSViewRepresentable {
    func makeNSView(context: Context) -> LoginAtLaunchControl { LoginAtLaunchControl() }
    func updateNSView(_ view: LoginAtLaunchControl, context: Context) { view.refresh() }
}
