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
            group.notify(queue: .main) {
                // 制作ファイル（IDML・PDF・AI）はプロジェクトに、それ以外はフォントとしてライブラリに
                let urls = dropped.urls
                let production = urls.filter { FontNameExtractor.fileExtensions.contains($0.pathExtension.lowercased()) }
                if !production.isEmpty { LibraryStore.shared.newProject(from: production) }
                // セットを選んでいるときは、そのセットにも入れる
                let store = LibraryStore.shared
                var set: UUID?
                if case .set(let id) = store.sidebar { set = id }
                store.add(urls.filter { !production.contains($0) }, toSet: set)
            }
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
            if TaskProgress.shared.isRunning {
                TaskProgressBar()
            } else if store.isBusy {
                ProgressView().controlSize(.small)
            }
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
    @AppStorage(LibraryStore.SidebarSection.smartSets.showKey) private var showSmartSets = true
    @AppStorage(LibraryStore.SidebarSection.sets.showKey) private var showSets = true
    @AppStorage(LibraryStore.showRecentKey) private var showRecent = true
    @AppStorage(LibraryStore.SidebarSection.projects.showKey) private var showProjects = true
    @AppStorage(LibraryStore.SidebarSection.projects.expandedKey) private var expandedProjects = true
    @AppStorage("sidebarExpanded.library") private var expandedLibrary = true
    @AppStorage(LibraryStore.SidebarSection.system.expandedKey) private var expandedSystem = true
    @AppStorage(LibraryStore.SidebarSection.kinds.expandedKey) private var expandedKinds = true
    @AppStorage(LibraryStore.SidebarSection.vendors.expandedKey) private var expandedVendors = true
    @AppStorage(LibraryStore.SidebarSection.collections.expandedKey) private var expandedCollections = false
    @AppStorage(LibraryStore.SidebarSection.smartSets.expandedKey) private var expandedSmartSets = true
    @AppStorage(LibraryStore.SidebarSection.sets.expandedKey) private var expandedSets = true
    @AppStorage(LibraryStore.SidebarSection.orderKey) private var order = ""
    @State private var optionsShown = false

    var body: some View {
        VStack(spacing: 0) {
            // 区分の表示と並び順（「…」ボタン）
            HStack {
                Button { optionsShown.toggle() } label: { Image(systemName: "ellipsis.circle").font(.system(size: 10)) }
                    .buttonStyle(.borderless)
                    .help(L("サイドバーの表示と並び順"))
                    .accessibilityLabel(L("サイドバーの表示と並び順"))
                    .popover(isPresented: $optionsShown, arrowEdge: .bottom) { SidebarOptionsPanel() }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            List(selection: Binding<SidebarItem?>(get: { store.sidebar }, set: { if let item = $0 { store.sidebar = item; store.selection.removeAll() } })) {
                Section(isExpanded: $expandedLibrary) {
                    row(.all, L("すべてのフォント"), "textformat")
                    row(.duplicates, L("重複"), "square.on.square")
                        .contextMenu { Button(L("重複フォントを解決…")) { DuplicateResolverWindow.shared.show() } }
                    row(.missing, L("見つからない"), "exclamationmark.triangle")
                } header: { Text(L("ライブラリ")) }
                ForEach(LibraryStore.SidebarSection.ordered(order), id: \.self) { section in
                    sectionView(section)
                }
            }
            .listStyle(.sidebar)
            Divider()
            HStack {
                Menu {
                    Button(L("新規セット…")) { store.newSet() }
                    Button(L("新規プロジェクト…")) { store.newProject() }
                    Button(L("新規スマートセット…")) { store.newSmartSet() }
                } label: { Image(systemName: "plus") }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help(L("新規セット・プロジェクト"))
                    .accessibilityLabel(L("新規セット・プロジェクト"))
                Spacer()
            }
            .padding(6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder private func sectionView(_ section: LibraryStore.SidebarSection) -> some View {
        switch section {
        case .system:
            if store.includeUserFonts && showSystem {
                // フォントフォルダー。System は切り替え・取り除きができない
                Section(isExpanded: $expandedSystem) {
                    row(.folder(.user), SystemFolder.user.title, "person")
                    row(.folder(.allUsers), SystemFolder.allUsers.title, "person.2")
                } header: { Text(section.title) }
            }
        case .kinds:
            if showKinds {
                Section(isExpanded: $expandedKinds) {
                    ForEach(FontKind.allCases, id: \.self) { kind in
                        row(.kind(kind), kind.title, kind.symbol)
                    }
                } header: { Text(section.title) }
            }
        case .vendors:
            if showVendors {
                Section(isExpanded: $expandedVendors) {
                    ForEach(LibraryStore.vendors, id: \.id) { vendor in
                        iconRow(.vendor(vendor.id), vendor.title) { VendorIcon(id: vendor.id) }
                    }
                    // Creative Cloud が入れたフォント。「フォントフォルダーのフォントも一覧に入れる」と切り離していつも出す（ユーザー指定）
                    iconRow(.folder(.adobeFonts), SystemFolder.adobeFonts.title) { AdobeFontsIcon() }
                        .contextMenu {
                            Button(L("fonts.adobe.comを開く")) { store.openAdobeFontsWeb() }
                        }
                } header: { Text(section.title) }
            }
        case .collections:
            if showCollections && !store.collectionNames.isEmpty {
                Section(isExpanded: $expandedCollections) {
                    ForEach(store.collectionNames, id: \.self) { name in
                        row(.collection(name), name, "square.stack")
                    }
                } header: { Text(section.title) }
            }
        case .smartSets:
            if showSmartSets {
                // 条件で中身が決まるセット
                Section(isExpanded: $expandedSmartSets) {
                    row(.favorites, L("お気に入り"), "star")
                    row(.active, L("アクティブ"), "checkmark.circle")
                    if showRecent { row(.recentlyActivated, L("最近アクティブ"), "clock.badge.checkmark") }
                    row(.inactive, L("非アクティブ"), "circle")
                    if showRecent {
                        row(.recentlyDeactivated, L("最近非アクティブ"), "clock.badge.xmark")
                        row(.recentlyAdded, L("最近追加したもの"), "calendar.badge.plus")
                    }
                    row(.japanese, L("日本語をサポート"), "character.ja")
                    row(.watchFolders, L("ウォッチフォルダー"), "eye")
                    // 自分で条件を作ったスマートセット
                    ForEach(store.data.smartSets) { smartSet in
                        row(.smartSet(smartSet.id), smartSet.name, "gearshape")
                            .simultaneousGesture(TapGesture(count: 2).onEnded { SmartSetEditorWindow.shared.show(smartSet, isNew: false) })
                            .contextMenu {
                                Button(L("スマートセットを編集…")) { SmartSetEditorWindow.shared.show(smartSet, isNew: false) }
                                Button(L("スマートセットを削除…")) { store.deleteSmartSet(smartSet.id) }
                            }
                    }
                } header: { Text(section.title) }
            }
        case .projects:
            if showProjects {
                Section(isExpanded: $expandedProjects) {
                    ForEach(store.data.projects) { project in
                        projectRow(project)
                            .contextMenu {
                                Button(L("プロジェクトを編集…")) { ProjectEditorWindow.shared.show(project.id) }
                                Divider()
                                Button(L("プロジェクトをアクティブにする")) { store.activateProject(project.id) }
                                Button(L("プロジェクトを解除")) { store.deactivateProject(project.id) }
                                Divider()
                                Button(L("読み直す")) { store.rebuildProject(project.id) }
                                Button(L("プロジェクトを削除…")) { store.deleteProject(project.id) }
                            }
                    }
                } header: { Text(section.title) }
            }
        case .sets:
            if showSets {
                Section(isExpanded: $expandedSets) {
                    ForEach(store.data.sets) { set in
                        setRow(set)
                            .contextMenu {
                                Button(L("セットをアクティブにする")) { store.setActive(store.setFiles(set.id), true) }
                                Button(L("セットを解除")) { store.setActive(store.setFiles(set.id), false) }
                                Divider()
                                Button(L("名前を変更…")) { store.renameSet(set.id) }
                                Button(L("セットを削除…")) { store.deleteSet(set.id) }
                            }
                    }
                } header: { Text(section.title) }
            }
        }
    }

    /// セットの行。左のチェックボックスでセットのフォントをまとめてアクティブ・解除する（一部だけアクティブなら「−」）
    /// プロジェクトの行。チェックボックスでまとめてアクティブ（失敗したら元に戻す）・解除。見つからないフォントがあれば印を出す
    private func projectRow(_ project: FontProject) -> some View {
        let state = store.projectState(project.id)
        return HStack(spacing: 6) {
            Button {
                if state == true { store.deactivateProject(project.id) } else { store.activateProject(project.id) }
            } label: {
                Image(systemName: state == true ? "checkmark.square.fill" : state == nil ? "minus.square.fill" : "square")
                    .foregroundStyle(state == false ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.borderless)
            .help(state == true ? L("プロジェクトを解除") : L("プロジェクトをアクティブにする"))
            .accessibilityLabel(state == true ? L("プロジェクトを解除") : L("プロジェクトをアクティブにする"))
            Label(project.name, systemImage: "doc.text").lineLimit(1)
            Spacer()
            if project.pendingCount > 0 {
                Image(systemName: "questionmark.circle").foregroundStyle(.orange).font(.caption)
                    .help(L("確認待ちの候補 %d", project.pendingCount))
            }
            if !project.missing.isEmpty {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).font(.caption)
                    .help(L("ライブラリに無いフォント %d", project.missing.count))
            }
            Text("\(store.count(.project(project.id)))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .tag(SidebarItem.project(project.id))
        .simultaneousGesture(TapGesture(count: 2).onEnded { ProjectEditorWindow.shared.show(project.id) })
    }

    private func setRow(_ set: FontSet) -> some View {
        let state = store.setState(set.id)
        return HStack(spacing: 6) {
            Button {
                store.setActive(store.setFiles(set.id), state != true)
            } label: {
                Image(systemName: state == true ? "checkmark.square.fill" : state == nil ? "minus.square.fill" : "square")
                    .foregroundStyle(state == false ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.borderless)
            .help(state == true ? L("セットを解除") : L("セットをアクティブにする"))
            .accessibilityLabel(state == true ? L("セットを解除") : L("セットをアクティブにする"))
            Label(set.name, systemImage: "folder").lineLimit(1)
            Spacer()
            Text("\(store.count(.set(set.id)))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .tag(SidebarItem.set(set.id))
    }

    /// SF Symbols ではなく自前のアイコンを出す行
    private func iconRow<Icon: View>(_ item: SidebarItem, _ title: String, @ViewBuilder icon: () -> Icon) -> some View {
        HStack {
            Label { Text(title).lineLimit(1) } icon: { icon() }
            Spacer()
            Text("\(store.count(item))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .tag(item)
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

/// サイドバーの「…」：区分ごとの表示と並び順。ライブラリは常に先頭に出す
private struct SidebarOptionsPanel: View {
    @AppStorage(LibraryStore.SidebarSection.orderKey) private var order = ""
    @AppStorage(LibraryStore.showRecentKey) private var showRecent = true

    var body: some View {
        let sections = LibraryStore.SidebarSection.ordered(order)
        VStack(alignment: .leading, spacing: 10) {
            Text(L("サイドバー")).font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(sections.enumerated()), id: \.element) { index, section in
                    HStack(spacing: 6) {
                        SectionToggle(section: section)
                        Spacer(minLength: 12)
                        Button { move(sections, index, -1) } label: { Image(systemName: "chevron.up") }
                            .disabled(index == 0)
                            .help(L("上へ"))
                            .accessibilityLabel(L("%@を上へ", section.title))
                        Button { move(sections, index, 1) } label: { Image(systemName: "chevron.down") }
                            .disabled(index == sections.count - 1)
                            .help(L("下へ"))
                            .accessibilityLabel(L("%@を下へ", section.title))
                    }
                    .buttonStyle(.borderless)
                }
            }
            Divider()
            Toggle(L("最近の項目を表示（最近アクティブ・最近非アクティブ・最近追加したもの）"), isOn: $showRecent)
                .onChange(of: showRecent) { LibraryStore.shared.ensureSidebarVisible() }
            Text(L("「ライブラリ」は常に先頭に出します。隠しても、フォントやセットは消えません。区分の見出しをクリックすると開閉できます。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("初期値に戻す")) {
                    order = ""
                    showRecent = true
                    for section in LibraryStore.SidebarSection.allCases { UserDefaults.standard.set(true, forKey: section.showKey) }
                }
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func move(_ sections: [LibraryStore.SidebarSection], _ index: Int, _ offset: Int) {
        var list = sections
        list.swapAt(index, index + offset)
        order = list.map(\.rawValue).joined(separator: ",")
    }
}

/// 区分を出すかどうか。隠した区分の項目を選んでいたら「すべてのフォント」に戻す
private struct SectionToggle: View {
    let section: LibraryStore.SidebarSection
    @AppStorage private var shown: Bool

    init(section: LibraryStore.SidebarSection) {
        self.section = section
        _shown = AppStorage(wrappedValue: true, section.showKey)
    }

    var body: some View {
        Toggle(section.title, isOn: $shown)
            .onChange(of: shown) { LibraryStore.shared.ensureSidebarVisible() }
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
                SearchOptionsButton()
                Button { previewVisible.toggle() } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(MenuShortcuts.shared.shortcut(.togglePreview))
                .help((previewVisible ? L("プレビューを隠す") : L("プレビューを表示"))
                      + (MenuShortcuts.shared.combo(.togglePreview).map { "（\($0.label)）" } ?? ""))
                .accessibilityLabel(previewVisible ? L("プレビューを隠す") : L("プレビューを表示"))
            }
            // 検索欄は上下を少し広げる
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
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
            if store.sidebar == .folder(.adobeFonts) { AdobeFontsBar() }
            if store.sidebar == .duplicates { DuplicatesBar() }
            Divider()
            if families.isEmpty {
                emptyView
            } else {
                FamilyOutline(nodes: FamilyNode.nodes(families), version: store.listVersion, selection: store.selection)
                .equatable()
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

/// 「重複」を表示している間だけ出す案内：優先外の重複をまとめて解除・取り除く
private struct DuplicatesBar: View {
    @ObservedObject private var store = LibraryStore.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.on.square").foregroundStyle(.secondary).accessibilityHidden(true)
            Text(L("ここには優先が決まらない重複だけを出します。ボタンは、選んでいなければライブラリの優先外すべてが対象です"))
                .font(.callout).foregroundStyle(.secondary)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(L("重複フォントを解決…")) { DuplicateResolverWindow.shared.show() }
            Button(L("優先外を解除")) { store.deactivateNonPreferredDuplicates() }
            Button(L("優先外を取り除く…")) { store.removeNonPreferredDuplicates() }
        }
        .controlSize(.small)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }
}

/// Adobe Fonts を表示している間だけ出す案内。切り替えは Creative Cloud で行う
private struct AdobeFontsBar: View {
    @ObservedObject private var store = LibraryStore.shared

    var body: some View {
        HStack(spacing: 8) {
            AdobeFontsIcon()
            Text(L("Adobe Fontsのオン・オフは、Creative Cloudで行います"))
                .font(.callout).foregroundStyle(.secondary)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(L("fonts.adobe.com")) { store.openAdobeFontsWeb() }
                .help(L("fonts.adobe.comを開く"))
        }
        .controlSize(.small)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }
}

/// 検索欄の右の「検索オプション」。条件での絞り込みをパネルで選ぶ。サイドバー・検索と重ねて効く
private struct SearchOptionsButton: View {
    @ObservedObject private var store = LibraryStore.shared
    @State private var shown = false

    var body: some View {
        Button { shown.toggle() } label: {
            // 絞り込み中は塗りつぶしのアイコンにして分かるようにする
            Image(systemName: store.hasFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .foregroundStyle(store.hasFilter ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.borderless)
        .help(L("検索オプション"))
        .accessibilityLabel(L("検索オプション"))
        .popover(isPresented: $shown, arrowEdge: .bottom) { SearchOptionsPanel() }
    }
}

private struct SearchOptionsPanel: View {
    @ObservedObject private var store = LibraryStore.shared

    var body: some View {
        let options = store.filterOptions
        VStack(alignment: .leading, spacing: 14) {
            Text(L("検索オプション")).font(.headline)
            // 3列：名前から読む条件／ファイルの形・種類／数で分ける条件
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 18) {
                    group(L("文字セット"), $store.charsetFilter, options.charsets.map {
                        ($0.0 == LibraryStore.noCharset ? L("名前に無し") : $0.0, $0.0, $0.1)
                    })
                    variantGroup(.n, options)
                }
                VStack(alignment: .leading, spacing: 18) {
                    group(L("形式"), $store.formatFilter, options.formats.map { ($0.0, $0.0, $0.1) })
                    group(L("種類"), $store.kindFilter, options.kinds.map { ($0.0.title, $0.0, $0.1) })
                }
                VStack(alignment: .leading, spacing: 18) {
                    group(L("ファミリーの書体数"), $store.faceCountFilter, options.faceCounts.map { ($0.0.title, $0.0, $0.1) })
                    group(L("収録文字数"), $store.characterCountFilter, options.characterCounts.map { ($0.0.title, $0.0, $0.1) })
                }
                // FontDB（メーカーの公式の情報）で分ける条件
                VStack(alignment: .leading, spacing: 18) {
                    // 分類は50種類ほどあるので、ラジオボタンのまま高さを決めてスクロールさせる
                    ScrollView {
                        group(L("分類"), $store.classificationFilter, options.classifications.map { ($0.0, $0.0, $0.1) })
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: 230, height: 300)
                    group(L("リリース年"), $store.releaseDecadeFilter, options.releaseDecades.map { ($0.0.title, $0.0, $0.1) })
                }
                VStack(alignment: .leading, spacing: 18) {
                    variantGroup(.ud, options)
                    variantGroup(.ap, options)
                    variantGroup(.nt, options)
                }
            }
            HStack {
                Text(L("（ ）の数はファミリー数です。サイドバー・検索と重ねて効きます。"))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(L("すべて解除")) { store.clearFilters() }
                    .disabled(!store.hasFilter)
            }
        }
        .padding(20)
        // 中身の大きさに合わせる（合わせないとポップオーバーが縦に伸び、上に空白ができる）
        .fixedSize()
    }

    /// 書体の違い（N・UD・AP版・新ゴ）のあり／なし
    private func variantGroup(_ variant: VariantFilter, _ options: LibraryStore.FilterOptions) -> some View {
        let binding = Binding<Bool?>(get: { store.variantFilters[variant] }, set: { store.variantFilters[variant] = $0 })
        return group(variant.title, binding, (options.variants[variant] ?? []).map { (variant.optionTitle($0.0), $0.0, $0.1) })
    }

    /// 見出しと「すべて」＋候補のラジオボタン
    private func group<Value: Hashable>(_ title: String, _ selection: Binding<Value?>, _ items: [(String, Value, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.callout.weight(.semibold))
            Picker(title, selection: selection) {
                Text(L("すべて")).tag(Value?.none)
                ForEach(items, id: \.1) { name, value, count in
                    Text(verbatim: "\(name)（\(count)）").tag(Value?.some(value))
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
        .fixedSize()
    }
}

// MARK: - プレビュー

/// プレビューの下のフォント情報に出す項目（プレビューのオプションでチェックボックスで選ぶ）。隠した項目を UserDefaults に覚える
enum FontInfoItem: String, CaseIterable {
    case state, format, characters, version, postScript, location, reveal
    case officialName, officialFileName, maker, designer, release, firstRelease, classification, series, languages, plans, description, officialPage

    static let hiddenKey = "fontInfoHidden"
    static let basic: [FontInfoItem] = [.state, .format, .characters, .version, .postScript, .location, .reveal]
    static let official: [FontInfoItem] = [.officialName, .officialFileName, .maker, .designer, .release, .firstRelease,
                                           .classification, .series, .languages, .plans, .description, .officialPage]

    var title: String {
        switch self {
        case .state: return L("状態")
        case .format: return L("形式")
        case .characters: return L("収録文字数")
        case .version: return L("バージョン")
        case .postScript: return L("PostScript名")
        case .location: return L("場所")
        case .reveal: return L("Finderで表示")
        case .officialName: return L("書体名")
        case .officialFileName: return L("ファイル名")
        case .maker: return L("メーカー")
        case .designer: return L("作者")
        case .release: return L("リリース")
        case .firstRelease: return L("初出")
        case .classification: return L("分類")
        case .series: return L("シリーズ")
        case .languages: return L("言語")
        case .plans: return L("プラン")
        case .description: return L("説明")
        case .officialPage: return L("公式のページを開く")
        }
    }

    /// 保存は隠した項目の rawValue をカンマでつないだもの（空＝すべて出す）
    static func hidden(_ stored: String) -> Set<FontInfoItem> {
        Set(stored.split(separator: ",").compactMap { FontInfoItem(rawValue: String($0)) })
    }
}

/// プレビューの見え方（文字の色・不透明度・カーニング・トラッキング）。設定は AppStorage に覚える
struct PreviewStyle {
    static let schemeKey = "previewColorScheme"
    static let foregroundKey = "previewForeground"
    static let backgroundKey = "previewBackground"
    static let opacityKey = "previewOpacity"
    static let kerningKey = "previewKerning"
    static let trackingOnKey = "previewTrackingOn"
    static let trackingKey = "previewTracking"
    static let modeKey = "previewMode"

    enum Mode: String, CaseIterable {
        case oneLine, multiline, waterfall
        var title: String {
            switch self {
            case .oneLine: return L("1行")
            case .multiline: return L("複数行")
            case .waterfall: return L("ウォーターフォール")
            }
        }
    }
    /// ウォーターフォールの大きさ（pt）
    static let waterfallSizes: [Double] = [72, 48, 36, 24, 18, 14, 12, 9]
    /// トラッキングの選択肢（1/1000 em）
    static let trackingValues: [Double] = [-100, -75, -50, -25, -10, 10, 25, 50, 75, 100, 200]

    var foreground: Color
    var opacity: Double
    var kerning: Bool
    var tracking: Double
    var mode: Mode

    /// 配色：白地に黒・黒地に白・カスタム（文字と背景の色を選ぶ）
    enum Scheme: String, CaseIterable {
        case blackOnWhite, whiteOnBlack, custom
        var title: String {
            switch self {
            case .blackOnWhite: return L("白地に黒")
            case .whiteOnBlack: return L("黒地に白")
            case .custom: return L("カスタム")
            }
        }
    }

    /// 配色から文字と背景の色を決める。カスタムで色を選んでいなければシステムの色
    static func colors(_ scheme: String, foreground: String, background: String) -> (Color, Color) {
        switch Scheme(rawValue: scheme) ?? .blackOnWhite {
        case .blackOnWhite: return (.black, .white)
        case .whiteOnBlack: return (.white, .black)
        case .custom: return (color(foreground) ?? Color(nsColor: .labelColor), color(background) ?? Color(nsColor: .textBackgroundColor))
        }
    }

    /// 色は「r g b a」（sRGB）で覚える。空なら既定（文字はラベルの色、背景は一覧の背景の色。ダークモードに合わせて変わる）
    static func color(_ text: String) -> Color? {
        let values = text.split(separator: " ").compactMap { Double($0) }
        guard values.count == 4 else { return nil }
        return Color(.sRGB, red: values[0], green: values[1], blue: values[2], opacity: values[3])
    }

    static func text(_ color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "" }
        return [rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent].map { String(format: "%.4f", Double($0)) }.joined(separator: " ")
    }

    /// プレビューの文字の候補（オプションのパネルで選ぶ）
    static let samples: [String] = [
        "あいうえお 永遠の文字 Aa Bb Cc 0123456789",
        "Lorem ipsum dolor sit amet",
        "The quick brown fox jumps over the lazy dog",
        "abcdefghijklmnopqrstuvwxyz",
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        "0123456789 !?@#$%&*()[]{}",
        "あいうえおかきくけこさしすせそたちつてと",
        "アイウエオカキクケコサシスセソタチツテト",
        "いろはにほへと ちりぬるを わかよたれそ つねならむ",
        "永東国酬愛鬱靈鷹袋蹴",
    ]
}

/// プレビューのオプション：文字と背景の色、不透明度、カーニング、トラッキング、プレビューの文字の候補
private struct PreviewOptionsPanel: View {
    @AppStorage(LibraryStore.sampleTextKey) private var sample = LibraryStore.defaultSampleText
    @AppStorage(PreviewStyle.schemeKey) private var scheme = PreviewStyle.Scheme.blackOnWhite.rawValue
    @AppStorage(PreviewStyle.foregroundKey) private var foreground = ""
    @AppStorage(PreviewStyle.backgroundKey) private var background = ""
    @AppStorage(PreviewStyle.opacityKey) private var opacity = 100.0
    @AppStorage(PreviewStyle.kerningKey) private var kerning = true
    @AppStorage(PreviewStyle.trackingOnKey) private var trackingOn = false
    @AppStorage(PreviewStyle.trackingKey) private var tracking = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("プレビューのオプション")).font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    label(L("配色"))
                    Picker(L("配色"), selection: $scheme) {
                        ForEach(PreviewStyle.Scheme.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
                GridRow {
                    label(L("文字の色"))
                    ColorPicker(L("文字の色"), selection: colorBinding($foreground, fallback: Color(nsColor: .labelColor)), supportsOpacity: false)
                        .labelsHidden()
                        .disabled(scheme != PreviewStyle.Scheme.custom.rawValue)
                }
                GridRow {
                    label(L("背景の色"))
                    ColorPicker(L("背景の色"), selection: colorBinding($background, fallback: Color(nsColor: .textBackgroundColor)), supportsOpacity: false)
                        .labelsHidden()
                        .disabled(scheme != PreviewStyle.Scheme.custom.rawValue)
                }
                GridRow {
                    label(L("不透明度"))
                    HStack(spacing: 8) {
                        Slider(value: $opacity, in: 10...100, step: 5).frame(width: 140)
                            .accessibilityLabel(L("不透明度"))
                        Text("\(Int(opacity)) %").monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    }
                }
                GridRow {
                    label(L("カーニング"))
                    Toggle(L("フォントのカーニングを使う"), isOn: $kerning)
                }
                GridRow {
                    label(L("トラッキング"))
                    HStack(spacing: 8) {
                        Toggle(L("トラッキング"), isOn: $trackingOn).labelsHidden()
                        Picker(L("トラッキング"), selection: $tracking) {
                            Text(verbatim: "0").tag(0.0)
                            ForEach(PreviewStyle.trackingValues, id: \.self) { value in
                                Text(verbatim: value > 0 ? "+\(Int(value))" : "\(Int(value))").tag(value)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)
                        .disabled(!trackingOn)
                        Text(L("（1/1000 em）")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Divider()
            HStack {
                Text(L("プレビューの文字") + L(" :"))
                // 候補はポップアップで選ぶ（ユーザー指定）。今の文字が候補に無ければ「その他」と出す
                Picker(L("プレビューの文字"), selection: $sample) {
                    ForEach(PreviewStyle.samples, id: \.self) { Text(verbatim: $0).tag($0) }
                    if !PreviewStyle.samples.contains(sample) {
                        Divider()
                        Text(L("その他（入力した文字）")).tag(sample)
                    }
                }
                .labelsHidden()
            }
            Divider()
            Text(L("表示する情報")).font(.callout.weight(.semibold))
            HStack(alignment: .top, spacing: 24) {
                infoColumn(L("基本"), FontInfoItem.basic)
                infoColumn(L("公式の情報"), FontInfoItem.official)
            }
            HStack {
                Spacer()
                Button(L("初期値に戻す")) {
                    scheme = PreviewStyle.Scheme.blackOnWhite.rawValue; foreground = ""; background = ""; opacity = 100; kerning = true; trackingOn = false; tracking = 0
                }
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func label(_ text: String) -> some View {
        Text(text + L(" :")).gridColumnAlignment(.trailing)
    }

    @AppStorage(FontInfoItem.hiddenKey) private var hiddenInfo = ""

    /// 表示する情報のチェックボックスの列
    private func infoColumn(_ title: String, _ items: [FontInfoItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            ForEach(items, id: \.self) { item in
                Toggle(item.title, isOn: Binding(
                    get: { !FontInfoItem.hidden(hiddenInfo).contains(item) },
                    set: { shown in
                        var hidden = FontInfoItem.hidden(hiddenInfo)
                        if shown { hidden.remove(item) } else { hidden.insert(item) }
                        hiddenInfo = hidden.map(\.rawValue).sorted().joined(separator: ",")
                    }))
            }
        }
    }

    private func colorBinding(_ stored: Binding<String>, fallback: Color) -> Binding<Color> {
        Binding(get: { PreviewStyle.color(stored.wrappedValue) ?? fallback },
                set: { stored.wrappedValue = PreviewStyle.text($0) })
    }
}

private struct PreviewView: View {
    @ObservedObject private var store = LibraryStore.shared
    @AppStorage(LibraryStore.sampleTextKey) private var sample = LibraryStore.defaultSampleText
    @AppStorage("previewSize") private var size = 36.0
    @AppStorage(PreviewStyle.schemeKey) private var scheme = PreviewStyle.Scheme.blackOnWhite.rawValue
    @AppStorage(PreviewStyle.foregroundKey) private var foreground = ""
    @AppStorage(PreviewStyle.backgroundKey) private var background = ""
    @AppStorage(PreviewStyle.opacityKey) private var opacity = 100.0
    @AppStorage(PreviewStyle.kerningKey) private var kerning = true
    @AppStorage(PreviewStyle.trackingOnKey) private var trackingOn = false
    @AppStorage(PreviewStyle.trackingKey) private var tracking = 0.0
    @AppStorage(PreviewStyle.modeKey) private var mode = PreviewStyle.Mode.multiline.rawValue
    @State private var optionsShown = false
    /// プレビュー（見本の文字）か字形の一覧か
    @AppStorage("previewShowsGlyphs") private var showsGlyphs = false

    /// 書体の行だけを選んでいるときはその書体だけ、ファミリーの行を選んでいるときは全書体をプレビューする（ユーザー指定）
    private func previewFiles(_ family: FontFamily) -> [FontFile] {
        guard !store.selection.contains(family.id) else { return family.files }
        let picked = family.files.filter { store.selection.contains(FamilyNode.fileID($0)) }
        return picked.isEmpty ? family.files : picked
    }

    private var style: PreviewStyle {
        PreviewStyle(foreground: PreviewStyle.colors(scheme, foreground: foreground, background: background).0,
                     opacity: opacity / 100, kerning: kerning, tracking: trackingOn ? tracking : 0,
                     mode: PreviewStyle.Mode(rawValue: mode) ?? .multiline)
    }

    var body: some View {
        let families = store.selectedFamilies
        VStack(spacing: 0) {
            Picker(L("プレビュー・字形"), selection: $showsGlyphs) {
                Text(L("プレビュー")).tag(false)
                Text(L("字形")).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 8)
            .padding(.top, 8)
            if showsGlyphs {
                if families.count == 1, let family = families.first {
                    GlyphGridView(family: family).id(family.id)
                } else {
                    VStack {
                        Spacer()
                        Text(families.isEmpty ? L("ファミリーを選ぶと字形を一覧にします") : L("%d個のファミリーを選択中", families.count))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
            HStack(spacing: 8) {
                // 1行・複数行（折り返す）・ウォーターフォール（いくつかの大きさを1行ずつ）
                Picker(L("表示"), selection: $mode) {
                    ForEach(PreviewStyle.Mode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .help(L("プレビューの表示"))
                TextField(L("プレビューの文字"), text: $sample)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(L("プレビューの文字"))
                if mode != PreviewStyle.Mode.waterfall.rawValue {
                    Slider(value: $size, in: 9...144)
                        .frame(width: 100)
                        .accessibilityLabel(L("大きさ"))
                    Text("\(Int(size)) pt").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
                Button { optionsShown.toggle() } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(.borderless)
                    .help(L("プレビューのオプション"))
                    .accessibilityLabel(L("プレビューのオプション"))
                    .popover(isPresented: $optionsShown, arrowEdge: .bottom) { PreviewOptionsPanel() }
            }
            .padding(8)
            Divider()
            if families.count == 1, let family = families.first {
                ScrollView {
                    // 数百書体のファミリーもあるので、見えている書体だけを描く
                    LazyVStack(alignment: .leading, spacing: 18) {
                        // ファミリーの全書体を1列にして、細い→太いの順に並べる（.ttc の中の書体も混ぜて並べる）
                        let faces = FontWeightOrder.sorted(previewFiles(family).flatMap { file in file.faces.map { (file: file, face: $0) } })
                        ForEach(faces, id: \.face.postScriptName) { item in
                            FaceSample(file: item.file, face: item.face, text: sample.isEmpty ? LibraryStore.defaultSampleText : sample, size: size, style: style)
                        }
                        Divider()
                        // フォント情報もプレビューと同じ書体だけ（書体の行だけを選んだときはその書体）
                        FamilyInfo(family: family, files: previewFiles(family))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(PreviewStyle.colors(scheme, foreground: foreground, background: background).1)
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
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct FaceSample: View {
    let file: FontFile
    let face: FontFace
    let text: String
    let size: Double
    let style: PreviewStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(NameDisplay.current == .postScript ? face.postScriptName
                 : NameDisplay.current == .both ? face.displayStyle + "  " + face.postScriptName : face.displayStyle)
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            if style.mode == .waterfall {
                // ウォーターフォール：大きさごとに1行。はみ出す分は切る
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(PreviewStyle.waterfallSizes, id: \.self) { size in
                        if let font = PreviewFonts.font(file: file, face: face, size: size) {
                            HStack(alignment: .lastTextBaseline, spacing: 8) {
                                Text("\(Int(size))").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                                    .frame(width: 22, alignment: .trailing)
                                Text(PreviewFonts.sample(text, font: font, style: style)).font(Font(font))
                                    .tracking(size * style.tracking / 1000)
                                    .opacity(style.opacity)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            } else if let font = PreviewFonts.font(file: file, face: face, size: size) {
                Text(PreviewFonts.sample(text, font: font, style: style)).font(Font(font)).textSelection(.enabled)
                    // トラッキングは 1/1000 em
                    .tracking(size * style.tracking / 1000)
                    .opacity(style.opacity)
                    .lineLimit(style.mode == .oneLine ? 1 : nil)
                    .fixedSize(horizontal: style.mode == .oneLine, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                    .help(L("このフォントに無い文字は、ほかのフォントで薄く表示しています"))
            } else {
                Text(L("プレビューできません")).foregroundStyle(.secondary)
            }
        }
    }
}

private struct FamilyInfo: View {
    let family: FontFamily
    /// 情報を出すファイル（選んだ書体だけのこともある）
    let files: [FontFile]
    @ObservedObject private var store = LibraryStore.shared
    @AppStorage(FontInfoItem.hiddenKey) private var hiddenInfo = ""

    private func shows(_ item: FontInfoItem) -> Bool { !FontInfoItem.hidden(hiddenInfo).contains(item) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(files) { file in
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.fileName).font(.callout.weight(.semibold))
                    if shows(.state) { info(L("状態"), stateText(store.states[file.id])) }
                    if shows(.format) { info(L("形式"), file.format) }
                    if shows(.characters), let characters = file.characterCount {
                        info(L("収録文字数"), L("%@文字（グリフ %@）", characters.formatted(.number), (file.glyphCount ?? 0).formatted(.number)))
                    }
                    if shows(.version), let version = PreviewFonts.version(file: file) { info(L("バージョン"), version) }
                    if shows(.postScript) { info(L("PostScript名"), file.faces.map(\.postScriptName).joined(separator: ", ")) }
                    if shows(.location) { info(L("場所"), file.path) }
                    if shows(.reveal) {
                        Button(L("Finderで表示")) { store.revealInFinder([file]) }
                            .buttonStyle(.link).font(.caption)
                    }
                    if let record = FontDB.record(for: file), FontInfoItem.official.contains(where: shows) { officialInfo(record) }
                }
            }
        }
    }

    /// FontDB（メーカーの公式の情報）。値のある項目だけを出す
    @ViewBuilder private func officialInfo(_ record: FontDBRecord) -> some View {
        Text(L("公式の情報")).font(.caption.weight(.semibold)).padding(.top, 4)
        if shows(.officialName), !record.name.isEmpty { info(L("書体名"), record.name + (record.reading.isEmpty ? "" : "（\(record.reading)）")) }
        if shows(.officialFileName), !record.fileName.isEmpty { info(L("ファイル名"), record.fileName) }
        if shows(.maker), !record.maker.isEmpty { info(L("メーカー"), record.maker) }
        if shows(.designer), !record.designer.isEmpty { info(L("作者"), record.designer) }
        if shows(.release), !record.releaseDate.isEmpty { info(L("リリース"), record.releaseDate) }
        if shows(.firstRelease), !record.originalRelease.isEmpty { info(L("初出"), record.originalRelease) }
        if shows(.classification), !record.classification.isEmpty { info(L("分類"), record.classification) }
        if shows(.series), !record.series.isEmpty { info(L("シリーズ"), record.series) }
        if shows(.languages), !record.languages.isEmpty { info(L("言語"), record.languages.joined(separator: L("、"))) }
        if shows(.plans), !record.plans.isEmpty { info(L("プラン"), record.plans.joined(separator: L("、"))) }
        if shows(.description), !record.description.isEmpty { info(L("説明"), record.description) }
        if shows(.officialPage), let url = URL(string: record.url), !record.url.isEmpty {
            Link(L("公式のページを開く"), destination: url).font(.caption)
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
    static func sample(_ text: String, font: CTFont, style: PreviewStyle) -> AttributedString {
        var result = AttributedString()
        for character in text {
            var piece = AttributedString(String(character))
            // tertiaryLabelColor（約26%）では濃いという指摘で、字形の無い文字は15%に
            piece.foregroundColor = !character.isWhitespace && !has(character, in: font) ? style.foreground.opacity(0.15) : style.foreground
            // カーニングを切るときは字送りの調整を0にする（指定しなければフォントのペアカーニングが効く）
            if !style.kerning { piece.kern = 0 }
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
