import AppKit

/// JavaScript sent to one InDesign process with `do script … language javascript` (event K2  /dosc, language JSLg).
/// Addressed by pid, so the InDesign in front is used even when several versions run (they share com.adobe.InDesign).
enum InDesignScript {
    private static func code(_ text: String) -> UInt32 { text.utf8.reduce(UInt32(0)) { $0 << 8 | UInt32($1) } }

    /// The script's result as text, or nil (no answer within `timeout`, an error, or no Automation permission).
    /// The first call asks for the Automation consent and returns nil (`.neverInteract` cannot show it).
    /// Blocks the calling thread: call it off the main thread.
    static func run(_ javascript: String, pid: pid_t, timeout: TimeInterval) -> String? {
        let target = NSAppleEventDescriptor(processIdentifier: pid)
        if let desc = target.aeDesc,
           AEDeterminePermissionToAutomateTarget(desc, code("K2  "), code("dosc"), false) == errAEEventWouldRequireUserConsent {
            _ = AEDeterminePermissionToAutomateTarget(desc, code("K2  "), code("dosc"), true)
            return nil
        }
        let event = NSAppleEventDescriptor(eventClass: code("K2  "), eventID: code("dosc"), targetDescriptor: target,
                                           returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(NSAppleEventDescriptor(string: javascript), forKeyword: keyDirectObject)
        event.setParam(NSAppleEventDescriptor(enumCode: code("JSLg")), forKeyword: code("doLg"))
        guard let reply = try? event.sendEvent(options: [.waitForReply, .neverInteract], timeout: timeout) else { return nil }
        return reply.paramDescriptor(forKeyword: keyDirectObject)?.stringValue
    }

    /// UITools TYPE_TOOL, TYPE_ON_PATH_TOOL, VERTICAL_TYPE_TOOL, VERTICAL_TYPE_ON_PATH_TOOL (current while text is edited).
    static let typingScript = "(function () { try { return /TYPE/.test(String(app.toolBoxTools.currentTool)) ? \"1\" : \"0\"; } catch (e) { return \"0\"; } })();"

    /// Whether Space would be typed. No answer in time (a dialog box, a long command, no permission) counts as typing.
    static func isTyping(_ pid: pid_t) -> Bool { run(typingScript, pid: pid, timeout: 0.3) != "0" }

    /// Switches to the Selection tool (leaves text editing).
    static func selectSelectionTool(_ pid: pid_t) {
        _ = run("app.toolBoxTools.currentTool = UITools.SELECTION_TOOL; \"\"", pid: pid, timeout: 3)
    }
}
