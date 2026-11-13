import AppKit
import Carbon
import SwiftUI

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

final class Model: ObservableObject {
    @Published var apps: [InDesignApp] = []
    @Published var states: [String: MarkerState] = [:]
    @Published var running: Set<String> = []
    @Published var busy = false
    @Published var status = ""
    /// The application bar tab.
    @Published var mode = Mode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "") ?? .background {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "mode") }
    }
    @Published var workspaces: [Workspace] = []
    /// Current-state files whose workspace was deleted are hidden unless this is on (not saved; off at launch).
    @Published var showOrphans = false
    /// What the list and 「すべて非表示にする」 work on.
    var visibleWorkspaces: [Workspace] { showOrphans ? workspaces : workspaces.filter { $0.kind != .orphan } }
    var orphanCount: Int { workspaces.filter { $0.kind == .orphan }.count }
    @Published var barStates: [String: BarState] = [:]
    @Published var barStatus = ""
    enum Mode: String { case background, applicationBar, tools, associations }
    let defaults = UserDefaults.standard

    // MARK: 起動・常駐

    /// ウインドウを閉じても常駐: the tools need the app running. On by default.
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true {
        didSet { defaults.set(keepRunning, forKey: "keepRunning") }
    }
    /// アプリ起動のホットキー: shows the main window from any app while LayoutMate runs. Unset by default (per Mac).
    @Published var launchCombo: KeyCombo? = UserDefaults.standard.data(forKey: "launchHotkey").flatMap { try? JSONDecoder().decode(KeyCombo.self, from: $0) } {
        didSet { defaults.set(try? JSONEncoder().encode(launchCombo), forKey: "launchHotkey"); refreshHotkeys() }
    }
    var onLaunchHotkey: (() -> Void)?
    static let launchNumber: UInt32 = 1, brighterNumber: UInt32 = 2, darkerNumber: UInt32 = 3, lightNumber: UInt32 = 4, mediumDarkNumber: UInt32 = 5
    /// Hidden keys (not shown in Settings or menus, as in VectorMate): ⌥⇧F2 straight to 明, ⌥⇧F1 straight to やや暗め.
    static let lightCombo = KeyCombo(code: UInt32(kVK_F2), modifiers: KeyCombo.option | KeyCombo.shift)
    static let mediumDarkCombo = KeyCombo(code: UInt32(kVK_F1), modifiers: KeyCombo.option | KeyCombo.shift)
    /// Numbers whose registration failed (another app holds the key).
    @Published var failedHotkeys: Set<UInt32> = []

    // MARK: ホットキー（UIの明るさ）

    /// ⇧F2 brighter / ⇧F1 darker, registered only while InDesign is in front (VectorMate uses the same keys for Illustrator).
    @Published var hotkeysEnabled = UserDefaults.standard.object(forKey: "hotkeysEnabled") as? Bool ?? true {
        didSet { defaults.set(hotkeysEnabled, forKey: "hotkeysEnabled"); refreshHotkeys() }
    }
    static let brighterDefault = KeyCombo(code: UInt32(kVK_F2), modifiers: KeyCombo.shift)
    static let darkerDefault = KeyCombo(code: UInt32(kVK_F1), modifiers: KeyCombo.shift)
    @Published var brighterCombo: KeyCombo? = Model.loadCombo("brighterHotkey", default: Model.brighterDefault) {
        didSet { storeCombo(brighterCombo, "brighterHotkey"); refreshHotkeys() }
    }
    @Published var darkerCombo: KeyCombo? = Model.loadCombo("darkerHotkey", default: Model.darkerDefault) {
        didSet { storeCombo(darkerCombo, "darkerHotkey"); refreshHotkeys() }
    }
    /// A cleared key is stored as null and stays cleared; no value yet means the default.
    static func loadCombo(_ key: String, default value: KeyCombo?) -> KeyCombo? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return value }
        return try? JSONDecoder().decode(KeyCombo?.self, from: data)
    }
    private func storeCombo(_ combo: KeyCombo?, _ key: String) { defaults.set(try? JSONEncoder().encode(combo), forKey: key) }

    lazy var ui: InDesignUI = MainActor.assumeIsolated { InDesignUI() }
    private var activation: NSObjectProtocol?
    private lazy var hotkeys: HotkeySet = MainActor.assumeIsolated {
        let set = HotkeySet(signature: "LyMt")
        set.action = { [weak self] number in
            guard let self else { return }
            switch number {
            case Self.launchNumber: self.onLaunchHotkey?()
            case Self.brighterNumber: MainActor.assumeIsolated { self.ui.step(1) }
            case Self.darkerNumber: MainActor.assumeIsolated { self.ui.step(-1) }
            case Self.lightNumber: MainActor.assumeIsolated { self.ui.setBrightness(3) }
            case Self.mediumDarkNumber: MainActor.assumeIsolated { self.ui.setBrightness(1) }
            default: break
            }
        }
        return set
    }
    /// The launch key always; the brightness keys only while InDesign is in front, so ⇧F1 / ⇧F2 stay with every other app.
    func refreshHotkeys() {
        if activation == nil {
            activation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                self?.refreshHotkeys()
            }
        }
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == AsyncExports.bundleID
        var failed: Set<UInt32> = []
        MainActor.assumeIsolated {
            for (number, combo, wanted) in [(Self.launchNumber, launchCombo, true),
                                            (Self.brighterNumber, brighterCombo, hotkeysEnabled && front),
                                            (Self.darkerNumber, darkerCombo, hotkeysEnabled && front),
                                            (Self.lightNumber, Self.lightCombo, hotkeysEnabled && front),
                                            (Self.mediumDarkNumber, Self.mediumDarkCombo, hotkeysEnabled && front)] {
                if let combo, wanted { if hotkeys.register(number, combo) != noErr { failed.insert(number) } }
                else { hotkeys.unregister(number) }
            }
        }
        // Keep the failures of keys not registered right now (Illustrator in front) out of the display.
        let shown = failed.union(failedHotkeys.filter { $0 != Self.launchNumber && !front }).subtracting([Self.lightNumber, Self.mediumDarkNumber])
        if shown != failedHotkeys { failedHotkeys = shown }
    }
    func refreshLaunchHotkey() { refreshHotkeys() }
    /// Assigned keys other than `number`'s, for the duplicate check of HotkeyField.
    func otherHotkeys(except number: UInt32) -> [(String, KeyCombo)] {
        [(Self.launchNumber, L("launch.hotkey"), launchCombo), (Self.brighterNumber, L("hotkey.brighter"), brighterCombo),
         (Self.darkerNumber, L("hotkey.darker"), darkerCombo)].compactMap { entry in entry.0 == number ? nil : entry.2.map { (entry.1, $0) } }
    }

    // MARK: ツール

    @Published var trusted = AXIsProcessTrusted()
    /// 選択ツール: a modifier key tapped twice selects the Selection tool. Off by default.
    @Published var doubleTap = UserDefaults.standard.bool(forKey: "doubleTapSelect") {
        didSet { defaults.set(doubleTap, forKey: "doubleTapSelect"); refreshTools() }
    }
    @Published var tapKey = DoubleTapSelect.TapKey(rawValue: UserDefaults.standard.string(forKey: "doubleTapKey") ?? "") ?? .control {
        didSet { defaults.set(tapKey.rawValue, forKey: "doubleTapKey"); refreshTools() }
    }
    /// ドラッグでパン: dragging with the right (or middle) button pans InDesign's view (Space + drag). Off by default.
    @Published var dragPan = UserDefaults.standard.bool(forKey: "dragPanEnabled") {
        didSet { defaults.set(dragPan, forKey: "dragPanEnabled"); refreshTools() }
    }
    @Published var dragPanButton = DragPan.Button(rawValue: UserDefaults.standard.string(forKey: "dragPanButton") ?? "") ?? .right {
        didSet { defaults.set(dragPanButton.rawValue, forKey: "dragPanButton"); refreshTools() }
    }
    var toolsNeedPermission: Bool { doubleTap || dragPan }
    private lazy var dragPanner: DragPan = MainActor.assumeIsolated {
        let pan = DragPan()
        pan.allowed = { [weak self] in self?.dragPan == true }
        pan.isTarget = { $0.bundleIdentifier == AsyncExports.bundleID }
        pan.isTyping = { InDesignScript.isTyping($0) }
        return pan
    }
    private lazy var doubleTapper: DoubleTapSelect = MainActor.assumeIsolated { DoubleTapSelect() }

    /// Starts or stops the event tap and the key monitors; also called when the app comes to the front
    /// (the Accessibility permission may have changed: global key monitors need it from the start).
    func refreshTools() {
        let now = AXIsProcessTrusted()
        let changed = now != trusted
        if changed { trusted = now }
        MainActor.assumeIsolated {
            dragPanner.button = dragPanButton
            if dragPan && trusted { dragPanner.start() } else { dragPanner.stop() }
            doubleTapper.tapKey = tapKey
            doubleTapper.enabled = doubleTap
            if changed { doubleTapper.restart() }
        }
    }

    func stopTools() {
        MainActor.assumeIsolated { dragPanner.stop(); doubleTapper.enabled = false; hotkeys.unregisterAll() }
        if let activation { NSWorkspace.shared.notificationCenter.removeObserver(activation) }
    }

    /// InDesign rewrites workspace files when it quits, so edits are refused while any InDesign runs.
    var inDesignRunning: Bool { !running.isEmpty }
    /// Bundles chosen with "Add InDesign…" outside the scanned folders.
    private var addedPaths: [String] {
        get { UserDefaults.standard.stringArray(forKey: "addedApps") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "addedApps") }
    }

    /// Keeps the last result message unless `resetStatus` (activation after the password dialog must not erase it).
    func refresh(resetStatus: Bool = false) {
        let fm = FileManager.default
        let roots = [URL(fileURLWithPath: "/Applications"), fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        let known = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: AsyncExports.bundleID)
        apps = AsyncExports.discover(roots: roots, extra: known + addedPaths.map { URL(fileURLWithPath: $0) })
        states = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, AsyncExports.state(of: $0)) })
        running = Set(NSRunningApplication.runningApplications(withBundleIdentifier: AsyncExports.bundleID).compactMap { $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path })
        if status.isEmpty || resetStatus { status = apps.isEmpty ? L("notFound") : String(format: L("found"), apps.count) }
        workspaces = ApplicationBar.discover()
        barStates = Dictionary(uniqueKeysWithValues: workspaces.map { ($0.id, ApplicationBar.state(of: $0)) })
        if barStatus.isEmpty || resetStatus {
            let count = workspaces.count - orphanCount
            barStatus = count == 0 ? L("barNotFound") : String(format: L("barFound"), count)
        }
    }

    func setBar(_ selection: [Workspace], hidden: Bool) {
        guard !busy else { return }
        refresh()
        guard !inDesignRunning else { barStatus = L("barQuitFirst"); return }
        // Re-read from disk right before writing.
        let current = Dictionary(uniqueKeysWithValues: workspaces.map { ($0.id, $0) })
        let targets = selection.compactMap { current[$0.id] }.filter { ApplicationBar.state(of: $0) == (hidden ? .shown : .hidden) }
        guard !targets.isEmpty else { barStatus = L("nothingToDo"); return }
        busy = true
        defer { busy = false }
        let failed = targets.filter { !ApplicationBar.set($0, hidden: hidden) }.count
        refresh()
        barStatus = failed == 0 ? String(format: L(hidden ? "barDoneHidden" : "barDoneShown"), targets.count)
            : String(format: L("partial"), targets.count - failed, failed)
    }

    func add() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let app = AsyncExports.app(at: url.resolvingSymlinksInPath().standardizedFileURL) else { status = L("notInDesign"); return }
        if !addedPaths.contains(app.id) { addedPaths.append(app.id) }
        refresh(resetStatus: true)
    }

    func change(_ selection: [InDesignApp], turnOff: Bool) {
        guard !busy else { return }
        // Re-check on disk right before acting; the list may be stale after an InDesign update.
        let targets = AsyncExports.targets(selection.compactMap { AsyncExports.app(at: $0.url) }, turnOff: turnOff)
        guard !targets.isEmpty else { refresh(); status = L("nothingToDo"); return }
        busy = true
        defer { busy = false }
        var pending: [InDesignApp] = []
        for app in targets where !AsyncExports.changeWithoutPrivileges(app, turnOff: turnOff) { pending.append(app) }
        var failure: String?
        if !pending.isEmpty, let command = AsyncExports.command(for: pending, turnOff: turnOff) {
            var error: NSDictionary?
            NSAppleScript(source: AsyncExports.appleScript(command: command, prompt: L("authPrompt")))?.executeAndReturnError(&error)
            if let error {
                let code = error[NSAppleScript.errorNumber] as? Int ?? 0
                failure = code == -128 ? L("authCancelled") : L("failed") + (error[NSAppleScript.errorMessage] as? String ?? String(code))
            }
        } else if !pending.isEmpty {
            failure = L("failed") + L("invalidPath")
        }
        refresh()
        let succeeded = targets.filter { AsyncExports.state(of: $0) == (turnOff ? .off : .on) }.count
        let failed = targets.count - succeeded
        if succeeded == 0 {
            status = failure ?? L("failed")
        } else if failed > 0 {
            status = String(format: L("partial"), succeeded, failed) + (failure.map { "\n" + $0 } ?? "")
        } else {
            status = String(format: L(turnOff ? "doneOff" : "doneOn"), succeeded)
        }
        if succeeded > 0, targets.contains(where: { running.contains($0.id) }) { status += "\n" + L("restartNote") }
    }
}

