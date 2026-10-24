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
        image.accessibilityDescription = L("PodiumAssist — セミナー準備")
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
    private let switchHider = AppSwitchHider()
    private let presets = PresetStore()
    private var timer: Timer?
    private var refreshTimer: Timer?
    private var observers = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        Self.refreshLoginItemAfterRename()
        ExcludedApps.shared.configure(explanation: L("対象外アプリへの切り替え時は何も隠さず、対象外アプリ自体も隠しません。"))
        switchHider.start()
        SettingsSync.shared.onImport = { [weak self] in
            self?.presets.reload()
            self?.settings.reloadSwitchHiding()
        }
        SettingsSync.shared.start(.init(keys: PresetStore.syncedKeys, note: L("syncNote"), perMac: L("syncPerMac"),
                                        merge: PresetStore.merged))
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
        if !loginLaunch && !StartupWindow.suppressInitialWindow { DispatchQueue.main.async { self.showControls() } }
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
        // Basic settings scroll within a bounded window; the header and footer stay visible.
        let size = NSSize(width: 480, height: 620)
        let minimum = NSSize(width: 440, height: 360)
        // Miniaturizable so the yellow button and Window > Minimize (no key equivalent) work; full screen stays off.
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = L("セミナー準備")
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.collectionBehavior.insert(.fullScreenNone)
        window.isReleasedWhenClosed = false
        let host = NSHostingController(rootView:
            MainView(countdown: countdown, settings: settings, presets: presets,
                     openPreferences: { [weak self] in self?.showPreferences() })
                .frame(minWidth: minimum.width, maxWidth: .infinity, minHeight: minimum.height, maxHeight: .infinity)
                .background(Color(nsColor: AppSurface.color), ignoresSafeAreaEdges: []))
        // Allow shrinking below the initial size; scrollable content absorbs the height change.
        host.sizingOptions = [.minSize]
        host.preferredContentSize = size
        window.contentViewController = host
        window.setContentSize(size)
        window.contentMinSize = minimum
        restoreFrame(of: window, name: "TokiMainWindow", minimum: minimum)
        controlsWindow = window
        NotificationCenter.default.addObserver(self, selector: #selector(windowOcclusionChanged), name: NSWindow.didChangeOcclusionStateNotification, object: window)
    }

    /// Settings open in their own window, next to the main window.
    private func preparePreferencesWindow() {
        guard preferencesWindow == nil else { return }
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "mergedAppsSettingsTabV3314") {
            let key = "shared.settings.selectedTabIndex"
            let previous = defaults.integer(forKey: key)
            if previous >= 2 { defaults.set(previous - 1, forKey: key) }
            defaults.set(true, forKey: "mergedAppsSettingsTabV3314")
        }
        let size = NSSize(width: 460, height: 560)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = L("設定")
        window.standardWindowButton(.zoomButton)?.isEnabled = true
        window.collectionBehavior.insert(.fullScreenNone)
        window.isReleasedWhenClosed = false
        let host = NSHostingController(rootView:
            PreferencesView(countdown: countdown, settings: settings, presets: presets)
                .frame(minWidth: size.width, maxWidth: .infinity, minHeight: 360, maxHeight: .infinity))
        host.sizingOptions = []
        host.preferredContentSize = size
        window.contentViewController = host
        window.setContentSize(size)
        window.contentMinSize = NSSize(width: 460, height: 360)
        restoreFrame(of: window, name: "TokiPreferencesWindow", minimum: window.contentMinSize)
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
        StartupWindow.userRequestedWindow()
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
    @Published var plan: TimerPlan
    @Published var running: TimerPlan?
    @Published var remaining = L("停止中")
    @Published var error = ""

    init() {
        let prefs = UserDefaults.standard
        plan = (prefs.data(forKey: "timerPlan").flatMap { try? JSONDecoder().decode(TimerPlan.self, from: $0) })
            ?? TimerPlan(start: Self.minuteNow, minutes: 30)
        running = prefs.data(forKey: "runningTimerPlan").flatMap { try? JSONDecoder().decode(TimerPlan.self, from: $0) }
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
    var zoomHotkeys: Bool? = nil
    /// ZoomSettings.Style raw value.
    var zoomStyle: Int? = nil
    var zoomMaxFactor: Double? = nil
    var zoomToggleShortcut: String? = nil
    var zoomInShortcut: String? = nil
    var resolution: DisplayResolution? = nil
    var hideDesktop: Bool? = nil
    var hideOthersOnSwitch: Bool? = nil
    var hideOthersDelay: Double? = nil
    var notificationsOff: Bool? = nil
    /// Legacy timer data is retained but never applied or captured by presets.
    var timerMinutes: Int? = nil
    var timerEnabled: Bool? = nil
    var quitApps: Bool? = nil
    var launchApps: [QuitAppTarget]? = nil
    var quitAppTargets: [QuitAppTarget]? = nil

    static var macOSDefault: Preset {
        var preset = Preset()
        preset.id = UUID(uuidString: "1747A067-47DA-4D61-91C3-9B5BA03D1311")!
        preset.name = L("macOSのデフォルト")
        preset.clock = false
        preset.showDate = true
        preset.showWeekday = true
        preset.dark = false
        preset.hideDock = false
        preset.killDock = false
        preset.hideDesktop = false
        preset.hideOthersOnSwitch = false
        preset.hideOthersDelay = 0
        preset.pointerSize = 1
        preset.resolution = .displayDefault
        preset.reduceTransparency = false
        preset.reduceMotion = false
        preset.volumeFeedback = false
        preset.zoomHotkeys = false
        preset.zoomStyle = ZoomSettings.Style.fullScreen.rawValue
        preset.zoomMaxFactor = 20
        preset.zoomToggleShortcut = ZoomSettings.toggleShortcut.defaultValue
        preset.zoomInShortcut = ZoomSettings.zoomInShortcut.defaultValue
        preset.notificationsOff = false
        preset.launchApps = []
        preset.quitAppTargets = []
        return preset
    }

    static var fullSet: Preset {
        var preset = macOSDefault
        preset.id = UUID(uuidString: "1747A067-47DA-4D61-91C3-9B5BA03D1312")!
        preset.name = L("フルセット")
        preset.clock = true
        preset.showDate = false
        preset.showWeekday = false
        preset.hideDock = true
        preset.hideDesktop = true
        preset.pointerSize = 2
        preset.reduceTransparency = true
        preset.reduceMotion = true
        preset.zoomHotkeys = true
        preset.zoomToggleShortcut = "122,8388608"
        preset.zoomInShortcut = "120,8388608"
        preset.notificationsOff = true
        return preset
    }

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
        installBuiltInPresets()
    }
    /// Seed once per Mac. Deletion and edits are respected on later launches.
    private func installBuiltInPresets() {
        let key = "builtInPresetsV1Installed"
        guard !defaults.bool(forKey: key) else { return }
        for preset in [Preset.macOSDefault, Preset.fullSet] {
            if !items.contains(where: { $0.id == preset.id || $0.name == preset.name }) { items.append(preset) }
        }
        persist()
        defaults.set(true, forKey: key)
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
    /// UserDefaults keys exported and synced by 設定の共有; the rest (timer plan, window tab, last applied preset) stays per Mac.
    static let syncedKeys: Set<String> = ["presets", "hideOthersOnSwitch", "hideOthersDelay"]
    /// 「追加する」 in 設定の共有: presets whose id is not in the list yet are appended; this Mac's other values stay.
    static func merged(_ file: NSDictionary, _ current: NSDictionary) -> (values: NSDictionary, added: Int) {
        let decode = { (value: Any?) in (value as? Data).flatMap { try? JSONDecoder().decode([Preset].self, from: $0) } ?? [] }
        let mine = decode(current["presets"])
        let ids = Set(mine.map(\.id))
        let added = decode(file["presets"]).filter { !ids.contains($0.id) }
        let values = NSMutableDictionary(dictionary: file)
        values.addEntries(from: current as? [AnyHashable: Any] ?? [:])
        values["presets"] = try? JSONEncoder().encode(mine + added)
        return (values, added.count)
    }
    /// Re-reads the list after SettingsSync applied another Mac's presets.
    func reload() {
        items = defaults.data(forKey: "presets").flatMap { try? JSONDecoder().decode([Preset].self, from: $0) } ?? []
    }
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
                VStack(spacing: 4) {
                    Image(nsImage: currentAppIcon()).resizable().scaledToFit()
                        .frame(width: 44, height: 44).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("セミナー準備")).font(.system(size: 20, weight: .bold))
                    Text(L("プリセットとタイマーで、まとめて準備。")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            // In-window tabs: a SwiftUI TabView would move into the native title bar.
            MainWindowTabs(selection: $tab)
                .fixedSize().frame(maxWidth: .infinity)
            Group {
                if let section = ManualControlsView.Section(rawValue: tab) {
                    ManualControlsView(settings: settings, countdown: countdown, presets: presets, section: section).padding(16)
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
        .onAppear { if tab == 3 { tab = 2 } }
    }
}

/// Native segmented tabs with a label-sized width and equal padding for every segment.
struct MainWindowTabs: NSViewRepresentable {
    @Binding var selection: Int
    private let items: [(title: String, tag: Int)] = [
        ("プリセット", 0), ("基本", 2), ("表示", 4), ("ズーム", 5), ("タイマー", 6)
    ]

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: items.map { L($0.title) }, trackingMode: .selectOne,
                                         target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        control.segmentStyle = .rounded
        control.segmentDistribution = .fit
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        control.font = font
        for (index, item) in items.enumerated() {
            control.setTag(item.tag, forSegment: index)
            let textWidth = (L(item.title) as NSString).size(withAttributes: [.font: font]).width
            control.setWidth(ceil(textWidth) + 24, forSegment: index)
        }
        control.setAccessibilityLabel(L("セミナー準備"))
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        control.selectedSegment = items.firstIndex { $0.tag == selection } ?? 0
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject {
        var parent: MainWindowTabs
        init(_ parent: MainWindowTabs) { self.parent = parent }
        @objc func changed(_ sender: NSSegmentedControl) {
            guard sender.selectedSegment >= 0 else { return }
            parent.selection = sender.tag(forSegment: sender.selectedSegment)
        }
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
    @State private var confirmingPreset: Preset?

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
        .sheet(item: $confirmingPreset) { preset in
            PresetAppConfirmation(preset: preset, cancel: { confirmingPreset = nil }) { selected in
                confirmingPreset = nil
                applyPreset(selected)
            }
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

    private func applyPreset(_ preset: Preset) {
        lastApplied = preset.id.uuidString
        presets.remember(preset.id)
        settings.apply(preset, countdown: countdown)
    }

    private func presetButton(_ preset: Preset) -> some View {
        let selected = preset.id.uuidString == lastApplied
        let index = presets.items.firstIndex { $0.id == preset.id } ?? 0
        return Button {
            if (preset.launchApps ?? []).isEmpty && (preset.quitAppTargets ?? []).isEmpty {
                applyPreset(preset)
            } else {
                confirmingPreset = preset
            }
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 22)).frame(width: 32)
                    Text(preset.name).font(.system(size: 15, weight: .medium)).lineLimit(1)
                    Spacer()
                    if selected { Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold)) }
                }
                HStack(alignment: .top, spacing: 12) {
                    appListSummary(preset.launchApps ?? [], launch: true)
                    appListSummary(preset.quitAppTargets ?? [], launch: false)
                }
                .foregroundStyle(selected ? Color.white.opacity(0.9) : Color.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(selected ? Color.accentColor : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(selected ? 0 : 0.12)))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? L("選択中") : L("未選択"))
        .overlay(PresetSecondaryClickMenu(items: [
            .init(title: L("名前を変更…"), action: { newName = preset.name; renaming = preset }),
            .separator,
            .init(title: L("上へ移動"), enabled: index > 0, action: { presets.move(preset.id, by: -1) }),
            .init(title: L("下へ移動"), enabled: index < presets.items.count - 1, action: { presets.move(preset.id, by: 1) }),
            .separator,
            .init(title: L("起動アプリを編集…") + " (\(preset.launchApps?.count ?? 0))", action: { editingApps = (preset, true) }),
            .init(title: L("終了アプリを編集…") + " (\(preset.quitAppTargets?.count ?? 0))", action: { editingApps = (preset, false) }),
            .separator,
            .init(title: L("削除…"), action: { deleting = preset })
        ]))
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

    private func appListSummary(_ targets: [QuitAppTarget], launch: Bool) -> some View {
        HStack(spacing: 4) {
            Text(L(launch ? "起動" : "終了")).fontWeight(.medium)
            if targets.isEmpty { Text("—") }
            ForEach(Array(targets.prefix(2))) { target in
                Image(nsImage: NSWorkspace.shared.icon(forFile: target.path))
                    .resizable().frame(width: 12, height: 12)
                    .accessibilityHidden(true)
                Text(target.name).lineLimit(1).truncationMode(.tail)
            }
            if targets.count > 2 { Text("+\(targets.count - 2)").fixedSize() }
            Spacer(minLength: 0)
        }
        .font(.system(size: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L(launch ? "起動アプリを編集…" : "終了アプリを編集…") + ": " + targets.map(\.name).joined(separator: ", "))
        .help(targets.map(\.name).joined(separator: ", "))
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
            Button(L("オートメーション設定を開く")) { MacSettings.openAutomationSettings() }
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
                AccessibilitySection()
            })),
            (L("アプリ"), AnyView(VStack(alignment: .leading, spacing: 20) {
                SettingsSection(L("プリセットのアプリ")) { PresetAppsSettings(presets: presets) }
                SettingsSection(ExcludedApps.title) { ExcludedAppsView() }
            })),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ]).padding(12)
    }
}

