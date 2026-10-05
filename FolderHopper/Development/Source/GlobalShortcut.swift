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
    var action: (() -> Void)?
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var current: (UInt32, UInt32)?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, id.signature == 0x464D4F56 else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
            owner.action?()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    // Register the replacement first so a conflict leaves the previous shortcut working.
    func configure(enabled: Bool, key: UInt32, modifiers: UInt32) -> Bool {
        guard handler != nil else { return false }
        if enabled, let current, current.0 == key, current.1 == modifiers { return true }
        var replacement: EventHotKeyRef?
        if enabled {
            let result = RegisterEventHotKey(key, modifiers, EventHotKeyID(signature: 0x464D4F56, id: 1), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &replacement)
            guard result == noErr else { return false }
        }
        if let reference { UnregisterEventHotKey(reference) }
        reference = replacement
        current = enabled ? (key, modifiers) : nil
        return true
    }
    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}
