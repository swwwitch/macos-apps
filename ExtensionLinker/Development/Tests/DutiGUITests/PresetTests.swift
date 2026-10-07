import XCTest
@testable import DutiGUI

final class PresetTests: XCTestCase {
    func testRoundTripNormalizesExtensionsAndPreservesAppIDs() throws {
        let file = PresetFile(name: "自分の設定", associations: [
            .init(ext: ".CSV", bundleID: "com.microsoft.Excel", appName: "Excel"),
            .init(ext: "pdf", bundleID: "com.adobe.Reader", appName: "Acrobat Reader")
        ])
        let decoded = try PresetFile.decode(file.encoded(), name: file.name)
        XCTAssertEqual(decoded.name, file.name)
        XCTAssertTrue(decoded.associations.contains { $0.ext == "csv" && $0.bundleID == "com.microsoft.Excel" })
        XCTAssertTrue(decoded.associations.contains { $0.bundleID == "com.adobe.Reader" })
    }
    func testRejectsDuplicateExtensionsBeforeImport() throws {
        let file = PresetFile(name: "重複", associations: [
            .init(ext: "csv", bundleID: "com.microsoft.Excel"),
            .init(ext: ".CSV", bundleID: "com.apple.TextEdit")
        ])
        XCTAssertThrowsError(try PresetFile.decode(file.encoded()))
    }
    func testRejectsConflictingAliases() throws {
        let file = PresetFile(name: "別名", associations: [
            .init(ext: "jpg", bundleID: "com.adobe.Photoshop"),
            .init(ext: "jpeg", bundleID: "com.apple.Preview")
        ])
        // Sandboxed test processes cannot read the user's Launch Services types.
        XCTAssertThrowsError(try PresetFile.decode(file.encoded(), typeIdentifier: { _ in "public.jpeg" }))
    }
    func testRejectsUnexpectedCommandsAndInvalidBundleID() throws {
        XCTAssertThrowsError(try PresetFile.decode(Data("echo finished\n".utf8)))
        let invalid = PresetFile(name: "invalid", associations: [.init(ext: "csv", bundleID: "run; something")])
        XCTAssertThrowsError(try PresetFile.decode(invalid.encoded()))
    }
    func testIgnoresCommentsAndBlankLines() throws {
        let text = "\u{FEFF}# Excel\r\n\r\n duti -s com.microsoft.Excel .csv all\r\n  # Photoshop\n\tduti -s com.adobe.Photoshop .gif all\n"
        let file = try PresetFile.decode(Data(text.utf8))
        XCTAssertEqual(file.associations.count, 2)
        XCTAssertEqual(file.associations[0].ext, "csv")
        XCTAssertEqual(file.associations[1].ext, "gif")
    }
    func testAliasesMergeWhenTheApplicationMatches() throws {
        let text = "duti -s com.adobe.Photoshop .jpg all\nduti -s com.adobe.Photoshop .jpeg all\nduti -s org.mozilla.firefox .html all\nduti -s org.mozilla.firefox .htm all\n"
        let file = try PresetFile.decode(Data(text.utf8))
        XCTAssertEqual(file.associations.map(\.ext), ["jpg", "html"])
        let exported = String(decoding: try file.encoded(), as: UTF8.self)
        XCTAssertTrue(exported.contains(".jpeg all"))
        XCTAssertTrue(exported.contains(".htm all"))
        XCTAssertEqual(try PresetFile.decode(file.encoded()).associations.count, 2)
    }
    @MainActor
    func testExtensionRemovalPersistsAndCanBeAddedBack() throws {
        let name = "dutiGUI-tests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = AssociationStore(defaults: defaults)
        store.removeExtensions(["jpeg", "rtf"])
        XCTAssertFalse(store.rows.contains { $0.ext == "jpg" || $0.ext == "rtf" })
        let reloaded = AssociationStore(defaults: defaults)
        XCTAssertFalse(reloaded.rows.contains { $0.ext == "jpg" || $0.ext == "rtf" })
        XCTAssertTrue(reloaded.add(".rtf"))
        XCTAssertTrue(AssociationStore(defaults: defaults).rows.contains { $0.ext == "rtf" })
        XCTAssertFalse(reloaded.add("rtf"))
    }
    func testAIUsesIllustratorInInitialPreset() {
        XCTAssertEqual(Preset.all.first { $0.ext == "ai" }?.bundleID, "com.adobe.illustrator")
    }
    func testLatestUserPresetMergesDuplicateAIAndTIFF() throws {
        let text = "# Illustrator\nduti -s com.adobe.illustrator .ai all\nduti -s com.adobe.illustrator .ai all\n# Photoshop\nduti -s com.adobe.Photoshop .tif all\nduti -s com.adobe.Photoshop .tiff all\n"
        let file = try PresetFile.decode(Data(text.utf8))
        XCTAssertEqual(file.associations.map(\.ext), ["ai", "tif"])
        XCTAssertEqual(Preset.all.first { $0.ext == "eps" }?.bundleID, "com.adobe.Photoshop")
        XCTAssertEqual(Preset.all.first { $0.ext == "txt" }?.bundleID, "jp.co.artman21.Jedit-Pro")
        XCTAssertEqual(Preset.all.first { $0.ext == "rtf" }?.bundleID, "jp.co.artman21.Jedit-Pro")
        XCTAssertEqual(Preset.all.count, 25)
    }
    @MainActor
    func testExcelGroupingAndPresetRoundTrip() throws {
        let name = "ExtensionLinker-excel-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = AssociationStore(defaults: defaults)
        XCTAssertEqual(Array(store.rows.prefix(2).map(\.ext)), ["ai", "svg"])
        let rows = store.rows.filter { $0.ext == "xls" || $0.ext == "xlsx" }
        XCTAssertEqual(rows.count, 1)
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.extensionLabel, ".xls / .xlsx")
        XCTAssertEqual(row.types.count, 2, "Both distinct file types must be updated")
        XCTAssertFalse(store.add("xlsx"))
        let text = "duti -s com.microsoft.Excel .xls all\nduti -s com.microsoft.Excel .xlsx all\n"
        let file = try PresetFile.decode(Data(text.utf8))
        XCTAssertEqual(file.associations.map(\.ext), ["xls"])
        let output = String(decoding: try file.encoded(), as: UTF8.self)
        XCTAssertTrue(output.contains(".xls all"))
        XCTAssertTrue(output.contains(".xlsx all"))
        XCTAssertEqual(try PresetFile.decode(file.encoded()).associations.count, 1)
        store.removeExtensions(["xlsx"])
        XCTAssertFalse(AssociationStore(defaults: defaults).rows.contains { $0.ext == "xls" })
        XCTAssertTrue(store.add("xlsx"))
        XCTAssertTrue(AssociationStore(defaults: defaults).rows.contains { $0.ext == "xls" })
    }

    @MainActor
    func testMarkdownAliasesInTextCategoryAndPreset() throws {
        XCTAssertEqual(AssociationCategory.category(for: "md"), .text)
        XCTAssertEqual(AssociationCategory.category(for: "markdown"), .text)
        let row = Association(ext: "md")
        XCTAssertEqual(row.extensionLabel, ".md / .markdown")
        XCTAssertEqual(row.aliases, ["md", "markdown"])
        let text = "duti -s com.uranusjr.macdown .md all\nduti -s com.uranusjr.macdown .markdown all\n"
        let file = try PresetFile.decode(Data(text.utf8))
        XCTAssertEqual(file.associations.map(\.ext), ["md"])
        let output = String(decoding: try file.encoded(), as: UTF8.self)
        XCTAssertTrue(output.contains(".md all"))
        XCTAssertTrue(output.contains(".markdown all"))
        XCTAssertEqual(try PresetFile.decode(file.encoded()).associations.count, 1)
        let name = "ExtensionLinker-markdown-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(["markdown"], forKey: "additionalExtensions")
        let store = AssociationStore(defaults: defaults)
        store.selectedCategory = .text
        XCTAssertEqual(store.visible.filter { $0.ext == "md" }.count, 1)
        XCTAssertFalse(store.add("markdown"))
    }

    func testJavaScriptAliasRoundTrip() throws {
        XCTAssertEqual(Association(ext: "js").extensionLabel, ".js / .jsx")
        XCTAssertEqual(AssociationCategory.category(for: "jsx"), .development)
        let input = "duti -s com.microsoft.VSCode .js all\nduti -s com.microsoft.VSCode .jsx all\n"
        let file = try PresetFile.decode(Data(input.utf8))
        XCTAssertEqual(file.associations.map(\.ext), ["js"])
        let output = String(decoding: try file.encoded(), as: UTF8.self)
        XCTAssertTrue(output.contains(".js all"))
        XCTAssertTrue(output.contains(".jsx all"))
        XCTAssertEqual(try PresetFile.decode(file.encoded()).associations.count, 1)
    }

    @MainActor
    func testAdditionalFormatsAndGroupedPresets() throws {
        let name = "ExtensionLinker-formats-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = AssociationStore(defaults: defaults)
        for (ext, aliases, category) in [
            ("doc", ["doc", "docx"], AssociationCategory.business),
            ("ppt", ["ppt", "pptx"], .business),
            ("psd", ["psd"], .design), ("indd", ["indd"], .design),
            ("json", ["json"], .development), ("ts", ["ts", "tsx"], .development)
        ] {
            let row = try XCTUnwrap(store.rows.first { $0.ext == ext })
            XCTAssertEqual(row.aliases, aliases)
            for alias in aliases { XCTAssertEqual(AssociationCategory.category(for: alias), category) }
            let file = PresetFile(name: "test", associations: [.init(ext: ext, bundleID: "com.example.Editor")])
            let data = try file.encoded()
            for alias in aliases { XCTAssertTrue(String(decoding: data, as: UTF8.self).contains(".\(alias) all")) }
            XCTAssertEqual(try PresetFile.decode(data).associations.map(\.ext), [ext])
        }
        XCTAssertTrue(store.rows.allSatisfy { $0.proposed == nil })
    }

    func testSelectingCurrentAppStillStagesAnAliasMismatch() throws {
        guard let app = Application(url: URL(fileURLWithPath: "/Applications/Xcode.app")) else { throw XCTSkip("Xcode fixture not installed") }
        var row = Association(ext: "jpg", current: app)
        row.proposed = app
        row.aliasesDiffer = true
        XCTAssertTrue(row.changed)
        row.aliasesDiffer = false
        XCTAssertFalse(row.changed)
    }
}
