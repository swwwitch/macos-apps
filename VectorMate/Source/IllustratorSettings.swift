import AppKit
import ApplicationServices
import Carbon

/// Why an Illustrator settings operation could not finish. Keys written from JavaScript only take effect after a restart,
/// so the dialog boxes are operated through Accessibility as SetAiMenuState.applescript does. Settings with a real
/// preference key are read from it; getBooleanPreference returns true for any unknown key, so a key is used only
/// after checking that it differs from an unknown one (enableBackgroundSave / enableBackgroundExport do not: measured 2026-10-18).
enum SettingsFailure: Error, Equatable {
    case notRunning
    case noDocument
    case notTrusted
    case automationDenied
    case menuNotFound
    case dialogNotFound
    case controlNotFound
    /// The key still reads the old value after OK.
    case notChanged
    case failed(String)
}

/// Runs a JavaScript expression in the running Illustrator (never launched for this).
func evaluate(_ javascript: String, in app: NSRunningApplication) -> Result<String, SettingsFailure> {
    switch Illustrator.run(javascript: javascript, in: app) {
    case .output(let text): return .success(text.trimmingCharacters(in: .whitespacesAndNewlines))
    case .automationDenied: return .failure(.automationDenied)
    case .timedOut: return .failure(.failed("timeout"))
    case .failed(let message): return .failure(.failed(message))
    }
}

func runningIllustrator() -> NSRunningApplication? { DispatchQueue.main.sync { Illustrator.running } }

/// Brings Illustrator to the front and waits for it (its dialog boxes close when it goes to the back).
func bringToFront(_ app: NSRunningApplication) -> Bool {
    for _ in 0..<50 {
        if DispatchQueue.main.sync(execute: { NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier }) { return true }
        DispatchQueue.main.sync { _ = app.activate(options: [.activateIgnoringOtherApps]) }
        Thread.sleep(forTimeInterval: 0.1)
    }
    return false
}

// MARK: - Accessibility

enum AX {
    static func element(_ el: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attribute as CFString, &value) == .success, let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    static func elements(_ el: AXUIElement, _ attribute: String = kAXChildrenAttribute) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }
    static func string(_ el: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attribute as CFString, &value) == .success, let text = value as? String, !text.isEmpty else { return nil }
        return text
    }
    static func number(_ el: AXUIElement, _ attribute: String) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attribute as CFString, &value) == .success else { return nil }
        return (value as? NSNumber)?.intValue
    }
    static func role(_ el: AXUIElement) -> String { string(el, kAXRoleAttribute) ?? "" }
    /// Illustrator puts control labels in the description, not the title.
    static func name(_ el: AXUIElement) -> String? { string(el, kAXDescriptionAttribute) ?? string(el, kAXTitleAttribute) }
    @discardableResult static func press(_ el: AXUIElement) -> Bool { AXUIElementPerformAction(el, kAXPressAction as CFString) == .success }
    static func find(in el: AXUIElement, depth: Int, where match: (AXUIElement) -> Bool) -> AXUIElement? {
        for child in elements(el) {
            if match(child) { return child }
            if depth > 1, let found = find(in: child, depth: depth - 1, where: match) { return found }
        }
        return nil
    }
    static func wait<T>(_ tries: Int, _ probe: () -> T?) -> T? {
        for _ in 0..<tries {
            if let value = probe() { return value }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return nil
    }
    static func pressButton(in dialog: AXUIElement, named names: [String]) {
        if let button = find(in: dialog, depth: 6, where: { role($0) == kAXButtonRole && names.contains(name($0) ?? "") }) { press(button) }
    }
    static let okNames = ["OK"]
    static let cancelNames = ["キャンセル", "Cancel"]

    /// A key press sent to the front app (Illustrator), with no modifiers.
    static func key(_ code: Int) {
        let source = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: down)
            event?.flags = []
            event?.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.03)
        }
    }
}

/// A pane of Illustrator's 設定 (環境設定) dialog box: an AXLayoutArea named 環境設定, opened from 設定… in the app menu.
struct PreferencesPane {
    /// 「設定…」 uses one ellipsis character, the pane items three periods (SetAiMenuState.applescript). English unverified.
    let menuNames: [String]
    let headings: [String]
    static let dialogNames = ["環境設定", "Preferences", "Settings"]

