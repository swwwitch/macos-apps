import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Single main window: no tab items in the Window/View menus.
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        FormatAction.installHiddenKeys()
        startSettingsSync()
        DispatchQueue.main.async { [weak self] in
            MenuBarPresence.shared.install(name: "MarkdownKitchen", symbol: "number",
                show: { self?.showWindow() },
                settings: { self?.showSettings() },
                help: { LocalHelp.shared.show() })
        }
    }
    /// 設定の共有で読み込んだ・同期した後に、設定画面の一覧を作り直す
    static let settingsImported = Notification.Name("MarkdownKitchenSettingsImported")

    /// 設定の共有：原稿の表示・コピー形式・ホットキー・HTML→Markdown・テーマ・右クリックの設定を書き出し・同期する。
    /// 原稿（sourceText）・開いているファイル（filePath・fileEdited）は書類の状態なので含めない
    private func startSettingsSync() {
        let keys: Set<String> = [
            MarkdownStore.levelsKey, MarkdownStore.copyFormatKey, MarkdownStore.boldHeadingsKey, MarkdownStore.colorizeKey,
            MarkdownStore.editorStyleKey, MarkdownStore.editorAppearanceKey, MarkdownStore.marginKey, MarkdownStore.editorFontKey,
            MarkdownStore.lineSpacingKey, MarkdownStore.fontSizeKey, MarkdownStore.skipDivsKey, MarkdownStore.skipTablesKey,
            ShortcutStore.key, FormatAction.contextHiddenKey, DoorkeeperPresets.key, DoorkeeperPresets.selectedKey,
            LineTools.DivBox.backgroundKey, LineTools.DivBox.paddingKey, LineTools.DivBox.radiusKey, LineTools.DivBox.marginKey,
            "markdownKitchen.rewriteTarget",
        ]
        SettingsSync.shared.onImport = {
            ShortcutStore.shared.reload()
            DoorkeeperPresets.shared.reload()
            NotificationCenter.default.post(name: AppDelegate.settingsImported, object: nil)
        }
        SettingsSync.shared.start(.init(
            keys: keys,
            note: StartupWindow.text("原稿の表示・見出しのコピー形式・ホットキー・HTML→Markdown・テーマ・右クリックの設定を書き出し・同期します。",
                                     "Exports and syncs the editor display, heading copy format, hotkeys, HTML→Markdown, themes and right-click settings.",
                                     "导出并同步原稿显示、标题复制格式、快捷键、HTML→Markdown、主题和右键菜单的设置。",
                                     "원고 표시, 제목 복사 형식, 단축키, HTML→Markdown, 테마, 오른쪽 클릭 설정을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("原稿と開いているファイル、ログイン時の起動・起動時の表示・メニューバーはMacごとに残ります。",
                                       "The source text, the open file, open at login, the startup window and the menu bar stay on each Mac.",
                                       "原稿和打开的文件、登录时打开、启动时的窗口和菜单栏在每台 Mac 上分别保留。",
                                       "원고와 열려 있는 파일, 로그인 시 열기, 시작 시 윈도우, 메뉴 막대는 Mac마다 남습니다."),
            merge: DoorkeeperPresets.merge))
    }

    // Closing the window keeps the app running; reopen from the Dock, ⌘0 or the menu bar icon.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    /// Follows 「アプリケーションを終了するときにウインドウを閉じる」: when off, windows keep their source and open again at the next launch.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MarkdownStore.prepareToQuit() ? .terminateNow : .terminateCancel
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showWindow()
        // showWindow() already reopens the main window; avoid SwiftUI opening a second one.
        return false
    }
    /// Markdown files dropped on the Dock icon or opened with "Open With" go to a blank window or a new window.
    func application(_ application: NSApplication, open urls: [URL]) {
        MarkdownStore.open(urls, from: MarkdownStore.shared)
        application.reply(toOpenOrPrint: .success)
    }
    @objc func showWindow() { MainWindow.show() }
    @objc func showSettings() { SettingsWindow.shared.show() }
}
