# VectorMate 2.20.0（82）検証用ビルド

- 2026-11-01 JST、開発Mac MacBook-Pro-14-2024-sw.local。
- ユーザーのVectorAssist要望3件に対応。現行正式名VectorMate、Bundle ID jp.dtp-transit.vectormateを保持。
- ブランチcodex/vectorassist-build-20261101、入力dc5b94c、対象SHAは本記録を含む確定コミット。
- 他アプリへ切り替えた際に3種類のパレットをorderOutし、Illustrator復帰時に復元。自アプリのパレット操作中は保持。閉じたパレットは復元対象外。
- 基本・詳細とも増減量を適用し、詳細のみドキュメント設定を追加。設定見出しと4言語説明を更新。
- 既存test.sh（単体・4言語）PASS。SKIP_DEPLOY=1の既存ビルド経路でUniversalビルド・既存証明書署名・codesign deep/strict検証PASS。
- 検証用.appの起動、主画面の2.20.0（82）、設定の「増減量」と新しい説明、保存済みセット値の保持をAXで確認。
- 検証用.appはアクセシビリティ未許可と表示。許可は変更していない。Illustratorでの実適用・3パレットの切替往復・全機能回帰は未確認。
- 公証・/Applications・Dropbox配置・DMG・公開なし。既存共通部品のSwift 6分離警告あり（Swift 5ビルド成功）。
