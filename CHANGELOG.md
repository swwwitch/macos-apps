# 変更履歴

## 2026年10月26日 — ScreenTake 1.0.1（build 2）

- アイコンをカチンコ（画面とポインタ入り）に変更。白い画面に赤い丸だけの旧アイコンが日の丸に見えたため（ユーザー指摘、3案からAを選択）。
- ビルド、両配置先の一致、/Applications 版の起動を確認。公証・DMG・公開は未実施。

## 2026年10月26日 — ScreenTake 1.0.0（build 1）

- ScreenTake を追加（画面・ウインドウ・システム音声・マイク・カメラを収録し、カット・ズーム・クリック表示・カメラのワイプを付けて MP4／MOV／GIF に書き出す。ScreenFlow の「収録＋簡易編集」に当たる範囲）。
- 収録中は画面に何も重ねず、メニューバーに経過時間と停止・一時停止を出す。開始・停止のホットキーは ⌃⌥⇧⌘6。
- ポインタは映像と別のレイヤーで記録し、編集で表示・大きさ・滑らかさ・区間ごとの非表示を変えられる。
- 自動テスト（時間計算・生成した動画からの書き出しとポインタの描画・4言語）、ビルド、両配置先の一致、/Applications 版の起動・二重起動の防止・終了・起動し直し・設定の保持を確認。ユーザーが実機で収録・停止・編集を確認。公証・DMG・公開は未実施。

## 2026年10月26日 — ControlMate 1.3.0（build 4）

- コピー系のキーを変更：行末まで選択してコピー ⌃⌘K → ⌃⌘Z、文章の末尾まで選択してコピー ⌃⌥⌘X → ⌃⌥⌘Z（⌃K はカットを表すため）。
- InDesign を対象外から外し、InDesign 用に調整：⌃A／⌃E／コピー系は InDesign 自身のキー（⇧⌘↑・⇧⌘↓・Home・End）、⌃K は IdDeleteFromCursorToEnd.jsx を実行（オートメーションの許可）、⌃X・⌃S は選択してからカット／コピー、段落の入れ替えは使えない旨を表示、⌃U・⌃M は Keyboard Maestro の InDesign 用マクロに任せる。
- アプリ別の差し替え表に「別の動き」「キーを通す」を指定できるようにした。Info.plist に NSAppleEventsUsageDescription、配布用署名に Entitlements.plist（apple-events）。
- Keyboard Maestro「InDesign：Emacキーバインド」の重なる10本（前の文字・次の文字・前の行・次の行・段落末尾・削除（次の文字）・esc・Tab・Kill・Yank）を個別にオフ（ユーザー指示）。
- 自動テスト・ビルド・両配置先の一致・起動を確認。InDesign での実機確認と公証は未実施。

## 2026年10月26日 — ControlMate 1.2.0（build 3）

- テキスト編集（拡張）に「文章の末尾まで選択してコピー」（⌃⌥⌘X）を追加。
- ⌃Z を削除。⌃K と ⌃X は同じ控え（標準のクリップボードとは別）に入り、⌃Y でペーストする。
- ⌃K・⌃Y は素通しにするアプリでも ControlMate が処理する（対象外アプリを除く）。Safari などでも ⌃X の文字を ⌃Y で貼れる。
- 自動テスト・ビルド・両配置先の一致・/Applications 版の起動とキーボード図の表示を確認。キー操作の実機確認と公証は未実施。

## 2026年10月26日 — ControlMate 1.1.0（build 2）・FnNumpad 1.1.0（build 8）

- ControlMate を追加（1.0.0 build 1、Emacs のキー操作を使えないアプリで補う）し、1.1.0 で次を変更。
  - ⌃A／⌃E を段落の先頭・末尾へ（macOS 標準と ⌃K に合わせた）。⌃⇧A／⌃⇧E で選択。
  - 設定［キー］を「カーソル移動」「キー送信」「テキスト編集」「Kill/Yank」の表にし、列を「機能」「デフォルト」「拡張（このアプリのみ）」にした。
  - メインウインドウに FnNumpad と同じ形のキーボード図（カテゴリ別の色）。
  - 「Caps Lock を常に ⌃ として扱う」を追加（初期値オフ）。
