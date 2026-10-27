# VectorKeys 1.5.0（build 7）通常配布（2026-10-27 JST）

- ユーザーが今回このMacでの版・build確定、公証、両配置先への更新を明示承認。
- ソース：`ea64d78f49e2d715765b4ce1cf3677810cdd7205`（基点bbca047のスクリプト専用化）。GitHub mainへpush後に同じ確定ソースを再ビルド。担当：公証Mac MacBookPro13-M5-2025.local、本チャット。
- メニューコマンドの追加・選択・実行と専用AX設定を削除。旧メニュー手順は保存互換のため保持し、項目全体の実行とキー登録を停止。KM混在マクロも全体をスキップ。
- ビルド・Developer ID/Hardened Runtime/タイムスタンプ署名・署名検証成功。既存test.sh（単体・旧形式データ往復・キー非登録・KM混在除外・Runner事前拒否・4言語キー/プレースホルダー/ヘルプ）成功。
- Apple公証：Accepted。submission ID `caeb9321-da24-4c4e-b358-92ea04d0ac50`。staple・stapler validate・GatekeeperのNotarized Developer ID確認済み。
- /Applications/VectorKeys.appとDropbox Latest Builds/VectorKeys.appへ同じ公証済み成果物を配置。両方のBundle ID・1.5.0/7・署名・全内容・実行権限・symlink一致を最終確認。/Applications版を起動してプロセス確認。更新前に起動していたため起動状態を復元。
- 旧版1.4.0（6）は両方ともワークスペース内へバックアップ。設定の配置前後スナップショットに差分なし。
- このMacに保存済みScripts.jsonはなく、旧データ互換性は合成データで検証。実キー入力・Illustratorでの実際のスクリプト実行・全機能UI・Intel実機・GitHub Release/note更新・DMG作成は未実施。

成果物と検証詳細：`Shared/ReleasePreparation/20261027-VectorKeys-1.5.0-build7/`。

- 提出ZIP SHA-256：`ec33e4d44628bb19edabea07ba432163c3efab12d1793217f9a2e76410ba4ee8`（公証提出用ZIP。配置した.appはstaple後）
- 配置.appマニフェスト SHA-256：`2b16dd4cce2df4fde91789a6510118057331233301a195c9795d631a5f808b99`
- バックアップ：`Shared/Backups/Build/20261027-140155-623079/Applications|LatestBuilds/VectorKeys.app`。
- 最終照合：2026-10-27T14:02:38.765534+09:00。
