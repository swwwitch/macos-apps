import AppKit
import SwiftUI
import UniformTypeIdentifiers

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// The two lists and their comparison. Lists typed or pasted live only in memory; a list read from a file
/// stays linked to it and can be saved back.
@MainActor
final class Model: ObservableObject {
    enum Side { case left, right }
    /// The three result lists.
    enum Result { case leftOnly, common, rightOnly }

    @Published var leftText = "" { didSet { if leftText != oldValue { textChanged(.left) } } }
    @Published var rightText = "" { didSet { if rightText != oldValue { textChanged(.right) } } }
    /// The file each list was read from (dropped or opened) and is saved back to.
    @Published private(set) var leftFile: LinkedFile? { didSet { refreshDocumentEdited() } }
    @Published private(set) var rightFile: LinkedFile? { didSet { refreshDocumentEdited() } }
    /// Set while a file replaces a list, so loading does not count as an edit.
    private var loading = false
    @Published private(set) var result = ListComparison()
    /// The lists `result` was made from (dimming applies only while a list still matches).
    @Published private(set) var compared = (left: "", right: "")
    @Published private(set) var isComparing = false
    /// A short message in the status line (copied, could not open…); cleared by the next edit.
    @Published private(set) var notice: (text: String, failed: Bool)?

    private let defaults = UserDefaults.standard
    /// Stay running after the main window is closed. On by default.
    @Published var keepRunning: Bool { didSet { defaults.set(keepRunning, forKey: "keepRunning") } }
    /// Show the items that are in both lists in a lighter color. On by default.
    @Published var dimCommon: Bool { didSet { defaults.set(dimCommon, forKey: "dimCommon") } }
    @Published var ignoreCase: Bool { didSet { optionChanged("ignoreCase", ignoreCase) } }
    @Published var ignoreWidth: Bool { didSet { optionChanged("ignoreWidth", ignoreWidth) } }
    @Published var splitAtSpaces: Bool { didSet { separatorChanged("splitAtSpaces", splitAtSpaces) } }
    @Published var splitAtCommas: Bool { didSet { separatorChanged("splitAtCommas", splitAtCommas) } }
    @Published var splitAtTabs: Bool { didSet { separatorChanged("splitAtTabs", splitAtTabs) } }
    @Published var sortResults: Bool { didSet { optionChanged("sortResults", sortResults) } }
    /// メールアドレスのみ: compare the addresses found in the text instead of whole lines.
    /// Per list: compare one column of rows split at the separators (0 = every field), optionally without the header row.
    @Published var leftColumn: Int { didSet { defaults.set(leftColumn, forKey: "leftColumn"); scheduleCompare(delay: 0) } }
    @Published var rightColumn: Int { didSet { defaults.set(rightColumn, forKey: "rightColumn"); scheduleCompare(delay: 0) } }
    @Published var leftSkipHeader: Bool { didSet { optionChanged("leftSkipHeader", leftSkipHeader) } }
    @Published var rightSkipHeader: Bool { didSet { optionChanged("rightSkipHeader", rightSkipHeader) } }
    @Published var emailOnly: Bool { didSet { optionChanged("emailOnly", emailOnly); if !emailOnly { splitIntoLines(.left); splitIntoLines(.right) } } }

    private var pending: DispatchWorkItem?
    private var generation = 0

