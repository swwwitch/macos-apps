import AppKit
import Carbon
@main struct LaunchTests {
    static func main() {
        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEOpenApplication), targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        precondition(!LaunchPolicy.isLoginLaunch(event))
        event.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsLogInItem), forKeyword: keyAEPropData)
        precondition(LaunchPolicy.isLoginLaunch(event))
        precondition(!LaunchPolicy.isLoginLaunch(nil))
        precondition(LaunchPolicy.shouldStayInBackground(loginLaunch: true, enabled: true, hasFiles: false))
        precondition(!LaunchPolicy.shouldStayInBackground(loginLaunch: false, enabled: true, hasFiles: false))
        precondition(!LaunchPolicy.shouldStayInBackground(loginLaunch: true, enabled: false, hasFiles: false))
        precondition(!LaunchPolicy.shouldStayInBackground(loginLaunch: true, enabled: true, hasFiles: true))
        print("PASS: login event detection, normal launch, preference off, Open With override")
    }
}
