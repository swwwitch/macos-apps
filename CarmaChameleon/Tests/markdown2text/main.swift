import Foundation
// Usage: markdown2text <sample.md> <options JSON object>  → prints the converted text.
let args = CommandLine.arguments
let markdown = try! String(contentsOfFile: args[1], encoding: .utf8)
let json = try! JSONSerialization.jsonObject(with: Data(args[2].utf8)) as! [String: Any]
var o = MarkdownTextOptions()
if let v = json["linkMode"] as? String { o.linkMode = .init(rawValue: v)! }
if let v = json["boldMode"] as? String { o.boldMode = .init(rawValue: v)! }
if let v = json["tableMode"] as? String { o.tableMode = .init(rawValue: v)! }
if let v = json["numMode"] as? String { o.numberMode = .init(rawValue: v)! }
if let v = json["imgMode"] as? String { o.imageMode = .init(rawValue: v)! }
if let v = json["listMarker"] as? String { o.listMarker = v }
if let v = json["blockGap"] as? String { o.blockGap = Int(v)! }
if let v = json["optLinkBelow"] as? Bool { o.linkBelow = v }
if let v = json["optZenkakuIndent"] as? Bool { o.zenkakuIndent = v }
if let v = json["optTrimBlank"] as? Bool { o.trimBlank = v }
if let v = json["optTrimLeading"] as? Bool { o.trimLeading = v }
if let v = json["optCollapseBlank"] as? Bool { o.collapseBlank = v }
if let v = json["stripHtml"] as? Bool { o.stripHTML = v }
for level in 1...6 {
    if let v = json["h\(level)p"] as? String { o.headingPrefixes[level - 1] = v }
    if let v = json["h\(level)m"] as? String { o.headingModes[level - 1] = .init(rawValue: v)! }
}
FileHandle.standardOutput.write(Data(MarkdownToText.convert(markdown, options: o).utf8))
