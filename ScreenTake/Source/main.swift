import AppKit
import SwiftUI
import Carbon
import AVFoundation
import Combine

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// One saved recording in the recordings folder.
struct RecordingEntry: Identifiable, Equatable {
    let folder: URL
    let created: Date
    let duration: Double
    var id: String { folder.path }
    var name: String { folder.lastPathComponent }
}

/// A choice in the 収録する範囲 menu.
struct TargetChoice: Hashable, Identifiable {
    let target: RecordOptions.Target
    let title: String
    var id: String { switch target { case .display(let id): return "d\(id)"; case .window(let id): return "w\(id)" } }
    static func == (a: TargetChoice, b: TargetChoice) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor final class Model: ObservableObject {
    private let defaults = UserDefaults.standard

    // MARK: Settings
    @Published var systemAudio = UserDefaults.standard.object(forKey: "systemAudio") as? Bool ?? true { didSet { defaults.set(systemAudio, forKey: "systemAudio") } }
    @Published var microphoneOn = UserDefaults.standard.object(forKey: "microphoneOn") as? Bool ?? true { didSet { defaults.set(microphoneOn, forKey: "microphoneOn") } }
    /// Per Mac (device IDs differ). Empty: the system default.
    @Published var microphoneID = UserDefaults.standard.string(forKey: "microphoneID") ?? "" { didSet { defaults.set(microphoneID, forKey: "microphoneID") } }
    @Published var cameraOn = UserDefaults.standard.bool(forKey: "cameraOn") { didSet { defaults.set(cameraOn, forKey: "cameraOn") } }
    @Published var cameraID = UserDefaults.standard.string(forKey: "cameraID") ?? "" { didSet { defaults.set(cameraID, forKey: "cameraID") } }
    @Published var showCursor = UserDefaults.standard.object(forKey: "showCursor") as? Bool ?? true { didSet { defaults.set(showCursor, forKey: "showCursor") } }
    @Published var fps = UserDefaults.standard.object(forKey: "fps") as? Int ?? 30 { didSet { defaults.set(fps, forKey: "fps") } }
    @Published var countdownSeconds = UserDefaults.standard.object(forKey: "countdown") as? Int ?? 3 { didSet { defaults.set(countdownSeconds, forKey: "countdown") } }
    @Published var openEditorAfter = UserDefaults.standard.object(forKey: "openEditorAfter") as? Bool ?? true { didSet { defaults.set(openEditorAfter, forKey: "openEditorAfter") } }
    /// Per Mac (a path). Empty means ~/Movies/ScreenTake.
    @Published var folderPath = UserDefaults.standard.string(forKey: "recordingsFolder") ?? "" { didSet { defaults.set(folderPath, forKey: "recordingsFolder"); loadRecordings() } }
    var folder: URL { folderPath.isEmpty ? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/ScreenTake", isDirectory: true) : URL(fileURLWithPath: folderPath, isDirectory: true) }

    nonisolated static let sharedKeys: Set<String> = ["systemAudio", "microphoneOn", "cameraOn", "showCursor", "fps", "countdown", "openEditorAfter", "recordHotkeyEnabled", "recordHotkey", "exportFormat", "exportSize", "exportHEVC"]
    func reloadSharedSettings() {
        systemAudio = defaults.object(forKey: "systemAudio") as? Bool ?? true
        microphoneOn = defaults.object(forKey: "microphoneOn") as? Bool ?? true
        cameraOn = defaults.bool(forKey: "cameraOn")
        showCursor = defaults.object(forKey: "showCursor") as? Bool ?? true
        fps = defaults.object(forKey: "fps") as? Int ?? 30
        countdownSeconds = defaults.object(forKey: "countdown") as? Int ?? 3
        openEditorAfter = defaults.object(forKey: "openEditorAfter") as? Bool ?? true
        recordHotkeyEnabled = defaults.object(forKey: "recordHotkeyEnabled") as? Bool ?? true
        recordCombo = Model.readCombo("recordHotkey", default: Model.defaultRecordCombo)
    }

    // MARK: Hotkeys
    /// ⌃⌥⇧⌘6 (2026-10-26): not used by Keyboard Maestro (⌃⌥⇧⌘5 and R are) or the other sw_apps.
    static let defaultRecordCombo = KeyCombo(code: UInt32(kVK_ANSI_6), modifiers: KeyCombo.control | KeyCombo.option | KeyCombo.shift | KeyCombo.command)
    static let recordFieldID = "recordHotkey", appFieldID = "appHotkey"
    static func readCombo(_ key: String, default value: KeyCombo?) -> KeyCombo? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return value }
        return data.isEmpty ? nil : try? JSONDecoder().decode(KeyCombo.self, from: data)
    }
    private func writeCombo(_ combo: KeyCombo?, _ key: String) { defaults.set(combo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: key) }
    @Published var recordHotkeyEnabled = UserDefaults.standard.object(forKey: "recordHotkeyEnabled") as? Bool ?? true { didSet { defaults.set(recordHotkeyEnabled, forKey: "recordHotkeyEnabled"); registerHotkeys() } }
    @Published var recordCombo = Model.readCombo("recordHotkey", default: Model.defaultRecordCombo) { didSet { writeCombo(recordCombo, "recordHotkey"); registerHotkeys() } }
    @Published var appHotkeyEnabled = UserDefaults.standard.object(forKey: "appHotkeyEnabled") as? Bool ?? true { didSet { defaults.set(appHotkeyEnabled, forKey: "appHotkeyEnabled"); registerHotkeys() } }
    @Published var appCombo = Model.readCombo("appHotkey", default: nil) { didSet { writeCombo(appCombo, "appHotkey"); registerHotkeys() } }
    @Published var recordHotkeyRegistered = true
    @Published var appHotkeyRegistered = true
    let hotkeys = HotkeySet(signature: "ScTk")
    enum HotkeyID: UInt32 { case app = 1, record = 2 }
    func registerHotkeys() {
        hotkeys.unregisterAll()
        recordHotkeyRegistered = true; appHotkeyRegistered = true
        if recordHotkeyEnabled, let recordCombo { recordHotkeyRegistered = hotkeys.register(HotkeyID.record.rawValue, recordCombo) == noErr }
        if appHotkeyEnabled, let appCombo { appHotkeyRegistered = hotkeys.register(HotkeyID.app.rawValue, appCombo) == noErr }
        var items: [HotkeyManifest.Item] = []
        if let recordCombo { items.append(.init(id: "recordHotkey", title: L("recordHotkey"), keyCode: Int(recordCombo.code), modifiers: Int(recordCombo.modifiers), enabled: recordHotkeyEnabled)) }
        if let appCombo { items.append(.init(id: "appHotkey", title: SettingsUI.shortcutTitle, keyCode: Int(appCombo.code), modifiers: Int(appCombo.modifiers), enabled: appHotkeyEnabled)) }
        HotkeyManifest.publish(items)
    }

