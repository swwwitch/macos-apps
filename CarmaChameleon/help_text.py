# CarmaChameleon help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
'ja': '''## 基本操作
1. 左の枠にファイルをドロップするか、「ファイルを選択…」（⌘O）を押します。
2. 中央で出力形式を、右で入力形式とオプションを選びます。
3. 保存先を確かめて「変換」（⌘Return）を押します。複数のファイルは1つずつ別々に変換します。
4. 完了したら「Finderで表示」で書き出したファイルを確認できます。

## 保存先と原本
- **元の文書と同じ**（初期値）：各原本と同じフォルダに保存します。
- **指定**：選んだ1つのフォルダにまとめて保存します。
- 原本は変更しません。同じ名前のファイルがあるときは番号を付けて保存します。
- 「変換後にファイルを開く」（初期値オフ）をオンにすると、完成したファイルを既定のアプリで開きます。
- キャンセルしても完成済みのファイルは残し、作りかけの一時ファイルは削除します。Undoはないので、不要なファイルはFinderで削除してください。

## 変換オプション
- 目次と見出し番号は、対応している形式でだけ使えます。
- テキスト系の出力では折り返しを選べます。

### PDF出力
- PDFエンジンは同梱していません。設定の「PDFエンジン（Typst）」で「最新版を確認」→「インストール」を押すと導入できます。
- 公式のtar.xzをSHA-256で検証し、~/Library/Application Support/PandocDesk/PDFEngines/ に保存します。管理者権限は不要です。
- インストール済みのXeLaTeX／LuaLaTeXも使えます。MacTeXの公式ダウンロードページを開くボタンもあります。
- 日本語にはHiragino Sansを使います。

### テキスト出力の「構造を保持」
- 出力形式で「Plain text」を選び「構造を保持」をオンにすると、見出し・箇条書き・リンク・表などの構造を記号や字下げで残したテキストにします。
- 見出しは「■」「●」「◇」などの記号付き、箇条書きは「・」、入れ子は全角スペースで字下げ、チェックリストは「□」「■」になります。
- リンクは「テキストのみ」「テキスト <URL>」「テキスト (URL)」から選べ、段落やリスト項目の下にまとめることもできます。表はタブ区切りか罫線付きにできます。
- Markdown以外の文書は、いったんMarkdownにしてから同じ規則で変換します。
- 変換の規則は note記事「Markdownをテキストに変換するツール」（https://note.com/swwwitch/n/n281cc79cdba2）と同じです。

### HTMLの整形
- **標準**（初期値）・**minify**・**beautify** から選べます。選択は保存されます。
- minifyはタグの余分な空白とブロック間の改行を減らし、beautifyはブロックタグを改行・字下げします。
- 本文、pre／code／textarea、CSS、JavaScript、コメントはそのまま残します。CSSとJavaScriptは圧縮しません。

### Keynoteへの変換
- 出力形式で「Keynote」を選ぶと、PDFの各ページをベクターのまま1枚ずつスライドに置いた .key を作ります（Keynoteが必要）。
- PDF以外の文書は、選択中のPDFエンジンで一度PDFにしてから変換します。
- スライドサイズ、配置（全体を収める／スライドを埋める）、使用する枠（CropBox・TrimBoxなど）を選べます。
- ページは画像として置かれるため、Keynote上で文字は編集できません。
- 「変換後にファイルを開く」がオンならKeynoteで開いたままにし、オフなら保存後に閉じます。
- キャンセルすると、作成中のプレゼンテーションは保存せずに閉じます。

## 入力形式の補足
### Illustrator（.ai）
- .ai をPDFに変換できます（簡易版、Illustratorは不要）。出力形式で「PDF」を選ぶと、.ai に入っているPDF用の内容をそのままPDFにします。Illustratorの編集用データは含めないので、元の .ai より小さくなります。
- 「Keynote」を選ぶとアートボードを1枚ずつスライドに、ほかの形式では文字を取り出して変換します。
- Illustratorで「PDF互換ファイルを作成」をオンにして保存した .ai が対象です。オフで保存した .ai は、アートワークの代わりにAdobeの案内ページが変換されるため、注意を表示します。
- **正式版（Illustratorで書き出す）**：設定の「Illustrator」タブか、.ai を追加したときの変換オプションで「Illustratorで書き出す」を選ぶと、Illustratorで選んだPDFプリセットを使って書き出します（「スクリーン用に書き出し」と同じ方法で、元のファイルや保存先は変わりません）。PDF互換なしで保存された .ai も変換できます。
- PDFプリセットは「IllustratorからPDFプリセットを読み込む」で一覧を取得して選びます。使うIllustratorのバージョンも選べます（初期値は最新版）。
- 変換中はIllustratorが起動します。フォントやリンクの警告は変換中だけ表示しません。Illustratorで開いているファイルは、開いている状態のまま書き出し、閉じません（未保存の変更も含まれます。そのときは注意を表示します）。リンク切れの画像があるときも注意を表示します。初回はIllustratorの操作（オートメーション）の許可を求められます。

### 表（CSV・TSV・Excel）
- CSV（.csv）、TSV（.tsv）、Excel（.xlsx）を読み込めます。表として取り込み、Word・HTML・Markdown・PDFなどの表に変換します。
- Excelはブックのシートを順に表として読み込みます。数式は計算結果の値、書式・結合セル・グラフ・画像は再現しません。旧形式の .xls には対応しません。
- テキスト出力で「構造を保持」を使うと、表をタブ区切りか罫線付きにできます。

### PDF
- 文字をそのまま取り出し、文字のないページは日本語・英語のOCRで読み取ります。すべてこのMac上で処理します。
- 画像、段組み、表の構造、組版は再現しません。OCRは読み間違えることがあります。
- 文字を得られないページがあるとエラーにして、途中の結果は保存しません。
- パスワードで保護されたPDFは、解除してから使ってください。上限は500ページ・抽出テキスト20MBです。

### IDML
- InDesignなしで、designmapのストーリー順に本文を取り出します。見た目のページ順は保証しません。
- 段落、直接指定した太字／斜体、基本的な表に対応します。段落スタイル名が「Heading 1〜6」「見出し1〜6」のものは見出しになります。
- 画像、ページ配置、組版、スタイルの継承は再現しません。読み込むXMLは合計20MBまでです。
- IDMLへの書き出しは、A4ページに編集可能な本文テキストを並べたものです。元の書式・表・画像は再現しません。

## pandocの管理
- 設定に、使用中のpandocのバージョン・場所・インストール状態を表示します。
- 「最新版を確認」は公式GitHubに接続します。「最新版をインストール」は公式ZIPをSHA-256で検証して ~/Library/Application Support/PandocDesk/Engines/ に保存します。
- 確認と更新はボタンを押したときだけ行います。独自のpandocも指定でき、「同梱版に戻す」でいつでも戻せます。

## 設定
- **起動・常駐**：ログイン時に起動（初期値オフ）、起動時にメインウインドウを表示しない、ウインドウを閉じても常駐、アプリ起動のホットキー。
- **起動・常駐**タブには、「Keynoteの操作」の許可状態も表示します。
- **変換形式**タブ：メインウインドウに表示する変換形式と、その順番を選べます。チェックを外した形式は一覧に出ません。ドラッグまたは↑↓で並べ替え、「初期状態に戻す」で元に戻せます。
- **エンジン**タブ：pandoc と PDFエンジン（Typst）の状態・更新・独自のパスを設定します。
- 常駐中はDockのアイコンからウインドウを再表示できます。
- アプリ起動のホットキーは、ショートカットAppで「アプリを開く」にCarmaChameleonを指定して割り当てます。

## ホットキー
- **⌘O**：ファイルを選択
- **⌘Return**：変換
- **Esc**：変換をキャンセル
- **⌘0**：メインウインドウを開く（閉じた後も再表示できます）
- **⌘W**：ウインドウを閉じる
- **⌘,**：設定
- **⌘?**：ヘルプ
- **⌘Q**：終了（変換中は終了できません。完了を待つかキャンセルしてください）

## 権限とプライバシー
- アクセシビリティの許可は不要です。
- Keynoteへの変換では、初回に「オートメーション」の許可を求められます。拒否した場合は、システム設定＞プライバシーとセキュリティ＞オートメーションでCarmaChameleonの「Keynote」をオンにしてください。状態はアプリの設定の「Keynoteの操作」で確認できます。
- 文書を外部のサービスへ送りません。ネットワークに接続するのは、pandocやTypstの更新を確認・導入するときだけです。
- エラーは画面に表示するだけで、診断ログは保存しません。

## 困ったとき
- 失敗したときは、表示されたメッセージ、入力形式、保存先のアクセス権を確認してください。
- pandocが見つからないときは、設定で同梱版に戻すか、最新版をインストールしてください。
- ヘルプメニューの「note記事を開く」で、使い方の記事とサポート情報を開けます。
- アプリ自体の自動更新と公証は未設定です。Apple Silicon・macOS 13以降用です。

## 削除
1. 設定でログイン時に起動をオフにします。
2. アプリを終了して、ゴミ箱に入れます。
3. 必要なら ~/Library/Application Support/PandocDesk/ の Engines と PDFEngines も削除します。設定の識別子は jp.local.PandocDesk です。
''',
'en': '''## Basics
1. Drop files on the left, or click Choose files… (Command-O).
2. Choose an output format in the middle, and the input format and options on the right.
3. Check where to save and click Convert (Command-Return). Each file is converted separately.
4. When it finishes, Show in Finder reveals the saved files.

## Saving and originals
- **Same as source document** (default): saves next to each original.
- **Choose a folder**: saves everything into one folder you choose.
- Originals are never changed. Existing names get a number.
- With Open files after conversion on (off by default), finished files open in their default apps.
- Cancel keeps finished files and removes unfinished temporary files. There is no Undo; remove unwanted files in Finder.

## Conversion options
- Table of contents and section numbering are available only for formats that support them.
- Text formats offer wrapping options.

### PDF output
- No PDF engine is bundled. In Settings › PDF engine (Typst), click Check latest version, then Install.
- The official tar.xz is verified with SHA-256 and saved under ~/Library/Application Support/PandocDesk/PDFEngines/. No administrator rights are needed.
- An installed XeLaTeX or LuaLaTeX also works; a button opens the official MacTeX download page.
- Japanese text uses Hiragino Sans.

### Keep structure (plain text)
- Choose Plain text and turn on Keep structure to keep headings, lists, links and tables readable with marks and indents.
- Headings get marks such as ■ ● ◇, list items start with ・, nested items are indented with full-width spaces, and checklists become □ / ■.
- Links can be text only, Text <URL> or Text (URL), and can be collected below each paragraph or list item. Tables can be tab-separated or bordered.
- Documents other than Markdown are first converted to Markdown, then the same rules apply.
- The rules follow the note article (Japanese): https://note.com/swwwitch/n/n281cc79cdba2

### HTML formatting
- Choose **Standard** (default), **minify** or **beautify**. The choice is remembered.
- minify trims extra spaces inside tags and line breaks between blocks; beautify puts block tags on their own lines with indentation.
- Text, pre/code/textarea, CSS, JavaScript and comments are kept as is. CSS and JavaScript are not minified.

### Keynote export
- Choose Keynote as the output format to create a .key with each PDF page on its own slide, kept as vector artwork (Keynote required).
- Other documents are first typeset to PDF with the selected PDF engine.
- Choose the slide size, placement (fit or fill) and page box (CropBox, TrimBox and more).
- Pages are placed as images, so their text cannot be edited in Keynote.
- With Open files after conversion on, the presentation stays open in Keynote; otherwise it is closed after saving.
- Cancel closes the unfinished presentation without saving.

## Notes on input formats
### Illustrator (.ai)
- .ai files can be converted to PDF (simple version, no Illustrator needed). With PDF as the output format, the PDF content stored in the .ai becomes the PDF as is. Illustrator's editing data is left out, so the PDF is smaller than the .ai.
- With Keynote, each artboard becomes a slide; other formats extract the text.
- This works for .ai files saved with "Create PDF Compatible File" on. Files saved with it off produce Adobe's notice page instead of the artwork, and a warning is shown.
- **Full version (Export with Illustrator)**: choose it in Settings › Illustrator or in the options shown when .ai files are added. Illustrator exports each file with the chosen PDF preset (the same way as Export for Screens; the original file and its save location are not changed). .ai files saved without PDF compatibility work too.
- Use Load PDF presets from Illustrator to list the presets, then pick one. You can also choose which Illustrator to use (newest by default).
- Illustrator runs during conversion; font and link alerts are suppressed only while converting. Files already open in Illustrator are exported as they are and stay open (unsaved changes are included, with a notice). Missing linked images also give a notice. The first run asks for Automation permission to control Illustrator.

### Tables (CSV, TSV, Excel)
- CSV (.csv), TSV (.tsv) and Excel (.xlsx) files are read as tables and converted to tables in Word, HTML, Markdown, PDF and other formats.
- Each sheet of an Excel workbook becomes a table in order. Formulas give their calculated values; formatting, merged cells, charts and images are not reproduced. The older .xls format is not supported.
- With Keep structure for plain text, tables can be tab-separated or bordered.

### PDF
- Text is extracted directly; pages without text are read with Japanese/English OCR, all on this Mac.
- Images, columns, table structure and layout are not reproduced. OCR can make mistakes.
- If a page yields no text, conversion stops with an error and no partial result is saved.
- Unlock password-protected PDFs first. Limit: 500 pages and 20 MB of extracted text.

### IDML
- Text is extracted without InDesign, in designmap story order; visual page order is not guaranteed.
- Paragraphs, directly applied bold/italic and basic tables are supported. Paragraph styles named Heading 1–6 or 見出し1–6 become headings.
- Images, page layout, typesetting and inherited styles are not reproduced. Input XML is limited to 20 MB in total.
- IDML export lays out editable body text on A4 pages, without the original formatting, tables or images.

## Managing pandoc
- Settings shows the pandoc version, location and installation status in use.
- Check latest version contacts the official GitHub. Install latest version verifies the official ZIP with SHA-256 and saves it under ~/Library/Application Support/PandocDesk/Engines/.
- Checks and updates run only when you click a button. You can choose your own pandoc, and Use bundled version switches back at any time.

## Settings
- **Startup & Background**: Launch at login (off by default), hide main window at startup, keep running after closing, and the app launch keyboard shortcut.
- The **Startup & Background** tab also shows the Keynote control permission.
- **Output format** tab: choose which output formats appear in the main window and in what order. Unchecked formats are hidden. Drag or use ↑↓ to reorder; Restore defaults puts everything back.
- **Engines** tab: status, updates and custom paths for pandoc and the PDF engine (Typst).
- While it keeps running, reopen the window from the Dock icon.
- For a launch shortcut, create an Open App action for CarmaChameleon in the Shortcuts app and assign a key.

## Keyboard shortcuts
- **Command-O**: choose files
- **Command-Return**: convert
- **Escape**: cancel the conversion
- **Command-0**: open the main window (also after closing it)
- **Command-W**: close the window
- **Command-comma**: Settings
- **Command-?**: Help
- **Command-Q**: quit (not during a conversion — wait for it or cancel first)

## Permissions and privacy
- No Accessibility permission is needed.
- Keynote export asks for Automation permission the first time. If you declined, turn on Keynote for CarmaChameleon in System Settings › Privacy & Security › Automation. Settings › Keynote control shows the status.
- Documents are never sent to an external service. The app goes online only to check for or install pandoc and Typst updates.
- Errors are shown on screen only; no diagnostic log is saved.

## Troubleshooting
- If a conversion fails, check the message, the input format and access to the destination folder.
- If pandoc is missing, use the bundled version or install the latest one in Settings.
- Help › Open the note Article opens the article with usage notes and support information.
- Automatic app updates and notarization are not set up. Requires Apple Silicon and macOS 13 or later.

## Removing
1. Turn off Launch at login in Settings.
2. Quit the app and move it to the Trash.
3. Optionally delete Engines and PDFEngines in ~/Library/Application Support/PandocDesk/. The preferences identifier is jp.local.PandocDesk.
''',
'zh-Hans': '''## 基本操作
1. 将文件拖到左侧，或点击“选择文件…”（⌘O）。
2. 在中间选择输出格式，在右侧选择输入格式和选项。
3. 确认保存位置后点击“转换”（⌘Return）。多个文件会分别转换。
4. 完成后，“在 Finder 中显示”可查看保存的文件。

## 保存位置与原文件
- **与原文档相同**（默认）：保存在各原文件所在的文件夹。
- **指定**：全部保存到所选的一个文件夹。
- 不修改原文件。同名文件会添加编号。
- 开启“转换后打开文件”（默认关闭）后，完成的文件会用默认应用打开。
- 取消时保留已完成的文件，删除未完成的临时文件。不支持撤销，请在 Finder 中删除不需要的文件。

## 转换选项
- 目录和章节编号仅在支持的格式中可用。
- 文本格式可选择换行方式。

### PDF 输出
- 未内置 PDF 引擎。请在设置的“PDF 引擎（Typst）”中点击“检查最新版本”，然后点击“安装”。
- 官方 tar.xz 经 SHA-256 验证后保存到 ~/Library/Application Support/PandocDesk/PDFEngines/，无需管理员权限。
- 也可使用已安装的 XeLaTeX 或 LuaLaTeX，并提供打开 MacTeX 官方下载页面的按钮。
- 日文使用 Hiragino Sans。

### 纯文本的“保留结构”
- 选择 Plain text 并打开“保留结构”，即可用符号和缩进保留标题、列表、链接和表格等结构。
- 标题加上 ■ ● ◇ 等符号，列表项以“・”开头，嵌套项用全角空格缩进，复选框变为 □ / ■。
- 链接可选择“仅文本”“文本 <URL>”“文本 (URL)”，也可汇总到段落或列表项下方。表格可为制表符分隔或带边框。
- 非 Markdown 文档会先转换为 Markdown，再按相同规则转换。
- 规则与 note 文章（日语）相同：https://note.com/swwwitch/n/n281cc79cdba2

### HTML 格式
- 可选择 **标准**（默认）、**minify** 或 **beautify**，选择会被记住。
- minify 删除标签内多余空白和块之间的换行；beautify 让块标签换行并缩进。
- 正文、pre/code/textarea、CSS、JavaScript 和注释保持不变，不压缩 CSS 和 JavaScript。

### Keynote 导出
- 选择 Keynote 输出格式，可将 PDF 每页以矢量图放到单独的幻灯片上并生成 .key（需要 Keynote）。
- 其他文档先用所选 PDF 引擎生成 PDF。
- 可选择幻灯片尺寸、放置方式（完整显示／填满）和页面框（CropBox、TrimBox 等）。
- 页面以图像放置，不能在 Keynote 中编辑文字。
- 开启“转换后打开文件”时在 Keynote 中保持打开，否则保存后关闭。
- 取消时不保存未完成的演示文稿并将其关闭。

## 输入格式说明
### Illustrator（.ai）
- 可将 .ai 转换为 PDF（简易版，无需 Illustrator）。输出格式选择“PDF”时，直接将 .ai 中保存的 PDF 内容生成 PDF。不包含 Illustrator 的编辑数据，因此比原 .ai 小。
- 选择“Keynote”时每个画板成为一张幻灯片；其他格式提取文字后转换。
- 适用于勾选“创建 PDF 兼容文件”保存的 .ai。未勾选保存的文件会转换为 Adobe 的提示页而非图稿，并显示提醒。
- **正式版（用 Illustrator 导出）**：在设置的“Illustrator”标签或添加 .ai 时的转换选项中选择后，由 Illustrator 用所选 PDF 预设导出（与“导出为多种屏幕所用格式”相同，不改变原文件及其保存位置）。未勾选 PDF 兼容的 .ai 也能转换。
- 用“从 Illustrator 读取 PDF 预设”获取列表后选择预设。也可选择使用哪个版本的 Illustrator（默认最新）。
- 转换期间会启动 Illustrator，仅在转换时不显示字体和链接警告。已在 Illustrator 中打开的文件按当前状态导出，不会关闭（包含未保存的更改，并显示提示）。有缺失的链接图像时也会显示提示。首次使用会请求控制 Illustrator 的自动化权限。

### 表格（CSV、TSV、Excel）
- 可读取 CSV（.csv）、TSV（.tsv）和 Excel（.xlsx），作为表格转换为 Word、HTML、Markdown、PDF 等格式的表格。
- Excel 工作簿的各工作表按顺序转换为表格。公式取计算结果；不重现格式、合并单元格、图表和图像。不支持旧的 .xls 格式。
- 纯文本使用“保留结构”时，表格可为制表符分隔或带边框。

### PDF
- 直接提取文字；没有文字的页面使用日语/英语 OCR 识别，全部在本机处理。
- 不重现图像、分栏、表格结构和排版。OCR 可能识别错误。
- 如有无法取得文字的页面，会报错且不保存中间结果。
- 受密码保护的 PDF 请先解除保护。上限为 500 页、提取文本 20MB。

### IDML
- 无需 InDesign，按 designmap 的故事顺序提取正文，不保证视觉页面顺序。
- 支持段落、直接指定的粗体/斜体和基本表格。段落样式名为 Heading 1–6 或 見出し1–6 的会成为标题。
- 不重现图像、页面布局、排版和样式继承。读取的 XML 合计上限为 20MB。
- 导出 IDML 时，会在 A4 页面上排列可编辑的正文文本，不保留原格式、表格和图像。

## 管理 pandoc
- 设置中显示正在使用的 pandoc 的版本、位置和安装状态。
- “检查最新版本”会连接官方 GitHub。“安装最新版本”会用 SHA-256 验证官方 ZIP 并保存到 ~/Library/Application Support/PandocDesk/Engines/。
- 仅在点击按钮时检查和更新。可指定自己的 pandoc，并可随时用“恢复内置版本”切换回来。

## 设置
- **启动与后台**：登录时启动（默认关闭）、启动时不显示主窗口、关闭窗口后继续运行、启动应用快捷键。
- **启动与后台**标签也显示“控制 Keynote”的权限状态。
- **输出格式**标签：选择主窗口显示哪些输出格式及其顺序。取消勾选的格式不显示。可拖动或用 ↑↓ 排序，“恢复默认”可还原。
- **引擎**标签：pandoc 和 PDF 引擎（Typst）的状态、更新和自定义路径。
- 后台运行时，可从 Dock 图标重新显示窗口。
- 启动快捷键：在快捷指令中为 CarmaChameleon 创建“打开 App”并分配按键。

## 键盘快捷键
- **⌘O**：选择文件
- **⌘Return**：转换
- **Esc**：取消转换
- **⌘0**：打开主窗口（关闭后也可重新显示）
- **⌘W**：关闭窗口
- **⌘,**：设置
- **⌘?**：帮助
- **⌘Q**：退出（转换期间无法退出，请等待完成或先取消）

## 权限与隐私
- 不需要辅助功能权限。
- Keynote 导出首次会请求“自动化”权限。如已拒绝，请在系统设置›隐私与安全性›自动化中为 CarmaChameleon 打开“Keynote”。可在设置的“控制 Keynote”中查看状态。
- 文档不会发送到外部服务。仅在检查或安装 pandoc、Typst 更新时联网。
- 错误只显示在屏幕上，不保存诊断日志。

## 故障排除
- 转换失败时，请检查提示信息、输入格式和保存位置的访问权限。
- 找不到 pandoc 时，请在设置中恢复内置版本或安装最新版本。
- “帮助”菜单中的“打开 note 文章”可打开使用说明和支持信息。
- 应用自动更新和公证尚未配置。需要 Apple Silicon 和 macOS 13 或更高版本。

## 删除
1. 在设置中关闭“登录时启动”。
2. 退出应用并将其移到废纸篓。
3. 如有需要，删除 ~/Library/Application Support/PandocDesk/ 中的 Engines 和 PDFEngines。设置标识符为 jp.local.PandocDesk。
''',
'ko': '''## 기본 사용법
1. 왼쪽에 파일을 드롭하거나 "파일 선택…"(⌘O)을 누르세요.
2. 가운데에서 출력 형식을, 오른쪽에서 입력 형식과 옵션을 선택하세요.
3. 저장 위치를 확인하고 "변환"(⌘Return)을 누르세요. 여러 파일은 하나씩 따로 변환합니다.
4. 완료되면 "Finder에서 보기"로 저장된 파일을 확인할 수 있습니다.

## 저장 위치와 원본
- **원본 문서와 동일**(기본값): 각 원본과 같은 폴더에 저장합니다.
- **지정**: 선택한 하나의 폴더에 모두 저장합니다.
- 원본은 변경하지 않습니다. 같은 이름이 있으면 번호를 붙여 저장합니다.
- "변환 후 파일 열기"(기본값 끔)를 켜면 완료된 파일을 기본 앱에서 엽니다.
- 취소해도 완료된 파일은 남기고 미완성 임시 파일은 삭제합니다. 실행 취소는 없으므로 필요 없는 파일은 Finder에서 삭제하세요.

## 변환 옵션
- 목차와 제목 번호는 지원하는 형식에서만 사용할 수 있습니다.
- 텍스트 형식은 줄 바꿈 방식을 선택할 수 있습니다.

### PDF 출력
- PDF 엔진은 포함되어 있지 않습니다. 설정의 "PDF 엔진(Typst)"에서 "최신 버전 확인" 후 "설치"를 누르세요.
- 공식 tar.xz를 SHA-256으로 검증한 후 ~/Library/Application Support/PandocDesk/PDFEngines/에 저장합니다. 관리자 권한은 필요하지 않습니다.
- 설치된 XeLaTeX 또는 LuaLaTeX도 사용할 수 있으며 MacTeX 공식 다운로드 페이지를 여는 버튼도 있습니다.
- 일본어는 Hiragino Sans를 사용합니다.

### 일반 텍스트의 "구조 유지"
- Plain text를 선택하고 "구조 유지"를 켜면 제목, 목록, 링크, 표 등의 구조를 기호와 들여쓰기로 읽기 쉽게 유지합니다.
- 제목에는 ■ ● ◇ 등의 기호가 붙고, 목록은 "・"로 시작하며, 중첩 항목은 전각 공백으로 들여쓰고, 체크리스트는 □ / ■가 됩니다.
- 링크는 "텍스트만", "텍스트 <URL>", "텍스트 (URL)" 중에서 고를 수 있고 문단이나 목록 항목 아래에 모을 수도 있습니다. 표는 탭 구분 또는 테두리 포함으로 만들 수 있습니다.
- Markdown이 아닌 문서는 먼저 Markdown으로 변환한 후 같은 규칙을 적용합니다.
- 규칙은 note 글(일본어)과 같습니다: https://note.com/swwwitch/n/n281cc79cdba2

### HTML 서식
- **기본**(기본값), **minify**, **beautify** 중에서 선택하며 선택은 저장됩니다.
- minify는 태그 안의 불필요한 공백과 블록 사이의 줄 바꿈을 줄이고, beautify는 블록 태그를 줄 바꿈하고 들여씁니다.
- 본문, pre/code/textarea, CSS, JavaScript, 주석은 그대로 유지하며 CSS와 JavaScript는 압축하지 않습니다.

### Keynote 내보내기
- 출력 형식에서 Keynote를 선택하면 PDF 각 페이지를 벡터 그대로 슬라이드에 하나씩 배치한 .key를 만듭니다(Keynote 필요).
- PDF가 아닌 문서는 선택한 PDF 엔진으로 먼저 PDF로 만든 후 변환합니다.
- 슬라이드 크기, 배치(전체 맞춤/슬라이드 채우기), 페이지 상자(CropBox, TrimBox 등)를 선택할 수 있습니다.
- 페이지는 이미지로 배치되므로 Keynote에서 텍스트를 편집할 수 없습니다.
- "변환 후 파일 열기"가 켜져 있으면 Keynote에서 열어 두고, 꺼져 있으면 저장 후 닫습니다.
- 취소하면 만드는 중인 프레젠테이션을 저장하지 않고 닫습니다.

## 입력 형식 참고
### Illustrator(.ai)
- .ai를 PDF로 변환할 수 있습니다(간이 버전, Illustrator 불필요). 출력 형식에서 "PDF"를 선택하면 .ai에 저장된 PDF용 내용을 그대로 PDF로 만듭니다. Illustrator 편집 데이터는 포함하지 않으므로 원래 .ai보다 작아집니다.
- "Keynote"를 선택하면 아트보드마다 슬라이드가 되고, 다른 형식은 텍스트를 추출해 변환합니다.
- "PDF 호환 파일 만들기"를 켜고 저장한 .ai가 대상입니다. 끄고 저장한 파일은 아트워크 대신 Adobe 안내 페이지가 변환되며 주의를 표시합니다.
- **정식 버전(Illustrator로 내보내기)**: 설정의 "Illustrator" 탭이나 .ai를 추가했을 때의 변환 옵션에서 선택하면 Illustrator가 선택한 PDF 사전 설정으로 내보냅니다("화면용으로 내보내기"와 같은 방식이며 원본 파일과 저장 위치는 바뀌지 않습니다). PDF 호환 없이 저장된 .ai도 변환할 수 있습니다.
- "Illustrator에서 PDF 사전 설정 불러오기"로 목록을 가져와 선택합니다. 사용할 Illustrator 버전도 고를 수 있습니다(기본값은 최신).
- 변환 중에는 Illustrator가 실행되며 글꼴·링크 경고는 변환 중에만 표시하지 않습니다. Illustrator에서 열려 있는 파일은 현재 상태 그대로 내보내며 닫지 않습니다(저장하지 않은 변경 사항도 포함되며 안내를 표시합니다). 링크가 끊어진 이미지가 있을 때도 안내를 표시합니다. 처음에는 Illustrator 제어(자동화) 허용을 요청합니다.

### 표(CSV, TSV, Excel)
- CSV(.csv), TSV(.tsv), Excel(.xlsx)을 표로 읽어 Word, HTML, Markdown, PDF 등의 표로 변환합니다.
- Excel 통합 문서의 각 시트를 순서대로 표로 읽습니다. 수식은 계산 결과 값을 사용하며 서식, 병합 셀, 차트, 이미지는 재현하지 않습니다. 이전 .xls 형식은 지원하지 않습니다.
- 일반 텍스트에서 "구조 유지"를 사용하면 표를 탭 구분 또는 테두리 포함으로 만들 수 있습니다.

### PDF
- 텍스트를 그대로 추출하고, 텍스트가 없는 페이지는 일본어/영어 OCR로 읽습니다. 모두 이 Mac에서 처리합니다.
- 이미지, 단 구성, 표 구조, 조판은 재현하지 않습니다. OCR은 잘못 읽을 수 있습니다.
- 텍스트를 얻을 수 없는 페이지가 있으면 오류로 처리하고 중간 결과를 저장하지 않습니다.
- 암호로 보호된 PDF는 먼저 해제하세요. 최대 500페이지, 추출 텍스트 20MB입니다.

### IDML
- InDesign 없이 designmap의 스토리 순서로 본문을 추출합니다. 시각적 페이지 순서는 보장하지 않습니다.
- 문단, 직접 지정한 굵게/기울임, 기본 표를 지원합니다. 문단 스타일 이름이 Heading 1–6 또는 見出し1–6이면 제목이 됩니다.
- 이미지, 페이지 배치, 조판, 스타일 상속은 재현하지 않습니다. 읽는 XML은 합계 20MB까지입니다.
- IDML로 내보내면 A4 페이지에 편집 가능한 본문 텍스트를 배치합니다. 원래 서식, 표, 이미지는 재현하지 않습니다.

## pandoc 관리
- 설정에 사용 중인 pandoc의 버전, 위치, 설치 상태를 표시합니다.
- "최신 버전 확인"은 공식 GitHub에 연결합니다. "최신 버전 설치"는 공식 ZIP을 SHA-256으로 검증한 후 ~/Library/Application Support/PandocDesk/Engines/에 저장합니다.
- 확인과 업데이트는 버튼을 누를 때만 실행합니다. 직접 지정한 pandoc도 사용할 수 있으며 "포함된 버전 사용"으로 언제든 되돌릴 수 있습니다.

## 설정
- **시작 및 백그라운드**: 로그인 시 실행(기본값 끔), 시작 시 메인 윈도우 표시 안 함, 창을 닫아도 계속 실행, 앱 실행 키보드 단축키.
- **시작 및 백그라운드** 탭에는 "Keynote 제어" 권한 상태도 표시됩니다.
- **출력 형식** 탭: 메인 윈도우에 표시할 출력 형식과 순서를 고릅니다. 선택을 해제한 형식은 표시되지 않습니다. 드래그하거나 ↑↓로 순서를 바꾸고 "기본값으로 복원"으로 되돌릴 수 있습니다.
- **엔진** 탭: pandoc과 PDF 엔진(Typst)의 상태, 업데이트, 사용자 경로를 설정합니다.
- 계속 실행 중에는 Dock 아이콘에서 윈도우를 다시 열 수 있습니다.
- 실행 단축키는 단축어 앱에서 CarmaChameleon를 여는 동작을 만들고 키를 지정하세요.

## 키보드 단축키
- **⌘O**: 파일 선택
- **⌘Return**: 변환
- **Esc**: 변환 취소
- **⌘0**: 메인 윈도우 열기(닫은 후에도 다시 표시)
- **⌘W**: 윈도우 닫기
- **⌘,**: 설정
- **⌘?**: 도움말
- **⌘Q**: 종료(변환 중에는 종료할 수 없습니다. 완료를 기다리거나 먼저 취소하세요)

## 권한과 개인정보
- 손쉬운 사용 권한은 필요하지 않습니다.
- Keynote로 내보낼 때 처음에 "자동화" 권한을 요청합니다. 거부했다면 시스템 설정 › 개인정보 보호 및 보안 › 자동화에서 CarmaChameleon의 "Keynote"를 켜세요. 상태는 설정의 "Keynote 제어"에서 확인할 수 있습니다.
- 문서를 외부 서비스로 보내지 않습니다. pandoc과 Typst 업데이트를 확인하거나 설치할 때만 네트워크에 연결합니다.
- 오류는 화면에만 표시하며 진단 로그를 저장하지 않습니다.

## 문제 해결
- 변환에 실패하면 표시된 메시지, 입력 형식, 저장 위치의 접근 권한을 확인하세요.
- pandoc을 찾을 수 없으면 설정에서 포함된 버전으로 되돌리거나 최신 버전을 설치하세요.
- 도움말 메뉴의 "note 글 열기"에서 사용법과 지원 정보를 볼 수 있습니다.
- 앱 자동 업데이트와 공증은 설정되어 있지 않습니다. Apple Silicon, macOS 13 이상이 필요합니다.

## 삭제
1. 설정에서 로그인 시 실행을 끄세요.
2. 앱을 종료하고 휴지통으로 옮기세요.
3. 필요하면 ~/Library/Application Support/PandocDesk/의 Engines와 PDFEngines도 삭제하세요. 설정 식별자는 jp.local.PandocDesk입니다.
''',
}