- FnNumpad：「Caps Lock を常に ⌃ として扱う」を追加（初期値オフ、テンキーに変換しないキーを ⌃ 付きで送る）。自分が送るキーに目印を付け、ほかのアプリが送ったキーには触れないようにした（ControlMate と同時に使うため）。
- 両アプリとも自動テスト・ビルド・両配置先の一致・/Applications 版の起動を確認。キー操作の実機確認は未実施（ControlMate 1.0.0 の段落の操作はテキストエディットで利用者が確認）。Developer ID署名・公証は未実施。

## 2026年10月24日 — 全アプリのDeveloper ID署名付き再ビルド

- 現在の38アプリを再ビルドし、Developer ID署名・Hardened Runtime・タイムスタンプ・内包コードの署名整合性を検証。
- 既存の自動テストは24アプリで成功。14アプリは一括処理対象のtest.shがなく未確認。CarmaChameleon・MarkdownKitchenは既存Node.jsのPATHを補って再テスト。
- KeynoteMaestro build 28のパレット関連変更と、PrefsPreset 1.2.1 build 22のコンピュータ名を保持する読み込み処理をソースへ反映。共通MenuBarPresenceの現行実装を各アプリへ同期。
- DropboxのLatest Buildsは37アプリを更新し、署名・内容一致を検証。SettingsCourierは既存build 13が再ビルドbuild 9より新しいため保持。
- 公開Releaseには35アプリの署名済みZIPとSHA-256一覧を掲載。既存の公開対象外2アプリ、および古いSettingsCourier build 9は添付しない。
- 今回の再ビルドのApple公証・DMG・/Applicationsへの配置・実機動作は未確認。過去の公証済み配布物は保持。

## 2026年10月24日 — SiteMirror 1.3.0（build 5）

- HTTrack の機能のうち、上書き時にサイトから消えたファイルをゴミ箱に入れる、取らない種類と大きさの上限、取り込むURL、中止した取り込みの続き、sitemap.xml、JavaScript の中の URL（推測）を追加。
- ハーネスで各機能を確認（続きからの取り込みが通しの取り込みと一致することを含む）。アプリの画面からの操作は未確認。

## 2026年10月24日 — SiteMirror 1.2.0（build 4）

- 失敗時の再試行、取得の間隔、取り込まないURL、上書き時に変わっていないファイルを取り直さない機能を追加（wget の --tries・--wait・--reject・-N 相当）。
- 保存せずリンク切れだけを調べる「リンクを調べる」（wget の --spider 相当、報告ファイルを保存先に書く）を追加。
- ログインが必要なサイトのための「ログイン…」（アプリ内ブラウザーの Cookie と Basic 認証を使い、ログアウトのリンクはたどらない）を追加。
- ローカルの試験サーバーとハーネスで各機能を確認。アプリ内ブラウザーでのログインの画面操作は未確認。

## 2026年10月24日 — SiteMirror 1.1.0（build 3）

- 一覧に「すべて／失敗／除外」の切り替えと、URL（と理由）のコピーを追加（1.0.1）。
- 同じサイトのフォルダーがあるとき「上書き／別のフォルダーに保存」を選べるようにした。上書きでも今回取り込まなかったファイルは消さない。
- 取り込みフォルダーに SiteMirror-log.txt（失敗・除外したURL・理由・参照元）を書く。「記録を開く」を追加。

## 2026年10月24日 — SiteMirror を追加（1.0.0 build 1）

- URLを指定したWebサイトのページをたどり、HTML・CSS・JavaScript・画像・フォントを保存して、リンクを相対パスに書き換える新しいアプリ。ページの表示に必要なファイルはほかのドメイン（CDN など）からも保存（設定でオフにできる）。robots.txt、たどる深さ・ファイル数・同時接続数を設定できる。
- 共通部品の配布スクリプト（MenuBarPresence・AppStandards・LoginAtLaunch・SettingsSync・Updater）に SiteMirror を登録。
- 開発Macでビルド・取り込みエンジンのハーネス試験（ローカルの試験サーバー）・/Applications と Latest Builds への配置（チームの開発証明書で署名）・起動を確認。アプリの画面からの取り込み操作、Developer ID 署名・公証・DMG・個別リポジトリ・note記事は未実施。

## 2026年10月24日 — SettingsCourier を追加（1.3.2 build 9、公開準備）

