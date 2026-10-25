import AppKit
import SwiftUI
import Carbon

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

@MainActor final class Model: ObservableObject {
    private let defaults = UserDefaults.standard

    // MARK: Settings
    /// Seconds between pressing 撮影 and the capture, to open a menu in the meantime.
    @Published var delay = UserDefaults.standard.object(forKey: "captureDelay") as? Int ?? 3 { didSet { defaults.set(delay, forKey: "captureDelay") } }
    @Published var range = BarRange(rawValue: UserDefaults.standard.string(forKey: "barRange") ?? "") ?? .fromLeft { didSet { defaults.set(range.rawValue, forKey: "barRange") } }
    @Published var shadow = UserDefaults.standard.object(forKey: "drawShadow") as? Bool ?? true { didSet { defaults.set(shadow, forKey: "drawShadow") } }
    @Published var copyToClipboard = UserDefaults.standard.object(forKey: "copyToClipboard") as? Bool ?? true { didSet { defaults.set(copyToClipboard, forKey: "copyToClipboard") } }
    @Published var playSound = UserDefaults.standard.object(forKey: "playSound") as? Bool ?? true { didSet { defaults.set(playSound, forKey: "playSound") } }
    /// Per Mac (a path). Empty means the folder of the macOS screenshot.
    @Published var folderPath = UserDefaults.standard.string(forKey: "saveFolder") ?? "" { didSet { defaults.set(folderPath, forKey: "saveFolder") } }
    var folder: URL { folderPath.isEmpty ? MenuCapture.systemScreenshotFolder : URL(fileURLWithPath: folderPath, isDirectory: true) }

    /// Keys shared by 設定の共有. The folder, startup, residency and the app hotkey stay per Mac.
    nonisolated static let sharedKeys: Set<String> = ["captureDelay", "barRange", "drawShadow", "copyToClipboard", "playSound", "captureHotkeyEnabled", "captureHotkey"]
    /// Re-reads the shared settings after an import so the next save does not write the old values back.
    func reloadSharedSettings() {
        delay = defaults.object(forKey: "captureDelay") as? Int ?? 3
        range = BarRange(rawValue: defaults.string(forKey: "barRange") ?? "") ?? .fromLeft
        shadow = defaults.object(forKey: "drawShadow") as? Bool ?? true
        copyToClipboard = defaults.object(forKey: "copyToClipboard") as? Bool ?? true
        playSound = defaults.object(forKey: "playSound") as? Bool ?? true
        captureHotkeyEnabled = defaults.object(forKey: "captureHotkeyEnabled") as? Bool ?? true
        captureCombo = Model.readCombo("captureHotkey", default: Model.defaultCaptureCombo)
    }

