# VectorKeys help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
VectorKeysは、登録したスクリプト（.jsx）を、Illustratorが前面のときにキーボードショートカットで実行します。
- ［ファイル］＞［スクリプトを追加…］（⌘O）でファイルを選ぶか、ウインドウへ .jsx ファイルをドラッグします。複数まとめて追加できます。
- 一覧で選ぶと、右側にファイルの場所とショートカットの欄が出ます。［変更…］を押してからキーを押すと割り当てます。
- 一覧のチェックボックスで、スクリプトごとにショートカットのオン・オフを切り替えます。
- ［実行］を押すと、Illustratorを前面にしてから実行します。
- 右上の「ホットキーを使う」をオフにすると、すべてのショートカットを一時停止します（メニューバーのアイコンからも切り替えられます）。
- 「最近の実行」に直近の結果が出ます。エラーで止まったときは、Illustratorが返したメッセージを表示します。履歴は保存せず、終了すると消えます。

## スクリプトの管理
- 追加できるのは .jsx・.js・.jsxbin です。同じファイルは二重に登録しません。
- 名前は欄で変えられます。ファイル名は変わりません。
- 一覧はドラッグで並べ替えられます（検索中を除く）。
- ファイルを移動・名前変更したときは「ファイルなし」と出ます。［ファイルを選び直す…］で指定し直すと、ショートカットはそのまま使えます。
- スクリプトはファイルの場所を覚えているだけです。中身を書き換えたら、次の実行から新しい内容で動きます。
- 一覧の右と詳細欄に、実行した回数と最後に実行した日時が出ます。ショートカットと［実行］ボタンで、エラーなく終わったものを数えます。

## ショートカット
- スクリプトのショートカット：Illustratorが前面のときだけ登録します。ほかのアプリでは、同じキーが本来の働きをします。Illustrator自身のショートカットと同じキーにすると、こちらが優先されます。
- アプリを呼び出すショートカット：設定の「起動・常駐」で割り当てると、どのアプリからでもVectorKeysのウインドウを表示します（初期値は未設定）。
- ⌘O：スクリプトを追加
- ⌘0：メインウインドウを開く
- ⌘,：設定
- ⌘W：ウインドウを閉じる
- ⌘?：このヘルプ
同じキーのスクリプトが2つあるときは、一覧で上にあるほうだけが反応し、キーを赤で表示します。

## 権限とプライバシー
- オートメーション（Adobe Illustrator）：スクリプトの実行に使います。初めての実行で許可を求められます。
一覧は ~/Library/Application Support/VectorKeys/Scripts.json に保存します。スクリプトのファイルは読むだけで、書き換えません。外部への送信はしません。

## 終了と常駐
ウインドウを閉じても常駐し、ショートカットは働き続けます。Dockやメニューバーのアイコンから再表示できます。［VectorKeys］＞［VectorKeysを終了］（⌘Q）で終了します。

## 困ったときは
- ショートカットが効かない：Illustratorが前面か、「ホットキーを使う」がオンか、スクリプトのチェックがオンかを確かめてください。キーが赤いときは、重複か、ほかのアプリが使っています。
- 「Illustratorを操作する許可がありません」：システム設定＞プライバシーとセキュリティ＞オートメーションで、VectorKeysのAdobe Illustratorをオンにしてください。
- 「ファイルが見つかりません」：［ファイルを選び直す…］で指定し直してください。
- 前の実行が終わらない：ダイアログボックスを出すスクリプトは、閉じるまで次の実行を待たせます。待ちは3件までで、それ以上は実行しません。

## 削除と復元
一覧で選んで－ボタン（またはdeleteキー）で削除します。ファイルそのものは消えません。すべて消すときは、アプリを終了してから Scripts.json を削除します。
""",
 "en": """## Basics
VectorKeys runs your scripts (.jsx) with keyboard shortcuts while Illustrator is in front.
- Choose File > Add Scripts… (⌘O), or drag .jsx files onto the window. You can add several at once.
- Select a script to see its file and shortcut on the right. Click Change…, then press the keys to assign.
- The checkbox in the list turns each script's shortcut on or off.
- Run brings Illustrator to the front, then runs the script.
- Turn off "Use hotkeys" at the top right to pause all shortcuts (also from the menu bar icon).
- Recent Runs shows the latest results. When a script stops with an error, Illustrator's message is shown. Not saved; cleared when the app quits.

## Managing scripts
- You can add .jsx, .js and .jsxbin files. The same file is not added twice.
- Change the name in its field. The file name stays.
- Drag to reorder the list (not while searching).
- A moved or renamed file shows "Missing". Choose Another File… points to it again and keeps the shortcut.
- Only the file's location is stored. Edit the script and the next run uses the new contents.
- The list and the detail pane show how many times a script ran and when it last ran. Runs from the shortcut or the Run button that finish without an error are counted.

