import AppKit
import SwiftUI

@MainActor final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var items: [FavoriteItem] = []
    @Published var selection: Set<UUID> = []
    @Published var sets: [String] = []
    @Published var setName = "" { didSet { if oldValue != setName && !oldValue.isEmpty { load() } } }
    @Published var status = ""
    /// Search text: shows only matching favorites (name or path). Dragging is off while searching.
    @Published var query = ""
    /// Bumped by ⌘F to move focus to the search field.
    @Published var searchFocusRequest = 0
    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    @Published var isDirty = false
    @Published var busy = false
    @Published var staysSorted = false
    @Published var dfxFound = true
    /// In-app category names, keyed "<folder set>|<category key>". Default Folder X separators cannot carry a name.
    @Published var categoryNames = UserDefaults.standard.dictionary(forKey: "categoryNames") as? [String: String] ?? [:] {
        didSet { defaults.set(categoryNames, forKey: "categoryNames") }
    }
    @Published var confirmBeforeSave = UserDefaults.standard.object(forKey: "confirmBeforeSave") as? Bool ?? true {
        didSet { defaults.set(confirmBeforeSave, forKey: "confirmBeforeSave") }
    }
    /// Per-folder data kept only in this app, keyed by FolderKey: notes (shared between Macs) and use counts (this Mac only).
    @Published var notes = UserDefaults.standard.dictionary(forKey: "folderNotes") as? [String: String] ?? [:] {
        didSet { defaults.set(notes, forKey: "folderNotes") }
    }
    @Published var usageCounts = UserDefaults.standard.dictionary(forKey: "usageCounts") as? [String: Int] ?? [:] {
        didSet { defaults.set(usageCounts, forKey: "usageCounts") }
    }
    @Published var trackUsage = UserDefaults.standard.bool(forKey: "trackUsage") {
        didSet { defaults.set(trackUsage, forKey: "trackUsage"); updateTracking() }
    }
    /// Automation (Apple events to Default Folder X) was refused; counting stops until retried.
    @Published var automationDenied = false
    nonisolated static let sharedKeys: Set<String> = ["categoryNames", "confirmBeforeSave", "folderNotes"]
    func reloadSharedSettings() {
        categoryNames = defaults.dictionary(forKey: "categoryNames") as? [String: String] ?? [:]
        confirmBeforeSave = defaults.object(forKey: "confirmBeforeSave") as? Bool ?? true
        notes = defaults.dictionary(forKey: "folderNotes") as? [String: String] ?? [:]
    }

    func note(for item: FavoriteItem) -> String { notes[FolderKey.of(item.path)] ?? "" }
    func setNote(_ text: String, for item: FavoriteItem) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        notes[FolderKey.of(item.path)] = trimmed.isEmpty ? nil : trimmed
    }
    func count(for item: FavoriteItem) -> Int { usageCounts[FolderKey.of(item.path)] ?? 0 }
    var showsCounts: Bool { showCounts && (trackUsage || !usageCounts.isEmpty) }
    @Published var editingNote: EditTarget?
    @Published var showingKeyboard = false
    @Published var renamingCategory: CategoryTarget?
    func editNote(_ id: UUID? = nil) {
        guard let id = id ?? (selection.count == 1 ? selection.first : nil), items.first(where: { $0.id == id })?.isSeparator == false else { return }
        editingNote = EditTarget(id: id)
    }

    // Counting uses: Default Folder X has no "folder used" event, so it is asked every 1.5 seconds while counting is on.
    private var usageTimer: Timer?
    private var counter = UsageCounter()
    private var polling = false
    private let pollQueue = DispatchQueue(label: "FavoriteFolders.usage")
    func updateTracking() {
        usageTimer?.invalidate(); usageTimer = nil; counter = UsageCounter(); automationDenied = false
        guard trackUsage else { return }
        usageTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.pollUsage() } }
        pollUsage()
    }
    private func pollUsage() {
        // Not while saving: Default Folder X is being quit and reopened.
        guard !polling, !busy, let id = DFX.running?.bundleIdentifier else { return }
        polling = true
        pollQueue.async { [weak self] in
            let result = DFXEvents.poll(id)
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.received(result) } }
        }
    }
    private func received(_ result: Result<(open: Bool, folder: String?, top: String?), DFXEvents.Failure>) {
        polling = false
        guard usageTimer != nil else { return }
        switch result {
        case .success(let look):
            for path in counter.step(dialogOpen: look.open, currentFolder: look.folder, recentTop: look.top) {
                usageCounts[FolderKey.of(path), default: 0] += 1
            }
        case .failure(.notPermitted):
            usageTimer?.invalidate(); usageTimer = nil; automationDenied = true
        case .failure:
            counter = UsageCounter()   // Default Folder X quit or did not answer; start over without counting a jump
        }
    }
    func resetCounts() { usageCounts = [:]; status = L("countsResetAll") }
    /// Resets the counts of the selected favorites (or just `id` when it is not part of the selection).
    func resetCounts(of id: UUID) {
        let ids = selection.contains(id) ? selection : [id]
        let keys = items.filter { ids.contains($0.id) && !$0.isSeparator }.map { FolderKey.of($0.path) }
        for key in keys { usageCounts[key] = nil }
        status = String(format: L("countsReset"), keys.count)
    }
    /// Asks, then clears every count on this Mac.
    func confirmResetAllCounts() {
        let alert = NSAlert(); alert.messageText = L("resetCountsTitle"); alert.informativeText = L("resetCountsDetail")
        alert.addButton(withTitle: L("resetCountsButton")); alert.addButton(withTitle: L("cancel"))
        alert.buttons[1].keyEquivalent = "\u{1b}"
        if alert.runModal() == .alertFirstButtonReturn { resetCounts() }
    }

    // Files and size per folder, counted in the background after each load (two folders at a time).
    /// Columns switched with the checkboxes above the list (kept per Mac).
    @Published var showFullPath = UserDefaults.standard.object(forKey: "showFullPath") as? Bool ?? true { didSet { defaults.set(showFullPath, forKey: "showFullPath") } }
    /// Settings › General: paths inside Dropbox start at the Dropbox folder (on by default, as before 1.3.0).
    @Published var shortDropboxPaths = UserDefaults.standard.object(forKey: "shortDropboxPaths") as? Bool ?? true {
        didSet { defaults.set(shortDropboxPaths, forKey: "shortDropboxPaths") }
    }
    @Published var showNotes = UserDefaults.standard.object(forKey: "showNotes") as? Bool ?? true { didSet { defaults.set(showNotes, forKey: "showNotes") } }
    @Published var showCounts = UserDefaults.standard.object(forKey: "showCounts") as? Bool ?? true { didSet { defaults.set(showCounts, forKey: "showCounts") } }
    @Published var showFileCount = UserDefaults.standard.object(forKey: "showFileCount") as? Bool ?? true {
        didSet { defaults.set(showFileCount, forKey: "showFileCount"); if showFileCount != oldValue && !(showSize) { refreshStats() } }
    }
    @Published var showSize = UserDefaults.standard.object(forKey: "showSize") as? Bool ?? true {
        didSet { defaults.set(showSize, forKey: "showSize"); if showSize != oldValue && !(showFileCount) { refreshStats() } }
    }
    /// Files and size are counted only while one of them is shown.
    var showStats: Bool { showFileCount || showSize }
    @Published var stats: [String: FolderStats] = [:]
    private var statsGeneration = 0
    private let statsQueue: OperationQueue = { let q = OperationQueue(); q.maxConcurrentOperationCount = 2; q.qualityOfService = .utility; return q }()
    func refreshStats() {
        statsGeneration += 1; stats = [:]; statsQueue.cancelAllOperations()
        guard showStats else { return }
        let generation = statsGeneration
        for path in Set(items.filter { !$0.isSeparator && $0.exists }.map(\.path)) {
            let operation = BlockOperation()
            operation.addExecutionBlock { [weak self, weak operation] in
                let result = FolderStats.measure(URL(fileURLWithPath: path, isDirectory: true)) { operation?.isCancelled ?? true }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard let self, generation == self.statsGeneration, let result else { return }
                        self.stats[FolderKey.of(path)] = result
                    }
                }
            }
            statsQueue.addOperation(operation)
        }
    }
    let undoManager = UndoManager()
    /// The file as it was read, to notice changes made in Default Folder X before saving.
    private var loadedFingerprint: [String] = []
    var fileURL: URL { DFX.favoritesURL(set: setName) }
    var categories: [Category] { Favorites.categories(items) }
    /// True for the favorite right before a separator.
    func endsCategory(_ id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }), index + 1 < items.count else { return false }
        return items[index + 1].isSeparator
    }

    func load() {
        let found = DFX.folderSets()
        sets = found.sets
        if setName.isEmpty || !sets.contains(setName) { setName = found.current ?? sets.first ?? "" }
        dfxFound = DFX.appURL != nil
        staysSorted = DFX.staysSorted
        guard !setName.isEmpty else { items = []; status = L("noSet"); return }
        do {
            items = try Favorites.read(fileURL)
            loadedFingerprint = Favorites.fingerprint(items)
            selection = []; isDirty = false; undoManager.removeAllActions()
            status = String(format: L("loaded"), items.filter { !$0.isSeparator }.count, categories.count)
            refreshStats()
        } catch {
            items = []; loadedFingerprint = []
            status = String(format: L("readFailed"), fileURL.path)
        }
    }

    /// Every edit goes through here so it can be undone (⌘Z) until it is saved.
    func apply(_ new: [FavoriteItem], _ action: String) {
        // Default Folder X writes its own copy when it quits, so edits wait until it has been quit.
        guard DFX.running == nil else { quitDFXBeforeEditing { self.apply(new, action) }; return }
        let old = items
        undoManager.registerUndo(withTarget: self) { $0.apply(old, action) }
        undoManager.setActionName(action)
        items = new
        isDirty = Favorites.fingerprint(items) != loadedFingerprint
    }

    func name(for key: String) -> String { categoryNames["\(setName)|\(key)"] ?? "" }
    func setName(_ text: String, for key: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        categoryNames["\(setName)|\(key)"] = trimmed.isEmpty ? nil : trimmed
    }
    func displayName(for key: String) -> String {
        let name = name(for: key)
        if !name.isEmpty { return name }
        return key == "top" ? L("firstCategory") : L("unnamedCategory")
    }

    var selectedCategoryKeys: Set<String> {
        Set(categories.filter { category in
            items[category.range].contains { selection.contains($0.id) } || category.separatorIndex.map { selection.contains(items[$0].id) } ?? false
        }.map(\.key))
    }
    func sort(_ order: SortOrder) {
        let keys = selection.isEmpty ? nil : selectedCategoryKeys
        apply(Favorites.sorted(items, by: order, only: keys, usage: usageCounts), L("sortAction"))
        status = keys == nil ? String(format: L("sortedAll"), L("sort.\(order.rawValue)")) : String(format: L("sortedSelected"), L("sort.\(order.rawValue)"), keys!.count)
    }
    /// Adds a separator after the last selected row, or at the end.
    func addSeparator() {
        let index = items.lastIndex { selection.contains($0.id) }.map { $0 + 1 } ?? items.count
        var new = items; let separator = FavoriteItem.separator()
        new.insert(separator, at: index)
        apply(new, L("addSeparator"))
        selection = [separator.id]
        status = L("separatorAdded")
    }
    func move(from source: IndexSet, to destination: Int) {
        var new = items; new.move(fromOffsets: source, toOffset: destination)
        apply(new, L("moveAction"))
    }
    func moveSelection(to key: String) {
        guard !selection.isEmpty else { return }
        apply(Favorites.moving(selection, to: key, in: items), L("moveAction"))
        status = String(format: L("movedTo"), displayName(for: key))
    }
    func moveCategory(_ key: String, by offset: Int) {
        apply(Favorites.movingCategory(key, by: offset, in: items), L("moveCategory"))
    }
    func deleteSelection() {
        guard !selection.isEmpty else { return }
        let count = items.filter { selection.contains($0.id) }.count
        apply(items.filter { !selection.contains($0.id) }, L("deleteAction"))
        selection = []
        status = String(format: L("deleted"), count)
    }
    func delete(_ id: UUID) { selection = [id]; deleteSelection() }

    /// The favorite whose hotkey sheet is open.
    @Published var editingHotkey: EditTarget?
    struct EditTarget: Identifiable { let id: UUID }
    func editHotkey(_ id: UUID? = nil) {
        guard let id = id ?? (selection.count == 1 ? selection.first : nil), items.first(where: { $0.id == id })?.isSeparator == false else { return }
        guard DFX.running == nil else { quitDFXBeforeEditing { self.editingHotkey = EditTarget(id: id) }; return }
        editingHotkey = EditTarget(id: id)
    }
    /// Asks to quit Default Folder X, then runs `edit` once it has quit. Cancel leaves everything as it was.
    func quitDFXBeforeEditing(then edit: @escaping () -> Void) {
        guard !busy else { return }
        let alert = NSAlert(); alert.messageText = L("editQuitTitle"); alert.informativeText = L("editQuitDetail")
        alert.addButton(withTitle: L("quitAndEdit")); alert.addButton(withTitle: L("cancel"))
        alert.buttons[1].keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { status = L("editCanceled"); return }
        Task { await toggleDFX(); if DFX.running == nil { edit() } }
    }
    func combo(for id: UUID) -> KeyCombo? { items.first { $0.id == id }?.hotkey.map { KeyCombo(code: $0.code, flags: $0.flags) } }
    func setCombo(_ combo: KeyCombo?, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var new = items
        if let combo { new[index].setHotkey(code: Int(combo.code), flags: combo.eventFlags) } else { new[index].clearHotkey() }
        apply(new, L("hotkeyAction"))
        status = combo.map { String(format: L("hotkeyChanged"), new[index].name, $0.label) } ?? String(format: L("hotkeyCleared"), new[index].name)
    }
    /// The other favorites' hotkeys, so the same key is not given twice.
    func otherHotkeys(except id: UUID) -> [(String, KeyCombo)] {
        items.compactMap { item in item.id == id ? nil : item.hotkey.map { (item.name, KeyCombo(code: $0.code, flags: $0.flags)) } }
    }

    @Published var dfxRunning = DFX.running != nil
    /// Set when Default Folder X was quit with the button here, so saving and quitting this app open it again.
    var dfxQuitHere = false
    private var workspaceObservers: [Any] = []
    func watchDFX() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, DFX.bundleIDs.contains(app.bundleIdentifier ?? "") else { return }
                MainActor.assumeIsolated { self?.dfxRunning = DFX.running != nil; if self?.dfxRunning == true { self?.dfxQuitHere = false } }
            })
        }
    }
    func toggleDFX() async {
        guard !busy else { return }
        busy = true; defer { busy = false; dfxRunning = DFX.running != nil }
        if let running = DFX.running {
            guard await DFX.quit(running) else { status = L("quitFailed2"); return }
            dfxQuitHere = true
            status = L("dfxQuit")
        } else if let url = DFX.appURL {
            status = await DFX.launch(url) ? L("dfxLaunched") : L("relaunchFailed")
        }
    }

    /// Quits Default Folder X (it writes its favorites when quitting), checks the file was not changed there,
    /// backs it up, writes the new order and opens Default Folder X again. Returns true when written.
    @discardableResult
    func save() async -> Bool {
        guard !busy, !setName.isEmpty else { return false }
        busy = true; defer { busy = false }
        // Also reopen it when it was quit with the button here.
        let running = DFX.running, appURL = running?.bundleURL ?? (dfxQuitHere ? DFX.appURL : nil)
        if let running {
            status = L("quittingDFX")
            guard await DFX.quit(running) else { status = L("quitFailed"); return false }
        }
        func relaunch() async { if let appURL, !(await DFX.launch(appURL)) { status += " " + L("relaunchFailed") } }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            guard let current = try? Favorites.read(fileURL) else { status = String(format: L("readFailed"), fileURL.path); await relaunch(); return false }
            if Favorites.fingerprint(current) != loadedFingerprint {
                status = L("changedOutside"); await relaunch(); return false
            }
            do { try Backups.save(fileURL, set: setName) } catch { status = L("backupFailed"); await relaunch(); return false }
        }
        do {
            try Favorites.data(items).write(to: fileURL, options: .atomic)
        } catch {
            status = String(format: L("writeFailed"), error.localizedDescription); await relaunch(); return false
        }
        loadedFingerprint = Favorites.fingerprint(items); isDirty = false
        status = appURL == nil ? L("savedNoDFX") : L("saved")
        await relaunch()
        dfxQuitHere = false; dfxRunning = DFX.running != nil
        return true
    }
}

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

