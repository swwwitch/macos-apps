# VectorKeys 1.9.1 (18)

- 開発担当: MacBook-Pro-14-2024-sw.local / main / 基点64250c0。15〜18の検証用変更を統合。
- ファイル手順にQuick Look、Finder表示、ソースを開くボタン。Quick LookはQuartzのQLPreviewPanel、元ファイルは変更しない。ソースは既知の.txt用エディタかTextEditへ明示的に開き、実行用関連付けを使わない。不在ファイルは無効、jsxbinのソース編集は無効。
- ホットキー・解除・1回/2回の選択を一行へ。押し方は視覚ラベル非表示、アクセシビリティ名は保持。詳細最小幅450。
- SCRIPT_NAME/VERSION/AUTHOR/RELEASED/UPDATED/README_JA/README_EN/ARTICLE_URLのvar/let/const文字列リテラルを読取。コメント・引用文字列内のコード例・計算式を除外。SCRIPTMETAを優先して変数で補完。READMEは日本語ならJA、それ以外EN、なければ他方。リンクはhttp/httpsのみ。
- test.sh PASS。ユーザーの8変数例・JA/EN選択・初回公開/更新日の分離・タグ優先・コメント/引用コード除外・計算式除外・Unicode/引用符エスケープを検証。既存回帰・4言語のキー/プレースホルダーも合格。
- build.sh成功、署名deep/strict検証合格。
- 実機: 17でホットキー一行化と押し方ラベル非表示、InsertNewTextJの名前・版・作者・noteリンク・日本語README・2025-04-01初回公開・2026-10-04更新日を確認。18でJSXのQuick Lookソース全文表示、閉じた後の詳細復帰を確認。
- 未確認: Finderボタンの最終選択結果、ソースエディタの最終ドキュメント表示（エディタ起動まで確認）、外部URLリンク遷移、多言語・狭幅の全画面操作。公証・配置・公開・GitHub push未実施。
