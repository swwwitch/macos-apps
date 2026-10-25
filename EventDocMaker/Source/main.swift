import AppKit
import SwiftUI
import Carbon

@MainActor final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var makeQR = UserDefaults.standard.object(forKey: "makeQR") as? Bool ?? true { didSet { defaults.set(makeQR, forKey: "makeQR") } }
    @Published var openAfter = UserDefaults.standard.object(forKey: "openAfter") as? Bool ?? true { didSet { defaults.set(openAfter, forKey: "openAfter") } }
    @Published var root = UserDefaults.standard.string(forKey: "root") ?? Locations.defaults.root { didSet { defaults.set(root, forKey: "root"); library.reload() } }
    @Published var eventDoc = UserDefaults.standard.string(forKey: "eventDoc") ?? Locations.defaults.eventDoc { didSet { defaults.set(eventDoc, forKey: "eventDoc"); library.reload() } }
    @Published var recent = UserDefaults.standard.string(forKey: "recent") ?? Locations.defaults.recent { didSet { defaults.set(recent, forKey: "recent") } }
    @Published var opener = UserDefaults.standard.string(forKey: "opener") ?? "pathfinder" { didSet { defaults.set(opener, forKey: "opener") } }
    @Published var sheetFile = UserDefaults.standard.string(forKey: "sheetFile") ?? SheetImport.defaultFile { didSet { defaults.set(sheetFile, forKey: "sheetFile") } }
    @Published var result: GenerationResult?
    @Published var resultEvent: UUID?
    @Published var status = ""
    @Published var statusIsError = false
    @Published var working = false
    lazy var library = Library(places: { [unowned self] in self.places })

    var places: Locations { Locations(root: root, eventDoc: eventDoc, recent: recent) }
    var templateCount: Int { Generator.templates(in: places.templates).count }
    func setStatus(_ text: String, error: Bool = false) { status = text; statusIsError = error }

    /// The variables for the selected event, from the same text the sheet used to hand over.
    var variables: EventVariables {
        EventVariables(fields: Schema.sheetValues(library.current?.values ?? [:]), readDoc: places.readDoc)
    }
    /// Cheap check for menus and buttons: the three values that name the folder (variables read files, so they are built only when needed).
    var canGenerate: Bool { !working && library.current?.folderName != nil }

    func generate() {
        guard canGenerate, let id = library.selection else { return }
        library.flush()
        let event = variables, places = self.places, makeQR = self.makeQR
        guard FileManager.default.fileExists(atPath: places.root) else { setStatus(String(format: L("rootMissing"), places.root), error: true); return }
        guard !Generator.templates(in: places.templates).isEmpty else { setStatus(String(format: L("noTemplates"), places.templates.path), error: true); return }
        working = true
        Task.detached(priority: .userInitiated) {
            let outcome = Result { try Generator.run(event, at: places, makeQR: makeQR) }
            await MainActor.run {
                self.working = false
                switch outcome {
                case .success(let result):
                    self.result = result; self.resultEvent = id
                    self.library.save(id)  // The folder exists now: the event's file moves into it.
                    self.setStatus(String(format: L("done"), result.written.count, result.folder.lastPathComponent))
                    if self.openAfter { self.open(result.folder.appendingPathComponent("docs")) }
                case .failure(let error):
                    self.setStatus(String(format: L("failed"), error.localizedDescription), error: true)
                }
            }
        }
    }

    func fillFromClipboard() {
        guard library.current != nil else { setStatus(L("noEventSelected"), error: true); return }
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { setStatus(L("clipboardEmpty"), error: true); return }
        let count = library.fillFromSheet(text)
        setStatus(count == 0 ? L("noFields") : String(format: L("filled"), count), error: count == 0)
    }

    /// Reads the workbook, then asks before writing: how many are new and whether to overwrite the ones already here.
    func importSheet() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "xlsx")!]
        panel.directoryURL = URL(fileURLWithPath: sheetFile).deletingLastPathComponent()
        panel.nameFieldStringValue = (sheetFile as NSString).lastPathComponent
        panel.prompt = L("import.choose")
        guard panel.runModal() == .OK, let file = panel.url else { return }
        sheetFile = file.path
        working = true
        setStatus(L("import.reading"))
        Task.detached(priority: .userInitiated) {
            let outcome = Result { SheetImport.events(from: try XLSX.read(file, sheet: SheetImport.sheetName)) }
            await MainActor.run { self.working = false; self.confirmImport(outcome) }
        }
    }
    private func confirmImport(_ outcome: Result<[[String: String]], Error>) {
        let rows: [[String: String]]
        switch outcome {
        case .failure(let error): setStatus(String(format: L("import.failed"), error.localizedDescription), error: true); return
        case .success(let value): rows = value
        }
        guard !rows.isEmpty else { setStatus(L("import.none"), error: true); return }
        let existing = Set(library.events.map { $0.record["#"] })
        let present = rows.filter { existing.contains($0["#"] ?? "") }.count
        let alert = NSAlert()
        alert.messageText = String(format: L("import.confirm"), rows.count, rows.count - present)
        alert.informativeText = L("import.confirmDetail")
        alert.addButton(withTitle: L("import.button"))
        alert.addButton(withTitle: L("cancel")).keyEquivalent = "\u{1b}"
        if present > 0 {
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = String(format: L("import.overwrite"), present)
            alert.suppressionButton?.state = .off
        }
        guard alert.runModal() == .alertFirstButtonReturn else { setStatus(""); return }
        let summary = library.importSheet(rows, overwrite: alert.suppressionButton?.state == .on)
        setStatus(String(format: L("import.done"), summary.added, summary.updated, summary.skipped), error: !library.saveError.isEmpty)
    }

    /// Opens a folder in Path Finder when chosen and installed, otherwise in Finder.
    func open(_ folder: URL) {
        if opener == "pathfinder", let app = ["com.cocoatech.PathFinder-setapp", "com.cocoatech.PathFinder"].lazy.compactMap({ NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }).first {
            NSWorkspace.shared.open([folder], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(folder)
        }
    }

    /// Hotkey that shows the main window while the app is running (per Mac). Default ⌃⌥E.
    static let defaultAppCombo = KeyCombo(code: UInt32(kVK_ANSI_E), modifiers: KeyCombo.control | KeyCombo.option)
    static let appHotkeyFieldID = "appHotkey"
    @Published var appHotkeyEnabled = UserDefaults.standard.object(forKey: "appHotkeyEnabled") as? Bool ?? true { didSet { defaults.set(appHotkeyEnabled, forKey: "appHotkeyEnabled"); registerAppHotkey() } }
    @Published var appCombo: KeyCombo? = {
        guard let data = UserDefaults.standard.data(forKey: "appHotkey") else { return Model.defaultAppCombo }
        return data.isEmpty ? nil : try? JSONDecoder().decode(KeyCombo.self, from: data)
    }() { didSet { defaults.set(appCombo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "appHotkey"); registerAppHotkey() } }
    @Published var appHotkeyRegistered = true
    let hotkeys = HotkeySet(signature: "EvDc")
    func registerAppHotkey() {
        hotkeys.unregisterAll()
        guard appHotkeyEnabled, let appCombo else { appHotkeyRegistered = true; return }
        appHotkeyRegistered = hotkeys.register(1, appCombo) == noErr
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
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "EventDocMaker"; window.titleVisibility = .hidden
        let host = GrowingHostingView(rootView: MainView(model: model, library: model.library))
        host.sizingOptions = [.minSize]
        window.contentView = host
        window.delegate = self; window.isReleasedWhenClosed = false
        if UserDefaults.standard.string(forKey: "NSWindow Frame MainWindow") == nil { window.center() }  // First launch: no saved frame yet.
        window.setFrameAutosaveName("MainWindow"); window.minSize = NSSize(width: 900, height: 640)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        model.hotkeys.action = { [weak self] _ in StartupWindow.userRequestedWindow(); self?.show() }
        model.registerAppHotkey()
        model.library.reload()
        MenuBarPresence.shared.install(name: "EventDocMaker", symbol: "doc.on.doc", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() })
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !login && !StartupWindow.suppressInitialWindow { show() }
    }

    @objc func fillFromClipboard() { show(); model.fillFromClipboard() }
    @objc func generate() { model.generate() }
    @objc func newEvent() { show(); model.library.newEvent() }
    @objc func duplicateEvent() { model.library.duplicate() }
    @objc func deleteEvent() { model.library.deleteCurrent() }
    @objc func importSheet() { show(); model.importSheet() }
    @objc func reload() { model.library.reload(); model.setStatus(String(format: L("reloaded"), model.library.events.count)) }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(generate): return model.canGenerate
        case #selector(duplicateEvent), #selector(deleteEvent), #selector(fillFromClipboard): return model.library.current != nil && !model.working
        case #selector(importSheet): return !model.working
        default: return true
        }
    }
    func applicationWillTerminate(_ notification: Notification) { model.library.flush() }
    func applicationDidResignActive(_ notification: Notification) { model.library.flush() }
    @objc func show() { guard let window else { return }; NSApp.activate(ignoringOtherApps: true); if window.isMiniaturized { window.deminiaturize(nil) }; window.makeKeyAndOrderFront(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        StartupWindow.userRequestedWindow(); show(); return true }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === window && !UserDefaults.standard.bool(forKey: "resident") { NSApp.terminate(nil); return false }
        return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.working else { return .terminateNow }
        let alert = NSAlert(); alert.messageText = L("busyQuit"); alert.addButton(withTitle: L("ok"))
        alert.runModal()
        return .terminateCancel
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
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "EventDocMaker")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "EventDocMaker", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) -> NSMenuItem { let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key); item.target = self; return item }
    func buildMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        let app = NSMenu(); let root = NSMenuItem(); root.submenu = app; bar.addItem(root)
        _ = add(app, L("about"), #selector(about), ""); app.addItem(.separator())
        _ = add(app, L("settings"), #selector(showSettings), ","); app.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to: app)   // 「アップデートを確認…」「アップデートを自動確認」 + separator
        #endif
        let services = NSMenu(title: L("services")); app.addItem(withTitle: L("services"), action: nil, keyEquivalent: "").submenu = services; NSApp.servicesMenu = services
        app.addItem(.separator())
        app.addItem(withTitle: L("hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: L("hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: L("showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator()); _ = add(app, L("quit"), #selector(quit), "q")
        let file = NSMenu(title: L("fileMenu")); let fileItem = NSMenuItem(title: L("fileMenu"), action: nil, keyEquivalent: ""); fileItem.submenu = file; bar.addItem(fileItem)
        _ = add(file, L("openMainWindow"), #selector(show), "0"); file.addItem(.separator())
        _ = add(file, L("newEvent"), #selector(newEvent), "n")
        _ = add(file, L("duplicateEvent"), #selector(duplicateEvent), "d")
        add(file, L("deleteEvent"), #selector(deleteEvent), "\u{8}").keyEquivalentModifierMask = [.command]
        file.addItem(.separator())
        _ = add(file, L("importSheetMenu"), #selector(importSheet), "")
        add(file, L("fillFromClipboard"), #selector(fillFromClipboard), "v").keyEquivalentModifierMask = [.command, .shift]
        _ = add(file, L("reload"), #selector(reload), "r")
        file.addItem(.separator())
        _ = add(file, L("generateMenu"), #selector(generate), "\r")
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
        _ = add(help, L("help"), #selector(showHelp), "?"); HelpLinks.addNoteItem(to: help); NSApp.helpMenu = help
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
MainActor.assumeIsolated {
    let delegate = Delegate(); app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