struct Header: NSViewRepresentable {
    var title = L("appHeadline")
    var subtitle = L("appSubtitle")
    func makeNSView(context: Context) -> NSStackView {
        let header = appHeader(title, subtitle: subtitle)
        // The wrapping subtitle is selectable and becomes first responder on open, showing a blue selection.
        func unselectable(_ view: NSView) {
            if let field = view as? NSTextField { field.isSelectable = false; field.drawsBackground = false; field.refusesFirstResponder = true }
            view.subviews.forEach(unselectable)
        }
        unselectable(header)
        return header
    }
    func updateNSView(_ v: NSStackView, context: Context) {}
}

struct StateBadge: View {
    let state: MarkerState
    var body: some View {
        switch state {
        case .off: Label(L("stateOff"), systemImage: "checkmark.circle.fill").foregroundColor(.green)
        case .on: Label(L("stateOn"), systemImage: "circle").foregroundColor(.secondary)
        case .invalid: Label(L("stateInvalid"), systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
        }
    }
}

struct AppRow: View {
    @ObservedObject var model: Model
    let app: InDesignApp
    var state: MarkerState { model.states[app.id] ?? .invalid }
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path)).resizable().scaledToFit().frame(width: 40, height: 40).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name).font(.system(size: 14, weight: .semibold))
                    Text(app.version).font(.system(size: 12)).foregroundColor(.secondary)
                    if model.running.contains(app.id) {
                        Text(L("running")).font(.system(size: 10, weight: .medium)).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                }
                StateBadge(state: state).font(.system(size: 12))
                Text(state == .invalid ? L("invalidDetail") : app.macOSFolder.path).font(.system(size: 11)).foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.middle).help(app.markerFile.path)
            }
            Spacer()
            Button { NSWorkspace.shared.activateFileViewerSelecting([state == .on ? app.macOSFolder : app.markerFile]) } label: { Image(systemName: "magnifyingglass") }
                .help(L("reveal")).accessibilityLabel(app.name + ": " + L("reveal"))
            switch state {
            case .on: Button(L("turnOff")) { model.change([app], turnOff: true) }.accessibilityLabel(app.name + ": " + L("turnOff"))
            case .off: Button(L("restore")) { model.change([app], turnOff: false) }.accessibilityLabel(app.name + ": " + L("restore"))
            case .invalid: EmptyView()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }
}

