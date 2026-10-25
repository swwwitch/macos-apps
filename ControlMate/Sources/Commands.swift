import CoreGraphics
import Foundation

/// Modifiers besides the trigger (⌃ or Caps Lock): what a command needs, and what a replacement key carries.
struct Mods: OptionSet, Hashable {
    let rawValue: Int
    static let shift = Mods(rawValue: 1)
    static let command = Mods(rawValue: 2)
    static let option = Mods(rawValue: 4)

    init(rawValue: Int) { self.rawValue = rawValue }
    /// ⇧⌘⌥ of a key event. Control, Caps Lock, Fn and the keypad flag are left out (the trigger is judged separately).
    init(_ flags: CGEventFlags) {
        var mods: Mods = []
        if flags.contains(.maskShift) { mods.insert(.shift) }
        if flags.contains(.maskCommand) { mods.insert(.command) }
        if flags.contains(.maskAlternate) { mods.insert(.option) }
        self = mods
    }
    var flags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.option) { flags.insert(.maskAlternate) }
        return flags
    }
    var symbols: String { (contains(.option) ? "⌥" : "") + (contains(.shift) ? "⇧" : "") + (contains(.command) ? "⌘" : "") }
}

/// One key the app receives instead of the pressed one. Codes are macOS virtual key codes (kVK_*).
struct Stroke: Equatable {
    var code: Int64
    var mods: Mods = []
    var label: String
    /// Arrows, Home/End, Page Up and Forward Delete carry the Fn flag (and arrows the keypad flag), as the real keys do.
    var flags: CGEventFlags {
        var flags = mods.flags
        if [115, 116, 117, 119, 121, 123, 124, 125, 126].contains(code) { flags.insert(.maskSecondaryFn) }
        if (123...126).contains(code) { flags.insert(.maskNumericPad) }
        return flags
    }
}

enum Action: Equatable {
    /// Replaced in the event tap: every stroke but the last is typed on key down, the last follows the key (repeat and release).
    case keys([Stroke])
    case killToLineEnd, killToLineStart, yank, selectParagraph, moveParagraphUp, moveParagraphDown
    /// ⌃A / ⌃E: start / end of the paragraph, as macOS's own ⌃A / ⌃E; with ⇧ the selection is extended.
    case paragraphStart, paragraphEnd
    /// Selects with the strokes, then cuts into the kill buffer (for apps whose text Accessibility cannot read).
    case killSelecting([Stroke])
    /// InDesign's ⌃K: runs the user's script (deletes to the paragraph end, keeps a trailing 「。」); without it, killSelecting.
    case inDesignScript(path: String, fallback: [Stroke])
    /// Not available in this app; the reason shows as the last command.
    case unsupported
}

/// The four categories of the 「キー」 settings and the main window.
enum KeyCategory: String, CaseIterable, Identifiable {
    case cursor, keySend, editing, killYank
    var id: String { rawValue }
}

/// The three groups of the 「キー」 settings. Each has its own list of apps where its keys pass through unchanged.
enum KeyGroup: String, CaseIterable, Identifiable {
    case basic, assist, paragraph
    var id: String { rawValue }
    var passthroughKey: String { "passthrough." + rawValue }
}

struct Command: Identifiable, Equatable {
    var id: String
    var key: Int64
    var keyLabel: String
    /// Needed besides the trigger.
    var mods: Mods = []
    /// ⇧ may be added; it then goes on to the replacement (⌃⇧F selects one character to the right).
    var carriesShift = false
    var group: KeyGroup
    var category: KeyCategory
    /// One of macOS's own Emacs keys (デフォルト); the others are ControlMate's additions (拡張).
    var standard = false
    /// Handled by ControlMate even in the group's pass-through apps (only the excluded apps get it unchanged):
    /// ⌃K and ⌃Y share ControlMate's kill buffer with ⌃X in every app.
    var ignoresPassthrough = false
    var action: Action
    var label: String { "⌃" + mods.symbols + keyLabel }
}

enum CommandTable {
    static let right = Stroke(code: 124, label: "→"), left = Stroke(code: 123, label: "←")
    static let down = Stroke(code: 125, label: "↓"), up = Stroke(code: 126, label: "↑")

