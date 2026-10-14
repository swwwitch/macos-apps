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
  var pointer = Preset(); pointer.name = "Pointer"; pointer.pointerSize = 2.5
  pointer.resolution = DisplayResolution(width: 1920, height: 1080, hiDPI: true); restored.save(pointer)
  var byDefault = Preset(); byDefault.name = "Default"; byDefault.resolution = .displayDefault; restored.save(byDefault)
  precondition(PresetStore(defaults: defaults).items.first { $0.name == "Default" }?.resolution?.isDisplayDefault == true)
  restored.remove(byDefault.id)
  let loaded = PresetStore(defaults: defaults).items.first { $0.name == "Pointer" }
  precondition(loaded?.pointerSize == 2.5 && loaded?.resolution == DisplayResolution(width: 1920, height: 1080, hiDPI: true))
  restored.remove(pointer.id)
  var zoom = Preset(); zoom.name = "Zoom"; zoom.zoomHotkeys = true; zoom.zoomStyle = ZoomSettings.Style.pictureInPicture.rawValue
  zoom.zoomMaxFactor = 4; zoom.zoomToggleShortcut = "28,1572864"; zoom.zoomInShortcut = "off"; restored.save(zoom)
  let zoomLoaded = PresetStore(defaults: defaults).items.first { $0.name == "Zoom" }
  precondition(zoomLoaded?.zoomHotkeys == true && zoomLoaded?.zoomStyle == 1 && zoomLoaded?.zoomMaxFactor == 4)
  precondition(zoomLoaded?.zoomToggleShortcut == "28,1572864" && zoomLoaded?.zoomInShortcut == "off")
  restored.remove(zoom.id)
  var second = Preset(); second.name = "Second"; restored.save(second)
  restored.move(second.id, by: -1)
  precondition(PresetStore(defaults: defaults).items.map(\.name) == ["Second", "Test"])
  restored.move(second.id, by: -1)  // already first: no change
  restored.move(preset.id, by: 1)   // already last: no change
  precondition(PresetStore(defaults: defaults).items.map(\.name) == ["Second", "Test"])
  print("PASS: persistent save, overwrite without duplicate, remembered selection, app lists, reorder")
 }
}
