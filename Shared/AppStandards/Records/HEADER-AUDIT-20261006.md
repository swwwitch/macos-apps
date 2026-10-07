# メインウインドウのアプリアイコン改修（2026-10-06）

対象は現在の9本。元の8本にSuperKakkoReplaceを含めて確認。

| アプリ | 変更 | 配布ビルド |
|---|---|---|
| BrowserSwitcher | 見出し左に44ptの現行アイコン | 23 |
| CommandDee | メインのヘルプ画面冒頭にアイコンとアプリ名 | 14 |
| ExtLink | 青い仮シンボルをバンドルアイコンに変更 | 17 |
| FolderHopper | 操作一覧上に44ptアイコン付き見出し追加 | 72 |
| KageTrimmer | 既存44ptアイコンをバンドルの現行リソース参照に統一 | 29 |
| QuickIconExporter | 仮シンボルを44ptバンドルアイコンに変更 | 8 |
| PodiumFlight | 主画面見出し左に44ptアイコン追加 | 17 |
| MightyEdit | パレット上部に32ptアイコンとアプリ名追加 | 30 |
| SuperKakkoReplace | パレット上部に32ptアイコンとアプリ名追加、高さ確保 | 7 |

## 確認済み

- 9本すべてビルド成功、既存の署名方式を維持。
- CFBundleIconFileが参照する現行icnsが全バンドルに存在。
- /ApplicationsとLatest Buildsの全ファイル・モード・ハッシュ一致、codesign --verify --deep --strict成功。
- /Applications旧版をShared/BuildBackups/header-applications-20261006-074832および074839へ退避。
- BrowserSwitcherは/Applicationsから起動、新しいアイコンと見出しをアクセシビリティツリーで確認。

## 残る確認

ネイティブ画面取得がtimeoutReachedとなり、全9本の目視確認は未完了。起動中の旧プロセスは次回再起動で新しい画面になる。PodiumFlightは別パス、MightyEditはLatest Buildsから動作中のため、/Applications版への再起動確認が必要。明暗表示、パレットの最小サイズ、全操作の回帰確認は未実施。

## 今後の実装

AGENTS.mdとBASELINE.mdのB14に従う。Shared/AppStandards/AppHeader.swiftを実装の参照として利用。通常画面44pt、パレット32pt、アイコンとタイトルの間隔12pt。Bundle.mainのCFBundleIconFileから取得し、画像は装飾として読み上げ対象から除外する。

## ヘッダー形式の追加改修

左に現行アプリアイコン、右に「端的な機能見出し／補足説明」を上下に配置する。アプリ名だけの見出しを使わない。BrowserSwitcherは説明をタイトル直下へ移動。CommandDeeは「ファイルの複製と名前変更」、FolderHopperは「選択したファイルを移動」、MightyEditは「選択テキストを整える」、SuperKakkoReplaceは「カッコを付ける・置き換える」へ変更し、それぞれ説明を追加。PodiumFlightは見出し直下に補足説明を追加。ExtLink・KageTrimmer・QuickIconExporterは既にこの構造を満たしている。
