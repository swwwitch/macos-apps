# VectorKeys help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
VectorKeysは、登録したスクリプト（.jsx）を、Illustratorが前面のときにキーボードショートカットで実行します。
- ［ファイル］＞［スクリプトを追加…］（⌘O）でファイルを選ぶか、ウインドウへ .jsx ファイルをドラッグします。複数まとめて追加できます。
- 一覧で選ぶと、右側にファイルの場所とショートカットの欄が出ます。ホットキー欄をクリックしてからキーを押すと割り当てます。
- 一覧のチェックボックスで、スクリプトごとにショートカットのオン・オフを切り替えます。
- ［実行］を押すと、Illustratorを前面にしてから実行します。
- 右上の「ホットキーを使う」をオフにすると、すべてのショートカットを一時停止します（メニューバーのアイコンからも切り替えられます）。
- 「最近の実行」に直近の結果が出ます。エラーで止まったときは、Illustratorが返したメッセージを表示します。履歴は保存せず、終了すると消えます。

## スクリプトの実行
登録できる手順はスクリプトファイルだけです。複数のスクリプトは上から順に実行します。途中でエラーになったら停止します。
- ［スクリプトの実行］で追加し、各行の … から上へ・下へ・削除を選びます。
- 以前に保存したメニュー手順は削除せず保持します。メニュー手順が1つでもある項目は実行せず、ホットキーも登録しません。メニュー手順を明示的に削除すると残りのスクリプトを実行できます。

## スクリプトの管理
- 追加できるのは .jsx・.js・.jsxbin です。同じファイルは二重に登録しません。
- 名前は欄で変えられます。ファイル名は変わりません。
- 一覧はドラッグで並べ替えられます（検索中を除く）。
- ファイルを移動・名前変更したときは「ファイルなし」と出ます。［ファイルを選び直す…］で指定し直すと、ショートカットはそのまま使えます。
- スクリプトはファイルの場所を覚えているだけです。中身を書き換えたら、次の実行から新しい内容で動きます。
- 一覧の右と詳細欄に、実行した回数と最後に実行した日時が出ます。ショートカットと［実行］ボタンで、エラーなく終わったものを数えます。［表示］＞［使用回数を表示］をオフにすると隠します（数えるのは続けます）。

## Keyboard Maestroから取り込む
Keyboard Maestroで書き出したマクロ（.kmmacros）をウインドウへドラッグするか、［ファイル］＞［Keyboard Maestroから取り込む…］（⌘I）で選びます。
- すべての有効な手順がスクリプト実行であるマクロだけを取り込みます（ファイル指定・マクロ内のJSXコード）。メニュー操作やほかの動作を含むマクロは、スクリプト部分だけを抜き出さず全体をスキップします。名前・ホットキー・オン／オフは保持します。
- マクロに書かれたコードは .jsx ファイルとして ~/Library/Application Support/VectorKeys/Imported に保存します。
- ほかの手順があるマクロや変数を使うマクロは取り込まず、理由を表示します。
- Keyboard Maestro側の同じマクロは、オフにしてください。有効なままだとスクリプトが2回実行されます。取り込み後のダイアログボックスのボタン、または［ツール］＞［選んだスクリプトのKMマクロをオフにする］でオフにできます（オンに戻す項目もあります）。初めて使うときはKeyboard Maestroを操作する許可を求められます。

## カテゴリ
左の列でスクリプトをカテゴリに分けられます。
- 下の＋で新しいカテゴリを作ります。右クリックで名前の変更・削除ができます。削除しても中のスクリプトは消えず、「未分類」に移ります。
- スクリプトのカテゴリは、右側の「カテゴリ」で選ぶか、一覧の行を左のカテゴリへドラッグするか、右クリックの［カテゴリ］で変えます。⌘クリック・⇧クリックで複数選ぶと、まとめてドラッグ・変更・削除できます。
- カテゴリを選んでいる間に追加したスクリプトは、そのカテゴリに入ります。「すべて」ではカテゴリごとに見出しを付けて並べます。
- Keyboard Maestroから取り込むと、マクロのグループ名がカテゴリになります。

## ツール
- ［ツール］＞［統計…］：すべてのスクリプトを使った回数の多い順に、カテゴリ・最終実行日時・ショートカットを添えて表示します。行をダブルクリックすると、メインウインドウでそのスクリプトを選びます。
- ［ツール］＞［アイテム名の検索と置換…］：一覧で選んだスクリプト（複数可）の名前を検索・置換します。置換前→置換後を確かめてから［置換］を押します。正規表現（$1 などで参照）と大文字・小文字の区別を選べます。ファイル名は変わりません。
- ［ツール］＞［KMマクロのナンバリングを削除］：一覧で選んだスクリプト（複数可）の名前の先頭から「11)」「21）」「11)1 」のような番号を外します。ファイル名は変わりません。

