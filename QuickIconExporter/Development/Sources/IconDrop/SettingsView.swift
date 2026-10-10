import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(Form { Section(SettingsUI.launchTitle) { LoginAtLaunchView().fixedSize(horizontal: false, vertical: true); MenuBarPresenceView() 
            } }.formStyle(.grouped))),
            (L("書き出し"), AnyView(Form { Section(L("書き出し")) {
                LabeledContent(L("保存先")) {
                    Text(settings.outputDirectory.path(percentEncoded: false))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 280, alignment: .trailing)
                }

                HStack {
                    Spacer()
                    Button(L("デスクトップに戻す")) {
                        settings.restoreDesktop()
                    }
                    Button(L("フォルダを選択…")) {
                        settings.chooseOutputDirectory()
                    }
                    .buttonStyle(.borderedProminent)
                }
            
                Text(L("PNGは透過を保ったまま、取得できる最大のピクセルサイズで保存されます。同名ファイルがある場合は番号を付けて保存します。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            
            } }.formStyle(.grouped))),
            (L("ファイル名"), AnyView(Form { Section(L("ファイル名")) {
                LabeledContent(L("icon部分")) {
                    TextField("", text: $settings.filenamePrefix)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: 190)
                }

                LabeledContent(L("配置")) {
                    Picker(L("配置"), selection: $settings.iconNamePosition) {
                        ForEach(IconNamePosition.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }

                LabeledContent(L("区切り文字")) {
                    Picker(L("区切り文字"), selection: $settings.filenameSeparator) {
                        ForEach(FilenameSeparator.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }

                LabeledContent(L("空白の処理")) {
                    Picker(L("空白の処理"), selection: $settings.spaceReplacement) {
                        ForEach(SpaceReplacement.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }

                Toggle(L("不要な記号を削除"), isOn: $settings.removesUnwantedCharacters)

                LabeledContent(L("プレビュー")) {
                    Text(filenamePreview)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Spacer()
                    Button(L("命名設定を初期値に戻す")) {
                        settings.restoreFilenameDefaults()
                    }
                }
            
            } }.formStyle(.grouped))),
            (L("完了時"), AnyView(Form { Section(L("完了時")) {
                Toggle(L("書き出し後、Finderで表示"), isOn: $settings.revealsInFinder)
                Toggle(L("書き出し後、アプリを隠す"), isOn: $settings.hidesAfterExport)
                Toggle(L("通知を表示"), isOn: $settings.showsCompletionNotification)
                Toggle(L("効果音を鳴らす"), isOn: $settings.playsCompletionSound)
                Text(L("通知を初めて使用するときは、macOSから許可を求められます。"))
                    .font(.caption).foregroundStyle(.secondary)

            
            } }.formStyle(.grouped))),
            (StartupWindow.text("ホットキー", "Shortcuts", "快捷键", "단축키"), AnyView(Form { Section(StartupWindow.text("ホットキー", "Shortcuts", "快捷键", "단축키")) {                Text(L("Finderでファイルを選択し、右クリック → サービス → アイコンを書き出す（QuickIconExporter）で実行できます。ホットキーはシステム設定 → キーボード → キーボードショートカット → サービスで変更できます。"))
                    .font(.caption)
            } }.formStyle(.grouped))),
            (AboutSection.title, AnyView(AboutView()))
        ]).padding(12)
    }

    private var filenamePreview: String {
        let sample = URL(fileURLWithPath: "/Sample App.app")
        return IconExporter.outputBaseName(for: sample, rules: settings.filenameRules) + ".png"
    }
}
