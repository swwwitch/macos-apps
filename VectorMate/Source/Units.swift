import AppKit
import ApplicationServices
import Carbon

/// A unit set of 単位パレット, edited in 設定 → 単位セット. Units always apply; in 詳細 mode the increments
/// and the document settings (nil = leave as it is) apply too.
struct UnitSet: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    /// Codes of rulerType / strokeUnits / text/units / text/asianunits.
    var units: [Int]
    /// キー入力・角丸の半径 in the 一般 unit, サイズ/行送り in the 文字 unit, ベースラインシフト in the 東アジア unit.
    var increments: [Double]
    var colorMode: ColorMode?
    var overprintPreview: Bool?
    var rasterResolution: Int?
    /// 透明グリッドのグリッドカラー (SetSameGridColors.applescript): nil leaves it, matchTop copies the upper color to the lower,
    /// color sets both to gridHex.
    var gridMode: GridMode?
    var gridHex: String?
    /// 表示 → ピクセルにスナップ.
    var snapToPixel: Bool?
    enum ColorMode: String, Codable, CaseIterable { case cmyk, rgb }
    enum GridMode: String, Codable, CaseIterable { case matchTop, color }
    var hasDocumentSettings: Bool { colorMode != nil || overprintPreview != nil || rasterResolution != nil || gridMode != nil || snapToPixel != nil }

    static let defaults: [UnitSet] = [
        UnitSet(id: "mmPt", name: L("units.preset.mmPt"), units: [1, 2, 2, 2], increments: [0.1, 1, 1, 0.1],
                colorMode: .cmyk, overprintPreview: true, rasterResolution: 300, snapToPixel: false),
        UnitSet(id: "mmQH", name: L("units.preset.mmQH"), units: [1, 1, 5, 5], increments: [0.1, 1, 1, 0.5],
                colorMode: .cmyk, overprintPreview: true, rasterResolution: 300, snapToPixel: false),
        UnitSet(id: "px", name: L("units.preset.px"), units: [6, 6, 6, 6], increments: [1, 1, 1, 0.1], snapToPixel: true),
        UnitSet(id: "presentation", name: L("units.preset.presentation"), units: [6, 6, 6, 6], increments: [10, 20, 8, 1],
                colorMode: .rgb, overprintPreview: false, rasterResolution: 300, snapToPixel: false)
    ]
    static let storeKey = "unitSets"
    static func load() -> [UnitSet] {
        guard var sets = UserDefaults.standard.data(forKey: storeKey).flatMap({ try? JSONDecoder().decode([UnitSet].self, from: $0) }) else { return defaults }
        // 1.9 added ピクセルにスナップ: the built-in sets saved before get their value once (ウェブ ON, the others OFF).
        if !UserDefaults.standard.bool(forKey: "snapToPixelDefaultApplied") {
            UserDefaults.standard.set(true, forKey: "snapToPixelDefaultApplied")
            for index in sets.indices where sets[index].snapToPixel == nil {
                if let builtIn = defaults.first(where: { $0.id == sets[index].id }) { sets[index].snapToPixel = builtIn.snapToPixel }
            }
            save(sets)
        }
        return sets
    }
    static func save(_ sets: [UnitSet]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(sets), forKey: storeKey)
    }
}

