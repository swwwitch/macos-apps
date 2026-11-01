# VectorMate 2.21.0（83）正負反転・検証用

- 開発Mac MacBook-Pro-14-2024-sw.local、2026-11-01 JST。入力23358bc、ブランチcodex/vectorassist-build-20261101、対象SHAは本記録を含む確定コミット。
- ⌥−でIllustratorの編集可能な数値欄の正負反転。AXValue／AXSelectedTextRangeから選択範囲、未選択時は欄全体を対象にする。クリップボードや切り取りは使用しない。
- 正負、小数、単位、前後空白、ゼロ不変、非数値・式・複数行・不正範囲の拒否を単体テストで確認。既存単体・4言語リソース検証PASS。
- 前面Illustrator、対象外アプリ、フォーカス・原文・選択範囲、AX書込み対応を確認し、成功したキーだけ消費。ゼロは変更せず消費。非対応欄・他アプリでは標準キーへ通す。
- 共通HotkeyFieldによる変更・解除・同アプリのキー重複拒否。Shared/ExcludedAppsによる除外設定。日英中韓ヘルプ・説明更新。
- SKIP_DEPLOY=1 zsh VectorMate/build.sh成功。arm64/x86_64 Universal、既存証明書Team PL9S9PXX96で署名、codesign --verify --deep --strict PASS。
- 通常の制限付き実行ではSwiftUIマクロ補助が停止したため、許可された環境で既存ビルドを実行。共通部品の既存Swift 6分離警告あり。
- 今回は検証用ビルド作成まで。起動・実キー・Illustrator実適用・Undo・失敗時のキー通過・KMとの競合・権限復帰・除外設定UIは未確認。既存の同キーKMマクロを変更・無効化していない。
- 権限要求・変更なし。公証・配布・/Applications・Dropbox配置・公開なし。
- アプリ：VectorMate/build/VectorMate.app。ファイルの相対パス・実行権限・SHA-256・シンボリックリンクはBUILD-MANIFEST-20261101-sign.json。
