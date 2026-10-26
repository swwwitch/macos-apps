import AppKit
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var settings: AppSettings { .shared }
    private var lastExportError: String?
    private var statusItem: NSStatusItem?
    private var pendingURLs: [URL] = []
    private var isProcessingExternalOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        UNUserNotificationCenter.current().delegate = self
        defer { DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MenuBarPresence.shared.install(name: "QuickIconExporter", symbol: "square.and.arrow.up", existing: self.statusItem,
                show: { [weak self] in self?.showWindow() },
                settings: { [weak self] in self?.showSettings() },
                help: { [weak self] in LocalHelp.shared.show() })
        } }
        NSApp.setActivationPolicy(.accessory)
        // 「設定の共有」: file naming and after-export actions. The output folder, login and menu bar stay per Mac.
        SettingsSync.shared.onImport = { AppSettings.shared.reloadSharedSettings() }
        SettingsSync.shared.start(.init(
            keys: AppSettings.sharedKeys,
            note: StartupWindow.text("ファイル名の付け方と、書き出し後の動作を書き出し・同期します。",
                                     "Exports and syncs the file naming and what happens after export.",
                                     "导出并同步文件命名方式以及导出后的操作。",
                                     "파일 이름 규칙과 내보낸 뒤의 동작을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("保存先・ログイン時の起動・メニューバーはMacごとに設定します。",
                                       "The save location, login launch and the menu bar are set on each Mac.",
                                       "保存位置、登录时启动和菜单栏需在每台 Mac 上分别设置。",
                                       "저장 위치, 로그인 시 실행, 메뉴 막대는 Mac마다 설정합니다.")))
        WindowActivationPolicy.install()
        ExportShortcut.shared.action = { [weak self] in self?.performShortcut() }
        ExportShortcut.shared.restore()
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "QuickIconExporter")
        let menu = NSMenu()
        menu.addItem(withTitle: L("メインウインドウを開く"), action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(withTitle: L("ファイルを選択…"), action: #selector(selectFiles), keyEquivalent: "o").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L("設定…"), action: #selector(showSettings), keyEquivalent: "").target = self
        // The main menu (and its Help menu) is hidden for this menu bar app, so help lives here too,
        // grouped in a ヘルプ submenu (BASELINE「メニューの共通構成」).
        let helpMenu = NSMenu()
        helpMenu.addItem(withTitle: L("QuickIconExporterヘルプ"), action: #selector(LocalHelp.show), keyEquivalent: "").target = LocalHelp.shared
        HelpLinks.addNoteItem(to: helpMenu)
        let helpItem = menu.addItem(withTitle: L("ヘルプ"), action: nil, keyEquivalent: "")
        menu.setSubmenu(helpMenu, for: helpItem)
        menu.addItem(.separator())
        // Update items live in the app menu only (BASELINE「常駐メニューの例外」).
        // Quit stays last: nothing (not even a separator) goes below it.
        menu.addItem(withTitle: L("QuickIconExporterを終了"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        StartupWindow.userRequestedWindow()
        showWindow()
        // showWindow() already reopens the main window; avoid SwiftUI opening a second one.
        return false
    }
    /// Shows the main window, reopening the SwiftUI scene when it was closed (status menu, reopen, ⌘0).
    @objc func showWindow() {
        // Pick the main window explicitly, not Settings, Help or another utility window.
        if let window = MainWindow.current {
            if window.isMiniaturized { window.deminiaturize(nil) }
            MainWindow.keepOnScreen(window)
            window.makeKeyAndOrderFront(nil)
        } else {
            MainWindow.open?()
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    /// Opens the SwiftUI Settings scene (status menu and the shared menu bar presence).
    @objc func showSettings() { AppSwitcherWindowReveal.preserveAuxiliaryWindowOnActivation();
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    @objc private func selectFiles() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { application(NSApp, open: panel.urls) }
    }
    /// Files selected in the frontmost Finder / Path Finder are exported in place; otherwise the main window comes forward.
    private func performShortcut() {
        #if !APP_STORE_BUILD
        switch FileBrowserSelection.selectedFiles() {
        case .files(let urls) where !urls.isEmpty:
            application(NSApp, open: urls)
            return
        case .denied:
            showWindow()
            let alert = NSAlert()
            alert.messageText = L("FinderまたはPath Finderの選択を読み取れませんでした。")
            alert.informativeText = L("システム設定の「プライバシーとセキュリティ」＞「オートメーション」で、QuickIconExporterに許可してください。")
            alert.runModal()
            return
        default:
            break
        }
        #endif
        showWindow()
    }
    @objc func exportIcons(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        var urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if urls.isEmpty, let paths = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls = paths.map { URL(fileURLWithPath: $0) }
        }
        guard !urls.isEmpty else { error.pointee = L("ファイルを選択してください。") as NSString; return }
        application(NSApp, open: urls)
        if let message = lastExportError { error.pointee = message as NSString }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        StartupWindow.userRequestedWindow()
        pendingURLs.append(contentsOf: urls)
        application.reply(toOpenOrPrint: .success)
        processPendingURLs(in: application)
    }

    private func processPendingURLs(in application: NSApplication) {
        guard !isProcessingExternalOpen, !pendingURLs.isEmpty else { return }
        isProcessingExternalOpen = true

        // FinderやDockのアプリアイコンへのドロップでは、通常のメイン画面を見せない。
        application.windows.forEach { $0.orderOut(nil) }

        let urls = pendingURLs
        pendingURLs.removeAll()
        lastExportError = nil
        settings.externalExportError = nil
        guard settings.prepareOutputDirectory() else {
            lastExportError = L("保存先の選択をキャンセルしました。")
            settings.externalExportError = lastExportError
            isProcessingExternalOpen = false
            if !pendingURLs.isEmpty { processPendingURLs(in: application) }
            return
        }
        let rules = settings.filenameRules
        var results: [ExportResult] = []

        for url in urls {
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing { url.stopAccessingSecurityScopedResource() }
            }

            do {
                results.append(
                    try IconExporter.exportIcon(
                        for: url,
                        to: settings.outputDirectory,
                        rules: rules
                    )
                )
            } catch {
                lastExportError = error.localizedDescription
                NSLog("QuickIconExporter: %@", error.localizedDescription)
            }
        }

        if !results.isEmpty {
            settings.reportSuccessfulExport(results)
        }

        settings.externalExportError = lastExportError
        isProcessingExternalOpen = false
        if !pendingURLs.isEmpty { processPendingURLs(in: application) }
    }
}

// Keep completion notifications visible while the app is foreground; clicking reopens its result window.
extension AppDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in self.showWindow() }
        completionHandler()
    }
}
