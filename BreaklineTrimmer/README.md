# BreaklineTrimmer

![macOS](https://img.shields.io/badge/macOS-14%2B-lightgrey) ![version](https://img.shields.io/badge/version-1.3.2-blue) ![license](https://img.shields.io/badge/license-private-lightgrey)

画像の一部を取り除いて残りを詰め、切り口に省略線を引いて、PNG・JPEG・PSDで書き出すアプリ。Illustratorのスクリプト [TrimWithBreakLine.jsx](https://github.com/swwwitch/illustrator-scripts/blob/master/readme-ja/TrimWithBreakLine.md)（v1.3.0）をビットマップ用に移植した。

- 元画像の上をドラッグして取り除く範囲（スクリプトの「マスク用の図形」）を描く。青いガイド（範囲の端）のドラッグで端だけを動かし、内側のドラッグで移動
- 切り分ける向き・片側だけ残す判定・切り口（旗／上昇／直線／ギザギザ）・間隔・省略線（線幅・線端・実線／破線・分割数）はスクリプトと同じ
- 右側の「ファイル形式」でPNG・JPEG・PSDを選ぶ。設定の「出力」で保存先（元画像と同じフォルダ／デスクトップ／指定したフォルダ／毎回指定）と、元の名前に付ける文字（初期値「-breakline」）を指定
- 背景（透明・白・グレー・黒）を選んで、PNG・JPEG・PSDで保存（JPEGは透明なら白で塗る。dpiを引き継ぐ。写真の向きは直して書き出す）、またはクリップボードへコピー（PNG）
- 長さの単位はピクセル（スクリプトの pt を 1px として扱う）

## ビルドとテスト

- ビルド：`build.sh`（arm64＋x86_64、チーム証明書で署名し、/Applications と Latest Builds へ配置。`SKIP_DEPLOY=1` で配置しない）
- テスト：`test.sh`（切り分けの向き・片側だけ残す・間隔・切りそろえ・省略線・切り口の形・透明・PNGの往復・設定の範囲、4言語の文字列とヘルプ）
- 文字列・ヘルプ・Info.plist：`make-resources.py` を編集して実行（バージョンとbuildは Info.plist の値を保つ）
- アイコン：`Assets/make-icon.sh`（`GenerateIcon.swift`）

## 配布

公証済みDMG：`Shared/ReleasePreparation/20261019-BreaklineTrimmer-1.2.0/DMGs/BreaklineTrimmer-1.2.0-build4-signed.dmg`（Developer ID・Hardened Runtime・公証・staple済み）。1.1.0 は 20261019-BreaklineTrimmer。手順は同フォルダーの `sign_all.py`（`updates.json` に版と元の.appを書く）→ `notarize.py`（キーチェーンのプロファイル swwwitch-notary）。/Applications と Latest Builds の .app はローカル用のチーム証明書署名。

## 構成

| ファイル | 内容 |
| --- | --- |
| Source/TrimGeometry.swift | スクリプトの移植部分：切る向きの判定、帯の範囲（大きさ・位置）、切り口の形、パーツの外形と移動量、省略線、出力の範囲。描画（CGContext）とPNG・JPEG・PSDの書き出し |
| Source/main.swift | 画面（元画像・プレビュー・設定の列）、メニュー、設定ウインドウ、起動と終了 |
| Tests/main.swift | TrimGeometry の自動テスト |
| ../Shared/… | 共通部品（ヘッダー・地色・設定タブ・情報・ログイン起動・設定の共有・メニューバー・更新）。コピーせず直接コンパイル |

## スクリプトとの違い

| スクリプト | アプリ |
| --- | --- |
| オブジェクトとマスク用のパスを選択 | 画像を開き、取り除く範囲をドラッグで描く（使うのは範囲の外接矩形だけなので同じ結果） |
| ワープ・ジグザグ効果を適用して分割 | 同じ形を計算で作る。カーブの量は画像の高さ（左右なら幅）に対する割合。旗は1周期の正弦波、上昇はS字、直線は斜線、ギザギザは両端を固定して交互に振る |
| 定規・線の単位 | ピクセル |
| 罫線をパーツとグループ化 | ビットマップには当てはまらないため省略 |
| 設定はスクリプトの保存ファイル | UserDefaults（「設定の共有」で書き出し・同期できる） |

## 更新履歴

- 2026-10-23（情報画面・記事導線）：共通のGitHubリンクを追加し、note記事URLを専用記事へ変更。ソースと生成スクリプトへ反映済み。配布アプリへの反映は未確認。

- 1.4.0（build 10, 2026-10-20）：設定の［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（初期値オフ。オンでDockと⌘Tabに出さず、メニューバーのアイコンかFinderで開き直して表示）。ヘルプ（4言語）にも追記。

- 1.3.2（build 9, 2026-10-19）：ファイル形式（PNG・JPEG・PSD）の選択を、設定の「出力」から右側の設定列（省略線の下）へ移した。JPEGを選ぶと「透明な部分は白になる」と表示。

- 1.3.1（build 7–8, 2026-10-19）：設定の「出力」に「保存後」→「保存したファイルを開く」を追加（初期値オフ、「設定の共有」の対象）。メインウインドウの「Finderで表示」ボタンを廃止。build 8 で「画像を開く…」を「処理する画像を開く…」に（ボタン・メニュー・パネル・ヘルプ、4言語）。

- 1.3.0（build 6, 2026-10-19）：書き出しの形式にJPEG・PSDを追加（設定の「出力」→「形式」、初期値PNG、「設定の共有」の対象）。JPEGは背景が透明なら白で塗り、画質90%。PSDは透明を保った1枚の画像。拡張子・保存パネル・ボタンとメニューの名前を形式に合わせる。コピーは従来どおりPNG。

- 1.2.1（build 5, 2026-10-19）：プレビューの背景（白・グレー・黒）を、保存・コピーする画像にも反映するようにした（透明なら従来どおり透明）。項目名を「プレビューの背景」から「背景」に。読み込みの案内にPSDを追加（統合画像を読む。RGB・CMYKとも可）。

- 1.2.0（build 4, 2026-10-19）：プレビューの背景を切り替え（透明・白・グレー・黒、表示だけで保存は透明のまま、Macごとに記憶）。省略線の色（不透明度つき、初期値は黒、「設定の共有」の対象）。

- 1.1.0（build 3, 2026-10-19）：アプリ名を TrimBreakline から BreaklineTrimmer に変更（フォルダー・.app・実行ファイル・アイコン・メニュー・ヘルプ）。build 3 で利用者の指示により Bundle ID も jp.dtp-transit.trimbreakline → jp.dtp-transit.breaklinetrimmer に変更（初回起動時に旧ドメインの設定を引き継ぐ。ウインドウ位置の保存名も BreaklineTrimmerMain・BreaklineTrimmerSettings に）。旧 .app は Backups/rename-20261019-112103（1.0.0）と Backups/bundleid-20261019-112218（1.1.0 build 2）へ退避。元画像の青いガイド（取り除く範囲の上下、左右に切るときは左右）をドラッグして端を動かせるようにした（ガイドの上でカーソルが上下・左右の矢印になる）。設定に「出力」タブを追加：保存先（元画像と同じフォルダ・デスクトップ・指定したフォルダ・毎回指定する）と、元の名前に付ける文字（初期値「-breakline」）。毎回指定以外は場所を尋ねずに保存し、同名は置き換えず番号を付ける。保存後に「Finderで表示」。

- 1.0.0（build 1, 2026-10-19）：最初の版。
