# VectorFX

Illustratorの効果・パスファインダー・複合シェイプ・複合パス・線端などを、Illustratorの上に浮かぶパレットとホットキーで実行するAppKit/SwiftUIアプリ。Apple Silicon / macOS 13以降。Bundle ID `jp.dtp-transit.vectorfx`。

Keyboard Maestroのパレット型グループ「Ai-アピアランス」（`sync-setting/keyboard maestro/outgo-2021/Ai-アピアランス Macros.kmmacros`）を移植した。1.0.0ではKMでオンだった33本、1.1.0で残りのマクロ（Ai-アピアランス Macros2.kmmacros）を追加して57項目。区切りのマクロは見出しに、「グラフィックスタイルを更新」（パネルメニューを座標クリック）は未移植。

## 動作

- パレット：Illustratorが前面のとき ⌃A（元のパレットと同じ）で表示／非表示。ほかのアプリが前面になると隠れ、Illustratorに戻ると再表示。`nonactivatingPanel` でIllustratorの選択を保つ。
- 項目のホットキー：パレットを表示中かつIllustratorが前面のときだけ登録（KMの「パレット表示中だけ有効」と同じ）。修飾キーなしのキー（「項目を削除」の -）も割り当てられる。
- 実行：ExtendScriptを組み立て、前面のIllustratorへパス指定の `do javascript`（osascript）。直列、待ちは3件まで。組み込みのスクリプトは `OK` / `ERR:nodoc|nosel|text|action` を返し、理由を画面に出す。

## 元のマクロからの置き換え

| 元のマクロの手順 | VectorFX |
| --- | --- |
| ［効果］メニュー＋キー入力で値を入れる（ドロップシャドウ 30%/2/2/2、パスのオフセット 1、長方形 +0/+0、ジグザグ 0・1、ジグザグ 0・0、ラフ 0・9・丸く） | `applyEffect` にLiveEffectのXML。値はメインウインドウで変更でき、長さはドキュメントの単位（`rulerUnits`）。Option＋クリックで元の［効果］メニュー（ダイアログボックス）。 |
| ダイアログボックスを開くだけの効果（角を丸くする・ワープ円弧・パスの自由変形・パンク・膨張・変形） | `app.executeMenuCommand("Live …")` |
| パスのアウトライン・オブジェクトのアウトライン・パスファインダー（追加・分割・アウトライン・切り抜き）・複合パス | `executeMenuCommand` |
| アピアランスを消去・項目を削除・複合シェイプ（Ai Do Action Text／Appearance Panel Action） | 一時アクション（.aiaを書いて loadAction → doScript → unloadAction、セット名「VectorFX Temporary」） |
| グループの抜き（Ai Do Action） | `app.doScript("グループの抜き", "S2A")` |
| ［効果］＞3D（クラシック）の各項目 | Ai 2026の［3D とマテリアル］（Live Adobe Geometry3D Extrude／Revolve／Rotate） |
| ラスタライズ（キー入力で設定してReturn）・ラスタライズ（2回目以降） | 1項目「ラスタライズ」にまとめ、ダイアログボックスを開く |
| オープンパスの「丸型線端に」 | KMの中のアクション（.aia）を Resources/Actions に同梱し、セット名を差し替えて実行 |
| 同じキーの重複（⇧E・⇧T・⇧K・K・`=`／`` ` ``） | 1キー1項目。先に移植した項目を優先し、重複した側はキーなし（項目を複製は =、リセット黒は K、白は W） |
| 線端（Ai Execute Jsx Text） | 組み込みのExtendScript（グループ・複合パスの中も） |
| スクリプトファイル（Open1File／Ai Execute Script File） | `do javascript (POSIX file …)`。場所は変更できる。KPTSketchy.jsx は現存しないため KPTSketchyPalette.jsx を既定にした |
| 変形「上を基準に6px下げ、つぶす2」 | テキスト1つ：長方形（+1/+3）→［変形］高さ0・基準点上中央・フォントサイズの半分下へ。それ以外：高さ0・中央 |

未確認：Illustrator上での各項目の実行（特に変形 pinPoint 1 が上中央か、moveV_Pts の符号、Live … コマンドがダイアログボックスを開くか）。

## しくみ

- `Source/Commands.swift`：項目の一覧・既定キー・一時アクションの.aia（Foundationのみ、テスト対象）
- `Source/ScriptBuilder.swift`：ExtendScriptの組み立て（テスト対象）
- `Source/Runner.swift`：Illustratorの判定・osascript・直列実行
- `Source/Model.swift`：設定（UserDefaults）・ホットキーの登録・実行結果
- `Source/Palette.swift`：パレット、`Source/Views.swift`：主画面・設定、`Source/main.swift`：メニュー・起動
- 外部通信なし（更新確認を除く。配信先は未設定）。権限：オートメーション（Illustrator）。アクセシビリティは使わない。

## ビルド・テスト

```
./test.sh            # 単体テスト（生成スクリプトの構文チェックを含む）＋4言語の翻訳キー・プレースホルダー検証
./build.sh           # build/VectorFX.app
Assets/make-icon.sh  # アイコンを作り直す
```

## 更新履歴

- 1.3.0 (5)　2026-11-01：項目ごとのカラー（Finderのタグの7色）。文字入力中（文字ツール・ダイアログボックス）は修飾キーなしのホットキーを実行しない（イベントタップ、アクセシビリティ）。主画面の右に「しくみ」（手順と送るExtendScript）。ダイアログボックスが開く項目の名前に「…」。「オープンパスにする」を［その他］へ。オープンパスは［変形］と［パスファインダー：アウトライン］をXMLで付け、変形→アウトラインの順・塗りのないアートワークを残す。削除：「変形：つぶして線にする」「変形：テキストを線にする（＋1・＋3）」「リセットして塗りを黒／白、線なし」「テキストの塗りを黒／白＋アウトライン」「新規塗りを追加」「新規線を追加」（49項目）。
- 1.1.0 (2)　2026-11-01：抜けていたマクロ24本を追加（パスファインダー5種、楕円形・角丸長方形、3D 3種、ランダム・ひねり、旋回、ラスタライズ、塗り・線の追加、項目を複製、リセット白・黒、テキストの塗り白・黒＋アウトライン、グラフィックスタイルを適用（最後）、アピアランスを分割（グループ解除）、オープンパスにする）。既存の保存キーに新項目の既定キーを追加（空いているキーだけ）。
- 1.0.0 (1)　2026-11-01：新規。KMの「Ai-アピアランス」パレットを移植（33項目・ホットキー17）。
