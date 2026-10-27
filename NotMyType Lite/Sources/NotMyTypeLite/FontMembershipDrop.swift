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
            // Extend the drop surface into the row's existing vertical insets.
            // Cancel this padding after attaching the drop handler so List keeps its normal row height.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 6).fill(targeted ? Color.accentColor.opacity(0.25) : Color.clear))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .opacity(targeted ? 1 : 0)
                    .allowsHitTesting(false)
            }
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
            .padding(.vertical, -6)
    }
}
