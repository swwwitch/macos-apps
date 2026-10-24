# FontSwitcher

現行版：**1.7.0（build 16）** — 2026-10-24

フォントファイルをライブラリに登録し、必要なときだけアクティブにするフォント管理アプリです（FontExplorer X Pro の基本機能に相当）。ユニバーサル版（Apple Silicon・Intel）。

- フォントファイル・フォルダーのドロップか「追加…」で登録する。フォルダーは下の階層まで探す（.otf・.ttf・.ttc・.otc・.dfont・.woff・.woff2）。ファイルはコピー・移動せず場所だけを覚える
- ファミリー単位でアクティブ／解除。ファイルが2つ以上のファミリーは開閉でき、書体（ファイル）ごとのチェックボックスでも切り替える（一部だけなら「－」）。複数選択でまとめて切り替え。アクティブは `CTFontManagerRegisterFontsForURL` の `.session`（ログイン中だけ、終了しても残る）
- 起動時に前回アクティブだったフォントを戻す（設定、初期値オン）。終了時にすべて解除（設定、初期値オフ）
- サイドバー：すべて・アクティブ・非アクティブ・重複（同じPostScript名）・見つからない・セット
- プレビュー：アクティブにしていないフォントもファイルから直接表示。文字と大きさを変えられる。形式・バージョン・PostScript名・場所
- お気に入り（ファミリー名で覚える）
- サイドバーの「システム」：ユーザー名（`~/Library/Fonts`）・All Users（`/Library/Fonts`）・System（`/System/Library/Fonts`）。起動時とフォントの変更時に読み込む。ユーザー名と All Users は `.persistent` の登録解除・再登録で切り替え（ファイルは動かさない）、System は切り替え・取り除き不可
- コレクションに追加：`NSFontCollection`（`~/Library/FontCollections`、visibility .user）に PostScript 名で加える
- ライブラリの共有：選んだフォルダー（Dropbox など）の `FontSwitcher-Library.json` を両方のMacで使う。場所は `$DROPBOX-<アカウント>/…`・`~/…` で保存し、Macごとの場所に読み替える（`~/.dropbox/info.json`）。フォルダーを見張り、前面に戻ったときも確かめて読み直し、アクティブの違いを反映する
- アプリを呼び出すホットキー（初期値 ⌃⇧⌘F、共通の HotkeyField・HotkeySet、HotkeyManifest に申告）。同じキーを前面アプリ専用で申告している起動中の自作アプリ（FolderHopper・SpreadsheetHelper）が前面の間は登録を外して譲る（`HotkeyManifest.claimedByOtherApp`）。未起動時は効かない
- サイドバーの「種類」（バリアブル・カラーフォント）
- サイドバーの「ベンダー」（OS/2 の achVendID：MRSW＝モリサワ、FWKS＝フォントワークス、ADBE＝アドビ）と「コレクション」（`NSFontCollection` の PostScript名・ファミリー名の問い合わせで照合）
- セット：作成・名前の変更・削除、セットに追加／外す、セットをまとめてアクティブ／解除

通信はアップデート確認だけです。アクセシビリティの許可は不要です。

## ビルド

```sh
./build.sh            # ビルド（arm64＋x86_64）→ 検証 → /Applications と Latest Builds へ配置
NO_DEPLOY=1 ./build.sh  # 配置せず build/ にだけ作る
```

- SwiftPM（`Package.swift`）。ソースは [Sources/FontSwitcher](Sources/FontSwitcher/)、文字列・ヘルプは [Localizations](Localizations/)（ja / en。中国語・韓国語は 1.10.0 で外した＝ユーザー指定）。
- 共通部品（AboutSection・AppSurface・StartupWindow・SettingsSection・HelpDocument・MenuBarPresence・LoginAtLaunch・SettingsSync・UpdateSupport）は `Tools/sync-shared.py` がビルド時に上書きするので、直接編集しない。
- 画面の文字列を足したら、[Tools/translations.tsv](Tools/translations.tsv) に訳を加えて `python3 Tools/make-strings.py` で Localizable.strings を作り直す。
- アイコンは [Assets/make-icon.sh](Assets/make-icon.sh)（GenerateIcon.swift から .icns を生成）。
- ロジックの確認：`xcrun swiftc -parse-as-library Sources/FontSwitcher/FontLibrary.swift Sources/FontSwitcher/Localization.swift Tests/FontLibraryTests.swift -o /tmp/fstests && /tmp/fstests <未インストールのフォントを入れたフォルダー>`（セッションに登録して解除まで行う）

