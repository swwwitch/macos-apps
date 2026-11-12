import Foundation

/// The Appearance feature's strings, under "fx." in Localizable.strings.
func FX(_ key: String) -> String { L("fx." + key) }

/// Palette sections in the order of the original palette (its numbered headers 00–95).
enum PaletteSection: String, CaseIterable {
    case stylize, threeD, path, pathfinder, shape, distort, misc, release, compoundShape, compoundPath, caps
    var title: String { FX("section." + rawValue) }
}

/// A key in Carbon terms (kVK_* code; ⌘256 ⇧512 ⌥2048 ⌃4096), kept free of AppKit for the tests.
struct DefaultKey: Equatable {
    let code: UInt32
    let modifiers: UInt32
    static let shift: UInt32 = 512, command: UInt32 = 256, option: UInt32 = 2048, control: UInt32 = 4096
}

/// A command's color, from Finder's standard tag palette (an app label, never a file tag).
enum ItemTag: String, CaseIterable {
    case red, orange, yellow, green, blue, purple, gray
    var title: String { FX("color." + rawValue) }
}

/// Values the user can change for an effect applied without its dialog box.
enum ParamKind: Equatable {
    /// In the document's units, like the effect dialog boxes.
    case length
    case percent
    case count
    case toggle
    /// Offset Path corners: 0 round, 1 bevel, 2 miter (the Dict's jntp).
    case join
}

struct ParamSpec: Equatable {
    let key: String
    let kind: ParamKind
    let defaultValue: Double
    let range: ClosedRange<Double>
    var title: String { FX("param." + key) }
}

/// Live effects built from values (no dialog box). `dialog` is the Effect menu command used instead with Option.
enum EffectKind: Equatable {
    case dropShadow, offsetPath, rectangle, roundedRectangle, ellipse, zigzag, roughen
    var dialog: String {
        switch self {
        case .dropShadow: return "Live Adobe Drop Shadow"
        case .offsetPath: return "Live Offset Path"
        case .rectangle: return "Live Rectangle"
        case .roundedRectangle: return "Live Rounded Rectangle"
        case .ellipse: return "Live Ellipse"
        case .zigzag: return "Live Zig Zag"
        case .roughen: return "Live Roughen"
        }
    }
}

enum CommandAction: Equatable {
    /// app.executeMenuCommand. Effect commands with "..." open their dialog box.
    case menu(String, dialog: Bool)
    case effect(EffectKind)
    /// Built-in ExtendScript run on the selection.
    case code(BuiltInCode)
    /// A one-event action loaded from text, run and unloaded again.
    case action(TempAction)
    /// An action of the user's own action set (Window › Actions).
    case namedAction(set: String, name: String)
    /// A script file; the path can be changed in the main window.
    case script(defaultPath: String)
}

enum BuiltInCode: Equatable {
    case cap(String)          // StrokeCap.BUTTENDCAP etc.
    /// Height 0 → Pathfinder Outline → 1 pt round caps: an open line.
    case openPath
    case pasteLastStyle           // the document's last graphic style
    case expandUngroup            // Expand Appearance, ungroup, deselect
}

struct Command: Equatable {
    let id: String
    let section: PaletteSection
    let action: CommandAction
    var params: [ParamSpec] = []
    var defaultKey: DefaultKey? = nil
    /// A script file that opens its own dialog box (or palette) before doing anything.
    var dialogScript = false
    var title: String { FX("cmd." + id) }
    /// The title with "…" when a dialog box opens, as macOS menus do.
    var displayTitle: String { title + (opensDialog ? "…" : "") }
    var opensDialog: Bool {
        if case .menu(_, let dialog) = action { return dialog }
        return dialogScript
    }
    /// Effects with values: Option (or the second button) opens Illustrator's dialog box instead.
    var dialogAlternative: String? {
        if case .effect(let kind) = action { return kind.dialog }
        return nil
    }
    var scriptPath: String? {
        if case .script(let path) = action { return path }
        return nil
    }
}

