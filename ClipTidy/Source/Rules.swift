import Foundation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// One rewrite of the copied text. A rule runs when its condition matches (or has none) and its search finds something.
struct Rule: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var enabled = true
    /// Regular expression that must match somewhere in the text. Empty: no extra condition.
    var condition = ""
    var find: String
    var replace: String
    var isRegex = true
    var caseSensitive = true
    /// Only when this app was in front at the time of copying. nil: any app.
    var appBundleID: String?
    var appName: String?
    /// Show the result near the top of the screen after rewriting.
    var announce = false

    /// Regex replacement template. Accepts \1 as well as $1, and \n / \t for a line break / tab.
    static func template(_ replace: String) -> String {
        var out = "", chars = Array(replace), i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\\", i + 1 < chars.count {
                let next = chars[i + 1]
                switch next {
                case "n": out += "\n"
                case "t": out += "\t"
                case "r": out += "\r"
                case _ where next.isASCII && next.isNumber: out += "$\(next)"
                case "$": out += "\\$"
                default: out += "\\\\" + (next == "\\" ? "" : String(next))
                }
                i += 2; continue
            }
            out.append(c); i += 1
        }
        return out
    }

    /// The rewritten text, or nil when the rule does not apply. Throws when a pattern is invalid.
    func apply(to text: String, frontApp: String?) throws -> String? {
        guard enabled else { return nil }
        if let appBundleID, appBundleID.caseInsensitiveCompare(frontApp ?? "") != .orderedSame { return nil }
        let range = NSRange(text.startIndex..., in: text)
        if !condition.isEmpty {
            let test = try NSRegularExpression(pattern: condition, options: caseSensitive ? [] : [.caseInsensitive])
            guard test.firstMatch(in: text, range: range) != nil else { return nil }
        }
        guard !find.isEmpty else { return nil }
        let pattern = isRegex ? find : NSRegularExpression.escapedPattern(for: find)
        let regex = try NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive])
        guard regex.firstMatch(in: text, range: range) != nil else { return nil }
        let template = isRegex ? Rule.template(replace) : NSRegularExpression.escapedTemplate(for: replace)
        let result = regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
        return result == text ? nil : result
    }

    /// Error text for an invalid pattern, or nil.
    var patternError: String? {
        for (label, pattern) in [(L("rule.condition"), condition), (L("rule.find"), isRegex ? find : "")] where !pattern.isEmpty {
            do { _ = try NSRegularExpression(pattern: pattern) } catch { return String(format: L("rule.invalid"), label) }
        }
        return nil
    }

    /// First-launch rules.
    static var defaults: [Rule] {
        [
            Rule(name: L("preset.vimeo"), condition: #"https:\/\/vimeo.com\/"#, find: "&fl=sv&fe=ci", replace: "", caseSensitive: false),
            Rule(name: L("preset.vimeoShare"), condition: "vimeo.com", find: #"\?share=copy"#, replace: ""),
            Rule(name: L("preset.facebook"), condition: "facebook.com", find: #"\?acontext(.+)"#, replace: ""),
            Rule(name: L("preset.mailto"), condition: "^mailto:", find: "mailto:", replace: "", isRegex: false),
            Rule(name: L("preset.twitter"), find: "https://mobile.twitter.com/", replace: "https://twitter.com/", isRegex: false, caseSensitive: false),
            Rule(name: L("preset.notion"), condition: #"https:\/\/swwwitch.notion.site\/"#,
                 find: #"(https?://[^/]+\.notion\.site/).*-\d{4}-\d{1,2}-\d{1,2}-([a-f0-9]{32})(?:\?[^\s]*)?"#, replace: "$1$2",
                 appBundleID: "org.mozilla.firefox", appName: "Firefox"),
            Rule(name: L("preset.letao"),
                 condition: #"入力期限:\d+\/\d+\/\d+\n※ご注文者様のご依頼により、小樽洋菓子舗ルタオからギフトをお届けいたします。ＵＲＬをクリックし配送先のご設定をお願いいたします。"#,
                 find: #"入力期限:(\d+\/\d+\/\d+)\n※ご注文者様のご依頼により、小樽洋菓子舗ルタオからギフトをお届けいたします。ＵＲＬをクリックし配送先のご設定をお願いいたします。\nhttps:\/\/www.letao.jp\/letao_send_info_input.html\?(.+)"#,
                 replace: #"小樽洋菓子舗ルタオからギフトをお届けします。\nURLをクリックして配送先のご設定をお願いします。\n（入力期限：\1）\nhttps://www.letao.jp/letao_send_info_input.html?\2"#,
                 announce: true),
        ]
    }
}

struct RuleOutcome: Equatable {
    var text: String
    var applied: [String]
    var errors: [String]
}

enum RuleEngine {
    /// Runs the enabled rules from top to bottom; each one sees the previous result.
    static func run(_ rules: [Rule], on text: String, frontApp: String?) -> RuleOutcome {
        var current = text, applied: [String] = [], errors: [String] = []
        for rule in rules where rule.enabled {
            do {
                if let next = try rule.apply(to: current, frontApp: frontApp) { current = next; applied.append(rule.name) }
            } catch { errors.append(rule.name) }
        }
        return RuleOutcome(text: current, applied: applied, errors: errors)
    }
}

/// Dropbox shared links that end in dl=0 (ready to share, not yet a direct download).
enum DropboxLink {
    static func isShareLink(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: "dropbox.com", options: .caseInsensitive) != nil && trimmed.range(of: #"(.+)&dl=0$"#, options: .regularExpression) != nil
    }
    /// dl=0 at the end becomes dl=1.
    static func direct(_ text: String) -> String {
        text.replacingOccurrences(of: #"dl=0(\s*)$"#, with: "dl=1$1", options: .regularExpression)
    }
    /// File or folder name from the link path (/scl/fi/<id>/<name>?…, /scl/fo/… is a folder).
    static func item(_ text: String) -> (name: String, isFolder: Bool)? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let last = parts.last, parts.count >= 2 else { return nil }
        let isFolder = parts.contains("fo") || (parts.first == "sh")
        return (last.removingPercentEncoding ?? last, isFolder)
    }
}
