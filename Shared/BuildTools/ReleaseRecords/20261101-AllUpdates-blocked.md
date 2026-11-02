# 全アプリ更新照合・公証作業（2026-11-01）

実行Mac: MacBookPro13-M5-2025.local（公証Mac）
最終記録日時: 2026-11-01T02:20:31.909918+09:00
確定ソース: ed5a731aaea9661733abe8287d16b28e58d60e1b（GitHub mainから取得した隔離git archive）。
ユーザー指定範囲: 更新のある全アプリ、工程3〜12。

## 最終状態

| アプリ | ソース | 工程3 | 工程4・5 | 工程6 | 工程7・8・10・11 | 現在の両配置先 |
| --- | --- | --- | --- | --- | --- | --- |
| PodiumAssist | 3.3.19（96） | 成功 | 成功 | ブロック中：ズーム自動設定が失敗 | 未実施：前提失敗で停止 | 3.3.19（95）へ復元済み |
| VectorKeys | 1.16.0（27） | 成功 | 成功 | ブロック中：コンポーネント追加でクラッシュ | 未実施：前提失敗で停止。既存個別repoも404 | 1.11.0（20）へ復元済み |

工程9: PodiumAssistの既存Projects対象Issue1に失敗・復元・停止状態を更新、openを維持。VectorKeysは個別repoが公開API/接続済みGitHubとも404のためブロック中。項目新規作成なし。
工程12: 両配置先・ソース・公開版・未確認項目を分けて版一覧に追記。開発Macの現物版は未確認。

## 実機確認と不具合

PodiumAssist: /Applications配布版に96を表示。停止中のタイマーで開始23:00→Shift+↑23:10→Shift+↓23:00、終了23:30→Shift+↑23:40（所要40分）→Shift+↓23:30（所要30分）を確認。日付とタイマー状態を含め元の値へ戻した。プリセット5件はJSONの意味内容が一致し、設定の再シリアライズを変更と誤認しない。
［ズーム→自動設定］は「最小拡大率を変更できませんでした。」を表示して失敗。最小/最大設定は実行前後で同じ値（最大2.44421875、最小キー未設定/表示1）。システム設定のHistoryだけが変化。変更機能の実機確認が失敗したため公開停止。旧95の両配置を復元し署名・公証・内容一致・/Applications再起動を検証。podium-rollback.json参照。

VectorKeys: /Applications配布版に1.16.0（27）を表示、既存スクリプトは0件。コンポーネント管理画面を開き、JavaScriptコード追加の後にクラッシュ。クラッシュ記録はEXC_BAD_ACCESS/SIGSEGV、Thread stack size exceeded due to excessive recursion、AppModel.library.didsetの再帰とLibrary.reconcileComponents(previous:)を示す。2件のipsを本ディレクトリへ保全。旧20を両配置へ復元し、署名・公証・内容一致と/Applications再起動を検証。vector-rollback.json参照。新27を公開しない。

## 保全・証跡

- ローカル変更: local-work-before.tar.gz、local-work-manifest.json。既存migration-backupsはその場に保持。
- 新規buildの初回失敗: 共有Updater SDK準備が同時に実行されrename競合。VectorKeysのみ同じソースで再試行し成功。初回のログとrelease-results.jsonは改変せず保持、成功分はverified-release-results.json。
- 署名鍵: Developer ID Application: masahiro takano (PL9S9PXX96)、秘密鍵利用を確認。Hardened Runtime・timestamp・内側から署名、別署名で代替なし。
- 6組のPodiumAssist回帰テスト、VectorKeys単体/Runner/4言語テスト通過。テスト通過を実機動作成功とは扱わない。
- PodiumAssist旧版: Shared/Backups/Build/20261101-021704-042572/{Applications,LatestBuilds}/PodiumAssist.app
- VectorKeys旧版: Shared/Backups/Build/20261101-021711-682943/{Applications,LatestBuilds}/VectorKeys.app
- 不具合新版の配置済みコピー: RejectedDeployment/ 以下へ保全。復元元バックアップも保持。
- 個別公開ソース同期はPodiumAssist-public-repoに準備のみ。コミット/push・Release・note公開を実施していない。

