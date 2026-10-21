import AppKit
import SwiftUI

@main
struct MarkdownKitchenApp: App {
    init() { SingleInstanceLaunch.enforce() }
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // One scene for both: no value is the main window, a value (source id) is a new window (⌃⌘N).
        // A second WindowGroup would make SwiftUI replace ウインドウを閉じる with its own Close / Close All.
        WindowGroup(id: MainWindow.sceneID, for: String.self) { $id in
            if let id {
                DocumentWindowContent(id: id)
                    .handlesExternalEvents(preferring: [], allowing: ["*"])
            } else {
                MainWindowContent()
                    .handlesExternalEvents(preferring: [], allowing: ["*"])
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 640)
        .commands {
            FormatMenuCommands()
            // 「ツール」：整形・HTML→Markdown・目次（原稿のバーの「整形」と同じ項目）、Doorkeeper用に整形、すべての見出しの上げ下げ
            CommandMenu(L("ツール")) {
                Menu(L("整形")) { TidyRuleItems() }
                Divider()
                TidyToolItems(levels: MarkdownStore.storedLevels, inToolsMenu: true)
            }
            CommandGroup(replacing: .help) {
                Button(L("MarkdownKitchenヘルプ")) { LocalHelp.shared.show() }
                    .keyboardShortcut("?", modifiers: .command)
                Divider()
                Button(HelpLinks.noteTitle) { HelpLinks.openNote() }
            }
            CommandGroup(replacing: .appSettings) {
                Button(L("設定…")) { SettingsWindow.shared.show() }
                    .keyboardShortcut(",", modifiers: .command)
                #if DIRECT_UPDATES && !APP_STORE
                Divider()
                UpdateMenuItems()
                #endif
            }
            // No tab bar or View menu: the app has a single main window.
            // 表示：文字の大きさ、原稿の配色・表示・見出しの太字（ツールバー・タブバーの項目は無し）
            CommandGroup(replacing: .toolbar) {
                Button(L("文字を大きく")) { MarkdownStore.changeFontSize(by: 1) }
                    .keyboardShortcut("+", modifiers: .command)
                Button(L("文字を小さく")) { MarkdownStore.changeFontSize(by: -1) }
                    .keyboardShortcut("-", modifiers: .command)
                Button(L("標準の文字サイズ")) { MarkdownStore.changeFontSize(by: 0) }
                Divider()
                EditorViewMenuItems()
                Divider()
            }
            // Replaces SwiftUI's "New Window" ⌘N so only one main window can exist.
            CommandGroup(replacing: .newItem) {
                Button(L("メインウインドウを開く")) { appDelegate.showWindow() }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button(L("新規")) { MarkdownStore.shared.newFile() }
                    .keyboardShortcut("n", modifiers: .command)
                Button(L("新規ウインドウ")) { MainWindow.openDocument() }
                    .keyboardShortcut("n", modifiers: [.command, .control])
                Button(L("ファイルを開く…")) { MarkdownStore.shared.chooseFile() }
                    .keyboardShortcut("o", modifiers: .command)
                Button(L("保存")) { MarkdownStore.shared.save() }
                    .keyboardShortcut("s", modifiers: .command)
                Button(L("別名で保存…")) { MarkdownStore.shared.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Button(L("上書き前の控えを表示")) { MarkdownStore.shared.showBackups() }
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                // "Copy as …" commands sit with Copy, as in other Mac apps.
                ShortcutButton(action: .copyHeadings)
                ShortcutButton(action: .copyHTML)
                Divider()
                Menu(L("検索")) {
                    ShortcutButton(action: .findReplace)
                    ShortcutButton(action: .findNext)
                    ShortcutButton(action: .findPrevious)
                    Divider()
                    ShortcutButton(action: .useSelectionForFind)
                    ShortcutButton(action: .jumpToSelection)
                }
            }
            // SwiftUI's "Close" lives in the save group; the shared menu names it "Close Window".
            // SwiftUI already separates this group from the one above.
            CommandGroup(replacing: .saveItem) {
                Button(L("ウインドウを閉じる")) {
                    // Asks about unsaved changes before the window's source is discarded.
                    if let window = NSApp.keyWindow, window.sheetParent == nil, let store = MarkdownStore.store(for: window) {
                        store.closeWindow()
                    } else {
                        NSApp.keyWindow?.performClose(nil)
                    }
                }
                    .keyboardShortcut("w", modifiers: .command)
            }
            // SwiftUI's standard Minimize carries ⌘M; the shared menu gives しまう no key equivalent.
            CommandGroup(replacing: .windowSize) {
                Button(L("しまう")) { NSApp.keyWindow?.performMiniaturize(nil) }
                Button(L("拡大／縮小")) { NSApp.keyWindow?.performZoom(nil) }
            }
        }

        // The settings window is SettingsWindow (AppKit), so 設定… and the update items share one group.
    }
}

/// メインウインドウの中身。メインウインドウが見えているときに作られたもの（ファイルを開いたときに
/// SwiftUI が足すウインドウ）は、同じ原稿を二重に表示しないよう何も出さずに閉じる
private struct MainWindowContent: View {
    @State private var duplicate = MainWindow.current?.isVisible == true
    var body: some View {
        if duplicate {
            DuplicateWindowCloser()
        } else {
            ContentView(store: .main)
                .background(StartupWindowGate())
                .background(UtilityWindowChrome(title: "", store: .main))
                .background(MainWindowOpenerCapture())
                .frame(minWidth: 560, minHeight: 360)
        }
    }
}

private struct DuplicateWindowCloser: NSViewRepresentable {
    func makeNSView(context: Context) -> CloserView { CloserView() }
    func updateNSView(_ view: CloserView, context: Context) {}
    final class CloserView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.orderOut(nil)
            DispatchQueue.main.async { window.close() }
        }
    }
}

