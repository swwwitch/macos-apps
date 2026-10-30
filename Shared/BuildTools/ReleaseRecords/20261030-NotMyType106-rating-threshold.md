# NotMyType 1.63.3（106）評価フィルター修正版 公開記録

実行Mac: MacBookPro13-M5-2025.local（公証Mac）
確認日時: 2026-10-30T10:28:22.755255+09:00
対象ソース: `f2862bb9fbf17dec11495ad6547cb985616e77af`

ユーザーがccef808・106を指定し、同番号の異なる内容を旧成果物と区別して配布する例外指示を確認。その後「★★★なら★★★★・★★★★★も含む」と修正指示。番号は106を保持、修正ソースをcommit/pushして確定。以前の同番号アプリはバックアップ、DMGはArchive、GitHubは新タグで識別。

## 成功

- RatingFilter.matchesを表示と数字キー対象で共有。すべて、未評価0、1〜5の全閾値、3→3/4/5の回帰テスト成功。日英表示・ヘルプ、既存の段落描画/行間/paltテスト成功。
- 既存Universalビルド（arm64/x86_64）、確定コミットのgit archive。既存ビルドスクリプトのHotkeyRecorder同期は同コミットのSharedを使用。フォントDB入力のSHAはinput-db.json、説明文除去を確認。
- Developer ID Application・Hardened Runtime・timestamp、アプリAccepted `3bfb9dc2-9484-437f-9967-e584bb813497`、DMG Accepted `863f5c39-0bba-427c-a8a7-f5345387e8ee`。stapler・Gatekeeper・hdiutil・読み取り専用内包マニフェスト/署名/チケット検証。
- 両配布先の署名・公証・全内容一致、/Applications起動。実画面で★★★以上に3・5のカードが同時表示。全閾値は回帰テストで検証。検証用YABAKO評価は解除、元からのAXIS評価は保持。
- 設定・ローカル/共有ライブラリのバックアップは前回候補のUserDataBefore。セット3件・プロジェクト2件・お気に入り保持。再スキャンで不在パス1993件が一覧から外れ、departed件数が1993増加。ユーザーの現在のライブラリを古い全体データで上書きしない。
- [GitHub Release](https://github.com/swwwitch/macos-apps/releases/tag/NotMyType-v1.63.3-build106-f2862bb)を公開。タグSHA一致、実DLのSHA・内包版/ID/署名/公証・全内容一致成功。
- [note](https://note.com/dtp_tranist/n/nae1b0044d8e0)はChromeで下部の既存プロ版ダウンロード欄を更新。本文の同欄前までのテキストと画像を比較し保持。300円、有料境界、タグ8件、旧添付保持。ユーザー承認により購入者通知なし。公開側DMGの実DL・SHA・内包版/ID/署名/公証・全内容一致成功。
- Notarized DMGs/Latestは1本、過去版はArchive/NotMyTypeに保全、SHA256SUMSを更新。既存Unicode表記のバージョン一覧を更新。
- GitHub Projects既存項目281768753を更新（重複作成なし）。後述の未確認を保持。

## 未確認・対象外

- 全機能の実キー/ユーザー確認、Intel実機、実ログイン、自動更新配信、開発Macの現物インストール版は未確認。数字1〜5・ハートのユーザー回答は正常確認として受け取っていない。今回の変更は評価閾値で、その実表示を操作ツールで確認。
- App Store/Lite変更・提出は対象外。

最終DMG: `NotMyType-1.63.3-build106-f2862bb-notarized.dmg`
SHA256: `b006f254a0f9afc9b0f69d8fee12bcced162e3e314208d4a539bf7bf28938a25`
証跡: `/Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261030-NotMyType106-threshold-101826`。verification.json / release-results.json / input-db.json / note-editor-before/after.json / note-public-download.dmg / GitHub-download.dmg / threshold-ui-proof.png / note-public-proof.png。
最終配置の旧版バックアップ: Shared/Backups/Build内の20261030-10*（Applications/LatestBuilds/NotMyType.app）。
