import AppKit
import SwiftUI
import ServiceManagement
import Carbon
import ApplicationServices
import UniformTypeIdentifiers

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var hotkeyEnabled = UserDefaults.standard.object(forKey: "hotkeyEnabled") as? Bool ?? true
    @Published var paused = false
    @Published var shortcut = UserDefaults.standard.data(forKey: "pasteShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .paste
    /// On: the app's own 「ペーストしてスタイルを合わせる」 etc. first, as the KM macros do.
    @Published var useMenu = UserDefaults.standard.object(forKey: "useMenu") as? Bool ?? true
    @Published var menuTitles = MenuTitles.load()
    /// On: the styled clipboard comes back after the plain-text paste. Off: it stays plain, like KM's 「Remove Styles」.
    @Published var restoreClipboard = UserDefaults.standard.object(forKey: "restoreClipboard") as? Bool ?? true
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    @Published var excluded = ExcludedAppList(ownID: Bundle.main.bundleIdentifier)
    @Published var recording = false
    @Published var status = L("ready")
    @Published var statusIsError = false
    @Published var hotkeyStatus = ""
    @Published var hotkeyFailed = false
    @Published var recordMessage = ""
    @Published var loginStatus = ""
    @Published var loginOn = false
    @Published var accessibilityAllowed = AXIsProcessTrusted()
    let hotkey = SingleHotKey(signature: 0x504D_5353)       // 'PMSS'
    let paster = PlainPaster()
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var observers: [NSObjectProtocol] = []
    private var workspaceObserver: NSObjectProtocol?
    private var monitor: Any?
    /// What is registered now; app switches re-register only when this changes.
    private var registeredState: String?

    init() {
        hotkey.action = { [weak self] in self?.trigger() }
        // Event-driven: the hotkey is released while an excluded app (or PasteMatchStyle itself) is in front (B13, B21).
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshHotkey()
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshLogin(); self?.refreshAccessibility(); self?.refreshHotkey()
        })
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.recording else { return event }
            if event.keyCode == 53 { self.recording = false; self.recordMessage = ""; self.refreshHotkey(); return nil }
            guard let candidate = Shortcut.recorded(keyCode: event.keyCode, flags: event.modifierFlags, characters: event.charactersIgnoringModifiers) else {
                self.recordMessage = L("invalidShortcut"); return nil
            }
            self.shortcut = candidate; self.hotkeyEnabled = true
            self.recording = false; self.recordMessage = ""; self.save(); return nil
        }
        refreshLogin(); refreshHotkey()
    }

    func save() {
        defaults.set(hotkeyEnabled, forKey: "hotkeyEnabled")
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: "pasteShortcut")
        defaults.set(useMenu, forKey: "useMenu")
        MenuTitles.save(menuTitles)
        defaults.set(restoreClipboard, forKey: "restoreClipboard")
        defaults.set(keepRunning, forKey: "keepRunning")
        refreshHotkey()
    }

    /// The hotkey passes through to the front app while it is excluded or PasteMatchStyle itself.
    func blocked(_ app: NSRunningApplication?) -> Bool {
        excluded.blocksHotkeys(bundleID: app?.bundleIdentifier, pid: app?.processIdentifier, ownPID: ownPID)
    }

    func refreshHotkey() {
        publishHotkeys()
        let wanted = hotkeyEnabled && !paused && !recording
        let front = !blocked(NSWorkspace.shared.frontmostApplication)
        let state = "\(wanted):\(front):\(shortcut.signature)"
        guard state != registeredState else { return }
        registeredState = state
        // Registered to detect a conflict even while an excluded app is in front; then released at once so the key passes through.
        var result: OSStatus = noErr
        if wanted {
            result = hotkey.register(shortcut)
            if !front { hotkey.register(nil) }
        } else {
            hotkey.register(nil)
        }
        hotkeyFailed = wanted && result != noErr
        if !hotkeyEnabled { hotkeyStatus = L("hotkeyDisabled") }
        else if paused { hotkeyStatus = L("hotkeyPaused") }
        else if recording { hotkeyStatus = L("recordHint") }
        else if hotkeyFailed { hotkeyStatus = String(format: L("hotkeyRegisterFailed"), shortcut.label, String(result)) }
        else { hotkeyStatus = String(format: L("hotkeyActive"), shortcut.label) }
    }

    /// Declares the hotkey for HotkeyHound (shared registrations cannot be listed from outside).
    func publishHotkeys() {
        HotkeyManifest.publish([
            HotkeyManifest.Item(id: "paste", title: L("pasteHotkey"), keyCode: Int(shortcut.code), modifiers: Int(shortcut.modifiers),
                                enabled: hotkeyEnabled, scope: excluded.ids.isEmpty ? "all" : "except", apps: excluded.ids)
        ])
    }

    func startRecording() {
        recording.toggle()
        recordMessage = recording ? L("recordHint") : ""
        refreshHotkey()
    }
    func resetShortcut() {
        shortcut = .paste; hotkeyEnabled = true; recording = false; recordMessage = ""; save()
    }
    func togglePause() { paused.toggle(); refreshHotkey() }

    func trigger() {
        guard hotkeyEnabled, !paused, !recording, let front = NSWorkspace.shared.frontmostApplication, !blocked(front) else { return }
        let pid = front.processIdentifier
        let outcome = paster.paste(appName: front.localizedName ?? "", pid: pid, useMenu: useMenu, titles: menuTitles,
                                   restoreClipboard: restoreClipboard, stillTarget: { [weak self] in
            guard let self, let now = NSWorkspace.shared.frontmostApplication, now.processIdentifier == pid else { return false }
            return self.hotkeyEnabled && !self.paused && !self.blocked(now)
        })
        switch outcome {
        case .menu(let appName, let title):
            status = String(format: L("success.menu"), appName, title); statusIsError = false
        case .plain(let appName):
            status = String(format: restoreClipboard ? L("success.plain") : L("success.plainKept"), appName); statusIsError = false
        case .failed(let reason):
            fail(reason)
        }
        refreshAccessibility()
    }

    /// Never just a beep (B27): the reason is shown near the top of the screen.
    func fail(_ reason: String) {
        status = reason; statusIsError = true
        NSSound.beep()
        MainActor.assumeIsolated { TransientMessage.show(reason) }
    }

    func stripClipboard() {
        if paster.stripClipboard() { status = L("stripped"); statusIsError = false }
        else { fail(L("fail.noText")) }
    }

    func setMenuTitles(_ text: String) { menuTitles = MenuTitles.parse(text); save() }
    func resetMenuTitles() { menuTitles = MenuTitles.initial; save() }

    func refreshAccessibility() { accessibilityAllowed = AXIsProcessTrusted() }

    func addExcluded(_ urls: [URL]) -> [String] {
        var rejected: [String] = []
        for url in urls {
            let name = appDisplayName(url)
            switch excluded.add(Bundle(url: url)?.bundleIdentifier) {
            case .added: break
            case .duplicate: rejected.append(String(format: L("excluded.duplicate"), name))
            case .own: rejected.append(L("excluded.own"))
            case .invalid: rejected.append(String(format: L("excluded.invalid"), name))
            }
        }
        excluded.save(); registeredState = nil; refreshHotkey()
        return rejected
    }
    func removeExcluded(_ ids: Set<String>) {
        ids.forEach { excluded.remove($0) }
        excluded.save(); registeredState = nil; refreshHotkey()
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
        hotkey.register(nil)
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

func appDisplayName(_ url: URL) -> String {
    let name = FileManager.default.displayName(atPath: url.path)
    return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
}
/// Name and icon of an installed app; a missing app shows its Bundle ID.
func appInfo(_ bundleID: String) -> (name: String, icon: NSImage, missing: Bool) {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
        return (appDisplayName(url), NSWorkspace.shared.icon(forFile: url.path), false)
    }
    return (bundleID, NSWorkspace.shared.icon(for: .applicationBundle), true)
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
            VStack(alignment: .leading, spacing: 10) {
                // Only a problem that stops the hotkey is shown above the result (B09, B27).
                if !model.accessibilityAllowed {
                    StatusRow(symbol: "exclamationmark.triangle.fill", tint: .orange, title: AccessibilityText.text("title"),
                              value: AccessibilityText.text("denied"))
                } else if model.hotkeyFailed || !model.hotkeyEnabled || model.paused {
                    StatusRow(symbol: "exclamationmark.triangle.fill", tint: .orange, title: L("hotkeyRow"), value: model.hotkeyStatus)
                } else {
                    StatusRow(symbol: "keyboard", tint: .secondary, title: L("hotkeyRow"), value: model.hotkeyStatus)
                }
                StatusRow(symbol: model.statusIsError ? "xmark.circle.fill" : "checkmark.circle", tint: model.statusIsError ? .red : .secondary,
                          title: L("lastResult"), value: model.status)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .border(Color(nsColor: .separatorColor), width: 1)
            Text(L("mainHint")).font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack {
                Button(L("settingsButton")) { (NSApp.delegate as? AppDelegate)?.showPreferences() }
                Button(L("help")) { (NSApp.delegate as? AppDelegate)?.help() }
                Spacer()
                Button(L("strip")) { model.stripClipboard() }.help(L("stripHint"))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 340, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
    }
}

struct ShortcutRow: View {
    @ObservedObject var model: Model
    var body: some View {
        HStack {
            Text(model.shortcut.label).font(.system(size: 14, weight: .medium)).tracking(3).frame(width: 110).accessibilityLabel(L("currentKey") + " " + model.shortcut.label)
            Button(model.recording ? L("cancelRecording") : L("change")) { model.startRecording() }
            Button(L("resetShortcut")) { model.resetShortcut() }
        }.disabled(!model.hotkeyEnabled && !model.recording)
    }
}

/// The menu titles, one per line. Saved when the editor loses focus or the window closes.
struct MenuTitlesEditor: View {
    @ObservedObject var model: Model
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $text)
                .font(.system(size: 13))
                .focused($focused)
                .frame(height: 180)
                .border(Color(nsColor: .separatorColor), width: 1)
                .accessibilityLabel(L("menuTitlesTitle"))
                .onChange(of: focused) { now in if !now { model.setMenuTitles(text) } }
                .onDisappear { model.setMenuTitles(text) }
            HStack {
                Button(L("resetTitles")) { model.resetMenuTitles(); text = model.menuTitles.joined(separator: "\n") }
                Text(String(format: L("titlesCount"), String(model.menuTitles.count))).font(.caption).foregroundColor(.secondary)
            }
        }
        .disabled(!model.useMenu)
        .onAppear { text = model.menuTitles.joined(separator: "\n") }
    }
}

