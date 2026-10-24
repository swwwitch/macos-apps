# FontSwitcher

現行版：**1.4.1（build 9）** — 2026-10-24

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
- サイドバーの「ベンダー」（OS/2 の achVendID：MRSW＝モリサワ、FWKS＝フォントワークス）と「コレクション」（`NSFontCollection` の PostScript名・ファミリー名の問い合わせで照合）
- セット：作成・名前の変更・削除、セットに追加／外す、セットをまとめてアクティブ／解除

通信はアップデート確認だけです。アクセシビリティの許可は不要です。

## ビルド

```sh
./build.sh            # ビルド（arm64＋x86_64）→ 検証 → /Applications と Latest Builds へ配置
NO_DEPLOY=1 ./build.sh  # 配置せず build/ にだけ作る
```

- SwiftPM（`Package.swift`）。ソースは [Sources/FontSwitcher](Sources/FontSwitcher/)、文字列・ヘルプは [Localizations](Localizations/)（ja / en / zh-Hans / ko）。
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

- 1.4.1（build 9）：アプリを呼び出すホットキーの初期値を ⌃⇧⌘F に（⌃⌥⌘F は FolderHopper・SpreadsheetHelper と重なるため）。1.4.0 の ⌃⌥⌘F のまま使っていた場合は1回だけ移す
- 1.4.0（build 8）：アプリを呼び出すホットキー ⌃⌥⌘F、サイドバーにベンダー（モリサワ・フォントワークス）とコレクション
- 1.3.1（build 7）：「.SF NS」など macOS 内部用のフォントを出さない、System は常にアクティブ表示、フォントフォルダーから消えたファイルを一覧から外す
- 1.3.0（build 6）：システムのフォントフォルダー3つ（username・All Users・System）、コレクションに追加、フォント変更の通知をまとめてから状態を読み直す（起動直後の約10秒の遅れを解消）
- 1.2.2（build 5）：ファミリーの一覧を AppKit の NSOutlineView に置き換え。選択1回のメインスレッド時間 188ms → 91ms（7,516件）
- 1.2.1（build 4）：一覧・件数の計算を控えて、選択や切り替えのたびに数え直さない。プレビューは見えている書体だけ描く
- 1.2.0（build 3）：ライブラリの共有（Dropbox など）、お気に入り、~/Library/Fonts の表示
- 1.1.0（build 2）：ファミリーを開いて書体（ファイル）ごとにチェックボックスで切り替え
- 1.0.0（build 1）：最初の版
