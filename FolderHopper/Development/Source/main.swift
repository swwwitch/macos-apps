import AppKit
import CoreImage
import ServiceManagement
import UserNotifications

// Finder's tag-based folder colors are not included in icon(forFile:).
func folderIcon(for url: URL) -> NSImage {
    let original = NSWorkspace.shared.icon(forFile: url.path)
    let values = try? url.resourceValues(forKeys: [.labelNumberKey, .customIconKey])
    guard values?.customIcon == nil, let label = values?.labelNumber, label > 0 else { return original }
    let colors: [NSColor] = [.clear, .systemGray, .systemGreen, .systemPurple,
                             .systemBlue, .systemYellow, .systemRed, .systemOrange]
    guard colors.indices.contains(label),
          let data = original.tiffRepresentation, let input = CIImage(data: data),
          let filter = CIFilter(name: "CIColorMonochrome") else { return original }
    filter.setValue(input, forKey: kCIInputImageKey)
    filter.setValue(CIColor(color: colors[label]), forKey: kCIInputColorKey)
    filter.setValue(1.0, forKey: kCIInputIntensityKey)
    guard let output = filter.outputImage else { return original }
    let result = NSImage(size: original.size)
    result.addRepresentation(NSCIImageRep(ciImage: output))
    return result
}

if CommandLine.arguments.contains("--probe-history") {
    let history = FolderHistory.read()
    print("Readable existing folder history: \(history.items.count)")
    for origin in Set(history.items.map(\.origin)).sorted() { print("\(origin): \(history.items.filter { $0.origin == origin }.count)") }
    for note in history.notes { print(note) }
    exit(history.items.isEmpty ? 1 : 0)
}

// Dynamic colors preserve the light palette and resolve against each view's appearance.
enum AppColors {
    static func gray(_ name: String, light: CGFloat, dark: CGFloat) -> NSColor {
        NSColor(name: NSColor.Name(name)) { appearance in
            NSColor(calibratedWhite: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light, alpha: 1)
        }
    }
    static let window = gray("Window", light: 0.94, dark: 0.16)
    static let list = gray("List", light: 1, dark: 0.11)
    static let stripe = gray("Stripe", light: 0.95, dark: 0.16)
    static let divider = gray("Divider", light: 0.68, dark: 0.38)
}

final class DividerView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        AppColors.divider.setFill()
        bounds.fill()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

