import Foundation

/// 「ファイル名のみ」: gives files and folders names that work on both macOS and Windows; the contents are not touched.
/// A copy is made (the original stays), or the original itself is renamed. Folders are handled with everything inside.
///   - Unicode normalization to NFC (macOS often writes decomposed kana, Hangul and accented letters, which Windows shows split).
///     CJK compatibility ideographs (神 U+FA19 and so on) are kept, as macOS itself does.
///   - Machine-dependent characters (①, ㈱, Ⅰ…), characters whose Mac and Windows Shift_JIS mappings differ (〜, −, ‖…)
///     and emoji, optionally (old Shift_JIS applications show them as "?").
///   - Characters Windows rejects (\ / : * ? " < > |) become full-width ones or "_"; control characters are removed.
///   - Spaces and periods at the end (Windows drops them) and spaces at the start are removed.
///   - Spaces (half- and full-width) are kept or become "_" / "-"; a leading "." (hidden on macOS) is kept, "_" or removed.
///   - Reserved device names (CON, PRN, AUX, NUL, COM1–9, LPT1–9) get "_" appended.
///   - Names can be shortened to a number of characters (Windows paths stop at 260 characters).
/// .DS_Store and "._" files (Finder's own data) keep their names.
enum FileNameConverter {
    struct Options: Equatable {
        /// "fullwidth" (＼／：＊？”＜＞｜) or "underscore".
        var replacement = "fullwidth"
        var normalize = true
        /// "keep", "underscore" or "hyphen".
        var spaces = "keep"
        /// Rename the original instead of making a copy.
        var renameOriginal = false
        /// "keep", "underscore" or "remove".
        var leadingDot = "keep"
        /// Machine-dependent characters, Mac/Windows Shift_JIS differences and emoji.
        var legacy = false
        /// Longest name in UTF-16 units, extension included (0 = no limit).
        var maxLength = 0
    }

    /// Converts one input. The report counts what the result note mentions.
    final class Session {
        let options: Options
        var shortened = 0
        var longestPath = 0
        init(options: Options) { self.options = options }
    }

    static let maxLengthRange = 10...255
    /// Windows' MAX_PATH less the drive ("C:\") and the folders the copy is likely to sit in.
    static let pathWarningLength = 200

    // ” instead of ＂: U+FF02 is an IBM extension in CP932 (machine-dependent itself).
    static let forbidden: [Character: Character] = ["\\":"＼", "/":"／", ":":"：", "*":"＊", "?":"？", "\"":"”", "<":"＜", ">":"＞", "|":"｜"]
    static let reserved: Set<String> = Set(["CON","PRN","AUX","NUL"] + (1...9).flatMap { ["COM\($0)", "LPT\($0)"] })
    /// Mac (JIS) forms → the forms Windows' CP932 maps the same Shift_JIS codes to.
    static let windowsForms: [Character: Character] = ["\u{301C}":"\u{FF5E}", "\u{2212}":"\u{FF0D}", "\u{2016}":"\u{2225}", "\u{2014}":"\u{2015}", "\u{00A2}":"\u{FFE0}", "\u{00A3}":"\u{FFE1}", "\u{00AC}":"\u{FFE2}"]

    /// The ranges macOS leaves undecomposed: NFC would replace these ideographs with their unified forms.
    static func isCompatibilityIdeograph(_ scalar: Unicode.Scalar) -> Bool {
        (0xF900...0xFAFF).contains(scalar.value) || (0x2F800...0x2FAFF).contains(scalar.value)
    }

