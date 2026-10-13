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
    @Published var trimIndent = UserDefaults.standard.object(forKey: "trimIndent") as? Bool ?? true
    @Published var stripMarkers = UserDefaults.standard.object(forKey: "stripMarkers") as? Bool ?? true
    /// Off by default, like the macro's local__notification = 0.
    @Published var notifyEach = UserDefaults.standard.object(forKey: "notifyEach") as? Bool ?? false
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
    @Published var upcoming: [String] = []
    @Published var upcomingLoaded = false
    @Published var canRestart = false
    /// The app that was in front before PasteInARow; clicks in the window paste there.
    @Published var targetName: String?
    @Published var pasting = false
    private var target: NSRunningApplication?
    let hotkey = SingleHotKey(signature: 0x5053_5543)       // 'PSUC'
    let paster = LinePaster()
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var observers: [NSObjectProtocol] = []
    private var workspaceObserver: NSObjectProtocol?
    private var monitor: Any?
    /// What is registered now; app switches re-register only when this changes.
    private var registeredState: String?

    init() {
        hotkey.action = { [weak self] in self?.trigger() }
        // Event-driven: the hotkey is released while an excluded app (or PasteInARow itself) is in front (B13, B21).
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.processIdentifier != self.ownPID {
                self.target = app; self.targetName = app.localizedName
            }
            self.refreshHotkey()
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshLogin(); self?.refreshAccessibility(); self?.refreshHotkey(); self?.refreshQueue()
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
        refreshLogin(); refreshHotkey(); refreshQueue()
    }

    func save() {
        defaults.set(hotkeyEnabled, forKey: "hotkeyEnabled")
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: "pasteShortcut")
        defaults.set(trimIndent, forKey: "trimIndent")
        defaults.set(stripMarkers, forKey: "stripMarkers")
        defaults.set(notifyEach, forKey: "notifyEach")
        defaults.set(keepRunning, forKey: "keepRunning")
        refreshHotkey(); refreshQueue()
    }

    /// The hotkey passes through to the front app while it is excluded or PasteInARow itself.
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
        var result: OSStatus = noErr
        if wanted {
            // Registered to detect a conflict even while an excluded app is in front; then released at once so the key passes through.
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
        let outcome = paster.paste(.next, appName: front.localizedName ?? "", pid: pid, trimIndent: trimIndent, stripMarkers: stripMarkers, stillTarget: { [weak self] in
            guard let self, let now = NSWorkspace.shared.frontmostApplication, now.processIdentifier == pid else { return false }
            return self.hotkeyEnabled && !self.paused && !self.blocked(now)
        })
        report(outcome)
    }

    func report(_ outcome: PasteOutcome) {
        switch outcome {
        case .pasted(let appName, let remaining, let next):
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
        refreshAccessibility(); refreshQueue()
        // The remainder is written back a moment later; show the clipboard state after that too.
        DispatchQueue.main.asyncAfter(deadline: .now() + LinePaster.writeBackDelay + 0.1) { [weak self] in self?.refreshQueue() }
    }
    /// Click in the window (the KM macro 「02)非連続ペースト」): bring back the previous app, wait until it is in front,
    /// then paste there. The window is ordered front again without activating PasteInARow, so the next click is easy.
    func pasteFromWindow(_ pick: LinePaster.Pick, window: NSWindow?) {
        guard !pasting else { return }
        guard let target, !target.isTerminated else { report(.failed(L("fail.noTarget"))); return }
        guard !blocked(target) else { report(.failed(String(format: L("fail.excludedTarget"), target.localizedName ?? ""))); return }
        guard AXIsProcessTrusted() else { report(.failed(L("fail.access"))); return }
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
                    let outcome = self.paster.paste(pick, appName: target.localizedName ?? "", pid: pid, trimIndent: self.trimIndent, stripMarkers: self.stripMarkers, stillTarget: { [weak self] in
                        guard let self, let now = NSWorkspace.shared.frontmostApplication, now.processIdentifier == pid else { return false }
                        return !self.blocked(now)
                    })
                    self.report(outcome)
                    window?.orderFrontRegardless()
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
    func clearQueue() {
        if paster.clear() { status = L("cleared"); statusIsError = false }
        refreshQueue()
    }

    static func preview(_ line: String) -> String { line.count > 40 ? String(line.prefix(40)) + "…" : line }

    func restart() {
        if paster.restart() { status = L("restarted"); statusIsError = false }
        else { status = L("restartUnavailable"); statusIsError = true }
        refreshQueue()
    }
    func refreshQueue() {
        let next = paster.upcoming(trimIndent: trimIndent, stripMarkers: stripMarkers)
        upcoming = next.lines; upcomingLoaded = next.loaded
        canRestart = paster.canRestart
    }
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

/// The lines the next presses paste, in BrowserSwitcher's list style: tall rows on the alternating
/// content backgrounds, a line border and large semibold text. The first row is the next paste.
struct QueueList: View {
    static let rowHeight: CGFloat = 56
    let lines: [String]
    /// Clicking a row pastes that line into the previous app; ⌥-click adds a line break (third argument).
    let pick: (Int, String, Bool) -> Void
    @State private var hovered: Int?
    var body: some View {
        let colors = NSColor.alternatingContentBackgroundColors
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.prefix(500).enumerated()), id: \.offset) { index, line in
                    Button { pick(index, line, NSEvent.modifierFlags.contains(.option)) } label: {
                        HStack(spacing: 16) {
                            Text("\(index + 1)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
                                .foregroundColor(index == 0 ? .white : .secondary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(index == 0 ? Color.accentColor : Color.primary.opacity(0.08)))
                            Text(line)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(index == 0 || hovered == index ? .primary : .secondary)
                                .lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: Self.rowHeight)
                        .background(hovered == index ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.18)
                                    : Color(nsColor: index.isMultiple(of: 2) && colors.count > 1 ? colors[1] : colors[0]))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in hovered = inside ? index : (hovered == index ? nil : hovered) }
                    .help(L("rowHint"))
                    .accessibilityLabel(String(format: L("ax.line"), String(index + 1), line))
                    .accessibilityHint(L("rowHint"))
                }
            }
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
            if !model.accessibilityAllowed {
                StatusRow(symbol: "exclamationmark.triangle.fill", tint: .orange, title: AccessibilityText.text("title"),
                          value: AccessibilityText.text("denied"))
            } else if model.hotkeyFailed {
                StatusRow(symbol: "exclamationmark.triangle.fill", tint: .orange, title: L("hotkeyRow"), value: model.hotkeyStatus)
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
                    QueueList(lines: model.upcoming) { index, line, newline in model.pasteFromWindow(.line(index: index, text: line, newline: newline), window: mainWindow) }
                }
                Text(L(model.upcomingLoaded ? "queueLoaded" : "queuePreview") + "\n" + (model.targetName.map { String(format: L("clickTarget"), $0) } ?? L("clickNoTarget"))).font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button(L("settingsButton")) { (NSApp.delegate as? AppDelegate)?.showPreferences() }
                Button(L("help")) { (NSApp.delegate as? AppDelegate)?.help() }
                Spacer()
                Button(L("restart")) { model.restart() }.disabled(!model.canRestart).help(L("restartHint"))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
    }
}