/// A category heading. The name is edited in a sheet (pencil, double-click or the shortcut menu): a text field inside a
/// selectable, draggable List row loses clicks to selection and dragging, and saving on every keystroke redraws the list.
struct CategoryHeader: View {
    @ObservedObject var model: Model
    let category: Category
    var body: some View {
        let name = model.name(for: category.key)
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal").foregroundColor(appTint).accessibilityHidden(true)
            Text(name.isEmpty ? model.displayName(for: category.key) : name)
                .font(.system(size: 13, weight: .semibold)).foregroundColor(name.isEmpty ? .secondary : .primary).lineLimit(1)
            Button { model.renamingCategory = CategoryTarget(id: category.key) } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless).foregroundColor(.secondary).help(L("renameCategory")).accessibilityLabel(L("renameCategory"))
            Spacer()
            Text(String(format: L("itemCount"), category.range.count)).font(.caption).foregroundColor(.secondary)
        }
        .padding(.top, category.separatorIndex == nil ? 0 : 10).padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { model.renamingCategory = CategoryTarget(id: category.key) }
        .help(L("categoryHint"))
        .contextMenu {
            Button(L("renameCategory")) { model.renamingCategory = CategoryTarget(id: category.key) }
            if category.separatorIndex != nil {
                Divider()
                Button(L("moveCategoryUp")) { model.moveCategory(category.key, by: -1) }
                Button(L("moveCategoryDown")) { model.moveCategory(category.key, by: 1) }
                Divider()
                Button(L("deleteSeparator")) { if let index = category.separatorIndex { model.delete(model.items[index].id) } }
            }
        }
    }
}