    init() {
        func flag(_ key: String, _ fallback: Bool) -> Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? fallback }
        keepRunning = flag("keepRunning", true)
        dimCommon = flag("dimCommon", true)
        ignoreCase = flag("ignoreCase", true)
        ignoreWidth = flag("ignoreWidth", false)
        // 1.0.0 had one switch for commas, semicolons and tabs; carry it over to commas and tabs.
        let legacySeparators = flag("splitAtSeparators", false)
        splitAtSpaces = flag("splitAtSpaces", false)
        splitAtCommas = flag("splitAtCommas", legacySeparators)
        splitAtTabs = flag("splitAtTabs", legacySeparators)
        sortResults = flag("sortResults", false)
        emailOnly = flag("emailOnly", false)
        leftColumn = UserDefaults.standard.integer(forKey: "leftColumn")
        rightColumn = UserDefaults.standard.integer(forKey: "rightColumn")
        leftSkipHeader = flag("leftSkipHeader", true)
        rightSkipHeader = flag("rightSkipHeader", true)
    }

    /// Keys shared by 設定の共有: the comparison options and per-list column choices. 常駐 and the lists stay per Mac.
    nonisolated static let sharedKeys: Set<String> = ["dimCommon", "ignoreCase", "ignoreWidth", "splitAtSpaces", "splitAtCommas", "splitAtTabs",
                                                      "sortResults", "emailOnly", "leftColumn", "rightColumn", "leftSkipHeader", "rightSkipHeader"]

    /// Re-reads the shared settings after an import so the next save does not write the old values back.
    /// Only changed values are assigned, so unchanged separators do not rewrite the lists.
    func reloadSharedSettings() {
        func flag(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }
        if case let v = flag("dimCommon", true), v != dimCommon { dimCommon = v }
        if case let v = flag("ignoreCase", true), v != ignoreCase { ignoreCase = v }
        if case let v = flag("ignoreWidth", false), v != ignoreWidth { ignoreWidth = v }
        if case let v = flag("sortResults", false), v != sortResults { sortResults = v }
        if case let v = defaults.integer(forKey: "leftColumn"), v != leftColumn { leftColumn = v }
        if case let v = defaults.integer(forKey: "rightColumn"), v != rightColumn { rightColumn = v }
        if case let v = flag("leftSkipHeader", true), v != leftSkipHeader { leftSkipHeader = v }
        if case let v = flag("rightSkipHeader", true), v != rightSkipHeader { rightSkipHeader = v }
        // Separators and the unit last: turning them on rewrites the lists one item per line, as when chosen by hand.
        if case let v = flag("emailOnly", false), v != emailOnly { emailOnly = v }
        if case let v = flag("splitAtSpaces", false), v != splitAtSpaces { splitAtSpaces = v }
        if case let v = flag("splitAtCommas", false), v != splitAtCommas { splitAtCommas = v }
        if case let v = flag("splitAtTabs", false), v != splitAtTabs { splitAtTabs = v }
    }

    var options: ListComparison.Options {
        ListComparison.Options(ignoreCase: ignoreCase, ignoreWidth: ignoreWidth, splitAtSpaces: splitAtSpaces, splitAtCommas: splitAtCommas, splitAtTabs: splitAtTabs, sortResults: sortResults, emailOnly: emailOnly)
    }
    /// The options for one list, with its column.
    func options(_ side: Side) -> ListComparison.Options {
        var options = self.options
        options.column = side == .left ? leftColumn : rightColumn
        options.skipHeader = side == .left ? leftSkipHeader : rightSkipHeader
        return options
    }
    var isEmpty: Bool { result.left.items.isEmpty && result.right.items.isEmpty }
    var hasText: Bool { !leftText.isEmpty || !rightText.isEmpty }

    /// Turning a separator on shows both lists one item per line.
    private func separatorChanged(_ key: String, _ value: Bool) {
        optionChanged(key, value)
        if value { splitIntoLines(.left); splitIntoLines(.right) }
    }

    /// Rewrites a list one item per line at the chosen separators (an edit: ⌘Z undoes it, a linked file shows 未保存).
    func splitIntoLines(_ side: Side) {
        guard let split = ListComparison.splitIntoLines(text(side), options(side)) else { return }
        if side == .left { leftText = split } else { rightText = split }
    }

    private func optionChanged(_ key: String, _ value: Bool) {
        defaults.set(value, forKey: key)
        scheduleCompare(delay: 0)
    }

    /// Compares after a short pause in typing, off the main thread; a newer edit discards an older result.
    func scheduleCompare(delay: Double = 0.15) {
        notice = nil
        lastMergedURL = nil
        pending?.cancel()
        generation += 1
        let generation = self.generation
        let left = leftText, right = rightText, leftOptions = options(.left), rightOptions = options(.right)
        isComparing = true
        let work = DispatchWorkItem {
            DispatchQueue.global(qos: .userInitiated).async {
                let result = ListComparison.compare(left, right, options: leftOptions, rightOptions: rightOptions)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard generation == self.generation else { return }
                        self.result = result
                        self.compared = (left, right)
                        self.isComparing = false
                    }
                }
            }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func items(_ kind: Result) -> [String] {
        switch kind {
        case .leftOnly: return result.leftOnly
        case .common: return result.common
        case .rightOnly: return result.rightOnly
        }
    }
    static func title(_ kind: Result) -> String {
        switch kind {
        case .leftOnly: return L("leftOnly")
        case .common: return L("commonItems")
        case .rightOnly: return L("rightOnly")
        }
    }

    func copy(_ kind: Result) {
        let items = items(kind)
        guard !items.isEmpty else { NSSound.beep(); notice = (L("nothingToCopy"), true); return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(items.joined(separator: "\n") + "\n", forType: .string)
        notice = (String(format: L("copiedResult"), Self.title(kind), items.count), false)
    }

    /// Saves one result list to a new UTF-8 text file, one item per line.
    func saveResult(_ kind: Result, from window: NSWindow?) {
        let items = items(kind)
        guard !items.isEmpty else { NSSound.beep(); notice = (L("nothingToSave"), true); return }
        let panel = NSSavePanel()
        panel.title = String(format: L("saveResultTitle"), Self.title(kind))
        panel.nameFieldStringValue = Self.title(kind) + ".txt"
        if let folder = (leftFile ?? rightFile)?.url.deletingLastPathComponent() { panel.directoryURL = folder }
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        let text = items.joined(separator: "\n") + "\n"
        let done: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            do {
                try ListFile.write(text, to: url, encoding: .utf8)
                self.notice = (String(format: L("statusResultSaved"), items.count, url.lastPathComponent), false)
                self.lastMergedURL = url
            } catch {
                NSSound.beep()
                self.notice = (String(format: L("errorSave"), error.localizedDescription), true)
            }
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: done) } else { done(panel.runModal()) }
    }

    /// 重複を削除: keeps the first of each item (⌘Z undoes it).
    func removeDuplicates(_ side: Side) {
        guard let cleaned = ListComparison.removingDuplicates(text(side), options(side)) else { NSSound.beep(); return }
        let before = side == .left ? result.left.duplicateCount : result.right.duplicateCount
        if side == .left { leftText = cleaned } else { rightText = cleaned }
        notice = (String(format: L("duplicatesRemoved"), before), false)
    }

    /// The list views, for showing where a result item is.
    weak var leftEditor: NSTextView?
    weak var rightEditor: NSTextView?

    /// Selects the item in the list(s) it comes from and scrolls to it.
    func reveal(_ item: String, from kind: Result) {
        let sides: [Side] = kind == .leftOnly ? [.left] : kind == .rightOnly ? [.right] : [.right, .left]
        for side in sides {
            guard let view = side == .left ? leftEditor : rightEditor,
                  let range = ListComparison.firstRange(of: item, in: view.string, options(side)) else { continue }
            view.window?.makeFirstResponder(view)
            view.setSelectedRange(range)
            view.scrollRangeToVisible(range)
            view.showFindIndicator(for: range)
        }
    }

    /// Files opened from Finder or the Dock: two go left and right; one goes to the empty side (left first).
    func openFiles(_ urls: [URL]) {
        let urls = urls.filter { !$0.hasDirectoryPath }
        guard let first = urls.first else { return }
        if urls.count >= 2 {
            load(first, into: .left); load(urls[1], into: .right)
        } else {
            load(first, into: !leftText.isEmpty && rightText.isEmpty ? .right : .left)
        }
    }

    /// 右のリストに追加 / 左のリストに追加: appends the items only on `side` to the other list (⌘Z undoes it).
    func addOnlyItems(from side: Side) {
        let items = side == .left ? result.leftOnly : result.rightOnly
        guard !items.isEmpty else { NSSound.beep(); return }
        let target = side == .left ? rightText : leftText
        let separator = target.isEmpty || target.hasSuffix("\n") || target.hasSuffix("\r") ? "" : "\n"
        let added = target + separator + items.joined(separator: "\n") + "\n"
        if side == .left { rightText = added } else { leftText = added }
        notice = (String(format: L(side == .left ? "addedToRight" : "addedToLeft"), items.count), false)
    }

    /// Empties both lists and unlinks their files (the files themselves are not touched).
    func clear() { leftFile = nil; rightFile = nil; leftText = ""; rightText = "" }

    func file(_ side: Side) -> LinkedFile? { side == .left ? leftFile : rightFile }
    private func setFile(_ file: LinkedFile?, _ side: Side) { if side == .left { leftFile = file } else { rightFile = file } }
    private func text(_ side: Side) -> String { side == .left ? leftText : rightText }
    var hasUnsavedFile: Bool { leftFile?.edited == true || rightFile?.edited == true }

    private func textChanged(_ side: Side) {
        if !loading, var file = file(side), !file.edited { file.edited = true; setFile(file, side) }
        scheduleCompare()
    }

    /// The close button's dot shows unsaved changes to a linked file.
    private func refreshDocumentEdited() { delegate.mainWindow?.isDocumentEdited = hasUnsavedFile }

    func load(_ url: URL, into side: Side) {
        // Replacing a linked list with unsaved changes loses them: ask first.
        if let current = file(side), current.edited {
            let alert = NSAlert()
            alert.messageText = String(format: L("replaceUnsavedTitle"), current.name)
            alert.informativeText = L("replaceUnsavedInfo")
            alert.addButton(withTitle: L("cancel"))
            alert.addButton(withTitle: L("replace"))
            alert.buttons[0].keyEquivalent = "\u{1b}"
            alert.buttons[1].keyEquivalent = ""
            guard alert.runModal() == .alertSecondButtonReturn else { return }
        }
        do {
            let (text, encoding) = try ListFile.read(url)
            loading = true
            if side == .left { leftText = text } else { rightText = text }
            loading = false
            setFile(LinkedFile(url: url, encoding: encoding, date: ListFile.modificationDate(url)), side)
            splitIntoLines(side)
        } catch {
            NSSound.beep()
            notice = (String(format: L("errorOpen"), url.lastPathComponent), true)
        }
    }

    func unlink(_ side: Side) {
        guard let file = file(side) else { return }
        setFile(nil, side)
        notice = (String(format: L("unlinked"), file.name), false)
    }

    /// Writes the list back to its file (same encoding; the previous version goes to the backup folder).
    func save(_ side: Side) {
        guard var file = file(side) else { NSSound.beep(); return }
        // Another app changed the file after it was read: ask before overwriting.
        if file.changedOnDisk {
            let alert = NSAlert()
            alert.messageText = String(format: L("changedTitle"), file.name)
            alert.informativeText = L("changedInfo")
            alert.addButton(withTitle: L("overwrite"))
            alert.addButton(withTitle: L("cancel"))
            alert.buttons[1].keyEquivalent = "\u{1b}"
            guard alert.runModal() == .alertFirstButtonReturn else { notice = (L("saveCancelled"), false); return }
        }
        do {
            file.encoding = try ListFile.write(text(side), to: file.url, encoding: file.encoding)
        } catch {
            NSSound.beep()
            notice = (String(format: L("errorSave"), error.localizedDescription), true)
            return
        }
        file.date = ListFile.modificationDate(file.url)
        file.edited = false
        setFile(file, side)
        notice = (String(format: L("statusSaved"), file.name), false)
    }

    /// マージして保存…: both lists together without repeats, one item per line, to a new UTF-8 file.
    func saveMerged(from window: NSWindow?) {
        let items = result.merged
        guard !items.isEmpty else { NSSound.beep(); notice = (L("nothingToMerge"), true); return }
        let panel = NSSavePanel()
        panel.title = L("mergeTitle")
        let base = leftFile.map { $0.url.deletingPathExtension().lastPathComponent + "-" + L("mergeSuffix") } ?? L("mergeFileName")
        let ext = leftFile.map { $0.url.pathExtension }.flatMap { $0.isEmpty ? nil : $0 } ?? "txt"
        panel.nameFieldStringValue = base + "." + ext
        if let folder = (leftFile ?? rightFile)?.url.deletingLastPathComponent() { panel.directoryURL = folder }
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        let text = items.joined(separator: "\n") + "\n"
        let done: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            do {
                // NSSavePanel already asked before replacing an existing file; it is still backed up.
                try ListFile.write(text, to: url, encoding: .utf8)
                self.notice = (String(format: L("statusMerged"), items.count, url.lastPathComponent), false)
                self.lastMergedURL = url
            } catch {
                NSSound.beep()
                self.notice = (String(format: L("errorSave"), error.localizedDescription), true)
            }
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: done) } else { done(panel.runModal()) }
    }
    /// The file the last merge was saved to (for Finderで表示 in the status line).
    @Published private(set) var lastMergedURL: URL?

    func open(_ side: Side, from window: NSWindow?) {
        let panel = NSOpenPanel()
        panel.title = L(side == .left ? "openLeftTitle" : "openRightTitle")
        panel.allowedContentTypes = [.plainText, .commaSeparatedText, .tabSeparatedText, .text]
        panel.allowsMultipleSelection = false
        let done: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.load(url, into: side)
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: done) } else { done(panel.runModal()) }
    }
}

