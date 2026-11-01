import AppKit
import Carbon

enum LaunchPolicy {
    static func isLoginLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventClass == AEEventClass(kCoreEventClass), event.eventID == AEEventID(kAEOpenApplication) else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
    /// Automatic activation is not a request to show a login-launched window.
    /// Explicit reopen/menu actions clear StartupWindow suppression; Command-Tab is user intent.
    static func shouldRevealOnActivation(loginSuppressed: Bool, commandHeld: Bool) -> Bool {
        !loginSuppressed || commandHeld
    }
    static func shouldStayInBackground(loginLaunch: Bool, enabled: Bool, hasFiles: Bool) -> Bool {
        loginLaunch && enabled && !hasFiles
    }
}
