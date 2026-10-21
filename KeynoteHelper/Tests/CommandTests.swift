import AppKit
import Carbon

/// Default keys are the KM macros' triggers, distinct, and every command has steps.
@main struct CommandTests {
    static func main() {
        let all = KeynoteCommand.allCases
        precondition(all.count == 102, "\(all.count)")
        precondition(Set(all.map(\.defaultShortcut.signature)).count == all.count, "duplicate default keys")
        precondition(all.allSatisfy { !$0.steps.isEmpty })
        precondition(CommandCategory.allCases.flatMap(\.commands).count == all.count)
        // Spot checks against Keynote Macros.kmmacros (KeyCode:KM modifiers).
        let km: [KeynoteCommand: String] = [.bringToFront: "30:2304", .exportPNG: "14:2304", .hide: "20:256", .showHidden: "20:2304",
            .opacity10: "18:512", .opacity90: "25:512", .opacity100: "29:512", .opacity100Alt: "50:512", .scale90: "43:2304", .scale200: "19:4096",
            .widthPlus: "24:6400", .fillWidth: "18:2304", .width80: "50:2304", .sweepTransitionsExceptMagicMove: "29:6144", .centerCross: "24:2816"]
        for (command, key) in km { precondition(command.defaultShortcut.signature == key, command.rawValue) }
        precondition(CommandCategory.sweeper.commands.count == 6 && CommandCategory.sweeper.commands.allSatisfy { $0.serviceNames.count == 4 }
                     && CommandCategory.sweeper.commands.filter(\.enabledByDefault) == [.sweepTransitionsExceptMagicMove])
        precondition(KeynoteCommand.group.enabledByDefault)
        precondition(CommandCategory.opacity.commands.first == .opacity10 && CommandCategory.opacity.commands.suffix(2) == [.opacity100, .opacity100Alt]
                     && KeynoteCommand.opacity100Alt.steps == KeynoteCommand.opacity100.steps)
        precondition(KeynoteCommand.opacity50.opacityPercent == 50 && KeynoteCommand.group.opacityPercent == nil)
        precondition(KeynoteCommand.duplicate.defaultShortcut.typesCharacter && !KeynoteCommand.hide.defaultShortcut.typesCharacter)
        precondition(KeynoteCommand.tighten.worksWhileTyping && !KeynoteCommand.opacity10.worksWhileTyping)
        // Menu titles: 「PDF...」 and 「PDF…」 match; a toggling item matches either title.
        precondition(MenuTitle.any(["PDF…"]).matches("PDF..."))
        precondition(MenuTitle.any(["ガイドを表示", "ガイドを非表示"]).matches("ガイドを非表示"))
        // AppleScript identifiers are case-insensitive: slide size never uses W/H next to w/h.
        for command in all {
            for case .script(let job) in command.steps {
                let source = job.source(bundleID: "com.apple.Keynote")
                precondition(NSAppleScript(source: source)?.compileAndReturnError(nil) == true, "\(command.rawValue) does not compile")
            }
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        precondition(CommandRunner.freeName("deck-p003", in: folder).lastPathComponent == "deck-p003.png")
        FileManager.default.createFile(atPath: folder.appendingPathComponent("deck-p003.png").path, contents: Data())
        precondition(CommandRunner.freeName("deck-p003", in: folder).lastPathComponent == "deck-p003-2.png")
        for name in ["deck.010.png", "deck.002.png", "deck.001.png"] { FileManager.default.createFile(atPath: folder.appendingPathComponent("sub/" + name).path, contents: nil) }
        try? FileManager.default.createDirectory(at: folder.appendingPathComponent("sub"), withIntermediateDirectories: true)
        for name in ["deck.010.png", "deck.002.png", "deck.001.png"] { FileManager.default.createFile(atPath: folder.appendingPathComponent("sub/" + name).path, contents: Data()) }
        precondition(CommandRunner.slideImages(in: folder.appendingPathComponent("sub")).map(\.lastPathComponent) == ["deck.001.png", "deck.002.png", "deck.010.png"])
        try? FileManager.default.removeItem(at: folder)
        print("PASS: 102 commands (6 KeynoteSweeper services; only ⌃⌥0 on by default) with distinct KM keys, steps, menu matching, AppleScript compiles, PNG naming")
    }
}
