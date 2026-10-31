import Foundation
func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
check(ClipboardGate.begin(blocked: true) == nil, "legacy compatibility must block")
check(!ClipboardGate.busy, "failed acquisition cannot reserve clipboard")
let first = ClipboardGate.begin(blocked: false)!
check(ClipboardGate.begin(blocked: false) == nil, "cross-feature paste must be exclusive")
ClipboardGate.end(UUID())
check(ClipboardGate.busy, "foreign token cannot release")
ClipboardGate.end(first, after: 0.03)
check(ClipboardGate.busy, "hold through delayed clipboard restore")
RunLoop.main.run(until: Date().addingTimeInterval(0.08))
check(!ClipboardGate.busy, "release after restore")
let second = ClipboardGate.begin(blocked: false)!
ClipboardGate.end(first)
check(ClipboardGate.busy, "stale token cannot release newer paste")
ClipboardGate.end(second)
check(!ClipboardGate.busy, "synchronous add completion releases")
print("Clipboard arbitration: 8 checks passed")

check(ClipboardGate.lineRestoreDelay < ClipboardGate.pasteHold, "restore must precede the next paste")
check(ClipboardGate.pasteHold <= 0.2, "rapid paste must not use the old 1.1s hold")
for _ in 0..<5 {
    let lease = ClipboardGate.begin(blocked: false)!
    ClipboardGate.end(lease, after: ClipboardGate.pasteHold)
    check(ClipboardGate.busy, "hold while destination reads")
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    check(!ClipboardGate.busy, "next repeat allowed after 0.2s")
}
print("Rapid paste: 5 consecutive operations at 0.2s intervals passed")
