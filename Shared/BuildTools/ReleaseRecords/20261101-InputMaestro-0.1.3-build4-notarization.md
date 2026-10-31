# InputMaestro 0.1.3（build 4）公証・配置の途中記録

- 確認日時：2026-11-01 02:23:07 JST
- 実行Mac：MacBookPro13-M5-2025（公証担当）。開発Macはこの作業で未接続。
- 取得ブランチ：codex/inputmaestro-integration-20261101。
- 対象GitHub SHA：5d1750f6b147a927d55a816c121e22b531469998。実装確定SHA：5494a2ab510ef4caff1dab917b1eb5d2cc93b1c2。後続コミットは検証記録のみ。
- Bundle ID：jp.dtp-transit.inputmaestro。通常版0.1.3（4）。番号は変更していない。
- 専用worktreeで作業。mainの既存未コミット・未追跡変更はその場で保持し、他アプリ差分を取り込み・commitしていない。main統合未実施。

| 工程 | 状態 | 根拠 |
| --- | --- | --- |
| 3 Git取得・照合 | 成功 | GitHubの対象SHAをff-onlyで取得、Info.plist照合、アプリの生成ソース差分なし |
| 4 配布ビルド・アプリ公証 | 成功 | 既存build.sh、NO_DEPLOY=1 SKIP_PUBLISH=1、Developer ID、内側から署名、runtime・timestamp、Accepted・stapler・Gatekeeper |
| 5 DMG | 成功 | Developer ID署名、Accepted、stapler、hdiutil verify、Gatekeeper、readonlyマウント内のBundle ID・版・build・全内容一致 |
| 6 配置・実機 | 一部成功／ブロック中 | 両配置先の版・署名・公証・マニフェスト一致。/Applications版の起動と画面操作成功。AX／画面収録が未許可、FnNumpad起動によるテンキー停止表示。外部アプリのキー・OCR実操作は未確認 |
| 7 DMG配布整理 | 未実施 | 工程6の完了待ち。検証済みDMGはワークスペース内に保持 |
| 8 GitHub Release | 未実施 | 工程6待ち。個別swwwitch/InputMaestroはAPIで404、既存構成は未発見。macos-appsの既存InputMaestro Releaseなし |
| 9 Projects | 未実施 | https://github.com/users/swwwitch/projects/2 のInputMaestro検索は0件。重複・新規項目を作成していない |
| 10 note | ブロック中 | 自分の記事の最新一覧に既存記事を発見できず、対象URL／新規記事の方針をユーザーへ確認中 |
| 11 公開ダウンロード検証 | 未実施 | 未公開 |
| 12 一覧・記録 | 途中更新 | 公証Mac／Latest Buildsの配置版を追記。公開版・開発Macインストール版は未確認 |

## 検証結果

- Tests/run.sh PASS。223キー×4言語、129直接参照・69生成キー、プレースホルダー整合PASS。
- arm64の既存ビルド経路。Universal／Intel実機は未実施。
- Developer ID Application: masahiro takano (PL9S9PXX96)。別署名で代替していない。
- アプリ公証ID：3ba78d6d-cbe8-4157-8023-c602822fd273。
- DMG公証ID：af800122-a58d-4802-8bfd-10cff86311b1。
- DMG SHA-256：edfd94116996de018896f9c499318455640a6beb9987eea5fd5e99bd9a355dc3。
- アプリ起動：/Applications/InputMaestro.app、0.1.3（4）表示。
- UI：全機能一時停止→OCRタブにも停止表示、個別有効値ONを維持→再開。最終状態は再開。
- UI：設定検索「段落 コピー」で3候補、段落末尾コピーを選ぶと編集キーの該当位置へ移動。設定⌘W後のメイン⌘0再表示。
- 設定は自動リセットしていない。初回メニューバー案内は「あとで」。機能の有効設定・OCR整形設定は変更していない。
- 権限スイッチは操作していない。FnNumpadを終了・設定変更していない。
- 自動アップデートのfeed未設定（ビルドログ）。実用化済みとは扱わない。

## 成果物・保全先

- 証跡・ログ・app-manifest.json・source.json・公証JSON・検証済みDMG：/Users/takano/Git/macos-apps/.local/worktrees/inputmaestro-handoff-20261101/.local/release-inputmaestro-20261101-build4
- 配置前アプリ：両配置先とも存在せず、旧アプリのバックアップは適用外。
- 設定バックアップ確認：/Users/takano/Git/macos-apps/.local/worktrees/inputmaestro-handoff-20261101/.local/release-inputmaestro-20261101-build4/Backups/preferences-before-status.txt（exported、preferences-before.plistに既存設定を保全）。
- 配置先：/Applications/InputMaestro.app および /Users/takano/sw Dropbox/takano masahiro/Dropbox-shared/sw_app-Latest Builds/InputMaestro.app。
- 全工程完了ではない。許可付与後に/Applications版で外部入力・OCR・設定保持を確認してから工程7以降を再開する。同じ版・buildを維持し、再ビルド時には成果物同一性を再検証する。

- 利用者から許可・終了完了の連絡後に/Applications版を再起動して再確認したが、この公証MacではAX・画面収録未許可の表示が継続。実プロセス確認で/Applications/FnNumpad.app（PID 1573）が存在。操作したMacの照合を依頼中。権限・終了済みとは扱わない。

- 利用者訂正：権限許可・FnNumpad終了は別のMacでの操作だった。公証Macで設定する旨の連絡を受領。実機の反映確認待ち。
- 利用者が新規note紹介記事の作成・公開を明示承認。Safariへ切り替え、本文1,918文字と共通テンプレート見出し画像の下書き保存を確認。下書きURL：https://editor.note.com/notes/nd338830e0d2e/edit/ 。未公開、DMG未添付・タグ未登録。実機確認後に公開工程を再開。

- Safari公開設定でInputMaestro・Mac・macOS・アプリ開発・作業効率化・テンキー・文字認識の7タグ、およびmacOSでの効率化／小さなMacアプリ工房の選択表示を確認。投稿せずキャンセルし、本文編集へ戻した。公開・保存後のタグ最終読み戻しは未実施。
