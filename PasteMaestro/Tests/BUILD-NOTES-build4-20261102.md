# PasteMaestro 1.2.0（4）コンパクト画面・行並べ替え

- 2026-11-02 JST、開発Mac MacBook-Pro-14-2024-sw.local。codex/pastemaestro-integration-20261101、基点06d61f52f9e732f25b13290943eb8e6addc68771。実装対象SHA：5147d0044fbb0340ebecf322bc675cad8410538e。
- 主画面：初期440×560pt、最小420×500pt。旧サイズから一度だけコンパクトな寸法へ移行し、保存位置と他設定を保持。タイトル「貼り付け」、上下ホットキー欄、現在値↓次の値のプレビュー。パレット／設定の幅は保持。
- パレット：本文のドラッグで行の前へ挿入、末尾領域へドロップ、選択＋上下ボタン。並べ替え後は先頭から実行。追加行は最初の★の前へ、★なしは末尾。新規行の順序、既存行の選択IDと★状態を保持。
- SlotQueue.swiftに純粋な行管理を分離。行IDで重複本文を区別し、選択・消費対象を識別。やり直しは同一セッションの手動変更済み順序と各行の★を復元。コピー待ち／貼り付け待ち／復元中はモデルから並べ替えを拒否。
- NO_DEPLOY=1 SKIP_PUBLISH=1 build.sh成功。Apple Distribution（PL9S9PXX96）証明書署名、deep/strict検証PASS。arm64開発用、最低macOS13。既存の共通actor／未使用変数警告あり。
- test.sh PASS：増加規則、行整形、メニュー名、排他8チェック・0.2秒間隔5連続、SlotQueue（★前のブロック挿入、重複ID、手動移動、先頭からの実行、履歴復元、保持、古いIDの移動拒否）、4言語の全4テーブルのキー・書式指定子。
- 成果物：専用worktreeのPasteMaestro/PasteMaestro.app。全ファイルのパス・モード・SHA-256とsymlink先はAPP-MANIFEST-build4-20261102.json。
- 今回は作成依頼のため、起動中の旧版の終了・通常workspace版の置換は行わない。新ビルドの起動・実機UI・ドラッグ・狭い幅の欠け・他アプリ貼り付け・権限継承は未確認。
- Universal、Developer ID配布署名、公証、DMG、/Applications／Dropboxへの配置、公開は未実施。

マニフェストSHA-256：fea9ed6a345bc21fc77f42dedd275feb9aa8c15c32be656c7f0f50d3288e09ce
