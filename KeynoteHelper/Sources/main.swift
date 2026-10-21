import AppKit
import SwiftUI
import ServiceManagement
import Carbon
import ApplicationServices

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// Keynote 14+ (com.apple.Keynote, including Keynote Creator Studio) and older iWork Keynote.
enum KeynoteApp {
    static let bundleIDs = ["com.apple.Keynote", "com.apple.iWork.Keynote"]
    static func isKeynote(_ app: NSRunningApplication?) -> Bool { bundleIDs.contains(app?.bundleIdentifier ?? "") }
    static var icon: NSImage? {
        for id in bundleIDs { if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return NSWorkspace.shared.icon(forFile: url.path) } }
        return nil
    }
}

@MainActor
final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var hotkeysEnabled = UserDefaults.standard.object(forKey: "hotkeysEnabled") as? Bool ?? true
    @Published var paused = false
    @Published var notifySuccess = UserDefaults.standard.object(forKey: "notifySuccess") as? Bool ?? true
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    /// Only changed keys are stored; a missing entry is the command's default.
    @Published var commandShortcuts = UserDefaults.standard.data(forKey: "commandShortcuts").flatMap { try? JSONDecoder().decode([String: Shortcut].self, from: $0) } ?? [:]
    /// Missing key = the command's default (on, except the KeynoteSweeper commands).
    @Published var commandEnabled = UserDefaults.standard.dictionary(forKey: "commandEnabled") as? [String: Bool] ?? [:]
    @Published var status = L("ready")
    @Published var statusIsError = false
    @Published var hotkeyStatus = ""
    @Published var hotkeyFailed = false
    /// Commands whose key could not be registered (shown under that row).
    @Published var failedCommands: Set<String> = []
    @Published var loginStatus = ""
    @Published var loginOn = false
    /// 100 + n = KeynoteCommand.allCases[n]. Paused by HotkeySet while a key is recorded.
    let hotkeys = HotkeySet(signature: "KNHK")
    static func number(_ command: KeynoteCommand) -> UInt32 { 100 + UInt32(KeynoteCommand.allCases.firstIndex(of: command)!) }
    let runner = CommandRunner()
    private var observers: [NSObjectProtocol] = []
    private var workspaceObserver: NSObjectProtocol?
    /// What is registered now; app switches re-register only when this changes.
    private var registeredState: String?

    init() {
        hotkeys.action = { [weak self] number in
            guard let self, let command = KeynoteCommand.allCases.first(where: { Self.number($0) == number }) else { return }
            self.runCommand(command)
        }
        // After recording, register again so a conflict with another app is reported.
        HotkeyRecorder.shared.onRecordingChanged.append { [weak self] recording in
            guard let self, !recording else { return }
            self.registeredState = nil; self.refreshHotkeys()
        }
        // Event-driven: the keys exist only while Keynote is in front (B13), so other apps keep them.
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshHotkeys() }
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLogin(); self?.refreshHotkeys() }
        })
        refreshLogin(); refreshHotkeys()
    }

    func save() {
        defaults.set(hotkeysEnabled, forKey: "hotkeysEnabled")
        defaults.set(notifySuccess, forKey: "notifySuccess")
        defaults.set(keepRunning, forKey: "keepRunning")
        defaults.set(commandEnabled, forKey: "commandEnabled")
        defaults.set(try? JSONEncoder().encode(commandShortcuts), forKey: "commandShortcuts")
        refreshHotkeys()
    }

    /// Re-reads the shared settings after SettingsSync applied them; save() would otherwise write the old values back.
    func reload() {
        hotkeysEnabled = defaults.object(forKey: "hotkeysEnabled") as? Bool ?? true
        notifySuccess = defaults.object(forKey: "notifySuccess") as? Bool ?? true
        commandShortcuts = defaults.data(forKey: "commandShortcuts").flatMap { try? JSONDecoder().decode([String: Shortcut].self, from: $0) } ?? [:]
        commandEnabled = defaults.dictionary(forKey: "commandEnabled") as? [String: Bool] ?? [:]
        registeredState = nil
        refreshHotkeys()
    }

    func isEnabled(_ command: KeynoteCommand) -> Bool { commandEnabled[command.rawValue] ?? command.enabledByDefault }
    func setEnabled(_ command: KeynoteCommand, _ value: Bool) { commandEnabled[command.rawValue] = value; save() }
    func setEnabled(_ category: CommandCategory, _ value: Bool) {
        for command in category.commands { commandEnabled[command.rawValue] = value }
        save()
    }
    func shortcut(for command: KeynoteCommand) -> Shortcut { commandShortcuts[command.rawValue] ?? command.defaultShortcut }
    func combo(_ command: KeynoteCommand) -> KeyCombo { shortcut(for: command).combo }
    /// Only changed keys are stored: the default is kept as a missing entry.
    func setCombo(_ command: KeynoteCommand, _ combo: KeyCombo?) {
        guard let combo else { return }
        commandShortcuts[command.rawValue] = combo == command.defaultShortcut.combo ? nil : Shortcut(combo)
        save()
    }
    func resetAllShortcuts() { commandShortcuts = [:]; save() }
    /// Every hotkey of the app with its title, for refusing the same key twice.
    func otherHotkeys(except command: KeynoteCommand) -> [(String, KeyCombo)] {
        KeynoteCommand.allCases.filter { $0 != command }.map { (L("command." + $0.rawValue), combo($0)) }
    }
    var activeCount: Int { KeynoteCommand.allCases.filter(isEnabled).count }
    func togglePause() { paused.toggle(); refreshHotkeys() }

    /// Each key is registered once to detect a conflict, then kept only while Keynote is in front.
    func refreshHotkeys() {
        publishHotkeys()
        let front = KeynoteApp.isKeynote(NSWorkspace.shared.frontmostApplication)
        let wanted = hotkeysEnabled && !paused
        let commands = wanted ? KeynoteCommand.allCases.filter(isEnabled) : []
        let state = "\(wanted):\(front):\(commands.map { $0.rawValue + "=" + shortcut(for: $0).signature })"
        guard state != registeredState else { return }
        registeredState = state
        var failed: [String] = []
        var failedIDs: Set<String> = []
        for command in KeynoteCommand.allCases {
            let number = Self.number(command)
            guard commands.contains(command) else { hotkeys.unregister(number); continue }
            if hotkeys.register(number, combo(command)) != noErr { failed.append(shortcut(for: command).label); failedIDs.insert(command.rawValue) }
            if !front { hotkeys.unregister(number) }
        }
        failedCommands = failedIDs
        hotkeyFailed = !failed.isEmpty
        if !hotkeysEnabled { hotkeyStatus = L("hotkeyDisabled") }
        else if paused { hotkeyStatus = L("hotkeyPaused") }
        else if commands.isEmpty { hotkeyStatus = L("commandsOff") }
        else if hotkeyFailed { hotkeyStatus = String(format: L("commandsRegisterFailed"), failed.joined(separator: " ")) }
        else { hotkeyStatus = String(format: L("commandsActive"), String(commands.count)) }
    }

    /// Declares the hotkeys for HotkeyHound (shared registrations cannot be listed from outside).
    func publishHotkeys() {
        HotkeyManifest.publish(KeynoteCommand.allCases.map { command in
            HotkeyManifest.Item(id: command.rawValue, title: L("command." + command.rawValue), keyCode: Int(shortcut(for: command).code),
                                modifiers: Int(shortcut(for: command).modifiers), enabled: hotkeysEnabled && isEnabled(command),
                                scope: "only", apps: KeynoteApp.bundleIDs)
        })
    }

    func runCommand(_ command: KeynoteCommand) {
        guard hotkeysEnabled, !paused, isEnabled(command),
              let front = NSWorkspace.shared.frontmostApplication, KeynoteApp.isKeynote(front), let bundleID = front.bundleIdentifier else { return }
        let pid = front.processIdentifier
        let key = shortcut(for: command)
        guard AccessibilitySection.isTrusted else { report(.failure(AccessibilityText.text("blocked"))); return }
        // ⌥L or ⇧1 while typing in a text box: the character, not the command (text commands excepted).
        if key.typesCharacter, !command.worksWhileTyping, CommandRunner.isEditingText(pid: pid) { CommandRunner.passThrough(key, to: pid); return }
        if runner.busy { report(.failure(L("fail.busy"))); return }
        runner.run(command, pid: pid, bundleID: bundleID) { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .done: self.report(.success(String(format: L("success.done"), L("command." + command.rawValue)), notify: false))
            case .passThrough: CommandRunner.passThrough(key, to: pid)
            case .scripted(let count): self.report(Self.scriptMessage(command, count: count))
            case .menuNotFound: self.report(.failure(L("fail.menu")))
            case .buttonNotFound: self.report(.failure(L("fail.button")))
            case .serviceMissing: self.report(.failure(L("fail.sweeper")))
            case .serviceStarted: self.report(.success(String(format: L("sweeper.started"), L("command." + command.rawValue)), notify: false))
            case .eventFailed: self.report(.failure(L("fail.event")))
            case .noDocument: self.report(.failure(L("fail.noDocument")))
            case .automationDenied: self.report(.failure(L("fail.automation")))
            case .scriptFailed(let code): self.report(.failure(String(format: L("fail.script"), String(code))))
            case .exporting: self.report(.success(L("export.running"), notify: true))
            case .exported(let url):
                self.report(.success(String(format: L("export.done"), url.lastPathComponent), notify: true))
                NSWorkspace.shared.activateFileViewerSelecting([url])
            case .exportNeedsSave: self.report(.failure(L("export.needsSave")))
            case .exportFailed(let code): self.report(.failure(code == -1743 ? L("fail.automation") : String(format: L("export.failed"), String(code))))
            }
        }
    }

    enum Report { case success(String, notify: Bool = true), failure(String) }

    /// Results of the AppleScript commands; 0 means nothing was selected (or nothing to change).
    static func scriptMessage(_ command: KeynoteCommand, count: Int) -> Report {
        let name = L("command." + command.rawValue)
        switch command.category {
        case .transition:
            return .success(String(format: L("result.done"), name))
        default:
            if command == .showHidden { return .success(count == 0 ? L("result.noneHidden") : String(format: L("result.shown"), String(count))) }
            if command == .slideSizeShape || command == .centerCross { return .success(String(format: L("result.done"), name), notify: false) }
            if count == 0 { return .failure(command == .sameHeight || command == .sameWidth || command == .sameWidthNarrowest ? L("result.selectTwo") : L("result.selectFirst")) }
            if command == .hide { return .success(String(format: L("result.hidden"), String(count))) }
            return .success(String(format: L("result.objects"), name, String(count)), notify: false)
        }
    }

    func report(_ result: Report) {
        switch result {
        case .success(let message, let notify):
            status = message
            statusIsError = false
            if notify && notifySuccess { TransientMessage.show(message) }
        case .failure(let reason):
            status = reason
            statusIsError = true
            NSSound.beep()
            // Never just a beep (B27): the reason is shown near the top of the screen.
            TransientMessage.show(reason)
        }
    }

    func refreshLogin() {
        let state = SMAppService.mainApp.status
        loginOn = state == .enabled || state == .requiresApproval
        switch state {
        case .enabled: loginStatus = L("loginEnabled")
        case .requiresApproval: loginStatus = L("loginApproval")
        case .notFound: loginStatus = Model.isInApplicationsFolder ? L("loginDisabled") : L("loginNotFound")
        default: loginStatus = L("loginDisabled")
        }
    }
    static var isInApplicationsFolder: Bool {
        let parent = Bundle.main.bundleURL.resolvingSymlinksInPath().deletingLastPathComponent().standardizedFileURL.path
        let folders = ["/Applications", FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").standardizedFileURL.path]
        return folders.contains { parent == $0 || parent.hasPrefix($0 + "/") }
    }
    func changeLogin(_ value: Bool) {
        do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; refreshLogin() }
        catch { refreshLogin(); loginStatus = L("loginFailed") + error.localizedDescription }
    }

    func stop() {
        hotkeys.unregisterAll()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
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
            Text(title).foregroundColor(.secondary).frame(width: 130, alignment: .leading)
            Text(value).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title + ": " + value)
    }
}

