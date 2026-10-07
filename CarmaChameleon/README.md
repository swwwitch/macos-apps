# CarmaChameleon（旧名 PandocDesk）

SwiftUI/AppKitによるpandocの非公式ネイティブGUI。Apple Silicon / macOS 13以降。

入力ファイル・出力形式・変換オプションの3カラム。原本保持、連番による上書き回避、非同期変換、取消、部分成功の表示。pandoc 3.12を同梱。PDFは環境設定からTypstを導入可能。既存のXeLaTeX／LuaLaTeXも利用可能。

環境設定でpandocの有無、使用バージョン、パス、最新版との比較を表示。公式GitHub release APIによる明示的な確認、公式SHA-256検証後のユーザー領域インストール、同梱版への復帰を用意。確認前や通信失敗を「最新版」とは表示しない。独自の実行ファイルパスは自分が信頼するpandocのみを指定する。

ビルド: `./build.sh`。共通部品は `../Shared/AppStandards/` を直接使用。LoginAtLaunchとLaunchPolicyはFolderMoverのローカライズ済み実装を再利用。

ライセンス: 同梱pandocはGPL-2.0-or-later。Resources内のCOPYINGとTHIRD-PARTY-NOTICESを参照。対応する上流ソースもSourceArchiveとして同梱。GUIソースもGPL-2.0-or-laterで提供する。

サポート: この開発フォルダのREADMEおよびBASELINE-CHECKLIST。公開問い合わせ先は未設定。
アプリの配信更新・Developer ID署名・公証は未設定。ローカル用ad-hoc署名。診断ログは保存しない。

## 0.1.1 / build 2

環境設定にPDFエンジン（Typst）の有無・版・更新確認・SHA-256検証付きインストールを追加。保存先はユーザー領域の `Application Support/PandocDesk/PDFEngines`。管理者権限は不要。日本語PDFにはHiragino Sansを指定。導入後はTypstを選択し、既存TeX環境は変更しない。MacTeX公式ダウンロードへの導線とXeLaTeX/LuaLaTeX検出も追加。

検証: Typst 0.15.1による日本語PDF生成、目次・見出し番号、PDFKitによる日本語抽出を確認。`./test.sh /path/to/typst` でPDFテストを追加実行できる。

## 0.1.2 / build 3

IDMLのテキスト入力対応を追加。designmap内のストーリー順、段落、直接指定太字/斜体、基本表をHTML経由で変換する。見出しはHeading 1〜6/見出し1〜6というスタイル名から推定。ページ配置・画像・スタイル継承・組版・完全な注釈の再現は非対応。IDML出力は非対応。入力XMLは合計20MBまで。

ZIPはエントリー単位でメモリへ読み、外部パスへ展開しない。XML外部エンティティは解決しない。原本保持・不正パス拒否・空文書拒否をテスト。合成IDMLフィクスチャからMarkdown、Word、PDFへの変換を検証。実際のInDesign出力ファイルによる確認は未実施。

## 0.2.0 / build 4

- 保存先は「元の文書と同じ」が初期値。複数文書は各原本のフォルダへ保存する。「指定」は共通フォルダへ保存する。指定パスと選択を保持する。
- 「変換後にファイルを開く」を追加（初期OFF、設定保持）。ONなら完成したファイルを既定アプリで開く。取消では自動オープンしない。
- PDF入力：PDFKitでテキストを抽出。文字レイヤーのないページはApple Visionによる日本語・英語OCRをローカル実行。段組み・画像・表構造・組版は復元しない。空白/読取不能ページを黙って落とさずエラー表示。保護PDFを拒否。500ページ・20MB上限。
- IDML出力：pandocの本文テキストからA4の編集用テキストフレームを持つIDMLを生成。1ページ40行、1行42文字までの簡易配置。元のスタイル・表構造・画像・ページ構成は保持しない。ZIP構造・本文往復・複数ページの末尾保持を検証。InDesignでのオープン/編集は操作ツールの不具合により未確認。
- MacTeX公式リンクを https://www.tug.org/mactex/mactex-download.html へ統一。www有無の両方でHTTP 200を確認。

検証：文字付きPDF→Word/IDML、日本語・英語の画像PDF OCR、ロックPDF拒否、取消、IDMLの本文往復、500ページ以内の複数ページIDML、既存10形式の出力、4言語キー一致が成功。GUIでの自動オープンと保存先選択の操作確認は未実施。