    static let all: [Command] = [
        // カーソル移動
        Command(id: "forward", key: 3, keyLabel: "F", carriesShift: true, group: .basic, category: .cursor, standard: true, action: .keys([right])),
        Command(id: "backward", key: 11, keyLabel: "B", carriesShift: true, group: .basic, category: .cursor, standard: true, action: .keys([left])),
        Command(id: "next", key: 45, keyLabel: "N", carriesShift: true, group: .basic, category: .cursor, standard: true, action: .keys([down])),
        Command(id: "previous", key: 35, keyLabel: "P", carriesShift: true, group: .basic, category: .cursor, standard: true, action: .keys([up])),
        Command(id: "lineStart", key: 0, keyLabel: "A", carriesShift: true, group: .basic, category: .cursor, standard: true, action: .paragraphStart),
        Command(id: "lineEnd", key: 14, keyLabel: "E", carriesShift: true, group: .basic, category: .cursor, standard: true, action: .paragraphEnd),
        Command(id: "pageUp", key: 32, keyLabel: "U", group: .basic, category: .cursor, action: .keys([Stroke(code: 116, label: "Page Up")])),
        Command(id: "home", key: 43, keyLabel: ",", group: .assist, category: .cursor, action: .keys([Stroke(code: 115, label: "Home")])),
        Command(id: "end", key: 47, keyLabel: ".", group: .assist, category: .cursor, action: .keys([Stroke(code: 119, label: "End")])),
        // キー送信
        Command(id: "escape", key: 5, keyLabel: "G", group: .basic, category: .keySend, action: .keys([Stroke(code: 53, label: "Esc")])),
        Command(id: "tab", key: 34, keyLabel: "I", carriesShift: true, group: .basic, category: .keySend, action: .keys([Stroke(code: 48, label: "Tab")])),
        Command(id: "enter", key: 46, keyLabel: "M", group: .assist, category: .keySend, action: .keys([Stroke(code: 76, label: "Enter")])),
        Command(id: "confirmRight", key: 38, keyLabel: "J", group: .assist, category: .keySend, action: .keys([Stroke(code: 36, label: "Return"), right])),
        // テキスト編集
        Command(id: "deleteForward", key: 2, keyLabel: "D", group: .basic, category: .editing, standard: true, action: .keys([Stroke(code: 117, label: "⌦")])),
        Command(id: "moveParagraphUp", key: 126, keyLabel: "↑", mods: .shift, group: .paragraph, category: .editing, action: .moveParagraphUp),
        Command(id: "moveParagraphDown", key: 125, keyLabel: "↓", mods: .shift, group: .paragraph, category: .editing, action: .moveParagraphDown),
        Command(id: "selectParagraph", key: 1, keyLabel: "S", group: .paragraph, category: .editing, action: .selectParagraph),
        Command(id: "copyToLineStart", key: 7, keyLabel: "X", mods: .command, group: .assist, category: .editing,
                action: .keys([Stroke(code: 123, mods: [.shift, .command], label: "⇧⌘←"), Stroke(code: 8, mods: .command, label: "⌘C")])),
        Command(id: "copyToLineEnd", key: 6, keyLabel: "Z", mods: .command, group: .assist, category: .editing,
                action: .keys([Stroke(code: 124, mods: [.shift, .command], label: "⇧⌘→"), Stroke(code: 8, mods: .command, label: "⌘C")])),
        Command(id: "copyToTextEnd", key: 6, keyLabel: "Z", mods: [.option, .command], group: .assist, category: .editing,
                action: .keys([Stroke(code: 125, mods: [.shift, .command], label: "⇧⌘↓"), Stroke(code: 8, mods: .command, label: "⌘C")])),
        // Kill/Yank
        Command(id: "killLine", key: 40, keyLabel: "K", group: .basic, category: .killYank, standard: true, ignoresPassthrough: true, action: .killToLineEnd),
        Command(id: "killToLineStart", key: 7, keyLabel: "X", group: .paragraph, category: .killYank, action: .killToLineStart),
        Command(id: "yank", key: 16, keyLabel: "Y", group: .basic, category: .killYank, standard: true, ignoresPassthrough: true, action: .yank),
    ]

    /// Rows of the 「キー」 table: one function, with its macOS key (デフォルト) and ControlMate's key (拡張) side by side.
    struct Row: Identifiable {
        var id: String
        var standard: Command?
        var extended: Command?
    }
    static func rows(in category: KeyCategory) -> [Row] {
        var rows: [Row] = []
        for command in all where command.category == category {
            rows.append(Row(id: command.id, standard: command.standard ? command : nil, extended: command.standard ? nil : command))
        }
        return rows
    }

    static func commands(in group: KeyGroup) -> [Command] { all.filter { $0.group == group } }
    static func commands(in category: KeyCategory) -> [Command] { all.filter { $0.category == category } }

    /// The command for a key pressed with the trigger, among the ones in use.
    static func match(code: Int64, mods: Mods, in commands: [Command]) -> Command? {
        commands.first { $0.key == code && ($0.mods == mods || ($0.carriesShift && $0.mods.union(.shift) == mods)) }
    }

    /// What a command does in one app instead of the usual.
    enum Override: Equatable {
        /// The app's own keys (or another way of doing it).
        case action(Action)
        /// Left to the app (or to Keyboard Maestro): the key is not replaced.
        case skip
    }

