import AppKit
import SwiftUI

@main
struct IconDropApp: App {
    init() { SingleInstanceLaunch.enforce() }
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup(id: MainWindow.sceneID) {
            ContentView()
                .background(StartupWindowGate())
                .background(UtilityWindowChrome(title: "", isMain: true))
                .background(MainWindowOpenerCapture())
                .environmentObject(settings)
                .frame(minWidth: 420, minHeight: 320)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 480, height: 380)
        .commands {
            CommandGroup(replacing: .help) {
                Button(L("QuickIconExporterヘルプ")) { LocalHelp.shared.show() }
                Divider()
                Button(HelpLinks.noteTitle) { HelpLinks.openNote() }
            }
            #if DIRECT_UPDATES && !APP_STORE
            UpdateCommands()
            #endif
            CommandGroup(after: .newItem) {
                Button(L("ファイルを選択…")) {
                    NotificationCenter.default.post(name: .init("QuickIconExporterChooseFiles"), object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .background(UtilityWindowChrome(title: L("環境設定")))
                .background(MainWindowOpenerCapture())
                .environmentObject(settings)
                .frame(width: 520, height: 650)
        }
    }
}

/// Tracks the drop window so "Show Window" never picks Settings, Help or other utility windows.
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
            window.styleMask.remove(.miniaturizable)
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
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
