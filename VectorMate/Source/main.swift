import AppKit
import ServiceManagement
import SwiftUI
import Carbon

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// What the last operation of a group did (shown under the group, and briefly at the top of the screen).
struct OperationResult: Equatable {
    var text: String
    var isError: Bool
}

@MainActor
final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    /// メトリクス → プロポーショナルメトリクス. On by default.
    @Published var metricsEnabled: Bool { didSet { defaults.set(metricsEnabled, forKey: "metricsEnabled"); refreshWatcher() } }
    /// メトリクス以外 → プロポーショナルメトリクス OFF. On by default.
    @Published var metricsOffEnabled: Bool { didSet { defaults.set(metricsOffEnabled, forKey: "metricsOffEnabled"); watcher.turnOff = metricsOffEnabled } }
    /// Pause from the menu bar (not saved: a relaunch resumes).
    @Published var paused = false { didSet { refreshWatcher() } }
    /// Short message near the top of the screen each time it is applied. Off by default.
    @Published var notifyApplied: Bool { didSet { defaults.set(notifyApplied, forKey: "notifyApplied") } }
    @Published var keepRunning: Bool { didSet { defaults.set(keepRunning, forKey: "keepRunning") } }
    @Published var metricsResult = ""
    @Published var metricsResultIsError = false
    @Published var automationDenied = false
    @Published var trusted = AXIsProcessTrusted()

    /// One Illustrator settings operation at a time (they share Illustrator's dialog boxes and menus).
    @Published var busy = false
    @Published var brightnessIndex: Int?
    @Published var interface: InterfaceMenus.State?
    @Published var shapeSource: ShapeBuilderColor.Source?
    @Published var shapeNoDocument = false
    /// Read from the preference files; what VectorMate itself set (or read in the dialog box) is newer and wins.
    @Published var fileHandling: FileHandling.State?
    private var fileHandlingKnownAt = Date.distantPast
    @Published var units: UnitSettings.State?
    @Published var unitResult: OperationResult?
    /// 単位セット (edited in 設定 → 単位セット).
    @Published var unitSets: [UnitSet] = UnitSet.load() { didSet { UnitSet.save(unitSets) } }
    /// 単位パレットのモード: false 基本 (units only), true 詳細 (increments and document settings too).
    @Published var unitDetail = UserDefaults.standard.bool(forKey: "unitPaletteDetail") { didSet { UserDefaults.standard.set(unitDetail, forKey: "unitPaletteDetail") } }
    /// クイック環境設定.
    @Published var quickPrefs: QuickPrefs.State?
    @Published var quickResult: OperationResult?
    @Published var interfaceResult: OperationResult?
    @Published var toolResult: OperationResult?
    @Published var fileResult: OperationResult?
    /// Brightness steps pressed while an operation was running; applied together afterwards.
    private var pendingBrightness = 0

    /// ⇧F2 brighter / ⇧F1 darker, only while Illustrator is in front.
    @Published var hotkeysEnabled: Bool { didSet { defaults.set(hotkeysEnabled, forKey: "hotkeysEnabled"); refreshHotkeys() } }
    @Published var brighterCombo: KeyCombo? { didSet { store(brighterCombo, "brighterHotkey"); refreshHotkeys() } }
    @Published var darkerCombo: KeyCombo? { didSet { store(darkerCombo, "darkerHotkey"); refreshHotkeys() } }
    /// Shows or hides 単位パレット. ⌃⌥⌘U by default; registered only while Illustrator is in front, like the others.
    /// KageTrimmer uses the same key everywhere and steps aside in Illustrator (HotkeyManifest.claimedByOtherApp).
    @Published var paletteCombo: KeyCombo? { didSet { store(paletteCombo, "paletteHotkey"); refreshHotkeys() } }
    var onPaletteHotkey: (() -> Void)?
    /// Shows or hides クイック環境設定. ⌃⌥⌘Q by default (Keyboard Maestro has macros on it; set per Mac if they collide).
    @Published var quickCombo: KeyCombo? { didSet { store(quickCombo, "quickHotkey"); refreshHotkeys() } }
    var onQuickHotkey: (() -> Void)?
    /// アプリ起動のホットキー: shows the main window from any app while VectorMate runs. ⌃⌥⌘; by default; per Mac (not shared).
    @Published var launchCombo: KeyCombo? { didSet { store(launchCombo, "launchHotkey"); refreshHotkeys() } }
    var onLaunchHotkey: (() -> Void)?
    /// その他 → トリミング表示でもガイドを表示する: while Illustrator is in front, ⌘; runs the menu command showguide
    /// (表示 → ガイド), which also works in トリミング表示. Off by default.
    @Published var guideInTrim: Bool { didSet { defaults.set(guideInTrim, forKey: "guideInTrimView"); refreshHotkeys() } }
    static let guideCombo = KeyCombo(code: UInt32(kVK_ANSI_Semicolon), modifiers: KeyCombo.command)
    static let guideNumber: UInt32 = 6
    /// ツール: a modifier key (⌃ by default) tapped twice selects the Selection tool; the Artboard / Gradient tool opens its panel. Off by default.
    @Published var doubleTap: Bool { didSet { defaults.set(doubleTap, forKey: "controlDoubleTapSelect"); refreshToolWatcher() } }
    @Published var tapKey: ToolWatcher.TapKey { didSet { defaults.set(tapKey.rawValue, forKey: "doubleTapKey"); refreshToolWatcher() } }
    @Published var artboardPanel: Bool { didSet { defaults.set(artboardPanel, forKey: "artboardToolPanel"); refreshToolWatcher() } }
    @Published var gradientPanel: Bool { didSet { defaults.set(gradientPanel, forKey: "gradientToolPanel"); refreshToolWatcher() } }
    let toolWatcher = ToolWatcher()
    @Published var failedHotkeys: Set<UInt32> = []
    static let brighterDefault = KeyCombo(code: UInt32(kVK_F2), modifiers: KeyCombo.shift)
    static let darkerDefault = KeyCombo(code: UInt32(kVK_F1), modifiers: KeyCombo.shift)
    static let paletteDefault = KeyCombo(code: UInt32(kVK_ANSI_U), modifiers: KeyCombo.control | KeyCombo.option | KeyCombo.command)
    static let quickDefault = KeyCombo(code: UInt32(kVK_ANSI_Q), modifiers: KeyCombo.control | KeyCombo.option | KeyCombo.command)
    static let launchDefault = KeyCombo(code: UInt32(kVK_ANSI_Semicolon), modifiers: KeyCombo.control | KeyCombo.option | KeyCombo.command)
    static let brighterNumber: UInt32 = 1, darkerNumber: UInt32 = 2, paletteNumber: UInt32 = 3, quickNumber: UInt32 = 4, launchNumber: UInt32 = 5
    let hotkeys = HotkeySet(signature: "VcMt")
    private var registeredState: String?
    private var activation: NSObjectProtocol?

    let watcher = MetricsWatcher()
    var onChange: (() -> Void)?

    init() {
        metricsEnabled = defaults.object(forKey: "metricsEnabled") as? Bool ?? true
        notifyApplied = defaults.bool(forKey: "notifyApplied")
        metricsOffEnabled = defaults.object(forKey: "metricsOffEnabled") as? Bool ?? true
        keepRunning = defaults.object(forKey: "keepRunning") as? Bool ?? true
        hotkeysEnabled = defaults.object(forKey: "hotkeysEnabled") as? Bool ?? true
        brighterCombo = Self.load("brighterHotkey") ?? Self.brighterDefault
        darkerCombo = Self.load("darkerHotkey") ?? Self.darkerDefault
        // Up to 1.7 the unset key was saved as null; 1.8 gives it the default ⌃⌥⌘U once.
        if !defaults.bool(forKey: "paletteDefaultApplied") { defaults.removeObject(forKey: "paletteHotkey"); defaults.set(true, forKey: "paletteDefaultApplied") }
        // A cleared key is stored as null and stays cleared; no value yet means the default.
        paletteCombo = UserDefaults.standard.data(forKey: "paletteHotkey") == nil ? Self.paletteDefault : Self.load("paletteHotkey")
        // Up to 2.2 the unset key was saved as null; 2.3 gives it the default ⌃⌥⌘Q once.
        if !defaults.bool(forKey: "quickDefaultApplied") { defaults.removeObject(forKey: "quickHotkey"); defaults.set(true, forKey: "quickDefaultApplied") }
        quickCombo = defaults.data(forKey: "quickHotkey") == nil ? Self.quickDefault : Self.load("quickHotkey")
        launchCombo = defaults.data(forKey: "launchHotkey") == nil ? Self.launchDefault : Self.load("launchHotkey")
        guideInTrim = defaults.bool(forKey: "guideInTrimView")
        doubleTap = defaults.bool(forKey: "controlDoubleTapSelect")
        tapKey = ToolWatcher.TapKey(rawValue: defaults.string(forKey: "doubleTapKey") ?? "") ?? .control
        artboardPanel = defaults.bool(forKey: "artboardToolPanel")
        gradientPanel = defaults.bool(forKey: "gradientToolPanel")
        metricsResult = L("metrics.none")
        watcher.onEvent = { [weak self] event in self?.report(event) }
        hotkeys.action = { [weak self] number in
            if number == Self.guideNumber { self?.showGuides() } else if number == Self.launchNumber { self?.onLaunchHotkey?() } else if number == Self.paletteNumber { self?.onPaletteHotkey?() } else if number == Self.quickNumber { self?.onQuickHotkey?() } else { self?.stepBrightness(number == Self.brighterNumber ? 1 : -1, fromHotkey: true) }
        }
        // After recording, register again so a conflict with another app is reported.
        HotkeyRecorder.shared.onRecordingChanged.append { [weak self] recording in
            guard let self, !recording else { return }
            self.registeredState = nil; self.refreshHotkeys()
        }
        // Event-driven: the keys exist only while Illustrator is in front, so ⇧F1 / ⇧F2 stay with every other app.
        activation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshHotkeys() }
        }
        watcher.turnOff = metricsOffEnabled
        refreshWatcher()
        refreshToolWatcher()
        refreshHotkeys()
    }

    func refreshToolWatcher() {
        toolWatcher.options = ToolWatcher.Options(doubleTap: doubleTap, tapKey: tapKey, artboardPanel: artboardPanel, gradientPanel: gradientPanel)
    }

    private static func load(_ key: String) -> KeyCombo? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(KeyCombo.self, from: $0) }
    }
    private func store(_ combo: KeyCombo?, _ key: String) { defaults.set(try? JSONEncoder().encode(combo), forKey: key) }

    var watching: Bool { metricsEnabled && !paused }
    var watchStatus: String {
        if !metricsEnabled { return L("watch.off") }
        if paused { return L("watch.paused") }
        return L(trusted ? "watch.on" : "watch.onMouseOnly")
    }

    func refreshWatcher() { watcher.isActive = watching; onChange?() }

    /// Called when the app comes to the front: the permission may have changed in System Settings.
    func refreshPermission() {
        let now = AXIsProcessTrusted()
        guard now != trusted else { return }
        trusted = now
        watcher.restart()
        toolWatcher.restart()
        onChange?()
    }

    private func report(_ event: MetricsWatcher.Event) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        switch event {
        case .applied(let on, let off):
            automationDenied = false
            metricsResult = on > 0 ? String(format: L("metrics.appliedOn"), time, on) : String(format: L("metrics.appliedOff"), time, off)
            metricsResultIsError = false
            if notifyApplied { TransientMessage.show(L(on > 0 ? "metrics.toastOn" : "metrics.toastOff")) }
        case .automationDenied:
            automationDenied = true
            metricsResult = L("fail.automation")
            metricsResultIsError = true
        case .failed(let message):
            metricsResult = String(format: L("fail.script"), message)
            metricsResultIsError = true
        }
        onChange?()
    }

    // MARK: Hotkeys

    func refreshHotkeys() {
        let front = Illustrator.isIllustrator(NSWorkspace.shared.frontmostApplication)
        let pairs = [(Self.brighterNumber, brighterCombo), (Self.darkerNumber, darkerCombo), (Self.paletteNumber, paletteCombo), (Self.quickNumber, quickCombo)]
        let state = "\(hotkeysEnabled):\(front):\(pairs.map { "\($0.0)=\($0.1?.label ?? "-")" }):\(launchCombo?.label ?? "-"):\(guideInTrim)"
        guard state != registeredState else { return }
        registeredState = state
        var failed: Set<UInt32> = []
        for (number, combo) in pairs {
            guard hotkeysEnabled, let combo else { hotkeys.unregister(number); continue }
            // Registered to detect a conflict even when Illustrator is not in front, then released so the key passes through.
            if hotkeys.register(number, combo) != noErr { failed.insert(number) }
            if !front { hotkeys.unregister(number) }
        }
        // The launch key works in every app, and apart from 「ホットキーを使う」.
        if let launchCombo {
            if hotkeys.register(Self.launchNumber, launchCombo) != noErr { failed.insert(Self.launchNumber) }
        } else { hotkeys.unregister(Self.launchNumber) }
        // ⌘; is Illustrator's own key, so it is taken only while Illustrator is in front and the option is on.
        if guideInTrim && front { _ = hotkeys.register(Self.guideNumber, Self.guideCombo) } else { hotkeys.unregister(Self.guideNumber) }
        failedHotkeys = failed
        publishHotkeys()
    }

    /// Declares the keys for HotkeyHound and for KageTrimmer, which yields ⌃⌥⌘U in Illustrator (scope only).
    private func publishHotkeys() {
        let apps = [Illustrator.bundlePrefix]
        let entries: [(String, String, KeyCombo?)] = [("brighter", L("hotkey.brighter"), brighterCombo), ("darker", L("hotkey.darker"), darkerCombo),
                                                      ("palette", L("hotkey.palette"), paletteCombo), ("quick", L("hotkey.quick"), quickCombo)]
        var items = entries.compactMap { id, title, combo in
            combo.map { HotkeyManifest.Item(id: id, title: title, keyCode: Int($0.code), modifiers: Int($0.modifiers), enabled: hotkeysEnabled, scope: "only", apps: apps) }
        }
        if guideInTrim {
            items.append(HotkeyManifest.Item(id: "guide", title: L("other.guide"), keyCode: Int(Self.guideCombo.code), modifiers: Int(Self.guideCombo.modifiers),
                                             enabled: true, scope: "only", apps: apps))
        }
        if let launchCombo {
            items.append(HotkeyManifest.Item(id: "launch", title: L("launch.hotkey"), keyCode: Int(launchCombo.code), modifiers: Int(launchCombo.modifiers), enabled: true))
        }
        HotkeyManifest.publish(items)
    }

    /// The app's hotkeys with their titles, for refusing the same key twice.
    func otherHotkeys(except number: UInt32) -> [(String, KeyCombo)] {
        let all: [(UInt32, String, KeyCombo?)] = [(Self.brighterNumber, L("hotkey.brighter"), brighterCombo), (Self.darkerNumber, L("hotkey.darker"), darkerCombo),
                                                  (Self.paletteNumber, L("hotkey.palette"), paletteCombo), (Self.quickNumber, L("hotkey.quick"), quickCombo),
                                                  (Self.launchNumber, L("launch.hotkey"), launchCombo)]
        return all.compactMap { entry in entry.0 == number ? nil : entry.2.map { (entry.1, $0) } }
    }

    /// ⌘; with その他 on: app.executeMenuCommand('showguide') in the Illustrator in front.
    func showGuides() {
        guard let app = Illustrator.running else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            if case .failed(let message) = Illustrator.run(javascript: "app.executeMenuCommand('showguide'); \"\"", in: app) {
                diagnostics.log("showguide failed: \(message, privacy: .public)")
            }
        }
    }

    // MARK: Illustrator settings

    /// Runs one blocking settings operation off the main thread, then reports it.
    private func perform<T>(_ work: @escaping () -> Result<T, SettingsFailure>, _ done: @escaping (Result<T, SettingsFailure>) -> OperationResult) {
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = work()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.busy = false
                    if case .failure(.automationDenied) = result { self.automationDenied = true }
                    let message = done(result)
                    if message.isError { NSSound.beep() }
                    // Shown where the user is (Illustrator is in front after this): B27, never just a beep.
                    TransientMessage.show(message.text)
                    self.refreshSettingsState()
                    self.onChange?()
                    if self.pendingBrightness != 0 {
                        let steps = self.pendingBrightness
                        self.pendingBrightness = 0
                        self.stepBrightness(steps, fromHotkey: true)
                    }
                }
            }
        }
    }

    func failureText(_ failure: SettingsFailure) -> String {
        switch failure {
        case .notRunning: return L("fail.notRunning")
        case .noDocument: return L("fail.noDocument")
        case .notTrusted: return AccessibilityText.text("blocked")
        case .automationDenied: return L("fail.automation")
        case .menuNotFound: return L("fail.menuNotFound")
        case .dialogNotFound: return L("fail.dialogNotFound")
        case .controlNotFound: return L("fail.controlNotFound")
        case .notChanged: return L("fail.notChanged")
        case .failed(let message): return String(format: L("fail.script"), message)
        }
    }

    private func outcome<T>(_ result: Result<T, SettingsFailure>, _ success: (T) -> String) -> OperationResult {
        switch result {
        case .success(let value): return OperationResult(text: success(value), isError: false)
        case .failure(let failure): return OperationResult(text: failureText(failure), isError: true)
        }
    }

    func levelName(_ index: Int) -> String { L("bright.level." + UIBrightness.levels[index].key) }

    /// +1 brighter, -1 darker. Hotkey presses during an operation are added up and applied after it.
    func stepBrightness(_ step: Int, fromHotkey: Bool = false) {
        guard Illustrator.isIllustrator(NSWorkspace.shared.frontmostApplication) || !fromHotkey else { return }
        if busy { pendingBrightness += step; return }
        perform({ UIBrightness.change(step: step) }) { [unowned self] result in
            let message = outcome(result) { before, after in
                before == after ? L(step > 0 ? "bright.atMax" : "bright.atMin") : String(format: L("bright.done"), self.levelName(after))
            }
            interfaceResult = message
            return message
        }
    }

    func setBrightness(_ level: Int) {
        guard !busy, level != brightnessIndex else { return }
        brightnessIndex = level
        perform({ UIBrightness.change(level: level) }) { [unowned self] result in
            let message = outcome(result) { _, after in String(format: L("bright.done"), self.levelName(after)) }
            interfaceResult = message
            return message
        }
    }

    func setInterface(_ wanted: InterfaceMenus.State, message success: String) {
        guard !busy else { return }
        if var current = interface { wanted.forEach { current[$0.key] = $0.value }; interface = current }
        perform({ InterfaceMenus.apply(wanted) }) { [unowned self] result in
            if case .success(let state) = result { interface = state }
            let message = outcome(result) { _ in success }
            interfaceResult = message
            return message
        }
    }
    func setInterface(_ item: InterfaceMenus.Item, _ value: Bool) {
        setInterface([item: value], message: String(format: L(value ? "ui.turnedOn" : "ui.turnedOff"), L("ui." + item.rawValue)))
    }
    func applyOldSchool() { setInterface(InterfaceMenus.oldSchool, message: L("ui.oldSchoolDone")) }

    func setShapeSource(_ source: ShapeBuilderColor.Source) {
        guard !busy, source != shapeSource else { return }
        perform({ ShapeBuilderColor.set(source) }) { [unowned self] result in
            let name = L(source == .swatches ? "shape.swatches" : "shape.artwork")
            let message = outcome(result) { changed in String(format: L(changed ? "shape.done" : "shape.already"), name) }
            toolResult = message
            return message
        }
    }

    /// Reads the checkboxes from the dialog box (opened and closed with キャンセル).
    func checkFileHandling() {
        guard !busy else { return }
        perform(FileHandling.read) { [unowned self] result in
            if case .success(let state) = result { fileHandling = state; fileHandlingKnownAt = Date() }
            let message = outcome(result) { _ in L("file.checked") }
            fileResult = message
            return message
        }
    }
    func setFileHandling(_ wanted: FileHandling.State, message success: String) {
        guard !busy else { return }
        perform({ FileHandling.apply(wanted) }) { [unowned self] result in
            if case .success(let before) = result { var after = before; wanted.forEach { after[$0.key] = $0.value }; fileHandling = after; fileHandlingKnownAt = Date() }
            let message = outcome(result) { _ in success }
            fileResult = message
            return message
        }
    }
    func setFileHandling(_ item: FileHandling.Item, _ value: Bool) {
        setFileHandling([item: value], message: String(format: L(value ? "ui.turnedOn" : "ui.turnedOff"), L("file." + item.rawValue)))
    }
    /// バックグラウンド保存・書き出しをオフ (menus).
    func turnOffBackground() { setFileHandling([.save: false, .export: false], message: L("bg.done")) }

    func applyUnitSet(_ id: String) {
        guard !busy, let set = unitSets.first(where: { $0.id == id }) else { return }
        let detail = unitDetail
        perform({ UnitSettings.apply(set, detail: detail) }) { [unowned self] result in
            if case .success(let applied) = result { units = applied.state }
            let message = outcome(result) { applied in
                String(format: L(detail ? "units.doneDetail" : "units.done"), set.name) + (applied.documentSkipped ? L("units.noDocument") : "")
            }
            unitResult = message
            return message
        }
    }

    // MARK: クイック環境設定

    private let quickQueue = DispatchQueue(label: "VectorMate.quick")
    /// Checkbox writes are quick JavaScript calls: run one after another off the main thread, errors only are reported.
    private func quick(_ work: @escaping () -> Result<QuickPrefs.State, SettingsFailure>) {
        quickQueue.async {
            let result = work()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    switch result {
                    case .success(let state): self.quickPrefs = state; self.quickResult = nil
                    case .failure(let failure):
                        if failure == .automationDenied { self.automationDenied = true }
                        self.quickResult = OperationResult(text: self.failureText(failure), isError: true)
                        if failure == .notRunning { self.quickPrefs = nil } else { NSSound.beep() }
                    }
                }
            }
        }
    }
    func refreshQuickPrefs() { quick(QuickPrefs.read) }
    func setQuick(_ items: [QuickPrefs.Item], _ value: Bool) {
        if var state = quickPrefs {   // shown at once; the read-back corrects it
            for item in items {
                switch item {
                case .previewBounds: state.previewBounds = value
                case .glyphBounds: state.glyphBounds = value
                case .transformPatterns: state.transformPatterns = value
                case .scaleCorners: state.scaleCorners = value
                case .scaleStroke: state.scaleStroke = value
                case .realtimeDrawing: state.realtimeDrawing = value
                case .pastePlain: state.pastePlain = value
                case .pastePreserve: state.pastePreserve = value
                }
            }
            quickPrefs = state
        }
        quick { QuickPrefs.set(items, value) }
    }
    func setQuickKeyLength(points: Double) { quick { QuickPrefs.setCursorKeyLength(points: points) } }
    func refreshQuickPreview() { quick(QuickPrefs.refreshPreview) }
    /// The ruler unit opens the 単位 pane, so it is a settings operation (one at a time, reported).
    func setQuickRulerUnit(_ code: Int) {
        guard !busy, code != quickPrefs?.rulerType else { return }
        perform({ QuickPrefs.setRulerUnit(code) }) { [unowned self] result in
            if case .success(let state) = result { quickPrefs = state }
            let message = outcome(result) { _ in String(format: L("quick.unitDone"), UnitSettings.label(code: code, popup: 0)) }
            quickResult = message
            return message
        }
    }

    /// Reads brightness, the menu checkmarks and the Shape Builder color (never launches Illustrator, opens no dialog box).
    func refreshSettingsState() {
        guard !busy, let app = Illustrator.running else {
            if Illustrator.running == nil { brightnessIndex = nil; interface = nil; shapeSource = nil; shapeNoDocument = false; units = nil }
            return
        }
        DispatchQueue.global(qos: .utility).async {
            let brightness = try? UIBrightness.read(app).get()
            let menus = try? InterfaceMenus.read().get()
            let shape = ShapeBuilderColor.read(app)
            let units = try? UnitSettings.read(app).get()
            let files = FileHandling.readFiles(app)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.brightnessIndex = brightness
                    self.interface = menus
                    self.units = units
                    if let files, files.written > self.fileHandlingKnownAt { self.fileHandling = files.state; self.fileHandlingKnownAt = files.written }
                    self.shapeSource = try? shape.get()
                    if case .failure(.noDocument) = shape { self.shapeNoDocument = true } else { self.shapeNoDocument = false }
                }
            }
        }
    }

    var notRunningText: String { L(Illustrator.running == nil ? "fail.notRunning" : "state.unknown") }

    var hotkeyStatusText: String {
        guard hotkeysEnabled else { return L("hotkey.off") }
        if !failedHotkeys.isEmpty { return HotkeyText.registerFailed }
        return String(format: L("hotkey.status"), brighterCombo?.label ?? HotkeyText.unset, darkerCombo?.label ?? HotkeyText.unset)
    }

    /// Keys shared by 設定の共有 (export/import and sync). 起動・常駐・メニューバー stay per Mac.
    static let sharedKeys: Set<String> = ["metricsEnabled", "metricsOffEnabled", "notifyApplied", "hotkeysEnabled",
                                          "brighterHotkey", "darkerHotkey", "paletteHotkey", "quickHotkey", UnitSet.storeKey, "unitPaletteDetail",
                                          "guideInTrimView", "controlDoubleTapSelect", "doubleTapKey", "artboardToolPanel", "gradientToolPanel"]
    /// Re-reads the shared settings after SettingsSync applied them, so the next save does not write the old values back.
    func reloadSharedSettings() {
        metricsEnabled = defaults.object(forKey: "metricsEnabled") as? Bool ?? true
        metricsOffEnabled = defaults.object(forKey: "metricsOffEnabled") as? Bool ?? true
        notifyApplied = defaults.bool(forKey: "notifyApplied")
        hotkeysEnabled = defaults.object(forKey: "hotkeysEnabled") as? Bool ?? true
        brighterCombo = Self.load("brighterHotkey") ?? Self.brighterDefault
        darkerCombo = Self.load("darkerHotkey") ?? Self.darkerDefault
        paletteCombo = defaults.data(forKey: "paletteHotkey") == nil ? Self.paletteDefault : Self.load("paletteHotkey")
        quickCombo = defaults.data(forKey: "quickHotkey") == nil ? Self.quickDefault : Self.load("quickHotkey")
        unitSets = UnitSet.load()
        unitDetail = defaults.bool(forKey: "unitPaletteDetail")
        guideInTrim = defaults.bool(forKey: "guideInTrimView")
        doubleTap = defaults.bool(forKey: "controlDoubleTapSelect")
        tapKey = ToolWatcher.TapKey(rawValue: defaults.string(forKey: "doubleTapKey") ?? "") ?? .control
        artboardPanel = defaults.bool(forKey: "artboardToolPanel")
        gradientPanel = defaults.bool(forKey: "gradientToolPanel")
    }

    func stop() {
        watcher.isActive = false
        hotkeys.unregisterAll()
        if let activation { NSWorkspace.shared.notificationCenter.removeObserver(activation) }
    }
}

