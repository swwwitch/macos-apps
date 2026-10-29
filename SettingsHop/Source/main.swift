import AppKit
import SwiftUI
import Carbon

@MainActor final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var closeAfterOpen = UserDefaults.standard.bool(forKey: "closeAfterOpen") { didSet { defaults.set(closeAfterOpen, forKey: "closeAfterOpen") } }
    /// Keys shared by 設定の共有. Startup, residency and the menu bar stay per Mac.
    nonisolated static let sharedKeys: Set<String> = ["closeAfterOpen", "hiddenPanes", "paneKeys"]
    /// Re-reads the shared settings after an import so the next save does not write the old values back.
    func reloadSharedSettings() { closeAfterOpen = defaults.bool(forKey: "closeAfterOpen"); layout = Model.storedLayout() }
    /// Panes shown and their keys (Settings › Items). The File menu is rebuilt through `onLayoutChanged`.
    @Published var layout = Model.storedLayout() {
        didSet {
            guard layout != oldValue else { return }
            defaults.set(layout.hiddenPlist, forKey: "hiddenPanes"); defaults.set(layout.keysPlist, forKey: "paneKeys")
            if layout.hidden.contains(selection) { selection = layout.visible.first ?? .systemSettings }
            onLayoutChanged?()
        }
    }
    var onLayoutChanged: (() -> Void)?
    static func storedLayout() -> PaneLayout {
        PaneLayout(hiddenPlist: UserDefaults.standard.object(forKey: "hiddenPanes"), keysPlist: UserDefaults.standard.object(forKey: "paneKeys"))
    }
    /// Hotkey that shows the main window while the app is running (per Mac, not shared). Default ⌃⌥Q.
    static let defaultAppCombo = KeyCombo(code: UInt32(kVK_ANSI_Q), modifiers: KeyCombo.control | KeyCombo.option)
    static let appHotkeyFieldID = "appHotkey"
    @Published var appHotkeyEnabled = UserDefaults.standard.object(forKey: "appHotkeyEnabled") as? Bool ?? true { didSet { defaults.set(appHotkeyEnabled, forKey: "appHotkeyEnabled"); registerAppHotkey() } }
    @Published var appCombo: KeyCombo? = {
        guard let data = UserDefaults.standard.data(forKey: "appHotkey") else { return Model.defaultAppCombo }
        return data.isEmpty ? nil : try? JSONDecoder().decode(KeyCombo.self, from: data)
    }() { didSet { defaults.set(appCombo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "appHotkey"); registerAppHotkey() } }
    @Published var appHotkeyRegistered = true
    let hotkeys = HotkeySet(signature: "SHop")
    func registerAppHotkey() {
        hotkeys.unregisterAll()
        guard appHotkeyEnabled, let appCombo else { appHotkeyRegistered = true; return }
        appHotkeyRegistered = hotkeys.register(1, appCombo) == noErr
    }
    @Published var status = ""
    /// Row chosen with ↑↓ in the main window; Return opens it. Follows the last opened pane.
    @Published var selection: Pane = .systemSettings
    func moveSelection(by offset: Int) {
        let all = layout.visible, index = all.firstIndex(of: selection) ?? 0
        selection = all[min(max(index + offset, 0), all.count - 1)]
    }
    /// The app that was active before SettingsHop (or System Settings), for Option-click.
    var previousApp: NSRunningApplication?
    private var activationObserver: Any?
    func trackPreviousApp() {
        let ignored: Set<String?> = [Bundle.main.bundleIdentifier, Pane.settingsBundleID]
        if let front = NSWorkspace.shared.frontmostApplication, !ignored.contains(front.bundleIdentifier) { previousApp = front }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, !ignored.contains(app.bundleIdentifier) else { return }
            MainActor.assumeIsolated { self?.previousApp = app }
        }
    }
    /// Names the Privacy list may show for an app: the .app file name and the localized name.
    static func rowNames(_ app: NSRunningApplication) -> [String] {
        var names = [app.bundleURL?.deletingPathExtension().lastPathComponent, app.localizedName].compactMap { $0 }
        if let url = app.bundleURL, let bundle = Bundle(url: url) {
            names += [bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, bundle.object(forInfoDictionaryKey: "CFBundleName") as? String].compactMap { $0 }
        }
        return Array(Set(names.filter { !$0.isEmpty }))
    }
    /// Called after a pane opened from the main window, to close it when closeAfterOpen is on.
    var onOpened: (() -> Void)?

    /// Returns false when the pane could not be opened; the reason is left in `status`.
    @discardableResult
    func open(_ pane: Pane, fromMainWindow: Bool = true, option: Bool = false) -> Bool {
        if option && pane.listsApps, let app = previousApp, let url = pane.url {
            // Option-click: open the list with the previously active app's row selected (the shared B31 locator; never changes the switch).
            selection = pane
            guard AccessibilitySection.isTrusted else {
                guard pane.open() else { status = String(format: L("failed"), pane.title); return false }
                status = String(format: L("selectNeedsAccess"), app.localizedName ?? ""); return true
            }
            let opened = AccessibilitySettingsLocator.shared.open(names: Model.rowNames(app), paneURL: url) { [weak self] message in self?.status = message }
            if !opened { status = String(format: L("failed"), pane.title); return false }
            if fromMainWindow && closeAfterOpen { onOpened?() }
            return true
        }
        // Privacy & Security at its top: open the main list, then scroll it up. Without the permission, open it as left last time.
        if AccessibilitySection.isTrusted, let path = pane.topExtensionPath, let url = pane.mainListURL {
            guard NSWorkspace.shared.open(url) else { status = String(format: L("failed"), pane.title); return false }
            DispatchQueue.global(qos: .userInitiated).async { _ = RowLocator.scrollToTop(extensionPath: path) }
        } else {
            guard pane.open() else { status = String(format: L("failed"), pane.title); return false }
        }
        status = String(format: L("opened"), pane.title)
        selection = pane
        if let target = pane.rowTarget {
            // Without the permission the pane still opens; the row is left for the user to scroll to.
            if AccessibilitySection.isTrusted {
                DispatchQueue.global(qos: .userInitiated).async {
                    let found = RowLocator.reveal(target)
                    DispatchQueue.main.async { if !found { self.status = String(format: L("rowNotFound"), pane.title) } }
                }
            } else {
                status = String(format: L("openedNoScroll"), pane.title)
            }
        }
        if fromMainWindow && closeAfterOpen { onOpened?() }
        return true
    }
}

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

