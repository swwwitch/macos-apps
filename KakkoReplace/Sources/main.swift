import AppKit
import SwiftUI
import ServiceManagement
import Carbon
import UniformTypeIdentifiers

final class Model: ObservableObject {
    @Published var disabled = UserDefaults.standard.bool(forKey: "disabled")
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    @Published var paletteMode = UserDefaults.standard.bool(forKey: "paletteMode")
    @Published var paused = false
    @Published var excluded = UserDefaults.standard.stringArray(forKey: "excluded") ?? []
    @Published var bindings = Shortcut.loadBindings()
    @Published var selectedAction = "round"
    @Published var forceWrap = UserDefaults.standard.bool(forKey: "forceWrap")
    @Published var trimSpaces = UserDefaults.standard.bool(forKey: "trimSpaces")
    @Published var registrationFailures: [String: OSStatus] = [:]
    var shortcut: Shortcut? { bindings[selectedAction] }
    var statusChanged: ((String) -> Void)?
    @Published var status = L("ready") { didSet { statusChanged?(status) } }
    @Published var recording = false
    @Published var recordingFront = false
    @Published var frontEnabled = UserDefaults.standard.object(forKey: "bringToFrontEnabled") as? Bool ?? true
    @Published var frontShortcut = UserDefaults.standard.data(forKey: "bringToFrontShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .bringToFront
    @Published var frontStatus = ""
    @Published var frontFailed = false
    @Published var loginStatus = ""
    @Published var loginOn = false
    let hotkey = HotKey()
    let frontHotkey = FrontHotKey()
    let editor = Editor()
    var monitor: Any?
    var observers: [NSObjectProtocol] = []
    var workspaceObserver: NSObjectProtocol?
    var departureObserver: NSObjectProtocol?
    var pending = false
    var releaseTimer: Timer?
    /// What is registered now; app switches re-register only when this changes (MightyEdit's refreshForFrontApp).
    var registeredState: String?
    var registeredFrontState: String?
    init() {
        hotkey.action = { [weak self] action in self?.trigger(action) }
        frontHotkey.action = { (NSApp.delegate as? AppDelegate)?.showPalette() }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            self?.refreshHotkey()
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { (NSApp.delegate as? AppDelegate)?.applicationActivated(app) }
        }
        departureObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main) { notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { (NSApp.delegate as? AppDelegate)?.applicationDeactivated(app) }
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshLogin(); self?.refreshHotkey() })
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.recording else { return event }
            if event.keyCode == 53 { self.recording = false; self.recordingFront = false; self.refreshHotkey(); return nil }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            // Preserve standard editing, window and quit shortcuts.
            let standard: Set<UInt16> = [0, 6, 7, 8, 9, 12, 13, 43]
            guard !flags.intersection([.command, .option, .control]).isEmpty,
                  !(flags == .command && standard.contains(event.keyCode)),
                  let key = event.charactersIgnoringModifiers, !key.isEmpty else { self.status = L("invalidShortcut"); return nil }
            var mods: UInt32 = 0
            if flags.contains(.command) { mods |= UInt32(cmdKey) }
            if flags.contains(.shift) { mods |= UInt32(shiftKey) }
            if flags.contains(.option) { mods |= UInt32(optionKey) }
            if flags.contains(.control) { mods |= UInt32(controlKey) }
            let prefix = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "") + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "")
            let candidate = Shortcut(code: UInt32(event.keyCode), modifiers: mods, label: prefix + (event.keyCode == 25 ? "9" : key.uppercased()))
            if self.recordingFront {
                guard !self.bindings.values.contains(where: { $0.signature == candidate.signature }) else { self.status = L("duplicateShortcut"); return nil }
                self.frontShortcut = candidate; self.frontEnabled = true
                self.recording = false; self.recordingFront = false; self.save(); return nil
            }
            guard !self.bindings.contains(where: { $0.key != self.selectedAction && $0.value.signature == candidate.signature }),
                  !(self.frontEnabled && self.frontShortcut.signature == candidate.signature) else { self.status = L("duplicateShortcut"); return nil }
            self.bindings[self.selectedAction] = candidate
            self.recording = false; self.save(); return nil
        }
        refreshLogin(); refreshHotkey()
    }
    func save() {
        UserDefaults.standard.set(paletteMode, forKey: "paletteMode")
        UserDefaults.standard.set(keepRunning, forKey: "keepRunning")
        UserDefaults.standard.set(disabled, forKey: "disabled")
        UserDefaults.standard.set(excluded, forKey: "excluded")
        UserDefaults.standard.set(try? JSONEncoder().encode(bindings), forKey: "bracketBindings")
        UserDefaults.standard.set(forceWrap, forKey: "forceWrap")
        UserDefaults.standard.set(trimSpaces, forKey: "trimSpaces")
        UserDefaults.standard.set(frontEnabled, forKey: "bringToFrontEnabled")
        UserDefaults.standard.set(try? JSONEncoder().encode(frontShortcut), forKey: "bringToFrontShortcut")
        refreshHotkey()
    }
    func allowed(_ app: NSRunningApplication?) -> Bool {
        guard let app, let id = app.bundleIdentifier else { return false }
        return !excluded.contains(id) && id != Bundle.main.bundleIdentifier
    }
    func refreshHotkey() {
        refreshFrontHotkey()
        let active = !disabled && !paused && !recording && allowed(NSWorkspace.shared.frontmostApplication)
        let state = active ? bindings.map { "\($0.key)=\($0.value.signature)" }.sorted().joined(separator: ",") : ""
        guard state != registeredState else { return }
        registeredState = state
        if active {
            registrationFailures = hotkey.register(bindings)
            if !registrationFailures.isEmpty { status = L("registrationFailed") }
        } else { _ = hotkey.register([:]) }
    }
    /// Registered before the bracket hotkeys so it wins a conflict. Blocked only while KakkoReplace
    /// itself is in front or a key is being recorded (MightyEdit's B21).
    func refreshFrontHotkey() {
        let blocked = recording || NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
        let state = "\(frontEnabled):\(frontShortcut.signature):\(blocked)"
        guard state != registeredFrontState else { return }
        registeredFrontState = state
        let result = frontHotkey.register(frontEnabled ? frontShortcut : nil, blocked: blocked)
        frontFailed = frontEnabled && result != noErr
        frontStatus = !frontEnabled ? L("frontDisabled") : result == noErr ? String(format: L("frontEnabledStatus"), frontShortcut.label) : String(format: L("frontRegisterFailed"), String(result))
    }
    func resetFrontShortcut() {
        frontShortcut = .bringToFront; frontEnabled = true; recording = false; recordingFront = false; save()
    }
    func resetShortcut() {
        let candidate = Shortcut.articleDefaults[selectedAction]
        if let candidate, bindings.contains(where: { $0.key != selectedAction && $0.value.signature == candidate.signature }) { status = L("duplicateShortcut"); return }
        bindings[selectedAction] = candidate; recording = false; save()
    }
    /// Runs as soon as the hotkey is pressed (MightyEdit's performOnPress); editing goes through AX, so held
    /// modifiers do not leak into the target. The gate stays closed until the trigger key is up, so key repeat never runs it twice.
    func trigger(_ action: String = "round") {
        guard !pending, !disabled, !paused, !recording, allowed(NSWorkspace.shared.frontmostApplication), let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return }
        pending = true
        if action == "palette" { (NSApp.delegate as? AppDelegate)?.showPalette() }
        else {
            status = editor.perform(pid: pid, action: action, force: forceWrap, trimSpaces: trimSpaces)
            if status != L("success") && status != L("unchanged") { NSSound.beep() }
        }
        let key = CGKeyCode(bindings[action]?.code ?? 0)
        let started = Date()
        releaseTimer?.invalidate()
        let timer = Timer(timeInterval: 0.02, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            // Reopen once the trigger key is up (or after 10 s if the key state is never reported).
            if !CGEventSource.keyState(.combinedSessionState, key: key) || Date().timeIntervalSince(started) > 10 {
                timer.invalidate(); self.releaseTimer = nil; self.pending = false
            }
        }
        releaseTimer = timer
        RunLoop.main.add(timer, forMode: .common)
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
    /// Only suggest moving the app when it is outside /Applications and ~/Applications.
    static var isInApplicationsFolder: Bool {
        let parent = Bundle.main.bundleURL.resolvingSymlinksInPath().deletingLastPathComponent().standardizedFileURL.path
        let folders = ["/Applications", FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").standardizedFileURL.path]
        return folders.contains { parent == $0 || parent.hasPrefix($0 + "/") }
    }
    /// Settings and the menu bar use the same excluded-app check as the palette before restoring.
    func restoreLastChange() {
        guard let pid = editor.recoveryPID else { status = editor.restore(); return }
        guard !disabled, !paused, !recording else { status = L("pausedHint"); return }
        let front = NSWorkspace.shared.frontmostApplication
        let frontIsExternal = front?.bundleIdentifier != Bundle.main.bundleIdentifier
        guard let target = NSRunningApplication(processIdentifier: pid), !target.isTerminated, allowed(target),
              !frontIsExternal || allowed(front) else { status = L("restoreExcluded"); return }
        status = editor.restore(expectedPID: pid)
    }
    func changeLogin(_ value: Bool) {
        do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; refreshLogin() }
        catch { refreshLogin(); loginStatus = L("loginFailed") + error.localizedDescription }
    }
    func addApp() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]; panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !excluded.contains(id) { excluded.append(id) }
        }
        excluded.sort(); save()
    }
    func stop() {
        _ = hotkey.register([:])
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L("login"), isOn: Binding(get: { model.loginOn }, set: { model.changeLogin($0) }))
                    Text(model.loginStatus).font(.caption).foregroundColor(.secondary)
                    Button(L("loginSettings")) { SMAppService.openSystemSettingsLoginItems() }
                    StartupWindowView()
                    Toggle(L("keepRunning"), isOn: Binding(get: { model.keepRunning }, set: { model.keepRunning = $0; model.save() }))
                    Text(L("keepRunningHint")).font(.caption).foregroundColor(.secondary)
                    MenuBarPresenceView()
                }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                SettingsSection(L("frontTitle")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L("frontEnable"), isOn: Binding(get: { model.frontEnabled }, set: { model.frontEnabled = $0; model.save() }))
                    HStack {
                        Text(model.frontShortcut.label).font(.system(.body, design: .monospaced)).frame(width: 120)
                        Button(model.recordingFront ? L("cancelRecording") : L("change")) {
                            model.recordingFront.toggle(); model.recording = model.recordingFront; model.refreshHotkey()
                        }
                        Button(L("frontReset")) { model.resetFrontShortcut() }
                    }.disabled(!model.frontEnabled && !model.recordingFront)
                    Text(model.frontStatus).font(.caption).foregroundColor(model.frontFailed ? .red : .secondary)
                    Text(model.recordingFront ? L("recordHint") : L("frontNote")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                SettingsSection(AccessibilityText.text("title")) {
                    AccessibilityPermissionView(required: true, showsTitle: false)
                }
            })),
            (L("shortcuts"), AnyView(GroupBox(label: Text(L("shortcuts"))) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L("enabled"), isOn: Binding(get: { !model.disabled }, set: { model.disabled = !$0; model.save() }))
                    Toggle(L("pause"), isOn: Binding(get: { model.paused }, set: { model.paused = $0; model.refreshHotkey() }))
                    HStack {
                        Text(L("operation"))
                        OperationPicker(selection: $model.selectedAction) { model.recording = false; model.recordingFront = false; model.refreshHotkey() }
                    }
                    HStack {
                        Text(model.shortcut?.label ?? L("unassigned")).font(.system(.body, design: .monospaced)).frame(width: 120)
                        Button(model.recording && !model.recordingFront ? L("cancelRecording") : L("change")) {
                            model.recording = model.recordingFront || !model.recording; model.recordingFront = false; model.refreshHotkey()
                        }
                        Button(L("resetShortcut")) { model.resetShortcut() }
                        Button(L("disableBinding")) { model.bindings.removeValue(forKey: model.selectedAction); model.recording = false; model.save() }
                    }
                    if let code = model.registrationFailures[model.selectedAction] { Text(L("registrationFailed") + " (\(code))").font(.caption) }
                    Text(model.recording && !model.recordingFront ? L("recordHint") : L("shortcutHint")).font(.caption).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
            })),
            (L("palette"), AnyView(GroupBox(label: Text(L("palette"))) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L("paletteMode"), isOn: Binding(get: { model.paletteMode }, set: { model.paletteMode = $0; model.save(); if $0 { (NSApp.delegate as? AppDelegate)?.showPalette() } }))
                    Text(L("paletteModeHint")).font(.caption).foregroundColor(.secondary)
                    Button(L("palette")) { (NSApp.delegate as? AppDelegate)?.showPalette() }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
            })),
            (L("bracketOptions"), AnyView(GroupBox(label: Text(L("bracketOptions"))) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L("forceWrap"), isOn: Binding(get: { model.forceWrap }, set: { model.forceWrap = $0; model.save() }))
                    Toggle(L("trimSpaces"), isOn: Binding(get: { model.trimSpaces }, set: { model.trimSpaces = $0; model.save() }))
                    Button(L("palette")) { (NSApp.delegate as? AppDelegate)?.showPalette() }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
            })),
            (L("exclusions"), AnyView(GroupBox(label: Text(L("exclusions"))) {
                VStack(alignment: .leading) {
                    List {
                        ForEach(model.excluded, id: \.self) { id in
                            HStack {
                                Text(appName(id)).lineLimit(1).help(id)
                                Spacer()
                                Button(L("remove")) { model.excluded.removeAll { $0 == id }; model.save() }
                            }
                        }
                    }.frame(height: 100)
                    Button(L("addApp")) { model.addApp() }
                }.padding(6)
            })),
            (AboutSection.title, AnyView(AboutView()))
        ])
            Text(model.status).font(.callout).fixedSize(horizontal: false, vertical: true).accessibilityLabel(L("status") + ": " + model.status)
            HStack {
                Button(L("help")) { (NSApp.delegate as? AppDelegate)?.help() }
                Button(L("restore")) { model.restoreLastChange() }
            }
        }.padding(12).frame(minWidth: 740, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
    }
    func appName(_ id: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
        return url.deletingPathExtension().lastPathComponent
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    var model: Model!
    var item: NSStatusItem!
    var preferences: NSWindow?
    var helpWindow: NSWindow?
    var palette: BracketPalette?
    /// Same timing as MightyEdit: the target is fixed when the palette is shown; another app coming
    /// to the front hides it, while KakkoReplace's own settings or menu do not.
    var targetSession = PaletteTargetSession(ownPID: ProcessInfo.processInfo.processIdentifier)
    var paletteTarget: NSRunningApplication? {
        targetSession.targetPID.flatMap { NSRunningApplication(processIdentifier: $0) }.flatMap { $0.isTerminated ? nil : $0 }
    }
    let menu = NSMenu()
    var resultItem: NSMenuItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        model = Model()
        WindowActivationPolicy.install()
        targetSession.bind(frontPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
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
        add(fileMenu, L("openMainWindow"), #selector(openMainWindow), "0"); fileMenu.items.last?.keyEquivalentModifierMask = .command
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
        let helpRoot = NSMenuItem(); let helpMenu = NSMenu(title: L("help")); helpRoot.submenu = helpMenu; main.addItem(helpRoot); add(helpMenu, L("appHelp"), #selector(help), "?"); HelpLinks.addNoteItem(to: helpMenu)
        NSApp.mainMenu = main; NSApp.helpMenu = helpMenu
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "（）"; item.button?.setAccessibilityLabel("KakkoReplace")
        menu.delegate = self
        resultItem = menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        add(menu, L("openMainWindow"), #selector(openMainWindow))
        add(menu, L("palette"), #selector(showPalette))
        add(menu, L("hidePalette"), #selector(hidePalette))
        add(menu, L("settings"), #selector(showPreferences), ",")
        add(menu, L("pause"), #selector(togglePause))
        add(menu, L("restore"), #selector(restore))
        menu.addItem(.separator()); add(menu, L("about"), #selector(about))
        // Help submenu: app help and the note article (BASELINE「メニューの共通構成」).
        let statusHelp = NSMenu(title: L("help")); add(statusHelp, L("appHelp"), #selector(help)); MainActor.assumeIsolated { HelpLinks.addNoteItem(to: statusHelp) }
        menu.setSubmenu(statusHelp, for: menu.addItem(withTitle: L("help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator()); add(menu, L("quit"), #selector(quit), "q")
        item.menu = menu
        // Shared menu-bar component: keeps this item, its menu and the （） title; adds「メニューバー設定…」to the app menu.
        MainActor.assumeIsolated {
            MenuBarPresence.shared.install(name: "KakkoReplace", symbol: "parentheses", existing: item,
                show: { [weak self] in self?.showPrimaryWindow() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in self?.help() })
        }
        item.button?.image = nil
        // Reuse FolderHopper's Apple-event login-launch detection.
        if !LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent) && !StartupWindow.hidden { showPrimaryWindow() }
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "") { let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: key); entry.target = self }
    func menuWillOpen(_ menu: NSMenu) {
        resultItem.title = model.status
        menu.items.first { $0.action == #selector(togglePause) }?.state = model.paused ? .on : .off
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPrimaryWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !model.keepRunning }
    func windowWillClose(_ notification: Notification) {
        // Accessory applications also need an explicit last-window close path.
        guard let closing = notification.object as? NSWindow else { return }
        DispatchQueue.main.async { [weak self, weak closing] in
            guard let self, !self.model.keepRunning else { return }
            let otherWindowIsVisible = NSApp.windows.contains { $0 !== closing && $0.isVisible && ($0.canBecomeMain || $0 === self.palette) }
            if !otherWindowIsVisible { NSApp.terminate(nil) }
        }
    }
    func applicationWillTerminate(_ notification: Notification) { model?.stop() }
    @objc func openMainWindow() { showPrimaryWindow() }
    func showPrimaryWindow() { if model.paletteMode || CommandLine.arguments.contains("--palette") { showPalette() } else { showPreferences() } }
    @objc func hidePalette() { palette?.performClose(nil) }
    @objc func showPreferences() {
        model.refreshLogin()
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle")
            // Resizable from the designed size upward; the hosting view reports only its minimum.
            let hosting = NSHostingView(rootView: Preferences(model: model))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.contentMinSize = NSSize(width: 740, height: 520)
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("Preferences"); preferences = window
        }
        if let window = preferences, !NSScreen.screens.contains(where: { $0.visibleFrame.contains(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
    }
    @objc func help() {
        if helpWindow == nil { helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: "KakkoReplace — " + L("help"), text: L("helpText")) } }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    func applicationActivated(_ app: NSRunningApplication) {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return }
        if targetSession.activated(app.processIdentifier) { palette?.orderOut(nil) }
    }
    func applicationDeactivated(_ app: NSRunningApplication) {
        targetSession.departed(app.processIdentifier, frontPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
    }
    func paletteCanEdit() -> Bool {
        guard let target = paletteTarget, !target.isTerminated,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier,
              model.allowed(target), !model.disabled, !model.paused, !model.recording else { return false }
        return true
    }
    /// Shown without activating KakkoReplace (MightyEdit's presentPalette). From the menu bar or settings,
    /// the editor used last becomes the target and is brought back to the front.
    @objc func showPalette() {
        targetSession.bind(frontPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        guard let target = paletteTarget, model.allowed(target) else {
            palette?.orderOut(nil); model.status = L("chooseTarget"); return
        }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            guard target.activate(options: [.activateIgnoringOtherApps]) else { model.status = L("chooseTarget"); return }
        }
        if palette == nil {
            palette = BracketPalette(model: model)
            palette?.delegate = self
            model.statusChanged = { [weak self] status in self?.palette?.result.stringValue = status }
        }
        guard let palette else { return }
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(palette.frame) }) { palette.center() }
        palette.refresh()
        NSApp.unhideWithoutActivation()
        palette.orderFrontRegardless()
    }
    @objc func togglePause() { model.paused.toggle(); model.refreshHotkey() }
    @objc func restore() { model.restoreLastChange() }
    @objc func about() { NSApp.activate(ignoringOtherApps: true); NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "KakkoReplace", .applicationVersion: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))", .credits: NSAttributedString(string: L("support"))]) }
    @objc func quit() { NSApp.terminate(nil) }
}
let app = NSApplication.shared
SingleInstanceLaunch.enforce()
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()

// Reused from BrowserSwitcher. Oldest process wins on simultaneous launch.
private enum SingleInstanceLaunch {
    static func enforce() {
        let current = NSRunningApplication.current
        guard let identifier = Bundle.main.bundleIdentifier else { return }
        var candidates = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .filter { !$0.isTerminated }
        if !candidates.contains(where: { $0.processIdentifier == current.processIdentifier }) {
            candidates.append(current)
        }
        candidates.sort {
            let left = $0.launchDate ?? .distantPast
            let right = $1.launchDate ?? .distantPast
            return left == right ? $0.processIdentifier < $1.processIdentifier : left < right
        }
        guard let existing = candidates.first,
              existing.processIdentifier != current.processIdentifier else { return }
        existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        if let url = existing.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
                exit(0)
            }
            // Allow the reopen Apple event to reach hidden/menu-bar applications.
            RunLoop.main.run(until: Date().addingTimeInterval(2))
        }
        exit(0)
    }
}
