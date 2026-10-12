import AppKit
@preconcurrency import ApplicationServices

/// 押したキーを記録する。アクセシビリティが許可されていればイベントタップで先回りして受け取り、
/// ほかのアプリのホットキーを反応させない。未許可のときはこのアプリに届いたキーだけを記録する
@MainActor
final class KeyRecorder {
    static let shared = KeyRecorder()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localMonitor: Any?
    private var pendingKeyUp: Int?
    private var completion: ((KeyCombo?) -> Void)?
    private(set) var usesEventTap = false

    var isRecording: Bool { completion != nil }

    /// 記録を始める。Esc だけを押すと取り消し（nil）
    func start(_ completion: @escaping (KeyCombo?) -> Void) {
        stop()
        self.completion = completion
        if AXIsProcessTrusted(), installTap() {
            usesEventTap = true
        } else {
            usesEventTap = false
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isRecording else { return event }
                self.finish(keyCode: Int(event.keyCode), flags: Int(event.modifierFlags.rawValue))
                return nil
            }
        }
    }

    func cancel() { finishWith(nil) }

    private func installTap() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, _ in
            // 記録が終わるまで、または記録したキーを離すまで、ほかのアプリへ渡さない
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = Int(event.flags.rawValue)
            let result = MainActor.assumeIsolated { KeyRecorder.shared.handle(type: type, keyCode: keyCode, flags: flags) }
            return result ? nil : Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: CGEventMask(mask), callback: callback, userInfo: nil) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
        return true
    }

    /// true を返したイベントは捨てる
    private func handle(type: CGEventType, keyCode: Int, flags: Int) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .keyDown:
            // 記録したキーの押し続け（リピート）だけを止める。ほかのキーは通す
            if let pending = pendingKeyUp { return pending == keyCode }
            guard isRecording else { return false }
            pendingKeyUp = keyCode
            finish(keyCode: keyCode, flags: flags)
            if tap != nil {
                // keyUp が届かなくても入力を止め続けないよう、必ず外す
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self, !self.isRecording else { return }
                    self.pendingKeyUp = nil
                    self.removeTap()
                }
            }
            return true
        case .keyUp:
            guard let pending = pendingKeyUp else { return isRecording }
            if pending == keyCode { pendingKeyUp = nil; removeTap() }
            return true
        default:
            return false
        }
    }

    private func finish(keyCode: Int, flags: Int) {
        let modifiers = KeyModifiers(cocoaFlags: flags)
        // 修飾なしの Esc は取り消し
        if keyCode == 53 && modifiers.subtracting(.function).isEmpty {
            finishWith(nil)
        } else {
            finishWith(KeyCombo(keyCode: keyCode, modifiers: modifiers))
        }
    }

    private func finishWith(_ combo: KeyCombo?) {
        let completion = self.completion
        self.completion = nil
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
        // イベントタップは離されるのを待ってから外す（keyUp を相手に渡さない）。取り消しはすぐ外す
        if combo == nil { pendingKeyUp = nil; removeTap() }
        completion?(combo)
    }

    func stop() {
        completion = nil
        pendingKeyUp = nil
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
        removeTap()
    }

    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
    }
}
