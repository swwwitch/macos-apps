import Foundation
struct BracketAction: Identifiable {
    let id: String
    let opening: String
    let closing: String
    var title: String { opening + " " + closing }
    static let pairs: [BracketAction] = [
        .init(id: "round", opening: "（", closing: "）"),
        .init(id: "square", opening: "［", closing: "］"),
        .init(id: "lenticular", opening: "【", closing: "】"),
        .init(id: "angle", opening: "〈", closing: "〉"),
        .init(id: "doubleAngle", opening: "《", closing: "》"),
        .init(id: "corner", opening: "「", closing: "」"),
        .init(id: "curly", opening: "｛", closing: "｝"),
        .init(id: "doubleCorner", opening: "『", closing: "』"),
        .init(id: "smartDouble", opening: "“", closing: "”"),
        .init(id: "smartSingle", opening: "‘", closing: "’"),
        .init(id: "asciiRound", opening: "(", closing: ")"),
        .init(id: "asciiSquare", opening: "[", closing: "]"),
        .init(id: "asciiCurly", opening: "{", closing: "}"),
        .init(id: "asciiAngle", opening: "<", closing: ">"),
        .init(id: "asciiSingle", opening: "'", closing: "'"),
        .init(id: "asciiDouble", opening: "\"", closing: "\""),
        .init(id: "html", opening: "<!-- ", closing: " -->"),
        .init(id: "css", opening: "/* ", closing: " */")
    ]
    static let operations = ["removeOuter", "removeAll", "spaces"]
    static let forceIDs = ["round", "square", "corner", "angle", "doubleAngle"].map { "force_" + $0 }
    static let ids = pairs.map(\.id) + forceIDs + operations + ["palette"]
    static func pair(_ id: String) -> BracketAction? { pairs.first { $0.id == id } }
}
struct BracketEdit {
    let replacement: String
    let selection: NSRange
    static func make(_ text: String, at location: Int, action: String = "round", force: Bool = false, trimSpaces: Bool = false) -> BracketEdit {
        if action.hasPrefix("force_"), BracketAction.forceIDs.contains(action) {
            return make(text, at: location, action: String(action.dropFirst(6)), force: true, trimSpaces: trimSpaces)
        }
        func selected(_ result: String) -> BracketEdit { .init(replacement: result, selection: NSRange(location: location, length: result.utf16.count)) }
        if action == "spaces" {
            return .init(replacement: " " + text + " ", selection: NSRange(location: location + 1, length: text.utf16.count))
        }
        let chars = Array(text)
        let markers = bracketMarkers(chars)
        if action == "removeOuter" || action == "removeAll" {
            let removed = Set(markers.filter { action == "removeAll" || $0.outer }.map(\.index))
            return selected(String(chars.enumerated().filter { !removed.contains($0.offset) }.map(\.element)))
        }
        guard let pair = BracketAction.pair(action) else { return selected(text) }
        if text.isEmpty {
            return .init(replacement: pair.opening + pair.closing, selection: NSRange(location: location + pair.opening.utf16.count, length: 0))
        }
        // Comments always wrap; never parse HTML/CSS source as bracket syntax.
        let outer = markers.filter(\.outer)
        if !force && action != "html" && action != "css" && !outer.isEmpty {
            let map = Dictionary(uniqueKeysWithValues: outer.map { ($0.index, $0.open ? pair.opening : pair.closing) })
            var removed = Set<Int>()
            if trimSpaces {
                for marker in outer {
                    var left = marker.index - 1
                    while left >= 0 && chars[left] == " " { removed.insert(left); left -= 1 }
                    var right = marker.index + 1
                    while right < chars.count && chars[right] == " " { removed.insert(right); right += 1 }
                }
            }
            return selected(chars.enumerated().map { removed.contains($0.offset) ? "" : map[$0.offset] ?? String($0.element) }.joined())
        }
        let content = trimSpaces ? text.trimmingCharacters(in: CharacterSet(charactersIn: " ")) : text
        return .init(replacement: pair.opening + content + pair.closing,
                     selection: NSRange(location: location + pair.opening.utf16.count, length: content.utf16.count))
    }
    private struct Marker { let index: Int; let open: Bool; let outer: Bool }
    private static func bracketMarkers(_ chars: [Character]) -> [Marker] {
        let opens = Set("（［【〈《「｛『‘“([{<")
        let closes = Set("）］】〉》」｝』’”)]}>")
        var stack: [Character] = []
        var result: [Marker] = []
        func word(_ c: Character) -> Bool { c.isLetter || c.isNumber }
        for (i, c) in chars.enumerated() {
            // Apostrophes within words are not quotation delimiters.
            if (c == "'" || c == "’"), i > 0, i + 1 < chars.count, word(chars[i-1]), word(chars[i+1]) { continue }
            let symmetric = c == "'" || c == "\""
            let reversedOpening = (c == "”" || c == "’") && i == 0 && chars.count > 1 && (chars.last == "“" || chars.last == "‘")
            let reversedClosing = (c == "“" || c == "‘") && i == chars.count - 1 && (chars.first == "”" || chars.first == "’")
            let isOpen = reversedOpening || (!reversedClosing && (opens.contains(c) || (symmetric && stack.last != c)))
            let isClose = reversedClosing || closes.contains(c) || (symmetric && stack.last == c)
            if isOpen {
                result.append(Marker(index: i, open: true, outer: stack.isEmpty)); stack.append(c)
            } else if isClose {
                if !stack.isEmpty { stack.removeLast() }
                result.append(Marker(index: i, open: false, outer: stack.isEmpty))
            }
        }
        return result
    }
}
