import AppKit
import SwiftUI
import ServiceManagement
import Carbon
import ApplicationServices

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

@MainActor
final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var hotkeyEnabled = UserDefaults.standard.object(forKey: "hotkeyEnabled") as? Bool ?? true
    @Published var paused = false
    @Published var shortcut = UserDefaults.standard.data(forKey: "cleanShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .clean
    /// Missing key = on (all four targets start enabled).
    @Published var targetEnabled = UserDefaults.standard.dictionary(forKey: "targetEnabled") as? [String: Bool] ?? [:]
    @Published var replaceApostrophe = UserDefaults.standard.object(forKey: "replaceApostrophe") as? Bool ?? true
    @Published var notifySuccess = UserDefaults.standard.object(forKey: "notifySuccess") as? Bool ?? true
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    /// Only changed keys are stored; a missing entry is the command's default.
    @Published var commandShortcuts = UserDefaults.standard.data(forKey: "commandShortcuts").flatMap { try? JSONDecoder().decode([String: Shortcut].self, from: $0) } ?? [:]
    @Published var status = L("ready")
    @Published var statusIsError = false
    @Published var hotkeyStatus = ""
    @Published var hotkeyFailed = false
    @Published var loginStatus = ""
    @Published var loginOn = false
    @Published var canRestore = false
    /// Missing key = on (all table commands start enabled).
    @Published var commandEnabled = UserDefaults.standard.dictionary(forKey: "commandEnabled") as? [String: Bool] ?? [:]
    @Published var commandStatus = ""
    @Published var commandFailed = false
    /// Commands whose key could not be registered (shown under that row).
    @Published var failedCommands: Set<String> = []
    /// 1 = copy and clean (⌥⌘C), 100 + n = SheetCommand.allCases[n]. Paused by HotkeySet while a key is recorded.
    let hotkeys = HotkeySet(signature: "CCCL")
    static let cleanNumber: UInt32 = 1
    static func number(_ command: SheetCommand) -> UInt32 { 100 + UInt32(SheetCommand.allCases.firstIndex(of: command)!) }
    let cleaner = ClipboardCleaner()
    let commandRunner = SheetCommandRunner()
    private var observers: [NSObjectProtocol] = []
    private var workspaceObserver: NSObjectProtocol?
    /// What is registered now; app switches re-register only when this changes.
    private var registeredState: String?

    init() {
        hotkeys.action = { [weak self] number in
            guard let self else { return }
            if number == Self.cleanNumber { self.trigger() }
            else if let command = SheetCommand.allCases.first(where: { Self.number($0) == number }) { self.runCommand(command) }
        }
        // After recording, register again so a conflict with another app is reported.
        HotkeyRecorder.shared.onRecordingChanged.append { [weak self] recording in
            guard let self, !recording else { return }
            self.registeredState = nil; self.refreshHotkey()
        }
        // Event-driven: the clean hotkey exists only while an enabled target app is in front (B13, B21).
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshHotkey() }
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLogin(); self?.refreshHotkey(); self?.refreshRestore() }
        })
        refreshLogin(); refreshHotkey()
    }

    func save() {
        defaults.set(hotkeyEnabled, forKey: "hotkeyEnabled")
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: "cleanShortcut")
        defaults.set(targetEnabled, forKey: "targetEnabled")
        defaults.set(replaceApostrophe, forKey: "replaceApostrophe")
        defaults.set(notifySuccess, forKey: "notifySuccess")
        defaults.set(keepRunning, forKey: "keepRunning")
        defaults.set(commandEnabled, forKey: "commandEnabled")
        defaults.set(try? JSONEncoder().encode(commandShortcuts), forKey: "commandShortcuts")
        refreshHotkey()
    }

    /// Re-reads the shared settings after SettingsSync applied them; save() would otherwise write the old values back.
    func reload() {
        hotkeyEnabled = defaults.object(forKey: "hotkeyEnabled") as? Bool ?? true
        shortcut = defaults.data(forKey: "cleanShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .clean
        targetEnabled = defaults.dictionary(forKey: "targetEnabled") as? [String: Bool] ?? [:]
        replaceApostrophe = defaults.object(forKey: "replaceApostrophe") as? Bool ?? true
        notifySuccess = defaults.object(forKey: "notifySuccess") as? Bool ?? true
        commandShortcuts = defaults.data(forKey: "commandShortcuts").flatMap { try? JSONDecoder().decode([String: Shortcut].self, from: $0) } ?? [:]
        commandEnabled = defaults.dictionary(forKey: "commandEnabled") as? [String: Bool] ?? [:]
        refreshHotkey()
    }

    func isEnabled(_ target: TargetApp) -> Bool { targetEnabled[target.bundleID] ?? true }
    func setEnabled(_ target: TargetApp, _ value: Bool) { targetEnabled[target.bundleID] = value; save() }
    func isEnabled(_ command: SheetCommand) -> Bool { commandEnabled[command.rawValue] ?? true }
    func shortcut(for command: SheetCommand) -> Shortcut { commandShortcuts[command.rawValue] ?? command.defaultShortcut }
    func setEnabled(_ command: SheetCommand, _ value: Bool) { commandEnabled[command.rawValue] = value; save() }
    /// The enabled target for this app, or nil (other apps keep ⌥⌘C).
    func activeTarget(_ app: NSRunningApplication?) -> TargetApp? {
        guard let target = CleanRules.target(for: app?.bundleIdentifier), isEnabled(target) else { return nil }
        return target
    }

    func refreshHotkey() {
        publishHotkeys()
        let wanted = hotkeyEnabled && !paused
        let frontProfile = activeTarget(NSWorkspace.shared.frontmostApplication)?.profile
        let front = frontProfile != nil
        let commands = SheetCommand.allCases.filter(isEnabled)
        let state = "\(wanted):\(paused):\(frontProfile?.rawValue ?? "-"):\(shortcut.signature):\(commands.map { $0.rawValue + "=" + shortcut(for: $0).signature })"
        guard state != registeredState else { return }
        registeredState = state
        var result: OSStatus = noErr
        if wanted {
            // Registered to detect a conflict even when no target is in front; then released at once so the key passes through.
            result = hotkeys.register(Self.cleanNumber, shortcut.combo)
            if !front { hotkeys.unregister(Self.cleanNumber) }
        } else {
            hotkeys.unregister(Self.cleanNumber)
        }
        hotkeyFailed = wanted && result != noErr
        if !hotkeyEnabled { hotkeyStatus = L("hotkeyDisabled") }
        else if paused { hotkeyStatus = L("hotkeyPaused") }
        else if hotkeyFailed { hotkeyStatus = HotkeyText.registerFailed }
        else { hotkeyStatus = String(format: L("hotkeyActive"), shortcut.label) }
        refreshCommandHotkeys(commands, frontProfile: frontProfile)
    }

    /// Same pattern as the clean key: registered to detect a conflict, then kept only while a target it applies to is in front.
    private func refreshCommandHotkeys(_ commands: [SheetCommand], frontProfile: CleanProfile?) {
        var failed: [String] = []
        var failedIDs: Set<String> = []
        for command in SheetCommand.allCases {
            let number = Self.number(command)
            guard !paused, commands.contains(command) else { hotkeys.unregister(number); continue }
            if hotkeys.register(number, shortcut(for: command).combo) != noErr { failed.append(shortcut(for: command).label); failedIDs.insert(command.rawValue) }
            if !(frontProfile.map(command.scope.includes) ?? false) { hotkeys.unregister(number) }
        }
        failedCommands = failedIDs
        commandFailed = !failed.isEmpty
        if commands.isEmpty { commandStatus = L("commandsOff") }
        else if paused { commandStatus = L("hotkeyPaused") }
        else if commandFailed { commandStatus = String(format: L("commandsRegisterFailed"), failed.joined(separator: " ")) }
        else { commandStatus = L("commandsActive") }
    }

    /// Declares the hotkeys for HotkeyHound (shared registrations cannot be listed from outside).
    func publishHotkeys() {
        let apps = CleanRules.targets.filter(isEnabled).map(\.bundleID)
        HotkeyManifest.publish([
            HotkeyManifest.Item(id: "clean", title: L("cleanHotkey"), keyCode: Int(shortcut.code), modifiers: Int(shortcut.modifiers),
                                enabled: hotkeyEnabled, scope: "only", apps: apps)
        ] + SheetCommand.allCases.map { command in
            let scoped = CleanRules.targets.filter { isEnabled($0) && command.scope.includes($0.profile) }.map(\.bundleID)
            return HotkeyManifest.Item(id: command.rawValue, title: L("command." + command.rawValue), keyCode: Int(shortcut(for: command).code),
                                       modifiers: Int(shortcut(for: command).modifiers), enabled: isEnabled(command), scope: "only", apps: scoped,
                                       note: command.scope == .excel ? nil : L("commandsSheetsNote"))
        })
    }

    /// The 「ホットキー」 fields: the stored Shortcut (JSON with code, modifiers, label) as a KeyCombo.
    var cleanCombo: KeyCombo? {
        get { shortcut.combo }
        set { if let newValue { shortcut = Shortcut(newValue); save() } }
    }
    func combo(_ command: SheetCommand) -> KeyCombo { shortcut(for: command).combo }
    /// Only changed keys are stored, as before: the default is kept as a missing entry.
    func setCombo(_ command: SheetCommand, _ combo: KeyCombo?) {
        guard let combo else { return }
        commandShortcuts[command.rawValue] = combo == command.defaultShortcut.combo ? nil : Shortcut(combo)
        save()
    }
    /// Every hotkey of the app with its title, for refusing the same key twice.
    func otherHotkeys(except id: String) -> [(String, KeyCombo)] {
        ([("clean", L("cleanHotkey"), shortcut.combo)] + SheetCommand.allCases.map { ($0.rawValue, L("command." + $0.rawValue), combo($0)) })
            .filter { $0.0 != id }.map { ($0.1, $0.2) }
    }
    func togglePause() { paused.toggle(); refreshHotkey() }

    func trigger() {
        guard hotkeyEnabled, !paused, !cleaner.busy,
              let front = NSWorkspace.shared.frontmostApplication, let target = activeTarget(front) else { return }
        let pid = front.processIdentifier
        // Browsers: only while a Google Sheets window is in front; anywhere else the key goes back to the browser.
        if target.profile == .spreadsheet, !CleanRules.isGoogleSheetsTitle(ClipboardCleaner.focusedWindowTitle(pid: pid)) {
            ClipboardCleaner.passThrough(shortcut, to: pid)
            return
        }
        let name = front.localizedName ?? target.name
        cleaner.run(target: target, appName: name, pid: pid, replaceApostrophe: replaceApostrophe, stillTarget: { [weak self] in
            guard let self, let now = NSWorkspace.shared.frontmostApplication, now.processIdentifier == pid else { return false }
            return self.hotkeyEnabled && !self.paused && self.activeTarget(now) != nil
        }) { [weak self] outcome in self?.report(outcome) }
    }

    /// ⌃I ⌃K ⇧⌘E ⌥⌘P ⌃F ⌃⇧F. Browsers: only in a Google Sheets window; elsewhere (and when Excel cannot do it now) the key goes back to the app.
    func runCommand(_ command: SheetCommand) {
        guard !paused, isEnabled(command), !commandRunner.busy,
              let front = NSWorkspace.shared.frontmostApplication, let target = activeTarget(front),
              command.scope.includes(target.profile) else { return }
        let pid = front.processIdentifier
        guard AccessibilitySection.isTrusted else { report(.failed(AccessibilityText.text("blocked"))); return }
        var title: String?
        if target.profile == .spreadsheet {
            title = ClipboardCleaner.focusedWindowTitle(pid: pid)
            guard CleanRules.isGoogleSheetsTitle(title) else { ClipboardCleaner.passThrough(shortcut(for: command), to: pid); return }
        }
        switch commandRunner.run(command, profile: target.profile, pid: pid, bundleID: front.bundleIdentifier, windowTitle: title) {
        case .done: break
        case .unavailable: ClipboardCleaner.passThrough(shortcut(for: command), to: pid)
        case .menuNotFound: report(.failed(L("fail.menu")))
        case .eventFailed: report(.failed(L("fail.commandEvent")))
        case .automationDenied: report(.failed(L("fail.automation")))
        case .scriptFailed(let code): report(.failed(String(format: L("fail.script"), String(code))))
        }
    }

    func report(_ outcome: CleanOutcome) {
        switch outcome {
        case .cleaned(let appName, let changed):
            status = String(format: L(changed ? "success.changed" : "success.unchanged"), appName)
            statusIsError = false
            if notifySuccess { let message = status; MainActor.assumeIsolated { TransientMessage.show(message) } }
        case .failed(let reason):
            status = reason
            statusIsError = true
            NSSound.beep()
            // Never just a beep (B27): the reason is shown near the top of the screen.
            let message = reason
            MainActor.assumeIsolated { TransientMessage.show(message) }
        }
        refreshRestore()
    }

    func restoreOriginal() {
        if cleaner.restore() { status = L("restored"); statusIsError = false }
        else { status = L("restoreUnavailable"); statusIsError = true }
        refreshRestore()
    }
    func refreshRestore() { canRestore = cleaner.canRestore }

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

func appIcon(for bundleID: String) -> NSImage? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
    return NSWorkspace.shared.icon(forFile: url.path)
}
func profileDescription(_ profile: CleanProfile) -> String { L(profile == .excel ? "profile.excel" : "profile.spreadsheet") }

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
                    StatusRow(symbol: model.hotkeyFailed ? "exclamationmark.triangle.fill" : (model.hotkeyEnabled && !model.paused ? "keyboard" : "pause.circle"),
                              tint: model.hotkeyFailed ? .orange : .secondary, title: L("cleanHotkey"), value: model.hotkeyStatus)
                    StatusRow(symbol: model.commandFailed ? "exclamationmark.triangle.fill" : "tablecells",
                              tint: model.commandFailed ? .orange : .secondary, title: L("commandsTitle"), value: model.commandStatus)
                    StatusRow(symbol: AccessibilitySection.isTrusted ? "checkmark.circle.fill" : "minus.circle",
                              tint: AccessibilitySection.isTrusted ? .green : .secondary, title: AccessibilityText.text("title"),
                              value: AccessibilityText.text(AccessibilitySection.isTrusted ? "allowed" : "denied"))
                    StatusRow(symbol: model.statusIsError ? "xmark.octagon.fill" : "doc.on.clipboard",
                              tint: model.statusIsError ? .red : .secondary, title: L("lastResult"), value: model.status)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            GroupBox(label: Text(L("targets")).font(.system(size: 13, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(CleanRules.targets, id: \.bundleID) { target in
                        HStack(spacing: 8) {
                            if let icon = appIcon(for: target.bundleID) { Image(nsImage: icon).resizable().frame(width: 20, height: 20).accessibilityHidden(true) }
                            else { Image(systemName: "app.dashed").frame(width: 20, height: 20).accessibilityHidden(true) }
                            Text(target.name)
                            Text(profileDescription(target.profile)).font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Label(L(model.isEnabled(target) ? "on" : "off"), systemImage: model.isEnabled(target) ? "checkmark.circle.fill" : "minus.circle")
                                .foregroundColor(model.isEnabled(target) ? .primary : .secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Text(L("targetsHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            HStack {
                Button(L("settingsButton")) { (NSApp.delegate as? AppDelegate)?.showPreferences() }
                Spacer()
                Button(L("restore")) { model.restoreOriginal() }.disabled(!model.canRestore).help(L("restoreHint"))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 440, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
    }
}

/// ✓ where a command works, a dash where it does not (not by color alone).
struct SupportMark: View {
    let supported: Bool
    var body: some View {
        Image(systemName: supported ? "checkmark" : "minus")
            .foregroundColor(supported ? .primary : .secondary)
            .accessibilityLabel(L(supported ? "supported" : "unsupported"))
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
                SettingsSection(L("cleanHotkey")) {
                    Toggle(HotkeyText.enable, isOn: Binding(get: { model.hotkeyEnabled }, set: { model.hotkeyEnabled = $0; model.save() }))
                    HotkeyField(id: "clean", combo: Binding(get: { model.cleanCombo }, set: { model.cleanCombo = $0 }),
                                defaultCombo: Shortcut.clean.combo, others: model.otherHotkeys(except: "clean"),
                                registered: !model.hotkeyFailed, isEnabled: model.hotkeyEnabled)
                    Text(L("shortcutHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("commandsTitle")) {
                    // One row per command; the Excel / Google Sheets columns show where it works.
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                        GridRow {
                            Text(L("column.command"))
                            Text("Excel").gridColumnAlignment(.center)
                            Text(L("column.sheets")).multilineTextAlignment(.center).gridColumnAlignment(.center)
                            Text(L("column.key"))
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                        .font(.caption).foregroundColor(.secondary)
                        ForEach(CommandCategory.allCases, id: \.self) { category in
                            GridRow {
                                Text(L("category." + category.rawValue)).font(.system(size: 13, weight: .semibold))
                                    .padding(.top, 6).gridCellColumns(5)
                            }
                            ForEach(category.commands, id: \.self) { command in
                                GridRow {
                                    Toggle(L("command." + command.rawValue), isOn: Binding(get: { model.isEnabled(command) }, set: { model.setEnabled(command, $0) }))
                                    SupportMark(supported: command.scope.includes(.excel))
                                    SupportMark(supported: command.scope.includes(.spreadsheet))
                                    HotkeyField(id: command.rawValue, combo: Binding(get: { model.combo(command) }, set: { model.setCombo(command, $0) }),
                                                defaultCombo: command.defaultShortcut.combo, others: model.otherHotkeys(except: command.rawValue),
                                                registered: !model.failedCommands.contains(command.rawValue), isEnabled: model.isEnabled(command),
                                                // ⌥V, ⌥← ⌥→ and ⌥⇧= are defaults without ⌘ or ⌃.
                                                allowsOption: command.defaultShortcut.modifiers & UInt32(cmdKey | controlKey) == 0)
                                        .controlSize(.small)
                                        .gridCellColumns(2)
                                }
                            }
                        }
                    }
                    Text(model.commandStatus).font(.caption).foregroundColor(model.commandFailed ? .red : .secondary).fixedSize(horizontal: false, vertical: true)
                    Text(L("commandsHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("notifyTitle")) {
                    Toggle(L("notifySuccess"), isOn: Binding(get: { model.notifySuccess }, set: { model.notifySuccess = $0; model.save() }))
                    Text(L("notifyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (L("targets"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("targets")) {
                    ForEach(CleanRules.targets, id: \.bundleID) { target in
                        Toggle(isOn: Binding(get: { model.isEnabled(target) }, set: { model.setEnabled(target, $0) })) {
                            // The icon sits on the name line, so it lines up with the checkbox.
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    if let icon = appIcon(for: target.bundleID) { Image(nsImage: icon).resizable().frame(width: 18, height: 18).accessibilityHidden(true) }
                                    Text(target.name)
                                }
                                Text(target.bundleID + " — " + profileDescription(target.profile)).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    Text(L("targetsHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("sheetsOptions")) {
                    Toggle(L("replaceApostrophe"), isOn: Binding(get: { model.replaceApostrophe }, set: { model.replaceApostrophe = $0; model.save() }))
                    Text(L("replaceApostropheHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
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
        LegacySettings.migrate()
        model = Model()
        SettingsSync.shared.onImport = { [weak self] in self?.model.reload() }
        SettingsSync.shared.start(.init(
            keys: ["hotkeyEnabled", "cleanShortcut", "targetEnabled", "replaceApostrophe", "notifySuccess", "commandEnabled", "commandShortcuts"],
            note: StartupWindow.text("ホットキー・表の操作・対象アプリと整え方を書き出し・同期します。",
                                     "Exports and syncs the hotkeys, the table commands, the target apps and the cleaning options.",
                                     "导出并同步快捷键、表格操作、目标应用和整理方式。",
                                     "단축키, 표 작업, 대상 앱과 정리 방식을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・常駐・メニューバーはMacごとに設定します。",
                                       "Launch at login, staying open and the menu bar icon are set on each Mac.",
                                       "登录时启动、常驻和菜单栏图标需在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 상주, 메뉴 막대 아이콘은 Mac마다 설정합니다.")))
        AccessibilityText.neededOverride = [
            "対象アプリへ「コピー」（⌘C）や表の操作（行・列の挿入と削除など）を送るために使用します。未許可の場合、⌥⌘C を押してもコピーと整形はできません。",
            "Used to send Copy (⌘C) and table commands (inserting and deleting rows or columns, etc.) to the target app. Without permission, ⌥⌘C cannot copy and clean.",
            "用于向目标应用发送“拷贝”（⌘C）和表格操作（插入、删除行或列等）。未获授权时，按 ⌥⌘C 无法拷贝和整理。",
            "대상 앱에 복사하기(⌘C)와 표 작업(행·열 삽입 및 삭제 등)을 보내는 데 사용합니다. 권한이 없으면 ⌥⌘C를 눌러도 복사 및 정리를 할 수 없습니다."
        ]
        WindowActivationPolicy.install()
        buildMainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.setAccessibilityLabel("SpreadsheetHelper")
        menu.delegate = self
        resultItem = menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, L("openMainWindow"), #selector(openMainWindow))
        add(menu, L("settings"), #selector(showPreferences))
        add(menu, L("pause"), #selector(togglePause))
        add(menu, L("restore"), #selector(restore))
        menu.addItem(.separator())
        // Help submenu: app help and the note article (BASELINE「メニューの共通構成」).
        let statusHelp = NSMenu(title: L("help")); add(statusHelp, L("appHelp"), #selector(help)); MainActor.assumeIsolated { HelpLinks.addNoteItem(to: statusHelp) }
        menu.setSubmenu(statusHelp, for: menu.addItem(withTitle: L("help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator()); add(menu, L("quit"), #selector(quit))
        item.menu = menu
        MainActor.assumeIsolated {
            MenuBarPresence.shared.install(name: "SpreadsheetHelper", symbol: "tablecells", existing: item,
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
        add(fileMenu, L("restore"), #selector(restore))
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
        model.refreshRestore()
        resultItem.title = model.status
        menu.items.first { $0.action == #selector(togglePause) }?.state = model.paused ? .on : .off
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Not available → disabled instead of a silent no-op (B27).
        if menuItem.action == #selector(restore) { return model.cleaner.canRestore }
        if menuItem.action == #selector(togglePause) { menuItem.state = model.paused ? .on : .off; return model.hotkeyEnabled }
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
        model.refreshRestore()
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 440), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            // Native title bar unchanged; no app name in it (BASELINE「主画面の背景とタイトルバー」).
            window.title = ""
            window.titleVisibility = .hidden
            let content = NSView(frame: window.contentLayoutRect)
            AppSurface.install(in: content)
            let hosting = NSHostingView(rootView: MainView(model: model))
            hosting.sizingOptions = [.minSize]
            // The hosting view sits on the shared surface view, so size the window from the SwiftUI content.
            let fitting = hosting.fittingSize
            let size = NSSize(width: max(560, ceil(fitting.width)), height: max(440, ceil(fitting.height)))
            window.setContentSize(size)
            content.frame = NSRect(origin: .zero, size: size)
            hosting.frame = content.bounds
            hosting.autoresizingMask = [.width, .height]
            content.addSubview(hosting)
            window.contentView = content
            window.contentMinSize = size
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("MainWindow")
            // A frame saved by an older layout must not cut off the content.
            let current = window.contentRect(forFrameRect: window.frame).size
            if current.width < size.width || current.height < size.height {
                var frame = window.frame
                let grow = NSSize(width: max(0, size.width - current.width), height: max(0, size.height - current.height))
                frame.size.width += grow.width; frame.size.height += grow.height; frame.origin.y -= grow.height
                window.setFrame(frame, display: false)
            }
            mainWindow = window
        }
        if let window = mainWindow, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); mainWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func showPreferences() {
        model.refreshLogin()
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle")
            let hosting = NSHostingView(rootView: Preferences(model: model))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.contentMinSize = NSSize(width: 640, height: 520)
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("Preferences"); preferences = window
        }
        if let window = preferences, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
    }
    @objc func help() {
        if helpWindow == nil { helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: "SpreadsheetHelper — " + L("help"), text: L("helpText"), heading: L("helpHeading")) } }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func togglePause() { model.togglePause() }
    @objc func restore() { model.restoreOriginal() }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary ?? [:]
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "SpreadsheetHelper",
            .applicationVersion: "\(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))",
            .credits: NSAttributedString(string: L("support"))])
    }
    @objc func quit() { NSApp.terminate(nil) }
}

/// Renamed from CellCopyCleaner in 1.3.0 with a new Bundle ID: its settings are copied once, never overwriting newer ones.
enum LegacySettings {
    static let oldDomain = "jp.dtp-transit.cellcopycleaner" as CFString
    static let doneKey = "migratedFromCellCopyCleaner"
    static func migrate() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        defaults.set(true, forKey: doneKey)
        guard let keys = CFPreferencesCopyKeyList(oldDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] else { return }
        for key in keys where defaults.object(forKey: key) == nil {
            if let value = CFPreferencesCopyAppValue(key as CFString, oldDomain) { defaults.set(value, forKey: key) }
        }
    }
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
