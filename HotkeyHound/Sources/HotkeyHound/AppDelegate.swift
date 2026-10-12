import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Single main window: no tab items in the Window/View menus.
        NSWindow.allowsAutomaticWindowTabbing = false
        AccessibilityText.neededOverride = [
            "押したキーをほかのアプリより先に受け取るためと、起動中のアプリのメニューに付いたホットキーを読むために使います。未許可の場合、ほかのアプリが先に受け取るキーは記録できず、メニューは照合しません。",
            "Used to receive the pressed key before other apps and to read the hotkeys in running apps' menus. Without it, keys that other apps take first cannot be recorded and menus are not checked.",
            "用于在其他应用之前接收按下的按键，并读取正在运行的应用菜单中的快捷键。未获授权时，无法记录被其他应用先接收的按键，也不会检查菜单。",
            "다른 앱보다 먼저 누른 키를 받고, 실행 중인 앱의 메뉴에 지정된 단축키를 읽는 데 사용합니다. 권한이 없으면 다른 앱이 먼저 받는 키는 기록할 수 없고 메뉴는 확인하지 않습니다.",
        ]
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        KeyNames.prepare()
        DispatchQueue.main.async { [weak self] in
            MenuBarPresence.shared.install(name: "HotkeyHound", symbol: "keyboard.badge.eye",
                show: { self?.showWindow() },
                settings: { self?.showSettings() },
                help: { LocalHelp.shared.show() })
        }
    }
    func applicationWillTerminate(_ notification: Notification) { KeyRecorder.shared.stop() }
    // Closing the window keeps the app running; reopen from the Dock, ⌘0 or the menu bar icon.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showWindow()
        // showWindow() already reopens the main window; avoid SwiftUI opening a second one.
        return false
    }
    /// Shows the main window, reopening the SwiftUI scene when it was closed.
    @objc func showWindow() {
        if let window = MainWindow.current {
            if window.isMiniaturized { window.deminiaturize(nil) }
            MainWindow.keepOnScreen(window)
            window.makeKeyAndOrderFront(nil)
        } else {
            MainWindow.open?()
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showSettings() { SettingsWindow.shared.show() }
}