## 並べ替え
検索欄の右で、手動・名前順・ショートカット順を選べます。ドラッグで並べ替えられるのは「手動」で検索していないときです。同じキーが重なったときは、手動の並びで上にあるスクリプトが反応します。

## ショートカット
- 押し方：「1回押す」と「2回押す」を選べます。同じキーに両方を割り当てると、1回押すほうは2回目を待つ分（約0.3秒）遅れて実行します。一覧では2回押すキーに「×2」が付きます。
- キーの欄をクリックすると記録を始めます。もう一度クリックするか、Escで取り消します。
- スクリプトのショートカット：Illustratorが前面のときだけ登録します。ほかのアプリでは、同じキーが本来の働きをします。Illustrator自身のショートカットと同じキーにすると、こちらが優先されます。
- アプリを呼び出すショートカット：設定の「起動・常駐」で割り当てると、どのアプリからでもVectorKeysのウインドウを表示します（初期値は未設定）。
- ⌘O：スクリプトを追加
- ⌘I：Keyboard Maestroから取り込む
- ⌘F：アイテム名の検索と置換（一覧でスクリプトを選んでいるとき）
- ⌘0：メインウインドウを開く
- ⌘,：設定
- ⌘W：ウインドウを閉じる
- ⌘?：このヘルプ
同じキーのスクリプトが2つあるときは、一覧で上にあるほうだけが反応し、キーを赤で表示します。

## 権限とプライバシー
- オートメーション（Adobe Illustrator）：スクリプトの実行に使います。初めての実行で許可を求められます。
- オートメーション（Keyboard Maestro）：取り込んだ元のマクロのオン・オフに使います。
- アクセシビリティの許可は不要です。Illustratorへのスクリプト実行にはオートメーションを使います。
一覧は ~/Library/Application Support/VectorKeys/Scripts.json に保存します。スクリプトのファイルは読むだけで、書き換えません。外部への送信はしません。

## 終了と常駐
ウインドウを閉じても常駐し、ショートカットは働き続けます。Dockやメニューバーのアイコンから再表示できます。［VectorKeys］＞［VectorKeysを終了］（⌘Q）で終了します。

## 困ったときは
- ショートカットが効かない：Illustratorが前面か、「ホットキーを使う」がオンか、スクリプトのチェックがオンかを確かめてください。キーが赤いときは、重複か、ほかのアプリが使っています。
- 「Illustratorを操作する許可がありません」：システム設定＞プライバシーとセキュリティ＞オートメーションで、VectorKeysのAdobe Illustratorをオンにしてください。
- 「ファイルが見つかりません」：［ファイルを選び直す…］で指定し直してください。
- 前の実行が終わらない：ダイアログボックスを出すスクリプトは、閉じるまで次の実行を待たせます。待ちは3件までで、それ以上は実行しません。

## 削除と復元
一覧で選んで－ボタン（またはdeleteキー）で削除します。ファイルそのものは消えません（Keyboard Maestroから取り込んだコードの .jsx だけは、ほかで使っていなければゴミ箱へ移します）。削除・名前の変更（ツール）・カテゴリの変更・取り込みは［編集］＞［取り消す］（⌘Z）で戻せます。すべて消すときは、アプリを終了してから Scripts.json を削除します。
""",
 "en": """## Basics
VectorKeys runs your scripts (.jsx) with keyboard shortcuts while Illustrator is in front.
- Choose File > Add Scripts… (⌘O), or drag .jsx files onto the window. You can add several at once.
- Select a script to see its file and shortcut on the right. Click the hotkey field, then press the keys to assign.
- The checkbox in the list turns each script's shortcut on or off.
- Run brings Illustrator to the front, then runs the script.
- Turn off "Use hotkeys" at the top right to pause all shortcuts (also from the menu bar icon).
- Recent Runs shows the latest results. When a script stops with an error, Illustrator's message is shown. Not saved; cleared when the app quits.

## Running scripts
Only script files can be added as steps. Multiple scripts run in order and stop at the first error.
- Add a file with Run Script. Use each row’s … menu to move it or remove it.
- Saved legacy menu steps are retained. An item containing any menu step does not run or register a hotkey. Explicitly remove those steps to run its remaining scripts.

## Managing scripts
- You can add .jsx, .js and .jsxbin files. The same file is not added twice.
- Change the name in its field. The file name stays.
- Drag to reorder the list (not while searching).
- A moved or renamed file shows "Missing". Choose Another File… points to it again and keeps the shortcut.
- Only the file's location is stored. Edit the script and the next run uses the new contents.
- The list and the detail pane show how many times a script ran and when it last ran. Runs from the shortcut or the Run button that finish without an error are counted. Turn off View > Show run counts to hide them (counting continues).

