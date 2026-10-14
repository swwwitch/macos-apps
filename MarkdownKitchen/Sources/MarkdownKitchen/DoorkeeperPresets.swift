import AppKit
import SwiftUI

/// 「Doorkeeper用に整形」の色の組。メニューと設定で共有し、UserDefaultsに保存する
@MainActor
final class DoorkeeperPresets: ObservableObject {
    static let shared = DoorkeeperPresets()
    static let key = "markdownKitchen.doorkeeperPresets"

    @Published var items: [DoorkeeperPreset] {
        didSet { save() }
    }
    /// 前回「Doorkeeper用に整形」で使ったテーマ
    @Published var selectedID: UUID? {
        didSet { UserDefaults.standard.set(selectedID?.uuidString, forKey: Self.selectedKey) }
    }
    static let selectedKey = "markdownKitchen.doorkeeperPreset"
    var current: DoorkeeperPreset? { items.first { $0.id == selectedID } ?? items.first }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([DoorkeeperPreset].self, from: data) {
            items = saved
        } else {
            items = DoorkeeperPreset.defaults
        }
        selectedID = UserDefaults.standard.string(forKey: Self.selectedKey).flatMap(UUID.init)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    func add() {
        items.append(DoorkeeperPreset(name: L("新しいテーマ"), color: "#666666", tintPercent: 20))
    }
}

/// 「Doorkeeper用に整形」のメニュー：テーマを選んで適用する（原稿のバーと編集メニューで共有）
struct DoorkeeperThemeMenuItems: View {
    @ObservedObject private var presets = DoorkeeperPresets.shared
    var body: some View {
        if presets.items.isEmpty {
            Text(L("テーマがありません"))
        }
        ForEach(presets.items) { preset in
            Button { MarkdownStore.shared.convertMarkdownToHTML(preset) } label: {
                // The theme used last is checked.
                if preset.id == presets.current?.id { Label(preset.name, systemImage: "checkmark") } else { Text(preset.name) }
            }
        }
        Divider()
        Button(L("テーマを編集…")) { SettingsWindow.shared.show(tab: L("テーマ")) }
    }
}

/// 設定の「テーマ」タブ：名前・基本カラー・h3の背景の濃さ
struct DoorkeeperPresetsView: View {
    @ObservedObject private var presets = DoorkeeperPresets.shared

    var body: some View {
        SettingsSection(L("テーマ")) {
            Text(L("## と ### を、ここで決めた色の装飾付きHTML見出しに変換します。h2は基本カラーの背景に白文字、h3は基本カラーの文字・罫線と淡い背景です。"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach($presets.items) { $preset in
                PresetRow(preset: $preset) { presets.items.removeAll { $0.id == preset.id } }
            }
            Button { presets.add() } label: { Label(L("追加"), systemImage: "plus") }
        }
    }
}

private struct PresetRow: View {
    @Binding var preset: DoorkeeperPreset
    let remove: () -> Void

    private var swatch: Color {
        guard let (r, g, b) = DoorkeeperHTML.rgb(preset.color) else { return .clear }
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField(L("名前"), text: $preset.name)
                .frame(width: 110)
                .accessibilityLabel(L("名前"))
            // Clicking the swatch opens the standard color panel; the hex field keeps what was typed (e.g. #0AF).
            ColorPicker(L("基本カラー"), selection: Binding(get: { swatch }, set: { preset.color = hex($0) }), supportsOpacity: false)
                .labelsHidden()
            TextField("#0AF", text: $preset.color)
                .font(.system(.body, design: .monospaced))
                .frame(width: 80)
                .accessibilityLabel(L("基本カラー"))
            if DoorkeeperHTML.rgb(preset.color) == nil {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    .help(L("#0AF や #993366 の形で入力してください"))
                    .accessibilityLabel(L("#0AF や #993366 の形で入力してください"))
            }
            Text(L("h3の背景")).foregroundStyle(.secondary).fixedSize()
            TextField("20", value: $preset.tintPercent, format: .number)
                .frame(width: 40)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(L("h3の背景の濃さ（%）"))
            Text("%").foregroundStyle(.secondary).fixedSize()
            Spacer(minLength: 0)
            Button(role: .destructive, action: remove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .help(L("削除"))
                .accessibilityLabel(L("%@を削除", preset.name))
        }
    }

    private func hex(_ color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return preset.color }
        return String(format: "#%02X%02X%02X", Int(round(rgb.redComponent * 255)), Int(round(rgb.greenComponent * 255)), Int(round(rgb.blueComponent * 255)))
    }
}