## Shortcuts
- Script shortcuts: registered only while Illustrator is in front, so the same keys keep their meaning in other apps. A key that Illustrator also uses runs the script instead.
- App shortcut: assign it in Settings > Launch & Background to show the VectorKeys window from any app (none by default).
- ⌘O: Add scripts
- ⌘0: Open the main window
- ⌘,: Settings
- ⌘W: Close the window
- ⌘?: This help
When two scripts share a key, only the one higher in the list reacts, and the key is shown in red.

## Permissions and privacy
- Automation (Adobe Illustrator): used to run the scripts. You are asked the first time.
The list is saved in ~/Library/Application Support/VectorKeys/Scripts.json. Script files are only read, never changed. Nothing is sent outside.

## Quitting and staying open
Closing the window keeps the app running and the shortcuts working. Reopen it from the Dock or the menu bar icon. Quit with VectorKeys > Quit VectorKeys (⌘Q).

## Troubleshooting
- A shortcut does nothing: check that Illustrator is in front, "Use hotkeys" is on and the script's checkbox is on. A red key is a duplicate or is used by another app.
- "Not allowed to control Illustrator": turn on Adobe Illustrator for VectorKeys in System Settings > Privacy & Security > Automation.
- "File not found": use Choose Another File… to point to it again.
- An earlier run does not finish: a script that shows a dialog box holds the next run until it is closed. Up to 3 runs wait; more are skipped.

## Removing and restoring
Select a script and click − (or press Delete). The file itself is not deleted. To clear everything, quit the app and delete Scripts.json.
""",
 "zh-Hans": """## 基本操作
VectorKeys 在 Illustrator 位于前台时，用键盘快捷键运行已登记的脚本（.jsx）。
- 选择“文件”>“添加脚本…”（⌘O），或将 .jsx 文件拖到窗口中。可一次添加多个。
- 在列表中选择脚本，右侧会显示文件位置和快捷键栏。点按“更改…”后按下按键即可分配。
- 列表中的复选框可逐个开关脚本的快捷键。
- 点按“运行”会先将 Illustrator 置于前台再运行。
- 关闭右上角的“使用快捷键”可暂停所有快捷键（也可从菜单栏图标切换）。
- “最近运行”显示最近的结果。因错误停止时，会显示 Illustrator 返回的信息。不会保存，退出应用时清除。

## 管理脚本
- 可添加 .jsx、.js 和 .jsxbin。同一文件不会重复登记。
- 可在名称栏中更改名称，文件名不变。
- 可拖移列表以重新排序（搜索时除外）。
- 文件被移动或重命名后会显示“文件丢失”。用“重新选择文件…”重新指定后，快捷键仍可使用。
- 只记录文件的位置。修改脚本内容后，下次运行即使用新内容。
- 列表右侧和详细栏会显示运行次数和最近运行时间。统计通过快捷键和“运行”按钮无错误完成的运行。

## 快捷键
- 脚本快捷键：仅在 Illustrator 位于前台时注册，因此在其他应用中按键保持原有功能。若与 Illustrator 自身的快捷键相同，则优先运行脚本。
- 调出应用的快捷键：在设置的“启动与常驻”中分配后，可从任何应用显示 VectorKeys 窗口（默认未设置）。
- ⌘O：添加脚本
- ⌘0：打开主窗口
- ⌘,：设置
- ⌘W：关闭窗口
- ⌘?：本帮助
两个脚本使用同一按键时，只有列表中靠上的脚本会响应，按键以红色显示。

## 权限与隐私
- 自动化（Adobe Illustrator）：用于运行脚本。首次运行时会请求许可。
列表存储在 ~/Library/Application Support/VectorKeys/Scripts.json。脚本文件只读取，不会修改。不会向外部发送任何内容。

## 退出与常驻
关闭窗口后应用仍会常驻，快捷键继续有效。可从 Dock 或菜单栏图标再次打开。选择“VectorKeys”>“退出 VectorKeys”（⌘Q）退出。

## 疑难解答
- 快捷键无效：请确认 Illustrator 位于前台、“使用快捷键”已打开、脚本的复选框已勾选。按键显示为红色时，表示重复或被其他应用占用。
- “没有控制 Illustrator 的权限”：请在“系统设置”>“隐私与安全性”>“自动化”中为 VectorKeys 打开 Adobe Illustrator。
- “找不到文件”：请用“重新选择文件…”重新指定。
- 之前的运行未结束：显示对话框的脚本会让下一次运行等待到对话框关闭。最多等待 3 次，超出的会被跳过。

