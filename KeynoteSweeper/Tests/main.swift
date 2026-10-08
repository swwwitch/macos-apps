import AppKit

// ./test.sh            unit tests
// ./test.sh --keynote  also cleans a scratch presentation in the real Keynote
//                      (Automation and Accessibility permission for the terminal required)
var failures = 0
func check(_ condition: Bool, _ name: String) {
    print((condition ? "PASS: " : "FAIL: ") + name)
    if !condition { failures += 1 }
}

// Plan
check(SweepPlan.unusedLayoutIndexes(layouts: ["A", "B", "C", "D"], used: ["B"]) == [4, 3, 1], "unused layouts are listed last first")
check(SweepPlan.unusedLayoutIndexes(layouts: ["A", "B"], used: []) == [], "never removes every layout")
check(SweepPlan.unusedLayoutIndexes(layouts: ["A", "B", "A"], used: ["A"]) == [2], "a used name keeps every layout of that name")
check(SweepPlan.unusedLayoutIndexes(layouts: [], used: []) == [], "empty presentation")
check(SweepPlan.steps(from: 10, to: 4) == -6 && SweepPlan.steps(from: 2, to: 5) == 3, "arrow steps")
check(SweepPlan.layoutName(fromInspectorTitle: "スライドレイアウトを編集: タイトル&画像") == "タイトル&画像", "layout name from Japanese title")
check(SweepPlan.layoutName(fromInspectorTitle: "Edit Slide Layout: A: B") == "A: B", "layout name keeps later colons")
check(SweepPlan.layoutName(fromInspectorTitle: "アピアランス") == nil, "other text is not a layout name")

let snapshot = KeynoteSnapshot(documentID: "x", documentName: "Deck", layouts: ["Title", "Photo", "Quote", "Blank"],
                               slideLayouts: ["Title", "Photo", "Quote"], skipped: [false, true, false])
check(snapshot.hiddenCount == 1 && !snapshot.allHidden, "hidden slide count")
check(snapshot.unusedLayoutIndexes(ignoringHidden: false) == [4], "hidden slides still use their layout")
check(snapshot.unusedLayoutIndexes(ignoringHidden: true) == [4, 2], "layouts of slides about to be deleted count as unused")
check(KeynoteSnapshot(documentID: "", documentName: "", layouts: ["A"], slideLayouts: ["A"], skipped: [true]).allHidden, "all hidden")
let withTransitions = KeynoteSnapshot(documentID: "", documentName: "", layouts: ["A"], slideLayouts: ["A", "A", "A"], skipped: [false, true, false], transitions: [true, true, false])
check(withTransitions.transitionCount(ignoringHidden: false) == 2 && withTransitions.transitionCount(ignoringHidden: true) == 1, "transitions on hidden slides about to be deleted are not counted")

