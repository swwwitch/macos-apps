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
        verifyPaletteVisibility()
        verifyPaletteDisplayHotkey()
        verifySettingsDisplay()
        let bound = CommandRunner.boundSource(KeynoteScript.autoMagicMove.source(bundleID: "com.apple.iWork.Keynote"), documentID: "fixture-doc")
        precondition(bound.contains("if (id of front document as text) is not \"fixture-doc\" then error number -1728"))
        precondition(bound.contains("tell (first document whose id is \"fixture-doc\")"))
        let slideBound = CommandRunner.boundSource(KeynoteScript.slideSizeShape.source(bundleID: "com.apple.iWork.Keynote"), documentID: "fixture-doc", slideNumber: 2)
        precondition(slideBound.contains("if slide number of current slide is not 2 then error number -1728"))
        precondition(slideBound.contains("tell slide 2 to make new shape"))
        precondition(!KeynoteCommand.whiteBackground.steps.contains(.script(.selectLastTwo)))
        precondition(KeynoteCommand.whiteBackground.steps.filter { if case .script(.whiteBackgroundShape) = $0 { return true }; return false }.count == 1)
        var blockedResult: CommandOutcome?
        let blockedRunner = CommandRunner()
        blockedRunner.run(.whiteBackground, pid: 0, bundleID: "com.apple.iWork.Keynote", canContinue: { false }) { blockedResult = $0 }
        guard case .eventFailed? = blockedResult else { preconditionFailure("A blocked target must never create a background") }
        precondition(!blockedRunner.busy)
        print("PASS: 14 palette mappings and section headers; captured-document binding; blocked-target no-op and exact background creation route")
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


func verifyPaletteVisibility() {
    let expected: [[KeynoteCommand]] = [[.transitionDissolve, .transitionNone, .transitionMagicMove, .autoMagicMove], [.fillWidth, .fillHeight, .width80], [.sameHeight, .sameWidth, .sameWidthNarrowest], [.copyAnimation, .pasteAnimation], [.slideSizeShape, .whiteBackground]]
    precondition(PaletteCommands.groups == expected)
    precondition(Set(PaletteCommands.all).count == 14)
    let defaults = PaletteVisibility()
    precondition(defaults.groups.flatMap(\.commands) == expected.flatMap { $0 })
    precondition(defaults.groups.map(\.headingKey) == ["palette.transitionHeading", "palette.centerHeading", "palette.alignHeading", nil, nil])
    precondition(defaults.groups.map(\.dividerBefore) == [false, true, true, true, true])
    // Every possible visibility combination must retain order and hide empty headings.
    for mask in 0..<(1 << 14) {
        var visibility = PaletteVisibility()
        var visible: [KeynoteCommand] = []
        for (index, command) in PaletteCommands.all.enumerated() {
            let include = mask & (1 << index) != 0
            visibility.set(command, visible: include)
            if include { visible.append(command) }
        }
        precondition(visibility.groups.flatMap(\.commands) == visible)
        precondition(visibility.groups.allSatisfy { !$0.commands.isEmpty })
        precondition(visibility.groups.first?.dividerBefore != true)
    }
    let suite = "KeynoteMaestro-PaletteTests-" + UUID().uuidString
    let store = UserDefaults(suiteName: suite)!
    defer { store.removePersistentDomain(forName: suite) }
    let savedProfile = Data([1, 2, 3])
    store.set(savedProfile, forKey: "shortcutProfilesV1")
    store.set(Data([4, 5, 6]), forKey: "commandShortcuts")
    store.set(["fillWidth": false], forKey: "commandEnabled")
    precondition(PaletteVisibility.load(from: store).groups.flatMap(\.commands).count == 14)
    var visibility = PaletteVisibility()
    for command in PaletteCommands.all { visibility.set(command, visible: false) }
    visibility.save(to: store)
    precondition(PaletteVisibility.load(from: store).groups.isEmpty)
    visibility = PaletteVisibility.load(from: store)
    visibility.set(.sameWidth, visible: true)
    visibility.save(to: store)
    precondition(PaletteVisibility.load(from: store).groups == [VisiblePaletteGroup(id: 2, headingKey: "palette.alignHeading", commands: [.sameWidth], dividerBefore: false)])
    visibility.set(.fillWidth, visible: true)
    precondition(visibility.groups.map(\.dividerBefore) == [false, true])
    for command in PaletteCommands.all { visibility.set(command, visible: true) }
    visibility.save(to: store)
    precondition(PaletteVisibility.load(from: store) == PaletteVisibility())
    precondition(visibility == PaletteVisibility())
    precondition(store.data(forKey: "shortcutProfilesV1") == savedProfile)
    precondition(store.data(forKey: "commandShortcuts") == Data([4, 5, 6]))
    precondition(store.dictionary(forKey: "commandEnabled") as? [String: Bool] == ["fillWidth": false])
    print("PASS: palette initial 14 items, fixed order/headers/dividers across 16384 combinations, empty/all-off/re-enable, save/reload and shortcut-setting independence")
}


