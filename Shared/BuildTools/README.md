# 検証済みビルドの共通配置

ビルドスクリプトが正常に署名検証を終えたあと、`publish_latest.py`を呼び出します。

- BrowserSwitcher：`BrowserSwitcher/build.sh` に組み込み済み。1.6.4（build 12）の実ビルド・署名検証・自動コピーを確認済み。
- ExtensionLinker：`ExtensionLinker/Development/build.sh` に組み込み済み。実ビルド→自動コピー→署名検証まで確認済み。
- KageTrimmer：`KageTrimmer/Development/build.sh` に組み込み済み。シェル構文確認済み。今回の再ビルドは未実施。
- QuickIconExporter：`QuickIconExporter/Development/build-app.sh` に組み込み済み。シェル構文確認済み。今回の再ビルドは未実施。App Store用スクリプトから通常ビルドを呼んだ場合も通常版がコピーされます。署名済み申請用パッケージは別の出力先です。
- FolderHopper：`FolderHopper/Development/build.sh` に組み込み済み。実ビルド・署名検証・自動コピーを確認済み。
- PodiumFlight：`PodiumFlight/Development/build-app.sh` に組み込み済み。実ビルド・署名検証・自動コピーを確認済み。

両アプリのソースは `/Users/takano/Documents/Codex` から取得しました。元フォルダは保持しています。今後はsw_app内のDevelopmentでビルドしてください。

## コピー処理

- コピー前後に署名を検証します。
- ファイル内容・実行権限・シンボリックリンクの一致を確認します。
- 既存アプリとBundle IDが異なる場合や、整数のbuild番号が古い場合は拒否します。
- 前のアプリは`Shared/Backups/Build`へ保存します。
- Latest Buildsには実体を配置します。
- 監視プロセスや常駐アプリは使用しません。上記スクリプトを経由しないビルドでは自動コピーされません。

## /Applications と Latest Builds への同時配置

`python3 Shared/BuildTools/deploy_both.py path/to/App.app` で、検証済みのビルドを2か所へ配置します（2026-10-07追加）。

- 既存版とBundle IDが異なる場合、または整数のbuild番号が古い場合は何も置き換えません。
- アプリの実行中は拒否します。先に終了してください（処理中のアプリは自分で終了を拒みます）。
- 既存版は `Shared/Backups/Build/<日時>/Applications|LatestBuilds/` へ退避します。
- 配置後に署名を検証し、全ファイルの内容と実行権限が元と一致することを確認します。
- `Latest Builds/README.md` の該当行の版とbuildを更新します。行がなければ手で追加します。

## 2026-10-08 配置経路の修正

通常ビルドの `publish_latest.py` は `deploy_both.py` を呼び、/Applications と Latest Builds の両方を更新します。全13本のビルド入口へ接続しました。App Store候補は通常版へ配置しません。両コピーを先に作成・検証し、置換失敗時は既存版を復元します。実行中アプリのパスに空白がある場合も検出し、プロセス確認自体に失敗した場合は置換しません。更新配信のURL・公開鍵は未設定のままです。
