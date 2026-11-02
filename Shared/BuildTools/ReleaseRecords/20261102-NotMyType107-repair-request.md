# NotMyType107 修正依頼

- ユーザーの明示依頼により開発チャット「NotMyType（フォント管理）」01a17147-6826-7911-8e42-cc45a77f2dafへ送信成功。
- 候補a3d75c6bcbbf3b311323ebfa31f51f354aeae650が、配布106のf2862bb9fbf17dec11495ad6547cb985616e77afにある評価しきい値を欠く問題。★★★は3/4/5、未評価は0、表示対象と数字キー操作対象の一致、日英ヘルプ・以上表示・回帰テストを復元する。版buildを重複して増やさず専用ブランチで検証・commit/pushを依頼。
- 開発側から修正としきい値・数字キー対象・既存回帰テスト成功、配布前ビルド進行中を確認。確定SHAは未受領。公証Macの106を保持。
- VectorMateは修正済み2.22.1（86）、54b4e675bd03b806ee2b23d144646c52d2ddd7f5。別の既存公証チャット「macOSアプリのリリース作業」01a16bb3-a7cc-76c1-b27f-c7ab19a4f8daが公証担当として着手。こちらは二重ビルドせず監視する。
- 公証・Latest更新は依頼送信や開発テスト完了と区別する。

記録日時: 2026-11-02T06:24:51.449943+09:00
実行Mac: MacBookPro13-M5-2025.local

## 修正確定・公証・Latest更新結果
{
  "at": "2026-11-02T06:30:55.681865+09:00",
  "VectorMate86": {
    "status": "app notarization and both installations verified",
    "source": "54b4e675bd03b806ee2b23d144646c52d2ddd7f5",
    "owner_thread": "01a16bb3-a7cc-76c1-b27f-c7ab19a4f8da",
    "feature_QA": "awaiting user sign inversion / appearance application / palette settings confirmation",
    "latest_dmg": "still84; owner must update after QA"
  },
  "NotMyType107": {
    "status": "fixed, notarized, deployed, rating UI QA and settings/library preservation passed",
    "source": "5efcd7b0e0c6fcaeaf31d00eeaed47f6888044c7",
    "evidence": "/Users/takano/Git/macos-apps/Shared/ReleasePreparation/NotMyType107-20261102-062524"
  },
  "Latest_SHA256SUMS": "all current entries verified"
}