struct WorkspaceRow: View {
    @ObservedObject var model: Model
    let workspace: Workspace
    var state: BarState { model.barStates[workspace.id] ?? .invalid }
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(workspace.name).font(.system(size: 14, weight: .semibold))
                    Text("Version " + workspace.version + " · " + workspace.locale).font(.system(size: 12)).foregroundColor(.secondary)
                    if workspace.kind == .builtIn { Text(L("barBuiltIn")).font(.system(size: 11)).foregroundColor(.secondary) }
                }
                if workspace.kind == .orphan {
                    Label(L("barOrphan"), systemImage: "questionmark.folder").foregroundColor(.secondary).font(.system(size: 12))
                }
                switch state {
                case .hidden: Label(L("barHidden"), systemImage: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 12))
                case .shown: Label(L("barShown"), systemImage: "circle").foregroundColor(.secondary).font(.system(size: 12))
                case .invalid: Label(L("stateInvalid"), systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.system(size: 12))
                }
                Text(workspace.files.map(\.lastPathComponent).joined(separator: "、")).font(.system(size: 11)).foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button { NSWorkspace.shared.activateFileViewerSelecting(workspace.files) } label: { Image(systemName: "magnifyingglass") }
                .help(L("reveal")).accessibilityLabel(workspace.name + ": " + L("reveal"))
            switch state {
            case .shown: Button(L("barHide")) { model.setBar([workspace], hidden: true) }.accessibilityLabel(workspace.name + ": " + L("barHide"))
            case .hidden: Button(L("barShow")) { model.setBar([workspace], hidden: false) }.accessibilityLabel(workspace.name + ": " + L("barShow"))
            case .invalid: EmptyView()
            }
        }
        .disabled(model.inDesignRunning)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }
}

