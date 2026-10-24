import SwiftUI

struct SettingsView: View {
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(SettingsSection(SettingsUI.launchTitle) {
                LoginAtLaunchView().fixedSize(horizontal: false, vertical: true)
                MenuBarPresenceView()
            })),
            (L("取り込み"), AnyView(MirrorSettingsView())),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView())),
        ]).padding(12)
    }
}

/// 「取り込み」タブ：たどる範囲・上限・通信・上書き。変更は次の取り込みから使う
private struct MirrorSettingsView: View {
    @AppStorage(Mirror.externalAssetsKey) private var externalAssets = true
    @AppStorage(Mirror.subdomainsKey) private var subdomains = false
    @AppStorage(Mirror.startFolderOnlyKey) private var startFolderOnly = false
    @AppStorage(Mirror.obeyRobotsKey) private var obeyRobots = true
    @AppStorage(Mirror.excludesKey) private var excludes = ""
    @AppStorage(Mirror.maxDepthKey) private var maxDepth = 0
    @AppStorage(Mirror.maxFilesKey) private var maxFiles = 10_000
    @AppStorage(Mirror.connectionsKey) private var connections = 4
    @AppStorage(Mirror.intervalKey) private var interval = 0.0
    @AppStorage(Mirror.retriesKey) private var retries = 2
    @AppStorage(Mirror.skipUnchangedKey) private var skipUnchanged = true
    @AppStorage(Mirror.includesKey) private var includes = ""
    @AppStorage(Mirror.useSitemapKey) private var useSitemap = false
    @AppStorage(Mirror.scanScriptsKey) private var scanScripts = false
    @AppStorage(Mirror.excludedTypesKey) private var excludedTypes = ""
    @AppStorage(Mirror.maxFileMBKey) private var maxFileMB = 0
    @AppStorage(Mirror.maxTotalMBKey) private var maxTotalMB = 0
    @AppStorage(Mirror.purgeRemovedKey) private var purgeRemoved = false

    private let intervals: [Double] = [0, 0.25, 0.5, 1, 2, 5]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("取り込む範囲")) {
                Toggle(L("ほかのドメインのCSS・JavaScript・画像・フォントも保存"), isOn: $externalAssets)
                note(L("CDNなどに置かれた、ページの表示に必要なファイルを保存します。ほかのドメインのページはたどりません。"))
                Toggle(L("サブドメインのページもたどる"), isOn: $subdomains)
                Toggle(L("開始URLのフォルダーより上はたどらない"), isOn: $startFolderOnly)
                Toggle(L("robots.txtに従う"), isOn: $obeyRobots)
                Toggle(L("sitemap.xmlに載っているページもたどる"), isOn: $useSitemap)
                note(L("どこからもリンクされていないページも見つけられます。robots.txtのSitemap:か、/sitemap.xmlを読みます。"))
                Toggle(L("JavaScriptの中に書かれたURLも拾う（推測）"), isOn: $scanScripts)
                note(L("引用符で囲まれた、画像・CSS・フォントなどのURLを拾います。関係のないURLを拾うことがあり、JavaScriptの中のURLは書き換えません。"))
                Text(L("取り込むURL :"))
                patterns($includes, label: L("取り込むURL"))
                note(L("書いたときは、当てはまるページだけをたどります（例：/illustrator/）。ページの表示に必要なファイルは関係なく取り込みます。"))
                Text(L("取り込まないURL :"))
                patterns($excludes, label: L("取り込まないURL"))
                note(L("1行に1つ。URLにその文字列が含まれていれば取り込みません（例：?page=、/tag/）。* は任意の文字列です。"))
            }
            SettingsSection(L("ファイルの種類と大きさ")) {
                HStack {
                    Text(L("取らない種類 :"))
                    TextField("", text: $excludedTypes, prompt: Text(verbatim: "mp4, mov, zip"))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel(L("取らない種類"))
                }
                note(L("拡張子をカンマで区切って書きます。拡張子の無いURLも、サーバーが返す種類で判定します。"))
                Stepper(value: $maxFileMB, in: 0...10_000, step: 10) {
                    Text(maxFileMB == 0 ? L("1ファイルの上限 : 無制限") : L("1ファイルの上限 : %d MB", maxFileMB))
                }
                Stepper(value: $maxTotalMB, in: 0...100_000, step: 100) {
                    Text(maxTotalMB == 0 ? L("合計の上限 : 無制限") : L("合計の上限 : %d MB", maxTotalMB))
                }
            }
            SettingsSection(L("上限")) {
                Stepper(value: $maxDepth, in: 0...50) {
                    Text(maxDepth == 0 ? L("たどる深さ : 無制限") : L("たどる深さ : %d", maxDepth))
                }
                Stepper(value: $maxFiles, in: 0...200_000, step: 1_000) {
                    Text(maxFiles == 0 ? L("ファイル数 : 無制限") : L("ファイル数 : %d", maxFiles))
                }
            }
            SettingsSection(L("通信")) {
                Stepper(value: $connections, in: 1...8) {
                    Text(L("同時接続数 : %d", connections))
                }
                Picker(L("取得の間隔 :"), selection: $interval) {
                    ForEach(intervals, id: \.self) { value in
                        Text(value == 0 ? L("なし") : L("%@秒", value.formatted())).tag(value)
                    }
                }
                .fixedSize()
                Stepper(value: $retries, in: 0...5) {
                    Text(retries == 0 ? L("失敗したときの再試行 : しない") : L("失敗したときの再試行 : %d回", retries))
                }
                note(L("同時接続数を増やすと速くなりますが、相手のサーバーの負担が増えます。失敗が多いときは、間隔をあけると通りやすくなります。再試行は、タイムアウトや一時的なエラー（429・5xx）のときだけ行います。"))
            }
            SettingsSection(L("上書き")) {
                Toggle(L("変わっていない画像などは取り直さない"), isOn: $skipUnchanged)
                note(L("同じフォルダーに上書きで取り込むとき、前回から変わっていないファイルはサーバーに確かめるだけで取り直しません。HTMLとCSSは毎回取り直します。"))
                Toggle(L("サイトから消えたファイルをゴミ箱に入れる"), isOn: $purgeRemoved)
                note(L("上書きで最後まで取り込めたとき、前回保存したのに、今回どこからもリンクされていないか、サーバーが404・410を返したファイルをゴミ箱に入れます。一時的に取れなかったファイルや除外したファイルは残します。"))
            }
            Button(L("初期値に戻す")) {
                externalAssets = true; subdomains = false; startFolderOnly = false; obeyRobots = true; excludes = ""
                maxDepth = 0; maxFiles = 10_000; connections = 4; interval = 0; retries = 2; skipUnchanged = true
                includes = ""; useSitemap = false; scanScripts = false; excludedTypes = ""; maxFileMB = 0; maxTotalMB = 0; purgeRemoved = false
            }
        }
    }

    private func patterns(_ text: Binding<String>, label: String) -> some View {
        TextEditor(text: text)
            .font(.system(.body, design: .monospaced))
            .frame(height: 60)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
            .accessibilityLabel(label)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
