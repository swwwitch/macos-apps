import AppKit
import SwiftUI

/// Handles bare digits only in the card window, never while editing text.
struct RatingKeyHandler: NSViewRepresentable {
    var handle: (Int) -> Bool
    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.handle = handle
        return view
    }
    func updateNSView(_ view: KeyView, context: Context) { view.handle = handle }
    static func dismantleNSView(_ view: KeyView, coordinator: ()) { view.stop() }

    final class KeyView: NSView {
        var handle: ((Int) -> Bool)?
        private var monitor: Any?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window, window.isKeyWindow,
                      event.window === window,
                      !event.isARepeat,
                      event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                      !(window.firstResponder is NSTextView),
                      !(window.firstResponder is NSTextField),
                      let chars = event.characters, chars.count == 1,
                      let value = Int(chars), (1...5).contains(value)
                else { return event }
                return self.handle?(value) == true ? nil : event
            }
        }
        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
