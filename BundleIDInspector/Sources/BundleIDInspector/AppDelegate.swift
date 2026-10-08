import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Single main window: no tab items in the Window/View menus.
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            MenuBarPresence.shared.install(name: "BundleIDInspector", symbol: "barcode.viewfinder",
                show: { self?.showWindow() },
                settings: { self?.showSettings() },
                help: { LocalHelp.shared.show() })
        }
    }
    // Closing the window keeps the app running; reopen from the Dock, ⌘0 or the menu bar icon.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showWindow()
        // showWindow() already reopens the main window; avoid SwiftUI opening a second one.
        return false
    }
    /// Apps dropped on the Dock icon or opened with "Open With" are added to the list.
    func application(_ application: NSApplication, open urls: [URL]) {
        AppStore.shared.add(urls)
        application.reply(toOpenOrPrint: .success)
        showWindow()
    }
    /// Shows the main window, reopening the SwiftUI scene when it was closed.
    @objc func showWindow() {
        if let window = MainWindow.current {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            MainWindow.open?()
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showSettings() { SettingsWindow.shared.show() }
}
