import AppKit
import SwiftUI

/// 条件を自分で作るスマートセット。条件はすべて／いずれかに一致。中身はライブラリが変わると変わる。
/// 共有ライブラリ（LibraryData.smartSets）に入れて、ほかのMacとそろえる
struct SmartSet: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var matchAll = true
    var rules: [SmartRule] = [SmartRule()]
}

/// 条件1つ。value は項目ごとの値（文字列で持つ）
struct SmartRule: Codable, Hashable, Sendable, Identifiable {
    enum Field: String, Codable, CaseIterable, Sendable {
        case name, prefix, vendor, kind, charset, n, ud, ap, nt, format, faceCount, characterCount, favorite, active, addedWithin

        var title: String {
            switch self {
            case .name: return L("名前に含む")
            case .prefix: return L("名前が次で始まる")
            case .vendor: return L("ベンダー")
            case .kind: return L("種類")
            case .charset: return L("文字セット")
            case .n: return L("N（JIS2004対応）")
            case .ud: return L("UD")
            case .ap: return L("AP版")
            case .nt: return L("新ゴ")
            case .format: return L("形式")
            case .faceCount: return L("ファミリーの書体数")
            case .characterCount: return L("収録文字数")
            case .favorite: return L("お気に入り")
            case .active: return L("アクティブ")
            case .addedWithin: return L("追加した日（日以内）")
            }
        }

        /// 選択肢（自由入力の項目は空）
        @MainActor var options: [(value: String, title: String)] {
            switch self {
            case .name, .prefix, .addedWithin: return []
            case .vendor: return LibraryStore.vendors.map { ($0.id, $0.title) }
            case .kind: return FontKind.allCases.map { ($0.rawValue, $0.title) }
            case .charset: return (FontNaming.charsets + [LibraryStore.noCharset]).map { ($0, $0 == LibraryStore.noCharset ? L("名前に無し") : $0) }
            case .n: return [("true", VariantFilter.n.optionTitle(true)), ("false", VariantFilter.n.optionTitle(false))]
            case .ud: return [("true", VariantFilter.ud.optionTitle(true)), ("false", VariantFilter.ud.optionTitle(false))]
            case .ap: return [("true", VariantFilter.ap.optionTitle(true)), ("false", VariantFilter.ap.optionTitle(false))]
            case .nt: return [("true", VariantFilter.nt.optionTitle(true)), ("false", VariantFilter.nt.optionTitle(false))]
            case .format: return ["OpenType (CFF)", "TrueType", "TrueType Collection", "OpenType Collection", "Datafork TrueType", "WOFF"].map { ($0, $0) }
            case .faceCount: return FaceCountRange.allCases.map { (String($0.rawValue), $0.title) }
            case .characterCount: return CharacterCountRange.allCases.map { (String($0.rawValue), $0.title) }
            case .favorite, .active: return [("true", L("はい")), ("false", L("いいえ"))]
            }
        }
    }

    var id = UUID()
    var field: Field = .name
    var value = ""
}

extension LibraryStore {
    /// スマートセットに当てはまるファイル（表示しているファイルの中から）
    func files(matching smartSet: SmartSet) -> [FontFile] {
        let base = visibleFiles
        let rules = smartSet.rules.filter { rule in rule.field.options.isEmpty ? !rule.value.trimmingCharacters(in: .whitespaces).isEmpty : !rule.value.isEmpty }
        guard !rules.isEmpty else { return [] }
        var faceCounts: [String: Int] = [:]
        if rules.contains(where: { $0.field == .faceCount }) {
            for file in base { faceCounts[file.family, default: 0] += file.faces.count }
        }
        return base.filter { file in
            let results = rules.map { matches(file, $0, faceCounts: faceCounts) }
            return smartSet.matchAll ? results.allSatisfy { $0 } : results.contains(true)
        }
    }

