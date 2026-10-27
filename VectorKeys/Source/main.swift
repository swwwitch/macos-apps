import AppKit
import SwiftUI
import Carbon

/// The hotkey that shows the main window from any app while VectorKeys runs (per Mac).
/// No default: every ⌃⌥ letter is taken by Keyboard Maestro or another app on this Mac (2026-10-26).
@MainActor final class AppLauncherHotkey: ObservableObject {
    static let fieldID = "appHotkey"
    private let defaults = UserDefaults.standard
    let keys = HotkeySet(signature: "VKap")
    @Published var enabled = UserDefaults.standard.object(forKey: "appHotkeyEnabled") as? Bool ?? true {
        didSet { defaults.set(enabled, forKey: "appHotkeyEnabled"); register() }
    }
    @Published var combo: KeyCombo? = {
        guard let data = UserDefaults.standard.data(forKey: "appHotkey") else { return nil }
        return data.isEmpty ? nil : try? JSONDecoder().decode(KeyCombo.self, from: data)
    }() { didSet { defaults.set(combo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "appHotkey"); register() } }
    @Published var registered = true
    func register() {
        keys.unregisterAll()
        guard enabled, let combo else { registered = true; return }
        registered = keys.register(1, combo) == noErr
    }
}

@MainActor final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = AppModel()
    let launcher = AppLauncherHotkey()
    var window: NSWindow!
    var settings: NSWindow?
    var helpWindow: NSWindow?
    var statsWindow: NSWindow?
    var isDuplicate = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        UserDefaults.standard.register(defaults: ["resident": true, "showUses": true])
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
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "VectorKeys"; window.titleVisibility = .hidden
        // A plain hosting view: the list would otherwise grow the window to fit every script.
        let host = NSHostingView(rootView: MainView(model: model))
        host.sizingOptions = [.minSize]
        window.contentView = host
        window.delegate = self; window.isReleasedWhenClosed = false
        if UserDefaults.standard.string(forKey: "NSWindow Frame MainWindow") == nil { window.center() }  // First launch: no saved frame yet.
        window.setFrameAutosaveName("MainWindow"); window.minSize = NSSize(width: 980, height: 600)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        launcher.keys.action = { [weak self] _ in StartupWindow.userRequestedWindow(); self?.show() }
        launcher.register()
        MenuBarPresence.shared.install(name: "VectorKeys", symbol: "keyboard", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() },
                                       extraItems: { [weak self] in self?.statusItems() ?? [] })
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !login && !StartupWindow.suppressInitialWindow { show() }
    }

    func applicationWillTerminate(_ notification: Notification) { model.saveNow() }

    func statusItems() -> [NSMenuItem] {
        let item = NSMenuItem(title: L(model.hotkeysEnabled ? "pauseHotkeys" : "resumeHotkeys"), action: #selector(toggleHotkeys), keyEquivalent: "")
        item.target = self
        return [item]
    }
    @objc func toggleHotkeys() { model.hotkeysEnabled.toggle() }
    @objc func addScripts() { show(); model.chooseFiles() }
    @objc func importKM() { show(); model.chooseKMFiles() }
    @objc func stripNumbering() { model.stripNumbering() }
    @objc func replaceNames() { show(); model.showReplace = true }
    /// 表示 › 使用回数を表示 (the views read the same "showUses" default through @AppStorage).
    @objc func toggleShowUses() { UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: "showUses"), forKey: "showUses") }
    @objc func kmOff() { model.setInKM(model.selectedKMUIDs, enabled: false) }
    @objc func kmOn() { model.setInKM(model.selectedKMUIDs, enabled: true) }
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? { window === self.window ? model.undoManager : nil }

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
            settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 460), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            let hosting = NSHostingView(rootView: SettingsView(model: model, launcher: launcher)); hosting.sizingOptions = [.minSize]
            settings!.title = L("settingsWindow"); settings!.contentView = hosting; settings!.contentMinSize = NSSize(width: 560, height: 460); settings!.isReleasedWhenClosed = false; settings!.center()
        }
        settings!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showStats() {
        if statsWindow == nil {
            statsWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 560), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            let hosting = NSHostingView(rootView: StatsView(model: model)); hosting.sizingOptions = [.minSize]
            statsWindow!.title = L("stats.title"); statsWindow!.contentView = hosting; statsWindow!.isReleasedWhenClosed = false
            statsWindow!.setFrameAutosaveName("StatsWindow")
            if UserDefaults.standard.string(forKey: "NSWindow Frame StatsWindow") == nil { statsWindow!.center() }
        }
        statsWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let text = Bundle.main.url(forResource: "Help", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? L("help")
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "VectorKeys")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "VectorKeys", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
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
        add(file, L("addMenu"), #selector(addScripts), "o")
        add(file, L("km.import"), #selector(importKM), "i")
        add(file, L("pauseHotkeys"), #selector(toggleHotkeys), "")
        file.addItem(.separator())
        file.addItem(withTitle: L("close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let edit = NSMenu(title: L("editMenu")); let editItem = NSMenuItem(title: L("editMenu"), action: nil, keyEquivalent: ""); editItem.submenu = edit; bar.addItem(editItem)
        for (key, action, shortcut) in [("undo", "undo:", "z"), ("redo", "redo:", "z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("paste", "paste:", "v"), ("selectAll", "selectAll:", "a")] {
            edit.addItem(withTitle: L(key), action: Selector(action), keyEquivalent: shortcut)
        }
        edit.item(at: 1)?.keyEquivalentModifierMask = [.command, .shift]   // やり直す ⇧⌘Z
        let view = NSMenu(title: L("viewMenu")); let viewItem = NSMenuItem(title: L("viewMenu"), action: nil, keyEquivalent: ""); viewItem.submenu = view; bar.addItem(viewItem)
        add(view, L("showUses"), #selector(toggleShowUses), "")
        let tools = NSMenu(title: L("toolsMenu")); let toolsItem = NSMenuItem(title: L("toolsMenu"), action: nil, keyEquivalent: ""); toolsItem.submenu = tools; bar.addItem(toolsItem)
        add(tools, L("tools.stats"), #selector(showStats), "")
        tools.addItem(.separator())
        add(tools, L("tools.replace"), #selector(replaceNames), "f")
        add(tools, L("tools.stripNumbering"), #selector(stripNumbering), "")
        tools.addItem(.separator())
        add(tools, L("tools.kmOff"), #selector(kmOff), "")
        add(tools, L("tools.kmOn"), #selector(kmOn), "")
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

extension Delegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(stripNumbering) || menuItem.action == #selector(replaceNames) { return !model.selection.isEmpty }
        if menuItem.action == #selector(toggleShowUses) { menuItem.state = UserDefaults.standard.bool(forKey: "showUses") ? .on : .off }
        if menuItem.action == #selector(kmOff) || menuItem.action == #selector(kmOn) { return !model.selectedKMUIDs.isEmpty }
        if menuItem.action == #selector(toggleHotkeys) { menuItem.title = L(model.hotkeysEnabled ? "pauseHotkeys" : "resumeHotkeys") }
        return true
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
MainActor.assumeIsolated {
    let delegate = Delegate(); app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
