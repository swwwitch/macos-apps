import Foundation

/// The preferences of 環境設定セット (PresetManager.jsx, ai-scripts): most are written from JavaScript at once.
/// UI brightness, the Shape Builder color and the three File Handling checkboxes are set through dialog boxes
/// (only when they differ), as 基本UI, ツール and バックグラウンド do; ガイドをロック through its menu command.
struct PrefValues: Codable, Equatable {
    // 一般
    var richToolTips: Bool
    var homeScreen: Bool
    var legacyNewDoc: Bool
    var printBleedWidget: Bool
    // 選択範囲・アンカー表示
    var zoomToSelection: Bool
    var unlockOnCanvas: Bool
    var objectPathOnly: Bool
    var textPathOnly: Bool
    /// anchorSizePref: one of `anchorSizes`.
    var anchorSize: Int
    // アートボード
    var moveLockedArt: Bool
    var showArtboardName: Bool
    /// Index into `artboardColors`.
    var artboardColor: Int
    /// 1–4.
    var artboardStrokeWidth: Int
    // テキスト
    var autoSizeAreaText: Bool
    /// Off is written as 0 (the list is hidden).
    var recentFontsEnabled: Bool
    var recentFontsCount: Int
    var missingGlyphProtection: Bool
    var alternateGlyph: Bool
    // ユーザーインターフェイス
    /// 0 暗, 1 やや暗め, 2 やや明るめ, 3 明 (UIBrightness.levels).
    var uiBrightness: Int
    var canvasWhite: Bool
    // ガイド
    var guideLightBlue: Bool
    var guideDots: Bool
    /// 表示 → ガイド → ガイドをロック: read from the menu item's name (ガイドをロック / ガイドをロック解除), toggled with lockguide (needs a document).
    var lockGuides: Bool
    // スマートガイド
    var objectHighlighting: Bool
    // シェイプ形成ツール
    /// 次のカラーを利用: true スウォッチ, false オブジェクト (Planar/MergeTool/PaintFills).
    var shapeSwatches: Bool
    // パフォーマンス
    var animatedZoom: Bool
    var historyStates: Int
    var realTimeDrawing: Bool
    // ファイル管理
    var editOriginalSystemDefault: Bool
    var autoActivateFonts: Bool
    var saveToCloud: Bool
    /// 0 自動, 1 手動, 2 確認.
    var updateLinks: Int
    /// Not readable from JavaScript: they come from the preference files or the dialog box (FileHandling).
    var backgroundExport: Bool
    var backgroundSave: Bool
    var recoverySave: Bool
    // クリップボードの処理
    var includeSvgCode: Bool
    // スクリプト
    /// スクリプト実行の許可: on writes ShowExternalJSXWarning false (no warning before an external .jsx runs).
    var allowScripts: Bool

    static let fileHandlingPaths: [WritableKeyPath<PrefValues, Bool>] = [\.backgroundExport, \.backgroundSave, \.recoverySave]

    /// The count does not matter while the list is off. `ignoring`: values that could not be read are not compared.
    func matches(_ other: PrefValues, ignoring: [WritableKeyPath<PrefValues, Bool>] = []) -> Bool {
        var a = self, b = other
        ignoring.forEach { b[keyPath: $0] = a[keyPath: $0] }
        if !a.recentFontsEnabled { a.recentFontsCount = 0 }
        if !b.recentFontsEnabled { b.recentFontsCount = 0 }
        return a == b
    }
}

