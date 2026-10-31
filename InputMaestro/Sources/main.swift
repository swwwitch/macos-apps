import AppKit
import SwiftUI
import ServiceManagement
import Carbon
import ApplicationServices
import UniformTypeIdentifiers

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// A group's 「素通しにするアプリ」: its keys reach these apps unchanged (the app has them already, or uses ⌃ itself).
/// Per Mac, like the shared 「対象外アプリ」 list.
@MainActor
final class PassList: ObservableObject {
    let group: KeyGroup
    @Published private(set) var ids: [String]
    @Published private(set) var rejected: [String] = []
    var onChange: (() -> Void)?

    init(group: KeyGroup) {
        self.group = group
        ids = UserDefaults.standard.stringArray(forKey: group.passthroughKey) ?? CommandTable.initialPassthrough[group] ?? []
    }
    func contains(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return ids.contains { $0.caseInsensitiveCompare(bundleID) == .orderedSame }
    }
    func add(_ urls: [URL]) {
        var messages: [String] = []
        for url in urls {
            let name = ExcludedApps.displayName(url)
            guard let id = Bundle(url: url)?.bundleIdentifier, !id.isEmpty else { messages.append(String(format: L("pass.unreadable"), name)); continue }
            if contains(id) { messages.append(String(format: L("pass.duplicate"), name)); continue }
            ids.append(id)
        }
        rejected = messages
        save()
    }
    func remove(_ selection: Set<String>) { ids.removeAll { selection.contains($0) }; rejected = []; save() }
    func reset() { ids = CommandTable.initialPassthrough[group] ?? []; rejected = []; save() }
    private func save() { UserDefaults.standard.set(ids, forKey: group.passthroughKey); onChange?() }
}

