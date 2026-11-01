import AppKit
import SwiftUI

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let fxTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

/// The 「アピアランス」 tab: the commands (left) and the selected one (right).
struct AppearancePage: View {
    @ObservedObject var model: AppearanceModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(FX("heading")).font(.headline)
            Text(FX("subtitle")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 0) {
                CommandList(model: model).frame(width: 240)
                Divider()
                if let id = model.selection, let command = Catalog.command(id) {
                    CommandDetail(model: model, command: command).id(id)
                } else {
                    Text(FX("detail.none")).foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.35)).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.gray.opacity(0.25)))
            HStack(spacing: 6) {
                if model.running > 0 { ProgressView().controlSize(.small) }
                if let status = model.status {
                    Image(systemName: status.isError ? "exclamationmark.triangle.fill" : "checkmark.circle")
                        .foregroundColor(status.isError ? .orange : .secondary).accessibilityHidden(true)
                    Text(status.text).foregroundColor(status.isError ? .orange : .secondary).lineLimit(2).textSelection(.enabled)
                } else { Text(" ") }
                Spacer()
            }.font(.callout)
        }
        .tint(fxTint)
    }
}

struct CommandList: View {
    @ObservedObject var model: AppearanceModel
    var body: some View {
        List(selection: $model.selection) {
            ForEach(PaletteSection.allCases, id: \.self) { section in
                Section(section.title) {
                    ForEach(Catalog.commands(in: section), id: \.id) { command in
                        HStack(spacing: 6) {
                            Toggle("", isOn: Binding(get: { !model.hidden.contains(command.id) }, set: { shown in
                                if shown { model.hidden.remove(command.id) } else { model.hidden.insert(command.id) }
                            }))
                            .labelsHidden().toggleStyle(.checkbox)
                            .accessibilityLabel(String(format: FX("list.showInPalette"), command.title))
                            .help(FX("list.showInPaletteHint"))
                            Text(command.displayTitle).lineLimit(1)
                                .foregroundColor(model.hidden.contains(command.id) ? .secondary : .primary)
                            Spacer()
                            if !model.scriptExists(command) {
                                Image(systemName: "exclamationmark.triangle").foregroundColor(.orange).accessibilityLabel(FX("script.missing"))
                            }
                            if let combo = model.keys[command.id] {
                                Text(combo.label).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                            }
                        }
                        .tag(command.id)
                        .listRowBackground(model.color(command).map { $0.displayColor.opacity(0.22) } ?? Color.clear)
                        .contextMenu {
                            Menu(FX("item.color")) {
                                Button(FX("color.none")) { model.setColor(nil, for: command) }
                                Divider()
                                ForEach(ItemTag.allCases, id: \.self) { tag in
                                    Button { model.setColor(tag, for: command) } label: {
                                        Label(tag.title, systemImage: model.color(command) == tag ? "checkmark.circle.fill" : "circle.fill")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }
}

struct CommandDetail: View {
    @ObservedObject var model: AppearanceModel
    let command: Command
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(command.displayTitle).font(.title2.weight(.semibold))
                    Text(kindText).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    ItemColorPicker(color: Binding(get: { model.color(command) }, set: { model.setColor($0, for: command) })).padding(.top, 6)
                }
                HStack(spacing: 8) {
                    Button(FX("detail.run")) { model.run(command, fromWindow: true) }
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(!model.scriptExists(command))
                    if command.dialogAlternative != nil {
                        Button(FX("detail.runDialog")) { model.run(command, dialog: true, fromWindow: true) }
                    }
                }
                SettingsSection(FX("detail.hotkey")) {
                    VStack(alignment: .leading, spacing: 6) {
                        CommandKeyField(model: model, command: command)
                        Text(FX("detail.hotkeyNote")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                if !command.params.isEmpty {
                    SettingsSection(FX("detail.values")) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(command.params, id: \.key) { spec in ParamRow(model: model, command: command, spec: spec) }
                            HStack {
                                Text(FX("detail.valuesNote")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Button(FX("detail.resetValues")) { model.resetValues(command) }.disabled(!model.hasCustomValues(command))
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if command.scriptPath != nil { ScriptFileSection(model: model, command: command) }
                LogicSection(model: model, command: command)
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var kindText: String {
        switch command.action {
        case .menu(_, let dialog): return FX(dialog ? "kind.dialog" : "kind.menu")
        case .effect: return FX("kind.effect")
        case .code: return FX("kind.code." + command.id)
        case .action: return FX("kind.action")
        case .namedAction(let set, let name): return String(format: FX("kind.namedAction"), name, set)
        case .script: return FX("kind.script")
        }
    }
}

extension ItemTag {
    var displayColor: Color {
        switch self {
        case .red: return Color(nsColor: .systemRed)
        case .orange: return Color(nsColor: .systemOrange)
        case .yellow: return Color(nsColor: .systemYellow)
        case .green: return Color(nsColor: .systemGreen)
        case .blue: return Color(nsColor: .systemBlue)
        case .purple: return Color(nsColor: .systemPurple)
        case .gray: return Color(nsColor: .systemGray)
        }
    }
}

/// None plus Finder's seven tag colors, like VectorKeys.
struct ItemColorPicker: View {
    @Binding var color: ItemTag?
    var body: some View {
        // Label above the swatches: the tab is narrow in VectorMate's window.
        VStack(alignment: .leading, spacing: 4) {
            Text(FX("item.color")).foregroundColor(.secondary)
            HStack(spacing: 6) {
                Button { color = nil } label: {
                    Image(systemName: "nosign").font(.system(size: 16)).frame(width: 23, height: 23)
                        .overlay(Circle().strokeBorder(color == nil ? Color.primary : .clear, lineWidth: 2))
                }.help(FX("color.none")).accessibilityLabel(FX("color.none"))
                ForEach(ItemTag.allCases, id: \.self) { tag in
                    Button { color = tag } label: {
                        Circle().fill(tag.displayColor.opacity(0.65))
                            .overlay(Circle().strokeBorder(tag.displayColor, lineWidth: 1.5))
                            .frame(width: 17, height: 17).padding(3)
                            .overlay(Circle().strokeBorder(color == tag ? Color.primary : .clear, lineWidth: 2))
                    }.help(tag.title).accessibilityLabel(tag.title)
                        .accessibilityValue(color == tag ? FX("color.selected") : "")
                }
            }.buttonStyle(.plain)
        }
    }
}

/// 「しくみ」: what the command does in Illustrator, step by step, and the ExtendScript it sends.
struct LogicSection: View {
    @ObservedObject var model: AppearanceModel
    let command: Command
    @State private var showsSource = false
    var body: some View {
        let values = Dictionary(uniqueKeysWithValues: command.params.map { ($0.key, model.value(command, $0)) })
        SettingsSection(FX("logic.title")) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(Logic.steps(for: command, values: values, recorded: AppearanceModel.recordedAction).enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(index + 1).").monospacedDigit().foregroundColor(.secondary).frame(width: 20, alignment: .trailing)
                        Text(step).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    }
                }
                // Shown with the bundled file's name; running copies it to the temporary folder first.
                if let source = ScriptBuilder.source(for: command, values: values, recorded: AppearanceModel.recordedAction, resourceFile: { "…/VectorMate.app/Contents/Resources/" + $0 }) {
                    DisclosureGroup(isExpanded: $showsSource) {
                        ScrollView([.horizontal, .vertical]) {
                            Text(source).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                        }
                        .frame(height: 220)
                        .background(Color(nsColor: .textBackgroundColor)).cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.gray.opacity(0.25)))
                    } label: { Text(FX("logic.source")) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ParamRow: View {
    @ObservedObject var model: AppearanceModel
    let command: Command
    let spec: ParamSpec
    private var binding: Binding<Double> { Binding(get: { model.value(command, spec) }, set: { model.setValue(command, spec, $0) }) }
    var body: some View {
        HStack(spacing: 8) {
            Text(spec.title + " :").frame(width: 130, alignment: .trailing)
            switch spec.kind {
            case .toggle:
                Toggle("", isOn: Binding(get: { binding.wrappedValue != 0 }, set: { binding.wrappedValue = $0 ? 1 : 0 })).labelsHidden()
                    .accessibilityLabel(spec.title)
            case .join:
                Picker("", selection: Binding(get: { Int(binding.wrappedValue) }, set: { binding.wrappedValue = Double($0) })) {
                    Text(FX("join.miter")).tag(2); Text(FX("join.round")).tag(0); Text(FX("join.bevel")).tag(1)
                }.labelsHidden().fixedSize().accessibilityLabel(spec.title)
            default:
                TextField("", value: binding, format: .number.precision(.fractionLength(0...3)))
                    .frame(width: 80).multilineTextAlignment(.trailing).accessibilityLabel(spec.title)
                Stepper("", value: binding, in: spec.range, step: spec.kind == .percent ? 5 : 1).labelsHidden().accessibilityLabel(spec.title)
                Text(unit).foregroundColor(.secondary)
            }
        }
    }
    private var unit: String {
        switch spec.kind {
        case .length: return FX("unit.document")
        case .percent: return "%"
        case .count: return FX(spec.key == "detail" ? "unit.perInch" : "unit.perSegment")
        default: return ""
        }
    }
}

struct ScriptFileSection: View {
    @ObservedObject var model: AppearanceModel
    let command: Command
    var body: some View {
        SettingsSection(FX("script.title")) {
            VStack(alignment: .leading, spacing: 8) {
                let path = model.scriptPath(command) ?? ""
                Text(path).font(.callout).textSelection(.enabled).lineLimit(3).truncationMode(.middle)
                    .foregroundColor(model.scriptExists(command) ? .primary : .orange)
                if !model.scriptExists(command) {
                    Text(FX("script.missingDetail")).font(.caption).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Button(FX("script.choose")) { choose() }
                    Button(FX("script.reveal")) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
                        .disabled(!model.scriptExists(command))
                    Spacer()
                    Button(FX("script.reset")) { model.scriptPaths[command.id] = nil }.disabled(model.scriptPaths[command.id] == nil)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["jsx", "js", "jsxbin"].compactMap { .init(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        if let path = model.scriptPath(command) { panel.directoryURL = URL(fileURLWithPath: (path as NSString).deletingLastPathComponent) }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.scriptPaths[command.id] = url.path
    }
}

/// Records a command key. Unlike the app's global keys, any key is accepted (⇧K, - alone):
/// command keys only work while the palette is shown and Illustrator is in front, like the original palette.
struct CommandKeyField: View {
    @ObservedObject var model: AppearanceModel
    let command: Command
    @State private var recording = false
    @State private var monitor: Any?
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // One row when it fits, otherwise the buttons go under the key.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { keyLabel; buttons }
                VStack(alignment: .leading, spacing: 6) { keyLabel; HStack(spacing: 8) { buttons } }
            }
            if recording {
                Text(FX("key.recordingHint")).font(.caption).foregroundColor(.secondary)
            } else if !message.isEmpty {
                Text(message).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if model.failedKeys.contains(command.id) {
                Text(FX("key.failed")).font(.caption).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
        .onDisappear { stop() }
    }
    private var keyLabel: some View {
        let combo = model.keys[command.id]
        return Text(recording ? HotkeyText.pressKeys : (combo?.label ?? HotkeyText.unset))
            .font(.system(size: 13, design: .monospaced)).kerning(recording || combo == nil ? 0 : 2)
            .foregroundColor(combo == nil && !recording ? .secondary : .primary)
            .frame(minWidth: 96, alignment: .leading)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).stroke(recording ? Color.accentColor : Color.secondary.opacity(0.4)))
            .contentShape(Rectangle())
            .onTapGesture { recording ? stop() : start() }
            .accessibilityLabel(combo?.label ?? HotkeyText.unset)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { recording ? stop() : start() }
            .help(recording ? HotkeyText.cancel : HotkeyText.change)
    }
    @ViewBuilder private var buttons: some View {
        let combo = model.keys[command.id]
        Button(HotkeyText.reset) { stop(); take(command.defaultKey?.combo) }
            .disabled(combo == command.defaultKey?.combo).fixedSize()
        Button(HotkeyText.clear) { stop(); message = ""; model.assign(nil, to: command.id) }.disabled(combo == nil).fixedSize()
    }
    private func take(_ combo: KeyCombo?) {
        if let combo, combo == model.paletteCombo {
            message = FX("key.paletteKey"); return
        }
        let previous = model.assign(combo, to: command.id)
        message = previous.map { String(format: FX("key.takenFrom"), $0.title) } ?? ""
    }
    private func start() {
        message = ""; recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty { stop(); return nil }   // Esc
            let flags = event.modifierFlags
            var modifiers: UInt32 = 0
            if flags.contains(.command) { modifiers |= KeyCombo.command }
            if flags.contains(.shift) { modifiers |= KeyCombo.shift }
            if flags.contains(.option) { modifiers |= KeyCombo.option }
            if flags.contains(.control) { modifiers |= KeyCombo.control }
            stop()
            take(KeyCombo(code: UInt32(event.keyCode), modifiers: modifiers))
            return nil
        }
    }
    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

/// Settings › Hotkeys, after the palette key: the typing guard for the item keys and resetting the items.
struct AppearanceSettings: View {
    @ObservedObject var model: AppearanceModel
    var body: some View {
        SettingsSection(FX("settings.itemsSection")) {
            VStack(alignment: .leading, spacing: 6) {
                Toggle(FX("settings.skipWhileTyping"), isOn: $model.skipWhileTyping)
                if model.skipWhileTyping && !AccessibilitySection.isTrusted {
                    Text(FX("settings.skipNeedsAccess")).font(.caption).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true)
                }
                Button(FX("settings.resetAll")) { model.resetAll() }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

