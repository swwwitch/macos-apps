import UniformTypeIdentifiers
import AppKit
import SwiftUI
import Carbon

struct Activity: Identifiable {
    let id = UUID()
    let date = Date()
    let symbol: String
    let text: String
    var isError = false
}

@MainActor final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    private func bool(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }

    // Text recognition
    @Published var joinJapanese = UserDefaults.standard.object(forKey: "joinJapanese") as? Bool ?? true { didSet { defaults.set(joinJapanese, forKey: "joinJapanese") } }
    @Published var fullwidthParens = UserDefaults.standard.object(forKey: "fullwidthParens") as? Bool ?? true { didSet { defaults.set(fullwidthParens, forKey: "fullwidthParens") } }
    @Published var showOCRPanel = UserDefaults.standard.object(forKey: "showOCRPanel") as? Bool ?? true { didSet { defaults.set(showOCRPanel, forKey: "showOCRPanel") } }
    @Published var lastOCR = ""
    @Published var recognizing = false
    // Notifications (B32: off until the user turns them on)
    @Published var notify = UserDefaults.standard.bool(forKey: "notify") { didSet { defaults.set(notify, forKey: "notify") } }

    @Published var activity: [Activity] = []
    func log(_ symbol: String, _ text: String, error: Bool = false) {
        activity.insert(Activity(symbol: symbol, text: text, isError: error), at: 0)
        if activity.count > 50 { activity.removeLast(activity.count - 50) }
        if notify { NotificationPreferences.shared.post(title: "TextLens", body: text, enabledKey: "notify", enabledDefault: false) }
    }

    /// Keys shared by 設定の共有. The folder, startup, residency and hotkeys stay per Mac.
    nonisolated static let sharedKeys: Set<String> = ["joinJapanese", "fullwidthParens", "showOCRPanel"]
    func reloadSharedSettings() {
        joinJapanese = bool("joinJapanese", true); fullwidthParens = bool("fullwidthParens", true); showOCRPanel = bool("showOCRPanel", true)
    }
    // Recognition hotkey stays per Mac. Legacy app-call preferences are retained but unused.
    static let defaultOCRCombo = KeyCombo(code: UInt32(kVK_ANSI_1), modifiers: KeyCombo.command | KeyCombo.shift)
    static let ocrHotkeyFieldID = "ocrHotkey"
    private static func combo(_ key: String, _ fallback: KeyCombo) -> KeyCombo? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return fallback }
        guard !data.isEmpty, let saved = try? JSONDecoder().decode(KeyCombo.self, from: data) else { return nil }
        if key == "ocrHotkey", saved == KeyCombo(code: UInt32(kVK_ANSI_O), modifiers: KeyCombo.control | KeyCombo.option) {
            return defaultOCRCombo
        }
        return saved
    }
    private func store(_ combo: KeyCombo?, _ key: String) { defaults.set(combo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: key) }
    @Published var ocrHotkeyEnabled = UserDefaults.standard.object(forKey: "ocrHotkeyEnabled") as? Bool ?? true { didSet { defaults.set(ocrHotkeyEnabled, forKey: "ocrHotkeyEnabled"); registerHotkeys() } }
    @Published var ocrCombo: KeyCombo? = Model.combo("ocrHotkey", Model.defaultOCRCombo) { didSet { store(ocrCombo, "ocrHotkey"); registerHotkeys() } }
    @Published var ocrHotkeyRegistered = true
    let hotkeys = HotkeySet(signature: "TxLn")
    func registerHotkeys() {
        hotkeys.unregisterAll()
        ocrHotkeyRegistered = true
        if !ExcludedApps.shared.excludes(NSWorkspace.shared.frontmostApplication?.bundleIdentifier), ocrHotkeyEnabled, let ocrCombo { ocrHotkeyRegistered = hotkeys.register(2, ocrCombo) == noErr }
    }
}

/// Recognizes screen areas and image files without altering originals.
@MainActor final class Engine {
    let model: Model
    let notice = NoticePanel()
    init(model: Model) { self.model = model }
    func stop() { notice.close() }
    func dropFiles(_ urls: [URL]) {
        guard !model.recognizing, let url = urls.first else { return }
        model.recognizing = true
        let join = model.joinJapanese, parens = model.fullwidthParens
        Task.detached(priority: .userInitiated) {
            do {
                guard let image = ImageReader.cgImage(url) else { throw CocoaError(.fileReadCorruptFile) }
                let text = OCRText.clean(try TextRecognizer.recognize(image), join: join, parens: parens)
                await MainActor.run { self.finishOCR(text) }
            } catch {
                await MainActor.run { self.model.recognizing = false; self.model.log("exclamationmark.triangle", error.localizedDescription, error: true) }
            }
        }
    }

