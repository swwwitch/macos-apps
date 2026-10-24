# 2.19.2 リリース前確認（2026-10-24）

- `./test.sh`：All tests passed／Resources OK。
- `SKIP_DEPLOY=1 ./build.sh`：arm64・x86_64ビルド、署名とdeep/strict検証成功。共通StartupWindowの既存の未使用変数警告が残る。
- 既存版をバックアップし、/ApplicationsとLatest Buildsへ同じ成果物を配置。Bundle ID・2.19.2（79）・署名・内容一致を確認。
- /Applications版の起動を確認。UIツールの接続切断により、設定・ヘルプ操作、VectorMateからのIllustratorセット切り替えは未確認。
- Developer ID署名・公証・DMG・更新配信は今回の対象外。実機検証を完了したリリースとはしない。

ソース確認：グリッドカラーとセット選択でAX要素の座標取得・クリック処理を共通化。
