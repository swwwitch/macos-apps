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

/// Hide background presence, but keep the application menu available for regular windows.
/// A minimized window stays listed so Dock/⌘Tab can restore it. Palettes never opt in.
enum DockPresence {
    static let key = "hideFromDockAndAppSwitcher"
    static var hidden: Bool { UserDefaults.standard.bool(forKey: key) }
    nonisolated(unsafe) static var usualPolicy: () -> NSApplication.ActivationPolicy = { .regular }
    nonisolated(unsafe) private static var observers: [NSObjectProtocol] = []
    nonisolated(unsafe) private static var applying = false
    nonisolated(unsafe) private static var minimizing = NSHashTable<NSWindow>.weakObjects()
    static var title: String { StartupWindow.text("Dockとアプリケーションスイッチャーに表示しない", "Hide from Dock and App Switcher", "不在程序坞和应用程序切换器中显示", "Dock 및 앱 전환기에 표시 안 함") }
    static var detail: String { StartupWindow.text("メイン・設定ウインドウがある間は、アプリメニューを使えるようDockと⌘Tabに表示します。最小化中も表示を保ち、対象ウインドウをすべて閉じると隠します。メニューバーのアイコンやFinderから開き直せます。", "While a main or settings window is open, the app appears in the Dock and ⌘Tab so its menus remain available. Minimized windows stay listed. Close all such windows to hide it; reopen from the menu bar icon or Finder.", "主窗口或设置窗口打开时，应用会显示在程序坞和 ⌘Tab 中，以便使用应用菜单。最小化时仍保留显示；关闭所有此类窗口后隐藏。可通过菜单栏图标或访达重新打开。", "메인 또는 설정 윈도우가 열려 있는 동안 앱 메뉴를 사용할 수 있도록 Dock과 ⌘Tab에 표시합니다. 최소화 중에도 유지하며 해당 윈도우를 모두 닫으면 숨깁니다. 메뉴 막대 아이콘이나 Finder에서 다시 열 수 있습니다.") }
    static func counts(_ window: NSWindow) -> Bool {
        (window.isVisible || window.isMiniaturized || minimizing.contains(window)) && !(window is NSPanel)
            && (window.canBecomeMain || window.isMiniaturized || minimizing.contains(window)) && window.styleMask.contains(.titled)
    }
    private static func observeWindows() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        // didUpdate covers orderFront/orderOut as well as SwiftUI-created settings windows.
        for name in [NSApplication.didUpdateNotification, NSWindow.didBecomeKeyNotification,
                     NSWindow.didDeminiaturizeNotification,
                     NSWindow.didChangeOcclusionStateNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in apply() })
        }
        observers.append(center.addObserver(forName: NSWindow.willMiniaturizeNotification, object: nil, queue: .main) { note in
            if let window = note.object as? NSWindow, counts(window) { minimizing.add(window) }
            apply()
        })
        observers.append(center.addObserver(forName: NSWindow.didMiniaturizeNotification, object: nil, queue: .main) { note in
            if let window = note.object as? NSWindow { minimizing.remove(window) }
            apply()
        })
        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            if let window = note.object as? NSWindow { minimizing.remove(window) }
            // willClose arrives before isVisible changes, including while another app is active.
            DispatchQueue.main.async { apply() }
        })
    }
    static func apply() {
        observeWindows()
        guard !applying else { return }
        applying = true
        defer { applying = false }
        let wanted: NSApplication.ActivationPolicy = hidden
            ? (NSApp.windows.contains(where: counts) ? .regular : .accessory) : usualPolicy()
        if NSApp.activationPolicy() != wanted { NSApp.setActivationPolicy(wanted) }
        // Window notifications must not activate this app or steal focus from another app.
    }
    static func set(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
        apply()
        // A user action in settings may change policy; keep that existing window in front.
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