struct FavoriteRow: View {
    @ObservedObject var model: Model
    let item: FavoriteItem
    /// The last favorite before a category heading. A List row line belongs to the row above it, so this row's line
    /// is the one above the next heading; it starts at the left edge (over the ≡ icon) to set the categories apart.
    var endsCategory = false
    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.exists ? item.path : "/System")).resizable().frame(width: 18, height: 18).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.name).lineLimit(1)
                    if item.dropboxRoot != nil { DropboxMark() }
                }
                // The row line starts here for every row (a note's text otherwise moved it).
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                if model.showFullPath {
                    Text(item.shownPath(shortDropbox: model.shortDropboxPaths)).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle).help(item.path)
                }
                let note = model.note(for: item)
                if model.showNotes && !note.isEmpty {
                    Text(note).font(.caption).foregroundColor(appTint).lineLimit(2)
                        .help(note).accessibilityLabel(String(format: L("noteLabel"), note))
                }
            }
            Spacer(minLength: 8)
            if !item.exists {
                Label(L("missing"), systemImage: "exclamationmark.triangle.fill").labelStyle(.iconOnly).foregroundColor(.orange)
                    .help(L("missing")).accessibilityLabel(L("missing"))
            }
            if model.showStats && item.exists {
                let stats = model.stats[FolderKey.of(item.path)]
                HStack(spacing: 8) {
                    if model.showFileCount { Text(stats.map { $0.filesText } ?? L("statsCounting")).frame(minWidth: 64, alignment: .trailing) }
                    if model.showSize { Text(stats.map { $0.sizeText } ?? (model.showFileCount ? "" : L("statsCounting"))).frame(minWidth: 64, alignment: .trailing) }
                }
                .font(.caption).monospacedDigit().foregroundColor(.secondary).fixedSize()
            }
            if model.showsCounts {
                Text(String(format: L("countText"), model.count(for: item))).font(.caption).monospacedDigit().foregroundColor(.secondary)
                    .frame(minWidth: 40, alignment: .trailing).help(L("countHint"))
                    .accessibilityLabel(String(format: L("countLabel"), model.count(for: item)))
            }
            // Click to change; a faint dash marks a favorite without a hotkey.
            Button { model.editHotkey(item.id) } label: {
                Text(item.hotkeyText.isEmpty ? "—" : item.hotkeyText).font(.callout).foregroundColor(.secondary).frame(minWidth: 36, alignment: .trailing)
            }
            .buttonStyle(.borderless).fixedSize().help(L("hotkeyChange"))
            .accessibilityLabel(item.hotkeyText.isEmpty ? L("hotkeyChange") : String(format: L("hotkeyLabel"), item.hotkeyText))
        }
        .padding(.leading, 22).padding(.vertical, 1)
        .alignmentGuide(.listRowSeparatorLeading) { endsCategory ? 0 : $0[.listRowSeparatorLeading] }
        .contextMenu {
            Button(L("noteEdit")) { model.editNote(item.id) }
            Button(L("resetItemCount")) { model.resetCounts(of: item.id) }.disabled(model.count(for: item) == 0 && !model.selection.contains(item.id))
            Button(L("hotkeyChange")) { model.editHotkey(item.id) }
            Divider()
            Button(L("revealInFinder")) { if let url = item.fileURL { NSWorkspace.shared.activateFileViewerSelecting([url]) } }.disabled(!item.exists)
            Button(L("copyPath")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(item.path, forType: .string) }
            Menu(L("moveTo")) {
                ForEach(model.categories) { category in
                    Button(model.displayName(for: category.key)) {
                        if !model.selection.contains(item.id) { model.selection = [item.id] }
                        model.moveSelection(to: category.key)
                    }
                }
            }
            Divider()
            Button(L("removeFavorite")) { model.delete(item.id) }
        }
    }
}

