import SwiftUI
import AppKit
import Combine
import Carbon
import ServiceManagement

enum TokiMenuIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            draw(color: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = L("PodiumAssist — セミナー・キャプチャ準備")
        return image
    }

    static func draw(color: NSColor) {
        color.setStroke()
        let screen = NSBezierPath(roundedRect: NSRect(x: 1, y: 5, width: 16, height: 11), xRadius: 2, yRadius: 2)
        screen.lineWidth = 1.35
        screen.stroke()
        let stand = NSBezierPath()
        stand.lineWidth = 1.35
        stand.lineCapStyle = .round
        stand.move(to: NSPoint(x: 9, y: 5))
        stand.line(to: NSPoint(x: 9, y: 2))
        stand.move(to: NSPoint(x: 5.5, y: 2))
        stand.line(to: NSPoint(x: 12.5, y: 2))
        stand.stroke()
        let dial = NSBezierPath(ovalIn: NSRect(x: 5.7, y: 7.2, width: 6.6, height: 6.6))
        dial.lineWidth = 1.05
        dial.stroke()
        let hands = NSBezierPath()
        hands.lineWidth = 1.15
        hands.lineCapStyle = .round
        hands.lineJoinStyle = .round
        hands.move(to: NSPoint(x: 9, y: 12.25))
        hands.line(to: NSPoint(x: 9, y: 10.5))
        hands.line(to: NSPoint(x: 10.4, y: 9.6))
        hands.stroke()
    }
}

