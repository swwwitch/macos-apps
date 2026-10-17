import SwiftUI

// Grouping is presentation-only. Action IDs and saved key bindings stay unchanged.
struct OperationGroup {
    let titleKey: String
    let ids: [String]
    static let all: [OperationGroup] = [
        .init(titleKey: "groupFullWidth", ids: ["round", "square", "lenticular", "angle", "doubleAngle", "corner", "curly", "doubleCorner"]),
        .init(titleKey: "groupHalfWidth", ids: ["asciiRound", "asciiSquare", "asciiCurly", "asciiAngle", "asciiSingle", "asciiDouble"]),
        .init(titleKey: "groupQuotes", ids: ["smartDouble", "smartSingle"]),
        .init(titleKey: "groupComments", ids: ["html", "css"]),
        .init(titleKey: "groupForce", ids: BracketAction.forceIDs),
        .init(titleKey: "groupOther", ids: BracketAction.operations + ["palette"])
    ]
    static func displayTitle(_ id: String) -> String {
        if all[0].ids.contains(id) { return L("widthFull") + "  " + actionTitle(id) }
        if all[1].ids.contains(id) { return L("widthHalf") + "  " + actionTitle(id) }
        if id == "html" { return "HTML  " + actionTitle(id) }
        if id == "css" { return "CSS  " + actionTitle(id) }
        if BracketAction.forceIDs.contains(id) { return L("widthFull") + "  " + actionTitle(id) }
        return actionTitle(id)
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
