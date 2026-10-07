# ExtensionLinkerへの名称変更

ExtLink → ExtensionLinker。開発フォルダ、表示名、配布名、現行ヘルプ・翻訳・共通ツールを更新。Bundle ID local.takano.DutiGUI、SwiftPM内部ターゲットDutiGUI、UserDefaultsキーは維持。過去のログ・バックアップ・配布物の旧名は履歴として保持。GitHubのswwwitch/macos-appsも名称変更を反映済み（ed310aa）。公開ソースの名称変更後に既存テスト18件が成功。ローカル現行ビルドは0.2.11 build 23。

## 確認結果と残作業

- /ApplicationsとLatest BuildsのExtensionLinker.appは同一内容。両方の署名を検証。
- note n21440ebdaa0eの公開タイトルと現行本文の名称変更をSafariで確認。旧版DMGリンクは保持。
- 新DMGはShared/NoteDrafts/ExtensionLinker-release/ExtensionLinker-0.2.11-build23-arm64.dmg。hdiutil verify成功。note末尾に添付し、更新成功表示を確認。
- 公開添付URL: https://note.com/api/v2/attachments/download/9137d5685028baa737351a6bc9309893 。公開ファイルをダウンロードし、ローカルDMGとSHA256一致（7b01323b21afdb935e25f226da0ab105db011c8a8bd5423258c28cebe5829f67）。
- 公開設定にMac、macOS、アプリ開発、作業効率化、ExtensionLinker、拡張子を登録し、更新成功を確認。保存後の設定画面再読戻しは未確認。
- Shared/NoteHeaders/KageTrimmer-template/ExtensionLinker.pngは1280×670。記事編集画面の画像が共通フォーマットのExtensionLinker表示であることを確認。
- /Applications/ExtensionLinker.appの起動、メイン画面の既存23種類、環境設定の起動時非表示項目（OFF）を確認。実行プロセスのパスも/Applicationsからの起動と確認。非表示ON時の起動・再表示は未確認。
- GitHubリンク前後の文字としての<u>と</u>は残る。局所選択の削除が別位置へ作用したため直ちに取り消し、本文の復元を確認。本文全置換は自動承認レビューが添付・書式喪失の懸念で拒否。最新版を含む3件の配布URLを保持した修正について明示承認を質問中。回答前には実行しない。
- KakkoReplaceの欠落していた見出し画像を共通テンプレートで復元し更新成功を確認。他記事の画像統一は未完了。SafariのRaise操作とスクロールバー値設定で先頭表示は復旧。CommandDeeの画像削除ボタンはAX・座標クリック後も変化せず、画像の差し替えは未実施。本文・画像は保持。
