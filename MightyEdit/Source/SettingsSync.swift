import AppKit

/// Syncs the palette button set and hotkeys through a plist in a folder the user picks
/// (iCloud Drive, Dropbox or any folder; modeled on Alfred's preferences folder). No entitlement needed.
/// Per-Mac state (login, residency, accessibility, window positions, excluded apps, the folder itself) is never synced.
/// Conflicts are resolved by the newest write.
final class SettingsSync: NSObject {
    static let shared = SettingsSync()
    private static let folderKey = "settingsSyncFolder"
    private static let legacyICloudKey = "iCloudSyncEnabled"
    private static let deviceKey = "iCloudSyncDeviceID"
    private static let lastSyncKey = "iCloudSyncLastDate"
    private static let fileName = "MightyEdit-Settings.plist"
    /// Called on the main thread after settings from another Mac were applied.
    var onImport: (() -> Void)?

    private let defaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "MightyEdit.settingsSync")
    private var lastValues: NSDictionary?
    private var pendingExport: DispatchWorkItem?
    private var timer: Timer?
    private var applying = false
    private let path = NSTextField(wrappingLabelWithString: "")
    private let status = NSTextField(wrappingLabelWithString: "")
    private let revealButton = NSButton(title: L("sync.reveal"), target: nil, action: nil)
    private let stopButton = NSButton(title: L("sync.stop"), target: nil, action: nil)
    private let nowButton = NSButton(title: L("sync.now"), target: nil, action: nil)

    var folder: URL? { defaults.string(forKey: Self.folderKey).map { URL(fileURLWithPath: $0, isDirectory: true) } }
    var enabled: Bool { folder != nil }
    private var file: URL? { folder?.appendingPathComponent(Self.fileName) }
    /// The folder is missing (sync service off, volume not mounted, or the App Store sandbox).
    var available: Bool { folder.map { FileManager.default.fileExists(atPath: $0.path) } ?? false }

    static func isSynced(_ key: String) -> Bool {
        let exact: Set<String> = ["paletteProfile", "paletteDisplayMode", "specialTypographyOptions", "shortcutsDisabled"]
        let prefixes = ["paletteVisible.", "specialListEnabled-", "shortcutDigit-", "shortcutScope-", "paletteInvocation."]
        return exact.contains(key) || prefixes.contains { key.hasPrefix($0) }
    }

    private var deviceID: String {
        if let id = defaults.string(forKey: Self.deviceKey) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: Self.deviceKey)
        return id
    }

    private func currentValues() -> NSDictionary {
        let domain = Bundle.main.bundleIdentifier.flatMap { defaults.persistentDomain(forName: $0) } ?? defaults.dictionaryRepresentation()
        return domain.filter { Self.isSynced($0.key) } as NSDictionary
    }

    /// Default folder for the chooser: Dropbox (custom locations included, from ~/.dropbox/info.json), else iCloud Drive.
    private static var suggestedFolder: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        if let data = try? Data(contentsOf: home.appendingPathComponent(".dropbox/info.json")),
           let info = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]],
           let root = (info["personal"]?["path"] ?? info["business"]?["path"]) as? String,
           FileManager.default.fileExists(atPath: root) {
            return URL(fileURLWithPath: root, isDirectory: true)
        }
        return home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    func start() {
        migrateICloudSetting()
        NotificationCenter.default.addObserver(self, selector: #selector(defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(check), name: NSApplication.didBecomeActiveNotification, object: nil)
        if enabled { resume() }
        refreshStatus()
    }

    /// The first version synced only to iCloud Drive/MightyEdit/Settings.plist.
    private func migrateICloudSetting() {
        guard defaults.bool(forKey: Self.legacyICloudKey) else { return }
        defaults.removeObject(forKey: Self.legacyICloudKey)
        guard folder == nil else { return }
        let legacy = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/MightyEdit", isDirectory: true)
        let old = legacy.appendingPathComponent("Settings.plist"), new = legacy.appendingPathComponent(Self.fileName)
        if FileManager.default.fileExists(atPath: old.path), !FileManager.default.fileExists(atPath: new.path) {
            try? FileManager.default.moveItem(at: old, to: new)
        }
        defaults.set(legacy.path, forKey: Self.folderKey)
    }

    private func resume(checkNow: Bool = true) {
        lastValues = currentValues()
        timer?.invalidate()
        // MightyEdit is resident and rarely active, so poll as well.
        timer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(check), userInfo: nil, repeats: true)
        if checkNow { check() }
    }

    @objc private func defaultsChanged() {
        guard enabled, !applying else { return }
        pendingExport?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.exportIfChanged() }
        pendingExport = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func exportIfChanged() {
        let values = currentValues()
        guard available, let file, values != lastValues else { return }
        lastValues = values
        let record: NSDictionary = ["version": 1, "device": deviceID, "deviceName": Host.current().localizedName ?? "", "modified": Date(), "values": values]
        queue.async { [weak self] in
            var error: NSError?
            var written = false
            NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &error) { url in
                written = record.write(to: url, atomically: true)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if written { self.defaults.set(record["modified"], forKey: Self.lastSyncKey) }
                self.refreshStatus(failed: !written)
            }
        }
    }

    private func readRecord(at file: URL, _ completion: @escaping (NSDictionary?) -> Void) {
        queue.async {
            var error: NSError?
            var record: NSDictionary?
            // A coordinated read also downloads a file that the sync service keeps online only.
            NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &error) { url in
                record = NSDictionary(contentsOf: url)
            }
            DispatchQueue.main.async { completion(record) }
        }
    }

    /// Applies a newer record written by another Mac.
    @objc func check() {
        guard available, let file else { refreshStatus(); return }
        readRecord(at: file) { [weak self] record in
            guard let self, self.file == file, let record,
                  let values = record["values"] as? NSDictionary, let modified = record["modified"] as? Date,
                  record["device"] as? String != self.deviceID else { return }
            let last = self.defaults.object(forKey: Self.lastSyncKey) as? Date ?? .distantPast
            guard modified > last else { return }
            if values != self.currentValues() { self.apply(values) }
            self.defaults.set(modified, forKey: Self.lastSyncKey)
            self.refreshStatus()
        }
    }

    private func apply(_ values: NSDictionary) {
        pendingExport?.cancel()
        applying = true
        for key in currentValues().allKeys.compactMap({ $0 as? String }) where values[key] == nil { defaults.removeObject(forKey: key) }
        for (key, value) in values { if let key = key as? String, Self.isSynced(key) { defaults.set(value, forKey: key) } }
        lastValues = currentValues()
        onImport?()
        applying = false
    }

    // MARK: Settings

    @MainActor func settingsView() -> NSView {
        path.font = .systemFont(ofSize: 13, weight: .medium)
        path.lineBreakMode = .byCharWrapping
        let note = NSTextField(wrappingLabelWithString: L("sync.note"))
        let perMac = NSTextField(wrappingLabelWithString: L("sync.perMac"))
        for label in [note, perMac] { label.font = .systemFont(ofSize: 11); label.textColor = .secondaryLabelColor }
        status.font = .systemFont(ofSize: 11)
        let choose = NSButton(title: L("sync.choose"), target: self, action: #selector(chooseFolder))
        revealButton.target = self; revealButton.action = #selector(reveal)
        stopButton.target = self; stopButton.action = #selector(stop)
        nowButton.target = self; nowButton.action = #selector(syncNow)
        for button in [choose, revealButton, nowButton, stopButton] { button.bezelStyle = .rounded }
        let buttons = NSStackView(views: [choose, revealButton, nowButton, stopButton]); buttons.spacing = 8
        let row = NSStackView(views: [buttons]); row.alignment = .leading
        refreshStatus()
        return SettingsUI.group(L("sync.title"), [path, status, note, perMac, row])
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L("sync.choosePrompt")
        panel.message = L("sync.chooseMessage")
        panel.directoryURL = folder ?? Self.suggestedFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        use(url)
    }

    /// Starts syncing with `url`. When the folder already holds different settings, ask which side wins.
    private func use(_ url: URL) {
        let candidate = url.appendingPathComponent(Self.fileName)
        readRecord(at: candidate) { [weak self] record in
            guard let self else { return }
            let values = record?["values"] as? NSDictionary
            var useSaved = false
            if let values, values != self.currentValues() {
                let alert = NSAlert()
                alert.messageText = L("sync.conflictTitle")
                alert.informativeText = L("sync.conflictDetail", (record?["deviceName"] as? String) ?? "?")
                alert.addButton(withTitle: L("sync.useCloud"))
                alert.addButton(withTitle: L("sync.useLocal"))
                alert.addButton(withTitle: L("sync.cancel"))
                switch alert.runModal() {
                case .alertFirstButtonReturn: useSaved = true
                case .alertSecondButtonReturn: break
                default: return
                }
            }
            self.defaults.set(url.path, forKey: Self.folderKey)
            if useSaved, let values {
                self.apply(values)
                self.defaults.set(record?["modified"] as? Date ?? Date(), forKey: Self.lastSyncKey)
                self.resume(checkNow: false)
            } else {
                // This Mac wins: mark the saved copy as seen, then overwrite it.
                self.defaults.set(Date(), forKey: Self.lastSyncKey)
                self.resume(checkNow: false)
                self.lastValues = nil
                self.exportIfChanged()
            }
            self.refreshStatus()
        }
    }

    @objc private func reveal() {
        guard let folder else { return }
        if let file, FileManager.default.fileExists(atPath: file.path) { NSWorkspace.shared.activateFileViewerSelecting([file]) }
        else { NSWorkspace.shared.open(folder) }
    }

    @objc private func stop() {
        defaults.removeObject(forKey: Self.folderKey)
        timer?.invalidate(); timer = nil
        refreshStatus()
    }

    @objc private func syncNow() {
        guard enabled else { return }
        defaults.removeObject(forKey: Self.lastSyncKey)
        check()
        exportIfChanged()
    }

    private func refreshStatus(failed: Bool = false) {
        path.stringValue = folder.map { ($0.path as NSString).abbreviatingWithTildeInPath } ?? L("sync.noFolder")
        path.textColor = enabled ? .labelColor : .secondaryLabelColor
        revealButton.isEnabled = available
        nowButton.isEnabled = available
        stopButton.isEnabled = enabled
        status.textColor = failed || (enabled && !available) ? .systemRed : .secondaryLabelColor
        guard enabled else { status.stringValue = L("sync.off"); return }
        if !available { status.stringValue = L("sync.unavailable"); return }
        if failed { status.stringValue = L("sync.failed"); return }
        if let date = defaults.object(forKey: Self.lastSyncKey) as? Date {
            status.stringValue = L("sync.last", DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short))
        } else { status.stringValue = L("sync.waiting") }
    }
}