/// A named set, edited in 設定 → 環境設定セット.
struct PrefPreset: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var values: PrefValues

    /// ［デフォルト］ and ［プリセット1］ of PresetManager.jsx.
    static let defaultValues = PrefValues(
        richToolTips: true, homeScreen: true, legacyNewDoc: false, printBleedWidget: true,
        zoomToSelection: true, unlockOnCanvas: false, objectPathOnly: false, textPathOnly: false, anchorSize: 5,
        moveLockedArt: false, showArtboardName: true, artboardColor: 0, artboardStrokeWidth: 1,
        autoSizeAreaText: false, recentFontsEnabled: true, recentFontsCount: 10, missingGlyphProtection: true, alternateGlyph: true,
        uiBrightness: 1, canvasWhite: false, guideLightBlue: false, guideDots: false, lockGuides: false, objectHighlighting: true, shapeSwatches: true,
        animatedZoom: true, historyStates: 100, realTimeDrawing: true,
        editOriginalSystemDefault: false, autoActivateFonts: false, saveToCloud: true, updateLinks: 2,
        backgroundExport: true, backgroundSave: true, recoverySave: true, includeSvgCode: false, allowScripts: false)
    static let preset1Values = PrefValues(
        richToolTips: false, homeScreen: false, legacyNewDoc: true, printBleedWidget: false,
        zoomToSelection: false, unlockOnCanvas: false, objectPathOnly: false, textPathOnly: false, anchorSize: 7,
        moveLockedArt: true, showArtboardName: false, artboardColor: 7, artboardStrokeWidth: 1,
        autoSizeAreaText: true, recentFontsEnabled: true, recentFontsCount: 15, missingGlyphProtection: false, alternateGlyph: false,
        uiBrightness: 3, canvasWhite: true, guideLightBlue: true, guideDots: false, lockGuides: false, objectHighlighting: false, shapeSwatches: false,
        animatedZoom: false, historyStates: 50, realTimeDrawing: false,
        editOriginalSystemDefault: true, autoActivateFonts: true, saveToCloud: false, updateLinks: 0,
        backgroundExport: false, backgroundSave: false, recoverySave: true, includeSvgCode: true, allowScripts: true)
    static var defaults: [PrefPreset] {
        [PrefPreset(id: "default", name: NSLocalizedString("prefsets.preset.default", comment: ""), values: defaultValues),
         PrefPreset(id: "preset1", name: NSLocalizedString("prefsets.preset.preset1", comment: ""), values: preset1Values)]
    }

    static let storeKey = "prefPresets"
    /// A value missing from a saved set (one added in a later version) is taken from ［デフォルト］.
    static func load() -> [PrefPreset] {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let stored = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]],
              let base = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(defaultValues))) as? [String: Any] else { return defaults }
        let sets = stored.compactMap { entry -> PrefPreset? in
            var merged = entry
            merged["values"] = base.merging(entry["values"] as? [String: Any] ?? [:]) { _, saved in saved }
            guard let json = try? JSONSerialization.data(withJSONObject: merged) else { return nil }
            return try? JSONDecoder().decode(PrefPreset.self, from: json)
        }
        return sets.isEmpty ? defaults : sets
    }
    static func save(_ sets: [PrefPreset]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(sets), forKey: storeKey)
    }
}

/// Reading and writing the values (app.preferences), and the choices shown for them.
enum PrefPresets {
    /// The checkboxes: preference key, whether 0 means on (hitShapeOnPreview / hitTypeShapeOnPreview),
    /// and whether false means on (ShowExternalJSXWarning; present in the prefs file, so it does not read true like an unknown key).
    struct Flag {
        let path: WritableKeyPath<PrefValues, Bool>
        let key: String
        var inverted = false
        var negated = false
        let label: String
    }
    static let flags: [Flag] = [
        Flag(path: \.richToolTips, key: "showRichToolTips", label: "prefsets.richToolTips"),
        Flag(path: \.homeScreen, key: "Hello/ShowHomeScreenWS", label: "prefsets.homeScreen"),
        Flag(path: \.legacyNewDoc, key: "Hello/NewDoc", label: "prefsets.legacyNewDoc"),
        Flag(path: \.printBleedWidget, key: "enablePrintBleedWidget", label: "prefsets.printBleedWidget"),
        Flag(path: \.zoomToSelection, key: "zoomToSelection", label: "prefsets.zoomToSelection"),
        Flag(path: \.unlockOnCanvas, key: "showLockIcon", label: "prefsets.unlockOnCanvas"),
        Flag(path: \.objectPathOnly, key: "hitShapeOnPreview", inverted: true, label: "prefsets.objectPathOnly"),
        Flag(path: \.textPathOnly, key: "hitTypeShapeOnPreview", inverted: true, label: "prefsets.textPathOnly"),
        Flag(path: \.moveLockedArt, key: "moveLockedAndHiddenArt", label: "prefsets.moveLockedArt"),
        Flag(path: \.showArtboardName, key: "showArtboardLabelOnCanvas", label: "prefsets.showArtboardName"),
        Flag(path: \.autoSizeAreaText, key: "text/autoSizing", label: "prefsets.autoSizeAreaText"),
        Flag(path: \.missingGlyphProtection, key: "text/doFontLocking", label: "prefsets.missingGlyphProtection"),
        Flag(path: \.alternateGlyph, key: "text/enableAlternateGlyph", label: "prefsets.alternateGlyph"),
        Flag(path: \.objectHighlighting, key: "smartGuides/showObjectHighlighting", label: "prefsets.objectHighlighting"),
        Flag(path: \.animatedZoom, key: "Performance/AnimZoom", label: "prefsets.animatedZoom"),
        Flag(path: \.realTimeDrawing, key: "LiveEdit_State_Machine", label: "prefsets.realTimeDrawing"),
        Flag(path: \.editOriginalSystemDefault, key: "useSysDefEdit", label: "prefsets.editOriginalSystemDefault"),
        Flag(path: \.autoActivateFonts, key: "AutoActivateMissingFont", label: "prefsets.autoActivateFonts"),
        Flag(path: \.saveToCloud, key: "AdobeSaveAsCloudDocumentPreference", label: "prefsets.saveToCloud"),
        Flag(path: \.includeSvgCode, key: "plugin/FileClipboard/copySVGCode", label: "prefsets.includeSvgCode"),
        Flag(path: \.allowScripts, key: "ShowExternalJSXWarning", negated: true, label: "prefsets.allowScripts")
    ]
    static func flag(_ path: WritableKeyPath<PrefValues, Bool>) -> Flag { flags.first { $0.path == path }! }