struct MainView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderView().fixedSize(horizontal: false, vertical: true)
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    // The master switch sits where its effect is shown, not inside Settings.
                    Toggle(HotkeyText.enable, isOn: Binding(get: { model.hotkeysEnabled }, set: { model.hotkeysEnabled = $0; model.save() }))
                    Divider()
                    StatusRow(symbol: model.hotkeyFailed ? "exclamationmark.triangle.fill" : (model.hotkeysEnabled && !model.paused ? "keyboard" : "pause.circle"),
                              tint: model.hotkeyFailed ? .orange : .secondary, title: L("hotkeyTab"), value: model.hotkeyStatus)
                    StatusRow(symbol: AccessibilitySection.isTrusted ? "checkmark.circle.fill" : "minus.circle",
                              tint: AccessibilitySection.isTrusted ? .green : .secondary, title: AccessibilityText.text("title"),
                              value: AccessibilityText.text(AccessibilitySection.isTrusted ? "allowed" : "denied"))
                    StatusRow(symbol: model.statusIsError ? "xmark.octagon.fill" : "play.rectangle",
                              tint: model.statusIsError ? .red : .secondary, title: L("lastResult"), value: model.status)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            GroupBox(label: Text(L("target")).font(.system(size: 13, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if let icon = KeynoteApp.icon { Image(nsImage: icon).resizable().frame(width: 20, height: 20).accessibilityHidden(true) }
                        Text("Keynote")
                        Text(KeynoteApp.bundleIDs.joined(separator: " / ")).font(.caption).foregroundColor(.secondary)
                    }
                    Text(L("targetHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            HStack {
                Button(L("settingsButton")) { (NSApp.delegate as? AppDelegate)?.showPreferences() }
                Button(L("showKeys")) { (NSApp.delegate as? AppDelegate)?.showPreferences(tab: 1) }
                Spacer()
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
    }
}

struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) {
                    Toggle(L("login"), isOn: Binding(get: { model.loginOn }, set: { model.changeLogin($0) }))
                    Text(model.loginStatus).font(.caption).foregroundColor(.secondary)
                    Button(L("loginSettings")) { SMAppService.openSystemSettingsLoginItems() }
                    StartupWindowView()
                    Toggle(L("keepRunning"), isOn: Binding(get: { model.keepRunning }, set: { model.keepRunning = $0; model.save() }))
                    Text(L("keepRunningHint")).font(.caption).foregroundColor(.secondary)
                    MenuBarPresenceView()
                }
                AccessibilitySection()
            })),
            (L("hotkeyTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("hotkeyTab")) {
                    Text(model.hotkeyStatus).font(.caption).foregroundColor(model.hotkeyFailed ? .red : .secondary).fixedSize(horizontal: false, vertical: true)
                    Text(L("commandsHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button(L("resetAllKeys")) { model.resetAllShortcuts() }
                }
                ForEach(CommandCategory.allCases, id: \.self) { category in
                    SettingsSection(L("category." + category.rawValue)) {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                            ForEach(category.commands, id: \.self) { command in
                                GridRow {
                                    Toggle(L("command." + command.rawValue), isOn: Binding(get: { model.isEnabled(command) }, set: { model.setEnabled(command, $0) }))
                                        .disabled(!model.hotkeysEnabled)
                                    HotkeyField(id: command.rawValue, combo: Binding(get: { model.combo(command) }, set: { model.setCombo(command, $0) }),
                                                defaultCombo: command.defaultShortcut.combo, others: model.otherHotkeys(except: command),
                                                registered: !model.failedCommands.contains(command.rawValue),
                                                isEnabled: model.hotkeysEnabled && model.isEnabled(command),
                                                // ⌥L, ⌥1 … and ⇧1 … are KM defaults without ⌘ or ⌃.
                                                allowsOption: command.defaultShortcut.typesCharacter)
                                        .controlSize(.small)
                                }
                            }
                        }
                        HStack {
                            Button(L("enableCategory")) { model.setEnabled(category, true) }
                            Button(L("disableCategory")) { model.setEnabled(category, false) }
                        }.controlSize(.small).disabled(!model.hotkeysEnabled)
                    }
                }
                SettingsSection(L("notifyTitle")) {
                    Toggle(L("notifySuccess"), isOn: Binding(get: { model.notifySuccess }, set: { model.notifySuccess = $0; model.save() }))
                    Text(L("notifyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 680, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
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
    var resultItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = Model()
        SettingsSync.shared.onImport = { [weak self] in self?.model.reload() }
        SettingsSync.shared.start(.init(
            keys: ["hotkeysEnabled", "notifySuccess", "commandEnabled", "commandShortcuts"],
            note: StartupWindow.text("Keynoteの操作のホットキー（オン・オフとキー）と通知を書き出し・同期します。",
                                     "Exports and syncs the Keynote command hotkeys (on/off and keys) and notifications.",
                                     "导出并同步 Keynote 操作的快捷键（开关与按键）和通知。",
                                     "Keynote 작업의 단축키(켜기/끄기와 키)와 알림을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・常駐・メニューバーはMacごとに設定します。",
                                       "Launch at login, staying open and the menu bar icon are set on each Mac.",
                                       "登录时启动、常驻和菜单栏图标需在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 상주, 메뉴 막대 아이콘은 Mac마다 설정합니다.")))
        AccessibilityText.neededOverride = [
            "Keynoteのメニュー項目を押したり、キーを送ったりするために使用します。未許可の場合、ホットキーを押してもKeynoteを操作できません。",
            "Used to press Keynote's menu items and send keys to it. Without permission, the hotkeys cannot operate Keynote.",
            "用于点按 Keynote 的菜单项并向其发送按键。未获授权时，按快捷键无法操作 Keynote。",
            "Keynote의 메뉴 항목을 누르고 키를 보내는 데 사용합니다. 권한이 없으면 단축키로 Keynote를 조작할 수 없습니다."
        ]
        WindowActivationPolicy.install()
        buildMainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.setAccessibilityLabel("KeynoteHelper")
        menu.delegate = self
        resultItem = menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, L("openMainWindow"), #selector(openMainWindow))
        add(menu, L("settings"), #selector(showPreferencesAction))
        add(menu, L("pause"), #selector(togglePause))
        menu.addItem(.separator())
        // Help submenu: app help and the note article (BASELINE「メニューの共通構成」).
        let statusHelp = NSMenu(title: L("help")); add(statusHelp, L("appHelp"), #selector(help)); HelpLinks.addNoteItem(to: statusHelp)
        menu.setSubmenu(statusHelp, for: menu.addItem(withTitle: L("help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator()); add(menu, L("quit"), #selector(quit))
        item.menu = menu
        MenuBarPresence.shared.install(name: "KeynoteHelper", symbol: "play.rectangle", existing: item,
            show: { [weak self] in self?.showMainWindow() },
            settings: { [weak self] in self?.showPreferences() },
            help: { [weak self] in self?.help() })
        if !LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent) && !StartupWindow.hidden { showMainWindow() }
    }

    private func buildMainMenu() {
        let main = NSMenu(); let root = NSMenuItem(); let appMenu = NSMenu()
        main.addItem(root); root.submenu = appMenu
        add(appMenu, L("about"), #selector(about))
        appMenu.addItem(.separator())
        add(appMenu, L("settings"), #selector(showPreferencesAction), ",")
        appMenu.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to: appMenu)
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
        HelpLinks.addNoteItem(to: helpMenu)
        NSApp.mainMenu = main; NSApp.helpMenu = helpMenu
    }

    func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "") {
        let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: key); entry.target = self
    }
    func menuWillOpen(_ menu: NSMenu) {
        resultItem.title = model.status
        menu.items.first { $0.action == #selector(togglePause) }?.state = model.paused ? .on : .off
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Not available → disabled instead of a silent no-op (B27).
        if menuItem.action == #selector(togglePause) { menuItem.state = model.paused ? .on : .off; return model.hotkeysEnabled }
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
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // A PNG export is still moving its file; quitting now would leave the temporary folder behind (B11).
        guard model.runner.busy else { return .terminateNow }
        model.report(.failure(L("quitBusy")))
        return .terminateCancel
    }
    func applicationWillTerminate(_ notification: Notification) { model?.stop() }

    @objc func openMainWindow() { showMainWindow() }
    func showMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 400), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            // Native title bar unchanged; no app name in it (BASELINE「主画面の背景とタイトルバー」).
            window.title = ""
            window.titleVisibility = .hidden
            let content = NSView(frame: window.contentLayoutRect)
            AppSurface.install(in: content)
            let hosting = NSHostingView(rootView: MainView(model: model))
            hosting.sizingOptions = [.minSize]
            // The hosting view sits on the shared surface view, so size the window from the SwiftUI content.
            let fitting = hosting.fittingSize
            let size = NSSize(width: max(560, ceil(fitting.width)), height: max(400, ceil(fitting.height)))
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
    @objc func showPreferencesAction() { showPreferences() }
    /// `tab` selects a tab by its index (the 「ホットキー一覧」 button of the main window opens 1, the hotkeys).
    func showPreferences(tab: Int? = nil) {
        model.refreshLogin()
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 620), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle")
            let hosting = NSHostingView(rootView: Preferences(model: model))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.contentMinSize = NSSize(width: 680, height: 560)
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("Preferences"); preferences = window
        }
        if let window = preferences, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
        preferences?.contentView?.layoutSubtreeIfNeeded()
        if let tab, let tabs = preferences?.contentView.flatMap(Self.tabView), tab < tabs.numberOfTabViewItems { tabs.selectTabViewItem(at: tab) }
    }
    private static func tabView(in view: NSView) -> NSTabView? {
        if let tabs = view as? NSTabView { return tabs }
        for child in view.subviews { if let tabs = tabView(in: child) { return tabs } }
        return nil
    }
    @objc func help() {
        if helpWindow == nil { helpWindow = HelpDocument.makeWindow(windowTitle: "KeynoteHelper — " + L("help"), text: L("helpText") + "\n\n" + keyList(), heading: L("helpHeading")) }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    /// The default keys by category, generated so the help never disagrees with the code.
    func keyList() -> String {
        "## " + L("help.defaultKeys") + "\n" + CommandCategory.allCases.map { category in
            "### " + L("category." + category.rawValue) + "\n" + category.commands.map { "- **\($0.defaultShortcut.label)** " + L("command." + $0.rawValue) }.joined(separator: "\n")
        }.joined(separator: "\n")
    }
    @objc func togglePause() { model.togglePause() }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary ?? [:]
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "KeynoteHelper",
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

// Reused from KakkoReplace (BrowserSwitcher origin). Oldest process wins on simultaneous launch.
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
