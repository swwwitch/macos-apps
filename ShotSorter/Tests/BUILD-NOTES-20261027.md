# ShotSorter 1.1.0（build 3）通常版・開発検証

- 作業日：2026-10-27（Asia/Tokyo）。開発Mac：MacBook-Pro-14-2024-sw。ブランチmain、入力SHA `95f484d41ab09f61329144924f534d11633ca38e`。
- ユーザー「gitを更新してビルド」により今回の受付分に着手。開発用成果物：`ShotSorter/build/ShotSorter.app`（arm64 / macOS 13以降）。
- `test.sh` PASS：命名、衝突回避、空白・括弧整形の全ON/OFF、LF/CRLF保持、旧単一フォルダー移行、空一覧の保存、重複パス排除、4言語のキー・プレースホルダー整合とヘルプ。
- `test-engine.sh` PASS：実ファイルを使い、2つの監視先で同名画像を処理、起動前ファイル維持、自分の改名による再処理なし、監視OFFで手動ドロップ経路、入力重複防止、同名番号付与を検証。Visionで2行の文字を認識し、改行を含むクリップボードと画面用結果の一致を検証。クリップボードとテスト用設定を復元。一時ファイルを削除。
- `NO_DEPLOY=1 SHOTSORTER_SIGNING_IDENTITY=- ./ShotSorter/build.sh` 成功。ローカル検証用ad-hoc署名、`codesign --verify --deep --strict` PASS。Developer ID署名・公証の成功ではない。更新配信先は未設定。
- 実行ファイルSHA-256：`65187085ecb771b3862059e2506db32ef277d198f13a20702bbd774c9ec5b576`。全ファイルの相対パス・実行権限・ハッシュ・リンク先は `.local/ShotSorter/20261027/build-manifest.json` に記録。
- 未確認：GUI上でのドラッグ操作、設定画面操作、Finderコメント書き込み、範囲選択とグローバルホットキーの実機操作、ログイン起動・終了などの今回の再検証。
- 未実施：公証MacでのDeveloper ID署名・公証・配布。開発担当のルールにより `/Applications` とLatest Buildsは更新していない。既存両配置先のplistは1.0.1（今回の内容一致・公証の確認ではない）。バージョン一覧は配布担当の工程で更新する。
- 共通部品の既存警告（StartupWindowの未使用変数、AccessibilityPermissionのSwift 6分離警告）は継続。ShotSorterのビルドエラーなし。

- GitHub反映済みの実装対象SHA：`93c589df4d5cc5121f00f984fddcaff0a13732e4`。この後の記録のみのコミットでも製品ソース・版・buildは同じ。
