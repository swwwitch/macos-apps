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
    /// ⌃⌥⌘⇧A: move the Finder/Path Finder selection to /Applications (fixed, hotkey ID 2).
    static let applicationsShortcut = (key: UInt32(0), modifiers: UInt32(controlKey | optionKey | cmdKey | shiftKey))
    /// Hotkey ID 1 shows the window; other IDs run app functions (e.g. 2 = move to Applications).
    var actions: [UInt32: () -> Void] = [:]
    var action: (() -> Void)? {
        get { actions[1] }
        set { actions[1] = newValue }
    }
    private var references: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var current: [UInt32: (UInt32, UInt32)] = [:]
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
    func configure(id: UInt32 = 1, enabled: Bool, key: UInt32, modifiers: UInt32) -> Bool {
        guard handler != nil else { return false }
        if enabled, let existing = current[id], existing.0 == key, existing.1 == modifiers { return true }
        var replacement: EventHotKeyRef?
        if enabled {
            let result = RegisterEventHotKey(key, modifiers, EventHotKeyID(signature: 0x464D4F56, id: id), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &replacement)
            guard result == noErr else { return false }
        }
        if let reference = references[id] { UnregisterEventHotKey(reference) }
        references[id] = replacement
        current[id] = enabled ? (key, modifiers) : nil
        return true
    }
    deinit {
        for reference in references.values { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}
