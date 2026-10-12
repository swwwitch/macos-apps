import Foundation
@main struct QuitFeatureTests {
 @MainActor static func main() throws {
   let old = Data("{\"id\":\"12345678-1234-1234-1234-123456789012\",\"name\":\"old\"}".utf8)
   let decoded = try JSONDecoder().decode(Preset.self, from: old)
   precondition(decoded.quitApps == nil)
   var selected = decoded
   selected.quitApps = true
   let restored = try JSONDecoder().decode(Preset.self, from: JSONEncoder().encode(selected))
   precondition(restored.quitApps == true)
   let target = QuitAppTarget(id: "test.bundle", name: "Test", path: "/tmp/Test.app")
   let targets = try JSONDecoder().decode([QuitAppTarget].self, from: JSONEncoder().encode([target]))
   precondition(targets.first?.id == target.id && targets.first?.path == target.path)
   print("PASS: old preset compatibility, quit option round trip, target list round trip")
 }
}
