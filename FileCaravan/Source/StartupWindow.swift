import AppKit
import SwiftUI

/// Persisted independently from login registration and residency. Missing key preserves existing behavior.
enum StartupWindow {
    static let key = "hideMainWindowAtStartup"
    static var hidden: Bool { UserDefaults.standard.bool(forKey: key) }
    static func text(_ ja: String, _ en: String, _ zh: String, _ ko: String) -> String {
        // Japanese-only apps have no localized bundles; keep their settings language consistent.
        let language = Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") == nil ? "ja" : (Bundle.main.preferredLocalizations.first ?? "en")
        if language.hasPrefix("ja") { return ja }
        if language.hasPrefix("zh") { return zh }
        if language.hasPrefix("ko") { return ko }
        return en
    }
    static var title: String { text("起動時にメインウインドウを表示しない", "Hide main window at startup", "启动时不显示主窗口", "시작 시 메인 윈도우 표시 안 함") }
    static var detail: String { text("メインウインドウを開かずに起動します。起動後はDockやメニューから表示できます。", "Launch without opening the main window. Show it later from the Dock or menu.", "启动时不打开主窗口。之后可从 Dock 或菜单显示。", "메인 윈도우를 열지 않고 시작합니다. Dock 또는 메뉴에서 다시 표시할 수 있습니다.") }
}

@MainActor
final class StartupWindowControl: NSStackView {
    private let toggle = NSButton(checkboxWithTitle: StartupWindow.title, target: nil, action: nil)
    init() {
        super.init(frame: .zero)
        orientation = .vertical; alignment = .leading; spacing = 6
        toggle.state = StartupWindow.hidden ? .on : .off
        toggle.target = self; toggle.action = #selector(changed)
        addArrangedSubview(toggle)
        let detail = NSTextField(wrappingLabelWithString: StartupWindow.detail)
        detail.font = .systemFont(ofSize: 11); detail.textColor = .secondaryLabelColor
        addArrangedSubview(detail)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    @objc private func changed() { UserDefaults.standard.set(toggle.state == .on, forKey: StartupWindow.key) }
}

struct StartupWindowView: View {
    @AppStorage(StartupWindow.key) private var hidden = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(StartupWindow.title, isOn: $hidden)
            Text(StartupWindow.detail).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
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
            guard StartupWindow.hidden else { return }
            window.orderOut(nil)
            DispatchQueue.main.async { window.orderOut(nil) }
        }
    }
}
