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
    private var busy = false
    private var swallowedKeys = Set<Int64>()
    private var enabled = UserDefaults.standard.object(forKey: "shortcutsEnabled") as? Bool ?? true
    private var localKeys: Any?
    private var shortcuts = Shortcut.load()
    private var shortcutButtons: [NSButton] = []
    private var recordingShortcut: Int?
    private var lastResult = "ファイル／フォルダーを選択して ⌘D"

    func applicationDidFinishLaunching(_ notification: Notification) {
        defer { DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MenuBarPresence.shared.install(name: "CommandDee", symbol: "doc.on.doc", existing: self.item,
                show: { [weak self] in self?.showPreferences() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in self?.showHelp() })
        } }
        NSApp.setActivationPolicy(.accessory)
        installApplicationMenu()
        localKeys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if let index = self.recordingShortcut {
                if event.keyCode == 53 { self.recordingShortcut = nil; self.refreshShortcutButtons(); return nil }
                guard let shortcut = Shortcut.capture(event) else { NSSound.beep(); return nil }
                guard !self.shortcuts.enumerated().contains(where: { $0.offset != index && $0.element.keyCode == shortcut.keyCode && $0.element.modifiers == shortcut.modifiers }) else { NSSound.beep(); return nil }
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
        item.button?.toolTip = "CommandDee — バージョン・日付付きで複製"
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
            showError("処理中です。完了してから終了してください。")
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
        let about = application.addItem(withTitle: "CommandDeeについて", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        application.addItem(.separator())
        let preferences = application.addItem(withTitle: "環境設定…", action: #selector(showPreferences), keyEquivalent: ",")
        preferences.target = self
        application.addItem(.separator())
        application.addItem(withTitle: "CommandDeeを隠す", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        application.addItem(withTitle: "CommandDeeを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        root.submenu = application
        main.addItem(root)
        let editRoot = NSMenuItem()
        let edit = NSMenu(title: "編集")
        edit.addItem(withTitle: "取り消す", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "カット", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "コピー", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "ペースト", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "すべてを選択", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editRoot.submenu = edit
        main.addItem(editRoot)
        let helpRoot = NSMenuItem()
        let helpMenu = NSMenu(title: "ヘルプ")
        let help = helpMenu.addItem(withTitle: "CommandDeeヘルプ", action: #selector(showHelp), keyEquivalent: "?")
        help.target = self
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
            guard !files.isEmpty else { busy = false; lastResult = "ファイル／フォルダーが選択されていません"; NSSound.beep(); return }
            let action = mode == .swapNames ? "名前入れ替え" : ((mode == .parent || mode == .renameVersion) ? "名前変更" : "複製")
            lastResult = "\(files.count)項目を\(action)中…"
            updateStatus()
            // Use one date for the whole selection, including batches crossing midnight.
            let batchDate = Date()
            let batchTimeZone = TimeZone.current
            let suffixOrder = NamingSettings.order()
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
                        case .version: copy = try Duplicator.duplicate(file, order: suffixOrder)
                        case .renameVersion: copy = try Duplicator.renameVersion(file, order: suffixOrder)
                        case .parent: copy = try Duplicator.renameParentToggled(file, skipping: skippedParentName)
                        case .date: copy = try Duplicator.duplicateDated(file, date: batchDate, timeZone: batchTimeZone, order: suffixOrder)
                        case .edited: copy = try Duplicator.duplicateDated(file, edited: true, date: batchDate, timeZone: batchTimeZone, order: suffixOrder)
                        }
                        if copy == file { skipped += 1 } else { copies.append(copy) }
                    }
                    catch { failures.append("\(file.lastPathComponent): \(error.localizedDescription)") }
                }
                let result = copies.count == 1 ? copies[0].lastPathComponent : "\(copies.count)項目を\(action)しました"
                let summary = result + (skipped > 0 ? "・\(skipped)項目は今日の日付のためスキップ" : "")
                let errors = failures.joined(separator: "\n")
                DispatchQueue.main.async {
                    self.busy = false
                    self.lastResult = failures.isEmpty ? summary : "\(copies.count)項目を\(action)・\(failures.count)項目でエラー"
                    self.updateStatus()
                    if !errors.isEmpty { self.showError(errors) }
                }
            }
        } catch {
            busy = false
            lastResult = "選択の取得に失敗しました"
            showError(error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "処理を完了できませんでした"
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
        let toggle = menu.addItem(withTitle: "ショートカットを有効にする", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        toggle.state = enabled ? .on : .off
        let preferences = menu.addItem(withTitle: "環境設定…", action: #selector(showPreferences), keyEquivalent: ",")
        preferences.target = self
        let settings = menu.addItem(withTitle: "CommandDeeヘルプ…", action: #selector(showHelp), keyEquivalent: "")
        settings.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "CommandDeeを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        UserDefaults.standard.set(enabled, forKey: "shortcutsEnabled")
        updateStatus()
    }

    private func updateStatus() {
        let ready = AXIsProcessTrusted() && tap.map { CGEvent.tapIsEnabled(tap: $0) } == true
        statusLabel.stringValue = !ready ? "アクセシビリティの許可が必要です" : (enabled ? "ショートカット有効" : "一時停止中")
        item.button?.appearsDisabled = !enabled || !ready
        item.button?.toolTip = "CommandDee\n\(statusLabel.stringValue)\n\(lastResult)"
    }

    @objc private func showHelp() {
        if window == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 800), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = ""
            AppSurface.install(in: panel.contentView!)
            panel.isReleasedWhenClosed = false
            let heading = appHeader("ファイルの複製と名前変更", subtitle: "選択した項目にバージョン番号や日付を付ける。")
            let detail = NSTextField(wrappingLabelWithString: "Finder／Path Finderでファイルやフォルダーを選択します。\n⌘D：同じフォルダの最大バージョン番号＋1\n⌃⌘D：末尾に今日の日付を追加・更新\n⌃⌘E：末尾に -edited- と今日の日付を追加\n⌃E：末尾の -親フォルダー名 を付け外しして名前変更\n⌃⇧⌘D：複製せず、最大番号＋1に名前変更\n⌃⌥⌘S：同じフォルダーで選んだ2項目の名前を入れ替え")
            let example = NSTextField(wrappingLabelWithString: "⌘D：v2・v5 がある場合 → v6（欠番は無視）\n⌃⌘D：aaa.txt → aaa-YYYYMMDD.txt\n⌃⌘E：aaa.txt → aaa-edited-YYYYMMDD.txt")
            example.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
            let note = NSTextField(wrappingLabelWithString: "拡張子を維持し、元ファイルや既存のコピーは上書きしません。複数選択・フォルダにも対応します。\n末尾の日付は6桁・8桁とも認識し、8桁に更新します。\n今日の日付が付いた項目はスキップします（editedの新規付与は実行）。別の同名項目がある場合は処理せず、お知らせします。\n環境設定で v番号・edited・日付の順番を選べます。既存の名前も読み取り、次の操作から指定順で出力します。\n名前入れ替えはファイル同士・フォルダー同士で実行します。名前全体（拡張子を含む）を交換し、内容と更新日時は各項目に保持します。最大番号や更新日時での自動判定はしません。戻すには同じ2項目を選んで再実行します。\n\n環境設定のショートカットボタンを押して、修飾キーと文字キーを入力すると変更できます。Escで取消、同じ組み合わせの重複は登録できません。\n親フォルダー名の除外は完全一致で上の階層を参照します。空欄で無効化できます。\nウインドウを閉じても常駐します。終了はこのアプリの画面で⌘Q。\n\n初回はアクセシビリティを許可してください。操作時に表示されるFinder／Path Finderの操作許可も必要です。")
            note.textColor = .secondaryLabelColor
            let button = NSButton(title: "アクセシビリティ設定を開く", target: self, action: #selector(openAccessibility))
            let preferencesButton = NSButton(title: "環境設定…", target: self, action: #selector(showPreferences))
            let buttons = NSStackView(views: [button, preferencesButton])
            buttons.spacing = 12
            let stack = NSStackView(views: [heading, detail, example, note, statusLabel, buttons])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 18
            stack.translatesAutoresizingMaskIntoConstraints = false
            panel.contentView!.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 26),
                stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -26),
                stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 26),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: panel.contentView!.bottomAnchor, constant: -24)
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
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 620),
                                 styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = "CommandDee — 環境設定"
            panel.isReleasedWhenClosed = false
            let title = NSTextField(labelWithString: "読み飛ばす親フォルダー名")
            title.font = .systemFont(ofSize: 17, weight: .semibold)
            skippedFolderField.delegate = self
            skippedFolderField.placeholderString = "空欄の場合は、直上の親フォルダー名を使用"
            skippedFolderField.setAccessibilityLabel("読み飛ばす親フォルダー名")
            let reset = NSButton(title: "ログインユーザー名に戻す", target: self, action: #selector(resetSkippedFolder))
            let login = MainActor.assumeIsolated { LoginAtLaunchControl() }
            let keysTitle = NSTextField(labelWithString: "キーボードショートカット")
            keysTitle.font = .systemFont(ofSize: 17, weight: .semibold)
            let keyRows = NSStackView()
            keyRows.orientation = .vertical
            keyRows.alignment = .leading
            keyRows.spacing = 10
            for index in shortcuts.indices {
                let label = NSTextField(labelWithString: Shortcut.titles[index])
                label.widthAnchor.constraint(equalToConstant: 235).isActive = true
                let button = NSButton(title: shortcuts[index].label, target: self, action: #selector(recordShortcut(_:)))
                button.tag = index
                button.widthAnchor.constraint(equalToConstant: 200).isActive = true
                shortcutButtons.append(button)
                keyRows.addArrangedSubview(NSStackView(views: [label, button]))
            }
            let orderTitle = NSTextField(labelWithString: "接尾辞の並び順")
            orderTitle.font = .systemFont(ofSize: 17, weight: .semibold)
            orderPopup.addItems(withTitles: NamingSettings.orders.map(NamingSettings.label))
            orderPopup.setAccessibilityLabel("接尾辞の並び順")
            orderPopup.target = self
            orderPopup.action = #selector(changeSuffixOrder)
            let resetKeys = NSButton(title: "ショートカットを初期値に戻す", target: self, action: #selector(resetShortcuts))
            let helpButton = NSButton(title: "ヘルプ", target: self, action: #selector(showHelp))
            let access = AccessibilityPermissionControl(required: true)
            let launchGroup = MainActor.assumeIsolated { SettingsUI.group(SettingsUI.launchTitle, [login, MenuBarPresence.shared.settingsControl()]) }
            let keyGroup = MainActor.assumeIsolated { SettingsUI.group("機能のショートカット", [keyRows, resetKeys]) }
            let nameGroup = MainActor.assumeIsolated { SettingsUI.group("ファイル名", [orderTitle, orderPopup, title, skippedFolderField, reset]) }
            let accessPage = NSStackView(views: [access, helpButton])
            accessPage.orientation = .vertical; accessPage.alignment = .leading; accessPage.spacing = 16
            access.widthAnchor.constraint(equalTo: accessPage.widthAnchor).isActive = true
            MainActor.assumeIsolated { SettingsUI.tabs([
                (SettingsUI.launchTitle, launchGroup), ("ホットキー", keyGroup),
                ("ファイル名", nameGroup), (AccessibilityText.text("title"), accessPage)
            ], in: panel.contentView!) }
            panel.center()
            preferencesWindow = panel
        }
        orderPopup.selectItem(at: NamingSettings.orders.firstIndex(of: NamingSettings.order()) ?? 0)
        skippedFolderField.stringValue = ParentFolderSettings.skippedName()
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func changeSuffixOrder() {
        let index = orderPopup.indexOfSelectedItem
        guard NamingSettings.orders.indices.contains(index) else { return }
        UserDefaults.standard.set(NamingSettings.orders[index], forKey: NamingSettings.key)
    }

    @objc private func recordShortcut(_ sender: NSButton) {
        recordingShortcut = sender.tag
        refreshShortcutButtons()
    }

    private func refreshShortcutButtons() {
        for (index, button) in shortcutButtons.enumerated() {
            button.title = recordingShortcut == index ? "キーを入力（Escで取消）" : shortcuts[index].label
        }
    }

    @objc private func resetShortcuts() {
        recordingShortcut = nil
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
