import AppKit
import SwiftUI
import ServiceManagement

// Canonical source: Shared/LoginAtLaunch/LoginAtLaunch.swift. Copy with Shared/LoginAtLaunch/sync.py.
// Text follows StartupWindow.text: Japanese-only apps (no CFBundleLocalizations) stay Japanese.
@MainActor
final class LoginAtLaunchControl: NSStackView {
    private let toggle = NSButton(checkboxWithTitle: StartupWindow.text("ログイン時に起動", "Open at login", "登录时启动", "로그인 시 실행"), target: nil, action: nil)
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let settingsButton = NSButton(title: StartupWindow.text("ログイン項目を開く", "Open Login Items", "打开登录项", "로그인 항목 열기"), target: nil, action: nil)
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
        addArrangedSubview(StartupWindowControl())
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
        case .enabled: statusLabel.stringValue = StartupWindow.text("Macへのログイン時に自動起動します。", "Opens automatically when you log in.", "登录时自动启动。", "로그인할 때 자동으로 실행합니다.")
        case .requiresApproval: statusLabel.stringValue = StartupWindow.text("システム設定のログイン項目で許可してください。", "Approve it in Login Items in System Settings.", "请在系统设置的登录项中允许。", "시스템 설정의 로그인 항목에서 허용하세요.")
        // A never-registered app also reports .notFound; only blame the location when it is really outside Applications.
        case .notFound where !Self.inApplicationsFolder: statusLabel.stringValue = StartupWindow.text("アプリをアプリケーションフォルダに移動して再起動してください。", "Move the app to Applications and relaunch it.", "请将应用移到“应用程序”文件夹并重新启动。", "앱을 응용 프로그램 폴더로 옮긴 후 다시 실행하세요.")
        default: statusLabel.stringValue = StartupWindow.text("自動起動はオフです。", "Not opening at login.", "登录时不启动。", "로그인 시 실행 안 함.")
        }
    }
    private static var inApplicationsFolder: Bool {
        let path = Bundle.main.bundleURL.deletingLastPathComponent().resolvingSymlinksInPath().path
        return path == "/Applications" || path == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
    }
    @objc private func changed() {
        do {
            if toggle.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refresh()
        } catch {
            refresh()
            statusLabel.stringValue = StartupWindow.text("設定を変更できませんでした：", "Could not change the setting: ", "无法更改设置：", "설정을 변경할 수 없습니다: ") + error.localizedDescription
        }
    }
    @objc private func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

struct LoginAtLaunchView: NSViewRepresentable {
    func makeNSView(context: Context) -> LoginAtLaunchControl { LoginAtLaunchControl() }
    func updateNSView(_ view: LoginAtLaunchControl, context: Context) { view.refresh() }
}

/// Removes the activation observer when the control goes away (Swift 6–safe, no deinit on the main actor).
private final class LoginActivationObserver: @unchecked Sendable {
    let token: NSObjectProtocol
    init(_ token: NSObjectProtocol) { self.token = token }
    deinit { NotificationCenter.default.removeObserver(token) }
}
