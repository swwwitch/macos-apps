import AppKit
import SwiftUI
import ServiceManagement
import Carbon
import ApplicationServices
import UniformTypeIdentifiers

func SL(_ key: String) -> String { NSLocalizedString(key, tableName: "Style", comment: "") }

@MainActor
final class StyleModel: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var hotkeyEnabled = UserDefaults.standard.object(forKey: "style.hotkeyEnabled") as? Bool ?? false
    @Published var paused = false
    @Published var shortcut = UserDefaults.standard.data(forKey: "style.pasteShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .style
    /// On: the app's own 「ペーストしてスタイルを合わせる」 etc. first, as the KM macros do.
    @Published var useMenu = UserDefaults.standard.object(forKey: "style.useMenu") as? Bool ?? true
    @Published var menuTitles = MenuTitles.load()
    /// On: the styled clipboard comes back after the plain-text paste. Off: it stays plain, like KM's 「Remove Styles」.
    @Published var restoreClipboard = UserDefaults.standard.object(forKey: "style.restoreClipboard") as? Bool ?? true
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    @Published var status = SL("ready")
    @Published var statusIsError = false
    @Published var hotkeyStatus = ""
    @Published var hotkeyFailed = false
    @Published var loginStatus = ""
    @Published var loginOn = false
    let hotkeys = HotkeySet(signature: "PMSS")
    let paster = PlainPaster()
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var observers: [NSObjectProtocol] = []
    private var workspaceObserver: NSObjectProtocol?
    /// What is registered now; app switches re-register only when this changes.
    private var registeredState: String?

    init() {
        hotkeys.action = { [weak self] _ in self?.trigger() }
        // HotkeySet pauses ⇧⌘V while a key is being recorded; afterwards register again to report a conflict.
        HotkeyRecorder.shared.onRecordingChanged.append { [weak self] recording in
            guard let self, !recording else { return }
            self.registeredState = nil; self.refreshHotkey()
        }
        // Event-driven: the hotkey is released while an excluded app (or PasteMatchStyle itself) is in front (B13, B21).
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshHotkey() }
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLogin(); self?.refreshHotkey() }
        })
        refreshLogin(); refreshHotkey()
    }

    func save() {
        defaults.set(hotkeyEnabled, forKey: "style.hotkeyEnabled")
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: "style.pasteShortcut")
        defaults.set(useMenu, forKey: "style.useMenu")
        MenuTitles.save(menuTitles)
        defaults.set(restoreClipboard, forKey: "style.restoreClipboard")
        refreshHotkey()
    }

    /// Re-reads the shared settings after SettingsSync applied them; save() would otherwise write the old values back.
    func reload() {
        hotkeyEnabled = defaults.object(forKey: "style.hotkeyEnabled") as? Bool ?? false
        shortcut = defaults.data(forKey: "style.pasteShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .style
        useMenu = defaults.object(forKey: "style.useMenu") as? Bool ?? true
        menuTitles = MenuTitles.load()
        restoreClipboard = defaults.object(forKey: "style.restoreClipboard") as? Bool ?? true
        refreshHotkey()
    }

    /// The hotkey passes through to the front app while it is excluded or PasteMatchStyle itself.
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
        // Registered to detect a conflict even while an excluded app is in front; then released at once so the key passes through.
        var result: OSStatus = noErr
        if wanted {
            result = hotkeys.register(1, shortcut.combo)
            if !front { hotkeys.unregister(1) }
        } else {
            hotkeys.unregister(1)
        }
        hotkeyFailed = wanted && result != noErr
        if !hotkeyEnabled { hotkeyStatus = SL("hotkeyDisabled") }
        else if paused { hotkeyStatus = SL("hotkeyPaused") }
        else if hotkeyFailed { hotkeyStatus = HotkeyText.registerFailed }
        else { hotkeyStatus = String(format: SL("hotkeyActive"), shortcut.label) }
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
        let outcome = paster.paste(appName: front.localizedName ?? "", pid: pid, useMenu: useMenu, titles: menuTitles,
                                   restoreClipboard: restoreClipboard, stillTarget: { [weak self] in
            guard let self, let now = NSWorkspace.shared.frontmostApplication, now.processIdentifier == pid else { return false }
            return self.hotkeyEnabled && !self.paused && !LegacyApps.running && !self.blocked(now)
        })
        switch outcome {
        case .menu(let appName, let title):
            status = String(format: SL("success.menu"), appName, title); statusIsError = false
        case .plain(let appName):
            status = String(format: restoreClipboard ? SL("success.plain") : SL("success.plainKept"), appName); statusIsError = false
        case .failed(let reason):
            fail(reason)
        }
    }

    /// Never just a beep (B27): the reason is shown near the top of the screen.
    func fail(_ reason: String) {
        status = reason; statusIsError = true
        NSSound.beep()
        MainActor.assumeIsolated { TransientMessage.show(reason) }
    }

    func stripClipboard() {
        if paster.stripClipboard() { status = SL("stripped"); statusIsError = false }
        else { fail(SL("fail.noText")) }
    }

    func setMenuTitles(_ text: String) { menuTitles = MenuTitles.parse(text); save() }
    func resetMenuTitles() { menuTitles = MenuTitles.initial; save() }


    /// The 「対象外アプリ」 list changed: register the hotkeys again for the front app.
    func excludedAppsChanged() { registeredState = nil; refreshHotkey() }

    func refreshLogin() {
        let state = SMAppService.mainApp.status
        loginOn = state == .enabled || state == .requiresApproval
        switch state {
        case .enabled: loginStatus = SL("loginEnabled")
        case .requiresApproval: loginStatus = SL("loginApproval")
        case .notFound: loginStatus = StyleModel.isInApplicationsFolder ? SL("loginDisabled") : SL("loginNotFound")
        default: loginStatus = SL("loginDisabled")
        }
    }
    static var isInApplicationsFolder: Bool {
        let parent = Bundle.main.bundleURL.resolvingSymlinksInPath().deletingLastPathComponent().standardizedFileURL.path
        let folders = ["/Applications", FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").standardizedFileURL.path]
        return folders.contains { parent == $0 || parent.hasPrefix($0 + "/") }
    }
    func changeLogin(_ value: Bool) {
        do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; refreshLogin() }
        catch { refreshLogin(); loginStatus = SL("loginFailed") + error.localizedDescription }
    }

    func stop() {
        hotkeys.unregisterAll()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

/// Shared header (AppHeader.swift): current bundle icon, functional title and subtitle.
struct StyleHeaderView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView { appHeader(SL("headerTitle"), subtitle: SL("headerSubtitle")) }
    func updateNSView(_ view: NSStackView, context: Context) {}
}