## Import from Keyboard Maestro
Drag macros exported from Keyboard Maestro (.kmmacros) onto the window, or choose File > Import from Keyboard Maestro… (⌘I).
- Import only macros whose active steps are script files or embedded JSX. Skip an entire macro if it includes a menu operation or another unsupported action; never import only its script portion. Names, hotkeys and enabled states are preserved.
- Code written in a macro is saved as a .jsx file in ~/Library/Application Support/VectorKeys/Imported.
- Macros with other steps or variables are not imported; the reason is shown.
- Turn the same macros off in Keyboard Maestro, or the scripts run twice. Use the button after importing, or Tools > Turn Off the Selected Scripts’ KM Macros (there is also an item to turn them back on). The first time, you are asked to allow controlling Keyboard Maestro.

## Categories
The left column sorts scripts into categories.
- Click + below to make a category. Right-click to rename or delete it. Deleting keeps its scripts; they become Uncategorized.
- Set a script's category with Category on the right, by dragging its row onto a category, or with Category in the right-click menu. Select several with ⌘-click or ⇧-click to drag, change or delete them together.
- Scripts added while a category is chosen go into it. All shows the scripts under a heading for each category.
- Macros imported from Keyboard Maestro take their group name as the category.

## Tools
- Tools > Statistics…: every script by run count, with its category, last run and shortcut. Double-click a row to select it in the main window.
- Tools > Find and Replace in Names…: finds and replaces in the selected scripts' names, with a before → after preview. Regular expressions ($1 for groups) and Match case are available. File names stay.
- Tools > Remove KM Macro Numbering: removes numbering such as "11)" or "11)1 " from the start of the selected scripts' names (several at once). File names stay.

## Sorting
Next to the search field, choose Manual, By Name or By Shortcut. Dragging rows works in Manual while not searching. When scripts share a key, the one higher in the manual order reacts.

## Shortcuts
- Press: choose Press once or Press twice. When a key has both, the Press once script waits for a second press (about 0.3 s) before it runs. Keys pressed twice show "×2" in the list.
- Click the key field to record a key. Click it again or press Esc to cancel.
- Script shortcuts: registered only while Illustrator is in front, so the same keys keep their meaning in other apps. A key that Illustrator also uses runs the script instead.
- App shortcut: assign it in Settings > Launch & Background to show the VectorKeys window from any app (none by default).
- ⌘O: Add scripts
- ⌘I: Import from Keyboard Maestro
- ⌘F: Find and replace in names (while scripts are selected)
- ⌘0: Open the main window
- ⌘,: Settings
- ⌘W: Close the window
- ⌘?: This help
When two scripts share a key, only the one higher in the list reacts, and the key is shown in red.

## Permissions and privacy
- Automation (Adobe Illustrator): used to run the scripts. You are asked the first time.
- Automation (Keyboard Maestro): used to turn imported original macros off or on.
- Accessibility access is not required. Running scripts in Illustrator uses Automation.
The list is saved in ~/Library/Application Support/VectorKeys/Scripts.json. Script files are only read, never changed. Nothing is sent outside.

## Quitting and staying open
Closing the window keeps the app running and the shortcuts working. Reopen it from the Dock or the menu bar icon. Quit with VectorKeys > Quit VectorKeys (⌘Q).

## Troubleshooting
- A shortcut does nothing: check that Illustrator is in front, "Use hotkeys" is on and the script's checkbox is on. A red key is a duplicate or is used by another app.
- "Not allowed to control Illustrator": turn on Adobe Illustrator for VectorKeys in System Settings > Privacy & Security > Automation.
- "File not found": use Choose Another File… to point to it again.
- An earlier run does not finish: a script that shows a dialog box holds the next run until it is closed. Up to 3 runs wait; more are skipped.

## Removing and restoring
Select a script and click − (or press Delete). The file itself is not deleted (only .jsx files saved from Keyboard Maestro code go to the Trash when nothing else uses them). Deleting, renaming with Tools, changing categories and importing can be undone with Edit > Undo (⌘Z). To clear everything, quit the app and delete Scripts.json.
""",
 "zh-Hans": """## 基本操作
VectorKeys 在 Illustrator 位于前台时，用键盘快捷键运行已登记的脚本（.jsx）。
- 选择“文件”>“添加脚本…”（⌘O），或将 .jsx 文件拖到窗口中。可一次添加多个。
- 在列表中选择脚本，右侧会显示文件位置和快捷键栏。点按快捷键栏后按下按键即可分配。
- 列表中的复选框可逐个开关脚本的快捷键。
- 点按“运行”会先将 Illustrator 置于前台再运行。
- 关闭右上角的“使用快捷键”可暂停所有快捷键（也可从菜单栏图标切换）。
- “最近运行”显示最近的结果。因错误停止时，会显示 Illustrator 返回的信息。不会保存，退出应用时清除。

## 运行脚本
只能添加脚本文件作为步骤。多个脚本依次运行，遇到错误即停止。
- 用“运行脚本”添加文件，通过各行的 … 菜单移动或删除。
- 保留以前保存的菜单步骤。只要包含菜单步骤，整个项目就不会运行，也不会注册快捷键。明确删除这些步骤后即可运行其余脚本。

