import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingLabelTarget: Identifiable {
    let bundleID: String
    let appName: String
    let row: KeyRow
    var id: String { bundleID + "\u{1}" + row.key }
}

struct SettingLabelEditor: View {
    let target: SettingLabelTarget
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var custom = CustomSettingLabels.shared
    @State private var title = ""
    @State private var imageURL: URL?
    @State private var preview: NSImage?
    @State private var lines: [String] = []
    @State private var reading = false
    @State private var status = ""
    @State private var saveError = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("項目名を編集")).font(.title2.weight(.semibold))
            Text(target.appName + " — " + target.row.key).font(.headline).textSelection(.enabled)
            Text(L("取得値：%@", describe(target.row.value))).lineLimit(2).foregroundStyle(.secondary)
            TextField(L("画面上の項目／意味"), text: $title).textFieldStyle(.roundedBorder)
            Text(L("入力した項目名はSettingsCourierの設定の書き出し・同期に含まれます。対象アプリの設定値は変更しません。"))
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(L("スクショを読み込む…")) { chooseImage() }.disabled(reading)
                if reading { ProgressView().controlSize(.small) }
                Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Text(L("読み取った文字を選ぶと入力欄に入ります。画像とキー・取得値を見比べ、必要なら修正して保存してください。"))
                .font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if let preview {
                        Image(nsImage: preview).resizable().scaledToFit()
                    } else {
                        Text(L("設定画面のスクショから項目名を読み取れます。画像は保存・送信しません。"))
                            .foregroundStyle(.secondary).padding(20)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                List(lines, id: \.self) { line in
                    Button { title = line } label: {
                        Text(line).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }.frame(width: 290)
            }.frame(height: 260)
            if !saveError.isEmpty { Text(saveError).foregroundStyle(.red).font(.caption) }
            HStack {
                Button(L("自動表示に戻す")) { title = "" }
                Spacer()
                Button(L("キャンセル")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("保存")) { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 760)
        .onAppear { title = custom.title(bundleID: target.bundleID, key: target.row.key) ?? target.row.label?.title ?? "" }
        .task(id: imageURL) {
            guard let url = imageURL else { return }
            reading = true; status = L("文字を読み取り中…"); lines = []; preview = nil
            do {
                let result = try await Task.detached(priority: .userInitiated) { try ScreenshotLabels.recognize(url) }.value
                guard !Task.isCancelled else { return }
                preview = NSImage(data: result.preview)
                lines = result.lines
                status = lines.isEmpty ? L("文字が見つかりませんでした。手入力するか、別の画像を選んでください。") : L("%@件の候補（キーとの対応は未確認）", String(lines.count))
            } catch {
                guard !Task.isCancelled else { return }
                status = L("画像を読み取れませんでした：%@", error.localizedDescription)
            }
            reading = false
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        imageURL = url
    }

    private func save() {
        do {
            try custom.save(title, bundleID: target.bundleID, key: target.row.key)
            dismiss()
        } catch { saveError = L("項目名を保存できませんでした：%@", error.localizedDescription) }
    }
}