    /// Opens the pane and waits until its controls are shown.
    func open(_ root: AXUIElement) -> Result<AXUIElement, SettingsFailure> {
        // The app menu (menu bar item 2) → 設定… → pane; the other menus are large and not searched.
        let barItems = AX.element(root, kAXMenuBarAttribute).map { AX.elements($0) } ?? []
        guard barItems.count > 1, let item = AX.find(in: barItems[1], depth: 4, where: {
            AX.role($0) == kAXMenuItemRole && menuNames.contains(AX.string($0, kAXTitleAttribute) ?? "")
        }) else { return .failure(.menuNotFound) }
        // A menu press right after a dialog box closed can be ignored, so press once more.
        var dialog: AXUIElement?
        for _ in 0..<2 where dialog == nil {
            guard AX.press(item) else { return .failure(.menuNotFound) }
            dialog = AX.wait(50) { Self.find(root) }
        }
        guard let dialog else { return .failure(.dialogNotFound) }
        // Right after opening, the previous pane's controls can linger: wait for this pane's heading.
        guard AX.wait(50, { AX.find(in: dialog, depth: 6) { AX.role($0) == kAXStaticTextRole && headings.contains(AX.string($0, kAXValueAttribute) ?? "") } }) != nil else {
            close(dialog, root, ok: false); return .failure(.dialogNotFound)
        }
        return .success(dialog)
    }

    func close(_ dialog: AXUIElement, _ root: AXUIElement, ok: Bool) {
        AX.pressButton(in: dialog, named: ok ? AX.okNames : AX.cancelNames)
        _ = AX.wait(50) { Self.find(root) == nil ? true : nil }
    }

    static func find(_ root: AXUIElement) -> AXUIElement? {
        (AX.elements(root) + AX.elements(root, kAXWindowsAttribute)).first { el in
            dialogNames.contains(AX.string(el, kAXTitleAttribute) ?? "") || dialogNames.contains(AX.string(el, kAXDescriptionAttribute) ?? "")
        }
    }

    /// Opens the pane in the running Illustrator, lets `body` set the controls, then OK (キャンセル when it fails or `commit` is false).
    static func operate(_ pane: PreferencesPane, in app: NSRunningApplication, commit: Bool = true, _ body: (AXUIElement) -> SettingsFailure?) -> SettingsFailure? {
        guard AXIsProcessTrusted() else { return .notTrusted }
        guard bringToFront(app) else { return .failed("activate") }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 3)
        switch pane.open(root) {
        case .failure(let failure): return failure
        case .success(let dialog):
            let failure = body(dialog)
            pane.close(dialog, root, ok: commit && failure == nil)
            return failure
        }
    }
}

// MARK: - 保存・書き出し

/// ［設定］→［ファイル管理］の「バックグラウンドで保存」「バックグラウンドで書き出し」「復帰データを次の間隔で自動保存」。
/// app.preferences cannot read them (enableBackgroundSave / enableBackgroundExport return true like an unknown key).
/// They are read from the preference files, as BackgroundSaveExportState.jsx does: the lowercase enableBackgroundSave /
/// enableBackgroundExport at the top level of 「Adobe Illustrator Cloud Prefs」 (the capitalized keys are other keys), and
/// AutomaticallySave in the CrashRecovery block of the main prefs file. Illustrator writes the files when it quits, so a
/// change made inside Illustrator during the session may not be there yet; Check reads the dialog box itself.
enum FileHandling {
    enum Item: String, CaseIterable { case export, save, recovery }
    typealias State = [Item: Bool]
    static let pane = PreferencesPane(menuNames: ["ファイル管理...", "File Handling..."], headings: ["ファイル管理", "File Handling"])
    /// Matched with hasPrefix against the description. The English labels are unverified.
    static let labels: [Item: [String]] = [
        .export: ["バックグラウンドで書き出し", "Export in Background"],
        .save: ["バックグラウンドで保存", "Save in Background"],
        .recovery: ["復帰データを次の間隔で自動保存", "Automatically Save Recovery Data"]
    ]

    private static func checkbox(_ dialog: AXUIElement, _ item: Item) -> AXUIElement? {
        AX.find(in: dialog, depth: 6, where: { el in
            guard AX.role(el) == kAXCheckBoxRole, let name = AX.name(el) else { return false }
            return labels[item]!.contains { name.hasPrefix($0) }
        })
    }
    private static func state(_ dialog: AXUIElement) -> State? {
        var state: State = [:]
        for item in Item.allCases {
            guard let box = checkbox(dialog, item) else { return nil }
            state[item] = AX.number(box, kAXValueAttribute) == 1
        }
        return state
    }

