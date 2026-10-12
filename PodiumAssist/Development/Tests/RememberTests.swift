import Foundation
@main struct RememberTests {
 @MainActor static func main() throws {
  let suite = "podium-tests-" + UUID().uuidString
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let store = PresetStore(defaults: defaults)
  var preset = Preset(); preset.name = "Test"; preset.dark = true
  preset.launchApps = [QuitAppTarget(id:"a",name:"A",path:"/a.app")]
  store.save(preset)
  precondition(PresetStore(defaults: defaults).rememberedPreset?.dark == true)
  preset.dark = false; preset.quitAppTargets = [QuitAppTarget(id:"b",name:"B",path:"/b.app")]
  store.save(preset)
  let restored = PresetStore(defaults: defaults)
  precondition(restored.items.count == 1 && restored.rememberedPreset?.dark == false)
  precondition(restored.rememberedPreset?.launchApps?.first?.id == "a" && restored.rememberedPreset?.quitAppTargets?.first?.id == "b")
  restored.remember(nil); precondition(PresetStore(defaults: defaults).rememberedPreset == nil)
  print("PASS: persistent save, overwrite without duplicate, remembered selection, app lists")
 }
}
