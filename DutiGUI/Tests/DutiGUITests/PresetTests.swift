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
        XCTAssertEqual(Preset.all.count, 20)
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
