import AppKit
import ApplicationServices

// MARK: - ツール（⌃のダブルタップ・ツールに合わせてパネルを開く）

/// While Illustrator is in front: a modifier key (⌃ by default) tapped twice selects the Selection tool, and choosing the Artboard or Gradient tool
/// opens its panel. Event-driven (no polling); the current tool is read with app.getSelectedToolName() (undocumented, Ai 2026 checked).
@MainActor
final class ToolWatcher {
    /// The modifier key tapped twice.
    enum TapKey: String, CaseIterable {
        case control, option, command, shift
        var flag: NSEvent.ModifierFlags { switch self { case .control: .control; case .option: .option; case .command: .command; case .shift: .shift } }
        var label: String { switch self { case .control: "control（⌃）"; case .option: "option（⌥）"; case .command: "command（⌘）"; case .shift: "shift（⇧）" } }
    }
    struct Options: Equatable {
        var doubleTap = false
        var tapKey = TapKey.control
        var artboardPanel = false
        var gradientPanel = false
        var any: Bool { doubleTap || artboardPanel || gradientPanel }
    }
    /// The tools that open a panel: tool name → (menu command, Window menu paths, Japanese first; English unverified).
    nonisolated static let panels: [(tool: String, command: String, paths: [[String]], option: KeyPath<Options, Bool>)] = [
        ("Adobe Crop Tool", "Adobe Artboard Palette", [["ウィンドウ", "アートボード"], ["Window", "Artboards"]], \.artboardPanel),
        ("Adobe Gradient Vector Tool", "Adobe Gradient Palette", [["ウィンドウ", "グラデーション"], ["Window", "Gradient"]], \.gradientPanel)
    ]
    nonisolated static let selectTool = "Adobe Select Tool"
    /// The key held no longer than this counts as a tap; the second tap must start within `tapGap` of the first one's release.
    static let tapLength: TimeInterval = 0.3, tapGap: TimeInterval = 0.35
    /// Wait after a click or key, so Illustrator has switched the tool before it is read.
    nonisolated static let delay: TimeInterval = 0.35
    /// A Keyboard Maestro hotkey is taken before it reaches the monitor: only its modifiers' release is seen, and the macro's
    /// app.selectTool may still be running, so the tool is read again this long after the release.
    static let macroDelay: TimeInterval = 1.0

    var options = Options() { didSet { if options != oldValue { restart() } } }
    private var monitors: [Any] = []
    private var activation: NSObjectProtocol?
    private let queue = DispatchQueue(label: "VectorMate.tools")
    private var pending: [DispatchWorkItem] = []
    private var previousTool: String?
    private var previousPID: pid_t = 0
    // Tap state: when the key went down alone (nil once anything else happened), and when the last tap ended.
    private var keyDown: TimeInterval?
    private var lastTap: TimeInterval?

    private var illustratorInFront: Bool { Illustrator.isIllustrator(NSWorkspace.shared.frontmostApplication) }

    /// Restarts the monitors (options changed, or the Accessibility permission did, so the key monitors can be added).
    func restart() { stop(); start() }

    private func start() {
        guard options.any, monitors.isEmpty else { return }
        // Key and modifier events reach a global monitor only with the Accessibility permission.
        if let flags = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.modifiersChanged(event) }
        }) { monitors.append(flags) }
        if let down = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.cancelTap() }
        }) { monitors.append(down) }
        if options.artboardPanel || options.gradientPanel {
            if let up = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .keyUp], handler: { [weak self] event in
                // ⌘ keys are commands, not tool shortcuts.
                if event.type == .keyUp, event.modifierFlags.contains(.command) { return }
                MainActor.assumeIsolated { self?.schedule() }
            }) { monitors.append(up) }
            // Read the tool as Illustrator comes forward, so the first switch afterwards is noticed.
            activation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                MainActor.assumeIsolated { if Illustrator.isIllustrator(app) { self?.schedule() } }
            }
            schedule()
        }
    }

    private func stop() {
        monitors.forEach(NSEvent.removeMonitor); monitors = []
        if let activation { NSWorkspace.shared.notificationCenter.removeObserver(activation) }
        activation = nil
        pending.forEach { $0.cancel() }; pending = []
        previousTool = nil
        cancelTap()
    }

    // MARK: Double tap

    private func cancelTap() { keyDown = nil; lastTap = nil }

    private func modifiersChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.shift, .control, .option, .command])
        // All modifiers released: a hotkey of another app (Keyboard Maestro) may have switched the tool.
        if flags.isEmpty { schedule(after: [Self.delay, Self.macroDelay]) }
        guard options.doubleTap else { return }
        if flags == options.tapKey.flag {
            keyDown = event.timestamp
        } else if flags.isEmpty, let down = keyDown {
            keyDown = nil
            guard event.timestamp - down <= Self.tapLength else { lastTap = nil; return }
            if let last = lastTap, down - last <= Self.tapGap {
                lastTap = nil
                if illustratorInFront { selectSelectionTool() }
            } else {
                lastTap = event.timestamp
            }
        } else {
            cancelTap()
        }
    }

    private func selectSelectionTool() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        queue.async {
            if case .failed(let message) = Illustrator.run(javascript: "app.selectTool('\(Self.selectTool)'); \"\"", in: app) {
                diagnostics.log("selectTool failed: \(message, privacy: .public)")
            }
        }
    }

    // MARK: Panels for the tool

    private func schedule(after delays: [TimeInterval] = [delay]) {
        guard options.artboardPanel || options.gradientPanel, illustratorInFront else { return }
        pending.forEach { $0.cancel() }
        pending = delays.map { delay in
            let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.checkTool() } }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            return work
        }
    }

    private func checkTool() {
        guard let app = NSWorkspace.shared.frontmostApplication, Illustrator.isIllustrator(app) else { return }
        if app.processIdentifier != previousPID { previousTool = nil; previousPID = app.processIdentifier }
        let options = options
        queue.async {
            guard case .output(let text) = Illustrator.run(javascript: "String(app.getSelectedToolName())", in: app) else { return }
            let tool = text.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    // Only a switch to the tool opens the panel; a panel closed while the tool stays is left closed.
                    let switched = self.previousTool != nil && self.previousTool != tool
                    self.previousTool = tool
                    guard switched, let panel = Self.panels.first(where: { $0.tool == tool }), options[keyPath: panel.option] else { return }
                    self.queue.async { Self.openPanel(command: panel.command, paths: panel.paths, in: app) }
                }
            }
        }
    }

    /// Window menu items toggle their panel, so the command runs only while the item has no checkmark (the panel is hidden).
    nonisolated private static func openPanel(command: String, paths: [[String]], in app: NSRunningApplication) {
        guard AXIsProcessTrusted() else { return }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 3)
        guard let item = InterfaceMenus.menuItem(root, paths: paths), !InterfaceMenus.isChecked(item) else { return }
        if case .failed(let message) = Illustrator.run(javascript: "app.executeMenuCommand('\(command)'); \"\"", in: app) {
            diagnostics.log("panel failed: \(message, privacy: .public)")
        }
    }
}
