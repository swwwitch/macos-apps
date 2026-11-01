import AppKit
import Carbon
func event(_ value: OSType) -> NSAppleEventDescriptor {
    let event = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEOpenApplication), targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
    event.setParam(NSAppleEventDescriptor(enumCode: value), forKeyword: keyAEPropData)
    return event
}
precondition(LaunchPolicy.isLoginLaunch(event(keyAELaunchedAsLogInItem)))
precondition(!LaunchPolicy.isLoginLaunch(nil))
precondition(!LaunchPolicy.isLoginLaunch(event(0)))
precondition(!LaunchPolicy.shouldRevealOnActivation(loginSuppressed: true, commandHeld: false))
precondition(LaunchPolicy.shouldRevealOnActivation(loginSuppressed: true, commandHeld: true))
precondition(LaunchPolicy.shouldRevealOnActivation(loginSuppressed: false, commandHeld: false))
precondition(LaunchPolicy.shouldRevealOnActivation(loginSuppressed: false, commandHeld: true))
print("Launch policy: login activation stays quiet; manual activation and Command-Tab reveal")
