import AppKit

/// JavaScript sent to one InDesign process with `do script … language javascript` (event K2  /dosc, language JSLg).
/// Addressed by pid, so the InDesign in front is used even when several versions run (they share com.adobe.InDesign).
enum InDesignScript {
    private static func code(_ text: String) -> UInt32 { text.utf8.reduce(UInt32(0)) { $0 << 8 | UInt32($1) } }

    enum Failure: Error {
        case permissionDenied
        case noReply
    }

    static func run(_ javascript: String, pid: pid_t, timeout: TimeInterval) -> String? {
        try? send(javascript, pid: pid, timeout: timeout)
    }

    /// Blocks the calling thread, including while the user responds to the first Automation prompt.
    static func send(_ javascript: String, pid: pid_t, timeout: TimeInterval) throws -> String {
        let target = NSAppleEventDescriptor(processIdentifier: pid)
        guard let desc = target.aeDesc else { throw Failure.noReply }
        let eventClass = code("K2  ")
        let eventID = code("dosc")
        var permission = AEDeterminePermissionToAutomateTarget(desc, eventClass, eventID, false)
        if permission == errAEEventWouldRequireUserConsent {
            permission = AEDeterminePermissionToAutomateTarget(desc, eventClass, eventID, true)
        }
        if permission == errAEEventNotPermitted { throw Failure.permissionDenied }
        let event = NSAppleEventDescriptor(eventClass: eventClass, eventID: eventID, targetDescriptor: target,
                                           returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(NSAppleEventDescriptor(string: javascript), forKeyword: keyDirectObject)
        event.setParam(NSAppleEventDescriptor(enumCode: code("JSLg")), forKeyword: code("doLg"))
        let reply: NSAppleEventDescriptor
        do {
            reply = try event.sendEvent(options: [.waitForReply, .neverInteract], timeout: timeout)
        } catch let error as NSError where error.code == Int(errAEEventNotPermitted) {
            throw Failure.permissionDenied
        }
        let replyError = reply.paramDescriptor(forKeyword: keyErrorNumber)?.int32Value ?? 0
        if replyError == errAEEventNotPermitted { throw Failure.permissionDenied }
        guard replyError == 0, let result = reply.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            throw Failure.noReply
        }
        return result
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
