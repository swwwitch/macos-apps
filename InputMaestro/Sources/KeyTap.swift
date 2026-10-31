import AppKit
import ApplicationServices
import Carbon

/// What the event tap reads on its own thread; the main thread replaces it as a whole.
struct TapState {
    /// On, not paused, and the front app is not excluded.
    var active = false
    /// The commands for the front app (CommandTable.resolved).
    var commands: [Command] = []
    var frontPID: pid_t = 0
    var ansiTrigger = TriggerKey.control
    var jisTrigger = TriggerKey.capsLock
    /// Caps Lock (where it is the trigger) also works as a real ⌃ for every other key. On whenever replacement is on and
    /// not paused, also in excluded and pass-through apps: there ⌃F reaches the app as the app's own ⌃F.
    var capsAsControl = false
    var googleArrows = false
    var inputRevision = 0
}

/// Replaces ⌃+key (or Caps Lock+key) with a session event tap (needs Accessibility).
/// Simple keys are swapped inside the tap; editing commands are swallowed and run by TextActions.
/// The tap runs on its own thread so a busy main thread never delays typing (as FnNumpad's NumpadTap).
final class KeyTap: @unchecked Sendable {
    /// Marks the keys InputMaestro types itself, so the tap lets them through.
    static let marker: Int64 = 0x434D_4154

    let numpad = NumpadTap()
    private var arrowSequence = ArrowSequence()
    private var arrowHeld = Set<Int64>()
    private let lock = NSLock()
    private var state = TapState()
    /// Physical key → command, from its key down to its key up, so the release (and key repeat) follows the same command
    /// even if the trigger is let go first (tap thread only). `extra` is the ⇧ carried to the replacement.
    private var held: [Int64: (command: Command, extra: Mods)] = [:]
    private var port: CFMachPort?
    private var runLoop: CFRunLoop?
    /// An editing command was pressed, with ⇧ to extend the selection (called on the tap thread). Set before start().
    var onAction: (@Sendable (Action, Bool, pid_t) -> Void)?
    /// Caps Lock toggled the lock (new state), and a command was used while Caps Lock was held (CapsLockGuard).
    var onCapsToggle: (@Sendable (Bool) -> Void)?
    var onCapsUsed: (@Sendable () -> Void)?

    var isRunning: Bool { lock.withLock { port != nil } }

    func update(_ newState: TapState) { lock.withLock { var next = newState; next.inputRevision = state.inputRevision &+ 1; state = next } }
    private var snapshot: TapState { lock.withLock { state } }

