import AppKit
import SwiftUI
import ServiceManagement
import Carbon
import UniformTypeIdentifiers

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var entries: [LaunchEntry] = UserDefaults.standard.data(forKey: "entries").flatMap { try? JSONDecoder().decode([LaunchEntry].self, from: $0) } ?? []
    @Published var hotkeysEnabled = UserDefaults.standard.object(forKey: "hotkeysEnabled") as? Bool ?? true
    @Published var paused = false
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    /// Finder entries go to Path Finder while it is running (on by default, as requested).
    @Published var preferPathFinder = UserDefaults.standard.object(forKey: "preferPathFinder") as? Bool ?? true
    @Published var recordingID: UUID?
    @Published var recordMessage = ""
    /// Enabled macOS shortcuts (signatures); re-read when the app becomes active, after System Settings changes.
    @Published var systemShortcuts = SystemShortcuts.enabled()
    /// Registration failures keyed by `Shortcut.signature`.
    @Published var failures: [String: OSStatus] = [:]
    /// Duplicate entry → the earlier entry that keeps the key.
    @Published var duplicates: [UUID: UUID] = [:]
    @Published var status = L("ready")
    @Published var statusIsError = false
    @Published var loginStatus = ""
    @Published var loginOn = false
    let hotkeys = HotKeyCenter()
    private var observers: [NSObjectProtocol] = []
    private var workspaceObserver: NSObjectProtocol?
    private var monitor: Any?
    /// What is registered now; app switches re-register only when this changes.
    private var registeredState: String?
    private var busy = false
    /// A key with a double-tap entry waits this long for the second press before running its single-press entry.
    static let doubleTapInterval: TimeInterval = min(max(NSEvent.doubleClickInterval, 0.25), 0.4)
    private var pendingTap: (signature: String, work: DispatchWorkItem)?

    init() {
        hotkeys.action = { [weak self] shortcut in self?.pressed(shortcut) }
        // Event-driven: hot keys are released while an excluded app is in front (B13).
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshHotkeys()
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshLogin(); self?.refreshHotkeys(); self?.systemShortcuts = SystemShortcuts.enabled()
        })
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let id = self.recordingID else { return event }
            if event.keyCode == 53 { self.stopRecording(); return nil }
            guard let candidate = Shortcut.recorded(keyCode: event.keyCode, flags: event.modifierFlags) else {
                self.recordMessage = L("invalidShortcut"); return nil
            }
            let double = self.entries.first { $0.id == id }?.doubleTap ?? false
            let conditioned = (self.entries.first { $0.id == id }?.frontRule ?? .none) != .none
            if !conditioned, let other = self.entries.first(where: { $0.id != id && $0.enabled && $0.frontRule == .none && $0.shortcut == candidate && $0.doubleTap == double }) {
                self.recordMessage = String(format: L("duplicateShortcut"), candidate.label, other.name); return nil
            }
            self.update(id) { $0.shortcut = candidate; $0.enabled = true }
            self.stopRecording()
            // Registered anyway, but say so: the system usually keeps the key.
            if self.systemShortcuts.contains(candidate.signature) {
                self.status = String(format: L("sys.recorded"), candidate.label, L(SystemShortcuts.nameKey(for: candidate))); self.statusIsError = true
                NSSound.beep()
            }
            return nil
        }
        refreshLogin(); refreshHotkeys()
    }

    func save() {
        defaults.set(try? JSONEncoder().encode(entries), forKey: "entries")
        defaults.set(hotkeysEnabled, forKey: "hotkeysEnabled")
        defaults.set(keepRunning, forKey: "keepRunning")
        defaults.set(preferPathFinder, forKey: "preferPathFinder")
        refreshHotkeys()
    }
    /// Re-reads the synced settings after SettingsSync applied another Mac's values; save() would otherwise write the old ones back.
    func reload() {
        recordingID = nil
        entries = defaults.data(forKey: "entries").flatMap { try? JSONDecoder().decode([LaunchEntry].self, from: $0) } ?? []
        hotkeysEnabled = defaults.object(forKey: "hotkeysEnabled") as? Bool ?? true
        preferPathFinder = defaults.object(forKey: "preferPathFinder") as? Bool ?? true
        // A received JSON payload is already stored. Re-encoding it here can change
        // object-key order and turn a received setting into a fresh outgoing edit.
        refreshHotkeys()
    }
    func update(_ id: UUID, _ change: (inout LaunchEntry) -> Void) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        change(&entries[index]); save()
    }

    func refreshHotkeys() {
        publishHotkeys()
        duplicates = EntryRules.duplicates(in: entries)
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let active = hotkeysEnabled && !paused && recordingID == nil && !Self.excludes(front)
        // Rows whose front-app condition does not hold are left out, so their key reaches the app in front.
        let items = active ? usable(front: front).compactMap(\.shortcut) : []
        let state = items.map(\.signature).joined(separator: ",") + ":\(active)"
        guard state != registeredState else { return }
        registeredState = state
        let result = hotkeys.register(items)
        // Keep failures seen while registered; an excluded app in front releases keys without clearing them.
        if active || items.isEmpty && !hotkeysEnabled { failures = result }
    }

    /// Enabled rows usable with this app in front, minus later rows sharing a key (and tap count) with an earlier one.
    func usable(front: String?) -> [LaunchEntry] {
        let clash = EntryRules.duplicates(in: entries, front: .some(front))
        return entries.filter { $0.enabled && EntryRules.applies($0, front: front) && clash[$0.id] == nil }
    }
    /// Declares the keys for HotkeyHound (shared registrations cannot be listed from outside).
    func publishHotkeys() {
        let own = Bundle.main.bundleIdentifier.map { [$0] } ?? []
        HotkeyManifest.publish(entries.compactMap { entry in
            guard let shortcut = entry.shortcut else { return nil }
            return HotkeyManifest.Item(id: entry.id.uuidString, title: String(format: L("manifestTitle"), entry.name), keyCode: Int(shortcut.code),
                                       modifiers: Int(shortcut.modifiers), enabled: hotkeysEnabled && entry.enabled, scope: "except", apps: Self.excludedIDs + own)
        })
    }

    func startRecording(_ id: UUID) {
        recordingID = recordingID == id ? nil : id
        recordMessage = recordingID == nil ? "" : L("recordHint")
        refreshHotkeys()
    }
    func stopRecording() { recordingID = nil; recordMessage = ""; save() }
    func togglePause() { paused.toggle(); refreshHotkeys() }

    /// A registered key went down. Without a double-tap entry the single entry runs at once; with one,
    /// a second press within `doubleTapInterval` runs the double-tap entry, otherwise the single entry runs after the wait.
    func pressed(_ shortcut: Shortcut) {
        guard hotkeysEnabled, !paused, recordingID == nil else { return }
        if passToGoogleSheets(shortcut) { return }
        let live = usable(front: NSWorkspace.shared.frontmostApplication?.bundleIdentifier).filter { $0.shortcut == shortcut }
        let single = live.first { !$0.doubleTap }
        guard let double = live.first(where: \.doubleTap) else { if let single { trigger(single) }; return }
        if let pending = pendingTap, pending.signature == shortcut.signature {
            pending.work.cancel(); pendingTap = nil
            trigger(double)
            return
        }
        pendingTap?.work.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingTap = nil
            if let single { self?.trigger(single) }
        }
        pendingTap = (shortcut.signature, work)
        DispatchQueue.main.asyncAfter(deadline: .now() + Model.doubleTapInterval, execute: work)
    }
    /// A key that is not physically down was sent by another app (SpreadsheetHelper's ⌃⌥D ⌃⌥H …):
    /// Google Sheets in Chrome, Safari or Firefox gets it back. A key pressed by hand still launches.
    private func passToGoogleSheets(_ shortcut: Shortcut) -> Bool {
        guard !CGEventSource.keyState(.hidSystemState, key: CGKeyCode(shortcut.code)),
              let frontApp = NSWorkspace.shared.frontmostApplication, let front = frontApp.bundleIdentifier,
              EntryRules.sheetsBrowsers.contains(front),
              let url = URLCondition.frontURL(pid: frontApp.processIdentifier), EntryRules.isGoogleSheets(url) else { return false }
        URLCondition.passThrough(shortcut, taps: 1, to: frontApp.processIdentifier)
        return true
    }
    func trigger(_ entry: LaunchEntry) {
        guard hotkeysEnabled, !paused, recordingID == nil, !busy else { return }
        // Re-check right before acting: the front app may have changed since the key went down.
        let frontApp = NSWorkspace.shared.frontmostApplication
        let front = frontApp?.bundleIdentifier
        if Self.excludes(front) { return }
        guard EntryRules.applies(entry, front: front) else { return }
        // URL condition: a browser showing a listed page gets the key back instead.
        if !entry.skipURLs.isEmpty, let frontApp, let front, EntryRules.browsers.contains(front), let shortcut = entry.shortcut {
            if !AccessibilitySection.isTrusted {
                status = L("url.noPermission"); statusIsError = true
            } else if let url = URLCondition.frontURL(pid: frontApp.processIdentifier), EntryRules.urlMatches(url, patterns: entry.skipURLs) {
                URLCondition.passThrough(shortcut, taps: entry.doubleTap ? 2 : 1, to: frontApp.processIdentifier)
                status = String(format: L("url.passed"), shortcut.label, frontApp.localizedName ?? front); statusIsError = false
                return
            }
        }
        launch(entry)
    }
    /// From the list (double-click, menu): works whether or not the row's shortcut is on, paused or excluded.
    func launch(_ entry: LaunchEntry) {
        guard !busy else { return }
        busy = true
        Launcher.run(resolved(entry)) { [weak self] outcome in
            self?.busy = false
            self?.report(outcome)
        }
    }
    /// Checked at each press, so it follows Path Finder being started or quit.
    func resolved(_ entry: LaunchEntry) -> LaunchEntry {
        let running = NSWorkspace.shared.runningApplications.compactMap { app -> (String, String, String)? in
            guard !app.isTerminated, let id = app.bundleIdentifier, id.hasPrefix(EntryRules.pathFinderPrefix) else { return nil }
            return (id, app.localizedName ?? "Path Finder", app.bundleURL?.path ?? "")
        }
        return EntryRules.resolved(entry, preferPathFinder: preferPathFinder, running: running)
    }
    func report(_ outcome: LaunchOutcome) {
        switch outcome {
        case .activated(let name): status = String(format: L("result.activated"), name); statusIsError = false
        case .launched(let name): status = String(format: L("result.launched"), name); statusIsError = false
        case .alreadyFront(let name): status = String(format: L("result.alreadyFront"), name); statusIsError = false
        case .failed(let reason):
            status = reason; statusIsError = true
            NSSound.beep()
            // Never just a beep (B27).
            let message = reason
            MainActor.assumeIsolated { TransientMessage.show(message) }
        }
    }

    func addApps(_ urls: [URL]) {
        var added = 0
        for url in urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { continue }
            if entries.contains(where: { $0.bundleID == id }) { continue }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            entries.append(LaunchEntry(bundleID: id, name: name, path: url.path)); added += 1
        }
        status = added > 0 ? String(format: L("added"), String(added)) : L("addedNone"); statusIsError = false
        save()
    }
    func chooseApps() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]; panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        addApps(panel.urls)
    }
    /// 「追加する」 in 設定の共有: rows for app slots not yet registered are appended; this Mac's other settings stay.
    static func mergeSettings(_ file: NSDictionary, _ current: NSDictionary) -> (values: NSDictionary, added: Int) {
        let decode = { (value: Any?) in (value as? Data).flatMap { try? JSONDecoder().decode([LaunchEntry].self, from: $0) } ?? [] }
        let result = EntryRules.adding(decode(file["entries"]), to: decode(current["entries"]))
        let values = NSMutableDictionary(dictionary: file)
        values.addEntries(from: current as? [AnyHashable: Any] ?? [:])
        values["entries"] = try? JSONEncoder().encode(result.entries)
        return (values, result.added)
    }
    /// A .docklesslauncher (or older .applauncher) file from 1.10.0 and earlier, as UserDefaults values. Excluded apps stay per Mac.
    static func legacySettings(_ data: Data) -> NSDictionary? {
        guard let file = try? SettingsFile.decode(data), let entries = try? JSONEncoder().encode(file.entries) else { return nil }
        return ["entries": entries, "preferPathFinder": file.preferPathFinder]
    }
    /// From the keyboard view: drag key `a` onto key `b` (same modifiers). Undoable with ⌘Z; undoing swaps back.
    func swapKeys(_ a: UInt32, _ b: UInt32, modifiers: UInt32, undoManager: UndoManager?) {
        guard a != b else { return }
        entries = EntryRules.swappingKeys(entries, a, b, modifiers: modifiers)
        save()
        let first = Shortcut(code: a, modifiers: modifiers), second = Shortcut(code: b, modifiers: modifiers)
        status = String(format: L("kb.swapped"), first.label, second.label); statusIsError = false
        undoManager?.registerUndo(withTarget: self) { model in model.swapKeys(a, b, modifiers: modifiers, undoManager: undoManager) }
        undoManager?.setActionName(L("kb.swapAction"))
    }
    /// From the keyboard view: choose an app for an empty key. A row for the same app is not reused,
    /// so one app can have several keys; an unconditioned row already on the key is reported instead.
    func addApp(for shortcut: Shortcut) {
        if let other = entries.first(where: { $0.enabled && $0.frontRule == .none && !$0.doubleTap && $0.shortcut == shortcut }) {
            status = String(format: L("duplicateShortcut"), shortcut.label, other.name); statusIsError = true; NSSound.beep(); return
        }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]; panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = String(format: L("kb.assignPanel"), shortcut.label)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        assignApp(url, to: shortcut)
    }
    /// An app dropped on a key, or chosen in the panel above.
    func assignApp(_ url: URL, to shortcut: Shortcut) {
        if let other = entries.first(where: { $0.enabled && $0.frontRule == .none && !$0.doubleTap && $0.shortcut == shortcut }) {
            status = String(format: L("duplicateShortcut"), shortcut.label, other.name); statusIsError = true; NSSound.beep(); return
        }
        guard let id = Bundle(url: url)?.bundleIdentifier else { status = L("addedNone"); statusIsError = true; NSSound.beep(); return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        entries.append(LaunchEntry(bundleID: id, name: name, path: url.path, shortcut: shortcut))
        status = String(format: L("kb.assigned"), shortcut.label, name); statusIsError = false
        save()
        if systemShortcuts.contains(shortcut.signature) {
            status = String(format: L("sys.recorded"), shortcut.label, L(SystemShortcuts.nameKey(for: shortcut))); statusIsError = true
        }
    }
    /// URL prefixes, one per line, edited in a small sheet. Empty text removes the condition.
    func editSkipURLs(_ id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = L("url.title")
        alert.informativeText = L("url.body")
        let scroll = NSTextView.scrollableTextView()
        scroll.frame = NSRect(x: 0, y: 0, width: 380, height: 90)
        scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        let text = scroll.documentView as! NSTextView
        text.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        text.isAutomaticQuoteSubstitutionEnabled = false; text.isAutomaticLinkDetectionEnabled = false
        text.string = entry.skipURLs.isEmpty ? "https://docs.google.com/" : entry.skipURLs.joined(separator: "\n")
        alert.accessoryView = scroll
        alert.addButton(withTitle: L("url.save"))
        alert.addButton(withTitle: L("cancel")).keyEquivalent = "\u{1b}"
        alert.window.initialFirstResponder = text
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let patterns = EntryRules.urlPatterns(from: text.string)
        update(id) { $0.skipURLs = patterns }
        if !patterns.isEmpty && !AccessibilitySection.isTrusted { status = L("url.noPermission"); statusIsError = true }
    }
    /// Apps for the row's front-app condition (several can be chosen; they replace the current ones).
    func chooseFrontApps(_ id: UUID) {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]; panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = L("cond.panel")
        guard panel.runModal() == .OK else { return }
        let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        guard !ids.isEmpty else { return }
        update(id) { $0.frontApps = Array(Set(ids)).sorted() }
    }
    /// Choosing a condition with no apps yet opens the chooser at once; cancelling it leaves the row unconditioned.
    func setFrontRule(_ id: UUID, _ rule: FrontRule) {
        update(id) { $0.frontRule = rule }
        if rule != .none, entries.first(where: { $0.id == id })?.frontApps.isEmpty == true {
            chooseFrontApps(id)
            if entries.first(where: { $0.id == id })?.frontApps.isEmpty == true { update(id) { $0.frontRule = .none } }
        }
    }
    /// Picks the exact app copy (for example Adobe InDesign 2025.app) and switches the row to "this path".
    /// A copy with another Bundle ID is refused, so the row's key and options keep meaning the same app.
    func chooseAppPath(_ id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]; panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: entry.path).deletingLastPathComponent()
        panel.message = String(format: L("ver.choosePanel"), entry.bundleID)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard Bundle(url: url)?.bundleIdentifier == entry.bundleID else {
            status = String(format: L("ver.otherID"), url.lastPathComponent, entry.bundleID); statusIsError = true; NSSound.beep(); return
        }
        update(id) { $0.path = url.path; $0.versionMode = .path }
    }
    /// An app dropped on a row takes the row's place; the key, conditions and options stay.
    /// Another copy of the same app (e.g. InDesign 2025) switches the row to "this path", as chooseAppPath does.
    func replaceApp(_ id: UUID, with url: URL, undoManager: UndoManager?) {
        guard let old = entries.first(where: { $0.id == id }) else { return }
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else { status = L("addedNone"); statusIsError = true; NSSound.beep(); return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        guard bundleID != old.bundleID || url.path != old.path else { return }
        update(id) { entry in
            if bundleID == entry.bundleID { entry.versionMode = .path }
            entry.bundleID = bundleID; entry.name = name; entry.path = url.path
        }
        status = String(format: L("row.replaced"), old.name, name); statusIsError = false
        undoManager?.registerUndo(withTarget: self) { model in model.restore(old, undoManager: undoManager) }
        undoManager?.setActionName(L("row.replaceAction"))
    }
    /// Undo for replaceApp: puts the saved row back (and offers redo the same way).
    private func restore(_ entry: LaunchEntry, undoManager: UndoManager?) {
        guard let current = entries.first(where: { $0.id == entry.id }) else { return }
        update(entry.id) { $0 = entry }
        undoManager?.registerUndo(withTarget: self) { model in model.restore(current, undoManager: undoManager) }
        undoManager?.setActionName(L("row.replaceAction"))
    }
    /// A folder or file the app opens after launching. Saved with "~" for the home folder.
    func chooseOpenPath(_ id: UUID) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = true; panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        panel.message = L("opt.openPathPanel")
        if let current = entries.first(where: { $0.id == id })?.openPath {
            panel.directoryURL = URL(fileURLWithPath: (current as NSString).expandingTildeInPath)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        update(id) { $0.openPath = (url.path as NSString).abbreviatingWithTildeInPath }
    }
    func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
        if recordingID == id { recordingID = nil }
        save()
    }

    /// The shared 対象外アプリ list (B21); the model runs on the main thread.
    static var excludedIDs: [String] { MainActor.assumeIsolated { ExcludedApps.shared.ids } }
    static func excludes(_ bundleID: String?) -> Bool { MainActor.assumeIsolated { ExcludedApps.shared.excludes(bundleID) } }

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
        hotkeys.register([])
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