- 登録したアプリの設定（defaults）をアプリごとの `<アプリ名>.settingscourier` に書き出し、ほかのMacで取り込む新しいアプリ。App Storeのアプリなどサンドボックスのアプリにも対応（起動時には読まず、「設定を読む」・書き出し・取り込みのときかフルディスクアクセスがあるときだけ読む）。
- 受け渡しは「設定の共有」の同期フォルダーの中の `SettingsCourier` フォルダー。「新しい設定があります」の表示、終了時の自動書き出し、まとめて書き出す・取り込む。取り込みは確認・バックアップ・起動中のアプリの終了と再起動を経て行い、自動では行わない。
- 設定ファイルの外にあるデータも「一緒に運ぶファイル」で運べる。Default Folder X は使用中のフォルダーセットのお気に入り（Favorites.plist）を自動で追加。
- 共通部品の配布スクリプト（MenuBarPresence・AppStandards・LoginAtLaunch・SettingsSync・Updater）に SettingsCourier を登録。
- 開発Macでビルド・自動テスト（7本）・/Applications と Latest Builds への配置（チームの開発証明書で署名）・起動を確認。Developer ID 署名・公証・DMG・個別リポジトリ・GitHub Release・note記事は未実施（公証Macの工程）。

## 2026年10月23日 — アプリごとの個別リポジトリへ公開

- 公開対象33アプリのソースを各アプリ名の個別リポジトリに登録。元の履歴を残し、各リポジトリの既存コミットに続けて公開コミットを追加。
- READMEの一覧に個別GitHubリポジトリへのリンクを掲載。情報画面のGitHubリンクも個別リポジトリへ対応。
- SVGExporter・InsertSnippetsは対象外。未コミットのKeynoteMaestroなどの作業を保持し、公開には確定済みソースだけを使用。
- 33件の内容（Git tree）・main・既存の親コミットを確認。共通情報画面のSwift型検査が成功。再ビルド・実機確認・配布は未確認。
- [公開コミット一覧と検証範囲](SOURCE-REPOSITORIES.md)。

## 2026年10月23日 — GitHub・noteの相互リンク

### アプリの情報画面と公開ソース

- 共通の「設定 → 情報」にGitHubへのリンクを追加。情報タブがないIdBackgroundOffは既存の「アプリについて」に追加。
- 公開対象33アプリのソースコードと共通部品を反映。KeynoteHelperからKeynoteMaestroへの名称変更を公開一覧へ反映。
- BreaklineTrimmerのnote記事URLを[専用記事](https://note.com/swwwitch/n/ne4a0fc0c1dd2)へ変更。リソース生成スクリプトも同じURLへ更新。
- SVGExporterとInsertSnippetsは公開対象外のまま保持。

関連コミット：[情報画面と公開ソース](https://github.com/swwwitch/macos-apps/commit/857ef286ca4aa62a45f21fb8fcc029ddd291065e)、[BreaklineTrimmerの記事URL](https://github.com/swwwitch/macos-apps/commit/a6bd17f)。

### noteの記事更新履歴

| 記事 | 今回の変更 | 確認結果 |
| --- | --- | --- |
| [KeynoteMaestro](https://note.com/swwwitch/n/n7b7e549f7379) | ソースコードへのリンクと「2026年10月23日（記事更新）」を追記。既存のGitHub Releasesへのリンクを保持 | 公開ページで確認済み |
| [FolderHopper](https://note.com/swwwitch/n/nd532a1c19f33) | ソースコードへのリンクを冒頭にも掲載し、既存の更新履歴へ追記 | 公開ページで確認済み |
| [BreaklineTrimmer](https://note.com/swwwitch/n/ne4a0fc0c1dd2) | ソースコードへのリンクと記事更新履歴を追記 | 公開ページで確認済み。本文末尾の既存境界を保持し、通知せず更新 |
| [IdBackgroundOff](https://note.com/dtp_tranist/n/nec393e9218e9) | ソースコードへのリンクと既存の更新履歴へ追記 | 公開ページで確認済み。有料100円・既存境界を保持し、通知せず更新 |

他の記事の既存GitHubリンクは保持。記事の更新はアプリ本体の新バージョン公開を意味しない。

### 検証

- 共通情報画面のSwift型検査、設定同期・KeynoteMaestro・CCAutoUpdateOffの既存テストを確認。
- BreaklineTrimmerの4言語リソース検査を確認。
- 情報画面のリンク追加を含む全アプリの再ビルド・実機表示・配布先更新は未確認。
