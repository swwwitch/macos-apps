import AppKit
import SwiftUI

// Canonical source: Shared/AppStandards/AboutSection.swift.
/// The 「情報」 settings tab, after CleanShot X's About: icon, name, version (build), copyright and links.
/// The app's own article is SWNoteArticleURL in Info.plist; it is left out when it is the summary page itself.
enum AboutSection {
    static var title: String { StartupWindow.text("情報", "About", "关于", "정보") }
    static let summaryURL = URL(string: "https://note.com/swwwitch/m/m057948d2fbeb")!
    static let xURL = URL(string: "https://x.com/swwwitch")!
    static var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? ""
        let build = info["CFBundleVersion"] as? String ?? ""
        return String(format: StartupWindow.text("バージョン %@（%@）", "Version %@ (%@)", "版本 %@（%@）", "버전 %@ (%@)"), short, build)
    }
    static var copyright: String? {
        (Bundle.main.localizedInfoDictionary?["NSHumanReadableCopyright"] ?? Bundle.main.infoDictionary?["NSHumanReadableCopyright"]) as? String
    }
    static var links: [AboutLink] {
        var result: [AboutLink] = []
        if let text = Bundle.main.infoDictionary?["SWNoteArticleURL"] as? String, let url = URL(string: text), url != summaryURL {
            result.append(AboutLink(title: StartupWindow.text("解説記事（note）", "Article (note)", "介绍文章（note）", "소개 글 (note)"), symbol: "doc.text", url: url))
        }
        result.append(AboutLink(title: StartupWindow.text("アプリのまとめ（note）", "All apps (note)", "应用合集（note）", "앱 모음 (note)"), symbol: "books.vertical", url: summaryURL))
        result.append(AboutLink(title: "X（@swwwitch）", symbol: nil, url: xURL))
        return result
    }
    /// AppKit form for settings built with NSTabView.
    @MainActor static func view() -> NSView { NSHostingView(rootView: AboutView()) }
}

struct AboutLink: Identifiable {
    let title: String
    /// nil draws the X mark, which has no SF Symbol.
    let symbol: String?
    let url: URL
    var id: String { url.absoluteString }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
                Text(AppLifecycle.appName).font(.system(size: 24, weight: .semibold))
                Text(AboutSection.version).foregroundColor(.secondary).textSelection(.enabled)
                if let copyright = AboutSection.copyright { Text(copyright).font(.caption).foregroundColor(.secondary) }
            }.frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                Text(StartupWindow.text("リンク", "Links", "链接", "링크")).font(.system(size: 13, weight: .semibold)).padding(.leading, 4)
                VStack(spacing: 0) {
                    ForEach(Array(AboutSection.links.enumerated()), id: \.element.id) { index, link in
                        if index > 0 { Divider().padding(.leading, 12) }
                        AboutLinkRow(link: link)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08)))
            }
        }.frame(maxWidth: .infinity)
    }
}

private struct AboutLinkRow: View {
    let link: AboutLink
    @State private var hovering = false
    var body: some View {
        Button { NSWorkspace.shared.open(link.url) } label: {
            HStack(spacing: 12) {
                Group {
                    if let symbol = link.symbol { Image(systemName: symbol) } else { Text("𝕏").font(.system(size: 15, weight: .semibold)) }
                }.frame(width: 20)
                Text(link.title)
                Spacer()
                Image(systemName: "arrow.up.right").foregroundColor(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(hovering ? Color.primary.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(link.url.absoluteString)
    }
}
