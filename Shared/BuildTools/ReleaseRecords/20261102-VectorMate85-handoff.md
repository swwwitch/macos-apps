# VectorMate 2.22.0（85）公証Mac向け引継ぎ

- 開発Mac：MacBook-Pro-14-2024-sw.local。2026-11-02 JST。
- 対象SHA：455cf1499e469973759111585ad3fdf0cbeb36f9
- GitHub：swwwitch/macos-apps、ブランチ codex/vectorassist-build-20261101。
- 版：通常版2.22.0、build85。Bundle ID jp.dtp-transit.vectormate。番号を再度増やさず、82や84へ戻さない。
- 元チャット：VectorAssist（01a1928e-065c-7691-ba82-23a16398667c）。
- 公証担当候補：既存「macOSアプリのリリース作業」（01a16bb3-a7cc-76c1-b27f-c7ab19a4f8da、remote-control:env_e_6ac05aff10f88330a7affbabf4b86f99）。担当実機名と重複作業は着手時に再確認。現段階では依頼未送信。

## ソース・検証

アピアランスf11038f2を、正負反転確認済みdfa27d5eの系統へ統合。49項目・アピアランスタブ／パレット・裁ち落とし・同梱openpath.aiとstrokeRound1pt.aia・⌃−正負反転・パレット設定統合を含む。

単体・4言語・49項目／生成88スクリプトの構文・初期⌃−非重複・Universal・開発用既存署名の検証済み。開発Macで85を起動、アピアランス一覧と保存済み設定、⌃−／アピアランス⌃Aの保存を確認。85のAX権限は未許可表示のため実適用・実キー・文字入力中抑止は未確認。84の正負反転および移植元82のオープンパス／裁ち落としのユーザー確認と、85の確認は区別する。

詳細：VectorMate/Tests/BUILD-NOTES-20261102-integration.md、開発検証用マニフェスト：VectorMate/Tests/BUILD-MANIFEST-20261102-integration.json。開発用.appを配布物として流用しない。

## 工程3〜12（すべて未実施）

3. 正本~/Git/macos-appsで未コミット・未追跡変更を復元可能に保全。fetchして対象SHAを取り込み、SHA・版・build・Bundle IDを照合。Dropbox旧ソースで作業しない。
4. Developer ID Application秘密鍵を確認。VectorMate/build.shの配布前経路はSKIP_DEPLOY=1 VECTORMATE_DISTRIBUTION=developer-id。Hardened Runtime・タイムスタンプ・Apple Events entitlement、内側からの署名を確認。鍵がなければ中止し代替署名しない。公証Accepted・staple・codesign・Gatekeeperを検証。
5. 公証済み.appからDMGを作成。DMGも署名・公証・staple。読取専用マウントで内包物のSHA・版・build・署名・公証を検証。
6. 既存Bundle ID確認、ワークスペースに旧版をバックアップ、処理・設定を保持して/Applicationsとdistribution_paths.pyが解決するLatest Buildsへ同一成果物を配置。両配置の内容・署名・版/build一致と/Applications版の変更機能・設定保持を確認。
7. 公証済みDMGのLatest／Archive整理、一覧・SHA256SUMS・アプリマニフェストと全検証証跡を保存。同名異内容は上書きしない。
8. GitHub Releaseを対象ソース・版・build・DMGに結び付けて公開。個別swwwitch/VectorMateの既存構成と履歴を保持して同期。
9. 既存GitHub Projects項目を検索・更新し、重複作成しない。
10. 既存公開note記事 https://note.com/dtp_tranist/n/n8554a434e90a を更新。本文・画像・タグ保持、最新版の版/build・更新内容・公証済みDMG・Releaseリンクは既存の下部ダウンロード節に集約。見出し画像は共通テンプレート。下書き指定・他の同時編集を尊重。
11. GitHub／noteの公開表示・リンク・タグを確認し、実際のダウンロードSHA-256とDMG内の版/build・署名・公証を再照合。
12. 既存Unicodeファイル名のアプリのバージョン一覧.mdを更新。開発Macインストール・公証Macインストール・Latest Builds・GitHub公開版を区別。工程6・8の確認値は途中更新可。全工程を確認するまでは全体完了にしない。

成功／未実施／ブロック中、実行Mac・日時・根拠・バックアップ先を工程別に記録。前提失敗時は後続の配置・公開を止める。ソース修正が必要ならcommit・pushし、新しいSHAを記録。公証結果・配置・公開の完了を推測で埋めない。
