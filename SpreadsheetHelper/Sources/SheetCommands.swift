import AppKit
import ApplicationServices
import Carbon

// Helper keys for table operations, ported from the user's Keyboard Maestro macros
// (groups 「Excel 2016」「Google スプレッドシート」). No L() here, so Tests/ShortcutTests.swift can compile it alone.

/// Which target apps a command works in.
enum CommandScope: String {
    case both, excel, sheets
    func includes(_ profile: CleanProfile) -> Bool {
        switch self {
        case .both: return true
        case .excel: return profile == .excel
        case .sheets: return profile == .spreadsheet
        }
    }
}

/// Headings of the table commands in Settings, in this order.
enum CommandCategory: String, CaseIterable {
    case rowsColumns, alignment, format, editing, navigation, data
    var commands: [SheetCommand] { SheetCommand.allCases.filter { $0.category == self } }
}

/// Case order fixes the hotkey signatures, so new commands go at the end; Settings groups them by `category`.
enum SheetCommand: String, CaseIterable {
    case insert, delete, hideRowsColumns
    case centerAlign, alignLeft, alignRight, centerAcross, uncenterAcross, jumpToA1, editCellStart,
         replace, pasteSpecial, clearHyperlinks, borders, powerQuery, newWindow
    case previousSheet, nextSheet, sum, numberFormat, headerRow, pivotTable, alternatingColors, filter
    case verticalCenterWrap, formatSpecial

    /// Default keys of the KM macros; the user can change them in Settings (Model.commandShortcuts).
    var defaultShortcut: Shortcut {
        let cmd = UInt32(cmdKey), shift = UInt32(shiftKey), opt = UInt32(optionKey), ctrl = UInt32(controlKey)
        switch self {
        case .insert: return Shortcut(code: 34, modifiers: ctrl, label: "⌃I")
        case .delete: return Shortcut(code: 40, modifiers: ctrl, label: "⌃K")
        case .hideRowsColumns: return Shortcut(code: 20, modifiers: cmd, label: "⌘3")
        case .centerAlign: return Shortcut(code: 14, modifiers: cmd | shift, label: "⇧⌘E")
        case .alignLeft: return Shortcut(code: 37, modifiers: cmd | shift, label: "⇧⌘L")
        case .alignRight: return Shortcut(code: 15, modifiers: cmd | shift, label: "⇧⌘R")
        case .centerAcross: return Shortcut(code: 5, modifiers: cmd, label: "⌘G")
        case .uncenterAcross: return Shortcut(code: 5, modifiers: cmd | shift, label: "⇧⌘G")
        case .jumpToA1: return Shortcut(code: 115, modifiers: ctrl | opt, label: "⌃⌥Home")
        case .editCellStart: return Shortcut(code: 32, modifiers: ctrl, label: "⌃U")
        case .replace: return Shortcut(code: 3, modifiers: cmd, label: "⌘F")
        case .pasteSpecial: return Shortcut(code: 9, modifiers: opt, label: "⌥V")
        case .clearHyperlinks: return Shortcut(code: 40, modifiers: cmd | opt, label: "⌥⌘K")
        case .borders: return Shortcut(code: 13, modifiers: cmd | opt, label: "⌥⌘W")
        case .powerQuery: return Shortcut(code: 34, modifiers: cmd | opt | ctrl, label: "⌃⌥⌘I")
        case .newWindow: return Shortcut(code: 45, modifiers: cmd | ctrl, label: "⌃⌘N")
        case .previousSheet: return Shortcut(code: 123, modifiers: opt, label: "⌥←")
        case .nextSheet: return Shortcut(code: 124, modifiers: opt, label: "⌥→")
        case .sum: return Shortcut(code: 24, modifiers: opt | shift, label: "⌥⇧=")
        case .numberFormat: return Shortcut(code: 18, modifiers: ctrl | shift, label: "⌃⇧1")
        case .headerRow: return Shortcut(code: 24, modifiers: cmd | opt | ctrl, label: "⌃⌥⌘=")
        case .pivotTable: return Shortcut(code: 35, modifiers: cmd | opt, label: "⌥⌘P")
        case .alternatingColors: return Shortcut(code: 3, modifiers: ctrl, label: "⌃F")
        case .filter: return Shortcut(code: 3, modifiers: ctrl | shift, label: "⌃⇧F")
        case .verticalCenterWrap: return Shortcut(code: 22, modifiers: ctrl | shift, label: "⌃⇧6")
        case .formatSpecial: return Shortcut(code: 3, modifiers: cmd | opt | ctrl, label: "⌃⌥⌘F")
        }
    }
    var scope: CommandScope {
        switch self {
        case .insert, .delete, .hideRowsColumns, .pivotTable: return .both
        case .centerAlign, .alignLeft, .alignRight, .centerAcross, .uncenterAcross, .jumpToA1, .editCellStart,
             .replace, .pasteSpecial, .clearHyperlinks, .borders, .powerQuery, .newWindow: return .excel
        case .previousSheet, .nextSheet, .sum, .numberFormat, .headerRow, .alternatingColors, .filter, .verticalCenterWrap, .formatSpecial: return .sheets
        }
    }
    var category: CommandCategory {
        switch self {
        case .insert, .delete, .hideRowsColumns: return .rowsColumns
        case .centerAlign, .alignLeft, .alignRight, .centerAcross, .uncenterAcross: return .alignment
        case .borders, .numberFormat, .headerRow, .alternatingColors, .verticalCenterWrap, .formatSpecial: return .format
        case .editCellStart, .replace, .pasteSpecial, .clearHyperlinks: return .editing
        case .jumpToA1, .previousSheet, .nextSheet, .newWindow: return .navigation
        case .sum, .filter, .pivotTable, .powerQuery: return .data
        }
    }
    /// Carbon hotkey signatures 'CCC1'… in list order (the clean key is 'CCCL').
    var signature: OSType { 0x4343_4331 + OSType(Self.allCases.firstIndex(of: self)!) }
}