    // MARK: Sources
    @Published var targets: [TargetChoice] = []
    @Published var target: TargetChoice?
    @Published var microphones: [AVCaptureDevice] = []
    @Published var cameras: [AVCaptureDevice] = []
    func refreshSources() {
        var choices: [TargetChoice] = NSScreen.screens.compactMap { screen in
            guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { return nil }
            return TargetChoice(target: .display(id), title: String(format: L("displayChoice"), screen.localizedName))
        }
        // Normal windows of other apps. Titles need Screen Recording; without it the app name is shown.
        let own = ProcessInfo.processInfo.processIdentifier
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for info in windows where info[kCGWindowLayer as String] as? Int == 0 && info[kCGWindowOwnerPID as String] as? Int32 != own {
            guard let number = info[kCGWindowNumber as String] as? UInt32, let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds), rect.width >= 100, rect.height >= 60 else { continue }
            let app = info[kCGWindowOwnerName as String] as? String ?? "?"
            let title = (info[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 }
            choices.append(TargetChoice(target: .window(number), title: title.map { "\(app) — \($0)" } ?? app))
        }
        targets = choices
        if target == nil || !choices.contains(target!) { target = choices.first }
        microphones = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified).devices
        cameras = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera], mediaType: .video, position: .unspecified).devices
    }

    // MARK: Recording
    enum Phase: Equatable { case idle, countdown(Int), recording, paused, finishing }
    @Published var phase = Phase.idle
    @Published var elapsed = 0.0
    @Published var status = ""
    @Published var failed = false
    @Published var screenPermitted = CGPreflightScreenCaptureAccess()
    private var recorder: Recorder?
    private let pointer = PointerLog()
    private var timer: Timer?
    private var startedAt = 0.0
    private var pausedTotal = 0.0
    private var pausedAt: Double?
    /// Opens a finished recording in the editor (set by the app delegate).
    var onFinished: ((URL) -> Void)?
    var onPhaseChange: (() -> Void)?
    var isBusy: Bool { phase != .idle }

    func toggleRecording() {
        switch phase {
        case .idle: start()
        case .countdown: cancelCountdown()
        case .recording, .paused: stop()
        case .finishing: break
        }
    }

    func start() {
        guard phase == .idle else { return }
        refreshSources()
        screenPermitted = CGPreflightScreenCaptureAccess()
        guard screenPermitted else {
            // The system prompt shows the first time only; later the reason and the way to System Settings stay in the window.
            CGRequestScreenCaptureAccess()
            report(L("needScreenPermission"), failed: true); return
        }
        guard let target else { report(L("noTarget"), failed: true); return }
        Task {
            if microphoneOn, !(await Model.allow(.audio)) { report(L("needMicPermission"), failed: true); return }
            if cameraOn, !(await Model.allow(.video)) { report(L("needCameraPermission"), failed: true); return }
            countdown(from: countdownSeconds, target: target.target)
        }
    }
    static func allow(_ type: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: type)
        default: return false
        }
    }
    private func countdown(from seconds: Int, target: RecordOptions.Target) {
        status = ""; failed = false
        guard seconds > 0 else { begin(target); return }
        phase = .countdown(seconds); onPhaseChange?()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, case .countdown(let left) = self.phase else { return }
                if left > 1 { self.phase = .countdown(left - 1); self.onPhaseChange?() }
                else { self.timer?.invalidate(); self.timer = nil; self.begin(target) }
            }
        }
    }
    func cancelCountdown() {
        guard case .countdown = phase else { return }
        timer?.invalidate(); timer = nil
        phase = .idle; onPhaseChange?()
        report(L("recordCanceled"), failed: false)
    }

    private func begin(_ target: RecordOptions.Target) {
        let mic = microphoneOn ? (microphones.first { $0.uniqueID == microphoneID } ?? AVCaptureDevice.default(for: .audio))?.uniqueID : nil
        let camera = cameraOn ? (cameras.first { $0.uniqueID == cameraID } ?? AVCaptureDevice.default(for: .video))?.uniqueID : nil
        let options = RecordOptions(target: target, systemAudio: systemAudio, microphoneID: mic, cameraID: camera, showCursor: showCursor, fps: fps)
        let recorder = Recorder(folder: uniqueFolder(), options: options)
        recorder.onStreamError = { [weak self] reason in
            guard let self, self.phase == .recording || self.phase == .paused else { return }
            self.stop(reason: reason)
        }
        self.recorder = recorder
        phase = .finishing; onPhaseChange?()
        Task {
            do {
                try await recorder.start()
                pointer.start(recorder)
                startedAt = hostNow(); pausedTotal = 0; pausedAt = nil; elapsed = 0
                phase = .recording; onPhaseChange?()
                timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.tick() }
                }
            } catch {
                self.recorder = nil
                try? FileManager.default.removeItem(at: recorder.folder)
                phase = .idle; onPhaseChange?()
                report(Model.message(error), failed: true)
            }
        }
    }
    private func tick() {
        let paused = pausedAt.map { hostNow() - $0 } ?? 0
        elapsed = hostNow() - startedAt - pausedTotal - paused
    }
    func togglePause() {
        guard let recorder else { return }
        if phase == .recording { recorder.pause(); pausedAt = hostNow(); phase = .paused }
        else if phase == .paused { recorder.resume(); pausedTotal += hostNow() - (pausedAt ?? hostNow()); pausedAt = nil; phase = .recording }
        onPhaseChange?()
    }

    func stop(reason: String? = nil) {
        guard let recorder, phase == .recording || phase == .paused else { return }
        timer?.invalidate(); timer = nil
        phase = .finishing; onPhaseChange?()
        Task {
            defer { self.recorder = nil; phase = .idle; onPhaseChange?(); finishWaiters.forEach { $0() }; finishWaiters = [] }
            do {
                let length = try await recorder.stop()
                let (cursor, shapes) = pointer.stop(saveIn: recorder.folder)
                var info = RecordingInfo(duration: length, width: Int(recorder.pixelSize.width), height: Int(recorder.pixelSize.height), fps: recorder.options.fps,
                                         hasCamera: recorder.options.cameraID != nil, hasSystemAudio: recorder.options.systemAudio,
                                         hasMicrophone: recorder.options.microphoneID != nil, cursor: cursor)
                info.pixelsPerPoint = recorder.pixelsPerPoint
                info.cursorShapes = shapes
                info.edits.showCursor = recorder.options.showCursor
                if info.cursor.samples.isEmpty { info.edits.highlightClicks = false }
                let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(info).write(to: recorder.folder.appendingPathComponent("project.json"), options: .atomic)
                loadRecordings()
                let text = String(format: L("recorded"), recorder.folder.lastPathComponent, timecode(length, tenths: false))
                report(reason.map { text + " " + String(format: L("stoppedBecause"), $0) } ?? text, failed: reason != nil)
                if openEditorAfter { onFinished?(recorder.folder) }
            } catch {
                _ = pointer.stop(saveIn: recorder.folder)
                // Nothing usable: do not leave a broken recording behind.
                try? FileManager.default.removeItem(at: recorder.folder)
                report(Model.message(error), failed: true)
                loadRecordings()
            }
        }
    }
    /// Quitting while recording waits for the movie to close.
    var finishWaiters: [() -> Void] = []

    static func message(_ error: Error) -> String {
        switch error {
        case RecordError.permission: return L("needScreenPermission")
        case RecordError.noTarget: return L("noTarget")
        case RecordError.failed(let reason): return String(format: L("recordFailed"), reason)
        default: return String(format: L("recordFailed"), error.localizedDescription)
        }
    }
    private func uniqueFolder() -> URL {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd H.mm.ss"
        let base = "\(L("filePrefix")) \(formatter.string(from: Date()))"
        var url = folder.appendingPathComponent(base, isDirectory: true), number = 2
        while FileManager.default.fileExists(atPath: url.path) { url = folder.appendingPathComponent("\(base) \(number)", isDirectory: true); number += 1 }
        return url
    }
    func report(_ text: String, failed: Bool) { status = text; self.failed = failed }

    // MARK: Recordings
    @Published var recordings: [RecordingEntry] = []
    @Published var selectedRecording: String?
    func loadRecordings() {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let folders = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        recordings = folders.compactMap { url in
            guard let data = try? Data(contentsOf: url.appendingPathComponent("project.json")),
                  let info = try? decoder.decode(RecordingInfo.self, from: data) else { return nil }
            return RecordingEntry(folder: url, created: info.created, duration: Timeline.outputDuration(Timeline.kept(duration: info.duration, removed: info.edits.removed)))
        }.sorted { $0.created > $1.created }
    }
    func trash(_ entry: RecordingEntry) {
        let alert = NSAlert()
        alert.messageText = String(format: L("trashConfirm"), entry.name)
        alert.informativeText = L("trashDetail")
        alert.addButton(withTitle: L("moveToTrash")); alert.addButton(withTitle: L("cancel"))
        alert.buttons[1].keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do { try FileManager.default.trashItem(at: entry.folder, resultingItemURL: nil); report(String(format: L("trashed"), entry.name), failed: false) }
        catch { report(String(format: L("trashFailed"), error.localizedDescription), failed: true) }
        loadRecordings()
    }
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.directoryURL = folder; panel.prompt = L("choose")
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url { folderPath = url.path }
    }
}

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

