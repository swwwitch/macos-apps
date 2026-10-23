import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Single main window: no tab items in the Window/View menus.
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        startSettingsSync()
        DispatchQueue.main.async { [weak self] in
            MenuBarPresence.shared.install(name: "SettingsCourier", symbol: "shippingbox",
                show: { self?.showWindow() },
                settings: { self?.showSettings() },
                help: { LocalHelp.shared.show() })
        }
    }
    /// 設定の共有：登録したアプリの一覧と、書き出すキーの選択を書き出し・同期する。アプリの設定そのものは .settingscourier で運ぶ
    private func startSettingsSync() {
        SettingsSync.shared.onImport = { Courier.shared.reload() }
        SettingsSync.shared.start(.init(
            keys: [Courier.appsKey, Courier.excludedKeysKey, Courier.includedKeysKey, Courier.extraFilesKey],
            note: StartupWindow.text("登録したアプリの一覧と書き出すキーの選択を同期します。アプリの設定の値は、同期フォルダーの SettingsCourier フォルダーで受け渡します。",
                                     "Syncs the list of registered apps and which keys to export. App setting values are handed over through the SettingsCourier folder in the sync folder.",
                                     "同步已登记的应用列表以及要导出的键的选择。应用的设置值通过同步文件夹中的 SettingsCourier 文件夹交接。",
                                     "등록한 앱 목록과 내보낼 키 선택을 동기화합니다. 앱의 설정 값은 동기화 폴더 안의 SettingsCourier 폴더로 주고받습니다."),
            perMac: StartupWindow.text("ログイン時の起動・起動時の表示・メニューバーはMacごとに設定します。",
                                       "Open at login, the startup window and the menu bar are set on each Mac.",
                                       "登录时打开、启动时的窗口和菜单栏在每台 Mac 上分别设置。",
                                       "로그인 시 열기, 시작 시 윈도우, 메뉴 막대는 Mac마다 설정합니다.")))
    }

    // Closing the window keeps the app running; reopen from the Dock, ⌘0 or the menu bar icon.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showWindow()
        // showWindow() already reopens the main window; avoid SwiftUI opening a second one.
        return false
    }
    /// .settingscourier files open the import sheet; apps dropped on the Dock icon are added to the list.
    func application(_ application: NSApplication, open urls: [URL]) {
        application.reply(toOpenOrPrint: .success)
        showWindow()
        let packages = urls.filter { $0.pathExtension == "settingscourier" }
        Courier.shared.add(urls.filter { $0.pathExtension == "app" })
        if !packages.isEmpty { openPackages(packages) }
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
