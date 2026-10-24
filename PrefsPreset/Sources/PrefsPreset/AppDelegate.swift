import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        // Single main window: no tab items in the Window/View menus.
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        startSettingsSync()
        DispatchQueue.main.async { [weak self] in
            MenuBarPresence.shared.install(name: "PrefsPreset", symbol: "slider.horizontal.3",
                show: { self?.showWindow() },
                settings: { self?.showSettings() },
                help: { LocalHelp.shared.show() })
        }
    }
    /// 設定の共有：このアプリ自身の表示の設定と、言語設定に足したアプリを書き出し・同期する。
    /// .prefspreset（macOSの設定のプリセット）は別のファイル。マイプリセットは同期フォルダーに置くが、自動では適用しない
    private func startSettingsSync() {
        SettingsSync.shared.onImport = { Store.shared.reloadLanguageApps() }
        SettingsSync.shared.start(.init(
            keys: [showGuideKey, showDomainKeyKey, mainModeKey, Store.languageAppsKey],
            note: StartupWindow.text("操作手順・ドメイン／キーの表示、メインウインドウの表示（一覧・ウィザード）、言語設定に追加したアプリを書き出し・同期します。macOSの設定そのものは、プリセット（.prefspreset）で書き出します。マイプリセットも同期フォルダーに保存しますが、自動では適用しません。",
                                     "Exports and syncs the guide and Domain / Key display, the main window view (list or wizard) and the apps added to Language. macOS settings themselves are exported as presets (.prefspreset). My Preset is also saved in the sync folder but is never applied automatically.",
                                     "导出并同步操作说明和“域 / 键”的显示、主窗口的显示方式（列表或向导）以及添加到语言设置的应用。macOS 设置本身以预设（.prefspreset）导出。“我的预设”也保存在同步文件夹中，但不会自动应用。",
                                     "조작 안내와 ‘도메인 / 키’ 표시, 메인 윈도우 보기(목록·마법사), 언어 설정에 추가한 앱을 내보내고 동기화합니다. macOS 설정 자체는 프리셋(.prefspreset)으로 내보냅니다. 내 프리셋도 동기화 폴더에 저장하지만 자동으로 적용하지는 않습니다."),
            perMac: StartupWindow.text("ログイン時の起動・起動時の表示・メニューバーはMacごとに設定します。",
                                       "Open at login, the startup window and the menu bar are set on each Mac.",
                                       "登录时打开、启动时的窗口和菜单栏在每台 Mac 上分别设置。",
                                       "로그인 시 열기, 시작 시 윈도우, 메뉴 막대는 Mac마다 설정합니다.")))
    }

    // Closing the window keeps the app running; reopen from the Dock, ⌘0 or the menu bar icon.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        StartupWindow.userRequestedWindow()
        showWindow()
        // showWindow() already reopens the main window; avoid SwiftUI opening a second one.
        return false
    }
    /// .prefspreset files opened from Finder or dropped on the Dock icon load into 「変更後」.
    func application(_ application: NSApplication, open urls: [URL]) {
        StartupWindow.userRequestedWindow()
        application.reply(toOpenOrPrint: .success)
        showWindow()
        if let url = urls.first { openPreset(url) }
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
