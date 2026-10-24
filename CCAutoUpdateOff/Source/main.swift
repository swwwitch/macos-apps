import AppKit
import ServiceManagement
import SwiftUI

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// Watches the Creative Cloud auto-update preferences (read-only) and reports when apps would update automatically.
final class Model: ObservableObject {
    @Published var state = CCState()
    @Published var status = ""
    @Published var mailStatus = ""
    @Published var sending = false

    private let defaults = UserDefaults.standard
    /// 通知 (macOS notification when it turns on). On by default.
    @Published var notifyEnabled: Bool { didSet { defaults.set(notifyEnabled, forKey: "notifyEnabled") } }
    /// メール送信 (once a day while on). Off by default.
    @Published var mailEnabled: Bool { didSet { defaults.set(mailEnabled, forKey: "mailEnabled"); check() } }
    @Published var mailAddress: String { didSet { defaults.set(mailAddress, forKey: "mailAddress") } }
    /// Send time, minutes after midnight (9:00 by default).
    @Published var mailTime: Int { didSet { defaults.set(mailTime, forKey: "mailTime"); scheduleMailTimer(); check() } }
    /// `mailTime` as a Date for the time picker.
    var mailTimeDate: Date {
        get { CCAutoUpdate.mailSlot(minutes: mailTime, on: Date()) }
        set { let c = Calendar.current.dateComponents([.hour, .minute], from: newValue); mailTime = (c.hour ?? 0) * 60 + (c.minute ?? 0) }
    }
    /// Stay running after the main window is closed (needed to keep watching). On by default.
    @Published var keepRunning: Bool { didSet { defaults.set(keepRunning, forKey: "keepRunning") } }
    /// Also report apps with 以前のバージョンを削除 checked. On by default.
    @Published var watchRemoveOld: Bool { didSet { defaults.set(watchRemoveOld, forKey: "watchRemoveOld"); check() } }
    private var lastMail: Date? {
        get { defaults.object(forKey: "lastMailDate") as? Date }
        set { defaults.set(newValue, forKey: "lastMailDate") }
    }
    /// What was last announced, so the same state is not notified again (cleared once it is off).
    private var notifiedSignature: String {
        get { defaults.string(forKey: "notifiedSignature") ?? "" }
        set { defaults.set(newValue, forKey: "notifiedSignature") }
    }
    private let mailQueue = DispatchQueue(label: "CCAutoUpdateOff.mail")
    private var mailTimer: Timer?
    private var notifyingSignature: String?
    var onChange: (() -> Void)?

    init() {
        notifyEnabled = defaults.object(forKey: "notifyEnabled") as? Bool ?? true
        mailEnabled = defaults.bool(forKey: "mailEnabled")
        mailAddress = defaults.string(forKey: "mailAddress") ?? ""
        mailTime = defaults.object(forKey: "mailTime") as? Int ?? CCAutoUpdate.defaultMailTime
        keepRunning = defaults.object(forKey: "keepRunning") as? Bool ?? true
        watchRemoveOld = defaults.object(forKey: "watchRemoveOld") as? Bool ?? true
    }

    /// Keys shared by 設定の共有 (export/import and sync). 常駐・ログイン起動・メニューバー stay per Mac.
    static let sharedKeys: Set<String> = ["notifyEnabled", "mailEnabled", "mailAddress", "mailTime", "watchRemoveOld"]

    /// Re-reads the shared settings after an import so the next save does not write the old values back.
    func reloadSharedSettings() {
        notifyEnabled = defaults.object(forKey: "notifyEnabled") as? Bool ?? true
        mailAddress = defaults.string(forKey: "mailAddress") ?? ""
        watchRemoveOld = defaults.object(forKey: "watchRemoveOld") as? Bool ?? true
        mailTime = defaults.object(forKey: "mailTime") as? Int ?? CCAutoUpdate.defaultMailTime
        mailEnabled = defaults.bool(forKey: "mailEnabled")
    }

    /// The 以前のバージョンを削除 line, or "" when not watched or none checked.
    var removeOldText: String {
        let list = CCAutoUpdate.removeOldList(state, separator: L("listSeparator"))
        return watchRemoveOld && !list.isEmpty ? String(format: L("removeOldOn"), list) : ""
    }

