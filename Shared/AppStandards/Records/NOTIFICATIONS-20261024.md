# 通知の共通化（2026-10-24）

## 対象と判断

現行SwiftソースのUserNotifications/NSUserNotification検索で標準通知の送信実装が見つかった3本にB32を適用した。バックアップ・生成物は対象外。

| アプリ | 用途 | 設定の扱い |
| --- | --- | --- |
| FolderHopper | ファイル移動・複製・リンク作成の完了 | completionNotificationEnabledを追加。未設定は従来どおりON。通知許可は設定から明示操作で取得。 |
| QuickIconExporter | アイコン書き出しの完了 | showsCompletionNotificationを維持（既定OFF）。Finderから実行した結果もメイン画面で確認可能。効果音は独立した従来設定を維持。 |
| CCAutoUpdateOff | Creative Cloudの自動更新設定の監視 | notifyEnabledを維持（既定ON）。通知登録に失敗・拒否した結果を通知済みとして記録しない。メール設定は変更しない。 |

通知APIを使わないアプリへの一括の権限要求・通知UI追加は行わない。即時操作・編集・入力補助は画面内の結果表示を基本とする。PodiumAssistの「通知」操作は集中モードの制御であり、自アプリの通知送信とは別。長時間処理アプリへ新しく通知を追加する場合もB32に従う。この記録は他の全アプリの実機適用外判定を完了したものではない。

## 共通実装

- 許可状態とアイコン、通知ON/OFF、macOS設定への導線を日英中韓で共通化。
- 初回表示とアプリ復帰で読み直す。読み取り・通知送信では許可要求しない。
- 利用者が有効化／許可／テストを押した場合だけ許可を求める。
- macOSの画面を開くのみで、許可スイッチ・表示スタイルを自動操作しない。
- 送信直前にもユーザー設定を確認。通知登録エラーは設定画面に表示。
- アプリ内の結果表示を維持。通知登録成功は実際の表示・既読を保証しない。

## 検証

- ソース確認：送信経路からrequestAuthorizationを除去。共通の明示操作のみで要求。既存のON/OFF保存キーとBundle IDを保持。差分の空白チェック合格。
- ビルド：FolderHopper 0.2.0 (122)、QuickIconExporter 1.2.0 (40)、CCAutoUpdateOff 1.4.0 (17) が署名付きで成功。CCAutoUpdateOffはarm64/x86_64。最初のサンドボックス内ビルドはSwiftマクロ起動に失敗し、通常権限の既存ビルド経路で成功。
- 自動テスト：CCAutoUpdateOff/test.shの既存ロジックテスト全件合格。FolderHopperとQuickIconExporterの4言語チェック合格。通知許可の各状態を模擬する自動テストは未実施。
- 配布：3本ともdeploy_both.pyで旧版をShared/Backups/Buildへ保全し、/ApplicationsとDropboxのLatest Buildsへ配置。Bundle ID確認、両配置先の署名と全ファイル内容一致を再検証済み。
- 起動：/Applications/FolderHopper.app/Contents/MacOS/FolderMoverと/Applications/QuickIconExporter.app/Contents/MacOS/QuickIconExporterの新規起動プロセスを確認。
- 実機UI：画面操作ツールでtimeoutReached/noWindowsAvailableと長時間応答停止が発生。更新後の通知設定の画面・クリック、ON/OFF保存、未確認/許可/拒否、前面/背面通知、集中モード、ヘルプ表示は未確認。
- CCAutoUpdateOffの起動：未実施。ユーザーのmailEnabledがON、通知対象状態がtrue、最終メール送信日が以前の日付であり、起動検証がメール送信を誘発し得るため保留。メール送信・メール設定変更は行っていない。
- 総合：実装・ビルド・配置済み。実機検証とCCAutoUpdateOffの起動検証が残っているため、検証完了扱いにはしない。
