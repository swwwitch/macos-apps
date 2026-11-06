import AppKit
import SwiftUI

/// One row of the match list.
struct MatchRow: Identifiable, Equatable {
    let match: Match
    let paragraph: Int
    let context: MatchContext
    var isExcluded: Bool
    /// The keyword this row becomes with 「すべてを統一」, when it is one of the rows to replace.
    var unifiesTo: String?
    var id: String { match.id }
}

/// Settings kept between launches.
private enum Key {
    static let variantRules = "variantRules", ignoredGroups = "ignoredGroups", variantFilter = "variantFilter", variantSort = "variantSort"
    static let useDictionary = "useVariantDictionary", userDictionary = "userDictionary"
    static let keywords = "keywords", unifyTarget = "unifyTarget", caseSensitive = "caseSensitive", wholeWord = "wholeWord"
    static let excludeContained = "excludeContained", withinParagraph = "withinParagraph", contextLength = "contextLength"
}

@MainActor final class AppModel: ObservableObject {
    static let fieldCount = 5
    static let maxContext = 20
    static let sharedKeys = [Key.variantRules, Key.ignoredGroups, Key.useDictionary, Key.userDictionary, Key.caseSensitive, Key.wholeWord, Key.excludeContained, Key.withinParagraph, Key.contextLength]

    private let defaults = UserDefaults.standard

    // Conditions. Changing one of the first group makes the last search out of date.
    @Published var keywords: [String] { didSet { if keywords != oldValue { defaults.set(keywords, forKey: Key.keywords); markStale() } } }
    @Published var caseSensitive: Bool { didSet { defaults.set(caseSensitive, forKey: Key.caseSensitive); markStale() } }
    @Published var wholeWord: Bool { didSet { defaults.set(wholeWord, forKey: Key.wholeWord); markStale() } }
    @Published var excludeContained: Bool { didSet { defaults.set(excludeContained, forKey: Key.excludeContained); markStale() } }
    // Display. These only rebuild the list.
    @Published var unifyTarget: Int { didSet { defaults.set(unifyTarget, forKey: Key.unifyTarget); rebuildRows() } }
    @Published var withinParagraph: Bool { didSet { defaults.set(withinParagraph, forKey: Key.withinParagraph); rebuildRows() } }
    @Published var contextLength: Int { didSet { defaults.set(contextLength, forKey: Key.contextLength); rebuildRows() } }

    @Published private(set) var target: TargetInfo?
    /// 「対象アプリを固定」: the document stays the target while other apps are used. Not kept between launches: a window cannot be found again.
    @Published var isTargetPinned = false { didSet { if !isTargetPinned { refreshTarget() } } }
    @Published private(set) var targetIcon: NSImage?
    @Published private(set) var targetProblem: String?
    @Published private(set) var trusted = AXIsProcessTrusted()
    @Published private(set) var rows: [MatchRow] = []
    @Published private(set) var counts: [String]
    @Published private(set) var totalText = L("status.initial")
    @Published private(set) var note = ""
    @Published private(set) var isStale = false
    @Published private(set) var isBusy = false
    @Published private(set) var progressText = ""
    @Published private(set) var variantGroups: [VariantGroup] = []
    /// Group id → the spelling chosen when it was last unified.
    @Published private(set) var variantRules: [String: String]
    /// Group id → how the group read when it was set aside.
    @Published private(set) var ignoredGroups: [String: String]
    /// nil shows every kind.
    @Published var variantFilter: VariantGroup.Kind? { didSet { defaults.set(variantFilter?.rawValue ?? "", forKey: Key.variantFilter) } }
    @Published var showsRareFirst: Bool { didSet { defaults.set(showsRareFirst, forKey: Key.variantSort) } }
    @Published private(set) var selectedGroup: VariantGroup.ID?
    @Published private(set) var hasCollected = false
    @Published var selection: MatchRow.ID? { didSet { if selection != oldValue { selectionChanged() } } }
    @Published var changeTo = ""
    /// The field typed in last, where 「選択文字を取り込む」 puts the text.
    var lastActiveField: Int?