#if !TESTING
@main
#endif
struct TokiApp {
    @MainActor static func main() {
        SingleInstanceLaunch.enforce()
        let app = NSApplication.shared
        let delegate = StatusBarController()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class StatusBarController: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private var controlsWindow: NSWindow?
    private var preferencesWindow: NSWindow?
    private let countdown = Countdown()
    private let settings = MacSettings()
    private let presets = PresetStore()
    private var timer: Timer?
    private var refreshTimer: Timer?
    private var observers = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.refreshLoginItemAfterRename()
        AccessibilityText.neededOverride = [
            "「透明度を下げる」「視差効果を減らす」の切り替えで、システム設定のスイッチを操作するために使用します。未許可の場合、この2つだけ利用できません。",
            "Used to turn the Reduce transparency and Reduce motion switches in System Settings on or off. Without permission, only these two are unavailable.",
            "用于在系统设置中切换“降低透明度”和“减弱动态效果”开关。未获授权时，仅这两项不可用。",
            "시스템 설정에서 ‘투명도 줄이기’와 ‘동작 줄이기’ 스위치를 켜고 끄는 데 사용합니다. 권한이 없으면 이 두 항목만 사용할 수 없습니다."]
        defer { DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MenuBarPresence.shared.install(name: "PodiumAssist", symbol: "clock", existing: self.item, keepExistingImage: true,
                show: { [weak self] in self?.revealWindow() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in LocalHelp.shared.show() })
        } }
        DispatchQueue.main.async { LocalHelp.shared.install() }
        NSApp.setActivationPolicy(.accessory)
        WindowActivationPolicy.install()
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("PodiumAssistについて"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let preferences = appMenu.addItem(withTitle: L("設定…"), action: #selector(showPreferences), keyEquivalent: ",")
        preferences.target = self
        appMenu.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to: appMenu)
        #endif
        addStandardApplicationCommands(to: appMenu, name: "PodiumAssist")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let fileRoot = NSMenuItem(title: L("ファイル"), action: nil, keyEquivalent: "")
        let file = NSMenu(title: L("ファイル")); fileRoot.submenu = file; menu.addItem(fileRoot)
        let showMain = file.addItem(withTitle: L("メインウインドウを開く"), action: #selector(openMainWindowFromMenu(_:)), keyEquivalent: "0")
        showMain.keyEquivalentModifierMask = [.command]
        showMain.target = self
        file.addItem(.separator())
        file.addItem(withTitle: L("ウインドウを閉じる"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let edit = NSMenu(title: L("編集"))
        edit.addItem(withTitle: L("取り消す"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: L("やり直す"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: L("カット"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("コピー"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("ペースト"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("すべてを選択"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        editItem.submenu = edit
        menu.addItem(editItem)
        addStandardWindowMenu(to: menu)
        NSApp.mainMenu = menu
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = TokiMenuIcon.make()
            button.image?.isTemplate = true
            button.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover)
            // Left click opens the main window; right-click / Control-click shows the status menu.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        tick()
        // The 1-second tick only drives the countdown display; run it only while a countdown exists.
        countdown.$running.receive(on: DispatchQueue.main).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.updateCountdownTimer() }
        }.store(in: &observers)
        let loginLaunch = Self.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !loginLaunch && !StartupWindow.hidden { DispatchQueue.main.async { self.showControls() } }
    }

    /// One-time step after the PodiumFlight → PodiumAssist rename: an enabled login item is registered
    /// again so it points at the renamed app. A disabled one is left alone.
    private static func refreshLoginItemAfterRename() {
        let key = "loginItemRefreshedForPodiumAssist"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        guard SMAppService.mainApp.status == .enabled else { return }
        try? SMAppService.mainApp.unregister()
        try? SMAppService.mainApp.register()
    }

    /// Login launches stay quiet in the menu bar, like CarmaChameleon's LaunchPolicy.
    private static func isLoginLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventClass == AEEventClass(kCoreEventClass), event.eventID == AEEventID(kAEOpenApplication) else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    private func updateCountdownTimer() {
        tick()
        if countdown.running == nil {
            timer?.invalidate(); timer = nil
        } else if timer == nil {
            let repeating = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            RunLoop.main.add(repeating, forMode: .common)
            timer = repeating
        }
    }

    /// Re-reads system settings every 2 seconds only while the main or settings window is on screen.
    @objc private func windowOcclusionChanged() {
        let onScreen = [controlsWindow, preferencesWindow].contains { $0.map { $0.isVisible && $0.occlusionState.contains(.visible) } ?? false }
        guard onScreen else {
            refreshTimer?.invalidate(); refreshTimer = nil
            return
        }
        guard refreshTimer == nil else { return }
        settings.refresh()
        let repeating = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.settings.refresh() }
        }
        RunLoop.main.add(repeating, forMode: .common)
        refreshTimer = repeating
    }

    private func tick() {
        countdown.tick()
        item.button?.title = countdown.end == nil ? "" : " " + countdown.remaining
        item.button?.toolTip = countdown.end == nil ? L("PodiumAssist — Macの表示設定") : L("残り ") + countdown.remaining
    }

    @objc private func togglePopover() {
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.type == .rightMouseDown || event.modifierFlags.contains(.control) {
            showStatusMenu()
            return
        }
        revealWindow()
    }

    /// Status menu (BASELINE「メニューの共通構成」: right-click exception for PodiumAssist).
    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: L("メインウインドウを開く"), action: #selector(openMainWindowFromMenu(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: L("設定…"), action: #selector(showPreferences), keyEquivalent: "").target = self
        let help = NSMenu(title: L("ヘルプ"))
        help.addItem(withTitle: L("PodiumAssistヘルプ"), action: #selector(showHelpFromMenu(_:)), keyEquivalent: "").target = self
        HelpLinks.addNoteItem(to: help)
        let helpItem = menu.addItem(withTitle: L("ヘルプ"), action: nil, keyEquivalent: "")
        menu.setSubmenu(help, for: helpItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: L("メニューバー設定…"), action: #selector(showMenuBarSettings(_:)), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L("%@を終了", "PodiumAssist"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "").target = NSApp
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func showHelpFromMenu(_ sender: Any?) { LocalHelp.shared.show() }
    @objc private func showMenuBarSettings(_ sender: Any?) { MenuBarPresence.shared.showSettings() }

    private func prepareWindow() {
        guard controlsWindow == nil else { return }
        // Fit the tallest tab so the header stays put when switching tabs. 180 = everything around the tab panel
        // (padding, header, tab picker, footer and the spacing between them).
        let panelWidth: CGFloat = 384  // 420 minus the 18pt side padding
        let manualHeight = [false, true].map { detailed in
            NSHostingView(rootView: ManualControlsView(settings: settings, countdown: countdown, presets: presets, detailed: detailed).padding(16).frame(width: panelWidth)).fittingSize.height
        }.max() ?? 0
        let size = NSSize(width: 420, height: ceil(180 + manualHeight))
        // Miniaturizable so the yellow button and Window > Minimize (no key equivalent) work; full screen stays off.
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = L("セミナー・キャプチャ準備")
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.collectionBehavior.insert(.fullScreenNone)
        window.isReleasedWhenClosed = false
        let host = NSHostingController(rootView:
            MainView(countdown: countdown, settings: settings, presets: presets,
                     openPreferences: { [weak self] in self?.showPreferences() })
                .frame(minWidth: size.width, maxWidth: .infinity, minHeight: size.height, maxHeight: .infinity)
                .background(Color(nsColor: AppSurface.color), ignoresSafeAreaEdges: []))
        // Resizable from the designed size upward; the hosting controller reports only its minimum.
        host.sizingOptions = [.minSize]
        host.preferredContentSize = size
        window.contentViewController = host
        window.setContentSize(size)
        window.contentMinSize = size
        restoreFrame(of: window, name: "TokiMainWindow", minimum: size)
        controlsWindow = window
        NotificationCenter.default.addObserver(self, selector: #selector(windowOcclusionChanged), name: NSWindow.didChangeOcclusionStateNotification, object: window)
    }

    /// Settings open in their own window, next to the main window.
    private func preparePreferencesWindow() {
        guard preferencesWindow == nil else { return }
        let size = NSSize(width: 460, height: 560)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = L("設定")
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.collectionBehavior.insert(.fullScreenNone)
        window.isReleasedWhenClosed = false
        let host = NSHostingController(rootView:
            PreferencesView(countdown: countdown, settings: settings, presets: presets)
                .frame(minWidth: size.width, maxWidth: .infinity, minHeight: size.height, maxHeight: .infinity))
        host.sizingOptions = [.minSize]
        host.preferredContentSize = size
        window.contentViewController = host
        window.setContentSize(size)
        window.contentMinSize = size
        restoreFrame(of: window, name: "TokiPreferencesWindow", minimum: size)
        preferencesWindow = window
        NotificationCenter.default.addObserver(self, selector: #selector(windowOcclusionChanged), name: NSWindow.didChangeOcclusionStateNotification, object: window)
    }

    /// Restores the saved frame; a frame smaller than the design or off every screen is replaced by a centered one.
    private func restoreFrame(of window: NSWindow, name: String, minimum: NSSize) {
        window.setFrameAutosaveName(name)
        let restored = window.setFrameUsingName(name)
        let content = window.contentRect(forFrameRect: window.frame).size
        let offScreen = !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) })
        if !restored || content.width < minimum.width || content.height < minimum.height || offScreen {
            window.setContentSize(minimum); window.center()
        }
    }

    private func revealWindow() {
        prepareWindow()
        NSApp.activate(ignoringOtherApps: true)
        if controlsWindow?.isMiniaturized == true { controlsWindow?.deminiaturize(nil) }
        controlsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openMainWindowFromMenu(_ sender: Any?) {
        revealWindow()
    }

    private func showControls() {
        settings.refresh()
        revealWindow()
    }

    @objc private func showPreferences() {
        preparePreferencesWindow()
        settings.refresh()
        NSApp.activate(ignoringOtherApps: true)
        if preferencesWindow?.isMiniaturized == true { preferencesWindow?.deminiaturize(nil) }
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        revealWindow()
        return false
    }

}

struct TimerPlan: Codable, Equatable {
    var start: Date
    var minutes: Int
    var end: Date { start.addingTimeInterval(Double(minutes) * 60) }
    mutating func setEnd(_ date: Date) { minutes = Int((date.timeIntervalSince(start) / 60).rounded()) }
}

@MainActor
final class Countdown: ObservableObject {
    @Published var enabled = (UserDefaults.standard.object(forKey: "timerEnabled") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "timerEnabled")
            if !enabled { stop() }
        }
    }
    @Published var plan: TimerPlan
    @Published var running: TimerPlan?
    @Published var remaining = L("停止中")
    @Published var error = ""

    init() {
        let prefs = UserDefaults.standard
        plan = (prefs.data(forKey: "timerPlan").flatMap { try? JSONDecoder().decode(TimerPlan.self, from: $0) })
            ?? TimerPlan(start: Self.minuteNow, minutes: 30)
        running = prefs.data(forKey: "runningTimerPlan").flatMap { try? JSONDecoder().decode(TimerPlan.self, from: $0) }
        if !enabled { stop() }
        tick()
    }
    static var minuteNow: Date { Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970 / 60) * 60) }
    var end: Date? { running?.end }

    func savePlan() {
        if let data = try? JSONEncoder().encode(plan) { UserDefaults.standard.set(data, forKey: "timerPlan") }
    }
    func tick() {
        guard let running else { remaining = L("停止中"); return }
        remaining = Self.display(running, now: Date())
    }
    static func display(_ plan: TimerPlan, now: Date) -> String {
        let waiting = now < plan.start
        let seconds = max(0, Int(ceil((waiting ? plan.start : plan.end).timeIntervalSince(now))))
        let text = seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%02d:%02d", seconds / 60, seconds % 60)
        return waiting ? L("開始まで ") + text : text
    }
    func start() {
        error = ""
        guard enabled else { error = L("「タイマーを使う」をオンにしてください。"); return }
        guard (1...10080).contains(plan.minutes) else { error = L("所要時間は1〜10080分で指定してください。"); return }
        guard plan.end > Date() else { error = L("終了時間を現在より後にしてください。"); return }
        running = plan
        savePlan()
        if let data = try? JSONEncoder().encode(plan) { UserDefaults.standard.set(data, forKey: "runningTimerPlan") }
        tick()
    }
    func stop() {
        running = nil
        UserDefaults.standard.removeObject(forKey: "runningTimerPlan")
        tick()
    }
}

struct Preset: Codable, Identifiable {
    var id = UUID()
    var name = L("新しいプリセット")
    var clock: Bool? = nil
    var showDate: Bool? = nil
    var showWeekday: Bool? = nil
    var dark: Bool? = nil
    var hideDock: Bool? = nil
    var killDock: Bool? = nil
    var pointerSize: Double? = nil
    var reduceTransparency: Bool? = nil
    var reduceMotion: Bool? = nil
    var volumeFeedback: Bool? = nil
    var resolution: DisplayResolution? = nil
    var hideDesktop: Bool? = nil
    var notificationsOff: Bool? = nil
    var timerMinutes: Int? = nil
    var timerEnabled: Bool? = nil
    var quitApps: Bool? = nil
    var launchApps: [QuitAppTarget]? = nil
    var quitAppTargets: [QuitAppTarget]? = nil

    mutating func migrateAppTargets(legacyQuitTargets: [QuitAppTarget]) {
        if quitApps == true && quitAppTargets == nil { quitAppTargets = legacyQuitTargets }
        quitApps = nil
    }
}

@MainActor
final class PresetStore: ObservableObject {
    @Published var items: [Preset] = []
    private let defaults: UserDefaults
    var rememberedPreset: Preset? {
        guard let id = defaults.string(forKey: "selectedPresetID") else { return nil }
        return items.first { $0.id.uuidString == id }
    }
    func remember(_ id: UUID?) { defaults.set(id?.uuidString, forKey: "selectedPresetID") }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "presets"), let saved = try? JSONDecoder().decode([Preset].self, from: data) {
            items = saved.map { value in
                var preset = value
                preset.migrateAppTargets(legacyQuitTargets: QuitAppsStore.shared.targets)
                return preset
            }
            persist()
        }
    }
    func save(_ preset: Preset) {
        if let i = items.firstIndex(where: { $0.id == preset.id }) { items[i] = preset } else { items.append(preset) }
        remember(preset.id)
        persist()
    }
    /// Moves a preset one place up (-1) or down (+1); the main window lists presets in this order.
    func move(_ id: UUID, by offset: Int) {
        guard let i = items.firstIndex(where: { $0.id == id }), items.indices.contains(i + offset) else { return }
        items.swapAt(i, i + offset)
        persist()
    }
    func remove(_ id: UUID) { items.removeAll { $0.id == id }; if defaults.string(forKey: "selectedPresetID") == id.uuidString { remember(nil) }; persist() }
    private func persist() {
        if let data = try? JSONEncoder().encode(items) { defaults.set(data, forKey: "presets") }
    }
}

/// Main window: preset buttons and the manual controls (with the timer) in tabs. Settings open in a separate window.
struct MainView: View {
    @ObservedObject var countdown: Countdown
    @ObservedObject var settings: MacSettings
    @ObservedObject var presets: PresetStore
    let openPreferences: () -> Void
    @AppStorage("mainWindowTab") private var tab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: currentAppIcon()).resizable().scaledToFit()
                    .frame(width: 44, height: 44).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("セミナー・キャプチャ準備")).font(.system(size: 20, weight: .bold))
                    Text(L("プリセットとタイマーで、まとめて準備。")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            // In-window tabs: a SwiftUI TabView would move into the native title bar.
            Picker("", selection: $tab) {
                Text(L("プリセット")).tag(0)
                Text(L("基本設定")).tag(2)
                Text(L("その他の設定")).tag(3)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize().frame(maxWidth: .infinity)
            Group {
                if tab == 2 || tab == 3 {
                    ManualControlsView(settings: settings, countdown: countdown, presets: presets, detailed: tab == 3).padding(16)
                } else {
                    PresetPicker(settings: settings, countdown: countdown, presets: presets)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Button(L("設定…"), action: openPreferences)
                Spacer()
                // The main menu is hidden for this menu bar app, so help is reachable here by mouse.
                Menu(L("ヘルプ")) {
                    Button(L("PodiumAssistヘルプ")) { LocalHelp.shared.show() }
                    Divider()
                    Button(HelpLinks.noteTitle) { HelpLinks.openNote() }
                }
                .fixedSize()
                Button(L("%@を終了", "PodiumAssist")) { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(18)
    }
}

/// Large one-click preset buttons, after BrowserSwitcher's browser list.
struct PresetPicker: View {
    @ObservedObject var settings: MacSettings
    @ObservedObject var countdown: Countdown
    @ObservedObject var presets: PresetStore
    @AppStorage("lastAppliedPreset") private var lastApplied = ""
    @State private var renaming: Preset?
    @State private var newName = ""
    @State private var deleting: Preset?
    @State private var editingApps: (preset: Preset, launch: Bool)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if presets.items.isEmpty {
                Spacer()
                Text(L("「基本設定」タブの「プリセットに保存…」で作れます。")).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(presets.items) { preset in presetButton(preset) }
                    }
                }
            }
            NetworkSpeedSection()
            StatusMessage(settings: settings)
        }
        .padding(12)
        .disabled(settings.busy)
        .alert(L("プリセット名を変更"), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField(L("プリセット名"), text: $newName)
            Button(L("キャンセル"), role: .cancel) { renaming = nil }
            Button(L("変更")) {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if var preset = renaming, !name.isEmpty { preset.name = name; presets.save(preset) }
                renaming = nil
            }
        }
        .confirmationDialog(L("「%@」を削除しますか？", deleting?.name ?? ""), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button(L("削除"), role: .destructive) { if let preset = deleting { presets.remove(preset.id) }; deleting = nil }
            Button(L("キャンセル"), role: .cancel) { deleting = nil }
        }
        .sheet(isPresented: Binding(get: { editingApps != nil }, set: { if !$0 { editingApps = nil } })) {
            if let editing = editingApps {
                PresetAppListEditor(title: L(editing.launch ? "起動アプリを編集…" : "終了アプリを編集…"),
                    targets: Binding(get: { (editing.launch ? editing.preset.launchApps : editing.preset.quitAppTargets) ?? [] },
                                     set: { list in
                                         guard var preset = presets.items.first(where: { $0.id == editing.preset.id }) else { return }
                                         if editing.launch { preset.launchApps = list } else { preset.quitAppTargets = list }
                                         presets.save(preset)
                                         editingApps = (preset, editing.launch)
                                     }),
                    done: { editingApps = nil })
            }
        }
    }

    private func presetButton(_ preset: Preset) -> some View {
        let selected = preset.id.uuidString == lastApplied
        let index = presets.items.firstIndex { $0.id == preset.id } ?? 0
        return Button {
            lastApplied = preset.id.uuidString
            presets.remember(preset.id)  // the target of option-click 「プリセットに保存…」, kept after manual changes
            settings.apply(preset, countdown: countdown)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 22)).frame(width: 32)
                Text(preset.name).font(.system(size: 15, weight: .medium)).lineLimit(1)
                Spacer()
                if selected { Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold)) }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(selected ? Color.accentColor : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(selected ? 0 : 0.12)))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .help(L("クリックすると、このプリセットをまとめて適用します。右クリックで、名前の変更・並べ替え・起動／終了アプリの編集・削除ができます。"))
        .accessibilityValue(selected ? L("選択中") : L("未選択"))
        .contextMenu {
            Button(L("名前を変更…")) { newName = preset.name; renaming = preset }
            Divider()
            Button(L("上へ移動")) { presets.move(preset.id, by: -1) }.disabled(index == 0)
            Button(L("下へ移動")) { presets.move(preset.id, by: 1) }.disabled(index == presets.items.count - 1)
            Divider()
            Button(L("起動アプリを編集…") + " (\(preset.launchApps?.count ?? 0))") { editingApps = (preset, true) }
            Button(L("終了アプリを編集…") + " (\(preset.quitAppTargets?.count ?? 0))") { editingApps = (preset, false) }
            Divider()
            Button(L("削除…")) { deleting = preset }
        }
    }
}

