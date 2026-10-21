import XCTest
@testable import DutiGUI

final class VerificationTests: XCTestCase {
    @MainActor
    func testStartupDoesNotStagePresetOverCurrentSettings() {
        let store = AssociationStore()
        XCTAssertTrue(store.rows.allSatisfy { $0.proposed == nil })
        XCTAssertEqual(store.pending, 0)
    }
    func testOpeningHandlerIsEnough() async {
        let verified = await AssociationService.verify(expected: "com.adobe.Photoshop", delay: 0) { "com.adobe.Photoshop" }
        XCTAssertTrue(verified)
    }
    func testDelayedPropagation() async {
        var reads = 0
        let verified = await AssociationService.verify(expected: "chosen", delay: 0) {
            reads += 1
            return reads < 3 ? "old" : "chosen"
        }
        XCTAssertTrue(verified)
        XCTAssertEqual(reads, 3)
    }
    func testMissingAndWrongHandlersFail() async {
        var reads = 0
        let missing = await AssociationService.verify(expected: "chosen", attempts: 3, delay: 0) {
            reads += 1
            return nil
        }
        XCTAssertFalse(missing)
        XCTAssertEqual(reads, 3)
        let wrong = await AssociationService.verify(expected: "chosen", delay: 0) { "wrong" }
        XCTAssertFalse(wrong)
    }
    func testHomebrewVersionFallback() throws {
        throw XCTSkip("DutiEnvironment was removed with the installer tab in 0.3.3; no Homebrew installer is shipped.")
    }
    func testInstallerSyntaxWithoutExecutingInstaller() throws {
        throw XCTSkip("The Homebrew installer feature was removed in 0.3.3.")
    }
}
