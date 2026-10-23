import Foundation
@main struct SettingsSharingTests {
 @MainActor static func main() throws {
  var a = Preset(); a.name = "A"; a.clock = true
  var b = Preset(); b.name = "B"; b.timerMinutes = 45
  var c = Preset(); c.name = "C"
  let encode = { (presets: [Preset]) in try! JSONEncoder().encode(presets) }
  let decode = { (value: Any?) in try! JSONDecoder().decode([Preset].self, from: value as! Data) }
  let file: NSDictionary = ["presets": encode([a, b]), "timerEnabled": false]
  let current: NSDictionary = ["presets": encode([a, c]), "timerEnabled": true]
  let merged = PresetStore.merged(file, current)
  precondition(decode(merged.values["presets"]).map(\.name) == ["A", "C", "B"] && merged.added == 1, "adds only new presets")
  precondition(decode(merged.values["presets"])[2].timerMinutes == 45, "added preset keeps its values")
  precondition(merged.values["timerEnabled"] as? Bool == true, "this Mac's Use Timer stays")
  let empty = PresetStore.merged(file, [:])
  precondition(decode(empty.values["presets"]).count == 2 && empty.values["timerEnabled"] as? Bool == false, "missing values come from the file")
  precondition(PresetStore.syncedKeys == ["presets", "hideOthersOnSwitch", "hideOthersDelay"])
  print("PASS: 設定の共有 add (merge) keeps this Mac's presets and values and appends new presets")
 }
}
