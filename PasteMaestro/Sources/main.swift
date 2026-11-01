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
    @Published var hotkeyEnabled = UserDefaults.standard.object(forKey: "hotkeyEnabled") as? Bool ?? false
    @Published var paused = false
    @Published var showShortcut = UserDefaults.standard.data(forKey: "showShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
    @Published var showFailed = false
    @Published var shortcut = UserDefaults.standard.data(forKey: "pasteShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .paste
    @Published var addEnabled = UserDefaults.standard.object(forKey: "addEnabled") as? Bool ?? false
    @Published var addShortcut = UserDefaults.standard.data(forKey: "addShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
        ?? .add
    @Published var trimIndent = UserDefaults.standard.object(forKey: "trimIndent") as? Bool ?? true
    @Published var stripMarkers = UserDefaults.standard.object(forKey: "stripMarkers") as? Bool ?? true
    /// Off by default, like the macro's local__notification = 0.
    @Published var notifyEach = UserDefaults.standard.object(forKey: "notifyEach") as? Bool ?? false
    @Published var closeWhenEmpty = UserDefaults.standard.object(forKey: "closeWhenEmpty") as? Bool ?? true
    /// Closes the main window (set by AppDelegate); called when the list runs out.
    var closeMainWindow: (() -> Void)?
    /// Shows the main window without taking focus from the front app (set by AppDelegate); called after ⌃⌥⌘C.
    var revealMainWindow: (() -> Void)?
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    @Published var addStatus = ""
    @Published var addFailed = false
    @Published var status = L("ready")
    @Published var statusIsError = false
    @Published var hotkeyStatus = ""
    @Published var hotkeyFailed = false
    @Published var loginStatus = ""
    @Published var loginOn = false
    @Published var upcoming: [SlotItem] = []
    /// The row the next ⌃⌥V pastes (starred rows stay, so it is not always the first).
    @Published var nextIndex: Int?
    @Published var canRestart = false
    /// The app that was in front before PasteMaestro; clicks in the window paste there.
    @Published var targetName: String?
    @Published var pasting = false
    /// Row chosen in the window; Return pastes it (⌥ keeps it, ⌘ adds a line break).
    @Published var selected: Int?
    weak var mainWindow: NSWindow?
    private var target: NSRunningApplication?
    /// 1 = paste the next line (⌃⌥V), 2 = add the selection (⌃⌥⌘C). Paused by HotkeySet while a key is recorded.
    let hotkeys = HotkeySet(signature: "PSUC")
    let paster = LinePaster()
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var observers: [NSObjectProtocol] = []
    private var workspaceObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    /// What is registered now; app switches re-register only when this changes.
    private var registeredState: String?

    init() {
        hotkeys.action = { [weak self] number in if number == 3 { (NSApp.delegate as? AppDelegate)?.showMainWindow() } else if number == 2 { self?.addSelection() } else { self?.trigger() } }
        // After recording, register again so a conflict with another app is reported.
        HotkeyRecorder.shared.onRecordingChanged.append { [weak self] recording in
            guard let self, !recording else { return }
            self.registeredState = nil; self.refreshHotkey()
        }
        // Event-driven: the hotkey is released while an excluded app (or PasteMaestro itself) is in front (B13, B21).
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self else { return }
                if let app, app.processIdentifier != self.ownPID {
                    self.target = app; self.targetName = app.localizedName
                }
                self.refreshHotkey()
            }
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLogin(); self?.refreshHotkey(); self?.refreshQueue() }
        })
        // Return / ⌥Return / ⌘Return and ↑↓ in the main window (the list rows only select on click).
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let keyCode = event.keyCode, eventWindow = event.window
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let self, let window = self.mainWindow, eventWindow === window, window.attachedSheet == nil else { return false }
                switch keyCode {
                case 36, 76:
                    guard flags.isSubset(of: [.command, .option]) else { return false }
                    self.pasteSelected(flags); return true
                case 125 where flags.isEmpty: self.moveSelection(1); return true
                case 126 where flags.isEmpty: self.moveSelection(-1); return true
                default: return false
                }
            }
            return handled ? nil : event
        }
        refreshLogin(); refreshHotkey(); refreshQueue()
    }

    func save() {
        defaults.set(try? showShortcut.map { try JSONEncoder().encode($0) }, forKey: "showShortcut")
        defaults.set(hotkeyEnabled, forKey: "hotkeyEnabled")
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: "pasteShortcut")
        defaults.set(addEnabled, forKey: "addEnabled")
        defaults.set(try? JSONEncoder().encode(addShortcut), forKey: "addShortcut")
        defaults.set(trimIndent, forKey: "trimIndent")
        defaults.set(stripMarkers, forKey: "stripMarkers")
        defaults.set(notifyEach, forKey: "notifyEach")
        defaults.set(closeWhenEmpty, forKey: "closeWhenEmpty")
        defaults.set(keepRunning, forKey: "keepRunning")
        refreshHotkey(); refreshQueue()
    }

    /// Re-reads the shared settings after SettingsSync applied them; save() would otherwise write the old values back.
    func reload() {
        hotkeyEnabled = defaults.object(forKey: "hotkeyEnabled") as? Bool ?? false
        shortcut = defaults.data(forKey: "pasteShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .paste
        addEnabled = defaults.object(forKey: "addEnabled") as? Bool ?? false
        addShortcut = defaults.data(forKey: "addShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
            ?? .add
        trimIndent = defaults.object(forKey: "trimIndent") as? Bool ?? true
        stripMarkers = defaults.object(forKey: "stripMarkers") as? Bool ?? true
        notifyEach = defaults.object(forKey: "notifyEach") as? Bool ?? false
        closeWhenEmpty = defaults.object(forKey: "closeWhenEmpty") as? Bool ?? true
        refreshHotkey(); refreshQueue()
    }

    /// The hotkey passes through to the front app while it is excluded or PasteMaestro itself.
    func blocked(_ app: NSRunningApplication?) -> Bool {
        MainActor.assumeIsolated { ExcludedApps.shared.blocksHotkeys(bundleID: app?.bundleIdentifier, pid: app?.processIdentifier) }
    }

    func refreshHotkey() {
        publishHotkeys()
        let wanted = hotkeyEnabled && !paused
        let wantedAdd = addEnabled && !paused
        let front = !blocked(NSWorkspace.shared.frontmostApplication) && !LegacyApps.running
        let state = "\(wanted):\(wantedAdd):\(front):\(shortcut.signature):\(addShortcut.signature)"
        if let combo = showShortcut?.combo {
            showFailed = hotkeys.register(3, combo) != noErr
        } else { hotkeys.unregister(3); showFailed = false }
        guard state != registeredState else { return }
        registeredState = state
        // Registered to detect a conflict even while an excluded app is in front; then released at once so the key passes through.
        func apply(_ number: UInt32, _ value: Shortcut, _ on: Bool) -> OSStatus {
            guard on else { hotkeys.unregister(number); return noErr }
            let result = hotkeys.register(number, value.combo)
            if !front { hotkeys.unregister(number) }
            return result
        }
        let result = apply(1, shortcut, wanted)
        let addResult = apply(2, addShortcut, wantedAdd)
        hotkeyFailed = wanted && result != noErr
        addFailed = wantedAdd && addResult != noErr
        hotkeyStatus = describe(enabled: hotkeyEnabled, failed: hotkeyFailed, shortcut: shortcut)
        addStatus = describe(enabled: addEnabled, failed: addFailed, shortcut: addShortcut)
    }
    private func describe(enabled: Bool, failed: Bool, shortcut: Shortcut) -> String {
        if !enabled { return L("hotkeyDisabled") }
        if paused { return L("hotkeyPaused") }
        if failed { return HotkeyText.registerFailed }
        return String(format: L("hotkeyActive"), shortcut.label)
    }

    /// Declares the hotkeys for HotkeyHound (shared registrations cannot be listed from outside).
    func publishHotkeys() { MaestroRegistry.changed?() }

    /// The two 「ホットキー」 fields: the stored Shortcut (JSON with code, modifiers, label) as a KeyCombo.
    var pasteCombo: KeyCombo? {
        get { shortcut.combo }
        set { if let newValue { shortcut = Shortcut(newValue); save() } }
    }
    var addCombo: KeyCombo? {
        get { addShortcut.combo }
        set { if let newValue { addShortcut = Shortcut(newValue); save() } }
    }
    func togglePause() { paused.toggle(); refreshHotkey() }

    func addSelection(fromWindow: Bool = false) {
        guard (fromWindow || addEnabled), !paused, !LegacyApps.running else {
            if fromWindow { report(.failed(M("disabled"))) }; return
        }
        guard let front = NSWorkspace.shared.frontmostApplication, !blocked(front) else {
            if fromWindow { report(.failed(L("fail.noTarget"))) }; return
        }
        let pid = front.processIdentifier
        paster.addSelection(appName: front.localizedName ?? "", pid: pid, trimIndent: trimIndent, stripMarkers: stripMarkers, stillTarget: { [weak self] in
            guard let self, let now = NSWorkspace.shared.frontmostApplication, now.processIdentifier == pid else { return false }
            return (fromWindow || self.addEnabled) && !self.paused && !LegacyApps.running && !self.blocked(now)
        }) { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .added(_, let count, let total):
                self.revealMainWindow?()
                self.status = String(format: L("added"), String(count), String(total)); self.statusIsError = false
                let message = self.status
                MainActor.assumeIsolated { TransientMessage.show(message) }
            case .failed(let reason):
                self.status = reason; self.statusIsError = true
                NSSound.beep()
                MainActor.assumeIsolated { TransientMessage.show(reason) }
            }
            self.refreshQueue()
        }
    }

    func trigger() {
        guard hotkeyEnabled, !paused, let front = NSWorkspace.shared.frontmostApplication, !blocked(front), !LegacyApps.running else { return }
        let pid = front.processIdentifier
        let outcome = paster.paste(.next, appName: front.localizedName ?? "", pid: pid, stillTarget: { [weak self] in
            guard let self, let now = NSWorkspace.shared.frontmostApplication, now.processIdentifier == pid else { return false }
            return self.hotkeyEnabled && !self.paused && !LegacyApps.running && !self.blocked(now)
        })
        report(outcome)
    }

    func report(_ outcome: PasteOutcome) {
        switch outcome {
        case .pasted(let appName, let remaining, let next):
            if remaining == 0 && closeWhenEmpty { closeMainWindow?() }
            status = remaining == 0 ? String(format: L("success.last"), appName) : String(format: L("success.pasted"), appName, String(remaining))
            statusIsError = false
            if notifyEach {
                let message = next.map { String(format: L("notify.next"), String(remaining), Self.preview($0)) } ?? L("notify.last")
                MainActor.assumeIsolated { TransientMessage.show(message) }
            }
        case .failed(let reason):
            status = reason
            statusIsError = true
            NSSound.beep()
            // Never just a beep (B27): the reason is shown near the top of the screen.
            let message = reason
            MainActor.assumeIsolated { TransientMessage.show(message) }
        }
        refreshQueue()
    }
    /// Click in the window (the KM macro 「02)非連続ペースト」): bring back the previous app, wait until it is in front,
    /// then paste there. The window is ordered front again without activating PasteMaestro, so the next click is easy.
    func pasteFromWindow(_ pick: LinePaster.Pick, window: NSWindow?) {
        guard !pasting, !paused, !LegacyApps.running else { report(.failed(M("disabled"))); return }
        guard let target, !target.isTerminated else { report(.failed(L("fail.noTarget"))); return }
        guard !blocked(target) else { report(.failed(String(format: L("fail.excludedTarget"), target.localizedName ?? ""))); return }
        guard AXIsProcessTrusted() else { report(.failed(AccessibilityText.text("blocked"))); return }
        pasting = true
        target.activate()
        let pid = target.processIdentifier
        let deadline = Date().addingTimeInterval(1.5)
        func wait() {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid {
                // A short pause lets the app restore its key window and text focus before ⌘V arrives.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                    guard let self else { return }
                    self.pasting = false
                    let outcome = self.paster.paste(pick, appName: target.localizedName ?? "", pid: pid, stillTarget: { [weak self] in
                        guard let self, let now = NSWorkspace.shared.frontmostApplication, now.processIdentifier == pid else { return false }
                        return !self.paused && !LegacyApps.running && !self.blocked(now)
                    })
                    self.report(outcome)
                    // Kept in front for the next click, unless the last line has just closed it.
                    if window?.isVisible == true { window?.orderFrontRegardless() }
                }
            } else if Date() >= deadline {
                pasting = false
                report(.failed(L("fail.target")))
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { wait() }
            }
        }
        wait()
    }
    func moveSelection(_ step: Int) {
        guard !upcoming.isEmpty else { return }
        selected = max(0, min(upcoming.count - 1, (selected ?? -step.signum()) + step))
    }
    /// Return: paste the chosen row. ⌥ keeps it in the list, ⌘ adds a line break.
    func pasteSelected(_ flags: NSEvent.ModifierFlags) {
        guard let index = selected, upcoming.indices.contains(index) else { NSSound.beep(); return }
        pasteFromWindow(.line(id: upcoming[index].id, newline: flags.contains(.command), keep: flags.contains(.option)), window: mainWindow)
    }
    func clearQueue() {
        paster.clear(); status = L("cleared"); statusIsError = false
        refreshQueue()
        if closeWhenEmpty && upcoming.isEmpty { closeMainWindow?() }
    }
    func toggleStar(_ index: Int) {
        paster.toggleStar(index); refreshQueue()
    }

    func moveSlot(id: UUID, before anchor: UUID?) {
        guard !pasting, !paster.adding, !ClipboardGate.busy else {
            status = M("busy"); statusIsError = true; return
        }
        let selectedID = selected.flatMap { upcoming.indices.contains($0) ? upcoming[$0].id : nil }
        if paster.move(id: id, before: anchor) {
            refreshQueue()
            selected = selectedID.flatMap { id in upcoming.firstIndex { $0.id == id } }
        }
    }
    func moveSelected(_ delta: Int) {
        guard let index = selected, upcoming.indices.contains(index), upcoming.indices.contains(index + delta) else { return }
        let anchor = delta < 0 ? upcoming[index - 1].id : (index + 2 < upcoming.count ? upcoming[index + 2].id : nil)
        moveSlot(id: upcoming[index].id, before: anchor)
    }
    static func preview(_ line: String) -> String { line.count > 40 ? String(line.prefix(40)) + "…" : line }

    func restart() {
        if paster.restart() { status = L("restarted"); statusIsError = false }
        else { status = L("restartUnavailable"); statusIsError = true }
        refreshQueue()
    }
    func refreshQueue() {
        let selectedID = selected.flatMap { upcoming.indices.contains($0) ? upcoming[$0].id : nil }
        upcoming = paster.queue
        nextIndex = paster.nextIndex
        // Follow identity across insertion/reorder; if consumed, select the following row.
        selected = selectedID.flatMap { id in upcoming.firstIndex { $0.id == id } }
            ?? (upcoming.isEmpty ? nil : min(selected ?? 0, upcoming.count - 1))
        canRestart = paster.canRestart
    }

    /// The 「対象外アプリ」 list changed: register the hotkeys again for the front app.
    func excludedAppsChanged() { registeredState = nil; refreshHotkey() }

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
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
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

