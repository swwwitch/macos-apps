import Foundation

func verifyShortcutProfiles(_ catalog: ShortcutCatalog) {
    let standard = catalog.rows.filter(ShortcutDomain.standard.includes)
    let special = catalog.rows.filter(ShortcutDomain.special.includes)
    precondition(standard.count == 339 && special.count == 71)
    precondition(Set(standard.map(\.id)).isDisjoint(with: Set(special.map(\.id))))
    precondition(Set(standard.compactMap(\.command)) == KeynoteCommand.standardCommands)
    precondition(KeynoteCommand.standardCommands.count == 32)
    precondition(special.allSatisfy { $0.command != nil && !$0.command!.isStandard })
    precondition(special.contains { $0.command == .duplicate } && special.contains { $0.command == .whiteRectangle })

    let changed = Shortcut(0, km: 4096 | 256)
    let second = Shortcut(11, km: 4096 | 256)
    let specialKey = Shortcut(3, km: 4096 | 256)
    let legacyKeys: [String: Shortcut] = ["group": changed, "duplicate": specialKey, "play": second]
    let legacyEnabled = ["group": false, "duplicate": false, "play": true]
    var profiles = ShortcutProfiles.migrating(shortcuts: legacyKeys, enabled: legacyEnabled, existingInstallation: true)
    precondition(profiles.selected == .custom)
    precondition(profiles.shortcut(.group, special: legacyKeys) == changed)
    precondition(!profiles.isEnabled(.group, special: legacyEnabled))
    precondition(profiles.shortcut(.duplicate, special: legacyKeys) == specialKey)
    precondition(!profiles.isEnabled(.duplicate, special: legacyEnabled))
    precondition(!profiles.isEnabled(.play, special: legacyEnabled))
    precondition(profiles.custom.shortcuts.keys.sorted() == ["group"])

    precondition(!profiles.configuredEnabled(.autoMagicMove, special: legacyEnabled))
    precondition(!profiles.isEnabled(.autoMagicMove, special: legacyEnabled))
    let custom = profiles.custom
    profiles.selected = .custom2
    precondition(profiles.shortcut(.group, special: legacyKeys) == KeynoteCommand.group.defaultShortcut)
    precondition(profiles.isEnabled(.group, special: legacyEnabled))
    profiles.setShortcut(.group, second)
    profiles.setEnabled(.group, false)
    precondition(profiles.custom == custom)
    profiles.selected = .custom
    precondition(profiles.shortcut(.group, special: legacyKeys) == changed)
    profiles.setEnabled(.group, true)
    precondition(profiles.isEnabled(.group, special: legacyEnabled))
    profiles.specialEnabled = false
    precondition(!profiles.isEnabled(.slideSizeShape, special: [:]))
    precondition(profiles.configuredEnabled(.slideSizeShape, special: [:]))
    precondition(profiles.isEnabled(.group, special: legacyEnabled))
    profiles.specialEnabled = true
    profiles.selected = .system
    precondition(KeynoteCommand.standardCommands.allSatisfy { !profiles.isEnabled($0, special: [:]) })
    precondition(profiles.isEnabled(.slideSizeShape, special: [:]))
    let beforeDefaultEdit = profiles
    profiles.setShortcut(.group, second)
    profiles.setEnabled(.group, false)
    profiles.resetCurrentStandardKeys()
    precondition(profiles == beforeDefaultEdit)

    profiles.selected = .custom
    profiles.resetCurrentStandardKeys()
    precondition(profiles.custom.shortcuts.isEmpty && profiles.custom.enabled["group"] == true)
    precondition(profiles.custom2.shortcuts["group"] == second && profiles.custom2.enabled["group"] == false)
    precondition(profiles.shortcut(.duplicate, special: legacyKeys) == specialKey)
    let data = try! JSONEncoder().encode(profiles)
    precondition(try! JSONDecoder().decode(ShortcutProfiles.self, from: data) == profiles)
    let fresh = ShortcutProfiles.migrating(shortcuts: [:], enabled: [:], existingInstallation: false)
    precondition(fresh.selected == .system && fresh.specialEnabled)
    print("PASS: disjoint standard/special tabs, 32/71 command split, migration, independent custom sets, default pass-through, special switch, reset scope and persistence")
}
