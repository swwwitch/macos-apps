import AppKit
import SwiftUI

/// Settings-only shared grouping. Does not alter persisted values or actions.
enum SettingsUI {
    static var launchTitle: String { StartupWindow.text("起動・常駐", "Startup & Background", "启动与后台", "시작 및 백그라운드") }
    static var displayTitle: String { StartupWindow.text("表示", "Display", "显示", "표시") }
    static var shortcutTitle: String { StartupWindow.text("アプリを呼び出すホットキー", "Show app shortcut", "显示应用快捷键", "앱 표시 단축키") }
    /// The quit/restart buttons go at the bottom of the 「起動・常駐」 tab.
    @MainActor static func tabs(_ sections: [(String, NSView)], in container: NSView) {
        let tabs = NSTabView(frame: container.bounds.insetBy(dx: 12, dy: 12))
        tabs.autoresizingMask = [.width, .height]
        tabs.font = .systemFont(ofSize: 13)
        // The tab view takes the initial focus; its focus ring is drawn offset from the selected tab.
        tabs.focusRingType = .none
        for (title, view) in sections {
            let item = NSTabViewItem(identifier: title)
            item.label = title
            item.view = page(title == launchTitle ? withQuitRestart(view) : view)
            tabs.addTabViewItem(item)
        }
        container.addSubview(tabs)
    }
    /// Scrollable tab page with the shared 20pt margins.
    @MainActor static func page(_ view: NSView) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let document = SettingsDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        view.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 20),
            view.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -20),
            view.topAnchor.constraint(equalTo: document.topAnchor, constant: 20),
            view.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -20)
        ])
        return scroll
    }
    /// Stacks the shared quit/restart group under a 「起動・常駐」 page.
    @MainActor static func withQuitRestart(_ view: NSView) -> NSView {
        let quit = quitRestartGroup()
        let stack = NSStackView(views: [view, quit])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        quit.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }
    /// AppKit form of the quit/restart group.
    @MainActor static func quitRestartGroup() -> NSBox {
        let target = AppLifecycleTarget.shared
        func button(_ title: String, symbol: String, action: Selector) -> NSButton {
            let button = NSButton(title: title, target: target, action: action)
            button.bezelStyle = .rounded
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            button.imagePosition = .imageLeading
            return button
        }
        let buttons = NSStackView(views: [
            button(AppLifecycle.restartTitle, symbol: "arrow.clockwise", action: #selector(AppLifecycleTarget.restart)),
            button(AppLifecycle.quitTitle, symbol: "xmark.square", action: #selector(AppLifecycleTarget.quit))
        ])
        buttons.orientation = .vertical
        buttons.alignment = .leading
        buttons.spacing = 10
        return group(AppLifecycle.actionTitle, [buttons])
    }
    @MainActor static func group(_ title: String, _ views: [NSView]) -> NSBox {
        let box = NSBox()
        box.title = title
        box.titleFont = .systemFont(ofSize: 13, weight: .semibold)
        box.contentViewMargins = NSSize(width: 12, height: 12)
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor),
            stack.topAnchor.constraint(equalTo: box.contentView!.topAnchor),
            stack.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor)
        ])
        for view in views {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return box
    }
}

/// Quit and restart shared by every app's settings.
@MainActor enum AppLifecycle {
    static var appName: String {
        let info = Bundle.main.localizedInfoDictionary ?? Bundle.main.infoDictionary ?? [:]
        return (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? ProcessInfo.processInfo.processName
    }
    static var actionTitle: String { StartupWindow.text("操作", "Action", "操作", "동작") }
    static var restartTitle: String { String(format: StartupWindow.text("%@を再起動", "Restart %@", "重新启动 %@", "%@ 재시작"), appName) }
    static var quitTitle: String { String(format: StartupWindow.text("%@を終了", "Quit %@", "退出 %@", "%@ 종료"), appName) }
    private static var relaunchObserver: NSObjectProtocol?
    static func quit() { NSApp.terminate(nil) }
    /// Relaunch only after this process has really exited; if quitting is cancelled (busy), nothing is launched.
    static func restart() {
        let path = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        relaunchObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { _ in
            let helper = Process()
            helper.executableURL = URL(fileURLWithPath: "/bin/sh")
            helper.arguments = ["-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.1; done; /usr/bin/open \"$2\"", "relaunch", String(pid), path]
            try? helper.run()
        }
        NSApp.terminate(nil)
        // terminate(_:) returns only when quitting was cancelled.
        if let relaunchObserver { NotificationCenter.default.removeObserver(relaunchObserver) }
        relaunchObserver = nil
    }
}

@MainActor private final class AppLifecycleTarget: NSObject {
    static let shared = AppLifecycleTarget()
    @objc func quit() { AppLifecycle.quit() }
    @objc func restart() { AppLifecycle.restart() }
}

/// SwiftUI form of the quit/restart group.
struct QuitRestartSection: View {
    var body: some View {
        SettingsSection(AppLifecycle.actionTitle) {
            Button { AppLifecycle.restart() } label: { Label(AppLifecycle.restartTitle, systemImage: "arrow.clockwise") }
            Button { AppLifecycle.quit() } label: { Label(AppLifecycle.quitTitle, systemImage: "xmark.square") }
        }
    }
}

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    var body: some View {
        GroupBox(label: Text(title).font(.system(size: 13, weight: .semibold))) {
            VStack(alignment: .leading, spacing: 10, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
    }
}

/// Keep settings tabs inside the content area, matching MightyEdit's NSTabView.
/// SwiftUI's automatic settings toolbar can hide all labels in an overflow menu.
struct SettingsTabs: NSViewRepresentable {
    let sections: [(String, AnyView)]
    /// The quit/restart group goes at the bottom of the 「起動・常駐」 tab.
    private var allSections: [(String, AnyView)] {
        sections.map { section in
            section.0 == SettingsUI.launchTitle
                ? (section.0, AnyView(VStack(alignment: .leading, spacing: 16) { section.1; QuitRestartSection() }))
                : section
        }
    }
    func makeNSView(context: Context) -> NSTabView {
        let tabs = NSTabView()
        tabs.font = .systemFont(ofSize: 13)
        // The tab view takes the initial focus; its focus ring is drawn offset from the selected tab.
        tabs.focusRingType = .none
        for (title, content) in allSections {
            let item = NSTabViewItem(identifier: title)
            item.label = title
            item.view = NSHostingView(rootView: page(content))
            tabs.addTabViewItem(item)
        }
        return tabs
    }
    func updateNSView(_ tabs: NSTabView, context: Context) {
        for (index, section) in allSections.enumerated() where index < tabs.numberOfTabViewItems {
            let item = tabs.tabViewItem(at: index)
            item.label = section.0
            (item.view as? NSHostingView<AnyView>)?.rootView = page(section.1)
        }
    }
    private func page(_ content: AnyView) -> AnyView {
        AnyView(ScrollView {
            content.frame(maxWidth: .infinity, alignment: .leading).padding(20)
        })
    }
}
