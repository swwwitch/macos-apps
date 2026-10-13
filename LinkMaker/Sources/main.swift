import AppKit
import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

func appIcon(for bundleID: String) -> NSImage? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
    return NSWorkspace.shared.icon(forFile: url.path)
}
func groupTitle(_ group: LinkAction.Group) -> String { L("group." + group.rawValue) }
func appName(for bundleID: String) -> String {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
    return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
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
            Text(title).foregroundColor(.secondary).frame(width: 130, alignment: .leading)
            Text(value).fixedSize(horizontal: false, vertical: true).textSelection(.enabled).lineLimit(4)
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
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    StatusRow(symbol: model.hotkeyProblem ? "exclamationmark.triangle.fill" : (model.paused ? "pause.circle" : "keyboard"),
                              tint: model.hotkeyProblem ? .orange : .secondary, title: L("hotkeyRow"), value: model.hotkeySummary)
                    StatusRow(symbol: model.accessibilityAllowed ? "checkmark.circle.fill" : "minus.circle",
                              tint: model.accessibilityAllowed ? .green : .secondary, title: AccessibilityText.text("title"),
                              value: AccessibilityText.text(model.accessibilityAllowed ? "allowed" : "denied"))
                    StatusRow(symbol: model.statusIsError ? "xmark.octagon.fill" : "link",
                              tint: model.statusIsError ? .red : .secondary, title: L("lastResult"), value: model.status)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            GroupBox(label: Text(L("functions")).font(.system(size: 13, weight: .semibold))) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(LinkAction.Group.allCases, id: \.self) { group in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(groupTitle(group)).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                                ForEach(LinkAction.listed(group), id: \.self) { action in
                                    HStack {
                                        Text(L(action.titleKey))
                                        Spacer()
                                        Text(model.isActive(action) ? model.label(action) : L("noKey"))
                                            .font(.system(.body, design: .monospaced)).foregroundColor(.secondary)
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }.frame(minHeight: 220)
            }
            Text(L("mainHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L("settingsButton")) { (NSApp.delegate as? AppDelegate)?.showPreferences() }
                Button(L("help")) { (NSApp.delegate as? AppDelegate)?.help() }
                Spacer()
                Button(L("showPalette")) { (NSApp.delegate as? AppDelegate)?.showPalette() }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 22)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: AppSurface.color))
    }
}

