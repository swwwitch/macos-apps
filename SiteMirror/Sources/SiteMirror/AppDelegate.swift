import AppKit
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        // Single main window: no tab items in the Window/View menus.
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        UNUserNotificationCenter.current().delegate = self
        startSettingsSync()
        DispatchQueue.main.async { [weak self] in
            MenuBarPresence.shared.install(name: "SiteMirror", symbol: "globe",
                show: { self?.showWindow() },
                settings: { self?.showSettings() },
                help: { LocalHelp.shared.show() })
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // The foreground window already shows the full result.
        completionHandler([])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            DispatchQueue.main.async { [weak self] in
                StartupWindow.userRequestedWindow()
                self?.showWindow()
            }
        }
        completionHandler()
    }
    /// 設定の共有：取り込みの設定（範囲・上限・同時接続数）を書き出し・同期する。保存先のフォルダーはMacごと
    private func startSettingsSync() {
        SettingsSync.shared.start(.init(
            keys: Mirror.syncedKeys,
            note: StartupWindow.text("取り込みの設定（取り込む範囲・上限・同時接続数）を同期します。",
                                     "Syncs the download settings (scope, limits and simultaneous connections).",
                                     "同步下载设置（范围、上限和同时连接数）。",
                                     "다운로드 설정(범위, 상한, 동시 연결 수)을 동기화합니다."),
            perMac: StartupWindow.text("保存先のフォルダー・ログイン時の起動・Dock表示・メニューバー・通知はMacごとに設定します。",
                                       "The destination folder, open at login, Dock visibility, menu bar and notifications are set on each Mac.",
                                       "保存位置、登录时打开、Dock 显示、菜单栏和通知在每台 Mac 上分别设置。",
                                       "저장 위치, 로그인 시 열기, Dock 표시, 메뉴 막대, 알림은 Mac마다 설정합니다.")))
    }

    // Closing the window keeps the app running; reopen from the Dock, ⌘0 or the menu bar icon.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        StartupWindow.userRequestedWindow()
        showWindow()
        // showWindow() already reopens the main window; avoid SwiftUI opening a second one.
        return false
    }
    /// 取り込み中は確かめてから中止し、保存したところまでリンクを書き換えてから終了する
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let mirror = Mirror.shared
        guard mirror.isRunning else { return .terminateNow }
        showWindow()
        let alert = NSAlert()
        alert.messageText = L("取り込み中です")
        alert.informativeText = L("中止して終了しますか？保存したところまではリンクを書き換えてから終了します。")
        alert.addButton(withTitle: L("中止して終了"))
        let cancel = alert.addButton(withTitle: L("キャンセル"))
        cancel.keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }
        guard mirror.isRunning else { return .terminateNow }
        mirror.onFinished = { NSApp.reply(toApplicationShouldTerminate: true) }
        mirror.cancel()
        return .terminateLater
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
