import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

struct RuleRow: View {
    @Binding var rule: Rule
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Toggle("", isOn: $rule.enabled).labelsHidden().accessibilityLabel(rule.name)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(rule.name).fontWeight(.medium).lineLimit(1)
                    if let app = rule.appName { Text(app).font(.caption).padding(.horizontal, 5).background(Capsule().fill(appTint.opacity(0.18))) }
                    if rule.announce { Image(systemName: "text.bubble").font(.caption).foregroundColor(.secondary).help(L("rule.announce")).accessibilityLabel(L("rule.announce")) }
                }
                Text(summary).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .opacity(rule.enabled ? 1 : 0.55)
    }
    private var summary: String {
        let replace = rule.replace.isEmpty ? L("rule.removed") : rule.replace.replacingOccurrences(of: "\n", with: "⏎")
        return rule.find.replacingOccurrences(of: "\n", with: "⏎") + "  →  " + replace
    }
}

struct MainView: View {
    @ObservedObject var model: Model
    @State private var selection: UUID?
    @State private var editing: Rule?
    @State private var isNew = false
    @State private var sample = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 4) { Text(L("heading")).font(.system(size: 22, weight: .semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
                Toggle(L("watching"), isOn: Binding(get: { !model.paused }, set: { model.paused = !$0 })).toggleStyle(.switch)
                    .help(L("watchingHint"))
            }
            Text(L("rules")).font(.headline)
            List(selection: $selection) {
                ForEach($model.rules) { $rule in RuleRow(rule: $rule).tag(rule.id) }
                    .onMove { model.rules.move(fromOffsets: $0, toOffset: $1) }
            }
            .contextMenu(forSelectionType: UUID.self, menu: { ids in
                if let id = ids.first {
                    Button(L("edit")) { edit(id) }
                    Button(L("duplicate")) { duplicate(id) }
                    Divider()
                    Button(L("delete")) { delete(id) }
                }
            }, primaryAction: { ids in if let id = ids.first { edit(id) } })
            .frame(minHeight: 190)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.gray.opacity(0.25)))
            HStack(spacing: 8) {
                Button { newRule() } label: { Image(systemName: "plus") }.help(L("newRule")).accessibilityLabel(L("newRule"))
                Button { if let selection { delete(selection) } } label: { Image(systemName: "minus") }.disabled(selection == nil).help(L("delete")).accessibilityLabel(L("delete"))
                Button(L("edit")) { if let selection { edit(selection) } }.disabled(selection == nil)
                Button { move(-1) } label: { Image(systemName: "arrow.up") }.disabled(selection == nil).help(L("moveUp")).accessibilityLabel(L("moveUp"))
                Button { move(1) } label: { Image(systemName: "arrow.down") }.disabled(selection == nil).help(L("moveDown")).accessibilityLabel(L("moveDown"))
                Spacer()
                Button(L("restorePresets")) { model.restorePresets() }.help(L("restorePresetsHint"))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(L("tryIt")).font(.headline)
                TextField(L("tryPlaceholder"), text: $sample, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
                let outcome = RuleEngine.run(model.rules, on: sample, frontApp: nil)
                if !sample.isEmpty {
                    Text(outcome.applied.isEmpty ? L("tryNone") : String(format: L("tryApplied"), outcome.applied.joined(separator: L("listSeparator"))))
                        .font(.caption).foregroundColor(.secondary)
                    if !outcome.applied.isEmpty { Text(outcome.text).font(.callout).textSelection(.enabled).lineLimit(5) }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L("history")).font(.headline)
                if model.history.isEmpty {
                    Text(L("historyEmpty")).font(.callout).foregroundColor(.secondary)
                } else {
                    ForEach(model.history.prefix(4)) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(entry.date, style: .time).font(.caption).monospacedDigit().foregroundColor(.secondary)
                            Text(entry.rules.joined(separator: L("listSeparator"))).font(.caption).fontWeight(.medium)
                            Text(entry.after.replacingOccurrences(of: "\n", with: " ")).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
            }
            Text(model.status.isEmpty ? " " : model.status).font(.callout).foregroundColor(model.statusIsError ? .red : .secondary).lineLimit(2)
        }
        .padding(20)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: AppSurface.color)).tint(appTint)
        .sheet(item: $editing) { rule in
            RuleEditor(rule: rule, isNew: isNew, sample: sample) { saved in
                if let saved { model.save(saved); selection = saved.id }
                editing = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newRule)) { _ in newRule() }
    }

    private func newRule() { isNew = true; editing = Rule(name: "", find: "", replace: "") }
    private func edit(_ id: UUID) { guard let rule = model.rules.first(where: { $0.id == id }) else { return }; isNew = false; editing = rule }
    private func duplicate(_ id: UUID) {
        guard let rule = model.rules.first(where: { $0.id == id }) else { return }
        var copy = rule; copy.id = UUID(); copy.name = String(format: L("copyName"), rule.name)
        model.save(copy); selection = copy.id
    }
    private func delete(_ id: UUID) {
        guard let rule = model.rules.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = String(format: L("deleteConfirm"), rule.name)
        alert.informativeText = L("deleteConfirmDetail")
        alert.addButton(withTitle: L("delete"))
        alert.addButton(withTitle: L("cancel")).keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        model.rules.removeAll { $0.id == id }; selection = nil
    }
    private func move(_ offset: Int) {
        guard let selection, let index = model.rules.firstIndex(where: { $0.id == selection }) else { return }
        let target = index + offset
        guard model.rules.indices.contains(target) else { return }
        model.rules.swapAt(index, target)
    }
}

