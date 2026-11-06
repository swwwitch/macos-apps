import AppKit
import SwiftUI

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

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

/// Keyword field with its unify-target mark, clear button and count.
struct KeywordRow: View {
    @ObservedObject var model: AppModel
    let index: Int
    var focus: FocusState<Int?>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Button { model.unifyTarget = model.unifyTarget == index ? -1 : index } label: {
                Image(systemName: model.unifyTarget == index ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(model.unifyTarget == index ? .accentColor : .secondary)
            }
            .buttonStyle(.plain).help(L("tip.unifyTarget"))
            .accessibilityLabel(String(format: L("a11y.unifyTarget"), index + 1))
            .accessibilityValue(L(model.unifyTarget == index ? "a11y.on" : "a11y.off"))
            HStack(spacing: 4) {
                TextField("", text: Binding(get: { model.keywords[index] }, set: { model.keywords[index] = $0; model.lastActiveField = index }))
                    .textFieldStyle(.plain).focused(focus, equals: index).onSubmit { model.find() }
                    .help(L("tip.keyword")).accessibilityLabel(String(format: L("a11y.keyword"), index + 1))
                Button {
                    if NSEvent.modifierFlags.contains(.option) { model.clearAllKeywords(); focus.wrappedValue = 0 }
                    else { model.clearKeyword(index); focus.wrappedValue = index }
                } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                    .buttonStyle(.plain).opacity(model.keywords[index].isEmpty ? 0 : 1).disabled(model.keywords[index].isEmpty)
                    .help(L("tip.clearKeyword")).accessibilityLabel(String(format: L("a11y.clearKeyword"), index + 1))
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.2)))
            Text(model.counts[index]).monospacedDigit().frame(width: 56, alignment: .trailing)
        }
    }
}

/// 「該当文字に色を付ける」 in Settings.
enum MatchColor {
    static func color(_ code: String) -> Color {
        MatchColorCode.decode(code).map { Color(.sRGB, red: $0.red, green: $0.green, blue: $0.blue) } ?? .red
    }
    static func code(_ color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "" }
        return MatchColorCode.encode(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
    }
}

struct ContextText: View {
    let row: MatchRow
    let isSelected: Bool
    /// nil when matches are only bold.
    let color: Color?
    var body: some View {
        let bold = Text(row.context.match).bold()
        // A selected row keeps the system's text color: a color may not read on the selection.
        let match = isSelected ? bold : row.isExcluded ? bold.foregroundColor(.secondary) : color.map { bold.foregroundColor($0) } ?? bold
        var line = Text(row.context.before) + match + Text(row.context.after)
        if let target = row.unifiesTo { line = line + Text(" → \(target)").foregroundColor(.secondary) }
        return line.lineLimit(1).foregroundColor(row.isExcluded ? .secondary : .primary)
    }
}

struct MatchTable: View {
    @ObservedObject var model: AppModel
    @AppStorage("matchInRed") private var matchInRed = true
    @AppStorage("matchColor") private var matchColor = ""
    var body: some View {
        Table(model.rows, selection: $model.selection) {
            TableColumn("") { row in
                Toggle("", isOn: Binding(get: { !row.isExcluded }, set: { model.setExcluded(row.id, !$0) }))
                    .labelsHidden().toggleStyle(.checkbox).help(L("tip.check")).accessibilityLabel(L("a11y.check"))
            }
            .width(22)
            TableColumn(L("column.paragraph")) { row in Text("\(row.paragraph)").monospacedDigit() }.width(min: 36, ideal: 44, max: 70)
            TableColumn(L("column.context")) { row in ContextText(row: row, isSelected: row.id == model.selection, color: matchInRed ? MatchColor.color(matchColor) : nil) }
        }
        .contextMenu(forSelectionType: MatchRow.ID.self, menu: { _ in }, primaryAction: { _ in model.showSelected() })
        .help(L(model.isGoogleDocs ? "tip.listDocs" : "tip.list"))
    }
}

/// The words written in more than one way. Picking one fills the term fields.
struct VariantList: View {
    @ObservedObject var model: AppModel

    private func kindTitle(_ kind: VariantGroup.Kind) -> String { L("kind." + kind.rawValue) }

