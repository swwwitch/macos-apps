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
    @Published var hotkeyEnabled = UserDefaults.standard.object(forKey: "hotkeyEnabled") as? Bool ?? true
    @Published var paused = false
    @Published var shortcut = UserDefaults.standard.data(forKey: "pasteShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .paste
    @Published var addEnabled = UserDefaults.standard.object(forKey: "addEnabled") as? Bool ?? true
    @Published var addShortcut = UserDefaults.standard.data(forKey: "addShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
        .flatMap { $0 == .oldAdd ? nil : $0 } ?? .add
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
    /// The app that was in front before PasteInARow; clicks in the window paste there.
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
        hotkeys.action = { [weak self] number in if number == 2 { self?.addSelection() } else { self?.trigger() } }
        // After recording, register again so a conflict with another app is reported.
        HotkeyRecorder.shared.onRecordingChanged.append { [weak self] recording in
            guard let self, !recording else { return }
            self.registeredState = nil; self.refreshHotkey()
        }
        // Event-driven: the hotkey is released while an excluded app (or PasteInARow itself) is in front (B13, B21).
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
        hotkeyEnabled = defaults.object(forKey: "hotkeyEnabled") as? Bool ?? true
        shortcut = defaults.data(forKey: "pasteShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .paste
        addEnabled = defaults.object(forKey: "addEnabled") as? Bool ?? true
        addShortcut = defaults.data(forKey: "addShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
            .flatMap { $0 == .oldAdd ? nil : $0 } ?? .add
        trimIndent = defaults.object(forKey: "trimIndent") as? Bool ?? true
        stripMarkers = defaults.object(forKey: "stripMarkers") as? Bool ?? true
        notifyEach = defaults.object(forKey: "notifyEach") as? Bool ?? false
        closeWhenEmpty = defaults.object(forKey: "closeWhenEmpty") as? Bool ?? true
        refreshHotkey(); refreshQueue()
    }

    /// The hotkey passes through to the front app while it is excluded or PasteInARow itself.
    func blocked(_ app: NSRunningApplication?) -> Bool {
        MainActor.assumeIsolated { ExcludedApps.shared.blocksHotkeys(bundleID: app?.bundleIdentifier, pid: app?.processIdentifier) }
    }

    func refreshHotkey() {
        publishHotkeys()
        let wanted = hotkeyEnabled && !paused
        let wantedAdd = addEnabled && !paused
        let front = !blocked(NSWorkspace.shared.frontmostApplication)
        let state = "\(wanted):\(wantedAdd):\(front):\(shortcut.signature):\(addShortcut.signature)"
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
    func publishHotkeys() {
        let excludedIDs = MainActor.assumeIsolated { ExcludedApps.shared.ids }
        let scope = excludedIDs.isEmpty ? "all" : "except"
        HotkeyManifest.publish([
            HotkeyManifest.Item(id: "paste", title: L("pasteHotkey"), keyCode: Int(shortcut.code), modifiers: Int(shortcut.modifiers),
                                enabled: hotkeyEnabled, scope: scope, apps: excludedIDs),
            HotkeyManifest.Item(id: "add", title: L("addHotkey"), keyCode: Int(addShortcut.code), modifiers: Int(addShortcut.modifiers),
                                enabled: addEnabled, scope: scope, apps: excludedIDs)
        ])
    }

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

    func addSelection() {
        guard addEnabled, !paused, let front = NSWorkspace.shared.frontmostApplication, !blocked(front) else { return }
        let pid = front.processIdentifier
        paster.addSelection(appName: front.localizedName ?? "", pid: pid, trimIndent: trimIndent, stripMarkers: stripMarkers, stillTarget: { [weak self] in
            guard let self, let now = NSWorkspace.shared.frontmostApplication, now.processIdentifier == pid else { return false }
            return self.addEnabled && !self.paused && !self.blocked(now)
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
        guard hotkeyEnabled, !paused, let front = NSWorkspace.shared.frontmostApplication, !blocked(front) else { return }
        let pid = front.processIdentifier
        let outcome = paster.paste(.next, appName: front.localizedName ?? "", pid: pid, stillTarget: { [weak self] in
            guard let self, let now = NSWorkspace.shared.frontmostApplication, now.processIdentifier == pid else { return false }
            return self.hotkeyEnabled && !self.paused && !self.blocked(now)
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
    /// then paste there. The window is ordered front again without activating PasteInARow, so the next click is easy.
    func pasteFromWindow(_ pick: LinePaster.Pick, window: NSWindow?) {
        guard !pasting else { return }
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
                        return !self.blocked(now)
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
        pasteFromWindow(.line(index: index, text: upcoming[index].text, newline: flags.contains(.command), keep: flags.contains(.option)), window: mainWindow)
    }
    func clearQueue() {
        paster.clear(); status = L("cleared"); statusIsError = false
        refreshQueue()
        if closeWhenEmpty && upcoming.isEmpty { closeMainWindow?() }
    }
    func toggleStar(_ index: Int) {
        paster.toggleStar(index); refreshQueue()
    }

    static func preview(_ line: String) -> String { line.count > 40 ? String(line.prefix(40)) + "…" : line }

    func restart() {
        if paster.restart() { status = L("restarted"); statusIsError = false }
        else { status = L("restartUnavailable"); statusIsError = true }
        refreshQueue()
    }
    func refreshQueue() {
        upcoming = paster.queue
        nextIndex = paster.nextIndex
        // Keep the chosen row where it is (it now holds the next line); start on the first row.
        selected = upcoming.isEmpty ? nil : min(selected ?? 0, upcoming.count - 1)
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
struct QueueList: View {
    static let rowHeight: CGFloat = 56
    let lines: [SlotItem]
    /// The row ⌃⌥V pastes next (filled number badge).
    let nextIndex: Int?
    /// Clicking a row only selects it; Return in the window pastes (see Model.pasteSelected).
    @Binding var selected: Int?
    /// ☆ → ★: a starred line stays in the slot after it is pasted.
    let toggleStar: (Int) -> Void
    var body: some View {
        let colors = NSColor.alternatingContentBackgroundColors
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.prefix(500).enumerated()), id: \.offset) { index, item in
                        let chosen = selected == index
                        let next = nextIndex == index
                        HStack(spacing: 16) {
                            Text("\(index + 1)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
                                .foregroundColor(next || chosen ? .white : .secondary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(chosen ? Color.white.opacity(0.25) : next ? Color.accentColor : Color.primary.opacity(0.08)))
                            Text(item.text)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(chosen ? .white : next ? .primary : .secondary)
                                .lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: 0)
                            Button { toggleStar(index) } label: {
                                Image(systemName: item.starred ? "star.fill" : "star")
                                    .font(.system(size: 18))
                                    .foregroundColor(item.starred ? Color(nsColor: .systemYellow) : chosen ? .white.opacity(0.8) : .secondary)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(L(item.starred ? "unstar" : "star"))
                            .accessibilityLabel(L(item.starred ? "unstar" : "star"))
                        }
                        .padding(.leading, 16).padding(.trailing, 10)
                        .frame(height: Self.rowHeight)
                        .background(chosen ? Color(nsColor: .selectedContentBackgroundColor)
                                    : Color(nsColor: index.isMultiple(of: 2) && colors.count > 1 ? colors[1] : colors[0]))
                        .contentShape(Rectangle())
                        .onTapGesture { selected = index }
                        .id(index)
                        .help(L("rowHint"))
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(String(format: L("ax.line"), String(index + 1), item.text) + (item.starred ? " ★" : ""))
                        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction { selected = index }
                        .accessibilityHint(L("rowHint"))
                    }
                }
            }
            .onChange(of: selected) { value in if let value { proxy.scrollTo(value) } }
        }
        .background(Color(nsColor: colors[0]))
        .border(Color(nsColor: .separatorColor), width: 1)
        .frame(maxWidth: .infinity, minHeight: Self.rowHeight * 3 + 2, idealHeight: Self.rowHeight * 6 + 2, maxHeight: .infinity)
        .accessibilityLabel(L("queueTitle"))
    }
}

struct MainView: View {
    @ObservedObject var model: Model
    private var mainWindow: NSWindow? { (NSApp.delegate as? AppDelegate)?.mainWindow }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderView().fixedSize(horizontal: false, vertical: true)
            // The status block is hidden; only a problem that stops ⌃⌥V is shown here (B09, B27).
            if !AccessibilitySection.isTrusted {
                StatusRow(symbol: "exclamationmark.triangle.fill", tint: .orange, title: AccessibilityText.text("title"),
                          value: AccessibilityText.text("denied"))
            } else if model.hotkeyFailed || model.addFailed {
                StatusRow(symbol: "exclamationmark.triangle.fill", tint: .orange, title: L("hotkeyRow"),
                          value: model.hotkeyFailed ? model.hotkeyStatus : model.addStatus)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(format: L("queueCount"), String(model.upcoming.count))).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button(L("pasteAll")) { model.pasteFromWindow(.all, window: mainWindow) }
                        .disabled(model.upcoming.isEmpty || model.pasting).help(L("pasteAllHint"))
                    Button(L("clear")) { model.clearQueue() }.disabled(model.upcoming.isEmpty).help(L("clearHint"))
                }
                if model.upcoming.isEmpty {
                    Text(L("queueEmpty")).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: QueueList.rowHeight * 3 + 2, maxHeight: .infinity)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .border(Color(nsColor: .separatorColor), width: 1)
                } else {
                    QueueList(lines: model.upcoming, nextIndex: model.nextIndex, selected: $model.selected) { model.toggleStar($0) }
                }
                Text(L("queueHint") + "\n" + (model.targetName.map { String(format: L("clickTarget"), $0) } ?? L("clickNoTarget"))).font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button(L("settingsButton")) { (NSApp.delegate as? AppDelegate)?.showPreferences() }
                Spacer()
                Button(L("restart")) { model.restart() }.disabled(!model.canRestart).help(L("restartHint"))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity, alignment: .topLeading)
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
                SettingsSection(L("pasteHotkey")) {
                    Toggle(HotkeyText.enable, isOn: Binding(get: { model.hotkeyEnabled }, set: { model.hotkeyEnabled = $0; model.save() }))
                    HotkeyField(id: "paste", combo: Binding(get: { model.pasteCombo }, set: { model.pasteCombo = $0 }),
                                defaultCombo: Shortcut.paste.combo, others: [(L("addHotkey"), model.addShortcut.combo)],
                                registered: !model.hotkeyFailed, isEnabled: model.hotkeyEnabled)
                    Text(L("shortcutHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("addHotkey")) {
                    Toggle(HotkeyText.enable, isOn: Binding(get: { model.addEnabled }, set: { model.addEnabled = $0; model.save() }))
                    HotkeyField(id: "add", combo: Binding(get: { model.addCombo }, set: { model.addCombo = $0 }),
                                defaultCombo: Shortcut.add.combo, others: [(L("pasteHotkey"), model.shortcut.combo)],
                                registered: !model.addFailed, isEnabled: model.addEnabled)
                    Text(L("addHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (L("pasteTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("cleanupTitle")) {
                    Toggle(L("trimIndent"), isOn: Binding(get: { model.trimIndent }, set: { model.trimIndent = $0; model.save() }))
                    Toggle(L("stripMarkers"), isOn: Binding(get: { model.stripMarkers }, set: { model.stripMarkers = $0; model.save() }))
                    Text(L("cleanupHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("windowTitle")) {
                    Toggle(L("closeWhenEmpty"), isOn: Binding(get: { model.closeWhenEmpty }, set: { model.closeWhenEmpty = $0; model.save() }))
                    Text(L("closeWhenEmptyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("notifyTitle")) {
                    Toggle(L("notifyEach"), isOn: Binding(get: { model.notifyEach }, set: { model.notifyEach = $0; model.save() }))
                    Text(L("notifyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
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
    var item: NSStatusItem!
    var mainWindow: NSWindow?
    var preferences: NSWindow?
    var helpWindow: NSWindow?
    let menu = NSMenu()
    var resultItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        ExcludedApps.shared.configure(explanation: L("excluded.explanation"), initial: ExcludedDefaults.initial)
        model = Model()
        ExcludedApps.shared.onChange = { [weak self] in self?.model.excludedAppsChanged() }
        model.closeMainWindow = { [weak self] in self?.mainWindow?.close() }
        model.revealMainWindow = { [weak self] in self?.showMainWindow(activate: false) }
        SettingsSync.shared.onImport = { [weak self] in self?.model.reload() }
        SettingsSync.shared.start(.init(
            keys: ["hotkeyEnabled", "pasteShortcut", "addEnabled", "addShortcut", "trimIndent", "stripMarkers", "notifyEach", "closeWhenEmpty"],
            note: StartupWindow.text("ホットキーと貼り付け方を書き出し・同期します。", "Exports and syncs the hotkeys and the paste options.",
                                     "导出并同步快捷键和粘贴方式。", "단축키와 붙여넣기 방식을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・常駐・メニューバー・対象外アプリはMacごとに設定します。",
                                       "Launch at login, staying open, the menu bar icon and excluded apps are set on each Mac.",
                                       "登录时启动、常驻、菜单栏图标和排除的应用需在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 상주, 메뉴 막대 아이콘, 제외할 앱은 Mac마다 설정합니다.")))
        AccessibilityText.neededOverride = [
            "前面のアプリへ「ペースト」（⌘V）を送るために使用します。未許可の場合、⌃⌥V を押しても1行ずつペーストできません。",
            "Used to send Paste (⌘V) to the front app. Without permission, ⌃⌥V cannot paste line by line.",
            "用于向前台应用发送“粘贴”（⌘V）。未获授权时，按 ⌃⌥V 无法逐行粘贴。",
            "앞에 있는 앱에 붙여넣기(⌘V)를 보내는 데 사용합니다. 권한이 없으면 ⌃⌥V를 눌러도 한 줄씩 붙여넣을 수 없습니다."
        ]
        WindowActivationPolicy.install()
        buildMainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.setAccessibilityLabel("PasteInARow")
        menu.delegate = self
        resultItem = menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, L("openMainWindow"), #selector(openMainWindow))
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
            MenuBarPresence.shared.install(name: "PasteInARow", symbol: "list.number", existing: item,
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
    /// `activate: false` (after ⌃⌥⌘C) puts the window in front without activating PasteInARow,
    /// so the user can keep selecting and copying in the other app.
    func showMainWindow(activate: Bool = true) {
        model.refreshQueue()
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            // Native title bar unchanged; no app name in it (BASELINE「主画面の背景とタイトルバー」).
            window.title = ""
            window.titleVisibility = .hidden
            let content = NSView(frame: window.contentLayoutRect)
            AppSurface.install(in: content)
            let hosting = NSHostingView(rootView: MainView(model: model))
            hosting.sizingOptions = [.minSize]
            // The hosting view sits on the shared surface view, so size the window from the SwiftUI content.
            let fitting = hosting.fittingSize
            let size = NSSize(width: max(560, ceil(fitting.width)), height: max(520, ceil(fitting.height)))
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
            model.mainWindow = window
        }
        if let window = mainWindow, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        if activate { NSApp.activate(ignoringOtherApps: true); mainWindow?.makeKeyAndOrderFront(nil) }
        else { mainWindow?.orderFrontRegardless() }
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
        if helpWindow == nil { helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: "PasteInARow — " + L("help"), text: L("helpText"), heading: L("helpHeading")) } }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func togglePause() { model.togglePause() }
    @objc func restart() { model.restart() }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary ?? [:]
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "PasteInARow",
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
    static let initial = ["com.adobe.illustrator", "com.cocoatech.PathFinder-setapp", "com.apple.iWork.Keynote", "com.apple.Keynote"]
}
