import AppKit
import Carbon

/// A key combination in Carbon terms (KakkoReplace's Shortcut, reduced to what this app needs).
struct Shortcut: Codable, Equatable {
    var code: UInt32
    var modifiers: UInt32
    var label: String
    /// ⌃⌥V — the KM macro's trigger (KeyCode 9, KM modifiers 6144 = ⌃4096 + ⌥2048).
    static let paste = Shortcut(code: 9, modifiers: UInt32(controlKey | optionKey), label: "⌃⌥V")
    /// ⌃⌥⌘C — copy the selection and add its lines to the list. Key code 8 = C.
    /// Not ⌥C: it types "ç" and LinkMaker already uses it.
    static let add = Shortcut(code: 8, modifiers: UInt32(controlKey | optionKey | cmdKey), label: "⌃⌥⌘C")
    /// The default of 1.3.0, replaced on launch unless the user chose it again.
    static let oldAdd = Shortcut(code: 8, modifiers: UInt32(optionKey), label: "⌥C")
    var signature: String { "\(code):\(modifiers)" }

    /// Keys that the recorder refuses: no ⌘/⌥/⌃, or a standard ⌘ editing/window/quit key (⌘A ⌘Z ⌘X ⌘C ⌘V ⌘Q ⌘W ⌘,).
    static let standardCommandKeys: Set<UInt16> = [0, 6, 7, 8, 9, 12, 13, 43]
    static func recorded(keyCode: UInt16, flags: NSEvent.ModifierFlags, characters: String?) -> Shortcut? {
        let flags = flags.intersection([.command, .option, .control, .shift])
        guard !flags.intersection([.command, .option, .control]).isEmpty,
              !(flags == .command && standardCommandKeys.contains(keyCode)),
              let key = characters, !key.isEmpty else { return nil }
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        let prefix = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "") + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "")
        return Shortcut(code: UInt32(keyCode), modifiers: mods, label: prefix + key.uppercased())
    }
}

/// One Carbon hotkey. `register(nil)` releases the key to the front app.
final class SingleHotKey {
    var action: (() -> Void)?
    private let signature: OSType
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var handlerStatus: OSStatus = noErr
    init(signature: OSType) {
        self.signature = signature
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<SingleHotKey>.fromOpaque(context).takeUnretainedValue()
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                  id.signature == owner.signature else { return OSStatus(eventNotHandledErr) }
            owner.action?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    var isRegistered: Bool { reference != nil }
    @discardableResult
    func register(_ shortcut: Shortcut?) -> OSStatus {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
        guard let shortcut else { return noErr }
        guard handlerStatus == noErr else { return handlerStatus }
        return RegisterEventHotKey(shortcut.code, shortcut.modifiers, EventHotKeyID(signature: signature, id: 1), GetApplicationEventTarget(), 0, &reference)
    }
    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}