/// ［設定］→［単位］. Units written from JavaScript only take effect after a restart, so the 単位 pane is opened and each
/// popup (AXComboBox: its items are AXUnknown children with the names in the description; 一般 has the focus on open,
/// measured 2026-10-18) is moved with the arrow keys from its current item to the wanted one; OK only when all four
/// show the wanted unit. In 詳細 mode the increments are written from JavaScript in points first, so OK keeps them.
/// That is the fallback: first the quick way of SetUnits-*.applescript (ai-scripts) is tried, see `quickSet`.
enum UnitSettings {
    static let unitKeys = ["rulerType", "strokeUnits", "text/units", "text/asianunits"]
    static let incrementKeys = ["cursorKeyLength", "ovalRadius", "text/sizeIncrement", "text/riseIncrement"]
    /// The unit each increment is given in (PreferenceManager-unit.jsx INCREMENT_FIELD_DEFINITIONS).
    static let incrementUnitIndex = [0, 0, 2, 3]
    /// Code → (label, points per unit). Code 5 is Q for text/units and H elsewhere.
    static let units: [(label: String, points: Double)] = [
        ("in", 72), ("mm", 72 / 25.4), ("pt", 1), ("pica", 12), ("cm", 72 / 2.54), ("Q", 72 / 25.4 * 0.25),
        ("px", 1), ("ft/in", 72 * 12), ("m", 72 / 25.4 * 1000), ("yd", 72 * 36), ("ft", 72 * 12)
    ]
    /// The codes each popup offers, in the popup's order.
    static let choices: [[Int]] = [[6, 2, 3, 5, 0, 10, 7, 9, 1, 4, 8], [6, 2, 3, 5, 0, 1, 4], [2, 0, 1, 5, 6], [2, 0, 1, 5, 6]]
    /// Item names in the popups (Japanese UI, measured). Code 5 is 級 in 文字 and 歯 elsewhere. English unverified.
    static func itemNames(code: Int, popup: Int) -> [String] {
        switch code {
        case 0: return ["インチ", "Inches"]
        case 1: return ["ミリメートル", "Millimeters"]
        case 2: return ["ポイント", "Points"]
        case 3: return ["パイカ", "Picas"]
        case 4: return ["センチメートル", "Centimeters"]
        case 5: return popup == 2 ? ["級", "Q"] : ["歯", "H"]
        case 6: return ["ピクセル", "Pixels"]
        case 7: return ["フィートとインチ", "Feet & Inches"]
        case 8: return ["メートル", "Meters"]
        case 9: return ["ヤード", "Yards"]
        case 10: return ["フィート", "Feet"]
        default: return []
        }
    }
    static func label(code: Int, popup: Int) -> String {
        guard units.indices.contains(code) else { return "?" }
        return code == 5 && popup != 2 ? "H" : units[code].label
    }

    struct State: Equatable {
        var units: [Int]
        var increments: [Double]
        /// Shown in the unit it is given in, rounded for display.
        func incrementText(_ index: Int) -> String {
            let popup = incrementUnitIndex[index], code = units[popup]
            let value = increments[index] / (UnitSettings.units.indices.contains(code) ? UnitSettings.units[code].points : 1)
            return format(value) + " " + label(code: code, popup: popup)
        }
    }
    static func format(_ value: Double) -> String { ((value * 1000).rounded() / 1000).formatted(.number.precision(.fractionLength(0...3))) }

    static var readScript: String {
        let units = unitKeys.map { "p.getIntegerPreference(\"\($0)\")" }
        let increments = incrementKeys.map { "p.getRealPreference(\"\($0)\")" }
        return "(function () { var p = app.preferences; return [" + (units + increments).joined(separator: ", ") + "].join(\"\\n\"); })()"
    }
    static func parse(_ text: String) -> State? {
        let values = text.split(separator: "\n").map(String.init)
        guard values.count == 8 else { return nil }
        let units = values[0..<4].compactMap { Int($0) }
        let increments = values[4..<8].compactMap { Double($0) }
        return units.count == 4 && increments.count == 4 ? State(units: units, increments: increments) : nil
    }
    static func read(_ app: NSRunningApplication) -> Result<State, SettingsFailure> {
        evaluate(readScript, in: app).flatMap { text in parse(text).map { .success($0) } ?? .failure(.failed(text)) }
    }
    static func matching(_ state: State?, in sets: [UnitSet]) -> String? {
        guard let state else { return nil }
        return sets.first { $0.units == state.units }?.id
    }

    static let pane = PreferencesPane(menuNames: ["単位...", "Units..."], headings: ["単位", "Units"])

    struct Applied {
        var state: State
        /// 詳細 mode had document settings, but no document was open.
        var documentSkipped: Bool
    }

