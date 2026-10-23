import AppKit

/// Optional real-Keynote smoke test. Only its newly-created, unsaved document is addressed/closed.
@main struct AutoMagicMoveIntegration {
    static func main() {
        do { try run() }
        catch {
            fputs("FAIL: Auto Magic Move integration: \(error)\n", stderr)
            exit(1)
        }
    }
    static func run() throws {
        let bundleID = "com.apple.iWork.Keynote"
        let token = UUID().uuidString
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("KeynoteMaestro-AutoMagicMove-" + token)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let image = folder.appendingPathComponent("shared-image.png")
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for x in 0..<8 { for y in 0..<8 { bitmap.setColor(NSColor(deviceRed: 1, green: 0.6, blue: 0, alpha: 1), atX: x, y: y) } }
        try bitmap.representation(using: .png, properties: [:])!.write(to: image)
        func execute(_ source: String) throws -> NSAppleEventDescriptor {
            var info: NSDictionary?
            guard let script = NSAppleScript(source: source) else { throw NSError(domain: "Integration", code: -2700) }
            let result = script.executeAndReturnError(&info)
            if let info { throw NSError(domain: "Integration", code: info[NSAppleScript.errorNumber] as? Int ?? -2700, userInfo: [NSLocalizedDescriptionKey: String(describing: info)]) }
            return result
        }
        let created = try execute("""
        tell application id "\(bundleID)"
            set testDoc to make new document
            return id of testDoc as text
        end tell
        """)
        guard let id = created.stringValue, !id.isEmpty else { throw NSError(domain: "Integration", code: -1) }
        defer {
            _ = try? execute("""
            tell application id "\(bundleID)"
                if exists (first document whose id is "\(id)") then close (first document whose id is "\(id)") saving no
            end tell
            """)
        }
        let target = "(first document whose id is \"\(id)\")"
        _ = try execute("""
        tell application id "\(bundleID)"
            tell \(target)
                repeat while (count slides) < 16
                    make new slide at end of slides
                end repeat
                repeat with s in slides
                    delete every iWork item of s
                    set transition properties of s to {transition effect:dissolve, transition duration:1.3, transition delay:0.4, automatic transition:true}
                    set skipped of s to false
                end repeat
                repeat with n in {2, 5, 8, 10, 13, 16}
                    set skipped of slide (contents of n) to true
                end repeat
                repeat with n in {1, 2, 3}
                    tell slide (contents of n) to make new shape with properties {object text:"A", width:100, height:40}
                end repeat
                tell slide 4 to make new shape with properties {object text:"B", width:100, height:40}
                tell slide 5 to make new shape with properties {object text:"B", width:100, height:40}
                tell slide 6 to make new shape with properties {object text:"B", width:200, height:80}
                tell slide 7 to make new shape with properties {object text:"", width:100.2, height:40.2}
                tell slide 8 to make new shape with properties {object text:"different", width:300, height:100}
                tell slide 9 to make new shape with properties {object text:"", width:99.8, height:39.8}
                tell slide 10 to make new shape with properties {object text:"", width:100, height:40}
                repeat with n in {11, 12, 13}
                    tell slide (contents of n) to make new image with properties {file:(POSIX file "\(image.path)")}
                end repeat
                repeat with n in {14, 15, 16}
                    tell slide (contents of n) to make new text item with properties {object text:"Shared text"}
                end repeat
            end tell
        end tell
        """)
        // Bind only this test wrapper to the captured document; production body/helpers are unchanged.
        let source = AutoMagicMoveScript.source(bundleID: bundleID).replacingOccurrences(of: "tell front document", with: "tell " + target)
        let result = try CommandRunner.runScriptProcess(source).get()
        guard AutoMagicMoveResult(output: result) == .completed(5) else {
            throw NSError(domain: "Integration", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unexpected result: \(result)"])
        }
        let verified = try execute("""
        tell application id "\(bundleID)"
            tell \(target)
                repeat with n from 1 to 16
                    set s to slide n
                    set p to transition properties of s
                    if {1, 4, 7, 11, 14} contains n then
                        if transition effect of p is not magic move then error "Matched slide effect was not set"
                        if (my abs((transition duration of p) - 0.7)) > 0.001 then error "Wrong Magic Move duration"
                    else
                        if transition effect of p is not dissolve then error "An unmatched/skipped/last slide changed"
                        if (my abs((transition duration of p) - 1.3)) > 0.001 then error "An unmatched duration changed"
                    end if
                    if automatic transition of p is not true then error "Automatic transition was changed"
                    if (my abs((transition delay of p) - 0.4)) > 0.001 then error "Transition delay was changed"
                    if {2, 5, 8, 10, 13, 16} contains n then
                        if skipped of s is not true then error "A skipped flag was changed"
                    else
                        if skipped of s is not false then error "A shown slide was skipped"
                    end if
                end repeat
                return "verified"
            end tell
        end tell
        on abs(n)
            if n < 0 then return -n
            return n
        end abs
        """)
        guard verified.stringValue == "verified" else { throw NSError(domain: "Integration", code: -3) }
        print("PASS: real Keynote 16-slide fixture; five matches across shapes/text/images; skipped/unmatched/last effects, delays and automatic flags preserved")
    }
}
