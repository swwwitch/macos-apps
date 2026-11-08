import AppKit
import ApplicationServices
// Keep these tests read-only: browser driving must stop at the permission guard.
enum AccessibilitySection { static let isTrusted = false }
func L(_ key: String) -> String { key }
@main struct BrowserTests {
    static func main() {
        for browser in Browser.all {
            let (code, flags) = browser.forceReloadKey
            precondition(code == 15)
            precondition(flags == (browser.kind == .safari ? [.maskCommand, .maskAlternate] : [.maskCommand, .maskShift]))
        }
        precondition(!BrowserBridge.showReader(pid: 0))
        precondition(!BrowserBridge.canMoveTabToNewWindow(browser: Browser.all[0], pid: 0))
        print("PASS: per-browser hard reload mapping; denied permission sends no reader command")
    }
}
