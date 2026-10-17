import AppKit
import UniformTypeIdentifiers

/// 原稿と見出しの状態。メインウインドウ・Dockアイコンへのドロップ・⌘Oで共有する
@MainActor
final class MarkdownStore: ObservableObject {
    static let shared = MarkdownStore()
    static let textKey = "markdownKitchen.sourceText"
    static let levelsKey = "markdownKitchen.levels"
    /// チェックボックスで選べる見出しレベル
    static let selectableLevels = Array(1...5)
    /// 抜き出すレベル。"135" のような数字の並びで保存する
    static func levels(from stored: String) -> Set<Int> { Set(stored.compactMap { $0.wholeNumberValue }) }
    static var storedLevels: Set<Int> { levels(from: UserDefaults.standard.string(forKey: levelsKey) ?? "12345") }
    static let copyFormatKey = "markdownKitchen.copyFormat"
    /// 左の原稿で見出しを太字で表示する（初期値オン）
    static let boldHeadingsKey = "markdownKitchen.boldHeadings"
    /// 原稿のMarkdownを色分けして表示する（初期値オン）
    static let colorizeKey = "markdownKitchen.colorize"
    /// 原稿欄の表示："rich"（MacDown風）・"color"（色分け）・"plain"（プレーン）
    static let editorStyleKey = "markdownKitchen.editorStyle"
    /// 原稿欄の配色："auto"（システムに合わせる）・"light"・"dark"
    static let editorAppearanceKey = "markdownKitchen.editorAppearance"
    /// 左右のペインの余白："narrow"・"standard"・"wide"
    static let marginKey = "markdownKitchen.margin"
    /// 原稿欄のフォント（PostScript名）。空なら標準
    static let editorFontKey = "markdownKitchen.editorFont"
    /// 原稿欄の行送り（行の高さの倍率）
    static let lineSpacingKey = "markdownKitchen.lineSpacing"
    static let defaultLineSpacing = 1.2
    static let lineSpacings = [1.1, 1.2, 1.3, 1.4, 1.5]

    /// 原稿欄の余白（左右・上下、pt）
    static func editorInset(_ margin: String) -> NSSize {
        switch margin {
        case "narrow": return NSSize(width: 6, height: 8)
        case "wide": return NSSize(width: 28, height: 18)
        default: return NSSize(width: 14, height: 12)
        }
    }

    /// プレビューの余白（CSSの margin：上下 左右）
    static func previewMargin(_ margin: String) -> String {
        switch margin {
        case "narrow": return "14px 18px"
        case "wide": return "28px 40px"
        default: return "18px 24px"
        }
    }
    /// 左右のペインの文字サイズ（pt）
    static let fontSizeKey = "markdownKitchen.fontSize"
    /// HTML→Markdownで <div>・<table> の中を変換しない（初期値オン）
    static let skipDivsKey = "markdownKitchen.htmlToMarkdown.skipDivs"
    static let skipTablesKey = "markdownKitchen.htmlToMarkdown.skipTables"
    static let defaultFontSize: Double = 13
    static let fontSizes: ClosedRange<Double> = 9...32

    /// 文字サイズを1段階変える（delta 0 で標準に戻す）
    static func changeFontSize(by delta: Double) {
        let defaults = UserDefaults.standard
        let current = defaults.object(forKey: fontSizeKey) as? Double ?? defaultFontSize
        let next = delta == 0 ? defaultFontSize : min(max(current + delta, fontSizes.lowerBound), fontSizes.upperBound)
        defaults.set(next, forKey: fontSizeKey)
    }

