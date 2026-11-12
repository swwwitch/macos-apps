import CoreGraphics

// MARK: - ドラッグでパン（状態の移り変わり）

/// Decides what happens to the pan button's events. Free of AppKit so the tests can drive it; DragPan carries the actions out.
/// The press is held back until it is known whether it is a click (sent on release as it was) or a drag (turned into Space + left drag).
/// Whether Illustrator is typing (Space would be typed) arrives later from `do javascript`; until then the drag waits.
struct DragPanMachine {
    enum Phase: Equatable {
        case idle
        /// The press was not for us (another app, modifiers, off): its drags and release pass untouched.
        case ignoring
        /// Held back: not yet moved far enough, or the typing check has not answered.
        case pending
        case panning
        /// Typing: the press was sent late as it was, and the rest of the drag passes untouched.
        case passing
    }
    enum Action: Equatable {
        /// Let the event through unchanged.
        case pass
        /// Drop the event.
        case swallow
        /// Drop the event; press Space, press the left button at `from` and drag it to `to`.
        case startPan(from: CGPoint, to: CGPoint)
        /// Drop the event; drag the left button to the point.
        case drag(CGPoint)
        /// Drop the event; release the left button at the point, then Space.
        case endPan(CGPoint)
        /// Drop the event; click the pan button (press and release) at the point.
        case click(CGPoint)
        /// Drop the event; press the pan button at `at` and drag it to `to`, so the drag carries on as it was.
        case replay(at: CGPoint, to: CGPoint)
    }

    /// Moving this far (in points) makes it a drag.
    static let threshold: CGFloat = 4

    private(set) var phase = Phase.idle
    private(set) var start = CGPoint.zero
    private var last = CGPoint.zero
    private var moved = false
    /// nil until Illustrator answered.
    private var typing: Bool?

    mutating func down(at point: CGPoint, eligible: Bool) -> Action {
        guard eligible else { phase = .ignoring; return .pass }
        phase = .pending; start = point; last = point; moved = false; typing = nil
        return .swallow
    }

    mutating func dragged(to point: CGPoint) -> Action {
        switch phase {
        case .idle, .ignoring, .passing: return .pass
        case .panning: return .drag(point)
        case .pending:
            last = point
            if !moved, hypot(point.x - start.x, point.y - start.y) >= Self.threshold { moved = true }
            return moved ? (decide() ?? .swallow) : .swallow
        }
    }

    mutating func up(at point: CGPoint) -> Action {
        defer { phase = .idle }
        switch phase {
        case .idle, .ignoring, .passing: return .pass
        case .pending: return .click(start)
        case .panning: return .endPan(point)
        }
    }

    /// Illustrator's answer to the typing check. Returns the action to carry out now, if the drag was waiting for it.
    mutating func typingAnswered(_ value: Bool) -> Action? {
        guard phase == .pending else { return nil }
        typing = value
        return moved ? decide() : nil
    }

    /// The tap stopped (disabled, setting turned off): a pan in progress must release Space and the button.
    mutating func abort() -> Action? {
        defer { phase = .idle }
        return phase == .panning ? .endPan(last) : nil
    }

    private mutating func decide() -> Action? {
        switch typing {
        case false?: phase = .panning; return .startPan(from: start, to: last)
        case true?: phase = .passing; return .replay(at: start, to: last)
        case nil: return nil
        }
    }
}