## 0.2.1 / build 5

HTML出力に「標準 / minify / beautify」を追加（初期値は標準、選択を保存）。minifyはタグの余分な空白とブロックタグ間の改行を削減、beautifyはブロックタグを改行・字下げする。本文・インライン間の空白・pre/code/textarea・コメント・CSS/JavaScriptは保持し、CSS/JavaScriptの圧縮はしない。

HTMLFormatting.swiftの空白保持、属性値、スクリプト、コード、整形の安定性、pandoc実変換への反映を検証済み。4言語のキー一致と既存形式の回帰テストも通過。

## 0.2.4 / build 8

修正：ログイン起動を一度も登録していないと状態が「見つからない」になり、/Applicationsにあっても「アプリケーションフォルダに移動して再起動してください」と表示していた。実際にアプリケーションフォルダの外にあるときだけ表示し、それ以外は「自動起動はOFFです」と表示する。「PandocDeskについて」の版表記を固定文字列からInfo.plistの読み取りに変更。

## 0.3.0 / build 9

出力形式に「Keynote（.key）」を追加。PDF2Keynoteと同じ処理を共通部品 `Shared/KeynoteExport/`（KeynoteExport.swift・Keynote.applescript）として使う。PDFは各ページをベクターのまま1枚ずつスライドに配置する。PDF以外の文書は選択中のPDFエンジンで一度PDFにしてから変換する（PDFエンジンがない場合は開始前に案内）。スライドサイズ・配置・使用する枠を選択でき、設定は保持。「変換後にファイルを開く」がオンならKeynoteで開いたまま、オフなら保存後に閉じる。同名は既存の「名前 (1)」方式で回避し、取消時は作成中のプレゼンテーションを保存せず閉じる。Keynoteへのオートメーション許可が必要（環境設定に状態表示）。

検証：Markdown→PDF→Keynote、PDF→Keynote、同名の連番、原本保持、取消時に何も書かないことを実機のKeynoteで確認（`PANDOCDESK_KEYNOTE_TEST=1 ./test.sh <typst>`）。既存形式の回帰テストと4言語キーの一致も通過。アプリ画面からの変換と許可ダイアログは未確認。

`make-resources.py` が版番号を固定で書いていたため、Info.plistを再生成すると版が戻る状態だった。0.3.0 / 9 に合わせた。


## 0.3.1 / build 10

UI文言の表記統一：環境設定ウインドウのタイトルから「…」を外す（新キー settingsWindow）、「常駐」→「ウインドウを閉じても常駐」、ON／OFF→オン／オフ、取消→キャンセル（ヘルプ・状態表示）。

## 0.3.2 / build 11

「環境設定」を「設定」に変更（macOS 13以降の表記）。メニューは「設定…」、ウインドウのタイトルは「設定」。

## 0.3.3 / build 12

ヘルプを見出し・箇条書き付きで読みやすく表示（共通部品 HelpDocument）。ヘルプ本文を4言語とも章立てし直した（help_text.py）。ヘルプメニューに「note記事を開く」を追加（Info.plistのSWNoteArticleURL）。

## 0.3.4 / build 13

キー操作の割り当ての呼び名を「ホットキー」に統一（「アプリ起動のホットキー」、ヘルプの見出し）。ショートカットAppに関する記述はそのまま。

## 0.4.0 / build 14

テキスト出力（Plain text）に「構造を保持」を追加。見出し（■●◇などの記号）・箇条書き（・、入れ子は全角スペース、チェックリストは□／■）・リンク（テキストのみ／テキスト <URL>／テキスト (URL)、段落の下にまとめる）・表（タブ区切り／罫線付き）・脚注（※）を読みやすく残す。規則は cssnite.jp/tool/markdown2text.html（note記事 https://note.com/swwwitch/n/n281cc79cdba2 ）をSwiftへ移植（Source/MarkdownToText.swift）。Markdown以外の入力はpandocでGitHub Markdownにしてから同じ規則で変換。設定は保持。

検証：元のJavaScriptとSwift版を4通りのオプションで同じ入力にかけ、出力が完全一致（Tests/markdown2text/run.sh）。Markdown・Word入力の結合テスト、既存形式の回帰テスト、4言語キーの一致も通過。

## 0.4.1 / build 15