/// Sheet for one favorite's hotkey, with the shared recorder (⌘ or ⌃ required, duplicates among favorites refused).
struct HotkeyEditor: View {
    @ObservedObject var model: Model
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: L("hotkeyFor"), model.items.first { $0.id == id }?.name ?? "")).font(.headline)
            HotkeyField(id: "favorite-\(id)", combo: Binding(get: { model.combo(for: id) }, set: { model.setCombo($0, for: id) }),
                        allowsClear: true, others: model.otherHotkeys(except: id))
            Text(model.dfxRunning ? L("hotkeyNoteRunning") : L("hotkeyNote")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                if model.dfxRunning {
                    Button(L("quitDFX")) { Task { await model.toggleDFX() } }.disabled(model.busy)
                }
                Spacer()
                Button(L("done")) { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 460)
        .onExitCommand { dismiss() }
        .onDisappear { HotkeyRecorder.shared.stop() }
    }
}

extension KeyCombo {
    /// Default Folder X stores NSEvent modifier flags; KeyCombo keeps Carbon modifiers.
    init(code: Int, flags: NSEvent.ModifierFlags) {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= KeyCombo.command }
        if flags.contains(.shift) { m |= KeyCombo.shift }
        if flags.contains(.option) { m |= KeyCombo.option }
        if flags.contains(.control) { m |= KeyCombo.control }
        self.init(code: UInt32(code), modifiers: m)
    }
    var eventFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & KeyCombo.command != 0 { flags.insert(.command) }
        if modifiers & KeyCombo.shift != 0 { flags.insert(.shift) }
        if modifiers & KeyCombo.option != 0 { flags.insert(.option) }
        if modifiers & KeyCombo.control != 0 { flags.insert(.control) }
        return flags
    }
}