    var body: some View {
        GroupBox(L("panel.variants")) {
            VStack(alignment: .leading, spacing: 8) {
                Button(L("button.collectVariants")) { model.collectVariants() }
                    .disabled(model.isBusy).help(L("tip.collectVariants")).frame(maxWidth: .infinity)
                if model.variantGroups.isEmpty {
                    Text(L(model.hasCollected ? "status.noVariants" : "variants.empty")).font(.caption).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                } else {
                    HStack(spacing: 6) {
                        Picker(L("variants.filter"), selection: $model.variantFilter) {
                            Text(L("kind.all")).tag(VariantGroup.Kind?.none)
                            ForEach(VariantGroup.Kind.allCases, id: \.self) { Text(kindTitle($0)).tag(VariantGroup.Kind?.some($0)) }
                        }
                        .labelsHidden().help(L("tip.variantFilter"))
                        Picker(L("variants.sort"), selection: $model.showsRareFirst) {
                            Text(L("sort.frequent")).tag(false)
                            Text(L("sort.rare")).tag(true)
                        }
                        .labelsHidden().help(L("tip.variantSort"))
                    }
                    List(model.visibleGroups, selection: Binding(get: { model.selectedGroup }, set: { model.pickGroup($0) })) { group in
                        VStack(alignment: .leading, spacing: 1) {
                            let preferred = model.preferredSpelling(of: group)
                            ForEach(group.spellings.indices, id: \.self) { index in
                                HStack(spacing: 6) {
                                    Text(group.spellings[index].text).fontWeight(group.spellings[index].text == preferred ? .semibold : .regular).lineLimit(1).truncationMode(.tail)
                                    Spacer(minLength: 4)
                                    Text("\(group.spellings[index].count)").monospacedDigit().foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .contextMenu { Button(L("button.ignore")) { model.pickGroup(group.id); model.ignoreSelectedGroup() } }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true)).help(L("tip.variantList"))
                    HStack(spacing: 6) {
                        Button(L("button.ignore")) { model.ignoreSelectedGroup() }.disabled(model.selectedGroup == nil).help(L("tip.ignore"))
                        Spacer(minLength: 0)
                        Button(L("button.copyTable")) { model.copyVariantTable() }.disabled(model.visibleGroups.isEmpty).help(L("tip.copyTable"))
                    }
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 6)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 170, idealWidth: 200, maxWidth: .infinity)
    }
}

/// Remembered choices, each with a way to remove it.
struct RememberedList: View {
    let items: [(id: String, text: String)]
    let empty: String
    let remove: (String) -> Void
    var body: some View {
        if items.isEmpty {
            Text(empty).font(.caption).foregroundColor(.secondary)
        } else {
            ForEach(items, id: \.id) { item in
                HStack {
                    Text(item.text).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button(L("button.remove")) { remove(item.id) }.controlSize(.small)
                }
            }
        }
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    let close: () -> Void
    @FocusState private var focus: Int?
    @State private var confirmsUnify = false

    private var targetLine: some View {
        HStack(spacing: 8) {
            if let icon = model.targetIcon { Image(nsImage: icon).resizable().frame(width: 22, height: 22).accessibilityHidden(true) }
            VStack(alignment: .leading, spacing: 1) {
                if let target = model.target {
                    Text(target.title.isEmpty ? target.appName : target.title).lineLimit(1).truncationMode(.middle).help(target.title)
                    Text(target.appName + (target.kind == .googleDocs ? " · " + L("target.docs") : "")).font(.caption).foregroundColor(.secondary)
                } else {
                    Text(model.targetProblem ?? L("target.none")).font(.callout).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox(L("panel.keywords")) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<AppModel.fieldCount, id: \.self) { KeywordRow(model: model, index: $0, focus: $focus) }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(L("field.total"))
                        Text(model.totalText).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                    Toggle(L("option.excludeContained"), isOn: $model.excludeContained).help(L("tip.excludeContained"))
                }
                .padding(.horizontal, 6).padding(.vertical, 6)
            }
            GroupBox(L("panel.target")) {
                VStack(alignment: .leading, spacing: 6) {
                    targetLine
                    Toggle(L("target.pin"), isOn: $model.isTargetPinned).disabled(model.target == nil || model.isBusy).help(L("tip.pin"))
                    Explanation(L(model.isTargetPinned ? "target.pinnedHint" : "target.hint"))
                }
                .padding(.horizontal, 6).padding(.vertical, 6)
            }
            GroupBox(L("panel.options")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("option.caseSensitive"), isOn: $model.caseSensitive)
                    Toggle(L("option.wholeWord"), isOn: $model.wholeWord).help(L("tip.wholeWord"))
                }
                .padding(.horizontal, 6).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .frame(minWidth: 250, idealWidth: 280, maxWidth: 360)
    }

    private var rightColumn: some View {
        GroupBox(L("panel.matches")) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    Text(L("field.contextLength"))
                    Slider(value: Binding(get: { Double(model.contextLength) }, set: { model.contextLength = Int($0.rounded()) }), in: 0...Double(AppModel.maxContext), step: 1)
                        .help(L("tip.contextLength")).accessibilityLabel(L("field.contextLength"))
                    Text("\(model.contextLength)").monospacedDigit().frame(width: 24, alignment: .trailing)
                }
                Toggle(L("option.withinParagraph"), isOn: $model.withinParagraph).help(L("tip.withinParagraph"))
                MatchTable(model: model).frame(minHeight: 200)
                HStack(spacing: 6) {
                    Text(model.listNote).font(.caption).foregroundColor(.secondary).lineLimit(2)
                    Spacer(minLength: 0)
                    Button(L("button.show")) { model.showSelected() }
                        .disabled(model.selectedRow == nil || model.isStale || model.isBusy).help(L("tip.show"))
                    Button(L(model.selectedRow?.isExcluded == true ? "button.include" : "button.exclude")) { model.toggleSelectedExcluded() }
                        .disabled(model.selectedRow == nil).help(L("tip.exclude"))
                }
                HStack(spacing: 6) {
                    Text(L("field.changeTo"))
                    TextField("", text: $model.changeTo).textFieldStyle(.roundedBorder).onSubmit { model.changeSelected() }
                        .help(L("tip.changeTo")).accessibilityLabel(L("field.changeTo"))
                    Button(L("button.change")) { model.changeSelected() }
                        .disabled(!model.canChangeSelected).help(L("tip.change"))
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 6)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("heading")).font(.system(size: 22, weight: .semibold))
                    Explanation(L("subtitle"))
                }
                Spacer()
            }
            if !model.trusted {
                HStack(spacing: 8) {
                    Label(L("error.notTrusted"), systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Spacer()
                    Button(L("button.openAccessibility")) { AccessibilitySettingsLocator.shared.open(required: true) }
                }
            }
            HSplitView {
                VariantList(model: model)
                ScrollView { leftColumn }.frame(minWidth: 250, idealWidth: 280, maxWidth: 360)
                rightColumn.frame(minWidth: 300, idealWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
            }
            if !model.note.isEmpty {
                Text(model.note).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button(L("button.loadSelection")) { model.loadSelection() }.disabled(model.isBusy).help(L("tip.loadSelection"))
                Button(L("button.unify")) {
                    if model.unifyMatches.isEmpty { model.noteNothingToReplace() } else { confirmsUnify = true }
                }
                .disabled(!model.canUnify).help(L("tip.unify"))
                if model.isBusy { ProgressView().controlSize(.small); Text(model.progressText).font(.callout).monospacedDigit() }
                Spacer()
                if model.isBusy { Button(L("button.stop")) { model.cancel() }.help(L("tip.stop")) }
                Button(L("button.close")) { close() }.keyboardShortcut(.cancelAction).disabled(model.isBusy)
                Button(L("button.find")) { model.find() }.keyboardShortcut(.defaultAction).disabled(!model.hasKeyword || model.isBusy).help(L("tip.find"))
            }
        }
        .padding(12)
        .frame(minWidth: 800, minHeight: 530)
        .background(Color(nsColor: AppSurface.color))
        .tint(appTint)
        .onAppear { focus = model.keywords.firstIndex(of: "") ?? 0 }
        .alert(String(format: L("alert.unify"), model.unifyMatches.count, model.unifyKeyword), isPresented: $confirmsUnify) {
            Button(L("button.cancel"), role: .cancel) {}
            Button(L("button.replace")) { model.unify() }
        } message: {
            Text(L(model.isGoogleDocs ? "alert.unifyDocs" : "alert.unifyText"))
        }
    }
}