@MainActor
final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true
    @Published var ansiTrigger = Model.loadTrigger("trigger.ansi", .control)
    @Published var jisTrigger = Model.loadTrigger("trigger.jis", .capsLock)
    /// Off at first: Caps Lock (where it is the trigger) also works as ⌃ for every other key.
    @Published var capsAsControl = UserDefaults.standard.bool(forKey: "capsAsControl")
    @Published var disabled = Set(UserDefaults.standard.stringArray(forKey: "disabledCommands") ?? [])
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    @Published var paused = false
    @Published var trusted = AccessibilitySection.isTrusted
    @Published var tapRunning = false
    /// The app the keys go to (the last one in front other than InputMaestro), for the main window.
    @Published var targetName = ""
    @Published var targetBundleID: String?
    @Published var excludedFront: String?
    /// The last editing command that could not be carried out.
    @Published var lastFailure: String?
    let passLists = Dictionary(uniqueKeysWithValues: KeyGroup.allCases.map { ($0, PassList(group: $0)) })
    let tap = KeyTap()
    let integration = IntegrationModel()
    let ocr = OCRModel()
    let actions = TextActions()
    let capsLockGuard = CapsLockGuard()
    private var observers: [NSObjectProtocol] = []

    // MARK: App hotkey
    static let appFieldID = "appHotkey"
    let hotkeys = HotkeySet(signature: "InMa")
    @Published var appHotkeyEnabled = UserDefaults.standard.object(forKey: "appHotkeyEnabled") as? Bool ?? true { didSet { defaults.set(appHotkeyEnabled, forKey: "appHotkeyEnabled"); registerHotkeys() } }
    @Published var appCombo = Model.readCombo("appHotkey") { didSet { defaults.set(appCombo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "appHotkey"); registerHotkeys() } }
    @Published var appHotkeyRegistered = true
    static func readCombo(_ key: String) -> KeyCombo? {
        guard let data = UserDefaults.standard.data(forKey: key), !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(KeyCombo.self, from: data)
    }

    /// Keys shared by 設定の共有. The app lists, startup and the app hotkey stay per Mac.
    static let sharedKeys: Set<String> = Set(["enabled", "trigger.ansi", "trigger.jis", "capsAsControl", "disabledCommands"]).union(IntegrationModel.sharedKeys).union(OCRModel.sharedKeys)

    init() {
        integration.onChange = { [weak self] in self?.refresh() }
        let typer = integration.commaTyper
        tap.numpad.onComma = { flags in MainActor.assumeIsolated { typer.type(flags: flags) } }
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } })
        }
        let caps = capsLockGuard
        tap.numpad.onCapsUsed = { MainActor.assumeIsolated { caps.markUsed() } }
        tap.onCapsToggle = { on in MainActor.assumeIsolated { caps.toggled(to: on) } }
        tap.onCapsUsed = { MainActor.assumeIsolated { caps.markUsed() } }
        let actions = actions
        tap.onAction = { action, extend, pid in actions.perform(action, extend: extend, pid: pid) }
        actions.onResult = { [weak self] failure in self?.lastFailure = failure }
        for list in passLists.values { list.onChange = { [weak self] in self?.refresh() } }
        // Event-driven (B13): app switches, returning to InputMaestro, and changes to the Accessibility list.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        // AXIsProcessTrusted turns true a moment after the switch in System Settings.
        observers.append(DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { MainActor.assumeIsolated { self?.refresh() } }
        })
        refresh()
    }

    static func loadTrigger(_ key: String, _ initial: TriggerKey) -> TriggerKey {
        UserDefaults.standard.string(forKey: key).flatMap(TriggerKey.init(rawValue:)) ?? initial
    }

    func save() {
        defaults.set(enabled, forKey: "enabled")
        defaults.set(ansiTrigger.rawValue, forKey: "trigger.ansi")
        defaults.set(jisTrigger.rawValue, forKey: "trigger.jis")
        defaults.set(capsAsControl, forKey: "capsAsControl")
        defaults.set(disabled.sorted(), forKey: "disabledCommands")
        defaults.set(keepRunning, forKey: "keepRunning")
        refresh()
    }

    /// Re-reads the shared settings after SettingsSync applied them; save() would otherwise write the old values back.
    func reload() {
        integration.reload(); ocr.reloadPreferences()
        enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        ansiTrigger = Model.loadTrigger("trigger.ansi", .control)
        jisTrigger = Model.loadTrigger("trigger.jis", .capsLock)
        capsAsControl = defaults.bool(forKey: "capsAsControl")
        disabled = Set(defaults.stringArray(forKey: "disabledCommands") ?? [])
        refresh()
    }

    func command(_ id: String) -> Binding<Bool> {
        Binding(get: { !self.disabled.contains(id) }, set: { on in
            if on { self.disabled.remove(id) } else { self.disabled.insert(id) }
            self.save()
        })
    }

    var passthrough: [KeyGroup: [String]] { passLists.mapValues(\.ids) }

    /// Starts the tap once Accessibility is granted and gives it the commands for the front app.
    func refresh() {
        ocr.screenAllowed = AreaCapture.allowed
        integration.updateConflicts()
        trusted = AccessibilitySection.isTrusted
        if trusted { if !tap.isRunning { tap.start() } } else if tap.isRunning { tap.stop() }
        tapRunning = tap.isRunning
        let front = NSWorkspace.shared.frontmostApplication
        if let front, front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            targetName = front.localizedName ?? front.bundleIdentifier ?? ""
            targetBundleID = front.bundleIdentifier
        }
        excludedFront = ExcludedApps.shared.excludes(targetBundleID) ? targetName : nil
        // Keys typed into InputMaestro itself (hotkey fields) are never replaced.
        let blocked = ExcludedApps.shared.blocksHotkeys(bundleID: front?.bundleIdentifier, pid: front?.processIdentifier)
        tap.numpad.update(NumpadState(active: integration.numpadEnabled && !integration.numpadConflict && !paused && !blocked, groups: integration.groups, ansiTrigger: integration.ansiTrigger, jisTrigger: integration.jisTrigger, capsAsControl: false))
        tap.update(TapState(active: enabled && !integration.controlConflict && !paused && !blocked,
                            commands: CommandTable.resolved(bundleID: front?.bundleIdentifier, passthrough: passthrough, disabled: disabled),
                            frontPID: front?.processIdentifier ?? 0, ansiTrigger: ansiTrigger, jisTrigger: jisTrigger,
                            capsAsControl: enabled && !integration.controlConflict && !paused && !blocked && capsAsControl))
        registerHotkeys()
    }

    func registerHotkeys() {
        hotkeys.unregisterAll()
        appHotkeyRegistered = true
        if ExcludedApps.shared.frontAppExcluded { return }
        if appHotkeyEnabled, let appCombo { appHotkeyRegistered = hotkeys.register(1, appCombo) == noErr }
        ocr.hotkeyRegistered = true
        if let combo = ocr.combo { ocr.hotkeyRegistered = (!appHotkeyEnabled || combo != appCombo) && hotkeys.register(2, combo) == noErr }
        var items: [HotkeyManifest.Item] = []
        if let appCombo { items.append(.init(id: "appHotkey", title: SettingsUI.shortcutTitle, keyCode: Int(appCombo.code), modifiers: Int(appCombo.modifiers), enabled: appHotkeyEnabled)) }
        // The command keys, for HotkeyHound: in every app but the excluded ones and the group's pass-through apps.
        for command in CommandTable.all {
            let modifiers = 4096 | (command.mods.contains(.shift) ? 512 : 0) | (command.mods.contains(.command) ? 256 : 0)
            items.append(.init(id: command.id, title: L("cmd." + command.id), keyCode: Int(command.key), modifiers: modifiers,
                               enabled: enabled && !disabled.contains(command.id), scope: "except",
                               apps: ExcludedApps.shared.ids + (passLists[command.group]?.ids ?? [])))
        }
        HotkeyManifest.publish(items)
    }

    var problem: Bool { !trusted || !tapRunning || !enabled || paused }
    var status: String {
        if !trusted { return L("status.denied") }
        if !tapRunning { return L("status.tapFailed") }
        if !enabled { return L("status.off") }
        if paused { return L("status.paused") }
        if integration.controlConflict { return L("conflict.control") }
        if let excludedFront { return String(format: L("status.excluded"), excludedFront) }
        return L("status.active")
    }

    /// The group's keys are replaced in the target app.
    func groupActive(_ group: KeyGroup) -> Bool { enabled && excludedFront == nil && !(passLists[group]?.contains(targetBundleID) ?? false) }

    var triggerSummary: String {
        let summary = String(format: L("triggerSummary"), ansiTrigger.title, jisTrigger.title)
        let capsUsed = ansiTrigger.usesCapsLock || jisTrigger.usesCapsLock
        return capsAsControl && capsUsed ? summary + L("capsAsControlNote") : summary
    }

    func togglePause() { paused.toggle(); refresh() }

    func stop() {
        tap.stop()
        hotkeys.unregisterAll()
        observers.forEach { NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0); DistributedNotificationCenter.default().removeObserver($0) }
    }
}