struct PaneRow: View {
    let pane: Pane
    let key: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: pane.symbol).font(.system(size: 15)).foregroundColor(appTint).frame(width: 22).accessibilityHidden(true)
                Text(pane.title).lineLimit(1)
                Spacer()
                Text(key).font(.callout).foregroundColor(.secondary).monospacedDigit().accessibilityHidden(true)
            }
            .padding(.vertical, 7).padding(.horizontal, 10)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 6).fill(selected ? appTint.opacity(0.18) : hovering ? Color.primary.opacity(0.07) : Color.clear))
        }
        .buttonStyle(.plain)
        // ↑↓ move the selection instead; a focus ring on one row would show a second, different "current" row.
        .focusable(false)
        .padding(.leading, pane.isSubpane ? 24 : 0)
        .onHover { hovering = $0 }
        .accessibilityLabel(pane.title)
        .accessibilityHint(L("openHint"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct MainView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 4) { Text(L("heading")).font(.system(size: 22, weight: .semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 2) {
                let panes = model.layout.visible
                ForEach(Array(panes.enumerated()), id: \.element) { index, pane in
                    if index > 0 && panes[index - 1].group != pane.group { Divider().padding(.vertical, 4) }
                    PaneRow(pane: pane, key: model.layout.key(for: pane), selected: model.selection == pane) { model.open(pane, option: NSEvent.modifierFlags.contains(.option)) }
                }
            }
            .padding(8).background(Color(nsColor: .textBackgroundColor)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.25)))
            // Empty until something is opened (a space keeps the row's height, so the window does not jump).
            Text(model.status.isEmpty ? " " : model.status).font(.callout).foregroundColor(.secondary).lineLimit(2)
        }.padding(20)
        // Fixed width, height from the content: the window is not resizable and follows this size.
        .frame(width: 420).fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: AppSurface.color)).tint(appTint)
    }
}

