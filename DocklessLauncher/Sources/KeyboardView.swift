import AppKit
import SwiftUI
import Carbon

extension KeyboardLayout {
    /// The connected keyboard's type (JIS or not); ISO is drawn like ANSI.
    static var detected: KeyboardLayout {
        KBGetLayoutType(Int16(LMGetKbdType())) == UInt32(kKeyboardJIS) ? .jis : .ansi
    }
}

/// One colour per modifier set, in the order the sets appear.
let modifierPalette: [Color] = [.blue, .green, .orange, .purple, .red, .teal, .pink, .brown, .indigo, .mint]

/// The keyboard view: keys show the apps registered on them for the chosen modifier set (or all sets).
struct KeyboardView: View {
    @ObservedObject var model: Model
    /// Selected modifier set; -1 shows every set.
    @AppStorage("keyboardModifiers") private var selected = -1
    /// "auto", "ansi" or "jis".
    @AppStorage("keyboardLayout") private var layoutChoice = "auto"
    var layout: KeyboardLayout { KeyboardLayout(rawValue: layoutChoice) ?? .detected }

    /// Modifier sets in use, fewest modifiers first (⌃⌥ before ⌃⌥⌘ …).
    var combos: [UInt32] {
        Array(Set(model.entries.compactMap { $0.shortcut?.modifiers })).sorted { EntryRules.modifierRank($0) < EntryRules.modifierRank($1) }
    }
    func color(_ modifiers: UInt32) -> Color { modifierPalette[(combos.firstIndex(of: modifiers) ?? 0) % modifierPalette.count] }
    var current: UInt32? { selected >= 0 && combos.contains(UInt32(selected)) ? UInt32(selected) : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(L("kb.modifiers")).foregroundColor(.secondary)
                comboButton(nil, L("kb.all"))
                ForEach(combos, id: \.self) { combo in comboButton(combo, Shortcut(code: 0, modifiers: combo).modifierSymbols) }
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
                                KeyCapView(model: model, key: key, modifiers: current, combos: combos, color: color)
                                    .frame(width: max(0, unit * CGFloat(key.width) - gap), height: index == 0 ? unit * 0.62 : unit - gap)
                            }
                        }
                    }
                }
            }
            // Fits both ways: limited by the width or, in a low window, by the height (then centred).
            .aspectRatio(CGFloat(layout.width) / 5.75, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Text(current == nil ? L("kb.hintAll") : L("kb.hint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    func comboButton(_ combo: UInt32?, _ title: String) -> some View {
        let isOn = current == combo
        let tint = combo.map(color) ?? .accentColor
        return Button(action: { selected = combo.map { Int($0) } ?? -1 }) {
            Text(title).font(combo == nil ? .body : .system(.body, design: .monospaced))
                .padding(.horizontal, 9).padding(.vertical, 3)
                .foregroundColor(isOn ? .white : .primary)
                .background(RoundedRectangle(cornerRadius: 5).fill(isOn ? tint : Color(nsColor: .controlColor)))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(combo == nil ? Color(nsColor: .separatorColor) : tint, lineWidth: isOn ? 0 : 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct KeyCapView: View {
    @ObservedObject var model: Model
    let key: KeySpec
    /// nil: every modifier set.
    let modifiers: UInt32?
    let combos: [UInt32]
    let color: (UInt32) -> Color
    /// Names are shown only while the pointer is over the key; otherwise just icons.
    @State private var hovering = false
    /// A dragged key is over this one.
    @State private var dropTargeted = false
    @Environment(\.undoManager) private var undoManager

    var entries: [LaunchEntry] {
        guard let code = key.code else { return [] }
        return model.entries.filter { entry in
            guard let s = entry.shortcut, s.code == code else { return false }
            return modifiers == nil || s.modifiers == modifiers
        }.sorted { EntryRules.modifierRank($0.shortcut!.modifiers) < EntryRules.modifierRank($1.shortcut!.modifiers) }
    }
    var isSystem: Bool {
        guard let code = key.code, let modifiers else { return false }
        return model.systemShortcuts.contains(Shortcut(code: code, modifiers: modifiers).signature)
    }
    var caption: String { key.caption ?? key.code.map { KeyName.name(for: $0) } ?? "" }
    var tooltip: String {
        let lines = entries.map { e in (e.shortcut.map { $0.label + (e.doubleTap ? " ×2" : "") } ?? "") + "  " + e.name }
        if !lines.isEmpty { return lines.joined(separator: "\n") }
        if isSystem, let code = key.code, let modifiers { return String(format: L("row.system"), L(SystemShortcuts.nameKey(for: Shortcut(code: code, modifiers: modifiers)))) }
        return key.assignable && modifiers != nil ? L("kb.emptyHelp") : caption
    }

    var body: some View {
        if key.code == nil && key.caption == nil {
            Color.clear
        } else {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(background)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(dropTargeted ? Color.accentColor : border, lineWidth: dropTargeted ? 3 : (entries.isEmpty ? 1 : 1.5)))
                if isSystem && entries.isEmpty {
                    // Hatched: taken by a macOS shortcut.
                    Hatch().stroke(Color.secondary.opacity(0.35), lineWidth: 1).clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text(caption).font(.system(size: key.caption == nil || caption.count == 1 ? 11 : 9, weight: .medium))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundColor(key.assignable ? .secondary : Color.secondary.opacity(0.6))
                    .padding(.leading, 5).padding(.top, 3)
                // Below the key name, so the icon never covers it.
                content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.top, 15).padding(.bottom, 3).padding(.horizontal, 2)
            }
            .contentShape(Rectangle())
            // Launch on double-click so a stray click doesn't start an app; a single click on an empty key assigns one.
            .onTapGesture(count: 2) { doubleTapped() }
            .onTapGesture { tapped() }
            .onHover { hovering = $0 }
            // Drag a key onto another to move or swap its apps (only with one modifier set chosen).
            .onDrag {
                guard canDrag, let code = key.code else { return NSItemProvider() }
                return NSItemProvider(object: "\(KeyCapView.dragPrefix)\(code)" as NSString)
            }
            // Also takes apps from Finder: assigned to this key, or just added while every modifier set is shown.
            .onDrop(of: [.plainText] + AppDrop.types, isTargeted: Binding(get: { dropTargeted }, set: { dropTargeted = $0 && canDrop })) { providers in
                let apps = AppDrop.load(providers) { urls in
                    if let shortcut = newShortcut, urls.count == 1 { model.assignApp(urls[0], to: shortcut) }
                    else if !urls.isEmpty { model.addApps(urls) }
                }
                if apps { return true }
                guard canDrop, let modifiers, let target = key.code, let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                    guard let text = object as? String, text.hasPrefix(KeyCapView.dragPrefix),
                          let source = UInt32(text.dropFirst(KeyCapView.dragPrefix.count)), source != target else { return }
                    DispatchQueue.main.async { model.swapKeys(source, target, modifiers: modifiers, undoManager: undoManager) }
                }
                return true
            }
            .contextMenu {
                if entries.count == 1, let entry = entries.first {
                    EntryMenuItems(model: model, entry: entry)
                } else {
                    ForEach(entries) { entry in
                        Menu((entry.shortcut?.label ?? "") + "  " + entry.name) { EntryMenuItems(model: model, entry: entry) }
                    }
                }
                if let shortcut = newShortcut {
                    if !entries.isEmpty { Divider() }
                    Button(String(format: L("kb.assign"), shortcut.label)) { model.addApp(for: shortcut) }
                }
            }
            .help(tooltip)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(caption + (entries.isEmpty ? "" : ": " + entries.map(\.name).joined(separator: ", ")))
            .accessibilityAddTraits(.isButton)
        }
    }

    static let dragPrefix = "dockless-key:"
    var canDrag: Bool { modifiers != nil && !entries.isEmpty }
    var canDrop: Bool { modifiers != nil && key.assignable && key.code != nil }

    /// The shortcut an empty key would get: only with one modifier set chosen.
    var newShortcut: Shortcut? {
        guard key.assignable, let code = key.code, let modifiers else { return nil }
        return Shortcut(code: code, modifiers: modifiers)
    }
    func tapped() {
        if entries.isEmpty, let shortcut = newShortcut { model.addApp(for: shortcut) }
    }
    func doubleTapped() {
        if entries.count == 1, let entry = entries.first { model.launch(entry) }
        // Several apps on one key: the right-click menu chooses.
    }

    var background: Color {
        guard let first = entries.first, let m = first.shortcut?.modifiers else {
            return key.assignable ? Color(nsColor: .textBackgroundColor) : Color(nsColor: .controlBackgroundColor).opacity(0.6)
        }
        return color(m).opacity(first.enabled ? 0.16 : 0.06)
    }
    var border: Color {
        guard let m = entries.first?.shortcut?.modifiers else { return Color(nsColor: .separatorColor) }
        return color(m).opacity(0.8)
    }

    @ViewBuilder var content: some View {
        if entries.count == 1, let entry = entries.first {
            // One app: the icon fills the space under the key name; the name takes a line only while hovering.
            GeometryReader { geo in
                let nameHeight: CGFloat = hovering ? 12 : 0
                let side = max(12, min(geo.size.width - 6, geo.size.height - nameHeight))
                VStack(spacing: 0) {
                    icon(entry, size: side)
                        .overlay(alignment: .topTrailing) { badges(entry).offset(x: 4, y: -2) }
                    if hovering {
                        Text(entry.name).font(.system(size: 9)).lineLimit(1).truncationMode(.tail).minimumScaleFactor(0.7)
                            .foregroundColor(entry.enabled ? .primary : .secondary)
                            .frame(height: nameHeight)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            }
        } else if !entries.isEmpty && hovering {
            VStack(spacing: 0) {
                ForEach(entries.prefix(3)) { entry in
                    Text(entry.name).font(.system(size: 8)).lineLimit(1).truncationMode(.tail).minimumScaleFactor(0.7)
                        .foregroundColor(modifiers == nil ? entry.shortcut.map { color($0.modifiers) } ?? .primary : .primary)
                }
                if entries.count > 3 { Text("+\(entries.count - 3)").font(.system(size: 8)).foregroundColor(.secondary) }
            }
        } else if !entries.isEmpty {
            HStack(spacing: 1) {
                ForEach(entries.prefix(3)) { entry in
                    icon(entry, size: 20)
                        .overlay(alignment: .bottom) {
                            if modifiers == nil, let m = entry.shortcut?.modifiers { Capsule().fill(color(m)).frame(height: 3).offset(y: 3) }
                        }
                }
                if entries.count > 3 { Text("+\(entries.count - 3)").font(.system(size: 8)).foregroundColor(.secondary) }
            }
        }
    }
    /// ×2 and the condition mark, drawn over the icon's corner so they take no width.
    @ViewBuilder func badges(_ entry: LaunchEntry) -> some View {
        HStack(spacing: 1) {
            if entry.doubleTap { Text("×2").font(.system(size: 8, weight: .bold)) }
            if entry.frontRule != .none || !entry.skipURLs.isEmpty { Image(systemName: "line.3.horizontal.decrease").font(.system(size: 7, weight: .bold)) }
        }
        .foregroundColor(.white)
        .padding(.horizontal, entry.doubleTap || entry.frontRule != .none || !entry.skipURLs.isEmpty ? 3 : 0)
        .padding(.vertical, 1)
        .background(Capsule().fill(Color.secondary.opacity(entry.doubleTap || entry.frontRule != .none || !entry.skipURLs.isEmpty ? 0.85 : 0)))
    }
    func icon(_ entry: LaunchEntry, size: CGFloat) -> some View {
        Group {
            if let image = appIcon(entry) { Image(nsImage: image).resizable() } else { Image(systemName: "questionmark.app.dashed").resizable() }
        }
        .frame(width: size, height: size)
        .opacity(entry.enabled ? 1 : 0.45)
    }
}

/// Diagonal lines for keys taken by macOS.
struct Hatch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = -rect.height
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.maxY)); path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += 6
        }
        return path
    }
}
