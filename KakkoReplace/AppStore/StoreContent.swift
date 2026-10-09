import SwiftUI
import AppKit
var storeTitle: String { S("括弧を置換する", "Replace brackets", "替换括号", "괄호 바꾸기") }
var storeDetail: String { S("テキストを貼り付け、括弧を選んで変換します。", "Paste text and choose brackets.", "粘贴文本并选择括号。", "텍스트를 붙여넣고 괄호를 선택하세요.") }
struct StoreContent: View {
    @State private var input = ""
    @State private var output = ""
    @State private var action = "round"
    @State private var force = false
    @State private var trim = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(S("処理", "Operation", "操作", "작업"), selection: $action) {
                ForEach(BracketAction.pairs) { Text($0.title).tag($0.id) }
                Text(S("外側の括弧を削除", "Remove Outer Brackets", "删除外层括号", "바깥 괄호 제거")).tag("removeOuter")
                Text(S("すべての括弧を削除", "Remove All Brackets", "删除所有括号", "모든 괄호 제거")).tag("removeAll")
                Text(S("前後にスペース", "Add Surrounding Spaces", "前后添加空格", "앞뒤 공백 추가")).tag("spaces")
            }
            HStack { Toggle(S("常に囲む", "Always Wrap", "始终包围", "항상 감싸기"), isOn: $force); Toggle(S("括弧周辺のスペースを除去", "Trim Spaces Around Brackets", "清除括号旁空格", "괄호 주변 공백 제거"), isOn: $trim) }.disabled(BracketAction.operations.contains(action))
            HStack { VStack { Text(S("入力", "Input", "输入", "입력")); TextEditor(text: $input) }; VStack { Text(S("結果", "Result", "结果", "결과")); TextEditor(text: .constant(output)) } }
            HStack {
                Button(S("変換", "Transform", "转换", "변환")) { output = BracketEdit.make(input, at: 0, action: action, force: force, trimSpaces: trim).replacement }.keyboardShortcut(.return, modifiers: [.command])
                Button(S("結果をコピー", "Copy Result", "复制结果", "결과 복사")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output, forType: .string) }.disabled(output.isEmpty)
            }
        }
    }
}
