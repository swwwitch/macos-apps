import AppKit
import SwiftUI

/// ツールメニューの「フォント管理」：フォントの契約・管理のページへのリンク。設定で足し・外し・並べ替えができる（ユーザー指定）
struct FontServiceLink: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var url: String
}

enum FontServices {
    /// どのMacでも同じにするので設定の同期に載せる。JSON の文字列で持つ（@AppStorage で読めるように）
    static let key = "fontServiceLinks"
    static let defaults = [
        FontServiceLink(name: "Adobe Fonts", url: "https://fonts.adobe.com/fonts"),
        FontServiceLink(name: L("モリサワ"), url: "https://morisawafonts.com/fonts/search/"),
    ]

    /// 保存したリンク。まだ一度も変えていなければ初期値
    static func links(_ raw: String) -> [FontServiceLink] {
        guard !raw.isEmpty, let data = raw.data(using: .utf8),
              let links = try? JSONDecoder().decode([FontServiceLink].self, from: data) else { return defaults }
        // 1.52 までの Adobe Fonts の初期値（トップページ・my_fonts）は、一覧のページに読み替える（ユーザー指定）
        return links.map { link in
            var copy = link
            if ["https://fonts.adobe.com/", "https://fonts.adobe.com", "https://fonts.adobe.com/my_fonts"].contains(link.url) { copy.url = "https://fonts.adobe.com/fonts" }
            return copy
        }
    }

    static func encode(_ links: [FontServiceLink]) -> String {
        guard let data = try? JSONEncoder().encode(links) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static func open(_ link: FontServiceLink) {
        var text = link.url.trimmingCharacters(in: .whitespaces)
        if !text.contains("://") { text = "https://" + text }
        if let url = URL(string: text) { NSWorkspace.shared.open(url) }
    }
}

/// ツールメニューの中身。リンクが無ければ設定を開く項目だけ出す
struct FontServicesMenu: View {
    @AppStorage(FontServices.key) private var raw = ""

    var body: some View {
        let links = FontServices.links(raw).filter { !$0.name.isEmpty && !$0.url.isEmpty }
        ForEach(links) { link in
            Button(link.name) { FontServices.open(link) }
        }
        if !links.isEmpty { Divider() }
        Button(L("リンクを編集…")) { SettingsWindow.shared.show() }
    }
}

/// 設定の「フォント管理」：リンクの名前と URL を編集する
struct FontServicesSection: View {
    @AppStorage(FontServices.key) private var raw = ""
    @State private var selection: UUID?

    private var links: [FontServiceLink] { FontServices.links(raw) }

    var body: some View {
        SettingsSection(L("フォント管理")) {
            VStack(spacing: 4) {
                ForEach(links) { link in
                    HStack(spacing: 6) {
                        TextField(L("名前"), text: binding(link.id, \.name))
                            .textFieldStyle(.roundedBorder).frame(width: 140)
                        TextField("https://", text: binding(link.id, \.url))
                            .textFieldStyle(.roundedBorder)
                        Button { move(link.id, by: -1) } label: { Image(systemName: "chevron.up") }
                            .buttonStyle(.borderless).disabled(link.id == links.first?.id)
                            .help(L("上へ")).accessibilityLabel(L("上へ"))
                        Button { move(link.id, by: 1) } label: { Image(systemName: "chevron.down") }
                            .buttonStyle(.borderless).disabled(link.id == links.last?.id)
                            .help(L("下へ")).accessibilityLabel(L("下へ"))
                        Button { save(links.filter { $0.id != link.id }) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .help(L("このリンクを外す")).accessibilityLabel(L("このリンクを外す"))
                    }
                }
            }
            HStack {
                Button { save(links + [FontServiceLink(name: "", url: "")]) } label: { Image(systemName: "plus") }
                    .help(L("リンクを足す")).accessibilityLabel(L("リンクを足す"))
                Spacer()
                Button(L("初期値に戻す")) { raw = "" }.disabled(raw.isEmpty)
            }
            Text(L("「ツール」メニューの「フォント管理」に出すページです。フォントの契約や管理のページを足しておくと、メニューからブラウザーで開けます。"))
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func binding(_ id: UUID, _ path: WritableKeyPath<FontServiceLink, String>) -> Binding<String> {
        Binding(get: { links.first { $0.id == id }?[keyPath: path] ?? "" },
                set: { value in
                    var list = links
                    guard let index = list.firstIndex(where: { $0.id == id }) else { return }
                    list[index][keyPath: path] = value
                    save(list)
                })
    }

    private func move(_ id: UUID, by offset: Int) {
        var list = links
        guard let index = list.firstIndex(where: { $0.id == id }), list.indices.contains(index + offset) else { return }
        list.swapAt(index, index + offset)
        save(list)
    }

    private func save(_ list: [FontServiceLink]) { raw = FontServices.encode(list) }
}