    /// ⌘⇧1: select an area, recognize its text and copy it.
    func recognizeArea() {
        guard !ExcludedApps.shared.excludes(NSWorkspace.shared.frontmostApplication?.bundleIdentifier) else { return }
        guard !model.recognizing else { return }
        guard AreaCapture.allowed else {
            notice.show(seconds: 12) {
                TextNotice(title: L("ocr.needsPermission"), symbol: "lock", text: L("ocr.needsPermissionDetail"), isError: true,
                           action: (L("ocr.allow"), { [weak self] in self?.notice.close(); CGRequestScreenCaptureAccess(); SystemSettings.openScreenRecording() }))
            }
            model.log("lock", L("ocr.needsPermission"), error: true)
            return
        }
        model.recognizing = true
        let join = model.joinJapanese, parens = model.fullwidthParens
        Task.detached(priority: .userInitiated) {
            guard let file = AreaCapture.capture() else { await MainActor.run { self.model.recognizing = false }; return }
            defer { try? FileManager.default.removeItem(at: file) }
            do {
                guard let image = ImageReader.cgImage(file) else { throw CocoaError(.fileReadCorruptFile) }
                let text = OCRText.clean(try TextRecognizer.recognize(image), join: join, parens: parens)
                await MainActor.run { self.finishOCR(text) }
            } catch {
                await MainActor.run { self.model.recognizing = false; self.model.log("exclamationmark.triangle", error.localizedDescription, error: true) }
            }
        }
    }
    private func finishOCR(_ text: String) {
        model.recognizing = false
        guard !ExcludedApps.shared.excludes(NSWorkspace.shared.frontmostApplication?.bundleIdentifier) else { return }
        guard !text.isEmpty else {
            if model.showOCRPanel { notice.show(seconds: 4) { TextNotice(title: L("ocr.none"), symbol: "text.viewfinder", text: "") } }
            model.log("text.viewfinder", L("ocr.none")); return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        model.lastOCR = text
        if model.showOCRPanel { notice.show(seconds: 6) { TextNotice(title: L("ocr.copied"), symbol: "text.viewfinder", text: text) } }
        model.log("text.viewfinder", String(format: L("log.ocr"), text.count))
    }
}

enum SystemSettings {
    static func openScreenRecording() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
}

/// Grows its window when the content needs more room; never shrinks it.
final class GrowingHostingView<Content: View>: NSHostingView<Content> {
    override func layout() {
        super.layout()
        guard let window else { return }
        let needed = fittingSize, current = window.contentLayoutRect.size
        guard needed.height > current.height + 0.5 || needed.width > current.width + 0.5 else { return }
        DispatchQueue.main.async {
            window.setContentSize(NSSize(width: max(current.width, needed.width), height: max(current.height, needed.height)))
        }
    }
}

@MainActor final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    let model = Model()
    lazy var engine = Engine(model: model)
    var window: NSWindow!
    var settings: NSWindow?
    var helpWindow: NSWindow?
    var isDuplicate = false
    var workspaceObserver: NSObjectProtocol?

