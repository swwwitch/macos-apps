import AppKit

// MARK: - 選択ツール（修飾キーのダブルタップ）

/// While InDesign is in front, a modifier key (⌃ by default) tapped alone twice selects the Selection tool.
/// Ported from VectorMate's ToolWatcher (Illustrator). Key events reach a global monitor only with the Accessibility permission.
@MainActor
final class DoubleTapSelect {
    enum TapKey: String, CaseIterable {
        case control, option, command, shift
        var flag: NSEvent.ModifierFlags { switch self { case .control: .control; case .option: .option; case .command: .command; case .shift: .shift } }
        var label: String { switch self { case .control: "control（⌃）"; case .option: "option（⌥）"; case .command: "command（⌘）"; case .shift: "shift（⇧）" } }
    }
    /// The key held no longer than this counts as a tap; the second tap must start within `tapGap` of the first one's release.
    static let tapLength: TimeInterval = 0.3, tapGap: TimeInterval = 0.35

    var enabled = false { didSet { if enabled != oldValue { restart() } } }
    var tapKey = TapKey.control
    /// Checked when the second tap ends (excluded apps etc.).
    var allowed: () -> Bool = { true }
    private var monitors: [Any] = []
    private let queue = DispatchQueue(label: "LayoutMate.tools")
    // When the key went down alone (nil once anything else happened), and when the last tap ended.
    private var keyDown: TimeInterval?
    private var lastTap: TimeInterval?

    /// Restarts the monitors (switched on, or the Accessibility permission changed).
    func restart() {
        monitors.forEach(NSEvent.removeMonitor); monitors = []
        keyDown = nil; lastTap = nil
        guard enabled else { return }
        if let flags = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.modifiersChanged(event) }
        }) { monitors.append(flags) }
        if let down = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.keyDown = nil; self?.lastTap = nil }
        }) { monitors.append(down) }
    }

    private func modifiersChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.shift, .control, .option, .command])
        if flags == tapKey.flag {
            keyDown = event.timestamp
        } else if flags.isEmpty, let down = keyDown {
            keyDown = nil
            guard event.timestamp - down <= Self.tapLength else { lastTap = nil; return }
            if let last = lastTap, down - last <= Self.tapGap {
                lastTap = nil
                selectSelectionTool()
            } else {
                lastTap = event.timestamp
            }
        } else {
            keyDown = nil; lastTap = nil
        }
    }

    private func selectSelectionTool() {
        guard allowed(), let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier == AsyncExports.bundleID else { return }
        let pid = app.processIdentifier
        queue.async { InDesignScript.selectSelectionTool(pid) }
    }
}
