# EventDocMaker help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
EventDocMakerは、イベントの表（Excel）の内容をテンプレートに差し込み、案内文・メール・告知などの文書をまとめて書き出します。
1. Excelで、そのイベントの「項目」と「値」の2列（例：「イベント名⇥武器になるHTML」）を選んでコピーします。
2. ［クリップボードから読み込む］（⇧⌘V）を押すか、表の欄にペーストします。
3. 種別・イベント名・日付・作成先を確かめ、［文書を作る］（⌘Return）を押します。
作成先は「親フォルダー／種別-仮の日付-タイトル（abc）／docs」です。表には「種別」「仮の日付」「タイトル（abc）」が必要です。

## 書き出すもの
- EventDocフォルダーの Templates にある各ファイルを、%Variable%Event…% を値に置き換えて docs に書き出します（同じ名前のファイルは上書きします）。サブフォルダーと、名前が「.」で始まるファイルは使いません。
- 99-stores.txt があれば「CeeBeeDee-仮の日付-タイトル（abc）.txt」という名前のコピーも作ります（前のコピーはゴミ箱へ）。
- 「QRコードも作る」がオンのときは、配信URL・DoorkeeperのURL・STORES（経費）・アンケート（参加者向け）のQRコードを、イベントのフォルダーに qr-…png として作ります。QRコードはMacの中で作り、外部のサービスは使いません。
- 「最近のイベントのリンク置き場」に、イベントのフォルダーへのリンクを置きます。
- 「変数の一覧」で、差し込む値をすべて確かめられます。書き出した後は、値が空だった変数と、見つからなかった共通の文書（Guide・Footer・ComingInfo など）を表示します。

## 表の書き方
1行に「項目」と「値」をタブで区切ります（「項目：値」も読めます）。Excelでセル内に改行がある値（プロフィールなど）も、そのまま読めます。日付は「日付（Doorkeeper）」に 2026-02-08 の形で入れると、曜日付きの日付や翌日の日付も作ります。種別が「CSS Nite」かどうかで、差出人・フッター・色などを切り替えます。

## 設定
［EventDocMaker］＞［設定…］（⌘,）で開きます。
- 起動・常駐：ログイン時に起動、Dockとアプリケーションスイッチャーに表示しない、ウインドウを閉じても常駐、メニューバーのアイコン、アプリ起動のホットキー、アプリを呼び出すホットキー（初期値 ⌃⌥E）。
- フォルダー：作成先の親フォルダー、EventDocフォルダー、最近のイベントのリンク置き場、フォルダーを開くアプリ（Path Finder／Finder）。
- 情報：バージョンとリンク。

## ホットキー
- ⌃⌥E：どのアプリからでもEventDocMakerのウインドウを表示（起動中のとき）
- ⇧⌘V：クリップボードから読み込む
- ⌘Return：文書を作る
- ⌘0：メインウインドウを開く
- ⌘,：設定
- ⌘W：ウインドウを閉じる
- ⌘?：このヘルプ

## 権限とプライバシー
特別な許可は不要です。クリップボードは［クリップボードから読み込む］を押したときだけ読みます。内容を外部に送りません。

## 常駐と終了
「ウインドウを閉じても常駐」がオンのときは、ウインドウを閉じても終了しません。DockやFinderから開き直すか、メニューバーのアイコンからウインドウを表示できます。終了するには［EventDocMaker］＞［EventDocMakerを終了］（⌘Q）を選びます。書き出しの途中は終了しません。

## 困ったときは
- ［文書を作る］が押せない：表に「種別」「仮の日付」「タイトル（abc）」があるか確かめてください。足りない項目は作成先の欄に表示します。
- 「テンプレートがありません」と出る：設定の「フォルダー」でEventDocフォルダーを確かめてください。
- 文書に値が入らない：「変数の一覧」と、書き出し後の「値が空の変数」を確かめてください。表の項目名が違うと読めません。
- 文書を作り直したい：表を直して、もう一度［文書を作る］を押します。docs の同じ名前のファイルは上書きされます。
""",
 "en": """## Basics
EventDocMaker fills the templates with the values from an event sheet (Excel) and writes out the standard documents—announcements, mails, notices and more—in one go.
1. In Excel, select and copy the label and value columns for the event (for example “イベント名⇥…”).
2. Click Load from Clipboard (⇧⌘V), or paste into the sheet box.
3. Check the category, event, date and folder, then click Make Documents (⌘Return).
Documents go to “parent folder/category-date-title (abc)/docs”. The sheet needs 種別, 仮の日付 and タイトル（abc）.

## What is written
- Each file in Templates in the EventDoc folder is written to docs with %Variable%Event…% replaced by its value (files with the same name are overwritten). Subfolders and files whose name starts with “.” are skipped.
- When 99-stores.txt exists, a copy named “CeeBeeDee-date-title (abc).txt” is made too (an older copy goes to the Trash).
- With Also make QR codes on, QR codes for the streaming URL, the Doorkeeper URL, STORES (経費) and the questionnaire are saved in the event folder as qr-….png. They are made on your Mac without any outside service.
- A link to the event folder is placed in the recent events folder.
- Variables lists every value. After writing, empty variables and missing shared texts (Guide, Footer, ComingInfo and so on) are shown.

