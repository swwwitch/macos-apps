import SwiftUI

/// Edit only the display label, scoped to the app and stored key of this cell.
struct InlineSettingLabel: View {
    let bundleID: String
    let row: KeyRow
    @State private var editing = false
    @State private var draft = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if editing {
                TextField(L("画面上の項目／意味"), text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit { save() }
                    .onExitCommand { cancel() }
                    .onAppear { focused = true }
                    .onChange(of: focused) { if !focused && editing && error == nil { save() } }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.label?.title ?? L("対応不明")).lineLimit(2)
                    if let label = row.label {
                        Text(label.evidence).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { beginEditing() }
                .accessibilityAction(named: Text(L("項目名を編集"))) { beginEditing() }
            }
        }
        .help(L("ダブルクリックで編集。Enterまたは別のセルへ移動で保存、Escでキャンセル。空欄で保存すると自動表示に戻ります。"))
        .alert(L("項目名を保存できませんでした"), isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil; focused = true } }
        )) { Button("OK") { error = nil; focused = true } } message: { Text(error ?? "") }
    }

    private func beginEditing() {
        draft = CustomSettingLabels.shared.title(bundleID: bundleID, key: row.key) ?? row.label?.title ?? ""
        editing = true
    }

    private func cancel() {
        editing = false
        focused = false
    }

    private func save() {
        guard editing else { return }
        do {
            try CustomSettingLabels.shared.save(draft, bundleID: bundleID, key: row.key)
            editing = false
            focused = false
        } catch { self.error = error.localizedDescription }
    }
}