## 管理脚本
- 可添加 .jsx、.js 和 .jsxbin。同一文件不会重复登记。
- 可在名称栏中更改名称，文件名不变。
- 可拖移列表以重新排序（搜索时除外）。
- 文件被移动或重命名后会显示“文件丢失”。用“重新选择文件…”重新指定后，快捷键仍可使用。
- 只记录文件的位置。修改脚本内容后，下次运行即使用新内容。
- 列表右侧和详细栏会显示运行次数和最近运行时间。统计通过快捷键和“运行”按钮无错误完成的运行。关闭“显示”>“显示使用次数”即可隐藏（仍会继续计数）。

## 从 Keyboard Maestro 导入
将从 Keyboard Maestro 导出的宏（.kmmacros）拖到窗口中，或选择“文件”>“从 Keyboard Maestro 导入…”（⌘I）。
- 只导入全部有效步骤都是脚本文件或内嵌 JSX 的宏。含菜单操作或其他不支持动作的宏会整体跳过，不会只提取脚本部分。保留名称、快捷键和开关状态。
- 宏中写入的代码会存储为 .jsx 文件，位于 ~/Library/Application Support/VectorKeys/Imported。
- 含其他步骤或使用变量的宏不会导入，并显示原因。
- 请在 Keyboard Maestro 中关闭相同的宏，否则脚本会运行两次。可用导入后对话框中的按钮，或“工具”>“关闭所选脚本的 KM 宏”关闭（也有重新打开的项目）。首次使用时会请求控制 Keyboard Maestro 的许可。

## 类别
左栏可将脚本分到各个类别。
- 点按下方的 + 新建类别。右键点按可重命名或删除。删除后其中的脚本不会被删除，而是移到“未分类”。
- 可在右侧的“类别”中选择，或将列表中的行拖到左侧类别，或用右键菜单中的“类别”更改脚本的类别。用 ⌘点按或⇧点按选择多个后，可一并拖移、更改或删除。
- 选中某个类别时添加的脚本会进入该类别。“全部”会按类别分标题显示。
- 从 Keyboard Maestro 导入时，宏的组名会成为类别。

## 工具
- “工具”>“统计…”：按使用次数从多到少显示所有脚本，并附上类别、最近运行时间和快捷键。双击某行可在主窗口中选中该脚本。
- “工具”>“在名称中查找和替换…”：在所选脚本（可多选）的名称中查找和替换。确认替换前→替换后后点按“替换”。可使用正则表达式（用 $1 等引用）和区分大小写。文件名不变。
- “工具”>“删除 KM 宏编号”：从所选脚本（可多选）名称开头删除“11)”“21）”“11)1 ”之类的编号。文件名不变。

## 排序
可在搜索栏右侧选择手动、按名称或按快捷键。在“手动”且未搜索时可拖移重新排序。多个脚本使用同一按键时，手动顺序中靠上的脚本会响应。

## 快捷键
- 按法：可选择“按一次”或“按两次”。同一按键同时分配两者时，“按一次”的脚本会等待第二次按下（约 0.3 秒）后再运行。列表中按两次的按键带有“×2”。
- 点按按键栏即开始录制。再次点按或按 Esc 取消。
- 脚本快捷键：仅在 Illustrator 位于前台时注册，因此在其他应用中按键保持原有功能。若与 Illustrator 自身的快捷键相同，则优先运行脚本。
- 调出应用的快捷键：在设置的“启动与常驻”中分配后，可从任何应用显示 VectorKeys 窗口（默认未设置）。
- ⌘O：添加脚本
- ⌘I：从 Keyboard Maestro 导入
- ⌘F：在名称中查找和替换（在列表中选中脚本时）
- ⌘0：打开主窗口
- ⌘,：设置
- ⌘W：关闭窗口
- ⌘?：本帮助
两个脚本使用同一按键时，只有列表中靠上的脚本会响应，按键以红色显示。

## 权限与隐私
- 自动化（Adobe Illustrator）：用于运行脚本。首次运行时会请求许可。
- 自动化（Keyboard Maestro）：用于关闭或打开已导入的原始宏。
- 无需辅助功能权限。在 Illustrator 中运行脚本使用自动化权限。
列表存储在 ~/Library/Application Support/VectorKeys/Scripts.json。脚本文件只读取，不会修改。不会向外部发送任何内容。

## 退出与常驻
关闭窗口后应用仍会常驻，快捷键继续有效。可从 Dock 或菜单栏图标再次打开。选择“VectorKeys”>“退出 VectorKeys”（⌘Q）退出。