## 全体照合の境界

Latest Buildsの50アプリを照合。新規確定版が配置版より新しいものは上記2本。生成Info.plistの4アプリとFolderHopperも別途照合し版/build一致。InsertSnippetsはprivateローカル版28で配置版と一致、SVGExporter/VectorMaestroは公開確定ソースの照合対象外として保持。NotMyTypeは現在のGitHub mainも1.63.3（106）で、公開済みf2862bbから実装差分なし（README/CHANGELOGのみ）。別履歴の107準備コミットを現在の確定版とは扱わない。
過去からのGitHub公開遅れもpublic-inventory.jsonに別途記録。29本の公開タグと配置版が異なり、17件は404/レート制限などで公開照合未完了。この確認だけを新規リリース成功と扱わず、既存note添付や配布物を一括再公開しない。前提となる出所・実機・公開先検証が揃っていないものは未完了。

## 公証済みだが公開停止したDMG

- PodiumAssist 3.3.19（96）: /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261101-AllUpdates/Release-004242/PodiumAssist/PodiumAssist-3.3.19-build96-notarized.dmg
  SHA-256 `ec411dfe73c526e5eaede959e968a34adc3fe415b176e31457c728b64e0cfc83`。app Accepted `7a7e1305-2a0b-466b-a91e-1d018157d487`、DMG Accepted `1c082e82-827d-495d-92ca-6b628e16ea75`。
- VectorKeys 1.16.0（27）: /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261101-AllUpdates/Release-004242/VectorKeys-Retry/VectorKeys/VectorKeys-1.16.0-build27-notarized.dmg
  SHA-256 `855214994298e6399ab240246cdd887bd51c54f2dace0eaeb28bce7d085b8aca`。app Accepted `215893d6-dd97-4e8e-8f85-db847c68e540`、DMG Accepted `3a7fda32-f66e-4a50-8d89-2f225b4f4a51`。

再開には開発側で不具合を修正し、版/buildを確定した新コミットが必要。同じ版/buildの成果物を重複更新しない。全体完了・Projects Doneにしない。


## 2026-11-01T02:35:31.822533+09:00 PodiumAssist 97 再検証
実行Mac: MacBookPro13-M5-2025.local。対象SHA: 2348ac42c446e7f7b188f53c89d8a25b6d3cbe34、3.3.19 (97)。
工程3〜5: 成功。6回帰テスト・4言語検証、Developer ID署名、アプリ/DMG公証Accepted・stapler・Gatekeeper・内包アプリ照合成功。根拠: release-results.json。
工程6: 実機確認失敗。/Applicationsの97で自動設定を2回実行し「最小拡大率を変更できませんでした。」。手動でスライダーを表示してキャンセルした後も再現。プリセット5件の意味的同一性は成功。両配置先は既存95に復元し署名/公証/内容/再起動を再検証。工程7〜12の最終公開処理: 未実施（実機失敗のため停止）。
バックアップ元: Shared/Backups/Build/20261101-021704-042572/Applications, LatestBuilds。97の退避: /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261101-AllUpdates/PodiumAssist97-022900/RejectedDeployment。記録: podium-rollback.json、ui-checks.json、zoom-preferences-comparison.json。
開発チャットへ再修正依頼済み。VectorKeysも修正待ち。公開Release/noteとNotarized DMGs/Latestは未変更。


## 2026-11-01T02:44:04.977483+09:00 PodiumAssist 98 再検証
実行Mac: MacBookPro13-M5-2025.local。対象SHA: 3c7a90b7525f4df091c56a12b9953618c8962303、3.3.19 (98)。
工程3〜5: 成功。6回帰テスト・4言語検証、Developer ID署名、アプリ/DMG公証Accepted・stapler・Gatekeeper・内包アプリ照合成功。根拠: release-results.json。
工程6: 実機確認失敗。/Applicationsの98で自動設定を1回実行し「最小拡大率を変更できませんでした。」。[reveal]で停止。AXScrollDownByPage=-25204。ログで原因を絞り99修正依頼済み。プリセット5件の意味的同一性は成功。両配置先は既存95に復元し署名/公証/内容/再起動を再検証。工程7〜12の最終公開処理: 未実施（実機失敗のため停止）。
バックアップ元: Shared/Backups/Build/20261101-021704-042572/Applications, LatestBuilds。98の退避: /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261101-AllUpdates/PodiumAssist98-023726/RejectedDeployment。記録: podium-rollback.json、ui-checks.json、zoom-preferences-comparison.json。
開発チャットへ再修正依頼済み。VectorKeysも修正待ち。公開Release/noteとNotarized DMGs/Latestは未変更。


