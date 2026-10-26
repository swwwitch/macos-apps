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
    var onWatchChange: (() -> Void)?

    // Screenshots
    @Published var shotEnabled = UserDefaults.standard.object(forKey: "shotEnabled") as? Bool ?? true { didSet { defaults.set(shotEnabled, forKey: "shotEnabled"); onWatchChange?() } }
    @Published var shotFolders = WatchFolders.migrate(UserDefaults.standard) { didSet {
        defaults.set(shotFolders, forKey: "shotFolders"); onWatchChange?()
    } }
    @Published var nameTemplate = UserDefaults.standard.string(forKey: "nameTemplate") ?? ShotNaming.defaultTemplate { didSet { defaults.set(nameTemplate, forKey: "nameTemplate") } }
    @Published var ocrComment = UserDefaults.standard.object(forKey: "ocrComment") as? Bool ?? true { didSet { defaults.set(ocrComment, forKey: "ocrComment") } }
    @Published var ocrClipboard = UserDefaults.standard.object(forKey: "ocrClipboard") as? Bool ?? true { didSet { defaults.set(ocrClipboard, forKey: "ocrClipboard") } }
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
        if notify { NotificationPreferences.shared.post(title: "ShotSorter", body: text, enabledKey: "notify", enabledDefault: false) }
    }

    /// Keys shared by 設定の共有. The folder, startup, residency and hotkeys stay per Mac.
    nonisolated static let sharedKeys: Set<String> = ["nameTemplate", "ocrComment", "ocrClipboard", "joinJapanese", "fullwidthParens", "showOCRPanel"]
    func reloadSharedSettings() {
        nameTemplate = defaults.string(forKey: "nameTemplate") ?? ShotNaming.defaultTemplate
        ocrComment = bool("ocrComment", true); ocrClipboard = bool("ocrClipboard", true)
        joinJapanese = bool("joinJapanese", true); fullwidthParens = bool("fullwidthParens", true); showOCRPanel = bool("showOCRPanel", true)
    }
    static var screenshotLocation: String {
        let saved = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        let path = (saved.map { ($0 as NSString).expandingTildeInPath }) ?? (NSHomeDirectory() + "/Desktop")
        return path
    }
    // Hotkeys (per Mac): 1 shows the main window (⌃⌥S), 2 recognizes text in a selected area (⌘⇧1).
    static let defaultAppCombo = KeyCombo(code: UInt32(kVK_ANSI_S), modifiers: KeyCombo.control | KeyCombo.option)
    static let defaultOCRCombo = KeyCombo(code: UInt32(kVK_ANSI_1), modifiers: KeyCombo.command | KeyCombo.shift)
    static let appHotkeyFieldID = "appHotkey", ocrHotkeyFieldID = "ocrHotkey"
    private static func combo(_ key: String, _ fallback: KeyCombo) -> KeyCombo? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return fallback }
        guard !data.isEmpty, let saved = try? JSONDecoder().decode(KeyCombo.self, from: data) else { return nil }
        if key == "ocrHotkey", saved == KeyCombo(code: UInt32(kVK_ANSI_O), modifiers: KeyCombo.control | KeyCombo.option) {
            return defaultOCRCombo
        }
        return saved
    }
    private func store(_ combo: KeyCombo?, _ key: String) { defaults.set(combo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: key) }
    @Published var appHotkeyEnabled = UserDefaults.standard.object(forKey: "appHotkeyEnabled") as? Bool ?? true { didSet { defaults.set(appHotkeyEnabled, forKey: "appHotkeyEnabled"); registerHotkeys() } }
    @Published var appCombo: KeyCombo? = Model.combo("appHotkey", Model.defaultAppCombo) { didSet { store(appCombo, "appHotkey"); registerHotkeys() } }
    @Published var ocrHotkeyEnabled = UserDefaults.standard.object(forKey: "ocrHotkeyEnabled") as? Bool ?? true { didSet { defaults.set(ocrHotkeyEnabled, forKey: "ocrHotkeyEnabled"); registerHotkeys() } }
    @Published var ocrCombo: KeyCombo? = Model.combo("ocrHotkey", Model.defaultOCRCombo) { didSet { store(ocrCombo, "ocrHotkey"); registerHotkeys() } }
    @Published var appHotkeyRegistered = true
    @Published var ocrHotkeyRegistered = true
    let hotkeys = HotkeySet(signature: "ShSo")
    func registerHotkeys() {
        hotkeys.unregisterAll()
        appHotkeyRegistered = true; ocrHotkeyRegistered = true
        if appHotkeyEnabled, let appCombo { appHotkeyRegistered = hotkeys.register(1, appCombo) == noErr }
        if ocrHotkeyEnabled, let ocrCombo { ocrHotkeyRegistered = hotkeys.register(2, ocrCombo) == noErr }
    }
}

