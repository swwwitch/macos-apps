import Foundation
struct SmartSet: Codable, Identifiable, Hashable, Sendable { var id = UUID() }
@main struct StorageTests {
 static func main() throws {
  var data = LibraryData()
  data.ratings = [UUID().uuidString: 0, UUID().uuidString: 3, UUID().uuidString: 5]
  data.favorites = ["Keep favorite"]
  let encoded = try JSONEncoder().encode(data)
  let restored = try JSONDecoder().decode(LibraryData.self, from: encoded)
  precondition(restored.ratings == data.ratings && restored.favorites == data.favorites)
  var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
  legacy.removeValue(forKey: "ratings")
  let old = try JSONDecoder().decode(LibraryData.self, from: JSONSerialization.data(withJSONObject: legacy))
  precondition(old.ratings.isEmpty && old.favorites == data.favorites)
  print("PASS ratings/favorites round-trip and legacy library compatibility")
 }
}
