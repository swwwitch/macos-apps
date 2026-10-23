import Foundation

func verifyNativeActions(_ catalog: ShortcutCatalog) {
    let url = URL(fileURLWithPath: "Resources/NativeActions.json")
    let library = try! JSONDecoder().decode(NativeActionLibrary.self, from: Data(contentsOf: url))
    precondition(library.actions.count == 305 && library.unsupported.count == 52)
    precondition(Set(library.actions.map(\.id)).count == library.actions.count)
    let sources = Set(library.actions.map(\.sourceID))
    let unsupported = Set(library.unsupported.map(\.sourceID))
    let pending = Set(catalog.rows.filter { $0.native != nil && $0.command == nil }.compactMap { $0.native?.id })
    precondition(sources.isDisjoint(with: unsupported))
    precondition(sources.union(unsupported) == pending, "Every reference-only row must have executable keys or an explicit reason")
    precondition(library.actions.allSatisfy { !$0.strokes.isEmpty && $0.strokes.allSatisfy { $0.code < 128 } })
    let merged = library.actions.first { $0.sourceID == "tables.62" }!
    precondition(merged.strokes[0].code == 46 && merged.strokes[0].modifiers == 4352)
    let doubleReturn = library.actions.first { $0.sourceID == "tables.31" }!
    precondition(doubleReturn.strokes.count == 2 && doubleReturn.strokes[0] == doubleReturn.strokes[1])
    precondition(library.actions(for: "objects.10").map(\.label) == ["←", "→", "↑", "↓"])
    precondition(library.actions(for: "presentation.14").map(\.label) == Array("0123456789").map(String.init))
    precondition(library.actions.first { $0.sourceID == "general.00" }!.strokes[0].fn)
    precondition(library.actions.first { $0.sourceID == "textFormat.06" }!.strokes[0].code == 117)
    let save = library.actions.first { $0.sourceID == "general.05" }!
    precondition(!save.needsRegistration(nil) && !save.needsRegistration(save.originalCombo))
    let newKey = KeyCombo(code: 1, modifiers: 4352)
    precondition(save.needsRegistration(newKey))
    var profiles = ShortcutProfiles(); profiles.selected = .custom
    profiles.setNativeBinding(save.id, newKey)
    profiles.selected = .custom2
    precondition(profiles.nativeBinding(save.id) == nil)
    profiles.setNativeBinding(save.id, KeyCombo(code: 11, modifiers: 4352))
    profiles.selected = .custom
    precondition(profiles.nativeBinding(save.id) == newKey)
    let data = try! JSONEncoder().encode(profiles)
    precondition(try! JSONDecoder().decode(ShortcutProfiles.self, from: data) == profiles)
    profiles.resetCurrentStandardKeys()
    precondition(profiles.nativeBinding(save.id) == nil && profiles.custom2.nativeBindings[save.id] != nil)
    let legacy = Data("{\"selected\":\"custom2\",\"specialEnabled\":false,\"custom\":{\"shortcuts\":{},\"enabled\":{\"group\":false}},\"custom2\":{\"shortcuts\":{},\"enabled\":{}}}".utf8)
    let old = try! JSONDecoder().decode(ShortcutProfiles.self, from: legacy)
    precondition(old.selected == .custom2 && !old.specialEnabled && old.custom.enabled["group"] == false && old.custom.nativeBindings.isEmpty)
    print("PASS: 305 executable native key actions, 52 explicit gesture/style exclusions, context variants, no-op defaults, independent bindings, reset and build-14 compatibility")
}