struct MainView: View {
    @ObservedObject var model: Model
    var open: (URL) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 4) { Text(L("heading")).font(.system(size: 22, weight: .semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text(L("targetLabel")).gridColumnAlignment(.trailing)
                    HStack {
                        Picker(L("targetLabel"), selection: $model.target) {
                            ForEach(model.targets) { Text($0.title).lineLimit(1).tag(Optional($0)) }
                        }.labelsHidden().frame(maxWidth: 360)
                        Button { model.refreshSources() } label: { Image(systemName: "arrow.clockwise") }.help(L("refresh")).accessibilityLabel(L("refresh"))
                    }
                }
                GridRow {
                    Text(L("audioLabel"))
                    HStack(spacing: 14) {
                        Toggle(L("systemAudio"), isOn: $model.systemAudio)
                        Toggle(L("microphone"), isOn: $model.microphoneOn)
                        Picker(L("microphone"), selection: $model.microphoneID) {
                            Text(L("systemDefault")).tag("")
                            ForEach(model.microphones, id: \.uniqueID) { Text($0.localizedName).tag($0.uniqueID) }
                        }.labelsHidden().frame(maxWidth: 200).disabled(!model.microphoneOn)
                    }
                }
                GridRow {
                    Text(L("cameraLabel"))
                    HStack(spacing: 14) {
                        Toggle(L("cameraOn"), isOn: $model.cameraOn)
                        Picker(L("cameraLabel"), selection: $model.cameraID) {
                            Text(L("systemDefault")).tag("")
                            ForEach(model.cameras, id: \.uniqueID) { Text($0.localizedName).tag($0.uniqueID) }
                        }.labelsHidden().frame(maxWidth: 200).disabled(!model.cameraOn)
                    }
                }
                GridRow {
                    Text(L("pointerLabel"))
                    Toggle(L("showCursor"), isOn: $model.showCursor)
                }
            }.disabled(model.isBusy)
            HStack(spacing: 10) {
                switch model.phase {
                case .idle:
                    Button(model.countdownSeconds > 0 ? String(format: L("startAfter"), model.countdownSeconds) : L("start")) { model.start() }
                        .keyboardShortcut(.defaultAction).controlSize(.large)
                case .countdown(let left):
                    Button(String(format: L("cancelCountdown"), left)) { model.cancelCountdown() }.keyboardShortcut(.cancelAction).controlSize(.large)
                case .recording, .paused:
                    Button(L("stop")) { model.stop() }.keyboardShortcut(.defaultAction).controlSize(.large)
                    Button(L(model.phase == .paused ? "resume" : "pause")) { model.togglePause() }.controlSize(.large)
                    Text(timecode(model.elapsed, tenths: false)).monospacedDigit().font(.title3)
                case .finishing:
                    ProgressView().controlSize(.small)
                }
                if model.recordHotkeyEnabled, let combo = model.recordCombo {
                    Text(String(format: L("hotkeyHint"), combo.label)).font(.callout).foregroundColor(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if model.failed { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange).accessibilityHidden(true) }
                Text(model.status.isEmpty ? " " : model.status).font(.callout).foregroundColor(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                if model.failed && !model.screenPermitted { Button(L("openScreenRecording")) { PermissionsSection.open("Privacy_ScreenCapture") }.font(.callout) }
            }
            Text(L("recordingsTitle")).font(.headline)
            List(selection: $model.selectedRecording) {
                ForEach(model.recordings) { entry in
                    HStack {
                        Image(systemName: "film").foregroundColor(.secondary).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name).lineLimit(1)
                            Text(timecode(entry.duration, tenths: false)).font(.caption).foregroundColor(.secondary).monospacedDigit()
                        }
                        Spacer()
                        Button(L("edit")) { open(entry.folder) }
                    }
                    .tag(entry.id)
                    .contextMenu {
                        Button(L("edit")) { open(entry.folder) }
                        Button(L("revealInFinder")) { FileReveal.reveal(entry.folder) }
                        Divider()
                        Button(L("moveToTrash")) { model.trash(entry) }
                    }
                    .onTapGesture(count: 2) { open(entry.folder) }
                }
            }
            .frame(minHeight: 160)
            .overlay { if model.recordings.isEmpty { Text(L("noRecordings")).foregroundColor(.secondary).multilineTextAlignment(.center).padding() } }
            .cornerRadius(6)
        }.padding(20)
        .frame(minWidth: 600, minHeight: 560, alignment: .top).background(Color(nsColor: AppSurface.color)).tint(appTint)
        .onAppear { model.refreshSources(); model.loadRecordings() }
    }
}