enum CommandOutcome {
    case done
    /// The app cannot do it now (e.g. Excel is editing a cell): the key goes back to the app.
    case unavailable
    case menuNotFound
    case eventFailed
    /// Excel did not allow Apple events from this app (error -1743).
    case automationDenied
    case scriptFailed(Int)
}

/// One step of a key sequence sent to the front browser or Excel.
enum CommandStep {
    case key(CGKeyCode, CGEventFlags)
    case text(String)
    case wait(TimeInterval)
}

/// Sends the keys, presses the menu item or runs the AppleScript for one command.
/// `busy` covers the delayed steps of a key sequence.
final class SheetCommandRunner {
    /// Pause between opening a Sheets menu and the next key (KM macros: 0.2 s).
    static let menuDelay: TimeInterval = 0.2
    /// Pause before Return in the Sheets menu search, so the results list is filled.
    static let searchDelay: TimeInterval = 0.6
    /// Arrow and Home keys carry these flags when typed on a real keyboard.
    static let navigation: CGEventFlags = [.maskSecondaryFn, .maskNumericPad]
    private(set) var busy = false

    func run(_ command: SheetCommand, profile: CleanProfile, pid: pid_t, bundleID: String?, windowTitle: String?) -> CommandOutcome {
        guard !busy else { return .done }
        return profile == .excel ? runExcel(command, pid: pid) : runSheets(command, pid: pid, bundleID: bundleID, windowTitle: windowTitle)
    }

    // MARK: Excel

