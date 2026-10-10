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
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let orderPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private var separatorButtons: [NSButton] = []
    private var busy = false
    private var swallowedKeys = Set<Int64>()
    private var enabled = UserDefaults.standard.object(forKey: "shortcutsEnabled") as? Bool ?? true
    private var localKeys: Any?
    private var shortcuts = Shortcut.load()
    private var shortcutButtons: [NSButton] = []
    private let shortcutMessage: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "")
        label.textColor = .systemRed
        label.font = .systemFont(ofSize: 12)
        return label
    }()
    private var recordingShortcut: Int?
    private var lastResult = L("status.initial")

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            if let index = self.recordingShortcut {
                if event.keyCode == 53 { self.recordingShortcut = nil; self.refreshShortcutButtons(); return nil }
                guard let shortcut = Shortcut.capture(event) else { self.showShortcutMessage(L("settings.shortcutInvalid")); return nil }
                guard !self.shortcuts.enumerated().contains(where: { $0.offset != index && $0.element.keyCode == shortcut.keyCode && $0.element.modifiers == shortcut.modifiers }) else {
                    self.showShortcutMessage(L("settings.shortcutDuplicate", shortcut.displayLabel)); return nil
                }
                self.shortcutMessage.stringValue = ""
                self.shortcuts[index] = shortcut
                Shortcut.save(self.shortcuts)
                self.recordingShortcut = nil
                self.refreshShortcutButtons()
                return nil
            }
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
        if !StartupWindow.hidden && !UserDefaults.standard.bool(forKey: "didShowIntroduction") {
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
        showPreferences()
        return true
    }

    private func installTap() {
        guard tap == nil, AXIsProcessTrusted() else { return }
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
        let modifiers = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl, .maskSecondaryFn])
        guard let shortcutIndex = shortcuts.firstIndex(where: { Int64($0.keyCode) == keyCode && $0.modifiers == UInt(modifiers.rawValue) }) else { return Unmanaged.passUnretained(event) }
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
            let action = mode == .swapNames ? "swap" : ((mode == .parent || mode == .renameDate) ? "rename" : "duplicate")
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

    @objc private func toggleEnabled() {
        enabled.toggle()
        UserDefaults.standard.set(enabled, forKey: "shortcutsEnabled")
        updateStatus()
    }

    private func updateStatus() {
        let ready = AXIsProcessTrusted() && tap.map { CGEvent.tapIsEnabled(tap: $0) } == true
        statusLabel.stringValue = !ready ? L("status.needsAccessibility") : (enabled ? L("status.enabled") : L("status.paused"))
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
            let login = MainActor.assumeIsolated { LoginAtLaunchControl() }
            let keysTitle = NSTextField(labelWithString: L("settings.keyboardShortcuts"))
            keysTitle.font = .systemFont(ofSize: 17, weight: .semibold)
            let keyRows = NSStackView()
            keyRows.orientation = .vertical
            keyRows.alignment = .leading
            keyRows.spacing = 10
            for index in shortcuts.indices {
                let label = NSTextField(labelWithString: Shortcut.titles[index])
                label.widthAnchor.constraint(equalToConstant: 190).isActive = true
                let button = NSButton(title: shortcuts[index].displayLabel, target: self, action: #selector(recordShortcut(_:)))
                button.tag = index
                button.widthAnchor.constraint(equalToConstant: 150).isActive = true
                shortcutButtons.append(button)
                keyRows.addArrangedSubview(NSStackView(views: [label, button]))
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
            let access = AccessibilityPermissionControl(required: true)
            let launchGroup = MainActor.assumeIsolated { SettingsUI.group(SettingsUI.launchTitle, [login, MenuBarPresence.shared.settingsControl()]) }
            let keyGroup = MainActor.assumeIsolated { SettingsUI.group(L("settings.actionShortcuts"), [keyRows, shortcutMessage, resetKeys]) }
            let nameGroup = MainActor.assumeIsolated { SettingsUI.group(L("settings.fileNames"), [separatorTitle, separatorRow, orderTitle, orderPopup, title, skippedFolderField, reset]) }
            let accessPage = NSStackView(views: [launchGroup, access, helpButton])
            accessPage.orientation = .vertical; accessPage.alignment = .leading; accessPage.spacing = 16
            access.widthAnchor.constraint(equalTo: accessPage.widthAnchor).isActive = true
            launchGroup.widthAnchor.constraint(equalTo: accessPage.widthAnchor).isActive = true
            MainActor.assumeIsolated { SettingsUI.tabs([
                (SettingsUI.launchTitle, accessPage), (L("settings.hotkeys"), keyGroup),
                (L("settings.fileNames"), nameGroup), (AboutSection.title, AboutSection.view())
            ], in: panel.contentView!) }
            panel.center()
            preferencesWindow = panel
        }
        refreshNamingControls()
        skippedFolderField.stringValue = ParentFolderSettings.skippedName()
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

    @objc private func recordShortcut(_ sender: NSButton) {
        recordingShortcut = sender.tag
        shortcutMessage.stringValue = ""
        refreshShortcutButtons()
    }

    /// Why the pressed key was not accepted, shown under the shortcut list (not just a beep).
    private func showShortcutMessage(_ text: String) {
        NSSound.beep()
        shortcutMessage.stringValue = text
    }

    private func refreshShortcutButtons() {
        for (index, button) in shortcutButtons.enumerated() {
            button.title = recordingShortcut == index ? L("settings.recordShortcut") : shortcuts[index].displayLabel
        }
    }

    @objc private func resetShortcuts() {
        recordingShortcut = nil
        shortcutMessage.stringValue = ""
        shortcuts = Shortcut.defaults
        Shortcut.save(shortcuts)
        refreshShortcutButtons()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard notification.object as? NSTextField === skippedFolderField else { return }
        UserDefaults.standard.set(skippedFolderField.stringValue, forKey: ParentFolderSettings.key)
    }

    @objc private func resetSkippedFolder() {
        UserDefaults.standard.removeObject(forKey: ParentFolderSettings.key)
        skippedFolderField.stringValue = ParentFolderSettings.skippedName()
    }

    @objc private func openAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
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