## 疑难解答
- 快捷键无效：请确认 Illustrator 位于前台、“使用快捷键”已打开、脚本的复选框已勾选。按键显示为红色时，表示重复或被其他应用占用。
- “没有控制 Illustrator 的权限”：请在“系统设置”>“隐私与安全性”>“自动化”中为 VectorKeys 打开 Adobe Illustrator。
- “找不到文件”：请用“重新选择文件…”重新指定。
- 之前的运行未结束：显示对话框的脚本会让下一次运行等待到对话框关闭。最多等待 3 次，超出的会被跳过。

## 删除与恢复
在列表中选择后点按 −（或按 Delete 键）删除。文件本身不会被删除（仅从 Keyboard Maestro 代码保存的 .jsx 在没有其他用途时移到废纸篓）。删除、用工具重命名、更改类别和导入可用“编辑”>“撤销”（⌘Z）还原。若要全部清除，请退出应用后删除 Scripts.json。
""",
 "ko": """## 기본 조작
VectorKeys는 Illustrator가 앞에 있을 때 등록한 스크립트(.jsx)를 키보드 단축키로 실행합니다.
- [파일] > [스크립트 추가…](⌘O)로 파일을 선택하거나 윈도우로 .jsx 파일을 드래그합니다. 여러 개를 한 번에 추가할 수 있습니다.
- 목록에서 선택하면 오른쪽에 파일 위치와 단축키 칸이 나타납니다. 단축키 칸을 클릭한 뒤 키를 누르면 지정됩니다.
- 목록의 체크상자로 스크립트별 단축키를 켜고 끕니다.
- [실행]을 클릭하면 Illustrator를 앞으로 가져온 뒤 실행합니다.
- 오른쪽 위의 '단축키 사용'을 끄면 모든 단축키를 일시 정지합니다(메뉴 막대 아이콘에서도 전환 가능).
- '최근 실행'에 최근 결과가 표시됩니다. 오류로 멈추면 Illustrator가 반환한 메시지를 표시합니다. 저장하지 않으며 앱을 종료하면 지워집니다.

## 스크립트 실행
스크립트 파일만 단계로 추가합니다. 여러 스크립트는 순서대로 실행하며 오류가 나면 중지합니다.
- [스크립트 실행]으로 파일을 추가하고 각 행의 …에서 이동하거나 삭제합니다.
- 이전에 저장한 메뉴 단계는 보존합니다. 메뉴 단계가 있는 항목은 실행하거나 단축키를 등록하지 않습니다. 해당 단계를 직접 삭제하면 남은 스크립트를 실행할 수 있습니다.

## 스크립트 관리
- .jsx, .js, .jsxbin을 추가할 수 있습니다. 같은 파일은 중복 등록하지 않습니다.
- 이름은 칸에서 바꿀 수 있습니다. 파일 이름은 바뀌지 않습니다.
- 목록은 드래그로 순서를 바꿀 수 있습니다(검색 중 제외).
- 파일을 이동하거나 이름을 바꾸면 '파일 없음'이 표시됩니다. [파일 다시 선택…]으로 다시 지정하면 단축키를 그대로 쓸 수 있습니다.
- 파일 위치만 기억합니다. 스크립트 내용을 고치면 다음 실행부터 새 내용으로 동작합니다.
- 목록 오른쪽과 상세 칸에 실행 횟수와 마지막 실행 일시가 표시됩니다. 단축키와 [실행] 버튼으로 오류 없이 끝난 실행을 셉니다. [보기] > [사용 횟수 표시]를 끄면 숨깁니다(횟수는 계속 셉니다).

## Keyboard Maestro에서 가져오기
Keyboard Maestro에서 내보낸 매크로(.kmmacros)를 윈도우로 드래그하거나 [파일] > [Keyboard Maestro에서 가져오기…](⌘I)로 선택합니다.
- 활성 단계가 모두 스크립트 파일이나 내장 JSX인 매크로만 가져옵니다. 메뉴 조작 등 지원하지 않는 동작이 있으면 스크립트 부분만 추출하지 않고 매크로 전체를 건너뜁니다. 이름, 단축키, 활성 상태는 유지합니다.
- 매크로에 쓰인 코드는 ~/Library/Application Support/VectorKeys/Imported에 .jsx 파일로 저장합니다.
- 다른 단계가 있거나 변수를 쓰는 매크로는 가져오지 않고 이유를 표시합니다.
- Keyboard Maestro의 같은 매크로는 꺼 주세요. 켜져 있으면 스크립트가 두 번 실행됩니다. 가져온 뒤 대화상자의 버튼이나 [도구] > [선택한 스크립트의 KM 매크로 끄기]로 끌 수 있습니다(다시 켜는 항목도 있습니다). 처음 사용할 때 Keyboard Maestro 제어 허용을 요청합니다.

