import AppKit

// Exercise real windows and the production notification observer without taking
// focus from the user's desktop. Activation itself is simulated; physical ⌘Tab
// checks belong to separate installed-app verification.
@MainActor final class SelectionTestApplication: NSApplication {
    var selected = false
    override var isActive: Bool { selected }
}

@main struct AppSwitcherWindowRevealTests {
    @MainActor static func main() {
        setbuf(stdout, nil)
        let app = SelectionTestApplication.shared as! SelectionTestApplication
        precondition(NSApp === app)
        app.setActivationPolicy(.accessory)
        func window() -> NSWindow {
            let w = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 200, height: 120),
                             styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            return w
        }
        let main = window(), settings = window()
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        var reveals = 0
        func expect(_ value: @autoclosure () -> Bool, _ label: String) {
            guard value() else { print("FAIL \(label)"); exit(1) }
            print("PASS \(label)")
        }
        func selection() { NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: app) }
        AppSwitcherWindowReveal.install { reveals += 1; main.makeKeyAndOrderFront(nil) }
        selection()
        expect(reveals == 0, "initial activation follows launch policy")
        var steps: [() -> Void] = [
            { app.selected = true; settings.orderFront(nil); reveals = 0; selection() },
            { expect(main.isVisible && reveals == 1, "closed main is displayed"); main.miniaturize(nil) },
            { reveals = 0; selection() },
            { expect(!main.isMiniaturized && reveals == 1, "minimized main is restored"); main.orderOut(nil); settings.orderFront(nil) },
            { reveals = 0; selection() },
            { expect(main.isVisible && reveals == 1, "settings-only selection opens main"); main.orderOut(nil); panel.orderFront(nil); reveals = 0 },
            { expect(reveals == 0, "palette does not request main"); panel.orderOut(nil); let sheet = window(); settings.beginSheet(sheet) },
            { reveals = 0; selection() },
            { expect(reveals == 0, "sheet workflow is protected"); if let sheet = settings.attachedSheet { settings.endSheet(sheet) } },
            { app.selected = false; AppSwitcherWindowReveal.preserveAuxiliaryWindowOnActivation(); app.selected = true; reveals = 0; selection() },
            { expect(reveals == 0, "explicit settings activation is protected"); selection() },
            { expect(main.isVisible && reveals == 1, "next selection is not suppressed"); main.orderOut(nil); app.selected = false; reveals = 0; selection() },
            { expect(!main.isVisible && reveals == 0, "inactive app never reveals main"); main.close(); settings.close(); panel.close(); print("AppSwitcherWindowReveal tests passed"); exit(0) }
        ]
        func next() {
            guard !steps.isEmpty else { return }
            steps.removeFirst()()
            // Allow the real minimize/sheet animation to finish before the next event.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { next() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { next() }
        app.run()
    }
}
