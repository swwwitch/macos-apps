# PandocDesk help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
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
- 常駐中はDockのアイコンからウインドウを再表示できます。
- アプリ起動のホットキーは、ショートカットAppで「アプリを開く」にPandocDeskを指定して割り当てます。

## ホットキー
- **⌘O**：ファイルを選択
- **⌘Return**：変換
- **Esc**：変換をキャンセル
- **⌘W**：ウインドウを閉じる
- **⌘,**：設定
- **⌘?**：ヘルプ
- **⌘Q**：終了（変換中は終了できません。完了を待つかキャンセルしてください）

## 権限とプライバシー
- アクセシビリティの許可は不要です。
- Keynoteへの変換では、初回に「オートメーション」の許可を求められます。拒否した場合は、システム設定＞プライバシーとセキュリティ＞オートメーションでPandocDeskの「Keynote」をオンにしてください。状態はアプリの設定の「Keynoteの操作」で確認できます。
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
- While it keeps running, reopen the window from the Dock icon.
- For a launch shortcut, create an Open App action for PandocDesk in the Shortcuts app and assign a key.

## Keyboard shortcuts
- **Command-O**: choose files
- **Command-Return**: convert
- **Escape**: cancel the conversion
- **Command-W**: close the window
- **Command-comma**: Settings
- **Command-?**: Help
- **Command-Q**: quit (not during a conversion — wait for it or cancel first)

## Permissions and privacy
- No Accessibility permission is needed.
- Keynote export asks for Automation permission the first time. If you declined, turn on Keynote for PandocDesk in System Settings › Privacy & Security › Automation. Settings › Keynote control shows the status.
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
- 后台运行时，可从 Dock 图标重新显示窗口。
- 启动快捷键：在快捷指令中为 PandocDesk 创建“打开 App”并分配按键。

## 键盘快捷键
- **⌘O**：选择文件
- **⌘Return**：转换
- **Esc**：取消转换
- **⌘W**：关闭窗口
- **⌘,**：设置
- **⌘?**：帮助
- **⌘Q**：退出（转换期间无法退出，请等待完成或先取消）

## 权限与隐私
- 不需要辅助功能权限。
- Keynote 导出首次会请求“自动化”权限。如已拒绝，请在系统设置›隐私与安全性›自动化中为 PandocDesk 打开“Keynote”。可在设置的“控制 Keynote”中查看状态。
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
- 계속 실행 중에는 Dock 아이콘에서 윈도우를 다시 열 수 있습니다.
- 실행 단축키는 단축어 앱에서 PandocDesk를 여는 동작을 만들고 키를 지정하세요.

## 키보드 단축키
- **⌘O**: 파일 선택
- **⌘Return**: 변환
- **Esc**: 변환 취소
- **⌘W**: 윈도우 닫기
- **⌘,**: 설정
- **⌘?**: 도움말
- **⌘Q**: 종료(변환 중에는 종료할 수 없습니다. 완료를 기다리거나 먼저 취소하세요)

## 권한과 개인정보
- 손쉬운 사용 권한은 필요하지 않습니다.
- Keynote로 내보낼 때 처음에 "자동화" 권한을 요청합니다. 거부했다면 시스템 설정 › 개인정보 보호 및 보안 › 자동화에서 PandocDesk의 "Keynote"를 켜세요. 상태는 설정의 "Keynote 제어"에서 확인할 수 있습니다.
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
