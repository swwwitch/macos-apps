import AppKit
import Carbon

/// A key combination in Carbon terms (SpreadsheetHelper's Shortcut).
struct Shortcut: Codable, Equatable, Hashable {
    var code: UInt32
    var modifiers: UInt32
    var label: String
    var signature: String { "\(code):\(modifiers)" }

    static let command = UInt32(cmdKey), shift = UInt32(shiftKey), option = UInt32(optionKey), control = UInt32(controlKey)

    /// Keyboard Maestro modifiers (⌘256 ⇧512 ⌥2048 ⌃4096) are the same bits as Carbon's.
    static func km(_ code: UInt32, _ modifiers: UInt32, _ key: String) -> Shortcut {
        Shortcut(code: code, modifiers: modifiers, label: prefix(modifiers) + key)
    }
    static func prefix(_ m: UInt32) -> String {
        (m & control != 0 ? "⌃" : "") + (m & option != 0 ? "⌥" : "") + (m & shift != 0 ? "⇧" : "") + (m & command != 0 ? "⌘" : "")
    }

    var cgFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers & Shortcut.command != 0 { flags.insert(.maskCommand) }
        if modifiers & Shortcut.option != 0 { flags.insert(.maskAlternate) }
        if modifiers & Shortcut.control != 0 { flags.insert(.maskControl) }
        if modifiers & Shortcut.shift != 0 { flags.insert(.maskShift) }
        return flags
    }
}

/// Several Carbon hotkeys sharing one handler; each is identified by a small number.
final class HotKeySet {
    var action: ((UInt32) -> Void)?
    private let signature: OSType
    private var references: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var handlerStatus: OSStatus = noErr
    init(signature: OSType) {
        self.signature = signature
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<HotKeySet>.fromOpaque(context).takeUnretainedValue()
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                  id.signature == owner.signature else { return OSStatus(eventNotHandledErr) }
            let number = id.id
            DispatchQueue.main.async { owner.action?(number) }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    var registered: Set<UInt32> { Set(references.keys) }
    @discardableResult
    func register(_ number: UInt32, _ shortcut: Shortcut) -> OSStatus {
        unregister(number)
        guard handlerStatus == noErr else { return handlerStatus }
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.code, shortcut.modifiers, EventHotKeyID(signature: signature, id: number), GetApplicationEventTarget(), 0, &reference)
        if status == noErr, let reference { references[number] = reference }
        return status
    }
    func unregister(_ number: UInt32) {
        if let reference = references.removeValue(forKey: number) { UnregisterEventHotKey(reference) }
    }
    func unregisterAll() { for number in Array(references.keys) { unregister(number) } }
    deinit {
        unregisterAll()
        if let handler { RemoveEventHandler(handler) }
    }
}