struct ShortcutRow: View {
    @ObservedObject var model: Model
    let action: LinkAction
    var body: some View {
        let enabled = model.actionEnabled[action] ?? false
        HStack(spacing: 8) {
            Toggle(L(action.titleKey), isOn: Binding(get: { enabled }, set: {
                model.actionEnabled[action] = $0
                if $0 && model.shortcuts[action] == nil { model.startRecording(action) }
                model.save()
            }))
            .frame(width: 250, alignment: .leading)
            Text(model.recording == action ? L("pressKey") : model.label(action))
                .font(.system(.body, design: .monospaced)).frame(width: 96, alignment: .leading)
                .foregroundColor(enabled ? .primary : .secondary)
                .accessibilityLabel(L("currentKey") + " " + model.label(action))
            Button(model.recording == action ? L("cancelRecording") : L("change")) { model.startRecording(action) }
            Button(L("resetShortcut")) { model.resetShortcut(action) }
            Toggle(L("doubleTap"), isOn: Binding(get: { model.isDouble(action) }, set: { model.setDoubleTap(action, $0) }))
                .help(L("doubleTapHint"))
            if let status = model.failures[action] {
                Label(String(format: L("registerFailed"), String(status)), systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.caption)
            } else if model.duplicates.contains(action) {
                Label(L("duplicateShortcut"), systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.caption)
            }
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
                }
                SettingsSection(AccessibilityText.text("title")) {
                    AccessibilityPermissionView(required: true, showsTitle: false)
                }
                SettingsSection(L("automationTitle")) {
                    Text(L("automationHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button(L("automationOpen")) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") { NSWorkspace.shared.open(url) }
                    }
                }
            })),
            (L("hotkeyTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("hotkeyGeneral")) {
                    Text(model.hotkeySummary).font(.caption).foregroundColor(model.hotkeyProblem ? .orange : .secondary)
                    if model.recording != nil { Text(model.recordMessage).font(.caption) }
                    Text(L("shortcutHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button(L("resetAll")) { model.resetAllShortcuts() }
                }
                ForEach(LinkAction.Group.allCases, id: \.self) { group in
                    SettingsSection(groupTitle(group)) {
                        ForEach(LinkAction.inSettings(group), id: \.self) { action in
                            ShortcutRow(model: model, action: action)
                        }
                    }
                }
            })),
            (L("paletteTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("paletteTab")) {
                    Toggle(L("paletteMode"), isOn: Binding(get: { model.paletteMode }, set: { model.paletteMode = $0; model.save() }))
                    Text(L("paletteModeHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button(L("showPalette")) { (NSApp.delegate as? AppDelegate)?.showPalette() }
                }
                SettingsSection(L("paletteHotkey")) {
                    HStack(spacing: 8) {
                        Toggle(L("showPalette"), isOn: Binding(get: { model.paletteHotkeyEnabled }, set: { model.paletteHotkeyEnabled = $0; model.save() }))
                            .frame(width: 250, alignment: .leading)
                        Text(model.recordingPalette ? L("pressKey") : model.paletteShortcut.label)
                            .font(.system(.body, design: .monospaced)).frame(width: 80, alignment: .leading)
                            .foregroundColor(model.paletteHotkeyEnabled ? .primary : .secondary)
                            .accessibilityLabel(L("currentKey") + " " + model.paletteShortcut.label)
                        Button(model.recordingPalette ? L("cancelRecording") : L("change")) { model.startRecordingPalette() }
                        Button(L("resetShortcut")) { model.resetPaletteShortcut() }
                    }
                    if let status = model.paletteFailure {
                        Label(String(format: L("registerFailed"), String(status)), systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.caption)
                    }
                    if model.recordingPalette { Text(model.recordMessage).font(.caption) }
                    Text(L("paletteHotkeyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (L("browsersTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("browsersTab")) {
                    ForEach(Browser.all, id: \.bundleID) { browser in
                        Toggle(isOn: Binding(get: { model.isEnabled(browser) }, set: { model.setEnabled(browser, $0) })) {
                            HStack(spacing: 8) {
                                if let icon = appIcon(for: browser.bundleID) { Image(nsImage: icon).resizable().frame(width: 20, height: 20).accessibilityHidden(true) }
                                else { Image(systemName: "app.dashed").frame(width: 20, height: 20).accessibilityHidden(true) }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(browser.name)
                                    Text(browser.bundleID + (browser.isInstalled ? "" : " — " + L("notInstalled"))).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    Text(L("browsersHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (L("outputTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("urlTitle")) {
                    Toggle(L("simplifyURL"), isOn: Binding(get: { model.simplifyURL }, set: { model.simplifyURL = $0; model.save() }))
                    Text(L("simplifyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("amazonTitle")) {
                    HStack {
                        Text(L("associateID"))
                        TextField("example", text: Binding(get: { model.associateID }, set: { model.associateID = $0; model.save() }))
                            .frame(width: 180).accessibilityLabel(L("associateID"))
                        Text("-22").foregroundColor(.secondary)
                    }
                    Text(L("associateHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(L("translateTitle")) {
                    Picker(L("translateTarget"), selection: Binding(get: { model.translateTarget }, set: { model.translateTarget = $0; model.save() })) {
                        ForEach(["ja", "en", "zh-CN", "ko", "fr", "de", "es"], id: \.self) { code in
                            Text(Locale.current.localizedString(forIdentifier: code) ?? code).tag(code)
                        }
                    }.frame(width: 300)
                }
                SettingsSection(L("notifyTitle")) {
                    Toggle(L("notifySuccess"), isOn: Binding(get: { model.notifySuccess }, set: { model.notifySuccess = $0; model.save() }))
                    Text(L("notifyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (L("excludedTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(L("excludedTab")) {
                    ForEach(model.excludedApps, id: \.self) { id in
                        HStack(spacing: 8) {
                            if let icon = appIcon(for: id) { Image(nsImage: icon).resizable().frame(width: 20, height: 20).accessibilityHidden(true) }
                            else { Image(systemName: "app.dashed").frame(width: 20, height: 20).accessibilityHidden(true) }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appName(for: id))
                                Text(id).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(L("remove")) { model.removeExcludedApp(id) }.accessibilityLabel(L("remove") + " " + appName(for: id))
                        }
                    }
                    if model.excludedApps.isEmpty { Text(L("excludedEmpty")).foregroundColor(.secondary) }
                    HStack {
                        Button(L("addApp")) {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.application]; panel.allowsMultipleSelection = true
                            panel.directoryURL = URL(fileURLWithPath: "/Applications")
                            if panel.runModal() == .OK { model.addExcludedApps(panel.urls) }
                        }
                        Button(L("resetExcluded")) { model.resetExcludedApps() }
                    }
                    Text(L("excludedHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            })),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 720, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, NSMenuItemValidation {
    var model: Model!
    var item: NSStatusItem!
    var mainWindow: NSWindow?
    var preferences: NSWindow?
    var helpWindow: NSWindow?
    var palette: LinkPalette?
    /// The palette stays open while a target browser (or LinkMaker itself) is in front, and comes back with the browser.
    var paletteWanted = false
    var activationObserver: NSObjectProtocol?
    let menu = NSMenu()
    var resultItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = Model()
        AccessibilityText.neededOverride = [
            "ブラウザーで表示中のページのタイトルとURLを読み取り、アドレスバーへの入力などのキー操作を送るために使用します。未許可の場合、ほとんどの機能が使えません。",
            "Used to read the title and URL of the page in your browser and to send keys such as typing into the address bar. Most functions are unavailable without permission.",
            "用于读取浏览器中页面的标题和 URL，并发送在地址栏输入等按键操作。未获授权时，大部分功能无法使用。",
            "브라우저에 표시된 페이지의 제목과 URL을 읽고 주소 막대 입력 등의 키 조작을 보내는 데 사용합니다. 권한이 없으면 대부분의 기능을 사용할 수 없습니다."
        ]
        WindowActivationPolicy.install()
        model.onPaletteHotkey = { [weak self] in self?.togglePalette() }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            self?.followFrontApp(note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
        buildMainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.setAccessibilityLabel("LinkMaker")
        menu.delegate = self
        resultItem = menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        for group in LinkAction.Group.allCases {
            let sub = NSMenu(title: groupTitle(group))
            for action in LinkAction.listed(group) {
                let entry = sub.addItem(withTitle: L(action.titleKey), action: #selector(runAction(_:)), keyEquivalent: "")
                entry.target = self; entry.representedObject = action.rawValue
            }
            menu.setSubmenu(sub, for: menu.addItem(withTitle: groupTitle(group), action: nil, keyEquivalent: ""))
        }
        menu.addItem(.separator())
        add(menu, L("openMainWindow"), #selector(openMainWindow))
        add(menu, L("showPalette"), #selector(openPalette))
        add(menu, L("hidePalette"), #selector(hidePalette))
        add(menu, L("settings"), #selector(showPreferences))
        add(menu, L("pause"), #selector(togglePause))
        menu.addItem(.separator())
        // Help submenu: app help and the note article (BASELINE「メニューの共通構成」).
        let statusHelp = NSMenu(title: L("help")); add(statusHelp, L("appHelp"), #selector(help)); MainActor.assumeIsolated { HelpLinks.addNoteItem(to: statusHelp) }
        menu.setSubmenu(statusHelp, for: menu.addItem(withTitle: L("help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator()); add(menu, L("quit"), #selector(quit))
        item.menu = menu
        MainActor.assumeIsolated {
            MenuBarPresence.shared.install(name: "LinkMaker", symbol: "link", existing: item,
                show: { [weak self] in self?.showPrimaryWindow() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in self?.help() })
        }
        if !LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent) && !StartupWindow.hidden { showPrimaryWindow() }
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
        add(fileMenu, L("showPalette"), #selector(openPalette))
        add(fileMenu, L("hidePalette"), #selector(hidePalette))
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

    func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "") {
        let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: key); entry.target = self
    }
    func menuWillOpen(_ menu: NSMenu) {
        resultItem.title = model.status.components(separatedBy: "\n").first ?? model.status
        menu.items.first { $0.action == #selector(togglePause) }?.state = model.paused ? .on : .off
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(togglePause) { menuItem.state = model.paused ? .on : .off }
        if menuItem.action == #selector(hidePalette) { return palette?.isVisible == true }
        if menuItem.action == #selector(runAction(_:)) {
            // The key is shown for reference; the menu runs the function on the last browser used.
            if let raw = menuItem.representedObject as? String, let action = LinkAction(rawValue: raw) {
                menuItem.title = L(action.titleKey) + (model.isActive(action) ? "  " + model.label(action) : "")
            }
            return !model.busy
        }
        return true
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPrimaryWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !model.keepRunning }
    func windowWillClose(_ notification: Notification) {
        // Accessory applications also need an explicit last-window close path.
        guard let closing = notification.object as? NSWindow else { return }
        if closing === palette { paletteWanted = false }
        DispatchQueue.main.async { [weak self, weak closing] in
            guard let self, !self.model.keepRunning else { return }
            let otherVisible = NSApp.windows.contains { $0 !== closing && $0.isVisible && ($0.canBecomeMain || $0 === self.palette) }
            if !otherVisible { NSApp.terminate(nil) }
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }

    @objc func runAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = LinkAction(rawValue: raw) else { return }
        model.perform(action)
    }
    @objc func openMainWindow() { showMainWindow() }
    /// Launch, Dock reopen and the menu-bar item: the palette when 「パレットで使う」 is on (KakkoReplace's paletteMode).
    func showPrimaryWindow() {
        if model.paletteMode, showPalette(quietly: true) { return }
        showMainWindow()
    }
    @objc func openPalette() { showPalette() }
    func showPalette() { showPalette(quietly: false) }
    /// Shown without activating LinkMaker, so the browser stays in front. From another app, the browser used last
    /// is brought forward first; without one the reason is shown instead of an empty palette.
    @discardableResult
    func showPalette(quietly: Bool) -> Bool {
        let front = NSWorkspace.shared.frontmostApplication
        let own = ProcessInfo.processInfo.processIdentifier
        if !model.isEnabledBrowser(front) {
            if let pid = model.lastBrowserPID, let browser = NSRunningApplication(processIdentifier: pid), !browser.isTerminated {
                browser.activate(options: [.activateIgnoringOtherApps])
            } else {
                // From LinkMaker's own windows the palette still opens; elsewhere there is nothing to act on.
                if !quietly { model.report(.failure(L("fail.noBrowser"))) }
                if front?.processIdentifier != own { return false }
            }
        }
        if palette == nil { palette = LinkPalette(model: model); palette?.delegate = self }
        guard let palette else { return false }
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(palette.frame) }) { palette.center() }
        palette.refresh()
        paletteWanted = true
        NSApp.unhideWithoutActivation()
        palette.orderFrontRegardless()
        return true
    }
    @objc func hidePalette() { paletteWanted = false; palette?.orderOut(nil) }
    func togglePalette() { if palette?.isVisible == true { hidePalette() } else { showPalette() } }
    /// Hidden while an excluded app is in front (its windows are not ours to cover); back with any other app.
    func followFrontApp(_ app: NSRunningApplication?) {
        guard paletteWanted, let palette, let app else { return }
        // The 「選択した文字列から」 buttons work in any app, so only the excluded apps hide it.
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier || model.isEnabledBrowser(app) || !model.isExcluded(app) { palette.orderFrontRegardless() }
        else { palette.orderOut(nil) }
    }
    func showMainWindow() {
        model.refreshAccessibility()
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 600), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            // Native title bar unchanged; no app name in it (BASELINE「主画面の背景とタイトルバー」).
            window.title = ""
            window.titleVisibility = .hidden
            let content = NSView(frame: window.contentLayoutRect)
            AppSurface.install(in: content)
            let hosting = NSHostingView(rootView: MainView(model: model))
            hosting.sizingOptions = [.minSize]
            let fitting = hosting.fittingSize
            let size = NSSize(width: max(560, ceil(fitting.width)), height: max(600, ceil(fitting.height)))
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
        }
        if let window = mainWindow, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); mainWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func showPreferences() {
        model.refreshLogin()
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 560), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle")
            let hosting = NSHostingView(rootView: Preferences(model: model))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.contentMinSize = NSSize(width: 720, height: 560)
            window.delegate = self; window.isReleasedWhenClosed = false; window.center(); window.setFrameAutosaveName("Preferences"); preferences = window
        }
        if let window = preferences, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
    }
    @objc func help() {
        if helpWindow == nil { helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: "LinkMaker — " + L("help"), text: L("helpText"), heading: L("helpHeading")) } }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func togglePause() { model.togglePause() }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary ?? [:]
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "LinkMaker",
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

// Reused from CellCopyCleaner (BrowserSwitcher origin). Oldest process wins on simultaneous launch.
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