アプリ名を PandocDesk から **CarmaChameleon** に変更（pandoc 以外の変換も増えたため）。フォルダ名・アプリ名・実行ファイル名・画面・ヘルプ・README の表記を変更。Bundle ID（jp.local.PandocDesk）、設定、~/Library/Application Support/PandocDesk/（導入した pandoc・Typst）は互換性のためそのまま。対応表は Shared/AppStandards/Records/RENAME-CarmaChameleon-20261007.md。

## 0.4.2 / build 16

入力に Excel（.xlsx）を追加（CSV・TSV は従来どおり pandoc で読み込み）。Excel は独自の取り込み（Source/XLSXImporter.swift）で各シートを表にし、整数は「120」（pandoc 標準の「120.0」にしない）、日付はセルの書式から「2026/10/07」、数式は計算結果の値にする。旧形式の .xls は非対応。

## 0.5.0 / build 17

設定をタブに分類：「起動・常駐」（ログイン起動・常駐・アプリ起動のホットキー・Keynoteの操作）、「変換形式」（メインウインドウに表示する形式と順番。チェックで表示／非表示、ドラッグか↑↓で並べ替え、初期状態に戻す）、「エンジン」（pandoc・PDFエンジン）。非表示にした形式が選択中なら、表示中の先頭の形式に切り替える。少なくとも1つは表示。起動・常駐は共通部品 LaunchPresenceSection を使用。

## 0.6.0 / build 18

入力に Illustrator（.ai）を追加（簡易版）。.ai に入っている PDF 用の内容を PDFKit で読み、PDF 出力ではそのまま PDF にする（Illustrator の編集用データ AIPrivateData は含めない）。Keynote などほかの出力は PDF 入力として扱う。「PDF互換ファイルを作成」オフの .ai は止めずに変換し、案内ページになったことを注意として表示（Source/AIImporter.swift）。

## 0.7.0 / build 19

.ai の正式版「Illustratorで書き出す」を追加。Illustrator でファイルを開き、選んだ PDF プリセットで保存する（Resources/Illustrator/SaveAsPDF.jsx、Adobe のサンプル「ドキュメントを PDF として保存.jsx」をもとに作成、osascript の do javascript で実行）。設定に「Illustrator」タブ（変換方法・使用する Illustrator・PDF プリセットの読み込み）。変換中だけ警告を出さない設定にし、Illustrator で開いているファイルは変換しない。Illustrator 2026（30.8.2）で、プリセット一覧の取得と [高品質印刷] での書き出しを確認（CARMA_ILLUSTRATOR_TEST=1 ./test.sh <typst>）。

## 0.7.1 / build 20

設定の「Illustrator」タブで見出しが二重に表示されていたのを修正。

## 0.7.2 / build 21

ファイルメニューに「メインウインドウを開く」（⌘0）を追加。ウインドウを閉じた後でも主画面を再表示できる。

## 0.7.3 / build 22

「Illustratorで書き出す」を sttk3 の exportPDF（exportForScreens ＋ ExportForScreensPDFOptions.pdfPreset）にならって書き直し。別名保存（saveAs）と違ってドキュメントのファイルや保存先を変えないため、Illustrator で開いている .ai も開いた状態のまま書き出し、閉じない（未保存の変更を含むときは注意を表示）。これまでは開いているファイルを変換しなかった。書き出し中だけ「サブフォルダを作成」をオフにして元に戻す。指定した PDF プリセットが Illustrator に無いとき・CC 2018 より前のときはエラー、リンク切れの画像があるときは注意を表示。# CarmaChameleon（旧名 PandocDesk）

SwiftUI/AppKitによるpandocの非公式ネイティブGUI。Apple Silicon / macOS 13以降。

入力ファイル・出力形式・変換オプションの3カラム。原本保持、連番による上書き回避、非同期変換、取消、部分成功の表示。pandoc 3.12を同梱。PDFは環境設定からTypstを導入可能。既存のXeLaTeX／LuaLaTeXも利用可能。

環境設定でpandocの有無、使用バージョン、パス、最新版との比較を表示。公式GitHub release APIによる明示的な確認、公式SHA-256検証後のユーザー領域インストール、同梱版への復帰を用意。確認前や通信失敗を「最新版」とは表示しない。独自の実行ファイルパスは自分が信頼するpandocのみを指定する。

ビルド: `./build.sh`。共通部品は `../Shared/AppStandards/` を直接使用。LoginAtLaunchとLaunchPolicyはFolderMoverのローカライズ済み実装を再利用。

