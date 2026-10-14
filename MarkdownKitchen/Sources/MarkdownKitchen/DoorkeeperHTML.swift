import Foundation

/// 「Doorkeeper用に整形」の色の組。設定で追加・編集する
struct DoorkeeperPreset: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    /// 基本カラー（#0AF・#993366 のような16進）。入力どおりに書き出す
    var color: String
    /// h3の淡い背景の濃さ（%）
    var tintPercent: Int

    static let defaults = [
        DoorkeeperPreset(name: "CSS Nite", color: "#0AF", tintPercent: 30),
        DoorkeeperPreset(name: "DTP Transit", color: "#993366", tintPercent: 20),
    ]
}

/// Markdownの見出し（## と ###）を、Doorkeeperのイベント説明で使う装飾付きのHTML見出しに置き換える。
/// 本文や #### 以下の見出し、すでにHTMLの見出しはそのまま
enum DoorkeeperHTML {
    /// "#0AF"・"#993366" を 0〜255 のRGBにする。読めなければnil
    static func rgb(_ hex: String) -> (Int, Int, Int)? {
        var digits = hex.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        return (value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
    }

    /// 見出しレベルごとのstyle属性。基本カラーが読めなければnil
    static func styles(for preset: DoorkeeperPreset) -> [Int: String]? {
        guard let (r, g, b) = rgb(preset.color) else { return nil }
        let color = preset.color.trimmingCharacters(in: .whitespaces)
        let alpha = Double(min(max(preset.tintPercent, 0), 100)) / 100
        let tint = "rgba(\(r), \(g), \(b), \(String(format: "%g", alpha)))"
        return [
            2: "margin-top: 2em; border-bottom: none; font-size: 1.5em;background-color:\(color); color:#fff; padding: 10px 20px; border-radius: 5px;",
            3: "color:\(color); background-color:\(tint); font-size: 1.2em; line-height: 1.2; margin-top: 2.2em; padding: .5em 1em; border-left: 2px solid \(color); border-bottom: 2px solid \(color); border-bottom-left-radius: 6px;",
        ]
    }

    /// Markdownの見出しを変換し、テーマで整形済みのHTML見出し（色だけ異なる同じ装飾）は style だけ差し替える
    static func convert(_ text: String, styles: [Int: String]) -> String {
        let string = NSMutableString(string: text)
        let source = text as NSString
        // Back to front so earlier ranges stay valid.
        for heading in HeadingParser.headings(in: text).reversed() {
            guard let style = styles[heading.level] else { continue }
            if heading.htmlLevelDigits != nil {
                // Already themed: swap the opening tag's style, keep the contents and closing tag.
                let line = source.substring(with: heading.range) as NSString
                guard let tag = openingTag.firstMatch(in: line as String, range: NSRange(location: 0, length: line.length)),
                      let current = attribute("style", in: line.substring(with: tag.range)),
                      normalized(current) == normalized(style) else { continue }
                let range = NSRange(location: heading.range.location + tag.range.location, length: tag.range.length)
                string.replaceCharacters(in: range, with: "<h\(heading.level) style=\"\(style)\">")
                continue
            }
            let end = NSMaxRange(heading.underline ?? heading.range)
            let html = "<h\(heading.level) style=\"\(style)\">\(heading.title)</h\(heading.level)>"
            string.replaceCharacters(in: NSRange(location: heading.range.location, length: end - heading.range.location), with: html)
        }
        return string as String
    }

    private static let openingTag = try! NSRegularExpression(pattern: #"<h[1-6]\b[^>]*>"#, options: .caseInsensitive)

    private static func attribute(_ name: String, in tag: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: name + #"\s*=\s*"([^"]*)""#, options: .caseInsensitive),
              let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: (tag as NSString).length)) else { return nil }
        return (tag as NSString).substring(with: match.range(at: 1))
    }

    /// 色（#0AF・rgb()・rgba()）を伏せ、空白と大文字小文字の違いを無視した形。テーマの装飾かどうかの判定に使う
    static func normalized(_ style: String) -> String {
        style.replacingOccurrences(of: #"#[0-9A-Fa-f]{3,8}\b|rgba?\([^)]*\)"#, with: "C", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            .lowercased()
    }
}
