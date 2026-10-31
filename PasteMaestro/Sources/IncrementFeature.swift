import AppKit
import SwiftUI
import ServiceManagement
import Carbon
import ApplicationServices
import UniformTypeIdentifiers

func IL(_ key: String) -> String { NSLocalizedString(key, tableName: "Increment", comment: "") }

@MainActor
final class IncrementModel: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var hotkeyEnabled = UserDefaults.standard.object(forKey: "increment.hotkeyEnabled") as? Bool ?? false
    @Published var paused = false
    @Published var shortcut = UserDefaults.standard.data(forKey: "increment.incrementShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .increment
    /// How much one press adds (numbers, days, letters). The macro always adds 1.
    @Published var step = max(1, min(999, UserDefaults.standard.object(forKey: "increment.step") as? Int ?? 1))
    @Published var dates = UserDefaults.standard.object(forKey: "increment.dates") as? Bool ?? true
    @Published var letters = UserDefaults.standard.object(forKey: "increment.letters") as? Bool ?? true
    /// Off by default: like the macro, the first press already counts up.
    @Published var firstAsIs = UserDefaults.standard.object(forKey: "increment.firstAsIs") as? Bool ?? false
    @Published var notifyEach = UserDefaults.standard.object(forKey: "increment.notifyEach") as? Bool ?? false
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    @Published var status = IL("ready")
    @Published var statusIsError = false
    @Published var hotkeyStatus = ""
    @Published var hotkeyFailed = false
    @Published var loginStatus = ""
    @Published var loginOn = false
    @Published var current: String?
    @Published var next: IncrementResult?
    @Published var canRevert = false
    /// The next press pastes the copied text as it is (「コピー直後は元の値をペースト」).
    @Published var firstPending = false
    let hotkeys = HotkeySet(signature: "INCP")
    let paster = IncrementPaster()
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var observers: [NSObjectProtocol] = []
    private var workspaceObserver: NSObjectProtocol?
    /// Watches the clipboard only while the main window is open (B13).
    private var clipboardTimer: Timer?
    private var seenChange = -1
    /// What is registered now; app switches re-register only when this changes.
    private var registeredState: String?

    var options: Incrementer.Options { .init(step: step, dates: dates, letters: letters) }

    init() {
        hotkeys.action = { [weak self] _ in self?.trigger() }
        // HotkeySet pauses ⌥V while a key is being recorded; afterwards register again to report a conflict.
        HotkeyRecorder.shared.onRecordingChanged.append { [weak self] recording in
            guard let self, !recording else { return }
            self.registeredState = nil; self.refreshHotkey()
        }
        // Event-driven: the hotkey is released while an excluded app (or IncrementPaste itself) is in front (B13, B21).
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshHotkey() }
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLogin(); self?.refreshHotkey(); self?.refreshPreview() }
        })
        refreshLogin(); refreshHotkey(); refreshPreview()
    }

    func save() {
        step = max(1, min(999, step))
        defaults.set(hotkeyEnabled, forKey: "increment.hotkeyEnabled")
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: "increment.incrementShortcut")
        defaults.set(step, forKey: "increment.step")
        defaults.set(dates, forKey: "increment.dates")
        defaults.set(letters, forKey: "increment.letters")
        defaults.set(firstAsIs, forKey: "increment.firstAsIs")
        defaults.set(notifyEach, forKey: "increment.notifyEach")
        refreshHotkey(); refreshPreview()
    }

    /// Re-reads the shared settings after SettingsSync applied them; save() would otherwise write the old values back.
    func reload() {
        hotkeyEnabled = defaults.object(forKey: "increment.hotkeyEnabled") as? Bool ?? false
        shortcut = defaults.data(forKey: "increment.incrementShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .increment
        step = max(1, min(999, defaults.object(forKey: "increment.step") as? Int ?? 1))
        dates = defaults.object(forKey: "increment.dates") as? Bool ?? true
        letters = defaults.object(forKey: "increment.letters") as? Bool ?? true
        firstAsIs = defaults.object(forKey: "increment.firstAsIs") as? Bool ?? false
        notifyEach = defaults.object(forKey: "increment.notifyEach") as? Bool ?? false
        refreshHotkey(); refreshPreview()
    }

    /// The hotkey passes through to the front app while it is excluded or IncrementPaste itself.
    func blocked(_ app: NSRunningApplication?) -> Bool {
        MainActor.assumeIsolated { ExcludedApps.shared.blocksHotkeys(bundleID: app?.bundleIdentifier, pid: app?.processIdentifier) }
    }

    func refreshHotkey() {
        publishHotkeys()
        let wanted = hotkeyEnabled && !paused
        let front = !blocked(NSWorkspace.shared.frontmostApplication) && !LegacyApps.running
        let state = "\(wanted):\(front):\(shortcut.signature)"
        guard state != registeredState else { return }
        registeredState = state
        var result = noErr
        if wanted {
            // Registered to detect a conflict even while an excluded app is in front; then released at once so the key passes through.
            result = hotkeys.register(1, shortcut.combo)
            if !front { hotkeys.unregister(1) }
        } else {
            hotkeys.unregister(1)
        }
        hotkeyFailed = wanted && result != noErr
        if !hotkeyEnabled { hotkeyStatus = IL("hotkeyDisabled") }
        else if paused { hotkeyStatus = IL("hotkeyPaused") }
        else if hotkeyFailed { hotkeyStatus = HotkeyText.registerFailed }
        else { hotkeyStatus = String(format: IL("hotkeyActive"), shortcut.label) }
    }

    /// Declares the hotkey for HotkeyHound (shared registrations cannot be listed from outside).
    func publishHotkeys() { MaestroRegistry.changed?() }

    /// The 「ホットキー」 field: the stored Shortcut (JSON with code, modifiers, label) as a KeyCombo.
    var combo: KeyCombo? {
        get { shortcut.combo }
        set { if let newValue { shortcut = Shortcut(newValue); save() } }
    }
    func togglePause() { paused.toggle(); refreshHotkey() }

    func trigger() {
        guard hotkeyEnabled, !paused, let front = NSWorkspace.shared.frontmostApplication, !blocked(front), !LegacyApps.running else { return }
        let pid = front.processIdentifier
        let outcome = paster.paste(options: options, firstAsIs: firstAsIs, appName: front.localizedName ?? "", pid: pid, stillTarget: { [weak self] in
            guard let self, let now = NSWorkspace.shared.frontmostApplication, now.processIdentifier == pid else { return false }
            return self.hotkeyEnabled && !self.paused && !LegacyApps.running && !self.blocked(now)
        })
        report(outcome)
    }

    func report(_ outcome: IncrementOutcome) {
        var message: String?
        switch outcome {
        case .pasted(let appName, _, let after, _):
            status = String(format: IL("success.pasted"), Self.preview(after), appName); statusIsError = false
            if notifyEach { message = Self.preview(after) }
        case .unchanged(let appName, let text, let first):
            status = String(format: IL(first ? "success.first" : "success.unchanged"), Self.preview(text), appName); statusIsError = false
            // Pasting the same text again is worth telling even with notifications off.
            if !first { message = IL("notify.unchanged") } else if notifyEach { message = Self.preview(text) }
        case .failed(let reason):
            status = reason; statusIsError = true
            NSSound.beep()
            // Never just a beep (B27): the reason is shown near the top of the screen.
            message = reason
        }
        if let message { MainActor.assumeIsolated { TransientMessage.show(message) } }
        refreshPreview()
    }

    func revert() {
        if paster.revert() { status = IL("reverted"); statusIsError = false }
        else { status = IL("revertUnavailable"); statusIsError = true }
        refreshPreview()
    }

    static func preview(_ text: String) -> String {
        let line = text.replacingOccurrences(of: "\r\n", with: " ").replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        return line.count > 40 ? String(line.prefix(40)) + "…" : line
    }

    func refreshPreview() {
        seenChange = NSPasteboard.general.changeCount
        let preview = paster.preview(options: options, firstAsIs: firstAsIs)
        current = preview.current; next = preview.next
        canRevert = paster.canRevert
        firstPending = firstAsIs && paster.lastChange != seenChange
    }
    func watchClipboard(_ on: Bool) {
        clipboardTimer?.invalidate(); clipboardTimer = nil
        guard on else { return }
        refreshPreview()
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, NSPasteboard.general.changeCount != self.seenChange else { return }
                self.refreshPreview()
            }
        }
        clipboardTimer?.tolerance = 0.2
    }

    /// The 「対象外アプリ」 list changed: register the hotkeys again for the front app.
    func excludedAppsChanged() { registeredState = nil; refreshHotkey() }

    func refreshLogin() {
        let state = SMAppService.mainApp.status
        loginOn = state == .enabled || state == .requiresApproval
        switch state {
        case .enabled: loginStatus = IL("loginEnabled")
        case .requiresApproval: loginStatus = IL("loginApproval")
        case .notFound: loginStatus = IncrementModel.isInApplicationsFolder ? IL("loginDisabled") : IL("loginNotFound")
        default: loginStatus = IL("loginDisabled")
        }
    }
    static var isInApplicationsFolder: Bool {
        let parent = Bundle.main.bundleURL.resolvingSymlinksInPath().deletingLastPathComponent().standardizedFileURL.path
        let folders = ["/Applications", FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").standardizedFileURL.path]
        return folders.contains { parent == $0 || parent.hasPrefix($0 + "/") }
    }
    func changeLogin(_ value: Bool) {
        do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; refreshLogin() }
        catch { refreshLogin(); loginStatus = IL("loginFailed") + error.localizedDescription }
    }

    func stop() {
        hotkeys.unregisterAll()
        clipboardTimer?.invalidate()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

/// Shared header (AppHeader.swift): current bundle icon, functional title and subtitle.
struct IncrementHeaderView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView { appHeader(IL("headerTitle"), subtitle: IL("headerSubtitle")) }
    func updateNSView(_ view: NSStackView, context: Context) {}
}