ライセンス: 同梱pandocはGPL-2.0-or-later。Resources内のCOPYINGとTHIRD-PARTY-NOTICESを参照。対応する上流ソースもSourceArchiveとして同梱。GUIソースもGPL-2.0-or-laterで提供する。

サポート: この開発フォルダのREADMEおよびBASELINE-CHECKLIST。公開問い合わせ先は未設定。
アプリの配信更新・Developer ID署名・公証は未設定。ローカル用ad-hoc署名。診断ログは保存しない。

## 0.1.1 / build 2

環境設定にPDFエンジン（Typst）の有無・版・更新確認・SHA-256検証付きインストールを追加。保存先はユーザー領域の `Application Support/PandocDesk/PDFEngines`。管理者権限は不要。日本語PDFにはHiragino Sansを指定。導入後はTypstを選択し、既存TeX環境は変更しない。MacTeX公式ダウンロードへの導線とXeLaTeX/LuaLaTeX検出も追加。

検証: Typst 0.15.1による日本語PDF生成、目次・見出し番号、PDFKitによる日本語抽出を確認。`./test.sh /path/to/typst` でPDFテストを追加実行できる。

## 0.1.2 / build 3

IDMLのテキスト入力対応を追加。designmap内のストーリー順、段落、直接指定太字/斜体、基本表をHTML経由で変換する。見出しはHeading 1〜6/見出し1〜6というスタイル名から推定。ページ配置・画像・スタイル継承・組版・完全な注釈の再現は非対応。IDML出力は非対応。入力XMLは合計20MBまで。

ZIPはエントリー単位でメモリへ読み、外部パスへ展開しない。XML外部エンティティは解決しない。原本保持・不正パス拒否・空文書拒否をテスト。合成IDMLフィクスチャからMarkdown、Word、PDFへの変換を検証。実際のInDesign出力ファイルによる確認は未実施。

## 0.2.0 / build 4

- 保存先は「元の文書と同じ」が初期値。複数文書は各原本のフォルダへ保存する。「指定」は共通フォルダへ保存する。指定パスと選択を保持する。
- 「変換後にファイルを開く」を追加（初期OFF、設定保持）。ONなら完成したファイルを既定アプリで開く。取消では自動オープンしない。
- PDF入力：PDFKitでテキストを抽出。文字レイヤーのないページはApple Visionによる日本語・英語OCRをローカル実行。段組み・画像・表構造・組版は復元しない。空白/読取不能ページを黙って落とさずエラー表示。保護PDFを拒否。500ページ・20MB上限。
- IDML出力：pandocの本文テキストからA4の編集用テキストフレームを持つIDMLを生成。1ページ40行、1行42文字までの簡易配置。元のスタイル・表構造・画像・ページ構成は保持しない。ZIP構造・本文往復・複数ページの末尾保持を検証。InDesignでのオープン/編集は操作ツールの不具合により未確認。
- MacTeX公式リンクを https://www.tug.org/mactex/mactex-download.html へ統一。www有無の両方でHTTP 200を確認。

検証：文字付きPDF→Word/IDML、日本語・英語の画像PDF OCR、ロックPDF拒否、取消、IDMLの本文往復、500ページ以内の複数ページIDML、既存10形式の出力、4言語キー一致が成功。GUIでの自動オープンと保存先選択の操作確認は未実施。

## 0.2.1 / build 5

HTML出力に「標準 / minify / beautify」を追加（初期値は標準、選択を保存）。minifyはタグの余分な空白とブロックタグ間の改行を削減、beautifyはブロックタグを改行・字下げする。本文・インライン間の空白・pre/code/textarea・コメント・CSS/JavaScriptは保持し、CSS/JavaScriptの圧縮はしない。

HTMLFormatting.swiftの空白保持、属性値、スクリプト、コード、整形の安定性、pandoc実変換への反映を検証済み。4言語のキー一致と既存形式の回帰テストも通過。

## 0.2.4 / build 8

修正：ログイン起動を一度も登録していないと状態が「見つからない」になり、/Applicationsにあっても「アプリケーションフォルダに移動して再起動してください」と表示していた。実際にアプリケーションフォルダの外にあるときだけ表示し、それ以外は「自動起動はOFFです」と表示する。「PandocDeskについて」の版表記を固定文字列からInfo.plistの読み取りに変更。

## 0.3.0 / build 9

