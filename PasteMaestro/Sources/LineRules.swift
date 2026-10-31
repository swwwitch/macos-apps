import Foundation

/// The 整形 group of the KM macro 「01)連続ペースト」, in the same order. Foundation-only for Tests/Rules.
enum LineRules {
    /// スペースやタブだけの行・行頭の空白（ICU の \s は全角スペースも含む）。
    static let leadingSpace = #"(?m)^\s+"#
    /// 行頭の「・」「* 」「- 」「1. 」「①」の順。
    static let markers = [
        #"(?m)^・"#,
        #"(?m)^\*\s"#,
        #"(?m)^-\s"#,
        #"(?m)^\d+\.\s?"#,
        #"(?m)^[①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳㉑㉒㉓㉔㉕㉖㉗㉘㉙㉚㉛㉜㉝㉞㉟㊱㊲㊳㊴㊵㊶㊷㊸㊹㊺㊻㊼㊽㊾㊿]\s?"#
    ]

    /// Lines to paste, top to bottom. Blank lines are always skipped (the macro's 空行を削除).
    static func lines(from text: String, trimIndent: Bool, stripMarkers: Bool) -> [String] {
        var text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var patterns: [String] = []
        if trimIndent { patterns.append(leadingSpace) }
        if stripMarkers { patterns += markers }
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        return text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
