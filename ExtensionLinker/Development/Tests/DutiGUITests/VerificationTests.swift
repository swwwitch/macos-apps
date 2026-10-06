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
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bin = root.appendingPathComponent("Cellar/duti/1.5.4/bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let executable = bin.appendingPathComponent("duti")
        try "#!/bin/sh\nprintf 'INTERNAL\\n'\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let result = DutiEnvironment.version(at: executable.path)
        XCTAssertEqual(result.0, "1.5.4（Homebrew）")
        XCTAssertTrue(result.1.contains("INTERNAL"))
    }
    func testInstallerSyntaxWithoutExecutingInstaller() throws {
        let script = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sh")
        defer { try? FileManager.default.removeItem(at: script) }
        try DutiEnvironment.homebrewInstaller.write(to: script, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-n", script.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }
}
