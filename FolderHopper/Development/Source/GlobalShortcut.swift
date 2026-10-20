import AppKit
import Carbon

final class GlobalShortcut {
    static let modifiers: [(String, UInt32)] = [
        ("⌃⌥⌘", UInt32(controlKey | optionKey | cmdKey)),
        ("⌃⌥", UInt32(controlKey | optionKey)),
        ("⌥⌘", UInt32(optionKey | cmdKey)),
        ("⌃⌘", UInt32(controlKey | cmdKey))
    ]
    static let keys: [(String, UInt32)] = [
        ("A",0),("B",11),("C",8),("D",2),("E",14),("F",3),("G",5),
        ("H",4),("I",34),("J",38),("K",40),("L",37),("M",46),("N",45),
        ("O",31),("P",35),("Q",12),("R",15),("S",1),("T",17),("U",32),
        ("V",9),("W",13),("X",7),("Y",16),("Z",6),("Space",49)
    ]
    /// Individual modifiers of the copy-to-/Applications hotkey (ID 2), combined freely; the default is all four (⌃⌥⌘⇧A).
    static let modifierFlags: [(String, UInt32)] = [
        ("⌃", UInt32(controlKey)), ("⌥", UInt32(optionKey)), ("⌘", UInt32(cmdKey)), ("⇧", UInt32(shiftKey))
    ]
    static let applicationsDefaultModifiers = UInt32(controlKey | optionKey | cmdKey | shiftKey)
    /// ⇧ alone (or nothing) would take over ordinary typing, so one of ⌃⌥⌘ is required.
    static let requiredModifiers = UInt32(controlKey | optionKey | cmdKey)
    /// Window hotkey default: ⌃⌥⌘F since 0.1.100 (⌃⌥⌘M before, now LinkMaker's palette; popup indices 0 / 12 until 0.1.96).
    static let windowDefault = (code: UInt32(3), modifiers: UInt32(controlKey | optionKey | cmdKey))
    static let previousWindowDefault = (code: UInt32(46), modifiers: UInt32(controlKey | optionKey | cmdKey))
    static let applicationsDefault = (code: UInt32(0), modifiers: applicationsDefaultModifiers)
    /// Saved form since 0.1.97: ["code": key code, "modifiers": Carbon modifiers] under shortcutCombo / applicationsShortcutCombo.
    static func stored(_ value: Any?) -> (code: UInt32, modifiers: UInt32)? {
        guard let dictionary = value as? [String: Any], let code = (dictionary["code"] as? NSNumber)?.uint32Value,
              let modifiers = (dictionary["modifiers"] as? NSNumber)?.uint32Value, modifiers & requiredModifiers != 0 else { return nil }
        return (code, modifiers)
    }
    static func storable(code: UInt32, modifiers: UInt32) -> [String: Int] { ["code": Int(code), "modifiers": Int(modifiers)] }
    /// Until 0.1.96 the window hotkey was saved as popup indices into `modifiers` and `keys`.
    static func legacyWindow(modifierIndex: Int, keyIndex: Int) -> (code: UInt32, modifiers: UInt32) {
        (keys.indices.contains(keyIndex) ? keys[keyIndex].1 : windowDefault.code,
         modifiers.indices.contains(modifierIndex) ? modifiers[modifierIndex].1 : windowDefault.modifiers)
    }
    /// Until 0.1.96 the copy-to-Applications hotkey was saved as a modifier mask and a popup index into `keys`.
    static func legacyApplications(modifiers mask: Int, keyIndex: Int) -> (code: UInt32, modifiers: UInt32) {
        let all = modifierFlags.reduce(UInt32(0)) { $0 | $1.1 }
        let modifiers = UInt32(truncatingIfNeeded: mask) & all
        return (keys.indices.contains(keyIndex) ? keys[keyIndex].1 : applicationsDefault.code,
                modifiers & requiredModifiers != 0 ? modifiers : applicationsDefaultModifiers)
    }
    /// One-time move to the new keys; the old keys are left as they are.
    static func migrate(_ defaults: UserDefaults) {
        if defaults.object(forKey: "shortcutCombo") == nil {
            let old = legacyWindow(modifierIndex: (defaults.object(forKey: "shortcutModifierIndex") as? Int) ?? 0,
                                   keyIndex: (defaults.object(forKey: "shortcutKeyIndex") as? Int) ?? 5)
            defaults.set(storable(code: old.code, modifiers: old.modifiers), forKey: "shortcutCombo")
        }
        // 0.1.100: a window hotkey still on the old default ⌃⌥⌘M moves to ⌃⌥⌘F, once; a later ⌃⌥⌘M stays.
        if !defaults.bool(forKey: "windowDefaultF20261017") {
            if let saved = stored(defaults.object(forKey: "shortcutCombo")), saved == previousWindowDefault {
                defaults.set(storable(code: windowDefault.code, modifiers: windowDefault.modifiers), forKey: "shortcutCombo")
            }
            defaults.set(true, forKey: "windowDefaultF20261017")
        }
        if defaults.object(forKey: "applicationsShortcutCombo") == nil {
            let old = legacyApplications(modifiers: (defaults.object(forKey: "applicationsShortcutModifiers") as? Int) ?? Int(applicationsDefaultModifiers),
                                         keyIndex: (defaults.object(forKey: "applicationsShortcutKeyIndex") as? Int) ?? 0)
            defaults.set(storable(code: old.code, modifiers: old.modifiers), forKey: "applicationsShortcutCombo")
        }
    }
    /// While the settings field records a key, every hotkey is released so the keystroke reaches the field.
    var suspended = false {
        didSet {
            guard suspended != oldValue else { return }
            if suspended {
                for reference in references.values { UnregisterEventHotKey(reference) }
                references.removeAll()
            } else { refresh() }
        }
    }
    /// Hotkey ID 1 shows the window; other IDs run app functions (e.g. 2 = copy to Applications).
    var actions: [UInt32: () -> Void] = [:]
    var action: (() -> Void)? {
        get { actions[1] }
        set { actions[1] = newValue }
    }
    /// Hotkeys are registered only while one of these apps is frontmost; elsewhere the keys pass through. Empty = always.
    var activeApps: Set<String> = []
    private var references: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var wanted: [UInt32: (UInt32, UInt32)] = [:]
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, id.signature == 0x464D4F56 else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
            guard let action = owner.actions[id.id] else { return OSStatus(eventNotHandledErr) }
            action()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    // Register the replacement first so a conflict leaves the previous shortcut working.
    // The key is registered even outside `activeApps` to report conflicts, then released by `refresh`.
    func configure(id: UInt32 = 1, enabled: Bool, key: UInt32, modifiers: UInt32) -> Bool {
        guard handler != nil else { return false }
        if suspended { wanted[id] = enabled ? (key, modifiers) : nil; return true }
        if enabled, let existing = wanted[id], existing == (key, modifiers) { refresh(); return true }
        var replacement: EventHotKeyRef?
        if enabled {
            let result = RegisterEventHotKey(key, modifiers, EventHotKeyID(signature: 0x464D4F56, id: id), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &replacement)
            guard result == noErr else { return false }
        }
        if let reference = references[id] { UnregisterEventHotKey(reference) }
        references[id] = replacement
        wanted[id] = enabled ? (key, modifiers) : nil
        refresh()
        return true
    }
    /// Call when the frontmost app changes: registers the wanted keys over `activeApps`, releases them elsewhere.
    func refresh(frontmost: String? = NSWorkspace.shared.frontmostApplication?.bundleIdentifier) {
        let active = !suspended && (activeApps.isEmpty || activeApps.contains(frontmost ?? ""))
        for (id, shortcut) in wanted {
            if active, references[id] == nil {
                var reference: EventHotKeyRef?
                if RegisterEventHotKey(shortcut.0, shortcut.1, EventHotKeyID(signature: 0x464D4F56, id: id), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &reference) == noErr {
                    references[id] = reference
                }
            } else if !active, let reference = references[id] {
                UnregisterEventHotKey(reference)
                references[id] = nil
            }
        }
    }
    deinit {
        for reference in references.values { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}
