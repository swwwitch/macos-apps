import AppKit
import Carbon

enum LaunchPolicy {
    static func isLoginLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventClass == AEEventClass(kCoreEventClass), event.eventID == AEEventID(kAEOpenApplication) else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
    static func shouldStayInBackground(loginLaunch: Bool, enabled: Bool, hasFiles: Bool) -> Bool {
        loginLaunch && enabled && !hasFiles
    }
}
