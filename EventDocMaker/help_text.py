# EventDocMaker help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
EventDocMakerは、イベントごとの情報を保存して管理し、その情報をテンプレートに差し込んで、案内文・メール・告知などの文書をまとめて書き出します。
- 左の一覧でイベントを選び、右の「開催前」「終了後」のタブで情報を入力します。入力した内容は自動で保存されます。
- 「文書を作る」タブで内容を確かめ、［文書を作る］（⌘Return）を押します。
- 一覧は新しい日付から並びます。上の欄で、イベント名・#・日付・出演者から探せます。
- ＋で新しいイベント（⌘N）、−で削除（⌘⌫）、重なった四角で複製（⌘D）します。複製では日付と「終了後」の値を空にします。

## 保存場所
- イベントのフォルダー（親フォルダー／種別-仮の日付-タイトル（abc））があるときは、その中の event.json に保存します。
- フォルダーがまだ無いイベントは EventDoc/EventData に保存し、一覧に「？」付きのフォルダーの印を出します。［文書を作る］でフォルダーができると、event.json がその中へ移ります。
- 種別・仮の日付・タイトル（abc）を変えると、保存場所もその名前のフォルダーに合わせて変わります。
- どちらもDropbox内なので、ほかのMacでも同じ情報を使えます。ほかのMacで変えた内容は［ファイル］＞「読み直す」（⌘R）で読み込みます。同じイベントを2台で同時に編集すると、後から保存した方が残ります。

## Excelから取り込む
［Excelから取り込む…］で「配信に関してのまとめ.xlsx」を選びます。シート「新しいまとめ」の、A列の項目名と、B列以降の1列1イベント（3行目の#）を読みます。
- すでにあるイベント（#が同じ）は変えません。確認画面で「すでにある…件もExcelの値で上書きする」を選ぶと上書きします。
- 日付・時刻は「20261202」「21:00」などの形に直して取り込みます。Excelは変更しません。
- Excelで2行ある項目（X広告とCSS Nite広告のSpendなど）は、CSS Nite側を「CSS Nite：Spend」のように別の項目にします。
- ［ファイル］＞「クリップボードの表から入力」（⇧⌘V）では、Excelでコピーした「項目⇥値」の2列を、選んでいるイベントに入力します。

## 書き出すもの
- EventDocフォルダーの Templates にある各ファイルを、%Variable%Event…% を値に置き換えてイベントのフォルダーの docs に書き出します（同じ名前のファイルは上書きします）。
- 空の項目は、以前のExcelと同じく「-」として差し込みます（Doorkeeper購入者数は「0」、アンケート回答期限は「準備中」）。
- 99-stores.txt があれば「CeeBeeDee-仮の日付-タイトル（abc）.txt」のコピーも作ります。
- 「QRコードも作る」がオンのときは、配信URL・DoorkeeperのURL・STORES（経費）・アンケート（参加者向け）のQRコードを作ります（Mac上で作り、外部のサービスは使いません）。
- 「最近のイベントのリンク置き場」に、イベントのフォルダーへのリンクを置きます。
- 書き出した後は、値が空だった変数と、見つからなかった共通の文書を表示します。「変数の一覧」で差し込む値をすべて確かめられます。

## 設定
［EventDocMaker］＞［設定…］（⌘,）で開きます。
- 起動・常駐：ログイン時に起動、Dockとアプリケーションスイッチャーに表示しない、ウインドウを閉じても常駐、メニューバーのアイコン、アプリ起動のホットキー、アプリを呼び出すホットキー（初期値 ⌃⌥E）。
- フォルダー：作成先の親フォルダー、EventDocフォルダー、最近のイベントのリンク置き場、フォルダーを開くアプリ（Path Finder／Finder）。
- 情報：バージョンとリンク。

## ホットキー
- ⌃⌥E：どのアプリからでもEventDocMakerのウインドウを表示（起動中のとき）
- ⌘N：新しいイベント　⌘D：複製　⌘⌫：削除
- ⌘R：読み直す　⇧⌘V：クリップボードの表から入力
- ⌘Return：文書を作る
- ⌘0：メインウインドウを開く　⌘,：設定　⌘W：ウインドウを閉じる　⌘?：このヘルプ