/// Below the preset buttons: a check before going live, not a setting, so presets do not save it.
struct NetworkSpeedSection: View {
    @ObservedObject private var network = NetworkSpeedStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text(L("ネットワーク")).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            if network.networks.isEmpty {
                Text(L("接続しているネットワークがありません。")).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            ForEach(network.networks) { item in
                HStack {
                    // Fixed-width icon column: the Wi-Fi and cable symbols differ in width, which shifted the names.
                    Image(systemName: item.ssid != nil || item.name.localizedCaseInsensitiveContains("Wi-Fi") ? "wifi" : "cable.connector")
                        .frame(width: 18)
                    Text(item.title).lineLimit(1)
                    Spacer()
                    Text(network.results[item.id] ?? "").monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.system(size: 12))
            }
            HStack {
                Spacer()
                Button(network.measuring == nil ? L("速度を測定") : L("測定中…")) { network.measureAll() }
                    .disabled(network.measuring != nil || network.networks.isEmpty)
                    .help(L("接続しているネットワークごとに、下り（↓）と上り（↑）の速度を測ります。1つにつき約10秒かかります。"))
            }
            .font(.system(size: 12))
        }
        .onAppear { network.refresh() }
    }
}

/// Result of the last action; the standing explanations are tooltips.
/// Always two lines tall, so a message appearing does not change the tab's height and push the header up.
struct StatusMessage: View {
    @ObservedObject var settings: MacSettings
    var body: some View {
        Text(settings.message)
            .font(.system(size: 11))
            .foregroundStyle(settings.error ? Color.red : Color.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28, alignment: .leading)
            .help(settings.message)
            .accessibilityLabel(settings.message)
        if settings.automationDenied {
            Button(L("オートメーションの設定を開く…")) { MacSettings.openAutomationSettings() }
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var countdown: Countdown
    @ObservedObject var settings: MacSettings
    @ObservedObject var presets: PresetStore
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) { LoginAtLaunchView().fixedSize(horizontal: false, vertical: true); MenuBarPresenceView() }
                SettingsSection(AccessibilityText.text("title")) { AccessibilityPermissionView(required: true, showsTitle: false) }
            })),
            (AboutSection.title, AnyView(AboutView()))
        ]).padding(12)
    }
}

