import SwiftUI
import AppKit
var storeTitle: String { S("テキストを整える", "Transform text", "整理文本", "텍스트 정리") }
var storeDetail: String { S("テキストを貼り付け、処理を選んで変換します。", "Paste text and choose a transformation.", "粘贴文本并选择处理方式。", "텍스트를 붙여넣고 변환을 선택하세요.") }
struct StoreContent: View {
    @State private var input = ""
    @State private var output = ""
    @State private var operation = TextTransform.join
    @State private var prefix = ""
    @State private var suffix = ""
    @State private var width = 40
    @State private var error = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(S("処理", "Operation", "操作", "작업"), selection: $operation) {
                ForEach(TextTransform.allCases, id: \.rawValue) { Text($0.title).tag($0) }
            }
            if operation == .affixLines { HStack { TextField(S("行頭", "Prefix", "前缀", "접두사"), text: $prefix); TextField(S("行末", "Suffix", "后缀", "접미사"), text: $suffix) } }
            if operation == .wrapLines { Stepper(S("折り返し文字数", "Wrap width", "换行字符数", "줄바꿈 문자 수") + ": \(width)", value: $width, in: 1...1000) }
            HStack { VStack { Text(S("入力", "Input", "输入", "입력")); TextEditor(text: $input) }; VStack { Text(S("結果", "Result", "结果", "결과")); TextEditor(text: .constant(output)) } }
            HStack {
                Button(S("変換", "Transform", "转换", "변환")) { convert() }.keyboardShortcut(.return, modifiers: [.command])
                Button(S("結果をコピー", "Copy Result", "复制结果", "결과 복사")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output, forType: .string) }.disabled(output.isEmpty)
                Text(error).foregroundColor(.red)
            }
        }
    }
    private func convert() {
        error = ""
        do {
            switch operation {
            case .sum: output = try TextTransform.summedText(input)
            case .countText: output = LineTools.statistics(input)
            case .affixLines: output = LineTools.affix(input, prefix: prefix, suffix: suffix)
            case .wrapLines: output = TextTransform.wrappedText(input, count: width)
            default: output = operation.apply(input)
            }
        } catch { output = ""; self.error = error.localizedDescription }
    }
}
