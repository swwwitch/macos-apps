# LayoutKeys help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
LayoutKeysは、登録したスクリプト（.jsx）を、InDesignが前面のときにキーボードショートカットで実行します。
- ［ファイル］＞［スクリプトを追加…］（⌘O）でファイルを選ぶか、ウインドウへ .jsx ファイルをドラッグします。複数まとめて追加できます。
- 一覧で選ぶと、右側にファイルの場所とショートカットの欄が出ます。ショートカットの欄をクリックしてからキーを押すと割り当てます。
- 一覧のチェックボックスで、スクリプトごとにショートカットのオン・オフを切り替えます。
- ［実行］を押すと、InDesignを前面にしてから実行します。
- 1回の実行は、InDesignの［取り消し］1回で戻せます（取り消しの名前はスクリプトの名前です）。
- 右上の「ホットキーを使う」をオフにすると、すべてのショートカットを一時停止します（メニューバーのアイコンからも切り替えられます）。
- 「最近の実行」に直近の結果が出ます。エラーで止まったときは、InDesignが返したメッセージを表示します。履歴は保存せず、終了すると消えます。

## スクリプトの管理
- 追加できるのは .jsx・.js・.jsxbin です。同じファイルは二重に登録しません。
- 名前は欄で変えられます。ファイル名は変わりません。
- 一覧はドラッグで並べ替えられます（検索中を除く）。
- ファイルを移動・名前変更したときは「ファイルなし」と出ます。［ファイルを選び直す…］で指定し直すと、ショートカットはそのまま使えます。
- スクリプトはファイルの場所を覚えているだけです。中身を書き換えたら、次の実行から新しい内容で動きます。
- 一覧の右と詳細欄に、実行した回数と最後に実行した日時が出ます。ショートカットと［実行］ボタンで、エラーなく終わったものを数えます。

## スクリプトの変数（SW_）
スクリプトに「var SW_名前 = 初期値;」の行があると、詳細欄の「スクリプトの変数」に並びます。値を入れると、その登録だけ初期値を差し替えて実行します。
- ファイルそのものは書き換えません。実行のたびにファイルを読み、差し替えた写しを実行します。空欄はファイルの初期値のままです。
- 対象は、1行に1つだけ書いた var 宣言で、初期値が文字列・数値・true／false のものです。行末のコメントは説明として表示します。
- 値を変えたショートカット：詳細欄の「ホットキー」の表に［行を追加］で行を足し、行ごとに変数の値とキーを選びます。そのキーでは、その値に差し替えて実行します。「—」の変数は「スクリプトの変数」の設定（空ならファイルの初期値）のままです。1行目「上の設定のまま」は、スクリプト自体のショートカットです。
- 行末のコメントに「[left|right|up]」のように候補を書いておくと、値をメニューから選べ、［（変数名）の候補ごとに追加］で候補の数だけ行をまとめて作れます。候補のある変数が2つ以上なら、［すべての組み合わせを追加］で値の組み合わせの数だけ行を作ります（すでにある組み合わせは足しません）。true／false の変数もメニューで選びます。
- 一覧の右に、割り当てたキーの数が出ます。
- .jsxbin と、$.fileName・$.evalFile・#include を使うスクリプトは差し替えられません（ファイルの場所に頼るため）。
- ファイルから変数が無くなったときは、残った値をオレンジで表示します。［取り除く］を押すまで、実行はエラーで止まります。

## ショートカット
- スクリプトのショートカット：InDesignが前面のときだけ登録します。ほかのアプリでは、同じキーが本来の働きをします。InDesign自身のショートカットと同じキーにすると、こちらが優先されます。
- アプリを呼び出すショートカット：設定の「起動・常駐」で割り当てると、どのアプリからでもLayoutKeysのウインドウを表示します（初期値は未設定）。
- ⌘O：スクリプトを追加
- ⌘0：メインウインドウを開く
- ⌘,：設定
- ⌘W：ウインドウを閉じる
- ⌘?：このヘルプ
同じキーのスクリプトが2つあるときは、一覧で上にあるほうだけが反応し、キーを赤で表示します。

## 設定の共有
設定の「設定の共有」タブで、書き出し・読み込みと設定の同期を使えます。
- 同期するのは、ホットキーを使うかどうかだけです。
- ［書き出す…］は、スクリプトの一覧（名前・ファイルの場所・変数の値・ホットキー・変数ごとのホットキー）も書き出します。別のMacへの移行や控えに使えます。
- ［読み込む…］は、このMacの一覧をファイルの内容に置き換えます。ファイルの場所は書き出したMacのままなので、別のMacでも同じ場所にスクリプトを置いてください。
- ログイン時の起動・常駐・メニューバーの表示・アプリを呼び出すホットキー・ウインドウの位置は、Macごとに設定します。