出力形式に「Keynote（.key）」を追加。PDF2Keynoteと同じ処理を共通部品 `Shared/KeynoteExport/`（KeynoteExport.swift・Keynote.applescript）として使う。PDFは各ページをベクターのまま1枚ずつスライドに配置する。PDF以外の文書は選択中のPDFエンジンで一度PDFにしてから変換する（PDFエンジンがない場合は開始前に案内）。スライドサイズ・配置・使用する枠を選択でき、設定は保持。「変換後にファイルを開く」がオンならKeynoteで開いたまま、オフなら保存後に閉じる。同名は既存の「名前 (1)」方式で回避し、取消時は作成中のプレゼンテーションを保存せず閉じる。Keynoteへのオートメーション許可が必要（環境設定に状態表示）。

検証：Markdown→PDF→Keynote、PDF→Keynote、同名の連番、原本保持、取消時に何も書かないことを実機のKeynoteで確認（`PANDOCDESK_KEYNOTE_TEST=1 ./test.sh <typst>`）。既存形式の回帰テストと4言語キーの一致も通過。アプリ画面からの変換と許可ダイアログは未確認。

`make-resources.py` が版番号を固定で書いていたため、Info.plistを再生成すると版が戻る状態だった。0.3.0 / 9 に合わせた。


## 0.3.1 / build 10

UI文言の表記統一：環境設定ウインドウのタイトルから「…」を外す（新キー settingsWindow）、「常駐」→「ウインドウを閉じても常駐」、ON／OFF→オン／オフ、取消→キャンセル（ヘルプ・状態表示）。

## 0.3.2 / build 11

「環境設定」を「設定」に変更（macOS 13以降の表記）。メニューは「設定…」、ウインドウのタイトルは「設定」。

## 0.3.3 / build 12

ヘルプを見出し・箇条書き付きで読みやすく表示（共通部品 HelpDocument）。ヘルプ本文を4言語とも章立てし直した（help_text.py）。ヘルプメニューに「note記事を開く」を追加（Info.plistのSWNoteArticleURL）。

## 0.3.4 / build 13

キー操作の割り当ての呼び名を「ホットキー」に統一（「アプリ起動のホットキー」、ヘルプの見出し）。ショートカットAppに関する記述はそのまま。

## 0.4.0 / build 14

テキスト出力（Plain text）に「構造を保持」を追加。見出し（■●◇などの記号）・箇条書き（・、入れ子は全角スペース、チェックリストは□／■）・リンク（テキストのみ／テキスト <URL>／テキスト (URL)、段落の下にまとめる）・表（タブ区切り／罫線付き）・脚注（※）を読みやすく残す。規則は cssnite.jp/tool/markdown2text.html（note記事 https://note.com/swwwitch/n/n281cc79cdba2 ）をSwiftへ移植（Source/MarkdownToText.swift）。Markdown以外の入力はpandocでGitHub Markdownにしてから同じ規則で変換。設定は保持。

検証：元のJavaScriptとSwift版を4通りのオプションで同じ入力にかけ、出力が完全一致（Tests/markdown2text/run.sh）。Markdown・Word入力の結合テスト、既存形式の回帰テスト、4言語キーの一致も通過。

## 0.4.1 / build 15

アプリ名を PandocDesk から **CarmaChameleon** に変更（pandoc 以外の変換も増えたため）。フォルダ名・アプリ名・実行ファイル名・画面・ヘルプ・README の表記を変更。Bundle ID（jp.local.PandocDesk）、設定、~/Library/Application Support/PandocDesk/（導入した pandoc・Typst）は互換性のためそのまま。対応表は Shared/AppStandards/Records/RENAME-CarmaChameleon-20261007.md。

## 0.4.2 / build 16

入力に Excel（.xlsx）を追加（CSV・TSV は従来どおり pandoc で読み込み）。Excel は独自の取り込み（Source/XLSXImporter.swift）で各シートを表にし、整数は「120」（pandoc 標準の「120.0」にしない）、日付はセルの書式から「2026/10/07」、数式は計算結果の値にする。旧形式の .xls は非対応。

## 0.5.0 / build 17

設定をタブに分類：「起動・常駐」（ログイン起動・常駐・アプリ起動のホットキー・Keynoteの操作）、「変換形式」（メインウインドウに表示する形式と順番。チェックで表示／非表示、ドラッグか↑↓で並べ替え、初期状態に戻す）、「エンジン」（pandoc・PDFエンジン）。非表示にした形式が選択中なら、表示中の先頭の形式に切り替える。少なくとも1つは表示。起動・常駐は共通部品 LaunchPresenceSection を使用。

