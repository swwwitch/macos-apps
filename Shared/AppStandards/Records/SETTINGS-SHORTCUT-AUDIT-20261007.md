# ⌘, 共通ショートカット確認

11本のソースを確認。全て既存実装があるため実装変更・再ビルド・再配置なし。共通仕様とAGENTSへ明記。全11本のキー入力による実機確認は未実施。

| アプリ | 実装 |
| --- | --- |
| BrowserSwitcher | Source/main.swift: アプリメニューのshowPreferencesにカンマ |
| CommandDee | Sources/main.swift: メニューとローカルキー処理 |
| ExtensionLinker | Development/Sources/DutiGUI/DutiGUIApp.swift: Settingsシーン |
| FolderHopper | Development/Source/main.swift: アプリメニューのshowPreferencesにカンマ |
| FolderMover | Source/main.swift: アプリメニューのshowSettingsにカンマ |
| KageTrimmer | Development/Sources/SoftShadowApp.swift: アプリメニューのshowSettingsにカンマ |
| KakkoReplace | Sources/main.swift: アプリメニューのshowPreferencesにカンマ |
| MightyEdit | Source/main.swift: アプリメニューのshowPreferencesにカンマ |
| PandocDesk | Source/main.swift: アプリメニューのshowSettingsにカンマ |
| PodiumFlight | Development/Sources/Toki/TokiApp.swift: アプリメニューのshowPreferencesにカンマ |
| QuickIconExporter | Development/Sources/IconDrop/IconDropApp.swift: Settingsシーン |

## ⌘W

MightyEditへNSWindow.performCloseを使う標準メニューを追加。CommandDeeは既存のローカルキー処理に加え、同じ標準メニューを追加。両方ビルド成功、両配置先の署名・内容一致を確認。配置済みMightyEdit 0.1.49 build 61、CommandDee 1.7.0 build 23。MightyEditは/Applicationsから設定を表示し、⌘W後に設定が閉じて主パレットが残ることを実機確認。CommandDeeは起動確認し、⌘Wを実行したが、観測APIが設定ウインドウを再表示するため閉鎖確認は未完了。ほか9本は既存のAppKit閉じるメニューまたはSwiftUI標準WindowGroup/Settingsで対応する構成をソース確認。全11本の実機確認は未完了。
