import Foundation
import AppKit
func L(_ key:String) -> String { key }
@main struct InstallerTest {
    @MainActor static func main() async throws {
        let manager = PDFEngineManager.shared
        manager.check()
        while manager.busy { try await Task.sleep(nanoseconds:100_000_000) }
        guard !manager.latest.isEmpty else { fatalError(manager.message) }
        print("PASS: official latest \(manager.latest)")
        manager.install()
        while manager.busy { try await Task.sleep(nanoseconds:100_000_000) }
        guard let path = UserDefaults.standard.string(forKey:"managedTypstPath"), FileManager.default.isExecutableFile(atPath:path) else { fatalError(manager.message) }
        guard PDFEngineManager.readVersion(URL(fileURLWithPath:path)) == manager.latest else { fatalError("version mismatch") }
        print("PASS: verified official install and executable version")
        print(path)
    }
}
