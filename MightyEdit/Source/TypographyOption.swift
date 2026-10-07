import Foundation

enum TypographyOption: Int, CaseIterable {
    case narrowAlphanumerics, widenKana, removeJapaneseSpaces, trimBracketSpaces
    case timeColon, parentheticalPeriod, correctLongVowel, widenPunctuation

    static var savedOptions: [Self] {
        guard let saved = UserDefaults.standard.array(forKey: "specialTypographyOptions") as? [Int] else { return allCases }
        return allCases.filter { saved.contains($0.rawValue) }
    }

    var title: String {
        switch self {
        case .narrowAlphanumerics: return L("typo.narrowAlphanumerics")
        case .widenKana: return L("typo.widenKana")
        case .removeJapaneseSpaces: return L("typo.removeJapaneseSpaces")
        case .trimBracketSpaces: return L("typo.trimBracketSpaces")
        case .timeColon: return L("typo.timeColon")
        case .parentheticalPeriod: return L("typo.parentheticalPeriod")
        case .correctLongVowel: return L("typo.correctLongVowel")
        case .widenPunctuation: return L("typo.widenPunctuation")
        }
    }

    static func applyAll(_ text: String, options: [Self]) -> String {
        // Normalize punctuation before rules that inspect brackets and sentence endings.
        let order: [Self] = [.narrowAlphanumerics, .widenKana, .widenPunctuation, .removeJapaneseSpaces,
                             .trimBracketSpaces, .timeColon, .parentheticalPeriod, .correctLongVowel]
        return order.filter { options.contains($0) }.reduce(text) { $1.apply($0) }
    }

    func apply(_ text: String) -> String {
        switch self {
        case .narrowAlphanumerics: return TextTransform.narrowAlphanumerics.apply(text)
        case .removeJapaneseSpaces: return TextTransform.removeJapaneseSpaces.apply(text)
        case .widenKana:
            // Keep halfwidth punctuation under its own checkbox's control.
            return Self.replacingMatches(text, pattern: #"[\uFF66-\uFF9F]+"#) { TextTransform.widenKana.apply($0) }
        case .trimBracketSpaces:
            return text.replacingOccurrences(of: #"(?<=[(\[{（［｛「｢『【〈《〔〖〘〚])[ \t\u3000]+|[ \t\u3000]+(?=[)\]}）］｝」｣』】〉》〕〗〙〛])"#, with: "", options: .regularExpression)
        case .timeColon:
            return Self.replacingMatches(text, pattern: #"(?<![0-9０-９:：])[0-9０-９]{1,2}：[0-9０-９]{2}(?:[：:][0-9０-９]{2})?(?![0-9０-９:：])|(?<![0-9０-９:：])[0-9０-９]{1,2}:[0-9０-９]{2}：[0-9０-９]{2}(?![0-9０-９:：])"#) { token in
                let normalized = TextTransform.narrowAlphanumerics.apply(token).replacingOccurrences(of: "：", with: ":")
                let numbers = normalized.split(separator: ":").compactMap { Int($0) }
                guard (2...3).contains(numbers.count), (0...23).contains(numbers[0]), (0...59).contains(numbers[1]), numbers.count < 3 || (0...59).contains(numbers[2]) else { return token }
                return token.replacingOccurrences(of: "：", with: ":")
            }
        case .parentheticalPeriod:
            let characters = Array(text)
            var stack: [(index: Int, close: Character)] = []
            var remove = Set<Int>()
            for (index, character) in characters.enumerated() {
                if character.unicodeScalars.contains(where: { CharacterSet.newlines.contains($0) }) { stack.removeAll(); continue }
                if character == "（" || character == "(" {
                    stack.append((index, character == "（" ? "）" : ")"))
                } else if character == "）" || character == ")" {
                    guard let open = stack.popLast(), open.close == character else { stack.removeAll(); continue }
                    if open.index > 0, index > open.index + 1, index + 1 < characters.count,
                       characters[open.index - 1] == "。", characters[index + 1] == "。" {
                        remove.insert(open.index - 1)
                    }
                }
            }
            return String(characters.enumerated().filter { !remove.contains($0.offset) }.map(\.element))
        case .correctLongVowel:
            return text.replacingOccurrences(of: #"(?<=([ァ-ヶ]))[-‐‑–—―−ｰ─]"#, with: "ー", options: .regularExpression)
        case .widenPunctuation:
            let map: [Character: Character] = ["｡": "。", "､": "、", "(": "（", ")": "）", "｢": "「", "｣": "」"]
            return String(text.map { map[$0] ?? $0 })
        }
    }

    private static func replacingMatches(_ text: String, pattern: String, replacement: (String) -> String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern)
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: replacement((text as NSString).substring(with: match.range)))
            }
        }
        return result
    }
}