/// 新規ウインドウの中身。ウインドウメニューにはファイル名（無ければ「名称未設定」）を出す
private struct DocumentWindowContent: View {
    // Created once per window, so a redraw while closing does not register the discarded source again.
    @StateObject private var store: MarkdownStore
    init(id: String) { _store = StateObject(wrappedValue: .document(id)) }
    var body: some View {
        ContentView(store: store)
            .background(UtilityWindowChrome(title: store.fileName ?? L("名称未設定"), store: store))
            .frame(minWidth: 560, minHeight: 360)
    }
}

#if DIRECT_UPDATES && !APP_STORE
/// アップデートを確認… / アップデートを自動確認 (same items as the shared UpdateCommands).
private struct UpdateMenuItems: View {
    @ObservedObject private var updates = AppUpdates.shared
    var body: some View {
        Button(updates.text("アップデートを確認…", "Check for Updates…", "检查更新…", "업데이트 확인…")) { updates.checkForUpdates() }
            .disabled(!updates.canCheck)
        Toggle(updates.text("アップデートを自動確認", "Automatically Check for Updates", "自动检查更新", "자동으로 업데이트 확인"), isOn: Binding(
            get: { updates.automaticChecks }, set: { _ in updates.toggleAutomaticChecks() }))
            .disabled(!updates.isConfigured)
    }
}
#endif