struct Header: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView {
        let header = appHeader(L("headline"), subtitle: L("subtitle"))
        // The wrapping subtitle would otherwise become first responder and show a selection.
        func unselectable(_ view: NSView) {
            if let field = view as? NSTextField { field.isSelectable = false; field.refusesFirstResponder = true }
            view.subviews.forEach(unselectable)
        }
        unselectable(header)
        return header
    }
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
            Text(title).foregroundColor(.secondary).frame(width: 130, alignment: .leading)
            Text(value).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title + ": " + value)
    }
}

struct GroupTitle: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 13, weight: .semibold)) }
}

struct ResultRow: View {
    let result: OperationResult?
    var body: some View {
        if let result {
            StatusRow(symbol: result.isError ? "xmark.octagon.fill" : "checkmark.circle", tint: result.isError ? .red : .secondary,
                      title: L("row.last"), value: result.text)
        }
    }
}

/// One feature per tab page: the group title and its controls, top-aligned.
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

/// Tabs along the top, as in the settings window (NSTabView; SwiftUI's TabView can fold into a flyout).
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
            item.view = NSHostingView(rootView: page.content)
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

struct Note: View {
    let text: String
    var body: some View { Text(text).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
}

/// 基本UI: brightness, the menu checkmarks of ViewToggles' basic UI, and オールドスクール設定.
struct InterfacePage: View {
    @ObservedObject var model: Model
    var body: some View {
        FeaturePage(title: L("bright.title")) {
            Picker("", selection: Binding(get: { model.brightnessIndex ?? -1 }, set: { model.setBrightness($0) })) {
                ForEach(UIBrightness.levels.indices, id: \.self) { index in Text(model.levelName(index)).tag(index) }
            }
            .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
            .disabled(model.busy || model.brightnessIndex == nil)
            HStack(spacing: 8) {
                Text(model.hotkeyStatusText).font(.caption).foregroundColor(.secondary)
                Button(L("hotkey.open")) { (NSApp.delegate as? AppDelegate)?.openPreferences(tab: L("hotkey.tab")) }.controlSize(.small)
            }
            GroupTitle(text: L("ui.title")).padding(.top, 8)
            ForEach(InterfaceMenus.Item.allCases, id: \.self) { item in
                Toggle(L("ui." + item.rawValue), isOn: Binding(get: { model.interface?[item] ?? false }, set: { model.setInterface(item, $0) }))
                    .disabled(model.busy || model.interface == nil)
            }
            HStack {
                Button(L("ui.oldSchool")) { model.applyOldSchool() }.disabled(model.busy || model.interface == nil)
            }.padding(.top, 4)
            Note(text: L("ui.oldSchoolDetail"))
            if model.interface == nil { Note(text: model.trusted ? model.notRunningText : AccessibilityText.text("blocked")) }
            ResultRow(result: model.interfaceResult)
        }
    }
}

/// テキスト: メトリクス → プロポーショナルメトリクス.
struct TextPage: View {
    @ObservedObject var model: Model
    var body: some View {
        FeaturePage(title: L("metrics.title")) {
            Toggle(L("metrics.toggle"), isOn: $model.metricsEnabled)
            Toggle(L("metrics.toggleOff"), isOn: $model.metricsOffEnabled).disabled(!model.metricsEnabled).padding(.leading, 20)
            Toggle(L("notify.toggle"), isOn: $model.notifyApplied).disabled(!model.metricsEnabled).padding(.leading, 20)
            StatusRow(symbol: model.watching ? "eye" : "pause.circle", tint: .secondary, title: L("row.state"), value: model.watchStatus)
            StatusRow(symbol: model.trusted ? "checkmark.circle.fill" : "minus.circle", tint: model.trusted ? .green : .secondary,
                      title: AccessibilityText.text("title"), value: AccessibilityText.text(model.trusted ? "allowed" : "denied"))
            StatusRow(symbol: model.metricsResultIsError ? "xmark.octagon.fill" : "textformat", tint: model.metricsResultIsError ? .red : .secondary,
                      title: L("row.last"), value: model.metricsResult)
            if model.automationDenied {
                Button(L("openAutomation")) { openPrivacy("Privacy_Automation") }
            }
        }
    }
}

struct MainView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header().fixedSize(horizontal: false, vertical: true)
            MainTabs(pages: [
                ("text", L("tab.text"), AnyView(TextPage(model: model))),
                ("interface", L("tab.interface"), AnyView(InterfacePage(model: model))),
                ("tools", L("tab.tools"), AnyView(FeaturePage(title: L("shape.title")) {
                    Picker("", selection: Binding(get: { model.shapeSource ?? .artwork }, set: { model.setShapeSource($0) })) {
                        Text(L("shape.swatches")).tag(ShapeBuilderColor.Source.swatches)
                        Text(L("shape.artwork")).tag(ShapeBuilderColor.Source.artwork)
                    }
                    .pickerStyle(.radioGroup).labelsHidden()
                    .disabled(model.busy || model.shapeSource == nil)
                    if model.shapeSource == nil { Note(text: model.shapeNoDocument ? L("fail.noDocument") : model.notRunningText) }
                    Note(text: L("shape.detail"))
                    ResultRow(result: model.toolResult)
                    GroupTitle(text: L("tool.selectTitle")).padding(.top, 8)
                    Toggle(L("tool.doubleTap"), isOn: $model.doubleTap)
                    HStack(spacing: 6) {
                        Text(L("tool.tapKey"))
                        Picker("", selection: $model.tapKey) {
                            ForEach(ToolWatcher.TapKey.allCases, id: \.self) { Text($0.label).tag($0) }
                        }.labelsHidden().fixedSize()
                    }.disabled(!model.doubleTap).padding(.leading, 20)
                    Note(text: L("tool.controlDoubleTapDetail"))
                    GroupTitle(text: L("tool.panelTitle")).padding(.top, 8)
                    Toggle(L("tool.artboardPanel"), isOn: $model.artboardPanel)
                    Toggle(L("tool.gradientPanel"), isOn: $model.gradientPanel)
                    Note(text: L("tool.panelDetail"))
                    if !model.trusted && (model.doubleTap || model.artboardPanel || model.gradientPanel) { Note(text: AccessibilityText.text("blocked")) }
                })),
                ("file", L("tab.file"), AnyView(FeaturePage(title: L("file.title")) {
                    ForEach(FileHandling.Item.allCases, id: \.self) { item in
                        Toggle(L("file." + item.rawValue), isOn: Binding(get: { model.fileHandling?[item] ?? false }, set: { model.setFileHandling(item, $0) }))
                            .disabled(model.busy)
                    }
                    HStack {
                        Button(L("file.check")) { model.checkFileHandling() }.disabled(model.busy)
                        if model.fileHandling == nil { Text(L("file.unchecked")).font(.caption).foregroundColor(.secondary) }
                    }
                    Note(text: L("file.detail"))
                    ResultRow(result: model.fileResult)
                })),
                ("version", L("version.tab"), AnyView(VersionSwitchView())),
                ("other", L("tab.other"), AnyView(FeaturePage(title: L("other.title")) {
                    Toggle(L("other.guide"), isOn: $model.guideInTrim)
                    Note(text: L("other.guideDetail"))
                }))
            ])
            HStack {
                Button(L("help")) { (NSApp.delegate as? AppDelegate)?.showHelp() }
                Button(L("settingsButton")) { (NSApp.delegate as? AppDelegate)?.showPreferences() }
                Button(L("palette.title")) { (NSApp.delegate as? AppDelegate)?.showUnitPalette() }
                Button(L("quick.title")) { (NSApp.delegate as? AppDelegate)?.showQuickPalette() }
                Spacer()
                if model.busy { ProgressView().controlSize(.small); Text(L("working")).font(.caption).foregroundColor(.secondary) }
                Button(L("reload")) { model.refreshSettingsState() }.disabled(model.busy)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
    }
}

