import XCTest

/// The bundled help must exist for every UI language, matching the Localizable.strings keys.
final class HelpLocalizationTests: XCTestCase {
    private let languages = ["ja", "en", "zh-Hans", "ko"]
    private var localizations: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Localizations")
    }

    func testHelpExistsForAllLanguages() throws {
        var sections: [String: Int] = [:]
        for language in languages {
            let url = localizations.appendingPathComponent("\(language).lproj/Help.txt")
            let text = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertFalse(text.isEmpty, language)
            sections[language] = text.components(separatedBy: "\n").filter { $0.hasPrefix("## ") }.count
        }
        XCTAssertEqual(Set(sections.values).count, 1, "\(sections)")
        XCTAssertGreaterThan(sections["en"] ?? 0, 0)
    }

    /// Subsections and list items stay parallel across languages, and each help mentions the note article.
    func testHelpStructureIsParallel() throws {
        var shapes: [String: [Int]] = [:]
        for language in languages {
            let url = localizations.appendingPathComponent("\(language).lproj/Help.txt")
            let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
            let subsections = lines.filter { $0.hasPrefix("### ") }.count
            let bullets = lines.filter { $0.hasPrefix("- ") }.count
            let steps = lines.filter { $0.range(of: #"^\d{1,2}\. "#, options: .regularExpression) != nil }.count
            shapes[language] = [subsections, bullets, steps]
            XCTAssertTrue(lines.contains { $0.contains("note") }, "\(language): note article not mentioned")
        }
        XCTAssertEqual(Set(shapes.values).count, 1, "\(shapes)")
    }

    func testLocalizableKeysMatch() throws {
        func keys(_ language: String) throws -> Set<String> {
            let url = localizations.appendingPathComponent("\(language).lproj/Localizable.strings")
            let table = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String], language)
            return Set(table.keys)
        }
        let base = try keys("ja")
        for language in languages { XCTAssertEqual(try keys(language), base, language) }
    }
}