## 権限とプライバシー
- オートメーション（Adobe InDesign）：スクリプトの実行に使います。初めての実行で許可を求められます。
一覧は ~/Library/Application Support/LayoutKeys/Scripts.json に保存します。スクリプトのファイルは読むだけで、書き換えません。外部への送信はしません。

## 終了と常駐
ウインドウを閉じても常駐し、ショートカットは働き続けます。Dockやメニューバーのアイコンから再表示できます。［LayoutKeys］＞［LayoutKeysを終了］（⌘Q）で終了します。

## 困ったときは
- ショートカットが効かない：InDesignが前面か、「ホットキーを使う」がオンか、スクリプトのチェックがオンかを確かめてください。キーが赤いときは、重複か、ほかのアプリが使っています。
- 「InDesignを操作する許可がありません」：システム設定＞プライバシーとセキュリティ＞オートメーションで、LayoutKeysのAdobe InDesignをオンにしてください。
- 「ファイルが見つかりません」：［ファイルを選び直す…］で指定し直してください。
- 前の実行が終わらない：ダイアログボックスを出すスクリプトは、閉じるまで次の実行を待たせます。待ちは3件までで、それ以上は実行しません。

## 削除と復元
一覧で選んで－ボタン（またはdeleteキー）で削除します。ファイルそのものは消えません。すべて消すときは、アプリを終了してから Scripts.json を削除します。
""",
 "en": """## Basics
LayoutKeys runs your scripts (.jsx) with keyboard shortcuts while InDesign is in front.
- Choose File > Add Scripts… (⌘O), or drag .jsx files onto the window. You can add several at once.
- Select a script to see its file and shortcut on the right. Click the shortcut field, then press the keys to assign.
- The checkbox in the list turns each script's shortcut on or off.
- Run brings InDesign to the front, then runs the script.
- One run is undone with a single Undo in InDesign (the undo step is named after the script).
- Turn off "Use hotkeys" at the top right to pause all shortcuts (also from the menu bar icon).
- Recent Runs shows the latest results. When a script stops with an error, InDesign's message is shown. Not saved; cleared when the app quits.

## Managing scripts
- You can add .jsx, .js and .jsxbin files. The same file is not added twice.
- Change the name in its field. The file name stays.
- Drag to reorder the list (not while searching).
- A moved or renamed file shows "Missing". Choose Another File… points to it again and keeps the shortcut.
- Only the file's location is stored. Edit the script and the next run uses the new contents.
- The list and the detail pane show how many times a script ran and when it last ran. Runs from the shortcut or the Run button that finish without an error are counted.

