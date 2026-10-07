import Foundation

/// Text-oriented IDML import. No archive entries are ever extracted into the user's folders.
enum IDMLImporter {
    static let maximumBytes = 20 * 1024 * 1024
    static func error(_ key: String) -> NSError {
        NSError(domain:"PandocDesk.IDML",code:1,userInfo:[NSLocalizedDescriptionKey:NSLocalizedString(key,comment:"")])
    }
    final class Node {
        let name: String
        let attributes: [String:String]
        var children: [Node] = []
        var text = ""
        init(_ name:String,_ attributes:[String:String]) { self.name = name; self.attributes = attributes }
        func descendants(_ name:String) -> [Node] {
            children.flatMap { ($0.name == name ? [$0] : []) + $0.descendants(name) }
        }
    }
    final class Tree: NSObject, XMLParserDelegate {
        let root = Node("root",[:])
        var stack: [Node] = []
        var count = 0
        var textBytes = 0
        override init() { super.init(); stack = [root] }
        func parser(_ parser:XMLParser,didStartElement elementName:String,namespaceURI:String?,qualifiedName:String?,attributes:[String:String]) {
            count += 1
            guard stack.count < 128, count < 200000 else { parser.abortParsing(); return }
            let node = Node(elementName.components(separatedBy:":").last!,attributes)
            stack.last!.children.append(node); stack.append(node)
        }
        func parser(_ parser:XMLParser,foundCharacters string:String) {
            textBytes += string.utf8.count
            guard textBytes <= maximumBytes else { parser.abortParsing(); return }
            stack.last?.text += string
        }
        func parser(_ parser:XMLParser,foundCDATA data:Data) { self.parser(parser,foundCharacters:String(data:data,encoding:.utf8) ?? "") }
        func parser(_ parser:XMLParser,didEndElement:String,namespaceURI:String?,qualifiedName:String?) { if stack.count > 1 { stack.removeLast() } }
    }
    static func parse(_ data:Data) throws -> Node {
        guard data.count <= maximumBytes else { throw error("idmlTooLarge") }
        let tree = Tree(); let parser = XMLParser(data:data)
        parser.shouldResolveExternalEntities = false; parser.delegate = tree
        guard parser.parse() else { throw error("idmlInvalid") }
        return tree.root
    }
    static func read(_ archive:URL,_ entry:String, cancelled:() -> Bool) throws -> Data {
        guard !entry.hasPrefix("/"), !entry.contains(".."), !entry.contains("*"), !entry.contains("?"), !entry.contains("["), !entry.contains("\\"), entry.utf8.count < 1024 else { throw error("idmlInvalid") }
        if cancelled() { throw CancellationError() }
        let p = Process(); p.executableURL = URL(fileURLWithPath:"/usr/bin/unzip"); p.arguments = ["-p",archive.path,entry]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice; p.standardInput = FileHandle.nullDevice
        try p.run(); var data = Data()
        do {
            while let chunk = try pipe.fileHandleForReading.read(upToCount:65536), !chunk.isEmpty {
                if cancelled() { throw CancellationError() }
                guard data.count + chunk.count <= maximumBytes else { throw error("idmlTooLarge") }
                data.append(chunk)
            }
        } catch { if p.isRunning { p.terminate() }; try? pipe.fileHandleForReading.close(); p.waitUntilExit(); throw error }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw error("idmlInvalid") }
        return data
    }
    static func html(from archive:URL, cancelled:() -> Bool = { false }) throws -> String {
        let map = try parse(read(archive,"designmap.xml",cancelled:cancelled))
        let paths = map.descendants("Story").compactMap { $0.attributes["src"] }
        guard !paths.isEmpty, paths.count <= 2000, Set(paths).count == paths.count,
              paths.allSatisfy({ $0.hasPrefix("Stories/") && $0.hasSuffix(".xml") }) else { throw error("idmlInvalid") }
        var result = "<!doctype html><html><head><meta charset=\"UTF-8\"></head><body>"
        var total = 0
        var hasText = false
        for path in paths {
            let data = try read(archive,path,cancelled:cancelled); total += data.count
            guard total <= maximumBytes else { throw error("idmlTooLarge") }
            let root = try parse(data)
            guard let story = root.descendants("Story").first else { throw error("idmlInvalid") }
            hasText = hasText || story.descendants("Content").contains { !$0.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty }
            result += "<section>" + renderChildren(story) + "</section>\n"
        }
        guard hasText else { throw error("idmlNoText") }
        return result.replacingOccurrences(of:"\u{001D}",with:"") + "</body></html>"
    }
    static func escape(_ string:String) -> String {
        string.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;").replacingOccurrences(of:"\"",with:"&quot;")
    }
    static func renderChildren(_ node:Node) -> String { node.children.map(render).joined() }
    static func render(_ node:Node) -> String {
        switch node.name {
        case "Content": return escape(node.text)
        case "Br": return "\u{001E}" // IDML Br is a paragraph boundary, including inside a style range.
        case "Tab": return "&#9;"
        case "ParagraphStyleRange":
            let style = node.attributes["AppliedParagraphStyle"]?.lowercased() ?? ""
            let level = (1...6).first { style.contains("heading \($0)") || style.contains("heading\($0)") || style.contains("見出し\($0)") || style.contains("見出し \($0)") }
            let tag = level.map { "h\($0)" } ?? "p"
            var pieces = renderChildren(node).components(separatedBy:"\u{001E}")
            if pieces.last == "" { pieces.removeLast() }
            return pieces.flatMap { $0.components(separatedBy:"\u{001D}") }.filter { !$0.isEmpty }.map { part in
                part.hasPrefix("<table>") ? part : "<\(tag)>\(part)</\(tag)>\n"
            }.joined()
        case "CharacterStyleRange":
            let font = node.attributes["FontStyle"]?.lowercased() ?? ""
            var start = "", end = ""
            if font.contains("bold") { start += "<strong>"; end = "</strong>" + end }
            if font.contains("italic") || font.contains("oblique") { start += "<em>"; end = "</em>" + end }
            if node.attributes["Position"] == "Superscript" { start += "<sup>"; end = "</sup>" + end }
            if node.attributes["Position"] == "Subscript" { start += "<sub>"; end = "</sub>" + end }
            // Close formatting around each paragraph break so generated HTML stays balanced.
            return renderChildren(node).components(separatedBy:"\u{001D}").map { block in
                if block.hasPrefix("<table>") { return block }
                return block.components(separatedBy:"\u{001E}").map { $0.isEmpty ? "" : start + $0 + end }.joined(separator:"\u{001E}")
            }.joined(separator:"\u{001D}")
        case "Table":
            let cells = node.children.filter { $0.name == "Cell" }
            let ordered = cells.compactMap { cell -> (Int,Int,Node)? in
                let coordinate = (cell.attributes["Name"] ?? "").split(separator:":").compactMap { Int($0) }
                guard coordinate.count == 2, coordinate.allSatisfy({$0 >= 0 && $0 < 10000}) else { return nil }
                return (coordinate[1],coordinate[0],cell)
            }.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
            guard ordered.count == cells.count else { return renderChildren(node) }
            var html = "<table>"; var row = -1
            for (r,_,cell) in ordered {
                if r != row { if row >= 0 { html += "</tr>" }; html += "<tr>"; row = r }
                let rs = min(1000,max(1,Int(cell.attributes["RowSpan"] ?? "1") ?? 1))
                let cs = min(1000,max(1,Int(cell.attributes["ColumnSpan"] ?? "1") ?? 1))
                html += "<td rowspan=\"\(rs)\" colspan=\"\(cs)\">" + renderChildren(cell) + "</td>"
            }
            if row >= 0 { html += "</tr>" }; return "\u{001D}" + html + "</table>\u{001D}"
        case "Properties", "StoryPreference", "InCopyExportOption", "TextFrame", "Rectangle", "Oval", "Polygon", "Note", "HiddenText": return ""
        default: return renderChildren(node)
        }
    }
}
