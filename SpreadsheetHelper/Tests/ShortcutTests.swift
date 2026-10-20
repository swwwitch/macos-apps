import AppKit
import Carbon
@main struct ShortcutTests {
    static func main() {
        precondition(Shortcut.clean.code == 8 && Shortcut.clean.modifiers == UInt32(cmdKey | optionKey) && Shortcut.clean.modifiers == 2304)
        let data = try! JSONEncoder().encode(Shortcut.clean)
        precondition(try! JSONDecoder().decode(Shortcut.self, from: data) == Shortcut.clean)
        // Table commands: keys of the KM macros they replace, all distinct and never the clean key.
        let keys = SheetCommand.allCases.map { ($0.defaultShortcut.code, $0.defaultShortcut.modifiers) }
        precondition(SheetCommand.allCases.count == 26)
        precondition(Set(keys.map { "\($0.0):\($0.1)" }).count == keys.count, "duplicate default keys")
        let km = ["insert": "34:4096", "delete": "40:4096", "hideRowsColumns": "20:256", "jumpToA1": "115:6144", "replace": "3:256",
                  "centerAcross": "5:256", "uncenterAcross": "5:768", "powerQuery": "34:6400", "clearHyperlinks": "40:2304", "alignLeft": "37:768",
                  "newWindow": "45:4352", "alignRight": "15:768", "editCellStart": "32:4096", "pasteSpecial": "9:2048", "borders": "13:2304",
                  "previousSheet": "123:2048", "nextSheet": "124:2048", "sum": "24:2560", "numberFormat": "18:4608", "headerRow": "24:6400",
                  "pivotTable": "35:2304", "alternatingColors": "3:4096", "filter": "3:4608", "verticalCenterWrap": "22:4608", "formatSpecial": "3:6400", "centerAlign": "14:768"]
        for command in SheetCommand.allCases {
            precondition(km[command.rawValue] == "\(command.defaultShortcut.code):\(command.defaultShortcut.modifiers)", command.rawValue)
        }
        precondition(Set(SheetCommand.allCases.map(\.defaultShortcut.signature)).count == SheetCommand.allCases.count)
        precondition(!SheetCommand.allCases.contains { $0.defaultShortcut.signature == Shortcut.clean.signature })
        precondition(Set(SheetCommand.allCases.map(\.signature)).count == SheetCommand.allCases.count)
        precondition(SheetCommand.insert.scope.includes(.excel) && SheetCommand.insert.scope.includes(.spreadsheet))
        precondition(SheetCommand.centerAlign.scope.includes(.excel) && !SheetCommand.centerAlign.scope.includes(.spreadsheet))
        precondition(!SheetCommand.filter.scope.includes(.excel) && SheetCommand.pivotTable.scope == .both && SheetCommand.alternatingColors.scope == .sheets
                     && SheetCommand.verticalCenterWrap.scope == .sheets && SheetCommand.formatSpecial.scope == .sheets)
        precondition(SheetCommandRunner.isExcelDeleteItem("削除...") && SheetCommandRunner.isExcelDeleteItem("行の削除") && SheetCommandRunner.isExcelDeleteItem("列の削除"))
        precondition(!SheetCommandRunner.isExcelDeleteItem("シートの削除") && !SheetCommandRunner.isExcelDeleteItem("Delete Sheet"))
        precondition(SheetCommandRunner.localizedName(.alternatingColors, windowTitle: "表 - Google スプレッドシート") == "交互の背景色")
        precondition(SheetCommandRunner.localizedName(.decreaseDecimals, windowTitle: "表 - Google スプレッドシート") == "小数点以下の桁数を減らす")
        precondition(SheetCommandRunner.localizedName(.alternatingColors, windowTitle: "Sheet - Google Sheets") == "Alternating colors")
        precondition(SheetCommand.hideRowsColumns.scope == .both && SheetCommand.jumpToA1.scope == .excel && SheetCommand.headerRow.scope == .sheets)
        print("PASS: 26 table commands (KM keys), scopes, Excel delete items, Sheets search names")
        print("PASS: default ⌥⌘C (KM 8/2304), labels, persistence")
    }
}