## The sheet
One row per line: a label and a value separated by a tab (“label：value” also works). Values with line breaks inside a cell, such as a profile, are read as they are. Put 日付（Doorkeeper） as 2026-02-08 to get dates with weekdays and the next day. Whether 種別 is “CSS Nite” switches the sender, footer, colors and so on.

## Settings
Open with EventDocMaker > Settings… (⌘,).
- Launch & Residency: open at login, hide from the Dock and App Switcher, keep running after closing the window, menu bar icon, app launch keyboard shortcut and the hotkey that shows the window (default ⌃⌥E).
- Folders: parent folder, EventDoc folder, recent events links, and the app that opens folders (Path Finder or Finder).
- About: version and links.

## Hotkeys
- ⌃⌥E: show the EventDocMaker window from any app (while running)
- ⇧⌘V: load from the clipboard
- ⌘Return: make documents
- ⌘0: open the main window
- ⌘,: settings
- ⌘W: close the window
- ⌘?: this help

## Permissions and privacy
No special permission is needed. The clipboard is read only when you click Load from Clipboard. Nothing is sent anywhere.

## Keeping it running and quitting
With Keep running after closing the window on, closing the window does not quit. Reopen from the Dock or Finder, or from the menu bar icon. To quit, choose EventDocMaker > Quit EventDocMaker (⌘Q). It does not quit while writing.

## Troubleshooting
- Make Documents is unavailable: check that the sheet has 種別, 仮の日付 and タイトル（abc）. Missing labels are shown in the folder row.
- “No templates”: check the EventDoc folder in Settings > Folders.
- Values are missing in documents: check Variables and the empty variables shown after writing. Labels must match exactly.
- To make documents again: fix the sheet and click Make Documents again. Files with the same name in docs are overwritten.
""",
 "zh-Hans": """## 基本操作
EventDocMaker 将活动表（Excel）中的内容填入模板，批量写出公告、邮件、通知等文档。
1. 在 Excel 中选择并拷贝该活动的“项目”和“值”两列（例如“イベント名⇥…”）。
2. 点按“从剪贴板读取”（⇧⌘V），或粘贴到表格栏。
3. 确认类别、活动名称、日期和创建位置，然后点按“生成文档”（⌘Return）。
文档写入“父文件夹／类别-暂定日期-标题（abc）／docs”。表中需要 種別、仮の日付 和 タイトル（abc）。

## 写出的内容
- 将 EventDoc 文件夹 Templates 中的各文件写入 docs，并把 %Variable%Event…% 替换为对应的值（同名文件会被覆盖）。不使用子文件夹和以“.”开头的文件。
- 若有 99-stores.txt，还会创建名为“CeeBeeDee-暂定日期-标题（abc）.txt”的副本（旧副本移到废纸篓）。
- 开启“同时生成二维码”时，会在活动文件夹中为直播网址、Doorkeeper 网址、STORES（経費）和问卷生成 qr-….png。二维码在本机生成，不使用外部服务。
- 在“最近活动链接位置”放置指向活动文件夹的链接。
- 可在“变量列表”中查看所有值。写出后会显示值为空的变量和未找到的共用文本（Guide、Footer、ComingInfo 等）。

## 表的写法
每行用制表符分隔“项目”和“值”（也可读取“项目：值”）。单元格内含换行的值（如个人简介）也可直接读取。在 日付（Doorkeeper） 中以 2026-02-08 的形式填写，即可生成带星期的日期和次日日期。根据 種別 是否为“CSS Nite”切换发件人、页脚、颜色等。

## 设置
通过“EventDocMaker”>“设置…”（⌘,）打开。
- 启动与常驻：登录时启动、不在程序坞和应用程序切换器中显示、关闭窗口后继续运行、菜单栏图标、启动应用快捷键，以及显示窗口的快捷键（默认 ⌃⌥E）。
- 文件夹：父文件夹、EventDoc 文件夹、最近活动链接位置，以及打开文件夹的应用（Path Finder 或访达）。
- 关于：版本和链接。

## 快捷键
- ⌃⌥E：在任何应用中显示 EventDocMaker 窗口（运行时）
- ⇧⌘V：从剪贴板读取
- ⌘Return：生成文档
- ⌘0：打开主窗口
- ⌘,：设置
- ⌘W：关闭窗口
- ⌘?：本帮助

## 权限与隐私
无需特殊权限。仅在点按“从剪贴板读取”时读取剪贴板。不会向外部发送任何内容。

## 常驻与退出
开启“关闭窗口后继续运行”时，关闭窗口不会退出。可从程序坞或访达重新打开，或通过菜单栏图标显示窗口。要退出，请选择“EventDocMaker”>“退出 EventDocMaker”（⌘Q）。写出过程中不会退出。

