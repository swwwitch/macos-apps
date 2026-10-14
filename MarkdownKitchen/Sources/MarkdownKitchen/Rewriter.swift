import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 選択した文章を、指定の文字数に近づけて書き直す（Mac内のApple Intelligenceのモデル）。
/// 文字数は左下と同じ本文の数え方（TextStats.content）で、ずれが大きければ数回やり直して近いものを返す
enum Rewriter {
    /// 目標からこの割合以内なら、やり直さない
    static let tolerance = 0.1
    static let maxAttempts = 3

    /// 使えないときの理由（使えれば nil）
    @MainActor static var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.deviceNotEligible):
                return L("このMacはApple Intelligenceに対応していません。")
            case .unavailable(.appleIntelligenceNotEnabled):
                return L("システム設定の「Apple IntelligenceとSiri」で、Apple Intelligenceをオンにしてください。")
            case .unavailable(.modelNotReady):
                return L("Apple Intelligenceのモデルを準備しています。しばらくしてからお試しください。")
            case .unavailable:
                return L("Apple Intelligenceのモデルを使えません。")
            }
        }
        #endif
        return L("macOS 26以降とApple Intelligenceが必要です。")
    }

    static func count(_ text: String) -> Int { TextStats.content(text).characters }

    static func isClose(_ count: Int, to target: Int) -> Bool {
        Double(abs(count - target)) <= Double(target) * tolerance
    }

    #if canImport(FoundationModels)
    /// attempt：何回目を書いているか（1始まり）を知らせる
    @available(macOS 26, *)
    static func rewrite(_ text: String, target: Int, attempt report: @MainActor (Int) -> Void) async throws -> String {
        let current = count(text)
        var best: (text: String, count: Int)?
        for attempt in 1...maxAttempts {
            await report(attempt)
            // The prompt is always Japanese, like the instructions (it is not shown in the UI).
            var prompt = "次の文章を、約\(target)文字に書き直してください（いまは\(current)文字。文字数はMarkdownの記号・HTMLのタグ・改行を除いて数えます）。"
            if let best {
                prompt += "\n" + (best.count > target
                    ? "前回の書き直しは\(best.count)文字で、長すぎました。もっと短くしてください。"
                    : "前回の書き直しは\(best.count)文字で、短すぎました。もっと長くしてください。")
            }
            prompt += "\n\n" + text
            // A new session each time, so the transcript does not fill the context window.
            let session = LanguageModelSession(instructions: instructions)
            let output = clean(try await session.respond(to: prompt).content)
            let result = (text: output, count: count(output))
            if best == nil || abs(result.count - target) < abs(best!.count - target) { best = result }
            if isClose(result.count, to: target) { break }
        }
        return best?.text ?? text
    }

    private static let instructions = """
        あなたは文章の編集者です。渡された文章を、内容・要点・語調を保ったまま、指定の文字数に近づけて書き直します。
        元の文章と同じ言語で書きます。
        Markdownの記号（見出しの#、リストの-、太字の**、リンクなど）とHTMLのタグは、元の形を保ちます。
        書き直した文章だけを出力し、前置き・説明・引用符は付けません。
        """
    #endif

    /// 前後の空白と、全体を囲むコードブロックの記号を外す
    static func clean(_ output: String) -> String {
        var lines = output.normalizedLineBreaks.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        if lines.count >= 2, lines.first!.hasPrefix("```"), lines.last!.trimmingCharacters(in: .whitespaces) == "```" {
            lines.removeFirst()
            lines.removeLast()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
