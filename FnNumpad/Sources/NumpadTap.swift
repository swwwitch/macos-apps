import AppKit
import ApplicationServices
import Carbon

/// What the event tap reads on its own thread; the main thread replaces it as a whole.
struct TapState: Equatable {
    /// Conversion on, not paused, and the front app is not excluded.
    var active = false
    var groups: Set<KeyGroup> = Set(KeyGroup.allCases)
    var ansiTrigger = TriggerKey.fn
    var jisTrigger = TriggerKey.capsLock
}

/// Turns Fn+key into keypad keys with a session event tap (needs Accessibility).
/// The tap runs on its own thread so a busy main thread never delays typing.
final class NumpadTap: @unchecked Sendable {
    /// Marks the extra event of Fn+N (00) so the tap lets it through.
    static let marker: Int64 = 0x464E_4E50

    private let lock = NSLock()
    private var state = TapState()
    /// Physical key → mapping, from its key down to its key up, so a key pressed with Fn ends as the same keypad key
    /// even if Fn is released first (tap thread only).
    private var held: [Int64: KeyMapping] = [:]
    private var port: CFMachPort?
    private var runLoop: CFRunLoop?
    /// Fn+, is typed on the main thread (CommaTyper), with the held modifiers minus Fn. Set before start().
    var onComma: (@Sendable (CGEventFlags) -> Void)?
    /// Caps Lock toggled the lock (new state), and a key was converted while Caps Lock was held (CapsLockGuard).
    var onCapsToggle: (@Sendable (Bool) -> Void)?
    var onCapsUsed: (@Sendable () -> Void)?

    var isRunning: Bool { lock.withLock { port != nil } }

    func update(_ newState: TapState) { lock.withLock { state = newState } }
    private var snapshot: TapState { lock.withLock { state } }

    /// False when the tap cannot be created (Accessibility not granted).
    @discardableResult
    func start() -> Bool {
        if isRunning { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                           eventsOfInterest: CGEventMask(mask), callback: numpadTapCallback,
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
        thread.name = "FnNumpad event tap"
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

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let port = lock.withLock({ port }) { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        case .flagsChanged:
            if event.getIntegerValueField(.keyboardEventKeycode) == 57, let onCapsToggle {
                let on = event.flags.contains(.maskAlphaShift)
                DispatchQueue.main.async { onCapsToggle(on) }
            }
            return Unmanaged.passUnretained(event)
        case .keyDown, .keyUp:
            break
        default:
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.marker { return Unmanaged.passUnretained(event) }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let down = type == .keyDown
        let repeating = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let mapping: KeyMapping
        if let current = held[code] {
            mapping = current
            if !down { held[code] = nil }
        } else {
            // A conversion starts only on the first key down with Fn, as Karabiner's from.modifiers.mandatory.
            let state = snapshot
            let trigger = Self.isJIS(event.getIntegerValueField(.keyboardEventKeyboardType)) ? state.jisTrigger : state.ansiTrigger
            // Caps Lock's release is not an event, so its physical state is asked only when it can be the trigger.
            let capsDown = down && !repeating && trigger.usesCapsLock && CGEventSource.keyState(.hidSystemState, key: 57)
            guard down, !repeating, state.active, trigger.pressed(fn: event.flags.contains(.maskSecondaryFn), capsLock: capsDown),
                  let found = KeyMap.mapping(for: code, groups: state.groups) else { return Unmanaged.passUnretained(event) }
            mapping = found
            if capsDown, let onCapsUsed { DispatchQueue.main.async { onCapsUsed() } }
            held[code] = found
        }
        guard let last = mapping.to.last else { return Unmanaged.passUnretained(event) }
        // Fn+, is swallowed here and typed by CommaTyper, which may have to paste it (Japanese input makes 「、」).
        if last == KeyMap.comma {
            if down, let onComma { let flags = Self.outputFlags(event.flags, keypad: false); DispatchQueue.main.async { onComma(flags) } }
            return nil
        }
        // Fn+N types 00: every key but the last goes in front of it; key repeat repeats the last only.
        if down && !repeating {
            for extra in mapping.to.dropLast() {
                for extraDown in [true, false] {
                    guard let copy = Self.makeEvent(extra, down: extraDown, like: event) else { continue }
                    copy.setIntegerValueField(.eventSourceUserData, value: Self.marker)
                    copy.tapPostEvent(proxy)
                }
            }
        }
        guard let output = Self.makeEvent(last, down: down, like: event) else { return Unmanaged.passUnretained(event) }
        return Unmanaged.passRetained(output)
    }

    /// A new event, so the characters come from the keypad key and not from the letter that was pressed.
    static func makeEvent(_ target: KeyTarget, down: Bool, like original: CGEvent) -> CGEvent? {
        guard let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .privateState), virtualKey: CGKeyCode(target.code), keyDown: down) else { return nil }
        event.flags = outputFlags(original.flags, keypad: target.keypad)
        event.timestamp = original.timestamp
        event.setIntegerValueField(.keyboardEventAutorepeat, value: original.getIntegerValueField(.keyboardEventAutorepeat))
        event.setIntegerValueField(.keyboardEventKeyboardType, value: original.getIntegerValueField(.keyboardEventKeyboardType))
        return event
    }

    static func isJIS(_ keyboardType: Int64) -> Bool {
        KBGetLayoutType(Int16(truncatingIfNeeded: keyboardType)) == UInt32(kKeyboardJIS)
    }

    /// Other modifiers pass through (Karabiner's optional: any); Fn is removed, the keypad flag follows the target.
    static func outputFlags(_ flags: CGEventFlags, keypad: Bool) -> CGEventFlags {
        var result = flags
        result.remove(.maskSecondaryFn)
        result.remove(.maskAlphaShift)
        if keypad { result.insert(.maskNumericPad) } else { result.remove(.maskNumericPad) }
        return result
    }
}

private func numpadTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, info: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let info else { return Unmanaged.passUnretained(event) }
    return Unmanaged<NumpadTap>.fromOpaque(info).takeUnretainedValue().handle(proxy: proxy, type: type, event: event)
}
