import Foundation

/// How the keywords are searched. The search runs on the text read from the target app.
struct SearchOptions: Equatable {
    var caseSensitive = false
    var wholeWord = false
    var excludeContained = true
}

/// One found keyword. `range` is in UTF-16 units, the same units as the Accessibility text ranges.
struct Match: Hashable {
    let keywordIndex: Int
    let range: NSRange
    let text: String
    var id: String { "\(keywordIndex)#\(range.location)" }
}

/// Characters shown around a match in the list.
struct MatchContext: Equatable {
    let before: String
    let match: String
    let after: String
}

/// Search logic ported from IdCountKeywordPalette.jsx (findKeywordRanges, removeContainedRanges, replaceMatches).
enum Matcher {
    private static let breaks: Set<unichar> = [0x0A, 0x0B, 0x0C, 0x0D, 0x2028, 0x2029]

    /// Finds one keyword, left to right, without overlaps.
    static func ranges(of keyword: String, in text: NSString, caseSensitive: Bool) -> [NSRange] {
        guard !keyword.isEmpty else { return [] }
        var found: [NSRange] = []
        var location = 0
        let options: NSString.CompareOptions = caseSensitive ? [.literal] : [.literal, .caseInsensitive]
        while location < text.length {
            let range = text.range(of: keyword, options: options, range: NSRange(location: location, length: text.length - location))
            if range.location == NSNotFound { break }
            found.append(range)
            location = range.location + max(range.length, 1)
        }
        return found
    }

    /// Latin, kanji and katakana words run on into the same script; hiragana has no such edge.
    private static func wordClass(_ scalar: Unicode.Scalar) -> Int? {
        let value = scalar.value
        if (0x3041...0x309F).contains(value) { return nil }
        if (0x30A1...0x30FA).contains(value) || value == 0x30FC || (0xFF66...0xFF9F).contains(value) { return 1 }
        if (0x3400...0x9FFF).contains(value) || (0xF900...0xFAFF).contains(value) || (0x20000...0x3FFFF).contains(value) || value == 0x3005 { return 2 }
        if (0xAC00...0xD7AF).contains(value) { return nil }
        return CharacterSet.alphanumerics.contains(scalar) || scalar == "_" ? 3 : nil
    }

    /// False when the match runs on into a character of the same script: 事 in 仕事, サーバ in サーバラック, apple in pineapple.
    static func isWholeWord(_ range: NSRange, in text: NSString) -> Bool {
        let matched = text.substring(with: range)
        // A kanji edge counts only for all-kanji words: 下さい stays a word after 確認.
        let isKanjiOnly = matched.unicodeScalars.allSatisfy { wordClass($0) == 2 }
        func hasEdge(_ kind: Int) -> Bool { kind != 2 || isKanjiOnly }
        if let first = matched.unicodeScalars.first, let kind = wordClass(first), hasEdge(kind), range.location > 0,
           let previous = text.substring(with: text.rangeOfComposedCharacterSequence(at: range.location - 1)).unicodeScalars.last, wordClass(previous) == kind { return false }
        let end = range.location + range.length
        if let last = matched.unicodeScalars.last, let kind = wordClass(last), hasEdge(kind), end < text.length,
           let next = text.substring(with: text.rangeOfComposedCharacterSequence(at: end)).unicodeScalars.first, wordClass(next) == kind { return false }
        return true
    }

    /// Matches per keyword field, in the order of `keywords`. An empty field gets an empty list.
    static func search(_ keywords: [String], in string: String, options: SearchOptions) -> [[Match]] {
        let text = string as NSString
        let found: [[Match]] = keywords.enumerated().map { index, keyword in
            ranges(of: keyword, in: text, caseSensitive: options.caseSensitive)
                .filter { !options.wholeWord || isWholeWord($0, in: text) }
                .map { Match(keywordIndex: index, range: $0, text: text.substring(with: $0)) }
        }
        return options.excludeContained ? removeContained(found, keywords: keywords) : found
    }

    /// Drops a match that lies inside a match of a different, longer keyword (「取引」 inside 「取引き」).
    static func removeContained(_ matches: [[Match]], keywords: [String]) -> [[Match]] {
        matches.enumerated().map { index, own in
            let length = (keywords[index] as NSString).length
            let longer = matches.enumerated().filter { (keywords[$0.offset] as NSString).length > length }.flatMap(\.element).map(\.range)
            guard !longer.isEmpty else { return own }
            return own.filter { match in
                !longer.contains { $0.location <= match.range.location && NSMaxRange(match.range) <= NSMaxRange($0) }
            }
        }
    }

