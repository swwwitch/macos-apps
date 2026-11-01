# スクリプトに渡す値：3欄の実装

2026-11-01、日本時間。開発Mac MacBook-Pro-14-2024-sw.local。
既存作業に追加し、引数3欄のみ実装。版・buildを変更せず、workspaceアプリ33を置換しない。

- StepsEditor：アクションのコンポーネント呼出しごとに見出しと値1／2／3。4言語対応。
- ScriptEntry.componentArguments：呼出し位置ごとの文字列配列。未設定の旧データはnilで互換。空欄の位置を保持し全欄空なら引数なし。同じ参照を複数回呼ぶ場合の値は独立。
- AppModel.setInvocationValue：既存Undo・保存経路を利用。Libraryの参照並べ替え／解除で値も移動／削除。共有Component定義は変更しない。
- ScriptText／ScriptRunner：ファイルと直書きの両方にAppleScriptのwith argumentsで渡す。コード置換なし。数値の変換は呼び出されるスクリプト側で行う。
- test.sh全PASS。新規ケース：位置付き空欄、同一参照の異なる値、並べ替え・解除、保存再読込、StoreのUndo／Redo相当スナップショット復元、全欄消去、旧引数なし、引用符・バックスラッシュ・日本語・改行のAppleScriptリスト構文実行（Illustratorは操作しない）。4言語のキーとプレースホルダー一致。
- 既存ビルド経路のコンパイル工程だけを/private/tmpへ実行しUIを含む全体を検証。公証・配布・既存アプリ置換なし。
- Illustratorでarguments[0]〜[2]を受け取るファイル／コードの実行と実UI操作は未確認。次回ビルド更新時に確認。