    /// 原稿。再起動しても残す（ファイルには書き戻さない）
    @Published var text: String {
        didSet {
            guard text != oldValue else { return }
            allHeadings = HeadingParser.headings(in: text)
            message = nil
            isEdited = true
            UserDefaults.standard.set(true, forKey: Self.editedKey)
            UserDefaults.standard.set(text, forKey: Self.textKey)
            if FindReplace.shared.isVisible { FindReplace.shared.refresh() }
        }
    }
    @Published private(set) var allHeadings: [Heading]
    /// 読み込んだ（保存した）ファイル。⌘Sの上書き先。再起動しても覚えておく
    @Published private(set) var fileURL: URL? {
        didSet { UserDefaults.standard.set(fileURL?.path, forKey: Self.fileKey) }
    }
    var fileName: String? { fileURL?.lastPathComponent }
    /// 読み込み・保存のあとに原稿を変えたか
    @Published private(set) var isEdited = false {
        didSet { refreshDocumentEdited() }
    }

    /// 閉じるボタンの点（未保存の印）。読み込んだファイルがあるときだけ
    func refreshDocumentEdited() {
        MainWindow.current?.isDocumentEdited = isEdited && fileURL != nil
    }
    /// 読み込んだときの文字コード。保存も同じ文字コードで書く
    private var fileEncoding: String.Encoding = .utf8
    /// 読み込み・保存した時点のファイルの更新日時。ほかで書き換えられたかの判定に使う
    private var fileDate: Date?
    static let fileKey = "markdownKitchen.filePath"
    static let editedKey = "markdownKitchen.fileEdited"

    @Published var message: String?
    /// 原稿で選択している文字列（選択がなければ空）。左下の「選択範囲」に使う
    @Published var selectedText = ""
    /// 「文字数を指定して書き直す」のシートに渡す範囲（開いているあいだだけ）
    @Published var rewriteRequest: RewriteRequest?
    /// 「HTMLリンク...」のシートに渡す範囲
    @Published var htmlLinkRequest: HTMLLinkRequest?
    /// 左ペインのテキストビュー。読み込みをUndoに載せる・見出しへ移動するために使う
    weak var editor: NSTextView?
    /// 原稿のスクロール（いちばん上に見えている行、末尾なら .infinity）をプレビューへ伝える
    var onSourceScroll: ((Double) -> Void)?