extension KeyGroup {
    var title: String { L("group." + rawValue) }
    var hint: String { L("group." + rawValue + ".hint") }
    /// The keys the group covers, for the 「素通しにするアプリ」 tab.
    var keyList: String { CommandTable.commands(in: self).filter { !$0.ignoresPassthrough }.map(\.label).joined(separator: " ") }
}

extension KeyCategory {
    var title: String { L("category." + rawValue) }
    var hint: String { L("category." + rawValue + ".hint") }
}

extension TriggerKey {
    var title: String { L("triggerKey." + rawValue) }
}

extension Command {
    var title: String { L("cmd." + id) }
}

/// Shared header (AppHeader.swift): current bundle icon, functional title and subtitle.
struct HeaderView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView { appHeader(L("headerTitle"), subtitle: L("headerSubtitle")) }
    func updateNSView(_ view: NSStackView, context: Context) {}
}

struct StatusRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).foregroundColor(tint).frame(width: 18).accessibilityHidden(true)
            Text(title).foregroundColor(.secondary).frame(width: 110, alignment: .leading)
            Text(value).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title + ": " + value)
    }
}

struct MainView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderView().fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                StatusRow(symbol: model.problem ? "exclamationmark.triangle.fill" : "keyboard", tint: model.problem ? .orange : .secondary,
                          title: L("statusRow"), value: model.status)
                StatusRow(symbol: "control", tint: .secondary, title: L("triggerRow"), value: model.triggerSummary)
                if !model.targetName.isEmpty {
                    StatusRow(symbol: "macwindow", tint: .secondary, title: L("targetRow"), value: targetText)
                }
                if let failure = model.lastFailure {
                    StatusRow(symbol: "exclamationmark.circle", tint: .orange, title: L("failureRow"), value: failure)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .border(Color(nsColor: .separatorColor), width: 1)
            TabView {
                KeyboardView(model: model).tabItem { Text(L("editingTab")) }
                NumpadPage(model: model.integration).tabItem { Text(L("numpadTab")) }
                OCRPage(model: model.ocr).tabItem { Text(L("ocrTab")) }
            }
            IntegrationStatus(model: model.integration)
            Spacer(minLength: 0)
            HStack {
                Button(L("settingsButton")) { AppDelegate.shared?.showPreferences() }
                Spacer()
                Toggle(L("enable"), isOn: Binding(get: { model.enabled }, set: { model.enabled = $0; model.save() }))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 720, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
    }

    /// 「Notes：すべて置き換え」 or which groups pass through there.
    private var targetText: String {
        if let excluded = model.excludedFront { return String(format: L("target.excluded"), excluded) }
        let passing = KeyGroup.allCases.filter { model.passLists[$0]?.contains(model.targetBundleID) ?? false }
        if passing.isEmpty { return String(format: L("target.all"), model.targetName) }
        return String(format: L("target.passing"), model.targetName, passing.map(\.title).joined(separator: L("listSeparator")))
    }
}

