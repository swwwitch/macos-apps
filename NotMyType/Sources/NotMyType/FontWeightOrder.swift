import Foundation

/// ファミリーの中の書体の並び順（細い→太い、幅・用途の語とイタリックは後ろ）。
/// ~/Git/ai-scripts/jsx/fonts/TypefaceSampler.jsx の getFontSortScore を移したもの（ユーザー指定）。同点は PostScript名順
enum FontWeightOrder {
    /// ウエイトの語の並び（番号が大きいほど太い）
    static let weightGroups: [[String]] = [
        ["hairline", "hair"],
        ["ultra thin", "ultrathin", "ut"],
        ["thin", "th"],
        ["default"],
        ["ultralight", "ultra light", "ultlt", "ul"],
        ["extralight", "extra light", "el", "xlight", "xl"],
        ["lightsemi"],
        ["light", "lt", "lite", "l"],
        ["lb"],
        ["book", "bk"],
        ["n", "normal"],
        ["middle"],
        ["regular", "roman", "レギュラー", "r"],
        ["rb"],
        ["medium", "md", "ミディアム", "m"],
        ["semibold", "semi bold", "sb"],
        ["demibold", "demi bold", "db", "デミボールド", "demi", "d", "demixtra"],
        ["bold", "bd", "ボールド", "b"],
        ["extrabold", "extra bold", "xbold", "エクストラボールド", "e", "eb", "xb"],
        ["heavy", "h"],
        ["black"],
        ["xblack", "extra black", "extrablack"],
        ["ultra", "u", "ub", "ultra black", "ultrablack"],
    ]

    /// 単独で使われたら Regular 扱いにする幅・用途の語
    static let decorationOnlyStyles: Set<String> = [
        "display", "compressed", "comp", "compact", "expanded", "extended", "semiextended",
        "ultracondensed", "extracondensed", "semicondensed", "cond", "condensed", "wide",
        "headline", "text", "low", "micro", "extra compressed", "semi expanded", "semiexpanded",
    ]

    static let regularGroupIndex = weightGroups.firstIndex { $0.contains("regular") } ?? 12

    /// 長い語から順に照合する（同じ長さなら細いほうを先に）
    private static let termTable: [(term: String, group: Int)] = weightGroups.enumerated()
        .flatMap { group, terms in terms.map { (term: $0, group: group) } }
        .sorted { $0.term.count != $1.term.count ? $0.term.count > $1.term.count : $0.group < $1.group }

    private static let widthCompound = try! NSRegularExpression(
        pattern: "(^|\\s)(ultra|extra|semi)\\s+(condensed|cond|compressed|comp|expanded|extended)(?=\\s|$)")