## 删除与恢复
在列表中选择后点按 −（或按 Delete 键）删除。文件本身不会被删除。若要全部清除，请退出应用后删除 Scripts.json。
""",
 "ko": """## 기본 조작
VectorKeys는 Illustrator가 앞에 있을 때 등록한 스크립트(.jsx)를 키보드 단축키로 실행합니다.
- [파일] > [스크립트 추가…](⌘O)로 파일을 선택하거나 윈도우로 .jsx 파일을 드래그합니다. 여러 개를 한 번에 추가할 수 있습니다.
- 목록에서 선택하면 오른쪽에 파일 위치와 단축키 칸이 나타납니다. [변경…]을 클릭한 뒤 키를 누르면 지정됩니다.
- 목록의 체크상자로 스크립트별 단축키를 켜고 끕니다.
- [실행]을 클릭하면 Illustrator를 앞으로 가져온 뒤 실행합니다.
- 오른쪽 위의 '단축키 사용'을 끄면 모든 단축키를 일시 정지합니다(메뉴 막대 아이콘에서도 전환 가능).
- '최근 실행'에 최근 결과가 표시됩니다. 오류로 멈추면 Illustrator가 반환한 메시지를 표시합니다. 저장하지 않으며 앱을 종료하면 지워집니다.

## 스크립트 관리
- .jsx, .js, .jsxbin을 추가할 수 있습니다. 같은 파일은 중복 등록하지 않습니다.
- 이름은 칸에서 바꿀 수 있습니다. 파일 이름은 바뀌지 않습니다.
- 목록은 드래그로 순서를 바꿀 수 있습니다(검색 중 제외).
- 파일을 이동하거나 이름을 바꾸면 '파일 없음'이 표시됩니다. [파일 다시 선택…]으로 다시 지정하면 단축키를 그대로 쓸 수 있습니다.
- 파일 위치만 기억합니다. 스크립트 내용을 고치면 다음 실행부터 새 내용으로 동작합니다.
- 목록 오른쪽과 상세 칸에 실행 횟수와 마지막 실행 일시가 표시됩니다. 단축키와 [실행] 버튼으로 오류 없이 끝난 실행을 셉니다.

## 단축키
- 스크립트 단축키: Illustrator가 앞에 있을 때만 등록하므로 다른 앱에서는 같은 키가 원래 기능을 합니다. Illustrator 자체 단축키와 같은 키라면 스크립트가 우선합니다.
- 앱을 불러오는 단축키: 설정의 '실행 및 상주'에서 지정하면 어느 앱에서든 VectorKeys 윈도우를 표시합니다(기본값은 없음).
- ⌘O: 스크립트 추가
- ⌘0: 메인 윈도우 열기
- ⌘,: 설정
- ⌘W: 윈도우 닫기
- ⌘?: 이 도움말
같은 키의 스크립트가 두 개 있으면 목록에서 위에 있는 것만 반응하고 키를 빨간색으로 표시합니다.

## 권한과 개인정보
- 자동화(Adobe Illustrator): 스크립트 실행에 사용합니다. 처음 실행할 때 허용을 요청합니다.
목록은 ~/Library/Application Support/VectorKeys/Scripts.json에 저장합니다. 스크립트 파일은 읽기만 하고 수정하지 않습니다. 외부로 아무것도 보내지 않습니다.

## 종료와 상주
윈도우를 닫아도 상주하며 단축키는 계속 작동합니다. Dock이나 메뉴 막대 아이콘에서 다시 열 수 있습니다. [VectorKeys] > [VectorKeys 종료](⌘Q)로 종료합니다.

## 문제 해결
- 단축키가 작동하지 않음: Illustrator가 앞에 있는지, '단축키 사용'이 켜져 있는지, 스크립트의 체크상자가 켜져 있는지 확인하세요. 키가 빨간색이면 중복이거나 다른 앱이 사용 중입니다.
- 'Illustrator를 제어할 권한이 없습니다': 시스템 설정 > 개인정보 보호 및 보안 > 자동화에서 VectorKeys의 Adobe Illustrator를 켜세요.
- '파일을 찾을 수 없습니다': [파일 다시 선택…]으로 다시 지정하세요.
- 이전 실행이 끝나지 않음: 대화상자를 띄우는 스크립트는 닫을 때까지 다음 실행을 기다리게 합니다. 대기는 3건까지이며 그 이상은 실행하지 않습니다.

## 삭제와 복원
목록에서 선택하고 − 버튼(또는 Delete 키)으로 삭제합니다. 파일 자체는 삭제되지 않습니다. 모두 지우려면 앱을 종료한 뒤 Scripts.json을 삭제하세요.
""",
}
