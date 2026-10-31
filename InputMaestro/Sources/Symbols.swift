import AppKit
import SwiftUI

@MainActor final class SymbolsModel: ObservableObject {
    @Published var modifiersEnabled = SymbolsModel.loadEnabled("symbols.modifiersEnabled") { didSet {
        UserDefaults.standard.set(modifiersEnabled, forKey: "symbols.modifiersEnabled"); onChange?()
    } }
    @Published var arrowsEnabled = SymbolsModel.loadEnabled("symbols.arrowsEnabled") { didSet {
        UserDefaults.standard.set(arrowsEnabled, forKey: "symbols.arrowsEnabled"); onChange?()
    } }
    @Published var arrowMode = ArrowMode(rawValue: UserDefaults.standard.string(forKey: "symbols.arrowMode") ?? "custom") ?? .custom { didSet {
        UserDefaults.standard.set(arrowMode.rawValue, forKey: "symbols.arrowMode"); onChange?()
    } }
    static let sharedKeys: Set<String> = ["symbols.modifiersEnabled", "symbols.arrowsEnabled", "symbols.arrowMode"]
    static func loadEnabled(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? UserDefaults.standard.object(forKey: "symbols.enabled") as? Bool ?? true
    }
    func enabled(for item: SymbolDefinition) -> Bool { item.isArrow ? arrowsEnabled : modifiersEnabled }
    func reload() {
        let modifiers = SymbolsModel.loadEnabled("symbols.modifiersEnabled"), arrows = SymbolsModel.loadEnabled("symbols.arrowsEnabled")
        modifiersEnabled = modifiers; arrowsEnabled = arrows
        arrowMode = ArrowMode(rawValue: UserDefaults.standard.string(forKey: "symbols.arrowMode") ?? "custom") ?? .custom
    }
    @Published var combos: [String: KeyCombo] = [:]
    @Published var failed = Set<String>()
    var onChange: (() -> Void)?
    init() {
        for item in SymbolDefinitions.all {
            let key = "symbols.combo." + item.id
            if UserDefaults.standard.object(forKey: key) != nil { combos[item.id] = Model.readCombo(key) }
            else { combos[item.id] = KeyCombo(code: item.code, modifiers: item.modifiers) }
        }
    }
    func binding(_ item: SymbolDefinition) -> Binding<KeyCombo?> {
        Binding(get: { self.combos[item.id] }, set: { combo in
            self.combos[item.id] = combo
            UserDefaults.standard.set(combo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "symbols.combo." + item.id)
            self.onChange?()
        })
    }
    func register(using hotkeys: HotkeySet, reserved: Set<KeyCombo>, paused: Bool) {
        var seen = reserved
        var failures = Set<String>()
        guard (modifiersEnabled || arrowsEnabled), !paused, AccessibilitySection.isTrusted else { failed = []; return }
        guard !ExcludedApps.shared.frontAppExcluded else { return }
        for (index, item) in SymbolDefinitions.all.enumerated() {
            guard enabled(for: item), (!item.isArrow || arrowMode == .custom), let combo = combos[item.id] else { continue }
            if !seen.insert(combo).inserted || hotkeys.register(UInt32(index + 10), combo) != noErr { failures.insert(item.id) }
        }
        failed = failures
    }
    func insert(_ number: UInt32, typer: CommaTyper) {
        guard AccessibilitySection.isTrusted, !ExcludedApps.shared.frontAppExcluded,
              let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return }
        let index = Int(number) - 10
        guard SymbolDefinitions.all.indices.contains(index), enabled(for: SymbolDefinitions.all[index]), (!SymbolDefinitions.all[index].isArrow || arrowMode == .custom) else { return }
        typer.pasteText(SymbolDefinitions.all[index].text, pid: pid)
    }
}
struct SymbolsPage: View {
    @ObservedObject var model: SymbolsModel
    @ObservedObject var owner: Model
    let arrows: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FeatureToggle(title: L(arrows ? "symbols.enableArrows" : "symbols.enableModifiers"), enabled: arrows ? $model.arrowsEnabled : $model.modifiersEnabled)
                FeatureNotice(model: owner, feature: arrows ? .arrows : .modifiers)
                if arrows {
                    Picker(L("arrows.mode"), selection: $model.arrowMode) {
                        Text(L("arrows.google")).tag(ArrowMode.google)
                        Text(L("arrows.custom")).tag(ArrowMode.custom)
                    }.pickerStyle(.segmented)
                }
                if arrows && model.arrowMode == .google {
                    SettingsSection(L("symbols.arrows")) {
                        ForEach(ArrowSequence.mappings, id: \.0) { pair in
                            HStack { Text(pair.0).font(.system(.body, design: .monospaced)); Text("→"); Text(pair.1).font(.system(size: 26)) }
                        }
                        Text(L("arrows.inputHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    SettingsSection(L(arrows ? "symbols.arrows" : "symbols.modifiers")) {
                        ForEach(SymbolDefinitions.all.filter { $0.isArrow == arrows }) { item in
                            HStack {
                                Text(item.text).font(.system(size: 26)).frame(width: 40)
                                HotkeyField(id: "symbols." + item.id, combo: model.binding(item), defaultCombo: KeyCombo(code: item.code, modifiers: item.modifiers), allowsClear: true, registered: !model.failed.contains(item.id), isEnabled: model.enabled(for: item), allowsOption: true)
                            }
                        }
                    }
                }
            }.padding(12)
        }
    }
}