    private func runExcel(_ command: SheetCommand, pid: pid_t) -> CommandOutcome {
        let edit = ["編集", "Edit"]
        switch command {
        // KM「02)行や列を挿入」: 「挿入 ▸ 行」 when enabled, otherwise 「挿入 ▸ 列」.
        case .insert: return Self.pressMenu(pid: pid, candidates: [[.any(["挿入", "Insert"]), .any(["行", "Rows"])],
                                                                    [.any(["挿入", "Insert"]), .any(["列", "Columns"])]])
        case .delete: return Self.pressMenu(pid: pid, candidates: [[.any(edit), .match(Self.isExcelDeleteItem)]])
        // KM「05)列を隠す」 hid columns only; whole rows selected now hide the rows.
        case .hideRowsColumns:
            let rows = (try? Self.runScript(Self.excelScript("return (get address of selection) = (get address of entire row of selection)"))) == "true"
            return Self.pressMenu(pid: pid, candidates: [[.any(["フォーマット", "Format"]), .any(rows ? ["行", "Row"] : ["列", "Column"]), .any(["表示しない", "Hide"])]])
        case .replace: return Self.pressMenu(pid: pid, candidates: [[.any(edit), .any(["検索", "Find"]), .prefix(["置換", "Replace"])]])
        case .pasteSpecial: return Self.pressMenu(pid: pid, candidates: [[.any(edit), .prefix(["形式を選択してペースト", "Paste Special"])]])
        case .clearHyperlinks: return Self.pressMenu(pid: pid, candidates: [[.any(edit), .any(["クリア", "Clear"]), .any(["ハイパーリンク", "Hyperlinks"])]])
        // 「データ ▸ ピボットテーブルで集計」 (Excel 16 has no PivotTable item in the Insert menu).
        case .pivotTable: return Self.pressMenu(pid: pid, candidates: [[.any(["データ", "Data"]), .prefix(["ピボットテーブル", "PivotTable", "Summarize with PivotTable"])]])
        case .newWindow: return Self.pressMenu(pid: pid, candidates: [[.any(["ウィンドウ", "ウインドウ", "Window"]), .prefix(["新しいウインドウ", "新しいウィンドウ", "New Window"])]])
        // KM「Power Query」: the menu, then Tab → Return Return in the dialog box.
        case .powerQuery:
            let outcome = Self.pressMenu(pid: pid, candidates: [[.any(["データ", "Data"]), .prefix(["データ ファイル指定", "Get Data"]), .prefix(["データ ファイル指定", "Get Data"])]])
            guard case .done = outcome else { return outcome }
            play([.wait(0.5), .key(48, []), .key(124, Self.navigation), .wait(0.2), .key(36, []), .wait(0.2), .key(36, [])], pid: pid)
            return .done
        // Excel's own keys: ⌘E center; ⌥⌘→ ⌥⌘↓ ⌥⌘0 (KM「罫線：選択範囲に引く」); ⌃U edits the cell, Home moves to its start.
        case .centerAlign: return Self.key(14, .maskCommand, to: pid) ? .done : .eventFailed
        case .borders:
            play([.key(124, Self.navigation.union([.maskCommand, .maskAlternate])), .key(125, Self.navigation.union([.maskCommand, .maskAlternate])),
                  .key(29, [.maskCommand, .maskAlternate])], pid: pid)
            return .done
        case .editCellStart:
            play([.key(32, .maskControl), .wait(0.1), .key(115, .maskSecondaryFn)], pid: pid)
            return .done
        // AppleScript, as the KM macros.
        case .centerAcross: return Self.excel(selection: "set horizontal alignment to horizontal align center across selection")
        case .uncenterAcross, .alignLeft: return Self.excel(selection: "set horizontal alignment to horizontal align left")
        case .alignRight: return Self.excel(selection: "set horizontal alignment to horizontal align right")
        // KM「44)A1に強制ジャンプ」: select A1 even with frozen panes, then ↓↑ so the window scrolls to it.
        case .jumpToA1:
            let outcome = Self.scriptOutcome(Self.excelScript("tell active sheet to select range \"A1\""))
            guard case .done = outcome else { return outcome }
            play([.key(125, Self.navigation), .key(126, Self.navigation)], pid: pid)
            return .done
        default: return .unavailable
        }
    }

    static func excelScript(_ body: String) -> String { "tell application id \"com.microsoft.Excel\"\n\(body)\nend tell" }
    private static func excel(selection body: String) -> CommandOutcome {
        scriptOutcome(excelScript("tell selection\n\(body)\nend tell"))
    }
    private static func scriptOutcome(_ source: String) -> CommandOutcome {
        do { _ = try runScript(source); return .done }
        catch let error as NSError { return error.code == -1743 ? .automationDenied : .scriptFailed(error.code) }
    }
    /// Returns the result as text; throws an NSError whose code is the AppleScript error number.
    static func runScript(_ source: String) throws -> String {
        var info: NSDictionary?
        guard let script = NSAppleScript(source: source) else { throw NSError(domain: "AppleScript", code: -2700) }
        let result = script.executeAndReturnError(&info)
        if let info { throw NSError(domain: "AppleScript", code: (info[NSAppleScript.errorNumber] as? Int) ?? -2700) }
        return result.stringValue ?? ""
    }

    // MARK: Google Sheets

    private func runSheets(_ command: SheetCommand, pid: pid_t, bundleID: String?, windowTitle: String?) -> CommandOutcome {
        guard let steps = Self.sheetsSteps(command, bundleID: bundleID, windowTitle: windowTitle) else { return .unavailable }
        play(steps, pid: pid)
        return .done
    }