## Script variables (SW_)
A script with a "var SW_name = value;" line lists it under Script Variables in the detail pane. Enter a value to change that initial value for this entry only.
- The file itself is not changed. Each run reads the file and runs a changed copy. Empty fields keep the file's initial values.
- Supported: a var declaration alone on its line, with a string, number or true/false value. A comment at the end of the line is shown as its description.
- Shortcuts with other values: in the Hotkey table of the detail pane, click Add Row, then pick the variable values and a key for each row. That key runs the script with those values. Variables left at "—" keep the Script Variables setting (or the file's initial value). The first row, "As set above", is the script's own shortcut.
- Write the choices in the line's comment, like "[left|right|up]", to pick values from a menu and to make one row per choice with "Add a Row for Each (name)". With two or more such variables, "Add All Combinations" makes one row per combination of values (combinations already in the table are skipped). true/false variables are picked from a menu too.
- The list shows how many keys are assigned.
- .jsxbin files and scripts that use $.fileName, $.evalFile or #include cannot be changed (they rely on the file's location).
- When a variable is gone from the file, its saved value is shown in orange, and runs stop with an error until you click Remove.

## Shortcuts
- Script shortcuts: registered only while InDesign is in front, so the same keys keep their meaning in other apps. A key that InDesign also uses runs the script instead.
- App shortcut: assign it in Settings > Launch & Background to show the LayoutKeys window from any app (none by default).
- ⌘O: Add scripts
- ⌘0: Open the main window
- ⌘,: Settings
- ⌘W: Close the window
- ⌘?: This help
When two scripts share a key, only the one higher in the list reacts, and the key is shown in red.

## Sharing settings
Use the Settings Sharing tab in Settings for export, import and sync.
- Only whether the hotkeys are used is synced.
- Export… also writes the script list (names, file locations, variable values, hotkeys and variable hotkeys), for moving to another Mac or keeping a backup.
- Import… replaces this Mac's list with the file's. File locations stay as on the exporting Mac, so put the scripts in the same places on the other Mac.
- Open at login, keep running, the menu bar icon, the app hotkey and window positions are set on each Mac.

## Permissions and privacy
- Automation (Adobe InDesign): used to run the scripts. You are asked the first time.
The list is saved in ~/Library/Application Support/LayoutKeys/Scripts.json. Script files are only read, never changed. Nothing is sent outside.

## Quitting and staying open
Closing the window keeps the app running and the shortcuts working. Reopen it from the Dock or the menu bar icon. Quit with LayoutKeys > Quit LayoutKeys (⌘Q).

## Troubleshooting
- A shortcut does nothing: check that InDesign is in front, "Use hotkeys" is on and the script's checkbox is on. A red key is a duplicate or is used by another app.
- "Not allowed to control InDesign": turn on Adobe InDesign for LayoutKeys in System Settings > Privacy & Security > Automation.
- "File not found": use Choose Another File… to point to it again.
- An earlier run does not finish: a script that shows a dialog box holds the next run until it is closed. Up to 3 runs wait; more are skipped.

## Removing and restoring
Select a script and click − (or press Delete). The file itself is not deleted. To clear everything, quit the app and delete Scripts.json.
""",
 "zh-Hans": """## 基本操作
LayoutKeys 在 InDesign 位于前台时，用键盘快捷键运行已登记的脚本（.jsx）。
- 选择“文件”>“添加脚本…”（⌘O），或将 .jsx 文件拖到窗口中。可一次添加多个。
- 在列表中选择脚本，右侧会显示文件位置和快捷键栏。点按快捷键栏后按下按键即可分配。
- 列表中的复选框可逐个开关脚本的快捷键。
- 点按“运行”会先将 InDesign 置于前台再运行。
- 每次运行在 InDesign 中只需一次“还原”即可撤销（还原名称为脚本名称）。
- 关闭右上角的“使用快捷键”可暂停所有快捷键（也可从菜单栏图标切换）。
- “最近运行”显示最近的结果。因错误停止时，会显示 InDesign 返回的信息。不会保存，退出应用时清除。

## 管理脚本
- 可添加 .jsx、.js 和 .jsxbin。同一文件不会重复登记。
- 可在名称栏中更改名称，文件名不变。
- 可拖移列表以重新排序（搜索时除外）。
- 文件被移动或重命名后会显示“文件丢失”。用“重新选择文件…”重新指定后，快捷键仍可使用。
- 只记录文件的位置。修改脚本内容后，下次运行即使用新内容。
- 列表右侧和详细栏会显示运行次数和最近运行时间。统计通过快捷键和“运行”按钮无错误完成的运行。

## 脚本变量（SW_）
脚本中有“var SW_名称 = 初始值;”的行时，会列在详细栏的“脚本变量”中。填写值后，仅此登记会替换初始值运行。
- 不会修改文件本身。每次运行都会读取文件并运行替换后的副本。空栏保持文件的初始值。
- 支持独占一行的 var 声明，初始值为字符串、数值或 true／false。行末的注释会显示为说明。
- 以其他值运行的快捷键：在详细栏的“快捷键”表中点按“添加行”，为每行选择变量值和按键。该按键会以这些值运行脚本。“—”的变量保持“脚本变量”中的设置（为空则为文件的初始值）。第一行“按上方设置”是脚本本身的快捷键。
- 在行末注释中写入候选值（如“[left|right|up]”），即可从菜单中选择值，并可用“为每个（变量名）候选添加”一次为每个候选建行。有候选的变量有两个以上时，“添加所有组合”会为每种值的组合建行（已有的组合不再添加）。true／false 变量也从菜单中选择。
- 列表右侧会显示已分配的按键数。
- .jsxbin 以及使用 $.fileName、$.evalFile、#include 的脚本无法替换（依赖文件位置）。
- 变量从文件中消失时，保留的值以橙色显示。点按“移除”前，运行会因错误而停止。

## 快捷键
- 脚本快捷键：仅在 InDesign 位于前台时注册，因此在其他应用中按键保持原有功能。若与 InDesign 自身的快捷键相同，则优先运行脚本。
- 调出应用的快捷键：在设置的“启动与常驻”中分配后，可从任何应用显示 LayoutKeys 窗口（默认未设置）。
- ⌘O：添加脚本
- ⌘0：打开主窗口
- ⌘,：设置
- ⌘W：关闭窗口
- ⌘?：本帮助
两个脚本使用同一按键时，只有列表中靠上的脚本会响应，按键以红色显示。

## 共享设置
在设置的“共享设置”标签中可以导出、导入和同步设置。
- 只同步是否使用快捷键。
- “导出…”还会写入脚本列表（名称、文件位置、变量值、快捷键和变量快捷键），可用于迁移到其他 Mac 或备份。
- “导入…”会将此 Mac 的列表替换为文件内容。文件位置保持导出时的 Mac 上的位置，请在另一台 Mac 上将脚本放在相同位置。
- 登录时启动、保持运行、菜单栏图标、调出应用的快捷键和窗口位置在每台 Mac 上分别设置。

## 权限与隐私
- 自动化（Adobe InDesign）：用于运行脚本。首次运行时会请求许可。
列表存储在 ~/Library/Application Support/LayoutKeys/Scripts.json。脚本文件只读取，不会修改。不会向外部发送任何内容。

## 退出与常驻
关闭窗口后应用仍会常驻，快捷键继续有效。可从 Dock 或菜单栏图标再次打开。选择“LayoutKeys”>“退出 LayoutKeys”（⌘Q）退出。

## 疑难解答
- 快捷键无效：请确认 InDesign 位于前台、“使用快捷键”已打开、脚本的复选框已勾选。按键显示为红色时，表示重复或被其他应用占用。
- “没有控制 InDesign 的权限”：请在“系统设置”>“隐私与安全性”>“自动化”中为 LayoutKeys 打开 Adobe InDesign。
- “找不到文件”：请用“重新选择文件…”重新指定。
- 之前的运行未结束：显示对话框的脚本会让下一次运行等待到对话框关闭。最多等待 3 次，超出的会被跳过。

## 删除与恢复
在列表中选择后点按 −（或按 Delete 键）删除。文件本身不会被删除。若要全部清除，请退出应用后删除 Scripts.json。
""",
 "ko": """## 기본 조작
LayoutKeys는 InDesign이 앞에 있을 때 등록한 스크립트(.jsx)를 키보드 단축키로 실행합니다.
- [파일] > [스크립트 추가…](⌘O)로 파일을 선택하거나 윈도우로 .jsx 파일을 드래그합니다. 여러 개를 한 번에 추가할 수 있습니다.
- 목록에서 선택하면 오른쪽에 파일 위치와 단축키 칸이 나타납니다. 단축키 칸을 클릭한 뒤 키를 누르면 지정됩니다.
- 목록의 체크상자로 스크립트별 단축키를 켜고 끕니다.
- [실행]을 클릭하면 InDesign을 앞으로 가져온 뒤 실행합니다.
- 한 번의 실행은 InDesign에서 [실행 취소] 한 번으로 되돌릴 수 있습니다(이름은 스크립트 이름입니다).
- 오른쪽 위의 '단축키 사용'을 끄면 모든 단축키를 일시 정지합니다(메뉴 막대 아이콘에서도 전환 가능).
- '최근 실행'에 최근 결과가 표시됩니다. 오류로 멈추면 InDesign이 반환한 메시지를 표시합니다. 저장하지 않으며 앱을 종료하면 지워집니다.

## 스크립트 관리
- .jsx, .js, .jsxbin을 추가할 수 있습니다. 같은 파일은 중복 등록하지 않습니다.
- 이름은 칸에서 바꿀 수 있습니다. 파일 이름은 바뀌지 않습니다.
- 목록은 드래그로 순서를 바꿀 수 있습니다(검색 중 제외).
- 파일을 이동하거나 이름을 바꾸면 '파일 없음'이 표시됩니다. [파일 다시 선택…]으로 다시 지정하면 단축키를 그대로 쓸 수 있습니다.
- 파일 위치만 기억합니다. 스크립트 내용을 고치면 다음 실행부터 새 내용으로 동작합니다.
- 목록 오른쪽과 상세 칸에 실행 횟수와 마지막 실행 일시가 표시됩니다. 단축키와 [실행] 버튼으로 오류 없이 끝난 실행을 셉니다.

## 스크립트 변수(SW_)
스크립트에 'var SW_이름 = 초기값;' 줄이 있으면 상세 칸의 '스크립트 변수'에 표시됩니다. 값을 넣으면 이 등록만 초기값을 바꿔 실행합니다.
- 파일 자체는 수정하지 않습니다. 실행할 때마다 파일을 읽어 바꾼 사본을 실행합니다. 빈 칸은 파일의 초기값을 그대로 씁니다.
- 대상은 한 줄에 하나만 쓴 var 선언이며 초기값이 문자열·숫자·true/false인 것입니다. 줄 끝의 주석은 설명으로 표시합니다.
- 값을 바꾼 단축키: 상세 칸의 '단축키' 표에서 [행 추가]로 행을 더하고 행마다 변수 값과 키를 고릅니다. 그 키로는 그 값으로 바꿔 실행합니다. '—'인 변수는 '스크립트 변수'의 설정(비어 있으면 파일의 초기값)을 그대로 씁니다. 첫 행 '위 설정 그대로'는 스크립트 자체의 단축키입니다.
- 줄 끝 주석에 '[left|right|up]'처럼 후보를 써 두면 메뉴에서 값을 고를 수 있고, [(변수 이름) 후보마다 추가]로 후보 수만큼 행을 한꺼번에 만듭니다. 후보가 있는 변수가 둘 이상이면 [모든 조합 추가]로 값의 조합 수만큼 행을 만듭니다(이미 있는 조합은 더하지 않습니다). true/false 변수도 메뉴에서 고릅니다.
- 목록 오른쪽에 지정한 키의 수가 표시됩니다.
- .jsxbin과 $.fileName·$.evalFile·#include를 쓰는 스크립트는 바꿀 수 없습니다(파일 위치에 의존하기 때문).
- 파일에서 변수가 없어지면 남은 값을 주황색으로 표시합니다. [제거]를 누를 때까지 실행은 오류로 멈춥니다.

## 단축키
- 스크립트 단축키: InDesign이 앞에 있을 때만 등록하므로 다른 앱에서는 같은 키가 원래 기능을 합니다. InDesign 자체 단축키와 같은 키라면 스크립트가 우선합니다.
- 앱을 불러오는 단축키: 설정의 '실행 및 상주'에서 지정하면 어느 앱에서든 LayoutKeys 윈도우를 표시합니다(기본값은 없음).
- ⌘O: 스크립트 추가
- ⌘0: 메인 윈도우 열기
- ⌘,: 설정
- ⌘W: 윈도우 닫기
- ⌘?: 이 도움말
같은 키의 스크립트가 두 개 있으면 목록에서 위에 있는 것만 반응하고 키를 빨간색으로 표시합니다.

## 설정 공유
설정의 '설정 공유' 탭에서 내보내기, 가져오기와 동기화를 사용할 수 있습니다.
- 동기화하는 것은 단축키 사용 여부뿐입니다.
- [내보내기…]는 스크립트 목록(이름·파일 위치·변수 값·단축키·변수별 단축키)도 내보냅니다. 다른 Mac으로 옮기거나 백업할 때 씁니다.
- [가져오기…]는 이 Mac의 목록을 파일 내용으로 바꿉니다. 파일 위치는 내보낸 Mac 그대로이므로 다른 Mac에서도 같은 위치에 스크립트를 두세요.
- 로그인 시 실행, 계속 실행, 메뉴 막대 아이콘, 앱 호출 단축키, 윈도우 위치는 Mac마다 설정합니다.

## 권한과 개인정보
- 자동화(Adobe InDesign): 스크립트 실행에 사용합니다. 처음 실행할 때 허용을 요청합니다.
목록은 ~/Library/Application Support/LayoutKeys/Scripts.json에 저장합니다. 스크립트 파일은 읽기만 하고 수정하지 않습니다. 외부로 아무것도 보내지 않습니다.

## 종료와 상주
윈도우를 닫아도 상주하며 단축키는 계속 작동합니다. Dock이나 메뉴 막대 아이콘에서 다시 열 수 있습니다. [LayoutKeys] > [LayoutKeys 종료](⌘Q)로 종료합니다.

## 문제 해결
- 단축키가 작동하지 않음: InDesign이 앞에 있는지, '단축키 사용'이 켜져 있는지, 스크립트의 체크상자가 켜져 있는지 확인하세요. 키가 빨간색이면 중복이거나 다른 앱이 사용 중입니다.
- 'InDesign을 제어할 권한이 없습니다': 시스템 설정 > 개인정보 보호 및 보안 > 자동화에서 LayoutKeys의 Adobe InDesign을 켜세요.
- '파일을 찾을 수 없습니다': [파일 다시 선택…]으로 다시 지정하세요.
- 이전 실행이 끝나지 않음: 대화상자를 띄우는 스크립트는 닫을 때까지 다음 실행을 기다리게 합니다. 대기는 3건까지이며 그 이상은 실행하지 않습니다.

## 삭제와 복원
목록에서 선택하고 − 버튼(또는 Delete 키)으로 삭제합니다. 파일 자체는 삭제되지 않습니다. 모두 지우려면 앱을 종료한 뒤 Scripts.json을 삭제하세요.
""",
}
