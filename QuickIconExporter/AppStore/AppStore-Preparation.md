# QuickIcon Exporter — App Store登録準備

## 登録情報案

- アプリ名: QuickIcon Exporter
- プラットフォーム: macOS
- プライマリ言語: 日本語
- メインカテゴリ: ユーティリティ
- バージョン: 1.0
- SKU案: `quickicon-exporter-macos-2026`
- Bundle ID: Apple Developerで新規登録後に確定

## サブタイトル案

Macのアイコンを透過PNGに

## 説明文案

QuickIcon Exporterは、macOSのアプリやファイルからアイコンを取り出し、取得できる最大サイズの透過PNGとして保存するシンプルなユーティリティです。

アプリやファイルをウインドウへドラッグ＆ドロップするだけで書き出せます。保存先、ファイル名の配置、区切り文字、空白の処理、不要な記号の削除を設定できます。複数ファイルの一括処理にも対応しています。

すべての処理はMac上で行われ、ファイルや画像が外部へ送信されることはありません。

## キーワード案

アイコン,PNG,透過,書き出し,抽出,アプリ,ファイル,一括変換,macOS

## プライバシー

- データ収集なし
- トラッキングなし
- 外部送信なし
- すべてローカル処理
- App Store Connectには公開可能なプライバシーポリシーURLが必要

## アップロード前に必要なもの

1. Apple Developer Programの更新反映
2. 正式なBundle IDの登録
3. Apple Distribution証明書
4. Mac Installer Distribution証明書
5. App Store Connectのアプリレコード
6. サポートURLとプライバシーポリシーURL
7. macOSスクリーンショット

## App Store用ビルド

証明書とBundle IDを取得後、次の環境変数を指定して実行します。

```sh
APP_BUNDLE_ID="jp.dtp-transit.quickiconexporter" \
APP_SIGNING_IDENTITY="Apple Distribution証明書名" \
INSTALLER_SIGNING_IDENTITY="Mac Installer Distribution証明書名" \
./build-app-store.sh
```

完成したPKGは `outputs/AppStore/QuickIcon Exporter.pkg` に作成されます。
