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
        // ログアウトでアクティブが外れるので、ログイン時の起動でも戻す
        LibraryStore.shared.restoreActiveFonts()
        LibraryStore.shared.scanUserFonts()
        LibraryStore.shared.fillMetadata()
        WatchFolders.shared.start()
        BenchMode.startIfRequested()
        AppHotkey.shared.onPress = { [weak self] in
            StartupWindow.userRequestedWindow()
            self?.showWindow()
        }
        AppHotkey.shared.start()
        startSettingsSync()
        DispatchQueue.main.async { [weak self] in
            MenuBarPresence.shared.install(name: "FontSwitcher", symbol: "textformat",
                show: { self?.showWindow() },
                settings: { self?.showSettings() },
                help: { LocalHelp.shared.show() },
                extraItems: { AppDelegate.projectMenuItems() })
        }
    }
    /// 設定の共有：起動・終了時の動作とプレビューの文字。ライブラリ（ファイルの場所）はMacごと
    private func startSettingsSync() {
        SettingsSync.shared.start(.init(
            keys: LibraryStore.syncedKeys,
            note: StartupWindow.text("起動・終了時のアクティブの扱い、~/Library/Fonts の表示、プレビューの文字を同期します。ライブラリ・セット・お気に入りは「フォント」タブの「ライブラリの共有」で共有します。",
                                     "Syncs how fonts are activated at launch and quit, whether ~/Library/Fonts is listed, and the preview text. Share the library, sets and favorites with Library Sharing in the Fonts tab.",
                                     "同步启动和退出时的激活方式、是否列出 ~/Library/Fonts 以及预览文字。资源库、字体集和个人收藏请在“字体”标签的“资源库共享”中共享。",
                                     "실행·종료 시의 활성화 방식, ~/Library/Fonts 표시 여부, 미리보기 문자를 동기화합니다. 보관함·세트·즐겨찾기는 ‘서체’ 탭의 ‘보관함 공유’에서 공유합니다."),
            perMac: StartupWindow.text("共有フォルダーの場所・ログイン時の起動・Dock表示・メニューバーはMacごとに設定します。",
                                       "The shared folder location, open at login, Dock visibility and menu bar are set on each Mac.",
                                       "共享文件夹位置、登录时打开、Dock 显示和菜单栏在每台 Mac 上分别设置。",
                                       "공유 폴더 위치, 로그인 시 열기, Dock 표시, 메뉴 막대는 Mac마다 설정합니다.")))
    }

    // Closing the window keeps the app running; reopen from the Dock, ⌘0 or the menu bar icon.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        StartupWindow.userRequestedWindow()
        showWindow()
        // showWindow() already reopens the main window; avoid SwiftUI opening a second one.
        return false
    }
    func applicationWillTerminate(_ notification: Notification) {
        LibraryStore.shared.deactivateAllOnQuit()
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

    /// メニューバーのメニューの先頭：プロジェクトの一覧。選ぶとまとめてアクティブにする（すべてアクティブなら解除）
    static func projectMenuItems() -> [NSMenuItem] {
        let store = LibraryStore.shared
        guard !store.data.projects.isEmpty else { return [] }
        let header = NSMenuItem(title: L("プロジェクト"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        return [header] + store.data.projects.map { project in
            let state = store.projectState(project.id)
            let item = ClosureMenuItem(title: project.name) {
                if state == true { store.deactivateProject(project.id) } else { store.activateProject(project.id) }
            }
            item.state = state == true ? .on : state == nil ? .mixed : .off
            item.toolTip = state == true ? L("プロジェクトを解除") : L("プロジェクトをアクティブにする")
            return item
        }
    }
}

/// 選んだときにクロージャーを呼ぶメニュー項目（ターゲットは自分自身。メニューが項目を持っている間は生きている）
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func run() { handler() }
}