/// Mark for favorites inside a Dropbox folder (the path next to it is relative to that folder).
struct DropboxMark: View {
    var body: some View {
        Text("Dropbox").font(.system(size: 9, weight: .semibold)).foregroundColor(.white)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(Capsule().fill(Color(nsColor: NSColor(srgbRed: 0, green: 0.38, blue: 1, alpha: 1))))
            .fixedSize().accessibilityLabel(L("inDropbox"))
    }
}

struct SearchField: View {
    @ObservedObject var model: Model
    @FocusState private var focused: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary).accessibilityHidden(true)
            TextField(L("searchPlaceholder"), text: $model.query).textFieldStyle(.plain).focused($focused)
                .onExitCommand { model.query = "" }
                .accessibilityLabel(L("searchLabel"))
            if model.isSearching {
                Text(String(format: L("searchCount"), model.items.filter { $0.matches(model.query, note: model.note(for: $0)) }.count)).font(.caption).foregroundColor(.secondary).fixedSize()
                Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                    .buttonStyle(.borderless).accessibilityLabel(L("clearSearch")).help(L("clearSearch"))
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(focused ? appTint : Color.gray.opacity(0.3)))
        .onChange(of: model.searchFocusRequest) { _ in focused = true }
    }
}

struct CategoryTarget: Identifiable { let id: String }

/// Sheet for a category name. Saved only with Done, so typing does not redraw the list.
struct CategoryNameEditor: View {
    @ObservedObject var model: Model
    let key: String
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("renameCategoryTitle")).font(.headline)
            TextField(key == "top" ? L("firstCategory") : L("unnamedCategory"), text: $text).textFieldStyle(.roundedBorder)
                .accessibilityLabel(L("categoryNameLabel"))
            Text(L("categoryHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("done")) { model.setName(text, for: key); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 400)
        .onAppear { text = model.name(for: key) }
    }
}

/// Sheet for one favorite's note. Notes stay in this app (not in Favorites.plist) and are found by the search field.
struct NoteEditor: View {
    @ObservedObject var model: Model
    let id: UUID
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss
    private var item: FavoriteItem? { model.items.first { $0.id == id } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: L("noteFor"), item?.name ?? "")).font(.headline)
            TextField(L("notePlaceholder"), text: $text, axis: .vertical).lineLimit(3...8).textFieldStyle(.roundedBorder)
            Text(L("noteHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("done")) { if let item { model.setNote(text, for: item) }; dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 460)
        .onAppear { text = item.map { model.note(for: $0) } ?? "" }
    }
}

