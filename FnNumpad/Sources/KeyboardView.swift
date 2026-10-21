import AppKit
import SwiftUI
import Carbon

// The keyboard view, after DocklessLauncher's KeyboardView: each key shows what Fn+key types, coloured by group.

extension KeyboardLayout {
    /// The connected keyboard's type (JIS or not); ISO is drawn like ANSI.
    static var detected: KeyboardLayout {
        KBGetLayoutType(Int16(LMGetKbdType())) == UInt32(kKeyboardJIS) ? .jis : .ansi
    }
}

extension KeyGroup {
    var color: Color {
        switch self {
        case .numpad: return .blue
        case .numberRow: return .green
        case .operators: return .orange
        case .editing: return .purple
        }
    }
}

/// Key names as the current input source types them (from DocklessLauncher's KeyName).
enum KeyName {
    static let special: [UInt32: String] = [36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 102: "英数", 104: "かな", 93: "¥", 94: "_"]
    static func name(for code: UInt32) -> String {
        if let name = special[code] { return name }
        if let typed = translate(code), !typed.isEmpty { return typed.uppercased() }
        return "#\(code)"
    }
    /// The character the key types without modifiers in the current layout (falls back to an ASCII-capable layout).
    private static func translate(_ code: UInt32) -> String? {
        for source in [TISCopyCurrentKeyboardLayoutInputSource(), TISCopyCurrentASCIICapableKeyboardLayoutInputSource()] {
            guard let source = source?.takeRetainedValue(),
                  let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { continue }
            let layoutData = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
            var deadKeys: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status = layoutData.withUnsafeBytes { raw -> OSStatus in
                guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
                return UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                      OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
            }
            let text = String(utf16CodeUnits: chars, count: length).trimmingCharacters(in: .whitespacesAndNewlines)
            if status == noErr, !text.isEmpty, text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) { return text }
        }
        return nil
    }
}

struct KeyboardView: View {
    @ObservedObject var model: Model
    /// "auto", "ansi" or "jis".
    @AppStorage("keyboardLayout") private var layoutChoice = "auto"
    var layout: KeyboardLayout { KeyboardLayout(rawValue: layoutChoice) ?? .detected }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ForEach(KeyGroup.allCases) { group in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3).fill(group.color.opacity(model.isOn(group) ? 0.8 : 0.25)).frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                        Text(group.shortTitle).font(.system(size: 11)).foregroundColor(model.isOn(group) ? .primary : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(group.title + (model.isOn(group) ? "" : " (" + L("kb.off") + ")"))
                }
                Spacer()
                Picker(L("kb.layout"), selection: $layoutChoice) {
                    Text(String(format: L("kb.layoutAuto"), L(KeyboardLayout.detected == .jis ? "kb.jis" : "kb.ansi"))).tag("auto")
                    Text(L("kb.ansi")).tag("ansi")
                    Text(L("kb.jis")).tag("jis")
                }
                .fixedSize()
            }
            GeometryReader { geo in
                let gap: CGFloat = 4
                let unit = (geo.size.width + gap) / CGFloat(layout.width)
                VStack(alignment: .leading, spacing: gap) {
                    ForEach(Array(layout.rows.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: gap) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                                KeyCapView(model: model, key: key, layout: layout)
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

struct KeyCapView: View {
    @ObservedObject var model: Model
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
        if isFn { return L("kb.fnHelp") }
        guard let mapping else { return caption }
        let text = String(format: L("chipLabel"), mapping.fromLabel, mapping.toLabel)
        return on ? text : text + " (" + L("kb.off") + ")"
    }
    var background: Color {
        if isFn { return Color.accentColor.opacity(model.enabled ? 0.85 : 0.35) }
        guard let mapping else { return Color(nsColor: .controlBackgroundColor).opacity(0.6) }
        return on ? mapping.group.color.opacity(0.14) : Color(nsColor: .textBackgroundColor)
    }
    var border: Color {
        guard let mapping, on else { return Color(nsColor: .separatorColor) }
        return mapping.group.color.opacity(0.8)
    }
}