func openPrivacy(_ anchor: String) {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?" + anchor)!)
}

struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) {
                    LoginAtLaunchView()
                    StartupWindowView()
                    Toggle(L("keepRunning"), isOn: $model.keepRunning)
                    Text(L("keepRunningHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text(L("launch.hotkey"))
                    HotkeyField(id: "launch", combo: $model.launchCombo, defaultCombo: Model.launchDefault, allowsClear: true,
                                others: model.otherHotkeys(except: Model.launchNumber),
                                registered: !model.failedHotkeys.contains(Model.launchNumber), isEnabled: true)
                    Text(L("launch.hotkeyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    MenuBarPresenceView()
                }
                AccessibilitySection()
            })),
            (L("hotkey.tab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("bright.title")) {
                    Toggle(HotkeyText.enable, isOn: $model.hotkeysEnabled)
                    Text(L("hotkey.brighter"))
                    HotkeyField(id: "brighter", combo: $model.brighterCombo, defaultCombo: Model.brighterDefault, allowsClear: true,
                                others: model.otherHotkeys(except: Model.brighterNumber),
                                registered: !model.failedHotkeys.contains(Model.brighterNumber), isEnabled: model.hotkeysEnabled)
                    Text(L("hotkey.darker"))
                    HotkeyField(id: "darker", combo: $model.darkerCombo, defaultCombo: Model.darkerDefault, allowsClear: true,
                                others: model.otherHotkeys(except: Model.darkerNumber),
                                registered: !model.failedHotkeys.contains(Model.darkerNumber), isEnabled: model.hotkeysEnabled)
                    Text(L("hotkey.hint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("quick.title")) {
                    Text(L("hotkey.quick"))
                    HotkeyField(id: "quick", combo: $model.quickCombo, defaultCombo: Model.quickDefault, allowsClear: true,
                                others: model.otherHotkeys(except: Model.quickNumber),
                                registered: !model.failedHotkeys.contains(Model.quickNumber), isEnabled: model.hotkeysEnabled)
                    Text(L("hotkey.quickHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("palette.title")) {
                    Text(L("hotkey.palette"))
                    HotkeyField(id: "palette", combo: $model.paletteCombo, defaultCombo: Model.paletteDefault, allowsClear: true,
                                others: model.otherHotkeys(except: Model.paletteNumber),
                                registered: !model.failedHotkeys.contains(Model.paletteNumber), isEnabled: model.hotkeysEnabled)
                    Text(L("hotkey.paletteHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (L("sets.tab"), AnyView(UnitSetsEditor(model: model))),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate, NSMenuItemValidation {
    let model = Model()
    var mainWindow: NSWindow?
    var preferences: NSWindow?
    var helpWindow: NSWindow?
    var item: NSStatusItem!
    var stateItem: NSMenuItem!
    let launchedAt = Date()
    lazy var unitPalette = UnitPalette(model: model)
    lazy var quickPalette = QuickPrefsPalette(model: model)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let loginLaunch = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        AccessibilityText.neededOverride = [
            "Illustratorで押したキー（Return・Tab・⌘キー）を確認のきっかけにするためと、環境設定・ツールオプションのダイアログボックスを操作するために使用します。未許可の場合、プロポーショナルメトリクスはクリックの後だけ確認し、UIの明るさ・シェイプ形成ツールのカラー・バックグラウンド保存と書き出しは変更できません。",
            "Used to notice keys pressed in Illustrator (Return, Tab, ⌘ keys) as a cue to check, and to operate the Settings and tool options dialog boxes. Without it, proportional metrics is checked only after clicks, and UI brightness, the Shape Builder color and background save and export cannot be changed.",
            "用于接收在 Illustrator 中按下的键（Return、Tab、⌘ 键）作为检查时机，以及操作设置和工具选项对话框。未获授权时，仅在点击后检查比例间距，且无法更改界面亮度、形状生成器颜色以及后台存储和导出。",
            "Illustrator에서 누른 키(Return, Tab, ⌘ 키)를 확인 시점으로 받고, 설정·도구 옵션 대화상자를 조작하는 데 사용합니다. 권한이 없으면 비례 메트릭은 클릭한 뒤에만 확인하며, UI 밝기·도형 구성 도구 색상·백그라운드 저장과 내보내기는 바꿀 수 없습니다."
        ]
        installMenus()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu(); menu.delegate = self
        stateItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: ""); stateItem.isEnabled = false
        menu.addItem(.separator())
        add(menu, L("pause"), #selector(togglePause))
        menu.addItem(.separator())
        add(menu, L("bright.menuUp"), #selector(brighter))
        add(menu, L("bright.menuDown"), #selector(darker))
        add(menu, L("shape.menuSwatches"), #selector(shapeSwatches))
        add(menu, L("shape.menuArtwork"), #selector(shapeArtwork))
        add(menu, L("bg.menu"), #selector(turnOffBackground))
        menu.addItem(.separator())
        add(menu, L("palette.menu"), #selector(showUnitPalette))
        add(menu, L("quick.menu"), #selector(showQuickPalette))
        add(menu, L("openMainWindow"), #selector(showMain))
        add(menu, L("settings"), #selector(showPreferences))
        let help = NSMenu(title: L("help")); add(help, L("helpItem"), #selector(showHelp)); HelpLinks.addNoteItem(to: help)
        menu.setSubmenu(help, for: menu.addItem(withTitle: L("help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(withTitle: L("quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "").target = NSApp
        item.menu = menu
        MenuBarPresence.shared.install(name: "VectorMate", symbol: "textformat", existing: item,
            show: { [weak self] in self?.showMain() },
            settings: { [weak self] in self?.showPreferences() },
            help: { [weak self] in self?.showHelp() })
        model.onChange = { [weak self] in self?.updateStatusItem() }
        model.onPaletteHotkey = { [weak self] in self?.unitPalette.toggle() }
        model.onQuickHotkey = { [weak self] in self?.quickPalette.toggle() }
        model.onLaunchHotkey = { [weak self] in self?.showMain() }
        SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings() }
        SettingsSync.shared.start(.init(keys: Model.sharedKeys, prefixes: [],
            note: StartupWindow.text("メトリクスの設定・ホットキー・単位セット・単位パレットのモードを書き出し・同期します。",
                                     "Exports and syncs the Metrics options, the hotkeys, the unit sets and the Units Palette mode.",
                                     "导出并同步度量标准设置、快捷键、单位组合和单位面板的模式。",
                                     "메트릭 설정, 단축키, 단위 세트, 단위 팔레트 모드를 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・常駐・メニューバーのアイコンはMacごとに設定します。",
                                       "Open at login, staying in the background and the menu bar icon are set on each Mac.",
                                       "登录时启动、保持运行和菜单栏图标在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 백그라운드 유지, 메뉴 막대 아이콘은 Mac마다 설정합니다.")))
        updateStatusItem()
        if !loginLaunch && !StartupWindow.hidden { showMain() }
    }

    func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "") {
        menu.addItem(withTitle: title, action: action, keyEquivalent: key).target = self
    }

    func updateStatusItem() {
        let image = NSImage(systemSymbolName: model.watching ? "textformat" : "pause.circle", accessibilityDescription: model.watchStatus)
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        item?.button?.image = image
        item?.button?.toolTip = "VectorMate — " + model.watchStatus
        stateItem?.title = model.watchStatus
    }

    func installMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        func submenu(_ name: String) -> NSMenu { let item = NSMenuItem(); let menu = NSMenu(title: name); item.submenu = menu; bar.addItem(item); return menu }
        func add(_ m: NSMenu, _ title: String, _ sel: Selector, _ key: String = "", _ target: AnyObject? = nil) { m.addItem(withTitle: title, action: sel, keyEquivalent: key).target = target ?? self }
        let app = submenu("VectorMate")
        add(app, L("about"), #selector(about)); app.addItem(.separator())
        // MenuBarPresence inserts メニューバー設定… between these separators.
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
        add(file, L("palette.menu"), #selector(showUnitPalette))
        add(file, L("quick.menu"), #selector(showQuickPalette))
        file.addItem(.separator())
        add(file, L("bg.menu"), #selector(turnOffBackground))
        file.addItem(.separator())
        add(file, L("close"), #selector(NSWindow.performClose(_:)), "w"); file.items.last?.target = nil
        let edit = submenu(L("edit"))
        for (key, selector, letter) in [("undo", "undo:", "z"), ("redo", "redo:", "Z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("paste", "paste:", "v"), ("selectAll", "selectAll:", "a")] {
            edit.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: letter).target = nil
            if key == "redo" { edit.addItem(.separator()) }
        }
        let window = submenu(L("window"))
        for (key, selector) in [("minimize", "performMiniaturize:"), ("zoom", "performZoom:")] { window.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: "").target = nil }
        window.addItem(.separator())
        window.addItem(withTitle: L("bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "").target = NSApp
        NSApp.windowsMenu = window
        let help = submenu(L("help")); add(help, L("helpItem"), #selector(showHelp), "?"); HelpLinks.addNoteItem(to: help); NSApp.helpMenu = help
    }

    func menuWillOpen(_ menu: NSMenu) { model.refreshPermission(); updateStatusItem() }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(togglePause) { menuItem.state = model.paused ? .on : .off; return model.metricsEnabled }
        let settingsActions: [Selector] = [#selector(turnOffBackground), #selector(brighter), #selector(darker), #selector(shapeSwatches), #selector(shapeArtwork)]
        if let action = menuItem.action, settingsActions.contains(action) { return !model.busy }
        return true
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        model.refreshPermission()
        if mainWindow?.isVisible == true { model.refreshSettingsState() }
        // ⌘Tab sends no reopen event: with no window on screen, bring one back. Checked on the next turn of the run loop,
        // so a window this app is opening itself (設定…, ヘルプ) counts.
        DispatchQueue.main.async { [weak self] in
            // The activation that comes with launching respects 起動時にメインウインドウを表示しない.
            guard let self, NSApp.isActive, !(StartupWindow.hidden && Date().timeIntervalSince(self.launchedAt) < 2) else { return }
            let windows = NSApp.windows.filter { !($0 is NSPanel) && $0.canBecomeMain && $0.styleMask.contains(.titled) }
            guard !windows.contains(where: { $0.isVisible }), !self.unitPalette.isVisible, !self.quickPalette.isVisible else { return }
            if let minimized = windows.first(where: { $0.isMiniaturized }) { minimized.deminiaturize(nil) } else { self.showMain() }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMain(); return true }
    /// Watching needs the app to keep running; with 常駐 off, closing the main window quits.
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === mainWindow, !model.keepRunning else { return }
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }
    func applicationWillTerminate(_ notification: Notification) { model.stop() }

    @objc func togglePause() { model.paused.toggle() }
    @objc func showUnitPalette() { unitPalette.show() }
    @objc func showQuickPalette() { quickPalette.show() }
    @objc func turnOffBackground() { model.turnOffBackground() }
    @objc func brighter() { model.stepBrightness(1) }
    @objc func darker() { model.stepBrightness(-1) }
    @objc func shapeSwatches() { model.setShapeSource(.swatches) }
    @objc func shapeArtwork() { model.setShapeSource(.artwork) }

    @objc func showMain() {
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            // Native title bar unchanged; no app name in it.
            window.title = ""; window.titleVisibility = .hidden
            let hosting = NSHostingView(rootView: MainView(model: model))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("VectorMateMain")
            mainWindow = window
        }
        if let window = mainWindow, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        model.refreshPermission(); model.refreshSettingsState()
        NSApp.activate(ignoringOtherApps: true); mainWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func showPreferences() { openPreferences(tab: nil) }
    /// Opens 設定 on the tab with this title (the 「ホットキーを設定…」 button of 基本UI).
    func openPreferences(tab: String?) {
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle"); window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: Preferences(model: model))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting; window.center(); window.setFrameAutosaveName("VectorMateSettings")
            preferences = window
        }
        if let window = preferences, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
        // The tab view (SettingsTabs) exists once the window has laid out its SwiftUI content.
        if let tab {
            DispatchQueue.main.async { [weak self] in
                guard let tabs = self?.preferences?.contentView.flatMap(Self.tabView),
                      let item = tabs.tabViewItems.first(where: { ($0.identifier as? String) == tab }) else { return }
                tabs.selectTabViewItem(item)
            }
        }
    }
    private static func tabView(_ view: NSView) -> NSTabView? {
        if let tabs = view as? NSTabView { return tabs }
        for sub in view.subviews { if let found = tabView(sub) { return found } }
        return nil
    }
    @objc func showHelp() {
        if helpWindow == nil { helpWindow = HelpDocument.makeWindow(windowTitle: "VectorMate — " + L("help"), text: L("helpContent")) }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: NSAttributedString(string: L("support"))])
    }
}

let app = NSApplication.shared
SingleInstanceLaunch.enforce()
LegacySettings.migrate()
let delegate = MainActor.assumeIsolated { AppDelegate() }
// Always in the app switcher (⌘Tab) and the Dock, even with no window open.
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()

// Same as SpreadsheetHelper (KakkoReplace / BrowserSwitcher origin). Oldest process wins on simultaneous launch.
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

/// Renamed from AiHelper (jp.dtp-transit.aihelper) in 2.0.0 with a new Bundle ID: its settings are copied once, never
/// overwriting newer ones, and its hotkey declaration for HotkeyHound / KageTrimmer is removed.
/// Accessibility, Automation and login launch belong to the Bundle ID and have to be granted again.
enum LegacySettings {
    static let oldDomain = "jp.dtp-transit.aihelper" as CFString
    static let doneKey = "migratedFromAiHelper"
    static func migrate() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        defaults.set(true, forKey: doneKey)
        if let keys = CFPreferencesCopyKeyList(oldDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] {
            for key in keys where defaults.object(forKey: key) == nil {
                if let value = CFPreferencesCopyAppValue(key as CFString, oldDomain) { defaults.set(value, forKey: key) }
            }
        }
        try? FileManager.default.removeItem(at: HotkeyManifest.folder.appendingPathComponent("jp.dtp-transit.aihelper.json"))
    }
}
