import AppKit
import SwiftUI

/// Sheet with the keyboard: assigned keys show the favorite's name; free keys are plain.
struct KeyboardMapView: View {
    @ObservedObject var model: Model
    @Environment(\.dismiss) private var dismiss
    @State private var flagsRaw: UInt = 0
    private var sets: [NSEvent.ModifierFlags] { KeyUsage.modifierSets(model.items) }
    private var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: flagsRaw) }
    var body: some View {
        let usage = KeyUsage.map(model.items, flags: flags)
        let rows = KeyboardRows.rows
        let free = rows.dropFirst().joined().filter { usage[$0] == nil }.count
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("keyboardTitle")).font(.headline)
                Spacer()
                if sets.count > 1 {
                    Picker(L("modifiers"), selection: $flagsRaw) {
                        ForEach(sets, id: \.rawValue) { Text(KeyboardRows.symbols($0)).tag($0.rawValue) }
                    }.fixedSize()
                } else if let only = sets.first {
                    Text(String(format: L("modifiersFixed"), KeyboardRows.symbols(only))).foregroundColor(.secondary)
                }
            }
            if sets.isEmpty {
                Text(L("noHotkeys")).foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: 6) {
                            ForEach(row, id: \.self) { code in KeyCap(code: code, users: usage[code] ?? [], small: index == 0) { item in
                                model.query = ""; model.selection = [item.id]; dismiss()
                            } }
                        }
                        .padding(.leading, CGFloat([0, 0, 22, 34, 52][index]))
                    }
                }
                Text(String(format: L("keyboardSummary"), KeyboardRows.symbols(flags), usage.count, free))
                    .font(.callout).foregroundColor(.secondary)
                let clashes = usage.filter { $0.value.count > 1 }
                if !clashes.isEmpty {
                    Label(String(format: L("keyClash"), clashes.map { (FavoriteItem.keyLabel($0.key) ?? "?") }.sorted().joined(separator: " ")),
                          systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundColor(.orange)
                }
            }
            HStack { Spacer(); Button(L("done")) { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(20).fixedSize()
        .onAppear { if !sets.contains(flags) { flagsRaw = sets.first?.rawValue ?? 0 } }
        .onExitCommand { dismiss() }
    }
}

struct KeyCap: View {
    let code: Int
    let users: [FavoriteItem]
    var small = false
    var select: (FavoriteItem) -> Void
    private var used: Bool { !users.isEmpty }
    private var label: String { FavoriteItem.keyLabel(code) ?? "" }
    private var names: String { users.map(\.name).joined(separator: " / ") }
    private var fill: Color {
        if users.count > 1 { return Color.orange.opacity(0.35) }
        return used ? appTint.opacity(0.25) : Color(nsColor: .controlBackgroundColor)
    }
    private var height: CGFloat { small ? (used ? 46 : 26) : 52 }
    private var face: some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: small ? 10 : 13, weight: .semibold))
            if !small || used {
                Text(names).font(.system(size: 9)).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
            }
        }
        .frame(width: 58, height: height)
        .foregroundColor(used ? .primary : .secondary)
        .background(RoundedRectangle(cornerRadius: 6).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(used ? appTint : Color.gray.opacity(0.35)))
    }
    var body: some View {
        Button { if let first = users.first { select(first) } } label: { face }
            .buttonStyle(.plain).disabled(!used)
            .help(users.map { "\($0.name)\n\($0.path)" }.joined(separator: "\n\n"))
            .accessibilityLabel(label + ": " + (used ? users.map(\.name).joined(separator: ", ") : L("keyFree")))
    }
}