    /// Re-reads the file, updates the display, and sends whatever notification or mail is due.
    func check() {
        state = CCAutoUpdate.read()
        status = summary()
        onChange?()
        let signature = CCAutoUpdate.signature(state, watchRemoveOld: watchRemoveOld)
        if signature.isEmpty {
            notifiedSignature = ""
        } else if signature != notifiedSignature && signature != notifyingSignature && notifyEnabled {
            notifyingSignature = signature
            Notifier.shared.post(title: notifyTitle(), body: notifyBody()) { [weak self] accepted in
                guard let self else { return }
                self.notifyingSignature = nil
                if accepted { self.notifiedSignature = signature }
            }
        }
        if mailEnabled, CCAutoUpdate.isValidAddress(mailAddress),
           CCAutoUpdate.mailDue(state, watchRemoveOld: watchRemoveOld, lastSent: lastMail, minutes: mailTime) { sendMail(test: false) }
    }

    /// Wakes at the next send time (the hourly recheck alone could be up to an hour late). Re-armed after each firing.
    func scheduleMailTimer() {
        mailTimer?.invalidate()
        let fire = CCAutoUpdate.nextMailSlot(minutes: mailTime, after: Date())
        let timer = Timer(fire: fire.addingTimeInterval(1), interval: 0, repeats: false) { [weak self] _ in
            self?.check(); self?.scheduleMailTimer()
        }
        RunLoop.main.add(timer, forMode: .common)
        mailTimer = timer
    }

    private func notifyTitle() -> String { state.level == .on ? L("notifyTitle") : L("removeOldTitle") }
    private func notifyBody() -> String {
        var lines: [String] = []
        if state.level == .on { lines.append(String(format: L("notifyBody"), CCAutoUpdate.appList(state, separator: L("listSeparator")))) }
        if !removeOldText.isEmpty { lines.append(removeOldText) }
        return lines.joined(separator: "\n")
    }

    func summary() -> String {
        switch state.level {
        case .unknown: return state.files.isEmpty ? L("notFound") : L("invalidFile")
        case .off: return L("levelOff")
        case .caution: return L("levelCaution")
        case .on: return String(format: L("levelOn"), CCAutoUpdate.appList(state, separator: L("listSeparator")))
        }
    }

    /// `test`: send now regardless of the state and without counting as today's mail.
    func sendMail(test: Bool) {
        guard !sending else { return }
        let address = mailAddress.trimmingCharacters(in: .whitespaces)
        guard CCAutoUpdate.isValidAddress(address) else { mailStatus = L("mailInvalidAddress"); return }
        let host = CCAutoUpdate.mailMachineName(displayName: Host.current().localizedName, hostName: ProcessInfo.processInfo.hostName)
        let subject = test ? String(format: L("mailTestSubject"), host) : String(format: L(state.level == .on ? "mailSubject" : "mailSubjectRemoveOld"), host)
        let body = (test ? L("mailTestBody") + "\n\n" : "") + mailBody(host: host)
        sending = true
        mailStatus = L("mailSending")
        mailQueue.async {
            let error = Mailer.send(to: address, subject: subject, body: body)
            DispatchQueue.main.async {
                self.sending = false
                let time = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
                if let error { self.mailStatus = error; return }
                if !test { self.lastMail = Date() }
                self.mailStatus = String(format: L(test ? "mailTestSent" : "mailSent"), address, time)
            }
        }
    }

    private func mailBody(host: String) -> String {
        var lines = [String(format: L("mailIntro"), host),
                     String(format: L("mailSourceMac"), host),
                     String(format: L("mailSourceHost"), CCAutoUpdate.mailMachineName(displayName: nil, hostName: ProcessInfo.processInfo.hostName)),
                     "", L("globalRow") + L("colon") + valueText(state.global)]
        lines += state.apps.map { "- " + $0.name + "\n    " + L("globalRowShort") + L("colon") + (state.autoUpdateActive($0) ? valueText($0.value) : "—")
            + L("mailFieldSeparator") + L("removeOldShortTitle") + L("colon") + (state.removeOldActive($0) ? ($0.removeOld ? L("stateOn") : L("stateOff")) : "—") }
        if !removeOldText.isEmpty { lines += ["", removeOldText] }
        lines += ["", L("mailHowTo"), "", "— CCAutoUpdateOff"]
        return lines.joined(separator: "\n")
    }

    func valueText(_ value: AutoUpdateValue) -> String {
        value == false ? L("stateOff") : L("stateOn")
    }
}

