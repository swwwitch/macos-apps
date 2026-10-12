import AppKit
import Carbon

/// Global palette key registered with Carbon (like MightyEdit's PaletteShortcut). An event tap never sees some
/// ⌃⌥⌘ combinations, while a registered hot key is delivered before other apps.
final class PaletteHotkey {
    private var handler: EventHandlerRef?
    private var reference: EventHotKeyRef?
    private let action: () -> Void
    private(set) var lastStatus: OSStatus = noErr

    init(action: @escaping () -> Void) {
        self.action = action
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                  id.signature == 0x43445050 else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<PaletteHotkey>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { owner.action() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }

    /// Registers `shortcut`, replacing the previous key. Returns false when the system refuses it (e.g. already taken).
    @discardableResult
    func register(_ shortcut: Shortcut) -> Bool {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
        guard shortcut.keyCode != UInt16.max else { lastStatus = noErr; return true }
        lastStatus = RegisterEventHotKey(UInt32(shortcut.keyCode), shortcut.carbonModifiers, EventHotKeyID(signature: 0x43445050, id: 1),
                                         GetApplicationEventTarget(), 0, &reference)
        return lastStatus == noErr
    }
}

extension Shortcut {
    /// Carbon modifier bits (cmdKey etc.) for RegisterEventHotKey and HotkeyManifest; fn has no Carbon bit.
    var carbonModifiers: UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        return value
    }
}
