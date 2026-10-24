import AppKit
import CoreServices
import Carbon

struct Browser {
    let url: URL
    let id: String
    let name: String
    var token: String { id.components(separatedBy: ".").last!.lowercased() }
}
func handler(_ scheme: String) -> String? {
    guard let url = URL(string: "\(scheme)://example.com") else { return nil }
    return NSWorkspace.shared.urlForApplication(toOpen: url).flatMap { Bundle(url: $0)?.bundleIdentifier }
}
func browsers() -> [Browser] {
    let ids = NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "http://example.com")!).compactMap { Bundle(url: $0)?.bundleIdentifier }
    let known = ["com.apple.safari", "com.google.chrome", "org.mozilla.firefox", "com.microsoft.edgemac", "com.brave.browser", "company.thebrowser.browser", "com.operasoftware.opera", "com.vivaldi.vivaldi", "org.chromium.chromium", "com.duckduckgo.macos.browser", "app.zen-browser.zen", "com.kagi.kagimacOS".lowercased(), "company.thebrowser.dia", "org.waterfox.waterfox"]
    return ids.compactMap { id -> Browser? in
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id), let bundle = Bundle(url: url) else { return nil }
        let info = bundle.infoDictionary ?? [:]
        guard known.contains(where: { id.lowercased() == $0 || id.lowercased().hasPrefix($0 + ".") }) || info["LSApplicationCategoryType"] as? String == "public.app-category.web-browsers" else { return nil }
        return Browser(url: url, id: id, name: url.deletingPathExtension().lastPathComponent)
    }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}
var switchingAvailable: Bool { true }

final class BrowserWindow: NSWindow {
    var moveCandidate: ((Int) -> Void)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, attachedSheet == nil,
           event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            switch event.keyCode {
            case 53: performClose(nil); return
            case 48: moveCandidate?(event.modifierFlags.contains(.shift) ? -1 : 1); return
            case 125: moveCandidate?(1); return
            case 126: moveCandidate?(-1); return
            default: break
            }
        }
        super.sendEvent(event)
    }
}

final class BrowserRowView: NSTableRowView {
    var isOddRow = false

    override func drawBackground(in dirtyRect: NSRect) {
        let colors = NSColor.alternatingContentBackgroundColors
        let color = isOddRow && colors.count > 1 ? colors[1] : colors[0]
        color.setFill()
        bounds.fill()
    }
}

final class BrowserTableView: NSTableView {
    var activateRow: ((Int) -> Void)?

    func moveSelection(_ direction: Int) {
        let candidates = (0..<numberOfRows).filter {
            delegate?.tableView?(self, shouldSelectRow: $0) != false
        }
        guard !candidates.isEmpty else { return }
        let next: Int
        if let index = candidates.firstIndex(of: selectedRow) {
            next = candidates[(index + direction + candidates.count) % candidates.count]
        } else {
            next = direction > 0 ? candidates[0] : candidates[candidates.count - 1]
        }
        window?.makeFirstResponder(self)
        selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        scrollRowToVisible(next)
    }