    /// NFC everywhere except CJK compatibility ideographs (they never combine with their neighbors).
    static func normalize(_ text: String) -> String {
        var result = ""; var run = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if isCompatibilityIdeograph(scalar) {
                result += String(run).precomposedStringWithCanonicalMapping; run = String.UnicodeScalarView()
                result.unicodeScalars.append(scalar)
            } else { run.append(scalar) }
        }
        return result + String(run).precomposedStringWithCanonicalMapping
    }

    static func isEmoji(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        return scalars.contains { $0.properties.isEmojiPresentation } || (scalars.count > 1 && scalars.contains { $0.value == 0xFE0F || $0.value == 0x200D } && scalars.contains { $0.properties.isEmoji && $0.value > 0xFF })
    }

    /// NEC special characters (lead byte 0x87) and IBM extensions (0xED–0xEE, 0xFA–0xFC) in CP932.
    static func isMachineDependent(_ character: Character) -> Bool {
        guard let lead = String(character).data(using:.shiftJIS)?.first else { return false }
        return lead == 0x87 || lead == 0xED || lead == 0xEE || lead >= 0xFA
    }

    /// ① → (1), ㈱ → (株), Ⅰ → I, ㍉ → ミリ, 〜 → ～, emoji removed. Kanji of the IBM extensions (髙, 﨑…) are kept: they are names.
    static func replaceLegacy(_ text: String) -> String {
        var result = ""
        for character in text {
            if isEmoji(character) { continue }
            if let form = windowsForms[character] { result.append(form); continue }
            guard isMachineDependent(character), let scalar = character.unicodeScalars.first, !scalar.properties.isIdeographic else { result.append(character); continue }
            if (0x2460...0x2473).contains(scalar.value) { result += "(\(scalar.value - 0x2460 + 1))"; continue }
            result += String(character).precomposedStringWithCompatibilityMapping
        }
        return result
    }

    /// Finder's own files: renaming or "fixing" them would only break them.
    static func isFinderData(_ name: String) -> Bool { name == ".DS_Store" || name.hasPrefix("._") }

    static func safeName(_ name: String, options: Options = Options(), isFolder: Bool = false) -> String {
        var text = options.normalize ? normalize(name) : name
        if options.legacy { text = replaceLegacy(text) }
        text = String(text.unicodeScalars.filter { $0.value >= 0x20 && $0.value != 0x7F }.map(Character.init))
        text = String(text.map { forbidden[$0].map { options.replacement == "underscore" ? "_" : $0 } ?? $0 })
        trim(&text)
        if text.hasPrefix(".") && options.leadingDot != "keep" {
            text = options.leadingDot == "underscore" ? "_" + text.dropFirst() : String(text.drop { $0 == "." })
            trim(&text)
        }
        if options.spaces != "keep" {
            let mark: Character = options.spaces == "hyphen" ? "-" : "_"
            text = String(text.map { $0 == " " || $0 == "\u{3000}" ? mark : $0 })
        }
        // "CON", "con.txt", "Com1.tar.gz": Windows checks the part before the first period.
        let head = text.split(separator:".", maxSplits:1, omittingEmptySubsequences:false).first.map(String.init) ?? text
        if reserved.contains(head.trimmingCharacters(in:.whitespaces).uppercased()) {
            text = head + "_" + text.dropFirst(head.count)
        }
        if options.maxLength > 0 { text = shorten(text, to:options.maxLength, keepExtension:!isFolder) }
        return text.isEmpty ? "_" : text
    }

    private static func trim(_ text: inout String) {
        while let first = text.first, first == " " || first == "\u{3000}" { text.removeFirst() }
        while let last = text.last, last == " " || last == "\u{3000}" || last == "." { text.removeLast() }
    }

    /// Cuts the stem (whole characters, so no emoji or kana mark is split) and keeps the extension.
    static func shorten(_ name: String, to limit: Int, keepExtension: Bool) -> String {
        guard name.utf16.count > limit else { return name }
        let ns = name as NSString
        let ext = keepExtension && !ns.pathExtension.isEmpty && ns.pathExtension.utf16.count < limit / 2 ? "." + ns.pathExtension : ""
        var stem = ""
        for character in ext.isEmpty ? name : ns.deletingPathExtension {
            if stem.utf16.count + String(character).utf16.count + ext.utf16.count > limit { break }
            stem.append(character)
        }
        trim(&stem)
        return (stem.isEmpty ? "_" : stem) + ext
    }

    /// Code points, not Swift's ==: that treats NFD and NFC as the same string.
    static func sameName(_ a: String, _ b: String) -> Bool { a.unicodeScalars.elementsEqual(b.unicodeScalars) }

    static func isFolder(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys:[.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey])
        return values?.isDirectory == true && values?.isPackage != true && values?.isSymbolicLink != true
    }

    private static func children(of folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at:folder, includingPropertiesForKeys:[.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey], options:[])
    }

    private static func newName(_ url: URL, _ options: Options) -> String {
        isFinderData(url.lastPathComponent) ? url.lastPathComponent : safeName(url.lastPathComponent, options:options, isFolder:isFolder(url))
    }

    /// newName, counting the names cut to the length limit.
    private static func resolvedName(_ url: URL, _ session: Session) -> String {
        let name = newName(url, session.options)
        if session.options.maxLength > 0, !isFinderData(url.lastPathComponent) {
            var unlimited = session.options; unlimited.maxLength = 0
            if safeName(url.lastPathComponent, options:unlimited, isFolder:isFolder(url)).utf16.count > session.options.maxLength { session.shortened += 1 }
        }
        return name
    }

    /// The longest path from the item's own name down (what is added to the folder it is put in on Windows).
    static func longestPath(_ url: URL) -> Int {
        let own = url.lastPathComponent.utf16.count
        guard isFolder(url), let items = try? children(of:url), !items.isEmpty else { return own }
        return own + 1 + items.map(longestPath).max()!
    }

    /// Whether anything in the tree gets a different name.
    static func needsChange(_ url: URL, options: Options) throws -> Bool {
        if !sameName(newName(url, options), url.lastPathComponent) { return true }
        return isFolder(url) ? try children(of:url).contains { try needsChange($0, options:options) } : false
    }

    /// Gives the scratch item its final name: "name.ext", then "name (1).ext"…; a folder's whole name is the stem
    /// ("v1.2", then "v1.2 (1)"). POSIX renamex_np, not FileManager: Foundation writes names decomposed (NFD),
    /// which would undo the normalization. RENAME_EXCL never replaces an existing item.
    static func place(_ temp: URL, in folder: URL, name: String, isFolder: Bool) throws -> URL {
        let ns = name as NSString
        let ext = isFolder ? "" : ns.pathExtension
        let stem = ext.isEmpty ? name : ns.deletingPathExtension
        for index in 0..<10000 {
            let path = folder.path + "/" + stem + (index == 0 ? "" : " (\(index))") + (ext.isEmpty ? "" : "." + ext)
            if FileManager.default.fileExists(atPath:path) { continue }
            if renamex_np(temp.path, path, UInt32(RENAME_EXCL)) == 0 { return URL(fileURLWithPath:path, isDirectory:isFolder) }
            if errno != EEXIST { throw POSIXError(POSIXErrorCode(rawValue:errno) ?? .EIO) }
        }
        throw NSError(domain:"PandocDesk", code:1, userInfo:[NSLocalizedDescriptionKey:"No unused output filename"])
    }

    private static func scratch(in folder: URL) -> URL { folder.appendingPathComponent(".PandocDesk-" + UUID().uuidString) }

    /// nil when no name changes (and, for a copy, it would land beside the original).
    static func convert(input: URL, folder: URL, session: Session) throws -> URL? {
        let options = session.options
        if options.renameOriginal || folder.standardizedFileURL == input.deletingLastPathComponent().standardizedFileURL {
            guard try needsChange(input, options:options) else { return nil }
        }
        let result = options.renameOriginal ? try rename(input, session:session) : try copy(input, into:folder, session:session)
        session.longestPath = max(session.longestPath, longestPath(result))
        return result
    }

    // MARK: Copy

    /// Each item is made under a hidden scratch name and then placed, so only complete copies get final names (APFS clones the files).
    private static func copy(_ input: URL, into folder: URL, session: Session) throws -> URL {
        let fm = FileManager.default
        let temp = scratch(in:folder)
        let folderInput = isFolder(input)
        do {
            if folderInput {
                try fm.createDirectory(at:temp, withIntermediateDirectories:false)
                try copyContents(of:input, into:temp, session:session)
            } else { try fm.copyItem(at:input, to:temp) }
            return try place(temp, in:folder, name:resolvedName(input, session), isFolder:folderInput)
        } catch { try? fm.removeItem(at:temp); throw error }
    }

    private static func copyContents(of source: URL, into target: URL, session: Session) throws {
        for child in try children(of:source).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let folder = isFolder(child)
            let temp = scratch(in:target)
            if folder {
                try FileManager.default.createDirectory(at:temp, withIntermediateDirectories:false)
                try copyContents(of:child, into:temp, session:session)
            } else { try FileManager.default.copyItem(at:child, to:temp) }
            _ = try place(temp, in:target, name:resolvedName(child, session), isFolder:folder)
        }
    }

    // MARK: Rename

    /// Inside first, so the folder paths stay valid while its contents are renamed. Through a scratch name, so a name
    /// that differs only in normalization or case (one name to APFS) still changes.
    private static func rename(_ url: URL, session: Session) throws -> URL {
        let folder = isFolder(url)
        if folder {
            for child in try children(of:url) { _ = try rename(child, session:session) }
        }
        let name = resolvedName(url, session)
        guard !sameName(name, url.lastPathComponent) else { return url }
        let parent = url.deletingLastPathComponent()
        let temp = scratch(in:parent)
        try FileManager.default.moveItem(at:url, to:temp)
        do { return try place(temp, in:parent, name:name, isFolder:folder) }
        catch { _ = renamex_np(temp.path, url.path, UInt32(RENAME_EXCL)); throw error }
    }
}
