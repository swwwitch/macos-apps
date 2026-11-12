import AppKit
import SwiftUI

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

extension Hotkey {
    var label: String { KeyCombo(code: code, modifiers: modifiers).label }
}

// MARK: Main window

/// A longer note that stays folded until 「説明」 is opened (house rule, 2026-10-28).
struct Explanation: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        DisclosureGroup(L("explain")) {
            Text(text).font(.caption).foregroundColor(.secondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption)
    }
}

/// One hotkey cell of the table (its ⌥ / ⇧ forms register with it), with the duplicate / registration messages under it.
struct TriggerKeyField: View {
    @ObservedObject var model: AppModel
    let trigger: Trigger
    var body: some View {
        let problems = model.problems(of: trigger)
        VStack(alignment: .leading, spacing: 2) {
            HotkeyField(id: "action-" + trigger.id,
                        combo: Binding(get: { model.keyMap[trigger].map { KeyCombo(code: $0.code, modifiers: $0.modifiers) } },
                                       set: { model.keyMap[trigger] = $0.map { Hotkey(code: $0.code, modifiers: $0.modifiers) } }),
                        defaultCombo: KeyMap.defaultHotkey(for: trigger).map { KeyCombo(code: $0.code, modifiers: $0.modifiers) },
                        allowsClear: true, others: model.otherHotkeys(except: trigger),
                        registered: !model.failedHotkeys.contains(trigger), isEnabled: model.hotkeysEnabled, allowsOption: true)
            if !problems.duplicate.isEmpty {
                Text(String(format: L("hotkey.duplicate"), problems.duplicate.joined(separator: " "))).font(.caption).foregroundColor(.red).fixedSize(horizontal: false, vertical: true)
            }
            if !problems.yielded.isEmpty {
                Text(String(format: L("hotkey.yielded"), problems.yielded.joined(separator: " "))).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if !problems.failed.isEmpty {
                Text(String(format: L("hotkey.formsFailed"), problems.failed.joined(separator: " "))).font(.caption).foregroundColor(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: true, vertical: false)   // Keeps 「割り当てを解除」 at its width inside the table.
    }
}

/// The palette's buttons, each with a hotkey, and one more for 「from the center」 where it applies.
struct ActionTable: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                Text(L("column.action")).gridCellColumns(2)
                Text(L("column.hotkey"))
                Text(L("column.fromCenter")).help(L("column.fromCenterHint"))
            }
            .font(.caption).foregroundColor(.secondary)
            Divider().gridCellUnsizedAxes(.horizontal)
            ForEach(AlignAction.allCases) { action in
                GridRow {
                    Image(systemName: action.symbol).frame(width: 20).foregroundColor(.secondary).accessibilityHidden(true)
                    Button(action.title) { model.runFromWindow(Trigger(action: action)) }
                        .buttonStyle(.link).help(L("runHint")).accessibilityLabel(String(format: L("a11y.run"), action.title))
                    TriggerKeyField(model: model, trigger: Trigger(action: action))
                    if action.hasFromCenter {
                        HStack(spacing: 6) {
                            TriggerKeyField(model: model, trigger: Trigger(action: action, fromCenter: true))
                            Button { model.runFromWindow(Trigger(action: action, fromCenter: true)) } label: { Image(systemName: "play.fill") }
                                .buttonStyle(.borderless).help(L("runHint")).accessibilityLabel(String(format: L("a11y.run"), Trigger(action: action, fromCenter: true).title))
                        }
                    } else {
                        Text("—").foregroundColor(.secondary).help(L("column.noFromCenter"))
                    }
                }
            }
        }
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 4) { Text(L("heading")).font(.system(size: 22, weight: .semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
                Toggle(L("useHotkeys"), isOn: $model.hotkeysEnabled).toggleStyle(.switch).help(L("useHotkeysHint"))
            }
            HStack(spacing: 8) {
                Button(L("openPalette")) { model.runFromWindow(nil) }.help(L("openPaletteHint"))
                Spacer()
                Label(L(model.inDesignFront ? "state.front" : "state.back"), systemImage: model.inDesignFront ? "circle.fill" : "circle")
                    .font(.caption).foregroundColor(.secondary).labelStyle(.titleAndIcon)
                    .help(L("state.hint"))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("hotkeys")).font(.headline)
                        ActionTable(model: model)
                        VStack(alignment: .leading, spacing: 2) {
                            Toggle(L("arrowKeys"), isOn: $model.arrowKeys).help(L("arrowKeysHint"))
                            if !model.arrowProblems.isEmpty {
                                Text(String(format: L("arrowKeys.problem"), model.arrowProblems.joined(separator: " "))).font(.caption).foregroundColor(.red).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Toggle(L("preferInDesign"), isOn: $model.preferInDesign).help(L("preferInDesignHint"))
                            Text(model.shortcutSet.map { String(format: L("preferInDesign.set"), $0.deletingPathExtension().lastPathComponent) } ?? L("preferInDesign.noSet"))
                                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Text(L("modifiers")).font(.callout).fixedSize(horizontal: false, vertical: true)
                        Explanation(L("hotkeysHint"))
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
            VStack(alignment: .leading, spacing: 4) {
                Text(L("recent")).font(.headline)
                if model.records.isEmpty {
                    Text(L("recentEmpty")).font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(model.records.prefix(3)) { record in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: record.isError ? "exclamationmark.triangle.fill" : "checkmark.circle").foregroundColor(record.isError ? .orange : .green)
                                .accessibilityLabel(L(record.isError ? "a11y.error" : "a11y.success"))
                            Text(record.date.formatted(date: .omitted, time: .standard)).font(.caption.monospacedDigit()).foregroundColor(.secondary)
                            Text(record.name).font(.caption.weight(.medium)).lineLimit(1)
                            Text(record.text).font(.caption).foregroundColor(record.isError ? .orange : .secondary).lineLimit(2).textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 600)
        .background(Color(nsColor: AppSurface.color))
        .tint(appTint)
    }
}

// MARK: Settings

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var launcher: AppLauncherHotkey
    @AppStorage("resident") var resident = true
    var body: some View {
        SettingsTabs(sections: [(SettingsUI.launchTitle, AnyView(VStack(spacing: 16) {
            SettingsSection(SettingsUI.launchTitle) {
                LaunchPresenceSection(title: SettingsUI.launchTitle, loginControl: LoginAtLaunchView(), residentTitle: L("resident"), residentDetail: L("residentDetail"), resident: $resident,
                                      presenceExtra: MenuBarPresenceView(), shortcutTitle: L("launchShortcut"), shortcutButton: L("openShortcuts"), shortcutDetail: L("shortcutDetail")) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(SettingsUI.shortcutTitle).padding(.top, 4)
                    Toggle(HotkeyText.enable, isOn: $launcher.enabled)
                    HotkeyField(id: AppLauncherHotkey.fieldID, combo: $launcher.combo, allowsClear: true,
                                others: model.otherHotkeys(except: nil), registered: launcher.registered, isEnabled: launcher.enabled)
                    Explanation(L("appHotkeyHint"))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (L("hotkeysTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("hotkeysSection")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("useHotkeys"), isOn: $model.hotkeysEnabled)
                    Explanation(L("useHotkeysDetail"))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())), (AboutSection.title, AnyView(AboutView()))])
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
    }
}