    private func matches(_ file: FontFile, _ rule: SmartRule, faceCounts: [String: Int]) -> Bool {
        let value = rule.value
        switch rule.field {
        case .name:
            let query = value.trimmingCharacters(in: .whitespaces)
            return file.faces.contains { $0.family.localizedCaseInsensitiveContains(query) || ($0.localizedFamily ?? "").localizedCaseInsensitiveContains(query)
                || $0.postScriptName.localizedCaseInsensitiveContains(query) } || file.fileName.localizedCaseInsensitiveContains(query)
        case .prefix:
            // ファミリー名・日本語名・PostScript名・ファイル名のどれかの先頭（大文字・小文字は区別しない）
            let query = value.trimmingCharacters(in: .whitespaces)
            let starts = { (text: String) in text.range(of: query, options: [.caseInsensitive, .anchored]) != nil }
            return file.faces.contains { starts($0.family) || starts($0.localizedFamily ?? "") || starts($0.postScriptName) } || starts(file.fileName)
        case .vendor: return Self.belongs(file, toVendor: value)
        case .kind: return FontKind(rawValue: value)?.matches(file) ?? false
        case .charset: return (FontNaming.charset(file.family) ?? Self.noCharset) == value
        case .n: return VariantFilter.n.value(file) == (value == "true")
        case .ud: return VariantFilter.ud.value(file) == (value == "true")
        case .ap: return VariantFilter.ap.value(file) == (value == "true")
        case .nt: return VariantFilter.nt.value(file) == (value == "true")
        case .format: return file.format == value
        case .faceCount: return Int(value).flatMap(FaceCountRange.init(rawValue:))?.contains(faceCounts[file.family] ?? 0) ?? false
        case .characterCount:
            guard let range = Int(value).flatMap(CharacterCountRange.init(rawValue:)), let count = file.characterCount else { return false }
            return range.contains(count)
        case .favorite: return data.favorites.contains(file.family) == (value == "true")
        case .active: return (states[file.id] == .active) == (value == "true")
        case .addedWithin:
            guard let days = Double(value.trimmingCharacters(in: .whitespaces)) else { return false }
            return file.added > Date().addingTimeInterval(-days * 24 * 60 * 60)
        }
    }
}

// MARK: - 編集の画面

@MainActor
final class SmartSetEditorWindow {
    static let shared = SmartSetEditorWindow()
    private var window: NSWindow?

    func show(_ smartSet: SmartSet, isNew: Bool) {
        window?.close()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = isNew ? L("新規スマートセット") : L("スマートセットを編集")
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: SmartSetEditorView(draft: smartSet, isNew: isNew)
            .frame(minWidth: 520, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity))
        hosting.sizingOptions = [.minSize]
        window.contentView = hosting
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }
}

/// 名前・すべて／いずれか・条件の行（項目と値）。当てはまるファイル数をその場で出す
private struct SmartSetEditorView: View {
    @State var draft: SmartSet
    let isNew: Bool
    @ObservedObject private var store = LibraryStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("名前") + L(" :"))
                TextField(L("名前"), text: $draft.name).textFieldStyle(.roundedBorder)
            }
            Picker(L("一致"), selection: $draft.matchAll) {
                Text(L("すべての条件に一致")).tag(true)
                Text(L("いずれかの条件に一致")).tag(false)
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            .labelsHidden()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach($draft.rules) { $rule in
                        HStack(spacing: 8) {
                            Picker(L("項目"), selection: Binding(get: { rule.field }, set: { rule.field = $0; rule.value = $0.options.first?.value ?? "" })) {
                                ForEach(SmartRule.Field.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 190)
                            if rule.field.options.isEmpty {
                                TextField(rule.field == .addedWithin ? L("日数") : L("文字"), text: $rule.value)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Picker(L("値"), selection: $rule.value) {
                                    ForEach(rule.field.options, id: \.value) { Text($0.title).tag($0.value) }
                                }
                                .labelsHidden()
                            }
                            Button { draft.rules.removeAll { $0.id == rule.id } } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless)
                                .disabled(draft.rules.count <= 1)
                                .accessibilityLabel(L("条件を外す"))
                            Button { draft.rules.append(SmartRule()) } label: { Image(systemName: "plus.circle") }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(L("条件を足す"))
                        }
                    }
                }
            }
            HStack {
                Text(L("当てはまるファイル %d個", store.files(matching: draft).count)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L("キャンセル")) { SmartSetEditorWindow.shared.close() }.keyboardShortcut(.cancelAction)
                Button(isNew ? L("作成") : L("保存")) {
                    store.saveSmartSet(draft)
                    SmartSetEditorWindow.shared.close()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }
}