## 0.6.0 / build 18

入力に Illustrator（.ai）を追加（簡易版）。.ai に入っている PDF 用の内容を PDFKit で読み、PDF 出力ではそのまま PDF にする（Illustrator の編集用データ AIPrivateData は含めない）。Keynote などほかの出力は PDF 入力として扱う。「PDF互換ファイルを作成」オフの .ai は止めずに変換し、案内ページになったことを注意として表示（Source/AIImporter.swift）。

## 0.7.0 / build 19

.ai の正式版「Illustratorで書き出す」を追加。Illustrator でファイルを開き、選んだ PDF プリセットで保存する（Resources/Illustrator/SaveAsPDF.jsx、Adobe のサンプル「ドキュメントを PDF として保存.jsx」をもとに作成、osascript の do javascript で実行）。設定に「Illustrator」タブ（変換方法・使用する Illustrator・PDF プリセットの読み込み）。変換中だけ警告を出さない設定にし、Illustrator で開いているファイルは変換しない。Illustrator 2026（30.8.2）で、プリセット一覧の取得と [高品質印刷] での書き出しを確認（CARMA_ILLUSTRATOR_TEST=1 ./test.sh <typst>）。

## 0.7.1 / build 20

設定の「Illustrator」タブで見出しが二重に表示されていたのを修正。

## 0.7.2 / build 21

ファイルメニューに「メインウインドウを開く」（⌘0）を追加。ウインドウを閉じた後でも主画面を再表示できる。

## 0.7.3 / build 22

「Illustratorで書き出す」を sttk3 の exportPDF（exportForScreens ＋ ExportForScreensPDFOptions.pdfPreset）にならって書き直し。別名保存（saveAs）と違ってドキュメントのファイルや保存先を変えないため、Illustrator で開いている .ai も開いた状態のまま書き出し、閉じない（未保存の変更を含むときは注意を表示）。これまでは開いているファイルを変換しなかった。書き出し中だけ「サブフォルダを作成」をオフにして元に戻す。指定した PDF プリセットが Illustrator に無いとき・CC 2018 より前のときはエラー、リンク切れの画像があるときは注意を表示。

## 0.7.4 / build 23

メニューを共通構成にそろえた（アプリメニューに「サービス」「CarmaChameleonを隠す」⌘H・「ほかを隠す」⌥⌘H・「すべてを表示」を追加し、「アップデートを確認…」を「設定…」の後へ移動。ファイルメニューの「閉じる」を「ウインドウを閉じる」に改名し、前に区切りを追加。編集の「すべて選択」を「すべてを選択」に。ヘルプメニューの名前を「ヘルプ」、項目を「CarmaChameleonヘルプ」に。メニューバーの「メインウインドウを表示」を「メインウインドウを開く」に）。

## 0.7.5 / build 24

メニューの共通構成の追加分を反映。編集メニューに「やり直す」（⇧⌘Z）を追加。ヘルプの前に「ウインドウ」メニュー（「しまう」⌘M・「拡大／縮小」・「すべてを手前に移動」とウインドウの一覧）を追加。共通の更新機能（Shared/Updater、Sparkle 2.10.0）を組み込み、アプリメニューの「設定…」の後に「アップデートを確認…」「アップデートを自動確認」を置いた（配信先と署名鍵が未設定の間は準備中と表示し、通信しない）。従来の仮の「アップデートを確認…」は削除。メニューバーアイコンを共通部品MenuBarPresenceに載せ替え、アプリメニューに「メニューバー設定…」、設定の「起動・常駐」に「メニューバーに表示」を追加（従来どおり初期値は表示）。メニューバーのメニューはヘルプとnote記事を「ヘルプ」サブメニューにまとめ、「CarmaChameleonを終了」を最後にした。

## 0.7.6 / build 25

メニューの中国語・韓国語を共通の標準訳語にそろえた（中国語の「コピー」を「拷贝」、韓国語の「CarmaChameleonについて」を「CarmaChameleon에 관하여」、「カット」を「오려두기」、「コピー」を「복사하기」に）。共通の更新機能（Shared/Updater）の中国語・韓国語の表示に対応。

## 0.7.7 / build 26

ウインドウメニューの「しまう」からホットキー⌘Mを外した（BASELINEの「メニューの共通構成」の更新に合わせた）。ヘルプのホットキー一覧からも⌘Mを削除。