struct Header: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView {
        let header = appHeader(L("headline"), subtitle: L("subtitle"))
        func unselectable(_ view: NSView) {
            if let field = view as? NSTextField { field.isSelectable = false; field.drawsBackground = false; field.refusesFirstResponder = true }
            view.subviews.forEach(unselectable)
        }
        unselectable(header)
        return header
    }
    func updateNSView(_ v: NSStackView, context: Context) {}
}

/// White rounded box shared by the list panes and the result panes.
struct Pane<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct InputPane: View {
    let title: String
    let label: String
    @Binding var text: String
    let side: ListComparison.Side
    let emailOnly: Bool
    let file: LinkedFile?
    let onFileDrop: (URL) -> Void
    let onPaste: () -> Void
    let dimmed: (text: String, ranges: [NSRange])
    let onCreate: (NSTextView) -> Void
    let removeDuplicates: () -> Void
    /// Column choice for this list; shown when separators are chosen (not in e-mail mode).
    let showsColumn: Bool
    @Binding var column: Int
    @Binding var skipHeader: Bool
    let save: () -> Void
    let unlink: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 4)
                Text(countText).font(.system(size: 11)).foregroundColor(.secondary).monospacedDigit().lineLimit(1)
                if side.duplicateCount > 0 {
                    Button(L("removeDuplicates"), action: removeDuplicates).controlSize(.small).fixedSize().help(L("removeDuplicatesHelp"))
                }
            }
            // Same height with or without the button, so the two lists line up.
            .frame(height: 22)
            if showsColumn {
                HStack(spacing: 10) {
                    Text(L("columnLabel")).foregroundColor(.secondary)
                    Picker(L("columnLabel"), selection: $column) {
                        Text(L("columnAll")).tag(0)
                        ForEach(1...10, id: \.self) { Text(String(format: L("columnNumber"), $0)).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .help(L("columnHelp"))
                    if column > 0 {
                        Toggle(L("skipHeader"), isOn: $skipHeader).toggleStyle(.checkbox)
                    }
                    Spacer(minLength: 0)
                }
                .controlSize(.small)
                .font(.system(size: 11))
                .frame(height: 20)
            }
            Pane {
                VStack(spacing: 0) {
                    if let file { linkedFileBar(file) }
                    ListEditor(text: $text, label: label, onFileDrop: onFileDrop, onPaste: onPaste, dimmed: dimmed, onCreate: onCreate)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text(L(emailOnly ? "inputPlaceholderEmail" : "inputPlaceholder")).font(.system(size: 12)).foregroundColor(.secondary)
                                    .padding(.horizontal, 11).padding(.vertical, 8).allowsHitTesting(false)
                            }
                        }
                }
            }
        }
    }

    /// The file the list was read from (as in MarkdownKitchen): name, folder, unsaved mark, save, Finder, unlink.
    private func linkedFileBar(_ file: LinkedFile) -> some View {
        let exists = file.exists
        let folder = (file.url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: exists ? file.url.path : "/System/Library/CoreServices/Finder.app"))
                    .resizable().frame(width: 18, height: 18).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(file.name).font(.system(size: 12, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                        if !exists {
                            Label(L("fileMissing"), systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundColor(.orange).lineLimit(1)
                        } else if file.edited {
                            Text(L("unsaved"))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(Color.orange.opacity(0.18)))
                                .foregroundColor(.orange)
                                .fixedSize()
                        }
                    }
                    Text(folder).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.head)
                }
                Spacer(minLength: 4)
                Button(L("saveButton"), action: save).disabled(!file.edited).help(L("saveHelp"))
                Button { NSWorkspace.shared.activateFileViewerSelecting([file.url]) } label: { Image(systemName: "magnifyingglass") }
                    .disabled(!exists).help(L("revealInFinder")).accessibilityLabel(L("revealInFinder"))
                Button(action: unlink) { Image(systemName: "xmark") }
                    .help(L("unlinkHelp")).accessibilityLabel(L("unlink"))
            }
            .controlSize(.small)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.08))
            .help(file.url.path)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(format: L("fileLabel"), file.name))
            Divider()
        }
    }
    var countText: String {
        var text = String(format: L(emailOnly ? "addressCount" : "itemCount"), side.items.count)
        if side.duplicateCount > 0 { text += " " + String(format: L("duplicateCount"), side.duplicateCount) }
        if side.skippedCount > 0 { text += " " + String(format: L(emailOnly ? "skippedCount" : "skippedColumnCount"), side.skippedCount) }
        return text
    }
}

