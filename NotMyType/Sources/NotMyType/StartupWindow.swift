import AppKit
import Carbon
import SwiftUI

/// Manual launch always shows the main window. Only a login-item launch is quiet.
/// The retired hideMainWindowAtStartup preference is deliberately ignored.
enum StartupWindow {
    nonisolated(unsafe) private static var loginLaunch = false
    nonisolated(unsafe) private static var explicitlyOpened = false

    static func isLoginEvent(_ event: NSAppleEventDescriptor?) -> Bool {
        event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
    static func captureLaunch(_ event: NSAppleEventDescriptor? = NSAppleEventManager.shared().currentAppleEvent) {
        loginLaunch = loginLaunch || isLoginEvent(event)
    }
    static var suppressInitialWindow: Bool {
        captureLaunch()
        return loginLaunch && !explicitlyOpened
    }
    /// Reopen and file delivery take precedence over a pending initial-window gate.
    static func userRequestedWindow() { explicitlyOpened = true }

    static func text(_ ja: String, _ en: String, _ zh: String, _ ko: String) -> String {
        // Japanese-only apps have no localized bundles; keep their settings language consistent.
        let language = Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") == nil ? "ja" : (Bundle.main.preferredLocalizations.first ?? "en")
        if language.hasPrefix("ja") { return ja }
        if language.hasPrefix("zh") { return zh }
        if language.hasPrefix("ko") { return ko }
        return en
    }
    static var detail: String { text("ログイン時の自動起動ではメインウインドウを表示しません。手動で起動・開き直したときは表示します。", "Automatic login launch does not show the main window. Opening or reopening the app manually shows it.", "登录时自动启动不显示主窗口。手动启动或重新打开应用时显示主窗口。", "로그인 시 자동 실행할 때는 메인 윈도우를 표시하지 않습니다. 수동으로 실행하거나 다시 열면 표시합니다.") }
}

/// Keeps the app out of the Dock and the ⌘Tab switcher (activation policy .accessory). Missing key keeps the usual policy.
/// Menu-bar apps get their window-dependent policy from WindowActivationPolicy; other apps are .regular.
/// Applied at launch by MenuBarPresence.install and right away when the setting changes.
enum DockPresence {
    static let key = "hideFromDockAndAppSwitcher"
    static var hidden: Bool { UserDefaults.standard.bool(forKey: key) }
    nonisolated(unsafe) static var usualPolicy: () -> NSApplication.ActivationPolicy = { .regular }
    static var title: String { StartupWindow.text("Dockとアプリケーションスイッチャーに表示しない", "Hide from Dock and App Switcher", "不在程序坞和应用程序切换器中显示", "Dock 및 앱 전환기에 표시 안 함") }
    static var detail: String { StartupWindow.text("Dockと⌘Tabの切り替えにアイコンを出しません。メニューバーのアイコンや、Finderからアプリを開き直すと表示できます。", "Keeps the app out of the Dock and the ⌘Tab switcher. Show it from the menu bar icon or by opening the app again in Finder.", "不在程序坞和 ⌘Tab 切换器中显示图标。可通过菜单栏图标或在访达中再次打开应用来显示。", "Dock과 ⌘Tab 전환기에 아이콘을 표시하지 않습니다. 메뉴 막대 아이콘이나 Finder에서 앱을 다시 열어 표시할 수 있습니다.") }
    static func apply() {
        let wanted: NSApplication.ActivationPolicy = hidden ? .accessory : usualPolicy()
        if NSApp.activationPolicy() != wanted { NSApp.setActivationPolicy(wanted) }
    }
    static func set(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
        apply()
        // Switching the policy can send the app behind other apps; keep the settings window in front.
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }
}

@MainActor
final class StartupWindowControl: NSStackView {
    private let dockToggle = NSButton(checkboxWithTitle: DockPresence.title, target: nil, action: nil)
    init() {
        super.init(frame: .zero)
        orientation = .vertical; alignment = .leading; spacing = 6
        addArrangedSubview(note(StartupWindow.detail))
        dockToggle.state = DockPresence.hidden ? .on : .off
        dockToggle.target = self; dockToggle.action = #selector(dockChanged)
        addArrangedSubview(dockToggle)
        addArrangedSubview(note(DockPresence.detail))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    private func note(_ text: String) -> NSTextField {
        let detail = NSTextField(wrappingLabelWithString: text)
        detail.font = .systemFont(ofSize: 11); detail.textColor = .secondaryLabelColor
        return detail
    }
    @objc private func dockChanged() { DockPresence.set(dockToggle.state == .on) }
}

struct StartupWindowView: View {
    @AppStorage(DockPresence.key) private var dockHidden = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(StartupWindow.detail).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Toggle(DockPresence.title, isOn: Binding(get: { dockHidden }, set: { DockPresence.set($0) }))
            Text(DockPresence.detail).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// For SwiftUI-created main windows only: applies once per process, never on reopen/settings.
struct StartupWindowGate: NSViewRepresentable {
    func makeNSView(context: Context) -> GateView { GateView() }
    func updateNSView(_ view: GateView, context: Context) {}
    final class GateView: NSView {
        private static var applied = false
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, !Self.applied else { return }
            Self.applied = true
            // SwiftUI may attach the view before the initial Apple event is delivered.
            NotificationCenter.default.addObserver(self, selector: #selector(finishedLaunching),
                name: NSApplication.didFinishLaunchingNotification, object: nil)
            hideInitialWindowIfNeeded()
        }
        @objc private func finishedLaunching() {
            NotificationCenter.default.removeObserver(self, name: NSApplication.didFinishLaunchingNotification, object: nil)
            hideInitialWindowIfNeeded()
        }
        private func hideInitialWindowIfNeeded() {
            guard let window, StartupWindow.suppressInitialWindow else { return }
            window.orderOut(nil)
            DispatchQueue.main.async {
                guard StartupWindow.suppressInitialWindow else { return }
                window.orderOut(nil)
            }
        }
    }
}