## 実装メモ

- [FontLibrary.swift](Sources/FontSwitcher/FontLibrary.swift)：AppKit に依存しないモデル・読み取り・アクティブ化。単体で試せる。
- 登録済みフォントの一覧を返す `CTFontManagerCopyRegisteredFontDescriptors` は macOS では使えない（iOS のみ）。状態は、先頭の書体のPostScript名で `CTFontCreateWithName` が返すファイルがこのファイルかどうかで判定する。ほかのアプリが入れた同名フォントは「conflict」。
- 登録済みの再登録は 105（alreadyRegistered）、未登録の解除は 201（notRegistered）で、どちらも成功とみなす（2026-10-24 実測）。
- 同じPostScript名の2つ目のファイルも登録自体は成功するが、使われるのは先のほう。紛らわしいので登録を戻して失敗として報告する。
- ライブラリは `~/Library/Application Support/FontSwitcher/Library.json`。読めないときは `Library.unreadable.json` に控えて上書きしない。
- `kCTFontManagerRegisteredFontsChangedNotification` でほかのアプリの変更にも追従する。
- 一覧（ファミリーへのまとめ・並べ替え）・サイドバーの件数・重複は、元（ライブラリ・状態・絞り込み・検索）が変わったときだけ計算し直す。7,516件で、まとめ直し26ms・検索27ms・全ファイルの状態696ms（裏で実行）・486書体のプレビュー用フォント136ms（2026-10-24、リリースビルドの計測）
- ファミリーの一覧は [FamilyOutline.swift](Sources/FontSwitcher/FamilyOutline.swift)（NSOutlineView）。SwiftUI の `List(children:)` は選択を変えるたびに全行を比べ直し（`OutlineListCoordinator.recursivelyDiffRows`）、1,428行で1回0.12〜0.19秒止まった。`listVersion` が進んだときだけ読み直す。
- 速さの計り方：`open --env FONTSWITCHER_BENCH=select -a FontSwitcher` で起動すると5秒後から0.3秒ごとに選択を30回変える（BenchMode.swift）。その間 `sample <pid> 9` を取り、メインスレッドの `__CFRunLoopServiceMachPort` 以外を使用時間とみなす。アクセシビリティで行を選ぶ計り方は、応答のために全行が作られて数字にならない
- `~/Library/Fonts` のフォントは `.session` では解除できない（201）。`.persistent` の解除で無効になり、`.persistent` の登録で戻る（2026-10-24、試験用フォントで実測）。`/Library/Fonts` は同じ方法だが未実測
- 未実装（今後）：Adobe アプリ向けの自動アクティベート（JSX 連携）、字形一覧、壊れたフォントの点検、スマートセット、フォントのコピー整理。

## 更新履歴