/// A group's pass-through list, laid out like the shared 「対象外アプリ」 list.
struct PassListView: View {
    @ObservedObject var list: PassList
    @State private var selection = Set<String>()
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            List(selection: $selection) {
                ForEach(list.ids, id: \.self) { id in
                    let info = ExcludedApps.info(id)
                    HStack(spacing: 8) {
                        Image(nsImage: info.icon).resizable().frame(width: 20, height: 20).accessibilityHidden(true)
                        Text(info.name).lineLimit(1)
                        Text(info.missing ? L("pass.missing") : id).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    .help(id)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(height: 130)
            .accessibilityLabel(list.group.title)
            HStack {
                Button(L("pass.add")) { add() }
                Button(L("pass.remove")) { list.remove(selection); selection = [] }.disabled(selection.isEmpty)
                Spacer()
                Button(L("pass.reset")) { list.reset(); selection = [] }
            }
            if !list.rejected.isEmpty {
                Text(list.rejected.joined(separator: "\n")).font(.caption).foregroundColor(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private func add() {
        let picker = NSOpenPanel()
        picker.title = L("pass.chooseTitle")
        picker.prompt = L("pass.add")
        picker.allowedContentTypes = [.applicationBundle]
        picker.allowsMultipleSelection = true
        picker.directoryURL = URL(fileURLWithPath: "/Applications")
        let list = list
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            MainActor.assumeIsolated { list.add(picker.urls) }
        }
        if let window = NSApp.keyWindow { picker.beginSheetModal(for: window, completionHandler: completion) } else { picker.begin(completionHandler: completion) }
    }
}

/// 「機能」「デフォルト」「拡張（このアプリのみ）」: each function with macOS's own key and InputMaestro's key, each with its switch.
struct KeyTable: View {
    @ObservedObject var model: Model
    let category: KeyCategory
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                Text(L("column.function")); Text(L("column.standard")); Text(L("column.extended"))
            }
            .font(.caption.weight(.semibold)).foregroundColor(.secondary)
            Divider()
            ForEach(CommandTable.rows(in: category)) { row in
                GridRow {
                    Text(L("cmd." + row.id)).frame(minWidth: 200, alignment: .leading)
                    cell(row.standard).frame(minWidth: 110, alignment: .leading)
                    cell(row.extended).frame(minWidth: 110, alignment: .leading)
                }
            }
        }
    }
    @ViewBuilder private func cell(_ command: Command?) -> some View {
        if let command {
            Toggle(isOn: model.command(command.id)) {
                Text(command.label).font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            .accessibilityLabel(command.label + " " + command.title)
        } else {
            Text("—").foregroundColor(.secondary).accessibilityHidden(true)
        }
    }
}

struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) {
                    // LoginAtLaunchView already includes the automatic login launch explanation and the Dock option.
                    LoginAtLaunchView()
                    Toggle(L("keepRunning"), isOn: Binding(get: { model.keepRunning }, set: { model.keepRunning = $0; model.save() }))
                    Text(L("keepRunningHint")).font(.caption).foregroundColor(.secondary)
                    MenuBarPresenceView()
                    VStack(alignment: .leading, spacing: 6) {
                        Text(SettingsUI.shortcutTitle).padding(.top, 4)
                        Toggle(HotkeyText.enable, isOn: $model.appHotkeyEnabled)
                        HotkeyField(id: Model.appFieldID, combo: $model.appCombo, allowsClear: true,
                                    registered: model.appHotkeyRegistered, isEnabled: model.appHotkeyEnabled)
                        Text(L("appHotkeyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                AccessibilitySection()
            })),
            (L("numpadTab"), AnyView(NumpadPage(model: model.integration))),
            (L("ocrTab"), AnyView(OCRPage(model: model.ocr))),
            (L("keysTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("conversionTitle")) {
                    Toggle(L("enable"), isOn: Binding(get: { model.enabled }, set: { model.enabled = $0; model.save() }))
                    Text(L("enableHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("triggerTitle")) {
                    Picker(L("trigger.ansi"), selection: Binding(get: { model.ansiTrigger }, set: { model.ansiTrigger = $0; model.save() })) {
                        ForEach(TriggerKey.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).fixedSize()
                    Picker(L("trigger.jis"), selection: Binding(get: { model.jisTrigger }, set: { model.jisTrigger = $0; model.save() })) {
                        ForEach(TriggerKey.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).fixedSize()
                    Toggle(L("capsAsControl"), isOn: Binding(get: { model.capsAsControl }, set: { model.capsAsControl = $0; model.save() }))
                        .padding(.top, 4)
                    Text(L("capsAsControlHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text(L("triggerHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .disabled(!model.enabled)
                ForEach(KeyCategory.allCases) { category in
                    SettingsSection(category.title) {
                        KeyTable(model: model, category: category)
                        Text(category.hint).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .disabled(!model.enabled)
                }
            })),
            (L("passTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                Text(L("passExplanation")).fixedSize(horizontal: false, vertical: true)
                ForEach(KeyGroup.allCases) { group in
                    SettingsSection(group.title) {
                        Text(group.keyList).font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                        if let list = model.passLists[group] { PassListView(list: list) }
                    }
                }
            })),
            (ExcludedApps.title, AnyView(SettingsSection(ExcludedApps.title) { ExcludedAppsView() })),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 640, maxHeight: .infinity)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, NSMenuItemValidation {
    static weak var shared: AppDelegate?
    var model: Model!
    var item: NSStatusItem!
    var mainWindow: NSWindow?
    var preferences: NSWindow?
    var helpWindow: NSWindow?
    let menu = NSMenu()
    var statusItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        StartupWindow.captureLaunch()
        ExcludedApps.shared.configure(explanation: L("excluded.explanation"), initial: CommandTable.initialExcluded)
        model = Model()
        ExcludedApps.shared.onChange = { [weak self] in self?.model.refresh() }
        model.hotkeys.action = { [weak self] number in
            if number == 2 { self?.model.ocr.recognizeArea(); return }
            StartupWindow.userRequestedWindow(); self?.showMainWindow()
        }
        model.ocr.onHotkeyChange = { [weak self] in self?.model.registerHotkeys() }
        SettingsSync.shared.onImport = { [weak self] in self?.model.reload() }
        SettingsSync.shared.start(.init(
            keys: Model.sharedKeys,
            note: StartupWindow.text("編集キー・テンキー入力・文字認識の機能設定を書き出し・同期します。",
                                     "Exports and syncs editing key, numeric keypad and text recognition preferences.",
                                     "导出并同步编辑按键、数字键盘和文字识别设置。",
                                     "편집 키, 숫자 키패드 및 텍스트 인식 설정을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・常駐・メニューバー・アプリを呼び出すホットキー・素通しにするアプリ・対象外アプリはMacごとに設定します。",
                                       "Launch at login, staying open, the menu bar icon, the show-app hotkey, pass-through apps and excluded apps are set on each Mac.",
                                       "登录时启动、常驻、菜单栏图标、显示应用快捷键、直接传递的应用和排除的应用需在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 상주, 메뉴 막대 아이콘, 앱 표시 단축키, 그대로 전달할 앱, 제외할 앱은 Mac마다 설정합니다.")))
        AccessibilityText.neededOverride = [
            "⌃を押しながら押したキーを受け取って別のキーに置き換え、カーソルのある段落の文字を読み取って選択するために使用します。未許可の場合、⌃F や ⌃K などを押しても置き換わりません。",
            "Used to receive the keys you press with ⌃ and replace them, and to read and select the text around the caret. Without permission, ⌃F, ⌃K and the others are not replaced.",
            "用于接收按住 ⌃ 时按下的键并替换为其他键，以及读取并选择光标所在段落的文字。未获授权时，按 ⌃F、⌃K 等不会被替换。",
            "⌃를 누른 채 누른 키를 받아 다른 키로 바꾸고, 커서가 있는 단락의 텍스트를 읽고 선택하는 데 사용합니다. 권한이 없으면 ⌃F, ⌃K 등을 눌러도 바뀌지 않습니다."
        ]
        WindowActivationPolicy.install()
        buildMainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.setAccessibilityLabel("InputMaestro")
        menu.delegate = self
        statusItem = menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, L("openMainWindow"), #selector(openMainWindow))
        add(menu, L("settings"), #selector(showPreferences))
        add(menu, L("recognizeButton"), #selector(recognize))
        add(menu, L("pause"), #selector(togglePause))
        menu.addItem(.separator())
        // Help submenu: app help and the note article (BASELINE「メニューの共通構成」).
        let statusHelp = NSMenu(title: L("help")); add(statusHelp, L("appHelp"), #selector(help)); HelpLinks.addNoteItem(to: statusHelp)
        menu.setSubmenu(statusHelp, for: menu.addItem(withTitle: L("help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator()); add(menu, L("quit"), #selector(quit))
        item.menu = menu
        MenuBarPresence.shared.install(name: "InputMaestro", symbol: "control", existing: item,
            show: { [weak self] in self?.showMainWindow() },
            settings: { [weak self] in self?.showPreferences() },
            help: { [weak self] in self?.help() })
        if !LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent) && !StartupWindow.suppressInitialWindow { showMainWindow() }
    }

    private func buildMainMenu() {
        let main = NSMenu(); let root = NSMenuItem(); let appMenu = NSMenu()
        main.addItem(root); root.submenu = appMenu
        add(appMenu, L("about"), #selector(about))
        appMenu.addItem(.separator())
        add(appMenu, L("settings"), #selector(showPreferences), ",")
        appMenu.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to: appMenu)
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
        HelpLinks.addNoteItem(to: helpMenu)
        NSApp.mainMenu = main; NSApp.helpMenu = helpMenu
    }

    func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "") {
        let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: key); entry.target = self
    }
    func menuWillOpen(_ menu: NSMenu) {
        model.refresh()
        statusItem.title = model.status
        menu.items.first { $0.action == #selector(togglePause) }?.state = model.paused ? .on : .off
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Not available → disabled instead of a silent no-op (B27).
        if menuItem.action == #selector(togglePause) { menuItem.state = model.paused ? .on : .off; return model.enabled }
        return true
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        StartupWindow.userRequestedWindow(); showMainWindow(); return true }
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
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { model.ocr.recognizing ? .terminateCancel : .terminateNow }
    func applicationWillTerminate(_ notification: Notification) { model?.stop() }

    @objc func openMainWindow() { showMainWindow() }
    func showMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 600), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            // Native title bar unchanged; no app name in it (BASELINE「主画面の背景とタイトルバー」).
            window.title = ""
            window.titleVisibility = .hidden
            let content = NSView(frame: window.contentLayoutRect)
            AppSurface.install(in: content)
            let hosting = NSHostingView(rootView: MainView(model: model))
            hosting.sizingOptions = [.minSize]
            // The hosting view sits on the shared surface view, so size the window from the SwiftUI content.
            let fitting = hosting.fittingSize
            let size = NSSize(width: max(720, ceil(fitting.width)), height: max(600, ceil(fitting.height)))
            window.setContentSize(size)
            content.frame = NSRect(origin: .zero, size: size)
            hosting.frame = content.bounds
            hosting.autoresizingMask = [.width, .height]
            content.addSubview(hosting)
            window.contentView = content
            window.contentMinSize = size
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("MainWindow")
            mainWindow = window
        }
        if let window = mainWindow, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); mainWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func showPreferences() {
        model.refresh()
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 640), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle")
            let hosting = NSHostingView(rootView: Preferences(model: model))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.contentMinSize = NSSize(width: 640, height: 640)
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("Preferences"); preferences = window
        }
        if let window = preferences, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
    }
    @objc func help() {
        if helpWindow == nil { helpWindow = HelpDocument.makeWindow(windowTitle: "InputMaestro — " + L("help"), text: L("helpText"), heading: L("helpHeading")) }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func recognize() { model.ocr.recognizeArea() }
    @objc func togglePause() { model.togglePause() }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary ?? [:]
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "InputMaestro",
            .applicationVersion: "\(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))",
            .credits: NSAttributedString(string: L("support"))])
    }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
SingleInstanceLaunch.enforce()
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()

// Reused from FnNumpad (BrowserSwitcher origin). Oldest process wins on simultaneous launch.
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
            // Allow the reopen Apple event to reach hidden/menu-bar applications.
            RunLoop.main.run(until: Date().addingTimeInterval(2))
        }
        exit(0)
    }
}