    static let copy = Stroke(code: 8, mods: .command, label: "⌘C")
    static let paragraphUpSelect = Stroke(code: 126, mods: [.shift, .command], label: "⇧⌘↑")
    static let paragraphDownSelect = Stroke(code: 125, mods: [.shift, .command], label: "⇧⌘↓")
    /// The user's InDesign script for ⌃K (same as the former Keyboard Maestro macro).
    static let inDesignKillScript = NSString(string: "~/Git/indesign-scripts/jsx/text/IdDeleteFromCursorToEnd.jsx").expandingTildeInPath

    static let overrides: [String: [String: Override]] = [
        "com.microsoft.VSCode": ["moveParagraphUp": .action(.keys([Stroke(code: 126, mods: .option, label: "⌥↑")])),
                                 "moveParagraphDown": .action(.keys([Stroke(code: 125, mods: .option, label: "⌥↓")]))],
        // InDesign: ⌘← / ⌘→ move by word and the text cannot be read through Accessibility, so InDesign's own keys are used
        // (⇧⌘↑ / ⇧⌘↓ select to the paragraph start / end, Home / End go to the line start / end).
        // ⌃U and ⌃M stay with Keyboard Maestro's InDesign macros.
        "com.adobe.InDesign": [
            "lineStart": .action(.keys([paragraphUpSelect, left])),
            "lineEnd": .action(.keys([paragraphDownSelect, right, left])),
            "copyToLineStart": .action(.keys([Stroke(code: 115, mods: .shift, label: "⇧Home"), copy])),
            "copyToLineEnd": .action(.keys([Stroke(code: 119, mods: .shift, label: "⇧End"), copy])),
            "copyToTextEnd": .action(.keys([Stroke(code: 119, mods: [.shift, .command], label: "⇧⌘End"), copy])),
            "selectParagraph": .action(.keys([paragraphUpSelect, left, paragraphDownSelect, copy])),
            "killLine": .action(.inDesignScript(path: inDesignKillScript, fallback: [paragraphDownSelect, Stroke(code: 123, mods: .shift, label: "⇧←")])),
            "killToLineStart": .action(.killSelecting([paragraphUpSelect])),
            "moveParagraphUp": .action(.unsupported),
            "moveParagraphDown": .action(.unsupported),
            "pageUp": .skip,
            "enter": .skip,
        ],
    ]

    /// The commands for one app: native keys swapped in, groups passed through and commands turned off left out.
    static func resolved(bundleID: String?, passthrough: [KeyGroup: [String]], disabled: Set<String>) -> [Command] {
        let native = bundleID.flatMap { id in overrides.first { $0.key.caseInsensitiveCompare(id) == .orderedSame }?.value } ?? [:]
        return all.compactMap { command in
            guard !disabled.contains(command.id) else { return nil }
            if !command.ignoresPassthrough, let bundleID, passthrough[command.group]?.contains(where: { $0.caseInsensitiveCompare(bundleID) == .orderedSame }) == true { return nil }
            var command = command
            switch native[command.id] {
            case .skip: return nil
            case .action(let action): command.action = action
            case nil: break
            }
            return command
        }
    }

    /// First-launch lists: apps that already have the keys or use ⌃ for their own work.
    static let initialPassthrough: [KeyGroup: [String]] = [
        .basic: ["com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox", "com.apple.finder", "com.cocoatech.PathFinder",
                 "com.cocoatech.PathFinder-setapp", "com.microsoft.Excel", "com.adobe.Photoshop", "com.apple.iWork.Keynote",
                 "com.panic.Transmit", "notion.id", "com.ecamm.EcammLive"],
        .assist: ["com.apple.iWork.Keynote", "com.apple.Keynote", "net.telestream.screenflow8", "com.microsoft.Powerpoint", "com.adobe.xd",
                  "com.microsoft.Excel", "com.stairways.keyboardmaestro.editor", "com.adobe.Acrobat.Pro", "com.microsoft.VSCode",
                  "com.apple.finder", "com.cocoatech.PathFinder", "com.cocoatech.PathFinder-setapp", "com.adobe.Photoshop"],
        .paragraph: ["com.google.Chrome", "org.mozilla.firefox", "com.microsoft.Word", "notion.id", "com.stairways.keyboardmaestro.editor"],
    ]
    /// The shared 「対象外アプリ」 list: nothing is replaced in these.
    static let initialExcluded = ["com.adobe.illustrator"]
}

/// The key held instead of ⌃, chosen separately for JIS and other keyboards.
enum TriggerKey: String, CaseIterable, Identifiable {
    case control, capsLock, both
    var id: String { rawValue }
    var usesControl: Bool { self != .capsLock }
    var usesCapsLock: Bool { self != .control }
    func pressed(control: Bool, capsLock: Bool) -> Bool { (usesControl && control) || (usesCapsLock && capsLock) }
}
