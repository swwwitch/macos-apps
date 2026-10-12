import SwiftUI

struct SettingsView: View {
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(spacing: 16) {
                Form { Section(SettingsUI.launchTitle) {
                    LoginAtLaunchView().fixedSize(horizontal: false, vertical: true)
                    MenuBarPresenceView()
                } }.formStyle(.grouped)
                SettingsSection(AccessibilityText.text("title")) { AccessibilityPermissionView(required: true, showsTitle: false) }
            })),
            (L("照合元"), AnyView(SourcesSettings())),
            (AboutSection.title, AnyView(AboutView()))
        ]).padding(12)
    }
}

/// 照合する定義元の選択・並び順・独自の照合元
private struct SourcesSettings: View {
    @ObservedObject private var store = HotkeyStore.shared
    @State private var order = HotkeySource.ordered
    @State private var revision = 0
    @State private var editing: CustomSource?
    @State private var deleting: CustomSource?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("照合元")) {
                List {
                    ForEach(order) { source in row(source) }
                        .onMove { from, to in
                            order.move(fromOffsets: from, toOffset: to)
                            HotkeySource.saveOrder(order)
                            store.objectWillChange.send()
                        }
                }
                .listStyle(.bordered(alternatesRowBackgrounds: false))
                .frame(height: CGFloat(order.count) * 28 + 8)
                .id(revision)
                HStack {
                    Button { editing = CustomSource(name: L("新しい照合元")) } label: {
                        Label(L("照合元を追加…"), systemImage: "plus")
                    }
                    Spacer()
                    Button(L("並び順を戻す")) {
                        UserDefaults.standard.removeObject(forKey: HotkeySource.orderKey)
                        refresh()
                    }
                }
                Text(L("ドラッグで並び替えると、照合結果もこの順に並びます。独自の照合元には、設定ファイルを読めないアプリのホットキーを手入力で登録できます。設定ファイルは読むだけで書き換えません。"))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(item: $editing) { source in
            CustomSourceEditor(source: source) { saved in
                var list = CustomSources.load()
                if let index = list.firstIndex(where: { $0.id == saved.id }) { list[index] = saved } else { list.append(saved) }
                CustomSources.save(list)
                refresh()
            }
        }
        .alert(L("「%@」を削除しますか？", deleting?.name ?? ""), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button(L("キャンセル"), role: .cancel) { deleting = nil }
            Button(L("削除"), role: .destructive) {
                if let deleting {
                    CustomSources.save(CustomSources.load().filter { $0.id != deleting.id })
                    UserDefaults.standard.removeObject(forKey: deleting.source.settingKey)
                    HotkeySource.saveOrder(order.filter { $0 != deleting.source })
                }
                deleting = nil
                refresh()
            }
        } message: {
            Text(L("登録したホットキーもすべて削除します。"))
        }
    }

    private func row(_ source: HotkeySource) -> some View {
        HStack(spacing: 8) {
            Toggle(isOn: binding(source)) {
                HStack(spacing: 8) {
                    Image(nsImage: source.icon).resizable().frame(width: 18, height: 18).accessibilityHidden(true)
                    Text(source.title).lineLimit(1)
                    if let count = store.loadedAt.map({ _ in store.count(for: source) }), source.isIncluded {
                        Text(L("%@件", String(count))).foregroundStyle(.secondary)
                    }
                }
            }
            .toggleStyle(.checkbox)
            Spacer(minLength: 0)
            if let custom = source.custom {
                Button { editing = custom } label: { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .help(L("編集"))
                    .accessibilityLabel(L("「%@」を編集", custom.name))
                Button { deleting = custom } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help(L("削除"))
                    .accessibilityLabel(L("「%@」を削除", custom.name))
            }
        }
        .frame(height: 20)
    }

    private func refresh() {
        order = HotkeySource.ordered
        revision += 1
        store.reload()
    }

    private func binding(_ source: HotkeySource) -> Binding<Bool> {
        Binding(get: { source.isIncluded }, set: {
            UserDefaults.standard.set($0, forKey: source.settingKey)
            revision += 1
            store.reload()
        })
    }
}

/// 独自の照合元の編集（名前と、キー・名前・効く範囲の組）
private struct CustomSourceEditor: View {
    @State var source: CustomSource
    let onSave: (CustomSource) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var recordingID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("独自の照合元")).font(.headline)
            HStack {
                Text(L("名前 :"))
                TextField("", text: $source.name).textFieldStyle(.roundedBorder)
            }
            List {
                HStack(spacing: 8) {
                    Text(L("キー")).frame(width: 110, alignment: .leading)
                    Text(L("名前")).frame(maxWidth: .infinity, alignment: .leading)
                    Text(L("効く範囲（空欄はすべてのアプリ）")).frame(width: 190, alignment: .leading)
                    Color.clear.frame(width: 18)
                }
                .font(.caption).foregroundStyle(.secondary)
                ForEach($source.hotkeys) { $hotkey in
                    HStack(spacing: 8) {
                        Button { record(hotkey.id) } label: {
                            Text(recordingID == hotkey.id ? L("キーを押す…") : hotkey.combo?.display ?? L("クリックして設定"))
                                .frame(width: 98)
                        }
                        .frame(width: 110, alignment: .leading)
                        TextField("", text: $hotkey.title).textFieldStyle(.roundedBorder)
                        TextField("", text: $hotkey.scope).textFieldStyle(.roundedBorder).frame(width: 190)
                        Button { source.hotkeys.removeAll { $0.id == hotkey.id } } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .help(L("削除"))
                            .frame(width: 18)
                    }
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: false))
            .frame(minHeight: 200)
            Button { source.hotkeys.append(CustomHotkey()) } label: { Label(L("ホットキーを追加"), systemImage: "plus") }
            HStack {
                Spacer()
                Button(L("キャンセル")) { cancelRecording(); dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L("保存")) {
                    cancelRecording()
                    let name = source.name.trimmingCharacters(in: .whitespaces)
                    source.name = name.isEmpty ? L("新しい照合元") : name
                    onSave(source)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 580, height: 420)
    }

    private func record(_ id: UUID) {
        if recordingID == id { cancelRecording(); return }
        recordingID = id
        KeyRecorder.shared.start { combo in
            if let combo, let index = source.hotkeys.firstIndex(where: { $0.id == id }) { source.hotkeys[index].combo = combo }
            recordingID = nil
        }
    }

    private func cancelRecording() {
        if recordingID != nil { KeyRecorder.shared.cancel() }
        recordingID = nil
    }
}
