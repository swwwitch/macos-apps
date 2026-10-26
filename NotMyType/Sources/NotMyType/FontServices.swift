import AppKit
import SwiftUI

/// 固定のリンク集と、ユーザーが編集できる追加リンク。
struct FontServiceLink: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var url: String
    var category: String? = nil
}

enum FontServices {
    /// どのMacでも同じにするので設定の同期に載せる。JSON の文字列で持つ（@AppStorage で読めるように）
    static let key = "fontServiceLinks"
    static let categories = ["vendors", "examples", "identify", "other"]
    static func categoryTitle(_ category: String) -> String {
        switch category {
        case "vendors": return L("フォントベンダー・配布サービス")
        case "examples": return L("フォント見本・使用例の検索")
        case "identify": return L("フォント識別・検索")
        default: return L("その他")
        }
    }
    static let defaults = [
        FontServiceLink(name: "Adobe Fonts", url: "https://fonts.adobe.com/fonts", category: "vendors"),
        FontServiceLink(name: "Google Fonts", url: "https://fonts.google.com/", category: "vendors"),
        FontServiceLink(name: "フォントワークスLETS", url: "https://lets.fontworks.co.jp/fonts", category: "vendors"),
        FontServiceLink(name: "Morisawa Fonts（モリサワ）", url: "https://morisawafonts.com/fonts/search/", category: "vendors"),
        FontServiceLink(name: "Type Project（タイププロジェクト）", url: "https://typeproject.com/", category: "vendors"),
        FontServiceLink(name: "OH MY FONT", url: "https://ohmyfont.jp/", category: "vendors"),
        FontServiceLink(name: "MyFonts", url: "https://www.myfonts.com/", category: "vendors"),
        FontServiceLink(name: "デザインポケット", url: "https://r.8to.jp/26SpFxAqU3bF", category: "vendors"),
        FontServiceLink(name: "nipponia", url: "https://nipponia.in/typefaces/", category: "vendors"),
        FontServiceLink(name: "Fonts In Use", url: "https://fontsinuse.com/", category: "examples"),
        FontServiceLink(name: "Typewolf", url: "https://www.typewolf.com/", category: "examples"),
        FontServiceLink(name: "WhatTheFont", url: "https://www.myfonts.com/pages/whatthefont", category: "identify"),
        FontServiceLink(name: "Fontspring Matcherator", url: "https://www.fontspring.com/matcherator", category: "identify"),
        FontServiceLink(name: "What the Free Font", url: "https://whatthefreefont.com/", category: "identify"),
        FontServiceLink(name: "モリサワ：AIでフォントを探す", url: "https://fontsjourney.morisawafonts.com/", category: "identify"),
    ]

    /// Only user-added links are editable. Old unmodified default links move to
    /// the fixed list; custom names and URLs are preserved.
    static func links(_ raw: String) -> [FontServiceLink] {
        guard !raw.isEmpty, let data = raw.data(using: .utf8),
              let links = try? JSONDecoder().decode([FontServiceLink].self, from: data) else { return [] }
        return links.filter { link in
            guard link.category == nil else { return true }
            let adobeURLs = ["https://fonts.adobe.com/fonts", "https://fonts.adobe.com/", "https://fonts.adobe.com", "https://fonts.adobe.com/my_fonts"]
            if link.name == "Adobe Fonts" && adobeURLs.contains(link.url) { return false }
            if ["モリサワ", "Morisawa"].contains(link.name) && link.url == "https://morisawafonts.com/fonts/search/" { return false }
            return true
        }
    }

    static func encode(_ links: [FontServiceLink]) -> String {
        guard let data = try? JSONEncoder().encode(links.map { link in
            var copy = link; copy.category = "other"; return copy
        }) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static func open(_ link: FontServiceLink) {
        var text = link.url.trimmingCharacters(in: .whitespaces)
        if !text.contains("://") { text = "https://" + text }
        if let url = URL(string: text) { NSWorkspace.shared.open(url) }
    }
}

/// 標準15件を3カテゴリで表示し、追加分をカスタムリンクとして表示する
struct FontServicesMenu: View {
    @AppStorage(FontServices.key) private var raw = ""

    var body: some View {
        let links = FontServices.links(raw).filter { !$0.name.isEmpty && !$0.url.isEmpty }
        ForEach(["vendors", "examples", "identify"], id: \.self) { category in
            Section {
                ForEach(FontServices.defaults.filter { $0.category == category }) { link in
                    Button(link.name) { FontServices.open(link) }
                }
            } header: {
                Text(FontServices.categoryTitle(category))
            }
        }
        if !links.isEmpty {
            Section {
                ForEach(links) { link in
                    Button(link.name) { FontServices.open(link) }
                }
            } header: {
                Text(L("カスタムリンク"))
            }
        }
        Divider()
        Button(L("リンクを編集…")) { SettingsWindow.shared.show() }
        Menu(L("デバッグ")) { FontDebugMenu() }
    }
}

/// 設定の「カスタムリンク」：ユーザーが追加したリンクだけを編集する
struct FontServicesSection: View {
    @AppStorage(FontServices.key) private var raw = ""
    @State private var selection: UUID?

    private var links: [FontServiceLink] { FontServices.links(raw) }

    var body: some View {
        SettingsSection(L("カスタムリンク")) {
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
            Text(L("追加したリンクだけを編集します。標準のリンク集は変更されません。"))
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
