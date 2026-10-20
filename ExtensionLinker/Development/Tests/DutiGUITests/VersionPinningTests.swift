import XCTest
@testable import DutiGUI

/// Paths that do not exist, so FileManager's localized app names do not interfere.
final class VersionPinningTests: XCTestCase {
    func testVersionedNameUsesVersionFolder() {
        XCTAssertEqual(Application.versionedName(URL(fileURLWithPath: "/NoSuchFolder/Sample Draw 2026/Sample Draw.app")), "Sample Draw 2026")
        XCTAssertEqual(Application.versionedName(URL(fileURLWithPath: "/NoSuchFolder/Sample Draw/Sample Draw.app")), "Sample Draw")
        XCTAssertEqual(Application.versionedName(URL(fileURLWithPath: "/NoSuchFolder/Sample Paint 2026/Sample Paint 2026.app")), "Sample Paint 2026")
        XCTAssertEqual(Application.versionedName(URL(fileURLWithPath: "/NoSuchFolder/Utilities/Sample.app")), "Sample")
    }

    func testCopiesWithSameVersionShareOneChoice() {
        let version = InstalledVersion(version: "29.8.11", shortVersion: "29.8.11", urls: [
            URL(fileURLWithPath: "/NoSuchFolder/Sample Draw/Sample Draw.app"),
            URL(fileURLWithPath: "/NoSuchFolder/Sample Draw 2025/Sample Draw.app")
        ])
        XCTAssertEqual(version.label, "Sample Draw / Sample Draw 2025（29.8.11）")
    }
}