/// The lines the next presses paste, in BrowserSwitcher's list style: tall rows on the alternating
/// content backgrounds, a line border and large semibold text. The first row is the next paste.
struct Preferences: View {
    @ObservedObject var model: Model
    @ObservedObject var increment: IncrementModel
    @ObservedObject var style: StyleModel
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) {
                    Toggle(L("login"), isOn: Binding(get: { model.loginOn }, set: { model.changeLogin($0) }))
                    Text(model.loginStatus).font(.caption).foregroundColor(.secondary)
                    Button(L("loginSettings")) { SMAppService.openSystemSettingsLoginItems() }
                    StartupWindowView()
                    Toggle(L("keepRunning"), isOn: Binding(get: { model.keepRunning }, set: { model.keepRunning = $0; model.save() }))
                    DisclosureGroup(M("explanation")) { Text(L("keepRunningHint")).font(.caption).foregroundColor(.secondary) }
                    Text(M("showHotkey")).font(.headline)
                    HotkeyField(id: "show", combo: Binding(get: { model.showShortcut?.combo }, set: { model.showShortcut = $0.map(Shortcut.init); model.save() }), allowsClear: true, others: MaestroRegistry.others(except: "show"), registered: !model.showFailed)
                    Text(M("showHint")).font(.caption).foregroundColor(.secondary)
                    MenuBarPresenceView()
                }
                AccessibilitySection()
            })),
            (M("behavior"), AnyView(VStack(alignment: .leading, spacing: 16) {
                DisclosureGroup(M("row")) { VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("cleanupTitle")) {
                    Toggle(L("trimIndent"), isOn: Binding(get: { model.trimIndent }, set: { model.trimIndent = $0; model.save() }))
                    Toggle(L("stripMarkers"), isOn: Binding(get: { model.stripMarkers }, set: { model.stripMarkers = $0; model.save() }))
                    DisclosureGroup(M("explanation")) { Text(L("cleanupHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
                SettingsSection(L("windowTitle")) {
                    Toggle(L("closeWhenEmpty"), isOn: Binding(get: { model.closeWhenEmpty }, set: { model.closeWhenEmpty = $0; model.save() }))
                    DisclosureGroup(M("explanation")) { Text(L("closeWhenEmptyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
                SettingsSection(L("notifyTitle")) {
                    Toggle(L("notifyEach"), isOn: Binding(get: { model.notifyEach }, set: { model.notifyEach = $0; model.save() }))
                    DisclosureGroup(M("explanation")) { Text(L("notifyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
                } }
                DisclosureGroup(M("increment")) { IncrementPreferences(model: increment) }
                DisclosureGroup(M("style")) { StylePreferences(model: style) }
            })),
            (ExcludedApps.title, AnyView(SettingsSection(ExcludedApps.title) { ExcludedAppsView() })),
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
    var increment: IncrementModel!
    var style: StyleModel!
    var selectedFeature = "row"
    private var compatibilityObservers: [NSObjectProtocol] = []
    var item: NSStatusItem!
    var mainWindow: NSWindow?
    var rowPalette: NSPanel?
    var preferences: NSWindow?
    var helpWindow: NSWindow?
    let menu = NSMenu()
    var resultItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        ExcludedApps.shared.configure(explanation: L("excluded.explanation"), initial: ExcludedDefaults.initial)
        model = Model()
        increment = IncrementModel(); style = StyleModel()
        MaestroRegistry.changed = { [weak self] in self?.publishAllHotkeys() }
        MaestroRegistry.combos = { [weak self] in guard let self else { return [] }; return [("row", self.model.shortcut.combo), ("add", self.model.addShortcut.combo), ("increment", self.increment.shortcut.combo), ("style", self.style.shortcut.combo)] + (self.model.showShortcut.map { [("show", $0.combo)] } ?? []) }
        publishAllHotkeys()
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            compatibilityObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.model.excludedAppsChanged(); self?.increment.excludedAppsChanged(); self?.style.excludedAppsChanged() }
            })
        }
        ExcludedApps.shared.onChange = { [weak self] in self?.model.excludedAppsChanged(); self?.increment.excludedAppsChanged(); self?.style.excludedAppsChanged() }
        model.closeMainWindow = { [weak self] in self?.rowPalette?.close() }
        model.revealMainWindow = { [weak self] in self?.showRowPalette() }
        SettingsSync.shared.onImport = { [weak self] in self?.model.reload(); self?.increment.reload(); self?.style.reload() }
        SettingsSync.shared.start(.init(
            keys: ["hotkeyEnabled", "pasteShortcut", "addEnabled", "addShortcut", "trimIndent", "stripMarkers", "notifyEach", "closeWhenEmpty", "increment.hotkeyEnabled", "increment.incrementShortcut", "increment.step", "increment.dates", "increment.letters", "increment.firstAsIs", "increment.notifyEach", "style.hotkeyEnabled", "style.pasteShortcut", "style.useMenu", "style.menuTitles", "style.restoreClipboard"],
            note: StartupWindow.text("ホットキーと貼り付け方を書き出し・同期します。", "Exports and syncs the hotkeys and the paste options.",
                                     "导出并同步快捷键和粘贴方式。", "단축키와 붙여넣기 방식을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・常駐・メニューバー・対象外アプリはMacごとに設定します。",
                                       "Launch at login, staying open, the menu bar icon and excluded apps are set on each Mac.",
                                       "登录时启动、常驻、菜单栏图标和排除的应用需在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 상주, 메뉴 막대 아이콘, 제외할 앱은 Mac마다 설정합니다.")))
        AccessibilityText.neededOverride = [
            "他のアプリへコピー・貼り付けを送信し、書式を合わせるメニューを実行するために使用します。",
            "Used to send Copy and Paste to other apps and run their matching-style menu commands.",
            "用于向其他应用发送复制和粘贴，以及执行匹配样式菜单。",
            "다른 앱에 복사와 붙여넣기를 보내고 스타일 맞추기 메뉴를 실행하는 데 사용합니다."
        ]
        WindowActivationPolicy.install()
        buildMainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.setAccessibilityLabel("PasteMaestro")
        menu.delegate = self
        resultItem = menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, L("openMainWindow"), #selector(openMainWindow))
        add(menu, M("openPalette"), #selector(openRowPalette))
        add(menu, L("settings"), #selector(showPreferences))
        add(menu, L("pause"), #selector(togglePause))
        add(menu, L("restart"), #selector(restart))
        menu.addItem(.separator())
        // Help submenu: app help and the note article (BASELINE「メニューの共通構成」).
        let statusHelp = NSMenu(title: L("help")); add(statusHelp, L("appHelp"), #selector(help)); MainActor.assumeIsolated { HelpLinks.addNoteItem(to: statusHelp) }
        menu.setSubmenu(statusHelp, for: menu.addItem(withTitle: L("help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator()); add(menu, L("quit"), #selector(quit))
        item.menu = menu
        MainActor.assumeIsolated {
            MenuBarPresence.shared.install(name: "PasteMaestro", symbol: "doc.on.clipboard", existing: item,
                show: { [weak self] in self?.showMainWindow() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in self?.help() })
        }
        if !LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent) && !StartupWindow.suppressInitialWindow { showMainWindow() }
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
        add(fileMenu, M("openPalette"), #selector(openRowPalette))
        fileMenu.addItem(.separator())
        add(fileMenu, L("restart"), #selector(restart))
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

    func publishAllHotkeys() {
        let ids = ExcludedApps.shared.ids
        var entries: [(String, KeyCombo, Bool)] = [("row", model.shortcut.combo, model.hotkeyEnabled), ("add", model.addShortcut.combo, model.addEnabled), ("increment", increment.shortcut.combo, increment.hotkeyEnabled), ("style", style.shortcut.combo, style.hotkeyEnabled)]
        if let combo = model.showShortcut?.combo { entries.append(("show", combo, true)) }
        HotkeyManifest.publish(entries.map { HotkeyManifest.Item(id: $0.0, title: M($0.0), keyCode: Int($0.1.code), modifiers: Int($0.1.modifiers), enabled: $0.2 && !model.paused && !LegacyApps.running, scope: ids.isEmpty ? "all" : "except", apps: ids) })
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "") {
        let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: key); entry.target = self
    }
    func menuWillOpen(_ menu: NSMenu) {
        model.refreshQueue()
        resultItem.title = model.status
        menu.items.first { $0.action == #selector(togglePause) }?.state = model.paused ? .on : .off
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Not available → disabled instead of a silent no-op (B27).
        if menuItem.action == #selector(restart) { return model.paster.canRestart }
        if menuItem.action == #selector(togglePause) { menuItem.state = model.paused ? .on : .off; return true }
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
        guard ClipboardGate.busy else { return .terminateNow }
        model.status = M("busy"); model.statusIsError = true
        TransientMessage.show(M("busy"))
        return .terminateCancel
    }
    func applicationWillTerminate(_ notification: Notification) { model?.stop(); increment?.stop(); style?.stop() }

    @objc func openMainWindow() { showMainWindow() }
    /// `activate: false` (after ⌃⌥⌘C) puts the window in front without activating PasteMaestro,
    /// so the user can keep selecting and copying in the other app.
    func showMainWindow(activate: Bool = true) {
        model.refreshQueue()
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 560), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            // Native title bar unchanged; no app name in it (BASELINE「主画面の背景とタイトルバー」).
            window.title = ""
            window.titleVisibility = .hidden
            let content = NSView(frame: window.contentLayoutRect)
            AppSurface.install(in: content)
            let hosting = NSHostingView(rootView: MaestroView(delegate: self, row: model, increment: increment, style: style))
            hosting.sizingOptions = [.minSize]
            // The hosting view sits on the shared surface view, so size the window from the SwiftUI content.
            let size = NSSize(width: 440, height: 560)
            window.setContentSize(size)
            content.frame = NSRect(origin: .zero, size: size)
            hosting.frame = content.bounds
            hosting.autoresizingMask = [.width, .height]
            content.addSubview(hosting)
            window.contentView = content
            window.contentMinSize = NSSize(width: 420, height: 500)
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("MainWindow")
            if !UserDefaults.standard.bool(forKey: "compactMainWindowV1") {
                window.setContentSize(size)
                UserDefaults.standard.set(true, forKey: "compactMainWindowV1")
            }
            mainWindow = window

        }
        if let window = mainWindow, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        if activate { NSApp.activate(ignoringOtherApps: true); mainWindow?.makeKeyAndOrderFront(nil) }
        else { mainWindow?.orderFrontRegardless() }
    }
    @objc func openRowPalette() { showRowPalette() }
    func showRowPalette() {
        model.refreshQueue()
        if rowPalette == nil {
            let panel = PastePalette(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420), styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = M("row")
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.isFloatingPanel = true
            panel.contentView = NSHostingView(rootView: RowPaletteView(model: model))
            panel.contentMinSize = NSSize(width: 380, height: 300)
            panel.center(); panel.setFrameAutosaveName("RowPalette")
            rowPalette = panel; model.mainWindow = panel
        }
        if let panel = rowPalette, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) { panel.center() }
        rowPalette?.makeKeyAndOrderFront(nil)
    }
    @objc func showPreferences() { AppSwitcherWindowReveal.preserveAuxiliaryWindowOnActivation();
        model.refreshLogin()
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle")
            let hosting = NSHostingView(rootView: Preferences(model: model, increment: increment, style: style))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.contentMinSize = NSSize(width: 640, height: 520)
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("Preferences"); preferences = window
        }
        if let window = preferences, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
    }
    @objc func help() { AppSwitcherWindowReveal.preserveAuxiliaryWindowOnActivation();
        if helpWindow == nil { helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: "PasteMaestro — " + L("help"), text: L("helpText"), heading: L("helpHeading")) } }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func togglePause() { let value = !model.paused; model.paused = value; increment.paused = value; style.paused = value; model.refreshHotkey(); increment.refreshHotkey(); style.refreshHotkey() }
    @objc func restart() { model.restart() }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary ?? [:]
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "PasteMaestro",
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

/// First launch list of 「対象外アプリ」 (Tests/check_km_macro.py compares it with the macro).
enum ExcludedDefaults {
    /// First launch: the apps the KM macro group excluded (Illustrator, Path Finder, Keynote).
    static let initial = ["com.adobe.illustrator", "com.cocoatech.PathFinder-setapp", "com.apple.iWork.Keynote", "com.apple.Keynote", "com.microsoft.Excel", "com.adobe.InDesign", "net.telestream.screenflow10"]
}
