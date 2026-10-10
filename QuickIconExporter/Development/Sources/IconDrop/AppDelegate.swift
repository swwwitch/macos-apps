import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: AppSettings { .shared }
    private var lastExportError: String?
    private var statusItem: NSStatusItem?
    private var pendingURLs: [URL] = []
    private var isProcessingExternalOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        defer { DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MenuBarPresence.shared.install(name: "QuickIconExporter", symbol: "square.and.arrow.up", existing: self.statusItem,
                show: { [weak self] in self?.showWindow() },
                settings: { [weak self] in self?.showSettings() },
                help: { [weak self] in LocalHelp.shared.show() })
        } }
        NSApp.setActivationPolicy(.accessory)
        WindowActivationPolicy.install()
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
    @objc func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    @objc private func selectFiles() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { application(NSApp, open: panel.urls) }
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

        isProcessingExternalOpen = false
        if !pendingURLs.isEmpty { processPendingURLs(in: application) }
    }
}
