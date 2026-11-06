# TermTally 1.1.0（2）検証記録 — 2026-11-07

- 開発Mac：MacBook-Pro-14-2024-sw.local。ブランチcodex/filesorter-screenshot-rename-20261101。基点76871f40b5a377f9d648b2bc7ddc8a3c52a58c4a。対象ソースSHAは本記録を含むコミット。
- test.sh：検索・辞書テストPASS、4言語キー・プレースホルダー・ヘルプPASS。
- NO_DEPLOY=1 build.sh：成功、証明書署名・deep/strict検証成功。初回のsandbox内コンパイルはSwiftUI macroで失敗、許可済みのsandbox外ビルドで成功。
- CUA：workspaceの1.1.0（2）起動、主見出し、対象のアプリ、折りたたみ説明、語句欄内×を確認。左スプリッタの幅298→230を確認。右スプリッタは操作競合検知で確認中止、実マウスドラッグ完走は未確認。
- AXIsProcessTrustedは現検証版でfalse（上部の未許可案内を確認）。古い下部noteを消す修正は実装済みだが、許可後の実機復帰と文書読み取り・先頭候補選択・同一文字置換のUI確認は未完了。許可は自動変更していない。
- note URL：Info.plistを指定URLへ更新。記事そのものは変更していない。
- 旧workspaceビルドはbuild.shでBackupsへ保全。通常終了後に更新版を起動。/Applications・Latest Buildsは未変更、公証・公開なし。
- マニフェストと署名詳細はBUILD2-MANIFEST.json、BUILD2-SIGNATURE.txt。
- 既存未コミットのShared/SettingsSync/SettingsSync.swiftを参照してビルドした（showsNotes既定trueの変更）。他作業の変更として保持・コミット対象外。配布前には共通部品を含む確定ソースから再ビルドすること。
