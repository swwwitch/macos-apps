# FileSorter help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
FileSorterは常駐して、ルールの「監視するフォルダー」にファイルが加わると、当てはまるものを「移動先」へ移動します。たとえば「ダウンロード」に保存した請求書のPDFを経理のフォルダーへ、音楽ファイルを音楽のフォルダーへ移します。
- 右上の「振り分ける」をオフにすると、移動を止めます。
- ルールは上から順に調べ、最初に当てはまったルールで移動します。一覧のチェックボックスでルールごとにオン・オフを切り替えます。
- ダウンロード中のファイル（.download・.crdownload など）は、書き込みが終わって大きさが変わらなくなってから移動します。
- 移動先に同じ名前があるときは、末尾に番号を付けます（上書きしません）。
- 「最近の処理」に直近の結果が出ます。履歴は保存せず、終了すると消えます。

## ルールの編集
＋ボタンで追加し、ダブルクリックか［編集…］で変更します。並べ替えはドラッグで行います。
- 監視するフォルダー・移動先：［変更…］で選びます。
- 名前に含む語・拡張子：カンマで区切ります。どちらかに当てはまれば移動します。大文字と小文字は区別しません。
- 最初は「請求書」（名前に 請求書・invoice）と「音楽」（mp3・m4a・flac）のルールが入っています。

## 今あるファイル
FileSorterを起動する前からあったファイルは、自動では移動しません。［今あるファイルを振り分ける…］を押すと、ルールに当てはまるファイルの数と一部を確かめてから移動します。

## 設定
［FileSorter］＞［設定…］（⌘,）で開きます。
- 起動・常駐：ログイン時に起動、Dockとアプリケーションスイッチャーに表示しない、ウインドウを閉じても常駐、メニューバーのアイコン、アプリ起動のホットキー、アプリを呼び出すホットキー（初期値 ⌃⌥F）。
- 通知：ファイルを移動したら通知（初期値オフ）。
- 情報：バージョンとリンク。
ルールはフォルダーの場所を含むため、Macごとに設定します。

## ホットキー
- ⌃⌥F：どのアプリからでもFileSorterのウインドウを表示（起動中のとき）
- ⌘0：メインウインドウを開く
- ⌘,：設定
- ⌘W：ウインドウを閉じる
- ⌘?：このヘルプ

## 権限とプライバシー
特別な許可は不要です。「書類」「デスクトップ」などのフォルダーを選んだときは、macOSが最初に許可を確認することがあります。ファイルの中身は読みません。ファイル名や処理の記録を保存・送信しません。

## 常駐と終了
「ウインドウを閉じても常駐」がオンのときは、ウインドウを閉じても監視を続けます。DockやFinderから開き直すか、メニューバーのアイコンからウインドウを表示できます。終了するには［FileSorter］＞［FileSorterを終了］（⌘Q）を選びます。終了中に加わったファイルは、［今あるファイルを振り分ける…］で移動できます。

## 困ったときは
- 移動しない：「振り分ける」とルールがオンか、監視するフォルダーと名前の条件が合っているか、「最近の処理」の理由を確かめてください。
- 「移動先のフォルダーがありません」と出る：移動先が移動・削除されています。ルールを編集して選び直してください。
- 間違えて移動した：移動先のフォルダーから元に戻してください。FileSorterはファイルを削除しません。
""",
 "en": """## Basics
FileSorter keeps running and, when a file is added to a rule's watched folder, moves matching files to its destination—for example invoice PDFs saved to Downloads into an accounting folder, and music files into a music folder.
- Turn off Sort at the top right to stop moving files.
- Rules are checked from the top; the first match moves the file. Use the checkbox in the list to turn each rule on or off.
- Files still downloading (.download, .crdownload and so on) are moved once they are complete and their size stops changing.
- When the name is taken at the destination, a number is added (nothing is overwritten).
- Recent Activity shows the latest results. It is not saved and is cleared when the app quits.

## Editing rules
Add with +; double-click or choose Edit… to change. Reorder by dragging.
- Watched folder / Move to: choose with Change….
- Name contains / Extensions: separate with commas. A file matching either is moved. Case-insensitive.
- Two rules come at first: Invoices (name contains 請求書 or invoice) and Music (mp3, m4a, flac).

