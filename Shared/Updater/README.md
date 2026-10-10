# 通常配布版の更新機能

Sparkle 2.10.0（公式配布SHA-256は `prepare.py` に固定）を使用します。各アプリは `DIRECT_UPDATES` が指定された通常ビルドだけでSparkleを参照します。`APP_STORE` ビルドでは更新コードを除外します。

共通実装は `UpdateSupport.swift` です。各Swiftターゲット内のコピーは `prepare.py` が一致確認します。共通実装を変更する場合は各アプリのコピー（全13本、`prepare.py` の TARGETS）も同期してください。これにより従来のSwiftPM / swiftcビルド構成を保っています。通常の `swift test` は更新UIをリンクせず既存ロジックを検証し、共通更新コードは `test.sh` がフレームワーク込みで検証します。

## 現在の動作

- 未設定のビルドはSparkle updaterを開始せず、更新通信・同意画面を出しません。手動確認で準備中と説明します。
- 正式設定後、初回起動時にSparkleの標準UIで自動チェックの選択を求めます。選択はSparkleが保存し、メニューから変更できます。
- 自動チェックの既定周期はSparkle標準の24時間です。ダウンロード・インストールはユーザー操作を必要とし、サイレント更新は無効です。
- エラー、更新なし、ダウンロードのキャンセル、インストールと再起動の確認はSparkle標準UIが担当します。これらの設定済み状態でのE2E検証はまだ実施していません。
- 更新アーカイブは展開前の署名検証を必須にしています。appcastも署名必須で、署名失敗の時間経過による例外を無効にしています。システムプロファイルの送信は無効です。
- FolderHopperの処理中終了拒否を保持し、KageTrimmerにも画像処理中の終了拒否を追加しました。

## 有効化に必要なもの

1. アプリごとの固定HTTPS appcast URLと、更新アーカイブを置く場所を決めます。ソースリポジトリのURLやnote記事のURLだけでは更新feedになりません。
2. Ed25519更新署名鍵の生成・保管・復旧方法を所有者が決めます。今回、鍵生成・秘密値の読み出し・Keychain登録は行っていません。鍵の共用は6アプリ全部の影響範囲になるため、原則アプリ別の鍵を推奨します。
3. 公開設定plistに `SUFeedURL` と `SUPublicEDKey` の2キーだけを入れ、対象アプリのビルド時に `UPDATE_PUBLIC_CONFIG=/path/to/public-config.plist` を渡します。公開鍵以外の署名情報は入れません。未設定は安全に停止し、部分設定・HTTP・明らかなダミーURL・不正な鍵形式はビルドで拒否します。この構文検査はURLの実在・鍵の所有を証明するものではありません。
4. 一般配布前に、Developer ID署名とApple公証を設定してください。現在のアドホック署名は配布の真正性をApple経由で証明しません。Sparkleのフレームワーク・Updater.app・XPCサービスなど内側のコードから正しく署名する必要があります。Library Validationを無効にする設定は追加していません。
5. 必ず `CFBundleVersion` を単調増加させ、Bundle ID・アプリ名を維持します。署名・公証後の最終アーカイブにSparkleの `generate_appcast` で署名します。署名後にappcastやアーカイブを書き換えないでください。
6. 検証済みの不変アーカイブを先に配置し、最後に署名済みappcastを公開します。今回は公開していません。

## 公開前の必須実機確認

別のテスト用配布先と正規の署名済み旧版・新版を使い、6本それぞれで次を確認してください。

- 初回の「自動確認する／しない」、再起動後の選択保持、メニューからの切り換え。
- 手動確認、更新なし、オフライン、404、遅い回線、チェック／ダウンロードのキャンセル。
- 署名のない／改ざんされたappcast、異なる鍵、破損アーカイブ、古いbuild番号、異なるBundle IDが拒否されること。
- 正常な更新、インストール途中の扱い、インストールと再起動、設定・ショートカット・プリセット・処理中データの保持。
- Applications配置、書込不可場所、DMG上の起動、App Translocation、Intel/Apple Siliconと対応OS（現在のアプリビルドはarm64）。
- App Store用アプリにSparkleや更新メニューが含まれないこと。

署名鍵が未設定なので、このリポジトリのテスト成功を更新インストール成功と解釈しないでください。

## 公式資料（2026-10-05確認）

- https://sparkle-project.org/documentation/
- https://sparkle-project.org/documentation/programmatic-setup/
- https://sparkle-project.org/documentation/customization/
- https://sparkle-project.org/documentation/publishing/
- https://sparkle-project.org/documentation/sandboxing/
- https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0

## 2026-10-08 公開鍵の設定

13本それぞれの公開鍵を `PublicKeys/<Bundle ID>.plist` に保存しました。秘密鍵はSparkle公式generate_keysでMacのキーチェーンへ保管し、書き出していません。署名時のaccountは `swwwitch.<Bundle ID>` を指定します（sign_update / generate_appcastの `--account`）。このMacのキーチェーンを失うと更新署名ができなくなるため、移行時は鍵の引き継ぎが必要です。

通常ビルドは公開鍵を自動で組み込みます。配信先未設定ではSUFeedURLを入れず、更新通信を開始しません。配信先確定後は公開鍵とSUFeedURLを含むUPDATE_PUBLIC_CONFIGを指定します。noteの記事URLをSUFeedURLとして設定しないでください。App Store版には公開鍵もSparkleも組み込みません。
