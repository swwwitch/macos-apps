import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var settings = AppSettings()
    private var lastExportError: String?
    private var statusItem: NSStatusItem?
    private var pendingURLs: [URL] = []
    private var isProcessingExternalOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "QuickIconExporter")
        let menu = NSMenu()
        menu.addItem(withTitle: "ファイルを選択…", action: #selector(selectFiles), keyEquivalent: "o").target = self
        menu.addItem(withTitle: "ウインドウを表示", action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to: menu)
        #endif
        item.menu = menu
        statusItem = item
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showWindow()
        return true
    }
    @objc private func showWindow() {
        NSApp.windows.first(where: { !$0.isSheet })?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        guard !urls.isEmpty else { error.pointee = "ファイルを選択してください。"; return }
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