private func key(_ code: UInt32, _ modifiers: UInt32 = DefaultKey.shift) -> DefaultKey { DefaultKey(code: code, modifiers: modifiers) }
private func length(_ key: String, _ value: Double) -> ParamSpec { ParamSpec(key: key, kind: .length, defaultValue: value, range: -1000...1000) }

enum Catalog {
    /// Keys follow the original palette; they work only while the palette is shown and Illustrator is in front.
    static let all: [Command] = [
        Command(id: "roundCorners", section: .stylize, action: .menu("Live Adobe Round Corners", dialog: true), defaultKey: key(15)),       // ⇧R
        Command(id: "dropShadow", section: .stylize, action: .effect(.dropShadow),
                params: [ParamSpec(key: "opacity", kind: .percent, defaultValue: 30, range: 0...100), length("offsetX", 2), length("offsetY", 2),
                         ParamSpec(key: "blur", kind: .length, defaultValue: 2, range: 0...1000)], defaultKey: key(2)),                      // ⇧D
        Command(id: "warp", section: .stylize, action: .menu("Live Deform Arc", dialog: true), defaultKey: key(9)),                          // ⇧V
        Command(id: "extrude3D", section: .threeD, action: .menu("Live Adobe Geometry3D Extrude", dialog: true), defaultKey: key(20, 0)),   // 3
        Command(id: "revolve3D", section: .threeD, action: .menu("Live Adobe Geometry3D Revolve", dialog: true)),
        Command(id: "rotate3D", section: .threeD, action: .menu("Live Adobe Geometry3D Rotate", dialog: true)),
        Command(id: "outlineObject", section: .path, action: .menu("Live Outline Object", dialog: false), defaultKey: key(37)),               // ⇧L
        Command(id: "outlineStroke", section: .path, action: .menu("Live Outline Stroke", dialog: false), defaultKey: key(31)),               // ⇧O
        Command(id: "offsetPath", section: .path, action: .effect(.offsetPath),
                params: [length("offset", 1), ParamSpec(key: "join", kind: .join, defaultValue: 2, range: 0...2)], defaultKey: key(1)),      // ⇧S
        Command(id: "pfAdd", section: .pathfinder, action: .menu("Live Pathfinder Add", dialog: false), defaultKey: key(35)),                 // ⇧P
        Command(id: "pfIntersect", section: .pathfinder, action: .menu("Live Pathfinder Intersect", dialog: false)),
        Command(id: "pfExclude", section: .pathfinder, action: .menu("Live Pathfinder Exclude", dialog: false)),
        Command(id: "pfSubtract", section: .pathfinder, action: .menu("Live Pathfinder Subtract", dialog: false)),
        Command(id: "pfMinusBack", section: .pathfinder, action: .menu("Live Pathfinder Minus Back", dialog: false)),
        Command(id: "pfDivide", section: .pathfinder, action: .menu("Live Pathfinder Divide", dialog: false)),
        Command(id: "pfMerge", section: .pathfinder, action: .menu("Live Pathfinder Merge", dialog: false), defaultKey: key(5)),              // ⇧G
        Command(id: "pfOutline", section: .pathfinder, action: .menu("Live Pathfinder Outline", dialog: false)),
        Command(id: "pfCrop", section: .pathfinder, action: .menu("Live Pathfinder Crop", dialog: false), defaultKey: key(8)),                // ⇧C
        Command(id: "rectangle", section: .shape, action: .effect(.rectangle),
                params: [length("extraWidth", 0), length("extraHeight", 0)], defaultKey: key(14)),                                       // ⇧E
        Command(id: "ellipse", section: .shape, action: .effect(.ellipse), params: [length("extraWidth", 0), length("extraHeight", 0)]),
        Command(id: "roundedRectangle", section: .shape, action: .effect(.roundedRectangle),
                params: [length("extraWidth", 0), length("extraHeight", 0), ParamSpec(key: "cornerRadius", kind: .length, defaultValue: 1, range: 0...1000)]),
        Command(id: "zigzag", section: .distort, action: .effect(.zigzag),
                params: [ParamSpec(key: "size", kind: .length, defaultValue: 0, range: 0...1000), ParamSpec(key: "ridges", kind: .count, defaultValue: 1, range: 0...100),
                         ParamSpec(key: "smooth", kind: .toggle, defaultValue: 0, range: 0...1)]),
        Command(id: "zigzagFlat", section: .distort, action: .effect(.zigzag),
                params: [ParamSpec(key: "size", kind: .length, defaultValue: 0, range: 0...1000), ParamSpec(key: "ridges", kind: .count, defaultValue: 0, range: 0...100),
                         ParamSpec(key: "smooth", kind: .toggle, defaultValue: 0, range: 0...1)], defaultKey: key(38)),                       // ⇧J
        Command(id: "freeDistort", section: .distort, action: .menu("Live Free Distort", dialog: true)),
        Command(id: "freeDistortScript", section: .distort, action: .script(defaultPath: "~/Git/ai-scripts/jsx/fx/SmartFreeDistort.jsx"), defaultKey: key(3), dialogScript: true), // ⇧F
        Command(id: "puckerBloat", section: .distort, action: .menu("Live Pucker & Bloat", dialog: true)),
        Command(id: "roughen", section: .distort, action: .effect(.roughen),
                params: [ParamSpec(key: "size", kind: .length, defaultValue: 0, range: 0...1000), ParamSpec(key: "detail", kind: .count, defaultValue: 9, range: 0...100),
                         ParamSpec(key: "smooth", kind: .toggle, defaultValue: 1, range: 0...1)]),
        Command(id: "scribbleTweak", section: .distort, action: .menu("Live Scribble and Tweak", dialog: true)),
        Command(id: "transform", section: .distort, action: .menu("Live Transform", dialog: true), defaultKey: key(17)),                     // ⇧T
        Command(id: "twist", section: .distort, action: .menu("Live Twist", dialog: true)),
        Command(id: "pasteLastStyle", section: .misc, action: .code(.pasteLastStyle),
                defaultKey: key(9, DefaultKey.control | DefaultKey.option | DefaultKey.command)),                                         // ⌃⌥⌘V
        Command(id: "duplicateItem", section: .misc, action: .action(.appearance(value: 3, name: "項目を複製")), defaultKey: key(24, 0)),     // =
        Command(id: "removeItem", section: .misc, action: .action(.appearance(value: 4, name: "項目を削除")), defaultKey: key(27, 0)),        // -
        Command(id: "sketchy", section: .misc, action: .script(defaultPath: "~/Git/ai-scripts/jsx/fx/KPTSketchyPalette.jsx"), defaultKey: key(40), dialogScript: true), // ⇧K
        Command(id: "rasterize", section: .misc, action: .menu("Live Rasterize", dialog: true)),
        Command(id: "strokeScale", section: .misc, action: .script(defaultPath: "~/sw Dropbox/takano masahiro/sync-setting/ai/スクリプト/stroke/resize-all-stroke-width-master/すべての線幅を変更.jsx"), dialogScript: true),
        Command(id: "openPath", section: .misc, action: .code(.openPath)),
        Command(id: "clearAppearance", section: .release, action: .action(.appearance(value: 6, name: "アピアランスを消去"))),
        Command(id: "clearKeepFill", section: .release, action: .script(defaultPath: "~/Git/ai-scripts/jsx/fx/ClearAppearance.jsx"),
                defaultKey: key(51, DefaultKey.option | DefaultKey.shift), dialogScript: true),                                                                 // ⌥⇧⌫
        Command(id: "expandAppearance", section: .release, action: .script(defaultPath: "~/Git/ai-scripts/jsx/misc/ExpandAppearanceEachObject.jsx"),
                defaultKey: key(31, DefaultKey.option | DefaultKey.shift | DefaultKey.command)),                                            // ⌥⇧⌘O
        Command(id: "expandUngroup", section: .release, action: .code(.expandUngroup)),
        Command(id: "knockout", section: .release, action: .namedAction(set: "S2A", name: "グループの抜き"),
                defaultKey: key(5, DefaultKey.option | DefaultKey.command)),                                                                // ⌥⌘G
        Command(id: "makeCompoundShape", section: .compoundShape, action: .action(.makeCompoundShape)),
        Command(id: "releaseCompoundShape", section: .compoundShape, action: .action(.releaseCompoundShape)),
        Command(id: "makeCompoundPath", section: .compoundPath, action: .menu("compoundPath", dialog: false)),
        Command(id: "releaseCompoundPath", section: .compoundPath, action: .menu("noCompoundPath", dialog: false)),
        Command(id: "buttCap", section: .caps, action: .code(.cap("BUTTENDCAP"))),
        Command(id: "roundCap", section: .caps, action: .code(.cap("ROUNDENDCAP"))),
        Command(id: "projectingCap", section: .caps, action: .code(.cap("PROJECTINGENDCAP"))),
    ]
    static func command(_ id: String) -> Command? { all.first { $0.id == id } }
    static func commands(in section: PaletteSection) -> [Command] { all.filter { $0.section == section } }
}

