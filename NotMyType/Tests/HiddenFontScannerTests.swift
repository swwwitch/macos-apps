// Standalone scanner harness: compile with FontLibrary.swift, Localization.swift and FontWeightOrder.swift.
import Foundation

// Unused persistence model dependency; scanner tests do not read or write smart sets.
struct SmartSet: Codable, Sendable { var id = UUID() }


@main
struct HiddenFontScannerTests {
    static func main() throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        var hidden = root.appendingPathComponent("fonts")
        try fm.createDirectory(at: hidden, withIntermediateDirectories: true)
        var flags = URLResourceValues(); flags.isHidden = true
        try hidden.setResourceValues(flags)
        let file = hidden.appendingPathComponent("font.otf")
        try fm.copyItem(at: URL(fileURLWithPath: "/System/Library/Fonts/Supplemental/Arial.ttf"), to: file)
        precondition(FontScanner.read(file) != nil)
        var hiddenFile = root.appendingPathComponent("hidden.ttf")
        try Data().write(to: hiddenFile)
        try hiddenFile.setResourceValues(flags)
        let dotFile = root.appendingPathComponent(".font.otf")
        try Data().write(to: dotFile)
        let visible = root.appendingPathComponent("visible.otf")
        try Data().write(to: visible)
        try Data().write(to: root.appendingPathComponent("ignore.txt"))
        let found = Set(FontScanner.fontURLs(in: [root]).map(\.path))
        let expected = Set([file, hiddenFile, dotFile, visible].map(\.path))
        if found != expected { FileHandle.standardError.write(Data("found=\(found) expected=\(expected)\n".utf8)) }
        precondition(found == expected)
        precondition(FontScanner.fontURLs(in: [root], includeHidden: false).map(\.path) == [visible.path])
        let directoryFlags = try hidden.resourceValues(forKeys: [.isHiddenKey]); precondition(directoryFlags.isHidden == true)
        let fileFlags = try hiddenFile.resourceValues(forKeys: [.isHiddenKey]); precondition(fileFlags.isHidden == true)
        let actual = URL(fileURLWithPath: "/Library/Fonts/oh_my_font/fonts/OMF-love_kakumaru_Kna_U.otf")
        if fm.fileExists(atPath: actual.path) {
            precondition(FontScanner.fontURLs(in: [URL(fileURLWithPath: "/Library/Fonts/oh_my_font")]).contains(actual))
            precondition(FontScanner.read(actual) != nil)
            print("PASS specified OMF font detected and parsed (no activation performed)")
        }
        print("PASS readable font inside hidden folder; no activation performed")
        print("PASS hidden folder, hidden file, dotfile, visible file, extension filtering, opt-out, unchanged hidden attributes")
    }
}
