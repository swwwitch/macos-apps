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
    var onWatchChange: (() -> Void)?
    @Published var sortEnabled = UserDefaults.standard.object(forKey: "sortEnabled") as? Bool ?? true { didSet { defaults.set(sortEnabled, forKey: "sortEnabled"); onWatchChange?() } }
    @Published var rules: [SortRule] = Model.loadRules() { didSet { if let data = try? JSONEncoder().encode(rules) { defaults.set(data, forKey: "rules") }; onWatchChange?() } }
    @Published var shotEnabled = UserDefaults.standard.bool(forKey: "shotEnabled") { didSet { defaults.set(shotEnabled, forKey: "shotEnabled"); onWatchChange?() } }
    @Published var shotFolders = WatchFolders.migrate(UserDefaults.standard) { didSet { defaults.set(shotFolders, forKey: "shotFolders"); onWatchChange?() } }
    @Published var nameTemplate = UserDefaults.standard.string(forKey: "nameTemplate") ?? ShotNaming.defaultTemplate { didSet { defaults.set(nameTemplate, forKey: "nameTemplate") } }
    static var screenshotLocation: String { WatchFolders.migrate(UserDefaults.standard).first ?? NSHomeDirectory() + "/Desktop" }
    // Notifications (B32: off until the user turns them on)
    @Published var notify = UserDefaults.standard.bool(forKey: "notify") { didSet { defaults.set(notify, forKey: "notify") } }
    @Published var activity: [Activity] = []

    func log(_ symbol: String, _ text: String, error: Bool = false) {
        activity.insert(Activity(symbol: symbol, text: text, isError: error), at: 0)
        if activity.count > 50 { activity.removeLast(activity.count - 50) }
        if notify { NotificationPreferences.shared.post(title: "FileSorter", body: text, enabledKey: "notify", enabledDefault: false) }
    }
    private static func loadRules() -> [SortRule] {
        guard let data = UserDefaults.standard.data(forKey: "rules") else { return SortRule.defaults }
        return (try? JSONDecoder().decode([SortRule].self, from: data)) ?? SortRule.defaults
    }
    func save(_ rule: SortRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) { rules[index] = rule } else { rules.append(rule) }
    }

    /// Hotkey that shows the main window while the app is running (per Mac). Default ⌃⌥F.
    static let defaultAppCombo = KeyCombo(code: UInt32(kVK_ANSI_F), modifiers: KeyCombo.control | KeyCombo.option)
    static let appHotkeyFieldID = "appHotkey"
    @Published var appHotkeyEnabled = UserDefaults.standard.object(forKey: "appHotkeyEnabled") as? Bool ?? true { didSet { defaults.set(appHotkeyEnabled, forKey: "appHotkeyEnabled"); registerAppHotkey() } }
    @Published var appCombo: KeyCombo? = {
        guard let data = UserDefaults.standard.data(forKey: "appHotkey") else { return Model.defaultAppCombo }
        return data.isEmpty ? nil : try? JSONDecoder().decode(KeyCombo.self, from: data)
    }() { didSet { defaults.set(appCombo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "appHotkey"); registerAppHotkey() } }
    @Published var appHotkeyRegistered = true
    let hotkeys = HotkeySet(signature: "FlSr")
    func registerAppHotkey() {
        hotkeys.unregisterAll()
        guard appHotkeyEnabled, let appCombo else { appHotkeyRegistered = true; return }
        appHotkeyRegistered = hotkeys.register(1, appCombo) == noErr
    }
}

/// Watches the rules' folders and moves added files that match.
@MainActor final class Engine {
    let model: Model
    private var watchers: [String: FolderWatcher] = [:]
    private var produced: Set<String> = []
    init(model: Model) { self.model = model }

    func refreshWatchers() {
        var wanted = model.sortEnabled ? Set(model.rules.filter(\.enabled).map { WatchFolders.canonical($0.folder) }) : []
        if model.shotEnabled { wanted.formUnion(model.shotFolders.map(WatchFolders.canonical)) }
        for (path, watcher) in watchers where !wanted.contains(path) { watcher.stop(); watchers[path] = nil }
        for path in wanted where watchers[path] == nil {
            if let watcher = FolderWatcher(url: URL(fileURLWithPath: path), onNew: { [weak self] url in self?.handle(url) }) {
                watchers[path] = watcher
            } else {
                model.log("exclamationmark.triangle", String(format: L("log.cannotWatch"), path), error: true)
            }
        }
    }
    func stop() { for watcher in watchers.values { watcher.stop() }; watchers = [:] }

    /// The first enabled rule for this folder whose condition matches.
    func rule(for url: URL) -> SortRule? {
        let folder = url.deletingLastPathComponent().path
        return model.rules.first { WatchFolders.canonical($0.folder) == WatchFolders.canonical(folder) && $0.matches(url.lastPathComponent) }
    }
    private func handle(_ url: URL) {
        if produced.remove(url.path) != nil { return }
        var file = url
        if model.shotEnabled, model.shotFolders.map(WatchFolders.canonical).contains(WatchFolders.canonical(url.deletingLastPathComponent().path)), ShotNaming.isCandidate(url.lastPathComponent) {
            file = renameShot(url) ?? url
        }
        if model.sortEnabled, let rule = rule(for: file) { move(file, rule) }
    }

