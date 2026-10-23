import AppKit
import Carbon

/// Default keys are the KM macros' triggers, distinct, and every command has steps.
@main struct CommandTests {
    static func main() {
        let all = KeynoteCommand.allCases
        precondition(all.count == 104, "\(all.count)")
        precondition(Set(all.map(\.defaultShortcut.signature)).count == all.count, "duplicate default keys")
        precondition(all.allSatisfy { !$0.steps.isEmpty })
        precondition(Array(all.suffix(2)) == [.whiteRectangle, .autoMagicMove])
        precondition(CommandCategory.allCases.flatMap(\.commands).count == all.count)
        // The guide is reference data only: all saved command IDs occur exactly once in the comparison.
        let catalog = try! ShortcutCatalog(contentsOf: URL(fileURLWithPath: "Resources/NativeShortcuts.json"))
        verifyShortcutProfiles(catalog)
        verifyNativeActions(catalog)
        verifyAutoMagicMove()
        precondition(catalog.native.count == 341)
        precondition(Set(catalog.native.map(\.section)).count == 14)
        precondition(catalog.rows.count == 410)
        precondition(Set(catalog.rows.map(\.id)).count == catalog.rows.count)
        precondition(catalog.rows.compactMap(\.command).count == 103)
        precondition(Set(catalog.rows.compactMap(\.command)) == Set(KeynoteCommand.availableCommands))
        precondition(ShortcutSection.allCases.flatMap(\.commands).count == 103)
        precondition(catalog.rows.filter(ShortcutScope.native.includes).count == 339)
        precondition(catalog.rows.filter(ShortcutScope.maestro.includes).count == 103)
        precondition(catalog.rows.filter { $0.native?.title == "「カラー」ウインドウを表示する" }.count == 1)
        precondition(catalog.rows.filter { $0.native?.title == "オブジェクトリストを表示する/非表示にする" }.count == 1)
        let group = catalog.rows.first { $0.command == .group }!
        precondition(group.native?.shortcut == "Option＋Command＋G" && group.section == .objects)
        precondition(group.matches("command+option+g", currentKey: KeynoteCommand.group.defaultShortcut.label))
        precondition(group.matches("⌥⌘G", currentKey: nil))
        precondition(group.matches("グループ化", currentKey: nil))
        precondition(group.matches("⌘G", currentKey: KeynoteCommand.group.defaultShortcut.label))
        precondition(!group.matches("存在しない操作", currentKey: nil))
        precondition(group.matches("  ", currentKey: nil))
        precondition(catalog.rows.first { $0.command == .zoomToSelection }!.native == nil,
                     "Compound fit-and-zoom-out must not claim the native fit-only shortcut")
        precondition(catalog.rows.first { $0.command == .whiteRectangle }!.section == .objects)
        precondition(catalog.rows.first { $0.command == .textLeft }!.section == .textFormat)
        precondition(!KeynoteCommand.play.isAvailable && KeynoteCommand.availableCommands.count == 103)
        precondition(catalog.rows.first { $0.command == .play } == nil)
        precondition(catalog.rows.first { $0.native?.id == "presentation.00" }?.command == nil)
        precondition(catalog.rows.first { $0.native?.id == "presentation.00" }?.native?.shortcut == "Option＋Command＋P")
        precondition(catalog.rows.first { $0.command == .skipSlide }!.section == .navigator)
        let nativeOnly = catalog.rows.first { $0.native?.id == "tables.62" }!
        precondition(nativeOnly.command == nil && nativeOnly.matches("セルを結合", currentKey: nil))
        precondition(!ShortcutScope.maestro.includes(nativeOnly))
        print("PASS: 341 reference entries, 14 original categories, 32 equivalent joins, 103 available commands, 104 retained IDs, filters and native/current-key searches")
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
        let duplicateInPlace = catalog.rows.first { $0.command == .duplicate }!
        precondition(duplicateInPlace.native == nil && duplicateInPlace.section == .objects)
        let standardDuplicate = catalog.rows.first { $0.native?.id == "objects.25" }!
        precondition(standardDuplicate.command == nil && standardDuplicate.native?.shortcut == "Command＋DまたはOptionキーを押したままドラッグ")
        precondition(KeynoteCommand.duplicate.defaultShortcut.signature == "2:2048")
        precondition(KeynoteCommand.duplicate.steps == [
            .menu([path(["編集", "Edit"], ["選択部分を複製", "Duplicate Selection"])]), .wait(0.1),
            .key(123, KeynoteCommand.arrowFlags.union(.maskShift)),
            .key(126, KeynoteCommand.arrowFlags.union(.maskShift))])
        precondition(KeynoteCommand.duplicate.defaultShortcut.typesCharacter && !KeynoteCommand.hide.defaultShortcut.typesCharacter)
        precondition(KeynoteCommand.tighten.worksWhileTyping && !KeynoteCommand.opacity10.worksWhileTyping)
        // Menu titles: 「PDF...」 and 「PDF…」 match; a toggling item matches either title.
        precondition(MenuTitle.any(["PDF…"]).matches("PDF..."))
        precondition(MenuTitle.any(["ガイドを表示", "ガイドを非表示"]).matches("ガイドを非表示"))
        precondition(KeynoteCommand.whiteRectangle.defaultShortcut.code == 29)
        precondition(KeynoteCommand.whiteRectangle.defaultShortcut.modifiers == UInt32(controlKey | optionKey | cmdKey))
        precondition(KeynoteCommand.slideSizeShape.defaultShortcut.code == 29)
        precondition(KeynoteCommand.slideSizeShape.defaultShortcut.modifiers == UInt32(controlKey))
        // AppleScript identifiers are case-insensitive: slide size never uses W/H next to w/h.
        for command in all {
            for case .script(let job) in command.steps {
                let source = job.source(bundleID: Bundle(url: NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iWork.Keynote") ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Keynote")!)!.bundleIdentifier!)
                var error: NSDictionary?
                let compiled = NSAppleScript(source: source)?.compileAndReturnError(&error) == true
                if !compiled { print("SCRIPT_COMPILE_ERROR", command.rawValue, error as Any); fflush(stdout) }
                precondition(compiled, "\(command.rawValue) does not compile")
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
        print("PASS: 104 stable command definitions, 103 available commands (6 KeynoteSweeper services; only ⌃⌥0 on by default) with distinct KM keys, steps, menu matching, AppleScript compiles, PNG naming")
    }
}