/// The countdown, elapsed time and controls in the menu bar while recording. No window floats over the screen being recorded.
/// Separate from the MenuBarPresence icon, so it also shows when that icon is turned off.
@MainActor final class RecordingStatusItem: NSObject, NSMenuDelegate {
    private var item: NSStatusItem?
    private weak var model: Model?
    private var observers: [AnyCancellable] = []

    func attach(_ model: Model) {
        self.model = model
        observers = [model.$phase.sink { [weak self] _ in DispatchQueue.main.async { self?.refresh() } },
                     model.$elapsed.sink { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }]
    }
    private func refresh() {
        guard let model else { return }
        guard model.phase != .idle else {
            if let item { NSStatusBar.system.removeStatusItem(item) }
            item = nil; return
        }
        if item == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            let menu = NSMenu(); menu.delegate = self; item.menu = menu
            self.item = item
        }
        guard let button = item?.button else { return }
        let symbol: String, color: NSColor, title: String
        switch model.phase {
        case .countdown(let left): symbol = "timer"; color = .labelColor; title = " \(left)"
        case .paused: symbol = "pause.circle.fill"; color = .secondaryLabelColor; title = " " + timecode(model.elapsed, tenths: false)
        case .finishing: symbol = "hourglass"; color = .labelColor; title = ""
        default: symbol = "record.circle.fill"; color = .systemRed; title = " " + timecode(model.elapsed, tenths: false)
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .regular).applying(.init(paletteColors: [color])))
        button.image = image; button.imagePosition = .imageLeading
        button.attributedTitle = NSAttributedString(string: title, attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)])
        let label: String
        switch model.phase {
        case .countdown(let left): label = String(format: L("hudCountdown"), left)
        case .finishing: label = L("finishing")
        case .paused: label = L("pausedLabel") + " " + timecode(model.elapsed, tenths: false)
        default: label = L("recordingLabel") + " " + timecode(model.elapsed, tenths: false)
        }
        button.toolTip = label; button.setAccessibilityLabel(label)
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let model else { return }
        func add(_ title: String, _ action: Selector) { menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = self }
        switch model.phase {
        case .countdown: add(L("cancelRecording"), #selector(cancel))
        case .recording, .paused:
            add(L("stopRecording"), #selector(stop))
            add(L(model.phase == .paused ? "resume" : "pause"), #selector(pause))
        default: menu.addItem(withTitle: L("finishing"), action: nil, keyEquivalent: "")
        }
        if model.recordHotkeyEnabled, let combo = model.recordCombo {
            menu.addItem(.separator())
            menu.addItem(withTitle: String(format: L("hotkeyHint"), combo.label), action: nil, keyEquivalent: "").isEnabled = false
        }
    }
    @objc private func stop() { model?.stop() }
    @objc private func pause() { model?.togglePause() }
    @objc private func cancel() { model?.cancelCountdown() }
}

/// 「権限」 group of the 起動・常駐 tab. Checking never prompts.
struct PermissionsSection: View {
    @ObservedObject var model: Model
    @State private var mic = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var camera = AVCaptureDevice.authorizationStatus(for: .video)
    static func open(_ pane: String) { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!) }
    private func row(_ title: String, _ ok: Bool, _ pane: String, required: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundColor(ok ? .green : (required ? .red : .secondary)).accessibilityHidden(true)
            Text(title); Text(L(ok ? "permitted" : "notPermitted")).foregroundColor(.secondary)
            Spacer()
            Button(L("openSettings")) { PermissionsSection.open(pane) }
        }
    }
    var body: some View {
        SettingsSection(L("permissions")) {
            VStack(alignment: .leading, spacing: 8) {
                row(L("screenRecording"), model.screenPermitted, "Privacy_ScreenCapture", required: true)
                row(L("microphone"), mic == .authorized, "Privacy_Microphone", required: false)
                row(L("camera"), camera == .authorized, "Privacy_Camera", required: false)
                Text(L("permissionsReason")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
        .onAppear { refresh() }
    }
    private func refresh() {
        model.screenPermitted = CGPreflightScreenCaptureAccess()
        mic = AVCaptureDevice.authorizationStatus(for: .audio); camera = AVCaptureDevice.authorizationStatus(for: .video)
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
                    HotkeyField(id: Model.appFieldID, combo: $model.appCombo, allowsClear: true,
                                others: model.recordCombo.map { [(L("recordHotkey"), $0)] } ?? [],
                                registered: model.appHotkeyRegistered, isEnabled: model.appHotkeyEnabled)
                    Text(L("appHotkeyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            PermissionsSection(model: model)
        })), (L("recordTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("recordHotkey")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(HotkeyText.enable, isOn: $model.recordHotkeyEnabled)
                    HotkeyField(id: Model.recordFieldID, combo: $model.recordCombo, defaultCombo: Model.defaultRecordCombo, allowsClear: true,
                                others: model.appCombo.map { [(SettingsUI.shortcutTitle, $0)] } ?? [],
                                registered: model.recordHotkeyRegistered, isEnabled: model.recordHotkeyEnabled)
                    Text(L("recordHotkeyDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("countdownTitle")) {
                VStack(alignment: .leading, spacing: 6) {
                    Stepper(value: $model.countdownSeconds, in: 0...10) { Text(String(format: L("seconds"), model.countdownSeconds)).monospacedDigit() }.fixedSize()
                    Text(L("countdownDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("qualityTitle")) {
                VStack(alignment: .leading, spacing: 6) {
                    Picker(L("frameRate"), selection: $model.fps) { Text("30 fps").tag(30); Text("60 fps").tag(60) }.pickerStyle(.radioGroup)
                    Text(L("frameRateDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.disabled(model.isBusy))), (L("outputTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("folderTitle")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.folder.path).font(.callout).textSelection(.enabled).lineLimit(2).truncationMode(.middle)
                    HStack {
                        Button(L("chooseFolder")) { model.chooseFolder() }
                        Button(L("showFolder")) { try? FileManager.default.createDirectory(at: model.folder, withIntermediateDirectories: true); NSWorkspace.shared.open(model.folder) }
                        Button(L("resetFolder")) { model.folderPath = "" }.disabled(model.folderPath.isEmpty)
                    }
                    Text(L("folderDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("afterRecording")) {
                Toggle(L("openEditorAfter"), isOn: $model.openEditorAfter).frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())), (AboutSection.title, AnyView(AboutView()))]).frame(minWidth: 560, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
    }
}

@MainActor final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    let model = Model()
    let recordingItem = RecordingStatusItem()
    var window: NSWindow!
    var settings: NSWindow?
    var helpWindow: NSWindow?
    var editorWindow: NSWindow?
    var editor: EditorModel?
    var isDuplicate = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        UserDefaults.standard.register(defaults: ["resident": true])
        if let id = Bundle.main.bundleIdentifier, let other = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            isDuplicate = true
            other.activate(options: [.activateAllWindows])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        guard !isDuplicate else { return }
        buildMenus()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 620), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "ScreenTake"; window.titleVisibility = .hidden
        let host = NSHostingView(rootView: MainView(model: model) { [weak self] url in self?.openEditor(url) })
        host.sizingOptions = [.minSize]
        window.contentView = host
        window.delegate = self; window.isReleasedWhenClosed = false
        if UserDefaults.standard.string(forKey: "NSWindow Frame MainWindow") == nil { window.center() }
        window.setFrameAutosaveName("MainWindow"); window.minSize = NSSize(width: 600, height: 560)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        model.hotkeys.action = { [weak self] number in
            switch Model.HotkeyID(rawValue: number) {
            case .app: StartupWindow.userRequestedWindow(); self?.show()
            case .record: self?.model.toggleRecording()
            case nil: break
            }
        }
        model.registerHotkeys()
        model.onFinished = { [weak self] url in self?.openEditor(url) }
        recordingItem.attach(model)
        model.onPhaseChange = { [weak self] in
            guard let self else { return }
            // Out of the way while recording; back afterwards.
            if model.phase == .recording, window.isVisible { window.miniaturize(nil) }
        }
        MenuBarPresence.shared.install(name: "ScreenTake", symbol: "record.circle", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() },
                                       extraItems: { [weak self] in self?.recordItems() ?? [] })
        SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings() }
        SettingsSync.shared.start(.init(keys: Model.sharedKeys, prefixes: [],
            note: StartupWindow.text("収録のホットキー・カウントダウン・フレームレート・音声とカメラのオン／オフ・書き出しの形式を書き出し・同期します。",
                                     "Exports and syncs the record hotkey, countdown, frame rate, audio and camera on/off, and the export format.",
                                     "导出并同步录制快捷键、倒计时、帧率、音频和摄像头开关以及导出格式。",
                                     "녹화 단축키, 카운트다운, 프레임률, 오디오 및 카메라 켜기/끄기, 내보내기 형식을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("保存先・使う機器・ログイン時の起動・常駐・メニューバーの表示・アプリを呼び出すホットキーはMacごとに設定します。",
                                       "The save folder, devices, open at login, keep running, the menu bar icon and the show-app hotkey are set on each Mac.",
                                       "存储位置、设备、登录时启动、保持运行、菜单栏图标和显示应用快捷键在每台 Mac 上分别设置。",
                                       "저장 위치, 기기, 로그인 시 실행, 계속 실행, 메뉴 막대 아이콘, 앱 표시 단축키는 Mac마다 설정합니다.")))
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !login && !StartupWindow.suppressInitialWindow { show() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if editor?.exporting == true {
            let alert = NSAlert()
            alert.messageText = L("quitWhileExporting"); alert.informativeText = L("quitWhileExportingDetail")
            alert.addButton(withTitle: L("quitAnyway")); alert.addButton(withTitle: L("cancel"))
            alert.buttons[1].keyEquivalent = "\u{1b}"
            guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }
            editor?.cancelExport()
        }
        switch model.phase {
        case .countdown: model.cancelCountdown(); return .terminateNow
        case .recording, .paused, .finishing:
            // Close the movie first so the recording is kept.
            model.finishWaiters.append { NSApp.reply(toApplicationShouldTerminate: true) }
            model.onFinished = nil
            model.stop()
            return .terminateLater
        case .idle: return .terminateNow
        }
    }
    func applicationWillTerminate(_ notification: Notification) { editor?.close() }

    @objc func show() { guard let window else { return }; NSApp.activate(ignoringOtherApps: true); if window.isMiniaturized { window.deminiaturize(nil) }; window.makeKeyAndOrderFront(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        StartupWindow.userRequestedWindow(); show(); return true }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === window && !UserDefaults.standard.bool(forKey: "resident") && editorWindow == nil { NSApp.terminate(nil); return false }
        if sender === editorWindow, editor?.exporting == true {
            let alert = NSAlert()
            alert.messageText = L("closeWhileExporting"); alert.addButton(withTitle: L("stopExport")); alert.addButton(withTitle: L("cancel"))
            alert.buttons[1].keyEquivalent = "\u{1b}"
            guard alert.runModal() == .alertFirstButtonReturn else { return false }
        }
        return true
    }
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === editorWindow else { return }
        editor?.close(); editor = nil; editorWindow = nil
        model.loadRecordings()
    }
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? { window === editorWindow ? editor?.undo : nil }

    // MARK: Editor
    func openEditor(_ folder: URL) {
        if let editor, editor.folder == folder, let editorWindow { editorWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        if editor?.exporting == true { model.report(L("busyExporting"), failed: true); editorWindow?.makeKeyAndOrderFront(nil); return }
        editorWindow?.close()
        do {
            let editor = try EditorModel(folder: folder)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = editor.title
            let host = NSHostingView(rootView: EditorView(model: editor)); host.sizingOptions = [.minSize]
            window.contentView = host
            window.delegate = self; window.isReleasedWhenClosed = false
            if UserDefaults.standard.string(forKey: "NSWindow Frame EditorWindow") == nil { window.center() }
            window.setFrameAutosaveName("EditorWindow")
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
            self.editor = editor; editorWindow = window
            window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        } catch {
            model.report(String(format: L("openFailed"), error.localizedDescription), failed: true)
        }
    }
    @objc func openRecording() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.directoryURL = model.folder; panel.prompt = L("edit")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("project.json").path) else { model.report(L("notRecording"), failed: true); show(); return }
        openEditor(url)
    }

    @objc func quit() { NSApp.terminate(nil) }
    @objc func toggleRecording() { model.toggleRecording() }
    @objc func togglePause() { model.togglePause() }
    @objc func exportMovie() { editor?.export() }
    @objc func playPause() { editor?.togglePlay() }
    @objc func stepBack() { editor?.step(-1) }
    @objc func stepForward() { editor?.step(1) }
    @objc func cutSelection() { editor?.cutSelection() }
    @objc func trimStart() { editor?.trimStart() }
    @objc func trimEnd() { editor?.trimEnd() }
    @objc func addZoom() { editor?.addZoom() }

    func recordTitle() -> String {
        switch model.phase {
        case .idle: return L("startRecording")
        case .countdown: return L("cancelRecording")
        default: return L("stopRecording")
        }
    }
    func recordItems() -> [NSMenuItem] {
        let item = NSMenuItem(title: recordTitle(), action: #selector(toggleRecording), keyEquivalent: "")
        item.target = self; item.isEnabled = model.phase != .finishing
        item.image = NSImage(systemSymbolName: model.phase == .idle ? "record.circle" : "stop.circle", accessibilityDescription: nil)
        var items = [item]
        if model.phase == .recording || model.phase == .paused {
            let pause = NSMenuItem(title: L(model.phase == .paused ? "resume" : "pause"), action: #selector(togglePause), keyEquivalent: "")
            pause.target = self; items.append(pause)
        }
        return items
    }
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        let editorKey = editorWindow?.isKeyWindow == true && editor != nil
        switch item.action {
        case #selector(toggleRecording): item.title = recordTitle(); return model.phase != .finishing
        case #selector(togglePause): item.title = L(model.phase == .paused ? "resume" : "pause"); return model.phase == .recording || model.phase == .paused
        case #selector(exportMovie): return editorKey && editor?.exporting == false
        case #selector(cutSelection): return editorKey && editor?.canCut == true
        case #selector(playPause), #selector(stepBack), #selector(stepForward), #selector(trimStart), #selector(trimEnd), #selector(addZoom): return editorKey
        case #selector(openRecording): return !model.isBusy
        default: return true
        }
    }
    @objc func showSettings() {
        if settings == nil {
            settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 600), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            let hosting = NSHostingView(rootView: SettingsView(model: model)); hosting.sizingOptions = [.minSize]
            settings!.title = L("settingsWindow"); settings!.contentView = hosting; settings!.contentMinSize = NSSize(width: 560, height: 600); settings!.isReleasedWhenClosed = false; settings!.center()
        }
        settings!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let text = Bundle.main.url(forResource: "Help", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? L("help")
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "ScreenTake")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "ScreenTake", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
    }
    @discardableResult func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String, _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key); item.target = self; item.keyEquivalentModifierMask = modifiers; return item
    }
    func buildMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        let app = NSMenu(); let root = NSMenuItem(); root.submenu = app; bar.addItem(root)
        add(app, L("about"), #selector(about), ""); app.addItem(.separator())
        add(app, L("settings"), #selector(showSettings), ","); app.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to: app)
        #endif
        let services = NSMenu(title: L("services")); app.addItem(withTitle: L("services"), action: nil, keyEquivalent: "").submenu = services; NSApp.servicesMenu = services
        app.addItem(.separator())
        app.addItem(withTitle: L("hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: L("hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: L("showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator()); add(app, L("quit"), #selector(quit), "q")
        let file = NSMenu(title: L("fileMenu")); let fileItem = NSMenuItem(title: L("fileMenu"), action: nil, keyEquivalent: ""); fileItem.submenu = file; bar.addItem(fileItem)
        add(file, L("openMainWindow"), #selector(show), "0"); file.addItem(.separator())
        add(file, L("startRecording"), #selector(toggleRecording), "r", [.command, .shift])
        add(file, L("pause"), #selector(togglePause), "")
        file.addItem(.separator())
        add(file, L("openRecording"), #selector(openRecording), "o")
        add(file, L("exportMenu"), #selector(exportMovie), "e")
        file.addItem(.separator())
        file.addItem(withTitle: L("close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let edit = NSMenu(title: L("editMenu")); let editItem = NSMenuItem(title: L("editMenu"), action: nil, keyEquivalent: ""); editItem.submenu = edit; bar.addItem(editItem)
        for (key, action, shortcut) in [("undo", "undo:", "z"), ("redo", "redo:", "z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("paste", "paste:", "v"), ("selectAll", "selectAll:", "a")] {
            edit.addItem(withTitle: L(key), action: Selector(action), keyEquivalent: shortcut)
        }
        edit.item(at: 1)?.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        add(edit, L("deleteSelection"), #selector(cutSelection), "\u{7f}", [])
        add(edit, L("trimStart"), #selector(trimStart), "[", [.command])
        add(edit, L("trimEnd"), #selector(trimEnd), "]", [.command])
        add(edit, L("addZoom"), #selector(addZoom), "z", [.command, .option])
        let play = NSMenu(title: L("playMenu")); let playItem = NSMenuItem(title: L("playMenu"), action: nil, keyEquivalent: ""); playItem.submenu = play; bar.addItem(playItem)
        add(play, L("playPause"), #selector(playPause), " ", [])
        add(play, L("stepBack"), #selector(stepBack), String(UnicodeScalar(NSLeftArrowFunctionKey)!), [])
        add(play, L("stepForward"), #selector(stepForward), String(UnicodeScalar(NSRightArrowFunctionKey)!), [])
        let windowMenu = NSMenu(title: L("windowMenu")); let windowItem = NSMenuItem(title: L("windowMenu"), action: nil, keyEquivalent: ""); windowItem.submenu = windowMenu; bar.addItem(windowItem)
        windowMenu.addItem(withTitle: L("minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: L("zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: L("bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
        let help = NSMenu(title: L("helpMenu")); let helpItem = NSMenuItem(title: L("helpMenu"), action: nil, keyEquivalent: ""); helpItem.submenu = help; bar.addItem(helpItem)
        add(help, L("help"), #selector(showHelp), "?"); HelpLinks.addNoteItem(to: help); NSApp.helpMenu = help
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
MainActor.assumeIsolated {
    let delegate = Delegate(); app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
