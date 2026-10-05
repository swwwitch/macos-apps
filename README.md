# macOS utilities

6本のmacOSユーティリティのソースです。通常配布版の再現に必要なSwiftソース、アイコン、ローカライズ、ビルドスクリプトを収録しています。

| アプリ | ソース | ビルドコマンド | 検証版 |
|---|---|---|---|
| BrowserSwitcher | `BrowserSwitcher/Source` | `zsh BrowserSwitcher/build.sh` | 1.6.8 (19) |
| ExtLink | `DutiGUI/Sources/DutiGUI` | `bash DutiGUI/build.sh` | 0.2.2 (7) |
| FolderHopper | `FolderHopper/Development/Source` | `zsh FolderHopper/Development/build.sh` | 0.1.65 (71) |
| KageTrimmer | `SoftShadow/Sources` | `zsh SoftShadow/build.sh` | 1.0 (28) |
| PodiumFlight | `Toki/Development/Sources/Toki` | `bash Toki/Development/build-app.sh` | 3.1.7 (14) |
| QuickIconExporter | `mac-png/Sources/IconDrop` | `zsh mac-png/build-app.sh` | 1.0 (7) |

macOS、Xcodeのコマンドラインツール（Swift 6以降）、Python 3が必要です。Apple Silicon上で検証しました。BrowserSwitcher / ExtLink / FolderHopper / PodiumFlightはmacOS 13以降、KageTrimmer / QuickIconExporterはmacOS 14以降が対象です。古いOSでの実機検証は未実施です。

リポジトリのルートで上のコマンドを実行してください。初回ビルド時に公式のSparkle 2.10.0をダウンロードし、固定SHA-256を照合します。ローカルに取得済みの同一アーカイブは `SPARKLE_ARCHIVE` 環境変数で指定できます。SDKとビルド生成物はGit管理しません。

成功した通常ビルドは `Latest Builds/` にコピーされます。同じBundle IDの古いビルドへの逆戻りを拒否し、置き換える前のアプリを `Shared/BuildBackups/` に保存します。スクリプトが生成するアプリはアドホック署名です。Developer ID署名・公証済みの一般配布物ではありません。

## 更新機能の状態

Sparkleの標準画面を使う更新機能を組み込みましたが、**更新先・署名公開鍵は未設定で、自動更新の実運用は開始していません**。手動の「アップデートを確認…」は未設定を案内し、自動チェックは利用できません。架空の配布先には接続しません。

[更新配布の設定・検証手順](Shared/Updater/README.md)をご覧ください。ソースの公開と、更新バイナリ／appcastの公開は別作業です。旧公開版にこの機能は入っていないため、初回は更新機能を設定済みの版を手動導入する必要があります。

既存のApp Store申請向けXcodeプロジェクト・証明書・プロファイル・ローカル設定はこの公開ソースに含めていません。`mac-png/build-app-store.sh` は自身の署名情報を環境変数で指定する従来の補助スクリプトです。そのビルド入力にはSparkleを含めませんが、App Storeの署名・審査・提出は本リポジトリの検証対象外です。

## 検証

`bash Shared/Updater/test.sh` で更新設定の拒否テストと、未設定時の起動・メニュー状態のテストを実行できます。その他の既存テストは各ソース内にあります。検証結果と未検証事項は [検証記録](VERIFICATION.md) を参照してください。

## 権利表記

アプリソースについて新しいライセンスは付与していません。公開されていることだけをもって再利用条件を追加するものではありません。既存の権利表記を保持しています。Sparkleは別ライセンスです。[第三者ソフトウェア](Shared/Updater/THIRD-PARTY-NOTICES.txt)をご覧ください。