struct ShortcutRow: View {
    @ObservedObject var model: Model
    var body: some View {
        HStack {
            Text(model.shortcut.label).font(.system(.body, design: .monospaced)).frame(width: 110).accessibilityLabel(L("currentKey") + " " + model.shortcut.label)
            Button(model.recording ? L("cancelRecording") : L("change")) { model.startRecording() }
            Button(L("resetShortcut")) { model.resetShortcut() }
        }.disabled(!model.hotkeyEnabled && !model.recording)
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
                    Toggle(L("pause"), isOn: Binding(get: { model.paused }, set: { _ in model.togglePause() }))
                    ShortcutRow(model: model)
                    Text(model.hotkeyStatus).font(.caption).foregroundColor(model.hotkeyFailed ? .red : .secondary).fixedSize(horizontal: false, vertical: true)
                    if model.recording, !model.recordMessage.isEmpty { Text(model.recordMessage).font(.caption) }
                    Text(L("shortcutHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (L("pasteTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("cleanupTitle")) {
                    Toggle(L("trimIndent"), isOn: Binding(get: { model.trimIndent }, set: { model.trimIndent = $0; model.save() }))
                    Toggle(L("stripMarkers"), isOn: Binding(get: { model.stripMarkers }, set: { model.stripMarkers = $0; model.save() }))
                    Text(L("cleanupHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("notifyTitle")) {
                    Toggle(L("notifyEach"), isOn: Binding(get: { model.notifyEach }, set: { model.notifyEach = $0; model.save() }))
                    Text(L("notifyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (L("excluded.title"), AnyView(SettingsSection(L("excluded.title")) { ExcludedAppsView(model: model) })),
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
    func showMainWindow() {
        model.refreshAccessibility(); model.refreshQueue()
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
