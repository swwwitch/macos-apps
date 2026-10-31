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