struct ApplicationBarView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                if model.visibleWorkspaces.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.topthird.inset.filled").font(.largeTitle).foregroundColor(.secondary)
                        Text(L("barNotFound")).font(.system(size: 14, weight: .medium))
                    }.frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(model.visibleWorkspaces) { workspace in
                            WorkspaceRow(model: model, workspace: workspace)
                            if workspace != model.visibleWorkspaces.last { Divider().padding(.leading, 14) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18)))
            if model.orphanCount > 0 {
                Toggle(String(format: L("barShowOrphans"), model.orphanCount), isOn: $model.showOrphans)
                    .font(.system(size: 12)).help(L("barOrphanHint"))
            }
            Text(model.inDesignRunning ? L("barQuitFirst") : L("barNote")).font(.system(size: 11))
                .foregroundColor(model.inDesignRunning ? .orange : .secondary).fixedSize(horizontal: false, vertical: true)
            Text(model.barStatus).font(.system(size: 13)).lineLimit(3).textSelection(.enabled).frame(minHeight: 34, alignment: .topLeading)
            HStack {
                Spacer()
                Button(L("barHideAll")) { model.setBar(model.visibleWorkspaces, hidden: true) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.inDesignRunning || !model.visibleWorkspaces.contains { model.barStates[$0.id] == .shown })
            }
        }
    }
}

