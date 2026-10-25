import AppKit

@main
struct DockPresenceTests {
    @MainActor static func main() {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        let domain = "DockPresenceRegression-\(ProcessInfo.processInfo.processIdentifier)"
        // Only this test process sees these preferences; no app's saved settings are changed.
        func preference(_ hidden: Bool) {
            UserDefaults.standard.setVolatileDomain([DockPresence.key: hidden], forName: UserDefaults.argumentDomain)
        }
        func window() -> NSWindow {
            let w = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 180, height: 120),
                             styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            return w
        }
        let main = window(), settings = window(), second = window()
        let palette = NSPanel(contentRect: .zero, styleMask: [.titled, .nonactivatingPanel, .utilityWindow], backing: .buffered, defer: false)
        palette.isReleasedWhenClosed = false
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        var checks = 0
        func expect(_ policy: NSApplication.ActivationPolicy, _ label: String) {
            precondition(app.activationPolicy() == policy, "\(label): \(app.activationPolicy().rawValue)")
            precondition(NSWorkspace.shared.frontmostApplication?.processIdentifier == frontmostPID, "Window observation must not steal focus: \(label)")
            checks += 1; print("PASS \(label)")
        }
        // Each action completes through AppKit's real event loop before its assertion.
        var steps: [() -> Void] = [
            { preference(true); DockPresence.apply(); expect(.accessory, "quiet background/login without windows") },
            { palette.orderFront(nil) },
            { expect(.accessory, "palette alone does not expose Dock"); main.orderFront(nil) },
            { expect(.regular, "main window restores application menus"); settings.orderFront(nil) },
            { main.close() },
            { expect(.regular, "settings remains after main closes"); second.orderFront(nil) },
            { settings.close() },
            { expect(.regular, "last of multiple windows remains"); second.miniaturize(nil) },
            { expect(.regular, "minimized window remains recoverable"); WindowActivationPolicy.restoreMinimized() },
            { expect(.regular, "Dock/Tab activation restores minimized window"); second.orderOut(nil) },
            { expect(.accessory, "orderOut with palette remaining"); preference(false); DockPresence.apply() },
            { expect(.regular, "OFF restores normal app policy"); preference(true); DockPresence.apply() },
            { expect(.accessory, "ON without regular windows"); settings.orderFront(nil) },
            { expect(.regular, "reopen settings while ON"); preference(false); DockPresence.apply() },
            { expect(.regular, "OFF while settings open"); preference(true); DockPresence.apply() },
            { expect(.regular, "ON while settings open"); settings.close() },
            { expect(.accessory, "close settings hides background again"); WindowActivationPolicy.install(); preference(false); DockPresence.apply() },
            { expect(.accessory, "OFF preserves menu-bar app's usual policy"); main.orderFront(nil) },
            { expect(.regular, "menu-bar app main window"); main.close() },
            { expect(.accessory, "menu-bar app last close"); palette.close(); UserDefaults.standard.removeVolatileDomain(forName: UserDefaults.argumentDomain); print("DockPresence: \(checks) AppKit event-loop checks passed (\(domain))"); exit(0) }
        ]
        func next() {
            guard !steps.isEmpty else { return }
            steps.removeFirst()()
            // Timer-driven actions need an application event to complete the normal update pass.
            if let event = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0) {
                app.postEvent(event, atStart: false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { next() }
        }
        DispatchQueue.main.async { next() }
        app.run()
    }
}
