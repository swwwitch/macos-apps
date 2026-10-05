import SwiftUI
import AppKit
import Combine

enum TokiMenuIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            draw(color: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = L("PodiumFlight — セミナー・キャプチャ準備")
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
    private let countdown = Countdown()
    private let settings = MacSettings()
    private let presets = PresetStore()
    private var timer: Timer?
    private let navigation = SettingsNavigation()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("PodiumFlightについて"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let preferences = appMenu.addItem(withTitle: L("環境設定…"), action: #selector(showPreferences), keyEquivalent: ",")
        preferences.target = self
        appMenu.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to: appMenu)
        #endif
        addStandardApplicationCommands(to: appMenu, name: "PodiumFlight")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let fileRoot = NSMenuItem(title: L("ファイル"), action: nil, keyEquivalent: "")
        let file = NSMenu(title: L("ファイル")); fileRoot.submenu = file; menu.addItem(fileRoot)
        file.addItem(withTitle: L("ウインドウを閉じる"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let edit = NSMenu(title: L("編集"))
        edit.addItem(withTitle: L("切り取り"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("コピー"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("ペースト"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("すべてを選択"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        editItem.submenu = edit
        menu.addItem(editItem)
        NSApp.mainMenu = menu
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = TokiMenuIcon.make()
            button.image?.isTemplate = true
            button.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover)
        }
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        DispatchQueue.main.async { self.showControls() }
    }

    private func tick() {
        countdown.tick()
        item.button?.title = countdown.end == nil ? "" : " " + countdown.remaining
        item.button?.toolTip = countdown.end == nil ? L("PodiumFlight — Macの表示設定") : L("残り ") + countdown.remaining
    }

    @objc private func togglePopover() {
        revealWindow()
    }

    private func prepareWindow() {
        guard controlsWindow == nil else { return }
        let size = NSSize(width: 420, height: 750)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L("セミナー・キャプチャ準備")
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.collectionBehavior.insert(.fullScreenNone)
        window.isReleasedWhenClosed = false
        let host = NSHostingController(rootView:
            SettingsRoot(navigation: navigation, countdown: countdown, settings: settings, presets: presets,
                         openPreferences: { [weak self] in self?.showPreferences() }, goBack: { [weak self] in self?.showControls() })
                .frame(width: 420, height: 750))
        host.sizingOptions = []
        host.preferredContentSize = size
        host.view.setFrameSize(size)
        window.contentViewController = host
        window.setContentSize(size)
        window.contentMinSize = size
        window.contentMaxSize = size
        window.setFrameAutosaveName("TokiUnifiedSettings")
        let restored = window.setFrameUsingName("TokiUnifiedSettings")
        let invalidFrame = window.frame.width < size.width || window.frame.height < size.height
        window.setContentSize(size)
        if !restored || invalidFrame { window.center() }
        controlsWindow = window
    }

    private func revealWindow() {
        prepareWindow()
        NSApp.activate(ignoringOtherApps: true)
        if controlsWindow?.isMiniaturized == true { controlsWindow?.deminiaturize(nil) }
        controlsWindow?.makeKeyAndOrderFront(nil)
    }

    private func showControls() {
        prepareWindow()
        navigation.preferencesShown = false
        controlsWindow?.title = L("セミナー・キャプチャ準備")
        settings.refresh()
        revealWindow()
    }

    @objc private func showPreferences() {
        prepareWindow()
        navigation.preferencesShown = true
        controlsWindow?.title = L("環境設定")
        revealWindow()
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
    var hideDesktop: Bool? = nil
    var notificationsOff: Bool? = nil
    var timerMinutes: Int? = nil
    var timerEnabled: Bool? = nil
}

@MainActor
final class PresetStore: ObservableObject {
    @Published var items: [Preset] = []
    init() {
        if let data = UserDefaults.standard.data(forKey: "presets"), let saved = try? JSONDecoder().decode([Preset].self, from: data) { items = saved }
    }
    func save(_ preset: Preset) {
        if let i = items.firstIndex(where: { $0.id == preset.id }) { items[i] = preset } else { items.append(preset) }
        persist()
    }
    func remove(_ id: UUID) { items.removeAll { $0.id == id }; persist() }
    private func persist() {
        if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: "presets") }
    }
}

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var preferencesShown = false
}

struct SettingsRoot: View {
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject var countdown: Countdown
    @ObservedObject var settings: MacSettings
    @ObservedObject var presets: PresetStore
    let openPreferences: () -> Void
    let goBack: () -> Void
    var body: some View {
        ZStack {
            SettingsView(settings: settings, countdown: countdown, presets: presets, openPreferences: openPreferences)
                .frame(width: 420, height: 700)
                .opacity(navigation.preferencesShown ? 0 : 1)
                .allowsHitTesting(!navigation.preferencesShown)
                .accessibilityHidden(navigation.preferencesShown)
            PreferencesContainer(countdown: countdown, settings: settings, presets: presets, goBack: goBack)
                .frame(width: 420, height: 750)
                .opacity(navigation.preferencesShown ? 1 : 0)
                .allowsHitTesting(navigation.preferencesShown)
                .accessibilityHidden(!navigation.preferencesShown)
        }.frame(width: 420, height: 750)
    }
}

struct PreferencesContainer: View {
    @ObservedObject var countdown: Countdown
    @ObservedObject var settings: MacSettings
    @ObservedObject var presets: PresetStore
    let goBack: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: goBack) { Label(L("設定一覧に戻る"), systemImage: "chevron.left") }
                Spacer()
            }.padding(.horizontal, 20).padding(.top, 14)
            PreferencesView(countdown: countdown, settings: settings, presets: presets)
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var countdown: Countdown
    @ObservedObject var settings: MacSettings
    @ObservedObject var presets: PresetStore
    var body: some View {
        TabView {
            TimerPreferences(countdown: countdown).tabItem { Text(L("タイマー")) }
            PresetPreferences(settings: settings, countdown: countdown, presets: presets).tabItem { Text(L("プリセット")) }
        }.padding(18)
    }
}

struct TimerPreferences: View {
    @ObservedObject var countdown: Countdown
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(L("カウントダウンタイマー")).font(.title2.bold())
            Toggle(L("タイマーを使う"), isOn: $countdown.enabled)
            Text(L("開始時間 ＋ 所要時間 ＝ 終了時間"))
                .font(.subheadline).foregroundStyle(.secondary)
            DatePicker(L("開始時間"), selection: Binding(get: { countdown.plan.start }, set: {
                countdown.plan.start = $0; countdown.savePlan()
            }), displayedComponents: [.date, .hourAndMinute])
            HStack {
                Text(L("所要時間"))
                TextField(L("分"), value: Binding(get: { countdown.plan.minutes }, set: {
                    countdown.plan.minutes = $0; countdown.savePlan()
                }), format: .number.grouping(.never)).frame(width: 90)
                Text(L("分"))
            }
            DatePicker(L("終了時間"), selection: Binding(get: { countdown.plan.end }, set: {
                countdown.plan.setEnd($0); countdown.savePlan()
            }), displayedComponents: [.date, .hourAndMinute])
            Button(L("開始時間を現在にする")) { countdown.plan.start = Countdown.minuteNow; countdown.savePlan() }
            Text(L("開始時間・所要時間の変更で終了時間を更新。終了時間の変更で所要時間を更新します。"))
                .font(.caption).foregroundStyle(.secondary)
            Text(L("開始前は「開始まで」、開始後は残り時間をメニューバーに表示します。終了後は00:00で止まります。"))
                .font(.caption).foregroundStyle(.secondary)
            if !countdown.error.isEmpty { Text(countdown.error).foregroundStyle(.red).font(.caption) }
            Spacer()
            HStack {
                Text(countdown.remaining).monospacedDigit()
                Spacer()
                Button(L("停止")) { countdown.stop() }.disabled(countdown.end == nil)
                Button(countdown.end == nil ? L("開始／予約") : L("設定を反映して再開")) { countdown.start() }.buttonStyle(.borderedProminent).disabled(!countdown.enabled)
            }
        }.padding(22)
    }
}

