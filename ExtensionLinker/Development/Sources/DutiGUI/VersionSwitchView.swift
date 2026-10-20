import SwiftUI
import AppKit
import UniformTypeIdentifiers

#if !APP_STORE
/// 「アプリの版」タブ: switches every listed extension of an app (Illustrator, Photoshop, InDesign …) to one installed version at once.
@MainActor
final class VersionSwitchModel: ObservableObject {
    struct Product: Identifiable {
        let name: String
        let bundleID: String
        let versions: [InstalledVersion]
        /// Listed extensions that this app (any version) opens now.
        let extensions: [String]
        let types: [String]
        /// Version label(s) that open those types now.
        let currentLabels: [String]
        /// Recorded preferred version per type ("-": newest).
        let pinned: Set<String>
        var choice: String
        var id: String { bundleID }
        var changed: Bool { !types.isEmpty && pinned != [choice] }
    }
    @Published var products: [Product] = []
    @Published var applying = false
    @Published var status = ""
    @Published var error: String?

    var pending: [Product] { products.filter(\.changed) }

    /// `keepChoices`: a reload on returning to the app keeps versions picked but not yet applied.
    func reload(_ rows: [Association], keepChoices: Bool = false) {
        let picked = keepChoices ? Dictionary(uniqueKeysWithValues: products.map { ($0.bundleID, $0.choice) }) : [:]
        products = VersionPinning.products.compactMap { product in
            let versions = VersionPinning.versions(of: product.bundleID)
            guard versions.count > 1 else { return nil }
            var extensions: [String] = []
            var types: [String] = []
            var urls: [URL] = []
            for row in rows {
                let opened = row.types.compactMap { type -> (String, URL)? in
                    guard let id = LSCopyDefaultRoleHandlerForContentType(type.identifier as CFString, .all)?.takeRetainedValue() as String?,
                          id.caseInsensitiveCompare(product.bundleID) == .orderedSame,
                          let url = NSWorkspace.shared.urlForApplication(toOpen: type) else { return nil }
                    return (type.identifier, url)
                }
                guard !opened.isEmpty else { continue }
                extensions.append(row.extensionLabel)
                types += opened.map(\.0)
                urls += opened.map(\.1)
            }
            let labels = urls.compactMap { url in versions.first { $0.urls.contains(url) || $0.version == VersionPinning.bundleVersion(of: url) }?.label }
            let pinned = Set(VersionPinning.pinnedVersions(for: types).values)
            let known = Set(versions.map(\.version) + [VersionPinning.anyVersion])
            let recorded = pinned.count == 1 && known.contains(pinned.first!) ? pinned.first! : VersionPinning.anyVersion
            let choice = picked[product.bundleID].flatMap { known.contains($0) ? $0 : nil } ?? recorded
            return Product(name: product.name, bundleID: product.bundleID, versions: versions, extensions: extensions, types: types,
                           currentLabels: labels.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }, pinned: pinned, choice: choice)
        }
    }
    func apply(_ store: AssociationStore) {
        let changes = pending
        guard !changes.isEmpty, !applying else { return }
        applying = true
        status = L("切り替え中…")
        Task {
            do {
                try await VersionPinning.apply(changes.map {
                    .init(bundleID: $0.bundleID, version: $0.choice == VersionPinning.anyVersion ? nil : $0.choice, types: $0.types)
                })
                status = L("%@種類の拡張子を切り替えました。", String(describing: changes.reduce(0) { $0 + $1.extensions.count }))
            } catch {
                self.error = error.localizedDescription
                status = ""
            }
            store.refresh()
            reload(store.rows)
            applying = false
        }
    }
}

struct VersionSwitchView: View {
    @ObservedObject var store: AssociationStore
    @StateObject private var model = VersionSwitchModel()
    @State private var confirm = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("アプリの版")).font(.title2.bold())
            Text(L("複数の版をインストールしたアプリについて、関連付けた拡張子をまとめて指定の版で開くようにします。"))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if model.products.isEmpty {
                Text(L("複数の版がインストールされたアプリは見つかりません。")).foregroundStyle(.secondary)
            }
            ForEach($model.products) { $product in
                SettingsSection(product.name) {
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 8) {
                        GridRow {
                            Text(L("拡張子 :")).gridColumnAlignment(.trailing)
                            Text(product.extensions.isEmpty ? L("関連付けた拡張子はありません") : product.extensions.joined(separator: ", "))
                                .foregroundStyle(product.extensions.isEmpty ? .secondary : .primary).fixedSize(horizontal: false, vertical: true)
                        }
                        GridRow {
                            Text(L("現在 :"))
                            Text(product.currentLabels.isEmpty ? "—" : product.currentLabels.joined(separator: L("、")))
                                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        GridRow {
                            Text(L("開く版 :"))
                            Picker(L("開く版 :"), selection: $product.choice) {
                                Text(L("最新版（自動）")).tag(VersionPinning.anyVersion)
                                Divider()
                                ForEach(product.versions) { version in Text(version.label).tag(version.version) }
                            }
                            .labelsHidden().frame(maxWidth: 320, alignment: .leading)
                            .disabled(product.types.isEmpty)
                        }
                    }
                }
            }
            HStack {
                Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
                Button(L("再読み込み")) { model.reload(store.rows) }
                Button(L("%@件を切り替え", String(describing: model.pending.count))) { confirm = true }
                    .buttonStyle(.borderedProminent).disabled(model.pending.isEmpty)
            }
            Text(L("最新版（自動）は、インストールされている版のうち最も新しい版で開きます。メインウインドウでアプリを選び直すと、その拡張子は最新版（自動）に戻ります。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .disabled(model.applying || store.applying)
        .onAppear { model.reload(store.rows) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if !model.applying { model.reload(store.rows, keepChoices: true) }
        }
        .alert(L("拡張子を開く版を切り替えますか？"), isPresented: $confirm) {
            Button(L("キャンセル"), role: .cancel) { }
            Button(L("切り替える")) { model.apply(store) }
        } message: {
            Text(L("対象: %@\n\nmacOSの関連付けの記録に版を書き込み、関連付けを管理するシステムの処理（lsd）を再起動します。変更前の記録は ~/Library/Application Support/ExtensionLinker に保存します。",
                   String(describing: model.pending.map { "\($0.name)（\($0.extensions.joined(separator: ", "))）" }.joined(separator: L("、")))))
        }
        .alert(L("版を切り替えられません"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { }
        } message: { Text(model.error ?? "") }
    }
}
#endif
