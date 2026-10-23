import Foundation

enum StandardShortcutSet: String, CaseIterable, Codable {
    case system, custom, custom2
    var title: String { NSLocalizedString("profiles.set." + rawValue, comment: "") }
    var isEditable: Bool { self != .system }
}

enum ShortcutDomain: String {
    case standard, special
    var title: String { NSLocalizedString("profiles." + rawValue, comment: "") }
    func includes(_ row: ShortcutRow) -> Bool { self == .standard ? row.native != nil : row.native == nil }
}

extension KeynoteCommand {
    /// Native-equivalent commands only. Compound/app-specific actions retain their own special bindings.
    static let standardCommands: Set<KeynoteCommand> = [.bringForward, .bringToFront, .collapse, .expand, .firstSlide, .fitSlide, .fontBigger, .fontSmaller, .goToSlide, .group, .hideInspector, .lastSlide, .loosen, .newDocument, .newSlide, .nextSlide, .objectList, .pasteMatchStyle, .previousSlide, .saveAs, .sendBackward, .sendToBack, .skipSlide, .textCenter, .textJustify, .textLeft, .textRight, .tighten, .ungroup, .zoomIn, .zoomOut, .zoomToContent]
    var isStandard: Bool { Self.standardCommands.contains(self) }
}

struct StandardShortcutPreset: Codable, Equatable {
    var shortcuts: [String: Shortcut] = [:]
    var enabled: [String: Bool] = [:]
    var nativeBindings: [String: KeyCombo] = [:]
    init() {}
    private enum CodingKeys: String, CodingKey { case shortcuts, enabled, nativeBindings }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        shortcuts = try values.decodeIfPresent([String: Shortcut].self, forKey: .shortcuts) ?? [:]
        enabled = try values.decodeIfPresent([String: Bool].self, forKey: .enabled) ?? [:]
        nativeBindings = try values.decodeIfPresent([String: KeyCombo].self, forKey: .nativeBindings) ?? [:]
    }
}

struct ShortcutProfiles: Codable, Equatable {
    static let storageKey = "shortcutProfilesV1"
    var selected = StandardShortcutSet.system
    var specialEnabled = true
    var custom = StandardShortcutPreset()
    var custom2 = StandardShortcutPreset()

    static func migrating(shortcuts: [String: Shortcut], enabled: [String: Bool], existingInstallation: Bool) -> Self {
        var profiles = Self()
        profiles.custom.shortcuts = shortcuts.filter { KeynoteCommand(rawValue: $0.key)?.isStandard == true }
        profiles.custom.enabled = enabled.filter { KeynoteCommand(rawValue: $0.key)?.isStandard == true }
        // Keep the previous effective keys on upgrade, including users who kept all old defaults.
        if existingInstallation { profiles.selected = .custom }
        return profiles
    }
    var preset: StandardShortcutPreset {
        get { selected == .custom2 ? custom2 : custom }
        set {
            guard selected.isEditable else { return }
            if selected == .custom2 { custom2 = newValue } else { custom = newValue }
        }
    }
    func shortcut(_ command: KeynoteCommand, special: [String: Shortcut]) -> Shortcut {
        (command.isStandard ? preset.shortcuts[command.rawValue] : special[command.rawValue]) ?? command.defaultShortcut
    }
    func isEnabled(_ command: KeynoteCommand, special: [String: Bool]) -> Bool {
        guard command.isAvailable else { return false }
        return (command.isStandard ? selected.isEditable : specialEnabled) && configuredEnabled(command, special: special)
    }
    func configuredEnabled(_ command: KeynoteCommand, special: [String: Bool]) -> Bool {
        guard command.isAvailable else { return false }
        return (command.isStandard ? preset.enabled[command.rawValue] : special[command.rawValue]) ?? command.enabledByDefault
    }
    mutating func setShortcut(_ command: KeynoteCommand, _ shortcut: Shortcut) {
        guard command.isStandard, selected.isEditable else { return }
        var value = preset
        value.shortcuts[command.rawValue] = shortcut == command.defaultShortcut ? nil : shortcut
        preset = value
    }
    mutating func setEnabled(_ command: KeynoteCommand, _ enabled: Bool) {
        guard command.isStandard, selected.isEditable else { return }
        var value = preset
        value.enabled[command.rawValue] = enabled
        preset = value
    }
    mutating func setNativeBinding(_ id: String, _ combo: KeyCombo?) {
        guard selected.isEditable else { return }
        var value = preset; value.nativeBindings[id] = combo; preset = value
    }
    func nativeBinding(_ id: String) -> KeyCombo? { selected.isEditable ? preset.nativeBindings[id] : nil }
    mutating func resetCurrentStandardKeys() {
        guard selected.isEditable else { return }
        var value = preset; value.shortcuts = [:]; value.nativeBindings = [:]; preset = value
    }
}
