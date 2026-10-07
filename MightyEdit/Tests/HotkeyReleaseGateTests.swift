import Foundation

@main struct HotkeyReleaseGateTests {
    static func main() {
        var gate = HotkeyReleaseGate()
        for id in [2, 4] { // Control+6 and Control+7
            precondition(gate.begin(id: id, pid: 42))
            precondition(!gate.begin(id: id, pid: 42)) // key repeat
            for _ in 0..<150 { // Trigger key held for 3 seconds
                precondition(gate.poll(frontPID: 42, keyHeld: true, enabled: true) == .waiting)
            }
            // Modifier state is deliberately not a gate input: Control may stay down.
            precondition(gate.poll(frontPID: 42, keyHeld: false, enabled: true) == .perform)
            precondition(gate.poll(frontPID: 42, keyHeld: false, enabled: true) == .cancelled)
        }
        precondition(gate.begin(id: 2, pid: 42))
        precondition(gate.poll(frontPID: 43, keyHeld: true, enabled: true) == .cancelled)
        precondition(gate.poll(frontPID: 42, keyHeld: false, enabled: true) == .cancelled)
        precondition(gate.begin(id: 4, pid: 42))
        precondition(gate.poll(frontPID: 42, keyHeld: false, enabled: false) == .cancelled)
        precondition(gate.begin(id: 4, pid: 42))
        gate.cancel() // changing settings cancels a held invocation
        precondition(gate.poll(frontPID: 42, keyHeld: false, enabled: true) == .cancelled)
        print("Passed delayed release, repeat suppression, single execution, app switch and disable checks")
    }
}
