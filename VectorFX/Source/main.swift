import AppKit
import Carbon
import SwiftUI

@MainActor final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Model()
    lazy var palette = PaletteController(model: model)
    var window: NSWindow!
    var settings: NSWindow?
    var helpWindow: NSWindow?
    var isDuplicate = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        UserDefaults.standard.register(defaults: ["resident": true])
        AccessibilityText.neededOverride = [
            "Illustratorで文字を入力しているあいだ、修飾キーなしのホットキー（- や ⇧K など）を実行せずに文字として入力させるために使います。未許可でもホットキーは使えますが、文字入力中も実行されます。",
            "Used to leave hotkeys without modifiers (such as - or ⇧K) to Illustrator while you type text there. Without it hotkeys still work, but they also run while typing.",
            "用于在 Illustrator 中输入文字时，不执行不带修饰键的快捷键（如 - 或 ⇧K），而是作为文字输入。未授权时快捷键仍可使用，但输入文字时也会执行。",
            "Illustrator에서 텍스트를 입력하는 동안 보조 키 없는 단축키(- 또는 ⇧K 등)를 실행하지 않고 문자로 입력되도록 하는 데 사용합니다. 권한이 없어도 단축키는 작동하지만 텍스트 입력 중에도 실행됩니다.",
        ]
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
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 600), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "VectorFX"; window.titleVisibility = .hidden
        let hosting = NSHostingView(rootView: MainView(model: model, togglePalette: { [weak self] in self?.palette.toggle() }))
        hosting.sizingOptions = [.minSize]
        window.contentView = hosting
        window.contentMinSize = NSSize(width: 760, height: 520)
        window.delegate = self; window.isReleasedWhenClosed = false
        if UserDefaults.standard.string(forKey: "NSWindow Frame MainWindow") == nil { window.center() }  // First launch: no saved frame yet.
        window.setFrameAutosaveName("MainWindow")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }

        model.appHotkeys.action = { [weak self] _ in StartupWindow.userRequestedWindow(); self?.show() }
        model.paletteHotkeys.suppressRepeatedPresses = true
        model.paletteHotkeys.action = { [weak self] _ in self?.palette.toggle() }
        model.commandHotkeys.suppressRepeatedPresses = true
        model.commandHotkeys.action = { [weak self] number in
            // The key may arrive after Illustrator lost the front; never act on another app.
            guard let self, Illustrator.front != nil, let command = self.model.command(forHotkey: number) else { return }
            self.model.run(command)
        }
        model.keyTap.action = { [weak self] id in
            guard let self, Illustrator.front != nil, let command = Catalog.command(id) else { return }
            self.model.run(command)
        }
        // Permission granted in System Settings: switch to the tap when coming back.
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.updateRegistrations() }
        }
        model.registerAppHotkey()
        // The palette controller follows the front app: keys are registered while Illustrator is in front, released for every other app.
        palette.updateVisibility()

        MenuBarPresence.shared.install(name: "VectorFX", symbol: "wand.and.stars", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() },
                                       extraItems: { [weak self] in
            guard let self else { return [] }
            let item = NSMenuItem(title: self.model.paletteRequested ? L("palette.hide") : L("palette.show"), action: #selector(self.togglePalette), keyEquivalent: "")
            item.target = self
            return [item]
        })
        SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings() }
        SettingsSync.shared.start(.init(keys: Model.sharedKeys, prefixes: [],
            note: StartupWindow.text("パレットに表示する項目、項目ごとのホットキーと効果の値、パレットを表示するホットキーを書き出し・同期します。",
                                     "Exports and syncs the palette items, each item's hotkey and effect values, and the palette hotkey.",
                                     "导出并同步面板中的项目、各项目的快捷键与效果数值，以及显示面板的快捷键。",
                                     "팔레트 항목, 항목별 단축키와 효과 값, 팔레트 표시 단축키를 내보내고 동기화합니다."),
            perMac: StartupWindow.text("スクリプトファイルの場所、ログイン時の起動・常駐・メニューバーの表示・アプリを呼び出すホットキーはMacごとに設定します。",
                                       "Script file locations, open at login, keep running, the menu bar icon and the show-app hotkey are set on each Mac.",
                                       "脚本文件位置、登录时启动、保持运行、菜单栏图标和显示应用快捷键在每台 Mac 上分别设置。",
                                       "스크립트 파일 위치, 로그인 시 실행, 계속 실행, 메뉴 막대 아이콘, 앱 표시 단축키는 Mac마다 설정합니다.")))
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !login && !StartupWindow.suppressInitialWindow { show() }
    }
    @objc func show() { guard let window else { return }; NSApp.activate(ignoringOtherApps: true); if window.isMiniaturized { window.deminiaturize(nil) }; window.makeKeyAndOrderFront(nil) }
    @objc func togglePalette() {
        palette.toggle()
        // Shown from here, the palette waits for Illustrator: bring it forward.
        if palette.isRequested, Illustrator.front == nil { Illustrator.running?.activate() }
    }
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
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "VectorFX")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "VectorFX", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
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
        let paletteItem = NSMenuItem(title: L("palette.toggle"), action: #selector(togglePalette), keyEquivalent: "p")
        paletteItem.keyEquivalentModifierMask = [.command, .shift]; paletteItem.target = self; file.addItem(paletteItem)
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

enum LaunchPolicy {
    static func isLoginLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventClass == AEEventClass(kCoreEventClass), event.eventID == AEEventID(kAEOpenApplication) else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
MainActor.assumeIsolated {
    let delegate = Delegate(); app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