@MainActor
final class PresetDraft: ObservableObject {
    @Published var draft = Preset()
    @Published var status = ""
}

struct PresetPreferences: View {
    @ObservedObject var settings: MacSettings
    @ObservedObject var countdown: Countdown
    @ObservedObject var presets: PresetStore
    @StateObject private var editor = PresetDraft()
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("いつもの設定を保存")).font(.title2.bold())
            HStack {
                Menu(L("保存済みから選択")) {
                    ForEach(presets.items) { item in Button(item.name) { editor.draft = item; editor.status = "" } }
                }.disabled(presets.items.isEmpty)
                Button(L("新規")) { editor.draft = Preset(); editor.status = "" }
            }
            TextField(L("プリセット名"), text: $editor.draft.name)
            Text(L("チェックした項目だけを一括変更します。"))
                .font(.caption).foregroundStyle(.secondary)
            presetRow(L("時計"), value: $editor.draft.clock, off: L("デジタル"), on: L("アナログ"), current: settings.analog)
            presetRow(L("時計の日付"), value: $editor.draft.showDate, off: L("表示しない"), on: L("表示する"), current: settings.showDate)
                .disabled(editor.draft.clock ?? settings.analog)
                .opacity((editor.draft.clock ?? settings.analog) ? 0.4 : 1)
            presetRow(L("時計の曜日"), value: $editor.draft.showWeekday, off: L("表示しない"), on: L("表示する"), current: settings.showWeekday)
                .disabled(editor.draft.clock ?? settings.analog)
                .opacity((editor.draft.clock ?? settings.analog) ? 0.4 : 1)
            presetRow(L("外観"), value: $editor.draft.dark, off: L("ライト"), on: L("ダーク"), current: settings.dark)
            presetRow(L("Dockを隠す"), value: $editor.draft.hideDock, off: "OFF", on: "ON", current: settings.dockHidden)
            presetRow(L("Dockを殺す"), value: $editor.draft.killDock, off: "OFF", on: "ON", current: settings.dockKilled)
            presetRow(L("デスクトップ非表示"), value: $editor.draft.hideDesktop, off: "OFF", on: "ON", current: settings.desktopHidden)
            presetRow(L("通知をOFF"), value: $editor.draft.notificationsOff, off: L("解除"), on: L("抑える"), current: false)
            presetRow(L("タイマーを使う"), value: $editor.draft.timerEnabled, off: "OFF", on: "ON", current: countdown.enabled)
            HStack {
                Toggle(L("タイマー所要時間"), isOn: Binding(get: { editor.draft.timerMinutes != nil }, set: { editor.draft.timerMinutes = $0 ? countdown.plan.minutes : nil }))
                Spacer()
                TextField(L("分"), value: Binding(get: { editor.draft.timerMinutes ?? 30 }, set: { editor.draft.timerMinutes = $0 }), format: .number.grouping(.never))
                    .frame(width: 55).disabled(editor.draft.timerMinutes == nil)
                Text(L("分"))
            }
            Text(L("タイマーは所要時間を設定します。開始／予約は別操作です。"))
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(editor.status).font(.caption).foregroundStyle(.secondary)
            Text(settings.message).font(.caption).foregroundStyle(settings.error ? Color.red : Color.secondary)
            HStack {
                Button(L("削除")) { presets.remove(editor.draft.id); editor.draft = Preset(); editor.status = L("削除しました。") }
                    .disabled(!presets.items.contains(where: { $0.id == editor.draft.id }))
                Spacer()
                Button(L("適用")) { settings.apply(editor.draft, countdown: countdown) }.disabled(settings.busy || !valid)
                Button(L("保存")) { presets.save(editor.draft); editor.status = L("「%@」を保存しました。", String(describing: editor.draft.name)) }
                    .buttonStyle(.borderedProminent).disabled(!valid)
            }
        }.padding(20)
    }
    private var valid: Bool {
        let hasSelection = editor.draft.showWeekday != nil || editor.draft.showDate != nil || editor.draft.clock != nil || editor.draft.dark != nil || editor.draft.hideDock != nil || editor.draft.killDock != nil || editor.draft.hideDesktop != nil || editor.draft.notificationsOff != nil || editor.draft.timerMinutes != nil || editor.draft.timerEnabled != nil
        return hasSelection && !editor.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (editor.draft.timerMinutes == nil || (1...10080).contains(editor.draft.timerMinutes!))
    }
    private func presetRow(_ title: String, value: Binding<Bool?>, off: String, on: String, current: Bool) -> some View {
        HStack {
            Toggle(title, isOn: Binding(get: { value.wrappedValue != nil }, set: { value.wrappedValue = $0 ? current : nil }))
            Spacer()
            Picker(title, selection: Binding(get: { value.wrappedValue ?? current }, set: { value.wrappedValue = $0 })) {
                Text(off).tag(false); Text(on).tag(true)
            }.labelsHidden().pickerStyle(.segmented).frame(width: 140).disabled(value.wrappedValue == nil)
        }
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
    @Published var busy = false
    @Published var message = L("選択すると、Macのシステム設定を変更します。")
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
            message = L("時計を%@に変更しました。", String(describing: value ? "アナログ" : "デジタル"))
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
            message = value ? L("メニューバーの日付を表示する設定にしました。") : L("メニューバーの日付を非表示にしました。")
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
            message = value ? L("メニューバーの曜日を表示する設定にしました。") : L("メニューバーの曜日を非表示にしました。")
        } catch { self.error = true; message = error.localizedDescription }
        busy = false
        refresh()
    }

    func setAppearance(_ value: Bool) {
        guard !busy else { return }
        busy = true
        error = false
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
            if code == -1743 {
                message = L("外観の変更には、システム設定 → プライバシーとセキュリティ → オートメーションで、PodiumFlightのSystem Events操作を許可してください。")
            } else {
                message = L("外観を変更できませんでした：%@", String(describing: details[NSAppleScript.errorMessage] ?? "不明なエラー"))
            }
        } else if let result, result.booleanValue == value {
            dark = value
            message = L("Macの外観を%@に変更しました。", String(describing: value ? "ダーク" : "ライト"))
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
            message = value ? L("Dockをサイズ1・出現遅延3000000秒にしました。") : L("Dockを変更前の設定に戻しました。")
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
        if let minutes = preset.timerMinutes { countdown.plan.minutes = minutes; countdown.savePlan() }
        if let value = preset.timerEnabled { countdown.enabled = value }
        if let value = preset.notificationsOff { setNotificationsOff(value) }
        else { message = L("「%@」を適用しました。", String(describing: preset.name)) }
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
                message = value ? L("おやすみモードをオンにしました。許可済みの通知は届く場合があります。") : L("おやすみモードを解除しました。")
            } catch {
                self.error = true
                message = L("通知の変更に失敗しました。ショートカットアプリのToki Notifications On / Offを確認してください。")
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

struct SettingsView: View {
    @ObservedObject var settings: MacSettings
    @ObservedObject var countdown: Countdown
    @ObservedObject var presets: PresetStore
    let openPreferences: () -> Void
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LoginAtLaunchView().frame(height: 80)
            VStack(alignment: .leading, spacing: 5) {
                Text(L("セミナー・キャプチャ準備")).font(.system(size: 22, weight: .semibold))
            }
            VStack(spacing: 20) {
                settingRow(L("時計"), subtitle: L("メニューバー"), symbol: "clock") {
                    choice(L("デジタル"), selected: !settings.analog) { settings.setClock(false) }
                    choice(L("アナログ"), selected: settings.analog) { settings.setClock(true) }
                }
                Divider()
                settingRow(L("日付"), subtitle: settings.analog ? L("デジタル時計用") : L("メニューバー"), symbol: "calendar") {
                    choice(L("表示する"), selected: settings.showDate) { settings.setDateVisible(true) }
                    choice(L("しない"), selected: !settings.showDate) { settings.setDateVisible(false) }
                }
                .disabled(settings.analog)
                .opacity(settings.analog ? 0.4 : 1)
                Divider()
                settingRow(L("曜日"), subtitle: settings.analog ? L("デジタル時計用") : L("メニューバー"), symbol: "calendar.day.timeline.left") {
                    choice(L("表示する"), selected: settings.showWeekday) { settings.setWeekdayVisible(true) }
                    choice(L("しない"), selected: !settings.showWeekday) { settings.setWeekdayVisible(false) }
                }
                .disabled(settings.analog)
                .opacity(settings.analog ? 0.4 : 1)
                Divider()
                settingRow(L("外観"), subtitle: L("Mac全体"), symbol: "circle.lefthalf.filled") {
                    choice(L("ライト"), selected: !settings.dark) { settings.setAppearance(false) }
                    choice(L("ダーク"), selected: settings.dark) { settings.setAppearance(true) }
                }
            }
            .padding(18)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            .disabled(settings.busy)
            HStack {
                Toggle(L("タイマーを使う"), isOn: $countdown.enabled)
                Spacer()
                Text(countdown.remaining).monospacedDigit()
                Button(L("環境設定…"), action: openPreferences)
            }.font(.system(size: 12))
            Toggle(L("Dockを隠す（自動非表示）"), isOn: Binding(get: { settings.dockHidden }, set: settings.setDockHidden))
                .font(.system(size: 12))
            Toggle(L("Dockを殺す（最小化・出現遅延）"), isOn: Binding(get: { settings.dockKilled }, set: settings.setDockKilled))
                .font(.system(size: 12))
            Toggle(L("デスクトップアイコンを非表示"), isOn: Binding(get: { settings.desktopHidden }, set: settings.setDesktopHidden))
                .font(.system(size: 12))
            HStack {
                Label(L("通知"), systemImage: "bell.slash")
                Spacer()
                Button("OFF") { settings.setNotificationsOff(true) }
                Button("ON") { settings.setNotificationsOff(false) }
            }.font(.system(size: 12)).disabled(settings.busy)
            Text(L("通知OFFは、おやすみモードを有効にします。"))
                .font(.system(size: 10)).foregroundStyle(.secondary)
            Menu(L("プリセットを適用")) {
                ForEach(presets.items) { preset in
                    Button(preset.name) { settings.apply(preset, countdown: countdown) }
                }
                if presets.items.isEmpty { Text(L("環境設定でプリセットを保存できます")) }
            }.disabled(settings.busy)
            Text(settings.message)
                .font(.system(size: 11))
                .foregroundStyle(settings.error ? Color.red : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(settings.message)
            Spacer(minLength: 0)
            Divider()
            HStack {
                Text("PodiumFlight").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(L("終了")) { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(18)
        .onAppear { settings.refresh() }
        .onReceive(timer) { _ in settings.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in settings.refresh() }
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