// MARK: Settings

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var launcher: AppLauncherHotkey
    @AppStorage("useVariantDictionary") var useDictionary = true
    @AppStorage("userDictionary") var userDictionary = ""
    @AppStorage("resident") var resident = true
    @AppStorage("alwaysOnTop") var alwaysOnTop = true
    @AppStorage("matchInRed") var matchInRed = true
    @AppStorage("matchColor") var matchColor = ""
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
                    HotkeyField(id: AppLauncherHotkey.fieldID, combo: $launcher.combo, allowsClear: true, registered: launcher.registered, isEnabled: launcher.enabled)
                    Explanation(L("appHotkeyHint"))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            AccessibilitySection()
        })), (L("displayTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("displayTab")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("alwaysOnTop"), isOn: $alwaysOnTop)
                    Explanation(L("alwaysOnTopDetail"))
                    HStack(spacing: 8) {
                        Toggle(L("matchInRed"), isOn: $matchInRed)
                        ColorPicker(L("matchColor"), selection: Binding(get: { MatchColor.color(matchColor) }, set: { matchColor = MatchColor.code($0) }), supportsOpacity: false)
                            .labelsHidden().disabled(!matchInRed).accessibilityLabel(L("matchColor"))
                        Button(L("matchColor.reset")) { matchColor = "" }.disabled(!matchInRed || matchColor.isEmpty)
                    }
                    .padding(.top, 6)
                    Explanation(L("matchInRedDetail"))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (L("dictionaryTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("dictionary.section")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("dictionary.bundled"), isOn: $useDictionary)
                    Explanation(String(format: L("dictionary.bundledDetail"), VariantDictionary.bundled.count))
                    Text(L("dictionary.user")).padding(.top, 6)
                    TextEditor(text: $userDictionary).font(.body).frame(height: 96).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                        .accessibilityLabel(L("dictionary.user"))
                    Text(L("dictionary.userDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("rules.section")) {
                VStack(alignment: .leading, spacing: 6) {
                    RememberedList(items: model.variantRules.sorted { $0.value < $1.value }.map { (id: $0.key, text: $0.value) }, empty: L("rules.empty")) { model.forgetRule($0) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("ignored.section")) {
                VStack(alignment: .leading, spacing: 6) {
                    RememberedList(items: model.ignoredGroups.sorted { $0.value < $1.value }.map { (id: $0.key, text: $0.value) }, empty: L("ignored.empty")) { model.stopIgnoring($0) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())), (AboutSection.title, AnyView(AboutView()))])
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
    }
}