    @discardableResult func renameShot(_ url: URL) -> URL? {
        guard url.pathExtension.lowercased() == "png", let info = ImageReader.info(url) else {
            model.log("exclamationmark.triangle", String(format: L("log.notImage"), url.lastPathComponent), error: true); return nil
        }
        let name = ShotNaming.name(template: model.nameTemplate, info: info, date: Date())
        if name == url.lastPathComponent { return url }
        let target = ShotNaming.unique(name, in: url.deletingLastPathComponent())
        do {
            if watchers[WatchFolders.canonical(target.deletingLastPathComponent().path)] != nil { produced.insert(target.path) }
            try FileManager.default.moveItem(at: url, to: target)
            model.log("pencil", String(format: L("log.renamed"), target.lastPathComponent))
            return target
        } catch {
            produced.remove(target.path)
            model.log("exclamationmark.triangle", String(format: L("log.renameFailed"), url.lastPathComponent, error.localizedDescription), error: true)
            return nil
        }
    }

    /// Files already in the watched folders that a rule would move now (for 今あるファイルを振り分ける).
    func existingMatches() -> [(URL, SortRule)] {
        var result: [(URL, SortRule)] = []
        for folder in Set(model.rules.filter(\.enabled).map(\.folder)) {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
            for name in names.sorted() where !PartialFile.isPartial(name) {
                let url = URL(fileURLWithPath: folder).appendingPathComponent(name)
                if let rule = rule(for: url) { result.append((url, rule)) }
            }
        }
        return result
    }
    func sortExisting() {
        let matches = existingMatches()
        guard !matches.isEmpty else { model.log("checkmark.circle", L("log.nothingToSort")); return }
        let alert = NSAlert()
        alert.messageText = String(format: L("sortExistingConfirm"), matches.count)
        alert.informativeText = matches.prefix(8).map { "・\($0.0.lastPathComponent) → \($0.1.name)" }.joined(separator: "\n") + (matches.count > 8 ? "\n…" : "")
        alert.addButton(withTitle: L("sortExistingButton"))
        alert.addButton(withTitle: L("cancel")).keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        for (url, rule) in matches where FileManager.default.fileExists(atPath: url.path) { move(url, rule) }
    }

    private func move(_ url: URL, _ rule: SortRule) {
        let destination = URL(fileURLWithPath: rule.destination)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            model.log("exclamationmark.triangle", String(format: L("log.noDestination"), url.lastPathComponent, rule.destination), error: true); return
        }
        let target = FileNames.unique(url.lastPathComponent, in: destination)
        do {
            try FileManager.default.moveItem(at: url, to: target)
            model.log("arrow.right.doc.on.clipboard", String(format: L("log.moved"), url.lastPathComponent, rule.name, destination.lastPathComponent))
        } catch {
            model.log("exclamationmark.triangle", String(format: L("log.moveFailed"), url.lastPathComponent, error.localizedDescription), error: true)
        }
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
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 560), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "FileSorter"; window.titleVisibility = .hidden
        let host = GrowingHostingView(rootView: MainView(model: model, renameFiles: { [weak self] in self?.renameFiles() }, sortExisting: { [weak self] in self?.engine.sortExisting() }))
        host.sizingOptions = [.minSize]
        window.contentView = host
        window.delegate = self; window.isReleasedWhenClosed = false
        if UserDefaults.standard.string(forKey: "NSWindow Frame MainWindow") == nil { window.center() }  // First launch: no saved frame yet.
        window.setFrameAutosaveName("MainWindow"); window.minSize = NSSize(width: 560, height: 500)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        model.hotkeys.action = { [weak self] _ in StartupWindow.userRequestedWindow(); self?.show() }
        model.registerAppHotkey()
        model.onWatchChange = { [weak self] in self?.engine.refreshWatchers() }
        engine.refreshWatchers()
        MenuBarPresence.shared.install(name: "FileSorter", symbol: "tray.and.arrow.down", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() })
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !login && !StartupWindow.suppressInitialWindow { show() }
    }
    func applicationWillTerminate(_ notification: Notification) { engine.stop() }

    @objc func renameFiles() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.png]; panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { engine.renameShot(url) }
    }
    @objc func sortExisting() { show(); engine.sortExisting() }
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
            settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 560), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            let hosting = NSHostingView(rootView: SettingsView(model: model)); hosting.sizingOptions = [.minSize]
            settings!.title = L("settingsWindow"); settings!.contentView = hosting; settings!.contentMinSize = NSSize(width: 560, height: 560); settings!.isReleasedWhenClosed = false; settings!.center()
        }
        settings!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let text = Bundle.main.url(forResource: "Help", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? L("help")
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "FileSorter")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "FileSorter", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
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
        add(file, L("sortExistingMenu"), #selector(sortExisting), "")
        add(file, L("renameFiles"), #selector(renameFiles), "")
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