## Existing files
Files present before FileSorter started are not moved automatically. Sort Existing Files… shows how many files match (and some of their names) and moves them after you confirm.

## Settings
Open with FileSorter > Settings… (⌘,).
- Launch & Residency: open at login, hide from the Dock and App Switcher, keep running after closing the window, menu bar icon, app launch keyboard shortcut and the hotkey that shows the window (default ⌃⌥F).
- Notifications: notify when files are moved (off at first).
- About: version and links.
Rules hold folder locations, so they are set on each Mac.

## Hotkeys
- ⌃⌥F: show the FileSorter window from any app (while running)
- ⌘0: open the main window
- ⌘,: settings
- ⌘W: close the window
- ⌘?: this help

## Permissions and privacy
No special permission is needed. When you choose folders such as Documents or Desktop, macOS may ask once. File contents are never read. File names and activity are not saved or sent.

## Keeping it running and quitting
With Keep running after closing the window on, watching continues after the window is closed. Reopen from the Dock or Finder, or from the menu bar icon. To quit, choose FileSorter > Quit FileSorter (⌘Q). Files added while it was not running can be moved with Sort Existing Files….

## Troubleshooting
- Nothing is moved: check that Sort and the rule are on, the watched folder and name conditions match, and the reason in Recent Activity.
- “The destination folder is missing”: the destination was moved or deleted. Edit the rule and choose it again.
- A file was moved by mistake: move it back from the destination folder. FileSorter never deletes files.
""",
 "zh-Hans": """## 基本操作
FileSorter 常驻运行，当文件添加到规则的“监视的文件夹”时，将符合条件的文件移到“移动到”。例如将存到“下载”的发票 PDF 移到财务文件夹，将音乐文件移到音乐文件夹。
- 关闭右上角的“分类”即可停止移动。
- 从上到下检查规则，按第一条匹配的规则移动。用列表中的复选框逐条开启或关闭规则。
- 正在下载的文件（.download、.crdownload 等）会在写入完成、大小不再变化后再移动。
- 目标位置有同名文件时会添加编号（不会覆盖）。
- “最近的处理”显示最近的结果。不会保存，退出应用时清除。

## 编辑规则
用 + 添加，双击或选择“编辑…”修改。拖移调整顺序。
- 监视的文件夹／移动到：用“更改…”选择。
- 名称包含／扩展名：用逗号分隔。符合任一项即移动。不区分大小写。
- 初始包含“发票”（名称包含 请求书 或 invoice）和“音乐”（mp3、m4a、flac）两条规则。

## 现有文件
FileSorter 启动前已有的文件不会自动移动。点按“分类现有文件…”，确认符合规则的文件数量和部分名称后再移动。

## 设置
通过“FileSorter”>“设置…”（⌘,）打开。
- 启动与常驻：登录时启动、不在程序坞和应用程序切换器中显示、关闭窗口后继续运行、菜单栏图标、启动应用快捷键，以及显示窗口的快捷键（默认 ⌃⌥F）。
- 通知：移动文件时通知（初始关闭）。
- 关于：版本和链接。
规则包含文件夹位置，因此在每台 Mac 上分别设置。

## 快捷键
- ⌃⌥F：在任何应用中显示 FileSorter 窗口（运行时）
- ⌘0：打开主窗口
- ⌘,：设置
- ⌘W：关闭窗口
- ⌘?：本帮助

## 权限与隐私
无需特殊权限。选择“文稿”“桌面”等文件夹时，macOS 可能会首次询问。不会读取文件内容，也不会保存或发送文件名和处理记录。

## 常驻与退出
开启“关闭窗口后继续运行”时，关闭窗口后仍继续监视。可从程序坞或访达重新打开，或通过菜单栏图标显示窗口。要退出，请选择“FileSorter”>“退出 FileSorter”（⌘Q）。未运行期间新增的文件可用“分类现有文件…”移动。