## 2026-11-01T02:45:01.425621+09:00 VectorKeys29 retest
MacBookPro13-M5-2025.local. Source cced17500df7e29e1c5a8e523a971548fb159af0, 1.17.1 (29). Stages3-5 passed. Stage6 /Applications: code add/edit, multi-selection, batch menu registration and one-step Undo passed; previous recursion crash did not recur. Component-to-group drag registration remains unconfirmed after repeated attempts. Requested full-row hit regions and diagnostic build30 from development. All QA components/categories/groups/actions cleaned through UI; original empty library restored. Both destinations restored to signed/notarized 1.11.0(20), content equality and /Applications launch verified. Backup Shared/Backups/Build/20261101-021711-682943. Rejected29 preserved in /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261101-AllUpdates/VectorKeys29-023828/RejectedDeployment. Evidence: vector-rollback.json, ui-checks.json. Stages7-11 unperformed; individual GitHub repository404 also awaits user response. Stage12 updated provisionally; overall incomplete. PodiumAssist destinations currently3.3.19(95), public GitHub remains92; development Mac install unknown.


## 2026-11-01T02:47:12.524474+09:00 PodiumAssist99 intermediate
MacBookPro13-M5-2025.local. Source5082c0695e8b7ff054bb3205be0401fdba1e982f, 3.3.19(99). Stages3-5 passed: six regression tests, four-language check, Developer ID signing, app/DMG Accepted, stapler/Gatekeeper, readonly DMG content validation. Both /Applications and Latest Builds installed99, full contents equal, signing/notarization/launch verified. Five presets semantically preserved. Feature UI test UNCONFIRMED: Mac locked; manual unlock requested. Do not treat launch as zoom-function verification. Stage7 DMG Latest and stages8-11 publication unchanged/unperformed. GitHub public remains3.3.19(92). Development Mac installed version unknown. Backup/deployment evidence in /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261101-AllUpdates/PodiumAssist99-024316/Deployment and deployment-results.json; old95 original backup retained. VectorKeys currently installed1.11.0(20); 1.17.2(30) tests/notarization in progress, unpublished. Overall incomplete.


## 2026-11-01T02:48:41.924041+09:00 Repair handoff and release hold
Execution Mac: MacBookPro13-M5-2025.local. Both existing development chats received repair requests and returned fixed commits. PodiumAssist3.3.19(99), SHA5082c0695e8b7ff054bb3205be0401fdba1e982f: stages3-5 SUCCESS; both destinations99, signature/stapler/Gatekeeper/content equality/launch/presets5 verified. Feature UI test NOT PERFORMED because Mac locked. VectorKeys1.17.2(30), SHA516dc6f556f31faf49eb4a63e9f53b6c7003c2a5: source/tests/build/signature SUCCESS; app notarization BLOCKED: notarytool reported No Keychain password item found for profile swwwitch-notary after Mac locked. Do not infer missing signing key or replace identity. DMG/deployment/UI/publication NOT PERFORMED. Both installed VectorKeys destinations remain1.11.0(20). Earlier29 code-add/edit/multi-selection/batch-register/Undo passed, component drag unconfirmed;29 rejected copies and original20 backups preserved. No new DMG entered Notarized DMGs/Latest, no new Release/note published. Stage12 provisional versions updated, development Mac installs unknown. User asked to unlock Mac manually and to identify/authorize new VectorKeys repository because oldURL404. Overall INCOMPLETE; Projects must remain open/In Progress.
Resume exact99/30, do not increment versions on notarization Mac; revalidate source/artifact and resume saved profile after unlock, then installed feature tests before Latest DMG and publication. Source/archive/evidence/backups remain under /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261101-AllUpdates.


