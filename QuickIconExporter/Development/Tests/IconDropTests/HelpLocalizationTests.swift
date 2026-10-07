import Foundation
import Testing

/// Bundled help (Localizations/<lang>.lproj/Help.txt) and UI string keys must exist for all 4 languages.
private let languages = ["ja", "en", "zh-Hans", "ko"]
private let localizations = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Localizations")

@Test func helpExistsForEveryLanguage() throws {
    // HelpDocument markup: the same ## / ### structure in every language, bullets, no "# " title line.
    var structures: [String: [String]] = [:]
    for language in languages {
        let url = localizations.appendingPathComponent("\(language).lproj/Help.txt")
        let text = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(!text.isEmpty, "\(language) Help.txt is empty")
        let lines = text.split(separator: "\n").map(String.init)
        structures[language] = lines.filter { $0.hasPrefix("#") }.map { String($0.prefix { $0 == "#" }) }
        #expect(!lines.contains { $0.hasPrefix("# ") }, "\(language) Help.txt has a # title line")
        #expect(lines.contains { $0.hasPrefix("- ") }, "\(language) Help.txt has no bullets")
        #expect((structures[language] ?? []).filter { $0 == "##" }.count >= 5, "\(language) Help.txt needs ## sections")
    }
    #expect(Set(structures.values).count == 1, "Help.txt heading structures differ: \(structures)")
}

/// Help mentions the shared "note記事を開く" item (HelpLinks.noteTitle) in each language.
@Test func helpMentionsNoteItem() throws {
    let titles = ["ja": "note記事を開く", "en": "Open the note Article", "zh-Hans": "打开 note 文章", "ko": "note 글 열기"]
    for language in languages {
        let url = localizations.appendingPathComponent("\(language).lproj/Help.txt")
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains(titles[language]!), "\(language) Help.txt does not mention the note item")
    }
}

@Test func localizableKeysMatchAcrossLanguages() throws {
    func keys(_ language: String) throws -> Set<String> {
        let url = localizations.appendingPathComponent("\(language).lproj/Localizable.strings")
        let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(language) Localizable.strings unreadable")
        #expect(!table.values.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }, "\(language) has empty values")
        return Set(table.keys)
    }
    let reference = try keys("ja")
    for language in languages.dropFirst() {
        let other = try keys(language)
        #expect(other == reference, "\(language): missing \(reference.subtracting(other).sorted()) extra \(other.subtracting(reference).sorted())")
    }
}
