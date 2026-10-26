import Foundation

/// UI categories intentionally overlap. Block ranges follow Unicode Blocks.txt;
/// general categories and emoji properties come from the OS Swift Unicode data.
enum GlyphScope: CaseIterable {
    case all, withUnicode, withoutUnicode
    case hiragana, katakana, emoji, enclosed, bullets, brackets, kanji, punctuation
    case pictographs, math, numbers, currency, kana, signs, letterlike, arrows

    var title: String {
        switch self {
        case .all: return L("すべての字形")
        case .withUnicode: return L("Unicodeあり")
        case .withoutUnicode: return L("Unicodeなし")
        case .hiragana: return L("ひらがな")
        case .katakana: return L("カタカナ")
        case .emoji: return L("絵文字")
        case .enclosed: return L("囲み文字")
        case .bullets: return L("箇条書きと星")
        case .brackets: return L("括弧/引用符")
        case .kanji: return L("漢字")
        case .punctuation: return L("句読点")
        case .pictographs: return L("象形文字")
        case .math: return L("数学記号")
        case .numbers: return L("数字")
        case .currency: return L("通貨記号")
        case .kana: return L("日本語かな")
        case .signs: return L("標識と標準記号")
        case .letterlike: return L("文字様記号")
        case .arrows: return L("矢印")
        }
    }

    func includes(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        func within(_ ranges: ClosedRange<UInt32>...) -> Bool { ranges.contains { $0.contains(v) } }
        let category = scalar.properties.generalCategory
        switch self {
        case .all, .withUnicode: return true
        case .withoutUnicode: return false
        case .hiragana:
            return within(0x3040...0x309F, 0x1B001...0x1B11F, 0x1B132...0x1B132, 0x1B150...0x1B152)
        case .katakana:
            return within(0x30A0...0x30FF, 0x31F0...0x31FF, 0xFF66...0xFF9F,
                          0x1B000...0x1B000, 0x1B120...0x1B122, 0x1B155...0x1B155, 0x1B164...0x1B167)
        case .emoji:
            return scalar.properties.isEmoji && (scalar.properties.isEmojiPresentation || v > 0xFF)
        case .enclosed:
            return within(0x2460...0x24FF, 0x3200...0x32FF, 0x1F100...0x1F2FF)
        case .bullets:
            return within(0x2022...0x2023, 0x2043...0x2043, 0x204C...0x204D, 0x2219...0x2219,
                          0x25A0...0x25FF, 0x2605...0x2606, 0x2726...0x274B, 0x2B50...0x2B54)
        case .brackets:
            return [.openPunctuation, .closePunctuation, .initialPunctuation, .finalPunctuation].contains(category)
                || v == 0x22 || v == 0x27 || v == 0xFF02 || v == 0xFF07
        case .kanji:
            return within(0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2FA1F, 0x30000...0x3347F)
        case .punctuation:
            return [.connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
                    .initialPunctuation, .finalPunctuation, .otherPunctuation].contains(category)
        case .pictographs:
            return within(0x2600...0x26FF, 0x1F300...0x1FAFF, 0x13000...0x1345F, 0x13460...0x143FF)
        case .math:
            return category == .mathSymbol || within(0x2200...0x22FF, 0x27C0...0x27EF, 0x2980...0x2AFF, 0x1D400...0x1D7FF)
        case .numbers:
            return [.decimalNumber, .letterNumber, .otherNumber].contains(category)
        case .currency: return category == .currencySymbol
        case .kana: return Self.hiragana.includes(scalar) || Self.katakana.includes(scalar)
        case .signs:
            return within(0x2300...0x23FF, 0x2400...0x245F, 0x2600...0x26FF, 0x2700...0x27BF, 0x1F680...0x1F6FF)
        case .letterlike: return within(0x2100...0x214F)
        case .arrows: return within(0x2190...0x21FF, 0x27F0...0x27FF, 0x2900...0x297F, 0x2B00...0x2B11, 0x2B30...0x2B4C, 0x1F800...0x1F8FF)
        }
    }
}
