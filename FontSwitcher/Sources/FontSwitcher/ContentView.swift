import AppKit
import CoreText
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var store = LibraryStore.shared
    @State private var isTargeted = false
    @AppStorage("previewVisible") private var previewVisible = true

    var body: some View {
        VStack(spacing: 0) {
            header
            HSplitView {
                SidebarView()
                    .frame(minWidth: 170, idealWidth: 200, maxWidth: 230)
                FamilyListView()
                    .frame(minWidth: 280, idealWidth: 340, maxWidth: previewVisible ? nil : .infinity)
                if previewVisible {
                    PreviewView()
                        .frame(minWidth: 300, maxWidth: .infinity)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 3).opacity(isTargeted ? 1 : 0))
            .padding(.horizontal, 16)
            footer
        }
        .background(Color(nsColor: AppSurface.color), ignoresSafeAreaEdges: [])
        // Finderからフォントファイルやフォルダーをドロップしてライブラリに加える
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            let group = DispatchGroup()
            let dropped = DroppedURLs()
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url, url.isFileURL { dropped.append(url) }
                    group.leave()
                }
            }
            group.notify(queue: .main) { LibraryStore.shared.add(dropped.urls) }
            return true
        }
        .accessibilityLabel(L("フォントファイルやフォルダーをドロップして追加"))
        .alert(store.message?.title ?? "", isPresented: Binding(
            get: { store.message != nil }, set: { if !$0 { store.message = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(store.message?.body ?? "")
        }
        .onAppear { store.refreshStates() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            // ほかのアプリと同じ共通ヘッダー：アイコンの下にバージョン（build）
            VStack(spacing: 4) {
                Image(nsImage: currentAppIcon()).resizable().scaledToFit()
                    .frame(width: 44, height: 44).accessibilityHidden(true)
                AppVersionLabel()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L("フォントのアクティブを切り替え"))
                    .font(.title2.weight(.semibold))
                Text(L("フォントファイルをライブラリに登録し、使うときだけアクティブにします"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { SettingsWindow.shared.show() } label: {
                Label(L("設定"), systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if store.isBusy { ProgressView().controlSize(.small) }
            Text(store.status.isEmpty ? summary : store.status)
                .font(.callout).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(L("追加…")) { store.showAddPanel() }
                .disabled(store.isBusy)
            Button(L("解除")) { store.setActive(store.selectedFiles, false) }
                .disabled(store.selection.isEmpty)
            Button(L("アクティブにする")) { store.setActive(store.selectedFiles, true) }
                .keyboardShortcut(.defaultAction)
                .disabled(store.selection.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var summary: String {
        L("%d ファミリー・%d ファイル（アクティブ %d）", store.familyCount, store.count(.all), store.count(.active))
    }
}

/// ドロップの読み取りは別々のスレッドから届くので、ロックして集める
private final class DroppedURLs: @unchecked Sendable {
    private let lock = NSLock()
    private var list: [URL] = []
    var urls: [URL] { lock.withLock { list } }
    func append(_ url: URL) { lock.withLock { list.append(url) } }
}

// MARK: - サイドバー

private struct SidebarView: View {
    @ObservedObject private var store = LibraryStore.shared
    // 区分ごとの表示（設定の「表示」）と開閉（ここで覚える）。コレクションは初めは閉じる
    @AppStorage(LibraryStore.SidebarSection.system.showKey) private var showSystem = true
    @AppStorage(LibraryStore.SidebarSection.kinds.showKey) private var showKinds = true
    @AppStorage(LibraryStore.SidebarSection.vendors.showKey) private var showVendors = true
    @AppStorage(LibraryStore.SidebarSection.collections.showKey) private var showCollections = true
    @AppStorage(LibraryStore.SidebarSection.sets.showKey) private var showSets = true
    @AppStorage("sidebarExpanded.library") private var expandedLibrary = true
    @AppStorage(LibraryStore.SidebarSection.system.expandedKey) private var expandedSystem = true
    @AppStorage(LibraryStore.SidebarSection.kinds.expandedKey) private var expandedKinds = true
    @AppStorage(LibraryStore.SidebarSection.vendors.expandedKey) private var expandedVendors = true
    @AppStorage(LibraryStore.SidebarSection.collections.expandedKey) private var expandedCollections = false
    @AppStorage(LibraryStore.SidebarSection.sets.expandedKey) private var expandedSets = true

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding<SidebarItem?>(get: { store.sidebar }, set: { if let item = $0 { store.sidebar = item; store.selection.removeAll() } })) {
                Section(isExpanded: $expandedLibrary) {
                    row(.all, L("すべてのフォント"), "textformat")
                    row(.favorites, L("お気に入り"), "star")
                    row(.active, L("アクティブ"), "checkmark.circle")
                    row(.inactive, L("非アクティブ"), "circle")
                    row(.duplicates, L("重複"), "square.on.square")
                    row(.missing, L("見つからない"), "exclamationmark.triangle")
                } header: { Text(L("ライブラリ")) }
                if store.includeUserFonts && showSystem {
                    // フォントフォルダー。System は切り替え・取り除きができない
                    Section(isExpanded: $expandedSystem) {
                        row(.folder(.user), SystemFolder.user.title, "person")
                        row(.folder(.allUsers), SystemFolder.allUsers.title, "person.2")
                        row(.folder(.system), SystemFolder.system.title, "lock")
                    } header: { Text(L("システム")) }
                }
                if showKinds {
                    Section(isExpanded: $expandedKinds) {
                        ForEach(FontKind.allCases, id: \.self) { kind in
                            row(.kind(kind), kind.title, kind.symbol)
                        }
                    } header: { Text(L("種類")) }
                }
                if showVendors {
                    Section(isExpanded: $expandedVendors) {
                        ForEach(LibraryStore.vendors, id: \.id) { vendor in
                            row(.vendor(vendor.id), vendor.title, "building.2")
                        }
                        // Creative Cloud が入れたフォント（フォントフォルダーと同じく読み込む）
                        if store.includeUserFonts {
                            row(.folder(.adobeFonts), SystemFolder.adobeFonts.title, "cloud")
                        }
                    } header: { Text(L("ベンダー")) }
                }
                if showCollections && !store.collectionNames.isEmpty {
                    Section(isExpanded: $expandedCollections) {
                        ForEach(store.collectionNames, id: \.self) { name in
                            row(.collection(name), name, "square.stack")
                        }
                    } header: { Text(L("コレクション")) }
                }
                if showSets {
                Section(isExpanded: $expandedSets) {
                    ForEach(store.data.sets) { set in
                        row(.set(set.id), set.name, "folder")
                            .contextMenu {
                                Button(L("セットをアクティブにする")) { store.setActive(store.setFiles(set.id), true) }
                                Button(L("セットを解除")) { store.setActive(store.setFiles(set.id), false) }
                                Divider()
                                Button(L("名前を変更…")) { store.renameSet(set.id) }
                                Button(L("セットを削除…")) { store.deleteSet(set.id) }
                            }
                    }
                } header: { Text(L("セット")) }
                }
            }
            .listStyle(.sidebar)
            Divider()
            HStack {
                Button { store.newSet() } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderless)
                    .help(L("新規セット"))
                    .accessibilityLabel(L("新規セット"))
                Spacer()
            }
            .padding(6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func row(_ item: SidebarItem, _ title: String, _ symbol: String) -> some View {
        HStack {
            Label(title, systemImage: symbol).lineLimit(1)
            Spacer()
            Text("\(store.count(item))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .tag(item)
    }
}

// MARK: - ファミリーの一覧

private struct FamilyListView: View {
    @ObservedObject private var store = LibraryStore.shared
    @AppStorage(NameDisplay.key) private var nameDisplay = NameDisplay.localized.rawValue
    @AppStorage("previewVisible") private var previewVisible = true

    var body: some View {
        let families = store.shownFamilies
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
                TextField(L("ファミリー名・PostScript名で検索"), text: $store.searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel(L("検索"))
                if !store.searchText.isEmpty {
                    Button { store.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                        .accessibilityLabel(L("検索を消去"))
                }
                Button { previewVisible.toggle() } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("p", modifiers: [.command, .option])
                .help(previewVisible ? L("プレビューを隠す（⌥⌘P）") : L("プレビューを表示（⌥⌘P）"))
                .accessibilityLabel(previewVisible ? L("プレビューを隠す") : L("プレビューを表示"))
            }
            .padding(8)
            // フォント名の出し方。一覧の幅いっぱいに伸び縮みさせる
            Picker(L("フォント名"), selection: $nameDisplay) {
                Text(L("日本語名")).tag(NameDisplay.localized.rawValue)
                Text(L("PostScript名")).tag(NameDisplay.postScript.rawValue)
                Text(L("両方")).tag(NameDisplay.both.rawValue)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .help(L("フォント名の出し方"))
            .onChange(of: nameDisplay) { store.invalidate() }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            FilterBar()
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            Divider()
            if families.isEmpty {
                emptyView
            } else {
                FamilyOutline(nodes: FamilyNode.nodes(families), version: store.listVersion)
                .onDeleteCommand { store.remove(store.selectedFiles) }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ViewBuilder private var emptyView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "textformat").font(.system(size: 36)).foregroundStyle(.tertiary).accessibilityHidden(true)
            Text(store.data.files.isEmpty ? L("フォントファイルやフォルダーをここへドロップするか、「追加…」で選びます")
                                          : L("当てはまるフォントはありません"))
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

/// 条件での絞り込み：文字セットと名前の先頭。サイドバー・検索と重ねて効く
private struct FilterBar: View {
    @ObservedObject private var store = LibraryStore.shared

    var body: some View {
        let options = store.filterOptions
        HStack(spacing: 8) {
            Picker(L("文字セット"), selection: $store.charsetFilter) {
                Text(L("すべて")).tag(String?.none)
                Divider()
                ForEach(options.charsets, id: \.0) { name, count in
                    Text(verbatim: "\(name == LibraryStore.noCharset ? L("名前に無し") : name)（\(count)）").tag(String?.some(name))
                }
            }
            .frame(minWidth: 120, maxWidth: 200)
            Picker(L("名前の先頭"), selection: $store.prefixFilter) {
                Text(L("すべて")).tag(String?.none)
                Divider()
                ForEach(options.prefixes, id: \.0) { name, count in
                    Text(verbatim: "\(name)（\(count)）").tag(String?.some(name))
                }
            }
            .frame(minWidth: 140, maxWidth: 240)
            if store.charsetFilter != nil || store.prefixFilter != nil {
                Button(L("解除")) { store.charsetFilter = nil; store.prefixFilter = nil }
                    .buttonStyle(.borderless)
                    .help(L("絞り込みを解除"))
            }
            Spacer(minLength: 0)
        }
        .font(.callout)
    }
}

// MARK: - プレビュー

private struct PreviewView: View {
    @ObservedObject private var store = LibraryStore.shared
    @AppStorage(LibraryStore.sampleTextKey) private var sample = LibraryStore.defaultSampleText
    @AppStorage("previewSize") private var size = 36.0

    var body: some View {
        let families = store.selectedFamilies
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField(L("プレビューの文字"), text: $sample)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(L("プレビューの文字"))
                Slider(value: $size, in: 9...144)
                    .frame(width: 100)
                    .accessibilityLabel(L("大きさ"))
                Text("\(Int(size)) pt").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(8)
            Divider()
            if families.count == 1, let family = families.first {
                ScrollView {
                    // 数百書体のファミリーもあるので、見えている書体だけを描く
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(family.files) { file in
                            ForEach(file.faces, id: \.postScriptName) { face in
                                FaceSample(file: file, face: face, text: sample.isEmpty ? LibraryStore.defaultSampleText : sample, size: size)
                            }
                        }
                        Divider()
                        FamilyInfo(family: family)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack {
                    Spacer()
                    Text(families.isEmpty ? L("ファミリーを選ぶとプレビューします") : L("%d個のファミリーを選択中", families.count))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct FaceSample: View {
    let file: FontFile
    let face: FontFace
    let text: String
    let size: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(NameDisplay.current == .postScript ? face.postScriptName
                 : NameDisplay.current == .both ? face.displayStyle + "  " + face.postScriptName : face.displayStyle)
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            if let font = PreviewFonts.font(file: file, face: face, size: size) {
                Text(PreviewFonts.sample(text, font: font)).font(Font(font)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(L("このフォントに無い文字は、ほかのフォントで薄く表示しています"))
            } else {
                Text(L("プレビューできません")).foregroundStyle(.secondary)
            }
        }
    }
}

private struct FamilyInfo: View {
    let family: FontFamily
    @ObservedObject private var store = LibraryStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(family.files) { file in
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.fileName).font(.callout.weight(.semibold))
                    info(L("状態"), stateText(store.states[file.id]))
                    info(L("形式"), file.format)
                    if let version = PreviewFonts.version(file: file) { info(L("バージョン"), version) }
                    info(L("PostScript名"), file.faces.map(\.postScriptName).joined(separator: ", "))
                    info(L("場所"), file.path)
                    Button(L("Finderで表示")) { store.revealInFinder([file]) }
                        .buttonStyle(.link).font(.caption)
                }
            }
        }
    }

    private func info(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label + L(" :")).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
    }

    private func stateText(_ state: FontState?) -> String {
        switch state {
        case .active: return L("アクティブ")
        case .inactive, nil: return L("非アクティブ")
        case .missing: return L("ファイルが見つかりません")
        case .conflict(let path): return L("同じ名前のフォントが別の場所で使われています：%@", path)
        }
    }
}

/// アクティブにしていないフォントも、ファイルから直接読んでプレビューする
@MainActor
enum PreviewFonts {
    private static var descriptors: [String: [CTFontDescriptor]] = [:]

    static func font(file: FontFile, face: FontFace, size: Double) -> CTFont? {
        guard let descriptor = descriptorsOf(file).first(where: {
            CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String == face.postScriptName
        }) else { return nil }
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    /// このフォントに字形の無い文字は、代わりのフォントで描かれる。薄い色にして見分けられるようにする
    static func sample(_ text: String, font: CTFont) -> AttributedString {
        var result = AttributedString()
        for character in text {
            var piece = AttributedString(String(character))
            if !character.isWhitespace && !has(character, in: font) {
                // tertiaryLabelColor（約26%）では濃いという指摘で、15%に
                piece.foregroundColor = Color(nsColor: .labelColor).opacity(0.15)
            }
            result += piece
        }
        return result
    }

    private static func has(_ character: Character, in font: CTFont) -> Bool {
        let units = Array(String(character).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        return CTFontGetGlyphsForCharacters(font, units, &glyphs, units.count)
    }

    static func version(file: FontFile) -> String? {
        guard let descriptor = descriptorsOf(file).first else { return nil }
        let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
        return CTFontCopyName(font, kCTFontVersionNameKey) as String?
    }

    private static func descriptorsOf(_ file: FontFile) -> [CTFontDescriptor] {
        if let cached = descriptors[file.path] { return cached }
        let list = CTFontManagerCreateFontDescriptorsFromURL(file.url as CFURL) as? [CTFontDescriptor] ?? []
        descriptors[file.path] = list
        return list
    }
}

// Main-window header uses the same icon resource as the distributed app.
@MainActor private func currentAppIcon() -> NSImage {
    let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String ?? "AppIcon"
    let filename = name.hasSuffix(".icns") ? name : name + ".icns"
    if let url = Bundle.main.resourceURL?.appendingPathComponent(filename),
       let image = NSImage(contentsOf: url) { return image }
    return NSApp.applicationIconImage
}
/// Shown under the header icon: version, then build in parentheses (「1.4.5」「（15）」).
private func appVersionText() -> String {
    let info = Bundle.main.infoDictionary ?? [:]
    let version = info["CFBundleShortVersionString"] as? String ?? ""
    guard let build = info["CFBundleVersion"] as? String, !build.isEmpty, build != version else { return version }
    let japanese = Bundle.main.preferredLocalizations.first?.hasPrefix("ja") ?? false
    return version + "\n" + (japanese ? "（\(build)）" : "(\(build))")
}
/// Placed under the header icon.
private struct AppVersionLabel: View {
    var body: some View {
        Text(appVersionText()).font(.system(size: 10)).foregroundStyle(.secondary)
            .multilineTextAlignment(.center).fixedSize()
    }
}