    override func mouseDown(with event: NSEvent) {
        let clicked = row(at: convert(event.locationInWindow, from: nil))
        if event.modifierFlags.contains(.command) || event.clickCount == 2 {
            guard clicked >= 0,
                  delegate?.tableView?(self, shouldSelectRow: clicked) != false else { return }
            selectRowIndexes(IndexSet(integer: clicked), byExtendingSelection: false)
            activateRow?(clicked)
            return
        }
        super.mouseDown(with: event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    var window: BrowserWindow!
    var hotKey: EventHotKeyRef?
    var hotKeyHandler: EventHandlerRef?
    static let defaultShortcut = KeyCombo(code: UInt32(kVK_ANSI_B), modifiers: UInt32(controlKey | optionKey | cmdKey))
    var shortcutKey = AppDelegate.defaultShortcut.code
    var shortcutModifiers = AppDelegate.defaultShortcut.modifiers
    /// False after RegisterEventHotKey failed; the settings field shows the shared message.
    var shortcutRegistered = true
    var shortcutSerial: UInt32 = 1
    var shortcutTap = ShortcutDoubleTap()
    let stack = NSStackView()
    let status = NSTextField(wrappingLabelWithString: "")
    var items: [Browser] = []
    let table = BrowserTableView()
    var selectedID: String?
    var currentID: String?
    var switchButton: NSButton?
    var busy = false
    var preferencesWindow: NSWindow?
    var preferenceBrowsers: [Browser] = []
    var exclusionCheckboxes: [NSButton] = []
    var excludedIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "excludedBrowserIDs") ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: "excludedBrowserIDs") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        WindowActivationPolicy.install()
        defer { DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MenuBarPresence.shared.install(name: "BrowserSwitcher", symbol: "globe", existing: nil,
                show: { [weak self] in self?.showMainWindow() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in LocalHelp.shared.show() })
        } }
        DispatchQueue.main.async { LocalHelp.shared.install() }
        let menu = NSMenu()
        let root = NSMenuItem()
        menu.addItem(root)
        let appMenu = NSMenu()
        let about = appMenu.addItem(withTitle: L("BrowserSwitcherについて"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(.separator())
        let preferences = appMenu.addItem(withTitle: L("設定…"), action: #selector(showPreferences), keyEquivalent: ",")
        preferences.target = self
        appMenu.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to: appMenu)
        #endif
        addStandardApplicationCommands(to: appMenu, name: "BrowserSwitcher")
        root.submenu = appMenu
        NSApp.mainMenu = menu
        let fileRoot = NSMenuItem()
        let fileMenu = NSMenu(title: L("ファイル"))
        let openMain = fileMenu.addItem(withTitle: L("メインウインドウを開く"), action: #selector(showMainWindow), keyEquivalent: "0")
        openMain.keyEquivalentModifierMask = [.command]
        openMain.target = self
        fileMenu.addItem(.separator())
        let close = fileMenu.addItem(withTitle: L("ウインドウを閉じる"), action: #selector(closeWindow), keyEquivalent: "w")
        close.keyEquivalentModifierMask = [.command]
        close.target = self
        fileRoot.submenu = fileMenu
        menu.addItem(fileRoot)
        let editRoot = NSMenuItem(title: L("編集"), action: nil, keyEquivalent: "")
        let edit = NSMenu(title: L("編集")); editRoot.submenu = edit; menu.addItem(editRoot)
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
        window = BrowserWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 440), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.moveCandidate = { [weak self] direction in
            self?.table.moveSelection(direction)
        }
        window.delegate = self
        window.title = ""
        window.titleVisibility = .hidden
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.collectionBehavior.insert(.fullScreenNone)
        window.isReleasedWhenClosed = false
        let content = window.contentView!
        AppSurface.install(in: content)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24)
        ])
        refresh()
        window.center()
        if !StartupWindow.suppressInitialWindow { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
        registerGlobalShortcut()
        SettingsSync.shared.onImport = { [weak self] in
            guard let self else { return }
            self.refresh()
            for checkbox in self.exclusionCheckboxes where self.preferenceBrowsers.indices.contains(checkbox.tag) {
                checkbox.state = self.excludedIDs.contains(self.preferenceBrowsers[checkbox.tag].id.lowercased()) ? .on : .off
            }
        }
        SettingsSync.shared.start(.init(
            keys: ["excludedBrowserIDs"],
            note: StartupWindow.text("一覧から除外するブラウザーを書き出し・同期します。",
                                     "Exports and syncs the browsers hidden from the list.",
                                     "导出并同步从列表中排除的浏览器。",
                                     "목록에서 제외할 브라우저를 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・起動時の表示・メニューバー・アプリを呼び出すホットキーはMacごとに設定します。",
                                       "Login launch, startup display, the menu bar icon and the show app shortcut are set per Mac.",
                                       "登录时启动、启动时的显示、菜单栏图标和显示应用快捷键在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 시작 시 표시, 메뉴 막대 아이콘, 앱 표시 단축키는 Mac마다 설정합니다.")))
    }
    var shortcutName: String {
        L("%@（2回押す）", KeyCombo(code: shortcutKey, modifiers: shortcutModifiers).label)
    }
    func registerGlobalShortcut() {
        if let saved = UserDefaults.standard.dictionary(forKey: "callShortcut"),
           let code = saved["key"] as? NSNumber, let modifiers = saved["modifiers"] as? NSNumber,
           modifiers.uint32Value & UInt32(controlKey | optionKey | cmdKey) != 0 {
            shortcutKey = code.uint32Value
            shortcutModifiers = modifiers.uint32Value
        }
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event = event, let context = context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == 0x42535754 else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            guard identifier.id == owner.shortcutSerial else { return noErr }
            if owner.shortcutTap.handle(pressed: GetEventKind(event) == UInt32(kEventHotKeyPressed), time: ProcessInfo.processInfo.systemUptime) {
                owner.showMainWindow()
            }
            return noErr
        }, 2, &eventTypes, context, &hotKeyHandler)
        let registered: OSStatus
        if installed == noErr {
            registered = RegisterEventHotKey(shortcutKey, shortcutModifiers, EventHotKeyID(signature: 0x42535754, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        } else {
            registered = installed
        }
        shortcutRegistered = registered == noErr
        // While the settings field records a key, the call shortcut is released so the keystroke reaches the field.
        MainActor.assumeIsolated { HotkeyRecorder.shared.onRecordingChanged.append { [weak self] recording in self?.suspendShortcut(recording) } }
        if registered != noErr {
            let alert = NSAlert()
            alert.messageText = L("ホットキーを登録できませんでした")
            alert.informativeText = L("%@ がほかのアプリで使われていないか確認してください。アプリのアイコンからは引き続き開けます。（エラー：%@）", String(describing: shortcutName), String(describing: registered))
            alert.beginSheetModal(for: window)
        }
        publishHotkeys()
    }
    /// Declares the call shortcut to HotkeyHound (Shared/HotkeyManifest); there is no off switch, so it is always enabled.
    func publishHotkeys() {
        HotkeyManifest.publish([HotkeyManifest.Item(id: "callShortcut", title: L("メインウインドウを開く"), keyCode: Int(shortcutKey),
                                                     modifiers: Int(shortcutModifiers), note: L("続けて2回押す"))])
    }
    @objc func showMainWindow() {
        if !busy { refresh() }
        NSApp.unhide(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let preferencesWindow = preferencesWindow {
            preferencesWindow.makeKeyAndOrderFront(nil)
        } else {
            window.makeFirstResponder(table)
        }
    }
    @objc func closeWindow() {
        if preferencesWindow != nil { closePreferences(); return }
        (NSApp.keyWindow ?? window).performClose(nil)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        NSApp.hide(nil)
        return false
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let hotKey = hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler = hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        StartupWindow.userRequestedWindow()
        showMainWindow()
        return true
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        if window != nil && !busy { refresh() }
    }
    func refresh(message: String? = nil) {
        for view in stack.arrangedSubviews { stack.removeArrangedSubview(view); view.removeFromSuperview() }
        items = browsers().filter { !excludedIDs.contains($0.id.lowercased()) }
        let current = handler("https")
        let title = appHeader(L("既定のブラウザーを選択"), subtitle: L("リンクを開くブラウザーを切り替えます。"))
        stack.addArrangedSubview(title)
        let available = switchingAvailable
        currentID = current?.lowercased()
        table.delegate = nil
        table.dataSource = self
        if table.tableColumns.isEmpty {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("browser"))
            table.addTableColumn(column)
        }
        table.headerView = nil
        table.rowHeight = 80
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.style = .plain
        table.usesAlternatingRowBackgroundColors = false
        table.selectionHighlightStyle = .regular
        table.allowsEmptySelection = true
        table.allowsMultipleSelection = false
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.activateRow = { [weak self] row in
            guard let self = self, self.items.indices.contains(row) else { return }
            self.selectedID = self.items[row].id
            self.performSwitch()
        }
        table.reloadData()
        table.deselectAll(nil)
        if let selectedID = selectedID, let index = items.firstIndex(where: { $0.id == selectedID }), items[index].id.lowercased() != currentID {
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else { selectedID = nil }
        table.delegate = self
        let scroll = NSScrollView()
        scroll.borderType = .lineBorder
        scroll.hasVerticalScroller = true
        scroll.documentView = table
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: CGFloat(max(1, min(items.count, 6)) * 80 + 2)).isActive = true
        status.stringValue = message ?? (items.isEmpty ? L("表示するブラウザーがありません。設定で除外を解除できます。") : L("Tab・↑↓で選択、Escで隠す。\n⌘＋Return／⌘＋クリック／ダブルクリックで実行。"))
        status.textColor = .secondaryLabelColor
        status.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(status)
        status.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.spacing = 12
        let preferences = NSButton(title: L("設定…"), target: self, action: #selector(showPreferences))
        preferences.bezelStyle = .rounded
        preferences.isEnabled = !busy
        actions.addArrangedSubview(preferences)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        actions.addArrangedSubview(spacer)
        let change = NSButton(title: L("切り替える"), target: self, action: #selector(performSwitch))
        change.bezelStyle = .rounded
        change.keyEquivalent = "\r"
        change.keyEquivalentModifierMask = [.command]
        change.isEnabled = selectedID != nil && !busy && available
        switchButton = change
        actions.addArrangedSubview(change)
        stack.addArrangedSubview(actions)
        actions.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        window.setContentSize(NSSize(width: 400, height: 210 + max(1, min(items.count, 6)) * 80))
    }
    /// Recording pauses the call shortcut; it comes back when recording ends.
    func suspendShortcut(_ suspended: Bool) {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        guard !suspended, hotKeyHandler != nil else { return }
        shortcutSerial &+= 1
        shortcutRegistered = RegisterEventHotKey(shortcutKey, shortcutModifiers, EventHotKeyID(signature: 0x42535754, id: shortcutSerial),
                                                 GetApplicationEventTarget(), 0, &hotKey) == noErr
    }
    /// Saves the key from the settings field (same {key, modifiers} dictionary as before) and registers it.
    func setShortcut(_ combo: KeyCombo) {
        shortcutKey = combo.code
        shortcutModifiers = combo.modifiers
        shortcutTap = ShortcutDoubleTap()
        UserDefaults.standard.set(["key": Int(combo.code), "modifiers": Int(combo.modifiers)], forKey: "callShortcut")
        // Recording is still on when the field commits; registration happens when it ends (suspendShortcut(false)).
        if MainActor.assumeIsolated({ HotkeyRecorder.shared.recordingID == nil }) { suspendShortcut(false) }
        publishHotkeys()
    }
    /// Keys that stay with macOS or the app (screen lock, hide, minimize), refused like a duplicate.
    var reservedShortcuts: [(String, KeyCombo)] {
        [(StartupWindow.text("画面をロック", "Lock Screen", "锁定屏幕", "화면 잠금"), KeyCombo(code: UInt32(kVK_ANSI_Q), modifiers: UInt32(controlKey | cmdKey))),
         (StartupWindow.text("隠す", "Hide", "隐藏", "가리기"), KeyCombo(code: UInt32(kVK_ANSI_H), modifiers: UInt32(cmdKey))),
         (StartupWindow.text("しまう", "Minimize", "最小化", "최소화"), KeyCombo(code: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey)))]
    }
    @objc func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: L("ブラウザー切り替え"),
            .applicationVersion: version,
            .version: build
        ])
    }
    @objc func showPreferences() {
        guard !busy else {
            // Say why instead of a bare beep: settings wait until the switch finishes.
            MainActor.assumeIsolated { TransientMessage.show(L("切り替え中は設定を開けません。完了してからお試しください。")) }
            return
        }
        if let preferencesWindow = preferencesWindow {
            preferencesWindow.makeKeyAndOrderFront(nil)
            return
        }
        preferenceBrowsers = browsers()
        let panelSize = NSSize(width: 480, height: 465 + 44 + min(2, max(1, preferenceBrowsers.count)) * 44)
        let panel = SettingsSheetWindow(contentRect: NSRect(origin: .zero, size: panelSize), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        // Esc closes the sheet like 完了 (the sheet has no close button).
        panel.onCancel = { [weak self] in self?.closePreferences() }
        // Resizable from the designed size upward; the tab view follows via its autoresizing mask.
        panel.contentMinSize = panelSize
        panel.title = L("設定")
        panel.isReleasedWhenClosed = false
        preferencesWindow = panel
        let content = panel.contentView!
        let launch = NSStackView(); launch.orientation = .vertical; launch.alignment = .leading; launch.spacing = 10
        launch.addArrangedSubview(MainActor.assumeIsolated { LoginAtLaunchControl() })

        launch.addArrangedSubview(MainActor.assumeIsolated { MenuBarPresence.shared.settingsControl() })
        let shortcutTitle = NSTextField(labelWithString: SettingsUI.shortcutTitle)
        shortcutTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        launch.addArrangedSubview(shortcutTitle)
        let field = MainActor.assumeIsolated {
            HotkeyField.control(id: "callShortcut",
                                get: { [weak self] in self.map { KeyCombo(code: $0.shortcutKey, modifiers: $0.shortcutModifiers) } },
                                set: { [weak self] combo in if let combo { self?.setShortcut(combo) } },
                                defaultCombo: AppDelegate.defaultShortcut,
                                others: { [weak self] in self?.reservedShortcuts ?? [] },
                                registered: { [weak self] in self?.shortcutRegistered ?? true })
        }
        launch.addArrangedSubview(field)
        field.widthAnchor.constraint(equalTo: launch.widthAnchor).isActive = true
        let shortcutNote = NSTextField(wrappingLabelWithString: L("続けて2回押すとメインウインドウを開きます。Escで隠す／⌘Qで終了"))
        shortcutNote.font = .systemFont(ofSize: 11)
        shortcutNote.textColor = .secondaryLabelColor
        launch.addArrangedSubview(shortcutNote)
        let launchGroup = MainActor.assumeIsolated { SettingsUI.group(SettingsUI.launchTitle, [launch]) }
        let title = NSTextField(labelWithString: L("一覧から除外するブラウザー"))
        title.font = .boldSystemFont(ofSize: 17)
        let help = NSTextField(wrappingLabelWithString: L("チェックしたブラウザーを非表示にします。変更は自動保存されます。"))
        help.textColor = .secondaryLabelColor
        let list = NSStackView()
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 0
        list.edgeInsets = NSEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        exclusionCheckboxes = []
        for (index, browser) in preferenceBrowsers.enumerated() {
            let checkbox = NSButton(checkboxWithTitle: browser.name, target: self, action: #selector(toggleExclusion(_:)))
            checkbox.tag = index
            checkbox.state = excludedIDs.contains(browser.id.lowercased()) ? .on : .off
            checkbox.font = .systemFont(ofSize: 15)
            exclusionCheckboxes.append(checkbox)
            list.addArrangedSubview(checkbox)
            checkbox.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }
        if preferenceBrowsers.isEmpty { list.addArrangedSubview(NSTextField(labelWithString: L("ブラウザーが見つかりません。"))) }
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = list
        list.translatesAutoresizingMaskIntoConstraints = false
        list.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor).isActive = true
        list.topAnchor.constraint(equalTo: scroll.contentView.topAnchor).isActive = true
        list.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        let browsersGroup = MainActor.assumeIsolated { SettingsUI.group(title.stringValue, [help, scroll]) }
        // The designed height is the minimum; the list takes whatever height the window adds.
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: CGFloat(min(2, max(1, preferenceBrowsers.count)) * 44 + 16)).isActive = true
        scroll.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .vertical)
        (browsersGroup.contentView?.subviews.first as? NSStackView)?.distribution = .fill
        // The sheet has no close button, so 完了 sits outside the tabs and is shown on every tab.
        let done = NSButton(title: L("完了"), target: self, action: #selector(closePreferences))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        done.sizeToFit(); done.frame.size.width = max(done.frame.width, 88)
        done.frame.origin = NSPoint(x: content.bounds.width - done.frame.width - 20, y: 16)
        done.autoresizingMask = [.minXMargin, .maxYMargin]
        content.addSubview(done)
        let tabArea = NSView(frame: NSRect(x: 0, y: 52, width: content.bounds.width, height: content.bounds.height - 52))
        tabArea.autoresizingMask = [.width, .height]
        content.addSubview(tabArea)
        MainActor.assumeIsolated { SettingsUI.tabs([(SettingsUI.launchTitle, launchGroup), (SettingsUI.displayTitle, browsersGroup), (SettingsSync.shared.tabTitle, SettingsSync.shared.sharingPage()), (AboutSection.title, AboutSection.view())], in: tabArea) }
        // Let the browsers page fill its tab so the list stretches with the window instead of leaving blank space below.
        if let document = browsersGroup.superview, let page = document.enclosingScrollView {
            let fill = document.heightAnchor.constraint(equalTo: page.contentView.heightAnchor)
            fill.priority = NSLayoutConstraint.Priority(200)
            fill.isActive = true
        }
        window.beginSheet(panel)
    }
    @objc func toggleExclusion(_ sender: NSButton) {
        guard preferenceBrowsers.indices.contains(sender.tag) else { return }
        let id = preferenceBrowsers[sender.tag].id.lowercased()
        var excluded = excludedIDs
        if sender.state == .on { excluded.insert(id) } else { excluded.remove(id) }
        excludedIDs = excluded
        refresh()
    }
    @objc func closePreferences() {
        guard let panel = preferencesWindow else { return }
        window.endSheet(panel)
        panel.orderOut(nil)
        preferencesWindow = nil
        window.makeKeyAndOrderFront(nil)
    }
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        !busy && switchingAvailable && items[row].id.lowercased() != currentID
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedID = items.indices.contains(table.selectedRow) ? items[table.selectedRow].id : nil
        switchButton?.isEnabled = selectedID != nil && !busy && switchingAvailable
    }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let view = BrowserRowView()
        view.isOddRow = row.isMultiple(of: 2)
        return view
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let browser = items[row]
        let dimmed = browser.id.lowercased() == currentID
        let cell = NSTableCellView()
        let icon = NSImageView()
        icon.image = NSWorkspace.shared.icon(forFile: browser.url.path)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.alphaValue = dimmed ? 0.35 : 1
        cell.addSubview(icon)
        cell.imageView = icon
        let label = NSTextField(labelWithString: browser.name + (dimmed ? L("  — 現在") : ""))
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = dimmed ? .disabledControlTextColor : .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        cell.addSubview(label)
        cell.textField = label
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }
    @objc func performSwitch() {
        guard !busy, let selectedID = selectedID, let browser = items.first(where: { $0.id == selectedID }) else { return }
        guard handler("https")?.lowercased() != browser.id.lowercased() || handler("http")?.lowercased() != browser.id.lowercased() else { return }
        busy = true
        refresh(message: L("%@ に切り替え中…\nmacOSの確認が表示されたら許可してください。", String(describing: browser.name)))
        Task { @MainActor in
            do {
                // HTTP is the default-browser entry point; HTTPS may follow the same change.
                try await NSWorkspace.shared.setDefaultApplication(at: browser.url, toOpenURLsWithScheme: "http")
                if handler("https")?.lowercased() != browser.id.lowercased() {
                    try await NSWorkspace.shared.setDefaultApplication(at: browser.url, toOpenURLsWithScheme: "https")
                }
                busy = false
                let matches = handler("https")?.lowercased() == browser.id.lowercased() && handler("http")?.lowercased() == browser.id.lowercased()
                refresh(message: matches ? L("%@ に切り替えました。", String(describing: browser.name)) : L("切り替えを確認できませんでした。macOSの確認ダイアログボックスをご確認ください。"))
            } catch {
                busy = false
                refresh(message: L("切り替えを完了できませんでした：%@", String(describing: error.localizedDescription)))
            }
        }

    }
}
/// Settings sheet that closes with Esc (cancelOperation reaches the window through the responder chain).
final class SettingsSheetWindow: NSWindow {
    var onCancel: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}
if CommandLine.arguments.contains("--diagnose") {
    print("Switching: Launch Services native API (no external tools)")
    print("HTTP: \(handler("http") ?? "unknown")")
    print("HTTPS: \(handler("https") ?? "unknown")")
    for browser in browsers() { print("\(browser.name) | \(browser.id) | \(browser.token) | dimmed=\(browser.id.lowercased() == handler("https")?.lowercased())") }
} else {
    MainActor.assumeIsolated { SingleInstanceLaunch.enforce() }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
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
