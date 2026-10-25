import AppKit
import SwiftUI
import Carbon

@MainActor final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var rules: [Rule] = Model.loadRules() { didSet { saveRules() } }
    @Published var paused = UserDefaults.standard.bool(forKey: "paused") { didSet { defaults.set(paused, forKey: "paused"); onPausedChange?() } }
    @Published var dropboxPrompt = UserDefaults.standard.object(forKey: "dropboxPrompt") as? Bool ?? true { didSet { defaults.set(dropboxPrompt, forKey: "dropboxPrompt") } }
    @Published var noticeSeconds = UserDefaults.standard.object(forKey: "noticeSeconds") as? Double ?? 4 { didSet { defaults.set(noticeSeconds, forKey: "noticeSeconds") } }
    @Published var history: [HistoryEntry] = []
    @Published var status = ""
    @Published var statusIsError = false
    var onPausedChange: (() -> Void)?

    /// Keys shared by 設定の共有. Startup, residency, the menu bar, the excluded apps and pausing stay per Mac.
    nonisolated static let sharedKeys: Set<String> = ["rules", "dropboxPrompt", "noticeSeconds"]
    func reloadSharedSettings() {
        rules = Model.loadRules()
        dropboxPrompt = defaults.object(forKey: "dropboxPrompt") as? Bool ?? true
        noticeSeconds = defaults.object(forKey: "noticeSeconds") as? Double ?? 4
    }
    private static func loadRules() -> [Rule] {
        guard let data = UserDefaults.standard.data(forKey: "rules") else { return Rule.defaults }
        return (try? JSONDecoder().decode([Rule].self, from: data)) ?? Rule.defaults
    }
    private func saveRules() { if let data = try? JSONEncoder().encode(rules) { defaults.set(data, forKey: "rules") } }

    func save(_ rule: Rule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) { rules[index] = rule } else { rules.append(rule) }
    }
    /// Adds the first-launch rules that are missing (by name); existing rules are kept as they are.
    func restorePresets() {
        let names = Set(rules.map(\.name))
        let missing = Rule.defaults.filter { !names.contains($0.name) }
        rules += missing
        setStatus(missing.isEmpty ? L("presetsPresent") : String(format: L("presetsAdded"), missing.count))
    }
    func setStatus(_ text: String, error: Bool = false) { status = text; statusIsError = error }
    func record(_ entry: HistoryEntry) {
        history.insert(entry, at: 0)
        if history.count > 30 { history.removeLast(history.count - 30) }
    }

    /// Hotkey that shows the main window while the app is running (per Mac, not shared). Default ⌃⌥T.
    static let defaultAppCombo = KeyCombo(code: UInt32(kVK_ANSI_T), modifiers: KeyCombo.control | KeyCombo.option)
    static let appHotkeyFieldID = "appHotkey"
    @Published var appHotkeyEnabled = UserDefaults.standard.object(forKey: "appHotkeyEnabled") as? Bool ?? true { didSet { defaults.set(appHotkeyEnabled, forKey: "appHotkeyEnabled"); registerAppHotkey() } }
    @Published var appCombo: KeyCombo? = {
        guard let data = UserDefaults.standard.data(forKey: "appHotkey") else { return Model.defaultAppCombo }
        return data.isEmpty ? nil : try? JSONDecoder().decode(KeyCombo.self, from: data)
    }() { didSet { defaults.set(appCombo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "appHotkey"); registerAppHotkey() } }
    @Published var appHotkeyRegistered = true
    let hotkeys = HotkeySet(signature: "CTdy")
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
    let monitor = ClipboardMonitor()
    let notice = NoticePanel()
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
        ExcludedApps.shared.configure(explanation: L("excludedExplanation"), initial: ["com.adobe.illustrator", "com.apple.iWork.Keynote"])
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 660), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "ClipTidy"; window.titleVisibility = .hidden
        let host = GrowingHostingView(rootView: MainView(model: model))
        host.sizingOptions = [.minSize]
        window.contentView = host
        window.delegate = self; window.isReleasedWhenClosed = false
        if UserDefaults.standard.string(forKey: "NSWindow Frame MainWindow") == nil { window.center() }  // First launch: no saved frame yet.
        window.setFrameAutosaveName("MainWindow"); window.minSize = NSSize(width: 560, height: 600)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        model.hotkeys.action = { [weak self] _ in StartupWindow.userRequestedWindow(); self?.show() }
        model.registerAppHotkey()
        monitor.onChange = { [weak self] text, app in self?.handle(text, app: app) }
        model.onPausedChange = { [weak self] in self?.applyPaused() }
        applyPaused()
        MenuBarPresence.shared.install(name: "ClipTidy", symbol: "wand.and.stars", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() },
                                       extraItems: { [weak self] in self?.statusItems() ?? [] })
        SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings() }
        SettingsSync.shared.start(.init(keys: Model.sharedKeys, prefixes: [],
            note: StartupWindow.text("書き換えのルール、Dropboxのリンクの確認、表示時間を書き出し・同期します。",
                                     "Exports and syncs the rewrite rules, the Dropbox link prompt and the display time.",
                                     "导出并同步改写规则、Dropbox 链接提示和显示时间。",
                                     "변환 규칙, Dropbox 링크 확인, 표시 시간을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・常駐・メニューバーの表示・対象外アプリ・監視の一時停止はMacごとに設定します。",
                                       "Open at login, keep running, the menu bar icon, excluded apps and pausing are set on each Mac.",
                                       "登录时启动、保持运行、菜单栏图标、排除的应用和暂停在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 계속 실행, 메뉴 막대 아이콘, 제외할 앱, 일시 정지는 Mac마다 설정합니다.")))
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !login && !StartupWindow.suppressInitialWindow { show() }
    }
    func applicationWillTerminate(_ notification: Notification) { monitor.stop(); notice.close() }

    private func applyPaused() {
        if model.paused { monitor.stop(); model.setStatus(L("pausedStatus")) } else { monitor.start(); model.setStatus(L("watchingStatus")) }
    }

    /// A new text was copied: apply the rules, then offer the Dropbox direct link.
    private func handle(_ text: String, app: NSRunningApplication?) {
        if let app, app.processIdentifier == ProcessInfo.processInfo.processIdentifier { return }  // Copies inside ClipTidy (rule editing) stay as they are.
        if ExcludedApps.shared.excludes(app?.bundleIdentifier) { return }
        let outcome = RuleEngine.run(model.rules, on: text, frontApp: app?.bundleIdentifier)
        var current = text
        if !outcome.applied.isEmpty {
            monitor.write(outcome.text)
            current = outcome.text
            model.record(HistoryEntry(date: Date(), rules: outcome.applied, before: text, after: outcome.text))
            model.setStatus(String(format: L("rewroteStatus"), outcome.applied.joined(separator: L("listSeparator"))))
            let announced = model.rules.filter { $0.announce && outcome.applied.contains($0.name) }.map(\.name)
            if !announced.isEmpty { notice.show(seconds: model.noticeSeconds) { RewriteNotice(rules: announced, text: outcome.text) } }
        }
        if !outcome.errors.isEmpty {
            model.setStatus(String(format: L("ruleErrors"), outcome.errors.joined(separator: L("listSeparator"))), error: true)
        }
        if model.dropboxPrompt, DropboxLink.isShareLink(current) {
            let count = monitor.changeCount, link = current
            notice.show(seconds: 30) {
                DropboxNotice(item: DropboxLink.item(link), direct: { [weak self] in
                    guard let self else { return }
                    if self.monitor.write(DropboxLink.direct(link), ifStill: count) {
                        self.model.setStatus(L("dropbox.changed"))
                    } else {
                        self.model.setStatus(L("dropbox.newer"), error: true)
                    }
                    self.notice.close()
                }, dismiss: { [weak self] in self?.notice.close() })
            }
        }
    }

    func statusItems() -> [NSMenuItem] {
        let item = NSMenuItem(title: L(model.paused ? "resume" : "pause"), action: #selector(togglePause), keyEquivalent: "")
        item.target = self
        return [item]
    }
    @objc func togglePause() { model.paused.toggle() }
    @objc func newRule() { show(); NotificationCenter.default.post(name: .newRule, object: nil) }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(togglePause) { menuItem.title = L(model.paused ? "resume" : "pause") }
        return true
    }

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
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "ClipTidy")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "ClipTidy", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
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
        add(file, L("newRuleMenu"), #selector(newRule), "n")
        add(file, L("pause"), #selector(togglePause), "")
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