struct Header: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView {
        let header = appHeader(L("headline"), subtitle: L("subtitle"))
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
    let value: AutoUpdateValue
    var body: some View {
        switch value {
        case .some(false): Label(L("stateOff"), systemImage: "checkmark.circle.fill").foregroundColor(.green)
        case .some(true): Label(L("stateOn"), systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
        // No value: Creative Cloud shows the switch as on.
        case .none: Label(L("stateOn"), systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
        }
    }
}

/// Column widths of the list (アプリ名 | 自動更新 | 以前のバージョンを削除).
enum Columns {
    static let autoUpdate: CGFloat = 130
    static let removeOld: CGFloat = 190
}

struct RemoveOldBadge: View {
    let on: Bool
    var body: some View {
        if on { Label(L("stateOn"), systemImage: "trash.circle.fill").foregroundColor(.orange) }
        else { Label(L("stateOff"), systemImage: "checkmark.circle.fill").foregroundColor(.green) }
    }
}

struct ColumnHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text(L("columnApp")).frame(maxWidth: .infinity, alignment: .leading)
            Text(L("globalRowShort")).frame(width: Columns.autoUpdate, alignment: .leading)
            Text(L("removeOldShortTitle")).frame(width: Columns.removeOld, alignment: .leading)
        }
        .font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
        .padding(.horizontal, 14).padding(.vertical, 6)
    }
}

struct Row: View {
    let title: String
    let value: AutoUpdateValue
    /// nil: no per-app value (the global row).
    var removeOld: Bool?
    /// The global switch is off, so the per-app auto-update value has no effect (Creative Cloud greys it out): dimmed, shown as —.
    var inactive = false
    /// 以前のバージョンを削除 has no effect (auto-update not active for this app): shown as —.
    var removeOldInactive = false
    var bold = false
    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 13, weight: bold ? .semibold : .regular)).lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if inactive { Text("—").foregroundColor(.secondary) } else { StateBadge(value: value) }
            }
            .font(.system(size: 12)).frame(width: Columns.autoUpdate, alignment: .leading)
            Group {
                if let removeOld, !inactive, !removeOldInactive { RemoveOldBadge(on: removeOld) } else { Text("—").foregroundColor(.secondary) }
            }
            .font(.system(size: 12)).frame(width: Columns.removeOld, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .opacity(inactive ? 0.4 : 1)
        .accessibilityElement(children: .combine)
    }
}

struct LevelBanner: View {
    let level: CCState.Level
    let text: String
    var body: some View {
        let (symbol, color): (String, Color) = {
            switch level {
            case .off: return ("checkmark.shield.fill", .green)
            case .caution: return ("exclamationmark.circle.fill", .yellow)
            case .on: return ("exclamationmark.triangle.fill", .orange)
            case .unknown: return ("questionmark.circle.fill", .secondary)
            }
        }()
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).foregroundColor(color).font(.system(size: 16))
            Text(text).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ContentView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Header().frame(height: 48)
            LevelBanner(level: model.state.level, text: model.status)
            if !model.removeOldText.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "trash.circle.fill").foregroundColor(.orange).font(.system(size: 16))
                    Text(model.removeOldText).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }.accessibilityElement(children: .combine)
            }
            VStack(spacing: 0) {
                if model.state.files.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.largeTitle).foregroundColor(.secondary)
                        Text(L("notFound")).font(.system(size: 14, weight: .medium))
                        Text(L("notFoundDetail")).font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
                } else {
                    ColumnHeader()
                    Divider()
                    Row(title: L("globalRow"), value: model.state.global, bold: true)
                    Divider()
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(model.state.apps) { app in
                                Row(title: app.name, value: app.value, removeOld: app.removeOld, inactive: !model.state.autoUpdateActive(app),
                                    removeOldInactive: !model.state.removeOldActive(app))
                                if app != model.state.apps.last { Divider().padding(.leading, 14) }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(L("note")).font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L("settingsButton")) { delegate.showPreferences() }
                Spacer()
                Button(L("reload")) { model.check() }
                Button(L("openCC")) { Mailer.openCreativeCloud() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(minWidth: 620, minHeight: 480).background(Color(nsColor: AppSurface.color))
    }
}