## 権限とプライバシー
特別な許可は不要です。クリップボードは「クリップボードの表から入力」を選んだときだけ読みます。内容を外部に送りません。

## 常駐と終了
「ウインドウを閉じても常駐」がオンのときは、ウインドウを閉じても終了しません。DockやFinderから開き直すか、メニューバーのアイコンからウインドウを表示できます。終了するには［EventDocMaker］＞［EventDocMakerを終了］（⌘Q）を選びます。終了やほかのアプリへの切り替えの前に、入力中の内容を保存します。書き出しの途中は終了しません。

## 困ったときは
- ［文書を作る］が押せない：種別・仮の日付・タイトル（abc）を入れてください。足りないときはイベント名の下に表示します。
- 「テンプレートがありません」と出る：設定の「フォルダー」でEventDocフォルダーを確かめてください。
- 一覧にイベントが出ない：設定の親フォルダーとEventDocフォルダーを確かめ、「読み直す」を押してください。
- 削除を取り消したい：ゴミ箱から event.json（またはEventDataの .json）を元の場所に戻し、「読み直す」を押します。
""",
 "en": """## Basics
EventDocMaker keeps the details of each event and writes out its standard documents—announcements, mails, notices and more—by filling the templates with those details.
- Choose an event in the list on the left and enter its details in the Before and After tabs. Changes are saved automatically.
- Check the Documents tab and click Make Documents (⌘Return).
- The list shows the newest date first. Search by event name, #, date or speaker in the field above it.
- + adds an event (⌘N), − deletes it (⌘⌫) and the stacked squares duplicate it (⌘D). A duplicate leaves the dates and the After values empty.

## Where events are saved
- When the event folder (parent folder/category-date-title (abc)) exists, the event is saved as event.json in it.
- Events without a folder yet are saved in EventDoc/EventData and marked with a folder-and-question-mark icon. When Make Documents creates the folder, event.json moves into it.
- Changing 種別, 仮の日付 or タイトル（abc） moves the file to match the new folder name.
- Both places are in Dropbox, so other Macs see the same events. Use File > Reload (⌘R) to read changes from another Mac. If two Macs edit the same event at once, the later save wins.

