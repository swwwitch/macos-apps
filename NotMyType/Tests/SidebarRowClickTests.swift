import AppKit
@main struct Tests {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 300, height: 120), styleMask: [.titled], backing: .buffered, defer: false)
        let view = SidebarRowClick.ClickObserver(frame: NSRect(x: 30, y: 20, width: 200, height: 60))
        window.contentView!.addSubview(view)
        var actions: [String] = []
        var preserved = false
        view.select = { keep in preserved = keep; actions.append("select") }
        view.edit = { actions.append("edit") }
        window.makeKeyAndOrderFront(nil)
        view.stop()
        var eventNumber = 0
        func click(_ count: Int, _ point: NSPoint = NSPoint(x: 80, y: 40), _ flags: NSEvent.ModifierFlags = []) {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                eventNumber += 1
                let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: eventNumber, clickCount: count, pressure: 1)!
                view.observe(event)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { click(1) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            precondition(actions == ["select"], "single click must select immediately")
            click(2)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            precondition(actions == ["select", "select", "edit"], "double click must select then edit")
            click(1, NSPoint(x: 10, y: 10))
            click(1, NSPoint(x: 80, y: 40), .control)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            precondition(actions.count == 3, "outside and control click must not select")
            click(1, NSPoint(x: 80, y: 40), .option)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            precondition(actions.count == 4 && preserved, "Option modifier must reach selection")
            print("PASS click handler: single/double click and outside/control exclusion, Option preservation")
            exit(0)
        }
        app.run()
    }
}
