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

/// Pairs distinct key presses. The interval is measured between key-down events.
struct AppHotkeyPressSequence {
    private var firstPress: TimeInterval?
    mutating func press(at time: TimeInterval, interval: TimeInterval) -> Bool {
        if let first = firstPress, time >= first, time - first <= interval {
            firstPress = nil
            return true
        }
        firstPress = time
        return false
    }
}