## Importing from Excel
Click Import from Excel… and choose 配信に関してのまとめ.xlsx. The sheet 新しいまとめ is read: labels in column A and one event per column from B (its # in row 3).
- Events already here (same #) are left as they are, unless you choose to overwrite them in the confirmation.
- Dates and times are converted to forms like 20261202 and 21:00. The workbook is not changed.
- Labels that appear twice in the sheet (Spend for X ads and CSS Nite ads, for example) become separate fields such as “CSS Nite：Spend”.
- File > Fill from Copied Sheet (⇧⌘V) fills the selected event from two columns (label ⇥ value) copied in Excel.

## What is written
- Each file in Templates in the EventDoc folder is written to the event folder's docs with %Variable%Event…% replaced by its value (files with the same name are overwritten).
- Empty fields are filled in as “-”, as the workbook used to do (0 for the Doorkeeper purchase counts, 準備中 for the survey deadline).
- When 99-stores.txt exists, a copy named “CeeBeeDee-date-title (abc).txt” is made too.
- With Also make QR codes on, QR codes for the streaming URL, the Doorkeeper URL, STORES (経費) and the questionnaire are made on your Mac without any outside service.
- A link to the event folder is placed in the recent events folder.
- After writing, empty variables and missing shared texts are shown. Variables lists every value.

## Settings
Open with EventDocMaker > Settings… (⌘,).
- Launch & Residency: open at login, hide from the Dock and App Switcher, keep running after closing the window, menu bar icon, app launch keyboard shortcut and the hotkey that shows the window (default ⌃⌥E).
- Folders: parent folder, EventDoc folder, recent events links, and the app that opens folders (Path Finder or Finder).
- About: version and links.

## Hotkeys
- ⌃⌥E: show the EventDocMaker window from any app (while running)
- ⌘N: new event　⌘D: duplicate　⌘⌫: delete
- ⌘R: reload　⇧⌘V: fill from copied sheet
- ⌘Return: make documents
- ⌘0: main window　⌘,: settings　⌘W: close the window　⌘?: this help

## Permissions and privacy
No special permission is needed. The clipboard is read only when you choose Fill from Copied Sheet. Nothing is sent anywhere.

## Keeping it running and quitting
With Keep running after closing the window on, closing the window does not quit. Reopen from the Dock or Finder, or from the menu bar icon. To quit, choose EventDocMaker > Quit EventDocMaker (⌘Q). Pending edits are saved before quitting or switching to another app. It does not quit while writing.

## Troubleshooting
- Make Documents is unavailable: enter 種別, 仮の日付 and タイトル（abc）. What is missing is shown under the event name.
- “No templates”: check the EventDoc folder in Settings > Folders.
- Events do not appear: check the parent and EventDoc folders in Settings, then click Reload.
- To undo a deletion: move event.json (or the .json in EventData) back from the Trash, then click Reload.
""",
 "zh-Hans": """## 基本操作
EventDocMaker 保存并管理每个活动的信息，并将这些信息填入模板，批量写出公告、邮件、通知等文档。
- 在左侧列表中选择活动，在右侧“活动前”“结束后”标签中输入信息。输入内容会自动存储。
- 在“生成文档”标签中确认内容，然后点按“生成文档”（⌘Return）。
- 列表按日期从新到旧排列。可在上方栏中按活动名称、#、日期或出演者搜索。
- 用 + 新建活动（⌘N），用 − 删除（⌘⌫），用重叠方块复制（⌘D）。复制时日期和“结束后”的值为空。

## 存储位置
- 活动文件夹（父文件夹／类别-暂定日期-标题（abc））存在时，存为其中的 event.json。
- 尚无文件夹的活动存入 EventDoc/EventData，并在列表中显示带问号的文件夹标记。“生成文档”创建文件夹后，event.json 会移入其中。
- 更改 種別、仮の日付 或 タイトル（abc） 后，存储位置会随新的文件夹名称改变。
- 两处都在 Dropbox 中，其他 Mac 也可使用相同的信息。用“文件”>“重新读取”（⌘R）读取在其他 Mac 上的更改。两台 Mac 同时编辑同一活动时，以后存储的为准。

## 从 Excel 导入
点按“从 Excel 导入…”，选择“配信に関してのまとめ.xlsx”。读取工作表“新しいまとめ”中 A 列的项目名和从 B 列起每列一个活动（第 3 行为 #）。
- 已有的活动（# 相同）保持不变；在确认画面中选择覆盖时会被覆盖。
- 日期和时间会转换为 20261202、21:00 等形式。不会更改 Excel。
- 在表中出现两次的项目（如 X 广告和 CSS Nite 广告的 Spend）会成为“CSS Nite：Spend”等不同项目。
- “文件”>“从剪贴板中的表填入”（⇧⌘V）可将在 Excel 中拷贝的“项目⇥值”两列填入所选活动。

## 写出的内容
- 将 EventDoc 文件夹 Templates 中的各文件写入活动文件夹的 docs，并把 %Variable%Event…% 替换为对应的值（同名文件会被覆盖）。
- 空项目与以前的 Excel 一样以“-”填入（Doorkeeper 购买人数为“0”，问卷截止为“準備中”）。
- 若有 99-stores.txt，还会创建“CeeBeeDee-暂定日期-标题（abc）.txt”副本。
- 开启“同时生成二维码”时，在本机为直播网址、Doorkeeper 网址、STORES（経費）和问卷生成二维码，不使用外部服务。
- 在“最近活动链接位置”放置指向活动文件夹的链接。
- 写出后会显示值为空的变量和未找到的共用文本。可在“变量列表”中查看所有值。

## 设置
通过“EventDocMaker”>“设置…”（⌘,）打开。
- 启动与常驻：登录时启动、不在程序坞和应用程序切换器中显示、关闭窗口后继续运行、菜单栏图标、启动应用快捷键，以及显示窗口的快捷键（默认 ⌃⌥E）。
- 文件夹：父文件夹、EventDoc 文件夹、最近活动链接位置，以及打开文件夹的应用（Path Finder 或访达）。
- 关于：版本和链接。

## 快捷键
- ⌃⌥E：在任何应用中显示 EventDocMaker 窗口（运行时）
- ⌘N：新建活动　⌘D：复制　⌘⌫：删除
- ⌘R：重新读取　⇧⌘V：从剪贴板中的表填入
- ⌘Return：生成文档
- ⌘0：主窗口　⌘,：设置　⌘W：关闭窗口　⌘?：本帮助

## 权限与隐私
无需特殊权限。仅在选择“从剪贴板中的表填入”时读取剪贴板。不会向外部发送任何内容。

## 常驻与退出
开启“关闭窗口后继续运行”时，关闭窗口不会退出。可从程序坞或访达重新打开，或通过菜单栏图标显示窗口。要退出，请选择“EventDocMaker”>“退出 EventDocMaker”（⌘Q）。退出或切换到其他应用前会存储正在输入的内容。写出过程中不会退出。

## 疑难解答
- 无法点按“生成文档”：请填写 種別、仮の日付 和 タイトル（abc）。缺少的项目显示在活动名称下方。
- 显示“没有模板”：请在“设置”>“文件夹”中确认 EventDoc 文件夹。
- 列表中没有活动：请确认设置中的父文件夹和 EventDoc 文件夹，然后点按“重新读取”。
- 想撤销删除：从废纸篓将 event.json（或 EventData 中的 .json）移回原处，然后点按“重新读取”。
""",
 "ko": """## 기본 조작
EventDocMaker는 이벤트마다 정보를 저장해 관리하고, 그 정보를 템플릿에 넣어 안내문, 메일, 공지 등의 문서를 한꺼번에 만듭니다.
- 왼쪽 목록에서 이벤트를 고르고 오른쪽 '개최 전'·'종료 후' 탭에서 정보를 입력합니다. 입력한 내용은 자동으로 저장됩니다.
- '문서 만들기' 탭에서 내용을 확인하고 '문서 만들기'(⌘Return)를 누릅니다.
- 목록은 최신 날짜부터 정렬됩니다. 위 칸에서 이벤트 이름, #, 날짜, 출연자로 찾을 수 있습니다.
- +로 새 이벤트(⌘N), −로 삭제(⌘⌫), 겹친 사각형으로 복제(⌘D)합니다. 복제하면 날짜와 '종료 후' 값은 비웁니다.

## 저장 위치
- 이벤트 폴더(상위 폴더/종류-임시 날짜-제목(abc))가 있으면 그 안의 event.json에 저장합니다.
- 아직 폴더가 없는 이벤트는 EventDoc/EventData에 저장하고 목록에 물음표가 붙은 폴더 표시를 합니다. '문서 만들기'로 폴더가 생기면 event.json이 그 안으로 옮겨집니다.
- 種別, 仮の日付, タイトル（abc）를 바꾸면 저장 위치도 새 폴더 이름에 맞춰 바뀝니다.
- 두 곳 모두 Dropbox 안이므로 다른 Mac에서도 같은 정보를 씁니다. 다른 Mac에서 바꾼 내용은 파일 > 다시 읽기(⌘R)로 읽습니다. 두 대에서 같은 이벤트를 동시에 편집하면 나중에 저장한 쪽이 남습니다.

## Excel에서 가져오기
'Excel에서 가져오기…'로 '配信に関してのまとめ.xlsx'를 고릅니다. 시트 '新しいまとめ'의 A열 항목 이름과 B열부터 한 열에 한 이벤트(3행이 #)를 읽습니다.
- 이미 있는 이벤트(#가 같음)는 그대로 둡니다. 확인 화면에서 덮어쓰기를 고르면 덮어씁니다.
- 날짜와 시간은 20261202, 21:00 같은 형식으로 바꿔 가져옵니다. Excel은 바꾸지 않습니다.
- 표에 두 번 나오는 항목(X 광고와 CSS Nite 광고의 Spend 등)은 'CSS Nite：Spend'처럼 별도 항목이 됩니다.
- 파일 > 클립보드의 표에서 입력(⇧⌘V)은 Excel에서 복사한 '항목⇥값' 두 열을 선택한 이벤트에 입력합니다.

## 만드는 것
- EventDoc 폴더의 Templates에 있는 각 파일을 %Variable%Event…%를 값으로 바꿔 이벤트 폴더의 docs에 씁니다(같은 이름의 파일은 덮어씁니다).
- 빈 항목은 이전 Excel처럼 '-'로 넣습니다(Doorkeeper 구매자 수는 '0', 설문 마감은 '準備中').
- 99-stores.txt가 있으면 'CeeBeeDee-임시 날짜-제목(abc).txt' 사본도 만듭니다.
- 'QR 코드도 만들기'를 켜면 방송 URL, Doorkeeper URL, STORES(経費), 설문의 QR 코드를 Mac에서 만들며 외부 서비스를 쓰지 않습니다.
- '최근 이벤트 링크 위치'에 이벤트 폴더로의 링크를 둡니다.
- 만든 후에는 값이 빈 변수와 찾지 못한 공통 문서를 표시합니다. '변수 목록'에서 모든 값을 확인할 수 있습니다.

## 설정
EventDocMaker > 설정…(⌘,)으로 엽니다.
- 실행·상주: 로그인 시 실행, Dock 및 앱 전환기에 표시 안 함, 윈도우를 닫아도 계속 실행, 메뉴 막대 아이콘, 앱 실행 키보드 단축키, 윈도우를 표시하는 단축키(기본 ⌃⌥E).
- 폴더: 상위 폴더, EventDoc 폴더, 최근 이벤트 링크 위치, 폴더를 열 앱(Path Finder 또는 Finder).
- 정보: 버전과 링크.

## 단축키
- ⌃⌥E: 어느 앱에서든 EventDocMaker 윈도우 표시(실행 중일 때)
- ⌘N: 새 이벤트　⌘D: 복제　⌘⌫: 삭제
- ⌘R: 다시 읽기　⇧⌘V: 클립보드의 표에서 입력
- ⌘Return: 문서 만들기
- ⌘0: 메인 윈도우　⌘,: 설정　⌘W: 윈도우 닫기　⌘?: 이 도움말

## 권한과 개인정보
특별한 권한은 필요 없습니다. 클립보드는 '클립보드의 표에서 입력'을 고를 때만 읽습니다. 내용을 외부로 보내지 않습니다.

## 상주와 종료
'윈도우를 닫아도 계속 실행'이 켜져 있으면 윈도우를 닫아도 종료하지 않습니다. Dock이나 Finder에서 다시 열거나 메뉴 막대 아이콘에서 윈도우를 표시할 수 있습니다. 종료하려면 EventDocMaker > EventDocMaker 종료(⌘Q)를 선택합니다. 종료하거나 다른 앱으로 바꾸기 전에 입력 중인 내용을 저장합니다. 쓰는 중에는 종료하지 않습니다.

## 문제 해결
- '문서 만들기'를 누를 수 없음: 種別, 仮の日付, タイトル（abc）를 넣으세요. 부족한 것은 이벤트 이름 아래에 표시합니다.
- '템플릿이 없습니다'가 표시됨: 설정 > 폴더에서 EventDoc 폴더를 확인하세요.
- 목록에 이벤트가 나오지 않음: 설정의 상위 폴더와 EventDoc 폴더를 확인하고 '다시 읽기'를 누르세요.
- 삭제를 되돌리고 싶을 때: 휴지통에서 event.json(또는 EventData의 .json)을 원래 위치로 되돌리고 '다시 읽기'를 누릅니다.
""",
}
