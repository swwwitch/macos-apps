import SwiftUI
import AppKit

#if !APP_STORE
@MainActor
final class DutiEnvironment: ObservableObject {
    @Published var duti: String?
    @Published var brew: String?
    @Published var installing = false
    @Published var log = ""
    @Published var status = ""
    @Published var dutiVersion = ""
    @Published var versionNote = ""
    private var refreshID = UUID()
    init() { refresh() }
    func refresh() {
        duti = find("duti")
        brew = find("brew")
        refreshID = UUID()
        let requestID = refreshID
        guard let duti else { dutiVersion = ""; versionNote = ""; return }
        dutiVersion = L("確認中…")
        versionNote = ""
        Task {
            let version = await Task.detached { Self.version(at: duti) }.value
            guard refreshID == requestID else { return }
            dutiVersion = version.0
            versionNote = version.1
        }
    }
    nonisolated static func version(at path: String) -> (String, String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-V"]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            process.waitUntilExit()
            guard process.terminationStatus == 0, !output.isEmpty else { return (L("取得できませんでした"), output) }
            if output == "INTERNAL" {
                let installed = URL(fileURLWithPath: path).resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent()
                if installed.pathComponents.contains("Cellar"), installed.deletingLastPathComponent().lastPathComponent == "duti" {
                    return (installed.lastPathComponent + "（Homebrew）", L("duti -V が INTERNAL を返すため、Homebrewの導入バージョンを表示しています。"))
                }
                return ("INTERNAL", L("このdutiはバージョン番号を返さないビルドです。"))
            }
            return (output, "")
        } catch { return (L("取得できませんでした"), error.localizedDescription) }
    }
    func installHomebrew() {
        guard brew == nil else { return }
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dutiGUI-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let command = directory.appendingPathComponent("Install-Homebrew.command")
            try Self.homebrewInstaller.write(to: command, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: command.path)
            NSWorkspace.shared.open([command], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), configuration: .init()) { _, error in
                Task { @MainActor in
                    if let error { self.status = L("ターミナルを開けませんでした: ") + error.localizedDescription }
                    else { self.status = L("ターミナルでインストールを完了し、「再確認」を押してください。") }
                }
            }
        } catch { status = error.localizedDescription }
    }
    nonisolated static let homebrewInstaller = #"""
    #!/bin/bash
    set -u
    printf 'Homebrewの公式インストーラーを起動します。\n'
    installer="$(/usr/bin/mktemp -t dutiGUI-homebrew)" || exit 1
    trap '/bin/rm -f "$installer"' EXIT
    if /usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
        /bin/bash "$installer"
        result=$?
    else
        result=1
        printf 'インストーラーを取得できませんでした。\n'
    fi
    if [ "$result" -eq 0 ]; then
        printf '\nHomebrewのインストールが完了しました。ExtensionLinkerに戻り「再確認」を押してください。\n'
    else
        printf '\nインストールは完了していません。上のメッセージを確認してください。\n'
    fi
    read -r -p 'Enterで終了します。' unused
    exit "$result"
    """#
    private func find(_ name: String) -> String? {
        var dirs = ["/opt/homebrew/bin", "/usr/local/bin"]
        dirs += (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        return dirs.map { $0 + "/" + name }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    func install() {
        guard let brew, !installing else { return }
        installing = true
        log = "$ \(brew) install duti\n"
        status = L("インストール中…")
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> (Int32, String) in
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: brew)
                process.arguments = ["install", "duti"]
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
                process.environment = env
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
                } catch { return (-1, error.localizedDescription) }
            }.value
            log += result.1
            refresh()
            status = result.0 == 0 && duti != nil ? L("dutiをインストールしました。") : L("インストールできませんでした。下のログを確認してください。")
            installing = false
        }
    }
}

#endif

#if APP_STORE
struct EnvironmentView: View {
    @ObservedObject var store: AssociationStore
    var body: some View { ExtensionSettingsView(store: store).padding(12) }
}
#else
struct EnvironmentView: View {
    @ObservedObject var store: AssociationStore
    @StateObject private var environment = DutiEnvironment()
    var body: some View {
        TabView {
            environmentBody.tabItem { Label(L("インストール"), systemImage: "shippingbox") }
            ExtensionSettingsView(store: store).tabItem { Label(L("拡張子"), systemImage: "list.bullet") }
        }.padding(12)
    }
    private var environmentBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(L("環境設定"), systemImage: "gearshape").font(.title2.bold())
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("duti").font(.headline)
                    Spacer()
                    Label(environment.duti == nil ? L("未インストール") : L("インストール済み"), systemImage: environment.duti == nil ? "circle.dashed" : "checkmark.circle.fill")
                        .foregroundStyle(environment.duti == nil ? Color.secondary : .green)
                }
                if let path = environment.duti {
                    Text(L("バージョン: ") + environment.dutiVersion).font(.callout).textSelection(.enabled)
                    Text(path).font(.caption.monospaced()).textSelection(.enabled)
                    if !environment.versionNote.isEmpty {
                        Text(environment.versionNote).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(L("このアプリの設定変更はmacOSのAPIで動作します。dutiはターミナルから同じ設定を行う場合に使えます。"))
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Homebrew").font(.headline)
                    Text(environment.brew ?? L("見つかりません")).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
                Button(L("再確認")) { environment.refresh() }.disabled(environment.installing)
            }
            if environment.brew != nil {
                HStack {
                    Button(environment.installing ? L("インストール中…") : L("dutiをインストール")) { environment.install() }
                        .buttonStyle(.borderedProminent).disabled(environment.installing || environment.duti != nil)
                    if environment.installing { ProgressView().controlSize(.small) }
                    Text("brew install duti").font(.caption.monospaced()).foregroundStyle(.secondary)
                }
            } else {
                Text(L("ターミナルで公式インストーラーを実行します。完了後に「再確認」を押すとdutiをインストールできます。"))
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                Button(L("Homebrewをインストール…")) { environment.installHomebrew() }.buttonStyle(.borderedProminent)
                Link(L("Homebrewの導入ページを開く ↗"), destination: URL(string: "https://brew.sh/ja/")!)
            }
            if !environment.status.isEmpty { Text(environment.status).font(.callout) }
            if !environment.log.isEmpty {
                ScrollView {
                    Text(environment.log).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }.frame(height: 180).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
        }.padding(28)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if !environment.installing { environment.refresh() }
        }
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
            LoginAtLaunchView().frame(height: 80)
            Text(L("拡張子一覧")).font(.title2.bold())
            Text(L("メインウィンドウに表示する拡張子を管理します。"))
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