func verifySettingsDisplay() {
    for width in [260.0, 540, 619, 620, 700, 900, 1300] {
        let columns = StandardShortcutColumns(availableWidth: width)
        precondition(columns.operationWidth <= width && columns.bindingWidth <= width)
        if columns.stacked { precondition(columns.operationWidth == width && columns.bindingWidth == width) }
        else { precondition(columns.operationWidth + columns.spacing + columns.bindingWidth == width) }
    }
    precondition(StandardShortcutColumns(availableWidth: 540).stacked)
    precondition(!StandardShortcutColumns(availableWidth: 700).stacked)
    precondition(StandardShortcutColumns(availableWidth: 900).operationWidth > StandardShortcutColumns(availableWidth: 700).operationWidth)
    for command in CommandCategory.sweeper.commands {
        precondition(SpecialShortcutDisplay.title("操作（KeynoteSweeper）", command: command) == "操作")
        precondition(SpecialShortcutDisplay.title("Action (KeynoteSweeper)", command: command) == "Action")
        precondition(SpecialShortcutDisplay.title("작업(KeynoteSweeper)", command: command) == "작업")
        precondition(SpecialShortcutDisplay.title("KeynoteSweeperを使う操作", command: command) == "KeynoteSweeperを使う操作")
        precondition(command.steps.contains { if case .service = $0 { return true }; return false })
    }
    precondition(SpecialShortcutDisplay.title("追加操作：KeynoteSweeper", command: nil) == "追加操作：KeynoteSweeper")
    precondition(SpecialShortcutDisplay.title("Action (KeynoteSweeper)", command: .transitionNone) == "Action (KeynoteSweeper)")
    var old = PaletteVisibility(overrides: Dictionary(uniqueKeysWithValues: PaletteCommands.all.dropLast().map { ($0.rawValue, false) }))
    precondition(old.groups.flatMap(\.commands) == [.whiteBackground])
    old.set(.whiteBackground, visible: false)
    precondition(old.groups.isEmpty)
    print("PASS: standard variable columns at narrow/normal/wide widths, no overflow in width allocation; six special-only Sweeper suffixes removed with service routes retained; new background button defaults on after upgrade")
}

func verifyPaletteDisplayHotkey() {
    let suite = "KeynoteMaestro-PaletteHotkey-" + UUID().uuidString
    let store = UserDefaults(suiteName: suite)!
    defer { store.removePersistentDomain(forName: suite) }
    let protectedKeys = ["shortcutProfilesV1", "commandShortcuts", "commandEnabled", "paletteVisibilityV1", "excludedBundleIDs"]
    for key in protectedKeys { store.set("sentinel", forKey: key) }
    precondition(PaletteDisplayHotkey.load(from: store).combo == nil)
    let key = KeyCombo(code: 35, modifiers: UInt32(controlKey | optionKey | cmdKey))
    let assigned = PaletteDisplayHotkey(combo: key)
    assigned.save(to: store)
    precondition(PaletteDisplayHotkey.load(from: store) == assigned)
    precondition(PaletteDisplayHotkey.conflict(for: key, among: [("feature", key)]) == "feature")
    precondition(PaletteDisplayHotkey.conflict(for: KeyCombo(code: 35, modifiers: UInt32(cmdKey)), among: [("feature", key)]) == nil)
    PaletteDisplayHotkey().save(to: store)
    precondition(store.object(forKey: PaletteDisplayHotkey.storageKey) == nil)
    precondition(PaletteDisplayHotkey.load(from: store).combo == nil)
    let malformed = Data([0, 1, 2])
    store.set(malformed, forKey: PaletteDisplayHotkey.storageKey)
    precondition(PaletteDisplayHotkey.load(from: store).combo == nil)
    precondition(store.data(forKey: PaletteDisplayHotkey.storageKey) == malformed)
    for key in protectedKeys { precondition(store.string(forKey: key) == "sentinel") }
    precondition(KeynoteHotkeyScope.permits("com.apple.Keynote"))
    precondition(KeynoteHotkeyScope.permits("com.apple.iWork.Keynote"))
    for app in [nil, "com.apple.finder", "jp.dtp-transit.keynotehelper", "com.apple.Keynote.other"] {
        precondition(!KeynoteHotkeyScope.permits(app))
    }
    precondition(PaletteDisplayHotkey.registrationID > 203 && PaletteDisplayHotkey.registrationID < 10_000)
    print("PASS: independent palette hotkey unset/save/reload/clear/corrupt preservation, duplicate detection and exact Keynote scope")
}
