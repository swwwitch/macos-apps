import AppKit
import SwiftUI
import Carbon

// The keyboard view, after FnNumpad's KeyboardView: each key shows what ⌃+key does, coloured by category.

extension KeyboardLayout {
    /// The connected keyboard's type (JIS or not); ISO is drawn like ANSI.
    static var detected: KeyboardLayout {
        KBGetLayoutType(Int16(LMGetKbdType())) == UInt32(kKeyboardJIS) ? .jis : .ansi
    }
}

extension KeyCategory {
    var color: Color {
        switch self {
        case .cursor: return .blue
        case .keySend: return .green
        case .editing: return .orange
        case .killYank: return .purple
        }
    }
}

/// Key names as the current input source types them (from FnNumpad's KeyName).
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
                ForEach(KeyCategory.allCases) { category in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3).fill(category.color.opacity(model.enabled ? 0.8 : 0.25)).frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                        Text(category.title).font(.system(size: 11)).foregroundColor(model.enabled ? .primary : .secondary)
                    }
                    .accessibilityElement(children: .combine)
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

    /// Every command on this key; the one without extra modifiers is drawn on the key, all of them in the tooltip.
    var commands: [Command] { key.code.map { code in CommandTable.all.filter { $0.key == Int64(code) } } ?? [] }
    var primary: Command? { commands.first { $0.mods.isEmpty } ?? commands.first }
    func isOn(_ command: Command) -> Bool { model.groupActive(command.group) && !model.disabled.contains(command.id) }
    /// The key(s) held instead of ⌃ for the layout shown: ⌃ and/or ⇪ (Caps Lock).
    var isTrigger: Bool {
        guard key.code == nil else { return false }
        let trigger = layout == .jis ? model.jisTrigger : model.ansiTrigger
        return (key.caption == "⌃" && trigger.usesControl) || (key.caption == "⇪" && trigger.usesCapsLock)
    }
    var caption: String { key.caption ?? key.code.map { KeyName.name(for: $0) } ?? "" }

    var body: some View {
        if key.code == nil && key.caption == nil {
            Color.clear
        } else {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6).fill(background)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(border, lineWidth: primary == nil ? 1 : 1.5))
                Text(caption).font(.system(size: key.caption == nil || caption.count == 1 ? 11 : 9, weight: .medium))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundColor(isTrigger ? .white : (primary == nil ? Color.secondary.opacity(0.6) : .secondary))
                    .padding(.leading, 5).padding(.top, 3)
                if let primary {
                    // What ⌃+key does, under the key name.
                    Text(L("short." + primary.id)).font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.45)
                        .foregroundColor(isOn(primary) ? primary.category.color : .secondary.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.top, 14).padding(.bottom, 4).padding(.horizontal, 3)
                }
            }
            .help(tooltip)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tooltip)
        }
    }

    var tooltip: String {
        if isTrigger { return L("kb.triggerHelp") }
        guard !commands.isEmpty else { return caption }
        return commands.map { $0.label + " " + $0.title + (isOn($0) ? "" : " (" + L("kb.off") + ")") }.joined(separator: "\n")
    }
    var background: Color {
        if isTrigger { return Color.accentColor.opacity(model.enabled ? 0.85 : 0.35) }
        guard let primary else { return Color(nsColor: .controlBackgroundColor).opacity(0.6) }
        return isOn(primary) ? primary.category.color.opacity(0.14) : Color(nsColor: .textBackgroundColor)
    }
    var border: Color {
        guard let primary, isOn(primary) else { return Color(nsColor: .separatorColor) }
        return primary.category.color.opacity(0.8)
    }
}
