import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSTextFieldDelegate {
    private var item: NSStatusItem!
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var timer: Timer?
    private var window: NSWindow?
    private var preferencesWindow: NSWindow?
    private let skippedFolderField = NSTextField(string: "")
    private let statusField = NSTextField(string: "")
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let orderPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private var separatorButtons: [NSButton] = []
    private var busy = false
    private var swallowedKeys = Set<Int64>()
    private var enabled = UserDefaults.standard.object(forKey: "shortcutsEnabled") as? Bool ?? true
    private var localKeys: Any?
    private var shortcuts = Shortcut.load()
    private var paletteShortcut = Shortcut.loadPalette()
    /// The six action keys followed by the palette key; settings rows and recording use this order.
    private var allShortcuts: [Shortcut] { shortcuts + [paletteShortcut] }
    /// False after the palette key could not be registered; its settings field shows the shared message.
    private var paletteRegistered = true
    private var lastResult = L("status.initial")
    private var palette: CommandPalette?
    private var paletteHotkey: PaletteHotkey?
    private weak var fileMenuPaletteItem: NSMenuItem?

    /// Settings imported from a file or another Mac (「設定の共有」).
    private func startSettingsSync() {
        MainActor.assumeIsolated {
            SettingsSync.shared.onImport = { [weak self] in
                guard let self else { return }
                self.shortcuts = Shortcut.load()
                self.enabled = UserDefaults.standard.object(forKey: "shortcutsEnabled") as? Bool ?? true
                self.palette?.refreshShortcutLabels(self.shortcuts)
                self.palette?.refresh()
                self.publishHotkeys()
                self.updateStatus()
                HotkeyRecorder.shared.touch()
                self.refreshNamingControls()
                self.skippedFolderField.stringValue = ParentFolderSettings.skippedName()
                self.statusField.stringValue = NamingSettings.statuses().joined(separator: ", ")
            }
            SettingsSync.shared.start(.init(
                keys: [Shortcut.storageKey, "shortcutsEnabled", NamingSettings.key, NamingSettings.separatorKey,
                       NamingSettings.statusKey, ParentFolderSettings.key],
                note: StartupWindow.text("機能のホットキーとその有効／無効、区切り文字、接尾辞の並び順、ステータスの語、読み飛ばす親フォルダ名を書き出し・同期します。",
                                         "Exports and syncs the action shortcuts and whether they are on, the separator, the suffix order, the status words and the parent folder name to skip.",
                                         "导出并同步功能快捷键及其开关、分隔符、后缀顺序、状态词和要跳过的父文件夹名称。",
                                         "기능 단축키와 사용 여부, 구분 문자, 접미사 순서, 상태 단어, 건너뛸 상위 폴더 이름을 내보내고 동기화합니다."),
                perMac: StartupWindow.text("ログイン時の起動・起動時の表示・メニューバー・パレットのホットキー・アクセシビリティはMacごとに設定します。",
                                           "Login launch, startup display, the menu bar icon, the palette shortcut and Accessibility are set per Mac.",
                                           "登录时启动、启动时的显示、菜单栏图标、面板快捷键和辅助功能在每台 Mac 上分别设置。",
                                           "로그인 시 실행, 시작 시 표시, 메뉴 막대 아이콘, 팔레트 단축키, 손쉬운 사용은 Mac마다 설정합니다.")))
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        AccessibilityText.neededOverride = [
            "Finder／Path Finderの選択項目の取得とホットキー操作に使用します。",
            "Used to get the selected items in Finder / Path Finder and to handle keyboard shortcuts.",
            "用于获取 Finder／Path Finder 中选中的项目以及处理快捷键操作。",
            "Finder／Path Finder에서 선택한 항목을 가져오고 단축키를 처리하는 데 사용합니다."]
        defer { DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MenuBarPresence.shared.install(name: "CommandDee", symbol: "doc.on.doc", existing: self.item,
                show: { [weak self] in self?.showPreferences() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in self?.showHelp() })
        } }
        NSApp.setActivationPolicy(.accessory)
        WindowActivationPolicy.install()
        installApplicationMenu()
        localKeys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else { return event }
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "q": NSApp.terminate(nil); return nil
            case ",": self.showPreferences(); return nil
            case "w": NSApp.keyWindow?.performClose(nil); return nil
            default: return event
            }
        }
        if !UserDefaults.standard.bool(forKey: "loginDefaultConfigured") {
            do {
                if SMAppService.mainApp.status == .notRegistered { try SMAppService.mainApp.register() }
                if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                    UserDefaults.standard.set(true, forKey: "loginDefaultConfigured")
                }
            } catch { NSLog("Login registration failed: %@", error.localizedDescription) }
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "⌘D"
        item.button?.toolTip = L("status.tooltip")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        installTap()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.tap == nil { self.installTap() }
            self.updateStatus()
        }
        palette = CommandPalette(perform: { [weak self] mode, target in self?.runFromPalette(mode, target: target) },
                                 isBusy: { [weak self] in self?.busy ?? false },
                                 openSettings: #selector(showPreferences), settingsTarget: self)
        if !StartupWindow.suppressInitialWindow && UserDefaults.standard.bool(forKey: CommandPalette.visibleKey) { palette?.show() }
        paletteHotkey = PaletteHotkey { [weak self] in self?.togglePalette() }
        registerPaletteHotkey()
        // While a settings field records a key, the palette key is released so the keystroke reaches the field.
        MainActor.assumeIsolated {
            HotkeyRecorder.shared.onRecordingChanged.append { [weak self] recording in
                if recording { self?.paletteHotkey?.unregister() } else { self?.registerPaletteHotkey() }
            }
        }
        startSettingsSync()
        if !StartupWindow.suppressInitialWindow {
            showPreferences()
            UserDefaults.standard.set(true, forKey: "didShowIntroduction")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if busy {
            showError(L("alert.busyQuit"))
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        if let localKeys { NSEvent.removeMonitor(localKeys) }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
    }

    private func installApplicationMenu() {
        let main = NSMenu()
        let root = NSMenuItem()
        let application = NSMenu(title: "CommandDee")
        let about = application.addItem(withTitle: L("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        application.addItem(.separator())
        let preferences = application.addItem(withTitle: L("menu.settings"), action: #selector(showPreferences), keyEquivalent: ",")
        preferences.target = self
        application.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        MainActor.assumeIsolated { AppUpdates.shared.addMenuItems(to: application) }
        #endif
        let services = NSMenu(title: L("menu.services"))
        application.addItem(withTitle: L("menu.services"), action: nil, keyEquivalent: "").submenu = services
        NSApp.servicesMenu = services
        application.addItem(.separator())
        application.addItem(withTitle: L("menu.hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = application.addItem(withTitle: L("menu.hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        application.addItem(withTitle: L("menu.showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        application.addItem(.separator())
        application.addItem(withTitle: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        root.submenu = application
        main.addItem(root)
        let fileRoot = NSMenuItem(title: L("menu.file"), action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: L("menu.file"))
        let openMain = fileMenu.addItem(withTitle: L("menu.openMainWindow"), action: #selector(showPreferences), keyEquivalent: "0")
        openMain.keyEquivalentModifierMask = .command
        openMain.target = self
        fileMenu.addItem(.separator())
        let showPalette = fileMenu.addItem(withTitle: L("menu.showPalette"), action: #selector(togglePalette), keyEquivalent: "")
        showPalette.target = self
        fileMenuPaletteItem = showPalette
        applyPaletteKey(to: showPalette)
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: L("menu.closeWindow"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileRoot.submenu = fileMenu
        main.addItem(fileRoot)
        let editRoot = NSMenuItem()
        let edit = NSMenu(title: L("menu.edit"))
        edit.addItem(withTitle: L("menu.undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: L("menu.redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(withTitle: L("menu.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("menu.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("menu.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("menu.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editRoot.submenu = edit
        main.addItem(editRoot)
        let windowRoot = NSMenuItem()
        let windowMenu = NSMenu(title: L("menu.window"))
        windowMenu.addItem(withTitle: L("menu.minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: L("menu.zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: L("menu.bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowRoot.submenu = windowMenu
        main.addItem(windowRoot)
        NSApp.windowsMenu = windowMenu
        let helpRoot = NSMenuItem()
        let helpMenu = NSMenu(title: L("menu.help"))
        let help = helpMenu.addItem(withTitle: L("menu.appHelp"), action: #selector(showHelp), keyEquivalent: "?")
        help.target = self
        MainActor.assumeIsolated { HelpLinks.addNoteItem(to: helpMenu) }
        helpRoot.submenu = helpMenu
        main.addItem(helpRoot)
        NSApp.helpMenu = helpMenu
        NSApp.mainMenu = main
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        StartupWindow.userRequestedWindow()
        showPreferences()
        return true
    }

    private func installTap() {
        guard tap == nil, AccessibilitySection.isTrusted else { return }
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        guard let port = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
                return owner.handle(type: type, event: event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        tap = port
        tapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            swallowedKeys.removeAll()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard swallowedKeys.contains(keyCode) || shortcuts.contains(where: { Int64($0.keyCode) == keyCode }) else { return Unmanaged.passUnretained(event) }
        if type == .keyUp {
            if swallowedKeys.remove(keyCode) != nil { return nil }
            return Unmanaged.passUnretained(event)
        }
        if swallowedKeys.contains(keyCode) && event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return nil }
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        guard let shortcutIndex = shortcuts.firstIndex(where: { $0.matches(keyCode: UInt16(truncatingIfNeeded: keyCode), flags: flags) }) else { return Unmanaged.passUnretained(event) }
        let mode = Shortcut.modes[shortcutIndex]
        guard enabled,
              let app = NSWorkspace.shared.frontmostApplication,
              let id = app.bundleIdentifier, Browser.identifiers.contains(id),
              !isEditingText(app.processIdentifier) else { return Unmanaged.passUnretained(event) }
        swallowedKeys.insert(keyCode)
        if !busy {
            busy = true
            DispatchQueue.main.async { [weak self] in self?.duplicateSelection(id: id, pid: app.processIdentifier, mode: mode) }
        }
        return nil
    }

    private func isEditingText(_ pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.05)
        var value: CFTypeRef?
        // Fail open: preserve the host shortcut if the focus cannot be inspected.
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return true }
        let element = unsafeBitCast(value, to: AXUIElement.self)
        var role: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success else { return true }
        return [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role as? String ?? "")
    }

    private func duplicateSelection(id: String, pid: pid_t, mode: Duplicator.Mode) {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { busy = false; return }
        do {
            let files = try Browser.selection(from: id)
            guard !files.isEmpty else {
                busy = false
                lastResult = L("status.noSelection")
                updateStatus()
                NSSound.beep()
                if !NSApp.windows.contains(where: { $0.isVisible && !($0 is NSPanel) }) {
                    DispatchQueue.main.async { MainActor.assumeIsolated { TransientMessage.show(L("status.noSelection")) } }
                }
                return
            }
            let action = mode == .swapNames ? "swap" : ((mode == .parent || mode == .renameDate || { if case .status = mode { return true }; return false }()) ? "rename" : "duplicate")
            lastResult = L("progress." + action, files.count)
            updateStatus()
            // Use one date for the whole selection, including batches crossing midnight.
            let batchDate = Date()
            let batchTimeZone = TimeZone.current
            let suffixOrder = NamingSettings.order()
            let separator = NamingSettings.separator()
            let skippedParentName = ParentFolderSettings.skippedName()
            DispatchQueue.global(qos: .userInitiated).async {
                var copies: [URL] = []
                var failures: [String] = []
                var skipped = 0
                if mode == .swapNames {
                    do { copies = try Duplicator.swapNames(files) }
                    catch { failures.append(error.localizedDescription) }
                }
                for file in mode == .swapNames ? [] : files {
                    do {
                        let copy: URL
                        switch mode {
                        case .swapNames: continue
                        case .version: copy = try Duplicator.duplicate(file, order: suffixOrder, separator: separator)
                        case .parent: copy = try Duplicator.renameParentToggled(file, skipping: skippedParentName, separator: separator)
                        case .date: copy = try Duplicator.duplicateDated(file, date: batchDate, timeZone: batchTimeZone, order: suffixOrder, separator: separator)
                        case .edited: copy = try Duplicator.duplicateEdited(file, order: suffixOrder, separator: separator)
                        case .renameDate: copy = try Duplicator.duplicateDated(file, rename: true, date: batchDate, timeZone: batchTimeZone, order: suffixOrder, separator: separator)
                        case .status(let word): copy = try Duplicator.renameStatus(file, status: word, order: suffixOrder, separator: separator)
                        }
                        if copy == file { skipped += 1 } else { copies.append(copy) }
                    }
                    catch { failures.append("\(file.lastPathComponent): \(error.localizedDescription)") }
                }
                let result = copies.count == 1 ? copies[0].lastPathComponent : L("done." + action, copies.count)
                let summary = result + (skipped > 0 ? L("done.skipped", skipped) : "")
                let errors = failures.joined(separator: "\n")
                DispatchQueue.main.async {
                    self.busy = false
                    self.lastResult = failures.isEmpty ? summary : L("partial." + action, copies.count, failures.count)
                    self.updateStatus()
                    self.palette?.refresh()
                    if !errors.isEmpty { self.showError(errors) }
                }
            }
        } catch {
            busy = false
            lastResult = L("status.selectionFailed")
            showError(error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("alert.failed")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = menu.addItem(withTitle: "CommandDee", action: nil, keyEquivalent: "")
        title.isEnabled = false
        let status = menu.addItem(withTitle: lastResult, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(.separator())
        let openMain = menu.addItem(withTitle: L("menu.openMainWindow"), action: #selector(showPreferences), keyEquivalent: "")
        openMain.target = self
        let paletteItem = menu.addItem(withTitle: palette?.isVisible == true ? L("menu.hidePalette") : L("menu.showPalette"),
                                       action: #selector(togglePalette), keyEquivalent: "")
        paletteItem.target = self
        applyPaletteKey(to: paletteItem)
        let toggle = menu.addItem(withTitle: L("menu.enableShortcuts"), action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        toggle.state = enabled ? .on : .off
        let preferences = menu.addItem(withTitle: L("menu.settings"), action: #selector(showPreferences), keyEquivalent: ",")
        preferences.target = self
        // Help submenu: app help and the note article (BASELINE「メニューの共通構成」).
        let helpMenu = NSMenu(title: L("menu.help"))
        let help = helpMenu.addItem(withTitle: L("menu.appHelp"), action: #selector(showHelp), keyEquivalent: "")
        help.target = self
        MainActor.assumeIsolated { HelpLinks.addNoteItem(to: helpMenu) }
        menu.setSubmenu(helpMenu, for: menu.addItem(withTitle: L("menu.help"), action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(withTitle: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    /// Menu items show the palette hotkey (a letter or digit key; other keys are left without an equivalent).
    private func applyPaletteKey(to item: NSMenuItem) {
        let character = paletteShortcut.label.last.map { String($0).lowercased() } ?? ""
        let usable = paletteShortcut.keyCode != UInt16.max && character.count == 1 && character.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
        item.keyEquivalent = usable ? character : ""
        item.keyEquivalentModifierMask = usable ? NSEvent.ModifierFlags(rawValue: paletteShortcut.modifiers) : []
    }

    /// Registers the palette key and shows the result under its row in Settings (and on the menu items).
    private func registerPaletteHotkey() {
        paletteRegistered = paletteHotkey?.register(paletteShortcut) ?? false
        MainActor.assumeIsolated { HotkeyRecorder.shared.touch() }
        if let item = fileMenuPaletteItem { applyPaletteKey(to: item) }
        publishHotkeys()
    }

    /// Lists the keys for HotkeyHound: the palette key works everywhere; action keys only over Finder / Path Finder
    /// (event tap, not Carbon) and follow 「ホットキーを有効にする」. Unset keys are left out.
    private func publishHotkeys() {
        let ids = ["version", "renameDate", "date", "edited", "parent", "swapNames"]   // order of Shortcut.defaults
        let actions = zip(ids, zip(shortcuts, Shortcut.titles)).map { id, pair in
            HotkeyManifest.Item(id: id, title: pair.1, keyCode: Int(pair.0.keyCode), modifiers: Int(pair.0.carbonModifiers),
                                enabled: enabled, scope: "only", apps: Browser.identifiers)
        }
        let palette = HotkeyManifest.Item(id: Shortcut.paletteStorageKey, title: L("shortcut.palette"), keyCode: Int(paletteShortcut.keyCode),
                                          modifiers: Int(paletteShortcut.carbonModifiers))
        HotkeyManifest.publish(([palette] + actions).filter { $0.keyCode != Int(UInt16.max) })
    }

    @objc private func togglePalette() {
        if palette?.isVisible == true { palette?.hide() } else { palette?.show() }
    }

    /// A palette click works on the selection it previewed; the browser is brought forward first if needed.
    private func runFromPalette(_ mode: Duplicator.Mode, target: PaletteTarget) {
        guard !busy, let app = NSRunningApplication(processIdentifier: target.pid), !app.isTerminated else { NSSound.beep(); return }
        busy = true
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid {
            duplicateSelection(id: target.bundleID, pid: target.pid, mode: mode)
        } else {
            app.activate(options: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.duplicateSelection(id: target.bundleID, pid: target.pid, mode: mode)
            }
        }
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        UserDefaults.standard.set(enabled, forKey: "shortcutsEnabled")
        publishHotkeys()
        updateStatus()
    }

    private func updateStatus() {
        let ready = AccessibilitySection.isTrusted && tap.map { CGEvent.tapIsEnabled(tap: $0) } == true
        statusLabel.stringValue = !ready ? AccessibilityText.text("blocked") : (enabled ? L("status.enabled") : L("status.paused"))
        item.button?.appearsDisabled = !enabled || !ready
        item.button?.toolTip = "CommandDee\n\(statusLabel.stringValue)\n\(lastResult)"
    }

    @objc private func showHelp() {
        if window == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            panel.title = ""
            panel.minSize = NSSize(width: 480, height: 420)
            AppSurface.install(in: panel.contentView!)
            panel.isReleasedWhenClosed = false
            let heading = appHeader(L("help.heading"), subtitle: L("help.subtitle"))
            let document = MainActor.assumeIsolated { HelpDocument.makeScrollView(helpText(), title: nil) }
            document.borderType = .lineBorder
            document.setContentHuggingPriority(.defaultLow, for: .vertical)
            let button = NSButton(title: L("help.openAccessibility"), target: self, action: #selector(openAccessibility))
            let preferencesButton = NSButton(title: L("menu.settings"), target: self, action: #selector(showPreferences))
            let buttons = NSStackView(views: [button, preferencesButton])
            buttons.spacing = 12
            let stack = NSStackView(views: [heading, document, statusLabel, buttons])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 16
            stack.translatesAutoresizingMaskIntoConstraints = false
            panel.contentView!.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 26),
                stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -26),
                stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 26),
                stack.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor, constant: -24),
                document.widthAnchor.constraint(equalTo: stack.widthAnchor)
            ])
            panel.center()
            window = panel
        }
        updateStatus()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func showPreferences() {
        if preferencesWindow == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
                                 styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            panel.title = L("settings.title")
            panel.contentMinSize = NSSize(width: 480, height: 560)
            panel.isReleasedWhenClosed = false
            let title = NSTextField(labelWithString: L("settings.skipFolder"))
            title.font = .systemFont(ofSize: 17, weight: .semibold)
            skippedFolderField.delegate = self
            skippedFolderField.placeholderString = L("settings.skipFolderPlaceholder")
            skippedFolderField.setAccessibilityLabel(L("settings.skipFolder"))
            let reset = NSButton(title: L("settings.resetSkipFolder"), target: self, action: #selector(resetSkippedFolder))
            let statusTitle = NSTextField(labelWithString: L("settings.statuses"))
            statusTitle.font = .systemFont(ofSize: 17, weight: .semibold)
            statusField.delegate = self
            statusField.setAccessibilityLabel(L("settings.statuses"))
            let statusNote = NSTextField(wrappingLabelWithString: L("settings.statusesNote"))
            statusNote.font = .systemFont(ofSize: 11)
            statusNote.textColor = .secondaryLabelColor
            let resetStatuses = NSButton(title: L("settings.resetStatuses"), target: self, action: #selector(resetStatusWords))
            let login = MainActor.assumeIsolated { LoginAtLaunchControl() }
            let keysTitle = NSTextField(labelWithString: L("settings.keyboardShortcuts"))
            keysTitle.font = .systemFont(ofSize: 17, weight: .semibold)
            let keyRows = NSStackView()
            keyRows.orientation = .vertical
            keyRows.alignment = .leading
            keyRows.spacing = 10
            for index in shortcuts.indices {
                let label = NSTextField(labelWithString: Shortcut.titles[index])
                let field = shortcutField(index)
                keyRows.addArrangedSubview(label)
                keyRows.addArrangedSubview(field)
                field.widthAnchor.constraint(equalTo: keyRows.widthAnchor).isActive = true
            }
            let orderTitle = NSTextField(labelWithString: L("settings.suffixOrder"))
            orderTitle.font = .systemFont(ofSize: 17, weight: .semibold)
            let separatorTitle = NSTextField(labelWithString: L("settings.separator"))
            separatorTitle.font = .systemFont(ofSize: 17, weight: .semibold)
            separatorButtons = [L("settings.separatorHyphen"), L("settings.separatorUnderscore")].enumerated().map { index, label in
                let button = NSButton(radioButtonWithTitle: label, target: self, action: #selector(changeSeparator(_:)))
                button.tag = index
                return button
            }
            let separatorRow = NSStackView(views: separatorButtons)
            separatorRow.spacing = 16
            orderPopup.setAccessibilityLabel(L("settings.suffixOrder"))
            orderPopup.target = self
            orderPopup.action = #selector(changeSuffixOrder)
            let resetKeys = NSButton(title: L("settings.resetShortcuts"), target: self, action: #selector(resetShortcuts))
            let helpButton = NSButton(title: L("menu.help"), target: self, action: #selector(showHelp))
            let access = MainActor.assumeIsolated { AccessibilitySection.group() }
            // Palette hotkey (the app-calling key) lives here, like MightyEdit's palette shortcut.
            let paletteLabel = NSTextField(labelWithString: L("shortcut.palette"))
            paletteLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            let paletteField = shortcutField(nil)
            let paletteNote = NSTextField(wrappingLabelWithString: L("settings.paletteHotkeyNote"))
            paletteNote.font = .systemFont(ofSize: 11)
            paletteNote.textColor = .secondaryLabelColor
            let launchGroup = MainActor.assumeIsolated { SettingsUI.group(SettingsUI.launchTitle, [login, MenuBarPresence.shared.settingsControl(),
                                                                                                   paletteLabel, paletteField, paletteNote]) }
            let keyGroup = MainActor.assumeIsolated { SettingsUI.group(L("settings.actionShortcuts"), [keyRows, resetKeys]) }
            let nameGroup = MainActor.assumeIsolated { SettingsUI.group(L("settings.fileNames"), [separatorTitle, separatorRow, orderTitle, orderPopup, title, skippedFolderField, reset,
                                                                                                 statusTitle, statusField, statusNote, resetStatuses]) }
            let accessPage = NSStackView(views: [launchGroup, access, helpButton])
            accessPage.orientation = .vertical; accessPage.alignment = .leading; accessPage.spacing = 16
            access.widthAnchor.constraint(equalTo: accessPage.widthAnchor).isActive = true
            launchGroup.widthAnchor.constraint(equalTo: accessPage.widthAnchor).isActive = true
            MainActor.assumeIsolated { SettingsUI.tabs([
                (SettingsUI.launchTitle, accessPage), (L("settings.hotkeys"), keyGroup),
                (L("settings.fileNames"), nameGroup), (SettingsSync.shared.tabTitle, SettingsSync.shared.sharingPage()),
                (AboutSection.title, AboutSection.view())
            ], in: panel.contentView!) }
            panel.center()
            preferencesWindow = panel
        }
        refreshNamingControls()
        skippedFolderField.stringValue = ParentFolderSettings.skippedName()
        statusField.stringValue = NamingSettings.statuses().joined(separator: ", ")
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }

    /// The order popup previews names with the current separator, so both are refreshed together.
    private func refreshNamingControls() {
        let separator = NamingSettings.separator()
        for button in separatorButtons { button.state = NamingSettings.separators[button.tag] == separator ? .on : .off }
        orderPopup.removeAllItems()
        orderPopup.addItems(withTitles: NamingSettings.orders.map { NamingSettings.label($0, separator: separator) })
        orderPopup.selectItem(at: NamingSettings.orders.firstIndex(of: NamingSettings.order()) ?? 0)
    }

    @objc private func changeSeparator(_ sender: NSButton) {
        guard NamingSettings.separators.indices.contains(sender.tag) else { return }
        UserDefaults.standard.set(NamingSettings.separators[sender.tag], forKey: NamingSettings.separatorKey)
        refreshNamingControls()
    }

    @objc private func changeSuffixOrder() {
        let index = orderPopup.indexOfSelectedItem
        guard NamingSettings.orders.indices.contains(index) else { return }
        UserDefaults.standard.set(NamingSettings.orders[index], forKey: NamingSettings.key)
    }

    @objc private func resetShortcuts() {
        MainActor.assumeIsolated { HotkeyRecorder.shared.stop() }
        shortcuts = Shortcut.defaults
        Shortcut.save(shortcuts)
        palette?.refreshShortcutLabels(shortcuts)
        publishHotkeys()
        MainActor.assumeIsolated { HotkeyRecorder.shared.touch() }
    }

    private static func combo(_ shortcut: Shortcut) -> KeyCombo? {
        shortcut.isUnset ? nil : KeyCombo(code: UInt32(shortcut.keyCode), modifiers: shortcut.carbonModifiers)
    }
    private static func shortcut(_ combo: KeyCombo?) -> Shortcut {
        combo.map { Shortcut(keyCode: UInt16($0.code), carbonModifiers: $0.modifiers, label: $0.label) } ?? Shortcut.unset
    }
    /// The shared hotkey field (Shared/HotkeyRecorder): `index` is an action key, nil the palette key.
    /// The JSON in keyboardShortcutsV2 / paletteShortcut is kept as it was.
    private func shortcutField(_ index: Int?) -> NSView {
        let fallback = index.map { Shortcut.defaults[$0] } ?? Shortcut.paletteDefault
        return MainActor.assumeIsolated {
            HotkeyField.control(id: index.map { "action\($0)" } ?? "palette",
                                get: { [weak self] in
                                    guard let self else { return nil }
                                    return Self.combo(index.map { self.shortcuts[$0] } ?? self.paletteShortcut)
                                },
                                set: { [weak self] combo in
                                    guard let self else { return }
                                    if let index {
                                        self.shortcuts[index] = Self.shortcut(combo)
                                        Shortcut.save(self.shortcuts)
                                        self.palette?.refreshShortcutLabels(self.shortcuts)
                                        self.publishHotkeys()
                                    } else if let combo {
                                        self.paletteShortcut = Self.shortcut(combo)
                                        Shortcut.savePalette(self.paletteShortcut)
                                        // While recording, the key is registered when recording ends (onRecordingChanged).
                                        if HotkeyRecorder.shared.recordingID == nil { self.registerPaletteHotkey() }
                                    }
                                },
                                defaultCombo: Self.combo(fallback),
                                allowsClear: index != nil,
                                others: { [weak self] in
                                    guard let self else { return [] }
                                    let titled = zip(Shortcut.titles, self.shortcuts).map { ($0.0, $0.1) } + [(L("shortcut.palette"), self.paletteShortcut)]
                                    let mine = index ?? self.shortcuts.count
                                    return titled.enumerated().compactMap { offset, pair in offset == mine ? nil : Self.combo(pair.1).map { (pair.0, $0) } }
                                },
                                registered: { [weak self] in index != nil || (self?.paletteRegistered ?? true) })
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        if notification.object as? NSTextField === statusField {
            UserDefaults.standard.set(NamingSettings.parseStatuses(statusField.stringValue), forKey: NamingSettings.statusKey)
            palette?.refresh()
            return
        }
        guard notification.object as? NSTextField === skippedFolderField else { return }
        UserDefaults.standard.set(skippedFolderField.stringValue, forKey: ParentFolderSettings.key)
    }

    /// Shows the list as saved (invalid words dropped) once editing ends.
    func controlTextDidEndEditing(_ notification: Notification) {
        guard notification.object as? NSTextField === statusField else { return }
        statusField.stringValue = NamingSettings.statuses().joined(separator: ", ")
    }

    @objc private func resetStatusWords() {
        UserDefaults.standard.removeObject(forKey: NamingSettings.statusKey)
        statusField.stringValue = NamingSettings.statuses().joined(separator: ", ")
        palette?.refresh()
    }

    @objc private func resetSkippedFolder() {
        UserDefaults.standard.removeObject(forKey: ParentFolderSettings.key)
        skippedFolderField.stringValue = ParentFolderSettings.skippedName()
    }

    @objc private func openAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        MainActor.assumeIsolated { _ = AccessibilitySettingsLocator.shared.open() }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()


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
func appHeader(_ title: String, subtitle: String = "", size: CGFloat = 44, showsVersion: Bool = true) -> NSStackView {
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
