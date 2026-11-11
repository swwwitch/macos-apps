import AppKit
import SwiftUI

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

struct Explanation: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
}

// MARK: - 主画面

struct MainView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if !model.trusted { accessibilityNotice }
            selectionBox
            if !model.errorText.isEmpty {
                Label(model.errorText, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).textSelection(.enabled)
            }
            if let diff = model.diff {
                ResultsView(model: model, diff: diff)
            } else {
                Spacer(minLength: 0)
            }
            bottomBar
        }
        .padding(24)
        .frame(minWidth: 600, minHeight: 600)
        .background(Color(nsColor: AppSurface.color))
        .tint(appTint)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 4) {
                Image(nsImage: currentAppIcon()).resizable().frame(width: 44, height: 44).accessibilityHidden(true)
                AppVersionLabel()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L("heading")).font(.system(size: 20, weight: .semibold))
                Text(L("subtitle")).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var accessibilityNotice: some View {
        HStack(spacing: 10) {
            Label(L("notice.accessibility"), systemImage: "xmark.circle.fill")
                .foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(L("button.openAccessibility")) { model.openAccessibilitySettings() }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private var selectionBox: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel(L("field.app"))
                HStack(spacing: 12) {
                    ForEach(AdobeApp.allCases) { app in
                        AppTile(app: app, selected: model.product == app) { model.product = app }
                            .disabled(model.isWorking)
                    }
                }
                .frame(maxWidth: .infinity)  // 左右中央
            }
            Divider()
            HStack(alignment: .top, spacing: 14) {
                sourceColumn(label: L("field.new"), selection: $model.newName)
                Button { model.swapSelection() } label: { Image(systemName: "arrow.left.arrow.right") }
                    .help(L("tip.swap")).accessibilityLabel(L("tip.swap"))
                    .disabled(model.isWorking)
                    .padding(.top, 26)
                sourceColumn(label: L("field.old"), selection: $model.oldName)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
    }

    /// 見出し（新・旧）、ポップアップ、その下に状態と［読み直す］
    private func sourceColumn(label: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(label)
            Picker(label, selection: selection) {
                ForEach(model.sources) { source in
                    Text(source.title).tag(source.name)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(model.isWorking)
            if let source = model.source(named: selection.wrappedValue) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(model.stateText(for: source)).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if source.install != nil {
                        Button(L("button.reread")) { model.reread(source.name) }
                            .controlSize(.small)
                            .disabled(model.isWorking)
                            .help(L("tip.reread"))
                    }
                }
            } else if model.sources.isEmpty {
                Explanation(LF("note.noInstall", model.product.title))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 下端：左に［保存先を開く］、右に進み具合と［比較］
    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(L("button.openFolder")) { model.openSnapshotFolder() }
                .help(L("tip.openFolder"))
            Spacer()
            if model.isWorking { ProgressView().controlSize(.small) }
            Text(model.status).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            Button { model.compare() } label: {
                Text(L("button.compare")).frame(minWidth: 100)
            }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canCompare)
        }
    }
}

extension AdobeApp {
    /// アプリ選択ボタンの下地の色（Illustrator はオレンジ、InDesign はピンク、Photoshop は青）
    var tileColor: Color {
        switch self {
        case .illustrator: return Color(red: 0.95, green: 0.55, blue: 0.0)
        case .indesign: return Color(red: 0.93, green: 0.18, blue: 0.40)
        case .photoshop: return Color(red: 0.10, green: 0.55, blue: 0.92)
        }
    }
}