    private var currentTarget: TextTarget?
    /// The document the current results came from. Offsets mean nothing in any other document.
    private var searchedTarget: TextTarget?
    private var lastApp: NSRunningApplication?
    private var lastText = ""
    /// The text and document the variant list came from.
    private var variantSource: (text: String, target: TextTarget?)?
    private var lastKeywords: [String] = []
    private var matches: [[Match]]?
    private var excluded = ExclusionList()
    private var refreshGeneration = 0
    private let cancelRequested = Locked(false)
    private var isRebuilding = false
    /// Tells whether the window is on screen, so nothing is looked up while it is hidden.
    var isWindowVisible: () -> Bool = { false }

    init() {
        let stored = defaults.stringArray(forKey: Key.keywords) ?? []
        keywords = (0..<Self.fieldCount).map { $0 < stored.count ? stored[$0] : "" }
        func flag(_ key: String, _ initial: Bool) -> Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? initial }
        caseSensitive = flag(Key.caseSensitive, false)
        wholeWord = flag(Key.wholeWord, false)
        excludeContained = flag(Key.excludeContained, true)
        withinParagraph = flag(Key.withinParagraph, true)
        contextLength = min(Self.maxContext, max(0, UserDefaults.standard.object(forKey: Key.contextLength) as? Int ?? 3))
        unifyTarget = UserDefaults.standard.object(forKey: Key.unifyTarget) as? Int ?? -1
        counts = Array(repeating: L("status.initial"), count: Self.fieldCount)
        variantRules = UserDefaults.standard.dictionary(forKey: Key.variantRules) as? [String: String] ?? [:]
        ignoredGroups = UserDefaults.standard.dictionary(forKey: Key.ignoredGroups) as? [String: String] ?? [:]
        variantFilter = VariantGroup.Kind(rawValue: UserDefaults.standard.string(forKey: Key.variantFilter) ?? "")
        showsRareFirst = UserDefaults.standard.bool(forKey: Key.variantSort)
    }

    func reloadSharedSettings() {
        variantRules = defaults.dictionary(forKey: Key.variantRules) as? [String: String] ?? variantRules
        ignoredGroups = defaults.dictionary(forKey: Key.ignoredGroups) as? [String: String] ?? ignoredGroups
        func flag(_ key: String, _ current: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? current }
        caseSensitive = flag(Key.caseSensitive, caseSensitive)
        wholeWord = flag(Key.wholeWord, wholeWord)
        excludeContained = flag(Key.excludeContained, excludeContained)
        withinParagraph = flag(Key.withinParagraph, withinParagraph)
        contextLength = min(Self.maxContext, max(0, defaults.object(forKey: Key.contextLength) as? Int ?? contextLength))
    }

    var hasKeyword: Bool { keywords.contains { !$0.isEmpty } }
    var canReplace: Bool { matches != nil && !isStale && !isBusy }
    var canUnify: Bool { canReplace && lastKeywords.indices.contains(unifyTarget) && !lastKeywords[unifyTarget].isEmpty }
    var selectedRow: MatchRow? { rows.first { $0.id == selection } }
    var showsOnSelect: Bool { currentTarget?.showsInBackground ?? false }
    var isGoogleDocs: Bool { target?.kind == .googleDocs }

    // MARK: Target

    /// Called when another app comes to the front. An app without readable text leaves the last document in place.
    func noteActivated(_ app: NSRunningApplication) {
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        lastApp = app
        refreshTarget()
    }
    func noteTerminated(_ app: NSRunningApplication) {
        if lastApp == app { lastApp = nil }
        if target?.pid == app.processIdentifier { isTargetPinned = false; setTarget(nil) }
    }

    func refreshTrust() { trusted = AXIsProcessTrusted() }

    func refreshTarget() {
        refreshTrust()
        guard !isBusy, !isTargetPinned, isWindowVisible(), trusted, let app = lastApp else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        DispatchQueue.global(qos: .userInitiated).async {
            let resolved = TargetDetector.resolve(app)
            let name = app.localizedName ?? ""
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.refreshGeneration, !self.isBusy else { return }
                if let resolved { self.setTarget(resolved) }
                else if self.target == nil { self.targetProblem = String(format: L("target.unsupported"), name) }
            }
        }
    }

    private func setTarget(_ newTarget: TextTarget?) {
        if newTarget?.info != target {
            target = newTarget?.info
            targetIcon = newTarget.flatMap { NSRunningApplication(processIdentifier: $0.info.pid)?.icon }
        }
        currentTarget = newTarget
        if newTarget != nil { targetProblem = nil }
        if let searchedTarget, let newTarget, !newTarget.isSameDocument(as: searchedTarget) { markStale() }
    }

    /// The running app of the current document, otherwise the app used last.
    private var appForLookup: NSRunningApplication? {
        target.flatMap { NSRunningApplication(processIdentifier: $0.pid) } ?? lastApp
    }

    // MARK: Running work off the main thread

    /// `sameDocument` is for work on the search results: it refuses to run on any other document.
    private func run<T>(sameDocument: Bool = false, _ work: @escaping (TextTarget) throws -> T, done: @escaping (Result<T, Error>) -> Void) {
        guard !isBusy else { return }
        refreshTrust()
        guard trusted else { note = L("error.notTrusted"); return }
        refreshGeneration += 1
        isBusy = true
        cancelRequested.value = false
        // A pinned target is used as it is: looking it up again would take whatever window is in front.
        let app = isTargetPinned ? nil : appForLookup
        let previous = currentTarget
        let searched = sameDocument ? searchedTarget : nil
        Task.detached(priority: .userInitiated) {
            // Look again: the document may have changed since the target was shown.
            let resolved = app.flatMap { TargetDetector.resolve($0) } ?? previous
            let result: Result<T, Error>
            if let searched, let resolved, !resolved.isSameDocument(as: searched) { result = .failure(TargetError.documentChanged) }
            else if let resolved { result = Result { try work(resolved) } }
            else { result = .failure(TargetError.noText) }
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let resolved { self.setTarget(resolved) }
                self.isBusy = false
                self.progressText = ""
                done(result)
            }
        }
    }

    func cancel() { cancelRequested.value = true }

    // MARK: Find

    func find() {
        guard hasKeyword, !isBusy else { return }
        let keywordsNow = keywords
        run({ try $0.readAll() }) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let text): self.show(text: text, keywords: keywordsNow)
            case .failure(let error):
                self.matches = nil
                self.rows = []
                self.counts = Array(repeating: L("status.initial"), count: Self.fieldCount)
                self.totalText = String(format: L("status.failed"), error.localizedDescription)
                self.note = ""
            }
        }
    }

    private func show(text: String, keywords searched: [String], from source: TextTarget? = nil) {
        if text != lastText && matches == nil { excluded.removeAll() }
        lastText = text
        lastKeywords = searched
        searchedTarget = source ?? currentTarget
        matches = Matcher.search(searched, in: text, options: SearchOptions(caseSensitive: caseSensitive, wholeWord: wholeWord, excludeContained: excludeContained))
        // Read earlier from another document than the one shown now: nothing may be replaced.
        if let searchedTarget, let currentTarget { isStale = !currentTarget.isSameDocument(as: searchedTarget) } else { isStale = false }
        note = ""
        selection = nil
        rebuildRows()
    }

    private func markStale() {
        guard matches != nil, !isStale else { return }
        isStale = true
        rebuildRows()
    }

    private func rebuildRows() {
        guard let matches else { return }
        isRebuilding = true
        defer { isRebuilding = false }
        let text = lastText as NSString
        let starts = Matcher.paragraphStarts(in: text)
        var built: [MatchRow] = []
        var excludedCount = 0
        var keptTotal = 0
        var newCounts = Array(repeating: L("status.initial"), count: Self.fieldCount)
        for (index, list) in matches.enumerated() {
            var kept = 0
            for match in list {
                let isExcluded = excluded.contains(match)
                if isExcluded { excludedCount += 1 } else { kept += 1 }
                built.append(MatchRow(match: match, paragraph: Matcher.paragraphNumber(of: match.range.location, starts: starts),
                                      context: Matcher.context(of: match.range, in: text, length: contextLength, withinParagraph: withinParagraph), isExcluded: isExcluded,
                                      unifiesTo: !isExcluded && isUnifyField(index) ? lastKeywords[unifyTarget] : nil))
            }
            keptTotal += kept
            if !lastKeywords[index].isEmpty { newCounts[index] = String(format: L("status.count"), kept) }
        }
        rows = built
        counts = newCounts
        let scope = searchedTarget?.info.appName ?? ""
        totalText = excludedCount > 0 ? String(format: L("status.totalWithExcluded"), keptTotal, scope, excludedCount) : String(format: L("status.total"), keptTotal, scope)
        listNote = isStale ? L("status.stale") : ""
        if let selection, !rows.contains(where: { $0.id == selection }) { self.selection = nil }
    }
    @Published private(set) var listNote = ""

    private func isUnifyField(_ index: Int) -> Bool {
        guard lastKeywords.indices.contains(unifyTarget), !lastKeywords[unifyTarget].isEmpty else { return false }
        return index != unifyTarget && lastKeywords[index] != lastKeywords[unifyTarget]
    }

    // MARK: List

    private func selectionChanged() {
        guard !isRebuilding else { return }
        guard let row = selectedRow else { return }
        changeTo = row.match.text
        if showsOnSelect { showSelected() }
    }

    /// Selects the row's text in the document. From a Docs window this takes the browser to the front for a moment.
    func showSelected() {
        guard let row = selectedRow, matches != nil, !isStale, !isBusy else { return }
        let keyword = lastKeywords[row.match.keywordIndex]
        let text = lastText
        run(sameDocument: true, { try $0.show(row.match, keyword: keyword, in: text) }) { [weak self] result in
            if case .failure(let error) = result { self?.note = error.localizedDescription }
        }
    }

    func setExcluded(_ id: MatchRow.ID, _ value: Bool) {
        guard let match = rows.first(where: { $0.id == id })?.match else { return }
        excluded.set(match, excluded: value)
        rebuildRows()
    }
    func toggleSelectedExcluded() {
        guard let row = selectedRow else { return }
        setExcluded(row.id, !row.isExcluded)
    }

    // MARK: Replace

    /// The checked matches of the fields other than the unify target.
    var unifyMatches: [Match] {
        guard let matches, canUnify else { return [] }
        return matches.enumerated().flatMap { index, list -> [Match] in
            isUnifyField(index) ? list.filter { !excluded.contains($0) } : []
        }
    }
    var unifyKeyword: String { lastKeywords.indices.contains(unifyTarget) ? lastKeywords[unifyTarget] : "" }

    func noteNothingToReplace() { note = L("status.nothingToReplace") }

    func unify() {
        let targets = unifyMatches
        guard !targets.isEmpty else { noteNothingToReplace(); return }
        let replacement = unifyKeyword
        rememberRule(replacement)
        replace(targets, with: replacement) { String(format: L("status.unified"), $0.replaced.count, replacement) }
    }

    func changeSelected() {
        guard canReplace, let row = selectedRow, changeTo != row.match.text else { return }
        let replacement = changeTo
        let before = row.match.text
        // Continue at the row that takes this one's place among the same keyword.
        let keyword = row.match.keywordIndex
        let offset = rows.filter { $0.match.keywordIndex == keyword }.firstIndex { $0.id == row.id } ?? 0
        replace([row.match], with: replacement, then: { [weak self] in
            guard let self else { return }
            let same = self.rows.filter { $0.match.keywordIndex == keyword }
            if !same.isEmpty { self.selection = same[min(offset, same.count - 1)].id }
        }) { $0.replaced.isEmpty ? L("status.nothingToReplace") : String(format: L("status.changed"), before, replacement) }
    }

    private func replace(_ targets: [Match], with replacement: String, then: (() -> Void)? = nil, message: @escaping (ReplaceOutcome) -> String) {
        let plan = Matcher.replacementPlan(targets)
        let keywordsNow = lastKeywords
        let text = lastText
        let total = plan.ordered.count
        let cancelled = cancelRequested
        progressText = String(format: L("status.progress"), 0, total)
        run(sameDocument: true, { target -> (ReplaceOutcome, String?) in
            let outcome = target.replace(plan.ordered, keywords: keywordsNow, with: replacement, in: text, progress: { step in
                DispatchQueue.main.async { [weak self] in self?.progressText = String(format: L("status.progress"), step + 1, total) }
            }, isCancelled: { cancelled.value })
            // Accessibility text is read again; Docs would lose the cursor, so its known result is used instead.
            let reread = outcome.text == nil ? try? target.readAll() : nil
            return (outcome, outcome.text ?? reread)
        }) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error): self.note = error.localizedDescription
            case .success(let (outcome, newText)):
                self.excluded.shift(after: outcome.replaced, replacementLength: (replacement as NSString).length)
                if let newText {
                    self.show(text: newText, keywords: keywordsNow)
                    if self.hasCollected {
                        self.variantGroups = VariantFinder.groups(in: newText, dictionary: self.activeDictionary)
                        self.variantSource = (newText, self.searchedTarget)
                        if !self.variantGroups.contains(where: { $0.id == self.selectedGroup }) { self.selectedGroup = nil }
                    }
                }
                var notes = [message(outcome)]
                let skipped = outcome.skipped + plan.overlapped
                if skipped > 0 { notes.append(String(format: L("status.skipped"), skipped)) }
                if let reason = outcome.stopReason { notes.append(reason) }
                if outcome.usedBulkReplace { notes.append(L("status.bulk")) }
                if !outcome.isReliable || newText == nil { self.isStale = true; notes.append(L("status.findAgain")); self.rebuildRows() }
                self.note = notes.joined(separator: " / ")
                then?()
            }
        }
    }

    // MARK: Keywords

    func clearKeyword(_ index: Int) { keywords[index] = ""; lastActiveField = index }

    /// Option-click on a × empties every field.
    func clearAllKeywords() {
        keywords = Array(repeating: "", count: Self.fieldCount)
        lastActiveField = nil
        selectedGroup = nil
    }

    private var insertField: Int {
        if let lastActiveField { return lastActiveField }
        return keywords.firstIndex(of: "") ?? 0
    }

    /// 「選択文字を取り込む」: one line of selected text goes into the field typed in last, or the first empty one.
    func loadSelection() {
        run({ try $0.selectedText() }) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let text):
                if text.isEmpty || text.contains(where: \.isNewline) { self.note = L("status.noSelection") }
                else { self.keywords[self.insertField] = text }
            case .failure(let error): self.note = error.localizedDescription
            }
        }
    }

    // MARK: Variants

    /// 「揺れ候補を拾う」: reads the whole document and lists the words written in more than one way.
    func collectVariants() {
        guard !isBusy else { return }
        let dictionary = activeDictionary
        run({ target -> (String, [VariantGroup]) in
            let text = try target.readAll()
            return (text, VariantFinder.groups(in: text, dictionary: dictionary))
        }) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error): self.note = error.localizedDescription
            case .success(let (text, groups)):
                self.variantGroups = groups
                self.selectedGroup = nil
                self.variantSource = (text, self.currentTarget)
                self.hasCollected = true
                let shown = self.visibleGroups.count
                self.note = shown == 0 ? L("status.noVariants") : String(format: L("status.variants"), shown)
            }
        }
    }

    private var activeDictionary: [DictionaryEntry] {
        let user = VariantDictionary.parse(defaults.string(forKey: Key.userDictionary) ?? "")
        return (defaults.object(forKey: Key.useDictionary) as? Bool ?? true) ? user + VariantDictionary.bundled : user
    }

    /// The list after the filter, without the groups set aside.
    var visibleGroups: [VariantGroup] {
        let shown = variantGroups.filter { ignoredGroups[$0.id] == nil && (variantFilter == nil || $0.kind == variantFilter) }
        return showsRareFirst ? shown.sorted { $0.total != $1.total ? $0.total < $1.total : $0.id < $1.id } : shown
    }

    /// The spelling a group is unified to first: the one chosen before, the dictionary's, then the most used.
    func preferredSpelling(of group: VariantGroup) -> String? {
        // A review group has no default: the word may be right where it stands.
        variantRules[group.id] ?? group.recommended ?? (group.kind == .review ? nil : group.spellings.first?.text)
    }

    /// Picking a group puts its spellings in the fields and shows their matches, from the text already read.
    func pickGroup(_ id: VariantGroup.ID?) {
        guard !isBusy, let id, let group = variantGroups.first(where: { $0.id == id }), let source = variantSource else { return }
        selectedGroup = id
        let preferred = preferredSpelling(of: group)
        // The target comes first, even when no text uses it yet.
        let ordered = (preferred.map { [$0] } ?? []) + group.spellings.map(\.text).filter { $0 != preferred }
        let spellings = Array(ordered.prefix(Self.fieldCount))
        let fields = spellings + Array(repeating: "", count: Self.fieldCount - spellings.count)
        // Apple and apple must be told apart, 「サーバ」 must not count again inside 「サーバー」, and 「事」 not inside 「仕事」.
        if Set(spellings.map { $0.lowercased() }).count < spellings.count { caseSensitive = true }
        excludeContained = true
        wholeWord = true
        keywords = fields
        lastActiveField = nil
        unifyTarget = preferred == nil ? -1 : 0
        show(text: source.text, keywords: fields, from: source.target)
        note = ordered.count > Self.fieldCount ? String(format: L("status.variantsMore"), Self.fieldCount, ordered.count - Self.fieldCount) : ""
    }

    /// Sets the selected group aside: it no longer appears in any document.
    func ignoreSelectedGroup() {
        guard let group = variantGroups.first(where: { $0.id == selectedGroup }) else { return }
        ignoredGroups[group.id] = group.label
        defaults.set(ignoredGroups, forKey: Key.ignoredGroups)
        selectedGroup = nil
    }
    func stopIgnoring(_ id: String) {
        ignoredGroups[id] = nil
        defaults.set(ignoredGroups, forKey: Key.ignoredGroups)
    }
    func forgetRule(_ id: String) {
        variantRules[id] = nil
        defaults.set(variantRules, forKey: Key.variantRules)
    }
    private func rememberRule(_ spelling: String) {
        guard let selectedGroup else { return }
        variantRules[selectedGroup] = spelling
        defaults.set(variantRules, forKey: Key.variantRules)
    }

    /// Copies the list shown as a table.
    func copyVariantTable() {
        let groups = visibleGroups
        let table = VariantExport.table(groups, header: [L("export.group"), L("export.spelling"), L("export.count"), L("export.target")], preferred: { [weak self] in self?.preferredSpelling(of: $0) })
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(table, forType: .string)
        note = String(format: L("status.copied"), groups.count)
    }

    /// When the window opens, text selected in a native app becomes a keyword, as when the script was run.
    func addSelectionIfQuiet() {
        guard let currentTarget, currentTarget.showsInBackground, !isBusy, let text = try? currentTarget.selectedText(),
              !text.isEmpty, !text.contains(where: \.isNewline), !keywords.contains(text), let empty = keywords.firstIndex(of: "") else { return }
        keywords[empty] = text
    }
}

/// A flag read by the worker and set from the main thread.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value
    init(_ value: Value) { stored = value }
    var value: Value {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); defer { lock.unlock() }; stored = newValue }
    }
}