## 疑难解答
- 没有移动：请确认“分类”和规则已开启、监视的文件夹和名称条件匹配，并查看“最近的处理”中的原因。
- 显示“目标文件夹不存在”：目标位置已被移动或删除。请编辑规则重新选择。
- 误移了文件：请从目标文件夹移回。FileSorter 不会删除文件。
""",
 "ko": """## 기본 조작
FileSorter는 상주하며 규칙의 '감시할 폴더'에 파일이 추가되면 일치하는 파일을 '이동할 곳'으로 옮깁니다. 예를 들어 다운로드에 저장한 청구서 PDF를 경리 폴더로, 음악 파일을 음악 폴더로 옮깁니다.
- 오른쪽 위의 '분류'를 끄면 이동을 멈춥니다.
- 규칙은 위에서부터 확인해 처음 일치한 규칙으로 이동합니다. 목록의 체크박스로 규칙마다 켜고 끕니다.
- 다운로드 중인 파일(.download, .crdownload 등)은 쓰기가 끝나 크기가 바뀌지 않게 된 후 이동합니다.
- 이동할 곳에 같은 이름이 있으면 번호를 붙입니다(덮어쓰지 않음).
- '최근 처리'에 최근 결과가 표시됩니다. 저장하지 않으며 앱을 종료하면 지워집니다.

## 규칙 편집
+로 추가하고, 두 번 클릭하거나 편집…으로 변경합니다. 드래그로 순서를 바꿉니다.
- 감시할 폴더·이동할 곳: 변경…으로 선택합니다.
- 이름에 포함·확장자: 쉼표로 구분합니다. 어느 하나라도 일치하면 이동합니다. 대소문자를 구분하지 않습니다.
- 처음에는 '청구서'(이름에 請求書·invoice)와 '음악'(mp3, m4a, flac) 규칙이 들어 있습니다.

## 기존 파일
FileSorter 실행 전부터 있던 파일은 자동으로 이동하지 않습니다. '기존 파일 분류…'를 누르면 규칙에 맞는 파일 수와 일부 이름을 확인한 후 이동합니다.

## 설정
FileSorter > 설정…(⌘,)으로 엽니다.
- 실행·상주: 로그인 시 실행, Dock 및 앱 전환기에 표시 안 함, 윈도우를 닫아도 계속 실행, 메뉴 막대 아이콘, 앱 실행 키보드 단축키, 윈도우를 표시하는 단축키(기본 ⌃⌥F).
- 알림: 파일을 이동하면 알림(처음에는 끔).
- 정보: 버전과 링크.
규칙은 폴더 위치를 포함하므로 Mac마다 설정합니다.

## 단축키
- ⌃⌥F: 어느 앱에서든 FileSorter 윈도우 표시(실행 중일 때)
- ⌘0: 메인 윈도우 열기
- ⌘,: 설정
- ⌘W: 윈도우 닫기
- ⌘?: 이 도움말

## 권한과 개인정보
특별한 권한은 필요 없습니다. 문서나 데스크탑 같은 폴더를 고르면 macOS가 처음에 확인할 수 있습니다. 파일 내용은 읽지 않습니다. 파일 이름과 처리 기록을 저장·전송하지 않습니다.

## 상주와 종료
'윈도우를 닫아도 계속 실행'이 켜져 있으면 윈도우를 닫아도 감시를 계속합니다. Dock이나 Finder에서 다시 열거나 메뉴 막대 아이콘에서 윈도우를 표시할 수 있습니다. 종료하려면 FileSorter > FileSorter 종료(⌘Q)를 선택합니다. 실행하지 않는 동안 추가된 파일은 '기존 파일 분류…'로 이동할 수 있습니다.

## 문제 해결
- 이동하지 않음: '분류'와 규칙이 켜져 있는지, 감시할 폴더와 이름 조건이 맞는지, '최근 처리'의 이유를 확인하세요.
- '이동할 폴더가 없습니다'가 표시됨: 이동할 곳이 옮겨지거나 삭제되었습니다. 규칙을 편집해 다시 선택하세요.
- 잘못 이동함: 이동할 곳의 폴더에서 되돌려 놓으세요. FileSorter는 파일을 삭제하지 않습니다.
""",
}