/// Checkboxes above the list: which details each row shows.
struct ColumnToggles: View {
    @ObservedObject var model: Model
    var body: some View {
        HStack(spacing: 14) {
            Text(L("showLabel")).foregroundColor(.secondary)
            Toggle(L("colFullPath"), isOn: $model.showFullPath)
            Toggle(L("colNotes"), isOn: $model.showNotes)
            Toggle(L("colCounts"), isOn: $model.showCounts).help(model.trackUsage ? "" : L("countsOffHint"))
            Toggle(L("colFiles"), isOn: $model.showFileCount).help(L("showStatsDetail"))
            Toggle(L("colSize"), isOn: $model.showSize).help(L("showStatsDetail"))
            Spacer(minLength: 0)
        }
        .toggleStyle(.checkbox).font(.callout)
    }
}

struct SortMenu: View {
    @ObservedObject var model: Model
    var body: some View {
        Menu {
            Section(model.selection.isEmpty ? L("sortScopeAll") : L("sortScopeSelected")) {
                ForEach(SortOrder.allCases, id: \.self) { order in Button(L("sort.\(order.rawValue)")) { model.sort(order) } }
            }
        } label: { Label(L("sortMenu"), systemImage: "arrow.up.arrow.down") }
        .fixedSize().disabled(model.items.isEmpty || model.busy)
    }
}

struct MainView: View {
    @ObservedObject var model: Model
    var save: () -> Void
    var reload: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 4) { Text(L("heading")).font(.system(size: 22, weight: .semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
            }
            SearchField(model: model)
            ColumnToggles(model: model)
            HStack(spacing: 8) {
                if model.sets.count > 1 {
                    Picker(L("folderSet"), selection: $model.setName) { ForEach(model.sets, id: \.self) { Text($0).tag($0) } }
                        .fixedSize().disabled(model.isDirty || model.busy).help(model.isDirty ? L("setLocked") : "")
                } else {
                    Text(String(format: L("folderSetFixed"), model.setName)).foregroundColor(.secondary).lineLimit(1).truncationMode(.tail).layoutPriority(-1)
                }
                Spacer(minLength: 8)
                Button { model.showingKeyboard = true } label: { Label(L("keyboardButton"), systemImage: "keyboard").labelStyle(.iconOnly) }
                    .help(L("keyboardTitle")).accessibilityLabel(L("keyboardTitle")).disabled(model.items.isEmpty).fixedSize()
                SortMenu(model: model)
                Button { model.addSeparator() } label: { Label(L("addSeparator"), systemImage: "minus") }.disabled(model.busy).fixedSize()
                Menu {
                    ForEach(model.categories) { category in Button(model.displayName(for: category.key)) { model.moveSelection(to: category.key) } }
                } label: { Label(L("moveTo"), systemImage: "arrow.right.to.line") }
                .fixedSize().disabled(model.selection.isEmpty || model.busy)
            }
            if model.staysSorted {
                Label(L("staysSortedWarning"), systemImage: "exclamationmark.triangle").font(.callout).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if !model.dfxFound {
                Label(L("dfxNotFound"), systemImage: "exclamationmark.triangle").font(.callout).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true)
            }
            List(selection: $model.selection) {
                if model.isSearching {
                    ForEach(model.items.filter { $0.matches(model.query, note: model.note(for: $0)) }) { item in FavoriteRow(model: model, item: item).tag(item.id) }
                } else {
                    if let first = model.categories.first { CategoryHeader(model: model, category: first).headerNotSelectable() }
                    ForEach(model.items) { item in
                        Group {
                            if item.isSeparator, let category = model.categories.first(where: { $0.separatorIndex.map { model.items[$0].id } == item.id }) {
                                CategoryHeader(model: model, category: category)
                            } else {
                                FavoriteRow(model: model, item: item, endsCategory: model.endsCategory(item.id))
                            }
                        }.tag(item.id)
                    }
                    .onMove { model.move(from: $0, to: $1) }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .onDeleteCommand { model.deleteSelection() }
            .cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.25)))
            .disabled(model.busy)
            HStack(alignment: .center, spacing: 12) {
                Text(model.status.isEmpty ? " " : model.status).font(.callout).foregroundColor(.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if model.busy { ProgressView().controlSize(.small) }
                Button(model.dfxRunning ? L("quitDFX") : L("launchDFX")) { Task { await model.toggleDFX() } }
                    .disabled(model.busy || !model.dfxFound).help(model.dfxRunning ? L("quitDFXHint") : "")
                Button(L("reload"), action: reload).disabled(model.busy)
                Button(L("save"), action: save).buttonStyle(.borderedProminent).disabled(!model.isDirty || model.busy)
            }
        }
        .padding(20)
        .sheet(item: $model.editingHotkey) { HotkeyEditor(model: model, id: $0.id) }
        .background(EmptyView().sheet(item: $model.editingNote) { NoteEditor(model: model, id: $0.id) })
        .background(EmptyView().sheet(isPresented: $model.showingKeyboard) { KeyboardMapView(model: model) })
        .background(EmptyView().sheet(item: $model.renamingCategory) { CategoryNameEditor(model: model, key: $0.id) })
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
        .background(Color(nsColor: AppSurface.color)).tint(appTint)
    }
}

extension View {
    /// `.selectionDisabled()` exists from macOS 14; on 13 the header simply stays selectable.
    @ViewBuilder func headerNotSelectable() -> some View {
        if #available(macOS 14, *) { self.selectionDisabled(true) } else { self }
    }
}

