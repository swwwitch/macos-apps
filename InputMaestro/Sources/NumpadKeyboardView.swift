import AppKit
import SwiftUI
extension NumpadGroup {
    var color: Color {
        switch self {
        case .numpad: return .blue
        case .numberRow: return .green
        case .operators: return .orange
        case .editing: return .purple
        }
    }
}

struct NumpadKeyboardView: View {
    @ObservedObject var model: IntegrationModel
    /// "auto", "ansi" or "jis".
    @AppStorage("keyboardLayout") private var layoutChoice = "auto"
    var layout: KeyboardLayout { KeyboardLayout(rawValue: layoutChoice) ?? .detected }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ForEach(NumpadGroup.allCases) { group in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3).fill(group.color.opacity(model.isOn(group) ? 0.8 : 0.25)).frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                        Text(L("numpadGroup." + group.rawValue)).font(.system(size: 11)).foregroundColor(model.isOn(group) ? .primary : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(L("numpadGroup." + group.rawValue) + (model.isOn(group) ? "" : " (" + L("kb.off") + ")"))
                }
                Spacer()

            }
            GeometryReader { geo in
                let gap: CGFloat = 4
                let unit = (geo.size.width + gap) / CGFloat(layout.width)
                VStack(alignment: .leading, spacing: gap) {
                    ForEach(Array(layout.rows.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: gap) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                                NumpadKeyCapView(model: model, key: key, layout: layout)
                                    .frame(width: max(0, unit * CGFloat(key.width) - gap), height: index == 0 ? unit * 0.62 : unit - gap)
                            }
                        }
                    }
                }
            }
            // Fits both ways: limited by the width or, in a low window, by the height.
            .aspectRatio(CGFloat(layout.width) / 5.75, contentMode: .fit)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}

struct NumpadKeyCapView: View {
    @ObservedObject var model: IntegrationModel
    let key: KeySpec
    let layout: KeyboardLayout

    var mapping: KeyMapping? { key.code.flatMap { code in KeyMap.all.first { $0.from == Int64(code) } } }
    var on: Bool { mapping.map { model.isOn($0.group) } ?? false }
    /// The trigger key(s) chosen for the layout shown: fn and/or ⇪ (Caps Lock).
    var isFn: Bool {
        guard key.code == nil else { return false }
        let trigger = layout == .jis ? model.jisTrigger : model.ansiTrigger
        return (key.caption == "fn" && trigger.usesFn) || (key.caption == "⇪" && trigger.usesCapsLock)
    }
    var caption: String { key.caption ?? key.code.map { KeyName.name(for: $0) } ?? "" }

    var body: some View {
        if key.code == nil && key.caption == nil {
            Color.clear
        } else {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6).fill(background)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(border, lineWidth: mapping == nil ? 1 : 1.5))
                Text(caption).font(.system(size: key.caption == nil || caption.count == 1 ? 11 : 9, weight: .medium))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundColor(isFn ? .white : (mapping == nil ? Color.secondary.opacity(0.6) : .secondary))
                    .padding(.leading, 5).padding(.top, 3)
                if let mapping {
                    // What Fn+key types, under the key name.
                    Text(output(mapping)).font(.system(size: 15, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .foregroundColor(on ? mapping.group.color : .secondary.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.top, 14).padding(.bottom, 4).padding(.horizontal, 3)
                }
            }
            .help(tooltip)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tooltip)
        }
    }

    /// Short forms for the named keys; the table and the tooltip use the full names.
    func output(_ mapping: KeyMapping) -> String {
        switch mapping.to.first?.code {
        case KeyMap.tab.code: return "⇥"
        case KeyMap.delete.code: return "⌫"
        case KeyMap.returnKey.code: return "↩"
        case KeyMap.keypadEnter.code: return "Enter"
        default: return mapping.toLabel
        }
    }
    var tooltip: String {
        if isFn { return L("numpad.triggerHelp") }
        guard let mapping else { return caption }
        let text = mapping.fromLabel + " → " + mapping.toLabel
        return on ? text : text + " (" + L("kb.off") + ")"
    }
    var background: Color {
        if isFn { return Color.accentColor.opacity(model.numpadEnabled ? 0.85 : 0.35) }
        guard let mapping else { return Color(nsColor: .controlBackgroundColor).opacity(0.6) }
        return on ? mapping.group.color.opacity(0.14) : Color(nsColor: .textBackgroundColor)
    }
    var border: Color {
        guard let mapping, on else { return Color(nsColor: .separatorColor) }
        return mapping.group.color.opacity(0.8)
    }
}