struct StyleStatusRow: View {
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

struct StyleMainView: View {
    @ObservedObject var model: StyleModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StyleHeaderView().fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                // Only a problem that stops the hotkey is shown above the result (B09, B27).
                if !AccessibilitySection.isTrusted {
                    StyleStatusRow(symbol: "exclamationmark.triangle.fill", tint: .orange, title: AccessibilityText.text("title"),
                              value: AccessibilityText.text("denied"))
                } else if model.hotkeyFailed || !model.hotkeyEnabled || model.paused {
                    StyleStatusRow(symbol: "exclamationmark.triangle.fill", tint: .orange, title: SL("hotkeyRow"), value: model.hotkeyStatus)
                } else {
                    StyleStatusRow(symbol: "keyboard", tint: .secondary, title: SL("hotkeyRow"), value: model.hotkeyStatus)
                }
                StyleStatusRow(symbol: model.statusIsError ? "xmark.circle.fill" : "checkmark.circle", tint: model.statusIsError ? .red : .secondary,
                          title: SL("lastResult"), value: model.status)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .border(Color(nsColor: .separatorColor), width: 1)
            DisclosureGroup(M("explanation")) { Text(SL("mainHint")).font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
            Spacer(minLength: 0)
            HStack {
                Button(SL("settingsButton")) { (NSApp.delegate as? AppDelegate)?.showPreferences() }
                Spacer()
                Button(SL("strip")) { model.stripClipboard() }.help(SL("stripHint"))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 340, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
    }
}

/// The menu titles, one per line. Saved when the editor loses focus or the window closes.
struct StyleMenuTitlesEditor: View {
    @ObservedObject var model: StyleModel
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $text)
                .font(.system(size: 13))
                .focused($focused)
                .frame(height: 180)
                .border(Color(nsColor: .separatorColor), width: 1)
                .accessibilityLabel(SL("menuTitlesTitle"))
                .onChange(of: focused) { now in if !now { model.setMenuTitles(text) } }
                .onDisappear { model.setMenuTitles(text) }
            HStack {
                Button(SL("resetTitles")) { model.resetMenuTitles(); text = model.menuTitles.joined(separator: "\n") }
                Text(String(format: SL("titlesCount"), String(model.menuTitles.count))).font(.caption).foregroundColor(.secondary)
            }
        }
        .disabled(!model.useMenu)
        .onAppear { text = model.menuTitles.joined(separator: "\n") }
        // Imported or synced titles replace the text, so leaving the editor does not write the old ones back.
        .onChange(of: model.menuTitles) { titles in if !focused { text = titles.joined(separator: "\n") } }
    }
}

struct StylePreferences: View {
 @ObservedObject var model: StyleModel
 var body: some View { VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SL("pasteHotkey")) {
                    Toggle(HotkeyText.enable, isOn: Binding(get: { model.hotkeyEnabled }, set: { model.hotkeyEnabled = $0; model.save() }))
                    HotkeyField(id: "style", combo: Binding(get: { model.combo }, set: { model.combo = $0 }),
                                defaultCombo: Shortcut.style.combo, others: MaestroRegistry.others(except: "style"), registered: !model.hotkeyFailed, isEnabled: model.hotkeyEnabled)
                    DisclosureGroup(M("explanation")) { Text(SL("shortcutHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SL("menuTitlesTitle")) {
                    Toggle(SL("useMenu"), isOn: Binding(get: { model.useMenu }, set: { model.useMenu = $0; model.save() }))
                    StyleMenuTitlesEditor(model: model)
                    DisclosureGroup(M("explanation")) { Text(SL("menuTitlesHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
                SettingsSection(SL("clipboardTitle")) {
                    Toggle(SL("restoreClipboard"), isOn: Binding(get: { model.restoreClipboard }, set: { model.restoreClipboard = $0; model.save() }))
                    DisclosureGroup(M("explanation")) { Text(SL("restoreClipboardHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
            }

 } }
}