/// Watches the screenshot folder and renames new screenshots; recognizes text in a selected area.
@MainActor final class Engine {
    let model: Model
    let notice = NoticePanel()
    private var watchers: [String: FolderWatcher] = [:]
    /// Names this app produced, so a rename is not taken for a new screenshot.
    private var produced: Set<String> = []
    private var processing: Set<String> = []
    init(model: Model) { self.model = model }

    func refreshWatchers() {
        var wanted: Set<String> = []
        if model.shotEnabled { wanted = Set(model.shotFolders.map { WatchFolders.canonical($0) }) }
        for (path, watcher) in watchers where !wanted.contains(path) { watcher.stop(); watchers[path] = nil }
        for path in wanted where watchers[path] == nil {
            if let watcher = FolderWatcher(url: URL(fileURLWithPath: path), onNew: { [weak self] url in self?.handle(url) }) {
                watchers[path] = watcher
            } else {
                model.log("exclamationmark.triangle", String(format: L("log.cannotWatch"), path), error: true)
            }
        }
    }
    func stop() { for watcher in watchers.values { watcher.stop() }; watchers = [:]; notice.close() }

    private func handle(_ url: URL) {
        let name = url.lastPathComponent, folder = url.deletingLastPathComponent().path
        if produced.remove(url.path) != nil { return }
        if model.shotEnabled, model.shotFolders.contains(where: { WatchFolders.canonical($0) == WatchFolders.canonical(folder) }), ShotNaming.isCandidate(name) { processShot(url) }
    }

    func dropFiles(_ urls: [URL]) {
        for url in urls { processShot(url.standardizedFileURL.resolvingSymlinksInPath()) }
    }

    private func processShot(_ url: URL) {
        guard url.pathExtension.lowercased() == "png", !processing.contains(url.path) else { return }

        guard let info = ImageReader.info(url) else { model.log("exclamationmark.triangle", String(format: L("log.notImage"), url.lastPathComponent), error: true); return }
        processing.insert(url.path)
        let date = Date(), needsText = model.ocrComment || model.ocrClipboard
        Task.detached(priority: .utility) {
            let text = needsText ? ((ImageReader.cgImage(url)).flatMap { try? TextRecognizer.recognize($0) } ?? "") : ""
            await MainActor.run { self.finishShot(url, info: info, date: date, text: text) }
        }
    }
    private func finishShot(_ url: URL, info: ImageInfo, date: Date, text: String) {
        defer { processing.remove(url.path) }
        guard FileManager.default.fileExists(atPath: url.path) else { return }  // Moved or renamed by someone else meanwhile.
        let text = OCRText.clean(text, join: model.joinJapanese, parens: model.fullwidthParens)
        let name = ShotNaming.name(template: model.nameTemplate, info: info, date: date)
        let target = ShotNaming.unique(name, in: url.deletingLastPathComponent())
        do {
            if watchers[WatchFolders.canonical(target.deletingLastPathComponent().path)] != nil { produced.insert(target.path) }
            try FileManager.default.moveItem(at: url, to: target)
        } catch {
            produced.remove(target.path)
            model.log("exclamationmark.triangle", String(format: L("log.renameFailed"), url.lastPathComponent, error.localizedDescription), error: true); return
        }
        var message = String(format: L("log.renamed"), target.lastPathComponent)
        if model.ocrComment && !text.isEmpty {
            switch FinderComment.set(text, for: target) {
            case .finder: break
            case .spotlightOnly: message += L("log.commentSpotlight")
            case .failed: message += L("log.commentFailed")
            }
        }
        if !text.isEmpty {
            model.lastOCR = text
            if model.ocrClipboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }
        model.log("camera.viewfinder", message)
    }