    // MARK: Hotkeys
    /// ⌃⌥⇧⌘4 (the user's choice, 2026-10-26). Not used by macOS, Keyboard Maestro or the other sw_apps (checked that day).
    static let defaultCaptureCombo = KeyCombo(code: UInt32(kVK_ANSI_4), modifiers: KeyCombo.control | KeyCombo.option | KeyCombo.shift | KeyCombo.command)
    static let captureFieldID = "captureHotkey", appFieldID = "appHotkey"
    static func readCombo(_ key: String, default value: KeyCombo?) -> KeyCombo? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return value }
        return data.isEmpty ? nil : try? JSONDecoder().decode(KeyCombo.self, from: data)
    }
    private func writeCombo(_ combo: KeyCombo?, _ key: String) { defaults.set(combo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: key) }
    @Published var captureHotkeyEnabled = UserDefaults.standard.object(forKey: "captureHotkeyEnabled") as? Bool ?? true { didSet { defaults.set(captureHotkeyEnabled, forKey: "captureHotkeyEnabled"); registerHotkeys() } }
    @Published var captureCombo = Model.readCombo("captureHotkey", default: Model.defaultCaptureCombo) { didSet { writeCombo(captureCombo, "captureHotkey"); registerHotkeys() } }
    /// Shows the main window from any app (per Mac). Unassigned at first.
    @Published var appHotkeyEnabled = UserDefaults.standard.object(forKey: "appHotkeyEnabled") as? Bool ?? true { didSet { defaults.set(appHotkeyEnabled, forKey: "appHotkeyEnabled"); registerHotkeys() } }
    @Published var appCombo = Model.readCombo("appHotkey", default: nil) { didSet { writeCombo(appCombo, "appHotkey"); registerHotkeys() } }
    @Published var captureHotkeyRegistered = true
    @Published var appHotkeyRegistered = true
    let hotkeys = HotkeySet(signature: "MnSt")
    enum HotkeyID: UInt32 { case app = 1, capture = 2 }
    func registerHotkeys() {
        hotkeys.unregisterAll()
        captureHotkeyRegistered = true; appHotkeyRegistered = true
        if captureHotkeyEnabled, let captureCombo { captureHotkeyRegistered = hotkeys.register(HotkeyID.capture.rawValue, captureCombo) == noErr }
        if appHotkeyEnabled, let appCombo { appHotkeyRegistered = hotkeys.register(HotkeyID.app.rawValue, appCombo) == noErr }
        var items: [HotkeyManifest.Item] = []
        if let captureCombo { items.append(.init(id: "captureHotkey", title: L("captureHotkey"), keyCode: Int(captureCombo.code), modifiers: Int(captureCombo.modifiers), enabled: captureHotkeyEnabled)) }
        if let appCombo { items.append(.init(id: "appHotkey", title: SettingsUI.shortcutTitle, keyCode: Int(appCombo.code), modifiers: Int(appCombo.modifiers), enabled: appHotkeyEnabled)) }
        HotkeyManifest.publish(items)
    }

    // MARK: Capturing
    /// Seconds left before the capture, while counting down.
    @Published var countdown: Int?
    @Published var busy = false
    @Published var status = ""
    @Published var failed = false
    @Published var lastURL: URL?
    @Published var lastImage: NSImage?
    @Published var permitted = MenuCapture.hasPermission
    private var timer: Timer?

    /// The 撮影 button and the menu items: count down so a menu can be opened, then capture.
    /// The hotkey captures at once when a menu is already open (it is pressed with the menu showing).
    func start(fromHotkey: Bool = false) {
        guard countdown == nil, !busy else { return }  // Already counting or saving; a second press changes nothing.
        if fromHotkey && MenuCapture.menuIsOpen() { capture(); return }
        guard delay > 0 else { capture(); return }
        countdown = delay
        status = ""; failed = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let left = self.countdown else { return }
                if left > 1 { self.countdown = left - 1 } else { self.stopTimer(); self.capture() }
            }
        }
    }
    func cancel() {
        guard countdown != nil else { return }
        stopTimer()
        report(L("canceled"), failed: false)
    }
    private func stopTimer() { timer?.invalidate(); timer = nil; countdown = nil }

    func capture() {
        guard !busy else { return }
        permitted = MenuCapture.hasPermission
        guard permitted else {
            // Shows the system prompt the first time only; later the reason and the way to System Settings stay in the window.
            CGRequestScreenCaptureAccess()
            report(L("needPermission"), failed: true); return
        }
        busy = true
        let range = range, shadow = shadow, folder = folder
        Task {
            defer { busy = false }
            do {
                let picture = try await MenuCapture.capture(range: range, shadow: shadow)
                let url = try MenuCapture.save(picture, in: folder, prefix: L("filePrefix"))
                if copyToClipboard { MenuCapture.copy(picture) }
                if playSound { NSSound(contentsOfFile: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif", byReference: true)?.play() }
                lastURL = url
                lastImage = NSImage(cgImage: picture.image, size: NSSize(width: CGFloat(picture.image.width) / picture.scale, height: CGFloat(picture.image.height) / picture.scale))
                report(String(format: L(copyToClipboard ? "savedAndCopied" : "saved"), url.lastPathComponent), failed: false)
            } catch CaptureError.noMenu {
                report(L("noMenu"), failed: true)
            } catch CaptureError.permission {
                permitted = false
                report(L("needPermission"), failed: true)
            } catch {
                let reason = (error as? CaptureError).flatMap { if case .failed(let text) = $0 { return text } else { return nil } } ?? error.localizedDescription
                report(String(format: L("captureFailed"), reason), failed: true)
            }
        }
    }
    private func report(_ text: String, failed: Bool) { status = text; self.failed = failed }

    func revealLast() { if let lastURL { NSWorkspace.shared.activateFileViewerSelecting([lastURL]) } }
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.directoryURL = folder; panel.prompt = L("choose")
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url { folderPath = url.path }
    }
}

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

