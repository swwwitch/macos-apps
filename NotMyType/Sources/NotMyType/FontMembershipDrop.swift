import AppKit
import SwiftUI

/// Private, ID-only payload: never treat an internal drag as a file import.
enum FontMembershipDrag {
    static let type = (Bundle.main.bundleIdentifier ?? "jp.dtp-transit.notmytype") + ".font-membership"
    static func encode(_ ids: [UUID]) -> Data? { try? JSONEncoder().encode(ids) }
    static func decode(_ data: Data) -> [UUID]? { try? JSONDecoder().decode([UUID].self, from: data) }
}

@MainActor
struct FontMembershipDrop: ViewModifier {
    let receive: @MainActor ([UUID]) -> Void
    @State private var targeted = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 5).fill(targeted ? Color.accentColor.opacity(0.2) : Color.clear))
            .onDrop(of: [FontMembershipDrag.type], isTargeted: $targeted) { providers in
                let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(FontMembershipDrag.type) }
                guard !matching.isEmpty else { return false }
                for provider in matching {
                    provider.loadDataRepresentation(forTypeIdentifier: FontMembershipDrag.type) { data, _ in
                        guard let data, let ids = FontMembershipDrag.decode(data), !ids.isEmpty else { return }
                        Task { @MainActor in receive(ids) }
                    }
                }
                return true
            }
    }
}