struct SettingsView: View {
    @ObservedObject var model: Model
    @AppStorage("resident") var resident = true
    var body: some View {
        SettingsTabs(sections: [(SettingsUI.launchTitle, AnyView(VStack(spacing: 16) {
            SettingsSection(SettingsUI.launchTitle) {
                LaunchPresenceSection(title: SettingsUI.launchTitle, loginControl: LoginAtLaunchView(), residentTitle: L("resident"), residentDetail: L("residentDetail"), resident: $resident,
                                      presenceExtra: MenuBarPresenceView(), shortcutTitle: L("launchShortcut"), shortcutButton: L("openShortcuts"), shortcutDetail: L("shortcutDetail")) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(SettingsUI.shortcutTitle).padding(.top, 4)
                    Toggle(HotkeyText.enable, isOn: $model.appHotkeyEnabled)
                    HotkeyField(id: Model.appHotkeyFieldID, combo: $model.appCombo, defaultCombo: Model.defaultAppCombo, allowsClear: true,
                                registered: model.appHotkeyRegistered, isEnabled: model.appHotkeyEnabled)
                    Text(L("appHotkeyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            AccessibilitySection()
        })), (L("generalTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("afterOpen")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("closeAfterOpen"), isOn: $model.closeAfterOpen)
                    Text(L("closeAfterOpenDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (L("itemsTab"), AnyView(PaneLayoutSettings(model: model))), (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())), (AboutSection.title, AnyView(AboutView()))]).frame(minWidth: 560, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
    }
}

/// Settings › Items: show or hide each pane and choose its key (⌘1–⌘9 or none).
struct PaneLayoutSettings: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(spacing: 16) {
            SettingsSection(L("itemsSection")) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Pane.allCases, id: \.self) { pane in
                        let shown = !model.layout.hidden.contains(pane)
                        HStack {
                            Toggle(isOn: Binding(get: { shown }, set: { show in
                                if show { model.layout.hidden.remove(pane) } else { model.layout.hidden.insert(pane) }
                            })) {
                                HStack(spacing: 6) {
                                    Image(systemName: pane.symbol).foregroundColor(appTint).frame(width: 18).accessibilityHidden(true)
                                    Text(pane.title).lineLimit(1)
                                }
                            }
                            .disabled(!model.layout.canHide(pane))
                            .padding(.leading, pane.isSubpane ? 20 : 0)
                            Spacer()
                            Picker(L("keyLabel"), selection: Binding(get: { model.layout.key(for: pane) }, set: { model.layout.assign($0, to: pane) })) {
                                Text(L("noKey")).tag("")
                                ForEach(1...9, id: \.self) { digit in Text("⌘\(digit)").tag(String(digit)) }
                            }
                            .labelsHidden().fixedSize().disabled(!shown)
                            .accessibilityLabel(String(format: L("keyFor"), pane.title))
                        }
                    }
                    Text(L("itemsDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
                    Button(L("resetItems")) { model.layout = PaneLayout() }.padding(.top, 2)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

@MainActor final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Model()
    var window: NSWindow!
    var settings: NSWindow?
    var helpWindow: NSWindow?
    var fileMenu: NSMenu?
    var isDuplicate = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        UserDefaults.standard.register(defaults: ["resident": true])
        AccessibilityText.neededOverride = [
            "「デフォルトのWebブラウザ」を開いたあと、システム設定のその行までスクロールするために使います。未許可でも「デスクトップとDock」は開きます。",
            "Used to scroll System Settings to the Default web browser row after opening it. Without it, Desktop & Dock still opens.",
            "用于打开“默认网页浏览器”后将系统设置滚动到该行。未获授权时仍会打开“桌面与程序坞”。",
            "'기본 웹 브라우저'를 연 후 시스템 설정을 해당 행까지 스크롤하는 데 사용합니다. 권한이 없어도 데스크탑 및 Dock은 열립니다.",
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
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 380), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "SettingsHop"; window.titleVisibility = .hidden
        // Not resizable: the hosting controller sizes the window to the SwiftUI content (and follows it when the status line wraps).
        let host = NSHostingController(rootView: MainView(model: model))
        host.sizingOptions = [.preferredContentSize]
        window.contentViewController = host
        window.delegate = self; window.isReleasedWhenClosed = false
        if UserDefaults.standard.string(forKey: "NSWindow Frame MainWindow") == nil { window.center() }  // First launch: no saved frame yet.
        window.setFrameAutosaveName("MainWindow")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        model.onOpened = { [weak self] in self?.window.performClose(nil) }
        model.onLayoutChanged = { [weak self] in self?.rebuildPaneMenu() }
        model.hotkeys.action = { [weak self] _ in self?.handleAppHotkey() }
        model.registerAppHotkey()
        installArrowKeys()
        model.trackPreviousApp()
        MenuBarPresence.shared.install(name: "SettingsHop", symbol: "gearshape.2", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() },
                                       extraItems: { [weak self] in self?.paneItems(withKeys: false) ?? [] })
        SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings() }
        SettingsSync.shared.start(.init(keys: Model.sharedKeys, prefixes: [],
            note: StartupWindow.text("「項目を開いたらウインドウを閉じる」の選択と、表示する項目・キーを書き出し・同期します。",
                                     "Exports and syncs the Close the window after opening choice and the items shown with their keys.",
                                     "导出并同步“打开项目后关闭窗口”的选择以及显示的项目和按键。",
                                     "'항목을 연 후 윈도우 닫기' 선택과 표시할 항목·키를 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・常駐・メニューバーの表示はMacごとに設定します。",
                                       "Open at login, keep running and the menu bar icon are set on each Mac.",
                                       "登录时启动、保持运行和菜单栏图标在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 계속 실행, 메뉴 막대 아이콘은 Mac마다 설정합니다.")))
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !login && !StartupWindow.suppressInitialWindow { show() }
    }
    private var lastAppHotkey: TimeInterval?
    private var waitingForRelease = false
    private var releaseTimer: Timer?
    private func handleAppHotkey() {
        guard !waitingForRelease else { return }
        waitingForRelease = true
        releaseTimer?.invalidate()
        releaseTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            guard let combo = self.model.appCombo else { self.waitingForRelease = false; timer.invalidate(); return }
            if !CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(combo.code)) {
                self.waitingForRelease = false; timer.invalidate()
            }
        }
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastAppHotkey, now - last <= NSEvent.doubleClickInterval {
            lastAppHotkey = nil
            window.orderOut(nil)
            _ = Pane.systemSettings.open()
        } else {
            lastAppHotkey = now
            StartupWindow.userRequestedWindow()
            show()
        }
    }
    @objc func show() { guard let window else { return }; NSApp.activate(ignoringOtherApps: true); if window.isMiniaturized { window.deminiaturize(nil) }; window.makeKeyAndOrderFront(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        StartupWindow.userRequestedWindow(); show(); return true }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === window && !UserDefaults.standard.bool(forKey: "resident") { NSApp.terminate(nil); return false }
        return true
    }
    @objc func quit() { NSApp.terminate(nil) }
    private var keyMonitor: Any?
    /// ↑↓ move the selection, Return / Enter opens it and 1–9 open a pane directly (⌘1–⌘9 also work from the File menu),
    /// only while the main window is the key window. Option adds the Option-click behavior to Return and the digits.
    func installArrowKeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, NSApp.keyWindow === self.window,
                  event.modifierFlags.intersection([.command, .control, .shift]).isEmpty else { return event }
            let option = event.modifierFlags.contains(.option)
            switch event.keyCode {
            case UInt16(kVK_DownArrow) where !option: self.model.moveSelection(by: 1)
            case UInt16(kVK_UpArrow) where !option: self.model.moveSelection(by: -1)
            case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter): self.model.open(self.model.selection, option: option)
            default:
                guard let digit = event.charactersIgnoringModifiers, let pane = self.model.layout.pane(forKey: digit) else { return event }
                self.model.open(pane, option: option)
            }
            return nil
        }
    }
    /// File menu (⌘1–⌘9, acts like a click in the main window) and the menu bar menu (no keys).
    func paneItems(withKeys: Bool) -> [NSMenuItem] {
        model.layout.visible.map { pane in
            let item = NSMenuItem(title: pane.title, action: withKeys ? #selector(openFromMenu(_:)) : #selector(openFromStatusMenu(_:)), keyEquivalent: withKeys ? model.layout.key(for: pane) : "")
            item.target = self; item.representedObject = pane.rawValue; item.indentationLevel = pane.isSubpane ? 1 : 0
            item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: nil)
            return item
        }
    }
    @objc func openFromMenu(_ sender: NSMenuItem) {
        guard let pane = (sender.representedObject as? String).flatMap(Pane.init(rawValue:)) else { return }
        if !model.open(pane, fromMainWindow: window.isKeyWindow, option: NSEvent.modifierFlags.contains(.option)) { show() }
    }
    @objc func openSelectingLastApp(_ sender: NSMenuItem) {
        guard let pane = (sender.representedObject as? String).flatMap(Pane.init(rawValue:)) else { return }
        if !model.open(pane, fromMainWindow: window.isKeyWindow, option: true) { show() }
    }
    @objc func openFromStatusMenu(_ sender: NSMenuItem) {
        guard let pane = (sender.representedObject as? String).flatMap(Pane.init(rawValue:)) else { return }
        // The window shows why when the pane could not be opened.
        if !model.open(pane, fromMainWindow: false) { show() }
    }
    @objc func showSettings() {
        if settings == nil {
            settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 600), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            // Resizable from the designed size upward; the hosting view reports only its minimum.
            let hosting = NSHostingView(rootView: SettingsView(model: model)); hosting.sizingOptions = [.minSize]
            settings!.title = L("settingsWindow"); settings!.contentView = hosting; settings!.contentMinSize = NSSize(width: 560, height: 600); settings!.isReleasedWhenClosed = false; settings!.center()
        }
        settings!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let text = Bundle.main.url(forResource: "Help", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? L("help")
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "SettingsHop")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "SettingsHop", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
    }
    /// Puts the visible panes between the File menu's two separators (again after Settings › Items changes).
    func rebuildPaneMenu() {
        guard let file = fileMenu else { return }
        for item in file.items where item.representedObject is String { file.removeItem(item) }
        var index = 2   // After 「メインウインドウを開く」 and its separator.
        for item in paneItems(withKeys: true) {
            file.insertItem(item, at: index); index += 1
            // Holding Option swaps in ⌘⌥N: the same list with the last app's row selected (Option-click from the keyboard).
            guard let pane = (item.representedObject as? String).flatMap(Pane.init(rawValue:)), pane.listsApps else { continue }
            let alternate = NSMenuItem(title: String(format: L("selectLastApp"), pane.title), action: #selector(openSelectingLastApp(_:)), keyEquivalent: item.keyEquivalent)
            alternate.keyEquivalentModifierMask = [.command, .option]; alternate.isAlternate = true
            alternate.target = self; alternate.representedObject = item.representedObject; alternate.indentationLevel = item.indentationLevel; alternate.image = item.image
            file.insertItem(alternate, at: index); index += 1
        }
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
        file.addItem(.separator())
        file.addItem(withTitle: L("close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu = file; rebuildPaneMenu()
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
