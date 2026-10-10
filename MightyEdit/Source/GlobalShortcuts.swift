import AppKit
import Carbon

// Uses the same Carbon registration approach as BrowserSwitcher/Source/main.swift.
final class GlobalShortcuts: NSObject {
    var additionalPreferenceTabs: [(String, NSView)] = []
    var actionEnabled: (Int) -> Bool = { _ in true }
    func reloadConfiguration() { register() }
    /// True while the front app is excluded or MightyEdit itself (B21): keys pass through.
    var hotkeysBlocked: () -> Bool = { false }
    private var blockedState = false
    /// Palette-only hotkeys are registered only while this returns true.
    var paletteVisible: () -> Bool = { false }
    private var visibleState = false
    /// Re-register only when the front app crosses the excluded boundary.
    func refreshForFrontApp() { if hotkeysBlocked() != blockedState { register() } }
    /// Call after the palette is shown, hidden or closed. Skips work when no action is palette-only.
    func refreshForPaletteVisibility() {
        guard paletteVisible() != visibleState else { return }
        if actions.contains(where: { scope($0.id) == .palette }) { register() } else { visibleState = paletteVisible() }
    }
    let menu = NSMenu(title: L("menu.hotkeys"))
    private var preferences: NSWindow?
    private var preferenceRows: [(id: Int, editor: HotkeyEditor, scope: NSPopUpButton, error: NSTextField)] = []
    private var enabledCheckbox: NSButton?
    private var pauseCheckbox: NSButton?
    private var handlerFailure: OSStatus?
    private let actions: [(id: Int, title: String, digit: Int)]
    private let perform: (Int) -> Void
    private var handler: EventHandlerRef?
    private var references: [EventHotKeyRef] = []
    private var paused = false
    private var pendingRelease: Timer?
    private var releaseGate = HotkeyReleaseGate()
    private var failures: [Int: OSStatus] = [:]
    // Keep persisted values 0...13 unchanged; append triple-modifier choices.
    private let keyCodes: [UInt32] = [29, 18, 19, 20, 21, 23, 22, 26, 28, 25, 43, 43, 18, 21,
                                      29, 18, 19, 20, 21, 23, 22, 26, 28, 25, 43, 27, 27, 27, 27, 24]

    private func binding(_ value: Int) -> HotkeyBinding? {
        if value >= 1000 { return HotkeyBinding.decode(value) }
        guard keyCodes.indices.contains(value) else { return nil }
        let mods: UInt32
        switch value {
        case 25: mods = UInt32(controlKey | shiftKey)
        case 26, 29: mods = UInt32(cmdKey | controlKey)
        case 27: mods = UInt32(cmdKey | controlKey | optionKey)
        case 28: mods = UInt32(cmdKey | controlKey | optionKey | shiftKey)
        default: mods = UInt32(controlKey) | (value >= 11 ? UInt32(optionKey) : 0) | (value >= 14 ? UInt32(cmdKey) : 0)
        }
        return HotkeyBinding(key: keyCodes[value], modifiers: mods)
    }

    private func label(_ value: Int) -> String {
        if value >= 1000 { return binding(value)?.label ?? L("hotkey.none") }
        // Joined with the localized plus sign (Japanese keeps the full-width ＋).
        func keys(_ parts: String...) -> String { parts.joined(separator: L("hotkey.plus")) }
        switch value {
        case 0...9: return keys("Control", "\(value)")
        case 10: return keys("Control", ",")
        case 11: return keys("Control", "Option", ",")
        case 12: return keys("Control", "Option", "1")
        case 13: return keys("Control", "Option", "4")
        case 14...23: return keys("Control", "Option", "⌘", "\(value - 14)")
        case 25: return keys("Control", "Shift", "-")
        case 26: return keys("⌘", "Control", "-")
        case 27: return keys("⌘", "Control", "Option", "-")
        case 28: return keys("⌘", "Control", "Option", "Shift", "-")
        case 29: return keys("⌘", "Control", "=")
        case 24: return keys("Control", "Option", "⌘", ",")
        default: return L("hotkey.none")
        }
    }

    init(actions: [(id: Int, title: String, digit: Int)], perform: @escaping (Int) -> Void) {
        self.actions = actions
        self.perform = perform
        super.init()
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == 0x4D454454 else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<GlobalShortcuts>.fromOpaque(context).takeUnretainedValue()
            let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
            owner.performOnPress(Int(identifier.id), pid: pid)
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        if status != noErr { handlerFailure = status; actions.forEach { failures[$0.id] = status }; rebuildMenu() }
        else { register() }
    }

