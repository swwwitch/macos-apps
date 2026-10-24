import AppKit

@main struct PaletteShapeIntegration {
    @MainActor static func main() {
        do { try test() }
        catch { fputs("FAIL: palette shape integration: \(error)\n", stderr); exit(1) }
    }
    @MainActor static func test() throws {
        let _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let bundleID = "com.apple.iWork.Keynote"
        func execute(_ source: String) throws -> String {
            try CommandRunner.runScriptProcess("with timeout of 15 seconds\n" + source + "\nend timeout").get().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let id = try execute("tell application id \"\(bundleID)\" to return id of (make new document) as text")
        print("Palette shape fixture document:", id); fflush(stdout)
        defer { _ = try? execute("tell application id \"\(bundleID)\" to close (first document whose id is \"\(id)\") saving no") }
        let start = "tell application id \"\(bundleID)\"\ntell (first document whose id is \"\(id)\")\n"
        let end = "\nend tell\nend tell"
        _ = try execute(start + """
            make new slide at end of slides
            repeat with s in slides
                delete every iWork item of s
            end repeat
            set current slide to slide 1
            """ + end)
        print("PASS: fixture setup"); fflush(stdout)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { throw NSError(domain: "KeynoteNotRunning", code: -1) }
        app.activate()
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        guard let target = CommandRunner.paletteTarget(bundleID: bundleID), target.documentID == id, target.slideNumber == 1 else { throw NSError(domain: "WrongPaletteContext", code: -1) }
        print("PASS: palette target", target); fflush(stdout)
        let runner = CommandRunner()
        var outcome: CommandOutcome?
        runner.run(.slideSizeShape, pid: app.processIdentifier, bundleID: bundleID, documentID: target.documentID, slideNumber: target.slideNumber,
                   canContinue: { NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier }) { outcome = $0 }
        guard case .scripted(1)? = outcome, !runner.busy else { throw NSError(domain: "ShapeOutcome", code: -1, userInfo: [NSLocalizedDescriptionKey: String(describing: outcome)]) }
        print("PASS: one command invocation", String(describing: outcome)); fflush(stdout)
        let verified = try execute(start + """
            if (count shapes of slide 1) is not 1 then error "Expected exactly one new shape"
            if (count iWork items of slide 2) is not 0 then error "Another slide changed"
            set o to shape 1 of slide 1
            set slideWidth to width
            set slideHeight to height
            if (width of o) is not slideWidth or (height of o) is not slideHeight then error "Shape does not match slide size"
            set p to position of o
            if item 1 of p is not 0 or item 2 of p is not 0 then error "Shape is not at slide origin"
            if opacity of o is not 100 then error "Wrong opacity"
            set current slide to slide 2
            return "verified"
            """ + end)
        guard verified == "verified" else { throw NSError(domain: "ShapeVerify", code: -1) }
        // A slide changed after the click: both the runner and bound script must stop.
        var rejected: CommandOutcome?
        runner.run(.slideSizeShape, pid: app.processIdentifier, bundleID: bundleID, documentID: id, slideNumber: 1) { rejected = $0 }
        guard case .eventFailed? = rejected else { throw NSError(domain: "ChangedSlideNotRejected", code: -1) }
        let bound = CommandRunner.boundSource(KeynoteScript.slideSizeShape.source(bundleID: bundleID), documentID: id, slideNumber: 1)
        guard case .failure(let error) = CommandRunner.runScript(bound), error.code == -1728 else { throw NSError(domain: "BoundSlideNotRejected", code: -1) }
        let counts = try execute(start + "return ((count shapes of slide 1) as text) & \":\" & ((count shapes of slide 2) as text)" + end)
        guard counts == "1:0" else { throw NSError(domain: "ChangedSlideModified", code: -1) }
        print("PASS: real Keynote palette context: one slide-sized shape at origin on captured slide, other slide unchanged; runner and bound script reject a changed slide")
    }
}