    func applicationWillFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        UserDefaults.standard.register(defaults: ["resident": true])
        if let id = Bundle.main.bundleIdentifier, let other = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            isDuplicate = true
            other.activate(options: [.activateAllWindows])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        guard !isDuplicate else { return }
        if !UserDefaults.standard.bool(forKey: "importedShotSorterOCR") {
            let old = UserDefaults(suiteName: "jp.dtp-transit.shotsorter")
            for key in Model.sharedKeys where UserDefaults.standard.object(forKey: key) == nil {
                if let value = old?.object(forKey: key) { UserDefaults.standard.set(value, forKey: key) }
            }
            UserDefaults.standard.set(true, forKey: "importedShotSorterOCR")
            model.reloadSharedSettings()
        }
        buildMenus()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 640), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "TextLens"; window.titleVisibility = .hidden
        let host = GrowingHostingView(rootView: MainView(model: model, dropFiles: { [weak self] in self?.engine.dropFiles($0) }, recognize: { [weak self] in self?.engine.recognizeArea() }))
        host.sizingOptions = [.minSize]
        window.contentView = host
        window.delegate = self; window.isReleasedWhenClosed = false
        if UserDefaults.standard.string(forKey: "NSWindow Frame MainWindow") == nil { window.center() }  // First launch: no saved frame yet.
        window.setFrameAutosaveName("MainWindow"); window.minSize = NSSize(width: 580, height: 560)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        model.hotkeys.action = { [weak self] number in
            if number == 2 { self?.engine.recognizeArea() }
        }
        model.registerHotkeys()
        ExcludedApps.shared.configure(explanation: L("excluded.detail"))
        ExcludedApps.shared.onChange = { [weak self] in self?.model.registerHotkeys() }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.registerHotkeys() }
        }
        DockPresence.apply()
        MenuBarPresence.shared.install(name: "TextLens", symbol: "text.viewfinder", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() },
                                       extraItems: { [weak self] in self?.statusItems() ?? [] })
        SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings() }
        SettingsSync.shared.start(.init(keys: Model.sharedKeys, prefixes: [],
            note: L("sharing.detail"), perMac: L("sharing.perMac")))
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !login && !StartupWindow.suppressInitialWindow { show() }
    }
    func applicationWillTerminate(_ notification: Notification) { engine.stop() }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.action != #selector(recognize) || !model.recognizing
    }
    func statusItems() -> [NSMenuItem] {
        let item = NSMenuItem(title: L("recognizeMenu"), action: #selector(recognize), keyEquivalent: "")
        item.target = self
        return [item]
    }
    @objc func recognize() { engine.recognizeArea() }

    @objc func show() { guard let window else { return }; NSApp.activate(ignoringOtherApps: true); if window.isMiniaturized { window.deminiaturize(nil) }; window.makeKeyAndOrderFront(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        StartupWindow.userRequestedWindow(); show(); return true }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === window && !UserDefaults.standard.bool(forKey: "resident") { NSApp.terminate(nil); return false }
        return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model.recognizing {
            model.log("exclamationmark.triangle", L("busy.quit"), error: true)
            show()
            return .terminateCancel
        }
        return .terminateNow
    }
    @objc func quit() { NSApp.terminate(nil) }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        StartupWindow.userRequestedWindow(); show()
        engine.dropFiles(filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
    }
    @objc func showSettings() {
        if settings == nil {
            settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 600), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            let hosting = NSHostingView(rootView: SettingsView(model: model)); hosting.sizingOptions = [.minSize]
            settings!.title = L("settingsWindow"); settings!.contentView = hosting; settings!.contentMinSize = NSSize(width: 560, height: 600); settings!.isReleasedWhenClosed = false; settings!.center()
        }
        StartupWindow.userRequestedWindow()
        settings!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let text = Bundle.main.url(forResource: "Help", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? L("help")
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "TextLens")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "TextLens", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) { menu.addItem(withTitle: title, action: action, keyEquivalent: key).target = self }
    func buildMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        let app = NSMenu(); let root = NSMenuItem(); root.submenu = app; bar.addItem(root)
        add(app, L("about"), #selector(about), ""); app.addItem(.separator())
        add(app, L("settings"), #selector(showSettings), ","); app.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to: app)   // 「アップデートを確認…」「アップデートを自動確認」 + separator
        #endif
        let services = NSMenu(title: L("services")); app.addItem(withTitle: L("services"), action: nil, keyEquivalent: "").submenu = services; NSApp.servicesMenu = services
        app.addItem(.separator())
        app.addItem(withTitle: L("hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: L("hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: L("showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator()); add(app, L("quit"), #selector(quit), "q")
        let file = NSMenu(title: L("fileMenu")); let fileItem = NSMenuItem(title: L("fileMenu"), action: nil, keyEquivalent: ""); fileItem.submenu = file; bar.addItem(fileItem)
        add(file, L("openMainWindow"), #selector(show), "0"); file.addItem(.separator())
        add(file, L("recognizeMenu"), #selector(recognize), "")
        file.addItem(.separator())
        file.addItem(withTitle: L("close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let edit = NSMenu(title: L("editMenu")); let editItem = NSMenuItem(title: L("editMenu"), action: nil, keyEquivalent: ""); editItem.submenu = edit; bar.addItem(editItem)
        for (key, action, shortcut) in [("undo", "undo:", "z"), ("redo", "redo:", "z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("paste", "paste:", "v"), ("selectAll", "selectAll:", "a")] {
            edit.addItem(withTitle: L(key), action: Selector(action), keyEquivalent: shortcut)
        }
        edit.item(at: 1)?.keyEquivalentModifierMask = [.command, .shift]   // やり直す ⇧⌘Z
        let windowMenu = NSMenu(title: L("windowMenu")); let windowItem = NSMenuItem(title: L("windowMenu"), action: nil, keyEquivalent: ""); windowItem.submenu = windowMenu; bar.addItem(windowItem)
        windowMenu.addItem(withTitle: L("minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: L("zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: L("bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
        let help = NSMenu(title: L("helpMenu")); let helpItem = NSMenuItem(title: L("helpMenu"), action: nil, keyEquivalent: ""); helpItem.submenu = help; bar.addItem(helpItem)
        add(help, L("help"), #selector(showHelp), "?"); HelpLinks.addNoteItem(to: help); NSApp.helpMenu = help
    }
}

let app = NSApplication.shared
DockPresence.apply()
MainActor.assumeIsolated {
    let delegate = Delegate(); app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