struct TimerPanel: View {
    @ObservedObject var countdown: Countdown
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle(L("タイマーを使う"), isOn: $countdown.enabled)
            dateTimeRow(L("開始時間"), value: countdown.plan.start) { countdown.plan.start = $0; countdown.savePlan() }
            HStack {
                Text(L("所要時間"))
                TextField(L("分"), value: Binding(get: { countdown.plan.minutes }, set: {
                    countdown.plan.minutes = $0; countdown.savePlan()
                }), format: .number.grouping(.never)).frame(width: 56)
                Text(L("分"))
            }
            dateTimeRow(L("終了時間"), value: countdown.plan.end) { countdown.plan.setEnd($0); countdown.savePlan() }
            HStack {
                Button(L("今日の日付にする")) {
                    countdown.plan.start = Self.combine(day: Date(), time: countdown.plan.start); countdown.savePlan()
                }
                Button(L("現在時刻にする")) {
                    countdown.plan.start = Self.combine(day: countdown.plan.start, time: Countdown.minuteNow); countdown.savePlan()
                }
            }
            if !countdown.error.isEmpty { Text(countdown.error).foregroundStyle(.red).font(.caption) }
            HStack {
                Text(countdown.remaining).monospacedDigit()
                Spacer()
                Button(L("停止")) { countdown.stop() }.disabled(countdown.end == nil)
                Button(countdown.end == nil ? L("開始／予約") : L("設定を反映して再開")) { countdown.start() }.buttonStyle(.borderedProminent).disabled(!countdown.enabled)
            }
        }.padding(16)
        .help(L("開始時間 ＋ 所要時間 ＝ 終了時間。開始時間・所要時間の変更で終了時間を更新。終了時間の変更で所要時間を更新します。開始前は「開始まで」、開始後は残り時間をメニューバーに表示します。終了後は00:00で止まります。"))
    }

    /// Date and time in separate fields; each keeps the other's part of the value.
    private func dateTimeRow(_ title: String, value: Date, set: @escaping (Date) -> Void) -> some View {
        HStack {
            Text(title)
            // SwiftUI's DatePicker keeps NSDatePicker's own width, which clips the last digit; a frame does not widen it.
            WideDatePicker(title: title, date: Binding(get: { value }, set: { set(Self.combine(day: $0, time: value)) }),
                           elements: .yearMonthDay, width: 150)
            WideDatePicker(title: title, date: Binding(get: { value }, set: { set(Self.combine(day: value, time: $0)) }),
                           elements: .hourMinute, width: 96)
        }
    }

    /// The calendar day of `day` at the hour and minute of `time`.
    static func combine(day: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: clock.hour ?? 0, minute: clock.minute ?? 0, second: 0, of: day) ?? day
    }
}


/// NSDatePicker (text field and stepper) at a fixed width.
struct WideDatePicker: NSViewRepresentable {
    let title: String
    @Binding var date: Date
    let elements: NSDatePicker.ElementFlags
    let width: CGFloat

    final class Picker: NSDatePicker {
        var width: CGFloat = 0
        override var intrinsicContentSize: NSSize { NSSize(width: width, height: super.intrinsicContentSize.height) }
    }

    func makeNSView(context: Context) -> Picker {
        let picker = Picker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = elements
        picker.width = width
        picker.setAccessibilityLabel(title)
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.changed(_:))
        return picker
    }

    func updateNSView(_ picker: Picker, context: Context) {
        context.coordinator.parent = self
        if picker.dateValue != date { picker.dateValue = date }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: WideDatePicker
        init(_ parent: WideDatePicker) { self.parent = parent }
        @objc func changed(_ sender: NSDatePicker) { parent.date = sender.dateValue }
    }
}