func appIcon(_ entry: LaunchEntry) -> NSImage? {
    guard let url = Launcher.appURL(for: entry) else { return nil }
    return NSWorkspace.shared.icon(forFile: url.path)
}
func appName(_ id: String) -> String {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
    return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
}

/// Shared header (AppHeader.swift): current bundle icon, functional title and subtitle.
struct HeaderView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView { appHeader(L("headerTitle"), subtitle: L("headerSubtitle")) }
    func updateNSView(_ view: NSStackView, context: Context) {}
}

struct EntryRow: View {
    @ObservedObject var model: Model
    let entry: LaunchEntry
    /// An app from Finder is over this row.
    @State private var dropTargeted = false
    @Environment(\.undoManager) private var undoManager
    var recording: Bool { model.recordingID == entry.id }
    var installed: Bool { Launcher.isInstalled(entry) }
    var problem: String? {
        if !installed { return L("row.notFound") }
        if let owner = model.duplicates[entry.id] {
            return String(format: L("row.duplicate"), model.entries.first { $0.id == owner }?.name ?? "")
        }
        if let signature = entry.shortcut?.signature, let code = model.failures[signature], entry.enabled { return String(format: L("row.registerFailed"), String(code)) }
        if let shortcut = entry.shortcut, model.systemShortcuts.contains(shortcut.signature) {
            return String(format: L("row.system"), L(SystemShortcuts.nameKey(for: shortcut)))
        }
        return nil
    }
    /// Bundle ID, the version actually used (when not left to the system), and the item to open.
    var caption: String {
        var parts = [entry.bundleID]
        if entry.versionMode != .system, let url = Launcher.appURL(for: entry) {
            parts.append(L(entry.versionMode == .newest ? "ver.captionNewest" : "ver.captionPath") + " " + (Launcher.version(of: url) ?? url.lastPathComponent))
        }
        if entry.frontRule != .none, !entry.frontApps.isEmpty {
            let names = entry.frontApps.map(appName).joined(separator: "、")
            parts.append(String(format: L(entry.frontRule == .except ? "cond.captionExcept" : "cond.captionOnly"), names))
        }
        if !entry.skipURLs.isEmpty {
            parts.append(String(format: L("url.caption"), entry.skipURLs.map { $0.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "") }.joined(separator: "、")))
        }
        if let open = entry.openPath { parts.append("→ " + open) }
        return parts.joined(separator: " · ")
    }
    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { entry.enabled }, set: { value in model.update(entry.id) { $0.enabled = value } }))
                .labelsHidden().help(L("row.enabled")).accessibilityLabel(L("row.enabled") + " " + entry.name)
            // Icon and name: double-click launches, like the Dock (the row's switch does not matter here).
            HStack(spacing: 10) {
                Group {
                    if let icon = appIcon(entry) { Image(nsImage: icon).resizable() } else { Image(systemName: "questionmark.app.dashed").resizable() }
                }.frame(width: 28, height: 28).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name).lineLimit(1)
                    if let problem {
                        Label(problem, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundColor(.orange).lineLimit(1)
                    } else {
                        Text(caption).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                }
                Spacer(minLength: 8)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { model.launch(entry) }
            .help(installed ? L("row.doubleClick") : L("row.notFound"))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: Text(L("row.launchNow"))) { model.launch(entry) }
            Button(action: { model.startRecording(entry.id) }) {
                Text(recording ? L("row.pressKey") : (entry.shortcut.map { $0.label + (entry.doubleTap ? " ×2" : "") } ?? L("row.noKey")))
                    .font(.system(.body, design: .monospaced)).lineLimit(1).fixedSize().frame(minWidth: 96, alignment: .leading)
            }
            .help(recording ? L("recordHint") : L("row.recordHelp"))
            .accessibilityLabel(L("row.key") + " " + (entry.shortcut?.label ?? L("row.noKey")))
            Button(action: { model.update(entry.id) { $0.shortcut = nil } }) { Image(systemName: "xmark.circle") }
                .buttonStyle(.borderless).disabled(entry.shortcut == nil).help(L("row.clearKey")).accessibilityLabel(L("row.clearKey"))
            Menu { menuItems } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize().help(L("row.options")).accessibilityLabel(L("row.options"))
        }
        .padding(.vertical, 3)
        .opacity(entry.enabled ? 1 : 0.55)
        .background(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2).padding(-2).opacity(dropTargeted ? 1 : 0))
        // One app dropped on a row replaces its app; several are added as new rows.
        .onDrop(of: AppDrop.types, isTargeted: $dropTargeted) { providers in
            AppDrop.load(providers) { urls in
                if urls.count == 1 { model.replaceApp(entry.id, with: urls[0], undoManager: undoManager) }
                else if !urls.isEmpty { model.addApps(urls) }
            }
        }
        // Right-click: the same items as the … menu.
        .contextMenu { menuItems }
    }
    var menuItems: some View { EntryMenuItems(model: model, entry: entry) }
}

