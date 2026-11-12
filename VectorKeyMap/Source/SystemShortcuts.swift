import Carbon
import Foundation

/// The macOS keyboard shortcuts (System Settings > Keyboard > Keyboard Shortcuts), read with Carbon's public
/// CopySymbolicHotKeys. It reflects changes made in System Settings and needs no permission.
enum SystemShortcuts {
    static func enabledSlots() -> Set<Slot> {
        var array: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&array) == noErr, let list = array?.takeRetainedValue() as? [[String: Any]] else { return [] }
        return Set(list.compactMap { item -> Slot? in
            guard (item[kHISymbolicHotKeyEnabled] as? Bool) ?? false,
                  let code = (item[kHISymbolicHotKeyCode] as? NSNumber)?.intValue,
                  let flags = (item[kHISymbolicHotKeyModifiers] as? NSNumber)?.intValue else { return nil }
            return KeyboardLayout.systemSlot(code: code, carbonFlags: flags)
        })
    }

    static var detectedKeyboard: KeyboardKind {
        KBGetLayoutType(Int16(LMGetKbdType())) == UInt32(kKeyboardJIS) ? .jis : .ansi
    }
}