    /// False when the tap cannot be created (Accessibility not granted).
    @discardableResult
    func start() -> Bool {
        if isRunning { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue) | (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.scrollWheel.rawValue)
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                           eventsOfInterest: CGEventMask(mask), callback: keyTapCallback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            let loop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(loop, source, .commonModes)
            self?.lock.withLock { self?.runLoop = loop }
            ready.signal()
            CFRunLoopRun()
        }
        thread.name = "InputMaestro event tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        lock.withLock { self.port = port }
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        let (port, loop) = lock.withLock { () -> (CFMachPort?, CFRunLoop?) in
            defer { self.port = nil; self.runLoop = nil }
            return (self.port, self.runLoop)
        }
        if let port { CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port) }
        if let loop { CFRunLoopStop(loop) }
    }

    func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let port = lock.withLock({ port }) { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        case .flagsChanged:
            arrowSequence.reset()
            if event.getIntegerValueField(.keyboardEventKeycode) == 57, let onCapsToggle {
                let on = event.flags.contains(.maskAlphaShift)
                DispatchQueue.main.async { onCapsToggle(on) }
            }
            return Unmanaged.passUnretained(event)
        case .keyDown, .keyUp:
            break
        default:
            arrowSequence.reset()
            return Unmanaged.passUnretained(event)
        }
        // Keys typed by InputMaestro, FnNumpad or any other app (non-zero source data) are never touched, so two apps that
        // both read Caps Lock do not add ⌃ to each other's output.
        if event.getIntegerValueField(.eventSourceUserData) != 0 { arrowSequence.reset(); return Unmanaged.passUnretained(event) }
        let routed = numpad.handle(proxy: proxy, type: type, event: event)
        guard let routed else { return nil }
        if routed.takeUnretainedValue() !== event { arrowSequence.reset(); return routed }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let down = type == .keyDown
        if arrowHeld.contains(code) {
            if !down { arrowHeld.remove(code) }
            return nil
        }
        if down {
            let state = snapshot
            var length = 0
            var chars = [UniChar](repeating: 0, count: 8)
            event.keyboardGetUnicodeString(maxStringLength: chars.count, actualStringLength: &length, unicodeString: &chars)
            let text = String(utf16CodeUnits: chars, count: length)
            let plain = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift, .maskSecondaryFn]).isEmpty
            if let arrow = arrowSequence.feed(text, context: state.inputRevision, allowed: state.googleArrows && plain && event.getIntegerValueField(.keyboardEventAutorepeat) == 0) {
                let outputs = Self.arrowEvents(arrow, like: event)
                guard outputs.count == 4, let last = outputs.last else { return Unmanaged.passUnretained(event) }
                arrowHeld.insert(code)
                for output in outputs.dropLast() { output.tapPostEvent(proxy) }
                return Unmanaged.passRetained(last)
            }
        }
        if let current = held[code] {
            if !down { held[code] = nil }
            // Editing commands run once; their repeat and release are swallowed.
            guard case .keys(let strokes) = current.command.action, let last = strokes.last,
                  let output = Self.makeEvent(last, extra: current.extra, down: down, like: event) else { return nil }
            return Unmanaged.passRetained(output)
        }
        let state = snapshot
        let trigger = Self.isJIS(event.getIntegerValueField(.keyboardEventKeyboardType)) ? state.jisTrigger : state.ansiTrigger
        // Caps Lock's release is not an event, so its physical state is asked only when it can be the trigger.
        let capsDown = trigger.usesCapsLock && CGEventSource.keyState(.hidSystemState, key: 57)
        // A command starts only on the first key down with the trigger.
        guard down, event.getIntegerValueField(.keyboardEventAutorepeat) == 0, state.active else { return passOn(event, capsDown, state) }
        let control = event.flags.contains(.maskControl)
        let mods = Mods(event.flags)
        guard let command = CommandTable.match(code: code, mods: mods, in: state.commands) else { return passOn(event, capsDown, state) }
        let alternate = command.alternates.contains { $0.code == code && $0.mods == mods }
        // Added Control+arrow hotkeys always use the physical Control key, including on JIS layouts.
        guard alternate ? control : trigger.pressed(control: control, capsLock: capsDown) else { return passOn(event, capsDown, state) }
        if control && !capsDown && !trigger.usesControl && !alternate { return passOn(event, capsDown, state) }
        if capsDown, let onCapsUsed { DispatchQueue.main.async { onCapsUsed() } }
        let extra = command.carriesShift ? mods.intersection(.shift).subtracting(command.mods) : []
        held[code] = (command, extra)
        guard case .keys(let strokes) = command.action else {
            onAction?(command.action, extra.contains(.shift), state.frontPID)
            return nil
        }
        for stroke in strokes.dropLast() {
            for strokeDown in [true, false] {
                guard let copy = Self.makeEvent(stroke, extra: extra, down: strokeDown, like: event) else { continue }
                copy.tapPostEvent(proxy)
            }
        }
        guard let last = strokes.last, let output = Self.makeEvent(last, extra: extra, down: true, like: event) else { return nil }
        return Unmanaged.passRetained(output)
    }

    /// A key that is not a command goes on as it is; with 「Caps Lock を常に ⌃ として扱う」 and Caps Lock down, it gets ⌃.
    private func passOn(_ event: CGEvent, _ capsDown: Bool, _ state: TapState) -> Unmanaged<CGEvent>? {
        if state.capsAsControl && capsDown {
            var flags = event.flags
            flags.insert(.maskControl); flags.remove(.maskAlphaShift)
            event.flags = flags
            if let onCapsUsed { DispatchQueue.main.async { onCapsUsed() } }
        }
        return Unmanaged.passUnretained(event)
    }

    /// A new event, so the characters come from the replacement key and the held ⌃ is not carried along.
    static func makeEvent(_ stroke: Stroke, extra: Mods, down: Bool, like original: CGEvent) -> CGEvent? {
        guard let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .privateState), virtualKey: CGKeyCode(stroke.code), keyDown: down) else { return nil }
        event.flags = stroke.flags.union(extra.flags)
        event.timestamp = original.timestamp
        event.setIntegerValueField(.keyboardEventAutorepeat, value: original.getIntegerValueField(.keyboardEventAutorepeat))
        event.setIntegerValueField(.keyboardEventKeyboardType, value: original.getIntegerValueField(.keyboardEventKeyboardType))
        event.setIntegerValueField(.eventSourceUserData, value: marker)
        return event
    }

    /// Balanced Delete and Unicode pairs; build all events before touching the target.
    static func arrowEvents(_ arrow: String, like original: CGEvent) -> [CGEvent] {
        var outputs: [CGEvent] = []
        for down in [true, false] {
            guard let deletion = makeEvent(Stroke(code: 51, label: "Delete"), extra: [], down: down, like: original) else { return [] }
            outputs.append(deletion)
        }
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .privateState), virtualKey: 0, keyDown: down) else { return [] }
            event.flags = []; event.timestamp = original.timestamp
            let units = Array(arrow.utf16)
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            outputs.append(event)
        }
        return outputs
    }

    static func isJIS(_ keyboardType: Int64) -> Bool {
        KBGetLayoutType(Int16(truncatingIfNeeded: keyboardType)) == UInt32(kKeyboardJIS)
    }
}

private func keyTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, info: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let info else { return Unmanaged.passUnretained(event) }
    return Unmanaged<KeyTap>.fromOpaque(info).takeUnretainedValue().handle(proxy: proxy, type: type, event: event)
}
