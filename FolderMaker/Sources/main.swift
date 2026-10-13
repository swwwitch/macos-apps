import AppKit
import SwiftUI
import ServiceManagement

/// Shared header (AppHeader.swift): current bundle icon, functional title and subtitle.
struct HeaderView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView { appHeader(L("headerTitle"), subtitle: L("headerSubtitle")) }
    func updateNSView(_ view: NSStackView, context: Context) {}
}

/// One row of the form: right-aligned label (as the Keyboard Maestro dialog box) and the control.
struct FormRow<Content: View>: View {
    static var labelWidth: CGFloat { 100 }
    let label: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).frame(width: FormRow.labelWidth, alignment: .trailing)
            content()
        }
    }
}

enum Field: Hashable { case client, region, year, month, day, memo, bulk, projectRoot }

struct MainView: View {
    @ObservedObject var model: Model
    @FocusState private var focus: Field?
    let today = Date()

    var todayParts: [String] {
        let p = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
        return [String(p.year!), String(format: "%02d", p.month!), String(format: "%02d", p.day!)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderView().fixedSize(horizontal: false, vertical: true)
            Picker(L("mode"), selection: $model.mode) {
                Text(L("mode.single")).tag(Model.Mode.single)
                Text(L("mode.bulk")).tag(Model.Mode.bulk)
                Text(L("mode.project")).tag(Model.Mode.project)
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 460)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel(L("mode"))
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    FormRow(label: L("destination")) {
                        destinationRows.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                    switch model.mode {
                    case .single: singleFields
                    case .bulk: bulkFields
                    case .project: projectFields
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    switch model.mode {
                    case .single: singlePreview
                    case .bulk: entriesPreview(model.bulkEntries)
                    case .project: entriesPreview(model.projectEntries)
                    }
                    if model.status != L("ready") {
                        HStack(alignment: .top) {
                            Label(model.status, systemImage: model.statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(model.statusIsError ? .orange : .secondary)
                                .font(.caption).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                            Spacer(minLength: 0)
                            if model.lastCreation != nil {
                                Button(L("undo.button")) { model.undoLast() }.controlSize(.small).help(L("undo.help"))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            HStack {
                Button(L("settingsButton")) { (NSApp.delegate as? AppDelegate)?.showPreferences() }
                Spacer()
                if model.bulkMode { Text(L("bulk.shortcutHint")).font(.caption).foregroundColor(.secondary) }
                Button(L("cancel")) { (NSApp.delegate as? AppDelegate)?.mainWindow?.performClose(nil) }
                    .keyboardShortcut(.cancelAction)
                // In the text area return is a line break, so the batch is created with ⌘return.
                Button(model.mode == .single ? L("createButton") : L("bulk.createButton")) { model.create() }
                    .keyboardShortcut(model.bulkMode ? KeyboardShortcut(.return, modifiers: .command) : .defaultAction)
                    .disabled(model.busy || !isReady)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
        .onReceive(NotificationCenter.default.publisher(for: .folderMakerFocus)) { _ in
            focus = initialFocus
        }
        .onChange(of: model.mode) { _ in
            model.saveForm()
            (NSApp.delegate as? AppDelegate)?.fitMainWindow()
            DispatchQueue.main.async { focus = initialFocus }
        }
    }

    private var initialFocus: Field {
        switch model.mode {
        case .single: return model.client.isEmpty ? .client : .region
        case .bulk: return .bulk
        case .project: return .projectRoot
        }
    }

    @ViewBuilder private var projectFields: some View {
        FormRow(label: L("project") + ":") {
            HStack(spacing: 8) { projectPicker }
        }
        FormRow(label: L("project.root") + ":") {
            TextField(L("project.rootPlaceholder"), text: $model.projectRoot).focused($focus, equals: .projectRoot)
                .frame(maxWidth: .infinity).accessibilityLabel(L("project.root"))
        }
        Text(L("project.hint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            .padding(.leading, FormRow<EmptyView>.labelWidth + 10)
    }

    @ViewBuilder private var bulkFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("bulk.label")).font(.system(size: 13, weight: .semibold))
            TextEditor(text: $model.bulkText)
                .font(.system(.body, design: .monospaced))
                .focused($focus, equals: .bulk)
                .frame(minHeight: 220, maxHeight: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
                .accessibilityLabel(L("bulk.label"))
            Text(L("bulk.hint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private func entriesPreview(_ entries: [BulkNames.Entry]) -> some View {
        let states = entries.map { model.state(of: $0) }
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "folder.badge.plus").foregroundColor(.secondary).accessibilityHidden(true)
            Text(String(format: L("bulk.summary"), String(states.filter { $0 == .new }.count), String(states.filter { $0 == .exists }.count), String(states.filter { $0 == .invalid }.count)))
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        // Always the same height, so the window does not grow while typing.
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        let state = states[index]
                        HStack(spacing: 6) {
                            Image(systemName: state == .invalid ? "exclamationmark.triangle.fill" : (entry.isFile ? "doc" : "folder"))
                                .foregroundColor(state == .invalid ? .orange : .secondary).frame(width: 18).accessibilityHidden(true)
                            Text(entry.path ?? entry.line).font(.system(.body, design: .monospaced))
                                .foregroundColor(state == .new ? .primary : .secondary).lineLimit(1).truncationMode(.middle)
                            Text(state == .new ? L("bulk.new") : (state == .exists ? L("bulk.exists") : (entry.problem == .tooLong ? L("problem.tooLong") : (entry.problem == .windowsName ? L("problem.windowsName") : L("bulk.badName")))))
                                .font(.caption).foregroundColor(state == .invalid ? .orange : .secondary)
                            if entry.isFile, state == .new, let path = entry.path {
                                switch FileTemplates.lookup(fileName: (path as NSString).lastPathComponent, explicit: entry.template) {
                                case .template(let url): Text("← " + url.lastPathComponent).font(.caption).foregroundColor(.secondary)
                                case .missing(let name): Text(String(format: L("template.notFound"), name)).font(.caption).foregroundColor(.orange)
                                case .none: Text(L("template.empty")).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 110)
        }
    }

    @ViewBuilder private var singlePreview: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "folder.badge.plus").foregroundColor(.secondary).accessibilityHidden(true)
            Text(L("folderName")).foregroundColor(.secondary)
            switch model.preview {
            case .success(let name): Text(name).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            case .failure(let problem): Text(L(problem.key)).foregroundColor(.orange)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        if model.singleWithProject, let project = model.selectedProject, case .success = model.preview {
            let entries = model.singleProjectEntries
            let bad = entries.filter { $0.path == nil }.count
            Text(String(format: L("single.structureCount"), project.name, String(entries.count - bad)) + (bad > 0 ? " " + String(format: L("bulk.skippedInvalid"), String(bad)) : ""))
                .font(.caption).foregroundColor(bad > 0 ? .orange : .secondary)
        }
    }

    @ViewBuilder private var singleFields: some View {
        FormRow(label: model.label(.client) + ":") {
            TextField(L("optional"), text: $model.client).focused($focus, equals: .client).frame(maxWidth: .infinity).accessibilityLabel(model.label(.client))
        }
        FormRow(label: model.label(.region) + ":") {
            TextField(L("optional"), text: $model.region).focused($focus, equals: .region).frame(maxWidth: .infinity).accessibilityLabel(model.label(.region))
        }
        FormRow(label: L("year") + ":") {
            TextField(model.useToday ? todayParts[0] : "", text: $model.year).focused($focus, equals: .year)
                .disabled(model.useToday).frame(width: 90).accessibilityLabel(L("year"))
        }
        FormRow(label: L("month") + ":") {
            TextField(model.useToday ? todayParts[1] : L("optional"), text: $model.month).focused($focus, equals: .month)
                .disabled(model.useToday).frame(width: 90).accessibilityLabel(L("month"))
        }
        FormRow(label: L("day") + ":") {
            TextField(model.useToday ? todayParts[2] : L("optional"), text: $model.day).focused($focus, equals: .day)
                .disabled(model.useToday).frame(width: 90).accessibilityLabel(L("day"))
        }
        Toggle(L("today"), isOn: $model.useToday).padding(.leading, FormRow<EmptyView>.labelWidth + 10)
        FormRow(label: model.label(.memo) + ":") {
            TextField(L("optional"), text: $model.memo).focused($focus, equals: .memo).frame(maxWidth: .infinity).accessibilityLabel(model.label(.memo))
        }
        // The project's structure inside the new folder (Post Haste's usual way).
        HStack(spacing: 8) {
            Toggle(L("single.withProject"), isOn: Binding(get: { model.singleWithProject }, set: { model.singleWithProject = $0; model.saveForm() }))
            if model.singleWithProject { projectPicker }
        }
        .padding(.leading, FormRow<EmptyView>.labelWidth + 10)
    }

    @ViewBuilder private var projectPicker: some View {
        if model.projects.isEmpty {
            Text(L("project.none")).foregroundColor(.secondary)
        } else {
            Picker(L("project"), selection: Binding(get: { model.selectedProject?.id }, set: { model.selectedProjectID = $0; model.saveForm() })) {
                ForEach(model.projects) { project in Text(project.name.isEmpty ? L("project.untitled") : project.name).tag(Optional(project.id)) }
            }
            .labelsHidden().frame(maxWidth: .infinity, alignment: .leading).accessibilityLabel(L("project"))
        }
        Button(L("project.edit")) { (NSApp.delegate as? AppDelegate)?.showPreferencesTab(L("projectTab")) }.controlSize(.small)
    }

    private var isReady: Bool {
        if model.mode == .bulk { return model.bulkCanCreate }
        if model.mode == .project { return model.projectCanCreate }
        if case .failure = model.preview { return false }
        return model.destination != nil
    }

    private func pathText(_ url: URL) -> some View {
        Text(url.path).font(.caption).foregroundColor(.secondary).lineLimit(2).truncationMode(.middle).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func problemText(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choose(_ kind: Model.DestinationKind) {
        model.destinationKind = kind
        if kind == .front { model.refreshFrontFolder() }
        if kind == .recent { model.refreshRecentFolders() }
        model.saveForm()
    }

    /// One radio button per row so each can be dimmed on its own and carry its button on the right:
    /// 選択… beside 指定したフォルダー, 読み直す beside 最前面のフォルダー (dimmed while no folder window is open).
    @ViewBuilder private var destinationRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                RadioButton(title: L("dest.specified"), isOn: model.destinationKind == .specified) { choose(.specified) }
                Spacer(minLength: 8)
                Button(L("choose")) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
                    panel.directoryURL = model.baseURL
                    if panel.runModal() == .OK, let url = panel.url { model.chooseSpecifiedFolder(url); choose(.specified) }
                }
                .controlSize(.small).accessibilityLabel(L("dest.specified") + " " + L("choose"))
            }
            if model.destinationKind == .specified { pathText(model.baseURL).padding(.leading, 22) }

            HStack(spacing: 8) {
                RadioButton(title: L("frontFolder"), isOn: model.destinationKind == .front, enabled: model.frontFolder != nil) { choose(.front) }
                Spacer(minLength: 8)
                Button(L("recheck")) { model.refreshFrontFolder() }.controlSize(.small)
            }
            if model.destinationKind == .front {
                Group {
                    if let url = model.frontFolder { pathText(url) } else { problemText(model.frontFolderProblem ?? L("noFrontFolder")) }
                }.padding(.leading, 22)
            }

            RadioButton(title: L("dest.recent"), isOn: model.destinationKind == .recent, enabled: !model.recentFolders.isEmpty) { choose(.recent) }
            if model.destinationKind == .recent {
                Group {
                    if model.recentFolders.isEmpty {
                        problemText(L("noRecentFolder"))
                    } else {
                        Picker(L("dest.recent"), selection: Binding(get: { model.recentChoice }, set: { model.recentChoice = $0; model.saveForm() })) {
                            ForEach(model.recentFolders, id: \.self) { url in
                                Text(url.lastPathComponent + " — " + (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath)
                                    .tag(Optional(url))
                            }
                        }
                        .labelsHidden().frame(maxWidth: .infinity, alignment: .leading).accessibilityLabel(L("dest.recent"))
                        if let url = model.recentChoice { pathText(url) }
                    }
                }.padding(.leading, 22)
            }
        }
        .accessibilityElement(children: .contain).accessibilityLabel(L("destination"))
    }
}

/// AppKit radio button (the system look and dimming); exclusivity is the caller's state.
struct RadioButton: NSViewRepresentable {
    let title: String
    let isOn: Bool
    var enabled = true
    let action: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(action) }
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(radioButtonWithTitle: title, target: context.coordinator, action: #selector(Coordinator.pressed))
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }
    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        button.title = title
        button.state = isOn ? .on : .off
        button.isEnabled = enabled
    }
    final class Coordinator: NSObject {
        var action: () -> Void
        init(_ action: @escaping () -> Void) { self.action = action }
        @objc func pressed() { action() }
    }
}

extension Notification.Name { static let folderMakerFocus = Notification.Name("FolderMakerFocus") }

/// Folder field with a 「選択…」 button (folder only).
struct FolderPicker: View {
    let title: String
    @Binding var path: String
    let onChange: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Text(path).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            Button(L("choose")) {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
                panel.directoryURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
                if panel.runModal() == .OK, let url = panel.url { path = url.path; onChange() }
            }
            .accessibilityLabel(title + " " + L("choose"))
        }
    }
}

/// Settings › プロジェクト: the list on the left, the selected project's name and structure on the right.
struct ProjectSettings: View {
    @ObservedObject var model: Model
    @State private var selection: UUID?
    @State private var templateMessage = ""

    private var index: Int? { model.projects.firstIndex { $0.id == (selection ?? model.projects.first?.id) } }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                List(selection: $selection) {
                    ForEach(model.projects) { project in
                        Text(project.name.isEmpty ? L("project.untitled") : project.name).tag(Optional(project.id))
                    }
                }
                .frame(width: 180, height: 300)
                .accessibilityLabel(L("project.list"))
                HStack(spacing: 4) {
                    Button { selection = model.addProject().id } label: { Image(systemName: "plus") }
                        .help(L("project.add")).accessibilityLabel(L("project.add"))
                    Button { removeSelected() } label: { Image(systemName: "minus") }
                        .disabled(index == nil).help(L("project.remove")).accessibilityLabel(L("project.remove"))
                    Button(L("project.duplicate")) { if let index { selection = model.addProject(copying: model.projects[index]).id } }
                        .disabled(index == nil)
                }
            }
            if let index {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L("project.name"))
                        TextField("", text: Binding(get: { model.projects[safe: index]?.name ?? "" }, set: { update(index) { $0.name = $1 }($0) }))
                            .accessibilityLabel(L("project.name"))
                    }
                    Text(L("project.structure")).font(.system(size: 13, weight: .semibold))
                    TextEditor(text: Binding(get: { model.projects[safe: index]?.structure ?? "" }, set: { update(index) { $0.structure = $1 }($0) }))
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 240)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
                        .accessibilityLabel(L("project.structure"))
                    let entries = Project.entries(model.projects[safe: index]?.structure ?? "", root: "")
                    let bad = entries.filter { $0.path == nil }.count
                    let files = entries.filter { $0.path != nil && $0.isFile }.count
                    Text(String(format: L("project.count"), String(entries.count - bad - files), String(files), String(bad)))
                        .font(.caption).foregroundColor(bad > 0 ? .orange : .secondary)
                    Text(L("project.structureHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Divider().padding(.vertical, 4)
                    Text(L("template.title")).font(.system(size: 13, weight: .semibold))
                    Text(FileTemplates.folder.path).font(.caption).foregroundColor(.secondary).textSelection(.enabled)
                        .lineLimit(2).truncationMode(.middle)
                    HStack {
                        Button(L("template.open")) {
                            FileTemplates.installDefaults()
                            NSWorkspace.shared.open(FileTemplates.folder)
                        }
                        Button(L("template.restore")) {
                            let added = FileTemplates.installDefaults()
                            templateMessage = String(format: L("template.restored"), String(added))
                        }
                    }
                    if !templateMessage.isEmpty { Text(templateMessage).font(.caption).foregroundColor(.secondary) }
                    Text(L("template.hint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(L("project.none")).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { if selection == nil { selection = model.selectedProject?.id } }
    }

    private func update(_ index: Int, _ change: @escaping (inout Project, String) -> Void) -> (String) -> Void {
        { value in
            guard var project = model.projects[safe: index] else { return }
            change(&project, value)
            model.updateProject(project)
        }
    }
    private func removeSelected() {
        guard let index, let project = model.projects[safe: index] else { return }
        let alert = NSAlert()
        alert.messageText = String(format: L("project.removeConfirm"), project.name.isEmpty ? L("project.untitled") : project.name)
        alert.informativeText = L("project.removeHint")
        alert.addButton(withTitle: L("project.remove"))
        alert.addButton(withTitle: L("cancel"))
        alert.buttons.last?.keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        model.removeProject(project.id)
        selection = model.projects.first?.id
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// Settings › 名前の規則: pattern, date style, field names, and the name checks (NFC, Windows).
struct RuleSettings: View {
    @ObservedObject var model: Model
    private func binding(_ key: WritableKeyPath<NamingRule, String>) -> Binding<String> {
        Binding(get: { model.rule[keyPath: key] }, set: { model.rule[keyPath: key] = $0; model.saveRule() })
    }
    private var example: String {
        let sample = FolderName(client: model.label(.client) == L("client") ? "ricoh" : model.label(.client),
                                region: "osaka", memo: L("rule.sampleMemo"), useToday: true,
                                pattern: model.rule.pattern, dateStyle: model.rule.style)
        switch sample.build() {
        case .success(let name): return name
        case .failure(let problem): return L(problem.key)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("ruleTab")) {
                HStack {
                    Text(L("rule.pattern"))
                    TextField(FolderName.defaultPattern, text: binding(\.pattern))
                        .font(.system(.body, design: .monospaced)).accessibilityLabel(L("rule.pattern"))
                }
                HStack(spacing: 6) {
                    Text(L("rule.insert")).font(.caption).foregroundColor(.secondary)
                    ForEach(FolderName.tokens, id: \.self) { token in
                        Button(tokenTitle(token)) { model.rule.pattern += "{\(token)}"; model.saveRule() }.controlSize(.small)
                    }
                }
                Picker(L("rule.dateStyle"), selection: Binding(get: { model.rule.style }, set: { model.rule.dateStyle = $0.rawValue; model.saveRule() })) {
                    ForEach(FolderName.DateStyle.allCases, id: \.self) { style in Text(style.example).tag(style) }
                }
                .frame(width: 320)
                HStack(spacing: 6) {
                    Text(L("rule.example")).foregroundColor(.secondary)
                    Text(example).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                }
                Text(L("rule.hint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(L("rule.reset")) { model.rule.pattern = FolderName.defaultPattern; model.rule.dateStyle = FolderName.DateStyle.compact.rawValue; model.saveRule() }
            }
            SettingsSection(L("rule.labels")) {
                ForEach([(\NamingRule.clientLabel, L("client")), (\NamingRule.regionLabel, L("region")), (\NamingRule.memoLabel, L("memo"))], id: \.1) { key, standard in
                    HStack {
                        Text(standard + ":").frame(width: 100, alignment: .trailing)
                        TextField(standard, text: binding(key)).frame(width: 220).accessibilityLabel(standard)
                    }
                }
                Text(L("rule.labelsHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            SettingsSection(L("rule.checks")) {
                Toggle(L("rule.nfc"), isOn: Binding(get: { model.normalizeNFC }, set: { model.normalizeNFC = $0; model.save() }))
                Text(L("rule.nfcHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                Toggle(L("rule.windows"), isOn: Binding(get: { model.windowsSafe }, set: { model.windowsSafe = $0; model.save() }))
                Text(L("rule.windowsHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private func tokenTitle(_ token: String) -> String {
        switch token {
        case "client": return model.label(.client)
        case "region": return model.label(.region)
        case "memo": return model.label(.memo)
        default: return L("rule.date")
        }
    }
}

struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) {
                    Toggle(L("login"), isOn: Binding(get: { model.loginOn }, set: { model.changeLogin($0) }))
                    Text(model.loginStatus).font(.caption).foregroundColor(.secondary)
                    Button(L("loginSettings")) { SMAppService.openSystemSettingsLoginItems() }
                    StartupWindowView()
                    Toggle(L("keepRunning"), isOn: Binding(get: { model.keepRunning }, set: { model.keepRunning = $0; model.save() }))
                    Text(L("keepRunningHint")).font(.caption).foregroundColor(.secondary)
                    MenuBarPresenceView()
                    HStack(spacing: 8) {
                        Toggle(SettingsUI.shortcutTitle, isOn: Binding(get: { model.appHotkeyEnabled }, set: {
                            model.appHotkeyEnabled = $0
                            if $0 && model.appShortcut == nil { model.startRecording() } else { model.save() }
                        }))
                        Text(model.recording ? L("pressKey") : model.hotkeyLabel)
                            .font(.system(.body, design: .monospaced)).frame(width: 90, alignment: .leading)
                            .foregroundColor(model.appHotkeyEnabled ? .primary : .secondary)
                            .accessibilityLabel(L("currentKey") + " " + model.hotkeyLabel)
                        Button(model.recording ? L("cancelRecording") : L("change")) { model.startRecording() }
                        Button(L("clearShortcut")) { model.clearShortcut() }.disabled(model.appShortcut == nil)
                    }
                    if let status = model.hotkeyFailure {
                        Label(String(format: L("registerFailed"), String(status)), systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.caption)
                    }
                    if model.recording { Text(model.recordMessage).font(.caption) }
                    Text(L("appHotkeyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(AccessibilityText.text("title")) {
                    AccessibilityPermissionView(required: model.addToSidebar, showsTitle: false)
                }
                SettingsSection(L("automationTitle")) {
                    Text(L("automationHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button(L("automationOpen")) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") { NSWorkspace.shared.open(url) }
                    }
                }
            })),
            (L("destinationTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("destinationTab")) {
                    FolderPicker(title: L("baseFolder"), path: $model.baseFolder) { model.save() }
                    Text(L("baseFolderHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button(L("resetBaseFolder")) { model.baseFolder = Model.defaultBaseFolder; model.save() }
                }
            })),
            (L("afterTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("showTitle")) {
                    Toggle(L("openAfter"), isOn: Binding(get: { model.openAfter }, set: { model.openAfter = $0; model.save() }))
                    Picker(L("viewer"), selection: Binding(get: { model.viewer }, set: { model.viewer = $0; model.save() })) {
                        Text(L("viewer.automatic")).tag(FileViewers.Choice.automatic)
                        Text("Path Finder").tag(FileViewers.Choice.pathFinder)
                        Text("Finder").tag(FileViewers.Choice.finder)
                    }.frame(width: 360).disabled(!model.openAfter)
                    Toggle(L("revealInParent"), isOn: Binding(get: { model.revealInParent }, set: { model.revealInParent = $0; model.save() }))
                        .disabled(!model.openAfter)
                    Toggle(L("closeAfter"), isOn: Binding(get: { model.closeAfter }, set: { model.closeAfter = $0; model.save() }))
                }
                SettingsSection(L("sidebarTitle")) {
                    Toggle(L("addToSidebar"), isOn: Binding(get: { model.addToSidebar }, set: { model.addToSidebar = $0; model.save() }))
                    Text(L("addToSidebarHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("linkTitle")) {
                    Toggle(L("makeLink"), isOn: Binding(get: { model.makeLink }, set: { model.makeLink = $0; model.save() }))
                    FolderPicker(title: L("linkFolder"), path: $model.linkFolder) { model.save() }.disabled(!model.makeLink)
                    Toggle(L("linkInBatch"), isOn: Binding(get: { model.linkInBatch }, set: { model.linkInBatch = $0; model.save() }))
                        .disabled(!model.makeLink)
                    Text(L("makeLinkHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (L("ruleTab"), AnyView(RuleSettings(model: model))),
            (L("projectTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("projectTab")) { ProjectSettings(model: model) }
                SettingsSection(L("shared.title")) {
                    FolderPicker(title: L("shared.folder"), path: Binding(get: { model.sharedFolder.isEmpty ? L("shared.none") : model.sharedFolder },
                                                                       set: { model.setSharedFolder($0) })) {}
                    if !model.sharedFolder.isEmpty {
                        Button(L("shared.stop")) { model.setSharedFolder("") }
                    }
                    if let problem = model.sharedProblem {
                        Label(problem, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundColor(.orange)
                    }
                    Text(L("shared.hint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    var model: Model!
    var item: NSStatusItem!
    var mainWindow: NSWindow?
    var preferences: NSWindow?
    var helpWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = Model()
        // Bundled file templates that are missing from the user's folder (never overwrites theirs).
        FileTemplates.installDefaults()
        AccessibilityText.neededOverride = [
            "Path Finder の［ファイル］メニューの「サイドバーへ追加」を押すために使用します。「Path Finder のサイドバーに追加」をオンにしたときだけ必要です。",
            "Used to press Add to Sidebar in Path Finder's File menu. Needed only when Add to Path Finder's sidebar is on.",
            "用于点按 Path Finder“文件”菜单中的“添加到边栏”。仅在打开“添加到 Path Finder 边栏”时需要。",
            "Path Finder의 [파일] 메뉴에서 ‘사이드바에 추가’를 누르는 데 사용합니다. ‘Path Finder 사이드바에 추가’를 켰을 때만 필요합니다."
        ]
        WindowActivationPolicy.install()
        model.onAppHotkey = { [weak self] in self?.toggleMainWindow() }
        model.onCreated = { [weak self] in
            guard let self, self.model.closeAfter else { return }
            self.mainWindow?.orderOut(nil)
            WindowActivationPolicy.update()
        }
        buildMainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.setAccessibilityLabel("FolderMaker")
        let menu = NSMenu()
        add(menu, L("openMainWindow"), #selector(openMainWindow))
        add(menu, L("undo.menu"), #selector(undoLast))
        add(menu, L("settings"), #selector(showPreferences))
        menu.addItem(.separator())
        let statusHelp = NSMenu(title: L("help")); add(statusHelp, L("appHelp"), #selector(help)); MainActor.assumeIsolated { HelpLinks.addNoteItem(to: statusHelp) }
        menu.setSubmenu(statusHelp, for: menu.addItem(withTitle: L("help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator()); add(menu, L("quit"), #selector(quit))
        item.menu = menu
        MainActor.assumeIsolated {
            MenuBarPresence.shared.install(name: "FolderMaker", symbol: "folder.badge.plus", existing: item,
                show: { [weak self] in self?.showMainWindow() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in self?.help() })
        }
        if !LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent) && !StartupWindow.hidden { showMainWindow() }
    }

    private func buildMainMenu() {
        let main = NSMenu(); let root = NSMenuItem(); let appMenu = NSMenu()
        main.addItem(root); root.submenu = appMenu
        add(appMenu, L("about"), #selector(about))
        appMenu.addItem(.separator())
        add(appMenu, L("settings"), #selector(showPreferences), ",")
        appMenu.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        MainActor.assumeIsolated { AppUpdates.shared.addMenuItems(to: appMenu) }
        #endif
        let services = NSMenu(title: L("services"))
        appMenu.addItem(withTitle: L("services"), action: nil, keyEquivalent: "").submenu = services
        NSApp.servicesMenu = services
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: L("hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: L("showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        add(appMenu, L("quit"), #selector(quit), "q")
        let fileRoot = NSMenuItem(); let fileMenu = NSMenu(title: L("file")); fileRoot.submenu = fileMenu; main.addItem(fileRoot)
        add(fileMenu, L("openMainWindow"), #selector(openMainWindow), "0")
        fileMenu.addItem(.separator())
        add(fileMenu, L("recheckMenu"), #selector(recheckFront), "r")
        add(fileMenu, L("undo.menu"), #selector(undoLast), "z").keyEquivalentModifierMask = [.command, .option]
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: L("closeWindow"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let editRoot = NSMenuItem(); let editMenu = NSMenu(title: L("edit")); editRoot.submenu = editMenu; main.addItem(editRoot)
        for (key, selector, equivalent) in [("undo", Selector(("undo:")), "z"), ("redo", Selector(("redo:")), "Z"), ("cut", #selector(NSText.cut(_:)), "x"), ("copy", #selector(NSText.copy(_:)), "c"), ("paste", #selector(NSText.paste(_:)), "v"), ("selectAll", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(withTitle: L(key), action: selector, keyEquivalent: equivalent)
        }
        let windowRoot = NSMenuItem(); let windowMenu = NSMenu(title: L("window")); windowRoot.submenu = windowMenu; main.addItem(windowRoot)
        windowMenu.addItem(withTitle: L("minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: L("zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: L("bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
        let helpRoot = NSMenuItem(); let helpMenu = NSMenu(title: L("help")); helpRoot.submenu = helpMenu; main.addItem(helpRoot)
        add(helpMenu, L("appHelp"), #selector(help), "?")
        MainActor.assumeIsolated { HelpLinks.addNoteItem(to: helpMenu) }
        NSApp.mainMenu = main; NSApp.helpMenu = helpMenu
    }

    @discardableResult
    func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: key); entry.target = self
        return entry
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(recheckFront) { return mainWindow?.isVisible == true && model.useFrontFolder }
        if menuItem.action == #selector(undoLast) { return model.lastCreation != nil && !model.busy }
        return true
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMainWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !model.keepRunning }
    func windowWillClose(_ notification: Notification) {
        // Accessory applications also need an explicit last-window close path.
        guard let closing = notification.object as? NSWindow else { return }
        DispatchQueue.main.async { [weak self, weak closing] in
            guard let self, !self.model.keepRunning else { return }
            let otherVisible = NSApp.windows.contains { $0 !== closing && $0.isVisible && $0.canBecomeMain }
            if !otherVisible { NSApp.terminate(nil) }
        }
    }
    func applicationWillTerminate(_ notification: Notification) { model?.stop() }

    @objc func openMainWindow() { showMainWindow() }
    @objc func recheckFront() { model.refreshFrontFolder() }
    @objc func undoLast() { model.undoLast() }
    /// The app hotkey: shows the form, or hides it when it is already in front.
    func toggleMainWindow() {
        if let window = mainWindow, window.isVisible, window.isKeyWindow, NSApp.isActive { window.performClose(nil) } else { showMainWindow() }
    }
    func showMainWindow() {
        // Read the front Finder / Path Finder window before FolderMaker comes forward.
        if mainWindow?.isVisible != true { model.prepareForm() }
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 560), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            // Native title bar unchanged; no app name in it (BASELINE「主画面の背景とタイトルバー」).
            window.title = ""
            window.titleVisibility = .hidden
            let content = NSView(frame: window.contentLayoutRect)
            AppSurface.install(in: content)
            let hosting = NSHostingView(rootView: MainView(model: model))
            hosting.sizingOptions = [.minSize]
            let size = fittingMainSize()
            window.setContentSize(size)
            content.frame = NSRect(origin: .zero, size: size)
            hosting.frame = content.bounds
            hosting.autoresizingMask = [.width, .height]
            content.addSubview(hosting)
            window.contentView = content
            window.contentMinSize = size
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("MainWindow")
            let current = window.contentRect(forFrameRect: window.frame).size
            if current.width < size.width || current.height < size.height {
                var frame = window.frame
                let grow = NSSize(width: max(0, size.width - current.width), height: max(0, size.height - current.height))
                frame.size.width += grow.width; frame.size.height += grow.height; frame.origin.y -= grow.height
                window.setFrame(frame, display: false)
            }
            mainWindow = window
            // A frame saved in bulk mode is taller than the other modes need.
            fitMainWindow()
        }
        if let window = mainWindow, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); mainWindow?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { NotificationCenter.default.post(name: .folderMakerFocus, object: nil) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.offerWaysToOpen() }
    }
    /// The form's natural size at the default width (fittingSize is 0 for a flexible-width SwiftUI root).
    func fittingMainSize() -> NSSize {
        // Proposed height 1: flexible parts (the bulk text area) take their minimum instead of filling the proposal.
        let fitting = NSHostingController(rootView: MainView(model: model)).sizeThatFits(in: NSSize(width: 560, height: 1))
        return NSSize(width: max(560, ceil(fitting.width)), height: max(420, ceil(fitting.height)))
    }
    /// Switching modes: the minimum follows the mode, and the window grows (never shrinks below what the user chose for bulk).
    func fitMainWindow() {
        guard let window = mainWindow else { return }
        DispatchQueue.main.async {
            let size = self.fittingMainSize()
            window.contentMinSize = size
            var frame = window.frame
            let current = window.contentRect(forFrameRect: frame).size
            let height = self.model.mode == .bulk ? max(current.height, size.height) : size.height
            let width = max(current.width, size.width)
            let target = window.frameRect(forContentRect: NSRect(origin: .zero, size: NSSize(width: width, height: height))).size
            frame.origin.y += frame.size.height - target.height
            frame.size = target
            window.setFrame(frame, display: true, animate: true)
        }
    }
    /// Opens Settings on the tab with this title (the main window's 「編集…」 for projects).
    func showPreferencesTab(_ tab: String) {
        showPreferences()
        func find(_ view: NSView) -> NSTabView? {
            if let tabs = view as? NSTabView { return tabs }
            for sub in view.subviews { if let found = find(sub) { return found } }
            return nil
        }
        if let content = preferences?.contentView, let tabs = find(content) {
            let index = tabs.indexOfTabViewItem(withIdentifier: tab)
            if index != NSNotFound { tabs.selectTabViewItem(at: index) }
        }
    }
    /// Once: without a hotkey or the menu bar icon the form can only be reached by opening the app again.
    func offerWaysToOpen() {
        let key = "waysToOpenOffered"
        guard !UserDefaults.standard.bool(forKey: key), model.appShortcut == nil,
              !MainActor.assumeIsolated({ MenuBarPresence.shared.enabled }), NSApp.modalWindow == nil, mainWindow?.isVisible == true else { return }
        UserDefaults.standard.set(true, forKey: key)
        let alert = NSAlert()
        alert.messageText = L("onboard.title")
        alert.informativeText = L("onboard.text")
        alert.addButton(withTitle: L("onboard.hotkey"))
        alert.addButton(withTitle: L("onboard.menuBar"))
        alert.addButton(withTitle: L("onboard.later"))
        alert.buttons.last?.keyEquivalent = "\u{1b}"
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            showPreferencesTab(SettingsUI.launchTitle)
            if !model.recording { model.startRecording() }
        case .alertSecondButtonReturn:
            MainActor.assumeIsolated { MenuBarPresence.shared.showSettings() }
        default: break
        }
    }
    @objc func showPreferences() {
        model.refreshLogin()
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle")
            let hosting = NSHostingView(rootView: Preferences(model: model))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.contentMinSize = NSSize(width: 640, height: 520)
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("Preferences"); preferences = window
        }
        if let window = preferences, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
    }
    @objc func help() {
        if helpWindow == nil { helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: "FolderMaker — " + L("help"), text: L("helpText"), heading: L("helpHeading")) } }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary ?? [:]
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "FolderMaker",
            .applicationVersion: "\(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))",
            .credits: NSAttributedString(string: L("support"))])
    }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
SingleInstanceLaunch.enforce()
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()

// Reused from LinkMaker (BrowserSwitcher origin). Oldest process wins on simultaneous launch.
private enum SingleInstanceLaunch {
    static func enforce() {
        let current = NSRunningApplication.current
        guard let identifier = Bundle.main.bundleIdentifier else { return }
        var candidates = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).filter { !$0.isTerminated }
        if !candidates.contains(where: { $0.processIdentifier == current.processIdentifier }) { candidates.append(current) }
        candidates.sort {
            let left = $0.launchDate ?? .distantPast
            let right = $1.launchDate ?? .distantPast
            return left == right ? $0.processIdentifier < $1.processIdentifier : left < right
        }
        guard let existing = candidates.first, existing.processIdentifier != current.processIdentifier else { return }
        existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        if let url = existing.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in exit(0) }
            RunLoop.main.run(until: Date().addingTimeInterval(2))
        }
        exit(0)
    }
}