/// アプリを選ぶ大きなボタン（Ai・Id・Ps の白い文字、下地はアプリの色）
struct AppTile: View {
    let app: AdobeApp
    let selected: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(app.prefix)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 12).fill(app.tileColor))
                Text(app.title).font(.system(size: 12, weight: selected ? .semibold : .regular))
            }
            .frame(width: 112, height: 100)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? appTint.opacity(0.14) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selected ? appTint : Color(nsColor: .separatorColor), lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .focusable(false)  // フォーカスリングが選択中の枠と紛らわしいので出さない
        .help(LF("tip.app", app.title))
        .accessibilityLabel(app.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - 結果

struct ResultsView: View {
    @ObservedObject var model: AppModel
    let diff: MenuDiff

    var body: some View {
        let rows = model.rows(for: model.category, in: diff)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.comparedTitle).font(.system(size: 13, weight: .semibold)).textSelection(.enabled)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                TextField(L("search.placeholder"), text: $model.query).textFieldStyle(.roundedBorder).frame(width: 150)
                Button(L("button.copy")) { model.copyShownRows() }
                    .disabled(rows.isEmpty)
                    .help(L("tip.copy"))
            }
            Picker(L("a11y.category"), selection: $model.category) {
                ForEach(ResultCategory.allCases) { category in
                    Text("\(category.title) \(model.count(of: category, in: diff))").tag(category)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            if let note = note(for: model.category) {
                Explanation(note)
            }
            List(rows) { row in
                ResultRowView(row: row)
                    .contextMenu {
                        Button(L("menu.copyPath")) { copy(row.path) }
                        if let oldPath = row.oldPath {
                            Button(L("menu.copyOldPath")) { copy(oldPath) }
                        }
                    }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .overlay {
                if rows.isEmpty { Text(L("empty.rows")).foregroundStyle(.secondary) }
            }
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func note(for category: ResultCategory) -> String? {
        switch category {
        case .renamed: return L("note.renamed")
        case .moved:
            return diff.impliedMoves > 0 ? L("note.moved") + LF("note.impliedMoves", diff.impliedMoves) : L("note.moved")
        case .shortcuts: return L("note.shortcuts")
        default: return nil
        }
    }
}

struct ResultRowView: View {
    let row: ResultRow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let oldPath = row.oldPath {
                pathText(oldPath).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary).font(.system(size: 10)).accessibilityHidden(true)
                    pathText(row.path)
                }
            } else if let oldShortcut = row.oldShortcut, let newShortcut = row.newShortcut {
                HStack {
                    pathText(row.path)
                    Spacer()
                    Text(oldShortcut.isEmpty ? "—" : oldShortcut).foregroundStyle(.secondary)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary).font(.system(size: 10)).accessibilityHidden(true)
                    Text(newShortcut.isEmpty ? "—" : newShortcut).fontWeight(.semibold)
                }
            } else {
                pathText(row.path)
            }
        }
        .textSelection(.enabled)
    }

    /// 親を薄く、末端を通常の色で
    private func pathText(_ path: String) -> Text {
        let parent = MenuDiff.parent(path)
        let leaf = MenuDiff.leaf(path)
        if parent.isEmpty { return Text(leaf) }
        return Text(parent + MenuReader.separator).foregroundColor(.secondary) + Text(leaf)
    }
}

// MARK: - 設定

struct SettingsView: View {
    @ObservedObject var launcher: AppLauncherHotkey
    @AppStorage("resident") var resident = false
    @State private var folderPath = SnapshotStore.folder.path

    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(spacing: 16) {
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
            })),
            (L("settings.saveTab"), AnyView(VStack(spacing: 16) {
                SettingsSection(L("settings.folder")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(folderPath).font(.system(size: 12)).textSelection(.enabled).lineLimit(2).truncationMode(.middle)
                        HStack {
                            Button(L("button.chooseFolder")) { chooseFolder() }
                            Button(L("button.defaultFolder")) { SnapshotStore.setFolder(nil); folderPath = SnapshotStore.folder.path }
                                .disabled(UserDefaults.standard.string(forKey: SnapshotStore.folderKey) == nil)
                            Button(L("button.openFolder")) {
                                try? FileManager.default.createDirectory(at: SnapshotStore.folder, withIntermediateDirectories: true)
                                NSWorkspace.shared.open(SnapshotStore.folder)
                            }
                        }
                        Explanation(L("settings.folderDetail"))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            })),
            (AboutSection.title, AnyView(AboutView())),
        ])
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 440, maxHeight: .infinity)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = SnapshotStore.folder
        panel.prompt = L("button.choose")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        SnapshotStore.setFolder(url)
        folderPath = url.path
    }
}
