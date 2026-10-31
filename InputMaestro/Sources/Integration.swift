import AppKit
import SwiftUI

@MainActor final class IntegrationModel: ObservableObject {
    let commaTyper = CommaTyper()
    var onChange: (() -> Void)?
    @Published var numpadEnabled = UserDefaults.standard.object(forKey: "numpad.enabled") as? Bool ?? true { didSet { save() } }
    @Published var ansiTrigger = NumpadTrigger(rawValue: UserDefaults.standard.string(forKey: "numpad.ansi") ?? "fn") ?? .fn { didSet { save() } }
    // fn on both layouts avoids overlapping ControlMate's JIS Caps Lock default.
    @Published var jisTrigger = NumpadTrigger(rawValue: UserDefaults.standard.string(forKey: "numpad.jis") ?? "fn") ?? .fn { didSet { save() } }
    @Published var groups = Set(NumpadGroup.allCases.filter { UserDefaults.standard.object(forKey: "numpad." + $0.rawValue) as? Bool ?? true }) { didSet { save() } }
    @Published var controlConflict = false
    @Published var numpadConflict = false
    func updateConflicts() {
        controlConflict = !NSRunningApplication.runningApplications(withBundleIdentifier: "jp.dtp-transit.controlmate").isEmpty
        numpadConflict = !NSRunningApplication.runningApplications(withBundleIdentifier: "jp.dtp-transit.fnnumpad").isEmpty
    }
    static let sharedKeys: Set<String> = Set(["numpad.enabled", "numpad.ansi", "numpad.jis"] + NumpadGroup.allCases.map { "numpad." + $0.rawValue })
    func reload() {
        let d = UserDefaults.standard
        let enabled = d.object(forKey: "numpad.enabled") as? Bool ?? true
        let ansi = NumpadTrigger(rawValue: d.string(forKey: "numpad.ansi") ?? "fn") ?? .fn
        let jis = NumpadTrigger(rawValue: d.string(forKey: "numpad.jis") ?? "fn") ?? .fn
        let savedGroups = Set(NumpadGroup.allCases.filter { d.object(forKey: "numpad." + $0.rawValue) as? Bool ?? true })
        numpadEnabled = enabled; ansiTrigger = ansi; jisTrigger = jis; groups = savedGroups
    }
    private func save() {
        let d = UserDefaults.standard
        d.set(numpadEnabled, forKey: "numpad.enabled")
        d.set(ansiTrigger.rawValue, forKey: "numpad.ansi"); d.set(jisTrigger.rawValue, forKey: "numpad.jis")
        for group in NumpadGroup.allCases { d.set(groups.contains(group), forKey: "numpad." + group.rawValue) }
        onChange?()
    }
}
struct IntegrationStatus: View {
    @ObservedObject var model: IntegrationModel
    var body: some View {
        VStack(alignment: .leading) {
            if model.controlConflict { Label(L("conflict.control"), systemImage: "pause.circle").foregroundColor(.orange) }
            if model.numpadConflict { Label(L("conflict.numpad"), systemImage: "pause.circle").foregroundColor(.orange) }
        }.fixedSize(horizontal: false, vertical: true)
    }
}
struct NumpadPage: View {
    @ObservedObject var model: IntegrationModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                IntegrationStatus(model: model)
                SettingsSection(L("numpadTab")) {
                    Toggle(L("numpadEnable"), isOn: $model.numpadEnabled)
                    Picker(L("trigger.ansi"), selection: $model.ansiTrigger) {
                        ForEach(NumpadTrigger.allCases) { Text(L("numpadTrigger." + $0.rawValue)).tag($0) }
                    }
                    Picker(L("trigger.jis"), selection: $model.jisTrigger) {
                        ForEach(NumpadTrigger.allCases) { Text(L("numpadTrigger." + $0.rawValue)).tag($0) }
                    }
                    DisclosureGroup(L("explanation")) { Text(L("numpadPriority")) }
                }
                ForEach(NumpadGroup.allCases) { group in
                    SettingsSection(L("numpadGroup." + group.rawValue)) {
                        Toggle(L("groupEnable"), isOn: Binding(get: { model.groups.contains(group) }, set: { on in
                            if on { model.groups.insert(group) } else { model.groups.remove(group) }
                        }))
                        Text(KeyMap.mappings(in: group).map { $0.fromLabel + " → " + $0.toLabel }.joined(separator: "    "))
                            .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    }
                }
            }.padding(12)
        }
    }
}