    /// Keys for one command in Google Sheets; nil when the command is Excel only.
    static func sheetsSteps(_ command: SheetCommand, bundleID: String?, windowTitle: String?) -> [CommandStep]? {
        let menu: CGEventFlags = [.maskControl, .maskAlternate]
        let steps: [CommandStep]
        switch command {
        // Google Sheets decides row or column from the selection (⌥⌘= / ⌥⌘-).
        case .insert: steps = [.key(24, [.maskCommand, .maskAlternate])]
        case .delete: steps = [.key(27, [.maskCommand, .maskAlternate])]
        // KM「03)列を隠す」: ⌥⌘9.
        case .hideRowsColumns: steps = [.key(25, [.maskCommand, .maskAlternate])]
        // KM「12)前のシート」「11)次のシート」: ⌥↑ / ⌥↓.
        case .previousSheet: steps = [.key(126, Self.navigation.union(.maskAlternate))]
        case .nextSheet: steps = [.key(125, Self.navigation.union(.maskAlternate))]
        // KM「24)SUM関数」: Insert ▸ Function ▸ SUM (⌃⌥I U S); Firefox types =sum( instead.
        case .sum:
            steps = bundleID == "org.mozilla.firefox" ? [.text("=sum(")]
                : [.key(34, menu), .wait(0.5), .key(32, []), .key(1, []), .wait(0.4), .key(36, [])]
        // KM「21)表示形式（#,##0）」: ⌃⇧1 (#,##0.00), then 「小数点以下の桁数を減らす」 twice.
        case .numberFormat:
            let decrease = Self.menuSearch(Self.localizedName(.decreaseDecimals, windowTitle: windowTitle))
            steps = [.key(18, [.maskControl, .maskShift]), .wait(0.3)] + decrease + [.wait(0.3)] + decrease
        // Freeze row 1 (View ⌃⌥V ▸ R ▸ O), then select row 1 from A1 and make it bold and centered.
        case .headerRow:
            steps = [.key(9, menu), .wait(Self.menuDelay), .key(15, []), .wait(Self.menuDelay), .key(31, []), .wait(0.3),
                     .key(126, Self.navigation.union(.maskCommand)), .key(123, Self.navigation.union(.maskCommand)),
                     .key(49, .maskShift), .wait(0.1), .key(11, .maskCommand), .key(14, [.maskCommand, .maskShift])]
        // ⌃⌥I = Insert menu, then P (KM「25)ピボットテーブル」). P now only selects 「ピボット テーブル」, so Return runs it.
        case .pivotTable: steps = [.key(34, menu), .wait(Self.menuDelay), .key(35, []), .wait(0.1), .key(36, [])]
        // ⌃⌥D = Data menu, then F (KM「31)フィルター作成／解除（2）」). F now only selects the item, so Return runs it.
        // A DocklessLauncher entry on ⌃⌥D took the key before (user report 2026-10-19).
        case .filter: steps = [.key(2, menu), .wait(Self.menuDelay), .key(3, []), .wait(0.1), .key(36, [])]
        // ⌃⌥O = Format menu: A M (Alignment ▸ Middle), then W W (Wrapping ▸ Wrap) (KM「22)垂直方向中央・折り返す」).
        case .verticalCenterWrap:
            steps = [.key(31, menu), .wait(Self.menuDelay), .key(0, []), .key(46, []), .wait(0.4),
                     .key(31, menu), .wait(Self.menuDelay), .key(13, []), .key(13, [])]
        case .alternatingColors: steps = Self.menuSearch(Self.localizedName(.alternatingColors, windowTitle: windowTitle))
        // Select all (⌘A), middle and wrap, header row, then select all again for alternating colors.
        // Alternating colors goes last: its sidebar takes the focus, so later arrow keys would not reach the grid.
        case .formatSpecial:
            let part = { (command: SheetCommand) in sheetsSteps(command, bundleID: bundleID, windowTitle: windowTitle) ?? [] }
            steps = [.key(0, .maskCommand), .wait(0.2)] + part(.verticalCenterWrap) + [.wait(0.4)] + part(.headerRow)
                + [.wait(0.3), .key(0, .maskCommand), .wait(0.2)] + part(.alternatingColors)
        default: return nil
        }
        return steps
    }

    /// ⌃⌥H opens the Help menu, whose search box takes the focus.
    /// Not ⌥/: Firefox types it into the cell as 「÷」 (user report 2026-10-16).
    static func menuSearch(_ name: String) -> [CommandStep] {
        [.key(4, [.maskControl, .maskAlternate]), .wait(menuDelay), .text(name), .wait(searchDelay), .key(36, [])]
    }