extension Notification.Name { static let newRule = Notification.Name("ClipTidy.newRule") }

struct RuleEditor: View {
    @State var rule: Rule
    let isNew: Bool
    @State var sample: String
    let done: (Rule?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L(isNew ? "newRule" : "editRule")).font(.headline)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow { label("rule.name"); TextField("", text: $rule.name).accessibilityLabel(L("rule.name")) }
                GridRow { label("rule.condition"); field($rule.condition, "rule.conditionHint") }
                GridRow { label("rule.find"); field($rule.find, "") }
                GridRow { label("rule.replace"); field($rule.replace, "rule.replaceHint") }
                GridRow {
                    Text("")
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(L("rule.regex"), isOn: $rule.isRegex)
                        Toggle(L("rule.caseSensitive"), isOn: $rule.caseSensitive)
                        Toggle(L("rule.announce"), isOn: $rule.announce)
                    }
                }
                GridRow {
                    label("rule.app")
                    HStack {
                        Text(rule.appName ?? L("rule.anyApp")).foregroundColor(rule.appName == nil ? .secondary : .primary)
                        Button(L("rule.chooseApp")) { chooseApp() }
                        if rule.appBundleID != nil { Button(L("rule.anyApp")) { rule.appBundleID = nil; rule.appName = nil } }
                    }
                }
            }
            if let error = rule.patternError { Text(error).font(.caption).foregroundColor(.red) }
            VStack(alignment: .leading, spacing: 4) {
                Text(L("tryIt")).font(.subheadline)
                TextField(L("tryPlaceholder"), text: $sample, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
                if !sample.isEmpty {
                    let result = (try? rule.apply(to: sample, frontApp: rule.appBundleID)) ?? nil
                    Text(result ?? L("tryNoMatch")).font(.callout).foregroundColor(result == nil ? .secondary : .primary).textSelection(.enabled).lineLimit(5)
                }
            }
            HStack {
                Spacer()
                Button(L("cancel")) { done(nil) }.keyboardShortcut(.cancelAction)
                Button(L("save")) { done(rule) }.keyboardShortcut(.defaultAction)
                    .disabled(rule.name.trimmingCharacters(in: .whitespaces).isEmpty || rule.find.isEmpty || rule.patternError != nil)
            }
        }
        .padding(20).frame(width: 520).tint(appTint)
    }
    private func label(_ key: String) -> some View { Text(L(key)).gridColumnAlignment(.trailing) }
    private func field(_ text: Binding<String>, _ hint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("", text: text, axis: .vertical).lineLimit(1...4).font(.system(.body, design: .monospaced))
            if !hint.isEmpty { Text(L(hint)).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
        }
    }
    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.allowedContentTypes = [.application]
        panel.prompt = L("rule.chooseApp")
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return }
        rule.appBundleID = id
        rule.appName = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}

struct SettingsView: View {
    @ObservedObject var model: Model
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
                    Toggle(HotkeyText.enable, isOn: $model.appHotkeyEnabled)
                    HotkeyField(id: Model.appHotkeyFieldID, combo: $model.appCombo, defaultCombo: Model.defaultAppCombo, allowsClear: true,
                                registered: model.appHotkeyRegistered, isEnabled: model.appHotkeyEnabled)
                    Text(L("appHotkeyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (L("generalTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("watchSection")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("watching"), isOn: Binding(get: { !model.paused }, set: { model.paused = !$0 }))
                    Text(L("watchDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("dropboxSection")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("dropboxPrompt"), isOn: $model.dropboxPrompt)
                    Text(L("dropboxPromptDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("noticeSection")) {
                VStack(alignment: .leading, spacing: 6) {
                    Picker(L("noticeSeconds"), selection: $model.noticeSeconds) {
                        ForEach([2.0, 4.0, 8.0], id: \.self) { Text(String(format: L("seconds"), Int($0))).tag($0) }
                    }.fixedSize()
                    Text(L("noticeDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (ExcludedApps.title, AnyView(SettingsSection(ExcludedApps.title) { ExcludedAppsView() })),
           (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())), (AboutSection.title, AnyView(AboutView()))])
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
    }
}