@MainActor
final class MacSettings: ObservableObject {
    @Published var dockHidden = false
    @Published var dockKilled = false
    @Published var desktopHidden = false
    @Published var analog = false
    @Published var showDate = true
    @Published var showWeekday = true
    @Published var dark = false
    @Published var pointerSize = 1.0
    @Published var reduceTransparency = false
    @Published var reduceMotion = false
    @Published var volumeFeedback = false
    @Published var resolution: DisplayResolution?
    /// Do Not Disturb as PodiumAssist last set it: the Focus state itself is not readable without Full Disk Access.
    @Published var notificationsOff = UserDefaults.standard.bool(forKey: "notificationsOffLastSet") {
        didSet { UserDefaults.standard.set(notificationsOff, forKey: "notificationsOffLastSet") }
    }
    @Published var hasExternalDisplay = false
    @Published var mirrored = false
    @Published var busy = false
    @Published var message = ""
    /// System Events automation was refused; the views offer a button to the Automation pane.
    @Published var automationDenied = false
    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") { NSWorkspace.shared.open(url) }
    }
    @Published var error = false

    private let clockDomain = "com.apple.menuextra.clock" as CFString

    func refresh() {
        guard !busy else { return }
        CFPreferencesAppSynchronize(clockDomain)
        showDate = (CFPreferencesCopyAppValue("ShowDate" as CFString, clockDomain) as? NSNumber)?.intValue != 2
        showWeekday = (CFPreferencesCopyAppValue("ShowDayOfWeek" as CFString, clockDomain) as? NSNumber)?.boolValue ?? true
        analog = (CFPreferencesCopyAppValue("IsAnalog" as CFString, clockDomain) as? NSNumber)?.boolValue ?? false
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        dockHidden = (CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) as? NSNumber)?.boolValue ?? false
        dockKilled = UserDefaults.standard.dictionary(forKey: "dockBackup") != nil
        CFPreferencesAppSynchronize("com.apple.finder" as CFString)
        desktopHidden = (CFPreferencesCopyAppValue("CreateDesktop" as CFString, "com.apple.finder" as CFString) as? NSNumber)?.boolValue == false
        dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        pointerSize = PointerSize.current
        resolution = DisplayResolution.current
        hasExternalDisplay = DisplayMirroring.hasExternal
        mirrored = DisplayMirroring.isMirrored
        reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        volumeFeedback = (CFPreferencesCopyAppValue(Self.volumeFeedbackKey, kCFPreferencesAnyApplication) as? NSNumber)?.boolValue ?? false
    }

    func setResolution(_ value: DisplayResolution) {
        do {
            let applied = try DisplayResolution.set(value)
            error = false
            message = L("解像度を %@ にしました。", applied.text)
        } catch {
            self.error = true
            message = error.localizedDescription
        }
        refresh()
    }

    func setMirrored(_ value: Bool) {
        do {
            try DisplayMirroring.set(mirrored: value)
            error = false
            message = value ? L("ミラーリングにしました。") : L("拡張ディスプレイにしました。")
        } catch {
            self.error = true
            message = error.localizedDescription
        }
        refresh()
    }

    /// System Settings → Sound → "Play feedback when volume is changed" (global domain; measured by toggling the switch).
    private static let volumeFeedbackKey = "com.apple.sound.beep.feedback" as CFString

    func setVolumeFeedback(_ value: Bool) {
        CFPreferencesSetAppValue(Self.volumeFeedbackKey, NSNumber(value: value ? 1 : 0), kCFPreferencesAnyApplication)
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        refresh()
        if volumeFeedback == value {
            error = false
            message = value ? L("音量変更時のフィードバックをオンにしました。") : L("音量変更時のフィードバックをオフにしました。")
        } else {
            error = true
            message = L("音量変更時のフィードバックを変更できませんでした。")
        }
    }

    /// Asks first (deletion cannot be undone), then clears the default browser's history.
    func clearBrowserHistory() {
        guard !busy else { return }
        guard let browser = BrowserHistory.defaultBrowser else { return }
        if case .unsupported = browser.kind {
            error = true
            message = L("%@の履歴は削除できません。ブラウザーのメニューから削除してください。", browser.name)
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("%@の閲覧履歴をすべて削除しますか？", browser.name)
        alert.informativeText = L("ブックマーク・Cookie・ログイン状態は残ります。削除した履歴は元に戻せません。%@が起動中の場合は終了し、削除後にもう一度開きます。", browser.name)
        alert.addButton(withTitle: L("削除"))
        alert.addButton(withTitle: L("キャンセル"))
        // Destructive: Return/Esc both stay on the safe side.
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        busy = true
        error = false
        message = L("%@の履歴を削除しています…", browser.name)
        Task {
            do {
                let count = try await BrowserHistory.clear(browser)
                message = count == 0 ? L("%@の履歴は見つかりませんでした。", browser.name) : L("%@の履歴を削除しました。", browser.name)
            } catch {
                self.error = true
                message = error.localizedDescription
            }
            busy = false
        }
    }

    /// Flips a System Settings switch (the preference write is refused without Full Disk Access). `then` runs afterwards on success.
    private func setSystemSwitch(_ target: (pane: String, identifier: String), to value: Bool, working: String, done: String, then: (() -> Void)?) {
        guard !busy else { return }
        busy = true
        error = false
        message = working
        Task {
            do {
                try await SystemSettingsSwitch.set(pane: target.pane, identifier: target.identifier, to: value)
                message = done
                busy = false
                refresh()
                then?()
            } catch {
                self.error = true
                message = error.localizedDescription
                busy = false
                refresh()
            }
        }
    }

    func setReduceTransparency(_ value: Bool, then: (() -> Void)? = nil) {
        setSystemSwitch(SystemSettingsSwitch.reduceTransparency, to: value, working: L("システム設定で透明度を変更しています…"),
                        done: value ? L("透明度を下げました。") : L("透明度を元に戻しました。"), then: then)
    }

    func setReduceMotion(_ value: Bool, then: (() -> Void)? = nil) {
        setSystemSwitch(SystemSettingsSwitch.reduceMotion, to: value, working: L("システム設定で視差効果を変更しています…"),
                        done: value ? L("視差効果を減らしました。") : L("視差効果を元に戻しました。"), then: then)
    }

    func setPointerSize(_ value: Double) {
        if PointerSize.set(value) {
            error = false
            message = L("ポインタのサイズを%@にしました。", PointerSize.text(value))
        } else {
            error = true
            message = L("ポインタのサイズを変更できませんでした。")
        }
        refresh()
    }

    func setClock(_ value: Bool) {
        guard !busy else { return }
        busy = true
        error = false
        do {
            try run("/usr/bin/defaults", ["write", clockDomain as String, "IsAnalog", "-bool", value ? "true" : "false"])
            // ControlCenter owns the menu bar clock on current macOS releases.
            // Restart only this user's process so it reloads its preferences.
            try run("/usr/bin/killall", ["-u", NSUserName(), "ControlCenter"], allowedStatuses: [0, 1])
            CFPreferencesAppSynchronize(clockDomain)
            let saved = (CFPreferencesCopyAppValue("IsAnalog" as CFString, clockDomain) as? NSNumber)?.boolValue ?? false
            guard saved == value else { throw SettingsError(L("時計の設定を保存できませんでした。")) }
            analog = saved
            message = L("時計を%@に変更しました。", value ? L("アナログ") : L("デジタル"))
        } catch {
            self.error = true
            message = error.localizedDescription
        }
        busy = false
        refresh()
    }

    func setDateVisible(_ value: Bool) {
        guard !busy else { return }
        busy = true
        do {
            try run("/usr/bin/defaults", ["write", clockDomain as String, "ShowDate", "-int", value ? "1" : "2"])
            try run("/usr/bin/killall", ["-u", NSUserName(), "ControlCenter"], allowedStatuses: [0, 1])
            error = false
            message = value ? L("メニューバーに日付を表示しました。") : L("メニューバーの日付を非表示にしました。")
        } catch { self.error = true; message = error.localizedDescription }
        busy = false
        refresh()
    }

    func setWeekdayVisible(_ value: Bool) {
        guard !busy else { return }
        busy = true
        do {
            try run("/usr/bin/defaults", ["write", clockDomain as String, "ShowDayOfWeek", "-bool", value ? "true" : "false"])
            try run("/usr/bin/killall", ["-u", NSUserName(), "ControlCenter"], allowedStatuses: [0, 1])
            error = false
            message = value ? L("メニューバーに曜日を表示しました。") : L("メニューバーの曜日を非表示にしました。")
        } catch { self.error = true; message = error.localizedDescription }
        busy = false
        refresh()
    }

    func setAppearance(_ value: Bool) {
        guard !busy else { return }
        busy = true
        error = false
        automationDenied = false
        // A documented System Events scripting property changes the system appearance.
        // No GUI scripting or Accessibility permission is required.
        let source = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to \(value ? "true" : "false")
                return dark mode
            end tell
        end tell
        """
        var details: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&details)
        if let details {
            error = true
            let code = details[NSAppleScript.errorNumber] as? Int
            automationDenied = code == -1743
            if code == -1743 {
                message = L("外観を変更するには、システム設定の「プライバシーとセキュリティ」→「オートメーション」で、PodiumAssistに「System Events」の操作を許可してください。")
            } else {
                message = L("外観を変更できませんでした：%@", String(describing: details[NSAppleScript.errorMessage] ?? L("不明なエラー")))
            }
        } else if let result, result.booleanValue == value {
            dark = value
            message = L("Macの外観を%@に変更しました。", value ? L("ダーク") : L("ライト"))
        } else {
            error = true
            message = L("外観の変更を確認できませんでした。")
        }
        busy = false
    }

    func setDockHidden(_ value: Bool) {
        do {
            try run("/usr/bin/defaults", ["write", "com.apple.dock", "autohide", "-bool", value ? "true" : "false"])
            try run("/usr/bin/killall", ["-u", NSUserName(), "Dock"], allowedStatuses: [0, 1])
            error = false
            message = value ? L("Dockの自動非表示をオンにしました。") : L("Dockの自動非表示をオフにしました。")
        } catch { self.error = true; message = error.localizedDescription }
        refresh()
    }

    func setDockKilled(_ value: Bool) {
        do {
            let keys = ["tilesize", "autohide-delay"]
            let domain = "com.apple.dock" as CFString
            if value {
                if UserDefaults.standard.dictionary(forKey: "dockBackup") == nil {
                    CFPreferencesAppSynchronize(domain)
                    var backup: [String: Any] = [:]
                    for key in keys {
                        backup[key] = CFPreferencesCopyAppValue(key as CFString, domain) ?? "__absent__" as CFString
                    }
                    UserDefaults.standard.set(backup, forKey: "dockBackup")
                }
                try run("/usr/bin/defaults", ["write", "com.apple.dock", "tilesize", "-int", "1"])
                try run("/usr/bin/defaults", ["write", "com.apple.dock", "autohide-delay", "-float", "3000000"])
            } else if let backup = UserDefaults.standard.dictionary(forKey: "dockBackup") {
                for key in keys {
                    let old = backup[key]
                    CFPreferencesSetAppValue(key as CFString, (old as? String) == "__absent__" ? nil : old as CFPropertyList?, domain)
                }
                guard CFPreferencesAppSynchronize(domain) else { throw SettingsError(L("Dockの復元を保存できませんでした。")) }
            }
            try run("/usr/bin/killall", ["-u", NSUserName(), "Dock"], allowedStatuses: [0, 1])
            if !value { UserDefaults.standard.removeObject(forKey: "dockBackup") }
            error = false
            message = value ? L("Dockを完全非表示にしました（サイズ1・表示までの待ち時間3000000秒）。") : L("Dockを完全非表示にする前の設定に戻しました。")
        } catch { self.error = true; message = error.localizedDescription }
        refresh()
    }

    func setDesktopHidden(_ value: Bool) {
        do {
            try run("/usr/bin/defaults", ["write", "com.apple.finder", "CreateDesktop", "-bool", value ? "false" : "true"])
            try run("/usr/bin/killall", ["-u", NSUserName(), "Finder"], allowedStatuses: [0, 1])
            error = false
            message = value ? L("デスクトップアイコンを非表示にしました。") : L("デスクトップアイコンを表示しました。")
        } catch { self.error = true; message = error.localizedDescription }
        refresh()
    }

    func apply(_ preset: Preset, countdown: Countdown) {
        guard !busy else { return }
        refresh()
        error = false
        if let value = preset.clock, value != analog { setClock(value); if error { return } }
        if let value = preset.showDate { setDateVisible(value); if error { return } }
        if let value = preset.showWeekday { setWeekdayVisible(value); if error { return } }
        if let value = preset.dark { setAppearance(value); if error { return } }
        if let value = preset.killDock, value != dockKilled { setDockKilled(value); if error { return } }
        if let value = preset.hideDock, value != dockHidden { setDockHidden(value); if error { return } }
        if let value = preset.hideDesktop, value != desktopHidden { setDesktopHidden(value); if error { return } }
        if let value = preset.pointerSize { setPointerSize(value); if error { return } }
        if let value = preset.resolution, value != resolution { setResolution(value); if error { return } }
        if let value = preset.volumeFeedback { setVolumeFeedback(value); if error { return } }
        if let minutes = preset.timerMinutes { countdown.plan.minutes = minutes; countdown.savePlan() }
        if let value = preset.timerEnabled { countdown.enabled = value }
        if let apps = preset.quitAppTargets { QuitAppsStore.shared.quit(apps, excluding: Set((preset.launchApps ?? []).map(\.id))) }
        if let apps = preset.launchApps { LaunchAppsStore.shared.launch(apps) }
        // Transparency and notifications both run asynchronously; notifications wait for the System Settings step.
        let finish = { [self] in
            if let value = preset.notificationsOff { setNotificationsOff(value) }
            else { message = L("「%@」を適用しました。", String(describing: preset.name)) }
        }
        // System Settings steps run one after another (each opens the pane), then notifications.
        let motion = { [self] in
            if let value = preset.reduceMotion, value != reduceMotion { setReduceMotion(value, then: finish) } else { finish() }
        }
        if let value = preset.reduceTransparency, value != reduceTransparency { setReduceTransparency(value, then: motion) } else { motion() }
    }

    func setNotificationsOff(_ value: Bool) {
        guard !busy else { return }
        busy = true
        error = false
        message = L("通知の設定を変更しています…")
        Task {
            do {
                try await Task.detached {
                    try self.run("/usr/bin/shortcuts", ["run", value ? "Toki Notifications Off" : "Toki Notifications On"])
                }.value
                notificationsOff = value
                message = value ? L("おやすみモードをオンにしました。許可済みの通知は届く場合があります。") : L("おやすみモードを解除しました。")
            } catch {
                self.error = true
                message = L("通知を変更できませんでした。ショートカットの「Toki Notifications On / Off」を確認してください。")
            }
            busy = false
        }
    }

    nonisolated private func run(_ path: String, _ arguments: [String], allowedStatuses: Set<Int32> = [0]) throws {
        let process = Process()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        try process.run()
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeout)
        defer { timeout.cancel() }
        let data = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard allowedStatuses.contains(process.terminationStatus) else {
            throw SettingsError(String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? L("設定を変更できませんでした。"))
        }
    }
}

struct SettingsError: LocalizedError {
    let text: String
    init(_ text: String) { self.text = text }
    var errorDescription: String? { text }
}

/// Main window 「基本設定」 / 「その他の設定」 tabs: switch each Mac setting directly (presets switch several at once).
struct ManualControlsView: View {
    @ObservedObject var settings: MacSettings
    @ObservedObject var countdown: Countdown
    @ObservedObject var presets: PresetStore
    /// false: clock, date, weekday, appearance and the timer. true: everything else.
    let detailed: Bool
    @State private var saving = false
    /// The preset ✓ means "applied last"; a manual change makes that stale, so it is cleared.
    @AppStorage("lastAppliedPreset") private var lastApplied = ""
    @State private var pointerDraft = 1.0
    /// Only widens the 解像度 menu; nothing on the Mac changes.
    @AppStorage("showAllResolutions") private var showAllResolutions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if detailed {
                category(L("ディスプレイ")) {
                    HStack {
                        Label(L("外部ディスプレイ"), systemImage: "rectangle.on.rectangle").fixedSize()
                        Spacer()
                        Picker(L("外部ディスプレイ"), selection: Binding(get: { settings.mirrored }, set: { value in manual { settings.setMirrored(value) } })) {
                            Text(L("ミラーリング")).tag(true)
                            Text(L("拡張ディスプレイ")).tag(false)
                        }
                        .pickerStyle(.segmented).labelsHidden().fixedSize()
                    }
                    .font(.system(size: 12))
                    .disabled(settings.busy || !settings.hasExternalDisplay)
                    .opacity(settings.hasExternalDisplay ? 1 : 0.4)
                    .help(settings.hasExternalDisplay ? L("外部ディスプレイにメインディスプレイと同じ画面を映すか、画面を広げて使うかを切り替えます。") : L("外部ディスプレイが接続されていません。"))
                    HStack {
                        Label(L("解像度"), systemImage: "display").fixedSize()
                        Spacer()
                        Picker(L("解像度"), selection: Binding(get: { settings.resolution }, set: { value in if let value { manual { settings.setResolution(value) } } })) {
                            Text(L("ディスプレイの既定に戻す")).tag(Optional(DisplayResolution.displayDefault))
                            Divider()
                            ForEach(DisplayResolution.choices(showAll: showAllResolutions), id: \.self) { Text($0.text).tag(Optional($0)) }
                        }
                        .labelsHidden().frame(width: 170)
                    }
                    .font(.system(size: 12)).disabled(settings.busy)
                    Toggle(L("すべての解像度を表示"), isOn: $showAllResolutions)
                        .font(.system(size: 12))
                        .help(L("低解像度のモードも一覧に含めます。"))
                }
                category(L("見やすさ")) {
                    Toggle(L("透明度を下げる"), isOn: Binding(get: { settings.reduceTransparency }, set: { value in manual { settings.setReduceTransparency(value) } }))
                        .font(.system(size: 12)).disabled(settings.busy)
                    Toggle(L("視差効果を減らす"), isOn: Binding(get: { settings.reduceMotion }, set: { value in manual { settings.setReduceMotion(value) } }))
                        .font(.system(size: 12)).disabled(settings.busy)
                    HStack {
                        Label(L("ポインタのサイズ"), systemImage: "cursorarrow").fixedSize()
                        Spacer()
                        // Applied when the knob is released, not on every step of the drag.
                        Slider(value: $pointerDraft, in: PointerSize.range, step: 0.5) { editing in
                            if !editing { manual { settings.setPointerSize(pointerDraft) } }
                        }
                        .frame(width: 96)
                        Text(PointerSize.text(pointerDraft)).monospacedDigit().frame(width: 28, alignment: .trailing)
                        Button(L("標準に戻す")) { pointerDraft = 1; manual { settings.setPointerSize(1) } }
                            .disabled(settings.pointerSize == 1)
                    }
                    .font(.system(size: 12))
                    .onAppear { pointerDraft = settings.pointerSize }
                    .onChange(of: settings.pointerSize) { pointerDraft = $0 }
                }
                category(L("集中を妨げるもの")) {
                    Toggle(L("音量を変更するときにフィードバックを再生"), isOn: Binding(get: { settings.volumeFeedback }, set: { value in manual { settings.setVolumeFeedback(value) } }))
                        .font(.system(size: 12))
                    Toggle(L("通知を止める（おやすみモード）"), isOn: Binding(get: { settings.notificationsOff }, set: { value in manual { settings.setNotificationsOff(value) } }))
                        .font(.system(size: 12)).disabled(settings.busy)
                        .help(L("おやすみモードを切り替えます。表示はPodiumAssistで最後に切り替えた状態です（コントロールセンターなどで変えた場合は反映されません）。"))
                }
                category(L("プライバシー")) {
                    Toggle(L("デスクトップアイコンを非表示"), isOn: Binding(get: { settings.desktopHidden }, set: { value in manual { settings.setDesktopHidden(value) } }))
                        .font(.system(size: 12))
                    HStack {
                        Label(L("ブラウザーの履歴"), systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text(BrowserHistory.defaultBrowser?.name ?? "").foregroundStyle(.secondary)
                        Button(L("削除…")) { settings.clearBrowserHistory() }
                    }
                    .font(.system(size: 12)).disabled(settings.busy)
                }
                category("Dock") {
                    HStack(spacing: 16) {
                        Toggle(L("自動非表示"), isOn: Binding(get: { settings.dockHidden }, set: { value in manual { settings.setDockHidden(value) } }))
                        Toggle(L("完全非表示"), isOn: Binding(get: { settings.dockKilled }, set: { value in manual { settings.setDockKilled(value) } }))
                            .help(L("アイコンを最小にし、表示までの待ち時間を最大にします。"))
                    }
                    .font(.system(size: 12))
                }
            } else {
                VStack(spacing: 14) {
                    settingRow(L("時計"), subtitle: L("メニューバー"), symbol: "clock") {
                        choice(L("デジタル"), selected: !settings.analog) { manual { settings.setClock(false) } }
                        choice(L("アナログ"), selected: settings.analog) { manual { settings.setClock(true) } }
                    }
                    Divider()
                    settingRow(L("日付"), subtitle: settings.analog ? L("デジタル時計用") : L("メニューバー"), symbol: "calendar") {
                        choice(L("表示する"), selected: settings.showDate) { manual { settings.setDateVisible(true) } }
                        choice(L("しない"), selected: !settings.showDate) { manual { settings.setDateVisible(false) } }
                    }
                    .disabled(settings.analog)
                    .opacity(settings.analog ? 0.4 : 1)
                    Divider()
                    settingRow(L("曜日"), subtitle: settings.analog ? L("デジタル時計用") : L("メニューバー"), symbol: "calendar.day.timeline.left") {
                        choice(L("表示する"), selected: settings.showWeekday) { manual { settings.setWeekdayVisible(true) } }
                        choice(L("しない"), selected: !settings.showWeekday) { manual { settings.setWeekdayVisible(false) } }
                    }
                    .disabled(settings.analog)
                    .opacity(settings.analog ? 0.4 : 1)
                    Divider()
                    settingRow(L("外観"), subtitle: L("Mac全体"), symbol: "circle.lefthalf.filled") {
                        choice(L("ライト"), selected: !settings.dark) { manual { settings.setAppearance(false) } }
                        choice(L("ダーク"), selected: settings.dark) { manual { settings.setAppearance(true) } }
                    }
                }
                .padding(14)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                .disabled(settings.busy)
                TimerPanel(countdown: countdown)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            }
            // The message sits beside the button, so its fixed two-line height adds no empty row.
            HStack(spacing: 12) {
                StatusMessage(settings: settings)
                // Click: overwrite the preset applied (or saved) last, with the items it already has.
                // Option-click, or no such preset yet: the sheet to choose the preset and items. No "…" when no sheet opens.
                Button(presets.rememberedPreset == nil ? L("プリセットに保存…") : L("プリセットに保存")) {
                    if !NSEvent.modifierFlags.contains(.option), let preset = presets.rememberedPreset {
                        PresetSaveSheet.overwrite(preset, settings: settings, countdown: countdown, presets: presets)
                    } else {
                        saving = true
                    }
                }
                .help(presets.rememberedPreset.map { L("今の状態を、最後に適用したプリセット「%@」に上書きします。optionキーを押しながらクリックすると、保存先と含める項目を選べます。", $0.name) }
                      ?? L("今の状態を、新しいプリセットか既存のプリセットに保存します。含める項目は保存時に選べます。"))
            }
        }
        .help(L("選択すると、Macのシステム設定を変更します。"))
        .sheet(isPresented: $saving) { PresetSaveSheet(settings: settings, countdown: countdown, presets: presets) { saving = false } }
        .onAppear { settings.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in settings.refresh() }
        // Connecting or disconnecting a display, or mirroring from elsewhere.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in settings.refresh() }
    }

    private func manual(_ change: () -> Void) {
        lastApplied = ""
        change()
    }

    /// A titled group on the 「その他の設定」 tab.
    private func category<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func settingRow<Content: View>(_ title: String, subtitle: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 19)).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4, content: content)
        }
    }

    private func choice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .frame(width: 64, height: 28)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Color.accentColor : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? L("選択中") : L("未選択"))
    }
}

/// Standard Window menu (placed before Help); registered as NSApp.windowsMenu so open windows are listed.
@MainActor
private func addStandardWindowMenu(to mainMenu: NSMenu) {
    let root = NSMenuItem(title: L("ウインドウ"), action: nil, keyEquivalent: "")
    let menu = NSMenu(title: L("ウインドウ"))
    menu.addItem(withTitle: L("しまう"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "")
    menu.addItem(withTitle: L("拡大／縮小"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(withTitle: L("すべてを手前に移動"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
    root.submenu = menu
    mainMenu.addItem(root)
    NSApp.windowsMenu = menu
}

private func addStandardApplicationCommands(to menu: NSMenu, name: String) {
    let services = NSMenu(title: L("サービス"))
    let item = menu.addItem(withTitle: L("サービス"), action: nil, keyEquivalent: "")
    item.submenu = services
    NSApp.servicesMenu = services
    menu.addItem(.separator())
    menu.addItem(withTitle: L("%@を隠す", String(describing: name)), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
    let others = menu.addItem(withTitle: L("ほかを隠す"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
    others.keyEquivalentModifierMask = [.command, .option]
    menu.addItem(withTitle: L("すべてを表示"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(withTitle: L("%@を終了", String(describing: name)), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
}

// Bundle identity, rather than the bundle path or build number, defines one app.
@MainActor
private enum SingleInstanceLaunch {
    static func enforce() {
        let current = NSRunningApplication.current
        guard let identifier = Bundle.main.bundleIdentifier else { return }
        var candidates = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .filter { !$0.isTerminated }
        if !candidates.contains(where: { $0.processIdentifier == current.processIdentifier }) {
            candidates.append(current)
        }
        candidates.sort {
            let left = $0.launchDate ?? .distantPast
            let right = $1.launchDate ?? .distantPast
            return left == right ? $0.processIdentifier < $1.processIdentifier : left < right
        }
        guard let existing = candidates.first,
              existing.processIdentifier != current.processIdentifier else { return }
        existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        if let url = existing.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
                exit(0)
            }
            // Allow the reopen Apple event to reach hidden/menu-bar applications.
            RunLoop.main.run(until: Date().addingTimeInterval(2))
        }
        exit(0)
    }
}


// Main-window header uses the same icon resource as the distributed app.
private func currentAppIcon() -> NSImage {
    let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String ?? "AppIcon"
    let filename = name.hasSuffix(".icns") ? name : name + ".icns"
    if let url = Bundle.main.resourceURL?.appendingPathComponent(filename),
       let image = NSImage(contentsOf: url) { return image }
    return NSApp.applicationIconImage
}
private func appHeader(_ title: String, subtitle: String = "", size: CGFloat = 44) -> NSStackView {
    let icon = NSImageView(image: currentAppIcon())
    icon.imageScaling = .scaleProportionallyUpOrDown
    icon.setAccessibilityElement(false)
    icon.widthAnchor.constraint(equalToConstant: size).isActive = true
    icon.heightAnchor.constraint(equalToConstant: size).isActive = true
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: size == 44 ? 20 : 15, weight: .semibold)
    let detail = NSTextField(wrappingLabelWithString: subtitle)
    detail.font = .systemFont(ofSize: size == 44 ? 12 : 11)
    detail.textColor = .secondaryLabelColor
    let text = NSStackView(views: subtitle.isEmpty ? [label] : [label, detail])
    text.orientation = .vertical; text.alignment = .leading; text.spacing = 4
    let row = NSStackView(views: [icon, text])
    row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 12
    return row
}