    /// ⌘⇧1: select an area, recognize its text and copy it.
    func recognizeArea() {
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
            let raw = ImageReader.cgImage(file).flatMap { try? TextRecognizer.recognize($0) } ?? ""
            let text = OCRText.clean(raw, join: join, parens: parens)
            await MainActor.run { self.finishOCR(text) }
        }
    }
    private func finishOCR(_ text: String) {
        model.recognizing = false
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

@MainActor final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Model()
    lazy var engine = Engine(model: model)
    var window: NSWindow!
    var settings: NSWindow?
    var helpWindow: NSWindow?
    var isDuplicate = false

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
        buildMenus()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 640), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "ShotSorter"; window.titleVisibility = .hidden
        let host = GrowingHostingView(rootView: MainView(model: model, dropFiles: { [weak self] in self?.engine.dropFiles($0) }, recognize: { [weak self] in self?.engine.recognizeArea() }))
        host.sizingOptions = [.minSize]
        window.contentView = host
        window.delegate = self; window.isReleasedWhenClosed = false
        if UserDefaults.standard.string(forKey: "NSWindow Frame MainWindow") == nil { window.center() }  // First launch: no saved frame yet.
        window.setFrameAutosaveName("MainWindow"); window.minSize = NSSize(width: 580, height: 560)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        model.hotkeys.action = { [weak self] number in
            if number == 2 { self?.engine.recognizeArea() } else { StartupWindow.userRequestedWindow(); self?.show() }
        }
        model.registerHotkeys()
        model.onWatchChange = { [weak self] in self?.engine.refreshWatchers() }
        engine.refreshWatchers()
        MenuBarPresence.shared.install(name: "ShotSorter", symbol: "camera.viewfinder", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() },
                                       extraItems: { [weak self] in self?.statusItems() ?? [] })
        SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings() }
        SettingsSync.shared.start(.init(keys: Model.sharedKeys, prefixes: [],
            note: StartupWindow.text("名前の形式、文字認識とFinderのコメントの整形ルールを書き出し・同期します。",
                                     "Exports and syncs the name format and the text recognition, Finder comment and formatting choices.",
                                     "导出并同步名称格式，以及文字识别、访达注释和文本格式设置。",
                                     "이름 형식과 문자 인식, Finder 메모, 텍스트 서식 설정을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("スクリーンショットのフォルダー・ログイン時の起動・常駐・ホットキー・通知はMacごとに設定します。",
                                       "The screenshot folder, open at login, keep running, hotkeys and notifications are set on each Mac.",
                                       "截图文件夹、登录时启动、保持运行、快捷键和通知在每台 Mac 上分别设置。",
                                       "스크린샷 폴더, 로그인 시 실행, 계속 실행, 단축키, 알림은 Mac마다 설정합니다.")))
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !login && !StartupWindow.suppressInitialWindow { show() }
    }
    func applicationWillTerminate(_ notification: Notification) { engine.stop() }

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
    @objc func quit() { NSApp.terminate(nil) }
    @objc func showSettings() {
        if settings == nil {
            settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 600), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            let hosting = NSHostingView(rootView: SettingsView(model: model)); hosting.sizingOptions = [.minSize]
            settings!.title = L("settingsWindow"); settings!.contentView = hosting; settings!.contentMinSize = NSSize(width: 560, height: 600); settings!.isReleasedWhenClosed = false; settings!.center()
        }
        settings!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let text = Bundle.main.url(forResource: "Help", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? L("help")
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "ShotSorter")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "ShotSorter", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
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
app.setActivationPolicy(.regular)
MainActor.assumeIsolated {
    let delegate = Delegate(); app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