struct IncrementStatusRow: View {
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

/// One white box of the clipboard → next paste pair.
struct IncrementValueBox: View {
    let title: String
    let value: String?
    let placeholder: String
    var emphasized = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
            Text(value.map(IncrementModel.preview) ?? placeholder)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(value == nil ? .secondary : emphasized ? .primary : .secondary)
                .lineLimit(1).truncationMode(.tail)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .border(Color(nsColor: .separatorColor), width: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title + ": " + (value ?? placeholder))
    }
}

struct IncrementMainView: View {
    @ObservedObject var model: IncrementModel
    private var kindText: String {
        guard model.current != nil, let next = model.next else { return "" }
        if next.kind == .none { return IL(model.firstPending ? "kind.first" : "kind.none") }
        return IL("kind." + next.kind.rawValue)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            IncrementHeaderView().fixedSize(horizontal: false, vertical: true)
            // Only a problem that stops the hotkey is shown here (B09, B27).
            if !AccessibilitySection.isTrusted {
                IncrementStatusRow(symbol: "exclamationmark.triangle.fill", tint: .orange, title: AccessibilityText.text("title"),
                          value: AccessibilityText.text("denied"))
            } else if model.hotkeyFailed {
                IncrementStatusRow(symbol: "exclamationmark.triangle.fill", tint: .orange, title: IL("hotkeyRow"), value: model.hotkeyStatus)
            }
            HStack(alignment: .center, spacing: 10) {
                IncrementValueBox(title: IL("clipboardTitle"), value: model.current, placeholder: IL("clipboardEmpty"))
                Image(systemName: "arrow.right").font(.system(size: 18, weight: .semibold)).foregroundColor(.secondary).accessibilityHidden(true)
                IncrementValueBox(title: String(format: IL("nextTitle"), model.shortcut.label), value: model.current == nil ? nil : model.next?.text,
                         placeholder: "—", emphasized: true)
            }
            Text(kindText).font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: model.statusIsError ? "exclamationmark.circle.fill" : "info.circle")
                    .foregroundColor(model.statusIsError ? .red : .secondary).accessibilityHidden(true)
                Text(model.status).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            .accessibilityElement(children: .combine)
            DisclosureGroup(M("explanation")) { Text(IL("examples")).font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
            Spacer(minLength: 0)
            HStack {
                Button(IL("settingsButton")) { (NSApp.delegate as? AppDelegate)?.showPreferences() }
                Spacer()
                Button(IL("revert")) { model.revert() }.disabled(!model.canRevert).help(IL("revertHint"))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
    }
}

struct IncrementPreferences: View {
 @ObservedObject var model: IncrementModel
 var body: some View { VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSection(IL("incrementHotkey")) {
                    Toggle(HotkeyText.enable, isOn: Binding(get: { model.hotkeyEnabled }, set: { model.hotkeyEnabled = $0; model.save() }))
                    HotkeyField(id: "increment", combo: Binding(get: { model.combo }, set: { model.combo = $0 }),
                                defaultCombo: Shortcut.increment.combo, others: MaestroRegistry.others(except: "increment"), registered: !model.hotkeyFailed, isEnabled: model.hotkeyEnabled,
                                allowsOption: true)  // the default ⌥V is ⌥ alone
                    DisclosureGroup(M("explanation")) { Text(IL("shortcutHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                SettingsSection(IL("rulesTitle")) {
                    HStack {
                        Text(IL("step"))
                        TextField("", value: Binding(get: { model.step }, set: { model.step = $0; model.save() }), format: .number)
                            .frame(width: 60).multilineTextAlignment(.trailing).accessibilityLabel(IL("step"))
                        Stepper("", value: Binding(get: { model.step }, set: { model.step = $0; model.save() }), in: 1...999).labelsHidden().accessibilityLabel(IL("step"))
                    }
                    Toggle(IL("dates"), isOn: Binding(get: { model.dates }, set: { model.dates = $0; model.save() }))
                    Toggle(IL("letters"), isOn: Binding(get: { model.letters }, set: { model.letters = $0; model.save() }))
                    DisclosureGroup(M("explanation")) { Text(IL("rulesHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
                SettingsSection(IL("pasteTitle")) {
                    Toggle(IL("firstAsIs"), isOn: Binding(get: { model.firstAsIs }, set: { model.firstAsIs = $0; model.save() }))
                    DisclosureGroup(M("explanation")) { Text(IL("firstAsIsHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
                    Toggle(IL("notifyEach"), isOn: Binding(get: { model.notifyEach }, set: { model.notifyEach = $0; model.save() }))
                    DisclosureGroup(M("explanation")) { Text(IL("notifyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
            }

 } }
}
