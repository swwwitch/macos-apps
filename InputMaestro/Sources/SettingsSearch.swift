import AppKit
import SwiftUI

struct SettingsSearchPage: View {
    @ObservedObject var model: Model
    @State private var query = ""
    let sections: [(String, AnyView)]
    var entries: [SettingsSearchEntry] {
        var result = sections.enumerated().map { SettingsSearchEntry(id: "page.\($0.offset)", title: $0.element.0, keywords: "", tab: $0.offset, anchor: "page.\($0.offset)") }
        result += [
            .init(id: "launch", title: SettingsUI.launchTitle, keywords: L("search.launch"), tab: 0, anchor: "page.0"),
            .init(id: "keyboard", title: L("keyboardDisplay"), keywords: "ANSI JIS US Caps Lock " + L("kb.layout"), tab: 0, anchor: "keyboardDisplay"),
            .init(id: "trigger", title: L("triggerTitle"), keywords: "Caps Lock Control " + L("editingTab"), tab: 2, anchor: "editing.trigger"),
            .init(id: "numpad.trigger", title: L("numpadTab"), keywords: "Caps Lock fn " + L("triggerTitle"), tab: 1, anchor: "page.1"),
            .init(id: "permissions", title: L("openPermissions"), keywords: L("search.permissions"), tab: 0, anchor: "permissions")
        ]
        result += CommandTable.all.map { .init(id: "cmd." + $0.id, title: $0.title, keywords: $0.label + " " + $0.alternates.map(\.label).joined(separator: " "), tab: 2, anchor: "cmd." + $0.id) }
        return result
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(L("search.settings"), text: $query).textFieldStyle(.roundedBorder).accessibilityLabel(L("search.settings"))
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let matches = SettingsSearchIndex.matches(query, in: entries)
                if matches.isEmpty { Text(L("search.none")).foregroundColor(.secondary) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(matches) { item in
                            Button {
                                model.settingsTab = item.tab; model.settingsFocus = item.anchor; query = ""
                            } label: {
                                HStack { Text(item.title); Spacer(); Text(sections[item.tab].0).foregroundColor(.secondary) }
                            }.buttonStyle(.plain).padding(4)
                        }
                    }
                }.frame(maxHeight: 150)
            }
            MainTabs(sections: sections.enumerated().map { index, section in
                (section.0, AnyView(SearchableSettingsContent(content: section.1, index: index, focus: model.settingsFocus)))
            }, selection: $model.settingsTab, storesSelection: true)
        }
    }
}
struct SearchableSettingsContent: View {
    let content: AnyView
    let index: Int
    let focus: String
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView { content.frame(maxWidth: .infinity, alignment: .leading).padding(20).id("page.\(index)") }
                .onAppear { if !focus.isEmpty { proxy.scrollTo(focus, anchor: .top) } }
                .onChange(of: focus) { value in DispatchQueue.main.async { proxy.scrollTo(value, anchor: .top) } }
        }
    }
}
