import SwiftUI

// Grouping is presentation-only. Action IDs and saved key bindings stay unchanged.
struct OperationGroup {
    let titleKey: String
    let ids: [String]
    static let all: [OperationGroup] = [
        .init(titleKey: "groupFullWidth", ids: ["round", "square", "curly", "angle", "doubleAngle", "lenticular", "corner", "doubleCorner"]),
        .init(titleKey: "groupHalfWidth", ids: ["asciiRound", "asciiSquare", "asciiCurly", "asciiAngle", "asciiSingle", "asciiDouble", "asciiBacktick"]),
        .init(titleKey: "groupQuotes", ids: ["smartDouble", "smartSingle"]),
        .init(titleKey: "groupComments", ids: ["html", "css"]),
        .init(titleKey: "groupForce", ids: BracketAction.forceIDs),
        .init(titleKey: "groupOther", ids: BracketAction.operations + ["palette"])
    ]
    /// The groups the palette shows as buttons (force variants are a checkbox there).
    static var paletteGroups: [OperationGroup] { all.filter { $0.titleKey != "groupForce" } }
    var paletteIDs: [String] { ids.filter { $0 != "palette" } }
    static func displayTitle(_ id: String) -> String {
        if all[0].ids.contains(id) { return L("widthFull") + "  " + actionTitle(id) }
        if all[1].ids.contains(id) { return L("widthHalf") + "  " + actionTitle(id) }
        if id == "html" { return "HTML  " + actionTitle(id) }
        if id == "css" { return "CSS  " + actionTitle(id) }
        if BracketAction.forceIDs.contains(id) { return L("widthFull") + "  " + actionTitle(id) }
        return actionTitle(id)
    }
}

/// Checkboxes choosing which palette buttons the compact palette keeps.
struct CompactPalettePicker: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(OperationGroup.paletteGroups, id: \.titleKey) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(L(group.titleKey)).font(.caption).foregroundColor(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: group.titleKey == "groupOther" ? 200 : 90), alignment: .leading)], alignment: .leading, spacing: 4) {
                        ForEach(group.paletteIDs, id: \.self) { id in
                            Toggle(actionTitle(id), isOn: Binding(get: { model.compactPaletteIDs.contains(id) }, set: { on in
                                model.compactPaletteIDs.removeAll { $0 == id }
                                if on { model.compactPaletteIDs.append(id) }
                                model.save(); (NSApp.delegate as? AppDelegate)?.palette?.refresh()
                            })).toggleStyle(.checkbox).help(OperationGroup.displayTitle(id))
                        }
                    }
                }
            }
        }
    }
}

/// One operation in the hotkey list: its title and the shared hotkey field.
/// The group heading already says full/half width, so the row shows the plain title.
struct ShortcutRow: View {
    @ObservedObject var model: Model
    let id: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(actionTitle(id)).frame(width: 200, alignment: .leading)
            HotkeyField(id: "bracket." + id,
                        combo: Binding(get: { model.bindings[id].map(KeyCombo.init) },
                                       set: { combo in
                                           if let combo { model.bindings[id] = Shortcut(combo) } else { model.bindings.removeValue(forKey: id) }
                                           model.save()
                                       }),
                        defaultCombo: Shortcut.articleDefaults[id].map(KeyCombo.init), allowsClear: true,
                        others: model.otherHotkeys(except: id),
                        registered: model.registrationFailures[id] == nil, isEnabled: !model.disabled)
        }
    }
}
