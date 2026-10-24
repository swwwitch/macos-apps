import AppKit
import Carbon

@main
struct StartupWindowGateTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 100, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = StartupWindowGate.GateView(frame: .zero)
        window.orderFront(nil)
        precondition(window.isVisible, "Manual launch must remain visible")
        let login = NSAppleEventDescriptor(eventClass: kCoreEventClass, eventID: kAEOpenApplication, targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        login.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsLogInItem), forKeyword: keyAEPropData)
        StartupWindow.captureLaunch(login)
        let reopen = CommandLine.arguments.contains("--reopen")
        if reopen { StartupWindow.userRequestedWindow() }
        NotificationCenter.default.post(name: NSApplication.didFinishLaunchingNotification, object: NSApp)
        precondition(window.isVisible == reopen, "Late login event hides only the unrequested initial window")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        precondition(window.isVisible == reopen, "Deferred gate must respect explicit reopening")
        window.orderOut(nil)
        print("StartupWindow gate passed: \(reopen ? "explicit reopen" : "late login event")")
    }
}
