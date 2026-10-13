import Foundation
import Testing
@testable import QuickIconExporter

struct OutputDirectoryTests {
    @Test func rejectsHiddenContainersAndAliases() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let container = root.appendingPathComponent("Library/Containers/test/Data/Desktop")
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let alias = root.appendingPathComponent("visible-export")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: container)
        #expect(!OutputDirectoryPolicy.isUserDirectory(container))
        #expect(!OutputDirectoryPolicy.isUserDirectory(alias))
        #expect(!OutputDirectoryPolicy.isUserDirectory(root.appendingPathComponent("Library/Group Containers/team/Export")))
        #expect(OutputDirectoryPolicy.isUserDirectory(root.appendingPathComponent("Containers")))
        #expect(OutputDirectoryPolicy.isUserDirectory(root.appendingPathComponent("Desktop")))
    }

    @Test func exportNeverCreatesContainerFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("Library/Containers/test/Data/Desktop")
        let rules = FilenameRules(prefix: "icon", iconNamePosition: .beforeFilename, separator: .hyphen, spaceReplacement: .keep, removesUnwantedCharacters: false)
        #expect(throws: IconExportError.self) {
            _ = try IconExporter.exportIcon(for: root.appendingPathComponent("sample.txt"), to: destination, rules: rules)
        }
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test func exportsRealPNGAndPreservesExistingFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("sample.txt")
        try Data("sample".utf8).write(to: source)
        let rules = FilenameRules(prefix: "icon", iconNamePosition: .beforeFilename, separator: .hyphen, spaceReplacement: .keep, removesUnwantedCharacters: false)
        let first = try IconExporter.exportIcon(for: source, to: root, rules: rules)
        let original = try Data(contentsOf: first.outputURL)
        let second = try IconExporter.exportIcon(for: source, to: root, rules: rules)
        #expect(first.outputURL != second.outputURL)
        #expect(try Data(contentsOf: first.outputURL) == original)
        #expect(Array(original.prefix(8)) == [137,80,78,71,13,10,26,10])
        #expect(first.pixelWidth > 0 && first.pixelHeight > 0)
    }
}