struct TimerPanel: View {
    @ObservedObject var countdown: Countdown
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    countdown.plan.start = Self.quickStart(countdown.plan.start, now: Date(), today: true, currentTime: NSEvent.modifierFlags.contains(.option)); countdown.savePlan()
                }
                Button(L("現在時刻にする")) {
                    countdown.plan.start = Self.quickStart(countdown.plan.start, now: Date(), today: NSEvent.modifierFlags.contains(.option), currentTime: true); countdown.savePlan()
                }
                Button(L("次の正時にする")) {
                    countdown.plan.start = Self.nextHour(after: Date()); countdown.savePlan()
                }
            }
            .help(L("Option＋クリックで今日の日付と現在時刻を両方適用します。"))
            if !countdown.error.isEmpty { Text(countdown.error).foregroundStyle(.red).font(.caption) }
            HStack {
                Text(countdown.remaining).monospacedDigit()
                Spacer()
                Button(L("停止")) { countdown.stop() }.disabled(countdown.end == nil)
                Button(countdown.end == nil ? L("開始／予約") : L("設定を反映して再開")) { countdown.start() }.buttonStyle(.borderedProminent)
            }
        }.font(.system(size: 12))
        .help(L("開始時間 ＋ 所要時間 ＝ 終了時間。開始時間・所要時間の変更で終了時間を更新。終了時間の変更で所要時間を更新します。開始前は「開始まで」、開始後は残り時間をメニューバーに表示します。終了後は00:00で止まります。"))
    }

    /// Date and time in separate fields; each keeps the other's part of the value.
    private func dateTimeRow(_ title: String, value: Date, set: @escaping (Date) -> Void) -> some View {
        HStack {
            Text(title)
            // SwiftUI's DatePicker keeps NSDatePicker's own width, which clips the last digit; a frame does not widen it.
            WideDatePicker(title: title, date: Binding(get: { value }, set: { set(Self.combine(day: $0, time: value)) }),
                           elements: .yearMonthDay, width: 150)
                .frame(width: 150)
            WideDatePicker(title: title, date: Binding(get: { value }, set: { set(Self.combine(day: value, time: $0)) }),
                           elements: .hourMinute, width: 96)
                .frame(width: 96)
            Spacer(minLength: 0)
        }
    }

    static func quickStart(_ start: Date, now: Date, today: Bool, currentTime: Bool) -> Date {
        combine(day: today ? now : start, time: currentTime ? now : start)
    }

    static func nextHour(after now: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .hour, for: now)?.end ?? now.addingTimeInterval(3600)
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
        picker.font = .systemFont(ofSize: 12)
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
    @Published var hideOthersOnSwitch = UserDefaults.standard.bool(forKey: "hideOthersOnSwitch") {
        didSet { UserDefaults.standard.set(hideOthersOnSwitch, forKey: "hideOthersOnSwitch") }
    }
    @Published var hideOthersDelay = AppSwitchHider.delay(UserDefaults.standard.double(forKey: "hideOthersDelay")) {
        didSet { UserDefaults.standard.set(AppSwitchHider.delay(hideOthersDelay), forKey: "hideOthersDelay") }
    }
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
    @Published var zoomHotkeys = false
    @Published var zoomStyle = ZoomSettings.Style.fullScreen
    @Published var zoomMaxFactor: Double?
    @Published var zoomToggleShortcut = ZoomSettings.toggleShortcut.defaultValue
    @Published var zoomInShortcut = ZoomSettings.zoomInShortcut.defaultValue
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

    func reloadSwitchHiding() {
        hideOthersOnSwitch = UserDefaults.standard.bool(forKey: "hideOthersOnSwitch")
        hideOthersDelay = AppSwitchHider.delay(UserDefaults.standard.double(forKey: "hideOthersDelay"))
    }

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
        zoomHotkeys = ZoomSettings.hotkeysEnabled
        zoomStyle = ZoomSettings.style
        zoomMaxFactor = ZoomSettings.maxFactor
        zoomToggleShortcut = ZoomSettings.current(ZoomSettings.toggleShortcut)
        zoomInShortcut = ZoomSettings.current(ZoomSettings.zoomInShortcut)
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
        inSystemSettings(working: working, done: done, then: then) {
            try await SystemSettingsSwitch.set(pane: target.pane, identifier: target.identifier, to: value)
        }
    }

    /// Runs a change that operates System Settings, showing `working` meanwhile. `then` runs afterwards on success.
    private func inSystemSettings(working: String, done: String, then: (() -> Void)?, _ change: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        error = false
        message = working
        Task {
            do {
                try await change()
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

    /// Zoom items that live in System Settings; nil leaves an item as it is.
    func setZoom(hotkeys: Bool? = nil, style: ZoomSettings.Style? = nil, maxFactor: Double? = nil, then: (() -> Void)? = nil) {
        let done: String
        if let hotkeys {
            done = hotkeys ? L("キーボードショートカットでの拡大・縮小をオンにしました。") : L("キーボードショートカットでの拡大・縮小をオフにしました。")
        } else if let style, maxFactor == nil {
            done = L("ズーム方法を「%@」にしました。", style.title)
        } else if let maxFactor, style == nil {
            done = L("最大拡大率を%@にしました。", ZoomSettings.text(maxFactor))
        } else {
            done = L("ズーム機能の設定を変更しました。")
        }
        inSystemSettings(working: L("システム設定でズーム機能を変更しています…"), done: done, then: then) {
            try await ZoomSettings.apply(hotkeys: hotkeys, style: style, maxFactor: maxFactor)
        }
    }

    func setZoomShortcut(_ shortcut: ZoomSettings.Shortcut, to value: String) {
        if ZoomSettings.setShortcut(shortcut, to: value) {
            error = false
            message = L("ショートカットを変更しました。")
        } else {
            error = true
            message = L("ショートカットを変更できませんでした。")
        }
        refresh()
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
        if let value = preset.zoomToggleShortcut, value != zoomToggleShortcut { setZoomShortcut(ZoomSettings.toggleShortcut, to: value); if error { return } }
        if let value = preset.zoomInShortcut, value != zoomInShortcut { setZoomShortcut(ZoomSettings.zoomInShortcut, to: value); if error { return } }
        if let value = preset.hideOthersDelay { hideOthersDelay = AppSwitchHider.delay(value) }
        if let value = preset.hideOthersOnSwitch { hideOthersOnSwitch = value }
        // Timer state is independent of presets, including legacy timer fields.
        if let apps = preset.quitAppTargets { QuitAppsStore.shared.quit(apps, excluding: Set((preset.launchApps ?? []).map(\.id))) }
        if let apps = preset.launchApps { LaunchAppsStore.shared.launch(apps) }
        // Transparency and notifications both run asynchronously; notifications wait for the System Settings step.
        let finish = { [self] in
            if let value = preset.notificationsOff { setNotificationsOff(value) }
            else { message = L("「%@」を適用しました。", String(describing: preset.name)) }
        }
        // System Settings steps run one after another (each opens the pane), then notifications.
        let zoom = { [self] in
            let hotkeys = preset.zoomHotkeys.flatMap { $0 != zoomHotkeys ? $0 : nil }
            let style = preset.zoomStyle.flatMap(ZoomSettings.Style.init(rawValue:)).flatMap { $0 != zoomStyle ? $0 : nil }
            let maxFactor = preset.zoomMaxFactor.flatMap { value in zoomMaxFactor.map { abs($0 - value) < 0.05 } == true ? nil : value }
            if hotkeys != nil || style != nil || maxFactor != nil {
                setZoom(hotkeys: hotkeys, style: style, maxFactor: maxFactor, then: finish)
            } else { finish() }
        }
        let motion = { [self] in
            if let value = preset.reduceMotion, value != reduceMotion { setReduceMotion(value, then: zoom) } else { zoom() }
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

/// Main window manual setting tabs: switch each Mac setting directly (presets switch several at once).
struct ManualControlsView: View {
    @ObservedObject var settings: MacSettings
    @ObservedObject var countdown: Countdown
    @ObservedObject var presets: PresetStore
    // Preserve the existing Basic and Zoom tab identifiers.
    enum Section: Int, CaseIterable {
        case basic = 2, display = 4, zoom = 5, timer = 6
    }
    let section: Section
    @State private var saving = false
    /// The preset ✓ means "applied last"; a manual change makes that stale, so it is cleared.
    @AppStorage("lastAppliedPreset") private var lastApplied = ""
    @State private var pointerDraft = 1.0
    @State private var zoomDraft = 10.0
    /// Only widens the 解像度 menu; nothing on the Mac changes.
    @AppStorage("showAllResolutions") private var showAllResolutions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if section == .basic {
                        category(L("メニューバー")) {
                            basicChoiceRow(L("時計"), symbol: "clock", value: settings.analog,
                                           off: L("デジタル"), on: L("アナログ")) { settings.setClock($0) }
                            basicChoiceRow(L("日付"), symbol: "calendar", value: settings.showDate,
                                           off: L("しない"), on: L("表示する"), trueFirst: true) { settings.setDateVisible($0) }
                                .disabled(settings.analog).opacity(settings.analog ? 0.4 : 1)
                                .help(L("デジタル時計用"))
                            basicChoiceRow(L("曜日"), symbol: "calendar.day.timeline.left", value: settings.showWeekday,
                                           off: L("しない"), on: L("表示する"), trueFirst: true) { settings.setWeekdayVisible($0) }
                                .disabled(settings.analog).opacity(settings.analog ? 0.4 : 1)
                                .help(L("デジタル時計用"))
                        }
                        .disabled(settings.busy)
                    }
                    if section == .display {
                        category(L("Mac全体")) {
                            basicChoiceRow(L("外観"), symbol: "circle.lefthalf.filled", value: settings.dark,
                                           off: L("ライト"), on: L("ダーク")) { settings.setAppearance($0) }
                        }
                        .disabled(settings.busy)
                    }
                    if section == .display {
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
                    }
                    if section == .display {
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
                                Button(L("初期値に戻す")) { pointerDraft = 1; manual { settings.setPointerSize(1) } }
                                    .disabled(settings.pointerSize == 1)
                            }
                            .font(.system(size: 12))
                            .onAppear { pointerDraft = settings.pointerSize }
                            .onChange(of: settings.pointerSize) { pointerDraft = $0 }
                        }
                    }
                    if section == .zoom {
                        category(L("キーボードショートカット")) {
                            Toggle(L("キーボードショートカットを使って拡大・縮小"), isOn: Binding(get: { settings.zoomHotkeys }, set: { value in manual { settings.setZoom(hotkeys: value) } }))
                                .font(.system(size: 12)).disabled(settings.busy)
                            zoomShortcutRow(L("ショートカット：ズーム機能のオン／オフ"), ZoomSettings.toggleShortcut, settings.zoomToggleShortcut)
                            zoomShortcutRow(L("ショートカット：拡大"), ZoomSettings.zoomInShortcut, settings.zoomInShortcut)
                        }
                        category(L("オプション")) {
                            HStack {
                                Label(L("ズーム方法"), systemImage: "plus.magnifyingglass").fixedSize()
                                Spacer()
                                Picker(L("ズーム方法"), selection: Binding(get: { settings.zoomStyle }, set: { value in manual { settings.setZoom(style: value) } })) {
                                    ForEach(ZoomSettings.Style.menuOrder, id: \.self) { Text($0.title).tag($0) }
                                }
                                .labelsHidden().pickerStyle(.radioGroup).fixedSize()
                            }
                            .font(.system(size: 12)).disabled(settings.busy)
                            HStack {
                                Label(L("最大拡大率"), systemImage: "arrow.up.left.and.arrow.down.right").fixedSize()
                                Spacer()
                                // Applied when the knob is released: System Settings is operated once per change.
                                Slider(value: $zoomDraft, in: ZoomSettings.maxFactorRange, step: 0.5) { editing in
                                    if !editing { manual { settings.setZoom(maxFactor: zoomDraft) } }
                                }
                                .frame(width: 140)
                                Text(ZoomSettings.text(zoomDraft)).monospacedDigit().frame(width: 32, alignment: .trailing)
                            }
                            .font(.system(size: 12)).disabled(settings.busy)
                            .help(L("システム設定の「詳細…」のスライダーを動かします。変更中はポインタが一瞬動きます。"))
                            .onAppear { zoomDraft = settings.zoomMaxFactor ?? zoomDraft }
                            .onChange(of: settings.zoomMaxFactor) { if let value = $0 { zoomDraft = value } }
                        }
                    }
                    if section == .basic {
                        category(L("集中を妨げるもの")) {
                            HStack(spacing: 8) {
                                Toggle(L("アプリ切り替え時にほかを隠す"), isOn: $settings.hideOthersOnSwitch)
                                Spacer(minLength: 4)
                                TextField("0", value: Binding(get: { settings.hideOthersDelay }, set: { settings.hideOthersDelay = AppSwitchHider.delay($0) }), format: .number)
                                    .frame(width: 48)
                                    .accessibilityLabel(L("ほかを隠すまでの秒数"))
                                    .disabled(!settings.hideOthersOnSwitch)
                                Text(L("秒後"))
                            }.font(.system(size: 12))
                            Toggle(L("音量を変更するときにフィードバックを再生しない"), isOn: Binding(get: { !settings.volumeFeedback }, set: { value in manual { settings.setVolumeFeedback(!value) } }))
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
                    }
                    if section == .timer {
                        TimerPanel(countdown: countdown)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 4)
            }
            // The message sits beside the button, so its fixed two-line height adds no empty row.
            HStack(spacing: 12) {
                StatusMessage(settings: settings)
                // Click: overwrite the preset applied (or saved) last, with the items it already has.
                // Option-click, or no such preset yet: the sheet to choose the preset and items. No "…" when no sheet opens.
                if section != .timer {
                Button(presets.rememberedPreset.map { L("プリセット（%@）に保存", $0.name) } ?? L("プリセットに保存…")) {
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

    /// A zoom shortcut menu; a value set elsewhere that is not among the choices is listed as it is.
    private func zoomShortcutRow(_ title: String, _ shortcut: ZoomSettings.Shortcut, _ current: String) -> some View {
        HStack {
            Label(title, systemImage: "keyboard").fixedSize()
            Spacer()
            Picker(title, selection: Binding(get: { current }, set: { value in manual { settings.setZoomShortcut(shortcut, to: value) } })) {
                ForEach(shortcut.choices, id: \.value) { Text($0.title).tag($0.value) }
                if current != "off", !shortcut.choices.contains(where: { $0.value == current }) {
                    Text(L("その他")).tag(current)
                }
                Divider()
                Text(L("オフ")).tag("off")
            }
            .labelsHidden().frame(width: 100)
        }
        .font(.system(size: 12)).disabled(settings.busy)
    }

    /// A titled group on a manual setting tab.
    private func category<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func basicChoiceRow(_ title: String, symbol: String, value: Bool,
                                off: String, on: String, trueFirst: Bool = false,
                                set: @escaping (Bool) -> Void) -> some View {
        HStack {
            Label(title, systemImage: symbol).fixedSize()
            Spacer()
            Picker(title, selection: Binding(get: { value }, set: { value in manual { set(value) } })) {
                if trueFirst {
                    Text(on).tag(true)
                    Text(off).tag(false)
                } else {
                    Text(off).tag(false)
                    Text(on).tag(true)
                }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
        }
        .font(.system(size: 12))
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
/// Shown under the header icon: version, then build in parentheses (「1.4.5」「（15）」).
private func appVersionText() -> String {
    let info = Bundle.main.infoDictionary ?? [:]
    let version = info["CFBundleShortVersionString"] as? String ?? ""
    guard let build = info["CFBundleVersion"] as? String, !build.isEmpty, build != version else { return version }
    let japanese = Bundle.main.preferredLocalizations.first?.hasPrefix("ja") ?? false
    return version + "\n" + (japanese ? "（\(build)）" : "(\(build))")
}
private func appVersionLabel() -> NSTextField {
    let label = NSTextField(labelWithString: appVersionText())
    label.font = .systemFont(ofSize: 10)
    label.textColor = .secondaryLabelColor
    label.alignment = .center
    label.maximumNumberOfLines = 2
    return label
}
/// Placed under the header icon.
private struct AppVersionLabel: View {
    var body: some View {
        Text(appVersionText()).font(.system(size: 10)).foregroundStyle(.secondary)
            .multilineTextAlignment(.center).fixedSize()
    }
}
private func appHeader(_ title: String, subtitle: String = "", size: CGFloat = 44, showsVersion: Bool = true) -> NSStackView {
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
    let iconColumn = NSStackView(views: showsVersion ? [icon, appVersionLabel()] : [icon])
    iconColumn.orientation = .vertical; iconColumn.alignment = .centerX; iconColumn.spacing = 4
    let row = NSStackView(views: [iconColumn, text])
    row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 12
    return row
}

/// Only intercepts secondary clicks; ordinary clicks continue to SwiftUI's preset button.
struct PresetSecondaryClickMenu: NSViewRepresentable {
    let items: [Item]
    struct Item {
        var title: String
        var enabled = true
        var action: (() -> Void)?
        static var separator: Item { Item(title: "", action: nil) }
    }
    final class MenuAction: NSObject {
        let perform: () -> Void
        init(_ perform: @escaping () -> Void) { self.perform = perform }
        @objc func invoke(_ sender: Any?) { perform() }
    }
    final class Surface: NSView {
        var items: [Item] = []
        private var actions: [MenuAction] = []
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent,
                  event.type == .rightMouseDown || event.type == .rightMouseUp ||
                  (event.type == .leftMouseDown && event.modifierFlags.contains(.control)) else { return nil }
            return super.hitTest(point)
        }
        private func showMenu(_ event: NSEvent) {
            let menu = NSMenu()
            menu.autoenablesItems = false
            actions = []
            for entry in items {
                guard let action = entry.action else { menu.addItem(.separator()); continue }
                let handler = MenuAction(action)
                actions.append(handler)
                let item = NSMenuItem(title: entry.title, action: #selector(MenuAction.invoke(_:)), keyEquivalent: "")
                item.target = handler
                item.isEnabled = entry.enabled
                menu.addItem(item)
            }
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
        override func rightMouseDown(with event: NSEvent) { showMenu(event) }
        override func mouseDown(with event: NSEvent) {
            if event.modifierFlags.contains(.control) { showMenu(event) }
            else { super.mouseDown(with: event) }
        }
    }
    func makeNSView(context: Context) -> Surface {
        let view = Surface()
        view.setAccessibilityElement(false)
        view.items = items
        return view
    }
    func updateNSView(_ view: Surface, context: Context) { view.items = items }
}