    static let anchorSizes = [5, 7, 9, 11]
    static let strokeWidths = [1, 2, 3, 4]
    static let recentFontsRange = 1...30
    static let historyRange = 1...1000
    /// ハイライトのカラー (RGB 0–1) and its label key.
    static let artboardColors: [(label: String, rgb: [Double])] = [
        ("prefsets.color.lightBlue", [0.29, 0.52, 1.0]), ("prefsets.color.lightRed", [1.0, 0.29, 0.29]),
        ("prefsets.color.green", [0.0, 0.65, 0.31]), ("prefsets.color.mediumBlue", [0.0, 0.45, 0.78]),
        ("prefsets.color.magenta", [1.0, 0.0, 1.0]), ("prefsets.color.cyan", [0.0, 1.0, 1.0]),
        ("prefsets.color.white", [1.0, 1.0, 1.0]), ("prefsets.color.lightGray", [0.65, 0.65, 0.65]),
        ("prefsets.color.black", [0.0, 0.0, 0.0]), ("prefsets.color.yellow", [1.0, 1.0, 0.0])
    ]
    /// uiBrightness of the four levels (0.5 and 0.51 are different levels, so the nearest wins).
    static let brightnessValues = [0.0, 0.5, 0.51, 1.0]
    static let guideCyan = [0.0, 1.0, 1.0]
    static let guideLightBlue = [0.29, 0.52, 1.0]

    /// The other values, in the order the read script returns them after the flags.
    static let otherReads: [(kind: String, key: String)] = [
        ("Integer", "anchorSizePref"),
        ("Real", "ArtboardBBColorRed"), ("Real", "ArtboardBBColorGreen"), ("Real", "ArtboardBBColorBlue"), ("Real", "ArtboardBBWidth"),
        ("Integer", "text/recentFontMenu/showNEntries"), ("Integer", "maximumUndoDepth"), ("Integer", "uiCanvasIsWhite"),
        ("Real", "Guide/Color/red"), ("Real", "Guide/Color/green"), ("Real", "Guide/Color/blue"), ("Integer", "Guide/Style"),
        ("Integer", "plugin/FileClipboard/linkoptions"),
        ("Real", "uiBrightness"), ("Integer", "Planar/MergeTool/PaintFills")
    ]

    static func literal(_ text: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [text])
        return String((data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]").dropFirst().dropLast())
    }

    /// One line per value; an empty line when the key could not be read.
    static var readScript: String {
        func call(_ kind: String, _ key: String) -> String { "g(function () { return p.get\(kind)Preference(\(literal(key))); })" }
        let reads = flags.map { call($0.inverted ? "Integer" : "Boolean", $0.key) } + otherReads.map { call($0.kind, $0.key) }
        return "(function () { var p = app.preferences; function g(read) { try { return String(read()); } catch (e) { return \"\"; } } return ["
            + reads.joined(separator: ", ") + "].join(\"\\n\"); })()"
    }

