import AppKit
import SwiftUI

let allKey = "__all"
let changedKey = "__changed"
let unsetTag = "__unset"
/// 主画面に操作手順を出すか（設定の「表示」タブで切り替える）
let showGuideKey = "showGuide"

/// 「変更後」の列。選択肢があればメニュー、なければ入力欄
struct ValueEditor: View {
    let entry: Entry
    @ObservedObject var store = Store.shared
    @State private var text = ""
    @FocusState private var focused: Bool

    var options: [(key: String, label: String)] {
        let pairs = entry.item.choices.isEmpty && isBoolean(entry.current ?? entry.target.object)
            ? Array(onOff) : Array(entry.item.choices)
        var result: [(key: String, label: String)] = []
        let selected = entry.target.object.map(choiceKey)
        for p in pairs where p.key == selected || !result.contains(where: { $0.label == L(p.value) }) {
            result.append((p.key, L(p.value)))
        }
        // 選択肢にない値が入っているときもメニューに出す（選択肢のない項目は入力欄のまま）
        if !result.isEmpty, let selected, !result.contains(where: { $0.key == selected }) {
            result.append((selected, selected))
        }
        return result
    }

    var isEditableText: Bool {
        switch entry.current ?? entry.target.object {
        case nil, is NSNumber, is String: return true
        default: return false
        }
    }

    var body: some View {
        if !options.isEmpty {
            Picker("", selection: Binding(
                get: { entry.target.object.map(choiceKey) ?? unsetTag },
                set: { $0 == unsetTag ? store.setTarget(entry.id, .unset) : store.setTarget(entry.id, key: $0) }
            )) {
                ForEach(options, id: \.key) { Text($0.label).tag($0.key) }
                Divider()
                Text(L("未設定（既定値）")).tag(unsetTag)
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel(L("%@の変更後の値", L(entry.item.label)))
        } else if isEditableText {
            TextField(L("未設定（既定値）"), text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { store.setTarget(entry.id, text: text) }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { store.setTarget(entry.id, text: text) }
                }
                .onAppear { text = entry.target.object.map(choiceKey) ?? "" }
                .onChange(of: entry.target) { _, t in text = t.object.map(choiceKey) ?? "" }
                .accessibilityLabel(L("%@の変更後の値", L(entry.item.label)))
        } else {
            Text(describe(entry.target.object, entry.item)).foregroundStyle(.secondary)
                .help(L("この型の値はここでは編集できません"))
        }
    }
}

struct ContentView: View {
    @ObservedObject var store = Store.shared
    @State private var selection: String = allKey
    @State private var search = ""
    @State private var showAdd = false
    @State private var confirmApply = false
    @State private var isTargeted = false
    @State private var selectedIDs = Set<String>()
    @AppStorage(showGuideKey) private var showGuide = true

    var categories: [(name: String, symbol: String)] {
        let present = Set(store.entries.map(\.item.category))
        return categoryOrder.filter { present.contains($0.name) }
    }

