import Foundation

enum HTMLFormatting: String, CaseIterable {
    case standard, minify, beautify

    /// Conservative HTML formatting. Text nodes, comments and raw/preformatted elements remain untouched.
    func apply(to html:String) -> String {
        guard self != .standard else { return html }
        struct Token {
            var text:String
            var name:String = ""
            var closing = false
            var special = false
            var tag = false
            var selfClosing = false
        }
        let blocks = Set(["html","head","body","section","article","nav","aside","header","footer","main","div","p","h1","h2","h3","h4","h5","h6","ul","ol","li","dl","dt","dd","table","thead","tbody","tfoot","tr","td","th","figure","figcaption","blockquote","hr","meta","link","title","pre","script","style"])
        let voids = Set(["area","base","br","col","embed","hr","img","input","link","meta","param","source","track","wbr"])
        let protected = Set(["pre","textarea","script","style","code","svg","math","title"])
        var tokens:[Token] = []; var cursor = html.startIndex
        while cursor < html.endIndex {
            if html[cursor] != "<" {
                let end = html[cursor...].firstIndex(of:"<") ?? html.endIndex
                tokens.append(Token(text:String(html[cursor..<end]))); cursor = end; continue
            }
            if html[cursor...].hasPrefix("<!--") {
                let end = html.range(of:"-->",range:cursor..<html.endIndex)?.upperBound ?? html.endIndex
                tokens.append(Token(text:String(html[cursor..<end]),special:true)); cursor = end; continue
            }
            var end = html.index(after:cursor); var quote:Character?
            while end < html.endIndex {
                let c = html[end]
                if let q = quote { if c == q { quote = nil } }
                else if c == "\"" || c == "'" { quote = c }
                else if c == ">" { end = html.index(after:end); break }
                end = html.index(after:end)
            }
            let raw = String(html[cursor..<end])
            let closing = raw.hasPrefix("</")
            let offset = closing ? 2 : 1
            let name = String(raw.dropFirst(offset).prefix { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == ":") }).lowercased()
            if !closing && protected.contains(name), let range = html.range(of:"</"+name,options:.caseInsensitive,range:end..<html.endIndex), let close = html[range.upperBound...].firstIndex(of:">") {
                end = html.index(after:close)
                tokens.append(Token(text:String(html[cursor..<end]),name:name,special:true,tag:true,selfClosing:true)); cursor = end; continue
            }
            tokens.append(Token(text:compactTag(raw),name:name,closing:closing,tag:!name.isEmpty,selfClosing:voids.contains(name) || raw.hasSuffix("/>")))
            cursor = end
        }
        // Only block-to-block separators are reformatted. Whitespace around inline elements is meaningful.
        var depth = 0; var output = ""; var previous:Token?
        for (index,token) in tokens.enumerated() {
            if token.text.allSatisfy({$0.isWhitespace}), let prior = previous, blocks.contains(prior.name) {
                let next = index+1 < tokens.count ? tokens[index+1] : nil
                if let next, blocks.contains(next.name) { continue }
            }
            if token.closing { depth = max(0,depth-1) }
            if let prior = previous, blocks.contains(prior.name), blocks.contains(token.name) {
                if self == .beautify { output += "\n" + String(repeating:"  ",count:min(depth,64)) }
            }
            output += token.text
            if token.tag && !token.closing && !token.selfClosing { depth += 1 }
            previous = token
        }
        return output
    }
    private func compactTag(_ tag:String) -> String {
        guard tag.hasPrefix("<"), !tag.hasPrefix("<!"), !tag.hasPrefix("<?") else { return tag }
        var result = ""; var quote:Character?; var space = false
        for character in tag {
            if let q = quote {
                result.append(character); if character == q { quote = nil }; continue
            }
            if character.isWhitespace { space = true; continue }
            if space && character != ">" { result.append(" ") }
            space = false; result.append(character)
            if character == "\"" || character == "'" { quote = character }
        }
        return result
    }
}
