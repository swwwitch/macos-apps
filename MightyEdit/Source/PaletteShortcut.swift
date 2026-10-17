import AppKit
import Carbon

/// Palette invocation is independent of text-transform hotkeys and needs no AX access.
final class PaletteShortcut: NSObject {
    private var handler: EventHandlerRef?
    private var reference: EventHotKeyRef?
    private let show: (pid_t?) -> Void
    private var invocationPID: pid_t?
    private let enabled = NSButton(checkboxWithTitle: HotkeyText.enable, target: nil, action: nil)
    /// False when the key could not be registered; the settings field shows the shared message.
    private var registered = true
    private var recording = false
    /// The action keys (GlobalShortcuts), offered to the field so the same key is not assigned twice.
    var actionCombos: () -> [(String, KeyCombo)] = { [] }
    private let prefix = "paletteInvocation."
    /// True while the front app is excluded or MightyEdit itself (B21): keys pass through.
    var hotkeysBlocked: () -> Bool = { false }
    private var blockedState = false
    func refreshForFrontApp() { if hotkeysBlocked() != blockedState { register() } else { publishManifest() } }
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
        // 0.2.8: the default moved from ⌃⌥⌘U to ⌃⌥⌘E. Only settings still on the old default move, once.
        if !defaults.bool(forKey: prefix + "defaultControlE20261008") {
            if defaults.object(forKey: prefix + "binding") == nil,
               ((defaults.object(forKey: prefix + "modifiers") as? Int) ?? 1) == 1,
               (defaults.string(forKey: prefix + "key") ?? "U") == "U" {
                defaults.set(1, forKey: prefix + "modifiers"); defaults.set("E", forKey: prefix + "key")
            }
            defaults.set(true, forKey: prefix + "defaultControlE20261008")
        }
        enabled.target = self; enabled.action = #selector(changed)
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
        if result == noErr { register() } else { registered = false }
        MainActor.assumeIsolated {
            HotkeyRecorder.shared.onRecordingChanged.append { [weak self] recording in self?.recording = recording; self?.register() }
        }
    }
    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
    @MainActor func settingsView() -> NSView {
        let heading = NSTextField(labelWithString: SettingsUI.launchTitle)
        heading.font = .boldSystemFont(ofSize: 18)
        let label = NSTextField(labelWithString: L("palette.bringToFront"))
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        let field = HotkeyField.control(id: "paletteInvocation",
                                        get: { [weak self] in self?.currentBinding?.combo },
                                        set: { [weak self] combo in
                                            guard let self, let combo else { return }
                                            UserDefaults.standard.set(HotkeyBinding(combo).encoded, forKey: self.prefix + "binding")
                                            self.register()
                                        },
                                        defaultCombo: Self.defaultBinding.combo,
                                        others: { [weak self] in self?.actionCombos() ?? [] },
                                        registered: { [weak self] in self?.registered ?? true },
                                        isEnabled: { [weak self] in self?.enabled.state == .on })
        let note = NSTextField(wrappingLabelWithString: L("palette.shortcutNote"))
        let login = LoginAtLaunchControl()
        let resident = NSButton(checkboxWithTitle: L("palette.resident"), target: self, action: #selector(changeResident(_:)))
        resident.state = UserDefaults.standard.object(forKey: "paletteResident") == nil || UserDefaults.standard.bool(forKey: "paletteResident") ? .on : .off
        let residentNote = NSTextField(wrappingLabelWithString: L("palette.residentNote"))
        residentNote.font = .systemFont(ofSize: 11); residentNote.textColor = .secondaryLabelColor
        let group = SettingsUI.group(SettingsUI.launchTitle, [login, resident, residentNote, MenuBarPresence.shared.settingsControl(), label, enabled, field, note])
        let permission = AccessibilitySection.group()
        let quit = SettingsUI.quitRestartGroup()
        let stack = NSStackView(views: [group, permission, quit])
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
            quit.widthAnchor.constraint(equalTo: stack.widthAnchor),
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
        register()
    }
    static let defaultBinding = HotkeyBinding(key: 14, modifiers: UInt32(controlKey | optionKey | cmdKey))   // ⌃⌥⌘E
    /// The saved key: paletteInvocation.binding, else the older modifiers index + key title (kept as they were).
    var currentBinding: HotkeyBinding? {
        let defaults = UserDefaults.standard
        if let saved = defaults.object(forKey: prefix + "binding") as? Int { return HotkeyBinding.decode(saved) }
        let combination = (defaults.object(forKey: prefix + "modifiers") as? Int) ?? 1
        let title = defaults.string(forKey: prefix + "key") ?? "E"
        return HotkeyBinding(key: (keys.first { $0.0 == title } ?? ("E", 14)).1,
                             modifiers: combinations[combinations.indices.contains(combination) ? combination : 1].1)
    }
    /// Re-reads the saved binding after settings were imported or synced.
    func reloadFromDefaults() {
        let defaults = UserDefaults.standard
        enabled.state = defaults.object(forKey: prefix + "enabled") == nil || defaults.bool(forKey: prefix + "enabled") ? .on : .off
        register()
    }
    private func register() {
        if let reference { UnregisterEventHotKey(reference) }; reference = nil
        blockedState = hotkeysBlocked()
        publishManifest()
        defer { MainActor.assumeIsolated { HotkeyRecorder.shared.touch() } }
        guard enabled.state == .on, !recording, let binding = currentBinding else { if handler != nil { registered = true }; return }
        guard handler != nil else { registered = false; return }
        let actual = binding.actual
        let result = RegisterEventHotKey(actual.key, actual.modifiers,
                                        EventHotKeyID(signature: 0x4D45504C, id: 1), GetApplicationEventTarget(), 0, &reference)
        registered = result == noErr
        // Conflicts are checked above; while blocked the key goes to the front app.
        if blockedState, let registered = reference { UnregisterEventHotKey(registered); reference = nil }
    }
    /// Declares the palette key for HotkeyHound (enabled = the checkbox, not the registration result).
    private func publishManifest() {
        HotkeyManifestParts.palette = currentBinding.map {
            var item = HotkeyManifestParts.item("palette", L("palette.shortcutTitle"), $0.actual)
            item.enabled = enabled.state == .on
            return [item]
        } ?? []
        HotkeyManifestParts.publish()
    }
}

private final class PaletteSettingsDocumentView: NSView { override var isFlipped: Bool { true } }