/// The settings window. Reused while the app runs; ⌘W closes it (File > ウインドウを閉じる).
@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()
    private var window: NSWindow?
    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = L("設定")
            window.isReleasedWhenClosed = false
            // Resizable from the designed size upward; the hosting view reports only its minimum.
            let hosting = NSHostingView(rootView: SettingsView().frame(minWidth: 520, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.contentMinSize = NSSize(width: 520, height: 400)
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// 設定を開き、見出し（ラベル）が一致するタブを選ぶ
    func show(tab label: String) {
        show()
        guard let content = window?.contentView else { return }
        content.layoutSubtreeIfNeeded()
        // SwiftUI builds the tab view on the next layout pass when the window was just created.
        if !select(label, in: content) {
            DispatchQueue.main.async { [weak self] in
                guard let content = self?.window?.contentView else { return }
                content.layoutSubtreeIfNeeded()
                _ = self?.select(label, in: content)
            }
        }
    }

    private func select(_ label: String, in view: NSView) -> Bool {
        if let tabs = view as? NSTabView, let item = tabs.tabViewItems.first(where: { $0.label == label }) {
            tabs.selectTabViewItem(item)
            return true
        }
        return view.subviews.contains { select(label, in: $0) }
    }
}

/// Tracks the main window so "Show Window" never picks Settings, Help or other utility windows.
@MainActor
enum MainWindow {
    static let sceneID = "main"
    static weak var current: NSWindow?
    /// Captured SwiftUI openWindow action, used when the main window was closed.
    static var open: (() -> Void)?
    /// Captured SwiftUI openWindow action for new windows (value = source id).
    static var openWithID: ((String) -> Void)?
    private static var restored = false

    /// Shows the main window, reopening the SwiftUI scene when it was closed (and the new windows left open last time).
    /// NSApp.delegate is SwiftUI's adaptor, not AppDelegate, so callers use this rather than casting it.
    static func show() {
        if let window = current {
            if window.isMiniaturized { window.deminiaturize(nil) }
            keepOnScreen(window)
            window.makeKeyAndOrderFront(nil)
        } else {
            open?()
        }
        restoreDocuments()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 新規ウインドウを開く（空の原稿）
    static func openDocument() {
        openWithID?(UUID().uuidString)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 前回開いていた新規ウインドウを開き直す（1回だけ）
    static func restoreDocuments() {
        guard !restored, let openWithID else { return }
        restored = true
        for id in UserDefaults.standard.stringArray(forKey: MarkdownStore.documentIDsKey) ?? [] { openWithID(id) }
    }
    /// Re-centers the window when its restored frame lies on no current screen (e.g. a display was disconnected).
    static func keepOnScreen(_ window: NSWindow) {
        guard !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) else { return }
        window.center()
    }
}

private struct MainWindowOpenerCapture: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .onAppear {
                MainWindow.open = { openWindow(id: MainWindow.sceneID) }
                MainWindow.openWithID = { openWindow(id: MainWindow.sceneID, value: $0) }
                // While the main window is hidden at startup, they open with it (AppDelegate.showWindow).
                if !StartupWindow.hidden { DispatchQueue.main.async { MainWindow.restoreDocuments() } }
            }
    }
}

// Configure the actual SwiftUI window once it joins the view hierarchy.
private struct UtilityWindowChrome: NSViewRepresentable {
    let title: String
    /// The source shown in this window (main window or a new window).
    let store: MarkdownStore
    func makeNSView(context: Context) -> ChromeView { ChromeView(title: title, store: store) }
    func updateNSView(_ view: ChromeView, context: Context) { view.windowTitle = title; view.apply() }
    final class ChromeView: NSView {
        var windowTitle: String
        let store: MarkdownStore
        private var observers: [NSObjectProtocol] = []
        init(title: String, store: MarkdownStore) { windowTitle = title; self.store = store; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            apply()
            guard let window else { return }
            // After SwiftUI restores the saved frame.
            if store.isMain { DispatchQueue.main.async { MainWindow.keepOnScreen(window) } }
            let store = store
            observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { _ in
                MainActor.assumeIsolated { store.becameActive() }
            })
            if !store.isMain {
                // Closing a new window discards its source (after asking about unsaved changes).
                observers.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
                    MainActor.assumeIsolated { MarkdownStore.discardDocument(store.id) }
                })
            }
        }
        func apply() {
            guard let window else { return }
            if store.isMain { MainWindow.current = window }
            if store.window !== window { store.window = window }
            window.title = windowTitle
            // The windows can be minimized (yellow button, Window > しまう, no key equivalent).
            window.styleMask.insert(.miniaturizable)
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.collectionBehavior.insert(.fullScreenNone)
            if let close = window.standardWindowButton(.closeButton) {
                close.target = self
                close.action = #selector(closeClicked(_:))
            }
        }
        @objc private func closeClicked(_ sender: Any?) { store.closeWindow() }
    }
}

// Bundle identity, rather than the bundle path or build number, defines one app.
@MainActor
private enum SingleInstanceLaunch {
    static func enforce() {
        let current = NSRunningApplication.current
        guard let identifier = Bundle.main.bundleIdentifier else { return }
        var candidates = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .filter { !$0.isTerminated }
        if !candidates.contains(where: { $0.processIdentifier == current.processIdentifier }) {
            candidates.append(current)
        }
        candidates.sort {
            let left = $0.launchDate ?? .distantPast
            let right = $1.launchDate ?? .distantPast
            return left == right ? $0.processIdentifier < $1.processIdentifier : left < right
        }
        guard let existing = candidates.first,
              existing.processIdentifier != current.processIdentifier else { return }
        existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        if let url = existing.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
                exit(0)
            }
            // Allow the reopen Apple event to reach hidden/menu-bar applications.
            RunLoop.main.run(until: Date().addingTimeInterval(2))
        }
        exit(0)
    }
}
