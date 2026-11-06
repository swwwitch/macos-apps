import Foundation

/// Spellings of one word that the text alone cannot tie together, such as 下さい and ください.
struct DictionaryEntry: Equatable {
    enum Mode {
        /// Listed when two of the spellings are both used.
        case variants
        /// Listed as soon as a wrong spelling is found, even when the right one is not used yet.
        case correction
        /// Like a correction, but the word can be right in context: the user picks the target.
        case review
    }

    var spellings: [String]
    var mode: Mode
    /// The spelling to unify to. Variants of unknown preference have none.
    var target: String?
    /// The spellings that make a correction or review entry appear.
    var wrong: [String] = []

    var id: String {
        switch mode {
        case .variants: return "d:" + spellings.joined(separator: "|")
        case .correction: return "c:" + (target ?? spellings[0])
        case .review: return "r:" + (target ?? spellings[0])
        }
    }
}

enum VariantDictionary {
    /// Common Japanese variants. The first spelling follows the usual rule for official and press writing (function words in kana).
    /// Replacing goes from kanji to kana, because a short kana word can sit inside another word (こと in ことば).
    static let words: [[String]] = [
        ["ください", "下さい"], ["いただく", "頂く"], ["いただき", "頂き"], ["いただきます", "頂きます"], ["いただいた", "頂いた"],
        ["できる", "出来る"], ["できます", "出来ます"], ["できない", "出来ない"], ["できた", "出来た"], ["できて", "出来て"],
        ["こと", "事"], ["とき", "時"], ["ところ", "所"], ["ほか", "他"], ["など", "等"], ["ただし", "但し"], ["および", "及び"], ["または", "又は"],
        ["ならびに", "並びに"], ["したがって", "従って"], ["すでに", "既に"], ["さらに", "更に"], ["まず", "先ず"], ["あらかじめ", "予め"],
        ["おそらく", "恐らく"], ["たとえば", "例えば"], ["ぜひ", "是非"], ["よろしく", "宜しく"], ["ありがとう", "有難う", "有り難う"],
        ["お願い", "御願い"], ["ご確認", "御確認"], ["ご連絡", "御連絡"], ["わかる", "分かる", "解る"], ["わかりやすい", "分かりやすい", "分り易い"],
        ["スマートフォン", "スマホ"], ["アプリ", "アプリケーション"],
    ]
    /// Full-width and half-width symbols.
    static let symbols: [[String]] = [["：", ":"], ["？", "?"], ["！", "!"], ["（", "("], ["）", ")"], ["％", "%"], ["＆", "&"], ["〜", "～"]]

    static let bundled: [DictionaryEntry] = merged(
        words.map { DictionaryEntry(spellings: $0, mode: .variants, target: $0[0]) }
        + symbols.map { DictionaryEntry(spellings: $0, mode: .variants, target: nil) }
        + lines(DictionaryData.text, prefersFirst: false))

    /// 「誤 → 正」 or 「誤<tab>正」, 「? 誤 → 正」, or 「A、B」. Several right spellings: the first is the target.
    private static func lines(_ text: String, prefersFirst: Bool) -> [DictionaryEntry] {
        func names(_ part: Substring) -> [String] {
            part.split(whereSeparator: { ",、，".contains($0) }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        return text.split(whereSeparator: \.isNewline).compactMap { raw in
            var line = raw.drop(while: \.isWhitespace)
            let isReview = line.hasPrefix("?") || line.hasPrefix("？")
            if isReview { line = line.dropFirst() }
            if let arrow = line.firstIndex(where: { "→\t".contains($0) }) {
                let wrong = names(line[..<arrow]), right = names(line[line.index(after: arrow)...])
                guard !wrong.isEmpty else { return nil }
                return DictionaryEntry(spellings: wrong + right, mode: isReview ? .review : .correction, target: right.first, wrong: wrong)
            }
            let spellings = names(line)
            if isReview, !spellings.isEmpty { return DictionaryEntry(spellings: spellings, mode: .review, target: nil, wrong: spellings) }
            return Set(spellings).count >= 2 ? DictionaryEntry(spellings: spellings, mode: .variants, target: prefersFirst ? spellings[0] : nil) : nil
        }
    }

    /// Entries with one target become one group; plain variants that only repeat a correction go.
    private static func merged(_ entries: [DictionaryEntry]) -> [DictionaryEntry] {
        var result: [DictionaryEntry] = []
        var indexOfID: [String: Int] = [:]
        for entry in entries {
            if let index = indexOfID[entry.id] {
                result[index].wrong += entry.wrong.filter { !result[index].wrong.contains($0) }
                result[index].spellings += entry.spellings.filter { !result[index].spellings.contains($0) }
            } else {
                indexOfID[entry.id] = result.count
                result.append(entry)
            }
        }
        let fixed = result.filter { $0.mode != .variants }.map { Set($0.spellings) }
        return result.filter { entry in entry.mode != .variants || !fixed.contains(Set(entry.spellings)) }
    }

    /// The user's own dictionary, in the same format. Without an arrow, the first spelling is the recommended one.
    static func parse(_ text: String) -> [DictionaryEntry] { merged(lines(text, prefersFirst: true)) }
}

/// The variant list as a table for spreadsheets and proofreading notes (tab-separated).
enum VariantExport {
    static func table(_ groups: [VariantGroup], header: [String], preferred: (VariantGroup) -> String?) -> String {
        var lines = [header.joined(separator: "\t")]
        for (number, group) in groups.enumerated() {
            let target = preferred(group)
            for spelling in group.spellings {
                lines.append(["\(number + 1)", spelling.text, "\(spelling.count)", spelling.text == target ? "◉" : ""].joined(separator: "\t"))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