## 2026-11-01T04:18:36.382318+09:00 PodiumAssist99 GitHub publication
MacBookPro13-M5-2025.local: /Applications and Latest Builds both3.3.19(99), Developer ID/app notarization/content equality/launch verified, five presets preserved. Installed automatic zoom passed: min2.1599888393/max4.3200055804, saved preferences verified. Manual changes passed; original min1 restored; max2.4583377511 vs original2.44421875 (UI pointer quantization delta0.014119 within0.05 verification tolerance). One protective foreground guard refusal during overlapping external work; retry after operations complete passed. Latest DMG99 installed, previous92 archived. SHA2563c76d5e436fb2901120f97eaf2a16a53b5b6270d0cbb84b704a92f060ad4941a. GitHub Release https://github.com/swwwitch/PodiumAssist/releases/tag/v3.3.19-build99 public; exact tagSHA6e6b378006e83e43a19c5171d62e18918a3df32c, public source tree equals prepared tree. GitHub actual download hash/app contents/signature/notarization verified. note update in progress, public note download pending; overall incomplete. Developer Mac installed build unknown. VectorKeys30 app/DMG notarization and dual deployment passed after unlock; installed drag UI awaits manual user confirmation. New public VectorKeys repository expressly authorized by user.


## 2026-11-01T04:22:31.944568+09:00 Current release state

PodiumAssist3.3.19(99): /Applications, Latest Builds, Latest DMG, GitHub public and note public now99. Developer ID/app+DMG notarization/content equality/installed automatic+manual zoom/presets5 passed. Both public actual downloads match SHA256 3c76d5e436fb2901120f97eaf2a16a53b5b6270d0cbb84b704a92f060ad4941a. Release https://github.com/swwwitch/PodiumAssist/releases/tag/v3.3.19-build99; note https://note.com/swwwitch/n/n084fa4c99650. Evidence /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261101-AllUpdates/PodiumAssist99-024316. Historical/development-Mac unknowns retained; max zoom restoration delta0.014119 documented.

VectorKeys1.17.2(30): source/tests/build/signing/app+DMG notarization SUCCESS after unlock. /Applications and Latest Builds are30; launch/content/signature/notarization verified. New code-add/edit passed. Drag begins but no drop/apply observed in automation. Manual user drag requested; one harmless Release QA component remains for that check. Latest DMG/Release/note publication NOT PERFORMED pending result. New PUBLIC repository created under explicit user authorization: https://github.com/swwwitch/VectorKeys (initial README only). Source prepared locally in /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261101-AllUpdates/VectorKeys30-024701/public-repo, not pushed. Original20 backup retained; same sourceSHA/build30 will be resumed.

Development Mac installed versions NOT VERIFIED. Overall INCOMPLETE; queue/Projects not Done. Structured stage/evidence record: /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261101-AllUpdates/current-state.json.


## 2026-11-01T05:33:30.860347+09:00 VectorKeys30 installed QA passed / publication access blocked
Execution Mac MacBookPro13-M5-2025.local. User confirmed manual component drag creates one referenced action. Native pasted code persisted, exact /Applications app quit/relaunch retained it, QA data cleaned to original empty library. Both /Applications and Latest Builds remain1.17.2(30), Developer ID/notarization/content equality verified. Latest DMG30 updated with SHA2565c15b305817d239844552593b7c10a170cd3b7b8df7e2413620e1c5aa1115d82; list/checksums/Records updated. Source SHA516dc6f556f31faf49eb4a63e9f53b6c7003c2a5 unchanged. Standalone extracted-repository build passed. Public source tree547d0ff3a3ca4a8a156040ae0e98c4a66f097ddb ready locally; not pushed. GitHub new repo exists but git push403 and connector create_blob403 Resource not accessible by integration. Safari installation174439552 authentication open; user asked to add only VectorKeys while keeping existing selections. Release/note/public download stages NOT PERFORMED; article and common header ready locally. No duplicate Projects item created, overall incomplete. Development Mac installed version unknown. Preserve original20 backups. Evidence /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261101-AllUpdates/VectorKeys30-024701/NotarizationRetry.