    /// The text around a match, cut on whole characters so emoji are not split.
    /// With `withinParagraph` it stops at a paragraph break, which is left out along with what lies beyond it.
    static func context(of range: NSRange, in text: NSString, length: Int, withinParagraph: Bool = false) -> MatchContext {
        var start = range.location
        var count = 0
        while start > 0, count < length {
            if withinParagraph, breaks.contains(text.character(at: start - 1)) { break }
            start = text.rangeOfComposedCharacterSequence(at: start - 1).location
            count += 1
        }
        var end = NSMaxRange(range)
        count = 0
        while end < text.length, count < length {
            if withinParagraph, breaks.contains(text.character(at: end)) { break }
            end = NSMaxRange(text.rangeOfComposedCharacterSequence(at: end))
            count += 1
        }
        return MatchContext(before: display(text.substring(with: NSRange(location: start, length: range.location - start))),
                            match: display(text.substring(with: range)),
                            after: display(text.substring(with: NSRange(location: NSMaxRange(range), length: end - NSMaxRange(range)))))
    }

    /// One-line form for the list: breaks become ¶, tabs become spaces, other control characters and object markers go.
    static func display(_ raw: String) -> String {
        var result = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            switch scalar.value {
            case 0x0A, 0x0B, 0x0C, 0x0D, 0x2028, 0x2029: result.append("¶")
            case 0x09: result.append(" ")
            case 0..<0x20, 0xFEFF, 0xFFFC: continue
            default: result.append(scalar)
            }
        }
        return String(result)
    }

    /// Start offset of every paragraph, for numbering the rows.
    static func paragraphStarts(in text: NSString) -> [Int] {
        var starts = [0]
        var index = 0
        while index < text.length {
            let character = text.character(at: index)
            if breaks.contains(character) {
                if character == 0x0D, index + 1 < text.length, text.character(at: index + 1) == 0x0A { index += 1 }
                starts.append(index + 1)
            }
            index += 1
        }
        return starts
    }

    /// 1-based paragraph number of an offset.
    static func paragraphNumber(of location: Int, starts: [Int]) -> Int {
        var low = 0, high = starts.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if starts[middle] <= location { low = middle } else { high = middle - 1 }
        }
        return low + 1
    }

    /// Order for replacing: from the end of the text, so earlier offsets stay valid. Of overlapping matches the later one wins.
    static func replacementPlan(_ matches: [Match]) -> (ordered: [Match], overlapped: Int) {
        var ordered: [Match] = []
        var overlapped = 0
        var nextStart = Int.max
        for match in matches.sorted(by: { $0.range.location > $1.range.location }) {
            if NSMaxRange(match.range) > nextStart { overlapped += 1; continue }
            ordered.append(match)
            nextStart = match.range.location
        }
        return (ordered, overlapped)
    }

    /// Where a match stands among the hits of Google Docs' find bar, which ignores case and knows nothing of whole words.
    static func findBarPosition(of range: NSRange, keyword: String, in text: NSString) -> (index: Int, total: Int)? {
        let hits = ranges(of: keyword, in: text, caseSensitive: false)
        guard let index = hits.firstIndex(where: { $0.location == range.location }) else { return nil }
        return (index, hits.count)
    }
}

/// Matches the user left out, kept by position and text. A position whose text changed no longer counts as excluded.
struct ExclusionList: Equatable {
    private(set) var items: [Int: String] = [:]

    func contains(_ match: Match) -> Bool { items[match.range.location] == match.text }
    mutating func set(_ match: Match, excluded: Bool) { items[match.range.location] = excluded ? match.text : nil }
    mutating func removeAll() { items = [:] }

    /// Moves the kept positions by what the replacements before them added or removed.
    mutating func shift(after replaced: [Match], replacementLength: Int) {
        var shifted: [Int: String] = [:]
        for (location, text) in items {
            let delta = replaced.filter { NSMaxRange($0.range) <= location }.reduce(0) { $0 + replacementLength - $1.range.length }
            shifted[location + delta] = text
        }
        items = shifted
    }
}