struct ResultPane: View {
    let kind: Model.Result
    @ObservedObject var model: Model
    var body: some View {
        let items = model.items(kind)
        let title = Model.title(kind)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(String(format: L("itemCount"), items.count)).font(.system(size: 11)).foregroundColor(.secondary).monospacedDigit().fixedSize()
                Spacer(minLength: 4)
                Button(L("copyButton")) { model.copy(kind) }.controlSize(.small).disabled(items.isEmpty)
                    .help(String(format: L("copyResult"), title)).accessibilityLabel(String(format: L("copyResult"), title))
            }
            Pane {
                if items.isEmpty {
                    Text(L("noItems")).font(.system(size: 12)).foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ResultText(text: items.joined(separator: "\n"), label: title) { model.reveal($0, from: kind) }
                        .help(L("resultClickHelp"))
                }
            }
            HStack(spacing: 6) {
                Button(L("saveResultButton")) { model.saveResult(kind, from: delegate.mainWindow) }.controlSize(.small).disabled(items.isEmpty)
                    .help(String(format: L("saveResultHelp"), title)).accessibilityLabel(String(format: L("saveResult"), title))
                Spacer(minLength: 4)
                switch kind {
                case .leftOnly:
                    Button(L("addToRight")) { model.addOnlyItems(from: .left) }.controlSize(.small).disabled(items.isEmpty).help(L("addToRightHelp"))
                case .rightOnly:
                    Button(L("addToLeft")) { model.addOnlyItems(from: .right) }.controlSize(.small).disabled(items.isEmpty).help(L("addToLeftHelp"))
                case .common:
                    EmptyView()
                }
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Header().frame(height: 48)
            // How the lists are read: unit (lines / e-mail addresses) and separators, in one quiet row.
            // The column choice sits under each list's title, in the same small style.
            HStack(spacing: 10) {
                Text(L("modeLabel")).foregroundColor(.secondary)
                Picker(L("modeLabel"), selection: $model.emailOnly) {
                    Text(L("modeLines")).tag(false)
                    Text(L("modeEmail")).tag(true)
                }
                .labelsHidden()
                .fixedSize()
                .help(L("modeHelp"))
                .accessibilityLabel(L("modeLabel"))
                Divider().frame(height: 14)
                Group {
                    Text(L("separatorLabel")).foregroundColor(.secondary)
                    if model.emailOnly {
                        Text(L("separatorEmailNote")).foregroundColor(.secondary).lineLimit(1)
                    } else {
                        Toggle(L("splitAtSpaces"), isOn: $model.splitAtSpaces)
                        Toggle(L("splitAtCommas"), isOn: $model.splitAtCommas)
                        Toggle(L("splitAtTabs"), isOn: $model.splitAtTabs)
                    }
                }
                .help(L("separatorHelp"))
                Spacer(minLength: 0)
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .font(.system(size: 12))
            .accessibilityElement(children: .contain)
            // Drag the divider to give the lists or the results more room (remembered).
            SplitPanes(top: ListsArea(model: model), bottom: ResultsArea(model: model), autosaveName: "ListDiffSplit")
                .frame(maxHeight: .infinity)
            HStack {
                Button(L("settingsButton")) { delegate.showPreferences() }
                Spacer()
                Button(L("clear")) { model.clear() }.disabled(!model.hasText).help(L("clearHelp"))
                Button(L("mergeSave")) { model.saveMerged(from: delegate.mainWindow) }
                    .disabled(model.result.merged.isEmpty).help(L("mergeHelp"))
            }
        }
        .padding(20).frame(minWidth: 780, minHeight: 640).background(Color(nsColor: AppSurface.color))
    }

}