    init() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: Self.textKey) ?? ""
        text = saved
        allHeadings = HeadingParser.headings(in: saved)
        if let path = defaults.string(forKey: Self.fileKey), FileManager.default.fileExists(atPath: path) {
            fileURL = URL(fileURLWithPath: path)
            fileDate = Self.modificationDate(fileURL!)
        }
        isEdited = defaults.bool(forKey: Self.editedKey)
    }

    /// チェックしたレベルの見出しだけ
    func headings(levels: Set<Int>) -> [Heading] {
        allHeadings.filter { levels.contains($0.level) }
    }

    static var readableTypes: [UTType] {
        [UTType(filenameExtension: "md"), UTType(filenameExtension: "markdown"), .plainText, .text].compactMap { $0 }
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.title = L("Markdownファイルを選択")
        panel.prompt = L("開く")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.readableTypes
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }

    /// ファイルを読み込んで原稿を置き換える。元のファイルは変更しない。置き換えは⌘Zで戻せる
    func load(_ url: URL) {
        let loaded: String
        var encoding = String.Encoding.utf8
        do {
            if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
                loaded = utf8
            } else {
                loaded = try String(contentsOf: url, usedEncoding: &encoding)
            }
        } catch {
            message = L("読み込めませんでした：%@", url.lastPathComponent)
            NSSound.beep()
            return
        }
        replaceAll(with: loaded)
        fileURL = url
        fileEncoding = encoding
        fileDate = Self.modificationDate(url)
        markSaved()
        message = nil
    }

    /// 原稿を空にしてファイルとの連携も外す（新規）。未保存の変更があれば保存するか確かめる。空にするのは⌘Zで戻せる
    func newFile() {
        bringMainWindowForward()
        if isEdited && !text.isEmpty {
            let alert = NSAlert()
            alert.messageText = fileName.map { L("「%@」への変更を保存しますか？", $0) } ?? L("原稿への変更を保存しますか？")
            alert.informativeText = L("保存しない場合、原稿は空になります（取り消す（⌘Z）で戻せます）。")
            alert.addButton(withTitle: L("保存"))
            alert.addButton(withTitle: L("キャンセル"))
            alert.addButton(withTitle: L("保存しない"))
            alert.buttons[1].keyEquivalent = "\u{1b}"
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                save()
                // The save panel was canceled or writing failed.
                guard !isEdited else { return }
            case .alertThirdButtonReturn:
                break
            default:
                return
            }
        }
        replaceAll(with: "")
        editor?.undoManager?.setActionName(L("新規"))
        fileURL = nil
        fileDate = nil
        fileEncoding = .utf8
        markSaved()
        message = L("新しい原稿を作成しました")
    }

    /// ファイルとの連携を外す。原稿は残し、以後の⌘Sは「別名で保存…」
    func unlinkFile() {
        guard let name = fileName else { return }
        fileURL = nil
        fileDate = nil
        refreshDocumentEdited()
        message = L("「%@」との連携を解除しました", name)
    }

    private func markSaved() {
        isEdited = false
        UserDefaults.standard.set(false, forKey: Self.editedKey)
    }

    private static func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// 読み込んだファイルに上書きする。ファイルが無ければ「別名で保存…」
    func save() {
        guard let url = fileURL else { saveAs(); return }
        // Another app changed the file after it was loaded: ask before overwriting.
        if let loadedDate = fileDate, let current = Self.modificationDate(url), current > loadedDate.addingTimeInterval(1) {
            let alert = NSAlert()
            alert.messageText = L("「%@」はほかのアプリで変更されています", url.lastPathComponent)
            alert.informativeText = L("上書きすると、ほかのアプリでの変更は失われます（上書き前の内容はアプリ内に控えます）。")
            alert.addButton(withTitle: L("上書き"))
            alert.addButton(withTitle: L("キャンセル"))
            alert.buttons[1].keyEquivalent = "\u{1b}"
            guard alert.runModal() == .alertFirstButtonReturn else {
                message = L("保存を取り消しました")
                return
            }
        }
        write(to: url, encoding: fileEncoding)
    }

    /// 保存先を選んで書き出す。以後の⌘Sはそのファイルに上書き
    func saveAs() {
        let panel = NSSavePanel()
        panel.title = L("別名で保存")
        panel.nameFieldStringValue = fileName ?? L("名称未設定") + ".md"
        if let directory = fileURL?.deletingLastPathComponent() { panel.directoryURL = directory }
        panel.allowedContentTypes = Self.readableTypes
        panel.allowsOtherFileTypes = true
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Keep the encoding only when overwriting the same file; a new file is UTF-8.
        write(to: url, encoding: url == fileURL ? fileEncoding : .utf8)
    }

    private func write(to url: URL, encoding: String.Encoding) {
        // Characters the original encoding cannot hold switch the file to UTF-8 rather than losing them.
        let encoding = text.canBeConverted(to: encoding) ? encoding : .utf8
        guard let data = text.data(using: encoding) else { return }
        do {
            if FileManager.default.fileExists(atPath: url.path) { Self.backUp(url) }
            try data.write(to: url, options: .atomic)
        } catch {
            message = L("保存できませんでした：%@", error.localizedDescription)
            NSSound.beep()
            return
        }
        fileURL = url
        fileEncoding = encoding
        fileDate = Self.modificationDate(url)
        markSaved()
        message = L("保存しました：%@", url.lastPathComponent)
    }

    /// 上書き前の内容を ~/Library/Application Support/MarkdownKitchen/Backups に控える（新しい20件）
    static var backupFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MarkdownKitchen/Backups", isDirectory: true)
    }

    private static func backUp(_ url: URL) {
        let manager = FileManager.default
        let folder = backupFolder
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = url.deletingPathExtension().lastPathComponent + "-" + formatter.string(from: Date()) + "." + (url.pathExtension.isEmpty ? "md" : url.pathExtension)
        try? manager.copyItem(at: url, to: folder.appendingPathComponent(name))
        let files = ((try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .sorted { (modificationDate($0) ?? .distantPast) > (modificationDate($1) ?? .distantPast) }
        for old in files.dropFirst(20) { try? manager.removeItem(at: old) }
    }

    func showBackups() {
        try? FileManager.default.createDirectory(at: Self.backupFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Self.backupFolder)
    }

    /// テキストビューを通して置き換え、Undoの履歴に残す
    func replaceAll(with newText: String) {
        if let editor, let storage = editor.textStorage {
            editor.window?.makeFirstResponder(editor)
            let whole = NSRange(location: 0, length: storage.length)
            if editor.shouldChangeText(in: whole, replacementString: newText) {
                storage.replaceCharacters(in: whole, with: newText)
                editor.didChangeText()
                editor.setSelectedRange(NSRange(location: 0, length: 0))
                editor.scrollRangeToVisible(NSRange(location: 0, length: 0))
            }
        } else {
            text = newText
        }
    }

    /// 見出し行を選択して表示する
    func reveal(_ heading: Heading) {
        guard let editor, NSMaxRange(heading.range) <= (editor.string as NSString).length else { return }
        editor.window?.makeFirstResponder(editor)
        editor.setSelectedRange(heading.range)
        editor.scrollRangeToVisible(heading.range)
        editor.showFindIndicator(for: heading.range)
    }

    /// すべての見出しを1段上げる（delta = -1、#を減らす）・下げる（+1）。
    /// 原稿で範囲を選択していれば、その中の見出しだけ。まとめて1回の⌘Zで戻せる
    func shiftHeadings(by delta: Int, levels: Set<Int>) {
        // Every level is shifted, whatever is checked in the right pane (levels is kept for the callers).
        var targets = allHeadings
        if let selected = editor?.selectedRange(), selected.length > 0 {
            targets = targets.filter { NSIntersectionRange($0.range, selected).length > 0 || NSLocationInRange($0.range.location, selected) }
        }
        guard !targets.isEmpty else {
            message = L("対象の見出しがありません")
            NSSound.beep()
            return
        }
        guard let edits = HeadingParser.shiftEdits(targets, by: delta, in: text) else {
            message = delta < 0 ? L("見出し1が含まれるため、これ以上上げられません") : L("見出し6が含まれるため、これ以上下げられません")
            NSSound.beep()
            return
        }
        let actionName = delta < 0 ? L("すべての見出しを1段上げる") : L("すべての見出しを1段下げる")
        if let editor, let storage = editor.textStorage {
            // Edit > 取り消す follows the first responder; without this, ⌘Z stays disabled after a button click.
            editor.window?.makeFirstResponder(editor)
            editor.breakUndoCoalescing()
            editor.undoManager?.beginUndoGrouping()
            for edit in edits where editor.shouldChangeText(in: edit.range, replacementString: edit.text) {
                storage.replaceCharacters(in: edit.range, with: edit.text)
                editor.didChangeText()
            }
            editor.undoManager?.setActionName(actionName)
            editor.undoManager?.endUndoGrouping()
        } else {
            let string = NSMutableString(string: text)
            for edit in edits { string.replaceCharacters(in: edit.range, with: edit.text) }
            text = string as String
        }
        message = delta < 0 ? L("%@件の見出しを1段上げました", String(targets.count)) : L("%@件の見出しを1段下げました", String(targets.count))
    }

    /// 原稿のHTMLをMarkdownに変換する。範囲を選択していればその中だけ。⌘Zで戻せる
    func convertHTMLToMarkdown() {
        transformSource(actionName: L("HTML→Markdown"), unchanged: L("変換するHTMLはありません"),
                        done: L("HTMLをMarkdownに変換しました")) { source in
            let defaults = UserDefaults.standard
            var keep: Set<String> = []
            if defaults.object(forKey: Self.skipDivsKey) as? Bool ?? true { keep.insert("div") }
            if defaults.object(forKey: Self.skipTablesKey) as? Bool ?? true { keep.insert("table") }
            return HTMLToMarkdown.convert(source, keep: keep)
        }
    }

    /// 原稿の ## と ### を、選んだテーマの装飾付きHTML見出しに変換する（使ったテーマはメニューにチェックで示す）
    func convertMarkdownToHTML(_ preset: DoorkeeperPreset) {
        DoorkeeperPresets.shared.selectedID = preset.id
        guard let styles = DoorkeeperHTML.styles(for: preset) else {
            message = L("「%@」の基本カラーを読めません。設定で #0AF のように入力してください", preset.name)
            NSSound.beep()
            return
        }
        transformSource(actionName: L("Doorkeeper用に整形"), unchanged: L("変換する見出し（##・###）はありません"),
                        done: L("見出しをHTMLに変換しました（%@）", preset.name)) { DoorkeeperHTML.convert($0, styles: styles) }
    }

    /// 整形（選択していればその範囲、なければ全文）
    func tidy(_ rules: [MarkdownTidy.Rule]) {
        transformSource(actionName: L("整形"), unchanged: L("整える箇所はありません"), done: L("整形しました")) {
            MarkdownTidy.apply(rules, to: $0)
        }
    }

    /// 行単位の操作（選択にかかる行、なければ全文）
    func transformLines(_ actionName: String, done: String, _ transform: @escaping (String) -> String) {
        if let editor {
            // Extend the selection to whole lines, so a partly selected line is handled as a whole.
            let string = editor.string as NSString
            let selection = editor.selectedRange()
            if selection.length > 0 {
                var range = string.lineRange(for: selection)
                if NSMaxRange(selection) > selection.location,
                   string.substring(with: NSRange(location: NSMaxRange(selection) - 1, length: 1)) == "\n" {
                    range = string.lineRange(for: NSRange(location: selection.location, length: selection.length - 1))
                }
                editor.setSelectedRange(range)
            }
        }
        transformSource(actionName: actionName, unchanged: L("変わる行はありません"), done: done, transform)
    }

    /// 見出しの目次（箇条書き）をカーソルの位置に入れる
    func insertTableOfContents(levels: Set<Int>) {
        let list = headings(levels: levels)
        guard !list.isEmpty else {
            message = L("目次にする見出しがありません")
            NSSound.beep()
            return
        }
        // Inserted at the start of the selection; selected text is kept.
        let location = editor?.selectedRange().location ?? (text as NSString).length
        let range = NSRange(location: location, length: 0)
        let toc = TableOfContents.make(list) + "\n"
        replace(range, with: toc, actionName: L("目次を挿入"))
        message = L("%@件の見出しで目次を入れました", String(list.count))
    }

    /// プレビューと同じHTMLを全文コピーする
    func copyHTML() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(MarkdownHTML.render(text), forType: .string)
        message = L("HTMLをコピーしました")
    }

    /// 右の一覧で shown[from] の章を shown[destination] の手前（末尾なら原稿の最後）へ移す
    func moveSection(from: Int, to destination: Int, shown: [Heading]) {
        guard shown.indices.contains(from) else { return }
        let target = destination < shown.count ? shown[destination] : nil
        guard let edit = SectionMover.moveEdit(in: text, all: allHeadings, moving: shown[from], before: target) else {
            if let target, target.range.location > shown[from].range.location,
               target.range.location < NSMaxRange(SectionMover.sectionRange(of: shown[from], in: allHeadings, length: (text as NSString).length)) {
                message = L("見出しの中には移動できません")
                NSSound.beep()
            }
            return
        }
        replace(edit.range, with: edit.text, actionName: L("見出しの移動"))
        message = L("「%@」を移動しました", shown[from].title)
    }

    /// メインウインドウを前に出す（しまっていれば戻す）
    func bringMainWindowForward() {
        if let window = MainWindow.current, !window.isVisible || window.isMiniaturized {
            (NSApp.delegate as? AppDelegate)?.showWindow()
        }
    }

    /// 検索・置換からの置き換え（Undoに残す）
    func replaceForFind(_ range: NSRange, with replacement: String, actionName: String) {
        replace(range, with: replacement, actionName: actionName)
    }

    /// 書式を変える（選択した文字・カーソルのある段落）。メインウインドウが前面のときだけ
    func format(_ actionName: String, _ make: (String, NSRange) -> TextEdit) {
        guard let editor, editor.window?.isKeyWindow == true else {
            NSSound.beep()
            return
        }
        let edit = make(editor.string, editor.selectedRange())
        replace(edit.range, with: edit.replacement, actionName: actionName)
        editor.setSelectedRange(edit.selection)
        editor.scrollRangeToVisible(edit.selection)
    }

    /// 選択した文章の書き直しを始める（シートを開く）
    func beginRewrite() {
        guard let editor, editor.selectedRange().length > 0 else {
            message = L("書き直す範囲を選択してください")
            NSSound.beep()
            return
        }
        let range = editor.selectedRange()
        rewriteRequest = RewriteRequest(range: range, original: (editor.string as NSString).substring(with: range))
    }

    /// 書き直した文章で、開いた時点の選択範囲を置き換える（Undoに残す）
    func applyRewrite(_ request: RewriteRequest, with replacement: String) {
        let string = text as NSString
        guard NSMaxRange(request.range) <= string.length, string.substring(with: request.range) == request.original else {
            message = L("原稿が変わったため、置き換えられませんでした")
            NSSound.beep()
            return
        }
        replace(request.range, with: replacement, actionName: L("書き直し"))
        let selection = NSRange(location: request.range.location, length: (replacement as NSString).length)
        editor?.setSelectedRange(selection)
        editor?.scrollRangeToVisible(selection)
        message = L("書き直しました")
    }

    /// HTMLリンクのシートを開く（選択した文字をテキストに使う。選択がなければカーソルの位置に入れる）
    func beginHTMLLink() {
        guard let editor, editor.window?.isKeyWindow == true else {
            NSSound.beep()
            return
        }
        let range = editor.selectedRange()
        htmlLinkRequest = HTMLLinkRequest(range: range, selectedText: (editor.string as NSString).substring(with: range))
    }

    /// 開いた時点の選択範囲を <a> タグに置き換える（Undoに残す）
    func insertHTMLLink(_ request: HTMLLinkRequest, tag: String) {
        let string = text as NSString
        guard NSMaxRange(request.range) <= string.length, string.substring(with: request.range) == request.selectedText else {
            message = L("原稿が変わったため、置き換えられませんでした")
            NSSound.beep()
            return
        }
        replace(request.range, with: tag, actionName: L("HTMLリンク"))
        let selection = NSRange(location: request.range.location, length: (tag as NSString).length)
        editor?.setSelectedRange(selection)
        editor?.scrollRangeToVisible(selection)
    }

    /// 範囲を置き換えてUndoの履歴に残す
    private func replace(_ range: NSRange, with replacement: String, actionName: String) {
        if let editor, let storage = editor.textStorage {
            editor.window?.makeFirstResponder(editor)
            editor.breakUndoCoalescing()
            if editor.shouldChangeText(in: range, replacementString: replacement) {
                storage.replaceCharacters(in: range, with: replacement)
                editor.didChangeText()
                editor.undoManager?.setActionName(actionName)
            }
        } else {
            text = (text as NSString).replacingCharacters(in: range, with: replacement)
        }
    }

    /// 原稿（選択していればその範囲）を変換して置き換え、Undoの履歴に残す
    private func transformSource(actionName: String, unchanged: String, done: String, _ transform: (String) -> String) {
        let string = text as NSString
        var target = NSRange(location: 0, length: string.length)
        if let selected = editor?.selectedRange(), selected.length > 0 { target = selected }
        let original = string.substring(with: target)
        let converted = transform(original)
        guard converted != original else {
            message = unchanged
            NSSound.beep()
            return
        }
        replace(target, with: converted, actionName: actionName)
        editor?.setSelectedRange(NSRange(location: target.location, length: (converted as NSString).length))
        message = done
    }

    func copyHeadings(levels: Set<Int>, format: HeadingParser.Format) {
        let list = headings(levels: levels)
        guard !list.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(HeadingParser.render(list, format: format), forType: .string)
        message = L("%@件の見出しをコピーしました", String(list.count))
    }
}
