import AppKit
import SwiftUI

@main
struct PrefsPresetApp: App {
    init() { SingleInstanceLaunch.enforce() }
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: MainWindow.sceneID) {
            ContentView()
                .background(StartupWindowGate())
                .background(UtilityWindowChrome(title: "", isMain: true))
                .background(MainWindowOpenerCapture())
                .frame(minWidth: 960, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1120, height: 720)
        .commands {
            CommandGroup(replacing: .help) {
                Button(L("PrefsPresetヘルプ")) { LocalHelp.shared.show() }
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
            CommandGroup(replacing: .toolbar) {}
            // Replaces SwiftUI's "New Window" ⌘N so only one main window can exist.
            CommandGroup(replacing: .newItem) {
                Button(L("メインウインドウを開く")) { appDelegate.showWindow() }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button(L("開く…")) { openPreset() }
                    .keyboardShortcut("o", modifiers: .command)
                Button(L("書き出す…")) { savePreset() }
                    .keyboardShortcut("s", modifiers: .command)
                Button(L("おすすめの設定を読み込む")) { loadRecommended() }
                Divider()
                Button(L("現在の設定をマイプリセットに保存…")) { MyPreset.save() }
                Button(L("マイプリセットを読み込む")) { MyPreset.load() }
                Button(L("マイプリセットのフォルダを表示")) { MyPreset.showFolder() }
                Divider()
                Button(L("バックアップフォルダを表示")) { showBackupFolder() }
            }
            // SwiftUI's "Close" lives in the save group; the shared menu names it "Close Window".
            CommandGroup(replacing: .saveItem) {
                Divider()
                Button(L("ウインドウを閉じる")) { NSApp.keyWindow?.performClose(nil) }
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
    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = L("設定")
            window.isReleasedWhenClosed = false
            // Resizable from the designed size upward; the hosting view reports only its minimum.
            let hosting = NSHostingView(rootView: SettingsView().frame(minWidth: 480, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.contentMinSize = NSSize(width: 480, height: 400)
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Tracks the main window so "Show Window" never picks Settings, Help or other utility windows.
@MainActor
enum MainWindow {
    static let sceneID = "main"
    static weak var current: NSWindow?
    /// Captured SwiftUI openWindow action, used when the main window was closed.
    static var open: (() -> Void)?
}

private struct MainWindowOpenerCapture: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .onAppear { MainWindow.open = { openWindow(id: MainWindow.sceneID) } }
    }
}

// Configure the actual SwiftUI window once it joins the view hierarchy.
private struct UtilityWindowChrome: NSViewRepresentable {
    let title: String
    var isMain = false
    func makeNSView(context: Context) -> ChromeView { ChromeView(title: title, isMain: isMain) }
    func updateNSView(_ view: ChromeView, context: Context) { view.windowTitle = title; view.apply() }
    final class ChromeView: NSView {
        var windowTitle: String
        let isMain: Bool
        init(title: String, isMain: Bool) { windowTitle = title; self.isMain = isMain; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); apply() }
        func apply() {
            guard let window else { return }
            if isMain { MainWindow.current = window }
            window.title = windowTitle
            if isMain {
                // The main window can be minimized (yellow button, Window > しまう, no key equivalent).
                window.styleMask.insert(.miniaturizable)
                window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            } else {
                window.styleMask.remove(.miniaturizable)
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            }
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.collectionBehavior.insert(.fullScreenNone)
        }
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
