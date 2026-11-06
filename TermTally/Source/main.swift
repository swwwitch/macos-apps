import AppKit
import SwiftUI
import Carbon

/// The hotkey that shows the main window from any app while TermTally runs (per Mac).
/// No default: every ⌃⌥ letter is taken by Keyboard Maestro or another app on this Mac (2026-10-26).
@MainActor final class AppLauncherHotkey: ObservableObject {
    static let fieldID = "appHotkey"
    private let defaults = UserDefaults.standard
    let keys = HotkeySet(signature: "TTap")
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
        AccessibilityText.neededOverride = ["テキストエディットなどの本文を読み書きし、Googleドキュメントへキー操作を送るために必要です。", "Needed to read and change the text of TextEdit and similar apps, and to send keystrokes to Google Docs.", "用于读取和更改“文本编辑”等应用的正文，并向 Google 文档发送按键。", "텍스트 편집기 등의 본문을 읽고 바꾸고, Google 문서에 키 입력을 보내는 데 필요합니다."]
        SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings(); self?.applyWindowLevel() }
        SettingsSync.shared.start(.init(keys: Set(AppModel.sharedKeys + ["alwaysOnTop", "matchInRed", "matchColor"]), note: L("sharing.note"), perMac: L("sharing.perMac")))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 580), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "TermTally"; window.titleVisibility = .hidden
        // A plain hosting view: the list would otherwise grow the window to fit every row.
        let host = NSHostingView(rootView: MainView(model: model, close: { [weak self] in self?.window.performClose(nil) }))
        host.sizingOptions = [.minSize]
        window.contentView = host
        window.delegate = self; window.isReleasedWhenClosed = false
        if UserDefaults.standard.string(forKey: "NSWindow Frame MainWindow") == nil { window.center() }  // First launch: no saved frame yet.
        window.setFrameAutosaveName("MainWindow"); window.contentMinSize = NSSize(width: 800, height: 530)
        if !UserDefaults.standard.bool(forKey: "compactLayoutV2") {
            window.setContentSize(NSSize(width: 920, height: 580))
            UserDefaults.standard.set(true, forKey: "compactLayoutV2")
        }
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        launcher.keys.action = { [weak self] _ in StartupWindow.userRequestedWindow(); self?.show() }
        launcher.register()
        MenuBarPresence.shared.install(name: "TermTally", symbol: "number.square", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() })
        model.isWindowVisible = { [weak self] in self?.window.isVisible ?? false }
        applyWindowLevel()
        observeApps()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyWindowLevel() }
        }
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !login && !StartupWindow.suppressInitialWindow { show() }
    }


    /// Remembers the app used last: this window takes the front as soon as it is clicked.
    func observeApps() {
        model.noteActivated(NSWorkspace.shared.frontmostApplication ?? .current)
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated { self?.model.noteActivated(app) }
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated { self?.model.noteTerminated(app) }
        }
    }
    func applicationDidBecomeActive(_ notification: Notification) { model.refreshTarget() }

    func applyWindowLevel() {
        guard let window else { return }
        let level: NSWindow.Level = UserDefaults.standard.object(forKey: "alwaysOnTop") as? Bool ?? true ? .floating : .normal
        if window.level != level { window.level = level }
    }

    @objc func show() { guard let window else { return }; NSApp.activate(ignoringOtherApps: true); if window.isMiniaturized { window.deminiaturize(nil) }; window.makeKeyAndOrderFront(nil); model.refreshTarget()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.model.addSelectionIfQuiet() } }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        StartupWindow.userRequestedWindow(); show(); return true }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === window && !UserDefaults.standard.bool(forKey: "resident") { NSApp.terminate(nil); return false }
        return true
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Replacing holds the clipboard and works key by key: stop it first, then quit again.
        guard model.isBusy else { return .terminateNow }
        model.cancel()
        return .terminateCancel
    }

    @objc func showSettings() {
        if settings == nil {
            settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 460), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            let hosting = NSHostingView(rootView: SettingsView(model: model, launcher: launcher)); hosting.sizingOptions = [.minSize]
            settings!.title = L("settingsWindow"); settings!.contentView = hosting; settings!.contentMinSize = NSSize(width: 560, height: 460); settings!.isReleasedWhenClosed = false; settings!.center()
        }
        settings!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let text = Bundle.main.url(forResource: "Help", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? L("help")
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "TermTally")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "TermTally", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
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
