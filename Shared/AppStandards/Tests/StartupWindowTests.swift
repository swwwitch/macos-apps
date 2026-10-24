import AppKit
import Carbon

@main
struct StartupWindowTests {
    static func main() {
        let manual = NSAppleEventDescriptor(eventClass: kCoreEventClass, eventID: kAEOpenApplication, targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        precondition(!StartupWindow.isLoginEvent(nil))
        precondition(!StartupWindow.isLoginEvent(manual))
        UserDefaults.standard.register(defaults: ["hideMainWindowAtStartup": true])
        StartupWindow.captureLaunch(manual)
        precondition(!StartupWindow.suppressInitialWindow, "Retired preference must not hide a manual launch")
        let login = manual.copy() as! NSAppleEventDescriptor
        login.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsLogInItem), forKeyword: keyAEPropData)
        precondition(StartupWindow.isLoginEvent(login))
        StartupWindow.captureLaunch(login)
        precondition(StartupWindow.suppressInitialWindow)
        StartupWindow.captureLaunch(nil)
        precondition(StartupWindow.suppressInitialWindow, "Login launch survives asynchronous window construction")
        StartupWindow.userRequestedWindow()
        precondition(!StartupWindow.suppressInitialWindow, "Reopen/file delivery overrides a pending gate")
        StartupWindow.captureLaunch(login)
        precondition(!StartupWindow.suppressInitialWindow)
        print("StartupWindow policy tests passed")
    }
}
