import SwiftUI

struct ShortcutSummary: Identifiable {
    let id: String
    let title: String
    let keys: String
    let category: String
    let combo: KeyCombo?
    let enabled: Bool
    let failed: Bool
    let settingsTab: Int?
    let mainTab: Int?
}
@MainActor extension Model {
    var shortcutSummary: [ShortcutSummary] {
        var rows: [ShortcutSummary] = []
        func row(_ id: String, _ title: String, _ category: String, _ combo: KeyCombo?, _ enabled: Bool, _ failed: Bool, settings: Int? = nil, main: Int? = nil) -> ShortcutSummary {
            .init(id: id, title: title, keys: combo?.label ?? HotkeyText.unset, category: category, combo: combo, enabled: enabled && combo != nil, failed: failed, settingsTab: settings, mainTab: main)
        }
        rows.append(row("app", SettingsUI.shortcutTitle, SettingsUI.launchTitle, appCombo, appHotkeyEnabled, !appHotkeyRegistered, settings: 0))
        for command in CommandTable.all {
            let on = enabled && !disabled.contains(command.id)
            let mods: (Mods) -> UInt32 = { 4096 | ($0.contains(.shift) ? 512 : 0) | ($0.contains(.command) ? 256 : 0) | ($0.contains(.option) ? 2048 : 0) }
            rows.append(row(command.id, command.title, L("editingTab"), KeyCombo(code: UInt32(command.key), modifiers: mods(command.mods)), on, false, settings: 2))
            for (index, key) in command.alternates.enumerated() {
                rows.append(row(command.id + ".\(index)", command.title, L("editingTab"), KeyCombo(code: UInt32(key.code), modifiers: mods(key.mods)), on, false, settings: 2))
            }
        }
        for mapping in KeyMap.all {
            let ansi = L("numpadTrigger." + integration.ansiTrigger.rawValue), jis = L("numpadTrigger." + integration.jisTrigger.rawValue)
            rows.append(.init(id: "numpad.\(mapping.id)", title: mapping.fromLabel + " → " + mapping.toLabel, keys: "US: \(ansi) / JIS: \(jis) + \(mapping.fromLabel)", category: L("numpadTab"), combo: nil, enabled: integration.numpadEnabled && integration.groups.contains(mapping.group), failed: false, settingsTab: 1, mainTab: nil))
        }
        rows.append(row("ocr", L("ocrTab"), L("ocrTab"), ocr.combo, ocr.enabled, !ocr.hotkeyRegistered, main: 2))
        for item in SymbolDefinitions.all {
            rows.append(row("symbols." + item.id, item.text, L(item.isArrow ? "symbols.arrows" : "symbols.modifiers"), symbols.combos[item.id], symbols.enabled(for: item) && (!item.isArrow || symbols.arrowMode == .custom), symbols.failed.contains(item.id), main: item.isArrow ? 4 : 3))
        }
        if symbols.arrowMode == .google {
            for pair in ArrowSequence.mappings {
                rows.append(.init(id: pair.0, title: pair.1, keys: pair.0, category: L("symbols.arrows"), combo: nil, enabled: symbols.arrowsEnabled, failed: false, settingsTab: nil, mainTab: 4))
            }
        }
        return rows
    }
}
struct HotkeyOverviewPage: View {
    @ObservedObject var model: Model
    @State private var query = ""
    var rows: [ShortcutSummary] { model.shortcutSummary }
    var duplicates: Set<KeyCombo> {
        Set(Dictionary(grouping: rows.filter { $0.enabled && $0.combo != nil }, by: { $0.combo! }).filter { $0.value.count > 1 }.keys)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.paused { Label(L("allPaused"), systemImage: "pause.circle") }
            TextField(L("search.hotkeys"), text: $query).textFieldStyle(.roundedBorder)
            Text(L("overview.scope")).font(.caption).foregroundColor(.secondary)
            ForEach(rows.filter { query.isEmpty || ($0.category + " " + $0.title + " " + $0.keys).localizedStandardContains(query) }) { row in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.category).font(.caption).foregroundColor(.secondary)
                        Text(row.title)
                        if row.failed { Label(L("overview.failed"), systemImage: "exclamationmark.triangle").foregroundColor(.orange) }
                        if let combo = row.combo, row.enabled && duplicates.contains(combo) { Label(L("overview.duplicate"), systemImage: "exclamationmark.triangle").foregroundColor(.orange) }
                    }
                    Spacer()
                    Text(row.keys).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    Text(L(row.enabled ? "overview.on" : "overview.off")).foregroundColor(.secondary)
                    Button(L("overview.configure")) {
                        if let tab = row.settingsTab { model.settingsTab = tab; model.settingsFocus = row.id.hasPrefix("numpad.") ? "page.1" : "cmd." + row.id.components(separatedBy: ".").first! }
                        else if let tab = row.mainTab { model.mainTab = tab; AppDelegate.shared?.showMainWindow() }
                    }
                }.padding(.vertical, 5)
                Divider()
            }
        }
    }
}
