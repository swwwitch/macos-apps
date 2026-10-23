# SettingsCourier 1.3.2（build 9）公開準備記録

確認日：2026-10-24。実行Mac：MacBook-Pro-14-2024-sw.local。
この記録はリリース完了を意味しない。

## 確認済み

- 開始時のGitHub mainとローカルHEAD：79f516756b2efe478d49f6e54b8e5e1f42946a5f。fetch後に一致。
- 1.3.1 build 8から1.3.2 build 9へ更新。機能変更なし。READMEの句読点と更新履歴を修正。
- NO_DEPLOY=1 ./build.sh：成功。成果物はSettingsCourier/build/SettingsCourier.app。
- 4言語のHelp.txt構成・翻訳キー・noteリンク検査：PASS。
- codesign --verify --deep --strict：成功。Apple Distribution署名であり、Developer ID署名ではない。
- バイナリ：arm64。Info.plist：macOS 14以降、jp.dtp-transit.settingscourier、1.3.2 / 9。
- build内アプリの起動プロセス・再表示・メイン画面の1.3.2（9）表示を確認。既存登録一覧も表示。
- /ApplicationsとLatest Buildsの既存版は1.3.1 build 8。今回の成果物は未配置。
- VectorMateの既存未コミット変更は保持。

## 未完了・再開条件

1. 自動テストは翻訳チェックのみ。専用の機能テストターゲットはPackage.swiftにない。実アプリへの設定取り込み・復元、設定保持、終了、ログイン起動の今回の実機試験は未実施。
2. Developer ID Application証明書と秘密鍵を現在の実行環境から取得できない。有効な署名IDはApple Distributionのみ。
3. notarytool history --keychain-profile swwwitch-notary：既定・明示login.keychain-dbで項目が見つからない。別名notaryも同様。明示System.keychainではロック中のエラー。ユーザーの解除連絡後も同じ結果。キーチェーンアクセスのログイン・システム・iCloudで公証関連項目の検索結果なし。不存在とは断定せず、利用可能な保存先・実行Macの確認が必要。
4. 公証・アプリへのチケット添付・DMG作成/署名/公証/検証：未実施。
5. 両配布先へのバックアップ・置換・一致確認・/Applicationsからの最終版実機確認：未実施。
6. Notarized DMGs整理・SHA-256更新・GitHub Release公開・公開DMGの再ダウンロード検証：未実施。
7. gh project listはread:projectスコープ不足。既存Projectの特定・更新は未実施。認証権限は変更していない。
8. noteはSafariでログイン済みの記事一覧を確認。直近一覧にSettingsCourierは見つからず新規エディターを開いた（https://editor.note.com/notes/nd02fb3b412c5/edit/）。本文保存・公開は未実施。原稿は同ディレクトリのnote-draft.md。
9. 見出し画像・DMG添付・関連Releaseリンク・公開設定のタグ登録・公開後検証：未実施。

公開時は上記を実施し、ソースコミット・公証ID・配布ハッシュ・Release URL・note URLを追記する。