/// One-event actions from Illustrator's Actions panel, written out as .aia text (names are UTF-8 hex).
enum TempAction: Equatable {
    case appearance(value: Int, name: String)   // ai_plugin_appearance: 4 項目を削除, 6 アピアランスを消去
    case makeCompoundShape, releaseCompoundShape
    static let setName = "VectorFX Temporary"
    static let actionName = "VectorFX"

    /// A recorded .aia with its set and action renamed to VectorFX's own (so a set of the same name is never unloaded).
    static func renamed(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: #"/keyIndex \d+"#, with: "/keyIndex 0", options: .regularExpression)   // no function key while loaded
        let set = name("name", setName, indent: ""), action = name("name", actionName, indent: "\t")
        if let range = text.range(of: #"(?m)^/name \[ \d+\n[0-9a-f\s]+?\n\]"#, options: .regularExpression) { text.replaceSubrange(range, with: set) }
        if let range = text.range(of: #"(?m)^\t/name \[ \d+\n[0-9a-f\s]+?\n\t\]"#, options: .regularExpression) { text.replaceSubrange(range, with: action) }
        return text
    }

    static func hex(_ text: String) -> String { text.utf8.map { String(format: "%02x", $0) }.joined() }
    private static func name(_ key: String, _ text: String, indent: String) -> String {
        "\(indent)/\(key) [ \(text.utf8.count)\n\(indent)\t\(hex(text))\n\(indent)]"
    }
    var source: String {
        let event: (internal: String, localized: String, parameter: String)
        switch self {
        case .appearance(let value, let name):
            event = ("ai_plugin_appearance", "アピアランス", """
            \t\t\t/key 1835363957
            \t\t\t/showInPalette 4294967295
            \t\t\t/type (enumerated)
            \(Self.name("name", name, indent: "\t\t\t"))
            \t\t\t/value \(value)
            """)
        case .makeCompoundShape:
            event = ("ai_make_compound_shape", "複合シェイプを作成", "\t\t\t/key 1835101029\n\t\t\t/showInPalette 4294967295\n\t\t\t/type (integer)\n\t\t\t/value 0")
        case .releaseCompoundShape:
            event = ("ai_release_compound_shape", "複合シェイプを解除", "\t\t\t/key 1919710053\n\t\t\t/showInPalette 4294967295\n\t\t\t/type (integer)\n\t\t\t/value 0")
        }
        return """
        /version 3
        \(Self.name("name", Self.setName, indent: ""))
        /isOpen 1
        /actionCount 1
        /action-1 {
        \(Self.name("name", Self.actionName, indent: "\t"))
        \t/keyIndex 0
        \t/colorIndex 0
        \t/isOpen 1
        \t/eventCount 1
        \t/event-1 {
        \t\t/useRulersIn1stQuadrant 0
        \t\t/internalName (\(event.internal))
        \(Self.name("localizedName", event.localized, indent: "\t\t"))
        \t\t/isOpen 0
        \t\t/isOn 1
        \t\t/hasDialog 0
        \t\t/parameterCount 1
        \t\t/parameter-1 {
        \(event.parameter)
        \t\t}
        \t}
        }

        """
    }
}
