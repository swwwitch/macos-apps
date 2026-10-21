import AppKit
@main struct KeyMapTests {
    static func main() {
        let all = Set(KeyGroup.allCases)
        precondition(KeyMap.all.count == 32)
        precondition(Set(KeyMap.all.map(\.from)).count == KeyMap.all.count, "one mapping per physical key")
        precondition(KeyMap.mapping(for: 0x26, groups: all)?.to == [KeyMap.keypad1])
        precondition(KeyMap.mapping(for: 0x2D, groups: all)?.toLabel == "00")
        precondition(KeyMap.mapping(for: 0x26, groups: [.editing]) == nil, "a group that is off converts nothing")
        precondition(KeyMap.mapping(for: 0x00, groups: all) == nil, "A is not mapped")
        precondition(KeyMap.all.filter { $0.to.contains { !$0.keypad } }.allSatisfy { $0.group == .editing || $0.from == 0x2B })
        precondition(KeyMap.mapping(for: 0x2B, groups: all)?.to == [KeyMap.comma])
        precondition(KeyMap.mapping(for: 0x24, groups: all)?.to == [KeyMap.keypadEnter])
        precondition(KeyMap.mapping(for: 0x30, groups: all)?.to == [KeyMap.keypadEquals])
        precondition(TriggerKey.fn.pressed(fn: true, capsLock: false) && !TriggerKey.fn.pressed(fn: false, capsLock: true))
        precondition(TriggerKey.capsLock.pressed(fn: false, capsLock: true) && !TriggerKey.capsLock.pressed(fn: true, capsLock: false))
        precondition(TriggerKey.both.pressed(fn: true, capsLock: false) && TriggerKey.both.pressed(fn: false, capsLock: true))
        precondition(!TriggerKey.both.pressed(fn: false, capsLock: false))
        precondition(NumpadTap.outputFlags([.maskAlphaShift, .maskSecondaryFn], keypad: true) == [.maskNumericPad], "Caps Lock does not leak")
        var flags: CGEventFlags = [.maskSecondaryFn, .maskShift]
        precondition(NumpadTap.outputFlags(flags, keypad: true) == [.maskShift, .maskNumericPad])
        flags = [.maskSecondaryFn, .maskNumericPad, .maskCommand]
        precondition(NumpadTap.outputFlags(flags, keypad: false) == [.maskCommand])
        for down in [true, false] {
            let original = CGEvent(keyboardEventSource: nil, virtualKey: 0x26, keyDown: down)!
            original.flags = [.maskSecondaryFn]
            let made = NumpadTap.makeEvent(KeyMap.keypad1, down: down, like: original)!
            precondition(made.getIntegerValueField(.keyboardEventKeycode) == 0x53)
            precondition(made.flags.contains(.maskNumericPad) && !made.flags.contains(.maskSecondaryFn))
            precondition(made.type == (down ? .keyDown : .keyUp))
        }
        print("PASS: 32 mappings, groups, trigger keys, Fn removed, keypad flag, new key events")
    }
}