struct Note: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
}

/// A scrolling tab page with one titled group (関連付け).
struct FeaturePage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                GroupTitle(text: title)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        }
    }
}

/// ツール: 選択ツール（修飾キーのダブルタップ）and ドラッグでパン. The Accessibility permission is shown in 設定.
struct ToolsView: View {
    @ObservedObject var model: Model
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.toolsNeedPermission && !model.trusted {
                    HStack(alignment: .firstTextBaseline) {
                        Label(L("toolsNeedPermission"), systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
                            .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button(L("openSettings")) { (NSApp.delegate as? AppDelegate)?.openPreferences(tab: SettingsUI.launchTitle) }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    GroupTitle(text: L("selectTitle"))
                    Toggle(L("doubleTap"), isOn: $model.doubleTap)
                    HStack(spacing: 6) {
                        Text(L("tapKey"))
                        Picker("", selection: $model.tapKey) {
                            ForEach(DoubleTapSelect.TapKey.allCases, id: \.self) { Text($0.label).tag($0) }
                        }.labelsHidden().fixedSize()
                    }.disabled(!model.doubleTap).padding(.leading, 20)
                    Note(text: L("doubleTapDetail"))
                }
                VStack(alignment: .leading, spacing: 10) {
                    GroupTitle(text: L("panTitle"))
                    Toggle(L("panToggle"), isOn: $model.dragPan)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(L("panButton"))
                        Picker("", selection: $model.dragPanButton) {
                            Text(L("panRight")).tag(DragPan.Button.right)
                            Text(L("panMiddle")).tag(DragPan.Button.middle)
                        }.pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden().fixedSize()
                    }.disabled(!model.dragPan).padding(.leading, 20)
                    Note(text: L("panDetail"))
                }
                Note(text: L("toolsResident"))
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        }
    }
}