    enum MenuName: Int { case alternatingColors, decreaseDecimals }
    /// Item names in 「メニューを検索」, picked from the window title marker (in MenuName order).
    static func localizedName(_ name: MenuName, windowTitle: String?) -> String {
        let title = windowTitle ?? ""
        let names: [String: [String]] = [
            "Google スプレッドシート": ["交互の背景色", "小数点以下の桁数を減らす"],
            "Google 스프레드시트": ["교차 색상", "소수점 이하 자리수 줄이기"],
            "Google 表格": ["交替颜色", "减少小数位数"],
            "Google 試算表": ["交替色彩", "減少小數位數"]
        ]
        let list = names.first { title.contains($0.key) }?.value ?? ["Alternating colors", "Decrease decimal places"]
        return list[name.rawValue]
    }

    /// Runs the steps in order on the main queue; waits are not blocking.
    private func play(_ steps: [CommandStep], pid: pid_t) {
        busy = true
        var remaining = steps[...]
        func next() {
            while let step = remaining.popFirst() {
                switch step {
                case .key(let code, let flags): _ = Self.key(code, flags, to: pid)
                case .text(let text): _ = Self.type(text, to: pid)
                case .wait(let seconds):
                    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { next() }
                    return
                }
            }
            busy = false
        }
        next()
    }

    // MARK: Excel menus (AX)

    /// One menu level: any of these titles, a title starting with one of them, or a predicate.
    enum MenuTitle {
        case any([String]), prefix([String]), match((String) -> Bool)
        func matches(_ title: String) -> Bool {
            switch self {
            case .any(let names): return names.contains(title)
            case .prefix(let names): return names.contains { title.hasPrefix($0) }
            case .match(let test): return test(title)
            }
        }
    }

    /// Excel's Edit menu shows 「削除...」 for cells and 「行の削除」「列の削除」 for whole rows/columns (KM: ^(削除|行の削除)).
    static func isExcelDeleteItem(_ title: String) -> Bool {
        if title.hasPrefix("削除") || title == "行の削除" || title == "列の削除" { return true }
        return title == "Delete..." || title == "Delete…" || title.hasPrefix("Delete Row") || title.hasPrefix("Delete Column")
    }

    /// Presses the first enabled item among the candidate paths (tried in order; within a path, the first match in menu order).
    private static func pressMenu(pid: pid_t, candidates: [[MenuTitle]]) -> CommandOutcome {
        let app = AXUIElementCreateApplication(pid)
        // A menu item that opens a dialog box may not answer until the dialog closes.
        AXUIElementSetMessagingTimeout(app, 1.0)
        guard let bar = element(app, kAXMenuBarAttribute) else { return .menuNotFound }
        var found: [AXUIElement] = []
        for path in candidates { found += items(in: children(bar), path: path[...]) }
        guard !found.isEmpty else { return .menuNotFound }
        guard let target = found.first(where: isEnabled) else { return .unavailable }
        let result = AXUIElementPerformAction(target, kAXPressAction as CFString)
        return result == .success || result == .cannotComplete ? .done : .eventFailed
    }

    private static func items(in elements: [AXUIElement], path: ArraySlice<MenuTitle>) -> [AXUIElement] {
        guard let level = path.first else { return [] }
        let matches = elements.filter { level.matches(title($0)) }
        if path.count == 1 { return matches }
        return matches.flatMap { item in children(item).flatMap { items(in: children($0), path: path.dropFirst()) } }
    }

    private static func element(_ parent: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private static func children(_ parent: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }
    private static func title(_ element: AXUIElement) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success else { return "" }
        return (value as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
    }
    private static func isEnabled(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    // MARK: Events

    /// One key straight to the process with explicit flags, so the held keys of the trigger do not leak in.
    static func key(_ code: CGKeyCode, _ flags: CGEventFlags, to pid: pid_t) -> Bool {
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else { return false }
        down.flags = flags
        up.flags = flags
        down.postToPid(pid)
        up.postToPid(pid)
        return true
    }

    /// Types text as Unicode (not through the input method), one character per event pair.
    static func type(_ text: String, to pid: pid_t) -> Bool {
        guard let source = CGEventSource(stateID: .privateState) else { return false }
        for character in text {
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return false }
            let units = Array(String(character).utf16)
            down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            down.flags = []
            up.flags = []
            down.postToPid(pid)
            up.postToPid(pid)
        }
        return true
    }
}
