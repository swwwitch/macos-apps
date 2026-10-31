import AppKit
import SwiftUI

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

func chooseFolder(_ start: String) -> String? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
    panel.directoryURL = URL(fileURLWithPath: start)
    panel.prompt = L("choose")
    return panel.runModal() == .OK ? panel.url?.path : nil
}
func displayPath(_ path: String) -> String { (path as NSString).abbreviatingWithTildeInPath }

struct MainView: View {
    @ObservedObject var model: Model
    let renameFiles: () -> Void
    let sortExisting: () -> Void
    @State private var editing: SortRule?
    @State private var isNew = false
    @State private var selection: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 4) { Text(L("heading")).font(.system(size: 22, weight: .semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
                Toggle(L("sort.enabled"), isOn: $model.sortEnabled).toggleStyle(.switch)
            }
            Text(L("rules")).font(.headline)
            List(selection: $selection) {
                ForEach($model.rules) { $rule in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Toggle("", isOn: $rule.enabled).labelsHidden().accessibilityLabel(rule.name)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.name).fontWeight(.medium)
                            Text(conditions(rule)).font(.caption).foregroundColor(.secondary).lineLimit(1)
                            Text(displayPath(rule.folder) + "  →  " + displayPath(rule.destination)).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                    }.tag(rule.id).opacity(rule.enabled ? 1 : 0.55)
                }.onMove { model.rules.move(fromOffsets: $0, toOffset: $1) }
            }
            .contextMenu(forSelectionType: UUID.self, menu: { ids in
                if let id = ids.first { Button(L("edit")) { edit(id) }; Button(L("delete")) { delete(id) } }
            }, primaryAction: { ids in if let id = ids.first { edit(id) } })
            .frame(minHeight: 170)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.gray.opacity(0.25)))
            HStack(spacing: 8) {
                Button { isNew = true; editing = SortRule(name: "", folder: NSHomeDirectory() + "/Downloads", destination: NSHomeDirectory()) } label: { Image(systemName: "plus") }
                    .help(L("newRule")).accessibilityLabel(L("newRule"))
                Button { if let selection { delete(selection) } } label: { Image(systemName: "minus") }.disabled(selection == nil).help(L("delete")).accessibilityLabel(L("delete"))
                Button(L("edit")) { if let selection { edit(selection) } }.disabled(selection == nil)
                Spacer()
                Button(L("renameFiles"), action: renameFiles)
                Button(L("sortExistingMenu"), action: sortExisting).help(L("sortExistingHint"))
            }
            Text(L("sort.detail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("activity")).font(.headline)
                if model.activity.isEmpty {
                    Text(L("activityEmpty")).font(.callout).foregroundColor(.secondary)
                } else {
                    ForEach(model.activity.prefix(5)) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(entry.date, style: .time).font(.caption).monospacedDigit().foregroundColor(.secondary)
                            Image(systemName: entry.symbol).font(.caption).foregroundColor(entry.isError ? .red : appTint).accessibilityHidden(true)
                            Text(entry.text).font(.caption).foregroundColor(entry.isError ? .red : .primary).lineLimit(2)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: AppSurface.color)).tint(appTint)
        .sheet(item: $editing) { rule in
            SortRuleEditor(rule: rule, isNew: isNew) { saved in
                if let saved { model.save(saved); selection = saved.id }
                editing = nil
            }
        }
    }

    private func conditions(_ rule: SortRule) -> String {
        var parts: [String] = []
        if !rule.keywords.isEmpty { parts.append(String(format: L("sort.keywordsSummary"), rule.keywords.joined(separator: L("listSeparator")))) }
        if !rule.extensions.isEmpty { parts.append(String(format: L("sort.extensionsSummary"), rule.extensions.joined(separator: L("listSeparator")))) }
        return parts.joined(separator: L("sort.or"))
    }
    private func edit(_ id: UUID) { guard let rule = model.rules.first(where: { $0.id == id }) else { return }; isNew = false; editing = rule }
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
}

