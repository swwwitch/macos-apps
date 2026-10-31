import AppKit
import Carbon

// No event is posted. All tested mappings produce exactly one returned event.
let tap = KeyTap()
tap.update(TapState(active: true, commands: CommandTable.all, ansiTrigger: .control, jisTrigger: .control))
tap.numpad.update(NumpadState(active: true, ansiTrigger: .fn, jisTrigger: .fn))
let proxy = OpaquePointer(bitPattern: 1)!
func event(_ code: CGKeyCode, _ down: Bool, _ flags: CGEventFlags, marker: Int64 = 0) -> CGEvent {
    let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
    e.flags = flags; e.setIntegerValueField(.eventSourceUserData, value: marker)
    return e
}
func route(_ e: CGEvent) -> CGEvent? {
    guard let output = tap.handle(proxy: proxy, type: e.type, event: e) else { return nil }
    if output.takeUnretainedValue() === e { return e }
    return output.takeRetainedValue()
}
let j = route(event(0x26, true, [.maskSecondaryFn]))!
precondition(j.getIntegerValueField(.keyboardEventKeycode) == 0x53)
let up = route(event(0x26, false, []))!
precondition(up.getIntegerValueField(.keyboardEventKeycode) == 0x53 && up.type == .keyUp, "release after fn released")
let f = route(event(3, true, [.maskControl]))!
precondition(f.getIntegerValueField(.keyboardEventKeycode) == 124, "control F still moves right")
_ = route(event(3, false, []))
let synthetic = event(0x26, true, [.maskSecondaryFn], marker: KeyTap.marker)
precondition(route(synthetic) === synthetic, "synthetic output not converted twice")
tap.numpad.update(NumpadState(active: false))
let plain = event(0x26, true, [.maskSecondaryFn])
precondition(route(plain) === plain, "disabled keypad passes through")
tap.update(TapState(active: false))
let blocked = event(3, true, [.maskControl])
precondition(route(blocked) === blocked, "excluded / disabled editing passes through")
precondition(OCRText.clean("日 本 (test)", join: true, parens: true) == "日本 （test）")
precondition(OCRText.clean("日 本 (test)", join: false, parens: false) == "日 本 (test)")
print("PASS: combined routing, modifier release, synthetic events, disabled features, OCR formatting")