struct NotifySettings: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("targetSection")) {
                Text(L("targetAutoUpdate")).fixedSize(horizontal: false, vertical: true)
                Toggle(L("removeOldToggle"), isOn: $model.watchRemoveOld)
                Text(L("removeOldHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            SettingsSection(L("notifySection")) {
                NotificationPermissionView(enabled: $model.notifyEnabled, toggleTitle: L("notifyToggle"), sound: true)
                Text(L("notifyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(L("notifyTest")) {
                    NotificationPreferences.shared.request(sound: true) { granted in
                        if granted { Notifier.shared.post(title: L("notifyTitle"), body: L("notifyTestBody"), test: true) }
                    }
                }
            }

            SettingsSection(L("mailSection")) {
                Toggle(L("mailToggle"), isOn: $model.mailEnabled)
                HStack {
                    Text(L("mailTime"))
                    DatePicker("", selection: $model.mailTimeDate, displayedComponents: .hourAndMinute).labelsHidden().fixedSize()
                }
                HStack {
                    Text(L("mailTo"))
                    TextField("name@example.com", text: $model.mailAddress).textFieldStyle(.roundedBorder).frame(maxWidth: 280)
                }
                if !model.mailAddress.isEmpty, !CCAutoUpdate.isValidAddress(model.mailAddress) {
                    Text(L("mailInvalidAddress")).font(.caption).foregroundColor(.red)
                }
                Text(L("mailHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(L("mailTest")) { model.sendMail(test: true) }
                    .disabled(model.sending || !CCAutoUpdate.isValidAddress(model.mailAddress))
                if !model.mailStatus.isEmpty {
                    Text(model.mailStatus).font(.caption).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
            }
        }
    }
}

struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(SettingsSection(SettingsUI.launchTitle) {
                LoginAtLaunchView()
                Toggle(L("keepRunning"), isOn: $model.keepRunning)
                Text(L("keepRunningHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                MenuBarPresenceView()
            })),
            (L("notifyTab"), AnyView(NotifySettings(model: model))),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    let model = Model()
    var mainWindow: NSWindow!
    var preferences: NSWindow?
    var helpWindow: NSWindow?
    var item: NSStatusItem!
    var stateItem: NSMenuItem!
    lazy var watcher = FolderWatcher { [weak self] in self?.model.check() }
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.takano.CCAutoUpdateOff").sorted(by: { ($0.launchDate ?? .distantPast) == ($1.launchDate ?? .distantPast) ? $0.processIdentifier < $1.processIdentifier : ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }).first, other.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            other.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]); NSApp.terminate(nil); return
        }
        let loginLaunch = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        WindowActivationPolicy.install()
        installMenus()
        Notifier.shared.setUp()
        mainWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 560), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        mainWindow.title = ""; mainWindow.titleVisibility = .hidden; mainWindow.isReleasedWhenClosed = false; mainWindow.delegate = self
        mainWindow.contentView = NSHostingView(rootView: ContentView(model: model)); mainWindow.minSize = NSSize(width: 620, height: 480)
        mainWindow.center(); mainWindow.setFrameAutosaveName("CCAutoUpdateOffMain")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(mainWindow.frame) }) { mainWindow.center() }
        // The status item reflects the state, so it is ours; MenuBarPresence handles showing/hiding it (on by default).
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu(); menu.delegate = self
        stateItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: ""); stateItem.isEnabled = false
        menu.addItem(.separator())
        addItem(menu, L("openMainWindow"), #selector(showMain))
        addItem(menu, L("openCC"), #selector(openCreativeCloud))
        addItem(menu, L("settings"), #selector(showPreferences))
        let help = NSMenu(title: L("help")); addItem(help, L("helpItem"), #selector(showHelp)); MainActor.assumeIsolated { HelpLinks.addNoteItem(to: help) }
        menu.setSubmenu(help, for: menu.addItem(withTitle: L("help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(withTitle: L("quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "").target = NSApp
        item.menu = menu
        model.onChange = { [weak self] in self?.updateStatusItem() }
        MainActor.assumeIsolated {
            MenuBarPresence.shared.install(name: "CCAutoUpdateOff", symbol: "icloud", existing: item, keepExistingImage: true,
                show: { [weak self] in self?.showMain() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in self?.showHelp() })
        }
        model.check()
        model.scheduleMailTimer()
        SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings() }
        SettingsSync.shared.start(.init(keys: Model.sharedKeys, prefixes: [],
            note: StartupWindow.text("知らせる内容・通知・メール送信（宛先と送信時刻）の設定を書き出し・同期します。",
                                     "Exports and syncs what to report, notifications and mail (address and send time).",
                                     "导出并同步提醒内容、通知和发送邮件（收件人与发送时间）的设置。",
                                     "알릴 내용, 알림, 메일 보내기(받는 사람과 보낼 시각) 설정을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・常駐・メニューバーのアイコンはMacごとに設定します。",
                                       "Open at login, staying in the background and the menu bar icon are set on each Mac.",
                                       "登录时启动、保持运行和菜单栏图标在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 백그라운드 유지, 메뉴 막대 아이콘은 Mac마다 설정합니다.")))
        // Safety net if a file event or the send-time timer was missed.
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in self?.recheck() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(recheck), name: NSWorkspace.didWakeNotification, object: nil)
        if !loginLaunch && !StartupWindow.suppressInitialWindow { showMain() }
    }

    func addItem(_ menu: NSMenu, _ title: String, _ sel: Selector, _ key: String = "") {
        menu.addItem(withTitle: title, action: sel, keyEquivalent: key).target = self
    }

    func updateStatusItem() {
        let symbol: String
        switch model.state.level {
        case .off: symbol = model.removeOldText.isEmpty ? "checkmark.icloud" : "exclamationmark.icloud"
        case .caution: symbol = "exclamationmark.icloud"
        case .on: symbol = "exclamationmark.icloud.fill"
        case .unknown: symbol = "icloud.slash"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: model.status)
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        item?.button?.image = image
        item?.button?.toolTip = "CCAutoUpdateOff — " + model.status
        stateItem?.title = model.status
    }

    func installMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        func submenu(_ name: String) -> NSMenu { let item = NSMenuItem(); let menu = NSMenu(title: name); item.submenu = menu; bar.addItem(item); return menu }
        func add(_ m: NSMenu, _ title: String, _ sel: Selector, _ key: String = "", _ target: AnyObject? = nil) { let i = m.addItem(withTitle: title, action: sel, keyEquivalent: key); i.target = target ?? self }
        let app = submenu("CCAutoUpdateOff")
        add(app, L("about"), #selector(about)); app.addItem(.separator())
        // MenuBarPresence inserts メニューバー設定… at index 2, between these separators.
        add(app, L("settings"), #selector(showPreferences), ",")
        app.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        MainActor.assumeIsolated { AppUpdates.shared.addMenuItems(to: app) }
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
        add(file, L("reload"), #selector(recheck), "r")
        add(file, L("openCC"), #selector(openCreativeCloud))
        file.addItem(.separator())
        add(file, L("close"), #selector(NSWindow.performClose(_:)), "w"); file.items.last?.target = nil
        let edit = submenu(L("edit"))
        for (key, selector, letter) in [("undo", "undo:", "z"), ("redo", "redo:", "Z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("paste", "paste:", "v"), ("selectAll", "selectAll:", "a")] { let i = edit.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: letter); i.target = nil; if key == "redo" { edit.addItem(.separator()) } }
        let window = submenu(L("window"))
        for (key, selector, letter) in [("minimize", "performMiniaturize:", ""), ("zoom", "performZoom:", "")] { window.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: letter).target = nil }
        window.addItem(.separator())
        window.addItem(withTitle: L("bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "").target = NSApp
        NSApp.windowsMenu = window
        let help = submenu(L("help")); add(help, L("helpItem"), #selector(showHelp), "?"); MainActor.assumeIsolated { HelpLinks.addNoteItem(to: help) }; NSApp.helpMenu = help
    }
    func menuWillOpen(_ menu: NSMenu) { model.check() }
    @objc func showMain() { guard mainWindow != nil else { return }; NSApp.activate(ignoringOtherApps: true); mainWindow.makeKeyAndOrderFront(nil) }
    @objc func recheck() { watcher.start(); model.scheduleMailTimer(); model.check() }
    @objc func openCreativeCloud() { Mailer.openCreativeCloud() }
    @objc func showPreferences() {
        if preferences == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 560), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            w.title = L("settingsTitle"); w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: Preferences(model: model)); w.center(); w.setFrameAutosaveName("CCAutoUpdateOffSettings")
            preferences = w
        }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        StartupWindow.userRequestedWindow(); showMain(); return true }
    func applicationDidBecomeActive(_ notification: Notification) { model.check() }
    /// Watching needs the app to keep running; with 常駐 off, closing the main window quits.
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === mainWindow else { return }
        if !model.keepRunning { NSApp.terminate(nil) }
    }
    @objc func showHelp() {
        if helpWindow == nil {
            helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: "CCAutoUpdateOff — " + L("help"), text: L("helpContent")) }
        }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options: [.credits: NSAttributedString(string: L("support"))]) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate; app.setActivationPolicy(.accessory); app.run()
