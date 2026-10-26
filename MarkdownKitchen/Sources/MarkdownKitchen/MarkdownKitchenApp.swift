import AppKit
import SwiftUI

@main
struct MarkdownKitchenApp: App {
    init() { SingleInstanceLaunch.enforce() }
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // System settings requests must display the same real settings as the
        // toolbar/menu. Document windows remain entirely AppKit-owned.
        Settings {
            SettingsView()
                .frame(minWidth: 520, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
                .background(SettingsSceneWindowCapture())
        }
        .defaultSize(width: 520, height: 400)
        .windowResizability(.contentMinSize)
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
                Button(L("新規")) { MainWindow.openDocument() }
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

    /// SwiftUI can open its Settings scene through a system settings action.
    /// Adopt that populated window so every subsequent entry point reuses it.
    func adoptSceneWindow(_ incoming: NSWindow) {
        guard window !== incoming else { return }
        let previous = window
        window = incoming
        incoming.title = L("設定")
        incoming.styleMask.insert(.resizable)
        incoming.contentMinSize = NSSize(width: 520, height: 400)
        incoming.contentMaxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        if let previous, previous !== incoming { previous.close() }
    }

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

/// Identify the system-created settings window without replacing its view graph.
private struct SettingsSceneWindowCapture: NSViewRepresentable {
    func makeNSView(context: Context) -> CaptureView { CaptureView() }
    func updateNSView(_ view: CaptureView, context: Context) {}
    final class CaptureView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async { [weak window] in
                guard let window else { return }
                SettingsWindow.shared.adoptSceneWindow(window)
            }
        }
    }
}

/// AppKit owns document lifetimes; SwiftUI is used only inside each hosting view.
@MainActor
enum MainWindow {
    private static var controllers: [String: DocumentWindowController] = [:]
    static var current: NSWindow? { controllers[""]?.window }
    private static var restored = false

    static func show() {
        let existing = NSApp.orderedWindows.compactMap { MarkdownStore.store(for: $0) }.first
        showDocument(existing?.id ?? "")
        restoreDocuments()
    }

    static func showDocument(_ id: String) {
        let controller: DocumentWindowController
        if let existing = controllers[id] {
            controller = existing
        } else {
            controller = DocumentWindowController(store: id.isEmpty ? .main : .document(id))
            controllers[id] = controller
        }
        guard let window = controller.window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        keepOnScreen(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func openDocument() {
        showDocument(MarkdownStore.document(UUID().uuidString).id)
    }

    static func restoreDocuments() {
        guard !restored else { return }
        restored = true
        MarkdownStore.prepareRestoredDocuments()
        for id in UserDefaults.standard.stringArray(forKey: MarkdownStore.documentIDsKey) ?? [] {
            showDocument(id)
        }
    }

    static func closed(_ controller: DocumentWindowController) {
        let store = controller.store
        guard controllers[store.id] === controller else { return }
        controllers.removeValue(forKey: store.id)
        store.window = nil
        store.editor?.delegate = nil
        store.editor = nil
        store.onSourceScroll = nil
        store.sourceScrollOwner = nil
        if !store.isMain { MarkdownStore.discardDocument(store.id) }
        // Release the hosting graph after AppKit finishes closing the window.
        DispatchQueue.main.async { withExtendedLifetime(controller) {} }
    }

    static func keepOnScreen(_ window: NSWindow) {
        guard !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) else { return }
        window.center()
    }
}

@MainActor
final class DocumentWindowController: NSWindowController, NSWindowDelegate {
    let store: MarkdownStore
    init(store: MarkdownStore) {
        self.store = store
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        super.init(window: window)
        window.isReleasedWhenClosed = false
        window.title = store.fileName ?? L("名称未設定")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.collectionBehavior.insert(.fullScreenNone)
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentMinSize = NSSize(width: 560, height: 360)
        let hosting = NSHostingView(rootView: ContentView(store: store)
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 360, maxHeight: .infinity))
        hosting.sizingOptions = [.minSize]
        window.contentView = hosting
        window.center()
        if store.isMain { window.setFrameAutosaveName("MarkdownKitchenMain") }
        window.delegate = self
        store.window = window
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    func windowDidBecomeKey(_ notification: Notification) { store.becameActive() }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // closeWindow performs the save confirmation and calls close directly.
        store.closeWindow()
        return false
    }
    func windowWillClose(_ notification: Notification) { MainWindow.closed(self) }
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
