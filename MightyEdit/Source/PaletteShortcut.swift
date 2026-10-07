import AppKit
import Carbon

/// Palette invocation is independent of text-transform hotkeys and needs no AX access.
final class PaletteShortcut: NSObject {
    private var handler: EventHandlerRef?
    private var reference: EventHotKeyRef?
    private let show: (pid_t?) -> Void
    private var invocationPID: pid_t?
    private let enabled = NSButton(checkboxWithTitle: L("palette.enableShortcut"), target: nil, action: nil)
    private let modifiers = NSPopUpButton()
    private let key = NSPopUpButton()
    private let status = NSTextField(wrappingLabelWithString: "")
    private var editor: HotkeyEditor?
    private let prefix = "paletteInvocation."
    /// True while the front app is excluded or MightyEdit itself (B21): keys pass through.
    var hotkeysBlocked: () -> Bool = { false }
    private var blockedState = false
    func refreshForFrontApp() { if hotkeysBlocked() != blockedState { register() } }
    private let keys: [(String, UInt32)] = [("A",0),("B",11),("C",8),("D",2),("E",14),("F",3),("G",5),("H",4),("I",34),("J",38),("K",40),("L",37),("M",46),("N",45),("O",31),("P",35),("Q",12),("R",15),("S",1),("T",17),("U",32),("V",9),("W",13),("X",7),("Y",16),("Z",6)]
    // Saved by index; the label is joined with the localized plus sign (Japanese keeps ＋).
    private let combinations: [(String, UInt32)] = [
        (["⌘", "Option", "Shift"], UInt32(cmdKey | optionKey | shiftKey)),
        (["Control", "Option", "⌘"], UInt32(controlKey | optionKey | cmdKey)),
        (["Control", "Option", "Shift"], UInt32(controlKey | optionKey | shiftKey)),
        (["Control", "Option"], UInt32(controlKey | optionKey)),
        (["⌘", "Option"], UInt32(cmdKey | optionKey)),
        (["Control", "Shift"], UInt32(controlKey | shiftKey))
    ].map { ($0.0.joined(separator: L("hotkey.plus")), $0.1) }
    init(show: @escaping (pid_t?) -> Void) {
        self.show = show
        super.init()
        modifiers.addItems(withTitles: combinations.map { $0.0 })
        key.addItems(withTitles: keys.map { $0.0 })
        modifiers.setAccessibilityLabel(L("palette.axModifiers"))
        key.setAccessibilityLabel(L("palette.axKey"))
        let defaults = UserDefaults.standard
        enabled.state = defaults.object(forKey: prefix + "enabled") == nil || defaults.bool(forKey: prefix + "enabled") ? .on : .off
        // Migrate only the legacy default; explicit editor bindings and disabled state survive.
        if !defaults.bool(forKey: prefix + "defaultControlU20261007") {
            if defaults.object(forKey: prefix + "binding") == nil,
               defaults.integer(forKey: prefix + "modifiers") == 0,
               (defaults.string(forKey: prefix + "key") ?? "U") == "U" {
                defaults.set(1, forKey: prefix + "modifiers")
            }
            defaults.set(true, forKey: prefix + "defaultControlU20261007")
        }
        let combination = (defaults.object(forKey: prefix + "modifiers") as? Int) ?? 1
        modifiers.selectItem(at: combinations.indices.contains(combination) ? combination : 1)
        key.selectItem(withTitle: defaults.string(forKey: prefix + "key") ?? "U")
        if key.indexOfSelectedItem < 0 { key.selectItem(withTitle: "U") }
        for control in [enabled as NSControl, modifiers, key] { control.target = self; control.action = #selector(changed) }
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                  id.signature == 0x4D45504C else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<PaletteShortcut>.fromOpaque(context).takeUnretainedValue()
            if GetEventKind(event) == UInt32(kEventHotKeyPressed) {
                owner.invocationPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            } else {
                let captured = owner.invocationPID
                owner.invocationPID = nil
                let current = NSWorkspace.shared.frontmostApplication?.processIdentifier
                // Do not apply a held invocation to an app the user switched away from.
                if let captured, let current, captured != current,
                   current != ProcessInfo.processInfo.processIdentifier,
                   captured != ProcessInfo.processInfo.processIdentifier { return noErr }
                owner.show(captured)
            }
            return noErr
        }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &handler)
        if result == noErr { register() }
        else { status.stringValue = L("palette.initFailed", String(result)) }
    }
    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
    @MainActor func settingsView() -> NSView {
        let heading = NSTextField(labelWithString: SettingsUI.launchTitle)
        heading.font = .boldSystemFont(ofSize: 18)
        let label = NSTextField(labelWithString: L("palette.bringToFront"))
        let editor = HotkeyEditor(title: L("palette.shortcutTitle"), binding: currentBinding) { [weak self] binding in
            guard let self else { return false }
            self.enabled.state = binding == nil ? .off : .on
            UserDefaults.standard.set(binding?.encoded ?? -1, forKey: self.prefix + "binding")
            self.changed()
            return true
        }
        self.editor = editor
        let row = NSStackView(views: [editor]); row.spacing = 8
        let note = NSTextField(wrappingLabelWithString: L("palette.shortcutNote"))
        let reset = NSButton(title: L("palette.resetShortcut"), target: self, action: #selector(resetDefault))
        reset.bezelStyle = .rounded
        let login = LoginAtLaunchControl()
        let resident = NSButton(checkboxWithTitle: L("palette.resident"), target: self, action: #selector(changeResident(_:)))
        resident.state = UserDefaults.standard.object(forKey: "paletteResident") == nil || UserDefaults.standard.bool(forKey: "paletteResident") ? .on : .off
        let residentNote = NSTextField(wrappingLabelWithString: L("palette.residentNote"))
        residentNote.font = .systemFont(ofSize: 11); residentNote.textColor = .secondaryLabelColor
        let group = SettingsUI.group(SettingsUI.launchTitle, [login, resident, residentNote, MenuBarPresence.shared.settingsControl(), enabled, label, row, status, reset, note])
        let permission = AccessibilityPermissionControl(required: true)
        let stack = NSStackView(views: [group, permission])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = PaletteSettingsDocumentView(); container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            group.widthAnchor.constraint(equalTo: stack.widthAnchor),
            permission.widthAnchor.constraint(equalTo: stack.widthAnchor),
            permission.heightAnchor.constraint(equalToConstant: 180),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24)
        ])
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        scroll.documentView = container
        container.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        return scroll
    }
    @objc private func changeResident(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "paletteResident")
    }
    @objc private func changed() {
        let defaults = UserDefaults.standard
        defaults.set(enabled.state == .on, forKey: prefix + "enabled")
        defaults.set(modifiers.indexOfSelectedItem, forKey: prefix + "modifiers")
        defaults.set(key.titleOfSelectedItem, forKey: prefix + "key")
        register()
    }
    private var currentBinding: HotkeyBinding? {
        if let saved = UserDefaults.standard.object(forKey: prefix + "binding") as? Int { return HotkeyBinding.decode(saved) }
        return HotkeyBinding(key: keys[key.indexOfSelectedItem].1, modifiers: combinations[modifiers.indexOfSelectedItem].1)
    }
    @objc private func resetDefault() {
        UserDefaults.standard.removeObject(forKey: prefix + "binding")
        enabled.state = .on; modifiers.selectItem(at: 1); key.selectItem(withTitle: "U"); changed(); editor?.load(currentBinding)
    }
    private func register() {
        if let reference { UnregisterEventHotKey(reference) }; reference = nil
        blockedState = hotkeysBlocked()
        guard enabled.state == .on else { status.stringValue = L("status.disabled"); return }
        guard handler != nil else { status.stringValue = L("palette.notInitialized"); return }
        guard let binding = currentBinding else { status.stringValue = L("status.disabled"); return }
        let actual = binding.actual
        let result = RegisterEventHotKey(actual.key, actual.modifiers,
                                        EventHotKeyID(signature: 0x4D45504C, id: 1), GetApplicationEventTarget(), 0, &reference)
        status.stringValue = result == noErr ? L("palette.enabledStatus", binding.label) : L("palette.registerFailed", String(result))
        status.textColor = result == noErr ? .secondaryLabelColor : .systemRed
        // Conflicts are checked above; while blocked the key goes to the front app.
        if blockedState, let registered = reference { UnregisterEventHotKey(registered); reference = nil }
    }
}

private final class PaletteSettingsDocumentView: NSView { override var isFlipped: Bool { true } }
