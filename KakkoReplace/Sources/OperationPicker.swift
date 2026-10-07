import SwiftUI
import AppKit

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

struct OperationPicker: NSViewRepresentable {
    @Binding var selection: String
    var onChange: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        let menu = NSMenu(); menu.autoenablesItems = false
        for (index, group) in OperationGroup.all.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            let heading = NSMenuItem(title: L(group.titleKey), action: nil, keyEquivalent: "")
            heading.isEnabled = false
            menu.addItem(heading)
            for id in group.ids {
                let item = NSMenuItem(title: OperationGroup.displayTitle(id), action: nil, keyEquivalent: "")
                item.representedObject = id; item.indentationLevel = 1
                menu.addItem(item)
            }
        }
        popup.menu = menu; popup.target = context.coordinator; popup.action = #selector(Coordinator.changed(_:))
        popup.setAccessibilityLabel(L("operation"))
        popup.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return popup
    }
    func updateNSView(_ popup: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        if let item = popup.itemArray.first(where: { $0.representedObject as? String == selection }) { popup.select(item) }
    }
    final class Coordinator: NSObject {
        var parent: OperationPicker
        init(_ parent: OperationPicker) { self.parent = parent }
        @objc func changed(_ popup: NSPopUpButton) {
            guard let id = popup.selectedItem?.representedObject as? String, BracketAction.ids.contains(id) else { return }
            parent.selection = id
            parent.onChange()
        }
    }
}
