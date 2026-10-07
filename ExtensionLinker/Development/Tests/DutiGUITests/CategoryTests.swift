import XCTest
@testable import DutiGUI

final class CategoryTests: XCTestCase {
    func testAliasesAndUnrecognizedExtensions() {
        XCTAssertEqual(AssociationCategory.category(for: "JPEG"), .design)
        XCTAssertEqual(AssociationCategory.category(for: "tiff"), .design)
        XCTAssertEqual(AssociationCategory.category(for: "htm"), .development)
        XCTAssertEqual(AssociationCategory.category(for: "docx"), .business)
        XCTAssertEqual(AssociationCategory.category(for: "unknown"), .other)
    }

    @MainActor
    func testColumnSortToggleAndFiltering() {
        let store = AssociationStore()
        store.rows = [Association(ext: "svg", unavailable: "Zebra"),
                      Association(ext: "ai", unavailable: "Alpha"),
                      Association(ext: "png", unavailable: "Alpha")]
        store.sort(by: .fileExtension)
        XCTAssertEqual(store.visible.map(\.ext), ["ai", "png", "svg"])
        store.sort(by: .fileExtension)
        XCTAssertEqual(store.visible.map(\.ext), ["svg", "png", "ai"])
        store.sort(by: .application)
        XCTAssertEqual(store.visible.map(\.ext), ["ai", "png", "svg"])
        store.sort(by: .application)
        XCTAssertEqual(store.visible.map(\.ext), ["svg", "png", "ai"])
        store.query = "Alpha"
        XCTAssertEqual(store.visible.map(\.ext), ["png", "ai"])
        XCTAssertEqual(store.rows.map(\.ext), ["svg", "ai", "png"])
    }

    @MainActor
    func testFiltersComposeAndDoNotDiscardHiddenChanges() {
        let name = "DutiGUI.CategoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = AssociationStore(defaults: defaults)
        store.rows = [Association(ext: "ai", unavailable: "Missing design app"),
                      Association(ext: "png"),
                      Association(ext: "doc", unavailable: "Missing business app"),
                      Association(ext: "js"), Association(ext: "txt")]
        store.selectedCategory = .design
        XCTAssertEqual(store.visible.map(\.ext), ["ai", "png"])
        store.onlyChanges = true
        XCTAssertEqual(store.visible.map(\.ext), ["ai"])
        store.query = "png"
        XCTAssertTrue(store.visible.isEmpty)
        store.query = ""
        store.selectedCategory = .business
        XCTAssertEqual(store.visible.map(\.ext), ["doc"])
        XCTAssertEqual(store.missing, 2)
        store.selectedCategory = .all
        XCTAssertEqual(store.visible.map(\.ext), ["ai", "doc"])
        XCTAssertEqual(store.rows.count, 5)
    }
}