    /// 小文字にし、_ と - を空白に
    static func normalize(_ style: String) -> String {
        style.lowercased().replacingOccurrences(of: "[_\\-]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// 語が英数字以外で区切られて入っているか（JSX の (?:^|[^a-z0-9])語(?=[^a-z0-9]|$) と同じ）
    private static func contains(_ text: String, _ term: String) -> Bool {
        var start = text.startIndex
        while let range = text.range(of: term, range: start..<text.endIndex) {
            let before = range.lowerBound == text.startIndex ? nil : text[text.index(before: range.lowerBound)]
            let after = range.upperBound == text.endIndex ? nil : text[range.upperBound]
            let isWordChar = { (c: Character?) in c.map { $0.isASCII && ($0.isLetter || $0.isNumber) } ?? false }
            if !isWordChar(before) && !isWordChar(after) { return true }
            start = text.index(after: range.lowerBound)
        }
        return false
    }

    static func weightGroupIndex(_ normalized: String) -> Int? {
        let range = NSRange(normalized.startIndex..., in: normalized)
        let style = widthCompound.stringByReplacingMatches(in: normalized, range: range, withTemplate: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        guard !style.isEmpty else { return nil }
        if let exact = weightGroups.firstIndex(where: { $0.contains(style) }) { return exact }
        return termTable.first { contains(style, $0.term) }?.group
    }

    /// W3・W600・25 Ultra Light のような数字の名前の数字
    static func numericWeight(_ normalized: String) -> Int? {
        guard let match = normalized.range(of: "^w?[0-9]{1,3}(?=[^0-9]|$)", options: .regularExpression) else { return nil }
        return Int(normalized[match].drop { $0 == "w" })
    }

    static func baseScore(_ normalized: String, postScriptName: String, family: String) -> Int {
        let words = normalized.split(separator: " ").map(String.init)
        let frutiger = family.range(of: "frutiger", options: .caseInsensitive) != nil && normalized.contains("ultralight")
        if let number = numericWeight(normalized) { return number }
        let ultraLightSpecial = ["helveticaneue", "tazugane", "universnextpro"].contains { postScriptName.contains($0) }
        if ultraLightSpecial && (normalized.contains("ultralight") || normalized.contains("ultra light") || normalized.contains("ultlt")) { return 999 }
        if words.count == 1 && ["italic", "oblique", "it", "wide"].contains(words[0]) { return 1000 + regularGroupIndex }
        if words.count == 1 && decorationOnlyStyles.contains(words[0]) { return 1000 + regularGroupIndex }
        if let group = weightGroupIndex(normalized) {
            return 1000 + group - (frutiger && group == 4 ? 5 : 0)
        }
        return 1000 + regularGroupIndex - (frutiger ? 5 : 0)
    }

    /// 点数の控え（PostScript名＋スタイル名ごと。3万書体で約0.3秒かかるので、一覧を作り直すたびに計算しない）
    nonisolated(unsafe) private static var cache: [String: Int] = [:]
    private static let cacheLock = NSLock()

    /// 並べ替えの点数（小さいほど先）
    static func score(_ face: FontFace) -> Int {
        let key = face.postScriptName + "\u{1F}" + face.style + "\u{1F}" + face.family
        cacheLock.lock()
        let cached = cache[key]
        cacheLock.unlock()
        if let cached { return cached }
        let value = computeScore(face)
        cacheLock.lock()
        cache[key] = value
        cacheLock.unlock()
        return value
    }

    private static func computeScore(_ face: FontFace) -> Int {
        let style = normalize(face.style)
        let postScriptName = face.postScriptName.lowercased()
        if postScriptName == "futurapt-heavy" { return 1015 }
        var score = baseScore(style, postScriptName: postScriptName, family: face.family.lowercased())
        let words = style.split(separator: " ").map(String.init)
        func has(_ word: String) -> Bool { words.contains(word) }
        func pair(_ first: String, _ second: String) -> Bool {
            zip(words, words.dropFirst()).contains { $0 == first && $1 == second }
        }
        let condensed = has("cond") || has("condensed")
        let cn = has("cn")
        let expanded = has("expanded") || has("semiexpanded") || pair("semi", "expanded")
        let extended = has("extended") || has("semiextended") || pair("semi", "extended")
        let ultraCondensed = has("ultracondensed") || pair("ultra", "condensed")
        let extraCondensed = has("extracondensed") || pair("extra", "condensed")
        let semiCondensed = has("semicondensed") || pair("semi", "condensed")
        let compressed = has("compressed") || has("comp")
        let extraCompressed = pair("extra", "compressed")
        let wide = has("wide")
        if has("display") { score += 100 }
        if compressed { score += 200 }
        if has("compact") { score += 300 }
        if expanded { score += 400 }
        if extended { score += 500 }
        if ultraCondensed { score += 600 }
        if extraCondensed { score += 700 }
        if semiCondensed { score += 850 }
        // Condensed 系はまとめて1回だけ
        if condensed || cn || wide || semiCondensed || extraCompressed { score += 900 }
        if has("headline") { score += 1000 }
        if has("text") { score += 1100 }
        if has("low") { score += 1200 }
        if has("micro") { score += 1250 }
        if wide { score += 1275 }
        if extraCompressed { score += 150 }
        if style.range(of: "italic|oblique|slanted|inclined|kursiv|\\bit\\b", options: .regularExpression) != nil { score += 1300 }
        return score
    }

    /// 書体を並べる
    static func sorted(_ faces: [(file: FontFile, face: FontFace)]) -> [(file: FontFile, face: FontFace)] {
        faces.map { (item: $0, score: score($0.face)) }
            .sorted { $0.score != $1.score ? $0.score < $1.score : $0.item.face.postScriptName < $1.item.face.postScriptName }
            .map(\.item)
    }

    /// ファイルを並べる（1つのファイルに書体が複数あるときは、いちばん細い書体の点数で）
    static func sorted(_ files: [FontFile]) -> [FontFile] {
        struct Key { let file: FontFile; let score: Int; let name: String }
        var keys: [Key] = []
        keys.reserveCapacity(files.count)
        for file in files {
            var bestScore = Int.max
            var bestName = file.fileName
            for face in file.faces {
                let value = score(face)
                if value < bestScore || (value == bestScore && face.postScriptName < bestName) {
                    bestScore = value
                    bestName = face.postScriptName
                }
            }
            keys.append(Key(file: file, score: bestScore, name: bestName))
        }
        keys.sort { left, right in
            if left.score != right.score { return left.score < right.score }
            if left.name != right.name { return left.name < right.name }
            return left.file.fileName < right.file.fileName
        }
        return keys.map(\.file)
    }
}