if CommandLine.arguments.contains("--keynote") {
    precondition(Thread.isMainThread)
    func script(_ source: String) throws -> NSAppleEventDescriptor { try KeynoteDOM.run(source) }
    let fixture = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("KeynoteSweeper-fixture-\(ProcessInfo.processInfo.processIdentifier).key")
    defer { try? FileManager.default.removeItem(at: fixture) }
    do {
        // A saved fixture with one hidden slide, opened the way a dropped file is.
        _ = try script("""
        tell application id "com.apple.Keynote"
            set d to make new document
            tell d
                make new slide with properties {base layout:slide layout "引用"}
                make new slide with properties {base layout:slide layout "空白"}
                make new slide with properties {base layout:slide layout "写真"}
                set skipped of slide 4 to true
                set transition properties of slide 1 to {transition effect:dissolve, transition duration:1.5, transition delay:2, automatic transition:true}
                set transition properties of slide 2 to {transition effect:magic move, transition duration:1.0, transition delay:0, automatic transition:false}
            end tell
            save d in POSIX file "\(fixture.path)"
            close d saving no
        end tell
        """)
        let id = try KeynoteDOM.open(fixture)
        // Another presentation in front: the target must be found by id, not by position.
        let other = try script("tell application id \"com.apple.Keynote\" to return id of (make new document)").stringValue ?? ""
        let before = try KeynoteDOM.snapshot(documentID: id)!
        let front = try KeynoteDOM.snapshot()?.documentID
        check(before.hiddenCount == 1 && front == other, "fixture found by id while another presentation is in front")
        let otherLayouts = try KeynoteDOM.snapshot(documentID: other)!.layouts.count
        let sweeper = Sweeper()
        let start = Date()
        let result = sweeper.run(SweepOptions(deleteUnusedLayouts: true, deleteHiddenSlides: true, removeTransitions: true), documentID: id) { _, _ in }
        let elapsed = Date().timeIntervalSince(start)
        let after = try KeynoteDOM.snapshot(documentID: id)!
        print(String(format: "  %.2fs, deleted %d slides, %d layouts, skipped %@, error %@", elapsed, result.deletedSlides, result.deletedLayouts.count,
                     result.skippedLayouts.description, String(describing: result.error)))
        check(result.error == nil && result.skippedLayouts.isEmpty, "sweep finished without errors")
        check(result.deletedSlides == 1 && after.hiddenCount == 0 && after.skipped.count == 3, "hidden slide deleted")
        check(Set(after.layouts) == Set(after.slideLayouts) && after.layouts.count == 3, "only used layouts remain")
        check(result.deletedLayouts.count == before.layouts.count - 3, "deleted layout count matches")
        check(before.transitionCount(ignoringHidden: true) == 2 && result.removedTransitions == 2 && !after.transitions.contains(true), "transitions removed")
        let kept = try script("tell application id \"com.apple.Keynote\" to tell document id \"\(id)\" to return transition properties of slide 1")
        check(kept.forKeyword(AEKeyword(0x78617574))?.booleanValue == true && kept.forKeyword(AEKeyword(0x78646c79))?.doubleValue == 2, "auto-advance and delay kept")
        let otherAfter = try KeynoteDOM.snapshot(documentID: other)!.layouts.count
        check(otherAfter == otherLayouts, "the other presentation is untouched")
        let unchanged = sweeper.run(SweepOptions(deleteUnusedLayouts: true, deleteHiddenSlides: true), documentID: id) { _, _ in }
        check(unchanged.error == nil && unchanged.deletedLayouts.isEmpty && unchanged.deletedSlides == 0, "second run has nothing to do")
        let missing = sweeper.run(SweepOptions(deleteUnusedLayouts: true, deleteHiddenSlides: true), documentID: "missing") { _, _ in }
        check(missing.error == .noDocument, "a closed presentation is reported, not replaced by the front one")
        _ = try script("tell application id \"com.apple.Keynote\" to close document id \"\(id)\" saving no")
        _ = try script("tell application id \"com.apple.Keynote\" to close document id \"\(other)\" saving no")
        let saved = try KeynoteDOM.open(fixture)
        let reopened = try KeynoteDOM.snapshot(documentID: saved)!.hiddenCount
        check(reopened == 1, "the file on disk is unchanged until saved")
        _ = try script("tell application id \"com.apple.Keynote\" to close document id \"\(saved)\" saving no")
    } catch {
        check(false, "Keynote run: \(error.localizedDescription)")
    }
}


// ./test.sh --builds <sample.key>: removes object animations from a temporary copy of a presentation that has builds.
if let flag = CommandLine.arguments.firstIndex(of: "--builds"), CommandLine.arguments.count > flag + 1 {
    let sample = URL(fileURLWithPath: CommandLine.arguments[flag + 1])
    let copy = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("KeynoteSweeper-builds-\(ProcessInfo.processInfo.processIdentifier).key")
    defer { try? FileManager.default.removeItem(at: copy) }
    do {
        try FileManager.default.copyItem(at: sample, to: copy)
        let id = try KeynoteDOM.open(copy)
        let before = try KeynoteDOM.snapshot(documentID: id)!
        try KeynoteDOM.setCurrentSlide(documentID: id, 2)
        let start = Date()
        let result = Sweeper().run(SweepOptions(deleteUnusedLayouts: false, deleteHiddenSlides: false, removeBuilds: true), documentID: id) { _, _ in }
        print(String(format: "  %.2fs, %d builds on %d of %d slides, error %@", Date().timeIntervalSince(start), result.removedBuilds, result.buildSlides,
                     before.skipped.count, String(describing: result.error)))
        check(result.error == nil && result.removedBuilds > 0, "object animations removed")
        check(try KeynoteDOM.currentSlide(documentID: id) == 2, "the slide shown before is shown again")
        let again = Sweeper().run(SweepOptions(deleteUnusedLayouts: false, deleteHiddenSlides: false, removeBuilds: true), documentID: id) { _, _ in }
        check(again.error == nil && again.removedBuilds == 0, "no object animations left")
        let after = try KeynoteDOM.snapshot(documentID: id)!
        check(after.skipped.count == before.skipped.count && after.layouts == before.layouts, "slides and masters untouched")
        _ = try KeynoteDOM.run("tell application id \"com.apple.Keynote\" to close document id \"\(id)\" saving no")
    } catch {
        check(false, "builds run: \(error.localizedDescription)")
    }
}

print(failures == 0 ? "ALL PASS" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
