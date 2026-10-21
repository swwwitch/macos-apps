import SwiftUI
import AppKit

#if APP_STORE
struct EnvironmentView: View {
    @ObservedObject var store: AssociationStore
    var body: some View { SettingsTabs(sections: [(SettingsUI.launchTitle, AnyView(SettingsSection(SettingsUI.launchTitle) { LoginAtLaunchView().fixedSize(horizontal: false, vertical: true) })), (L("拡張子"), AnyView(ExtensionSettingsView(store: store))), (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())), (AboutSection.title, AnyView(AboutView()))]).padding(12) }
}
#else
struct EnvironmentView: View {
    @ObservedObject var store: AssociationStore
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(SettingsSection(SettingsUI.launchTitle) { LoginAtLaunchView().fixedSize(horizontal: false, vertical: true); MenuBarPresenceView() })),
            (L("拡張子"), AnyView(ExtensionSettingsView(store: store))),
            (L("バージョン"), AnyView(VersionSwitchView(store: store))),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ]).padding(12)
    }
}

#endif


struct ExtensionSettingsView: View {
    @ObservedObject var store: AssociationStore
    @State private var selection: Set<String> = []
    @State private var input = ""
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("拡張子一覧")).font(.title2.bold())
            Text(L("メインウインドウに表示する拡張子を管理します。"))
                .font(.callout).foregroundStyle(.secondary)
            List(selection: $selection) {
                ForEach(store.rows) { row in
                    HStack {
                        Text(row.extensionLabel).font(.system(.body, design: .monospaced)).frame(width: 150, alignment: .leading)
                        Text(row.displayName).foregroundStyle(.secondary).lineLimit(1)
                    }.tag(row.ext)
                }
            }.frame(height: 280)
            HStack {
                TextField(L("追加する拡張子（例: rtf）"), text: $input).textFieldStyle(.roundedBorder).onSubmit(add)
                Button(L("追加"), action: add).disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(L("選択を削除"), role: .destructive) {
                    store.removeExtensions(selection)
                    selection.removeAll()
                    error = nil
                }.disabled(selection.isEmpty)
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            Text(L("削除してもmacOSの関連付けは変わりません。別名をまとめた行は一緒に削除します。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(20).disabled(store.applying)
    }
    private func add() {
        let oldQuery = store.query
        guard store.add(input) else { error = L("有効な未登録の拡張子を入力してください。"); return }
        store.query = oldQuery
        if let normalized = AssociationService.normalized(input) { selection = [AssociationService.canonicalExtension(normalized)] }
        input = ""
        error = nil
    }
}