/// One spelling of a word and how often it appears.
struct Spelling: Equatable {
    let text: String
    var count: Int
}

/// Spellings of the same word found in one text, most frequent first.
struct VariantGroup: Identifiable, Equatable {
    enum Kind: String, CaseIterable { case katakana, kanji, latin, suru, dictionary, review }

    let id: String
    let spellings: [Spelling]
    /// The spelling a dictionary recommends.
    var recommended: String?
    var total: Int { spellings.reduce(0) { $0 + $1.count } }
    var kind: Kind {
        switch id.prefix(2) {
        case "k:": return .katakana
        case "j:": return .kanji
        case "l:": return .latin
        case "s:": return .suru
        case "r:": return .review
        default: return .dictionary
        }
    }
    /// Short form for lists of remembered groups.
    var label: String { spellings.map(\.text).joined(separator: "／") }
}

/// Finds words written in more than one way, without being told which words to look at.
/// Japanese has no spaces, so only three kinds of word are cut out: katakana runs, Latin words, and kanji with okurigana.
/// Differences that do not change the word are ignored: case, width, long vowels, middle dots, small kana, ヴ and okurigana.
enum VariantFinder {
    private enum Script { case kanji, hiragana, katakana, latin, other }

    private struct Unit {
        var key: String
        var script: Script
        var range: NSRange
    }

    private static let smallKana: [Unicode.Scalar: Unicode.Scalar] = ["ァ": "ア", "ィ": "イ", "ゥ": "ウ", "ェ": "エ", "ォ": "オ"]
    private static let vuKana: [String: String] = ["ァ": "バ", "ィ": "ビ", "ェ": "ベ", "ォ": "ボ"]
    /// One kana between kanji in a noun: 取り引き, 申し込み, 建て替え. Only the forms a noun takes,
    /// so that 「入力する場合」 and 「入力した場合」 are not taken for one word. Particles are left out for the same reason.
    private static let innerOkurigana: Set<String> = ["キ", "リ", "シ", "チ", "ミ", "イ", "ギ", "ビ", "ケ", "エ", "セ", "メ", "レ", "ゲ", "ベ", "テ"]
    /// Okurigana that ends a noun: 取引き, 売上げ, 組立て.
    private static let endingOkurigana: Set<String> = ["キ", "リ", "イ", "ミ", "ケ", "ゲ", "エ", "チ", "レ", "テ", "セ", "メ"]
    /// Kana that may follow a noun. Any other kana after a kanji word means an inflected word.
    private static let particles: Set<String> = ["ハ", "ガ", "ヲ", "ニ", "ノ", "デ", "ト", "モ", "ヘ", "ヤ", "カ", "ネ", "ヨ", "ナ", "ダ", "マ"]
    /// The forms of する after a compound: 変更する, 変更して, 変更され, 変更せず.
    private static let suruForms: Set<String> = ["ス", "シ", "サ", "セ"]
    /// Two-kana endings: 打ち合わせ, 見積もり.
    private static let longEndings: Set<String> = ["ワセ", "モリ"]
    /// Forms of する compared with and without を, longest first. Each form is its own group: 確認する can replace 確認をする, not 確認をします.
    private static let suruEndings = ["しました", "しません", "します", "しない", "すれば", "して", "した", "する"]
    /// Words that change case only at the start of a sentence.
    private static let commonWords: Set<String> = ["a", "an", "and", "are", "as", "at", "be", "but", "by", "for", "from", "he", "i", "if", "in", "is", "it", "its", "no", "not", "of", "on", "or", "our", "she", "so", "that", "the", "their", "there", "these", "they", "this", "to", "we", "what", "when", "which", "with", "you", "your"]

    private static func script(of text: String) -> Script {
        guard let scalar = text.unicodeScalars.first else { return .other }
        switch scalar.value {
        case 0x3041...0x309F: return .hiragana
        case 0x30FB: return .other
        case 0x30A1...0x30FC: return .katakana
        case 0x3400...0x9FFF, 0xF900...0xFAFF, 0x20000...0x3FFFF, 0x3005: return .kanji
        default: return CharacterSet.alphanumerics.contains(scalar) ? .latin : .other
        }
    }