    deinit {
        pendingRelease?.invalidate()
        references.forEach { UnregisterEventHotKey($0) }
        if let handler { RemoveEventHandler(handler) }
    }

    private func digit(_ id: Int) -> Int {
        let key = "shortcutDigit-\(id)"
        return UserDefaults.standard.object(forKey: key) == nil
            ? actions.first(where: { $0.id == id })!.digit : UserDefaults.standard.integer(forKey: key)
    }

    private func scope(_ id: Int) -> HotkeyScope { HotkeyScope.load(id) }

    /// Runs the action as soon as the hotkey is pressed (no wait for the key to come up).
    /// The gate stays closed until the trigger key is released, so key repeat never runs it twice.
    private func performOnPress(_ id: Int, pid: pid_t?) {
        guard let pid, let binding = binding(digit(id)) else { return }
        guard releaseGate.begin(id: id, pid: pid) else { return }
        pendingRelease?.invalidate()
        let enabled = !paused && !UserDefaults.standard.bool(forKey: "shortcutsDisabled") && actionEnabled(id)
            && scope(id).allowsAction(paletteVisible: paletteVisible())
        guard enabled, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { releaseGate.cancel(); return }
        // Paste uses a private event source with explicit Command-only flags, so held modifiers do not leak into it.
        perform(id)
        let key = CGKeyCode(binding.actual.key)
        let started = Date()
        let timer = Timer(timeInterval: 0.02, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            // Reopen the gate once the trigger key is up (or after 10 s if the key state is never reported).
            if !CGEventSource.keyState(.combinedSessionState, key: key) || Date().timeIntervalSince(started) > 10 {
                timer.invalidate(); self.pendingRelease = nil; self.releaseGate.cancel()
            }
        }
        pendingRelease = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func register() {
        pendingRelease?.invalidate(); pendingRelease = nil
        releaseGate.cancel()
        references.forEach { UnregisterEventHotKey($0) }
        references.removeAll()
        failures.removeAll()
        blockedState = hotkeysBlocked()
        visibleState = paletteVisible()
        if let handlerFailure {
            actions.forEach { failures[$0.id] = handlerFailure }
        } else if !paused && !UserDefaults.standard.bool(forKey: "shortcutsDisabled") {
            var used = Set<String>()
            for action in actions {
                guard actionEnabled(action.id) else { continue }
                let value = digit(action.id)
                guard let binding = binding(value) else { continue }
                let actual = binding.actual
                guard used.insert("\(actual.key):\(actual.modifiers)").inserted else { failures[action.id] = OSStatus(eventHotKeyExistsErr); continue }
                var ref: EventHotKeyRef?
                let status = RegisterEventHotKey(actual.key, actual.modifiers,
                                                EventHotKeyID(signature: 0x4D454454, id: UInt32(action.id)),
                                                GetApplicationEventTarget(), 0, &ref)
                guard status == noErr, let ref else { failures[action.id] = status; continue }
                // Every binding is probed so conflicts show even while hidden or blocked;
                // keys outside their scope are released at once and reach the front app.
                if scope(action.id).shouldRegister(paletteVisible: visibleState, blocked: blockedState) { references.append(ref) }
                else { UnregisterEventHotKey(ref) }
            }
        }
        rebuildMenu()
        refreshPreferences()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let enabled = menu.addItem(withTitle: L("hotkey.enable"), action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.target = self
        enabled.state = UserDefaults.standard.bool(forKey: "shortcutsDisabled") ? .off : .on
        let pause = menu.addItem(withTitle: L("hotkey.pause"), action: #selector(togglePause), keyEquivalent: "")
        pause.target = self; pause.state = paused ? .on : .off
        menu.addItem(.separator())
        for action in actions {
            let value = digit(action.id)
            let label = label(value)
            let error = failures[action.id].map { L("hotkey.menuFailure", String($0)) } ?? ""
            let actionScope = scope(action.id)
            let suffix = actionScope == .palette && binding(value) != nil ? L("hotkey.scopeSuffix", actionScope.title) : ""
            let root = menu.addItem(withTitle: L("fmt.labelValue", action.title, label) + suffix + error, action: nil, keyEquivalent: "")
            let options = NSMenu(title: action.title)
            for choice in [-1] + Array(keyCodes.indices) {
                let item = options.addItem(withTitle: self.label(choice), action: #selector(choose(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = [action.id, choice]
                item.state = value == choice ? .on : .off
                item.isEnabled = choice < 0 || !actions.contains { $0.id != action.id && binding(digit($0.id))?.actual == binding(choice)?.actual }
            }
            options.addItem(.separator())
            for choice in HotkeyScope.allCases {
                let item = options.addItem(withTitle: L("hotkey.scopeItem", choice.title), action: #selector(chooseScope(_:)), keyEquivalent: "")
                item.target = self; item.tag = action.id; item.representedObject = choice.rawValue
                item.state = actionScope == choice ? .on : .off
            }
            options.autoenablesItems = false
            root.submenu = options
        }
        menu.addItem(.separator())
        let reset = menu.addItem(withTitle: L("hotkey.reset"), action: #selector(reset), keyEquivalent: "")
        reset.target = self
        if !failures.isEmpty {
            let note = menu.addItem(withTitle: L("hotkey.failureNote"), action: nil, keyEquivalent: "")
            note.isEnabled = false
        }
    }

    func showPreferences() {
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = L("settings.window")
            window.isReleasedWhenClosed = false
            window.contentMinSize = NSSize(width: 760, height: 620)
            let scroll = NSScrollView(frame: window.contentView!.bounds)
            scroll.autoresizingMask = [.width, .height]
            scroll.hasVerticalScroller = true
            window.contentView!.addSubview(scroll)
            let document = PreferencesDocumentView()
            document.translatesAutoresizingMaskIntoConstraints = false
            scroll.documentView = document
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
            let column = NSStackView()
            column.orientation = .vertical
            column.alignment = .leading
            column.spacing = 12
            column.translatesAutoresizingMaskIntoConstraints = false
            document.addSubview(column)
            let heading = NSTextField(labelWithString: L("menu.hotkeys"))
            heading.font = .boldSystemFont(ofSize: 18)
            column.addArrangedSubview(heading)
            let enabled = NSButton(checkboxWithTitle: L("hotkey.enable"), target: self, action: #selector(toggleEnabled))
            column.addArrangedSubview(enabled)
            enabledCheckbox = enabled
            let pause = NSButton(checkboxWithTitle: L("hotkey.pauseUntilRelaunch"), target: self, action: #selector(togglePause))
            column.addArrangedSubview(pause)
            pauseCheckbox = pause
            let note = NSTextField(wrappingLabelWithString: L("hotkey.note"))
            column.addArrangedSubview(note)
            note.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
            let resetButton = NSButton(title: L("hotkey.reset"), target: self, action: #selector(reset))
            resetButton.bezelStyle = .rounded
            column.addArrangedSubview(resetButton)
            var groupedIDs = [("パレット操作", [10000])]
            for (name, operations) in PaletteConfiguration.groups {
                var ids = operations.map(\.rawValue)
                if name == "リスト" { ids += ([TextTransform.bracketNumber, .bracketAlphabet] + TextTransform.specialLists).map(\.rawValue) }
                if name == "文字の整形" { ids.append(TextTransform.specialTypography.rawValue) }
                if name == "日付" { ids.append(TextTransform.toggleDateFormat.rawValue) }
                groupedIDs.append((name, ids))
            }
            let knownIDs = Set(groupedIDs.flatMap { $0.1 })
            let remaining = actions.filter { !knownIDs.contains($0.id) }.map(\.id)
            if !remaining.isEmpty { groupedIDs.append(("追加の操作", remaining)) }
            for (category, ids) in groupedIDs {
                let categoryActions = ids.compactMap { id in actions.first { $0.id == id } }
                guard !categoryActions.isEmpty else { continue }
                var items: [NSView] = []
                for action in categoryActions {
                let row = NSStackView()
                row.orientation = .horizontal
                row.spacing = 12
                let label = NSTextField(wrappingLabelWithString: action.title)
                // Scope sits under the name so the row keeps its width.
                let scopeMenu = NSPopUpButton()
                scopeMenu.controlSize = .small; scopeMenu.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
                scopeMenu.addItems(withTitles: HotkeyScope.allCases.map(\.title))
                scopeMenu.tag = action.id; scopeMenu.target = self; scopeMenu.action = #selector(changeScope(_:))
                scopeMenu.setAccessibilityLabel(L("hotkey.axScope", action.title))
                scopeMenu.toolTip = L("hotkey.scopeTip")
                let nameColumn = NSStackView(views: [label, scopeMenu])
                nameColumn.orientation = .vertical; nameColumn.alignment = .leading; nameColumn.spacing = 4
                nameColumn.widthAnchor.constraint(equalToConstant: 220).isActive = true
                label.widthAnchor.constraint(equalTo: nameColumn.widthAnchor).isActive = true
                row.alignment = .top
                row.addArrangedSubview(nameColumn)
                let editor = HotkeyEditor(title: action.title, binding: binding(digit(action.id))) { [weak self] selection in
                    guard let self else { return false }
                    if let selection, self.actions.contains(where: { $0.id != action.id && self.binding(self.digit($0.id))?.actual == selection.actual }) { return false }
                    UserDefaults.standard.set(selection?.encoded ?? -1, forKey: "shortcutDigit-\(action.id)")
                    self.register()
                    return true
                }
                row.addArrangedSubview(editor)
                items.append(row)
                let error = NSTextField(wrappingLabelWithString: "")
                error.textColor = .secondaryLabelColor
                error.font = .systemFont(ofSize: 11)
                items.append(error)
                preferenceRows.append((action.id, editor, scopeMenu, error))
                }
                let group = MainActor.assumeIsolated { SettingsUI.group(PaletteConfiguration.displayName(for: category), items) }
                column.addArrangedSubview(group)
                group.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
            }
            NSLayoutConstraint.activate([
                column.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
                column.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
                column.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
                column.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24)
            ])
            let tabs = RememberedTabView(frame: window.contentView!.bounds.insetBy(dx: 10, dy: 10))
            tabs.autoresizingMask = [.width, .height]
            let shortcutTab = NSTabViewItem(identifier: "shortcuts")
            shortcutTab.label = L("menu.hotkeys")
            scroll.removeFromSuperview()
            shortcutTab.view = scroll
            tabs.addTabViewItem(shortcutTab)
            for (label, view) in additionalPreferenceTabs {
                let tab = NSTabViewItem(identifier: label)
                tab.label = label
                tab.view = view
                if label == SettingsUI.launchTitle { tabs.insertTabViewItem(tab, at: 0) }
                else { tabs.addTabViewItem(tab) }
            }
            tabs.restoreSelection()
            window.contentView!.addSubview(tabs)
            window.center()
            window.setFrameAutosaveName("ShortcutPreferencesPosition")
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
            preferences = window
        }
        refreshPreferences()
        NSApp.activate(ignoringOtherApps: true)
        preferences?.makeKeyAndOrderFront(nil)
    }

    private func refreshPreferences() {
        enabledCheckbox?.state = UserDefaults.standard.bool(forKey: "shortcutsDisabled") ? .off : .on
        pauseCheckbox?.state = paused ? .on : .off
        for row in preferenceRows {
            row.editor.load(binding(digit(row.id)))
            row.scope.selectItem(at: HotkeyScope.allCases.firstIndex(of: scope(row.id)) ?? 0)
            row.error.stringValue = failures[row.id].map { L("hotkey.rowFailure", String($0)) } ?? ""
            row.error.isHidden = failures[row.id] == nil
        }
    }

    @objc private func choose(_ item: NSMenuItem) {
        guard let pair = item.representedObject as? [Int], pair.count == 2 else { return }
        UserDefaults.standard.set(pair[1], forKey: "shortcutDigit-\(pair[0])")
        register()
    }
    @objc private func changeScope(_ sender: NSPopUpButton) {
        HotkeyScope.save(HotkeyScope.allCases[max(0, sender.indexOfSelectedItem)], id: sender.tag)
        register()
    }
    @objc private func chooseScope(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let scope = HotkeyScope(rawValue: raw) else { return }
        HotkeyScope.save(scope, id: item.tag)
        register()
    }
    @objc private func toggleEnabled() {
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: "shortcutsDisabled"), forKey: "shortcutsDisabled")
        register()
    }
    @objc private func togglePause() { paused.toggle(); register() }
    @objc private func reset() {
        actions.forEach { UserDefaults.standard.removeObject(forKey: "shortcutDigit-\($0.id)"); UserDefaults.standard.removeObject(forKey: HotkeyScope.key($0.id)) }
        register()
    }
}

private final class PreferencesDocumentView: NSView {
    override var isFlipped: Bool { true }
}
