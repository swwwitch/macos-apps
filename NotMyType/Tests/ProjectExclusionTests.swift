import Foundation
struct SmartSet: Codable, Identifiable, Hashable, Sendable { var id = UUID() }
@main struct ProjectExclusionTests {
 static func main() throws {
  let a = UUID(), b = UUID()
  var p = FontProject(name: "Test")
  p.matched = [a, b]; p.refreshFiles()
  p.excludedFiles = [a]; p.refreshFiles()
  precondition(p.files == [b])
  var restored = try JSONDecoder().decode(FontProject.self, from: JSONEncoder().encode(p))
  restored.matched = [a, b]; restored.refreshFiles()
  precondition(restored.files == [b], "rescan and serialization preserve exclusion")
  restored.excludedFiles.removeAll(); restored.refreshFiles()
  precondition(restored.files == [a, b])
  restored.excludedFiles = [a]
  restored.addFiles([a, a, b])
  precondition(restored.manualFiles == [a, b])
  precondition(restored.excludedFiles.isEmpty)
  restored.matched = []; restored.refreshFiles()
  precondition(restored.files == [a, b], "manual additions survive source rescans")
  restored = try JSONDecoder().decode(FontProject.self, from: JSONEncoder().encode(restored))
  precondition(restored.manualFiles == [a, b])
  var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as! [String: Any]
  legacy.removeValue(forKey: "excludedFiles")
  legacy.removeValue(forKey: "manualFiles")
  let old = try JSONDecoder().decode(FontProject.self, from: JSONSerialization.data(withJSONObject: legacy))
  precondition(old.excludedFiles.isEmpty && old.manualFiles.isEmpty)
  precondition(ReleaseDecade(rawValue: 2010)!.title.contains("2010"))
  precondition(!ReleaseDecade(rawValue: 2010)!.title.contains(","))
  print("PASS: project exclusion, persistence, rescan, restoration, legacy decode, ungrouped decade")
 }
}
