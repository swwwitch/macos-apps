import AppKit
import SwiftUI
import ServiceManagement
import Carbon
import ApplicationServices
import UniformTypeIdentifiers

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

@MainActor
final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var enabled = UserDefaults.standard.object(forKey: "conversionEnabled") as? Bool ?? true
    @Published var groups = Model.loadGroups()
    @Published var ansiTrigger = Model.loadTrigger("trigger.ansi", .fn)
    @Published var jisTrigger = Model.loadTrigger("trigger.jis", .capsLock)
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    @Published var paused = false
    @Published var trusted = AccessibilitySection.isTrusted
    @Published var tapRunning = false
    @Published var excludedFront: String?
    let tap = NumpadTap()
    let commaTyper = CommaTyper()
    let capsLockGuard = CapsLockGuard()
    private var observers: [NSObjectProtocol] = []
    private var workspaceObserver: NSObjectProtocol?
    private var accessibilityObserver: NSObjectProtocol?

    init() {
        let typer = commaTyper
        tap.onComma = { flags in MainActor.assumeIsolated { typer.type(flags: flags) } }
        let caps = capsLockGuard
        tap.onCapsToggle = { on in MainActor.assumeIsolated { caps.toggled(to: on) } }
        tap.onCapsUsed = { MainActor.assumeIsolated { caps.markUsed() } }
        // Event-driven (B13): app switches, returning to FnNumpad, and changes to the Accessibility list.
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        // AXIsProcessTrusted turns true a moment after the switch in System Settings.
        accessibilityObserver = DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { MainActor.assumeIsolated { self?.refresh() } }
        }
        refresh()
    }

    static func loadTrigger(_ key: String, _ initial: TriggerKey) -> TriggerKey {
        UserDefaults.standard.string(forKey: key).flatMap(TriggerKey.init(rawValue:)) ?? initial
    }

    static func loadGroups() -> Set<KeyGroup> {
        Set(KeyGroup.allCases.filter { UserDefaults.standard.object(forKey: $0.defaultsKey) as? Bool ?? true })
    }

    func save() {
        defaults.set(enabled, forKey: "conversionEnabled")
        for group in KeyGroup.allCases { defaults.set(groups.contains(group), forKey: group.defaultsKey) }
        defaults.set(keepRunning, forKey: "keepRunning")
        defaults.set(ansiTrigger.rawValue, forKey: "trigger.ansi")
        defaults.set(jisTrigger.rawValue, forKey: "trigger.jis")
        refresh()
    }

    /// Re-reads the shared settings after SettingsSync applied them; save() would otherwise write the old values back.
    func reload() {
        enabled = defaults.object(forKey: "conversionEnabled") as? Bool ?? true
        groups = Model.loadGroups()
        ansiTrigger = Model.loadTrigger("trigger.ansi", .fn)
        jisTrigger = Model.loadTrigger("trigger.jis", .capsLock)
        refresh()
    }

    func group(_ group: KeyGroup) -> Binding<Bool> {
        Binding(get: { self.groups.contains(group) }, set: { on in
            if on { self.groups.insert(group) } else { self.groups.remove(group) }
            self.save()
        })
    }

    /// Starts the tap once Accessibility is granted and tells it whether to convert for the front app.
    func refresh() {
        trusted = AccessibilitySection.isTrusted
        if trusted { if !tap.isRunning { tap.start() } } else if tap.isRunning { tap.stop() }
        tapRunning = tap.isRunning
        let front = NSWorkspace.shared.frontmostApplication
        excludedFront = ExcludedApps.shared.excludes(front?.bundleIdentifier) ? (front?.localizedName ?? front?.bundleIdentifier ?? "") : nil
        tap.update(TapState(active: enabled && !paused && excludedFront == nil, groups: groups, ansiTrigger: ansiTrigger, jisTrigger: jisTrigger))
    }

    var problem: Bool { !trusted || !tapRunning || !enabled || paused }
    var status: String {
        if !trusted { return L("status.denied") }
        if !tapRunning { return L("status.tapFailed") }
        if !enabled { return L("status.off") }
        if paused { return L("status.paused") }
        if groups.isEmpty { return L("status.noGroups") }
        if let excludedFront { return String(format: L("status.excluded"), excludedFront) }
        return L("status.active")
    }

    /// The group converts now (shown in colour on the keyboard).
    func isOn(_ group: KeyGroup) -> Bool { enabled && groups.contains(group) }

    func togglePause() { paused.toggle(); refresh() }

    /// The 「対象外アプリ」 list changed: decide again for the front app.
    func excludedAppsChanged() { refresh() }

    func stop() {
        tap.stop()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        if let accessibilityObserver { DistributedNotificationCenter.default().removeObserver(accessibilityObserver) }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

extension KeyGroup {
    var title: String { L("group." + rawValue) }
    var hint: String { L("group." + rawValue + ".hint") }
    var shortTitle: String { L("group." + rawValue + ".short") }
}

extension TriggerKey {
    var title: String { L("triggerKey." + rawValue) }
}

/// Shared header (AppHeader.swift): current bundle icon, functional title and subtitle.
struct HeaderView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView { appHeader(L("headerTitle"), subtitle: L("headerSubtitle")) }
    func updateNSView(_ view: NSStackView, context: Context) {}
}

