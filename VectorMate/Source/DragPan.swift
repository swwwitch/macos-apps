import AppKit
import ApplicationServices
import Carbon.HIToolbox

// MARK: - ドラッグでパン（右ボタン／中ボタン）

/// While Illustrator is in front, dragging with the right (or middle) button pans the view: the drag is turned into
/// Space + left drag, which is Illustrator's temporary Hand tool. A press without movement is sent on release as the
/// original click, so the context menu still opens (on release rather than on press).
/// Karabiner-Elements cannot do this: it keeps only the last of several output events held down.
@MainActor
final class DragPan {
    enum Button: String, CaseIterable {
        case right, middle
        var label: String { L(self == .right ? "pan.right" : "pan.middle") }
    }

    /// Changing the button while a pan is in progress releases it first.
    var button = Button.right { didSet { if button != oldValue { finish() } } }
    /// Checked on every press (master switch, excluded apps).
    var allowed: () -> Bool = { false }

    /// Marks the events posted here, so the tap lets them through.
    nonisolated static let marker: Int64 = 0x564D_5041
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var machine = DragPanMachine()
    private var pid: pid_t = 0
    /// Answers to an earlier press's typing check are ignored.
    private var generation = 0

    var isRunning: Bool { tap != nil }

    func start() {
        guard tap == nil else { return }
        guard AXIsProcessTrusted() else { diagnostics.log("pan: not trusted"); return }
        let types: [CGEventType] = [.rightMouseDown, .rightMouseUp, .rightMouseDragged, .otherMouseDown, .otherMouseUp, .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | CGEventMask(1) << $1.rawValue }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
                                callback: { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            return MainActor.assumeIsolated { Unmanaged<DragPan>.fromOpaque(info).takeUnretainedValue().handle(type, event) }
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { diagnostics.error("pan: event tap unavailable"); return }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)
        diagnostics.log("pan: tap started (\(self.button.rawValue, privacy: .public))")
    }

    func stop() {
        finish()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }

    /// Releases Space and the left button if a pan is in progress.
    private func finish() {
        generation += 1
        if let action = machine.abort() { carryOut(action) }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // The release may have been missed: do not leave Space held down.
            finish()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.marker, isPanButton(type, event) else {
            return Unmanaged.passUnretained(event)
        }
        let point = event.location
        let action: DragPanMachine.Action
        switch type {
        case .rightMouseDown, .otherMouseDown:
            action = machine.down(at: point, eligible: eligible(event))
            diagnostics.log("pan: down \(String(describing: action), privacy: .public)")
            if action == .swallow { askTyping() }
        case .rightMouseDragged, .otherMouseDragged:
            action = machine.dragged(to: point)
        default:
            action = machine.up(at: point)
        }
        if action == .pass { return Unmanaged.passUnretained(event) }
        carryOut(action, original: event)
        return nil
    }

    private func isPanButton(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch button {
        case .right: return [.rightMouseDown, .rightMouseUp, .rightMouseDragged].contains(type)
        case .middle:
            return [.otherMouseDown, .otherMouseUp, .otherMouseDragged].contains(type) && event.getIntegerValueField(.mouseEventButtonNumber) == 2
        }
    }

    /// Illustrator in front, no modifier keys (⌘/⌥ + Space zoom), and the pointer over one of Illustrator's windows
    /// (not a palette of VectorMate floating above it, the menu bar or the Dock).
    private func eligible(_ event: CGEvent) -> Bool {
        guard allowed(), let front = NSWorkspace.shared.frontmostApplication, Illustrator.isIllustrator(front),
              !ExcludedApps.shared.frontAppExcluded else { return false }
        guard event.flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift]).isEmpty else {
            diagnostics.log("pan: modifiers"); return false
        }
        let owner = Self.windowOwner(of: event)
        guard owner == front.processIdentifier else {
            diagnostics.log("pan: window owner \(owner ?? -1, privacy: .public) is not Illustrator \(front.processIdentifier, privacy: .public)"); return false
        }
        pid = front.processIdentifier
        return true
    }

    /// Space would be typed while a type tool is in use: ask Illustrator off the main thread; the drag waits for the answer.
    private func askTyping() {
        generation += 1
        let asked = generation, pid = pid
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            let typing = IllustratorState.isTyping(pid)
            diagnostics.log("pan: typing=\(typing, privacy: .public)")
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.generation == asked, let action = self.machine.typingAnswered(typing) else { return }
                    self.carryOut(action)
                }
            }
        }
    }

    /// The owner of the window the window server routes this press to. A geometric search of CGWindowList does not work:
    /// the pointer itself and click-through overlays (Keystroke Pro, dimmers) are windows above everything.
    nonisolated static func windowOwner(of event: CGEvent) -> pid_t? {
        for field in [CGEventField.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, .mouseEventWindowUnderMousePointer] {
            let id = event.getIntegerValueField(field)
            guard id > 0, let list = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(id)) as? [[String: Any]],
                  let pid = (list.first?[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value else { continue }
            return pid
        }
        let target = event.getIntegerValueField(.eventTargetUnixProcessID)
        return target > 0 ? pid_t(target) : nil
    }

    // MARK: Posting

    private func carryOut(_ action: DragPanMachine.Action, original: CGEvent? = nil) {
        switch action {
        case .pass, .swallow, .drag: break
        default: diagnostics.log("pan: \(String(describing: action), privacy: .public)")
        }
        let deltas = original.map { ($0.getIntegerValueField(.mouseEventDeltaX), $0.getIntegerValueField(.mouseEventDeltaY)) }
        switch action {
        case .pass, .swallow: break
        case let .startPan(from, to):
            postKey(down: true)
            postMouse(.leftMouseDown, at: from, button: .left)
            postMouse(.leftMouseDragged, at: to, button: .left)
        case let .drag(point):
            postMouse(.leftMouseDragged, at: point, button: .left, deltas: deltas)
        case let .endPan(point):
            postMouse(.leftMouseUp, at: point, button: .left)
            postKey(down: false)
        case let .click(point):
            let (down, up, mouse) = buttonTypes(dragged: false)
            postMouse(down, at: point, button: mouse)
            postMouse(up, at: point, button: mouse)
        case let .replay(at, to):
            let (down, dragged, mouse) = buttonTypes(dragged: true)
            postMouse(down, at: at, button: mouse)
            postMouse(dragged, at: to, button: mouse)
        }
    }

    /// The pan button's press and release (or drag) types.
    private func buttonTypes(dragged: Bool) -> (CGEventType, CGEventType, CGMouseButton) {
        switch button {
        case .right: return (.rightMouseDown, dragged ? .rightMouseDragged : .rightMouseUp, .right)
        case .middle: return (.otherMouseDown, dragged ? .otherMouseDragged : .otherMouseUp, .center)
        }
    }

    private func postMouse(_ type: CGEventType, at point: CGPoint, button: CGMouseButton, deltas: (Int64, Int64)? = nil) {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button) else { return }
        event.flags = []
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        if button == .center { event.setIntegerValueField(.mouseEventButtonNumber, value: 2) }
        if [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp].contains(type) {
            event.setIntegerValueField(.mouseEventClickState, value: 1)
        }
        if let (dx, dy) = deltas {
            event.setIntegerValueField(.mouseEventDeltaX, value: dx)
            event.setIntegerValueField(.mouseEventDeltaY, value: dy)
        }
        event.post(tap: .cghidEventTap)
    }

    private func postKey(down: Bool) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Space), keyDown: down) else { return }
        event.flags = []
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        event.post(tap: .cghidEventTap)
    }
}
