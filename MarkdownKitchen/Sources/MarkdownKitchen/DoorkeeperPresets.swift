import AppKit
import SwiftUI

/// 「Doorkeeper用に整形」の色の組。メニューと設定で共有し、UserDefaultsに保存する
@MainActor
final class DoorkeeperPresets: ObservableObject {
    static let shared = DoorkeeperPresets()
    nonisolated static let key = "markdownKitchen.doorkeeperPresets"

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
        items = Self.stored
        selectedID = UserDefaults.standard.string(forKey: Self.selectedKey).flatMap(UUID.init)
    }

    private static var stored: [DoorkeeperPreset] {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([DoorkeeperPreset].self, from: $0) } ?? DoorkeeperPreset.defaults
    }

    /// 設定の読み込み・同期の後に UserDefaults から読み直す（古い一覧で書き戻さない）
    func reload() {
        let saved = Self.stored
        if saved != items { items = saved }
        let id = UserDefaults.standard.string(forKey: Self.selectedKey).flatMap(UUID.init)
        if id != selectedID { selectedID = id }
    }

    /// 読み込んだ設定ファイルのテーマのうち、まだ無いもの（IDで判定）を今の一覧に足す（SettingsSync の「追加する」）
    nonisolated static func merge(_ file: NSDictionary, _ current: NSDictionary) -> (values: NSDictionary, added: Int) {
        func decode(_ value: Any?) -> [DoorkeeperPreset]? { (value as? Data).flatMap { try? JSONDecoder().decode([DoorkeeperPreset].self, from: $0) } }
        let values = NSMutableDictionary(dictionary: current)
        // 一覧を保存していなければ既定のテーマが使われている
        var list = decode(current[key]) ?? DoorkeeperPreset.defaults
        let new = (decode(file[key]) ?? []).filter { item in !list.contains { $0.id == item.id } }
        guard !new.isEmpty else { return (values, 0) }
        list += new
        if let data = try? JSONEncoder().encode(list) { values[key] = data }
        return (values, new.count)
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
    @ObservedObject private var shortcuts = ShortcutStore.shared
    var body: some View {
        if presets.items.isEmpty {
            Text(L("テーマがありません"))
        }
        ForEach(presets.items) { preset in
            Button { MarkdownStore.shared.convertMarkdownToHTML(preset) } label: {
                // The theme used last is checked.
                if preset.id == presets.current?.id { Label(preset.name, systemImage: "checkmark") } else { Text(preset.name) }
            }
            .keyboardShortcut(shortcuts.shortcut(id: "theme." + preset.id.uuidString)?.swiftUI)
        }
        Divider()
        ShortcutButton(action: .plainMarkdown)
        Divider()
        ShortcutButton(action: .editThemes)
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

/// 設定の「テーマ」：「divブロックで囲む」の囲みの背景色と余白
struct DivBoxSettingsView: View {
    private typealias Box = LineTools.DivBox
    @AppStorage(LineTools.DivBox.backgroundKey) private var background = LineTools.DivBox.defaultBackground
    @AppStorage(LineTools.DivBox.paddingKey) private var padding = LineTools.DivBox.defaultPadding
    @AppStorage(LineTools.DivBox.radiusKey) private var radius = LineTools.DivBox.defaultRadius
    @AppStorage(LineTools.DivBox.marginKey) private var margin = LineTools.DivBox.defaultMargin

    private var swatch: Color {
        guard let (r, g, b) = DoorkeeperHTML.rgb(background) else { return .clear }
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    var body: some View {
        SettingsSection(L("divブロック")) {
            Text(L("ツールの「divブロックで囲む」で使う囲みの見た目です。余白はCSSの書き方（例：1px 20px 15px）で入れます。"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Text(L("背景色")).gridColumnAlignment(.trailing)
                    HStack(spacing: 8) {
                        ColorPicker(L("背景色"), selection: Binding(get: { swatch }, set: { background = hex($0) }), supportsOpacity: false)
                            .labelsHidden()
                        TextField(Box.defaultBackground, text: $background)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 90)
                            .accessibilityLabel(L("背景色"))
                        if DoorkeeperHTML.rgb(background) == nil {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                .help(L("#0AF や #993366 の形で入力してください"))
                                .accessibilityLabel(L("#0AF や #993366 の形で入力してください"))
                        }
                    }
                }
                row(L("内側の余白（padding）"), $padding, Box.defaultPadding)
                row(L("角の丸み（border-radius）"), $radius, Box.defaultRadius)
                row(L("下の余白（margin-bottom）"), $margin, Box.defaultMargin)
            }
            Text(LineTools.divOpen)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Button(L("初期値に戻す")) {
                background = Box.defaultBackground
                padding = Box.defaultPadding
                radius = Box.defaultRadius
                margin = Box.defaultMargin
            }
            .disabled(background == Box.defaultBackground && padding == Box.defaultPadding && radius == Box.defaultRadius && margin == Box.defaultMargin)
        }
    }

    private func row(_ title: String, _ value: Binding<String>, _ placeholder: String) -> some View {
        GridRow {
            Text(title)
            TextField(placeholder, text: value)
                .font(.system(.body, design: .monospaced))
                .frame(width: 160)
                .accessibilityLabel(title)
        }
    }

    private func hex(_ color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return background }
        return String(format: "#%02X%02X%02X", Int(round(rgb.redComponent * 255)), Int(round(rgb.greenComponent * 255)), Int(round(rgb.blueComponent * 255)))
    }
}
