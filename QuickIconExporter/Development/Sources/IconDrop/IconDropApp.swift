import AppKit
import SwiftUI

@main
struct IconDropApp: App {
    init() { SingleInstanceLaunch.enforce() }
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(UtilityWindowChrome(title: ""))
                .environmentObject(settings)
                .frame(minWidth: 420, minHeight: 320)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 480, height: 380)
        .commands {
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
                .environmentObject(settings)
                .frame(width: 520, height: 650)
        }
    }
}

// Configure the actual SwiftUI window once it joins the view hierarchy.
private struct UtilityWindowChrome: NSViewRepresentable {
    let title: String
    func makeNSView(context: Context) -> ChromeView { ChromeView(title: title) }
    func updateNSView(_ view: ChromeView, context: Context) { view.windowTitle = title; view.apply() }
    final class ChromeView: NSView {
        var windowTitle: String
        init(title: String) { windowTitle = title; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); apply() }
        func apply() {
            guard let window else { return }
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