/// Gray-and-white squares behind the picture, so the transparent background reads as transparent.
struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 8
            for row in 0..<Int(ceil(size.height / cell)) {
                for column in 0..<Int(ceil(size.width / cell)) where (row + column) % 2 == 0 {
                    context.fill(Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)), with: .color(.gray.opacity(0.15)))
                }
            }
        }
    }
}

struct MainView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 4) { Text(L("heading")).font(.system(size: 22, weight: .semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
            }
            ZStack {
                Checkerboard()
                if let image = model.lastImage {
                    Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fit).padding(8)
                        .onDrag { model.lastURL.map { NSItemProvider(contentsOf: $0) ?? NSItemProvider() } ?? NSItemProvider() }
                        .accessibilityLabel(model.lastURL?.lastPathComponent ?? "")
                } else {
                    Text(L("noPicture")).foregroundColor(.secondary).multilineTextAlignment(.center).padding()
                }
            }
            .frame(minHeight: 220, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.25)))
            HStack(spacing: 10) {
                if let left = model.countdown {
                    Button(String(format: L("cancelCountdown"), left)) { model.cancel() }.keyboardShortcut(.cancelAction).controlSize(.large)
                } else {
                    Button(model.delay > 0 ? String(format: L("captureAfter"), model.delay) : L("captureNow")) { model.start() }
                        .keyboardShortcut(.defaultAction).controlSize(.large).disabled(model.busy)
                }
                if model.captureHotkeyEnabled, let combo = model.captureCombo {
                    Text(String(format: L("hotkeyHint"), combo.label)).font(.callout).foregroundColor(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                Button(L("revealInFinder")) { model.revealLast() }.disabled(model.lastURL == nil)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if model.failed { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange).accessibilityHidden(true) }
                // A space keeps the row's height so the window does not jump.
                Text(model.status.isEmpty ? " " : model.status).font(.callout).foregroundColor(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                if model.failed && !model.permitted {
                    Button(L("openScreenRecording")) { ScreenRecordingSection.openSettings() }.font(.callout)
                }
            }
        }.padding(20)
        .frame(minWidth: 480, minHeight: 420, alignment: .top).background(Color(nsColor: AppSurface.color)).tint(appTint)
    }
}

