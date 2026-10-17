import AppKit
import ServiceManagement
import ApplicationServices

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// Settings, hotkey registration and the action runner.
final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var shortcuts: [LinkAction: Shortcut] = [:]
    @Published var actionEnabled: [LinkAction: Bool] = [:]
    /// Runs on a double tap of its key (DocklessLauncher's doubleTap). A key can carry one single and one double function.
    @Published var doubleTap: [LinkAction: Bool] = [:]
    /// Missing key = on.
    @Published var browserEnabled = UserDefaults.standard.dictionary(forKey: "browserEnabled") as? [String: Bool] ?? [:]
    @Published var simplifyURL = UserDefaults.standard.object(forKey: "simplifyURL") as? Bool ?? true
    @Published var associateID = UserDefaults.standard.string(forKey: "associateID") ?? Model.defaultAssociateID
    /// The macro's 「アソシエイトID」 (事前に変更してください): cssnite.
    static let defaultAssociateID = "cssnite"
    @Published var notifySuccess = UserDefaults.standard.object(forKey: "notifySuccess") as? Bool ?? true
    @Published var translateTarget = UserDefaults.standard.string(forKey: "translateTarget") ?? Model.systemLanguage
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    @Published var paused = false
    /// Apps where the 「選択した文字列から」 functions never take their keys (the misc group's excluded apps).
    static let defaultExcludedApps = ["com.adobe.illustrator", "com.adobe.InDesign", "com.adobe.Photoshop", "com.microsoft.Word"]
    /// True while the shared HotkeyRecorder records a key; every hotkey stays unregistered meanwhile.
    @Published var recording = false
    @Published var paletteShortcut = UserDefaults.standard.data(forKey: "paletteShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? Model.defaultPaletteShortcut
    @Published var paletteHotkeyEnabled = UserDefaults.standard.object(forKey: "paletteHotkeyEnabled") as? Bool ?? true
    /// Show the palette instead of the main window at launch and on reopen (KakkoReplace's paletteMode).
    @Published var paletteMode = UserDefaults.standard.bool(forKey: "paletteMode")
    @Published var paletteFailure: OSStatus?
    /// 「簡易モード」: the palette shows only the chosen buttons (MightyEdit's palette profiles). Off = 「全部入り」.
    @Published var paletteSimple = UserDefaults.standard.bool(forKey: "paletteSimple")
    @Published var simpleActions = Model.savedSimpleActions()
    static let defaultSimpleActions: Set<LinkAction> = [.copyAsk, .copyURL, .copyMarkdown, .tabsURLs, .weblocAsk, .reloadClean, .editMode]
    static func savedSimpleActions() -> Set<LinkAction> {
        UserDefaults.standard.stringArray(forKey: "paletteSimpleActions").map { Set($0.compactMap(LinkAction.init(rawValue:))) } ?? defaultSimpleActions
    }
    /// ⌃⌥⌘M (2026-10-17, was ⌃⇧⌘K). FolderHopper uses the same key in Finder and Path Finder.
    static let defaultPaletteShortcut = Shortcut.km(46, 6400, "M")
    var onPaletteHotkey: (() -> Void)?
    @Published var failures: [LinkAction: OSStatus] = [:]
    @Published var duplicates: Set<LinkAction> = []
    @Published var status = L("ready")
    @Published var statusIsError = false
    @Published var loginStatus = ""
    @Published var loginOn = false
    @Published var busy = false

    let hotkeys = HotKeySet(signature: 0x4D4B_4C4B)        // 'MKLK'
    /// The palette key works in every app (like KakkoReplace's ⌥⇧⌘U), so it is registered separately.
    let paletteHotkey = HotKeySet(signature: 0x4D4B_4C50)  // 'MKLP'
    /// The last enabled browser in front: menu-bar items act on it (clicking the menu bar does not change the front app).
    private(set) var lastBrowserPID: pid_t?
    /// The last app in front other than LinkMaker: the 「選択した文字列から」 functions in the menu act on it.
    private(set) var lastExternalPID: pid_t?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObserver: NSObjectProtocol?
    private var registeredState: String?

    static var systemLanguage: String {
        let code = Locale.preferredLanguages.first.map { String($0.prefix(while: { $0 != "-" })) } ?? "ja"
        return code == "zh" ? "zh-CN" : code
    }

    init() {
        var saved = (defaults.data(forKey: "shortcuts").flatMap { try? JSONDecoder().decode([String: Shortcut].self, from: $0) }) ?? [:]
        var enabled = defaults.dictionary(forKey: "actionEnabled") as? [String: Bool] ?? [:]
        // 1.2.3: ⌥W / ⌥Q moved to the combined webloc / QR functions. Saved copies on the old front-Finder functions
        // would clash with them, so those are released once (other keys the user chose are kept).
        if !defaults.bool(forKey: "migratedFileAskKeys") {
            for (old, key) in [("weblocFinder", "13:2048"), ("qrFinder", "12:2048")] where saved[old]?.signature == key {
                saved[old] = nil; enabled[old] = false
            }
            defaults.set(try? JSONEncoder().encode(saved), forKey: "shortcuts")
            defaults.set(enabled, forKey: "actionEnabled")
            defaults.set(true, forKey: "migratedFileAskKeys")
        }
        let taps = defaults.dictionary(forKey: "doubleTap") as? [String: Bool] ?? [:]
        for action in LinkAction.allCases {
            if let s = saved[action.rawValue] ?? action.defaultShortcut { shortcuts[action] = s }
            actionEnabled[action] = enabled[action.rawValue] ?? (action.defaultShortcut != nil)
            doubleTap[action] = taps[action.rawValue] ?? action.defaultDoubleTap
        }
        hotkeys.action = { [weak self] number in
            guard let self, let shortcut = self.registeredKeys[number] else { return }
            self.pressed(shortcut)
        }
        paletteHotkey.action = { [weak self] _ in self?.onPaletteHotkey?() }
        // Event-driven: the hotkeys exist only while an enabled browser is in front (B13, B21), like the KM group's 「Included」 apps.
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, let self {
                if self.isEnabledBrowser(app) { self.lastBrowserPID = app.processIdentifier }
                if app.processIdentifier != ProcessInfo.processInfo.processIdentifier { self.lastExternalPID = app.processIdentifier }
            }
            self?.refreshHotkeys()
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshLogin(); self?.refreshHotkeys()
        })
        if let front = NSWorkspace.shared.frontmostApplication, isEnabledBrowser(front) { lastBrowserPID = front.processIdentifier }
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ProcessInfo.processInfo.processIdentifier { lastExternalPID = front.processIdentifier }
        refreshLogin(); refreshHotkeys()
    }

    func save() {
        let saved = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        defaults.set(try? JSONEncoder().encode(saved), forKey: "shortcuts")
        defaults.set(Dictionary(uniqueKeysWithValues: actionEnabled.map { ($0.key.rawValue, $0.value) }), forKey: "actionEnabled")
        defaults.set(Dictionary(uniqueKeysWithValues: doubleTap.map { ($0.key.rawValue, $0.value) }), forKey: "doubleTap")
        defaults.set(browserEnabled, forKey: "browserEnabled")
        defaults.set(simplifyURL, forKey: "simplifyURL")
        defaults.set(associateID, forKey: "associateID")
        defaults.set(notifySuccess, forKey: "notifySuccess")
        defaults.set(translateTarget, forKey: "translateTarget")
        defaults.set(keepRunning, forKey: "keepRunning")
        defaults.set(try? JSONEncoder().encode(paletteShortcut), forKey: "paletteShortcut")
        defaults.set(paletteHotkeyEnabled, forKey: "paletteHotkeyEnabled")
        defaults.set(paletteMode, forKey: "paletteMode")
        defaults.set(paletteSimple, forKey: "paletteSimple")
        defaults.set(simpleActions.map(\.rawValue).sorted(), forKey: "paletteSimpleActions")
        refreshHotkeys()
    }

    /// Re-reads the synced settings after SettingsSync applied another Mac's values; save() would otherwise write the old ones back.
    func reload() {
        let saved = (defaults.data(forKey: "shortcuts").flatMap { try? JSONDecoder().decode([String: Shortcut].self, from: $0) }) ?? [:]
        let enabled = defaults.dictionary(forKey: "actionEnabled") as? [String: Bool] ?? [:]
        let taps = defaults.dictionary(forKey: "doubleTap") as? [String: Bool] ?? [:]
        var newShortcuts: [LinkAction: Shortcut] = [:]
        for action in LinkAction.allCases {
            if let s = saved[action.rawValue] ?? action.defaultShortcut { newShortcuts[action] = s }
            actionEnabled[action] = enabled[action.rawValue] ?? (action.defaultShortcut != nil)
            doubleTap[action] = taps[action.rawValue] ?? action.defaultDoubleTap
        }
        shortcuts = newShortcuts
        browserEnabled = defaults.dictionary(forKey: "browserEnabled") as? [String: Bool] ?? [:]
        simplifyURL = defaults.object(forKey: "simplifyURL") as? Bool ?? true
        associateID = defaults.string(forKey: "associateID") ?? Model.defaultAssociateID
        notifySuccess = defaults.object(forKey: "notifySuccess") as? Bool ?? true
        translateTarget = defaults.string(forKey: "translateTarget") ?? Model.systemLanguage
        paletteShortcut = defaults.data(forKey: "paletteShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? Model.defaultPaletteShortcut
        paletteHotkeyEnabled = defaults.object(forKey: "paletteHotkeyEnabled") as? Bool ?? true
        paletteMode = defaults.bool(forKey: "paletteMode")
        paletteSimple = defaults.bool(forKey: "paletteSimple")
        simpleActions = Model.savedSimpleActions()
        MainActor.assumeIsolated { HotkeyRecorder.shared.stop() }
        refreshHotkeys()
    }

    // MARK: Palette

    func showsInPalette(_ action: LinkAction) -> Bool { !paletteSimple || simpleActions.contains(action) }
    func setSimple(_ action: LinkAction, _ shown: Bool) {
        if shown { simpleActions.insert(action) } else { simpleActions.remove(action) }
        save()
    }
    func resetSimpleActions() { simpleActions = Model.defaultSimpleActions; save() }

    // MARK: Browsers

    func isEnabled(_ browser: Browser) -> Bool { browserEnabled[browser.bundleID] ?? true }
    func setEnabled(_ browser: Browser, _ value: Bool) { browserEnabled[browser.bundleID] = value; save() }
    func isEnabledBrowser(_ app: NSRunningApplication?) -> Bool {
        guard let browser = Browser.find(app?.bundleIdentifier) else { return false }
        return isEnabled(browser)
    }

    // MARK: Excluded apps (「選択した文字列から」)

    func isExcluded(_ app: NSRunningApplication?) -> Bool {
        guard let app else { return true }
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { return true }
        return MainActor.assumeIsolated { ExcludedApps.shared.excludes(app.bundleIdentifier) }
    }
    /// 「初期値に戻す」 under the shared list: Illustrator, InDesign, Photoshop and Word again.
    func resetExcludedApps() {
        // reset(to:) saves and runs onChange (hotkeys and the palette are refreshed there).
        MainActor.assumeIsolated { ExcludedApps.shared.reset(to: Model.defaultExcludedApps) }
    }

    // MARK: Hotkeys

    func isActive(_ action: LinkAction) -> Bool { (actionEnabled[action] ?? false) && shortcuts[action] != nil }
    func isDouble(_ action: LinkAction) -> Bool { doubleTap[action] ?? false }
    func label(_ action: LinkAction) -> String { shortcuts[action].map { $0.label + (isDouble(action) ? " ×2" : "") } ?? L("noKey") }
    /// Key + tap count: what must be unique among enabled functions.
    func trigger(_ action: LinkAction) -> String? { shortcuts[action].map { $0.signature + (isDouble(action) ? "×2" : "") } }
    func setDoubleTap(_ action: LinkAction, _ value: Bool) { doubleTap[action] = value; save() }

    /// The functions a key can run with this app in front: browser functions in an enabled browser,
    /// 「選択した文字列から」 in any app that is not excluded.
    func applies(_ action: LinkAction, front: NSRunningApplication?) -> Bool {
        action.isGlobal ? !isExcluded(front) : isEnabledBrowser(front)
    }

    /// A key with a double-tap function waits this long for the second press before running its single-press function.
    static let doubleTapInterval: TimeInterval = min(max(NSEvent.doubleClickInterval, 0.25), 0.4)
    private var pendingTap: (signature: String, work: DispatchWorkItem)?
    /// Carbon id → key. Each key is registered once even when it has a single and a double function.
    private var registeredKeys: [UInt32: Shortcut] = [:]

    /// A registered key went down (DocklessLauncher's pressed): without a double-tap function the single one runs at once;
    /// with one, a second press within `doubleTapInterval` runs it, otherwise the single function runs after the wait.
    func pressed(_ shortcut: Shortcut) {
        guard !paused, !recording else { return }
        let front = NSWorkspace.shared.frontmostApplication
        let live = LinkAction.allCases.filter { isActive($0) && !duplicates.contains($0) && shortcuts[$0]?.signature == shortcut.signature && applies($0, front: front) }
        let single = live.first { !isDouble($0) }
        guard let double = live.first(where: isDouble) else { if let single { perform(single, fromHotkey: true) }; return }
        if let pending = pendingTap, pending.signature == shortcut.signature {
            pending.work.cancel(); pendingTap = nil
            perform(double, fromHotkey: true)
            return
        }
        pendingTap?.work.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingTap = nil
            if let single { self?.perform(single, fromHotkey: true) }
        }
        pendingTap = (shortcut.signature, work)
        DispatchQueue.main.asyncAfter(deadline: .now() + Model.doubleTapInterval, execute: work)
    }

    func refreshHotkeys() {
        let active = LinkAction.allCases.filter(isActive)
        // Same key and tap count on two functions: neither is registered, and both are shown (B07).
        var byTrigger: [String: [LinkAction]] = [:]
        for action in active { byTrigger[trigger(action)!, default: []].append(action) }
        duplicates = Set(byTrigger.values.filter { $0.count > 1 }.flatMap { $0 })
        refreshPaletteHotkey()
        if paletteHotkeyEnabled { duplicates.formUnion(active.filter { shortcuts[$0]!.signature == paletteShortcut.signature }) }
        let wanted = !paused && !recording
        let frontApp = NSWorkspace.shared.frontmostApplication
        let usable = active.filter { !duplicates.contains($0) }
        // Registered only while one of the key's functions applies to the app in front (B13, B21).
        let applying = Set(usable.filter { applies($0, front: frontApp) }.map { shortcuts[$0]!.signature })
        let state = "\(wanted):" + applying.sorted().joined(separator: ",") + "|" + usable.map { "\($0.rawValue)=\(trigger($0)!)" }.joined(separator: ",")
        guard state != registeredState else { return }
        registeredState = state
        hotkeys.unregisterAll(); registeredKeys = [:]
        var failed: [LinkAction: OSStatus] = [:]
        if wanted {
            var keys: [Shortcut] = []
            for action in usable where !keys.contains(where: { $0.signature == shortcuts[action]!.signature }) { keys.append(shortcuts[action]!) }
            for (index, key) in keys.enumerated() {
                let number = UInt32(index + 1)
                let result = hotkeys.register(number, key)
                if result != noErr {
                    for action in usable where shortcuts[action]?.signature == key.signature { failed[action] = result }
                } else if applying.contains(key.signature) {
                    registeredKeys[number] = key
                } else {
                    // Registered to detect failures even where it does not apply; then released so the key passes through.
                    hotkeys.unregister(number)
                }
            }
        }
        failures = failed
        publishHotkeys()
    }

    /// Registered in every app; not affected by the browser check or the pause (it only shows the palette).
    private var paletteRegistered: String?
    func refreshPaletteHotkey() {
        let state = paletteHotkeyEnabled && !recording ? paletteShortcut.signature : ""
        guard state != paletteRegistered else { return }
        paletteRegistered = state
        paletteHotkey.unregisterAll()
        paletteFailure = nil
        if !state.isEmpty {
            let result = paletteHotkey.register(1, paletteShortcut)
            if result != noErr { paletteFailure = result }
        }
    }
    /// Keys HotkeyField must refuse for `action` (nil = the palette): enabled functions with the same tap count, and the palette.
    /// A single-press and a double-tap function may share a key, as before.
    func otherHotkeys(except action: LinkAction?) -> [(String, KeyCombo)] {
        var result: [(String, KeyCombo)] = LinkAction.allCases.compactMap { other in
            guard other != action, isActive(other), let shortcut = shortcuts[other] else { return nil }
            if let action, isDouble(other) != isDouble(action) { return nil }
            if action == nil, isDouble(other) { return nil }
            return (L(other.titleKey), KeyCombo(shortcut))
        }
        if action != nil, paletteHotkeyEnabled { result.append((L("showPalette"), KeyCombo(paletteShortcut))) }
        return result
    }
    /// From HotkeyField: a recorded key turns the function on; clearing turns it off.
    func setShortcut(_ action: LinkAction, _ combo: KeyCombo?) {
        if let combo { shortcuts[action] = Shortcut(combo); actionEnabled[action] = true } else { clearShortcut(action) }
        save()
    }

    /// Declares the hotkeys for HotkeyHound (shared registrations cannot be listed from outside).
    func publishHotkeys() {
        let apps = Browser.all.filter(isEnabled).map(\.bundleID)
        var items = LinkAction.allCases.compactMap { action -> HotkeyManifest.Item? in
            guard let s = shortcuts[action] else { return nil }
            return HotkeyManifest.Item(id: action.rawValue, title: L(action.titleKey), keyCode: Int(s.code), modifiers: Int(s.modifiers),
                                       enabled: actionEnabled[action] ?? false, scope: action.isGlobal ? "except" : "only",
                                       apps: action.isGlobal ? MainActor.assumeIsolated { ExcludedApps.shared.ids } : apps, note: isDouble(action) ? L("doubleTapNote") : nil)
        }
        items.append(HotkeyManifest.Item(id: "palette", title: L("showPalette"), keyCode: Int(paletteShortcut.code), modifiers: Int(paletteShortcut.modifiers),
                                         enabled: paletteHotkeyEnabled))
        HotkeyManifest.publish(items)
    }

    var hotkeySummary: String {
        if paused { return L("hotkeyPaused") }
        let count = LinkAction.allCases.filter(isActive).count
        if !failures.isEmpty || !duplicates.isEmpty { return String(format: L("hotkeyProblems"), String(failures.count + duplicates.count)) }
        return String(format: L("hotkeyActive"), String(count))
    }
    var hotkeyProblem: Bool { !failures.isEmpty || !duplicates.isEmpty }

    func resetShortcut(_ action: LinkAction) {
        if let s = action.defaultShortcut { shortcuts[action] = s } else { shortcuts[action] = nil }
        doubleTap[action] = action.defaultDoubleTap
        actionEnabled[action] = action.defaultShortcut != nil
        save()
    }
    func clearShortcut(_ action: LinkAction) { shortcuts[action] = nil; actionEnabled[action] = false; save() }
    func resetAllShortcuts() { for action in LinkAction.allCases { resetShortcut(action) } }
    func togglePause() { paused.toggle(); refreshHotkeys() }

    // MARK: Running

    /// Hotkey: the browser in front. Menu: the last browser that was in front (it is brought forward first).
    func perform(_ action: LinkAction, fromHotkey: Bool = false) {
        guard !busy else { return }
        if fromHotkey && (paused || !isActive(action)) { return }
        let front = NSWorkspace.shared.frontmostApplication
        var target: NSRunningApplication?
        if isEnabledBrowser(front) { target = front }
        else if let pid = lastBrowserPID, let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated, isEnabledBrowser(app) { target = app }
        let runner = ActionRunner(model: self)
        if action.isGlobal {
            // Hotkey: the app in front. Menu/palette: front stays (non-activating), else the last app used.
            var app = front
            if app?.processIdentifier == ProcessInfo.processInfo.processIdentifier, let pid = lastExternalPID { app = NSRunningApplication(processIdentifier: pid) }
            guard let app, !app.isTerminated else { report(.failure(L("fail.noApp"))); return }
            guard !isExcluded(app) else { report(.failure(String(format: L("fail.excluded"), app.localizedName ?? ""))); return }
            guard AccessibilitySection.isTrusted else { report(.failure(AccessibilityText.text("blocked"))); return }
            busy = true
            let run = { [weak self] in
                if fromHotkey, NSWorkspace.shared.frontmostApplication?.processIdentifier != app.processIdentifier {
                    self?.busy = false; self?.report(.failure(L("fail.target"))); return
                }
                runner.runSelection(action, app: app) { outcome in self?.busy = false; self?.report(outcome) }
            }
            if front?.processIdentifier == app.processIdentifier { run() }
            else { app.activate(options: []); DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: run) }
            return
        }
        if action.needsPage || action.group == .tabs {
            guard let app = target, let browser = Browser.find(app.bundleIdentifier) else { report(.failure(L("fail.noBrowser"))); return }
            guard AccessibilitySection.isTrusted || action.group == .tabs else { report(.failure(AccessibilityText.text("blocked"))); return }
            busy = true
            let run = { [weak self] in
                // Checked again right before acting: the front app may have changed since the key press (B21).
                if fromHotkey, NSWorkspace.shared.frontmostApplication?.processIdentifier != app.processIdentifier {
                    self?.busy = false; self?.report(.failure(L("fail.target"))); return
                }
                runner.run(action, browser: browser, app: app) { outcome in self?.busy = false; self?.report(outcome) }
            }
            if front?.processIdentifier == app.processIdentifier { run() }
            else { app.activate(options: []); DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: run) }
        } else {
            busy = true
            let browser = target.flatMap { Browser.find($0.bundleIdentifier) }
            runner.runClipboard(action, browser: browser) { [weak self] outcome in self?.busy = false; self?.report(outcome) }
        }
    }

    func report(_ outcome: ActionOutcome) {
        switch outcome {
        case .success(let message):
            status = message; statusIsError = false
            if notifySuccess { MainActor.assumeIsolated { TransientMessage.show(message) } }
        case .failure(let reason):
            status = reason; statusIsError = true
            NSSound.beep()
            // Never just a beep (B27).
            MainActor.assumeIsolated { TransientMessage.show(reason) }
        case .silent:
            break
        }
    }

    // MARK: Login item

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
        hotkeys.unregisterAll(); paletteHotkey.unregisterAll()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

enum ActionOutcome {
    case success(String)
    case failure(String)
    /// Finished without a message (the browser shows the result itself).
    case silent
}