final class FavoriteSelectionView: NSStackView {
    var selected = false { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard selected else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        NSColor.selectedContentBackgroundColor.withAlphaComponent(0.18).setFill()
        path.fill()
        NSColor.selectedContentBackgroundColor.setStroke()
        path.lineWidth = 2
        path.stroke()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

final class FolderRowView: NSTableRowView {
    var stripeColor: NSColor = AppColors.list
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
    override func drawBackground(in dirtyRect: NSRect) {
        stripeColor.setFill()
        dirtyRect.fill()
    }
}

final class FavoriteConfigurationButton: NSButton {
    override var acceptsFirstResponder: Bool { false }
}

final class FavoriteButton: NSButton {
    weak var selectionPanel: FavoriteSelectionView?
    override var state: NSControl.StateValue {
        didSet { selectionPanel?.selected = state == .on }
    }
    override var acceptsFirstResponder: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuItemValidation, NSTextFieldDelegate, UNUserNotificationCenterDelegate {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 680), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    let table = NSTableView()
    var favoriteButtons: [NSButton] = []
    /// 「フォルダを選択…」 in the 指定 section; part of the ←/→ cycle before the favorites.
    weak var chooserButton: FavoriteButton?
    static let chooserTag = -1
    /// 「デスクトップ」, to the right of 「フォルダを選択…」 in the same section.
    weak var desktopButton: FavoriteButton?
    static let desktopTag = -2
    /// 指定・デスクトップ first, then the favorites, in on-screen order.
    var selectableButtons: [NSButton] { [chooserButton, desktopButton].compactMap { $0 } + favoriteButtons }
    var selectedFavoriteIndex: Int?
    var selectedSourceID: String?
    let operationHint = NSTextField(labelWithString: "")
    let symbolicLinks = NSButton(checkboxWithTitle: L("シンボリックリンクとして作成"), target: nil, action: nil)
    let copies = NSButton(checkboxWithTitle: L("複製"), target: nil, action: nil)
    let summary = NSTextField(labelWithString: "")
    let status = NSTextField(wrappingLabelWithString: "")
    /// Shown under the status while Finder / Path Finder automation is refused.
    lazy var automationButton: NSButton = {
        let button = NSButton(title: L("オートメーションの設定を開く…"), target: self, action: #selector(openAutomationSettings))
        button.bezelStyle = .rounded; button.isHidden = true
        return button
    }()
    let shortenDropbox = NSButton(checkboxWithTitle: L("Dropboxのパスを簡易表示"), target: nil, action: nil)
    let showFavorites = NSButton(checkboxWithTitle: L("お気に入りセクションを表示"), target: nil, action: nil)
    let showChooser = NSButton(checkboxWithTitle: L("「指定・デスクトップ」セクションを表示"), target: nil, action: nil)
    var preferencesWindow: NSWindow?
    let globalShortcut = GlobalShortcut()
    let shortcutEnabled = NSButton(checkboxWithTitle: L("ホットキーでウインドウを表示"), target: nil, action: nil)
    let shortcutModifiers = NSPopUpButton()
    let shortcutKey = NSPopUpButton()
    let shortcutStatus = NSTextField(wrappingLabelWithString: "")
    let applicationsShortcutEnabled = NSButton(checkboxWithTitle: L("⌃⌥⌘⇧Aで選択項目を「アプリケーション」へ移動"), target: nil, action: nil)
    let applicationsShortcutStatus = NSTextField(wrappingLabelWithString: "")
    let loginEnabled = NSButton(checkboxWithTitle: L("ログイン時に自動起動"), target: nil, action: nil)
    let loginInBackground = NSButton(checkboxWithTitle: L("ログイン時はウインドウを表示せず、バックグラウンドで起動"), target: nil, action: nil)
    let loginStatus = NSTextField(wrappingLabelWithString: "")
    let renameConflicts = NSPopUpButton()
    let historyLimit = NSTextField(string: "0")
    let closeAfterOperation = NSButton(checkboxWithTitle: L("処理完了後にウインドウを閉じる（常駐は継続）"), target: nil, action: nil)
    var hiddenHistory = Set(UserDefaults.standard.stringArray(forKey: "hiddenHistoryPaths") ?? [])
    let queue = DispatchQueue(label: "FolderMover.io", qos: .userInitiated)
    var states: [BrowserState] = []
    var current: [Destination] = []
    var history: [Destination] = []
    var rows: [Row] = []
    var busy = false
    var lastBrowser: String?
    var uiReady = false
    var pendingOpenFiles: [URL]?
    var activationRefresh: DispatchWorkItem?
    enum Row { case heading(String), folder(Destination), favorites, choose }
    var chosen: BrowserState? {
        states.first { $0.id == selectedSourceID }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        defer { DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MenuBarPresence.shared.install(name: "FolderHopper", symbol: "folder", existing: nil,
                show: { [weak self] in self?.window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in LocalHelp.shared.show() })
        } }
        DispatchQueue.main.async { LocalHelp.shared.install() }
        #if APP_STORE
        _ = FolderAccess.shared
        #endif
        let loginLaunch = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        UserDefaults.standard.register(defaults: ["loginInBackground": true])
        loginInBackground.state = UserDefaults.standard.bool(forKey: "loginInBackground") ? .on : .off
        loginInBackground.target = self; loginInBackground.action = #selector(loginBackgroundChanged)
        lastBrowser = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().setNotificationCategories([])
        buildUI()
        setupShortcut()
        UserDefaults.standard.register(defaults: ["showFavorites": true, "showChooser": true])
        showChooser.state = UserDefaults.standard.bool(forKey: "showChooser") ? .on : .off
        showChooser.target = self; showChooser.action = #selector(chooserVisibilityChanged)
        showFavorites.state = UserDefaults.standard.bool(forKey: "showFavorites") ? .on : .off
        showFavorites.target = self; showFavorites.action = #selector(favoritesVisibilityChanged)
        loginEnabled.target = self; loginEnabled.action = #selector(loginChanged)
        renameConflicts.target = self; renameConflicts.action = #selector(renameConflictsChanged)
        UserDefaults.standard.register(defaults: ["renameConflicts": true, "historyDisplayLimit": 0, "closeAfterOperation": true])
        renameConflicts.addItems(withTitles: [L("別名にして両方残す（連番を付ける）"), L("処理を中止する（上書きしない）")])
        renameConflicts.selectItem(at: UserDefaults.standard.bool(forKey: "renameConflicts") ? 0 : 1)
        renameConflicts.setAccessibilityLabel(L("移動先に同名のファイルがあるとき"))
        historyLimit.integerValue = UserDefaults.standard.integer(forKey: "historyDisplayLimit")
        historyLimit.delegate = self
        historyLimit.setAccessibilityLabel(L("最近使ったウインドウの数"))
        closeAfterOperation.state = UserDefaults.standard.bool(forKey: "closeAfterOperation") ? .on : .off
        closeAfterOperation.target = self; closeAfterOperation.action = #selector(closeAfterChanged)
        updateLoginStatus()
        window.center()
        if (!StartupWindow.hidden || pendingOpenFiles != nil) && !LaunchPolicy.shouldStayInBackground(loginLaunch: loginLaunch, enabled: loginInBackground.state == .on, hasFiles: pendingOpenFiles != nil) {
            requestTransfer()
        }
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        var seen = Set<String>()
        let files = filenames.map { URL(fileURLWithPath: $0).standardizedFileURL }
            .filter { seen.insert($0.path).inserted }
        if !files.isEmpty { pendingOpenFiles = files }
        // Accept the Open Documents event as a transfer request, without parsing document contents.
        sender.reply(toOpenOrPrint: .success)
        guard uiReady else { return }
        if !busy { requestTransfer() }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if busy {
            let alert = NSAlert(); alert.messageText = L("処理中のため終了できません"); alert.informativeText = L("ファイルの移動・複製・リンク作成が終わってから、もう一度終了してください。"); alert.addButton(withTitle: L("OK"))
            alert.runModal()
            return .terminateCancel
        }
        return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        guard uiReady else { return }
        updateLoginStatus()
        activationRefresh?.cancel()
        let refresh = DispatchWorkItem { [weak self] in
            guard let self, NSApp.isActive, self.window.isVisible,
                  self.window.attachedSheet == nil, !self.busy else { return }
            self.load(preservingReceivedFiles: true)
        }
        activationRefresh = refresh
        // Open With / reopen / hotkey may request their own refresh during activation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: refresh)
    }
    func applicationDidResignActive(_ notification: Notification) {
        activationRefresh?.cancel()
        activationRefresh = nil
    }
    func applyPendingOpenFiles() -> Bool {
        guard let files = pendingOpenFiles else { return false }
        pendingOpenFiles = nil
        states.append(BrowserState(id: "opened-files", name: L("受け取ったファイル"), files: files))
        return true
    }
    @objc func activated(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           BrowserReader.apps().contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) { lastBrowser = app.bundleIdentifier }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Even while processing or with a sheet open, at least bring the window to the front.
        if busy || window.attachedSheet != nil { presentDestinations() } else { requestTransfer() }
        return true
    }
    func buildUI() {
        window.title = ""
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 540, height: 420)
        window.isReleasedWhenClosed = false
        window.backgroundColor = AppColors.window
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.collectionBehavior.insert(.fullScreenNone)
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        let aboutItem = appMenu.addItem(withTitle: L("FolderHopperについて"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(.separator())
        let preferencesItem = appMenu.addItem(withTitle: L("設定…"), action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        appMenu.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        MainActor.assumeIsolated { AppUpdates.shared.addMenuItems(to: appMenu) }
        #endif
        addStandardApplicationCommands(to: appMenu, name: "FolderHopper")
        let fileItem = NSMenuItem(title: L("ファイル"), action: nil, keyEquivalent: ""); menu.addItem(fileItem)
        let fileMenu = NSMenu(title: L("ファイル")); fileItem.submenu = fileMenu
        let showMainItem = fileMenu.addItem(withTitle: L("メインウインドウを開く"), action: #selector(showMainWindow), keyEquivalent: "0")
        showMainItem.target = self
        #if APP_STORE
        let choose = fileMenu.addItem(withTitle: L("ファイルを選択…"), action: #selector(chooseSourceFiles), keyEquivalent: "o")
        choose.target = self
        #endif
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: L("ウインドウを閉じる"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let editItem = NSMenuItem(title: L("編集"), action: nil, keyEquivalent: ""); menu.addItem(editItem)
        let edit = NSMenu(title: L("編集")); editItem.submenu = edit
        edit.addItem(withTitle: L("取り消す"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: L("やり直す"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        for (title, selector, key) in [(L("カット"), "cut:", "x"), (L("コピー"), "copy:", "c"), (L("ペースト"), "paste:", "v"), (L("すべてを選択"), "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        // Window menu (before Help, which LocalHelp appends later): BASELINE「メニューの共通構成」.
        let windowRoot = NSMenuItem(title: L("ウインドウ"), action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: L("ウインドウ")); windowRoot.submenu = windowMenu; menu.addItem(windowRoot)
        windowMenu.addItem(withTitle: L("しまう"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: L("拡大／縮小"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: L("すべてを手前に移動"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = menu
        AppSurface.install(in: window.contentView!)
        let root = NSStackView(); root.orientation = .vertical; root.alignment = .leading; root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20), root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20), root.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20), root.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -16)])
        root.addArrangedSubview(appHeader(L("選択したファイルを移動"), subtitle: L("移動先を選んで、移動・複製・リンク作成。")))
        #if APP_STORE
        let chooseFiles = NSButton(title: L("ファイルを選択…"), target: self, action: #selector(chooseSourceFiles))
        root.addArrangedSubview(chooseFiles)
        #endif
        summary.lineBreakMode = .byTruncatingMiddle
        let selectionRow = NSStackView(views: [summary, NSView(), symbolicLinks, copies])
        selectionRow.spacing = 12
        root.addArrangedSubview(selectionRow)
        selectionRow.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        summary.isHidden = true
        shortenDropbox.state = UserDefaults.standard.bool(forKey: "shortenDropboxPaths") ? .on : .off
        shortenDropbox.target = self
        shortenDropbox.action = #selector(pathDisplayChanged)
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = AppColors.list
        table.backgroundColor = AppColors.list
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("folder")); table.addTableColumn(column)
        table.headerView = nil; table.delegate = self; table.dataSource = self
        table.target = self; table.action = #selector(destinationSelected); table.doubleAction = #selector(moveClicked(_:)); table.allowsEmptySelection = true
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        scroll.documentView = table; root.addArrangedSubview(scroll)
        symbolicLinks.target = self; symbolicLinks.action = #selector(operationChanged)
        copies.target = self; copies.action = #selector(operationChanged)
        copies.toolTip = L("元のファイルを残し、選んだフォルダに複製します。")
        symbolicLinks.toolTip = L("元のファイルを残し、選んだフォルダにシンボリックリンクを作成します。")
        let hint = operationHint
        operationChanged()
        hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor; root.addArrangedSubview(hint)
        status.font = .systemFont(ofSize: 12); root.addArrangedSubview(status); root.addArrangedSubview(automationButton)
        let preferences = NSButton(title: L("設定…"), target: self, action: #selector(showPreferences))
        let footer = NSStackView(views: [NSView(), preferences]); footer.spacing = 12
        root.addArrangedSubview(footer)
        footer.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        for view in [scroll, status] { view.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true }
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window.isKeyWindow else { return event }
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == 48 && (modifiers.isEmpty || modifiers == .shift), self.window.attachedSheet == nil {
                self.switchDestinationSection()
                return nil
            }
            if (event.keyCode == 123 || event.keyCode == 124), modifiers.isEmpty,
               self.window.attachedSheet == nil,
               self.window.firstResponder === self.table || self.window.firstResponder is FavoriteButton {
                self.stepFavorite(event.keyCode == 124 ? 1 : -1)
                return nil
            }
            if event.keyCode == 53 && !self.busy { self.window.orderOut(nil); return nil }
            if (event.keyCode == 36 || event.keyCode == 76), self.window.attachedSheet == nil {
                if self.selectedFavoriteIndex == Self.chooserTag, let chooser = self.chooserButton, chooser.isEnabled {
                    self.chooseDestination(chooser)
                    return nil
                }
                if self.selectedFavoriteIndex == Self.desktopTag, let desktop = self.desktopButton, desktop.isEnabled {
                    self.moveToDesktop(desktop)
                    return nil
                }
                if let index = self.selectedFavoriteIndex, let url = self.favoriteURL(index) {
                    self.move(to: Destination(url: url, origin: L("お気に入り")), bringForward: modifiers.contains(.command), copying: modifiers.contains(.option), linking: modifiers.contains(.control))
                    return nil
                }
                if self.window.firstResponder === self.table { self.moveClicked(); return nil }
                if let button = self.window.firstResponder as? FavoriteButton, button.isEnabled {
                    if let url = self.favoriteURL(button.tag) {
                        self.move(to: Destination(url: url, origin: L("お気に入り")), bringForward: event.modifierFlags.contains(.command), copying: event.modifierFlags.contains(.option), linking: event.modifierFlags.contains(.control))
                    }
                    return nil
                }
            }
            return event
        }
        uiReady = true
    }
    @objc func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "FolderHopper",
            .applicationVersion: version,
            .version: build,
            .credits: NSAttributedString(string: L("開いているフォルダへ、ファイルをすばやく移動。"))
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showPreferences() {
        if preferencesWindow == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
                                 styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            panel.title = L("設定")
            panel.contentMinSize = NSSize(width: 620, height: 560)
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = AppColors.window
            var sections: [(String, NSView)] = []
            func group(_ title: String, _ controls: [NSView]) {
                sections.append((title, MainActor.assumeIsolated { SettingsUI.group(title, controls) }))
            }
            loginStatus.font = .systemFont(ofSize: 12); loginStatus.textColor = .secondaryLabelColor
            let keys = NSStackView(views: [shortcutModifiers, shortcutKey]); keys.spacing = 8
            shortcutStatus.font = .systemFont(ofSize: 12); shortcutStatus.textColor = .secondaryLabelColor
            group(SettingsUI.launchTitle, [loginEnabled, loginInBackground, loginStatus, MainActor.assumeIsolated { StartupWindowControl() }, MainActor.assumeIsolated { MenuBarPresence.shared.settingsControl() }, shortcutEnabled, keys, shortcutStatus])
            group(SettingsUI.displayTitle, [shortenDropbox, showChooser, showFavorites])
            let conflictLabel = NSTextField(labelWithString: L("移動先に同名のファイルがあるとき"))
            #if APP_STORE
            group(L("ファイル操作"), [conflictLabel, renameConflicts, closeAfterOperation])
            #else
            applicationsShortcutStatus.font = .systemFont(ofSize: 12); applicationsShortcutStatus.textColor = .secondaryLabelColor
            group(L("ファイル操作"), [conflictLabel, renameConflicts, closeAfterOperation, applicationsShortcutEnabled, applicationsShortcutStatus])
            #endif
            let limitRow = NSStackView(views: [NSTextField(labelWithString: L("最近使ったウインドウの数")), historyLimit, NSTextField(labelWithString: L("件（0＝すべて）"))])
            limitRow.spacing = 8
            historyLimit.widthAnchor.constraint(equalToConstant: 64).isActive = true
            let clear = NSButton(title: L("最近使ったウインドウをクリア"), target: self, action: #selector(clearRecentWindows))
            let restore = NSButton(title: L("再表示"), target: self, action: #selector(restoreRecentWindows))
            let historyHelp = NSTextField(wrappingLabelWithString: L("このアプリの一覧だけをクリアします。Finder／Path Finderの履歴は保持され、新しいフォルダは引き続き表示されます。"))
            historyHelp.font = .systemFont(ofSize: 12); historyHelp.textColor = .secondaryLabelColor
            group(L("履歴"), [limitRow, NSStackView(views: [clear, restore]), historyHelp])

            sections.append((AboutSection.title, MainActor.assumeIsolated { AboutSection.view() }))
            MainActor.assumeIsolated { SettingsUI.tabs(sections, in: panel.contentView!) }
            panel.center()
            preferencesWindow = panel
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }
    func updateLoginStatus() {
        let state = SMAppService.mainApp.status
        loginEnabled.state = state == .enabled || state == .requiresApproval ? .on : .off
        loginInBackground.isEnabled = loginEnabled.state == .on
        switch state {
        case .enabled: loginStatus.stringValue = L("自動起動は有効です。")
        case .requiresApproval: loginStatus.stringValue = L("システム設定 → 一般 → ログイン項目で許可してください。")
        default: loginStatus.stringValue = L("Macへのログイン時にFolderHopperを起動します。")
        }
    }
    @objc func loginBackgroundChanged() {
        UserDefaults.standard.set(loginInBackground.state == .on, forKey: "loginInBackground")
    }
    @objc func loginChanged() {
        do {
            if loginEnabled.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            updateLoginStatus()
        } catch {
            updateLoginStatus()
            loginStatus.stringValue = L("自動起動の変更に失敗しました: %@", String(describing: error.localizedDescription))
        }
    }
    @objc func renameConflictsChanged() {
        UserDefaults.standard.set(renameConflicts.indexOfSelectedItem == 0, forKey: "renameConflicts")
    }
    @objc func closeAfterChanged() {
        UserDefaults.standard.set(closeAfterOperation.state == .on, forKey: "closeAfterOperation")
    }
    @objc func chooserVisibilityChanged() {
        UserDefaults.standard.set(showChooser.state == .on, forKey: "showChooser")
        filterRows()
    }
    @objc func favoritesVisibilityChanged() {
        UserDefaults.standard.set(showFavorites.state == .on, forKey: "showFavorites")
        filterRows()
    }
    func controlTextDidEndEditing(_ notification: Notification) {
        guard notification.object as? NSTextField === historyLimit else { return }
        guard let count = Int(historyLimit.stringValue.trimmingCharacters(in: .whitespaces)), (0...10000).contains(count) else {
            historyLimit.integerValue = UserDefaults.standard.integer(forKey: "historyDisplayLimit")
            NSSound.beep()
            showError(L("最近使ったウインドウの数は0〜10000の整数で入力してください。元の値に戻しました。"))
            return
        }
        UserDefaults.standard.set(count, forKey: "historyDisplayLimit")
        historyLimit.integerValue = count
        filterRows()
    }
    @objc func clearRecentWindows() {
        hiddenHistory.formUnion(history.map { $0.url.standardizedFileURL.path })
        UserDefaults.standard.set(Array(hiddenHistory), forKey: "hiddenHistoryPaths")
        filterRows()
    }
    @objc func restoreRecentWindows() {
        hiddenHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: "hiddenHistoryPaths")
        filterRows()
    }
    func setupShortcut() {
        UserDefaults.standard.register(defaults: ["shortcutEnabled": true, "shortcutModifierIndex": 0, "shortcutKeyIndex": 12])
        shortcutModifiers.addItems(withTitles: GlobalShortcut.modifiers.map { $0.0 })
        shortcutKey.addItems(withTitles: GlobalShortcut.keys.map { $0.0 })
        shortcutModifiers.setAccessibilityLabel(L("ホットキーの修飾キー"))
        shortcutKey.setAccessibilityLabel(L("ホットキーのキー"))
        for control in [shortcutEnabled as NSControl, shortcutModifiers, shortcutKey] {
            control.target = self; control.action = #selector(shortcutChanged)
        }
        restoreShortcutControls()
        globalShortcut.action = { [weak self] in
            guard let self else { return }
            if let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
               BrowserReader.apps().contains(where: { $0.bundleIdentifier == id }) { self.lastBrowser = id }
            if !self.busy { self.requestTransfer() }
        }
        shortcutChanged()
        #if !APP_STORE
        UserDefaults.standard.register(defaults: ["applicationsShortcutEnabled": true])
        applicationsShortcutEnabled.state = UserDefaults.standard.bool(forKey: "applicationsShortcutEnabled") ? .on : .off
        applicationsShortcutEnabled.target = self; applicationsShortcutEnabled.action = #selector(applicationsShortcutChanged)
        globalShortcut.actions[2] = { [weak self] in self?.moveSelectionToApplications() }
        applicationsShortcutChanged()
        #endif
    }
    #if !APP_STORE
    /// ⌃⌥⌘⇧A (fixed): hotkey ID 2, independent of the window hotkey.
    @objc func applicationsShortcutChanged() {
        let enabled = applicationsShortcutEnabled.state == .on
        let shortcut = GlobalShortcut.applicationsShortcut
        if globalShortcut.configure(id: 2, enabled: enabled, key: shortcut.key, modifiers: shortcut.modifiers) {
            UserDefaults.standard.set(enabled, forKey: "applicationsShortcutEnabled")
            applicationsShortcutStatus.stringValue = L("ウインドウを表示せず、Finder／Path Finderで選択中の項目を移動します。常駐中に使用できます。")
        } else {
            applicationsShortcutEnabled.state = .off
            applicationsShortcutStatus.stringValue = L("⌃⌥⌘⇧Aは他のアプリが使用しているため登録できませんでした。")
        }
    }
    /// Reads the frontmost Finder/Path Finder selection and moves it to /Applications without showing the window.
    /// The window opens only to show an error; when there is nothing to move, a short message says why.
    func moveSelectionToApplications() {
        guard !busy, window.attachedSheet == nil else {
            NSSound.beep(); MainActor.assumeIsolated { TransientMessage.show(L("FolderHopperは処理中です。完了してからもう一度お試しください。")) }; return
        }
        let running = BrowserReader.apps()
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard let app = running.first(where: { $0.bundleIdentifier == frontmost })
                ?? running.first(where: { $0.bundleIdentifier == lastBrowser }) else {
            NSSound.beep(); MainActor.assumeIsolated { TransientMessage.show(L("Finder／Path Finderが起動していません。")) }; return
        }
        lastBrowser = app.bundleIdentifier
        let destination = Destination(url: URL(fileURLWithPath: "/Applications", isDirectory: true), origin: L("お気に入り"))
        setBusy(true)
        queue.async {
            let state = BrowserReader.read(app)
            DispatchQueue.main.async {
                self.setBusy(false)
                guard !state.files.isEmpty else {
                    if let error = state.error { self.showError(error, automation: state.automationDenied) } else { NSSound.beep(); MainActor.assumeIsolated { TransientMessage.show(L("Finder／Path Finderで項目が選択されていません。")) } }
                    return
                }
                if let reason = MoveEngine.destinationDisabledReason(state.files, into: destination.url) { self.showError(reason); return }
                self.move(to: destination, source: state)
            }
        }
    }
    #endif
    func restoreShortcutControls() {
        let defaults = UserDefaults.standard
        shortcutEnabled.state = defaults.bool(forKey: "shortcutEnabled") ? .on : .off
        let modifier = defaults.integer(forKey: "shortcutModifierIndex")
        let key = defaults.integer(forKey: "shortcutKeyIndex")
        shortcutModifiers.selectItem(at: GlobalShortcut.modifiers.indices.contains(modifier) ? modifier : 0)
        shortcutKey.selectItem(at: GlobalShortcut.keys.indices.contains(key) ? key : 12)
    }
    @objc func shortcutChanged() {
        let enabled = shortcutEnabled.state == .on
        let modifier = shortcutModifiers.indexOfSelectedItem
        let key = shortcutKey.indexOfSelectedItem
        if globalShortcut.configure(enabled: enabled, key: GlobalShortcut.keys[key].1, modifiers: GlobalShortcut.modifiers[modifier].1) {
            UserDefaults.standard.set(enabled, forKey: "shortcutEnabled")
            UserDefaults.standard.set(modifier, forKey: "shortcutModifierIndex")
            UserDefaults.standard.set(key, forKey: "shortcutKeyIndex")
            shortcutStatus.stringValue = L("常駐中に使用できます。アプリを終了した場合は、先に起動してください。")
        } else {
            restoreShortcutControls()
            shortcutStatus.stringValue = L("このキーは登録できませんでした。他の組み合わせを選んでください。")
        }
        shortcutModifiers.isEnabled = shortcutEnabled.state == .on
        shortcutKey.isEnabled = shortcutEnabled.state == .on
    }
    /// File menu ⌘0: same path as reopening from the Dock. The window is kept (isReleasedWhenClosed = false).
    @objc func showMainWindow() {
        NSApp.unhide(nil)
        if busy || window.attachedSheet != nil { presentDestinations() } else { requestTransfer() }
    }
    func presentDestinations() {
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(table)
    }
    func requestTransfer() {
        guard !busy, window.attachedSheet == nil else { return }
        presentDestinations()
        load(preservingReceivedFiles: false)
    }
    #if APP_STORE
    @objc func chooseSourceFiles() {
        guard !busy, window.attachedSheet == nil else { return }
        let panel = NSOpenPanel()
        panel.title = L("ファイルを選択…")
        panel.canChooseFiles = true; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true; panel.treatsFilePackagesAsDirectories = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let self, !panel.urls.isEmpty else { return }
            do {
                for url in panel.urls { try FolderAccess.shared.remember(url) }
                self.pendingOpenFiles = panel.urls
                DispatchQueue.main.async { self.requestTransfer() }
            } catch { self.showError(error.localizedDescription) }
        }
    }
    #endif
    @objc func load() {
        load(preservingReceivedFiles: false)
    }
    func load(preservingReceivedFiles: Bool) {
        activationRefresh?.cancel()
        activationRefresh = nil
        guard !busy else { return }
        #if APP_STORE
        let received = chosen?.id == "opened-files" ? chosen : nil
        #else
        let received = preservingReceivedFiles && chosen?.id == "opened-files" ? chosen : nil
        #endif
        setBusy(true); status.stringValue = L("ウインドウと既存のフォルダ履歴を読み込んでいます…")
        let apps = BrowserReader.apps()
        let preferred = lastBrowser ?? chosen?.id
        queue.async {
            let states = apps.map { BrowserReader.read($0) }
            let history = FolderHistory.read()
            DispatchQueue.main.async {
                self.states = states
                self.current = states.flatMap(\.destinations)
                self.history = history.items
                let receivedFiles = self.applyPendingOpenFiles()
                if !receivedFiles, let received { self.states.append(received) }
                self.selectedSourceID = nil
                if receivedFiles || received != nil { self.selectedSourceID = "opened-files" }
                else if let state = states.first(where: { $0.id == preferred && !$0.files.isEmpty }) { self.selectedSourceID = state.id }
                else {
                    let selected = states.filter { !$0.files.isEmpty }
                    if selected.count == 1 { self.selectedSourceID = selected[0].id }
                }
                self.setBusy(false); self.sourceChanged(); self.filterRows()
                self.focusOpenDestination()
                let errors = states.compactMap(\.error) + history.notes
                self.status.stringValue = errors.joined(separator: "\n")
                self.status.isHidden = errors.isEmpty
                self.automationButton.isHidden = !states.contains(where: \.automationDenied)

            }
        }
    }
    @objc func operationChanged(_ sender: NSButton? = nil) {
        let linking = symbolicLinks.state == .on
        if linking { copies.state = .off }
        copies.isEnabled = !busy && !linking
        window.title = linking ? L("選択したファイルのリンクを作成") : copies.state == .on ? L("選択したファイルを複製") : L("選択したファイルを移動")
        operationHint.stringValue = linking
            ? L("Return：シンボリックリンク作成　⌥Return：無効　⌘併用：移動先を開く。")
            : L("Return：実行　⌥Return：複製　⌃Return：シンボリックリンク作成　⌘併用：移動先を開く。")
        table.reloadData()
    }
    @objc func sourceChanged() {
        selectedFavoriteIndex = nil
        table.deselectAll(nil)
        table.reloadData()
        summary.toolTip = nil
        summary.stringValue = ""
        summary.isHidden = true
        guard let chosen, !chosen.files.isEmpty else { return }
        summary.stringValue = L("%@項目を選択中", String(describing: chosen.files.count))
        summary.isHidden = false
    }
    func focusOpenDestination() {
        guard !busy else { return }
        table.deselectAll(nil)
        // Only choose from the open-window section; never silently choose history.
        for row in rows.indices.dropFirst() {
            guard case .folder(let destination) = rows[row] else { break }
            if disabledReason(destination) == nil {
                table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                table.scrollRowToVisible(row)
                break
            }
        }
        if window.isKeyWindow { window.makeFirstResponder(table) }
    }
    func switchDestinationSection() {
        selectedFavoriteIndex = nil
        activationRefresh?.cancel()
        activationRefresh = nil
        guard !busy else { return }
        var openRows: [Int] = [], recentRows: [Int] = []
        var section = ""
        for (index, entry) in rows.enumerated() {
            switch entry {
            case .heading(let name): section = name
            case .folder(let destination):
                guard disabledReason(destination) == nil else { continue }
                if section == L("現在開いているウインドウ") { openRows.append(index) }
                if section == L("最近使ったウインドウ") { recentRows.append(index) }
            case .favorites, .choose: break
            }
        }
        for button in selectableButtons { button.state = .off }
        let target = openRows.contains(table.selectedRow) ? recentRows : openRows
        window.makeFirstResponder(table)
        guard let first = target.first else { NSSound.beep(); return }
        table.selectRowIndexes(IndexSet(integer: first), byExtendingSelection: false)
        table.scrollRowToVisible(first)
    }
    func displayPath(_ url: URL, abbreviateHome: Bool = true) -> String {
        let path = url.path
        if shortenDropbox.state == .on {
            let components = url.pathComponents
            if let index = components.firstIndex(of: "Dropbox-shared") {
                return "/" + components[index...].joined(separator: "/")
            }
        }
        return abbreviateHome ? (path as NSString).abbreviatingWithTildeInPath : path
    }
    @objc func pathDisplayChanged() {
        UserDefaults.standard.set(shortenDropbox.state == .on, forKey: "shortenDropboxPaths")
        sourceChanged()
    }
    @objc func filterRows() {
        selectedFavoriteIndex = nil
        var seen = Set<String>()
        func filtered(_ entries: [Destination]) -> [Destination] {
            entries.filter { entry in
                seen.insert(entry.url.standardizedFileURL.path).inserted
            }
        }
        #if APP_STORE
        rows = []
        #else
        rows = [.heading(L("現在開いているウインドウ"))]
        rows += filtered(current).map(Row.folder)
        #endif
        if showChooser.state == .on { rows += [.heading(L("指定・デスクトップ")), .choose] }
        if showFavorites.state == .on { rows += [.heading(L("お気に入り")), .favorites] }
        rows += [.heading(L("最近使ったウインドウ"))]
        let recent = filtered(history.filter { !hiddenHistory.contains($0.url.standardizedFileURL.path) })
        let limit = UserDefaults.standard.integer(forKey: "historyDisplayLimit")
        rows += (limit > 0 ? Array(recent.prefix(limit)) : recent).map(Row.folder)
        table.reloadData(); table.deselectAll(nil)
    }
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if case .heading = rows[row] { return 30 }
        if case .favorites = rows[row] { return 122 }
        if case .choose = rows[row] { return 72 }
        return 48
    }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .folder(let destination) = rows[row] { return disabledReason(destination) == nil }; return false
    }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = FolderRowView()
        var folderIndex = 0
        for entry in rows.prefix(row) {
            switch entry {
            case .heading, .favorites, .choose: folderIndex = 0
            case .folder: folderIndex += 1
            }
        }
        if case .folder = rows[row], folderIndex % 2 == 1 {
            rowView.stripeColor = AppColors.stripe
        } else {
            rowView.stripeColor = AppColors.list
        }
        return rowView
    }
    /// True when Finder/Path Finder (or Open With) supplied at least one item to move.
    var hasSelection: Bool { !(chosen?.files.isEmpty ?? true) }
    #if APP_STORE
    static let noSelectionReason = L("ファイルを選択…")
    #else
    static let noSelectionReason = L("Finder／Path Finderで項目を選択すると指定できます")
    #endif
    func disabledReason(_ destination: Destination) -> String? {
        if busy { return L("処理中です") }
        // Without a selection every destination is dimmed (the reason is shown only as a tooltip).
        guard hasSelection else { return Self.noSelectionReason }
        #if APP_STORE
        let files = chosen?.files ?? []
        if files.contains(where: { $0.deletingLastPathComponent().standardizedFileURL == destination.url.standardizedFileURL }) {
            return L("選択中のファイルがあるフォルダ")
        }
        // An ungranted folder must remain selectable so its permission panel can open.
        if !FolderAccess.shared.covers(destination.url) { return nil }
        #endif
        return MoveEngine.destinationDisabledReason(chosen?.files ?? [], into: destination.url)
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = NSView()
        switch rows[row] {
        case .favorites:
            return favoritesView()
        case .choose:
            return chooserView()
        case .heading(let label):
            let text = NSTextField(labelWithString: label); text.font = .systemFont(ofSize: 12, weight: .semibold); text.textColor = .secondaryLabelColor
            text.frame = NSRect(x: 10, y: 4, width: 460, height: 18); view.addSubview(text)
            if row > 0 {
                let line = DividerView(frame: NSRect(x: 8, y: 26, width: max(400, table.bounds.width - 16), height: 1))
                line.autoresizingMask = [.width]
                view.addSubview(line)
            }
        case .folder(let destination):
            let icon = NSImageView(frame: NSRect(x: 10, y: 2, width: 44, height: 44))
            icon.image = folderIcon(for: destination.url)
            icon.imageScaling = .scaleProportionallyUpOrDown
            icon.setAccessibilityLabel(L("フォルダ"))
            view.addSubview(icon)
            let label = NSTextField(labelWithString: destination.url.lastPathComponent.isEmpty ? "/" : destination.url.lastPathComponent)
            let isOpenWindow = !rows.prefix(row).contains { entry in
                if case .heading(let title) = entry, title == L("最近使ったウインドウ") { return true }
                return false
            }
            label.font = .systemFont(ofSize: isOpenWindow ? 16 : 13, weight: .medium)
            label.frame = NSRect(x: 68, y: 24, width: max(300, table.bounds.width - 80), height: 22)
            label.lineBreakMode = .byTruncatingMiddle; view.addSubview(label)
            let path = displayPath(destination.url)
            let detail = NSTextField(labelWithString: path)
            detail.font = .systemFont(ofSize: 11); detail.textColor = .secondaryLabelColor
            detail.frame = NSRect(x: 68, y: 6, width: max(300, table.bounds.width - 80), height: 16); detail.lineBreakMode = .byTruncatingMiddle; view.addSubview(detail)
            view.toolTip = displayPath(destination.url, abbreviateHome: false)
            #if APP_STORE
            if !FolderAccess.shared.covers(destination.url) {
                view.toolTip = L("初回の操作時にフォルダへのアクセスを許可してください。\n") + displayPath(destination.url, abbreviateHome: false)
            }
            #endif
            if let reason = disabledReason(destination) {
                icon.alphaValue = 0.4
                label.textColor = .disabledControlTextColor
                detail.textColor = .disabledControlTextColor
                detail.stringValue = reason == Self.noSelectionReason ? path : "\(reason) · \(path)"
                view.toolTip = "\(reason)\n\(displayPath(destination.url, abbreviateHome: false))"
                view.setAccessibilityEnabled(false)
            }
        }
        return view
    }
    func favoriteURL(_ index: Int) -> URL? {
        if index == 0 { return URL(fileURLWithPath: "/Applications", isDirectory: true) }
        guard (1...2).contains(index), let path = UserDefaults.standard.string(forKey: "favoriteFolder\(index)") else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
    func favoritesView() -> NSView {
        favoriteButtons.removeAll()
        let view = NSView()
        let stack = NSStackView()
        stack.orientation = .horizontal; stack.distribution = .fillEqually; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6)
        ])
        let firstEmpty = (1...2).first { favoriteURL($0) == nil }
        let visibleSlots = (0...2).filter { favoriteURL($0) != nil || $0 == firstEmpty }
        for index in visibleSlots {
            let url = favoriteURL(index)
            let cell = FavoriteSelectionView(); cell.orientation = .vertical; cell.alignment = .centerX; cell.spacing = 2
            let button = FavoriteButton(title: "", target: self, action: #selector(favoriteClicked(_:)))
            cell.wantsLayer = true; cell.layer?.cornerRadius = 8
            button.selectionPanel = cell
            if index > 0, url != nil {
                let menu = NSMenu(); menu.autoenablesItems = false
                let removeItem = NSMenuItem(title: L("お気に入りから解除"), action: #selector(removeFavorite(_:)), keyEquivalent: "")
                for item in [removeItem] {
                    item.tag = index; item.target = self; item.isEnabled = !busy; menu.addItem(item)
                }
                cell.menu = menu; button.menu = menu
            }
            button.setButtonType(.toggle)
            button.state = selectedFavoriteIndex == index ? .on : .off
            favoriteButtons.append(button)
            button.tag = index; button.isBordered = false; button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyUpOrDown
            button.image = url.map { folderIcon(for: $0) } ?? NSWorkspace.shared.icon(forFile: "/System/Library")
            if url == nil { button.image = NSImage(named: NSImage.folderName); button.alphaValue = 0.3 }
            let name = index == 0 ? L("アプリケーション") : (url?.lastPathComponent ?? L("お気に入りを追加"))
            button.setAccessibilityLabel(url == nil ? L("お気に入り%@：未設定", String(describing: index)) : L("%@へ", String(describing: name)) + (symbolicLinks.state == .on ? L("リンクを作成") : L("移動")))
            button.toolTip = url.map { displayPath($0) } ?? L("下の「指定…」ボタンでフォルダを指定")
            button.isEnabled = !busy && url != nil
            if let url {
                let destination = Destination(url: url, origin: L("お気に入り"))
                if let reason = disabledReason(destination) {
                    button.isEnabled = false; button.alphaValue = 0.35
                    button.toolTip = reason
                }
            }
            cell.addArrangedSubview(button)
            button.widthAnchor.constraint(equalToConstant: 52).isActive = true
            button.heightAnchor.constraint(equalToConstant: 52).isActive = true
            let label = NSTextField(labelWithString: name)
            label.font = .systemFont(ofSize: 12, weight: .medium); label.alignment = .center
            label.lineBreakMode = .byTruncatingMiddle
            cell.addArrangedSubview(label)
            let detail = NSTextField(labelWithString: url.map {
                if index == 0 { return "/Applications" }
                let parent = displayPath($0.deletingLastPathComponent())
                return parent.hasSuffix("/") ? parent : parent + "/"
            } ?? L("未設定"))
            if let url, let reason = disabledReason(Destination(url: url, origin: L("お気に入り"))), !busy, hasSelection {
                detail.stringValue += "\n" + reason
                detail.maximumNumberOfLines = 2
                detail.toolTip = reason + "\n" + displayPath(url)
            }
            detail.font = .systemFont(ofSize: 10); detail.textColor = .secondaryLabelColor
            detail.alignment = .center; detail.lineBreakMode = .byTruncatingMiddle
            if url != nil, !button.isEnabled {
                // Dim the name and path together with the icon.
                label.textColor = .disabledControlTextColor; detail.textColor = .disabledControlTextColor
            }
            cell.addArrangedSubview(detail)
            if index > 0 {
                let change = FavoriteConfigurationButton(title: url == nil ? L("指定…") : L("変更…"), target: self, action: #selector(chooseFavorite(_:)))
                change.tag = index; change.bezelStyle = .inline; change.font = .systemFont(ofSize: 11)
                change.isEnabled = !busy; cell.addArrangedSubview(change)
            } else {
                let spacer = NSView(); spacer.heightAnchor.constraint(equalToConstant: 18).isActive = true
                cell.addArrangedSubview(spacer)
            }
            stack.addArrangedSubview(cell)
            label.widthAnchor.constraint(equalTo: cell.widthAnchor).isActive = true
            detail.widthAnchor.constraint(equalTo: cell.widthAnchor).isActive = true
        }
        return view
    }
    @objc func favoriteClicked(_ sender: NSButton) {
        guard !busy else { return }
        guard let url = favoriteURL(sender.tag) else { return }
        selectFavorite(sender)
        if NSApp.currentEvent?.clickCount == 2 {
            move(to: Destination(url: url, origin: L("お気に入り")), bringForward: NSApp.currentEvent?.modifierFlags.contains(.command) == true)
        }
    }
    func selectFavorite(_ sender: NSButton) {
        activationRefresh?.cancel(); activationRefresh = nil
        table.deselectAll(nil)
        selectedFavoriteIndex = sender.tag
        for button in selectableButtons { button.state = button === sender ? .on : .off }
        window.makeFirstResponder(sender)
    }
    func stepFavorite(_ direction: Int) {
        guard !busy, showFavorites.state == .on || showChooser.state == .on else { return }
        let sectionRows = rows.indices.filter { switch rows[$0] { case .choose, .favorites: return true; default: return false } }
        if let first = sectionRows.first, let last = sectionRows.last {
            table.scrollRowToVisible(last); table.scrollRowToVisible(first)
            table.layoutSubtreeIfNeeded()
        }
        let buttons = selectableButtons.filter { $0.isEnabled && $0.window != nil }
        guard !buttons.isEmpty else { return }
        let current = buttons.firstIndex { $0 === window.firstResponder }
        let next = current.map { ($0 + direction + buttons.count) % buttons.count } ?? (direction > 0 ? 0 : buttons.count - 1)
        selectFavorite(buttons[next])
    }
    @objc func removeFavorite(_ sender: NSMenuItem) {
        guard !busy, (1...2).contains(sender.tag), window.attachedSheet == nil else { return }
        if selectedFavoriteIndex == sender.tag { selectedFavoriteIndex = nil }
        UserDefaults.standard.removeObject(forKey: "favoriteFolder\(sender.tag)")
        window.makeFirstResponder(table)
        table.reloadData()
    }
    @objc func destinationSelected() {
        selectedFavoriteIndex = nil
        activationRefresh?.cancel()
        activationRefresh = nil
        for button in selectableButtons { button.state = .off }
        window.makeFirstResponder(table)
    }
    /// 「指定・デスクトップ」: two equal-width tiles (icon and two lines of text); clicking anywhere on a tile runs it.
    /// Left asks for a destination folder; right sends the selection straight to the Desktop.
    func chooserView() -> NSView {
        let view = NSView()
        let ready = !busy && hasSelection
        let verb = copies.state == .on ? L("複製") : (symbolicLinks.state == .on ? L("リンクを作成") : L("移動"))
        let chooser = chooserTile(tag: Self.chooserTag, image: NSImage(named: NSImage.folderName), title: L("フォルダを選択…"),
                                  detail: L("クリックして移動先を指定"), accessibility: L("フォルダを選択…"),
                                  action: #selector(chooseDestination(_:)), ready: ready)
        chooserButton = chooser.button
        let desktopDetail = L("クリックしてデスクトップへ%@", verb)
        let desktop = chooserTile(tag: Self.desktopTag, image: NSWorkspace.shared.icon(forFile: Self.desktopURL.path), title: L("デスクトップ"),
                                  detail: desktopDetail, accessibility: L("%@へ", L("デスクトップ")) + verb,
                                  action: #selector(moveToDesktop(_:)), ready: ready)
        desktopButton = desktop.button
        let pair = NSStackView(views: [chooser.row, desktop.row])
        pair.orientation = .horizontal; pair.distribution = .fillEqually; pair.spacing = 12
        pair.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pair)
        NSLayoutConstraint.activate([
            pair.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            pair.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            pair.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -2)
        ])
        return view
    }
    private func chooserTile(tag: Int, image: NSImage?, title: String, detail detailText: String, accessibility: String, action: Selector, ready: Bool) -> (row: FavoriteSelectionView, button: FavoriteButton) {
        let button = FavoriteButton(title: "", target: self, action: action)
        button.isBordered = false; button.imagePosition = .imageOnly; button.imageScaling = .scaleProportionallyUpOrDown
        button.image = image
        button.setButtonType(.toggle)
        button.tag = tag
        button.isEnabled = ready
        // Without a Finder/Path Finder selection the whole tile (icon and both lines) is dimmed.
        button.alphaValue = ready ? 1 : 0.35
        button.setAccessibilityLabel(accessibility)
        button.toolTip = ready ? detailText : Self.noSelectionReason
        button.widthAnchor.constraint(equalToConstant: 48).isActive = true
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = ready ? .labelColor : .tertiaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        let detail = NSTextField(labelWithString: detailText)
        detail.font = .systemFont(ofSize: 11); detail.textColor = ready ? .secondaryLabelColor : .quaternaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        for field in [label, detail] { field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal) }
        let texts = NSStackView(views: [label, detail]); texts.orientation = .vertical; texts.alignment = .leading; texts.spacing = 2
        let row = FavoriteSelectionView(views: [button, texts]); row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 10
        row.edgeInsets = NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 14)
        row.wantsLayer = true; row.layer?.cornerRadius = 8
        button.selectionPanel = row
        button.state = ready && selectedFavoriteIndex == tag ? .on : .off
        if ready {
            let click = NSClickGestureRecognizer(target: self, action: #selector(chooserAreaClicked(_:)))
            row.addGestureRecognizer(click)
        }
        return (row, button)
    }
    @objc func chooserAreaClicked(_ sender: NSClickGestureRecognizer) {
        guard let button = (sender.view as? NSStackView)?.arrangedSubviews.first as? NSButton, button.isEnabled, let action = button.action else { return }
        NSApp.sendAction(action, to: button.target, from: button)
    }
    /// The user's real Desktop (also inside the App Store sandbox, where the home directory is the container).
    static var desktopURL: URL {
        if let home = getpwuid(getuid())?.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home), isDirectory: true).appendingPathComponent("Desktop", isDirectory: true)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Desktop", isDirectory: true)
    }
    /// 「デスクトップ」: runs the current mode into the Desktop right away. In the App Store build, move() asks for
    /// access to the Desktop (FolderAccess.authorize, panel opened at the Desktop) when it is not granted yet.
    @objc func moveToDesktop(_ sender: NSButton) {
        guard !busy, window.attachedSheet == nil, hasSelection else { return }
        if let tile = sender as? FavoriteButton, tile.tag == Self.desktopTag { selectFavorite(tile) }
        let bringForward = NSApp.currentEvent?.modifierFlags.contains(.command) == true
        let destination = Destination(url: Self.desktopURL, origin: L("デスクトップ"))
        if let reason = disabledReason(destination) { showError(reason); return }
        move(to: destination, bringForward: bringForward)
    }
    @objc func chooseDestination(_ sender: NSButton) {
        guard !busy, window.attachedSheet == nil, !(chosen?.files.isEmpty ?? true) else { return }
        // Mouse or Return: show it as the current choice, like a favorite.
        if let chooser = sender as? FavoriteButton, chooser.tag == Self.chooserTag { selectFavorite(chooser) }
        let bringForward = NSApp.currentEvent?.modifierFlags.contains(.command) == true
        let panel = NSOpenPanel()
        panel.title = L("移動先のフォルダを指定")
        panel.prompt = copies.state == .on ? L("複製") : (symbolicLinks.state == .on ? L("リンクを作成") : L("移動"))
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false; panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = UserDefaults.standard.string(forKey: "lastChosenDestination").map { URL(fileURLWithPath: $0, isDirectory: true) }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            UserDefaults.standard.set(url.standardizedFileURL.path, forKey: "lastChosenDestination")
            #if APP_STORE
            do { try FolderAccess.shared.remember(url) }
            catch { self.showError(error.localizedDescription); return }
            #endif
            let destination = Destination(url: url, origin: L("指定"))
            if let reason = self.disabledReason(destination) { self.showError(reason); return }
            // Run after the sheet has fully detached; move() refuses while a sheet is attached.
            DispatchQueue.main.async { self.move(to: destination, bringForward: bringForward) }
        }
    }
    @objc func chooseFavorite(_ sender: NSButton) {
        guard sender is FavoriteConfigurationButton, NSApp.currentEvent?.type != .keyDown else { return }
        let index = sender.tag
        guard !busy, (1...2).contains(index), window.attachedSheet == nil else { return }
        let panel = NSOpenPanel()
        panel.title = L("お気に入り%@のフォルダを指定", String(describing: index))
        panel.prompt = L("設定する"); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false; panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = favoriteURL(index)
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            #if APP_STORE
            do { try FolderAccess.shared.remember(url) }
            catch { self.showError(error.localizedDescription); return }
            #endif
            UserDefaults.standard.set(url.standardizedFileURL.path, forKey: "favoriteFolder\(index)")
            self.selectedFavoriteIndex = nil
            self.table.reloadData()
        }
    }
    func setBusy(_ value: Bool) {
        if value { status.isHidden = false; selectedFavoriteIndex = nil }
        symbolicLinks.isEnabled = !value
        copies.isEnabled = !value && symbolicLinks.state != .on
        busy = value
        table.deselectAll(nil)
        table.reloadData()
        if !value && pendingOpenFiles != nil && uiReady {
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.busy, self.pendingOpenFiles != nil else { return }
                self.requestTransfer()
            }
        }
    }
    func showError(_ message: String, automation: Bool = false) {
        presentDestinations()
        let alert = NSAlert(); alert.messageText = L("処理できませんでした"); alert.informativeText = message
        if automation { alert.addButton(withTitle: L("OK")); alert.addButton(withTitle: L("オートメーションの設定を開く…")) }
        alert.beginSheetModal(for: window) { [weak self] response in
            if automation && response == .alertSecondButtonReturn { self?.openAutomationSettings() }
        }
    }
    @objc func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") { NSWorkspace.shared.open(url) }
    }
    @objc func moveClicked(_ sender: Any? = nil) {
        // Mouse actions must use the clicked row: a disabled click can leave an older row selected.
        let row = (sender as? NSTableView) === table ? table.clickedRow : table.selectedRow
        guard rows.indices.contains(row), case .folder(let destination) = rows[row] else { return }
        let event = NSApp.currentEvent
        let copying = event?.type == .keyDown && event?.modifierFlags.contains(.option) == true
        move(to: destination, bringForward: event?.modifierFlags.contains(.command) == true, copying: copying, linking: event?.type == .keyDown && event?.modifierFlags.contains(.control) == true)
    }
    /// `source` overrides the window's chosen selection (the ⌃⌥⌘⇧A hotkey, which checks the destination itself).
    func move(to destination: Destination, source requestedSource: BrowserState? = nil, bringForward: Bool = false, copying requestedCopy: Bool = false, linking requestedLink: Bool = false) {
        guard !busy, window.attachedSheet == nil, requestedSource != nil || disabledReason(destination) == nil,
              let source = requestedSource ?? chosen, !source.files.isEmpty else { return }
        // Ignore Option+Return while symbolic-link mode is selected.
        // Control+Return always creates a link, including when Option is also held.
        guard !(symbolicLinks.state == .on && requestedCopy && !requestedLink) else { return }
        let files = source.files
        #if APP_STORE
        do {
            guard try FolderAccess.shared.authorize(files.map { $0.deletingLastPathComponent() } + [destination.url]) else { presentDestinations(); return }
        } catch { showError(error.localizedDescription); return }
        #endif
        let shouldRename = renameConflicts.indexOfSelectedItem == 0
        // Control forces linking; otherwise the enabled operation and Option determine copying.
        let copying = !requestedLink && (requestedCopy || copies.state == .on)
        let linking = requestedLink || (!copying && symbolicLinks.state == .on)
        let preferredBrowser = lastBrowser
        setBusy(true); status.stringValue = copying ? L("複製しています…") : (linking ? L("リンクを作成しています…") : L("移動しています…"))
        queue.async {
            do {
                // Links into /Applications overwrite an existing link of the same name (no numbered copy).
                let intoApplications = destination.url.resolvingSymlinksInPath().standardizedFileURL.path == "/Applications"
                let plan = try MoveEngine.plan(files, into: destination.url, renameConflicts: shouldRename, replaceSymbolicLinks: linking && intoApplications)
                let result = MoveEngine.execute(plan, asSymbolicLinks: linking, asCopies: copying)
                DispatchQueue.main.async {
                    if !linking && !copying, let index = self.states.firstIndex(where: { $0.id == source.id }) {
                        let moved = Set(result.done.map { $0.from.standardizedFileURL.path })
                        self.states[index].files.removeAll { moved.contains($0.standardizedFileURL.path) }
                    }
                    self.setBusy(false); self.sourceChanged()
                    self.status.stringValue = copying ? L("%@項目を「%@」へ複製しました。", String(describing: result.done.count), String(describing: destination.url.lastPathComponent)) : linking ? L("「%@」に%@項目のリンクを作成しました。", String(describing: destination.url.lastPathComponent), String(describing: result.done.count)) : L("%@項目を「%@」へ移動しました。", String(describing: result.done.count), String(describing: destination.url.lastPathComponent))
                    if let error = result.error { self.showError(L("%@項目を処理した後に停止しました。\n%@", String(describing: result.done.count), String(describing: error.localizedDescription))) }
                    else if result.done.count == files.count && self.pendingOpenFiles == nil {
                        self.notifyOperation(count: result.done.count, destination: destination.url, linking: linking, copying: copying)
                        if self.closeAfterOperation.state == .on {
                            let wasActive = NSApp.isActive
                            self.window.orderOut(nil)
                            // Hand focus back to the source folder's window instead of leaving FolderHopper active with no window.
                            if wasActive && !bringForward, let folder = files.first?.deletingLastPathComponent() {
                                self.queue.async {
                                    let failed = BrowserReader.bringDestinationForward(Destination(url: folder, origin: source.name), preferredID: source.id) != nil
                                    if failed { DispatchQueue.main.async { NSApp.hide(nil) } }
                                }
                            }
                        }
                        if bringForward {
                            self.queue.async {
                                if let message = BrowserReader.bringDestinationForward(destination, preferredID: preferredBrowser) {
                                    DispatchQueue.main.async {
                                        self.status.stringValue = message
                                        self.status.isHidden = false
                                        self.window.makeKeyAndOrderFront(nil)
                                    }
                                }
                            }
                        }
                    }
                }
            } catch { DispatchQueue.main.async { self.setBusy(false); self.status.stringValue = L("処理を中止しました。"); self.showError(error.localizedDescription) } }
        }
    }
    func notifyOperation(count: Int, destination: URL, linking: Bool, copying: Bool) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, error in
            guard granted else {
                DispatchQueue.main.async {
                    self.status.stringValue = L("処理は完了しました。通知は未許可です。")
                    self.status.isHidden = false
                }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "FolderHopper"
            content.body = copying
                ? L("%@項目を「%@」へ複製しました。", String(count), destination.lastPathComponent)
                : linking ? L("「%@」に%@項目のリンクを作成しました。", destination.lastPathComponent, String(count))
                : L("%@項目を「%@」へ移動しました。", String(count), destination.lastPathComponent)
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)) { error in
                if let error { DispatchQueue.main.async { self.status.stringValue = L("通知できませんでした: ") + error.localizedDescription; self.status.isHidden = false } }
            }
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            defer { completionHandler() }
            NSApp.activate(ignoringOtherApps: true)
            self.window.makeKeyAndOrderFront(nil)
        }
    }

}
MainActor.assumeIsolated { SingleInstanceLaunch.enforce() }
let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()

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
