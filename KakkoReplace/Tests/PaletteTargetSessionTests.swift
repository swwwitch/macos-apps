// Same as MightyEdit/Tests/PaletteTargetSessionTests.swift.
import Foundation
@main struct PaletteTargetSessionTests {
 static func main() {
  var state = PaletteTargetSession(ownPID: 1)
  state.bind(frontPID: 2)
  precondition(state.targetPID == 2)
  precondition(!state.activated(2))
  precondition(!state.activated(1)) // Preferences must not retarget the editor.
  precondition(state.activated(3)) // Switching apps hides the old palette.
  precondition(state.targetPID == 2)
  state.bind(frontPID: 3)
  precondition(state.targetPID == 3 && !state.activated(3))
  _ = state.activated(4)
  state.bind(frontPID: 1) // Invocation from the app menu uses the latest editor.
  precondition(state.targetPID == 4)
  state.bind(frontPID: 5) // Press-time app wins over the previous target.
  precondition(state.targetPID == 5)
  state.departed(6, frontPID: 1) // Editor -> own settings/menu activation.
  state.bind(frontPID: 1)
  precondition(state.targetPID == 6)
  state.departed(4, frontPID: 7) // Delayed unrelated departure must not overwrite the editor.
  state.bind(frontPID: 1)
  precondition(state.targetPID == 6)
  print("Passed target binding, switch hiding, self-activation and re-invocation")
 }
}
