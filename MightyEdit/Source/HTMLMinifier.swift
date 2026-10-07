import Foundation

/// Conservative text/html minifier. Unknown markup and whitespace-sensitive regions stay intact.
enum HTMLMinifier {
    private struct Token {
        var text: String
        var name: String = ""
        var closing = false
        var protected = false
        var isText = false
    }
    private static let spaces = CharacterSet(charactersIn: " \t\r\n\u{000C}")
    private static let blocks = Set("html head body div section article aside header footer main nav p ul ol li dl dt dd table thead tbody tfoot tr td th caption colgroup h1 h2 h3 h4 h5 h6 blockquote form fieldset figure figcaption hr pre".split(separator: " ").map(String.init))
    private static let protectedNames = Set(["pre", "svg", "math"])
    private static let rawNames = Set(["script", "style", "textarea", "title", "xmp", "iframe", "noembed", "noframes"])
    private static let voids = Set("area base br col embed hr img input link meta source track wbr".split(separator: " ").map(String.init))
    private static func regex(_ pattern: String) -> NSRegularExpression { try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) }
    private static func collapse(_ value: String) -> String { value.replacingOccurrences(of: "[ \\t\\r\\n\\x{000C}]+", with: " ", options: .regularExpression) }

    private static func tokenize(_ input: String, compact: Bool) -> [Token]? {
        // XML/XHTML and server-side templates have different syntax rules.
        if input.contains("<?") || input.contains("<%") { return nil }
        let source = input as NSString
        let scanner = regex(#"<!--[\s\S]*?-->|<!\[CDATA\[[\s\S]*?\]\]>|<![^>]*>|</?[a-z][a-z0-9:_-]*(?:[^>"']|"[^"]*"|'[^']*')*>|[^<]+|<"#)
        let namePattern = regex(#"^</?([a-z][a-z0-9:_-]*)"#)
        var tokens: [Token] = []
        var position = 0
        var protectedStack: [String] = []
        while position < source.length {
            guard let match = scanner.firstMatch(in: input, range: NSRange(location: position, length: source.length-position)), match.range.location == position else { return nil }
            let text = source.substring(with: match.range)
            position = NSMaxRange(match.range)
            if text == "<" { return nil } // Incomplete/ambiguous markup: leave the selection unchanged.
            var token = Token(text: text, protected: !protectedStack.isEmpty)
            if text.hasPrefix("<!--") {
                let lower = text.lowercased()
                if !compact || token.protected || lower.contains("[if") || lower.contains("[endif") || lower.hasPrefix("<!--!") || lower.hasPrefix("<!--#") { tokens.append(token) }
                continue
            }
            if let nameMatch = namePattern.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) {
                token.name = (text as NSString).substring(with: nameMatch.range(at: 1)).lowercased()
                token.closing = text.hasPrefix("</")
                if token.name == "plaintext" { return nil }
                if rawNames.contains(token.name) && !token.closing {
                    let end = regex("</" + token.name + "[ \\t\\r\\n]*>")
                    guard let close = end.firstMatch(in: input, range: NSRange(location: position, length: source.length-position)) else { return nil }
                    token.text = (token.protected || !compact ? text : compactTag(text, name: token.name)) + source.substring(with: NSRange(location: position, length: NSMaxRange(close.range)-position))
                    token.protected = true
                    position = NSMaxRange(close.range)
                } else if protectedNames.contains(token.name) {
                    token.protected = true
                    if token.closing {
                        guard protectedStack.last == token.name else { return nil }
                        protectedStack.removeLast()
                    } else if !text.hasSuffix("/>") { protectedStack.append(token.name) }
                }
                if compact && !token.protected && !token.closing { token.text = compactTag(text, name: token.name) }
            } else if !text.hasPrefix("<!") {
                token.isText = true
            }
            if token.isText, !token.protected, let last = tokens.last, last.isText && !last.protected {
                tokens[tokens.count-1].text += token.text
            } else { tokens.append(token) }
        }
        guard protectedStack.isEmpty else { return nil }
        return tokens
    }

    static func minify(_ input: String) -> String {
        guard var tokens = tokenize(input, compact: true) else { return input }
        for i in tokens.indices where tokens[i].isText && !tokens[i].protected {
            tokens[i].text = collapse(tokens[i].text)
            if tokens[i].text == " ", i > 0, i + 1 < tokens.count,
               blocks.contains(tokens[i-1].name), blocks.contains(tokens[i+1].name) { tokens[i].text = "" }
        }
        tokens.removeAll { $0.text.isEmpty }
        for i in tokens.indices where tokens[i].closing && !tokens[i].protected {
            guard i + 1 < tokens.count else {
                if ["html", "body", "head"].contains(tokens[i].name) { tokens[i].text = "" }
                continue
            }
            let next = tokens[i+1]
            if omitEnd(tokens[i].name, next: next) { tokens[i].text = "" }
        }
        return tokens.map(\.text).joined()
    }

    /// Format structural boundaries only; never split inline text or raw contents.
    static func beautify(_ input: String) -> String {
        guard var tokens = tokenize(input, compact: false), !tokens.isEmpty else { return input }
        let structural = blocks.union(["script", "style", "title", "meta", "link", "!doctype"])
        func boundary(_ token: Token) -> Bool {
            structural.contains(token.name) || token.text.lowercased().hasPrefix("<!doctype")
        }
        // Replace existing indentation only where we are allowed to introduce it.
        for i in tokens.indices where tokens[i].isText && !tokens[i].protected {
            if tokens[i].text.trimmingCharacters(in: spaces).isEmpty,
               i > 0, i + 1 < tokens.count, boundary(tokens[i-1]), boundary(tokens[i+1]) {
                tokens[i].text = ""
            }
        }
        tokens.removeAll { $0.text.isEmpty }
        var stack: [String] = []
        var output = ""
        var previous: Token?
        var protectedDepth = 0
        for token in tokens {
            let isBoundary = boundary(token)
            // pre/svg/math are tokenized internally but their interior must stay byte-for-byte intact.
            let insideProtected = protectedDepth > 0
            if token.closing, protectedNames.contains(token.name) { protectedDepth = max(0, protectedDepth - 1) }
            var implicitBoundary = false
            if token.closing, let index = stack.lastIndex(of: token.name), !insideProtected {
                implicitBoundary = index < stack.count - 1
                stack.removeSubrange(index...)
            }
            if !token.closing && !insideProtected {
                let implied: [String: Set<String>] = ["li": ["li"], "dt": ["dt", "dd"], "dd": ["dt", "dd"], "p": ["p"], "tr": ["tr"], "td": ["td", "th"], "th": ["td", "th"]]
                if let names = implied[token.name], let last = stack.last, names.contains(last) { stack.removeLast(); implicitBoundary = true }
            }
            if let previous, isBoundary && (boundary(previous) || implicitBoundary) && !insideProtected {
                if implicitBoundary { output = output.replacingOccurrences(of: "[ \t\r\n]+$", with: "", options: .regularExpression) }
                output += "\n" + String(repeating: "  ", count: stack.count)
            }
            output += token.text
            if !token.closing && isBoundary && !voids.contains(token.name) && !token.protected && !token.name.isEmpty {
                stack.append(token.name)
            }
            if !token.closing, protectedNames.contains(token.name), !token.text.hasSuffix("/>") { protectedDepth += 1 }
            previous = token
        }
        return output
    }

    private static func omitEnd(_ name: String, next: Token) -> Bool {
        if ["html", "body"].contains(name) { return !next.text.hasPrefix("<!--") }
        if name == "head" { return !next.isText && !next.text.hasPrefix("<!--") }
        guard !next.name.isEmpty, !next.protected else { return false }
        if !next.closing {
            switch name {
            case "li": return next.name == "li"
            case "dt", "dd": return ["dt", "dd"].contains(next.name)
            case "rt", "rp": return ["rt", "rp"].contains(next.name)
            case "option": return ["option", "optgroup", "hr"].contains(next.name)
            case "optgroup": return next.name == "optgroup"
            case "thead": return ["tbody", "tfoot"].contains(next.name)
            case "tbody": return ["tbody", "tfoot"].contains(next.name)
            case "tr": return next.name == "tr"
            case "td", "th": return ["td", "th"].contains(next.name)
            case "p": return Set("address article aside blockquote details dialog div dl fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6 header hgroup hr main menu nav ol p pre search section table ul".split(separator: " ").map(String.init)).contains(next.name)
            default: return false
            }
        }
        switch name {
        case "li": return ["ul", "ol", "menu"].contains(next.name)
        case "dd": return next.name == "dl"
        case "rt", "rp": return next.name == "ruby"
        case "option": return ["select", "datalist", "optgroup"].contains(next.name)
        case "optgroup": return next.name == "select"
        case "tbody", "tfoot": return next.name == "table"
        case "tr": return ["thead", "tbody", "tfoot", "table"].contains(next.name)
        case "td", "th": return next.name == "tr"
        // Only known valid parents; never omit before an inline/custom-element parent.
        case "p": return ["div", "section", "article", "aside", "main", "body", "li", "td", "th", "blockquote", "form"].contains(next.name)
        default: return false
        }
    }

    private static func compactTag(_ tag: String, name: String) -> String {
        // Preserve custom elements and template expressions without interpreting their attributes.
        if name.contains("-") || tag.contains("{{") || tag.contains("${") { return tag }
        let ns = tag as NSString
        let head = regex(#"^<[a-z][a-z0-9:_-]*"#).firstMatch(in: tag, range: NSRange(location: 0, length: ns.length))!
        var cursor = NSMaxRange(head.range)
        var result = ns.substring(with: head.range)
        let attr = regex(#"[ \t\r\n\f]+([^\s=/'"<>`]+)(?:[ \t\r\n\f]*=[ \t\r\n\f]*("[^"]*"|'[^']*'|[^\s"'=<>`]+))?"#)
        while cursor < ns.length {
            let rest = ns.substring(from: cursor)
            if rest.trimmingCharacters(in: spaces) == ">" { return result + ">" }
            if rest.trimmingCharacters(in: spaces) == "/>" { return result + " />" }
            guard let match = attr.firstMatch(in: tag, range: NSRange(location: cursor, length: ns.length-cursor)), match.range.location == cursor else { return tag }
            let attrName = ns.substring(with: match.range(at: 1))
            result += " " + attrName
            if match.range(at: 2).location != NSNotFound {
                let original = ns.substring(with: match.range(at: 2))
                let quoted = original.first == "\"" || original.first == "'"
                let value = quoted ? String(original.dropFirst().dropLast()) : original
                if !booleanAttribute(attrName.lowercased(), on: name) {
                    let unsafe = CharacterSet(charactersIn: " \t\r\n\u{000C}\"'`=<> &")
                    let unquote = quoted && !value.isEmpty && value.rangeOfCharacter(from: unsafe) == nil && !value.hasSuffix("/")
                    result += "=" + (unquote ? value : original)
                }
            }
            cursor = NSMaxRange(match.range)
        }
        return tag
    }

    private static func booleanAttribute(_ attribute: String, on tag: String) -> Bool {
        if ["itemscope", "inert", "autofocus"].contains(attribute) { return true }
        let tags: [String: Set<String>] = [
            "disabled": ["button", "fieldset", "input", "optgroup", "option", "select", "textarea"],
            "checked": ["input"], "readonly": ["input", "textarea"], "required": ["input", "select", "textarea"],
            "multiple": ["input", "select"], "selected": ["option"], "ismap": ["img"],
            "async": ["script"], "defer": ["script"], "nomodule": ["script"],
            "autoplay": ["audio", "video"], "controls": ["audio", "video"], "loop": ["audio", "video"], "muted": ["audio", "video"], "playsinline": ["video"],
            "open": ["details", "dialog"], "reversed": ["ol"], "novalidate": ["form"], "formnovalidate": ["button", "input"], "default": ["track"]
        ]
        return tags[attribute]?.contains(tag) ?? false
    }
}
