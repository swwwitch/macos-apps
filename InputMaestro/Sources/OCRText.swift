import Foundation
enum OCRText {
    /// Removes horizontal spaces between two Japanese (non-ASCII) characters.
    static func joinJapanese(_ text: String) -> String {
        text.replacingOccurrences(of: #"(?<=[^\x00-\x7E])[ \t　]+(?=[^\x00-\x7E])"#, with: "", options: .regularExpression)
    }
    static func fullwidthParens(_ text: String) -> String {
        text.replacingOccurrences(of: "(", with: "（").replacingOccurrences(of: ")", with: "）")
    }
    static func clean(_ text: String, join: Bool, parens: Bool) -> String {
        var out = text
        if join { out = joinJapanese(out) }
        if parens { out = fullwidthParens(out) }
        return out
    }
}
