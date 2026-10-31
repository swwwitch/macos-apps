# InputMaestro 0.1.0（1）開発検証

- 2026-11-01 JST、開発Mac MacBook-Pro-14-2024-sw.local、macOS 26.7.1（25G241）、arm64。
- 入力SHA：9068227c96152f37521313108259c886670d5fc6、ブランチmain。確定SHAはGit履歴とRELEASE-QUEUE.mdの後続記録を参照。
- 通常版0.1.0（1）、Bundle ID `jp.dtp-transit.inputmaestro`。既存3アプリとは別の設定領域。
- `NO_DEPLOY=1 SKIP_PUBLISH=1 REGENERATE_ICON=1 InputMaestro/build.sh` 成功。配布処理を含まない開発用ビルド経路。
- 成果物：`InputMaestro/InputMaestro.app`、arm64。Universalビルドは未実施。
- 実行ファイルSHA-256：`57b040632f11ffe6dc0559b4e513acbe9851493dd44a0bed99b1f40794c276bd`。
- 署名：Apple Distribution: masahiro takano、TeamIdentifier PL9S9PXX96。キーチェーンへアクセス可能な環境で `codesign --verify --deep --strict` PASS。Developer ID署名・公証済み配布物ではない。
- マニフェスト：`InputMaestro/build/InputMaestro-0.1.0-1-manifest.json`。各通常ファイルの相対パス・権限・SHA-256、シンボリックリンク先を記録。
- `Tests/run.sh` PASS：186キー×4言語・形式指定一致、識別子から作る69キー、編集キーの一致・アプリ別判定・トリガー・段落範囲、32テンキー変換、単一タップの統合順序・トリガー先行解除・生成イベントの再変換防止・無効時の通過、OCR整形。
- Vision実認識テストPASS：テスト用に描画した `InputMaestro 12345` を認識。他アプリや利用者の画面はテスト入力に使っていない。
- 最終ビルドを起動し、メイン画面0.1.0（1）を確認。途中のビルドで文字認識タブ・整形設定・未設定ホットキー・権限案内、FnNumpad実行中の停止表示を確認。
- アクセシビリティと画面収録は未許可のまま。実キーによる外部アプリ編集・範囲選択OCR・権限変更後の動作は未確認。
- 設定画面への操作を試みたが取得状態はメイン画面のままであり、設定画面の実表示・⌘,・⌘Wを確認済みとしない。ログイン起動、設定の同期往復、スリープ復帰、二重起動も未確認。
- 同梱ヘルプ・メニュー・共通設定はソース移植済み。専用note記事未作成。更新配信未設定で通信なし。
- 既存共有ソースの未使用変数・Swift 6 actor分離に関する警告あり。共有ソースは変更していない。
- 公証、Developer ID署名、DMG、/Applications、Latest Buildsへの配置、GitHub Release、note公開、公証担当Macへの引き継ぎ実行は未実施。
- 同時進行中のFolderHopper・MarkdownKitchen・ShotSorter等の作業ツリー変更は保持。ShotSorterは文字認識エンジンと整形の既存ソースを参照コピーしただけで、このチャットでは変更していない。