/// 対象外アプリ (B21): Bundle IDs with name and icon, add from /Applications, remove the selection.
struct ExcludedAppsView: View {
    @ObservedObject var model: Model
    @State private var selection = Set<String>()
    @State private var rejected: [String] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("excluded.explanation")).fixedSize(horizontal: false, vertical: true)
            List(selection: $selection) {
                ForEach(model.excluded.ids, id: \.self) { id in
                    let info = appInfo(id)
                    HStack(spacing: 8) {
                        Image(nsImage: info.icon).resizable().frame(width: 24, height: 24).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(info.name).lineLimit(1)
                            Text(info.missing ? L("excluded.missing") : id).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                    }
                    .help(id)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(info.name + ", " + id)
                }
            }
            .frame(height: 200)
            .accessibilityLabel(L("excluded.title"))
            HStack {
                Button(L("excluded.add")) { add() }
                Button(L("excluded.remove")) { model.removeExcluded(selection); selection = [] }.disabled(selection.isEmpty)
            }
            Text(model.excluded.ids.isEmpty ? L("excluded.none") : String(format: L("excluded.count"), String(model.excluded.ids.count)))
                .font(.caption).foregroundColor(.secondary)
            if !rejected.isEmpty {
                Text(rejected.joined(separator: "\n")).font(.caption).foregroundColor(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private func add() {
        let picker = NSOpenPanel()
        picker.title = L("excluded.pickerTitle")
        picker.prompt = L("excluded.add")
        picker.allowedContentTypes = [.applicationBundle]
        picker.allowsMultipleSelection = true
        picker.canChooseDirectories = false
        picker.directoryURL = URL(fileURLWithPath: "/Applications")
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            rejected = model.addExcluded(picker.urls)
        }
        if let window = NSApp.keyWindow { picker.beginSheetModal(for: window, completionHandler: completion) }
        else { picker.begin(completionHandler: completion) }
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
                SettingsSection(AccessibilityText.text("title")) {
                    AccessibilityPermissionView(required: true, showsTitle: false)
                }
            })),
            (L("hotkeyTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("pasteHotkey")) {
                    Toggle(L("enabled"), isOn: Binding(get: { model.hotkeyEnabled }, set: { model.hotkeyEnabled = $0; model.save() }))
                    ShortcutRow(model: model)
                    Text(model.hotkeyStatus).font(.caption).foregroundColor(model.hotkeyFailed ? .red : .secondary).fixedSize(horizontal: false, vertical: true)
                    if model.recording, !model.recordMessage.isEmpty { Text(model.recordMessage).font(.caption) }
                    Text(L("shortcutHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (L("pasteTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("menuTitlesTitle")) {
                    Toggle(L("useMenu"), isOn: Binding(get: { model.useMenu }, set: { model.useMenu = $0; model.save() }))
                    MenuTitlesEditor(model: model)
                    Text(L("menuTitlesHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("clipboardTitle")) {
                    Toggle(L("restoreClipboard"), isOn: Binding(get: { model.restoreClipboard }, set: { model.restoreClipboard = $0; model.save() }))
                    Text(L("restoreClipboardHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (L("excluded.title"), AnyView(SettingsSection(L("excluded.title")) { ExcludedAppsView(model: model) })),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
    }
}

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
        AccessibilityText.neededOverride = [
            "前面のアプリのメニュー項目（「ペーストしてスタイルを合わせる」など）を実行し、「ペースト」（⌘V）を送るために使用します。未許可の場合、⇧⌘V を押しても書式なしでペーストできません。",
            "Used to choose the front app's menu item (such as Paste and Match Style) and to send Paste (⌘V). Without permission, ⇧⌘V cannot paste without formatting.",
            "用于执行前台应用的菜单项（如“粘贴并匹配样式”）并发送“粘贴”（⌘V）。未获授权时，按 ⇧⌘V 无法以纯文本粘贴。",
            "앞에 있는 앱의 메뉴 항목(붙여넣고 스타일 일치 등)을 실행하고 붙여넣기(⌘V)를 보내는 데 사용합니다. 권한이 없으면 ⇧⌘V를 눌러도 서식 없이 붙여넣을 수 없습니다."
        ]
        WindowActivationPolicy.install()
        buildMainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.setAccessibilityLabel("PasteMatchStyle")
        menu.delegate = self
        resultItem = menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, L("openMainWindow"), #selector(openMainWindow))
        add(menu, L("settings"), #selector(showPreferences))
        add(menu, L("pause"), #selector(togglePause))
        add(menu, L("strip"), #selector(stripClipboard))
        menu.addItem(.separator())
        // Help submenu: app help and the note article (BASELINE「メニューの共通構成」).
        let statusHelp = NSMenu(title: L("help")); add(statusHelp, L("appHelp"), #selector(help)); MainActor.assumeIsolated { HelpLinks.addNoteItem(to: statusHelp) }
        menu.setSubmenu(statusHelp, for: menu.addItem(withTitle: L("help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator()); add(menu, L("quit"), #selector(quit))
        item.menu = menu
        MainActor.assumeIsolated {
            MenuBarPresence.shared.install(name: "PasteMatchStyle", symbol: "doc.plaintext", existing: item,
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
        add(fileMenu, L("strip"), #selector(stripClipboard))
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
        resultItem.title = model.status
        menu.items.first { $0.action == #selector(togglePause) }?.state = model.paused ? .on : .off
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Not available → disabled instead of a silent no-op (B27).
        if menuItem.action == #selector(togglePause) { menuItem.state = model.paused ? .on : .off; return model.hotkeyEnabled }
        if menuItem.action == #selector(stripClipboard) { return NSPasteboard.general.string(forType: .string)?.isEmpty == false }
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
        model.refreshAccessibility()
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 340), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            // Native title bar unchanged; no app name in it (BASELINE「主画面の背景とタイトルバー」).
            window.title = ""
            window.titleVisibility = .hidden
            let content = NSView(frame: window.contentLayoutRect)
            AppSurface.install(in: content)
            let hosting = NSHostingView(rootView: MainView(model: model))
            hosting.sizingOptions = [.minSize]
            // The hosting view sits on the shared surface view, so size the window from the SwiftUI content.
            let fitting = hosting.fittingSize
            let size = NSSize(width: max(520, ceil(fitting.width)), height: max(340, ceil(fitting.height)))
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
        model.refreshLogin()
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 560), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle")
            let hosting = NSHostingView(rootView: Preferences(model: model))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.contentMinSize = NSSize(width: 640, height: 560)
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("Preferences"); preferences = window
        }
        if let window = preferences, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
    }
    @objc func help() {
        if helpWindow == nil { helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: "PasteMatchStyle — " + L("help"), text: L("helpText"), heading: L("helpHeading")) } }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func togglePause() { model.togglePause() }
    @objc func stripClipboard() { model.stripClipboard() }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary ?? [:]
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "PasteMatchStyle",
            .applicationVersion: "\(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))",
            .credits: NSAttributedString(string: L("support"))])
    }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
SingleInstanceLaunch.enforce()
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()

// Reused from PasteInARow (BrowserSwitcher origin). Oldest process wins on simultaneous launch.
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