    /// Blocking: call off the main thread. Do not touch the keyboard meanwhile (the arrow keys go to the front app).
    static func apply(_ set: UnitSet, detail: Bool) -> Result<Applied, SettingsFailure> {
        guard let app = runningIllustrator() else { return .failure(.notRunning) }
        guard AXIsProcessTrusted() else { return .failure(.notTrusted) }
        let writes = incrementKeys.indices.map { index -> String in
            let code = set.units[incrementUnitIndex[index]]
            return "p.setRealPreference(\"\(incrementKeys[index])\", \(set.increments[index] * (units.indices.contains(code) ? units[code].points : 1)));"
        }
        if let failure = setUnits(set.units, writes: writes, in: app) { return .failure(failure) }
        var skipped = false
        if detail, set.hasDocumentSettings {
            switch DocumentSettings.apply(set, in: app) {
            case .success(let applied): skipped = !applied
            case .failure(let failure): return .failure(failure)
            }
        }
        switch read(app) {
        case .success(let after): return after.units == set.units ? .success(Applied(state: after, documentSkipped: skipped)) : .failure(.notChanged)
        case .failure(let failure): return .failure(failure)
        }
    }

    /// Blocking: only the given popups (nil = leave) change, through the 単位 pane (クイック環境設定's ruler unit).
    static func applyUnits(_ targets: [Int?]) -> Result<State, SettingsFailure> {
        guard let app = runningIllustrator() else { return .failure(.notRunning) }
        guard AXIsProcessTrusted() else { return .failure(.notTrusted) }
        if let failure = setUnits(targets, writes: [], in: app) { return .failure(failure) }
        switch read(app) {
        case .success(let after):
            return targets.indices.allSatisfy { targets[$0] == nil || after.units[$0] == targets[$0] } ? .success(after) : .failure(.notChanged)
        case .failure(let failure): return .failure(failure)
        }
    }

    /// The quick way, then (when the units read back differ) the popups one by one. `writes` are JavaScript statements on `p`
    /// (app.preferences) run first, the increments of 詳細 mode.
    private static func setUnits(_ targets: [Int?], writes: [String], in app: NSRunningApplication) -> SettingsFailure? {
        switch quickSet(targets, writes: writes, in: app) {
        case .failure(.automationDenied): return .automationDenied
        case .success:
            if case .success(let after) = read(app), targets.indices.allSatisfy({ targets[$0] == nil || after.units[$0] == targets[$0] }) { return nil }
            diagnostics.log("units: quick way did not match, falling back")
        case .failure(.dialogNotFound):
            // Illustrator did not come to the front (another app took it): opening the pane from the menu would fail too.
            diagnostics.log("units: the pane did not open")
            return .dialogNotFound
        case .failure(let failure):
            diagnostics.log("units: quick way failed (\(String(describing: failure), privacy: .public)), falling back")
        }
        if !writes.isEmpty, case .failure(let failure) = evaluate("(function () { var p = app.preferences; " + writes.joined(separator: " ") + " return \"\"; })()", in: app) {
            return failure
        }
        return setPopups(targets, in: app)
    }