/// The row's … menu, shared by the list (… button, right-click) and the keyboard view (right-click).
struct EntryMenuItems: View {
    @ObservedObject var model: Model
    let entry: LaunchEntry
    var installed: Bool { Launcher.isInstalled(entry) }
    var body: some View {
        Button(L("row.launchNow")) { model.launch(entry) }.disabled(!installed)
        Divider()
        Toggle(L("opt.allWindows"), isOn: Binding(get: { entry.allWindows }, set: { value in model.update(entry.id) { $0.allWindows = value } }))
        Toggle(L("opt.reopen"), isOn: Binding(get: { entry.reopen }, set: { value in model.update(entry.id) { $0.reopen = value } }))
        Toggle(L("opt.hideOthers"), isOn: Binding(get: { entry.hideOthers }, set: { value in model.update(entry.id) { $0.hideOthers = value } }))
        Toggle(L("opt.abc"), isOn: Binding(get: { entry.switchToABC }, set: { value in model.update(entry.id) { $0.switchToABC = value } }))
        Toggle(L("opt.doubleTap"), isOn: Binding(get: { entry.doubleTap }, set: { value in model.update(entry.id) { $0.doubleTap = value } }))
        Divider()
        Picker(L("ver.menu"), selection: Binding(get: { entry.versionMode }, set: { value in model.update(entry.id) { $0.versionMode = value } })) {
            Text(L("ver.system")).tag(VersionMode.system)
            Text(L("ver.newest")).tag(VersionMode.newest)
            Text(String(format: L("ver.path"), (entry.path as NSString).abbreviatingWithTildeInPath)).tag(VersionMode.path)
        }
        Button(L("ver.chooseApp")) { model.chooseAppPath(entry.id) }
        Divider()
        Picker(L("cond.menu"), selection: Binding(get: { entry.frontRule }, set: { value in model.setFrontRule(entry.id, value) })) {
            Text(L("cond.none")).tag(FrontRule.none)
            Text(L("cond.except")).tag(FrontRule.except)
            Text(L("cond.only")).tag(FrontRule.only)
        }
        if entry.frontRule != .none { Button(L("cond.choose")) { model.chooseFrontApps(entry.id) } }
        Button(entry.skipURLs.isEmpty ? L("url.menu") : L("url.menuEdit")) { model.editSkipURLs(entry.id) }
        if !entry.skipURLs.isEmpty { Button(L("url.clear")) { model.update(entry.id) { $0.skipURLs = [] } } }
        Divider()
        Button(entry.openPath == nil ? L("opt.openPath") : L("opt.openPathChange")) { model.chooseOpenPath(entry.id) }
        if entry.openPath != nil { Button(L("opt.openPathClear")) { model.update(entry.id) { $0.openPath = nil } } }
        Divider()
        Button(L("row.reveal")) { if let url = Launcher.appURL(for: entry) { NSWorkspace.shared.activateFileViewerSelecting([url]) } }.disabled(!installed)
        Divider()
        Button(L("row.remove")) { model.remove(entry.id) }
    }
}