struct StatusRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).foregroundColor(tint).frame(width: 18).accessibilityHidden(true)
            Text(title).foregroundColor(.secondary).frame(width: 110, alignment: .leading)
            Text(value).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title + ": " + value)
    }
}

/// One key of the table: 「Fn U」 → 「4」.
struct KeyChip: View {
    let mapping: KeyMapping
    let on: Bool
    var body: some View {
        HStack(spacing: 4) {
            Text("fn " + mapping.fromLabel).font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary)
            Image(systemName: "arrow.right").font(.system(size: 9)).foregroundColor(.secondary).accessibilityHidden(true)
            Text(mapping.toLabel).font(.system(size: 12, weight: .semibold, design: .monospaced))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
        .opacity(on ? 1 : 0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: L("chipLabel"), mapping.fromLabel, mapping.toLabel))
    }
}

struct GroupKeys: View {
    let group: KeyGroup
    let on: Bool
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(KeyMap.mappings(in: group)) { KeyChip(mapping: $0, on: on) }
        }
    }
}

struct MainView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderView().fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                StatusRow(symbol: model.problem ? "exclamationmark.triangle.fill" : "keyboard", tint: model.problem ? .orange : .secondary,
                          title: L("statusRow"), value: model.status)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .border(Color(nsColor: .separatorColor), width: 1)
            KeyboardView(model: model)
            Spacer(minLength: 0)
            HStack {
                Button(L("settingsButton")) { (NSApp.delegate as? AppDelegate)?.showPreferences() }
                Spacer()
                Toggle(L("enable"), isOn: Binding(get: { model.enabled }, set: { model.enabled = $0; model.save() }))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 720, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
    }
}

struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) {
                    // LoginAtLaunchView already includes 起動時にメインウインドウを表示しない and the Dock option.
                    LoginAtLaunchView()
                    Toggle(L("keepRunning"), isOn: Binding(get: { model.keepRunning }, set: { model.keepRunning = $0; model.save() }))
                    Text(L("keepRunningHint")).font(.caption).foregroundColor(.secondary)
                    MenuBarPresenceView()
                }
                AccessibilitySection()
            })),
            (L("keysTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("conversionTitle")) {
                    Toggle(L("enable"), isOn: Binding(get: { model.enabled }, set: { model.enabled = $0; model.save() }))
                    Text(L("enableHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("triggerTitle")) {
                    Picker(L("trigger.ansi"), selection: Binding(get: { model.ansiTrigger }, set: { model.ansiTrigger = $0; model.save() })) {
                        ForEach(TriggerKey.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).fixedSize()
                    Picker(L("trigger.jis"), selection: Binding(get: { model.jisTrigger }, set: { model.jisTrigger = $0; model.save() })) {
                        ForEach(TriggerKey.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).fixedSize()
                    Text(L("triggerHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .disabled(!model.enabled)
                ForEach(KeyGroup.allCases) { group in
                    SettingsSection(group.title) {
                        Toggle(L("useGroup"), isOn: model.group(group))
                        GroupKeys(group: group, on: model.groups.contains(group))
                        Text(group.hint).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .disabled(!model.enabled)
                }
            })),
            (ExcludedApps.title, AnyView(SettingsSection(ExcludedApps.title) { ExcludedAppsView() })),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, NSMenuItemValidation {
    var model: Model!
    var item: NSStatusItem!
    var mainWindow: NSWindow?
    var preferences: NSWindow?
    var helpWindow: NSWindow?
    let menu = NSMenu()
    var statusItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        ExcludedApps.shared.configure(explanation: L("excluded.explanation"))
        model = Model()
        ExcludedApps.shared.onChange = { [weak self] in self?.model.excludedAppsChanged() }
        SettingsSync.shared.onImport = { [weak self] in self?.model.reload() }
        SettingsSync.shared.start(.init(
            keys: Set(["conversionEnabled", "trigger.ansi", "trigger.jis"] + KeyGroup.allCases.map(\.defaultsKey)),
            note: StartupWindow.text("テンキー変換のオン・オフと、使うキーのグループを書き出し・同期します。",
                                     "Exports and syncs whether conversion is on and which key groups are used.",
                                     "导出并同步数字键盘转换的开关以及使用的按键组。",
                                     "숫자 키패드 변환의 켜기/끄기와 사용할 키 그룹을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・常駐・メニューバー・対象外アプリはMacごとに設定します。",
                                       "Launch at login, staying open, the menu bar icon and excluded apps are set on each Mac.",
                                       "登录时启动、常驻、菜单栏图标和排除的应用需在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 상주, 메뉴 막대 아이콘, 제외할 앱은 Mac마다 설정합니다.")))
        AccessibilityText.neededOverride = [
            "Fnキーを押しながら押したキーを受け取り、テンキーのキーに置き換えるために使用します。未許可の場合、Fn＋J などを押しても変換されません。",
            "Used to receive the keys you press while holding Fn and replace them with keypad keys. Without permission, Fn+J and the others are not converted.",
            "用于接收按住 Fn 时按下的键，并将其替换为数字键盘按键。未获授权时，按 Fn+J 等不会转换。",
            "Fn 키를 누른 채 누른 키를 받아 숫자 키패드 키로 바꾸는 데 사용합니다. 권한이 없으면 Fn+J 등을 눌러도 변환되지 않습니다."
        ]
        WindowActivationPolicy.install()
        buildMainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.setAccessibilityLabel("FnNumpad")
        menu.delegate = self
        statusItem = menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, L("openMainWindow"), #selector(openMainWindow))
        add(menu, L("settings"), #selector(showPreferences))
        add(menu, L("pause"), #selector(togglePause))
        menu.addItem(.separator())
        // Help submenu: app help and the note article (BASELINE「メニューの共通構成」).
        let statusHelp = NSMenu(title: L("help")); add(statusHelp, L("appHelp"), #selector(help)); MainActor.assumeIsolated { HelpLinks.addNoteItem(to: statusHelp) }
        menu.setSubmenu(statusHelp, for: menu.addItem(withTitle: L("help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator()); add(menu, L("quit"), #selector(quit))
        item.menu = menu
        MainActor.assumeIsolated {
            MenuBarPresence.shared.install(name: "FnNumpad", symbol: "number.square", existing: item,
                show: { [weak self] in self?.showMainWindow() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in self?.help() })
        }
        if !LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent) && !StartupWindow.hidden { showMainWindow() }
    }

    private func buildMainMenu() {
        let main = NSMenu(); let root = NSMenuItem(); let appMenu = NSMenu()
        main.addItem(root); root.submenu = appMenu
        add(appMenu, L("about"), #selector(about))
        appMenu.addItem(.separator())
        add(appMenu, L("settings"), #selector(showPreferences), ",")
        appMenu.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        MainActor.assumeIsolated { AppUpdates.shared.addMenuItems(to: appMenu) }
        #endif
        let services = NSMenu(title: L("services"))
        appMenu.addItem(withTitle: L("services"), action: nil, keyEquivalent: "").submenu = services
        NSApp.servicesMenu = services
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: L("hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: L("showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        add(appMenu, L("quit"), #selector(quit), "q")
        let fileRoot = NSMenuItem(); let fileMenu = NSMenu(title: L("file")); fileRoot.submenu = fileMenu; main.addItem(fileRoot)
        add(fileMenu, L("openMainWindow"), #selector(openMainWindow), "0")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: L("closeWindow"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let editRoot = NSMenuItem(); let editMenu = NSMenu(title: L("edit")); editRoot.submenu = editMenu; main.addItem(editRoot)
        for (key, selector, equivalent) in [("undo", Selector(("undo:")), "z"), ("redo", Selector(("redo:")), "Z"), ("cut", #selector(NSText.cut(_:)), "x"), ("copy", #selector(NSText.copy(_:)), "c"), ("paste", #selector(NSText.paste(_:)), "v"), ("selectAll", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(withTitle: L(key), action: selector, keyEquivalent: equivalent)
        }
        let windowRoot = NSMenuItem(); let windowMenu = NSMenu(title: L("window")); windowRoot.submenu = windowMenu; main.addItem(windowRoot)
        windowMenu.addItem(withTitle: L("minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: L("zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: L("bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
        let helpRoot = NSMenuItem(); let helpMenu = NSMenu(title: L("help")); helpRoot.submenu = helpMenu; main.addItem(helpRoot)
        add(helpMenu, L("appHelp"), #selector(help), "?")
        MainActor.assumeIsolated { HelpLinks.addNoteItem(to: helpMenu) }
        NSApp.mainMenu = main; NSApp.helpMenu = helpMenu
    }

    func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "") {
        let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: key); entry.target = self
    }
    func menuWillOpen(_ menu: NSMenu) {
        model.refresh()
        statusItem.title = model.status
        menu.items.first { $0.action == #selector(togglePause) }?.state = model.paused ? .on : .off
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Not available → disabled instead of a silent no-op (B27).
        if menuItem.action == #selector(togglePause) { menuItem.state = model.paused ? .on : .off; return model.enabled }
        return true
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMainWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !model.keepRunning }
    func windowWillClose(_ notification: Notification) {
        // Accessory applications also need an explicit last-window close path.
        guard let closing = notification.object as? NSWindow else { return }
        DispatchQueue.main.async { [weak self, weak closing] in
            guard let self, !self.model.keepRunning else { return }
            let otherVisible = NSApp.windows.contains { $0 !== closing && $0.isVisible && $0.canBecomeMain }
            if !otherVisible { NSApp.terminate(nil) }
        }
    }
    func applicationWillTerminate(_ notification: Notification) { model?.stop() }

    @objc func openMainWindow() { showMainWindow() }
    func showMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            // Native title bar unchanged; no app name in it (BASELINE「主画面の背景とタイトルバー」).
            window.title = ""
            window.titleVisibility = .hidden
            let content = NSView(frame: window.contentLayoutRect)
            AppSurface.install(in: content)
            let hosting = NSHostingView(rootView: MainView(model: model))
            hosting.sizingOptions = [.minSize]
            // The hosting view sits on the shared surface view, so size the window from the SwiftUI content.
            let fitting = hosting.fittingSize
            let size = NSSize(width: max(720, ceil(fitting.width)), height: max(520, ceil(fitting.height)))
            window.setContentSize(size)
            content.frame = NSRect(origin: .zero, size: size)
            hosting.frame = content.bounds
            hosting.autoresizingMask = [.width, .height]
            content.addSubview(hosting)
            window.contentView = content
            window.contentMinSize = size
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("MainWindow")
            mainWindow = window
        }
        if let window = mainWindow, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); mainWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func showPreferences() {
        model.refresh()
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 600), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle")
            let hosting = NSHostingView(rootView: Preferences(model: model))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.contentMinSize = NSSize(width: 640, height: 600)
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("Preferences"); preferences = window
        }
        if let window = preferences, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
    }
    @objc func help() {
        if helpWindow == nil { helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: "FnNumpad — " + L("help"), text: L("helpText"), heading: L("helpHeading")) } }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func togglePause() { model.togglePause() }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary ?? [:]
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "FnNumpad",
            .applicationVersion: "\(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))",
            .credits: NSAttributedString(string: L("support"))])
    }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
SingleInstanceLaunch.enforce()
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()

// Reused from PasteMatchStyle (BrowserSwitcher origin). Oldest process wins on simultaneous launch.
private enum SingleInstanceLaunch {
    static func enforce() {
        let current = NSRunningApplication.current
        guard let identifier = Bundle.main.bundleIdentifier else { return }
        var candidates = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).filter { !$0.isTerminated }
        if !candidates.contains(where: { $0.processIdentifier == current.processIdentifier }) { candidates.append(current) }
        candidates.sort {
            let left = $0.launchDate ?? .distantPast
            let right = $1.launchDate ?? .distantPast
            return left == right ? $0.processIdentifier < $1.processIdentifier : left < right
        }
        guard let existing = candidates.first, existing.processIdentifier != current.processIdentifier else { return }
        existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        if let url = existing.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in exit(0) }
            // Allow the reopen Apple event to reach hidden/menu-bar applications.
            RunLoop.main.run(until: Date().addingTimeInterval(2))
        }
        exit(0)
    }
}