    var visible: [Entry] {
        store.entries.filter { e in
            switch selection {
            case allKey: break
            case changedKey: if !e.isChanged { return false }
            default: if e.item.category != selection { return false }
            }
            if search.isEmpty { return true }
            return [L(e.item.label), e.item.label, e.item.key, e.item.domains[0]]
                .contains { $0.localizedCaseInsensitiveContains(search) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 12) {
                sidebar
                VStack(spacing: 8) {
                    if showGuide { guide }
                    tableBar
                    table
                }
            }
            .padding(.horizontal, 16)
            footer
        }
        .background(Color(nsColor: AppSurface.color), ignoresSafeAreaEdges: .all)
        .sheet(isPresented: $showAdd) { AddItemView() }
        .alert(L("%@件の設定をMacに適用しますか？", String(store.changed.count)), isPresented: $confirmApply) {
            Button(L("適用")) { store.apply() }
            Button(L("キャンセル"), role: .cancel) {}
        } message: {
            if store.changed.contains(where: { !administratorDomains.isDisjoint(with: $0.item.domains) }) {
                Text(L("元の値はバックアップします。DockやFinderなどは再起動します。") + "\n\n" + L("起動時のサウンドとキャップスロックインジケータの書き込みでは、管理者のパスワードを求められます。"))
            } else {
                Text(L("元の値はバックアップします。DockやFinderなどは再起動します。"))
            }
        }
        .alert(store.message?.title ?? "", isPresented: Binding(
            get: { store.message != nil }, set: { if !$0 { store.message = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(store.message?.body ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .presetLoaded)) { _ in
            selection = changedKey
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { openPreset(url) }
            }
            return true
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: currentAppIcon()).resizable().scaledToFit()
                .frame(width: 44, height: 44).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Macの設定をまとめて変更"))
                    .font(.title2.weight(.semibold))
                Text(L("値を選んで適用し、ほかのMacへ書き出して移せます"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { openPreset() } label: { Label(L("開く…"), systemImage: "folder") }
                .help(L("書き出したセットを開き、その値を「変更後」に入れる"))
            Button { savePreset() } label: { Label(L("書き出す…"), systemImage: "square.and.arrow.up") }
                .help(L("全項目の「変更後」の値をセットとしてファイルに保存"))
            Button { SettingsWindow.shared.show() } label: {
                Label(L("設定"), systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var sidebar: some View {
        List(selection: Binding(get: { selection }, set: { if let value = $0 { selection = value } })) {
            Label(L("すべて"), systemImage: "list.bullet").tag(allKey)
            Label(L("変更した項目"), systemImage: "pencil")
                .badge(store.changed.count)
                .tag(changedKey)
            Section(L("カテゴリ")) {
                ForEach(categories, id: \.name) { c in
                    Label(L(c.name), systemImage: c.symbol).tag(c.name)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(width: 210)
    }

    private var guide: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle").font(.title2).foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(markdown(L("**設定を変える**　「変更後」の列で値を選ぶか入力し、右下の「適用」を押します。")))
                Text(markdown(L("**新しいMacへ移す**　「書き出す…」で今の設定一式をファイルに保存し、新しいMacでそのファイルを「開く…」で読み込んで「適用」を押します。")))
                Text(L("変更を取り消すには、行を右クリックして「現在の値に戻す」を選びます。"))
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button { showGuide = false } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .help(L("この説明を隠す（設定の「表示」タブで再表示できます）"))
                .accessibilityLabel(L("この説明を隠す"))
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var tableBar: some View {
        HStack(spacing: 8) {
            SearchField(placeholder: L("項目名・キーで検索"), text: $search)
                .frame(maxWidth: 280)
            Spacer()
            MyPresetMenu()
            Button { loadRecommended() } label: { Label(L("おすすめの設定"), systemImage: "sparkles") }
                .help(L("おすすめの設定を「変更後」に入れる"))
            Button { store.refreshCurrent() } label: { Label(L("読み直す"), systemImage: "arrow.clockwise") }
                .help(L("現在の値を読み直す"))
            Button { showAdd = true } label: { Label(L("項目を追加…"), systemImage: "plus") }
                .help(L("一覧にないドメインとキーを追加"))
        }
    }

    private var table: some View {
        Table(visible, selection: $selectedIDs) {
            TableColumn(L("項目")) { e in
                HStack(spacing: 6) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .opacity(e.isChanged ? 1 : 0)
                        .accessibilityHidden(!e.isChanged)
                        .accessibilityLabel(L("変更あり"))
                    Text(L(e.item.label)).fontWeight(e.isChanged ? .semibold : .regular)
                }
                .help(e.item.domains.contains(featureFlagDomain) ? L("このMacでは管理者のパスワードなしに読み取れないため、PrefsPresetで最後に適用した値を「現在の値」に表示します。書き込みでは管理者のパスワードを求められます。")
                      : e.item.domains.contains(nvramDomain) ? L("書き込みでは管理者のパスワードを求められます。")
                      : e.isChanged ? L("「適用」で書き換わります") : "")
            }
            .width(min: 220, ideal: 320)
            TableColumn(L("現在の値")) { e in
                Text(describe(e.current, e.item))
                    .foregroundStyle(e.current == nil ? .secondary : .primary)
            }
            .width(min: 90, ideal: 140)
            TableColumn(L("変更後")) { e in
                ValueEditor(entry: e)
            }
            .width(min: 140, ideal: 180)
            TableColumn(L("ドメイン / キー")) { e in
                Text("\(e.item.domains[0])  \(e.item.key)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .width(min: 160, ideal: 260)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            Button(L("現在の値に戻す")) { store.revert(Array(ids)) }
            Button(L("未設定（既定値）にする")) { ids.forEach { store.setTarget($0, .unset) } }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 3)
            }
        }
    }

    private var footer: some View {
        HStack {
            if store.changed.isEmpty {
                Text(L("変更した項目はありません"))
                    .foregroundStyle(.secondary)
            } else {
                Button(L("変更した項目 %@件", String(store.changed.count))) { selection = changedKey }
                    .buttonStyle(.link)
            }
            Spacer()
            Button(L("すべての変更を取り消す")) { store.revertAll() }
                .disabled(store.changed.isEmpty)
            Button(L("適用")) { confirmApply = true }
                .keyboardShortcut(.defaultAction)
                .disabled(store.changed.isEmpty || store.isApplying)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var domain = ""
    @State private var key = ""
    @State private var label = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("項目を追加")).font(.headline)
            Form {
                TextField(L("ドメイン"), text: $domain, prompt: Text("com.apple.dock"))
                TextField(L("キー"), text: $key, prompt: Text("autohide"))
                TextField(L("表示名"), text: $label, prompt: Text(L("省略するとキー名")))
            }
            Text(L("「追加した項目」カテゴリに現在の値とともに並びます。全体の設定はNSGlobalDomainと入力します。"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("キャンセル")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("追加")) {
                    Store.shared.addCustom(domain: domain.trimmingCharacters(in: .whitespaces),
                                           key: key.trimmingCharacters(in: .whitespaces), label: label)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(domain.trimmingCharacters(in: .whitespaces).isEmpty || key.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

/// 標準の検索フィールド。入力があると×ボタンが出て、押すかEscで検索語を消せる
struct SearchField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        field.setAccessibilityLabel(placeholder)
        return field
    }
    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
    }
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSSearchField { text.wrappedValue = field.stringValue }
        }
        // ×ボタンで消したときは controlTextDidChange が来ないことがあるので、ここでも拾う
        func searchFieldDidEndSearching(_ sender: NSSearchField) { text.wrappedValue = "" }
    }
}

/// 太字（**…**）だけを含む説明文
private func markdown(_ text: String) -> AttributedString {
    (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
}

/// 見出しの左に出す、バンドル内の現行アイコン
@MainActor private func currentAppIcon() -> NSImage {
    let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String ?? "AppIcon"
    let filename = name.hasSuffix(".icns") ? name : name + ".icns"
    if let url = Bundle.main.resourceURL?.appendingPathComponent(filename),
       let image = NSImage(contentsOf: url) { return image }
    return NSApp.applicationIconImage
}
