import AppKit
import Carbon

extension Shortcut {
    /// "⌃⌥D" etc. The key name follows the current keyboard layout, so a JIS keyboard shows its own symbols.
    var label: String { modifierSymbols + KeyName.name(for: code) }

    /// Keys the recorder refuses: no ⌘/⌥/⌃, or a standard ⌘ key (⌘A ⌘Z ⌘X ⌘C ⌘V ⌘Q ⌘W ⌘, ⌘Tab ⌘Space).
    static let standardCommandKeys: Set<UInt16> = [0, 6, 7, 8, 9, 12, 13, 43, 48, 49]
    static func recorded(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Shortcut? {
        let flags = flags.intersection([.command, .option, .control, .shift])
        guard !flags.intersection([.command, .option, .control]).isEmpty,
              !(flags == .command && standardCommandKeys.contains(keyCode)) else { return nil }
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= Shortcut.command }
        if flags.contains(.shift) { mods |= Shortcut.shift }
        if flags.contains(.option) { mods |= Shortcut.option }
        if flags.contains(.control) { mods |= Shortcut.control }
        return Shortcut(code: UInt32(keyCode), modifiers: mods)
    }
}

enum KeyName {
    static let special: [UInt32: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 117: "⌦", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑", 76: "⌤", 71: "⌧", 102: "英数", 104: "かな",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"
    ]
    static func name(for code: UInt32) -> String {
        if let name = special[code] { return name }
        if let typed = translate(code), !typed.isEmpty { return typed.uppercased() }
        return "#\(code)"
    }
    /// The character the key types without modifiers in the current layout (falls back to an ASCII-capable layout).
    private static func translate(_ code: UInt32) -> String? {
        for source in [TISCopyCurrentKeyboardLayoutInputSource(), TISCopyCurrentASCIICapableKeyboardLayoutInputSource()] {
            guard let source = source?.takeRetainedValue(),
                  let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { continue }
            let layoutData = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
            var deadKeys: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status = layoutData.withUnsafeBytes { raw -> OSStatus in
                guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
                return UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                      OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
            }
            let text = String(utf16CodeUnits: chars, count: length).trimmingCharacters(in: .whitespacesAndNewlines)
            if status == noErr, !text.isEmpty, text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) { return text }
        }
        return nil
    }
}

/// Many Carbon hot keys under one handler. `register` replaces the whole set and reports failures per key.
/// A key with both a single and a double-tap entry is registered once; the tap count is decided after the press.
final class HotKeyCenter {
    var action: ((Shortcut) -> Void)?
    private static let signature: OSType = 0x4150_4C4E  // 'APLN'
    private var references: [EventHotKeyRef] = []
    private var targets: [UInt32: Shortcut] = [:]
    private var handler: EventHandlerRef?
    private var handlerStatus: OSStatus = noErr
    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                  id.signature == HotKeyCenter.signature else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<HotKeyCenter>.fromOpaque(context).takeUnretainedValue()
            if let target = owner.targets[id.id] { owner.action?(target) }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    var registeredCount: Int { references.count }
    @discardableResult
    /// Returns the failures keyed by `Shortcut.signature`.
    func register(_ shortcuts: [Shortcut]) -> [String: OSStatus] {
        references.forEach { UnregisterEventHotKey($0) }
        references.removeAll(); targets.removeAll()
        var failures: [String: OSStatus] = [:]
        var seen = Set<String>()
        for shortcut in shortcuts where seen.insert(shortcut.signature).inserted {
            guard handlerStatus == noErr else { failures[shortcut.signature] = handlerStatus; continue }
            var reference: EventHotKeyRef?
            let number = UInt32(seen.count)
            let status = RegisterEventHotKey(shortcut.code, shortcut.modifiers, EventHotKeyID(signature: Self.signature, id: number), GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference { references.append(reference); targets[number] = shortcut } else { failures[shortcut.signature] = status }
        }
        return failures
    }
    deinit {
        references.forEach { UnregisterEventHotKey($0) }
        if let handler { RemoveEventHandler(handler) }
    }
}

/// The macOS keyboard shortcuts (System Settings > Keyboard > Keyboard Shortcuts), read with Carbon's public
/// CopySymbolicHotKeys. It reflects changes made in System Settings and needs no permission.
enum SystemShortcuts {
    /// Enabled ones, keyed by `Shortcut.signature`.
    static func enabled() -> Set<String> {
        var array: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&array) == noErr, let list = array?.takeRetainedValue() as? [[String: Any]] else { return [] }
        let mask = Shortcut.command | Shortcut.shift | Shortcut.option | Shortcut.control
        return Set(list.compactMap { item -> String? in
            guard (item[kHISymbolicHotKeyEnabled] as? Bool) ?? false,
                  let code = (item[kHISymbolicHotKeyCode] as? NSNumber)?.uint32Value,
                  let modifiers = (item[kHISymbolicHotKeyModifiers] as? NSNumber)?.uint32Value else { return nil }
            return Shortcut(code: code, modifiers: modifiers & mask).signature
        })
    }
    /// Names for the well-known ones (Localizable keys); others are shown as "a macOS shortcut".
    static let names: [String: String] = [
        Shortcut(code: 20, modifiers: Shortcut.command | Shortcut.shift).signature: "sys.screenshot",
        Shortcut(code: 21, modifiers: Shortcut.command | Shortcut.shift).signature: "sys.screenshot",
        Shortcut(code: 23, modifiers: Shortcut.command | Shortcut.shift).signature: "sys.screenshot",
        Shortcut(code: 20, modifiers: Shortcut.command | Shortcut.shift | Shortcut.control).signature: "sys.screenshot",
        Shortcut(code: 21, modifiers: Shortcut.command | Shortcut.shift | Shortcut.control).signature: "sys.screenshot",
        Shortcut(code: 49, modifiers: Shortcut.command).signature: "sys.spotlight",
        Shortcut(code: 49, modifiers: Shortcut.command | Shortcut.option).signature: "sys.finderSearch",
        Shortcut(code: 49, modifiers: Shortcut.control).signature: "sys.inputSource",
        Shortcut(code: 49, modifiers: Shortcut.control | Shortcut.option).signature: "sys.inputSource",
        Shortcut(code: 126, modifiers: Shortcut.control).signature: "sys.missionControl",
        Shortcut(code: 125, modifiers: Shortcut.control).signature: "sys.appWindows",
        Shortcut(code: 123, modifiers: Shortcut.control).signature: "sys.spaces",
        Shortcut(code: 124, modifiers: Shortcut.control).signature: "sys.spaces",
        Shortcut(code: 12, modifiers: Shortcut.command | Shortcut.control).signature: "sys.lockScreen",
    ]
    /// Localizable key of the name (the caller localizes it).
    static func nameKey(for shortcut: Shortcut) -> String { names[shortcut.signature] ?? "sys.generic" }
}
