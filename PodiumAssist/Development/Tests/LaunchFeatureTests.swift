import Foundation
@main struct LaunchFeatureTests {
 @MainActor static func main() async throws {
  let old = try JSONDecoder().decode(Preset.self, from: Data("{\"id\":\"12345678-1234-1234-1234-123456789012\",\"name\":\"old\"}".utf8))
  precondition(old.launchApps == nil)
  var preset = old
  preset.launchApps = [QuitAppTarget(id: "test.missing.podiumflight", name: "Missing Test App", path: "/nonexistent/Test.app")]
  let copy = try JSONDecoder().decode(Preset.self, from: JSONEncoder().encode(preset))
  precondition(copy.launchApps?.first?.id == "test.missing.podiumflight")
  let store = LaunchAppsStore()
  store.launch(copy.launchApps)
  while store.busy { try await Task.sleep(nanoseconds: 10_000_000) }
  precondition(store.status.contains("Missing Test App"))
  print("PASS: legacy presets, saved launch list, missing application reporting")
 }
}