struct SettingsView: View {
    @ObservedObject var model: Model
    @AppStorage("resident") var resident = true
    var body: some View {
        SettingsTabs(sections: [(SettingsUI.launchTitle, AnyView(VStack(spacing: 16) {
            SettingsSection(SettingsUI.launchTitle) {
                LaunchPresenceSection(title: SettingsUI.launchTitle, loginControl: LoginAtLaunchView(), residentTitle: L("resident"), residentDetail: L("residentDetail"), resident: $resident,
                                      presenceExtra: MenuBarPresenceView(), shortcutTitle: L("launchShortcut"), shortcutButton: L("openShortcuts"), shortcutDetail: L("shortcutDetail")) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                }
            }
        })), (L("generalTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("displayGroup")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("shortDropbox"), isOn: $model.shortDropboxPaths)
                    Text(L("shortDropboxDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("usageGroup")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("trackUsage"), isOn: $model.trackUsage)
                    Text(L("trackUsageDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    if model.automationDenied {
                        Label(L("automationDenied"), systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack {
                        if model.automationDenied {
                            Button(L("openAutomation")) {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
                            }
                            Button(L("retry")) { model.updateTracking() }
                        }
                        Spacer()
                        Button(L("resetCounts")) { model.confirmResetAllCounts() }.disabled(model.usageCounts.isEmpty)
                    }.padding(.top, 4)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("saveGroup")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("confirmBeforeSave"), isOn: $model.confirmBeforeSave)
                    Text(L("confirmBeforeSaveDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text(String(format: L("backupDetail"), Backups.limit)).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button(L("openBackups")) {
                            try? FileManager.default.createDirectory(at: Backups.folder, withIntermediateDirectories: true)
                            NSWorkspace.shared.open(Backups.folder)
                        }
                    }.padding(.top, 6)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())), (AboutSection.title, AnyView(AboutView()))]).frame(minWidth: 560, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
    }
}

@MainActor final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Model()
    var window: NSWindow!
    var settings: NSWindow?
    var helpWindow: NSWindow?
    var isDuplicate = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        UserDefaults.standard.register(defaults: ["resident": true])
        if let id = Bundle.main.bundleIdentifier, let other = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            isDuplicate = true
            other.activate(options: [.activateAllWindows])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        guard !isDuplicate else { return }
        buildMenus()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 720), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "FavoriteFolders"; window.titleVisibility = .hidden
        let hosting = NSHostingView(rootView: MainView(model: model, save: { [weak self] in self?.save() }, reload: { [weak self] in self?.reload() })); hosting.sizingOptions = [.minSize]
        window.contentView = hosting; window.contentMinSize = NSSize(width: 560, height: 520)
        window.delegate = self; window.isReleasedWhenClosed = false
        if UserDefaults.standard.string(forKey: "NSWindow Frame MainWindow") == nil { window.center() }  // First launch: no saved frame yet.
        window.setFrameAutosaveName("MainWindow")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        Backups.migrate()
        model.load()
        model.watchDFX()
        model.updateTracking()
        MenuBarPresence.shared.install(name: "FavoriteFolders", symbol: "folder.badge.gearshape", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() })
        SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings() }
        SettingsSync.shared.start(.init(keys: Model.sharedKeys, prefixes: [],
            note: StartupWindow.text("カテゴリの名前と「保存の前に確認する」の選択を書き出し・同期します。",
                                     "Exports and syncs category names and the Confirm before saving choice.",
                                     "导出并同步类别名称和“保存前确认”的选择。",
                                     "카테고리 이름과 '저장하기 전에 확인' 선택을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・常駐・メニューバーの表示はMacごとに設定します。",
                                       "Open at login, keep running and the menu bar icon are set on each Mac.",
                                       "登录时启动、保持运行和菜单栏图标在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 계속 실행, 메뉴 막대 아이콘은 Mac마다 설정합니다.")))
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !login && !StartupWindow.suppressInitialWindow { show() }
    }
    @objc func show() { guard let window else { return }; NSApp.activate(ignoringOtherApps: true); if window.isMiniaturized { window.deminiaturize(nil) }; window.makeKeyAndOrderFront(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        StartupWindow.userRequestedWindow(); show(); return true }
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? { window === self.window ? model.undoManager : nil }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === window && !UserDefaults.standard.bool(forKey: "resident") { NSApp.terminate(nil); return false }
        return true
    }
    /// Unsaved changes: save (quits and reopens Default Folder X), discard, or stay.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model.busy { show(); alert(L("busyQuit"), L("busyQuitDetail"), [L("ok")]); return .terminateCancel }
        guard model.isDirty else { return reopenDFXThenQuit() }
        show()
        switch alert(L("unsavedTitle"), L("unsavedDetail"), [L("save"), L("cancel"), L("dontSave")]) {
        case .alertFirstButtonReturn:
            Task { let saved = await model.save(); NSApp.reply(toApplicationShouldTerminate: saved) }
            return .terminateLater
        case .alertThirdButtonReturn: return reopenDFXThenQuit()
        default: return .terminateCancel
        }
    }
    /// Default Folder X quit from here (button or the edit check) is opened again before this app quits.
    /// The open has to finish first: started from applicationWillTerminate, it was lost when the process exited.
    private func reopenDFXThenQuit() -> NSApplication.TerminateReply {
        guard model.dfxQuitHere, DFX.running == nil, let url = DFX.appURL else { return .terminateNow }
        Task { _ = await DFX.launch(url); NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
    @discardableResult
    func alert(_ title: String, _ detail: String, _ buttons: [String], suppression: Bool = false) -> NSApplication.ModalResponse {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = detail
        for button in buttons { alert.addButton(withTitle: button) }
        // The second button is Cancel in every multi-button alert here, so Esc cancels.
        if buttons.count > 1 { alert.buttons[1].keyEquivalent = "\u{1b}" }
        return alert.runModal()
    }
    @objc func save() {
        guard model.isDirty, !model.busy else { return }
        if model.confirmBeforeSave && DFX.running != nil {
            guard alert(L("confirmSaveTitle"), L("confirmSaveDetail"), [L("save"), L("cancel")]) == .alertFirstButtonReturn else { return }
        }
        Task { await model.save() }
    }
    @objc func reload() {
        if model.isDirty, alert(L("reloadTitle"), L("reloadDetail"), [L("reload"), L("cancel")]) != .alertFirstButtonReturn { return }
        model.load()
    }
    @objc func addSeparator() { model.addSeparator() }
    @objc func editHotkey() { model.editHotkey() }
    @objc func editNote() { model.editNote() }
    @objc func showKeyboard() { show(); model.showingKeyboard = true }
    @objc func resetAllCounts() { show(); model.confirmResetAllCounts() }
    @objc func focusSearch() { show(); model.searchFocusRequest += 1 }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func showSettings() {
        if settings == nil {
            settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            let hosting = NSHostingView(rootView: SettingsView(model: model)); hosting.sizingOptions = [.minSize]
            settings!.title = L("settingsWindow"); settings!.contentView = hosting; settings!.contentMinSize = NSSize(width: 560, height: 520); settings!.isReleasedWhenClosed = false; settings!.center()
        }
        settings!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let text = Bundle.main.url(forResource: "Help", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? L("help")
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "FavoriteFolders")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "FavoriteFolders", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String, _ modifiers: NSEvent.ModifierFlags = .command) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key); item.target = self; item.keyEquivalentModifierMask = modifiers
    }
    func buildMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        let app = NSMenu(); let root = NSMenuItem(); root.submenu = app; bar.addItem(root)
        add(app, L("about"), #selector(about), ""); app.addItem(.separator())
        add(app, L("settings"), #selector(showSettings), ","); app.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to: app)   // 「アップデートを確認…」「アップデートを自動確認」 + separator
        #endif
        let services = NSMenu(title: L("services")); app.addItem(withTitle: L("services"), action: nil, keyEquivalent: "").submenu = services; NSApp.servicesMenu = services
        app.addItem(.separator())
        app.addItem(withTitle: L("hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: L("hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: L("showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator()); add(app, L("quit"), #selector(quit), "q")
        let file = NSMenu(title: L("fileMenu")); let fileItem = NSMenuItem(title: L("fileMenu"), action: nil, keyEquivalent: ""); fileItem.submenu = file; bar.addItem(fileItem)
        add(file, L("openMainWindow"), #selector(show), "0"); file.addItem(.separator())
        add(file, L("saveMenu"), #selector(save), "s")
        add(file, L("reload"), #selector(reload), "r")
        file.addItem(.separator())
        add(file, L("addSeparator"), #selector(addSeparator), "n", [.command, .shift])
        add(file, L("hotkeyChange"), #selector(editHotkey), "k")
        add(file, L("noteEdit"), #selector(editNote), "i")
        add(file, L("keyboardMenu"), #selector(showKeyboard), "k", [.command, .shift])
        add(file, L("resetAllCountsMenu"), #selector(resetAllCounts), "")
        file.addItem(.separator())
        file.addItem(withTitle: L("close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let edit = NSMenu(title: L("editMenu")); let editItem = NSMenuItem(title: L("editMenu"), action: nil, keyEquivalent: ""); editItem.submenu = edit; bar.addItem(editItem)
        for (key, action, shortcut) in [("undo", "undo:", "z"), ("redo", "redo:", "z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("paste", "paste:", "v"), ("delete", "delete:", ""), ("selectAll", "selectAll:", "a")] {
            edit.addItem(withTitle: L(key), action: Selector(action), keyEquivalent: shortcut)
        }
        edit.item(at: 1)?.keyEquivalentModifierMask = [.command, .shift]   // やり直す ⇧⌘Z
        edit.addItem(.separator()); add(edit, L("findMenu"), #selector(focusSearch), "f")
        let windowMenu = NSMenu(title: L("windowMenu")); let windowItem = NSMenuItem(title: L("windowMenu"), action: nil, keyEquivalent: ""); windowItem.submenu = windowMenu; bar.addItem(windowItem)
        windowMenu.addItem(withTitle: L("minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: L("zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: L("bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
        let help = NSMenu(title: L("helpMenu")); let helpItem = NSMenuItem(title: L("helpMenu"), action: nil, keyEquivalent: ""); helpItem.submenu = help; bar.addItem(helpItem)
        add(help, L("help"), #selector(showHelp), "?"); HelpLinks.addNoteItem(to: help); NSApp.helpMenu = help
    }
}

extension Delegate: NSMenuItemValidation {
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(save): return model.isDirty && !model.busy
        case #selector(reload), #selector(addSeparator): return !model.busy
        case #selector(resetAllCounts): return !model.usageCounts.isEmpty
        case #selector(editNote): return model.selection.count == 1 && model.items.contains { model.selection.contains($0.id) && !$0.isSeparator }
        case #selector(editHotkey): return !model.busy && model.selection.count == 1 && model.items.contains { model.selection.contains($0.id) && !$0.isSeparator }
        default: return true
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
MainActor.assumeIsolated {
    let delegate = Delegate(); app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