    /// One unit per visible character. Half-width kana with a voiced mark is already one character here.
    private static func units(of text: String) -> [Unit] {
        var result: [Unit] = []
        var offset = 0
        for character in text {
            let length = String(character).utf16.count
            defer { offset += length }
            let folded = String(character).precomposedStringWithCompatibilityMapping.lowercased()
            // ヴァ and バ are one word: the pair becomes a single unit.
            if result.last?.key == "ヴ", let merged = vuKana[folded] {
                result[result.count - 1].key = merged
                result[result.count - 1].range.length += length
                continue
            }
            var key = String.UnicodeScalarView()
            for scalar in folded.unicodeScalars {
                let katakana = (0x3041...0x3096).contains(scalar.value) ? Unicode.Scalar(scalar.value + 0x60)! : scalar
                key.append(smallKana[katakana] ?? katakana)
            }
            result.append(Unit(key: String(key), script: script(of: folded), range: NSRange(location: offset, length: length)))
        }
        for index in result.indices where result[index].key == "ヴ" { result[index].key = "ブ" }
        return result
    }

    /// Long vowels are ignored inside longer words only: ユーザビリティ and ユーザービリティ are one word, ビル and ビール are not.
    private static func katakanaKey(_ units: ArraySlice<Unit>) -> String? {
        var keys = units.map(\.key).filter { $0 != "・" }
        while keys.last == "ー" { keys.removeLast() }
        let letters = keys.filter { $0 != "ー" }
        guard letters.count >= 2 else { return nil }
        return "k:" + (letters.count >= 4 ? letters : keys).joined()
    }

    private static func latinKey(_ units: ArraySlice<Unit>) -> String? {
        let word = units.map(\.key).filter { $0 != "-" }.joined()
        // Numbers count too: they group only when 12 and １２ both appear.
        guard word.count >= 2 || word.allSatisfy(\.isNumber), !commonWords.contains(word) else { return nil }
        return "l:" + word
    }

    private static func kanjiKey(_ units: ArraySlice<Unit>) -> String? {
        let kanji = units.filter { $0.script == .kanji }.map(\.key)
        return kanji.count >= 2 ? "j:" + kanji.joined() : nil
    }

    /// Where a katakana or Latin word that starts at `start` ends (exclusive).
    private static func wordEnd(_ all: [Unit], from start: Int) -> Int {
        var end = start + 1
        switch all[start].script {
        case .katakana:
            while end < all.count {
                if all[end].script == .katakana { end += 1 }
                else if all[end].key == "・", end + 1 < all.count, all[end + 1].script == .katakana { end += 2 }
                else { break }
            }
        case .latin:
            while end < all.count {
                if all[end].script == .latin { end += 1 }
                else if all[end].key == "-", end + 1 < all.count, all[end + 1].script == .latin { end += 2 }
                else { break }
            }
        default: break
        }
        return end
    }

    /// A kanji word with its okurigana. A verb in the middle of its ending (取り消す, 切り替える) is no word to compare:
    /// its stem would show up as a broken spelling. Compounds with する (変更せず, 確認して) keep the kanji part.
    private static func kanjiWord(_ all: [Unit], from start: Int) -> (end: Int, isNoun: Bool) {
        var end = start + 1
        var hasInner = false
        while end < all.count {
            if all[end].script == .kanji { end += 1 }
            else if all[end].script == .hiragana, innerOkurigana.contains(all[end].key), end + 1 < all.count, all[end + 1].script == .kanji { end += 2; hasInner = true }
            else { break }
        }
        let stem = end
        if end + 1 < all.count, all[end].script == .hiragana, all[end + 1].script == .hiragana, longEndings.contains(all[end].key + all[end + 1].key) { end += 2 }
        else if end < all.count, all[end].script == .hiragana, endingOkurigana.contains(all[end].key) || (hasInner && all[end].key == "シ") { end += 1 }
        guard end < all.count, all[end].script == .hiragana, !particles.contains(all[end].key) else { return (end, true) }
        return (stem, !hasInner && stem < all.count && suruForms.contains(all[stem].key))
    }

    /// The する form after a noun: 「する」 for 調整する and 調整をする alike, with the length up to the end of the form.
    private static func suruEnding(after location: Int, in text: NSString) -> (ending: String, end: Int)? {
        func hasText(_ part: String, at offset: Int) -> Bool {
            let length = (part as NSString).length
            return offset + length <= text.length && text.substring(with: NSRange(location: offset, length: length)) == part
        }
        let start = hasText("を", at: location) ? location + 1 : location
        return suruEndings.first { hasText($0, at: start) }.map { ($0, start + ($0 as NSString).length) }
    }

