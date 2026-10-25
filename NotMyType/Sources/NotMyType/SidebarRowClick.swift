import AppKit
import SwiftUI

/// Observe native clicks without competing with List selection or its context menu.
struct SidebarRowClick: NSViewRepresentable {
    var select: (Bool) -> Void
    var edit: () -> Void

    func makeNSView(context: Context) -> ClickObserver { ClickObserver() }
    func updateNSView(_ view: ClickObserver, context: Context) {
        view.select = select
        view.edit = edit
    }
    static func dismantleNSView(_ view: ClickObserver, coordinator: ()) { view.stop() }

    final class ClickObserver: NSView {
        var select: ((Bool) -> Void)?
        var edit: (() -> Void)?
        private var monitor: Any?
        private var lastMouseDown: (number: Int, timestamp: TimeInterval)?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                self?.observe(event)
                return event
            }
        }
        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
        func observe(_ event: NSEvent) {
            let inside = event.window === window && window != nil && !isHiddenOrHasHiddenAncestor
                && bounds.contains(convert(event.locationInWindow, from: nil))
                && visibleRect.contains(convert(event.locationInWindow, from: nil))
            guard event.type == .leftMouseDown, inside, !event.modifierFlags.contains(.control) else { return }
            // AppKit can replay an event when a window first becomes key.
            if let lastMouseDown, lastMouseDown.number == event.eventNumber,
               lastMouseDown.timestamp == event.timestamp { return }
            lastMouseDown = (event.eventNumber, event.timestamp)
            let preserveSearch = event.modifierFlags.contains(.option)
            let select = self.select
            let edit = event.clickCount == 2 ? self.edit : nil
            // Let List finish handling the event, then set the intended selection.
            DispatchQueue.main.async {
                select?(preserveSearch)
                edit?()
            }
        }
    }
}
