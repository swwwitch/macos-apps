# PasteMaestro 1.0.0（1）開発用ビルド検証

- 日時：2026-11-01 JST、開発担当 MacBook-Pro-14-2024-sw.local。
- ブランチ：main。基点：9068227c96152f37521313108259c886670d5fc6。対象SHA：本記録を含む実装コミット（確定後キューへ実SHAを追記）。
- macOS 26.7.1（25G241）、arm64、最低macOS 13。Universalは未作成。
- 成果物：PasteMaestro/PasteMaestro.app。Bundle ID：jp.dtp-transit.pastemaestro。
- 実行：NO_DEPLOY=1 SKIP_PUBLISH=1 ./PasteMaestro/build.sh。通常の制限内ではSwiftマクロの実行制限が発生したため、ビルドは許可された環境で実行。
- Apple Distribution: masahiro takano（PL9S9PXX96）証明書署名。Sparkleも同じ証明書。codesign --verify --deep --strict PASS（制限内ではCSSMERR_TP_NOT_TRUSTEDとなるが、キーチェーンへアクセス可能な許可環境で検証PASS）。配布用Developer ID署名・公証とは異なる。
- ビルド警告：共通AccessibilityPermission.swiftのactor境界とStartupWindow.swiftの未使用変数。Swift 6厳格モードへの対応は今回未実施。
- ./PasteMaestro/test.sh：増加規則、行整形、メニュー名、設定保存、排他トークン8チェック、4テーブル×4言語のキー・書式指定子一致PASS。
- アプリ全ファイルの相対パス／モード／SHA-256とsymlink先：Tests/APP-MANIFEST-20261101.json。マニフェストSHA-256：75cc5d773c27c9e6f5166d8c081ecca3cb5ad1a19482c1266c6d5e444351132b。

## 実機確認

- ワークスペース版の起動、3モード切替、機能プレビュー、設定表示、連番設定タブ、ヘルプメニューから統合版本文が開くことを確認。
- 既存アプリ起動中の停止メッセージを確認。既存アプリの終了や設定変更は行っていない。
- 機能ホットキー初期OFF、呼び出しキー未設定、ログインOFF、アクセシビリティ未許可を設定画面で確認。権限は付与していない。
- 設定を閉じるボタンとアプリメニューからの終了を確認し、最終ビルドを再起動。メニューバー追加案内は「あとで」で閉じ、選択を確定していない。
- ⌘,／⌘Wの自動キー操作は表示変化を確認できなかったため実キー未確認。ソース／メニューに標準項目あり。
- 他アプリへの実貼り付け、フォーカス切替、ホットキー登録・重複・素通し、権限付与後、ログイン・Dock全条件・設定共有往復・スリープ復帰・負荷は未確認。

## 配布状況

公証・DMG・/Applications・Dropbox Latest Buildsへの配置・GitHub Release・note記事・公開ダウンロード検証・配布版一覧更新は未実施。更新配信URL／公開鍵は未設定。開発用ビルドを公証済み配布物として扱わない。
