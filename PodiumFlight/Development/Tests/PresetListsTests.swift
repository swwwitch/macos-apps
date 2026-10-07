import Foundation
@main struct PresetListsTests {
 @MainActor static func main() throws {
  let a = QuitAppTarget(id: "a", name: "A", path: "/a.app")
  let b = QuitAppTarget(id: "b", name: "B", path: "/b.app")
  var first = Preset(); first.launchApps = [a]; first.quitAppTargets = [b]
  var second = first; second.id = UUID(); second.launchApps?.append(b); second.quitAppTargets = []
  precondition(first.launchApps?.count == 1 && first.quitAppTargets?.count == 1)
  let decoded = try JSONDecoder().decode([Preset].self, from: JSONEncoder().encode([first,second]))
  precondition(decoded[0].launchApps?.map(\.id) == ["a"])
  precondition(decoded[0].quitAppTargets?.map(\.id) == ["b"])
  precondition(decoded[1].launchApps?.count == 2 && decoded[1].quitAppTargets?.isEmpty == true)
  var old = try JSONDecoder().decode(Preset.self, from: Data("{\"id\":\"12345678-1234-1234-1234-123456789012\",\"name\":\"old\",\"quitApps\":true}".utf8))
  old.migrateAppTargets(legacyQuitTargets: [a]); old.migrateAppTargets(legacyQuitTargets: [b])
  precondition(old.quitAppTargets?.map(\.id) == ["a"] && old.quitApps == nil)
  print("PASS: independent preset lists, persistence, one-time legacy migration")
 }
}