/// Same layout as VectorMate: one header, tabs along the top (NSTabView), a button row at the bottom.
struct ContentView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header().fixedSize(horizontal: false, vertical: true)
            MainTabs(pages: [
                ("background", L("tabBackground"), AnyView(BackgroundPage(model: model))),
                ("ui", L("tabApplicationBar"), AnyView(UIPage(model: model, ui: model.ui))),
                ("tools", L("tabTools"), AnyView(ToolsView(model: model))),
                ("associations", L("version.tab"), AnyView(VersionSwitchView()))
            ])
            .frame(maxHeight: .infinity)
            HStack {
                Button(L("settingsButton")) { (NSApp.delegate as? AppDelegate)?.showPreferences() }
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Button(L("reload")) { (NSApp.delegate as? AppDelegate)?.reload() }.disabled(model.busy)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 620, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
    }
}

/// Tabs along the top, as in the settings window and VectorMate (NSTabView; SwiftUI's TabView can fold into a flyout).
/// The chosen tab is remembered under its own key, apart from the settings window's.
struct MainTabs: NSViewRepresentable {
    let pages: [(id: String, title: String, content: AnyView)]
    static let key = "mainTab"
    final class Coordinator: NSObject, NSTabViewDelegate {
        func tabView(_ tabView: NSTabView, didSelect item: NSTabViewItem?) {
            if let id = item?.identifier as? String { UserDefaults.standard.set(id, forKey: MainTabs.key) }
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSTabView {
        let tabs = NSTabView()
        tabs.font = .systemFont(ofSize: 13)
        tabs.focusRingType = .none
        for page in pages {
            let item = NSTabViewItem(identifier: page.id)
            item.label = page.title
            let hosting = NSHostingView(rootView: page.content)
            hosting.sizingOptions = []
            item.view = hosting
            tabs.addTabViewItem(item)
        }
        if let saved = UserDefaults.standard.string(forKey: Self.key), let index = pages.firstIndex(where: { $0.id == saved }) { tabs.selectTabViewItem(at: index) }
        tabs.delegate = context.coordinator
        return tabs
    }
    func updateNSView(_ tabs: NSTabView, context: Context) {
        for (index, page) in pages.enumerated() where index < tabs.numberOfTabViewItems {
            (tabs.tabViewItem(at: index).view as? NSHostingView<AnyView>)?.rootView = page.content
        }
    }
}

struct GroupTitle: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 13, weight: .semibold)) }
}

/// バックグラウンド書き出し: the InDesign list with its own buttons.
struct BackgroundPage: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupTitle(text: L("headline"))
            Note(text: L("subtitle"))
            VStack(spacing: 0) {
                if model.apps.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.largeTitle).foregroundColor(.secondary)
                        Text(L("notFound")).font(.system(size: 14, weight: .medium))
                        Text(L("notFoundDetail")).font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button(L("addApp")) { model.add() }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(model.apps) { app in
                                AppRow(model: model, app: app)
                                if app != model.apps.last { Divider().padding(.leading, 66) }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18)))
            Note(text: L("updateNote"))
            Text(model.status).font(.system(size: 12)).lineLimit(3).textSelection(.enabled).frame(minHeight: 30, alignment: .topLeading)
            HStack {
                Button(L("addApp")) { model.add() }
                Spacer()
                Button(L("turnOffAll")) { model.change(model.apps, turnOff: true) }
                    .disabled(!model.apps.contains { model.states[$0.id] == .on })
            }
        }
        .disabled(model.busy)
        .padding(16)
    }
}

/// UI: brightness and display (InDesign running), then the application bar (InDesign quit).
struct UIPage: View {
    @ObservedObject var model: Model
    @ObservedObject var ui: InDesignUI
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                InDesignUIGroups(ui: ui)
                GroupTitle(text: L("ui.barTitle")).padding(.top, 6)
                ApplicationBarView(model: model)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .clipped()
    }
}

struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) {
                    LoginAtLaunchView()
                    Toggle(L("keepRunning"), isOn: $model.keepRunning)
                    Note(text: L("keepRunningHint"))
                    Text(L("launch.hotkey"))
                    HotkeyField(id: "launch", combo: $model.launchCombo, allowsClear: true, others: model.otherHotkeys(except: Model.launchNumber),
                                registered: !model.failedHotkeys.contains(Model.launchNumber), isEnabled: true)
                    Note(text: L("launch.hotkeyHint"))
                    MenuBarPresenceView()
                }
                AccessibilitySection(required: model.toolsNeedPermission)
            })),
            (L("hotkey.tab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("ui.brightnessTitle")) {
                    Toggle(HotkeyText.enable, isOn: $model.hotkeysEnabled)
                    Text(L("hotkey.brighter"))
                    HotkeyField(id: "brighter", combo: $model.brighterCombo, defaultCombo: Model.brighterDefault, allowsClear: true,
                                others: model.otherHotkeys(except: Model.brighterNumber),
                                registered: !model.failedHotkeys.contains(Model.brighterNumber), isEnabled: model.hotkeysEnabled)
                    Text(L("hotkey.darker"))
                    HotkeyField(id: "darker", combo: $model.darkerCombo, defaultCombo: Model.darkerDefault, allowsClear: true,
                                others: model.otherHotkeys(except: Model.darkerNumber),
                                registered: !model.failedHotkeys.contains(Model.darkerNumber), isEnabled: model.hotkeysEnabled)
                    Note(text: L("hotkey.brightnessHint"))
                }
                Spacer()
            })),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Model()
    var mainWindow: NSWindow?
    var preferences: NSWindow?
    var helpWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) { StartupWindow.captureLaunch() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        AccessibilityText.neededOverride = ["ja", "en", "zh-Hans", "ko"].map { Self.text("accessibilityReason", $0) }
        installMenus()
        model.refresh()
        model.onLaunchHotkey = { [weak self] in self?.showMain() }
        model.refreshLaunchHotkey()
        model.refreshTools()
        MenuBarPresence.shared.install(name: "LayoutMate", symbol: "doc.richtext",
            show: { [weak self] in self?.showMain() },
            settings: { [weak self] in self?.showPreferences() },
            help: { [weak self] in self?.showHelp() })
        if !StartupWindow.suppressInitialWindow { showMain() }
    }

    /// A string from one language's table (AccessibilityText takes all four).
    static func text(_ key: String, _ language: String) -> String {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) else { return L(key) }
        return bundle.localizedString(forKey: key, value: L(key), table: nil)
    }

    func installMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        func submenu(_ name: String) -> NSMenu { let item = NSMenuItem(); let menu = NSMenu(title: name); item.submenu = menu; bar.addItem(item); return menu }
        func add(_ m: NSMenu, _ title: String, _ sel: Selector, _ key: String = "", _ target: AnyObject? = nil) { let i = m.addItem(withTitle: title, action: sel, keyEquivalent: key); i.target = target ?? self }
        let app = submenu("LayoutMate")
        add(app, L("about"), #selector(about)); app.addItem(.separator())
        // MenuBarPresence inserts メニューバー設定… at index 2, before 設定….
        add(app, L("settings"), #selector(showPreferences), ",")
        app.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to: app)
        #endif
        let services = NSMenu(title: L("services")); app.addItem(withTitle: L("services"), action: nil, keyEquivalent: "").submenu = services; NSApp.servicesMenu = services
        app.addItem(.separator())
        add(app, L("hideApp"), #selector(NSApplication.hide(_:)), "h", NSApp)
        add(app, L("hideOthers"), #selector(NSApplication.hideOtherApplications(_:)), "h", NSApp); app.items.last?.keyEquivalentModifierMask = [.command, .option]
        add(app, L("showAll"), #selector(NSApplication.unhideAllApplications(_:)), "", NSApp); app.addItem(.separator())
        add(app, L("quit"), #selector(NSApplication.terminate(_:)), "q", NSApp)
        let file = submenu(L("file"))
        add(file, L("openMainWindow"), #selector(showMain), "0")
        file.addItem(.separator())
        add(file, L("reload"), #selector(reload), "r")
        add(file, L("addApp"), #selector(addApp), "o")
        file.addItem(.separator())
        add(file, L("close"), #selector(NSWindow.performClose(_:)), "w"); file.items.last?.target = nil
        let edit = submenu(L("edit"))
        for (key, selector, letter) in [("undo", "undo:", "z"), ("redo", "redo:", "Z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("paste", "paste:", "v"), ("selectAll", "selectAll:", "a")] { let i = edit.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: letter); i.target = nil; if key == "redo" { edit.addItem(.separator()) } }
        let window = submenu(L("window"))
        for (key, selector, letter) in [("minimize", "performMiniaturize:", ""), ("zoom", "performZoom:", "")] { window.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: letter).target = nil }
        window.addItem(.separator())
        window.addItem(withTitle: L("bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "").target = NSApp
        NSApp.windowsMenu = window
        let help = submenu(L("help")); add(help, L("helpItem"), #selector(showHelp), "?"); HelpLinks.addNoteItem(to: help); NSApp.helpMenu = help
    }

    @objc func showMain() {
        StartupWindow.userRequestedWindow()
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 640), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            // Native title bar unchanged; no app name in it.
            window.title = ""; window.titleVisibility = .hidden; window.isReleasedWhenClosed = false; window.delegate = self
            window.contentView = NSHostingView(rootView: ContentView(model: model)); window.minSize = NSSize(width: 620, height: 460)
            window.center(); window.setFrameAutosaveName("LayoutMateMain")
            mainWindow = window
        }
        if let window = mainWindow, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        model.refreshTools()
        NSApp.activate(ignoringOtherApps: true)
        if mainWindow?.isMiniaturized == true { mainWindow?.deminiaturize(nil) }
        mainWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func showPreferences() { openPreferences(tab: nil) }
    /// Opens 設定 on the tab with this title (the ツール tab's 「設定を開く」).
    func openPreferences(tab: String?) {
        AppSwitcherWindowReveal.preserveAuxiliaryWindowOnActivation()
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 560), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle"); window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: Preferences(model: model))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting; window.center(); window.setFrameAutosaveName("LayoutMateSettings")
            preferences = window
        }
        if let window = preferences, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true)
        if preferences?.isMiniaturized == true { preferences?.deminiaturize(nil) }
        preferences?.makeKeyAndOrderFront(nil)
        if let tab {
            DispatchQueue.main.async { [weak self] in
                guard let tabs = self?.preferences?.contentView.flatMap(Self.tabView),
                      let item = tabs.tabViewItems.first(where: { ($0.identifier as? String) == tab || $0.label == tab }) else { return }
                tabs.selectTabViewItem(item)
            }
        }
    }
    private static func tabView(_ view: NSView) -> NSTabView? {
        if let tabs = view as? NSTabView { return tabs }
        for sub in view.subviews { if let found = tabView(sub) { return found } }
        return nil
    }
    @objc func reload() { model.refresh(resetStatus: true); model.ui.read() }
    @objc func addApp() { showMain(); model.add() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        StartupWindow.userRequestedWindow(); showMain(); return true }
    // InDesign may have been updated or reinstalled while we were in the background; the permission may have changed.
    func applicationDidBecomeActive(_ notification: Notification) { if !model.busy { model.refresh() }; model.refreshTools() }
    /// The tools need the app running: with 常駐 off, closing the main window quits.
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === mainWindow, !model.keepRunning else { return }
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }
    func applicationWillTerminate(_ notification: Notification) { model.stopTools() }
    @objc func showHelp() {
        AppSwitcherWindowReveal.preserveAuxiliaryWindowOnActivation()
        if helpWindow == nil { helpWindow = HelpDocument.makeWindow(windowTitle: "LayoutMate — " + L("help"), text: L("helpContent")) }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: NSAttributedString(string: L("support"))])
    }
}

let app = NSApplication.shared
SingleInstanceLaunch.enforce()
let delegate = MainActor.assumeIsolated { AppDelegate() }
// Always in the app switcher (⌘Tab) and the Dock, even with no window open,
// unless 「Dockとアプリケーションスイッチャーに表示しない」 is on (DockPresence, applied by MenuBarPresence.install).
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()

/// Same as VectorMate. The oldest process wins on simultaneous launch; another copy hands over to it.
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
