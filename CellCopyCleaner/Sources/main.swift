import AppKit
import SwiftUI
import ServiceManagement
import Carbon
import ApplicationServices

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

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
    @Published var recording = false
    @Published var status = L("ready")
    @Published var statusIsError = false
    @Published var hotkeyStatus = ""
    @Published var hotkeyFailed = false
    @Published var recordMessage = ""
    @Published var loginStatus = ""
    @Published var loginOn = false
    @Published var accessibilityAllowed = AXIsProcessTrusted()
    @Published var canRestore = false
    let hotkey = SingleHotKey(signature: 0x4343_434C)       // 'CCCL'
    let cleaner = ClipboardCleaner()
    private var observers: [NSObjectProtocol] = []
    private var workspaceObserver: NSObjectProtocol?
    private var monitor: Any?
    /// What is registered now; app switches re-register only when this changes.
    private var registeredState: String?

    init() {
        hotkey.action = { [weak self] in self?.trigger() }
        // Event-driven: the clean hotkey exists only while an enabled target app is in front (B13, B21).
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshHotkey()
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshLogin(); self?.refreshAccessibility(); self?.refreshHotkey(); self?.refreshRestore()
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
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: "cleanShortcut")
        defaults.set(targetEnabled, forKey: "targetEnabled")
        defaults.set(replaceApostrophe, forKey: "replaceApostrophe")
        defaults.set(notifySuccess, forKey: "notifySuccess")
        defaults.set(keepRunning, forKey: "keepRunning")
        refreshHotkey()
    }

    func isEnabled(_ target: TargetApp) -> Bool { targetEnabled[target.bundleID] ?? true }
    func setEnabled(_ target: TargetApp, _ value: Bool) { targetEnabled[target.bundleID] = value; save() }
    /// The enabled target for this app, or nil (other apps keep ⌥⌘C).
    func activeTarget(_ app: NSRunningApplication?) -> TargetApp? {
        guard let target = CleanRules.target(for: app?.bundleIdentifier), isEnabled(target) else { return nil }
        return target
    }

    func refreshHotkey() {
        publishHotkeys()
        let wanted = hotkeyEnabled && !paused && !recording
        let front = activeTarget(NSWorkspace.shared.frontmostApplication) != nil
        let state = "\(wanted):\(front):\(shortcut.signature)"
        guard state != registeredState else { return }
        registeredState = state
        var result: OSStatus = noErr
        if wanted {
            // Registered to detect a conflict even when no target is in front; then released at once so the key passes through.
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

    /// Declares the hotkeys for HotkeyHound (shared registrations cannot be listed from outside).
    func publishHotkeys() {
        let apps = CleanRules.targets.filter(isEnabled).map(\.bundleID)
        HotkeyManifest.publish([
            HotkeyManifest.Item(id: "clean", title: L("cleanHotkey"), keyCode: Int(shortcut.code), modifiers: Int(shortcut.modifiers),
                                enabled: hotkeyEnabled, scope: "only", apps: apps)
        ])
    }

    func startRecording() {
        recording.toggle()
        recordMessage = recording ? L("recordHint") : ""
        refreshHotkey()
    }
    func resetShortcut() {
        shortcut = .clean; hotkeyEnabled = true; recording = false; recordMessage = ""; save()
    }
    func togglePause() { paused.toggle(); refreshHotkey() }

    func trigger() {
        guard hotkeyEnabled, !paused, !recording, !cleaner.busy,
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
        refreshAccessibility(); refreshRestore()
    }

    func restoreOriginal() {
        if cleaner.restore() { status = L("restored"); statusIsError = false }
        else { status = L("restoreUnavailable"); statusIsError = true }
        refreshRestore()
    }
    func refreshRestore() { canRestore = cleaner.canRestore }
    func refreshAccessibility() { accessibilityAllowed = AXIsProcessTrusted() }

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
                              tint: model.hotkeyFailed ? .orange : .secondary, title: L("hotkeyRow"), value: model.hotkeyStatus)
                    StatusRow(symbol: model.accessibilityAllowed ? "checkmark.circle.fill" : "minus.circle",
                              tint: model.accessibilityAllowed ? .green : .secondary, title: AccessibilityText.text("title"),
                              value: AccessibilityText.text(model.accessibilityAllowed ? "allowed" : "denied"))
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
                Button(L("help")) { (NSApp.delegate as? AppDelegate)?.help() }
                Spacer()
                Button(L("restore")) { model.restoreOriginal() }.disabled(!model.canRestore).help(L("restoreHint"))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 440, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
    }
}

struct ShortcutRow: View {
    @ObservedObject var model: Model
    let shortcut: Shortcut
    let enabled: Bool
    let reset: () -> Void
    var body: some View {
        HStack {
            Text(shortcut.label).font(.system(.body, design: .monospaced)).frame(width: 110).accessibilityLabel(L("currentKey") + " " + shortcut.label)
            Button(model.recording ? L("cancelRecording") : L("change")) { model.startRecording() }
            Button(L("resetShortcut"), action: reset)
        }.disabled(!enabled && !model.recording)
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
                SettingsSection(L("cleanHotkey")) {
                    Toggle(L("enabled"), isOn: Binding(get: { model.hotkeyEnabled }, set: { model.hotkeyEnabled = $0; model.save() }))
                    Toggle(L("pause"), isOn: Binding(get: { model.paused }, set: { _ in model.togglePause() }))
                    ShortcutRow(model: model, shortcut: model.shortcut, enabled: model.hotkeyEnabled) { model.resetShortcut() }
                    Text(model.hotkeyStatus).font(.caption).foregroundColor(model.hotkeyFailed ? .red : .secondary).fixedSize(horizontal: false, vertical: true)
                    if model.recording, !model.recordMessage.isEmpty { Text(model.recordMessage).font(.caption) }
                    Text(L("shortcutHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
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
                            HStack(spacing: 8) {
                                if let icon = appIcon(for: target.bundleID) { Image(nsImage: icon).resizable().frame(width: 20, height: 20).accessibilityHidden(true) }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(target.name)
                                    Text(target.bundleID + " — " + profileDescription(target.profile)).font(.caption).foregroundColor(.secondary)
                                }
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
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
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
            "対象アプリへ「コピー」（⌘C）を送るために使用します。未許可の場合、⌥⌘C を押してもコピーと整形はできません。",
            "Used to send Copy (⌘C) to the target app. Without permission, ⌥⌘C cannot copy and clean.",
            "用于向目标应用发送“拷贝”（⌘C）。未获授权时，按 ⌥⌘C 无法拷贝和整理。",
            "대상 앱에 복사하기(⌘C)를 보내는 데 사용합니다. 권한이 없으면 ⌥⌘C를 눌러도 복사 및 정리를 할 수 없습니다."
        ]
        WindowActivationPolicy.install()
        buildMainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.setAccessibilityLabel("CellCopyCleaner")
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
            MenuBarPresence.shared.install(name: "CellCopyCleaner", symbol: "tablecells", existing: item,
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
        model.refreshAccessibility(); model.refreshRestore()
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
        if helpWindow == nil { helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: "CellCopyCleaner — " + L("help"), text: L("helpText"), heading: L("helpHeading")) } }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func togglePause() { model.togglePause() }
    @objc func restore() { model.restoreOriginal() }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary ?? [:]
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "CellCopyCleaner",
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