struct SortRuleEditor: View {
    @State var rule: SortRule
    let isNew: Bool
    let done: (SortRule?) -> Void
    @State private var keywords = ""
    @State private var extensions = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L(isNew ? "newRule" : "editRule")).font(.headline)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow { Text(L("rule.name")).gridColumnAlignment(.trailing); TextField("", text: $rule.name).accessibilityLabel(L("rule.name")) }
                GridRow { Text(L("rule.folder")); folder($rule.folder) }
                GridRow { Text(L("rule.keywords")); TextField(L("rule.keywordsHint"), text: $keywords).accessibilityLabel(L("rule.keywords")) }
                GridRow { Text(L("rule.extensions")); TextField(L("rule.extensionsHint"), text: $extensions).accessibilityLabel(L("rule.extensions")) }
                GridRow { Text(L("rule.destination")); folder($rule.destination) }
            }
            Text(L("rule.detail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("cancel")) { done(nil) }.keyboardShortcut(.cancelAction)
                Button(L("save")) {
                    rule.keywords = SortRule.list(keywords); rule.extensions = SortRule.list(extensions)
                    done(rule)
                }.keyboardShortcut(.defaultAction)
                    .disabled(rule.name.trimmingCharacters(in: .whitespaces).isEmpty || (SortRule.list(keywords).isEmpty && SortRule.list(extensions).isEmpty) || rule.folder == rule.destination)
            }
        }
        .padding(20).frame(width: 540).tint(appTint)
        .onAppear { keywords = rule.keywords.joined(separator: ", "); extensions = rule.extensions.joined(separator: ", ") }
    }
    private func folder(_ path: Binding<String>) -> some View {
        HStack {
            Text(displayPath(path.wrappedValue)).lineLimit(1).truncationMode(.middle).help(path.wrappedValue)
            Spacer(minLength: 4)
            Button(L("change")) { if let chosen = chooseFolder(path.wrappedValue) { path.wrappedValue = chosen } }
        }
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
        })), (L("renameTitle"), AnyView(SettingsSection(L("renameTitle")) { ScreenshotSettingsView(model: model) })), (NotificationPreferences.title, AnyView(SettingsSection(NotificationPreferences.title) {
            NotificationPermissionView(enabled: $model.notify, toggleTitle: L("notifyToggle"))
        })), (AboutSection.title, AnyView(AboutView()))])
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
    }
}

struct ScreenshotSettingsView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(L("shot.enabled"), isOn: $model.shotEnabled)
            Text(L("shot.folders")).font(.subheadline)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.shotFolders, id: \.self) { path in
                        HStack {
                            Text(displayPath(path)).lineLimit(1).truncationMode(.middle).help(path)
                            Spacer()
                            Button { NSWorkspace.shared.open(URL(fileURLWithPath: path)) } label: { Image(systemName: "arrow.up.forward.app") }
                                .accessibilityLabel(L("openFolder"))
                            Button(L("removeFolder")) { model.shotFolders.removeAll { $0 == path } }
                        }
                    }
                }
            }.frame(height: min(CGFloat(model.shotFolders.count) * 30, 150))
            Button(L("addFolder")) {
                if let path = chooseFolder(model.shotFolders.first ?? Model.screenshotLocation) {
                    model.shotFolders = WatchFolders.normalize(model.shotFolders + [path])
                }
            }
            HStack {
                Text(L("shot.template"))
                TextField("", text: $model.nameTemplate).font(.system(.body, design: .monospaced)).accessibilityLabel(L("shot.template"))
                Button(L("resetDefault")) { model.nameTemplate = ShotNaming.defaultTemplate }.disabled(model.nameTemplate == ShotNaming.defaultTemplate)
            }
            Text(L("shot.templateHint") + "  " + ShotNaming.name(template: model.nameTemplate, info: ImageInfo(width: 1920, height: 1080, dpi: 144), date: Date()))
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            DisclosureGroup(L("explanation")) {
                Text(L("shot.detail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

}