## 카테고리
왼쪽 열에서 스크립트를 카테고리로 나눌 수 있습니다.
- 아래의 +로 새 카테고리를 만듭니다. 오른쪽 클릭으로 이름 변경·삭제를 할 수 있습니다. 삭제해도 안의 스크립트는 지워지지 않고 '미분류'로 옮겨집니다.
- 스크립트의 카테고리는 오른쪽의 '카테고리'에서 고르거나, 목록의 행을 왼쪽 카테고리로 드래그하거나, 오른쪽 클릭의 [카테고리]로 바꿉니다. ⌘클릭·⇧클릭으로 여러 개를 고르면 한꺼번에 드래그·변경·삭제할 수 있습니다.
- 카테고리를 선택한 상태에서 추가한 스크립트는 그 카테고리에 들어갑니다. '전체'에서는 카테고리별 제목을 붙여 표시합니다.
- Keyboard Maestro에서 가져오면 매크로의 그룹 이름이 카테고리가 됩니다.

## 도구
- [도구] > [통계…]: 모든 스크립트를 사용 횟수가 많은 순으로 카테고리·최근 실행·단축키와 함께 표시합니다. 행을 더블클릭하면 메인 윈도우에서 그 스크립트를 선택합니다.
- [도구] > [이름 찾기 및 바꾸기…]: 목록에서 선택한 스크립트(여러 개 가능)의 이름을 찾아 바꿉니다. 바뀌기 전→후를 확인한 뒤 [바꾸기]를 누릅니다. 정규 표현식($1 등으로 참조)과 대소문자 구분을 고를 수 있습니다. 파일 이름은 바뀌지 않습니다.
- [도구] > [KM 매크로 번호 삭제]: 목록에서 선택한 스크립트(여러 개 가능) 이름 앞의 '11)', '21）', '11)1 ' 같은 번호를 지웁니다. 파일 이름은 바뀌지 않습니다.

## 정렬
검색 칸 오른쪽에서 수동·이름순·단축키순을 고를 수 있습니다. 드래그로 순서를 바꿀 수 있는 것은 '수동'이고 검색하지 않을 때입니다. 같은 키를 쓰는 스크립트가 있으면 수동 순서에서 위에 있는 것이 반응합니다.

## 단축키
- 누르는 방법: '한 번 누르기'와 '두 번 누르기'를 고를 수 있습니다. 같은 키에 둘 다 지정하면 한 번 누르기 쪽은 두 번째 누름을 기다리는 만큼(약 0.3초) 늦게 실행됩니다. 목록에서 두 번 누르는 키에는 '×2'가 붙습니다.
- 키 칸을 클릭하면 기록을 시작합니다. 다시 클릭하거나 Esc로 취소합니다.
- 스크립트 단축키: Illustrator가 앞에 있을 때만 등록하므로 다른 앱에서는 같은 키가 원래 기능을 합니다. Illustrator 자체 단축키와 같은 키라면 스크립트가 우선합니다.
- 앱을 불러오는 단축키: 설정의 '실행 및 상주'에서 지정하면 어느 앱에서든 VectorKeys 윈도우를 표시합니다(기본값은 없음).
- ⌘O: 스크립트 추가
- ⌘I: Keyboard Maestro에서 가져오기
- ⌘F: 이름 찾기 및 바꾸기(목록에서 스크립트를 선택했을 때)
- ⌘0: 메인 윈도우 열기
- ⌘,: 설정
- ⌘W: 윈도우 닫기
- ⌘?: 이 도움말
같은 키의 스크립트가 두 개 있으면 목록에서 위에 있는 것만 반응하고 키를 빨간색으로 표시합니다.

## 권한과 개인정보
- 자동화(Adobe Illustrator): 스크립트 실행에 사용합니다. 처음 실행할 때 허용을 요청합니다.
- 자동화(Keyboard Maestro): 가져온 원래 매크로를 끄고 켜는 데 사용합니다.
- 손쉬운 사용 권한은 필요하지 않습니다. Illustrator에서 스크립트를 실행할 때 자동화 권한을 사용합니다.
목록은 ~/Library/Application Support/VectorKeys/Scripts.json에 저장합니다. 스크립트 파일은 읽기만 하고 수정하지 않습니다. 외부로 아무것도 보내지 않습니다.

## 종료와 상주
윈도우를 닫아도 상주하며 단축키는 계속 작동합니다. Dock이나 메뉴 막대 아이콘에서 다시 열 수 있습니다. [VectorKeys] > [VectorKeys 종료](⌘Q)로 종료합니다.

## 문제 해결
- 단축키가 작동하지 않음: Illustrator가 앞에 있는지, '단축키 사용'이 켜져 있는지, 스크립트의 체크상자가 켜져 있는지 확인하세요. 키가 빨간색이면 중복이거나 다른 앱이 사용 중입니다.
- 'Illustrator를 제어할 권한이 없습니다': 시스템 설정 > 개인정보 보호 및 보안 > 자동화에서 VectorKeys의 Adobe Illustrator를 켜세요.
- '파일을 찾을 수 없습니다': [파일 다시 선택…]으로 다시 지정하세요.
- 이전 실행이 끝나지 않음: 대화상자를 띄우는 스크립트는 닫을 때까지 다음 실행을 기다리게 합니다. 대기는 3건까지이며 그 이상은 실행하지 않습니다.