    /// SetUnits-*.applescript (ai-scripts): each unit is written from JavaScript as its neighbor in the popup, the 単位 pane is
    /// opened with the menu command unitundoPref (not waiting for it: the dialog box blocks the script), and one arrow key per
    /// popup moves it to the wanted unit, Tab between them (一般 has the focus on open). No item names are read, so no language
    /// is assumed; the caller checks the result from JavaScript.
    private static func quickSet(_ targets: [Int?], writes: [String], in app: NSRunningApplication) -> Result<Void, SettingsFailure> {
        guard let path = app.bundleURL?.path else { return .failure(.failed("no bundle")) }
        var statements = writes
        var keys: [Int?] = []
        for index in 0..<4 {
            guard let code = targets[index] else { keys.append(nil); continue }
            let list = choices[index]
            guard let at = list.firstIndex(of: code), list.count > 1 else { return .failure(.controlNotFound) }
            let neighbor = at > 0 ? list[at - 1] : list[at + 1]
            keys.append(at > 0 ? kVK_DownArrow : kVK_UpArrow)
            statements.append("p.setIntegerPreference(\"\(unitKeys[index])\", \(neighbor));")
        }
        guard bringToFront(app) else { return .failure(.failed("activate")) }
        let javascript = "(function () { var p = app.preferences; " + statements.joined(separator: " ") + " return \"\"; })()"
        let source = """
        with timeout of 5 seconds
            tell application \(MetricsScript.quoted(path))
                do javascript \(MetricsScript.quoted(javascript))
                ignoring application responses
                    execute menu command menu command string "unitundoPref"
                end ignoring
            end tell
        end timeout
        """
        switch Illustrator.run(appleScript: source) {
        case .output: break
        case .automationDenied: return .failure(.automationDenied)
        case .timedOut: return .failure(.failed("timeout"))
        case .failed(let message): return .failure(.failed(message))
        }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 3)
        guard let dialog = AX.wait(50, { PreferencesPane.find(root) }) else { return .failure(.dialogNotFound) }
        guard pane.showsHeading(dialog, tries: 30) else { pane.close(dialog, root, ok: false); return .failure(.dialogNotFound) }
        let popups = AX.elements(dialog).filter { AX.role($0) == kAXComboBoxRole && !AX.elements($0).isEmpty }
        guard popups.count >= 4, isFocused(popups[0]) else { pane.close(dialog, root, ok: false); return .failure(.controlNotFound) }
        let last = keys.lastIndex { $0 != nil } ?? 0
        for index in 0...last {
            if let key = keys[index] { AX.key(key) }
            if index < last { AX.key(kVK_Tab) }
        }
        pane.close(dialog, root, ok: true)
        return .success(())
    }

    /// Opens the 単位 pane, moves each popup with a target to it, and presses OK only when all of them match.
    private static func setPopups(_ targets: [Int?], in app: NSRunningApplication) -> SettingsFailure? {
        PreferencesPane.operate(pane, in: app, { dialog in
            let popups = AX.elements(dialog).filter { AX.role($0) == kAXComboBoxRole && !AX.elements($0).isEmpty }
            guard popups.count >= 4 else { return .controlNotFound }
            for index in 0..<4 {
                guard let code = targets[index] else { continue }
                let popup = popups[index]
                let items = AX.elements(popup).compactMap(AX.name)
                let wanted = itemNames(code: code, popup: index)
                guard let to = items.firstIndex(where: wanted.contains), let from = items.firstIndex(of: AX.string(popup, kAXValueAttribute) ?? "") else {
                    return .controlNotFound
                }
                guard from != to else { continue }
                guard focus(popup) else { return .controlNotFound }
                for _ in 0..<abs(to - from) { AX.key(to > from ? kVK_DownArrow : kVK_UpArrow); Thread.sleep(forTimeInterval: 0.08) }
                Thread.sleep(forTimeInterval: 0.15)
                guard wanted.contains(AX.string(popup, kAXValueAttribute) ?? "") else { return .notChanged }
            }
            return nil
        })
    }

    /// Setting AXFocused on a popup succeeds but leaves the focus where it was (measured 2026-10-18, the arrow keys then
    /// went to 一般), so Tab moves it: 一般 → 線 → 文字 → 東アジア in order.
    private static func focus(_ popup: AXUIElement) -> Bool {
        for attempt in 0...8 {
            if isFocused(popup) { return true }
            if attempt < 8 { AX.key(kVK_Tab); Thread.sleep(forTimeInterval: 0.15) }
        }
        return false
    }
    private static func isFocused(_ el: AXUIElement) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(el, kAXFocusedAttribute as CFString, &value) == .success && (value as? Bool) == true
    }
}

