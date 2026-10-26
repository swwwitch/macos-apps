import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
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
        StartupWindow.captureLaunch()
        KeyNames.prepare()
        startSettingsSync()
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
        StartupWindow.userRequestedWindow()
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
    @objc func showSettings() { AppSwitcherWindowReveal.preserveAuxiliaryWindowOnActivation(); SettingsWindow.shared.show() }

    /// 設定の共有：照合元の選択・並び順・独自の照合元と「無効なホットキーを非表示」を書き出し・同期する
    private func startSettingsSync() {
        SettingsSync.shared.onImport = { HotkeyStore.shared.settingsImported() }
        SettingsSync.shared.start(.init(
            keys: [HotkeySource.orderKey, CustomSources.key, "lookup.hideInactive"],
            prefixes: ["source."],
            note: StartupWindow.text("照合元の選択・並び順・独自の照合元と、「無効なホットキーを非表示」を書き出し・同期します。",
                                     "Exports and syncs which sources are checked, their order, custom sources and “Hide inactive hotkeys”.",
                                     "导出并同步所选来源、来源顺序、自定来源和“隐藏无效的快捷键”。",
                                     "선택한 출처, 출처 순서, 사용자 출처와 ‘비활성 단축키 숨기기’를 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・起動時の表示・メニューバー・照合する範囲（指定したアプリ）はMacごとに設定します。",
                                       "Open at login, startup window, menu bar and the apps to check are set on each Mac.",
                                       "登录时打开、启动时的窗口、菜单栏和要检查的应用在每台 Mac 上分别设置。",
                                       "로그인 시 열기, 시작 시 윈도우, 메뉴 막대, 확인할 앱은 Mac마다 설정합니다."),
            merge: CustomSources.merge))
    }
}