/// The two lists (upper part of the split).
struct ListsArea: View {
    @ObservedObject var model: Model
    var body: some View {
        HStack(spacing: 12) {
                InputPane(title: L("leftList"), label: L("leftListLabel"), text: $model.leftText, side: model.result.left, emailOnly: model.emailOnly, file: model.leftFile, onFileDrop: { model.load($0, into: .left) }, onPaste: { model.splitIntoLines(.left) }, dimmed: model.dimCommon ? (model.compared.left, model.result.left.commonRanges) : ("", []), onCreate: { model.leftEditor = $0 }, removeDuplicates: { model.removeDuplicates(.left) }, showsColumn: model.options.splitsAtAny && !model.emailOnly, column: $model.leftColumn, skipHeader: $model.leftSkipHeader, save: { model.save(.left) }, unlink: { model.unlink(.left) })
                InputPane(title: L("rightList"), label: L("rightListLabel"), text: $model.rightText, side: model.result.right, emailOnly: model.emailOnly, file: model.rightFile, onFileDrop: { model.load($0, into: .right) }, onPaste: { model.splitIntoLines(.right) }, dimmed: model.dimCommon ? (model.compared.right, model.result.right.commonRanges) : ("", []), onCreate: { model.rightEditor = $0 }, removeDuplicates: { model.removeDuplicates(.right) }, showsColumn: model.options.splitsAtAny && !model.emailOnly, column: $model.rightColumn, skipHeader: $model.rightSkipHeader, save: { model.save(.right) }, unlink: { model.unlink(.right) })
            }
        .padding(.bottom, 7)
    }
}

