import AppKit
import SwiftUI
import ServiceManagement
import Carbon
import ApplicationServices

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// Keynote 14+ (com.apple.Keynote, including Keynote Creator Studio) and older iWork Keynote.
enum KeynoteApp {
    static let bundleIDs = KeynoteHotkeyScope.bundleIDs
    static func isKeynote(_ app: NSRunningApplication?) -> Bool { KeynoteHotkeyScope.permits(app?.bundleIdentifier) }
    static var icon: NSImage? {
        for id in bundleIDs { if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return NSWorkspace.shared.icon(forFile: url.path) } }
        return nil
    }
}

@MainActor
final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    let hotkeysEnabled = true // Legacy master switch is replaced by standard-set selection and the special switch.
    @Published var paletteVisibility = PaletteVisibility.load()
    @Published private(set) var paletteDisplayHotkey = PaletteDisplayHotkey.load()
    @Published private(set) var paletteDisplayFailed = false
    @Published var paused = false
    @Published private(set) var paletteBusy = false
    @Published private(set) var paletteTargetAvailable = false
    @Published var notifySuccess = UserDefaults.standard.object(forKey: "notifySuccess") as? Bool ?? true
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    /// Only changed keys are stored; a missing entry is the command's default.
    @Published var commandShortcuts = UserDefaults.standard.data(forKey: "commandShortcuts").flatMap { try? JSONDecoder().decode([String: Shortcut].self, from: $0) } ?? [:]
    /// Missing key = the command's default (document-wide tasks can start off).
    @Published var commandEnabled = UserDefaults.standard.dictionary(forKey: "commandEnabled") as? [String: Bool] ?? [:]
    @Published var profiles = ShortcutProfiles()
    @Published var status = L("ready")
    @Published var statusIsError = false
    @Published var hotkeyStatus = ""
    @Published var hotkeyFailed = false
    /// Commands whose key could not be registered (shown under that row).
    @Published var failedCommands: Set<String> = []
    @Published var failedNativeActions: Set<String> = []
    private let nativeActions = NativeActionLibrary.bundled.actions
    private var nativeSending = false
    private var nativeTask: DispatchWorkItem?
    private func nativeNumber(_ action: NativeKeyboardAction) -> UInt32 { 10_000 + UInt32(nativeActions.firstIndex { $0.id == action.id }!) }
    private var activeNativeActions: [NativeKeyboardAction] {
        nativeActions.filter { $0.needsRegistration(profiles.nativeBinding($0.id)) }
    }
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
    private var registeredConfiguration: String?

    init() {
        // Inserting Palette before Sharing/About must preserve the old selected tab.
        if !defaults.bool(forKey: "paletteSettingsTabV1") {
            let key = "shared.settings.selectedTabIndex"
            if let old = defaults.object(forKey: key) as? Int, (3...4).contains(old) { defaults.set(old + 1, forKey: key) }
            defaults.set(true, forKey: "paletteSettingsTabV1")
        }
        loadProfiles()
        if !defaults.bool(forKey: "independentShortcutControlsV1") {
            if defaults.object(forKey: "hotkeysEnabled") as? Bool == false {
                profiles.selected = .system; profiles.specialEnabled = false
                defaults.set(try? JSONEncoder().encode(profiles), forKey: ShortcutProfiles.storageKey)
            }
            defaults.set(true, forKey: "independentShortcutControlsV1")
        }
        hotkeys.action = { [weak self] number in
            guard let self else { return }
            guard KeynoteApp.isKeynote(NSWorkspace.shared.frontmostApplication) else {
                // A queued Carbon event can outlive an app switch. Release registrations
                // first, then return that key to the actual front app rather than consuming it.
                let key = self.keyForRegistration(number)
                self.hotkeys.unregisterAll(); self.registeredState = nil
                if let key, let front = NSWorkspace.shared.frontmostApplication { CommandRunner.passThrough(Shortcut(key), to: front.processIdentifier) }
                return
            }
            if number == PaletteDisplayHotkey.registrationID {
                guard !self.paused, !self.nativeSending, self.paletteDisplayHotkey.combo != nil,
                      KeynoteApp.isKeynote(NSWorkspace.shared.frontmostApplication) else { return }
                (NSApp.delegate as? AppDelegate)?.showPalette()
            } else if let command = KeynoteCommand.availableCommands.first(where: { Self.number($0) == number }) { self.runCommand(command) }
            else if let action = self.nativeActions.first(where: { self.nativeNumber($0) == number }) { self.runNativeAction(action) }
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

    private func loadProfiles() {
        if let data = defaults.data(forKey: ShortcutProfiles.storageKey),
           let saved = try? JSONDecoder().decode(ShortcutProfiles.self, from: data) {
            profiles = saved
        } else {
            if let data = defaults.data(forKey: ShortcutProfiles.storageKey) {
                defaults.set(data, forKey: "shortcutProfilesV1.unreadableBackup")
            }
            let existing = !(defaults.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "jp.dtp-transit.keynotehelper") ?? [:]).isEmpty
            if defaults.object(forKey: ShortcutProfiles.storageKey) == nil,
               let oldTab = defaults.object(forKey: "shared.settings.selectedTabIndex") as? Int,
               (2...3).contains(oldTab) {
                defaults.set(oldTab + 1, forKey: "shared.settings.selectedTabIndex")
            }
            profiles = .migrating(shortcuts: commandShortcuts, enabled: commandEnabled, existingInstallation: existing)
            defaults.set(try? JSONEncoder().encode(profiles), forKey: ShortcutProfiles.storageKey)
        }
    }
    func selectStandardSet(_ value: StandardShortcutSet) { profiles.selected = value; save() }
    func setSpecialEnabled(_ value: Bool) { profiles.specialEnabled = value; save() }
    func canEdit(_ command: KeynoteCommand) -> Bool { !command.isStandard || profiles.selected.isEditable }
    func setCommandsEnabled(_ commands: [KeynoteCommand], _ enabled: Bool) {
        for command in commands {
            if command.isStandard { profiles.setEnabled(command, enabled) }
            else { commandEnabled[command.rawValue] = enabled }
        }
        save()
    }
    func save() {
        defaults.set(try? JSONEncoder().encode(profiles), forKey: ShortcutProfiles.storageKey)
        defaults.set(notifySuccess, forKey: "notifySuccess")
        defaults.set(keepRunning, forKey: "keepRunning")
        defaults.set(commandEnabled, forKey: "commandEnabled")
        defaults.set(try? JSONEncoder().encode(commandShortcuts), forKey: "commandShortcuts")
        refreshHotkeys()
    }

    /// Re-reads the shared settings after SettingsSync applied them; save() would otherwise write the old values back.
    func reload() {
        paletteVisibility = .load()
        paletteDisplayHotkey = .load()
        paletteDisplayFailed = false
        notifySuccess = defaults.object(forKey: "notifySuccess") as? Bool ?? true
        commandShortcuts = defaults.data(forKey: "commandShortcuts").flatMap { try? JSONDecoder().decode([String: Shortcut].self, from: $0) } ?? [:]
        commandEnabled = defaults.dictionary(forKey: "commandEnabled") as? [String: Bool] ?? [:]
        loadProfiles()
        registeredState = nil
        refreshHotkeys()
    }

    func isEnabled(_ command: KeynoteCommand) -> Bool { profiles.isEnabled(command, special: commandEnabled) }
    func configuredEnabled(_ command: KeynoteCommand) -> Bool { profiles.configuredEnabled(command, special: commandEnabled) }
    func setEnabled(_ command: KeynoteCommand, _ value: Bool) { setCommandsEnabled([command], value) }
    func shortcut(for command: KeynoteCommand) -> Shortcut { profiles.shortcut(command, special: commandShortcuts) }
    func combo(_ command: KeynoteCommand) -> KeyCombo { shortcut(for: command).combo }
    func setCombo(_ command: KeynoteCommand, _ combo: KeyCombo?) {
        guard let combo, canEdit(command) else { return }
        if command.isStandard { profiles.setShortcut(command, Shortcut(combo)) }
        else { commandShortcuts[command.rawValue] = combo == command.defaultShortcut.combo ? nil : Shortcut(combo) }
        save()
    }
    func resetShortcuts(_ domain: ShortcutDomain) {
        if domain == .standard { profiles.resetCurrentStandardKeys() }
        else { commandShortcuts = commandShortcuts.filter { KeynoteCommand(rawValue: $0.key)?.isStandard != false } }
        save()
    }
    /// Every hotkey of the app with its title, for refusing the same key twice.
    func otherHotkeys(except command: KeynoteCommand) -> [(String, KeyCombo)] {
        KeynoteCommand.availableCommands.filter { $0 != command && isEnabled($0) }.map { (L("command." + $0.rawValue), combo($0)) }
            + activeNativeActions.compactMap { action in profiles.nativeBinding(action.id).map { (action.title, $0) } }
            + paletteDisplayConflict
    }
    func setNativeBinding(_ id: String, _ combo: KeyCombo?) { profiles.setNativeBinding(id, combo); save() }
    func nativeCombo(_ id: String) -> KeyCombo? { profiles.nativeBinding(id) }
    func otherNativeHotkeys(except id: String) -> [(String, KeyCombo)] {
        KeynoteCommand.availableCommands.filter(isEnabled).map { (L("command." + $0.rawValue), combo($0)) }
            + activeNativeActions.filter { $0.id != id }.compactMap { action in profiles.nativeBinding(action.id).map { (action.title, $0) } }
            + paletteDisplayConflict
    }
    /// Forward the source key with our registrations suspended, so swaps/chains never recurse.
    private func runNativeAction(_ action: NativeKeyboardAction) {
        guard hotkeysEnabled, !paused, !nativeSending, profiles.selected.isEditable,
              action.needsRegistration(profiles.nativeBinding(action.id)),
              let target = NSWorkspace.shared.frontmostApplication, KeynoteApp.isKeynote(target) else { return }
        guard AccessibilitySection.isTrusted else { report(.failure(AccessibilityText.text("blocked"))); return }
        guard !runner.busy else { report(.failure(L("fail.busy"))); return }
        let pid = target.processIdentifier
        let selectedSet = profiles.selected
        let assigned = profiles.nativeBinding(action.id)
        nativeSending = true; hotkeys.unregisterAll(); registeredState = nil
        func finish() {
            nativeTask = nil; nativeSending = false; registeredState = nil; refreshHotkeys()
        }
        func send(_ index: Int) {
            guard hotkeysEnabled, !paused, profiles.selected == selectedSet,
                  profiles.nativeBinding(action.id) == assigned,
                  let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier == pid, KeynoteApp.isKeynote(front) else { finish(); return }
            guard index < action.strokes.count else { status = L("native.sent"); statusIsError = false; finish(); return }
            let stroke = action.strokes[index]
            guard let source = CGEventSource(stateID: .privateState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(stroke.combo.code), keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(stroke.combo.code), keyDown: false) else {
                report(.failure(L("fail.event"))); finish(); return
            }
            down.flags = stroke.flags; up.flags = stroke.flags
            down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
            let work = DispatchWorkItem { send(index + 1) }; nativeTask = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
        }
        send(0)
    }
    var activeCount: Int { KeynoteCommand.availableCommands.filter(isEnabled).count + activeNativeActions.count + (paletteDisplayHotkey.combo == nil ? 0 : 1) }
    func togglePause() { paused.toggle(); refreshHotkeys() }

    private var paletteDisplayConflict: [(String, KeyCombo)] {
        paletteDisplayHotkey.combo.map { [(L("palette.showHotkey"), $0)] } ?? []
    }
    var otherPaletteHotkeys: [(String, KeyCombo)] {
        KeynoteCommand.availableCommands.filter(isEnabled).map { (L("command." + $0.rawValue), combo($0)) }
            + activeNativeActions.compactMap { action in profiles.nativeBinding(action.id).map { (action.title, $0) } }
    }
    func setPaletteDisplayHotkey(_ combo: KeyCombo?) {
        if let combo, let owner = PaletteDisplayHotkey.conflict(for: combo, among: otherPaletteHotkeys) {
            HotkeyRecorder.shared.show(PaletteDisplayHotkey.fieldID, HotkeyText.duplicate(combo.label, owner), error: true)
            return
        }
        paletteDisplayHotkey = PaletteDisplayHotkey(combo: combo)
        paletteDisplayHotkey.save()
        paletteDisplayFailed = false
        registeredState = nil
        refreshHotkeys()
    }
    private func keyForRegistration(_ number: UInt32) -> KeyCombo? {
        if number == PaletteDisplayHotkey.registrationID { return paletteDisplayHotkey.combo }
        if let command = KeynoteCommand.availableCommands.first(where: { Self.number($0) == number }) { return combo(command) }
        if let action = nativeActions.first(where: { nativeNumber($0) == number }) { return profiles.nativeBinding(action.id) }
        return nil
    }

    /// Register only with a supported Keynote in front, including conflict checks.
    /// Outside Keynote there are no transient registrations for probing conflicts.
    func refreshHotkeys() {
        paletteTargetAvailable = KeynoteApp.isKeynote(NSWorkspace.shared.frontmostApplication)
        publishHotkeys()
        if nativeSending { return }
        let front = paletteTargetAvailable
        let wanted = hotkeysEnabled && !paused
        let commands = wanted ? KeynoteCommand.availableCommands.filter(isEnabled) : []
        let natives = wanted ? activeNativeActions : []
        let displayKey = wanted ? paletteDisplayHotkey.combo : nil
        let displaySignature = displayKey.map { "\($0.code):\($0.modifiers)" } ?? ""
        let configuration = "\(wanted):\(commands.map { $0.rawValue + "=" + shortcut(for: $0).signature }):\(natives.map { $0.id + "=" + (profiles.nativeBinding($0.id)?.label ?? "") }):palette=\(displaySignature)"
        let state = "\(front):\(configuration)"
        guard state != registeredState else { return }
        let changed = registeredConfiguration != configuration
        registeredState = state; registeredConfiguration = configuration
        hotkeys.unregisterAll()
        if front || changed {
            failedCommands = []; failedNativeActions = []; paletteDisplayFailed = false
        }
        if front {
            for command in commands {
                if hotkeys.register(Self.number(command), combo(command)) != noErr { failedCommands.insert(command.rawValue) }
            }
            for action in natives {
                if let key = profiles.nativeBinding(action.id), hotkeys.register(nativeNumber(action), key) != noErr { failedNativeActions.insert(action.id) }
            }
            if let displayKey {
                if let owner = PaletteDisplayHotkey.conflict(for: displayKey, among: otherPaletteHotkeys) {
                    paletteDisplayFailed = true
                    HotkeyRecorder.shared.show(PaletteDisplayHotkey.fieldID, HotkeyText.duplicate(displayKey.label, owner), error: true)
                } else { paletteDisplayFailed = hotkeys.register(PaletteDisplayHotkey.registrationID, displayKey) != noErr }
            }
        }
        let failed = commands.filter { failedCommands.contains($0.rawValue) }.map { shortcut(for: $0).label }
            + natives.filter { failedNativeActions.contains($0.id) }.compactMap { profiles.nativeBinding($0.id)?.label }
            + (paletteDisplayFailed ? [displayKey?.label ?? ""] : [])
        hotkeyFailed = !failed.isEmpty
        if !hotkeysEnabled { hotkeyStatus = L("hotkeyDisabled") }
        else if paused { hotkeyStatus = L("hotkeyPaused") }
        else if commands.isEmpty && natives.isEmpty && displayKey == nil { hotkeyStatus = L("commandsOff") }
        else if hotkeyFailed { hotkeyStatus = String(format: L("commandsRegisterFailed"), failed.joined(separator: " ")) }
        else { hotkeyStatus = String(format: L("commandsActive"), String(commands.count + natives.count + (displayKey == nil ? 0 : 1))) }
    }

    /// Declares the hotkeys for HotkeyHound (shared registrations cannot be listed from outside).
    func publishHotkeys() {
        let nativeItems = activeNativeActions.compactMap { action -> HotkeyManifest.Item? in
            guard let key = profiles.nativeBinding(action.id) else { return nil }
            return HotkeyManifest.Item(id: "native." + action.id, title: action.title, keyCode: Int(key.code), modifiers: Int(key.modifiers), enabled: hotkeysEnabled, scope: "only", apps: KeynoteApp.bundleIDs)
        }
        let paletteItems = paletteDisplayHotkey.combo.map { key in
            [HotkeyManifest.Item(id: PaletteDisplayHotkey.fieldID, title: L("palette.showHotkey"), keyCode: Int(key.code), modifiers: Int(key.modifiers), enabled: !paused, scope: "only", apps: KeynoteApp.bundleIDs)]
        } ?? []
        HotkeyManifest.publish(KeynoteCommand.availableCommands.map { command in
            HotkeyManifest.Item(id: command.rawValue, title: L("command." + command.rawValue), keyCode: Int(shortcut(for: command).code),
                                modifiers: Int(shortcut(for: command).modifiers), enabled: hotkeysEnabled && isEnabled(command),
                                scope: "only", apps: KeynoteApp.bundleIDs)
        } + nativeItems + paletteItems)
    }

    func setPaletteVisible(_ command: KeynoteCommand, _ visible: Bool) {
        paletteVisibility.set(command, visible: visible)
        paletteVisibility.save()
    }
    func setAllPaletteVisible(_ visible: Bool) {
        var next = paletteVisibility
        for command in PaletteCommands.all { next.set(command, visible: visible) }
        paletteVisibility = next
        next.save()
    }
    func runPaletteCommand(_ command: KeynoteCommand) {
        guard PaletteCommands.all.contains(command) else { return }
        runCommand(command, fromPalette: true)
    }
    func runCommand(_ command: KeynoteCommand, fromPalette: Bool = false) {
        guard hotkeysEnabled, !paused, !nativeSending, (fromPalette || isEnabled(command)),
              let front = NSWorkspace.shared.frontmostApplication, KeynoteApp.isKeynote(front), let bundleID = front.bundleIdentifier else { return }
        let pid = front.processIdentifier
        let key = shortcut(for: command)
        guard AccessibilitySection.isTrusted else { report(.failure(AccessibilityText.text("blocked"))); return }
        // ⌥L or ⇧1 while typing in a text box: the character, not the command (text commands excepted).
        if !fromPalette, key.typesCharacter, !command.worksWhileTyping, CommandRunner.isEditingText(pid: pid) { CommandRunner.passThrough(key, to: pid); return }
        if runner.busy { report(.failure(L("fail.busy"))); return }
        var documentID: String?
        var slideNumber: Int?
        if fromPalette {
            guard let target = CommandRunner.paletteTarget(bundleID: bundleID) else { report(.failure(L("fail.noDocument"))); return }
            documentID = target.documentID
            slideNumber = target.slideNumber
        }
        paletteBusy = true
        runner.run(command, pid: pid, bundleID: bundleID, documentID: documentID, slideNumber: slideNumber, canContinue: { [weak self] in
            guard let self else { return false }
            return !self.paused && AccessibilitySection.isTrusted
                && NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        }) { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .autoMagicMoveRunning, .exporting: break
            default: self.paletteBusy = false
            }
            switch outcome {
            case .done: self.report(.success(String(format: L("success.done"), L("command." + command.rawValue)), notify: false))
            case .passThrough:
                if fromPalette { self.report(.failure(L("fail.menu"))) }
                else { CommandRunner.passThrough(key, to: pid) }
            case .scripted(let count): self.report(Self.scriptMessage(command, count: count))
            case .autoMagicMoveRunning: self.report(.success(L("autoMagicMove.running"), notify: false))
            case .autoMagicMovePartial(let count, let error):
                self.report(.failure(String(format: L("autoMagicMove.partial"), String(count), String(error))))
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

    /// Results of AppleScript commands; the document-wide job treats zero matching slides as success.
    static func scriptMessage(_ command: KeynoteCommand, count: Int) -> Report {
        let name = L("command." + command.rawValue)
        if command == .autoMagicMove { return .success(String(format: L("autoMagicMove.done"), String(count))) }
        switch command.category {
        case .transition:
            return .success(String(format: L("result.done"), name))
        default:
            if command == .showHidden { return .success(count == 0 ? L("result.noneHidden") : String(format: L("result.shown"), String(count))) }
            if command == .slideSizeShape || command == .centerCross { return .success(String(format: L("result.done"), name), notify: false) }
            if count == 0 { return .failure(command == .sameHeight || command == .sameWidth || command == .sameWidthNarrowest ? L("result.selectTwo") : L(command == .whiteRectangle ? "result.selectOne" : "result.selectFirst")) }
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
        nativeTask?.cancel(); nativeTask = nil
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
                    StatusRow(symbol: model.hotkeyFailed ? "exclamationmark.triangle.fill" : (model.hotkeysEnabled && !model.paused ? "keyboard" : "pause.circle"),
                              tint: model.hotkeyFailed ? .orange : .secondary, title: L("hotkeyTab"), value: model.hotkeyStatus)
                    StatusRow(symbol: AccessibilitySection.isTrusted ? "checkmark.circle.fill" : "minus.circle",
                              tint: AccessibilitySection.isTrusted ? .green : .secondary, title: AccessibilityText.text("title"),
                              value: AccessibilityText.text(AccessibilitySection.isTrusted ? "allowed" : "denied"))
                    StatusRow(symbol: model.statusIsError ? "xmark.octagon.fill" : "play.rectangle",
                              tint: model.statusIsError ? .red : .secondary, title: L("lastResult"), value: model.status)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            GroupBox(label: Text(L("profiles.standard")).font(.system(size: 13, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 8) {
                    StandardSetPicker(model: model)
                    Text(L("profiles.standardHint")).font(.caption).foregroundColor(.secondary)
                    Button(L("profiles.configureStandard")) { (NSApp.delegate as? AppDelegate)?.showPreferences(tab: 1) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            GroupBox(label: Text(L("profiles.special")).font(.system(size: 13, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L("profiles.enableSpecial"), isOn: Binding(get: { model.profiles.specialEnabled }, set: model.setSpecialEnabled))
                    Button(L("profiles.configureSpecial")) { (NSApp.delegate as? AppDelegate)?.showPreferences(tab: 2) }
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
                Button(L("palette.open")) { (NSApp.delegate as? AppDelegate)?.showPalette() }
                Spacer()
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
    }
}

struct StandardSetPicker: View {
    @ObservedObject var model: Model
    var body: some View {
        Picker(L("profiles.standardSet"), selection: Binding(get: { model.profiles.selected }, set: model.selectStandardSet)) {
            ForEach(StandardShortcutSet.allCases, id: \.self) { Text($0.title).tag($0) }
        }.pickerStyle(.segmented)
    }
}

private struct StandardListWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

struct ShortcutSettingsView: View {
    @ObservedObject var model: Model
    let domain: ShortcutDomain
    @State private var searchText = ""
    @State private var selectedSection = ""
    @State private var standardListWidth: CGFloat = 600
    private var standardColumns: StandardShortcutColumns { StandardShortcutColumns(availableWidth: Double(standardListWidth)) }
    private let catalog = ShortcutCatalog.bundled
    private var filteredRows: [ShortcutRow] {
        catalog.rows.filter { row in
            domain.includes(row) && (selectedSection.isEmpty || row.section.rawValue == selectedSection)
                && row.matches(searchText, currentKey: row.command.map { model.shortcut(for: $0).label })
        }
    }
    private struct RowGroup: Identifiable {
        let id: String
        let title: String
        var rows: [ShortcutRow]
    }
    private func rowGroups(_ rows: [ShortcutRow]) -> [RowGroup] {
        guard domain == .special else { return [RowGroup(id: "standard", title: "", rows: rows)] }
        var groups: [RowGroup] = []
        for row in rows {
            guard let command = row.command else { continue }
            let title: String
            switch command {
            case .alignLeft, .alignRight, .alignTop, .alignBottom, .alignCenter, .alignMiddle:
                title = StartupWindow.text("オブジェクトの整列", "Align Objects", "对象对齐", "객체 정렬")
            case .distributeHorizontally, .distributeVertically:
                title = StartupWindow.text("オブジェクトの均等配置", "Distribute Objects", "对象分布", "객체 분산")
            case .centerBoth, .centerBothGrouped, .centerGrouped, .middleGrouped:
                title = StartupWindow.text("スライドの中央へ移動", "Center on Slide", "移至幻灯片中央", "슬라이드 가운데로 이동")
            case .mask, .resetMask:
                title = StartupWindow.text("マスク", "Mask", "遮罩", "마스크")
            case .hide, .showHidden:
                title = StartupWindow.text("オブジェクトの表示・非表示", "Show and Hide Objects", "显示与隐藏对象", "객체 표시 및 숨기기")
            case .duplicate, .slideSizeShape, .whiteBackground, .whiteRectangle, .centerCross:
                title = StartupWindow.text("複製・図形の作成", "Duplicate and Create Shapes", "复制与创建形状", "복제 및 도형 만들기")
            default:
                title = L("category." + command.category.rawValue)
            }
            if let index = groups.firstIndex(where: { $0.id == title }) { groups[index].rows.append(row) }
            else { groups.append(RowGroup(id: title, title: title, rows: [row])) }
        }
        return groups
    }
    private func visibleCommands(in section: ShortcutSection) -> [KeynoteCommand] {
        filteredRows.filter { $0.section == section }.compactMap(\.command)
    }
    private func setVisibleEnabled(_ section: ShortcutSection, _ enabled: Bool) {
        model.setCommandsEnabled(visibleCommands(in: section), enabled)
    }
    var body: some View {
        if domain == .standard { compactStandardBody }
        else { specialBody }
    }

    /// Standard keys belong with the operation name; a third fixed column wastes
    /// width and forces horizontal scrolling even when editing a single binding.
    private var compactStandardBody: some View {
        let rows = filteredRows
        let sections = ShortcutSection.allCases.filter { section in rows.contains { $0.section == section } }
        return VStack(alignment: .leading, spacing: 12) {
            SettingsSection(domain.title) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.hotkeyStatus).font(.caption).foregroundColor(model.hotkeyFailed ? .red : .secondary)
                    Spacer(minLength: 8)
                    Text(String(format: L("catalog.results"), rows.count)).font(.caption).foregroundColor(.secondary)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { StandardSetPicker(model: model); resetStandardButton }
                    VStack(alignment: .leading, spacing: 8) { StandardSetPicker(model: model); resetStandardButton }
                }
                Text(L("profiles.standardHint")).font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField(L("searchCommands"), text: $searchText).textFieldStyle(.roundedBorder)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).accessibilityLabel(L("clearSearch"))
                    }
                }
                Picker(L("catalog.category"), selection: $selectedSection) {
                    Text(L("catalog.allCategories")).tag("")
                    ForEach(ShortcutSection.allCases.filter { section in catalog.rows.contains { domain.includes($0) && $0.section == section } }, id: \.self) {
                        Text($0.title).tag($0.rawValue)
                    }
                }
                Text(L("catalog.referenceHint")).font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if catalog.unavailable || NativeActionLibrary.bundled.actions.isEmpty { Text(L("catalog.loadFailed")).foregroundColor(.red) }
                if rows.isEmpty { Text(L("noSearchResults")).foregroundColor(.secondary) }
            }
            ForEach(sections, id: \.self) { section in
                SettingsSection(section.title) {
                    Group {
                        if standardColumns.stacked {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L("catalog.operation")).fontWeight(.semibold)
                                Text(model.profiles.selected.title).fontWeight(.semibold).foregroundColor(.secondary)
                            }
                        } else {
                            HStack(alignment: .top, spacing: standardColumns.spacing) {
                                Text(L("catalog.operation")).fontWeight(.semibold)
                                    .frame(width: standardColumns.operationWidth, alignment: .leading)
                                Text(model.profiles.selected.title).fontWeight(.semibold)
                                    .frame(width: standardColumns.bindingWidth, alignment: .leading)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                        .background(GeometryReader { proxy in
                            Color.clear.preference(key: StandardListWidthKey.self, value: proxy.size.width)
                        })
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(rows.filter { $0.section == section }, id: \.id) { row in
                            Divider()
                            if standardColumns.stacked {
                                VStack(alignment: .leading, spacing: 6) {
                                    standardOperation(row).frame(width: standardColumns.operationWidth, alignment: .leading)
                                    standardBinding(row).frame(width: standardColumns.bindingWidth, alignment: .leading)
                                }
                            } else {
                                HStack(alignment: .top, spacing: standardColumns.spacing) {
                                    standardOperation(row).frame(width: standardColumns.operationWidth, alignment: .leading)
                                    standardBinding(row).frame(width: standardColumns.bindingWidth, alignment: .leading)
                                }
                            }
                        }
                    }
                    if rows.contains(where: { $0.section == section && $0.command != nil }) && model.profiles.selected.isEditable {
                        ViewThatFits(in: .horizontal) {
                            HStack { standardEnableButtons(section) }
                            VStack(alignment: .leading) { standardEnableButtons(section) }
                        }.controlSize(.small)
                    }
                }
            }
            SettingsSection(L("notifyTitle")) {
                Toggle(L("notifySuccess"), isOn: Binding(get: { model.notifySuccess }, set: { model.notifySuccess = $0; model.save() }))
                Text(L("notifyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.onPreferenceChange(StandardListWidthKey.self) { width in
            if width > 0, abs(width - standardListWidth) > 0.5 { standardListWidth = width }
        }
    }
    private var resetStandardButton: some View {
        Button(L("resetAllKeys")) { model.resetShortcuts(.standard) }
            .disabled(!model.profiles.selected.isEditable).fixedSize()
    }
    private func standardOperation(_ row: ShortcutRow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let command = row.command, model.canEdit(command) {
                HStack(alignment: .top, spacing: 6) {
                    Toggle("", isOn: Binding(get: { model.configuredEnabled(command) }, set: { model.setEnabled(command, $0) }))
                        .labelsHidden().fixedSize().accessibilityLabel(row.title)
                        .disabled(!model.hotkeysEnabled || !model.profiles.selected.isEditable)
                    Text(row.title).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            if model.hotkeysEnabled && model.profiles.selected.isEditable {
                                model.setEnabled(command, !model.configuredEnabled(command))
                            }
                        }
                }
            } else { Text(row.title).textSelection(.enabled) }
            Text(L("catalog.nativeColumn") + ": " + (row.nativeLabel ?? L("catalog.notListed")))
                .font(.caption).foregroundColor(.secondary).textSelection(.enabled)
        }.fixedSize(horizontal: false, vertical: true)
    }
    @ViewBuilder private func standardBinding(_ row: ShortcutRow) -> some View {
        if let command = row.command, model.canEdit(command) {
            HotkeyField(id: command.rawValue, combo: Binding(get: { model.combo(command) }, set: { model.setCombo(command, $0) }),
                        defaultCombo: command.defaultShortcut.combo, others: model.otherHotkeys(except: command),
                        registered: !model.failedCommands.contains(command.rawValue),
                        isEnabled: model.hotkeysEnabled && model.isEnabled(command),
                        allowsOption: command.defaultShortcut.typesCharacter).controlSize(.small)
        } else if let native = row.native, model.profiles.selected.isEditable {
            NativeBindingFields(model: model, native: native)
        } else {
            Text(row.nativeLabel ?? L("catalog.referenceOnly")).font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    @ViewBuilder private func standardEnableButtons(_ section: ShortcutSection) -> some View {
        Button(L("catalog.enableVisible")) { setVisibleEnabled(section, true) }
        Button(L("catalog.disableVisible")) { setVisibleEnabled(section, false) }
    }
    private var specialBody: some View {
        let rows = filteredRows
        let sections = ShortcutSection.allCases.filter { section in rows.contains { $0.section == section } }
        return VStack(alignment: .leading, spacing: 16) {
                SettingsSection(domain.title) {
                    Text(model.hotkeyStatus).font(.caption).foregroundColor(model.hotkeyFailed ? .red : .secondary).fixedSize(horizontal: false, vertical: true)
                    Text(L(domain == .standard ? "catalog.referenceHint" : "profiles.specialHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    if domain == .standard {
                        StandardSetPicker(model: model)
                        Text(L("profiles.standardHint")).font(.caption).foregroundColor(.secondary)
                    }
                    Button(L("resetAllKeys")) { model.resetShortcuts(domain) }
                        .disabled(domain == .standard && !model.profiles.selected.isEditable)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField(L("searchCommands"), text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                                .buttonStyle(.plain).accessibilityLabel(L("clearSearch"))
                        }
                    }
                    Picker(L("catalog.category"), selection: $selectedSection) {
                        Text(L("catalog.allCategories")).tag("")
                        ForEach(ShortcutSection.allCases.filter { section in catalog.rows.contains { domain.includes($0) && $0.section == section } }, id: \.self) { Text($0.title).tag($0.rawValue) }
                    }
                    Text(String(format: L("catalog.results"), rows.count)).font(.caption).foregroundColor(.secondary)
                    if catalog.unavailable || (domain == .standard && NativeActionLibrary.bundled.actions.isEmpty) { Text(L("catalog.loadFailed")).foregroundColor(.red) }
                    if rows.isEmpty { Text(L("noSearchResults")).foregroundColor(.secondary) }
                }
                ForEach(sections, id: \.self) { section in
                    SettingsSection(section.title) {
                        ScrollView(.horizontal) {
                        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 12) {
                            GridRow {
                                Text(L("catalog.operation")).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                                if domain == .standard { Text(L("catalog.nativeColumn")).fontWeight(.semibold).frame(width: 150, alignment: .leading) }
                                Text(domain == .standard ? model.profiles.selected.title : "KeynoteMaestro").fontWeight(.semibold).frame(width: 420, alignment: .leading)
                            }
                            ForEach(rowGroups(rows.filter { $0.section == section })) { group in
                                if !group.title.isEmpty {
                                    GridRow {
                                        Text(group.title).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                                            .padding(.top, 12).frame(maxWidth: .infinity, alignment: .leading).gridCellColumns(2)
                                    }
                                }
                                ForEach(group.rows, id: \.id) { row in
                                GridRow {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if let command = row.command, model.canEdit(command) {
                                            Toggle(SpecialShortcutDisplay.title(row.title, command: row.command), isOn: Binding(get: { model.configuredEnabled(command) }, set: { model.setEnabled(command, $0) }))
                                                .disabled(!model.hotkeysEnabled || (domain == .standard && !model.profiles.selected.isEditable))
                                            if command == .autoMagicMove {
                                                Text(L("autoMagicMove.hint")).font(.caption).foregroundColor(.secondary)
                                            }
                                            if row.native != nil && row.title != L("command." + command.rawValue) {
                                                Text(L("command." + command.rawValue)).font(.caption).foregroundColor(.secondary)
                                            }
                                        } else {
                                            Text(SpecialShortcutDisplay.title(row.title, command: row.command)).textSelection(.enabled)
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                                    if domain == .standard {
                                    Text(row.nativeLabel ?? L("catalog.notListed"))
                                        .font(.system(size: 12)).foregroundColor(row.native == nil ? .secondary : .primary)
                                        .textSelection(.enabled).frame(width: 150, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .help(row.native?.shortcut ?? L("catalog.notListed"))
                                    }
                                    if let command = row.command, model.canEdit(command) {
                                        HotkeyField(id: command.rawValue, combo: Binding(get: { model.combo(command) }, set: { model.setCombo(command, $0) }),
                                                    defaultCombo: command.defaultShortcut.combo, others: model.otherHotkeys(except: command),
                                                    registered: !model.failedCommands.contains(command.rawValue),
                                                    isEnabled: model.hotkeysEnabled && model.isEnabled(command),
                                                    allowsOption: command.defaultShortcut.typesCharacter)
                                            .controlSize(.small).frame(width: 420, alignment: .leading)
                                    } else if let native = row.native, model.profiles.selected.isEditable {
                                        NativeBindingFields(model: model, native: native)
                                            .frame(width: 420, alignment: .leading)
                                    } else {
                                        Text(row.nativeLabel ?? L("catalog.referenceOnly")).font(.caption).foregroundColor(.secondary)
                                            .frame(width: 420, alignment: .leading)
                                    }
                                }
                            }
                        }
                        }
                        .frame(minWidth: 760, maxWidth: .infinity, alignment: .leading)
                        }
                        if rows.contains(where: { $0.section == section && $0.command != nil }) && (domain == .special || model.profiles.selected.isEditable) {
                            HStack {
                                Button(L("catalog.enableVisible")) { setVisibleEnabled(section, true) }
                                Button(L("catalog.disableVisible")) { setVisibleEnabled(section, false) }
                            }.controlSize(.small).disabled(!model.hotkeysEnabled || (domain == .standard && !model.profiles.selected.isEditable))
                        }
                    }
                }
                SettingsSection(L("notifyTitle")) {
                    Toggle(L("notifySuccess"), isOn: Binding(get: { model.notifySuccess }, set: { model.notifySuccess = $0; model.save() }))
                    Text(L("notifyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
    }
}

struct NativeBindingFields: View {
    @ObservedObject var model: Model
    let native: NativeShortcut
    private var actions: [NativeKeyboardAction] { NativeActionLibrary.bundled.actions(for: native.id) }
    private var unavailableReason: String {
        if native.id == "textFormat.38" { return L("native.styleRequired") }
        return L("native.mouseOnly")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if actions.isEmpty {
                Text(unavailableReason)
                    .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(actions) { action in
                    if !action.label.isEmpty { Text(action.label).font(.caption).foregroundColor(.secondary) }
                    HotkeyField(id: "native." + action.id,
                                combo: Binding(get: { model.nativeCombo(action.id) }, set: { model.setNativeBinding(action.id, $0) }),
                                allowsClear: true, others: model.otherNativeHotkeys(except: action.id),
                                registered: !model.failedNativeActions.contains(action.id), isEnabled: model.hotkeysEnabled)
                        .controlSize(.small)
                }
            }
        }
    }
}

struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        return SettingsTabs(sections: [
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
            (L("profiles.standardTab"), AnyView(ShortcutSettingsView(model: model, domain: .standard))),
            (L("profiles.specialTab"), AnyView(ShortcutSettingsView(model: model, domain: .special))),
            (L("palette.tab"), AnyView(PaletteSettingsView(model: model))),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 720, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, NSMenuItemValidation {
    var model: Model!
    var item: NSStatusItem!
    var mainWindow: NSWindow?
    var preferences: NSWindow?
    var helpWindow: NSWindow?
    var commandPalette: CommandPalette?
    let menu = NSMenu()
    var resultItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        model = Model()
        SettingsSync.shared.onImport = { [weak self] in self?.model.reload() }
        SettingsSync.shared.start(.init(
            keys: ["notifySuccess", "commandEnabled", "commandShortcuts", ShortcutProfiles.storageKey, PaletteVisibility.storageKey, PaletteDisplayHotkey.storageKey],
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
        item.button?.setAccessibilityLabel("KeynoteMaestro")
        menu.delegate = self
        resultItem = menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, L("openMainWindow"), #selector(openMainWindow))
        add(menu, L("palette.open"), #selector(showPalette))
        add(menu, L("palette.settings"), #selector(showPalettePreferences))
        add(menu, L("settings"), #selector(showPreferencesAction))
        add(menu, L("pause"), #selector(togglePause))
        menu.addItem(.separator())
        // Help submenu: app help and the note article (BASELINE「メニューの共通構成」).
        let statusHelp = NSMenu(title: L("help")); add(statusHelp, L("appHelp"), #selector(help)); HelpLinks.addNoteItem(to: statusHelp)
        menu.setSubmenu(statusHelp, for: menu.addItem(withTitle: L("help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator()); add(menu, L("quit"), #selector(quit))
        item.menu = menu
        MenuBarPresence.shared.install(name: "KeynoteMaestro", symbol: "play.rectangle", existing: item,
            show: { [weak self] in self?.showMainWindow() },
            settings: { [weak self] in self?.showPreferences() },
            help: { [weak self] in self?.help() })
        if !LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent) && !StartupWindow.suppressInitialWindow { showMainWindow() }
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
        add(fileMenu, L("palette.open"), #selector(showPalette))
        add(fileMenu, L("palette.settings"), #selector(showPalettePreferences))
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
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        StartupWindow.userRequestedWindow(); showMainWindow(); return true }
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
        // Keep a document-wide script or PNG export alive until its result is reported (B11).
        guard model.runner.busy else { return .terminateNow }
        model.report(.failure(L("quitBusy")))
        return .terminateCancel
    }
    func applicationWillTerminate(_ notification: Notification) { model?.stop() }

    @objc func showPalettePreferences() { showPreferences(tab: 3) }
    @objc func showPalette() {
        if commandPalette == nil { commandPalette = CommandPalette(model: model) }
        commandPalette?.show()
    }
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
    @objc func showPreferencesAction() { AppSwitcherWindowReveal.preserveAuxiliaryWindowOnActivation(); showPreferences() }
    /// `tab` selects a tab by its index (the 「ホットキー一覧」 button of the main window opens 1, the hotkeys).
    func showPreferences(tab: Int? = nil) { AppSwitcherWindowReveal.preserveAuxiliaryWindowOnActivation();
        model.refreshLogin()
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 620), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle")
            let hosting = NSHostingView(rootView: Preferences(model: model))
            // The explicit minimum below controls resizing; tab content must not lock the window width.
            hosting.sizingOptions = []
            window.contentView = hosting
            window.contentMinSize = NSSize(width: 720, height: 560)
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("Preferences")
            // Shrink an inherited oversized frame once; subsequent user resizing is preserved.
            if !UserDefaults.standard.bool(forKey: "compactStandardSettingsV1") {
                let current = window.contentLayoutRect.size
                let top = window.frame.maxY
                window.setContentSize(NSSize(width: max(720, min(current.width, 820)), height: max(560, min(current.height, 620))))
                window.setFrameOrigin(NSPoint(x: window.frame.minX, y: top - window.frame.height))
                UserDefaults.standard.set(true, forKey: "compactStandardSettingsV1")
            }
            preferences = window
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
    @objc func help() { AppSwitcherWindowReveal.preserveAuxiliaryWindowOnActivation();
        if helpWindow == nil { helpWindow = HelpDocument.makeWindow(windowTitle: "KeynoteMaestro — " + L("help"), text: L("helpText") + "\n\n" + keyList(), heading: L("helpHeading")) }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    /// The default keys by category, generated so the help never disagrees with the code.
    func keyList() -> String {
        "## " + L("help.defaultKeys") + "\n" + ShortcutSection.allCases.filter { !$0.commands.isEmpty }.map { category in
            "### " + category.title + "\n" + category.commands.map { "- **\($0.defaultShortcut.label)** " + L("command." + $0.rawValue) }.joined(separator: "\n")
        }.joined(separator: "\n")
    }
    @objc func togglePause() { model.togglePause() }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary ?? [:]
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "KeynoteMaestro",
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