/// The document settings of 詳細 mode: ドキュメントのカラーモード and オーバープリントプレビュー through the menus
/// (their checkmarks are read through Accessibility), ラスタライズ効果設定の解像度 from JavaScript.
enum DocumentSettings {
    static let colorModePaths: [UnitSet.ColorMode: [[String]]] = [
        .cmyk: [["ファイル", "ドキュメントのカラーモード", "CMYK カラー"], ["File", "Document Color Mode", "CMYK Color"]],
        .rgb: [["ファイル", "ドキュメントのカラーモード", "RGB カラー"], ["File", "Document Color Mode", "RGB Color"]]
    ]
    static let overprintPaths = [["表示", "オーバープリントプレビュー"], ["View", "Overprint Preview"]]
    static let snapToPixelPaths = [["表示", "ピクセルにスナップ"], ["View", "Snap to Pixel"]]

    /// false when no document is open (nothing to set).
    static func apply(_ set: UnitSet, in app: NSRunningApplication) -> Result<Bool, SettingsFailure> {
        guard case .success(let count) = evaluate("String(app.documents.length)", in: app), count != "0" else { return .success(false) }
        guard bringToFront(app) else { return .failure(.failed("activate")) }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 3)
        if let mode = set.colorMode {
            guard let item = MenuPath.find(root, colorModePaths[mode]!) else { return .failure(.menuNotFound) }
            if !MenuPath.isChecked(item) { AX.press(item); Thread.sleep(forTimeInterval: 0.5) }
        }
        if let on = set.overprintPreview {
            guard let item = MenuPath.find(root, overprintPaths) else { return .failure(.menuNotFound) }
            if MenuPath.isChecked(item) != on { AX.press(item); Thread.sleep(forTimeInterval: 0.3) }
        }
        if let on = set.snapToPixel {
            guard let item = MenuPath.find(root, snapToPixelPaths) else { return .failure(.menuNotFound) }
            if MenuPath.isChecked(item) != on { AX.press(item); Thread.sleep(forTimeInterval: 0.3) }
        }
        if let resolution = set.rasterResolution {
            if case .failure(let failure) = evaluate("app.activeDocument.rasterEffectSettings.resolution = \(resolution); \"\"", in: app) { return .failure(failure) }
        }
        if let mode = set.gridMode, let failure = GridColors.apply(mode == .color ? (set.gridHex ?? "FFFFFF") : nil, root: root) { return .failure(failure) }
        return .success(true)
    }
}

/// A menu item found by its titles (Japanese path first), and its checkmark.
enum MenuPath {
    static func find(_ root: AXUIElement, _ paths: [[String]]) -> AXUIElement? {
        guard let bar = AX.element(root, kAXMenuBarAttribute) else { return nil }
        for path in paths {
            var level = AX.elements(bar)
            var found: AXUIElement?
            for name in path {
                found = level.first { AX.string($0, kAXTitleAttribute) == name }
                guard let hit = found else { break }
                level = AX.elements(hit).flatMap { AX.elements($0) }
            }
            if let found { return found }
        }
        return nil
    }
    static func isChecked(_ el: AXUIElement) -> Bool { !(AX.string(el, "AXMenuItemMarkChar") ?? "").isEmpty }
}

/// 透明グリッドのグリッドカラー2色をそろえる (SetSameGridColors.applescript, measured 2026-10-09 on Illustrator 30.8 Japanese).
/// ［ドキュメント設定］ is an AXLayoutArea named ドキュメント設定; its swatches (description gridColor1 / gridColor2) have no
/// action, so a real click (CGEvent) opens the macOS color panel (window カラー). The hex field of RGB つまみ is written and
/// Return pressed; the swatch takes the color when the panel closes. English names are unverified.
enum GridColors {
    static let menuPaths = [["ファイル", "ドキュメント設定..."], ["File", "Document Setup..."]]
    static let dialogNames = ["ドキュメント設定", "Document Setup"]
    static let panelNames = ["カラー", "Colors"]
    static let slidersNames = ["カラーつまみ", "Color Sliders"]
    static let rgbNames = ["RGBつまみ", "RGB Sliders"]

