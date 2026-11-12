import AppKit
import SwiftUI

/// Darker than system green in light mode, so the dashes and the word stay legible on the window background.
private let freeColor = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .systemGreen : NSColor(srgbRed: 0.08, green: 0.5, blue: 0.2, alpha: 1)
})

private extension SlotState {
    var fill: Color {
        switch self {
        case .free: return .clear
        case .used: return Color(nsColor: .controlBackgroundColor)
        case .textOnly: return Color.yellow.opacity(0.28)
        case .system: return Color.purple.opacity(0.2)
        case .unavailable: return Color.secondary.opacity(0.08)
        }
    }
    var stroke: Color {
        switch self {
        case .free: return freeColor
        case .system: return Color.purple.opacity(0.6)
        case .unavailable: return Color.secondary.opacity(0.15)
        default: return Color.secondary.opacity(0.45)
        }
    }
    var title: String {
        switch self {
        case .free: return L("key.free")
        case .used: return L("key.used")
        case .textOnly: return L("key.textOnly")
        case .system: return L("key.system")
        case .unavailable: return L("key.unavailable")
        }
    }
}

/// The key's outline. A free key is an empty dashed slot; every other state is a solid keycap.
private struct KeyPlate: View {
    let state: SlotState
    var selected = false
    var cornerRadius: CGFloat = 5

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        let width: CGFloat = selected ? 2 : state == .free ? 1.5 : 1
        shape.fill(state.fill)
            .overlay(shape.strokeBorder(selected ? appTint : state.stroke, style: StrokeStyle(lineWidth: width, dash: state == .free ? [4, 3] : [])))
    }
}

struct KeyCell: View {
    @ObservedObject var model: AppModel
    let key: KeySpec
    let width: CGFloat
    let height: CGFloat

    private var uses: [KeyUse] { model.keyMap.uses(key, model.keyboardModifiers) }
    private var state: SlotState { model.keyMap.state(key, model.keyboardModifiers) }
    private var names: String { uses.map(\.name).joined(separator: " / ") }
    private var caption: String {
        switch state {
        case .free, .unavailable: return ""
        case .system: return L("key.system")
        case .used, .textOnly: return names
        }
    }

    private var face: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 2) {
                Text(key.label).font(.system(size: 13, weight: .semibold)).lineLimit(1).foregroundColor(state == .unavailable ? .secondary : .primary)
                Spacer(minLength: 0)
                Text(key.shiftLabel).font(.system(size: 10)).foregroundColor(.secondary)
            }
            Text(caption).font(.system(size: 9)).lineLimit(2).foregroundColor(state == .used || state == .textOnly ? .primary : .secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4).padding(.vertical, 3)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(KeyPlate(state: state, selected: model.selectedKeyCode == key.id))
        .contentShape(Rectangle())
    }

    var body: some View {
        if key.id < 0 {
            Text(key.label).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                .frame(width: width, height: height)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.08)))
                .accessibilityHidden(true)
        } else {
            Button { model.selectedKeyCode = key.id } label: { face }
                .buttonStyle(.plain)
                .help(names.isEmpty ? state.title : names)
                .accessibilityLabel(KeyboardLayout.modifierLabel(model.keyboardModifiers) + key.label + " " + state.title + " " + names)
        }
    }
}

struct KeyboardPicture: View {
    @ObservedObject var model: AppModel
    private let rowHeight: CGFloat = 54, gap: CGFloat = 4

    var body: some View {
        let rows = KeyboardLayout.rows(model.keyboardKind)
        GeometryReader { geometry in
            let unit = (geometry.size.width + gap) / KeyboardLayout.unitsPerRow
            VStack(alignment: .leading, spacing: gap) {
                ForEach(rows.indices, id: \.self) { index in
                    HStack(spacing: gap) {
                        ForEach(rows[index]) { key in
                            KeyCell(model: model, key: key, width: unit * key.width - gap, height: rowHeight)
                        }
                    }
                }
            }
        }
        .frame(height: CGFloat(rows.count) * (rowHeight + gap) - gap)
    }
}

struct KeyLegend: View {
    private func item(_ state: SlotState) -> some View {
        HStack(spacing: 4) {
            KeyPlate(state: state, cornerRadius: 3).frame(width: 18, height: 14).accessibilityHidden(true)
            Text(state.title).font(.caption).lineLimit(1).fixedSize()
        }
    }
    var body: some View {
        HStack(spacing: 14) {
            item(.free); item(.used); item(.textOnly); item(.system); item(.unavailable)
            Spacer(minLength: 0)
        }
    }
}

/// All eight modifier sets of the key clicked on the keyboard.
struct KeyDetail: View {
    @ObservedObject var model: AppModel
    let key: KeySpec

    private func text(_ modifiers: Int) -> String {
        let uses = model.keyMap.uses(key, modifiers)
        if !uses.isEmpty {
            return uses.map { $0.name + ($0.context == 1 ? " (" + L("context.mark") + ")" : "") }.joined(separator: " / ")
        }
        return model.keyMap.state(key, modifiers) == .system ? L("key.system") : L("key.free")
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], alignment: .leading, spacing: 3) {
            ForEach(KeyboardLayout.modifierSets, id: \.self) { modifiers in
                let state = model.keyMap.state(key, modifiers)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(KeyboardLayout.modifierLabel(modifiers) + key.label)
                        .font(.system(.body, design: .monospaced)).lineLimit(1).fixedSize().frame(minWidth: 72, alignment: .leading)
                    Text(text(modifiers)).foregroundColor(state == .free ? freeColor : state == .system ? .purple : .primary).lineLimit(1).truncationMode(.middle)
                        .help(text(modifiers))
                }
            }
        }
    }
}

struct KeyboardPane: View {
    @ObservedObject var model: AppModel

    private func title(_ modifiers: Int) -> String {
        let label = modifiers == 0 ? L("modifier.none") : KeyboardLayout.modifierLabel(modifiers)
        return "\(label) \(model.keyMap.freeKeys(modifiers).count)"
    }

    var controls: some View {
        HStack(spacing: 10) {
            Text(L("field.freeCount")).lineLimit(1).fixedSize()
            Picker(L("a11y.modifiers"), selection: $model.keyboardModifiers) {
                ForEach(KeyboardLayout.modifierSets, id: \.self) { Text(title($0)).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            Spacer(minLength: 0)
            Picker(L("a11y.keyboardSide"), selection: $model.keyboardUsesBaseline) {
                Text(L("column.target")).tag(false)
                Text(L("column.baseline")).tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize().help(L("tip.keyboardSide"))
            Picker(L("a11y.keyboardKind"), selection: $model.keyboardKind) {
                Text(L("keyboard.jis")).tag(KeyboardKind.jis)
                Text(L("keyboard.ansi")).tag(KeyboardKind.ansi)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            controls
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    KeyboardPicture(model: model)
                    KeyLegend()
                    if let key = model.selectedKey {
                        KeyDetail(model: model, key: key)
                    } else {
                        Text(L("key.hint")).font(.callout).foregroundColor(.secondary)
                    }
                    if !model.keyMap.unplaced.isEmpty {
                        Text(String(format: L("key.unplaced"), model.keyMap.unplaced.joined(separator: " / "))).font(.caption).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.trailing, 2)
            }
        }
    }
}