    /// 「Adobe Illustrator <major> Settings/<locale>」 of the running Illustrator: the locale folder whose Cloud Prefs is newest.
    static func settingsFolder(_ app: NSRunningApplication) -> URL? {
        let version = app.bundleURL.flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String } ?? ""
        guard let major = version.split(separator: ".").first else { return nil }
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/Adobe Illustrator \(major) Settings")
        let locales = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return locales.compactMap { folder -> (URL, Date)? in
            let file = folder.appendingPathComponent("Adobe Illustrator Cloud Prefs")
            guard let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { return nil }
            return (folder, date)
        }.max { $0.1 < $1.1 }?.0
    }

    /// Top-level "/key value" at the start of a line (case-sensitive; the files use CR line ends).
    static func topLevelInteger(_ text: String, _ key: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: "(?:^|[\\r\\n])/" + NSRegularExpression.escapedPattern(for: key) + " (-?\\d+)"),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Int(text[range])
    }
    static func recoveryValue(_ text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: "/CrashRecovery \\{[^}]*?/AutomaticallySave (\\d+)"),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Int(text[range])
    }

    /// Reads the files (no dialog box). Also returns when they were written.
    static func readFiles(_ app: NSRunningApplication) -> (state: State, written: Date)? {
        guard let folder = settingsFolder(app) else { return nil }
        let cloud = folder.appendingPathComponent("Adobe Illustrator Cloud Prefs")
        let main = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
            .first { ["Adobe Illustrator Prefs", "Adobe Illustrator 環境設定"].contains($0.lastPathComponent.precomposedStringWithCanonicalMapping) }
        guard let data = try? Data(contentsOf: cloud) else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        guard let save = topLevelInteger(text, "enableBackgroundSave"), let export = topLevelInteger(text, "enableBackgroundExport") else { return nil }
        var state: State = [.save: save != 0, .export: export != 0]
        var written = (try? cloud.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
        if let main, let mainData = try? Data(contentsOf: main), let recovery = recoveryValue(String(decoding: mainData, as: UTF8.self)) {
            state[.recovery] = recovery != 0
            written = min(written, (try? main.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? written)
        }
        return (state, written)
    }

    /// Blocking: opens the dialog box, reads the checkboxes and closes it with キャンセル.
    static func read() -> Result<State, SettingsFailure> { apply([:]) }

    /// Blocking: sets the given checkboxes (others untouched), OK, and returns the state before.
    /// An empty change only reads and closes with キャンセル.
    static func apply(_ wanted: State) -> Result<State, SettingsFailure> {
        guard let app = runningIllustrator() else { return .failure(.notRunning) }
        var before: State?
        if let failure = PreferencesPane.operate(pane, in: app, commit: !wanted.isEmpty, { dialog in
            guard let current = state(dialog) else { return .controlNotFound }
            before = current
            for (item, value) in wanted where current[item] != value {
                guard let box = checkbox(dialog, item), AX.press(box) else { return .failed("AXPress") }
            }
            let after = state(dialog) ?? [:]
            return wanted.allSatisfy { after[$0.key] == $0.value } ? nil : .notChanged
        }) { return .failure(failure) }
        return before.map { .success($0) } ?? .failure(.controlNotFound)
    }
}

// MARK: - 基本UI（メニューの ✓ で読み、メニューを押して切り替える）

/// The basic UI items of ViewToggles.jsx that are menu items with a checkmark. The checkmark is read through
/// Accessibility (AXMenuItemMarkChar); preference keys are not used (ContextualTaskBarEnabled read 0 while checked, 2026-10-18).
enum InterfaceMenus {
    /// In the order shown (コンテキストタスクバー last).
    enum Item: String, CaseIterable { case advancedToolbar, controlBar, helpBar, applicationBar, snapToGlyph, contextualTaskBar }
    /// Menu paths, Japanese first (English unverified).
    static let paths: [Item: [[String]]] = [
        .advancedToolbar: [["ウィンドウ", "ツールバー", "詳細"], ["Window", "Toolbars", "Advanced"]],
        .contextualTaskBar: [["ウィンドウ", "コンテキストタスクバー"], ["Window", "Contextual Task Bar"]],
        .controlBar: [["ウィンドウ", "コントロール"], ["Window", "Control"]],
        .helpBar: [["ウィンドウ", "ヘルプバー"], ["Window", "Help Bar"]],
        .applicationBar: [["ウィンドウ", "アプリケーションバー"], ["Window", "Application Bar"]],
        .snapToGlyph: [["表示", "グリフにスナップ"], ["View", "Snap to Glyph"]]
    ]
    typealias State = [Item: Bool]
    /// オールドスクール設定. The toolbar's two columns cannot be set: the toolbar panel is not exposed to Accessibility.
    static let oldSchool: State = [.advancedToolbar: true, .contextualTaskBar: false, .controlBar: true, .snapToGlyph: false, .helpBar: false, .applicationBar: false]

    private static func menuItem(_ root: AXUIElement, _ item: Item) -> AXUIElement? {
        guard let bar = AX.element(root, kAXMenuBarAttribute) else { return nil }
        for path in paths[item]! {
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
    private static func isChecked(_ el: AXUIElement) -> Bool { !(AX.string(el, "AXMenuItemMarkChar") ?? "").isEmpty }

    /// Reads every checkmark without opening a menu (no dialog box; Illustrator stays where it is).
    static func read() -> Result<State, SettingsFailure> {
        guard AXIsProcessTrusted() else { return .failure(.notTrusted) }
        guard let app = runningIllustrator() else { return .failure(.notRunning) }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 3)
        var state: State = [:]
        for item in Item.allCases {
            guard let el = menuItem(root, item) else { return .failure(.menuNotFound) }
            state[item] = isChecked(el)
        }
        return .success(state)
    }

    /// Blocking: presses the menu items whose checkmark differs from `wanted`, then reads them again.
    static func apply(_ wanted: State) -> Result<State, SettingsFailure> {
        guard AXIsProcessTrusted() else { return .failure(.notTrusted) }
        guard let app = runningIllustrator() else { return .failure(.notRunning) }
        guard bringToFront(app) else { return .failure(.failed("activate")) }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 3)
        for item in Item.allCases {
            guard let value = wanted[item] else { continue }
            guard let el = menuItem(root, item) else { return .failure(.menuNotFound) }
            if isChecked(el) != value {
                guard AX.press(el) else { return .failure(.failed("AXPress")) }
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
        switch read() {
        case .success(let after): return wanted.allSatisfy { after[$0.key] == $0.value } ? .success(after) : .failure(.notChanged)
        case .failure(let failure): return .failure(failure)
        }
    }
}

// MARK: - UIの明るさ

/// ［設定］→［ユーザーインターフェイス］の明るさ（4段階）。uiBrightness で読み、ボタンを押して変える。
enum UIBrightness {
    /// value: uiBrightness (0.5 and 0.51 are different levels, so the nearest wins). buttons: the button names (English unverified).
    static let levels: [(key: String, value: Double, buttons: [String])] = [
        ("dark", 0.0, ["暗", "Dark"]),
        ("mediumDark", 0.5, ["やや暗め", "Medium Dark"]),
        ("mediumLight", 0.51, ["やや明るめ", "Medium Light"]),
        ("light", 1.0, ["明", "Light"])
    ]
    static let pane = PreferencesPane(menuNames: ["ユーザーインターフェイス...", "User Interface..."], headings: ["ユーザーインターフェイス", "User Interface"])
    static let readScript = #"String(app.preferences.getRealPreference("uiBrightness"))"#

    static func index(of value: Double) -> Int {
        levels.indices.min { abs(levels[$0].value - value) < abs(levels[$1].value - value) } ?? 0
    }
    /// The level after one step brighter (+1) or darker (-1), kept within the four levels.
    static func target(from index: Int, step: Int) -> Int { min(max(index + step, 0), levels.count - 1) }

    static func read(_ app: NSRunningApplication) -> Result<Int, SettingsFailure> {
        evaluate(readScript, in: app).flatMap { text in Double(text).map { .success(index(of: $0)) } ?? .failure(.failed(text)) }
    }

    /// Blocking: call off the main thread. `step` moves from the current level; `level` sets one directly.
    /// Returns (before, after) level indexes; equal when nothing needed changing.
    static func change(step: Int = 0, level: Int? = nil) -> Result<(Int, Int), SettingsFailure> {
        guard let app = runningIllustrator() else { return .failure(.notRunning) }
        let before: Int
        switch read(app) { case .success(let value): before = value; case .failure(let failure): return .failure(failure) }
        let wanted = level ?? target(from: before, step: step)
        if wanted == before { return .success((before, before)) }
        if let failure = PreferencesPane.operate(pane, in: app, { dialog in
            let names = levels[wanted].buttons
            guard let button = AX.find(in: dialog, depth: 6, where: { AX.role($0) == kAXButtonRole && names.contains(AX.name($0) ?? "") }) else { return .controlNotFound }
            return AX.press(button) ? nil : .failed("AXPress")
        }) { return .failure(failure) }
        if case .success(let after) = read(app), after != wanted { return .failure(.notChanged) }
        return .success((before, wanted))
    }
}

// MARK: - シェイプ形成ツールのカラー

/// ［シェイプ形成ツールオプション］の「次のカラーを利用」（スウォッチ／オブジェクト）。
/// Planar/MergeTool/PaintFills で読む（0：オブジェクト、1：スウォッチ）。書いてもツールに反映されず［OK］で上書きされるので、
/// ツールを選んで Return でオプションを開き、ポップアップを矢印キーで選ぶ（ポップアップは値を書けず、一覧の項目にもアクションが無い）。
enum ShapeBuilderColor {
    enum Source: Int { case artwork = 0, swatches = 1 }
    static let toolID = "Adobe Shape Builder Tool"
    /// Popup item names per source (English unverified).
    static let names: [Source: [String]] = [.swatches: ["スウォッチ", "Color Swatches"], .artwork: ["オブジェクト", "Artwork"]]
    static let dialogSuffixes = ["オプション", "Options"]
    static let readScript = #"app.documents.length === 0 ? "nodoc" : String(app.preferences.getIntegerPreference("Planar/MergeTool/PaintFills"))"#

    static func parse(_ text: String) -> Result<Source, SettingsFailure> {
        if text == "nodoc" { return .failure(.noDocument) }
        guard let value = Int(text) else { return .failure(.failed(text)) }
        return .success(value == 0 ? .artwork : .swatches)
    }
    static func read(_ app: NSRunningApplication) -> Result<Source, SettingsFailure> { evaluate(readScript, in: app).flatMap(parse) }

    /// The tool options dialog box: an AXLayoutArea named 〜オプション.
    private static func optionsDialog(_ root: AXUIElement) -> AXUIElement? {
        AX.elements(root).first { el in AX.role(el) == "AXLayoutArea" && dialogSuffixes.contains { (AX.name(el) ?? "").hasSuffix($0) } }
    }

    /// Blocking: call off the main thread. Returns whether it changed. The Shape Builder tool stays selected.
    static func set(_ wanted: Source) -> Result<Bool, SettingsFailure> {
        guard let app = runningIllustrator() else { return .failure(.notRunning) }
        switch read(app) {
        case .success(let current) where current == wanted: return .success(false)
        case .success: break
        case .failure(let failure): return .failure(failure)
        }
        guard AXIsProcessTrusted() else { return .failure(.notTrusted) }
        if case .failure(let failure) = evaluate("app.selectTool(\(MetricsScript.jsString(toolID))); \"\"", in: app) { return .failure(failure) }
        guard bringToFront(app) else { return .failure(.failed("activate")) }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 3)
        // Return opens the selected tool's options; the first one can be ignored, so press again until it appears.
        var dialog: AXUIElement?
        for _ in 0..<3 where dialog == nil {
            Thread.sleep(forTimeInterval: 0.3)
            AX.key(kVK_Return)
            dialog = AX.wait(30) { optionsDialog(root) }
        }
        guard let dialog else { return .failure(.dialogNotFound) }
        let allNames = names.values.flatMap { $0 }
        // The popup that holds both items.
        guard let popup = AX.find(in: dialog, depth: 6, where: { el in
            let items = AX.elements(el).compactMap(AX.name)
            return (names[.swatches]!.contains { items.contains($0) }) && (names[.artwork]!.contains { items.contains($0) })
        }) else { AX.pressButton(in: dialog, named: AX.cancelNames); return .failure(.controlNotFound) }
        let items = AX.elements(popup).compactMap(AX.name)
        let current = AX.string(popup, kAXValueAttribute) ?? ""
        guard let from = items.firstIndex(of: current), let to = items.firstIndex(where: { names[wanted]!.contains($0) }), allNames.contains(current) else {
            AX.pressButton(in: dialog, named: AX.cancelNames); return .failure(.controlNotFound)
        }
        if from != to {
            AX.press(popup)
            Thread.sleep(forTimeInterval: 0.5)
            for _ in 0..<abs(to - from) { AX.key(to > from ? kVK_DownArrow : kVK_UpArrow); Thread.sleep(forTimeInterval: 0.1) }
            AX.key(kVK_Return)
            Thread.sleep(forTimeInterval: 0.5)
        }
        let picked = names[wanted]!.contains(AX.string(popup, kAXValueAttribute) ?? "")
        AX.pressButton(in: dialog, named: picked ? AX.okNames : AX.cancelNames)
        _ = AX.wait(30) { optionsDialog(root) == nil ? true : nil }
        guard picked else { return .failure(.notChanged) }
        if case .success(let after) = read(app), after != wanted { return .failure(.notChanged) }
        return .success(true)
    }
}