/// Finder drops: collects the .app URLs (in drop order) and hands them over on the main thread.
enum AppDrop {
    static let types = [UTType.fileURL]
    static func load(_ providers: [NSItemProvider], _ done: @escaping ([URL]) -> Void) -> Bool {
        let files = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !files.isEmpty else { return false }
        let group = DispatchGroup()
        var found = [URL?](repeating: nil, count: files.count)
        for (i, provider) in files.enumerated() {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                DispatchQueue.main.async {
                    if let url, url.pathExtension == "app" { found[i] = url }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) { done(found.compactMap { $0 }) }
        return true
    }
}

struct MainView: View {
    @ObservedObject var model: Model
    @State private var dropTargeted = false
    @State private var query = ""
    @AppStorage("listOrder") private var orderRaw = EntryRules.Order.name.rawValue
    @AppStorage("listAscending") private var ascending = true
    /// "list" or "keyboard".
    @AppStorage("viewMode") private var viewMode = "list"
    /// A value saved by 1.1 ("manual") falls back to name order.
    var order: EntryRules.Order { EntryRules.Order(rawValue: orderRaw) ?? .name }
    var shown: [LaunchEntry] { EntryRules.visible(model.entries, query: query, order: order, ascending: ascending, label: { $0.label }) }
    /// Clicking the current sort again flips the direction; another one starts ascending.
    func sortButton(_ value: EntryRules.Order, _ title: String) -> some View {
        let selected = order == value
        return Button(action: {
            if selected { ascending.toggle() } else { orderRaw = value.rawValue; ascending = true }
        }) {
            HStack(spacing: 3) {
                Text(title)
                if selected { Image(systemName: ascending ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold)) }
            }
            .padding(.horizontal, 10).padding(.vertical, 3)
            .foregroundColor(selected ? .white : .primary)
            .background(RoundedRectangle(cornerRadius: 5).fill(selected ? Color.accentColor : Color(nsColor: .controlColor)))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(nsColor: .separatorColor), lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
        .help(selected ? L("sort.flip") : title)
        .accessibilityLabel(title + (selected ? " " + L(ascending ? "sort.ascending" : "sort.descending") : ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HeaderView().fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Picker(L("view.label"), selection: Binding(get: { viewMode }, set: { new in
                    guard new != viewMode else { return }
                    (NSApp.delegate as? AppDelegate)?.resizeMainWindow(from: viewMode, to: new)
                    viewMode = new
                })) {
                    Label(L("view.list"), systemImage: "list.bullet").tag("list")
                    Label(L("view.keyboard"), systemImage: "keyboard").tag("keyboard")
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .help(L("view.label"))
                if viewMode == "list" {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary).accessibilityHidden(true)
                    TextField(L("search.placeholder"), text: $query).textFieldStyle(.plain).accessibilityLabel(L("search.placeholder"))
                    if !query.isEmpty {
                        Button(action: { query = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                            .buttonStyle(.borderless).help(L("search.clear")).accessibilityLabel(L("search.clear"))
                    }
                }
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: .infinity)
                Text(L("sort.label")).foregroundColor(.secondary)
                HStack(spacing: 4) {
                    sortButton(.name, L("sort.name"))
                    sortButton(.key, L("sort.key"))
                }.fixedSize()
                .disabled(model.entries.isEmpty)
                } else {
                    Spacer()
                }
            }
            if viewMode == "keyboard" {
                // No scrolling: the keyboard is scaled to fit the window's current width and height.
                KeyboardView(model: model).padding(2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .frame(minHeight: 260)
            } else {
            Group {
                if model.entries.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "keyboard").font(.system(size: 34)).foregroundColor(.secondary).accessibilityHidden(true)
                        Text(L("empty")).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if shown.isEmpty {
                    Text(String(format: L("search.none"), query)).foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(shown) { entry in EntryRow(model: model, entry: entry) }
                    }
                }
            }
            .frame(minHeight: 260)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(dropTargeted ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: dropTargeted ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            if model.recordingID != nil {
                Text(model.recordMessage).font(.callout).foregroundColor(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: model.statusIsError ? "xmark.octagon.fill" : (model.hotkeysEnabled && !model.paused ? "keyboard" : "pause.circle"))
                    .foregroundColor(model.statusIsError ? .red : .secondary).accessibilityHidden(true)
                Text(model.hotkeysEnabled ? (model.paused ? L("pausedStatus") : model.status) : L("disabledStatus"))
                    .font(.callout).lineLimit(2).textSelection(.enabled)
                    .accessibilityLabel(L("status") + ": " + model.status)
            }
            HStack {
                Button(L("addApp")) { model.chooseApps() }
                Spacer()
                Button(L("settingsButton")) { (NSApp.delegate as? AppDelegate)?.showPreferences() }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
        // Apps dropped anywhere in the window are added (a key in the keyboard view takes them itself).
        .onDrop(of: AppDrop.types, isTargeted: $dropTargeted) { providers in
            AppDrop.load(providers) { urls in if !urls.isEmpty { model.addApps(urls) } }
        }
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
                // Needed only for the URL condition; launching and switching work without it.
                AccessibilitySection()
            })),
            (L("hotkeyTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("hotkeyTab")) {
                    Toggle(L("enabled"), isOn: Binding(get: { model.hotkeysEnabled }, set: { model.hotkeysEnabled = $0; model.save() }))
                    Text(String(format: L("registeredCount"), String(model.hotkeys.registeredCount))).font(.caption).foregroundColor(.secondary)
                    Text(L("shortcutHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("behavior")) {
                    Toggle(L("preferPathFinder"), isOn: Binding(get: { model.preferPathFinder }, set: { model.preferPathFinder = $0; model.save() }))
                    Text(L("preferPathFinderHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (ExcludedApps.title, AnyView(SettingsSection(ExcludedApps.title) { ExcludedAppsView() })),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
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
        // Configured before the model registers hot keys; 1.10 and earlier kept the list under "excluded".
        ExcludedApps.shared.configure(explanation: L("exclusionsHint"), legacyKeys: ["excluded"])
        model = Model()
        ExcludedApps.shared.onChange = { [weak self] in self?.model.refreshHotkeys() }
        SettingsSync.shared.onImport = { [weak self] in self?.model.reload() }
        SettingsSync.shared.start(.init(
            keys: ["entries", "hotkeysEnabled", "preferPathFinder", "listOrder", "listAscending", "viewMode"],
            note: L("syncNote"), perMac: L("syncPerMac"),
            merge: Model.mergeSettings,
            legacyExtensions: [SettingsFile.fileExtension, SettingsFile.legacyExtension], legacyImport: Model.legacySettings))
        AccessibilityText.neededOverride = [
            "「URLによる条件」でブラウザーのページのURLを読み取り、キーをブラウザーへ渡すために使います。アプリの起動・切り替えには不要です。",
            "Used by the URL condition to read the browser's page URL and hand the key back to the browser. Not needed for launching or switching apps.",
            "用于“URL 条件”读取浏览器页面的 URL，并把按键交还给浏览器。启动和切换应用不需要此权限。",
            "‘URL 조건’에서 브라우저 페이지의 URL을 읽고 키를 브라우저에 돌려주는 데 사용합니다. 앱 실행·전환에는 필요하지 않습니다."
        ]
        WindowActivationPolicy.install()
        buildMainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.setAccessibilityLabel("DocklessLauncher")
        menu.delegate = self
        resultItem = menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, L("openMainWindow"), #selector(openMainWindow))
        add(menu, L("settings"), #selector(showPreferences))
        add(menu, L("pause"), #selector(togglePause))
        menu.addItem(.separator())
        // Help submenu: app help and the note article (BASELINE「メニューの共通構成」).
        let statusHelp = NSMenu(title: L("help")); add(statusHelp, L("appHelp"), #selector(help)); MainActor.assumeIsolated { HelpLinks.addNoteItem(to: statusHelp) }
        menu.setSubmenu(statusHelp, for: menu.addItem(withTitle: L("help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator()); add(menu, L("quit"), #selector(quit))
        item.menu = menu
        MainActor.assumeIsolated {
            MenuBarPresence.shared.install(name: "DocklessLauncher", symbol: "command.square", existing: item,
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
        add(fileMenu, L("addAppMenu"), #selector(addApp), "o")
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
        resultItem.title = model.status
        menu.items.first { $0.action == #selector(togglePause) }?.state = model.paused ? .on : .off
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(togglePause) { menuItem.state = model.paused ? .on : .off; return model.hotkeysEnabled }
        return true
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMainWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !model.keepRunning }
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        // Leaving the list while a key is being recorded cancels the recording.
        if closing === mainWindow, model.recordingID != nil { model.stopRecording() }
        DispatchQueue.main.async { [weak self, weak closing] in
            guard let self, !self.model.keepRunning else { return }
            let otherVisible = NSApp.windows.contains { $0 !== closing && $0.isVisible && $0.canBecomeMain }
            if !otherVisible { NSApp.terminate(nil) }
        }
    }
    func applicationWillTerminate(_ notification: Notification) { model?.stop() }

    @objc func openMainWindow() { showMainWindow() }
    func showMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 600), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            // Native title bar unchanged; no app name in it (BASELINE「主画面の背景とタイトルバー」).
            window.title = ""
            window.titleVisibility = .hidden
            let content = NSView(frame: window.contentLayoutRect)
            AppSurface.install(in: content)
            let hosting = NSHostingView(rootView: MainView(model: model))
            hosting.sizingOptions = [.minSize]
            let size = NSSize(width: 680, height: 600)
            window.setContentSize(size)
            content.frame = NSRect(origin: .zero, size: size)
            hosting.frame = content.bounds
            hosting.autoresizingMask = [.width, .height]
            content.addSubview(hosting)
            window.contentView = content
            window.contentMinSize = NSSize(width: 640, height: 520)
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("MainWindow")
            mainWindow = window
        }
        if let window = mainWindow, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); mainWindow?.makeKeyAndOrderFront(nil)
        if UserDefaults.standard.string(forKey: "viewMode") == "keyboard" { widenMainWindow() }
    }
    /// Each view keeps its own window width: switching saves the width of the view being left and
    /// restores the other one (first time: list 680, keyboard 1000). The left edge stays put.
    func resizeMainWindow(from old: String, to new: String) {
        guard let window = mainWindow else { return }
        UserDefaults.standard.set(Double(window.frame.width), forKey: "windowWidth." + old)
        let saved = UserDefaults.standard.double(forKey: "windowWidth." + new)
        setMainWindowWidth(saved > 0 ? saved : (new == "keyboard" ? 1000 : 680))
    }
    /// At launch in keyboard view: make sure the window is at least that view's width.
    func widenMainWindow() {
        guard let window = mainWindow else { return }
        let saved = UserDefaults.standard.double(forKey: "windowWidth.keyboard")
        let wanted = saved > 0 ? saved : 1000
        if window.frame.width < wanted { setMainWindowWidth(wanted) }
    }
    private func setMainWindowWidth(_ width: Double) {
        guard let window = mainWindow else { return }
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? window.frame
        var frame = window.frame
        frame.size.width = min(max(CGFloat(width), window.minSize.width), visible.width)
        frame.origin.x = min(frame.origin.x, visible.maxX - frame.width)
        window.setFrame(frame, display: true, animate: true)
    }
    @objc func showPreferences() {
        model.refreshLogin()
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle")
            let hosting = NSHostingView(rootView: Preferences(model: model))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.contentMinSize = NSSize(width: 640, height: 480)
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("Preferences"); preferences = window
        }
        if let window = preferences, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
    }
    @objc func addApp() { showMainWindow(); model.chooseApps() }
    @objc func help() {
        if helpWindow == nil { helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: "DocklessLauncher — " + L("help"), text: L("helpText"), heading: L("helpHeading")) } }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func togglePause() { model.togglePause() }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary ?? [:]
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "DocklessLauncher",
            .applicationVersion: "\(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))",
            .credits: NSAttributedString(string: L("support"))])
    }
    @objc func quit() { NSApp.terminate(nil) }
}

// Apps launched through Launch Services inherit this process's environment. Started from a VS Code terminal,
// it carries ELECTRON_RUN_AS_NODE=1, which makes Electron apps (Biscuit, Discord…) start as Node and quit at once.
unsetenv("ELECTRON_RUN_AS_NODE")

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