## 삭제와 복원
목록에서 선택하고 − 버튼(또는 Delete 키)으로 삭제합니다. 파일 자체는 삭제되지 않습니다(Keyboard Maestro 코드에서 저장한 .jsx만 다른 곳에서 쓰지 않으면 휴지통으로 옮깁니다). 삭제, 도구로 이름 변경, 카테고리 변경, 가져오기는 [편집] > [실행 취소](⌘Z)로 되돌릴 수 있습니다. 모두 지우려면 앱을 종료한 뒤 Scripts.json을 삭제하세요.
""",
}

SHARING_HELP = {'ja': '設定の「設定の共有」で書き出し・読み込み・iCloud DriveやDropboxなどのフォルダー同期ができます。読み込みは確認後に共有設定を置き換えます。同期する全Macを1.5.1以降へ更新してください。 ホットキー全体の有効状態・使用回数表示・並び順を共有します。 スクリプト一覧・実ファイル・項目別ホットキー、起動・常駐・呼び出しホットキー・ウインドウ位置は共有しません。', 'en': 'Share Settings provides export, import and folder sync through iCloud Drive or Dropbox. Import replaces shared preferences after confirmation. Update all syncing Macs to 1.5.1 or later. Shares global hotkey enablement, usage-count display and sort order. The script library, files, per-item hotkeys, startup and residency settings, launcher hotkey and window positions stay on this Mac.', 'zh-Hans': '共享设置标签页提供导出、导入及 iCloud Drive 或 Dropbox 文件夹同步。确认后导入会替换共享设置。所有同步的 Mac 均须更新至 1.5.1 或更高版本。 共享全局快捷键启用状态、使用次数显示和排序。 不共享脚本列表、文件、各项目快捷键、启动与常驻设置、应用启动快捷键及窗口位置。', 'ko': '설정 공유 탭에서 내보내기, 가져오기 및 iCloud Drive나 Dropbox 폴더 동기화를 사용합니다. 확인 후 공유 설정을 교체합니다. 모든 동기화 Mac을 1.5.1 이상으로 업데이트하세요. 전체 단축키 활성 상태, 사용 횟수 표시와 정렬 순서를 공유합니다. 스크립트 목록과 파일, 항목별 단축키, 시작 및 상주 설정, 앱 호출 단축키와 윈도우 위치는 공유하지 않습니다.'}
for language, text in SHARING_HELP.items():
    HELP[language] += "\n\n" + text + "\n"

for lang, note in {"ja": "［ファイル］＞［JavaScriptコードを追加］で直書き項目を作成し、編集欄へコードを入力します。ファイル指定と直書きコードは手順として混在でき、上から順に実行します。空のコードは実行できません。コードは保存され、再起動後も編集できます。", "en": "Choose File > Add JavaScript Code and enter code in the editor. File and inline code steps can be mixed and run in order. Empty code cannot run. Code is saved for editing after restart.", "zh-Hans": "选择文件 > 添加 JavaScript 代码，在编辑框中输入代码。文件和代码步骤可混合并按顺序运行。空代码无法运行。代码会保存，重启后可继续编辑。", "ko": "파일 > JavaScript 코드 추가를 선택하고 편집기에 코드를 입력하세요. 파일과 코드 단계를 섞어 순서대로 실행할 수 있습니다. 빈 코드는 실행되지 않습니다. 코드는 저장되며 재시작 후 편집할 수 있습니다."}.items():
    HELP[lang] += "\n\n## JavaScript\n" + note + "\n"

for lang, note in {"ja": "カテゴリを選び、カテゴリ欄下部のパレットボタン、または［表示］＞［パレットとして表示］を選びます。カテゴリの右クリックメニューからも開けます。複数カテゴリを同時表示でき、ボタンをクリックするとIllustratorで実行します。パレットは前面に残り、位置とサイズを保持します。閉じるボタンで非表示にでき、同じ操作で再表示できます。無効・実行不可の項目は実行できません。終了するとパレットも閉じます。再起動時は自動で開きません。", "en": "Select a category and click the palette button below the categories, or choose View > Show as Palette. The category context menu also opens it. Multiple category palettes can stay open; click a script to run it in Illustrator. Palettes float and remember their position and size. Close to hide, then reopen with the same command. Disabled or unavailable items cannot run. Palettes close when VectorKeys quits and do not reopen automatically.", "zh-Hans": "选择分类，点按分类下方的面板按钮，或选择显示 > 显示为面板。也可从分类右键菜单打开。支持同时显示多个分类面板，点按脚本即可在 Illustrator 中运行。面板保持浮动并记住位置和大小。关闭后可再次打开。已停用或无法运行的项目不可执行。退出应用会关闭面板，重启后不会自动打开。", "ko": "카테고리를 선택한 뒤 카테고리 아래 팔레트 버튼 또는 보기 > 팔레트로 표시를 선택하세요. 카테고리 우클릭 메뉴에서도 열 수 있습니다. 여러 팔레트를 동시에 열고 스크립트를 클릭하여 Illustrator에서 실행할 수 있습니다. 팔레트는 떠 있는 상태로 위치와 크기를 기억합니다. 닫은 후 같은 명령으로 다시 열 수 있습니다. 비활성 또는 실행 불가 항목은 실행되지 않습니다. 앱 종료 시 팔레트도 닫히며 재시작 시 자동으로 열리지 않습니다."}.items():
    HELP[lang] += "\n\n## Palette\n" + note + "\n"

for lang, note in {"ja": "3カラムの境界をドラッグして幅を調整できます。幅はこのMacに保存されます。［設定］＞［パレット］でカテゴリ別の表示ホットキーを設定できます。他のアプリの操作中も有効で、ホットキー全体をオフにすると停止します。設定は一覧と一緒に保存され、カテゴリの改名・削除に追従します。スクリプト内のSCRIPTMETAコメントにScript-IDとVersionがあれば版を表示します。ファイルと直書きに対応。タグなし・読取不可・バイナリは版を表示しません。ローカルファイルの先頭256KiBを読み、再びアプリを操作するときに更新します。", "en": "Drag either column divider to resize; widths stay on this Mac. In Settings > Palettes, assign each category an opening hotkey that works in other apps too. The global hotkey switch pauses these keys. Keys are saved with the library and follow category renaming/deletion. Local SCRIPTMETA comments with Script-ID and Version display the script version, for files and inline code. Missing, unreadable or binary metadata has no version display. The first 256 KiB is read and refreshed on app activation.", "zh-Hans": "拖动列间边界调整宽度，保存在本机。在设置 > 面板中可为每个分类指定打开快捷键，其他应用中也有效。关闭全局快捷键开关可暂停。快捷键随列表保存，并跟随分类重命名与删除。文件和代码中的 SCRIPTMETA 注释若含 Script-ID 和 Version，将显示版本。标签缺失、不可读或二进制则不显示。读取前256KiB，应用激活时刷新。", "ko": "열 경계를 드래그하여 너비를 조정하고 이 Mac에 저장합니다. 설정 > 팔레트에서 카테고리별 열기 단축키를 지정합니다. 다른 앱에서도 작동하며 전체 단축키를 끄면 중지합니다. 목록과 함께 저장되고 카테고리 이름 변경과 삭제를 따릅니다. 파일과 직접 입력 코드의 SCRIPTMETA 주석에 Script-ID와 Version이 있으면 버전을 표시합니다. 태그 없음, 읽기 불가, 바이너리는 표시하지 않습니다. 앞 256KiB를 읽고 앱 활성화 시 갱신합니다."}.items():
    HELP[lang] += "\n\n## Layout / Hotkeys / SCRIPTMETA\n" + note + "\n"

for lang, note in {"ja": "詳細画面の下部にスクリプト情報を表示します。概要はSCRIPTMETAのDescription、版はVersion、URLはMeta-URL、作者はAuthorです。概要はクリックして開きます。READMEはスクリプトと同名の.md、同じフォルダーのREADME.md、README.txtの順に探し、クリックで開きます。メモは項目ごとに入力・保存でき、元のスクリプトは変更しません。複数手順は手順ごとに情報を表示します。取得できない情報は未記載と表示します。", "en": "Script information appears below the detail editor. Overview, version, URL and author come from SCRIPTMETA Description, Version, Meta-URL and Author. Click to expand the overview. README searches for a same-named .md file, then README.md and README.txt in the script folder. Click to open. Notes are saved per item without editing the script. Multiple steps show their own metadata. Missing information is marked Not provided.", "zh-Hans": "详情下方显示脚本信息。概述、版本、URL、作者读取 SCRIPTMETA 的 Description、Version、Meta-URL、Author。点击展开概述。README依次查找脚本同名.md、同目录README.md、README.txt，点击打开。备注随项目保存，不修改原脚本。多个步骤分别显示信息。缺失信息显示未提供。", "ko": "상세 편집기 아래에 스크립트 정보를 표시합니다. 개요, 버전, URL, 작성자는 SCRIPTMETA의 Description, Version, Meta-URL, Author에서 읽습니다. 개요를 클릭하면 펼칩니다. README는 스크립트와 같은 이름의 .md, 같은 폴더의 README.md, README.txt 순으로 찾아 클릭하여 엽니다. 메모는 항목별로 저장하며 원본은 수정하지 않습니다. 여러 단계는 각 정보를 표시하고 누락 정보는 미기재로 표시합니다."}.items():
    HELP[lang] += "\n\n## Script Information\n" + note + "\n"