    /// `hex` nil: copy the upper color to the lower one. Returns nil when done.
    static func apply(_ hex: String?, root: AXUIElement) -> SettingsFailure? {
        let dialog: AXUIElement
        if let open = findDialog(root) { dialog = open } else {
            guard let item = MenuPath.find(root, menuPaths), AX.press(item) else { return .menuNotFound }
            guard let opened = AX.wait(50, { findDialog(root) }) else { return .dialogNotFound }
            dialog = opened
        }
        guard let top = AX.find(in: dialog, depth: 6, where: { AX.string($0, kAXDescriptionAttribute) == "gridColor1" }),
              let bottom = AX.find(in: dialog, depth: 6, where: { AX.string($0, kAXDescriptionAttribute) == "gridColor2" }) else {
            AX.pressButton(in: dialog, named: AX.cancelNames); return .controlNotFound
        }
        let target: String
        if let hex {
            target = hex
            if let failure = setColor(top, root: root, hex: target) { AX.pressButton(in: dialog, named: AX.cancelNames); return failure }
        } else {
            guard let field = openPanel(top, root: root) else { AX.pressButton(in: dialog, named: AX.cancelNames); return .controlNotFound }
            target = AX.string(field, kAXValueAttribute) ?? ""
            closePanel(root)
            guard target.count == 6 else { AX.pressButton(in: dialog, named: AX.cancelNames); return .controlNotFound }
        }
        if let failure = setColor(bottom, root: root, hex: target) { AX.pressButton(in: dialog, named: AX.cancelNames); return failure }
        AX.pressButton(in: dialog, named: AX.okNames)
        _ = AX.wait(30) { findDialog(root) == nil ? true : nil }
        return nil
    }

    private static func findDialog(_ root: AXUIElement) -> AXUIElement? {
        AX.elements(root).first { el in
            dialogNames.contains(AX.string(el, kAXTitleAttribute) ?? "") || dialogNames.contains(AX.string(el, kAXDescriptionAttribute) ?? "")
        }
    }
    private static func panel(_ root: AXUIElement) -> AXUIElement? {
        AX.elements(root, kAXWindowsAttribute).first { panelNames.contains(AX.string($0, kAXTitleAttribute) ?? "") }
    }

    private static func setColor(_ swatch: AXUIElement, root: AXUIElement, hex: String) -> SettingsFailure? {
        guard let field = openPanel(swatch, root: root) else { return .controlNotFound }
        AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, hex.uppercased() as CFString)
        Thread.sleep(forTimeInterval: 0.1)
        AX.key(kVK_Return)
        Thread.sleep(forTimeInterval: 0.2)
        closePanel(root)
        return nil
    }

    /// Clicks the swatch, shows RGB sliders, and returns the hex field (the 6-character text field).
    private static func openPanel(_ swatch: AXUIElement, root: AXUIElement) -> AXUIElement? {
        guard let frame = AX.frame(swatch) else { return nil }
        // The swatches ignore AXPress and synthetic clicks from System Events; a real mouse click opens them.
        AX.click(CGPoint(x: frame.midX, y: frame.midY))
        guard let window = AX.wait(50, { panel(root) }) else { return nil }
        if let sliders = AX.find(in: window, depth: 4, where: { AX.role($0) == kAXButtonRole && slidersNames.contains(AX.name($0) ?? "") }) {
            AX.press(sliders); Thread.sleep(forTimeInterval: 0.2)
        }
        if let popup = AX.find(in: window, depth: 4, where: { AX.role($0) == kAXPopUpButtonRole }), !rgbNames.contains(AX.string(popup, kAXValueAttribute) ?? "") {
            AX.press(popup); Thread.sleep(forTimeInterval: 0.2)
            if let item = AX.find(in: popup, depth: 3, where: { rgbNames.contains(AX.string($0, kAXTitleAttribute) ?? "") }) { AX.press(item) }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return AX.wait(20) { AX.find(in: window, depth: 5, where: { AX.role($0) == kAXTextFieldRole && (AX.string($0, kAXValueAttribute) ?? "").count == 6 }) }
    }

    /// The swatch takes the color when the panel closes.
    private static func closePanel(_ root: AXUIElement) {
        guard let window = panel(root) else { return }
        if let close = AX.element(window, kAXCloseButtonAttribute) { AX.press(close) }
        _ = AX.wait(30) { panel(root) == nil ? true : nil }
    }
}
