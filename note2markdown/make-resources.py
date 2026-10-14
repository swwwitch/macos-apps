from pathlib import Path
import json, plistlib
root = Path(__file__).resolve().parent
LANGS = ['ja', 'en', 'zh-Hans', 'ko']
rows = [
('headline', 'note記事をMarkdownに書き出す', 'Export a note article as Markdown', '将 note 文章导出为 Markdown', 'note 글을 Markdown으로 내보내기'),
('subtitle', '記事のURLを入力すると、タイトルを見出し1にしたMarkdownファイルに書き出します。', 'Enter the article URL to write it to a Markdown file with the title as a level-1 heading.', '输入文章 URL，将其写入以标题为一级标题的 Markdown 文件。', '글 URL을 입력하면 제목을 제목 1로 한 Markdown 파일로 내보냅니다.'),
('urlPlaceholder', 'https://note.com/ユーザー名/n/n0123456789ab', 'https://note.com/username/n/n0123456789ab', 'https://note.com/用户名/n/n0123456789ab', 'https://note.com/사용자이름/n/n0123456789ab'),
('urlLabel', 'note記事のURL', 'note article URL', 'note 文章 URL', 'note 글 URL'),
('clearURL', 'URLを消去', 'Clear URL', '清除 URL', 'URL 지우기'),
('load', '読み込む', 'Load', '载入', '불러오기'),
('cancel', 'キャンセル', 'Cancel', '取消', '취소'),
('export', '書き出す…', 'Export…', '导出…', '내보내기…'),
('copyMarkdown', 'Markdownをコピー', 'Copy Markdown', '拷贝 Markdown', 'Markdown 복사하기'),
('fromBrowser', 'ブラウザーから', 'From Browser', '从浏览器', '브라우저에서'),
('fromBrowserHelp', '最前面のブラウザーで表示中のnote記事を読み込みます', 'Load the note article shown in the front browser window', '载入最前面浏览器中显示的 note 文章', '맨 앞 브라우저에 표시된 note 글을 불러옵니다'),
('fromBrowserMenu', '最前面のブラウザーから読み込む', 'Load from Front Browser', '从最前面的浏览器载入', '맨 앞 브라우저에서 불러오기'),
('errorNoAccess', '「ブラウザーから」にはアクセシビリティの許可が必要です。システム設定で note2markdown を許可してください。', 'From Browser needs the Accessibility permission. Allow note2markdown in System Settings.', '“从浏览器”需要辅助功能权限。请在系统设置中允许 note2markdown。', '브라우저에서를 사용하려면 손쉬운 사용 권한이 필요합니다. 시스템 설정에서 note2markdown을 허용하세요.'),
('errorNoBrowser', '開いているブラウザーのウインドウが見つかりません。', 'No open browser window was found.', '找不到打开的浏览器窗口。', '열려 있는 브라우저 윈도우를 찾을 수 없습니다.'),
('errorNoBrowserURL', '%@ で表示中のページのURLを読み取れませんでした。', 'Could not read the URL of the page in %@.', '无法读取 %@ 中页面的 URL。', '%@에 표시된 페이지의 URL을 읽을 수 없습니다.'),
('errorBrowserNotNote', '%1$@ で表示中のページはnote記事ではありません：%2$@', 'The page in %1$@ is not a note article: %2$@', '%1$@ 中的页面不是 note 文章：%2$@', '%1$@에 표시된 페이지는 note 글이 아닙니다: %2$@'),
('errorDropNotNote', 'ドロップしたものはnote記事のURLではありません：%@', 'What you dropped is not a note article URL: %@', '拖放的内容不是 note 文章 URL：%@', '드롭한 항목은 note 글 URL이 아닙니다: %@'),
('dropLabel', 'Markdownのプレビュー（note記事のURLをドロップして読み込み）', 'Markdown preview (drop a note article URL to load it)', 'Markdown 预览（拖放 note 文章 URL 以载入）', 'Markdown 미리 보기(note 글 URL을 드롭하여 불러오기)'),
('loadMenu', '記事を読み込む', 'Load Article', '载入文章', '글 불러오기'),
('exportMenu', 'Markdownを書き出す…', 'Export Markdown…', '导出 Markdown…', 'Markdown 내보내기…'),
('exportTitle', 'Markdownを書き出す', 'Export Markdown', '导出 Markdown', 'Markdown 내보내기'),
('revealInFinder', 'Finderで表示', 'Show in Finder', '在访达中显示', 'Finder에서 보기'),
('previewLabel', 'Markdownのプレビュー', 'Markdown preview', 'Markdown 预览', 'Markdown 미리 보기'),
('emptyPreview', 'note記事のURLを入力して⌘Returnを押すと、ここにMarkdownが表示されます。\nブラウザーのアドレスバーのアイコン（ファビコン）をここへドラッグ＆ドロップしても読み込めます。', 'Enter a note article URL and press ⌘Return to see the Markdown here.\nYou can also drag the icon (favicon) in the browser’s address bar here.', '输入 note 文章 URL 并按 ⌘Return，Markdown 将显示在这里。\n也可以将浏览器地址栏中的图标（网站图标）拖放到这里。', 'note 글 URL을 입력하고 ⌘Return을 누르면 여기에 Markdown이 표시됩니다.\n브라우저 주소 막대의 아이콘(파비콘)을 여기로 드래그 앤 드롭해도 불러올 수 있습니다.'),
('statusLoading', '読み込み中…', 'Loading…', '正在载入…', '불러오는 중…'),
('statusLoaded', '読み込みました：%@', 'Loaded: %@', '已载入：%@', '불러왔습니다: %@'),
('statusPaid', '有料記事です。無料で読める部分だけを書き出します。', 'This is a paid article. Only the free part is exported.', '这是付费文章。仅导出免费部分。', '유료 글입니다. 무료로 읽을 수 있는 부분만 내보냅니다.'),
('statusSaved', '書き出しました：%@', 'Exported: %@', '已导出：%@', '내보냈습니다: %@'),
('statusCopied', 'Markdownをクリップボードにコピーしました。', 'Markdown copied to the clipboard.', '已将 Markdown 拷贝到剪贴板。', 'Markdown을 클립보드에 복사했습니다.'),
('errorEmpty', 'note記事のURLを入力してください。', 'Enter a note article URL.', '请输入 note 文章 URL。', 'note 글 URL을 입력하세요.'),
('errorInvalidURL', 'note記事のURLではありません。「https://note.com/ユーザー名/n/n…」の形で入力してください。', 'This is not a note article URL. Enter it as https://note.com/username/n/n…', '这不是 note 文章 URL。请按“https://note.com/用户名/n/n…”格式输入。', 'note 글 URL이 아닙니다. https://note.com/사용자이름/n/n… 형식으로 입력하세요.'),
('errorNotFound', '記事が見つかりません。URLが正しいか、記事が公開されているか確認してください。', 'The article was not found. Check the URL and that the article is published.', '找不到文章。请检查 URL 是否正确以及文章是否已发布。', '글을 찾을 수 없습니다. URL이 올바른지, 글이 공개되어 있는지 확인하세요.'),
('errorForbidden', 'この記事は読み込めません（非公開・下書き・メンバー限定など）。', 'This article cannot be loaded (private, draft or members-only).', '无法载入此文章（未公开、草稿或仅限会员等）。', '이 글은 불러올 수 없습니다(비공개, 임시 저장, 멤버 전용 등).'),
('errorNoBody', 'この記事には書き出せる本文がありません（画像・つぶやき・動画などの記事）。', 'This article has no text body to export (image, talk or video posts).', '此文章没有可导出的正文（图片、碎碎念、视频等）。', '이 글에는 내보낼 본문이 없습니다(이미지, 중얼거림, 동영상 등).'),
('errorResponse', 'noteから予期しない応答がありました（%ld）。時間をおいて試してください。', 'Unexpected response from note (%ld). Try again later.', 'note 返回了意外的响应（%ld）。请稍后再试。', 'note에서 예상치 못한 응답이 왔습니다(%ld). 잠시 후 다시 시도하세요.'),
('errorNetwork', 'noteに接続できませんでした：', 'Could not connect to note: ', '无法连接到 note：', 'note에 연결할 수 없습니다: '),
('errorWrite', '書き出せませんでした：', 'Could not export: ', '无法导出：', '내보낼 수 없습니다: '),
('noteLinkText', 'note記事へのリンク', 'Link to the note article', 'note 文章链接', 'note 글 링크'),
('tweetLinkText', 'Twitter（現「X」）リンク', 'X (Twitter) link', 'X（Twitter）链接', 'X(Twitter) 링크'),
('imageText', '画像', 'Image', '图片', '이미지'),
('outputTab', '出力', 'Output', '输出', '출력'),
('outputSection', 'Markdown', 'Markdown', 'Markdown', 'Markdown'),
('embedTitles', '埋め込まれたnote記事のタイトルをリンクの文字にする', 'Use the titles of embedded note articles as link text', '将嵌入的 note 文章标题用作链接文字', '삽입된 note 글의 제목을 링크 텍스트로 사용'),
('embedTitlesHint', 'オフにすると「note記事へのリンク」と書き出します。オンのときは、埋め込まれた記事ごとにnoteへタイトルを問い合わせます。', 'When off, they are written as “Link to the note article”. When on, note is asked for the title of each embedded article.', '关闭时写为“note 文章链接”。开启时会向 note 查询每篇嵌入文章的标题。', '끄면 "note 글 링크"로 씁니다. 켜면 삽입된 글마다 note에 제목을 조회합니다.'),
('keepRunning', 'ウインドウを閉じても終了しない', 'Keep running after closing the window', '关闭窗口后继续运行', '윈도우를 닫아도 종료하지 않음'),
('keepRunningHint', 'オフにすると、メインウインドウを閉じたときに終了します。', 'When off, closing the main window quits the app.', '关闭此项后，关闭主窗口即退出。', '끄면 메인 윈도우를 닫을 때 종료합니다.'),
('settingsButton', '設定…', 'Settings…', '设置…', '설정…'),
('settings', '設定…', 'Settings…', '设置…', '설정…'),
('settingsTitle', '設定', 'Settings', '设置', '설정'),
('about', 'note2markdownについて', 'About note2markdown', '关于 note2markdown', 'note2markdown에 관하여'),
('services', 'サービス', 'Services', '服务', '서비스'),
('hideApp', 'note2markdownを隠す', 'Hide note2markdown', '隐藏 note2markdown', 'note2markdown 가리기'),
('hideOthers', 'ほかを隠す', 'Hide Others', '隐藏其他', '기타 가리기'),
('showAll', 'すべてを表示', 'Show All', '全部显示', '모두 보기'),
('quit', 'note2markdownを終了', 'Quit note2markdown', '退出 note2markdown', 'note2markdown 종료'),
('file', 'ファイル', 'File', '文件', '파일'),
('openMainWindow', 'メインウインドウを開く', 'Open Main Window', '打开主窗口', '메인 윈도우 열기'),
('close', 'ウインドウを閉じる', 'Close Window', '关闭窗口', '윈도우 닫기'),
('edit', '編集', 'Edit', '编辑', '편집'),
('undo', '取り消す', 'Undo', '撤销', '실행 취소'),
('redo', 'やり直す', 'Redo', '重做', '실행 복귀'),
('cut', 'カット', 'Cut', '剪切', '오려두기'),
('copy', 'コピー', 'Copy', '拷贝', '복사하기'),
('paste', 'ペースト', 'Paste', '粘贴', '붙여넣기'),
('selectAll', 'すべてを選択', 'Select All', '全选', '모두 선택'),
('window', 'ウインドウ', 'Window', '窗口', '윈도우'),
('minimize', 'しまう', 'Minimize', '最小化', '최소화'),
('zoom', '拡大／縮小', 'Zoom', '缩放', '확대/축소'),
('bringAllToFront', 'すべてを手前に移動', 'Bring All to Front', '前置全部窗口', '모두 앞으로 가져오기'),
('help', 'ヘルプ', 'Help', '帮助', '도움말'),
('helpItem', 'note2markdownヘルプ', 'note2markdown Help', 'note2markdown 帮助', 'note2markdown 도움말'),
('support', 'サポート：同梱のREADME.md', 'Support: see the bundled README.md', '支持：请参阅随附的 README.md', '지원: 함께 제공된 README.md 참조'),
]
helptexts = [
'''note2markdown — note記事をMarkdownに書き出す

使い方
1. note記事のURL（https://note.com/ユーザー名/n/n… の形）をコピーし、入力欄にペーストします。独自ドメインの記事のURLや、記事キー（n＋英数字12文字）だけでも使えます。
2. ⌘Return（入力欄ではReturnでも可）で記事を読み込み、Markdownをプレビューに表示します。
3. 「書き出す…」（⌘S）で保存先を選ぶと、.mdファイルに書き出します。ファイル名は記事のタイトルです。前回の保存先を覚えています。
「ブラウザーから」（⌘L）を押すと、最前面のブラウザー（Safari・Chrome・Firefox・Edge・Brave・Arc・Vivaldiなど）で表示中のnote記事を入力欄に入れて読み込みます。初回はアクセシビリティの許可が必要です。
ブラウザーのアドレスバーのアイコン（ファビコン）やリンクをウインドウへドラッグ＆ドロップしても読み込めます（許可は不要）。
「Markdownをコピー」（⇧⌘C）でクリップボードに入れることもできます。URLを入れてすぐ「書き出す…」を押した場合は、読み込んでから保存先を聞きます。

変換のしかた
- 記事のタイトルを見出し1（# ）にします。本文の大見出し・小見出しは ## と ### になります。
- 段落内の改行は、行末に半角スペース2つの改行にします。
- 太字・斜体・取り消し線・リンク・箇条書き・番号付きリスト・引用・コード・区切り線をMarkdownにします。目次は書き出しません。
- 画像は ![画像](URL) にします。キャプションがあれば代替テキストに使います。URLから表示サイズの指定（?width=…）を取り除きます。
- 埋め込みはリンクにします：note記事はタイトル（設定で切り替え）、X（Twitter）は「Twitter（現「X」）リンク」、外部サイトはページのタイトル、添付ファイルはファイル名、YouTubeはURLだけの行。

設定
「出力」タブ：埋め込まれたnote記事のタイトルをリンクの文字にする（初期値オン）。オフにすると「note記事へのリンク」と書き出し、記事ごとの問い合わせをしません。
「起動・常駐」タブ：ログイン時に起動（初期値オフ）、起動時にメインウインドウを表示しない（初期値オフ）、ウインドウを閉じても終了しない（初期値オン）、メニューバーに表示（初期値オフ）。

ホットキー
⌘Returnで読み込む、⌘Lでブラウザーから読み込む、⌘Sで書き出す、⇧⌘CでMarkdownをコピー、⌘,で設定、⌘0で「メインウインドウを開く」、⌘Wでウインドウを閉じる、⌘Qで終了、⌘?でこのヘルプを開きます。読み込み中はEscでキャンセルできます。

常駐と終了
メインウインドウを閉じてもアプリは終了しません。Dockのアイコンをクリックするか、ファイルメニューの「メインウインドウを開く」で再表示します。終了は⌘Q、またはアプリメニューの「note2markdownを終了」です。

権限
「ブラウザーから」を使うときだけ、アクセシビリティの許可が必要です（ブラウザーで表示中のページのURLを読み取るため）。設定の「起動・常駐」タブで状態を確認し、システム設定を開けます。URLを入力して使う場合は許可は不要です。フルディスクアクセスや管理者パスワードは使いません。

困ったとき
「記事が見つかりません」：URLが正しいか、記事が公開中か確認してください。
「この記事は読み込めません」：非公開・下書き・メンバー限定の記事は書き出せません。
有料記事：無料で読める部分だけを書き出します。購入済みでも有料部分は取得しません。
画像・つぶやき・動画だけの記事は本文がないため書き出せません。
同じ名前のファイルがあるときは、保存の画面で置き換えるかどうかを確認します。

プライバシー
入力した記事を読み込むため、note（note.com）の公開API（/api/v3/notes/記事キー）に接続します。ログイン情報やクッキーは送りません。保存するのは設定と最後の保存先フォルダー（UserDefaults）だけです。
「アップデートを確認…」は共通の更新機能ですが、このビルドでは配信先と署名が未設定のため準備中と表示し、通信しません。
サポート：同梱のREADME.md（アプリ内の Contents/Resources/README.md）をご覧ください。''',
'''note2markdown — Export a note article as Markdown

How to use
1. Copy the URL of a note article (https://note.com/username/n/n…) and paste it into the field. Articles on custom domains and the bare article key (n + 12 characters) also work.
2. Press ⌘Return (or Return in the field) to load the article and preview the Markdown.
3. Click Export… (⌘S) and choose where to save the .md file. The file is named after the article title. The last folder is remembered.
From Browser (⌘L) puts the note article shown in the front browser window (Safari, Chrome, Firefox, Edge, Brave, Arc, Vivaldi and others) into the field and loads it. It needs the Accessibility permission.
You can also drag the icon (favicon) in the browser’s address bar, or a link, onto the window (no permission needed).
Copy Markdown (⇧⌘C) puts it on the clipboard. If you click Export… right after entering a URL, the article is loaded first.

Conversion
- The article title becomes a level-1 heading (# ). Headings in the body become ## and ###.
- Line breaks inside a paragraph become hard breaks (two spaces at the end of the line).
- Bold, italic, strikethrough, links, bulleted and numbered lists, quotes, code and rules become Markdown. The table of contents is left out.
- Images become ![Image](URL), using the caption when there is one. Size parameters (?width=…) are removed from the URL.
- Embeds become links: note articles use their title (see Settings), X (Twitter) posts “X (Twitter) link”, other sites the page title, attachments the file name, and YouTube a line with just the URL.

Settings
Output: Use the titles of embedded note articles as link text (on by default). When off, they are written as “Link to the note article” and no extra requests are made.
Startup & Background: Launch at login (off), Hide main window at startup (off), Keep running after closing the window (on), Show in menu bar (off).

Hotkeys
⌘Return load, ⌘L load from the front browser, ⌘S export, ⇧⌘C copy Markdown, ⌘, settings, ⌘0 Open Main Window, ⌘W close the window, ⌘Q quit, ⌘? this help. Press Esc to cancel loading.

Running and quitting
Closing the main window does not quit the app. Click the Dock icon or choose File → Open Main Window to show it again. Quit with ⌘Q or Quit note2markdown in the app menu.

Permissions
Only From Browser needs the Accessibility permission (to read the URL of the page in the browser). Check it and open System Settings in the Startup & Background tab of Settings. Entering a URL works without it. No Full Disk Access or administrator password is used.

Troubleshooting
“The article was not found”: check the URL and that the article is published.
“This article cannot be loaded”: private, draft and members-only articles cannot be exported.
Paid articles: only the free part is exported, even if you bought the article.
Image, talk and video posts have no text body and cannot be exported.
When a file with the same name exists, the save dialog asks whether to replace it.

Privacy
To load the article you enter, the app connects to note's public API (note.com/api/v3/notes/<key>). No login information or cookies are sent. Only the settings and the last export folder are stored (UserDefaults).
Check for Updates… is the shared update feature, but this build has no update feed or signing key yet, so it shows that updates are being prepared and makes no connection.
Support: see the bundled README.md (Contents/Resources/README.md in the app).''',
'''note2markdown — 将 note 文章导出为 Markdown

使用方法
1. 拷贝 note 文章的 URL（https://note.com/用户名/n/n…），粘贴到输入框。也支持自定义域名的文章 URL 或仅文章键（n＋12 个字符）。
2. 按 ⌘Return（在输入框中也可按 Return）载入文章并预览 Markdown。
3. 点按“导出…”（⌘S）并选择保存位置，即可写入 .md 文件。文件名为文章标题。会记住上次的文件夹。
“从浏览器”（⌘L）会将最前面浏览器（Safari、Chrome、Firefox、Edge、Brave、Arc、Vivaldi 等）中显示的 note 文章填入输入框并载入。需要辅助功能权限。
也可以将浏览器地址栏中的图标（网站图标）或链接拖放到窗口中载入（无需权限）。
“拷贝 Markdown”（⇧⌘C）可将其放入剪贴板。输入 URL 后直接点按“导出…”时，会先载入文章。

转换方式
- 文章标题成为一级标题（# ）。正文中的标题成为 ## 和 ###。
- 段落内的换行转换为硬换行（行尾两个空格）。
- 粗体、斜体、删除线、链接、项目符号列表、编号列表、引用、代码和分隔线转换为 Markdown。不导出目录。
- 图片转换为 ![图片](URL)，有说明文字时用作替代文本。会从 URL 中删除尺寸参数（?width=…）。
- 嵌入内容转换为链接：note 文章使用标题（可在设置中切换），X（Twitter）为“X（Twitter）链接”，其他网站为页面标题，附件为文件名，YouTube 为仅含 URL 的一行。

设置
“输出”：将嵌入的 note 文章标题用作链接文字（默认开启）。关闭时写为“note 文章链接”，不进行额外请求。
“启动与后台”：登录时启动（关）、启动时不显示主窗口（关）、关闭窗口后继续运行（开）、在菜单栏中显示（关）。

快捷键
⌘Return 载入，⌘L 从浏览器载入，⌘S 导出，⇧⌘C 拷贝 Markdown，⌘, 设置，⌘0 打开主窗口，⌘W 关闭窗口，⌘Q 退出，⌘? 本帮助。载入中按 Esc 取消。

运行与退出
关闭主窗口不会退出应用。点按 Dock 图标或选择“文件 → 打开主窗口”可再次显示。使用 ⌘Q 或应用菜单中的“退出 note2markdown”退出。

权限
仅“从浏览器”需要辅助功能权限（用于读取浏览器中页面的 URL）。可在设置的“启动与后台”中查看状态并打开系统设置。输入 URL 时无需此权限。不使用完全磁盘访问权限或管理员密码。

故障排除
“找不到文章”：请检查 URL 以及文章是否已发布。
“无法载入此文章”：未公开、草稿和仅限会员的文章无法导出。
付费文章：仅导出免费部分，即使已购买也一样。
图片、碎碎念和视频文章没有正文，无法导出。
存在同名文件时，保存对话框会询问是否替换。

隐私
为了载入您输入的文章，应用会连接 note 的公开 API（note.com/api/v3/notes/文章键）。不发送登录信息或 Cookie。仅保存设置和上次导出的文件夹（UserDefaults）。
“检查更新…”是共用的更新功能，但此版本尚未设置更新源和签名，因此显示为准备中，不进行通信。
支持：请参阅随附的 README.md（应用内的 Contents/Resources/README.md）。''',
'''note2markdown — note 글을 Markdown으로 내보내기

사용 방법
1. note 글의 URL(https://note.com/사용자이름/n/n…)을 복사하여 입력란에 붙여넣습니다. 독자 도메인 글의 URL이나 글 키(n＋12자)만으로도 사용할 수 있습니다.
2. ⌘Return(입력란에서는 Return도 가능)으로 글을 불러오고 Markdown을 미리 봅니다.
3. 내보내기…(⌘S)에서 저장 위치를 선택하면 .md 파일로 내보냅니다. 파일 이름은 글 제목입니다. 마지막 폴더를 기억합니다.
브라우저에서(⌘L)를 누르면 맨 앞 브라우저(Safari, Chrome, Firefox, Edge, Brave, Arc, Vivaldi 등)에 표시된 note 글을 입력란에 넣고 불러옵니다. 손쉬운 사용 권한이 필요합니다.
브라우저 주소 막대의 아이콘(파비콘)이나 링크를 윈도우로 드래그 앤 드롭해도 불러옵니다(권한 불필요).
Markdown 복사하기(⇧⌘C)로 클립보드에 넣을 수도 있습니다. URL을 입력하고 바로 내보내기…를 누르면 먼저 글을 불러옵니다.

변환 방식
- 글 제목을 제목 1(# )로 합니다. 본문의 제목은 ##과 ###이 됩니다.
- 단락 안의 줄바꿈은 강제 줄바꿈(줄 끝에 공백 2개)으로 합니다.
- 굵게, 기울임, 취소선, 링크, 글머리 기호 목록, 번호 목록, 인용, 코드, 구분선을 Markdown으로 합니다. 목차는 내보내지 않습니다.
- 이미지는 ![이미지](URL)로 하며, 캡션이 있으면 대체 텍스트로 사용합니다. URL에서 크기 지정(?width=…)을 제거합니다.
- 삽입 콘텐츠는 링크로 합니다: note 글은 제목(설정에서 전환), X(Twitter)는 "X(Twitter) 링크", 외부 사이트는 페이지 제목, 첨부 파일은 파일 이름, YouTube는 URL만 있는 줄.

설정
출력: 삽입된 note 글의 제목을 링크 텍스트로 사용(기본값 켬). 끄면 "note 글 링크"로 쓰고 추가 조회를 하지 않습니다.
시작 및 백그라운드: 로그인 시 실행(끔), 시작 시 메인 윈도우 표시 안 함(끔), 윈도우를 닫아도 종료하지 않음(켬), 메뉴 막대에 표시(끔).

단축키
⌘Return 불러오기, ⌘L 브라우저에서 불러오기, ⌘S 내보내기, ⇧⌘C Markdown 복사하기, ⌘, 설정, ⌘0 메인 윈도우 열기, ⌘W 윈도우 닫기, ⌘Q 종료, ⌘? 이 도움말. 불러오는 중에는 Esc로 취소할 수 있습니다.

실행과 종료
메인 윈도우를 닫아도 앱은 종료되지 않습니다. Dock 아이콘을 클릭하거나 파일 → 메인 윈도우 열기로 다시 표시합니다. ⌘Q 또는 앱 메뉴의 note2markdown 종료로 끝냅니다.

권한
브라우저에서를 사용할 때만 손쉬운 사용 권한이 필요합니다(브라우저에 표시된 페이지의 URL을 읽기 위해). 설정의 시작 및 백그라운드 탭에서 상태를 확인하고 시스템 설정을 열 수 있습니다. URL을 입력해 사용할 때는 필요하지 않습니다. 전체 디스크 접근 권한이나 관리자 암호는 사용하지 않습니다.

문제 해결
"글을 찾을 수 없습니다": URL이 올바른지, 글이 공개 중인지 확인하세요.
"이 글은 불러올 수 없습니다": 비공개, 임시 저장, 멤버 전용 글은 내보낼 수 없습니다.
유료 글: 무료로 읽을 수 있는 부분만 내보냅니다. 구매한 경우에도 같습니다.
이미지, 중얼거림, 동영상 글은 본문이 없어 내보낼 수 없습니다.
같은 이름의 파일이 있으면 저장 화면에서 대치할지 확인합니다.

개인정보
입력한 글을 불러오기 위해 note의 공개 API(note.com/api/v3/notes/글 키)에 연결합니다. 로그인 정보나 쿠키는 보내지 않습니다. 설정과 마지막 내보내기 폴더(UserDefaults)만 저장합니다.
업데이트 확인…은 공통 업데이트 기능이지만, 이 빌드는 배포 주소와 서명이 설정되지 않아 준비 중으로 표시하고 통신하지 않습니다.
지원: 함께 제공된 README.md(앱 내부 Contents/Resources/README.md)를 참조하세요.''',
]
for idx, lang in enumerate(LANGS):
    folder = root / 'Resources' / f'{lang}.lproj'; folder.mkdir(parents=True, exist_ok=True)
    values = {r[0]: r[idx + 1] for r in rows}; values['helpContent'] = helptexts[idx]
    (folder / 'Localizable.strings').write_text('\n'.join(json.dumps(k, ensure_ascii=False) + ' = ' + json.dumps(v, ensure_ascii=False) + ';' for k, v in values.items()) + '\n')
    (folder / 'Help.txt').write_text(helptexts[idx] + '\n')
    (folder / 'InfoPlist.strings').write_text('"CFBundleDisplayName" = "note2markdown";\n')