    static func nearest(_ value: Double, _ choices: [Int]) -> Int {
        choices.min { abs(Double($0) - value) < abs(Double($1) - value) } ?? choices[0]
    }
    static func isClose(_ a: [Double], _ b: [Double], tolerance: Double = 0.02) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < tolerance }
    }

    /// Unreadable values fall back to ［デフォルト］; the color and sizes snap to the nearest choice, as the script does.
    static func parse(_ text: String) -> PrefValues? {
        let lines = text.components(separatedBy: "\n")
        guard lines.count == flags.count + otherReads.count else { return nil }
        var values = PrefPreset.defaultValues
        for (index, flag) in flags.enumerated() {
            let line = lines[index]
            if flag.inverted { if let number = Int(line) { values[keyPath: flag.path] = number == 0 } }
            else if line == "true" || line == "false" { values[keyPath: flag.path] = (line == "true") != flag.negated }
        }
        let rest = Array(lines[flags.count...])
        func real(_ index: Int) -> Double? { Double(rest[index]) }
        func int(_ index: Int) -> Int? { Int(rest[index]) ?? Double(rest[index]).map { Int($0.rounded()) } }
        if let size = int(0) { values.anchorSize = nearest(Double(size), anchorSizes) }
        if let red = real(1), let green = real(2), let blue = real(3) {
            let rgb = [red, green, blue]
            let distances = artboardColors.map { zip($0.rgb, rgb).reduce(0) { $0 + abs($1.0 - $1.1) } }
            values.artboardColor = distances.indices.min { distances[$0] < distances[$1] } ?? 0
        }
        if let width = real(4) { values.artboardStrokeWidth = nearest(width, strokeWidths) }
        if let count = int(5) {
            values.recentFontsEnabled = count > 0
            if count > 0 { values.recentFontsCount = min(max(count, recentFontsRange.lowerBound), recentFontsRange.upperBound) }
        }
        // 0 means the key is not there yet (PresetManager.jsx safeGetPositiveInt).
        if let depth = int(6) { values.historyStates = depth > 0 ? min(depth, historyRange.upperBound) : 100 }
        if let white = int(7) { values.canvasWhite = white == 1 }
        if let red = real(8), let green = real(9), let blue = real(10) { values.guideLightBlue = isClose([red, green, blue], guideLightBlue) }
        if let style = int(11) { values.guideDots = style == 1 }
        if let links = int(12), (0...2).contains(links) { values.updateLinks = links }
        if let brightness = real(13) {
            values.uiBrightness = brightnessValues.indices.min { abs(brightnessValues[$0] - brightness) < abs(brightnessValues[$1] - brightness) } ?? 0
        }
        if let fills = int(14) { values.shapeSwatches = fills != 0 }
        return values
    }

    /// Writes the JavaScript values (not brightness, the Shape Builder color or File Handling), redraws the document window (zoomout / zoomin, as the script does), then reads them back.
    static func writeScript(_ values: PrefValues) -> String {
        var statements = flags.map { flag -> String in
            let on = values[keyPath: flag.path]
            return flag.inverted ? "p.setIntegerPreference(\(literal(flag.key)), \(on ? 0 : 1));" : "p.setBooleanPreference(\(literal(flag.key)), \(on != flag.negated));"
        }
        let color = artboardColors.indices.contains(values.artboardColor) ? artboardColors[values.artboardColor].rgb : artboardColors[0].rgb
        let guide = values.guideLightBlue ? guideLightBlue : guideCyan
        let recent = values.recentFontsEnabled ? min(max(values.recentFontsCount, recentFontsRange.lowerBound), recentFontsRange.upperBound) : 0
        statements += [
            "p.setIntegerPreference(\"anchorSizePref\", \(anchorSizes.contains(values.anchorSize) ? values.anchorSize : anchorSizes[0]));",
            "p.setRealPreference(\"ArtboardBBColorRed\", \(color[0])); p.setRealPreference(\"ArtboardBBColorGreen\", \(color[1])); p.setRealPreference(\"ArtboardBBColorBlue\", \(color[2]));",
            "p.setRealPreference(\"ArtboardBBWidth\", \(min(max(values.artboardStrokeWidth, 1), 4)));",
            "p.setIntegerPreference(\"text/recentFontMenu/showNEntries\", \(recent));",
            "p.setIntegerPreference(\"maximumUndoDepth\", \(min(max(values.historyStates, historyRange.lowerBound), historyRange.upperBound)));",
            "p.setIntegerPreference(\"uiCanvasIsWhite\", \(values.canvasWhite ? 1 : 0));",
            "p.setRealPreference(\"Guide/Color/red\", \(guide[0])); p.setRealPreference(\"Guide/Color/green\", \(guide[1])); p.setRealPreference(\"Guide/Color/blue\", \(guide[2]));",
            "p.setIntegerPreference(\"Guide/Style\", \(values.guideDots ? 1 : 0));",
            "p.setIntegerPreference(\"plugin/FileClipboard/linkoptions\", \((0...2).contains(values.updateLinks) ? values.updateLinks : 2));"
        ]
        let refresh = "if (app.documents.length > 0) { try { app.executeMenuCommand(\"zoomout\"); app.executeMenuCommand(\"zoomin\"); } catch (e) {} }"
        return "(function () { var p = app.preferences; " + statements.joined(separator: " ") + " " + refresh + " })(); " + readScript
    }

    static func matching(_ values: PrefValues?, ignoring: [WritableKeyPath<PrefValues, Bool>] = [], in sets: [PrefPreset]) -> String? {
        guard let values else { return nil }
        return sets.first { $0.values.matches(values, ignoring: ignoring) }?.id
    }
}
