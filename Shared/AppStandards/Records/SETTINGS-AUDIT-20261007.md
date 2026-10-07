# 環境設定のUI整理

共通SettingsSection.swiftを追加。既存設定キー・実行処理・初期値は保持。AppKitとSwiftUIに共通の見出し・間隔・カテゴリ枠を設けた。不要なAX権限UIは除去（権限自体は変更しない）。

| アプリ | 変更 |
| --- | --- |
| BrowserSwitcher | 起動・常駐（ログイン、起動時非表示、メニューバー表示、呼び出し）／一覧から除外するブラウザー |
| CommandDee | 起動・常駐／機能のショートカット／ファイル名／アクセシビリティ。スクロール対応 |
| FolderMover | 起動・常駐／表示／プライバシー |
| FolderHopper | 起動・常駐に呼び出しを集約。表示／ファイル操作／履歴を分離 |
| KageTrimmer | 起動・常駐に呼び出しとメニューバー表示を集約 |
| KakkoReplace | 一般を起動・常駐へ変更。ログイン・起動時非表示・常駐の順。機能ショートカット／パレット／カッコ／対象外アプリは保持 |
| MightyEdit | 起動・常駐タブを先頭へ。常駐・メニューバー表示・パレット呼び出しを集約。機能ホットキー・権限・固有設定を保持 |
| PodiumFlight | 起動設定を主画面から環境設定の先頭タブへ移動。アプリ起動／終了／タイマー／プリセットを保持 |
| QuickIconExporter | 起動・常駐／完了時／出力／ファイル名。完了時の重複セクションを統合 |
| ExtensionLinker | 起動・常駐を独立した先頭タブへ。インストール／拡張子を保持 |

10本のビルド結果、配置・署名・一致確認はSETTINGS-DEPLOY-20261007.txt。BrowserSwitcherとFolderMoverの/Applications版で設定画面を表示し、グループと既存値を確認。ただし最終調整後の再表示は未確認。KakkoReplaceの/Applications版は主画面を起動確認。続く設定画面の操作で「Sky Computer Use native pipe closed before response」が発生し、セッション再初期化後も復旧しない。ほか7本の改修後GUI起動・設定表示は未確認。設定値を変更するUI試験は行っていない。配置済み10本の署名・内容一致は完了しているが、全アプリの実機検証完了とはしない。

## タブ形式への統一

全10本で「起動・常駐」を先頭の独立タブとした。機能実行ホットキー、表示、出力などは別タブ。AppKitはSettingsUI.tabs、SwiftUIはNSTabViewを内包したSettingsTabsを使用し、タイトルバー内へのタブ移動を防ぐ。AppKitのスクロール領域は上端から配置する。既存値は保持。

最終ビルドは全10本を/ApplicationsとLatest Buildsへ配置し、Bundle ID、バージョン、署名、内容一致を確認した。BrowserSwitcherのタブ表示とKakkoReplaceの起動は途中版で確認したが、最終版の全10本の設定表示は未確認。最終版の再確認時にもSky Computer Use native pipe closed before responseが発生した。App Store専用分岐はビルド未確認。

## 起動・常駐と権限の同一カテゴリ化

2026-10-07の追加指示で、アクセシビリティも起動・常駐タブへ移動。CommandDee build 22、KakkoReplace build 20、MightyEdit build 55をビルドし、バックアップ後に/ApplicationsとLatest Buildsへ配置。署名・内容一致を確認。MightyEditとCommandDeeは/Applicationsから起動し、同一タブ内の起動設定・権限状態表示を実機確認。MightyEditの呼び出しショートカットも同一タブ内にあることを確認。KakkoReplaceは起動を確認したが、設定表示操作でSky Computer Use native pipe closed before responseが発生し、設定画面は未確認。設定値・権限は変更していない。呼び出し機能がないアプリへ新しいショートカットは追加していない。