info = {'CFBundleName': 'note2markdown', 'CFBundleDisplayName': 'note2markdown', 'CFBundleIdentifier': 'jp.dtp-transit.note2markdown', 'CFBundleExecutable': 'note2markdown', 'CFBundlePackageType': 'APPL', 'CFBundleIconFile': 'note2markdown.icns', 'LSMinimumSystemVersion': '13.0', 'LSMultipleInstancesProhibited': True, 'NSHighResolutionCapable': True, 'CFBundleDevelopmentRegion': 'en', 'CFBundleLocalizations': LANGS, 'NSPrincipalClass': 'NSApplication', 'LSApplicationCategoryType': 'public.app-category.productivity', 'SWAppFamily': 'swwwitch', 'NSHumanReadableCopyright': '© 2026 swwwitch', 'CFBundleShortVersionString': '1.0.0', 'CFBundleVersion': '1'}
# Version and build come from the existing Info.plist, so regeneration never reverts them.
plist_path = root / 'Info.plist'; current = plistlib.loads(plist_path.read_bytes()) if plist_path.exists() else {}
info.update({k: current[k] for k in ('CFBundleShortVersionString', 'CFBundleVersion', 'SWNoteArticleURL') if k in current})
plist_path.write_bytes(plistlib.dumps(info))