/// Status line and the three results (lower part of the split).
struct ResultsArea: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 6) {
                statusIcon
                Text(statusText).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                Spacer()
                if let url = model.lastMergedURL {
                    Button(L("revealInFinder")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }.controlSize(.small)
                }
            }
            .frame(minHeight: 18)
            HStack(spacing: 12) {
                ResultPane(kind: .leftOnly, model: model)
                ResultPane(kind: .common, model: model)
                ResultPane(kind: .rightOnly, model: model)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 7)
    }

    @ViewBuilder var statusIcon: some View {
        if let notice = model.notice {
            Image(systemName: notice.failed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill").foregroundColor(notice.failed ? .orange : .green)
        } else if model.isComparing && model.hasText {
            ProgressView().controlSize(.small)
        } else if !model.isEmpty && model.result.leftOnly.isEmpty && model.result.rightOnly.isEmpty {
            Image(systemName: "equal.circle.fill").foregroundColor(.green)
        } else if !model.isEmpty {
            Image(systemName: "info.circle").foregroundColor(.secondary)
        }
    }

    var statusText: String {
        if let notice = model.notice { return notice.text }
        if model.isEmpty { return model.hasText ? "" : L("statusEmpty") }
        let r = model.result
        if r.leftOnly.isEmpty && r.rightOnly.isEmpty { return String(format: L("statusSame"), r.commonCount) }
        return String(format: L("statusSummary"), r.commonCount, r.leftOnly.count, r.rightOnly.count)
    }
}

/// Two SwiftUI views stacked in an NSSplitView, so the boundary can be dragged; the position is remembered.
struct SplitPanes<Top: View, Bottom: View>: NSViewRepresentable {
    let top: Top
    let bottom: Bottom
    let autosaveName: String
    var topMinimum: CGFloat = 200
    var bottomMinimum: CGFloat = 170

    func makeCoordinator() -> Coordinator { Coordinator(topMinimum: topMinimum, bottomMinimum: bottomMinimum) }

    func makeNSView(context: Context) -> NSSplitView {
        let split = NSSplitView()
        split.isVertical = false
        split.dividerStyle = .thin
        split.delegate = context.coordinator
        for view in [AnyView(top), AnyView(bottom)] {
            let host = NSHostingView(rootView: view)
            host.sizingOptions = []
            split.addArrangedSubview(host)
        }
        // Window resizing grows both parts; the lists a little more.
        split.setHoldingPriority(NSLayoutConstraint.Priority(249), forSubviewAt: 0)
        split.setHoldingPriority(NSLayoutConstraint.Priority(250), forSubviewAt: 1)
        let saved = UserDefaults.standard.object(forKey: "NSSplitView Subview Frames " + autosaveName) != nil
        split.autosaveName = autosaveName
        if !saved {
            DispatchQueue.main.async { split.setPosition(max(split.bounds.height * 0.6, topMinimum), ofDividerAt: 0) }
        }
        split.setAccessibilityLabel(L("splitLabel"))
        return split
    }

    func updateNSView(_ split: NSSplitView, context: Context) {}

    final class Coordinator: NSObject, NSSplitViewDelegate {
        let topMinimum: CGFloat, bottomMinimum: CGFloat
        init(topMinimum: CGFloat, bottomMinimum: CGFloat) { self.topMinimum = topMinimum; self.bottomMinimum = bottomMinimum }
        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            max(proposedMinimumPosition, topMinimum)
        }
        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            min(proposedMaximumPosition, splitView.bounds.height - bottomMinimum)
        }
    }
}

struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) {
                    // LoginAtLaunchView already includes 起動時にメインウインドウを表示しない.
                    LoginAtLaunchView()
                    Toggle(L("keepRunning"), isOn: $model.keepRunning)
                    Text(L("keepRunningHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    MenuBarPresenceView()
                }
            })),
            (L("compareTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("matchSection")) {
                    Toggle(L("ignoreCase"), isOn: $model.ignoreCase)
                    Text(L("ignoreCaseHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Group {
                        Toggle(L("ignoreWidth"), isOn: $model.ignoreWidth)
                        Text(L("ignoreWidthHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .disabled(model.emailOnly)
                }
                if model.emailOnly {
                    Text(L("emailModeSettingsNote")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("displaySection")) {
                    Toggle(L("dimCommon"), isOn: $model.dimCommon)
                    Text(L("dimCommonHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("resultSection")) {
                    Toggle(L("sortResults"), isOn: $model.sortResults)
                    Text(L("sortResultsHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 440, maxHeight: .infinity)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    let model = MainActor.assumeIsolated { Model() }
    var mainWindow: NSWindow!
    var preferences: NSWindow?
    var helpWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "jp.dtp-transit.listdiff").sorted(by: { ($0.launchDate ?? .distantPast) == ($1.launchDate ?? .distantPast) ? $0.processIdentifier < $1.processIdentifier : ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }).first, other.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            other.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]); NSApp.terminate(nil); return
        }
        let loginLaunch = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        installMenus()
        mainWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        mainWindow.title = ""; mainWindow.titleVisibility = .hidden; mainWindow.isReleasedWhenClosed = false; mainWindow.delegate = self
        mainWindow.contentView = NSHostingView(rootView: ContentView(model: model)); mainWindow.minSize = NSSize(width: 780, height: 640)
        // Autosave names and the Bundle ID keep the former name (ListDiff) so positions and settings carry over.
        mainWindow.center(); mainWindow.setFrameAutosaveName("ListDiffMain")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(mainWindow.frame) }) { mainWindow.center() }
        MainActor.assumeIsolated {
            MenuBarPresence.shared.install(name: "ListMatch", symbol: "list.bullet.rectangle",
                show: { [weak self] in self?.showMain() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in self?.showHelp() })
        }
        SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings() }
        SettingsSync.shared.start(.init(keys: Model.sharedKeys, prefixes: [],
            note: StartupWindow.text("比較の設定（区切り文字・比較の単位・列・見出し行を含む）を書き出し・同期します。リストの内容は含みません。",
                                     "Exports and syncs the comparison settings, including separators, the comparison unit, columns and header rows. The lists are not included.",
                                     "导出并同步比较设置（包括分隔符、比较单位、列和标题行）。不包含列表内容。",
                                     "비교 설정(구분 문자, 비교 단위, 열, 머리글 행 포함)을 내보내고 동기화합니다. 목록 내용은 포함하지 않습니다."),
            perMac: StartupWindow.text("ログイン時の起動・常駐・メニューバーの表示はMacごとに設定します。",
                                       "Open at login, keep running and the menu bar icon are set on each Mac.",
                                       "登录时启动、保持运行和菜单栏图标在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 계속 실행, 메뉴 막대 아이콘은 Mac마다 설정합니다.")))
        if !loginLaunch && !StartupWindow.hidden { showMain() }
    }

    func installMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        func submenu(_ name: String) -> NSMenu { let item = NSMenuItem(); let menu = NSMenu(title: name); item.submenu = menu; bar.addItem(item); return menu }
        func add(_ m: NSMenu, _ title: String, _ sel: Selector, _ key: String = "", _ target: AnyObject? = nil) { let i = m.addItem(withTitle: title, action: sel, keyEquivalent: key); i.target = target ?? self }
        let app = submenu("ListMatch")
        add(app, L("about"), #selector(about)); app.addItem(.separator())
        // MenuBarPresence inserts メニューバー設定… at index 2, between these separators.
        add(app, L("settings"), #selector(showPreferences), ",")
        app.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        MainActor.assumeIsolated { AppUpdates.shared.addMenuItems(to: app) }
        #endif
        let services = NSMenu(title: L("services")); app.addItem(withTitle: L("services"), action: nil, keyEquivalent: "").submenu = services; NSApp.servicesMenu = services
        app.addItem(.separator())
        add(app, L("hideApp"), #selector(NSApplication.hide(_:)), "h", NSApp)
        add(app, L("hideOthers"), #selector(NSApplication.hideOtherApplications(_:)), "h", NSApp); app.items.last?.keyEquivalentModifierMask = [.command, .option]
        add(app, L("showAll"), #selector(NSApplication.unhideAllApplications(_:)), "", NSApp); app.addItem(.separator())
        add(app, L("quit"), #selector(NSApplication.terminate(_:)), "q", NSApp)
        let file = submenu(L("file"))
        add(file, L("openMainWindow"), #selector(showMain), "0")
        file.addItem(.separator())
        add(file, L("openLeft"), #selector(openLeft), "o")
        add(file, L("openRight"), #selector(openRight), "o"); file.items.last?.keyEquivalentModifierMask = [.command, .option]
        add(file, L("saveLeft"), #selector(saveLeft), "s")
        add(file, L("saveRight"), #selector(saveRight), "s"); file.items.last?.keyEquivalentModifierMask = [.command, .option]
        add(file, L("mergeSave"), #selector(saveMerged), "S")
        file.addItem(.separator())
        add(file, L("copyLeftOnly"), #selector(copyLeftOnly), "L")
        add(file, L("copyRightOnly"), #selector(copyRightOnly), "R")
        add(file, L("copyCommonMenu"), #selector(copyCommon))
        add(file, L("saveLeftOnlyMenu"), #selector(saveLeftOnly))
        add(file, L("saveCommonMenu"), #selector(saveCommon))
        add(file, L("saveRightOnlyMenu"), #selector(saveRightOnly))
        file.addItem(.separator())
        add(file, L("addToRightMenu"), #selector(addToRight))
        add(file, L("addToLeftMenu"), #selector(addToLeft))
        file.addItem(.separator())
        add(file, L("modeLinesMenu"), #selector(compareLines))
        add(file, L("modeEmailMenu"), #selector(compareEmail))
        file.addItem(.separator())
        add(file, L("dedupeLeftMenu"), #selector(dedupeLeft))
        add(file, L("dedupeRightMenu"), #selector(dedupeRight))
        add(file, L("clearMenu"), #selector(clearLists))
        file.addItem(.separator())
        add(file, L("close"), #selector(NSWindow.performClose(_:)), "w"); file.items.last?.target = nil
        let edit = submenu(L("edit"))
        for (key, selector, letter) in [("undo", "undo:", "z"), ("redo", "redo:", "Z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("paste", "paste:", "v"), ("selectAll", "selectAll:", "a")] { let i = edit.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: letter); i.target = nil; if key == "redo" { edit.addItem(.separator()) } }
        let window = submenu(L("window"))
        for (key, selector) in [("minimize", "performMiniaturize:"), ("zoom", "performZoom:")] { window.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: "").target = nil }
        window.addItem(.separator())
        window.addItem(withTitle: L("bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "").target = NSApp
        NSApp.windowsMenu = window
        let help = submenu(L("help")); add(help, L("helpItem"), #selector(showHelp), "?"); MainActor.assumeIsolated { HelpLinks.addNoteItem(to: help) }; NSApp.helpMenu = help
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        MainActor.assumeIsolated {
            switch item.action {
            case #selector(copyLeftOnly): return !model.result.leftOnly.isEmpty
            case #selector(copyRightOnly): return !model.result.rightOnly.isEmpty
            case #selector(clearLists): return model.hasText
            case #selector(saveLeft): return model.leftFile?.edited == true
            case #selector(saveRight): return model.rightFile?.edited == true
            case #selector(saveMerged): return !model.result.merged.isEmpty
            case #selector(addToRight): return !model.result.leftOnly.isEmpty
            case #selector(addToLeft), #selector(saveRightOnly): return !model.result.rightOnly.isEmpty
            case #selector(copyCommon), #selector(saveCommon): return !model.result.common.isEmpty
            case #selector(saveLeftOnly): return !model.result.leftOnly.isEmpty
            case #selector(dedupeLeft): return model.result.left.duplicateCount > 0
            case #selector(dedupeRight): return model.result.right.duplicateCount > 0
            case #selector(compareLines): item.state = model.emailOnly ? .off : .on; return true
            case #selector(compareEmail): item.state = model.emailOnly ? .on : .off; return true
            default: return true
            }
        }
    }

    @objc func showMain() { guard mainWindow != nil else { return }; NSApp.activate(ignoringOtherApps: true); mainWindow.makeKeyAndOrderFront(nil) }
    @objc func openLeft() { showMain(); MainActor.assumeIsolated { model.open(.left, from: mainWindow) } }
    @objc func openRight() { showMain(); MainActor.assumeIsolated { model.open(.right, from: mainWindow) } }
    @objc func copyLeftOnly() { MainActor.assumeIsolated { model.copy(.leftOnly) } }
    @objc func copyRightOnly() { MainActor.assumeIsolated { model.copy(.rightOnly) } }
    @objc func copyCommon() { MainActor.assumeIsolated { model.copy(.common) } }
    @objc func saveLeftOnly() { showMain(); MainActor.assumeIsolated { model.saveResult(.leftOnly, from: mainWindow) } }
    @objc func saveCommon() { showMain(); MainActor.assumeIsolated { model.saveResult(.common, from: mainWindow) } }
    @objc func saveRightOnly() { showMain(); MainActor.assumeIsolated { model.saveResult(.rightOnly, from: mainWindow) } }
    @objc func dedupeLeft() { MainActor.assumeIsolated { model.removeDuplicates(.left) } }
    @objc func dedupeRight() { MainActor.assumeIsolated { model.removeDuplicates(.right) } }
    /// Files dropped on the Dock icon or opened from Finder.
    func application(_ sender: NSApplication, open urls: [URL]) {
        showMain()
        MainActor.assumeIsolated { model.openFiles(urls) }
    }
    @objc func compareLines() { MainActor.assumeIsolated { model.emailOnly = false } }
    @objc func compareEmail() { MainActor.assumeIsolated { model.emailOnly = true } }
    @objc func saveLeft() { MainActor.assumeIsolated { model.save(.left) } }
    @objc func saveRight() { MainActor.assumeIsolated { model.save(.right) } }
    @objc func saveMerged() { showMain(); MainActor.assumeIsolated { model.saveMerged(from: mainWindow) } }
    @objc func addToRight() { MainActor.assumeIsolated { model.addOnlyItems(from: .left) } }
    @objc func addToLeft() { MainActor.assumeIsolated { model.addOnlyItems(from: .right) } }
    @objc func clearLists() { MainActor.assumeIsolated { model.clear() } }
    @objc func showPreferences() {
        if preferences == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 460), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            w.title = L("settingsTitle"); w.isReleasedWhenClosed = false
            let host = NSHostingView(rootView: Preferences(model: model))
            host.sizingOptions = [.minSize]
            w.contentView = host; w.center(); w.setFrameAutosaveName("ListDiffSettings")
            preferences = w
        }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
    }
    /// Unsaved changes to a linked file would be lost (the lists are not kept): ask first.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let names = MainActor.assumeIsolated { [model.leftFile, model.rightFile].compactMap { $0 }.filter(\.edited).map(\.name) }
        guard !names.isEmpty else { return .terminateNow }
        showMain()
        let alert = NSAlert()
        alert.messageText = L("quitUnsavedTitle")
        alert.informativeText = String(format: L("quitUnsavedInfo"), names.joined(separator: ", "))
        alert.addButton(withTitle: L("cancel"))
        alert.addButton(withTitle: L("quitAnyway"))
        alert.buttons[0].keyEquivalent = "\u{1b}"
        alert.buttons[1].keyEquivalent = ""
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMain(); return true }
    /// With 常駐 off, closing the main window quits.
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === mainWindow else { return }
        if !MainActor.assumeIsolated({ model.keepRunning }) { DispatchQueue.main.async { NSApp.terminate(nil) } }
    }
    @objc func showHelp() {
        if helpWindow == nil {
            helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: "ListMatch — " + L("help"), text: L("helpContent")) }
        }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options: [.credits: NSAttributedString(string: L("support"))]) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