/// 「画面収録」 group of the 起動・常駐 tab, laid out like the shared Accessibility group. Checking never prompts.
struct ScreenRecordingSection: View {
    @ObservedObject var model: Model
    static func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
    var body: some View {
        SettingsSection(L("screenRecording")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: model.permitted ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundColor(model.permitted ? .green : .red).accessibilityHidden(true)
                    Text(L(model.permitted ? "permitted" : "notPermitted"))
                }
                Text(L("screenRecordingReason")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(L("openScreenRecording")) { ScreenRecordingSection.openSettings() }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.permitted = MenuCapture.hasPermission }
        .onAppear { model.permitted = MenuCapture.hasPermission }
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
                                others: model.captureCombo.map { [(L("captureHotkey"), $0)] } ?? [],
                                registered: model.appHotkeyRegistered, isEnabled: model.appHotkeyEnabled)
                    Text(L("appHotkeyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            ScreenRecordingSection(model: model)
        })), (L("captureTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("captureHotkey")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(HotkeyText.enable, isOn: $model.captureHotkeyEnabled)
                    HotkeyField(id: Model.captureFieldID, combo: $model.captureCombo, defaultCombo: Model.defaultCaptureCombo, allowsClear: true,
                                others: model.appCombo.map { [(SettingsUI.shortcutTitle, $0)] } ?? [],
                                registered: model.captureHotkeyRegistered, isEnabled: model.captureHotkeyEnabled)
                    Text(L("captureHotkeyDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("delayTitle")) {
                VStack(alignment: .leading, spacing: 6) {
                    Stepper(value: $model.delay, in: 0...10) { Text(String(format: L("seconds"), model.delay)).monospacedDigit() }.fixedSize()
                    Text(L("delayDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("rangeTitle")) {
                VStack(alignment: .leading, spacing: 6) {
                    Picker(L("rangeTitle"), selection: $model.range) {
                        ForEach(BarRange.allCases, id: \.self) { Text(L("range." + $0.rawValue)).tag($0) }
                    }.pickerStyle(.radioGroup).labelsHidden()
                    Text(L("rangeDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Toggle(L("shadow"), isOn: $model.shadow).padding(.top, 6)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (L("outputTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("folderTitle")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.folder.path).font(.callout).textSelection(.enabled).lineLimit(2).truncationMode(.middle)
                    HStack {
                        Button(L("chooseFolder")) { model.chooseFolder() }
                        Button(L("showFolder")) { NSWorkspace.shared.open(model.folder) }
                        Button(L("resetFolder")) { model.folderPath = "" }.disabled(model.folderPath.isEmpty)
                    }
                    Text(L("folderDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("afterCapture")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("copyToClipboard"), isOn: $model.copyToClipboard)
                    Toggle(L("playSound"), isOn: $model.playSound)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())), (AboutSection.title, AnyView(AboutView()))]).frame(minWidth: 560, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
    }
}

@MainActor final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    let model = Model()
    var window: NSWindow!
    var settings: NSWindow?
    var helpWindow: NSWindow?
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
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 460), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "MenuShot"; window.titleVisibility = .hidden
        let host = NSHostingView(rootView: MainView(model: model))
        host.sizingOptions = [.minSize]
        window.contentView = host
        window.delegate = self; window.isReleasedWhenClosed = false
        if UserDefaults.standard.string(forKey: "NSWindow Frame MainWindow") == nil { window.center() }  // First launch: no saved frame yet.
        window.setFrameAutosaveName("MainWindow"); window.minSize = NSSize(width: 480, height: 420)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        model.hotkeys.action = { [weak self] number in
            switch Model.HotkeyID(rawValue: number) {
            case .app: StartupWindow.userRequestedWindow(); self?.show()
            // Never activates MenuShot: that would close the menu being captured.
            case .capture: self?.model.start(fromHotkey: true)
            case nil: break
            }
        }
        model.registerHotkeys()
        MenuBarPresence.shared.install(name: "MenuShot", symbol: "menubar.rectangle", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() },
                                       extraItems: { [weak self] in self?.captureItems() ?? [] })
        SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings() }
        SettingsSync.shared.start(.init(keys: Model.sharedKeys, prefixes: [],
            note: StartupWindow.text("撮影のホットキー・撮影までの秒数・写す範囲・影・撮影後の動作を書き出し・同期します。",
                                     "Exports and syncs the capture hotkey, delay, range, shadow and after-capture choices.",
                                     "导出并同步截图快捷键、延迟秒数、截取范围、阴影和截图后的操作。",
                                     "캡처 단축키, 대기 시간, 캡처 범위, 그림자, 캡처 후 동작을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("保存先・ログイン時の起動・常駐・メニューバーの表示・アプリを呼び出すホットキーはMacごとに設定します。",
                                       "The save folder, open at login, keep running, the menu bar icon and the show-app hotkey are set on each Mac.",
                                       "保存位置、登录时启动、保持运行、菜单栏图标和显示应用快捷键在每台 Mac 上分别设置。",
                                       "저장 위치, 로그인 시 실행, 계속 실행, 메뉴 막대 아이콘, 앱 표시 단축키는 Mac마다 설정합니다.")))
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !login && !StartupWindow.suppressInitialWindow { show() }
    }
    func applicationWillTerminate(_ notification: Notification) { model.cancel() }
    @objc func show() { guard let window else { return }; NSApp.activate(ignoringOtherApps: true); if window.isMiniaturized { window.deminiaturize(nil) }; window.makeKeyAndOrderFront(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        StartupWindow.userRequestedWindow(); show(); return true }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === window && !UserDefaults.standard.bool(forKey: "resident") { NSApp.terminate(nil); return false }
        return true
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func startCapture() { model.start() }
    @objc func revealLast() { model.revealLast() }
    /// Top of the menu bar menu: start the countdown, then open the menu to capture.
    func captureItems() -> [NSMenuItem] {
        let title = model.delay > 0 ? String(format: L("captureAfter"), model.delay) : L("captureNow")
        let item = NSMenuItem(title: title, action: #selector(startCapture), keyEquivalent: "")
        item.target = self; item.isEnabled = model.countdown == nil && !model.busy
        item.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)
        return [item]
    }
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(startCapture): return model.countdown == nil && !model.busy
        case #selector(revealLast): return model.lastURL != nil
        default: return true
        }
    }
    @objc func showSettings() {
        if settings == nil {
            settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 600), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            // Resizable from the designed size upward; the hosting view reports only its minimum.
            let hosting = NSHostingView(rootView: SettingsView(model: model)); hosting.sizingOptions = [.minSize]
            settings!.title = L("settingsWindow"); settings!.contentView = hosting; settings!.contentMinSize = NSSize(width: 560, height: 600); settings!.isReleasedWhenClosed = false; settings!.center()
        }
        settings!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let text = Bundle.main.url(forResource: "Help", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? L("help")
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "MenuShot")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "MenuShot", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) { menu.addItem(withTitle: title, action: action, keyEquivalent: key).target = self }
    func buildMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        let app = NSMenu(); let root = NSMenuItem(); root.submenu = app; bar.addItem(root)
        add(app, L("about"), #selector(about), ""); app.addItem(.separator())
        add(app, L("settings"), #selector(showSettings), ","); app.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to: app)   // 「アップデートを確認…」「アップデートを自動確認」 + separator
        #endif
        let services = NSMenu(title: L("services")); app.addItem(withTitle: L("services"), action: nil, keyEquivalent: "").submenu = services; NSApp.servicesMenu = services
        app.addItem(.separator())
        app.addItem(withTitle: L("hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: L("hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: L("showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator()); add(app, L("quit"), #selector(quit), "q")
        let file = NSMenu(title: L("fileMenu")); let fileItem = NSMenuItem(title: L("fileMenu"), action: nil, keyEquivalent: ""); fileItem.submenu = file; bar.addItem(fileItem)
        add(file, L("openMainWindow"), #selector(show), "0"); file.addItem(.separator())
        add(file, L("captureMenuItem"), #selector(startCapture), "")
        add(file, L("revealInFinder"), #selector(revealLast), "")
        file.addItem(.separator())
        file.addItem(withTitle: L("close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let edit = NSMenu(title: L("editMenu")); let editItem = NSMenuItem(title: L("editMenu"), action: nil, keyEquivalent: ""); editItem.submenu = edit; bar.addItem(editItem)
        for (key, action, shortcut) in [("undo", "undo:", "z"), ("redo", "redo:", "z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("paste", "paste:", "v"), ("selectAll", "selectAll:", "a")] {
            edit.addItem(withTitle: L(key), action: Selector(action), keyEquivalent: shortcut)
        }
        edit.item(at: 1)?.keyEquivalentModifierMask = [.command, .shift]   // やり直す ⇧⌘Z
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
