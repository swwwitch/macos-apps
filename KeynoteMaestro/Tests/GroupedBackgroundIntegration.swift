import AppKit

/// Own unsaved document only. Exercise the production runner, including its AX menu steps.
@main struct GroupedBackgroundIntegration {
    @MainActor static func main() {
        do { try test() }
        catch { fputs("FAIL: background integration: \(error)\n", stderr); exit(1) }
    }
    @MainActor static func test() throws {
        let _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let bundleID = "com.apple.iWork.Keynote"
        func execute(_ source: String) throws -> String {
            try CommandRunner.runScriptProcess("with timeout of 15 seconds\n" + source + "\nend timeout").get().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let id = try execute("tell application id \"\(bundleID)\" to return id of (make new document) as text")
        defer { _ = try? execute("tell application id \"\(bundleID)\" to close (first document whose id is \"\(id)\") saving no") }
        let start = "tell application id \"\(bundleID)\"\ntell (first document whose id is \"\(id)\")\n"
        let end = "\nend tell\nend tell"
        print("Background fixture document:", id); fflush(stdout)
        // Initialize NSWorkspace's running-app snapshot on the AppKit run loop.
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { throw NSError(domain: "KeynoteNotRunning", code: -1) }
        app.activate()
        // A newly-created document finishes its initial UI selection asynchronously.
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        for originalIndex in 1...3 {
            _ = try execute(start + """
                set s to slide 1
                delete every iWork item of s
                repeat with i from 1 to 3
                    if i is \(originalIndex) then
                        tell s to make new shape with properties {object text:"ORIGINAL", position:{100,100}, width:200, height:80}
                    else
                        tell s to make new shape with properties {object text:("OTHER" & i), position:{(400 + i * 100),300}, width:100, height:60}
                    end if
                end repeat
                set current slide to s
                set selection to {shape \(originalIndex) of s}
                """ + end)
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            let runner = CommandRunner()
            var outcome: CommandOutcome?
            var duplicateReports = 0
            guard let target = CommandRunner.paletteTarget(bundleID: bundleID), target.documentID == id, target.slideNumber == 1 else { throw NSError(domain: "BackgroundPaletteTarget", code: originalIndex) }
            runner.run(.whiteBackground, pid: app.processIdentifier, bundleID: bundleID, documentID: target.documentID, slideNumber: target.slideNumber,
                       canContinue: { NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier }) { outcome = $0 }
            // A second invocation while the command is in flight must create nothing.
            runner.run(.whiteBackground, pid: app.processIdentifier, bundleID: bundleID) { _ in duplicateReports += 1 }
            let deadline = Date().addingTimeInterval(15)
            while runner.busy && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
            guard case .scripted(1)? = outcome, !runner.busy, duplicateReports == 0 else { throw NSError(domain: "BackgroundOutcome", code: originalIndex, userInfo: [NSLocalizedDescriptionKey: String(describing: outcome)]) }
            let verified = try execute(start + """
                set s to slide 1
                if (count iWork items of s) is not 3 then error "Unexpected top-level objects"
                if (count groups of s) is not 1 then error "Missing group"
                if (count shapes of s) is not 2 then error "Unrelated objects were grouped"
                set g to group 1 of s
                if (count iWork items of g) is not 2 then error "Background created more than once"
                if (object text of shape 1 of g as text) is not "" then error "Background is not behind original"
                if (object text of shape 2 of g as text) is not "ORIGINAL" then error "Wrong original grouped"
                repeat with o in (get shapes of g)
                    if width of o is not 200 or height of o is not 80 then error "Frame changed"
                    if opacity of o is not 100 then error "Opacity changed"
                end repeat
                set groupPosition to position of g
                if item 1 of groupPosition is not 100 or item 2 of groupPosition is not 100 then error "Group moved"
                repeat with o in (get shapes of s)
                    if (object text of o as text) does not start with "OTHER" then error "Wrong object left outside"
                    if width of o is not 100 or height of o is not 60 then error "Unrelated dimensions changed"
                end repeat
                return "verified"
                """ + end)
            guard verified == "verified" else { throw NSError(domain: "BackgroundVerify", code: originalIndex) }
        }
        print("PASS: real Keynote production palette background command with captured document/slide, original at back/middle/front; exactly one background, behind original, exact two-member group; unrelated shapes preserved; busy duplicate ignored")
    }
}