## 疑难解答
- 无法点按“生成文档”：请确认表中有 種別、仮の日付 和 タイトル（abc）。缺少的项目会显示在创建位置一栏。
- 显示“没有模板”：请在“设置”>“文件夹”中确认 EventDoc 文件夹。
- 文档中缺少值：请查看“变量列表”和写出后显示的空变量。项目名称必须完全一致。
- 想重新生成：修改表后再次点按“生成文档”。docs 中的同名文件会被覆盖。
""",
 "ko": """## 기본 조작
EventDocMaker는 이벤트 표(Excel)의 내용을 템플릿에 넣어 안내문, 메일, 공지 등의 문서를 한꺼번에 만듭니다.
1. Excel에서 해당 이벤트의 항목과 값 두 열(예: “イベント名⇥…”)을 선택해 복사합니다.
2. '클립보드에서 읽기'(⇧⌘V)를 누르거나 표 칸에 붙여넣습니다.
3. 종류, 이벤트 이름, 날짜, 만들 위치를 확인하고 '문서 만들기'(⌘Return)를 누릅니다.
문서는 “상위 폴더/종류-임시 날짜-제목(abc)/docs”에 만듭니다. 표에는 種別, 仮の日付, タイトル（abc）가 필요합니다.

## 만드는 것
- EventDoc 폴더의 Templates에 있는 각 파일을 %Variable%Event…%를 값으로 바꿔 docs에 씁니다(같은 이름의 파일은 덮어씁니다). 하위 폴더와 이름이 “.”로 시작하는 파일은 쓰지 않습니다.
- 99-stores.txt가 있으면 “CeeBeeDee-임시 날짜-제목(abc).txt”라는 사본도 만듭니다(이전 사본은 휴지통으로).
- 'QR 코드도 만들기'를 켜면 방송 URL, Doorkeeper URL, STORES(経費), 설문의 QR 코드를 이벤트 폴더에 qr-….png로 만듭니다. QR 코드는 Mac 안에서 만들며 외부 서비스를 쓰지 않습니다.
- '최근 이벤트 링크 위치'에 이벤트 폴더로의 링크를 둡니다.
- '변수 목록'에서 넣을 값을 모두 확인할 수 있습니다. 만든 후에는 값이 빈 변수와 찾지 못한 공통 문서(Guide, Footer, ComingInfo 등)를 표시합니다.

## 표 작성법
한 줄에 항목과 값을 탭으로 구분합니다(“항목：값”도 읽습니다). 셀 안에 줄바꿈이 있는 값(프로필 등)도 그대로 읽습니다. 日付（Doorkeeper）에 2026-02-08 형식으로 넣으면 요일이 붙은 날짜와 다음 날 날짜도 만듭니다. 種別이 “CSS Nite”인지에 따라 보낸 사람, 바닥글, 색 등을 바꿉니다.

## 설정
EventDocMaker > 설정…(⌘,)으로 엽니다.
- 실행·상주: 로그인 시 실행, Dock 및 앱 전환기에 표시 안 함, 윈도우를 닫아도 계속 실행, 메뉴 막대 아이콘, 앱 실행 키보드 단축키, 윈도우를 표시하는 단축키(기본 ⌃⌥E).
- 폴더: 상위 폴더, EventDoc 폴더, 최근 이벤트 링크 위치, 폴더를 열 앱(Path Finder 또는 Finder).
- 정보: 버전과 링크.

## 단축키
- ⌃⌥E: 어느 앱에서든 EventDocMaker 윈도우 표시(실행 중일 때)
- ⇧⌘V: 클립보드에서 읽기
- ⌘Return: 문서 만들기
- ⌘0: 메인 윈도우 열기
- ⌘,: 설정
- ⌘W: 윈도우 닫기
- ⌘?: 이 도움말

## 권한과 개인정보
특별한 권한은 필요 없습니다. 클립보드는 '클립보드에서 읽기'를 누를 때만 읽습니다. 내용을 외부로 보내지 않습니다.

## 상주와 종료
'윈도우를 닫아도 계속 실행'이 켜져 있으면 윈도우를 닫아도 종료하지 않습니다. Dock이나 Finder에서 다시 열거나 메뉴 막대 아이콘에서 윈도우를 표시할 수 있습니다. 종료하려면 EventDocMaker > EventDocMaker 종료(⌘Q)를 선택합니다. 쓰는 중에는 종료하지 않습니다.

## 문제 해결
- '문서 만들기'를 누를 수 없음: 표에 種別, 仮の日付, タイトル（abc）가 있는지 확인하세요. 부족한 항목은 만들 위치 칸에 표시합니다.
- '템플릿이 없습니다'가 표시됨: 설정 > 폴더에서 EventDoc 폴더를 확인하세요.
- 문서에 값이 들어가지 않음: '변수 목록'과 만든 후 표시되는 빈 변수를 확인하세요. 항목 이름이 정확히 같아야 합니다.
- 다시 만들고 싶을 때: 표를 고친 뒤 '문서 만들기'를 다시 누릅니다. docs의 같은 이름 파일은 덮어씁니다.
""",
}