- 1.17.0（build 38）：設定の「フォント」にウォッチフォルダー（複数。FSEvents で下の階層も見張り、新しいフォントファイルをライブラリに足す。場所は Mac ごとに UserDefaults `watchFolders`）。アイコンフォントの判定に「ラテン文字拡張A（U+0100〜017F）が20字未満」を足し、名前（Awesome・Icon・Dingbat・Ornament・Symbols・Emoji など、大文字・小文字を区別）でも判定し、`metadataVersion` 6 で全件を読み直す（SF Pro・筆記体の誤判定。Font Awesome 6・7 は欧文の拡張文字も持ち、文字の構成では筆記体と分けられない）
- 1.16.0（build 37）：「種類」にアイコンフォント（私用領域の文字が半分以上か、CTFontStylisticClass が Symbolic）。「ツール」メニューに「Illustratorのフォントを統一…」（ai-scripts の AiFontConverter.jsx v1.1.8 を移植。名前の変換は FontConverterRules.swift、ドキュメントの操作は osascript の do javascript で送る JSX。変換先が Illustrator にあるかは app.textFonts で確かめる）。NSAppleEventsUsageDescription を追加
- 1.15.2（build 36）：プレビューのオプションに配色（白地に黒・黒地に白・カスタム）。初めは白地に黒
- 1.15.1（build 35）：検索オプションに N（JIS2004対応）・UD・AP版・新ゴ（AiFontConverter と同じ区分、`VariantFilter`）。4列に
- 1.15.0（build 34）：プレビューに表示の切り替え（1行・複数行・ウォーターフォール 72〜9pt）とオプション（文字・背景の色、不透明度、カーニング、トラッキング 1/1000 em、プレビューの文字の候補）。「アドビ」に Myriad・Minion・りょう・Source Code Pro・Noto を追加（ユーザー指定）
- 1.14.2（build 33）：「アドビ」は `adobeFamilies` のファミリーだけに（ユーザー指定。ベンダーID・商標の持ち主では入れない）
- 1.14.1（build 32）：ベンダーの判定を商標の持ち主（name テーブルの商標・著作権の「trademark of …」、ITC で始まる名前は ITC）優先に。ADBE のベンダーIDを持つモリサワ（A-OTF リュウミンなど）・Linotype（Helvetica・Frutiger）・ITC の書体がアドビに入っていた。貂明朝・小塚・源ノ角ゴシック・源ノ明朝・ヒグミン・百千鳥・Adobe Clean はファミリー名で必ずアドビに（ユーザー指定、`LibraryStore.adobeFamilies`）
- 1.14.0（build 31）：Adobe Fonts を表示している間、一覧の上に「Creative Cloudを開く」「fonts.adobe.com」（サイドバーの行の右クリックにも）。Adobe Fonts は `.persistent` で解除しても1秒以内に Creative Cloud が登録し直す（実測）ため切り替えはしない
- 1.13.5（build 30）：サイドバーの「種類」に「かなフォント」
- 1.13.4（build 29）：検索オプションを3列に整理（文字セット＋Nフォント／形式＋種類／書体数＋収録文字数）、中身の大きさに合わせて上の空白をなくす
- 1.13.3（build 28）：モリサワ・フォントワークスの行のアイコンを各社のロゴに（ユーザー指定の画像を見て描き起こした近似の図形）、「Adobe Fonts」の行のアイコンを濃紺の角丸に白い斜体の「f」に（ユーザー指定の画像にならう）
- 1.13.2（build 27）：ベンダー「アドビ」のアイコンをアドビのロゴに（ユーザー指定の SVG を SwiftUI の Shape に写した VendorLogos.swift）
- 1.13.1（build 26）：サイドバーの「…」ボタンを小さく（18→10pt）
- 1.13.0（build 25）：お気に入り・アクティブ・非アクティブ・最近〜・日本語をサポートを、セットとは別の区分「スマートセット」に（「…」パネルの表示・並び順の対象。並び順を保存済みでも、セットの前に入る）、ベンダーの行のアイコンを頭文字のバッジ（M・F・A）に
- 1.12.0（build 24）：セットの行にまとめてアクティブ・解除するチェックボックス（一部なら「−」）、検索オプションに「Nフォント」（ファミリー名の文字セットが N で終わるか）
- 1.11.0（build 23）：サイドバーの「お気に入り」「アクティブ」「非アクティブ」をライブラリからセットの先頭へ移し、「最近アクティブ」「最近非アクティブ」「最近追加したもの」（7日以内。FontFile に activatedAt・deactivatedAt を記録）と「日本語をサポート」（あ・アを持つ）を追加
- 1.10.3（build 22）：検索欄の上下を広げ（8→12pt）、サイドバーの「…」ボタンを大きく（18pt）
- 1.10.2（build 21）：検索オプションから「名前の先頭」を外す（ユーザー指定）
- 1.10.1（build 20）：検索オプションの候補をポップアップメニューからラジオボタンに（5つの条件を横に並べ、名前の先頭は4列でスクロール）
- 1.10.0（build 19）：フォント情報に収録文字数（CFCharacterSet のビットマップで数える）とグリフ数、検索オプションに収録文字数と「かなフォント」（あ・アを持ち CJK 統合漢字が50字未満）、サイドバー上部の「…」で区分の表示と並び順（設定の「表示」タブは廃止）、表示言語を日本語・英語だけに（zh-Hans・ko を削除＝ユーザー指定）
- 1.9.0（build 18）：検索欄の右に「検索オプション」ボタン。文字セット・名前の先頭の絞り込みを一覧の上からポップオーバーへ移し、形式・種類（バリアブル・カラー）・ファミリーの書体数（1、2〜4、5〜9、10以上）を追加。絞り込み中はボタンを塗りつぶし
- 1.8.0（build 17）：サイドバーに「種類」（バリアブル＝fvar、カラーフォント＝COLR・sbix・CBDT・SVG。`CTFontCopyAvailableTables` の中身は CFNumber ではなくタグそのものなので `CFArrayGetValueAtIndex` で読む。古い版で登録したファイルは裏で読み直して足す）、ベンダーに「アドビ」（ADBE。Creative Cloud でアクティブにした「Adobe Fonts」とは別に、ライブラリにあるアドビ製のフォント）
- 1.7.0（build 16）：ベンダーに「Adobe Fonts」（Creative Cloud が `~/Library/Application Support/Adobe/CoreSync/plugins/livetype/.r` に「.<ID>.otf」で置くフォント。隠しファイルも読む。切り替えは Creative Cloud で行うので FontSwitcher では切り替えない）
- 1.6.3（build 15）：スペースバーで選んだ行を切り替える（すべてアクティブなら解除、それ以外はアクティブ）。チェックボックス・☆はキーの入力を受けない（クリックしたチェックボックスにフォーカスが残り、スペースで一度だけ解除されていた）
- 1.6.2（build 14）：プレビューで字形の無い文字をさらに薄く（15%）
- 1.6.1（build 13）：フォント名の切り替えを検索欄の下の行に移し、一覧の幅いっぱいに伸び縮みさせる（狭いとプレビューのボタンと重なっていた）
- 1.6.0（build 12）：絞り込み（文字セット・名前の先頭、ファミリー名から FontNaming で判定）、プレビューで字形の無い文字を薄く表示、フォント名の切り替えの幅を可変に、アイコンを「あa」に（スイッチを外す）
- 1.5.1（build 11）：バージョン（build）をヘッダーのアイコンの下に移し、見出しの大きさをほかのアプリに合わせる
- 1.5.0（build 10）：フォント名の出し方（日本語名・PostScript名・両方）、プレビューを隠す（⌥⌘P）、サイドバーの区分の開閉（コレクションは初めは閉じる）と設定「表示」での表示切り替え。日本語の表示名（CTFontDescriptorCopyLocalizedAttribute）をベンダーIDと一緒に裏で補う
- 1.4.1（build 9）：アプリを呼び出すホットキーの初期値を ⌃⇧⌘F に（⌃⌥⌘F は FolderHopper・SpreadsheetHelper と重なるため）。1.4.0 の ⌃⌥⌘F のまま使っていた場合は1回だけ移す
- 1.4.0（build 8）：アプリを呼び出すホットキー ⌃⌥⌘F、サイドバーにベンダー（モリサワ・フォントワークス）とコレクション
- 1.3.1（build 7）：「.SF NS」など macOS 内部用のフォントを出さない、System は常にアクティブ表示、フォントフォルダーから消えたファイルを一覧から外す
- 1.3.0（build 6）：システムのフォントフォルダー3つ（username・All Users・System）、コレクションに追加、フォント変更の通知をまとめてから状態を読み直す（起動直後の約10秒の遅れを解消）
- 1.2.2（build 5）：ファミリーの一覧を AppKit の NSOutlineView に置き換え。選択1回のメインスレッド時間 188ms → 91ms（7,516件）
- 1.2.1（build 4）：一覧・件数の計算を控えて、選択や切り替えのたびに数え直さない。プレビューは見えている書体だけ描く
- 1.2.0（build 3）：ライブラリの共有（Dropbox など）、お気に入り、~/Library/Fonts の表示
- 1.1.0（build 2）：ファミリーを開いて書体（ファイル）ごとにチェックボックスで切り替え
- 1.0.0（build 1）：最初の版