    /// Dictionary groups present in the text. Hits inside a longer spelling of the entry do not count (字詰め in 文字詰め).
    private static func dictionaryGroups(_ entries: [DictionaryEntry], in text: String) -> [VariantGroup] {
        let options = SearchOptions(caseSensitive: true, wholeWord: true, excludeContained: true)
        return entries.compactMap { entry in
            let counts = Matcher.search(entry.spellings, in: text, options: options).map(\.count)
            let all = zip(entry.spellings, counts).map { Spelling(text: $0, count: $1) }
            let used = all.filter { $0.count > 0 }
            switch entry.mode {
            case .variants:
                guard used.count >= 2 else { return nil }
                return VariantGroup(id: entry.id, spellings: used.sorted { $0.count > $1.count }, recommended: entry.target)
            case .correction, .review:
                guard all.contains(where: { $0.count > 0 && entry.wrong.contains($0.text) }) else { return nil }
                // The right spelling stays in the group even when the text does not use it yet.
                let shown = all.filter { $0.count > 0 || $0.text == entry.target }
                return VariantGroup(id: entry.id, spellings: shown.sorted { $0.count > $1.count }, recommended: entry.mode == .correction ? entry.target : nil)
            }
        }
    }

    /// Every word written in more than one way, the most used first.
    static func groups(in text: String, dictionary: [DictionaryEntry] = []) -> [VariantGroup] {
        let all = units(of: text)
        let source = text as NSString
        var found: [String: [String: Int]] = [:]
        var firstSeen: [String: Int] = [:]
        var index = 0
        while index < all.count {
            let script = all[index].script
            guard script == .katakana || script == .latin || script == .kanji else { index += 1; continue }
            let kanji = script == .kanji ? kanjiWord(all, from: index) : nil
            let end = kanji?.end ?? wordEnd(all, from: index)
            let word = all[index..<end]
            let key = script == .katakana ? katakanaKey(word) : script == .latin ? latinKey(word) : kanji?.isNoun == true ? kanjiKey(word) : nil
            if let key {
                let start = all[index].range.location
                let surface = source.substring(with: NSRange(location: start, length: NSMaxRange(all[end - 1].range) - start))
                found[key, default: [:]][surface, default: 0] += 1
                if firstSeen[surface] == nil { firstSeen[surface] = start }
                // 調整する and 調整をする: only plain nouns, not 取り引き or a verb stem.
                let isPlainNoun = script == .katakana || word.allSatisfy { $0.script == .kanji }
                if isPlainNoun, let suru = suruEnding(after: NSMaxRange(all[end - 1].range), in: source) {
                    let phrase = source.substring(with: NSRange(location: start, length: suru.end - start))
                    found["s:" + key.dropFirst(2) + suru.ending, default: [:]][phrase, default: 0] += 1
                    if firstSeen[phrase] == nil { firstSeen[phrase] = start }
                }
            }
            index = end
        }
        let fromDictionary = dictionaryGroups(dictionary, in: text)
        let covered = fromDictionary.map { Set($0.spellings.map(\.text)) }
        let groups = found.filter { $0.value.count >= 2 }.map { key, spellings in
            VariantGroup(id: key, spellings: spellings.map { Spelling(text: $0.key, count: $0.value) }.sorted {
                $0.count != $1.count ? $0.count > $1.count : firstSeen[$0.text, default: 0] < firstSeen[$1.text, default: 0]
            })
        }.filter { group in !covered.contains { Set(group.spellings.map(\.text)).isSubset(of: $0) } }
        return (groups + fromDictionary).sorted { $0.total != $1.total ? $0.total > $1.total : $0.id < $1.id }
    }
}

/// The match color as stored in the settings: 「r,g,b」 in sRGB. Empty means the system red, which adapts to Dark Mode.
enum MatchColorCode {
    static func encode(red: Double, green: Double, blue: Double) -> String {
        [red, green, blue].map { String(format: "%.4f", min(1, max(0, $0))) }.joined(separator: ",")
    }
    static func decode(_ text: String) -> (red: Double, green: Double, blue: Double)? {
        let parts = text.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 3, parts.allSatisfy({ (0...1).contains($0) }) else { return nil }
        return (parts[0], parts[1], parts[2])
    }
}
