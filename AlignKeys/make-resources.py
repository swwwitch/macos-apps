# -*- coding: utf-8 -*-
from pathlib import Path
import json
root = Path(__file__).parent
APP = 'AlignKeys'
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''heading|InDesignで近くの線に揃える|Align to the Nearest Line in InDesign|在 InDesign 中对齐到最近的线|InDesign에서 가장 가까운 선에 맞추기
subtitle|「近くの線に揃える」パレットのボタンを、InDesignが前面のときにキーボードショートカットで実行します。|Runs the buttons of the Align to Nearest Edge palette with keyboard shortcuts while InDesign is in front.|在 InDesign 位于前台时，用键盘快捷键运行“对齐到最近边缘”面板的按钮。|InDesign이 앞에 있을 때 '가장 가까운 가장자리에 맞추기' 팔레트의 버튼을 키보드 단축키로 실행합니다.
useHotkeysHint|オフにすると、ボタンのショートカットをすべて一時停止します。|When off, all button shortcuts are paused.|关闭后暂停所有按钮快捷键。|끄면 모든 버튼 단축키를 일시 정지합니다.
useHotkeysDetail|ボタンのショートカットは、InDesignが前面にあるときだけ登録します。ほかのアプリでは同じキーが本来の働きをします。オフにすると一時停止します（メニューバーのアイコンからも切り替えられます）。|Button shortcuts are registered only while InDesign is in front, so the same keys keep their meaning in other apps. Turn off to pause them (also from the menu bar icon).|按钮快捷键仅在 InDesign 位于前台时注册，因此在其他应用中按键保持原有功能。关闭可暂停（也可从菜单栏图标切换）。|버튼 단축키는 InDesign이 앞에 있을 때만 등록하므로 다른 앱에서는 같은 키가 원래 기능을 합니다. 끄면 일시 정지합니다(메뉴 막대 아이콘에서도 전환 가능).
state.hint|ボタンのショートカットは、InDesignが前面のときだけ働きます。|Button shortcuts work only while InDesign is in front.|按钮快捷键仅在 InDesign 位于前台时有效。|버튼 단축키는 InDesign이 앞에 있을 때만 작동합니다.
runHint|InDesignを前面にしてから実行します。|Brings InDesign to the front, then runs.|先将 InDesign 置于前台再运行。|InDesign을 앞으로 가져온 뒤 실행합니다.
hotkey.duplicate|ほかと同じキーのため、表で上にあるほうだけが反応します：%@|Same key as another; only the one higher in the table reacts: %@|与其他按键相同，只有表中靠上的会响应：%@|다른 것과 같은 키여서 표에서 위에 있는 것만 반응합니다: %@
hotkeysSection|ボタンのショートカット|Button Shortcuts|按钮快捷键|버튼 단축키
result.failed|エラーで止まりました：%@|Stopped with an error: %@|因错误而停止：%@|오류로 중지됨: %@
aboutDetail|「近くの線に揃える」パレットのボタンを、InDesignが前面のときにキーボードショートカットで実行します。サポート：同梱のREADME.md|Runs the buttons of the Align to Nearest Edge palette with keyboard shortcuts while InDesign is in front. Support: bundled README.md|在 InDesign 位于前台时用键盘快捷键运行“对齐到最近边缘”面板的按钮。支持：内置 README.md|InDesign이 앞에 있을 때 '가장 가까운 가장자리에 맞추기' 팔레트의 버튼을 키보드 단축키로 실행합니다. 지원: 포함된 README.md
openMainWindow|メインウインドウを開く|Open Main Window|打开主窗口|메인 윈도우 열기
settings|設定…|Settings…|设置…|설정…
settingsWindow|設定|Settings|设置|설정
help|{APP}ヘルプ|{APP} Help|{APP} 帮助|{APP} 도움말
helpMenu|ヘルプ|Help|帮助|도움말
quit|{APP}を終了|Quit {APP}|退出 {APP}|{APP} 종료
hide|{APP}を隠す|Hide {APP}|隐藏 {APP}|{APP} 가리기
services|サービス|Services|服务|서비스
hideOthers|ほかを隠す|Hide Others|隐藏其他|기타 가리기
showAll|すべてを表示|Show All|全部显示|모두 보기
about|{APP}について|About {APP}|关于 {APP}|{APP}에 관하여
fileMenu|ファイル|File|文件|파일
editMenu|編集|Edit|编辑|편집
windowMenu|ウインドウ|Window|窗口|윈도우
minimize|しまう|Minimize|最小化|최소화
zoom|拡大／縮小|Zoom|缩放|확대/축소
bringAllToFront|すべてを手前に移動|Bring All to Front|前置全部窗口|모두 앞으로 가져오기
close|ウインドウを閉じる|Close Window|关闭窗口|윈도우 닫기
undo|取り消す|Undo|撤销|실행 취소
redo|やり直す|Redo|重做|실행 복귀
cut|カット|Cut|剪切|오려두기
copy|コピー|Copy|拷贝|복사하기
paste|ペースト|Paste|粘贴|붙여넣기
selectAll|すべてを選択|Select All|全选|모두 선택
cancel|キャンセル|Cancel|取消|취소
resident|ウインドウを閉じても常駐|Keep running after closing the window|关闭窗口后继续运行|윈도우를 닫아도 계속 실행
residentDetail|閉じた後もDockやメニューバーから再表示できます。オフにすると閉じたときに終了し、ホットキーも使えなくなります。|Reopen from the Dock or menu bar. When off, closing the window quits and the hotkeys stop.|可从 Dock 或菜单栏再次打开。关闭此项时，关闭窗口即退出，快捷键也会停止。|Dock 또는 메뉴 막대에서 다시 열 수 있습니다. 끄면 창을 닫을 때 종료되고 단축키도 멈춥니다.
launchShortcut|アプリ起動のホットキー|App launch keyboard shortcut|启动应用快捷键|앱 실행 키보드 단축키
openShortcuts|ショートカットを開く|Open Shortcuts|打开快捷指令|단축어 열기
shortcutDetail|ショートカットAppで「アプリを開く」に{APP}を指定し、キーを割り当ててください。未起動時も使えます。|In Shortcuts, create an Open App action for {APP} and assign a key. It works even when the app is not running.|在快捷指令中为 {APP} 创建“打开 App”并分配按键，应用未运行时也可使用。|단축어 앱에서 {APP}을 여는 동작을 만들고 키를 지정하세요. 앱이 실행 중이 아니어도 작동합니다.
appHotkeyHint|{APP}の起動中に押すと、どのアプリからでもメインウインドウを表示します。未起動のときは上の「ショートカットを開く」で割り当てたキーを使ってください。|While {APP} is running, press it in any app to show the main window. When it is not running, use the key assigned with Open Shortcuts above.|{APP} 运行时，在任何应用中按下即可显示主窗口。未运行时请使用上方“打开快捷指令”中分配的按键。|{APP}이 실행 중일 때 어느 앱에서든 누르면 메인 윈도우를 표시합니다. 실행 중이 아닐 때는 위의 '단축어 열기'에서 지정한 키를 사용하세요.
pauseHotkeys|ホットキーを一時停止|Pause Hotkeys|暂停快捷键|단축키 일시 정지
resumeHotkeys|ホットキーを再開|Resume Hotkeys|恢复快捷键|단축키 재개
useHotkeys|ホットキーを使う|Use hotkeys|使用快捷键|단축키 사용
recent|最近の実行|Recent Runs|最近运行|최근 실행
recentEmpty|まだありません。履歴は保存せず、終了すると消えます。|None yet. Not saved; cleared when the app quits.|暂无。不会保存，退出应用时清除。|아직 없습니다. 저장하지 않으며 앱을 종료하면 지워집니다.
a11y.error|失敗|Failed|失败|실패
a11y.success|成功|Succeeded|成功|성공
hotkeysTab|ホットキー|Hotkeys|快捷键|단축키
result.success|完了|Done|完成|완료
result.busy|前の実行が続いているため、実行しませんでした。|Skipped: earlier runs are still going.|已跳过：之前的运行仍在进行。|건너뜀: 이전 실행이 아직 진행 중입니다.
result.noInDesign|InDesignが起動していません。|InDesign is not running.|InDesign 未运行。|InDesign이 실행 중이 아닙니다.
result.automation|InDesignを操作する許可がありません。システム設定＞プライバシーとセキュリティ＞オートメーションで、{APP}のAdobe InDesignをオンにしてください。|Not allowed to control InDesign. Turn on Adobe InDesign for {APP} in System Settings > Privacy & Security > Automation.|没有控制 InDesign 的权限。请在“系统设置”>“隐私与安全性”>“自动化”中为 {APP} 打开 Adobe InDesign。|InDesign을 제어할 권한이 없습니다. 시스템 설정 > 개인정보 보호 및 보안 > 자동화에서 {APP}의 Adobe InDesign을 켜세요.
state.front|InDesignが前面：ホットキー有効|InDesign in front: hotkeys on|InDesign 在前台：快捷键有效|InDesign이 앞에 있음: 단축키 사용
override.syntax|変数を安全に解析できません。%@|Cannot safely parse variable declarations. %@|无法安全解析变量声明。%@|변수 선언을 안전하게 분석할 수 없습니다. %@
override.identifier|変数名が不正です：%@|Invalid variable name: %@|变量名无效：%@|잘못된 변수 이름: %@
override.duplicate|同じ変数名が複数の欄にあります：%@|Variable specified more than once: %@|多个输入栏使用同一变量：%@|여러 입력란에 같은 변수 이름이 있습니다: %@
override.missing|変数の宣言が見つかりません：%@|Variable declaration not found: %@|找不到变量声明：%@|변수 선언을 찾을 수 없습니다: %@
override.ambiguous|同名の宣言が複数あるため差し替えできません：%@|Multiple declarations prevent replacement: %@|有多个同名声明，无法替换：%@|같은 이름의 선언이 여러 개여서 바꿀 수 없습니다: %@
override.unsupported|単独行の var 変数 = 初期値; の形式に対応しています：%@|Use a standalone var name = literal; declaration: %@|仅支持独立行 var 变量 = 初始值;：%@|별도 줄의 var 이름 = 리터럴; 선언을 사용하세요: %@
override.number|数値の初期値と数値の入力が必要です：%@|A numeric default and numeric input are required: %@|需要数值初始值和数值输入：%@|숫자 초기값과 숫자 입력이 필요합니다: %@
override.boolean|値に true または false を入力してください：%@|Enter true or false: %@|请输入 true 或 false：%@|true 또는 false를 입력하세요: %@
override.fileText|変数の差し替えはUTF-8のテキストファイルに対応しています：%@|Variable replacement requires a UTF-8 text file: %@|变量替换需要UTF-8文本文件：%@|변수 교체에는 UTF-8 텍스트 파일이 필요합니다: %@
override.fileContext|このファイルは元の場所に依存するため変数を差し替えできません：%@|This file depends on its original location and cannot use variable replacement: %@|文件依赖原位置，无法替换变量：%@|원래 파일 위치에 의존하여 변수를 바꿀 수 없습니다: %@
explain|説明|Details|说明|설명
sharing.note|ボタンのホットキー・矢印キーとInDesign優先の設定・ホットキーを使うかどうかを同期します。|Syncs the button hotkeys, the arrow key and InDesign-first settings, and whether the hotkeys are used.|同步按钮快捷键、方向键和 InDesign 优先设置以及是否使用快捷键。|버튼 단축키, 화살표 키와 InDesign 우선 설정, 단축키 사용 여부를 동기화합니다.
sharing.perMac|ログイン時の起動・常駐・メニューバーの表示・アプリを呼び出すホットキー・ウインドウの位置はMacごとに設定します。|Open at login, keep running, the menu bar icon, the app hotkey and window positions are set on each Mac.|登录时启动、保持运行、菜单栏图标、调出应用的快捷键和窗口位置在每台 Mac 上分别设置。|로그인 시 실행, 계속 실행, 메뉴 막대 아이콘, 앱 호출 단축키, 윈도우 위치는 Mac마다 설정합니다.
state.back|InDesignが背面：ホットキー待機中|InDesign not in front: hotkeys waiting|InDesign 不在前台：快捷键待机|InDesign이 뒤에 있음: 단축키 대기
openPalette|パレットを開く|Open the Palette|打开面板|팔레트 열기
openPaletteHint|InDesignを前面にして、同梱のスクリプトのパレットを開きます。|Brings InDesign to the front and opens the palette of the bundled script.|将 InDesign 置于前台并打开内置脚本的面板。|InDesign을 앞으로 가져와 포함된 스크립트의 팔레트를 엽니다.
palette|パレット|Palette|面板|팔레트
hotkeys|ボタンとホットキー|Buttons and Hotkeys|按钮和快捷键|버튼과 단축키
column.action|ボタン|Button|按钮|버튼
column.hotkey|ホットキー|Hotkey|快捷键|단축키
column.fromCenter|中央から|From the Center|从中央|가운데에서
column.fromCenterHint|いったん中央に移してから揃えます（パレットのOption＋クリックと同じ）。|Centers the object first, then aligns (like Option-click on the palette).|先移到中央再对齐（与在面板上按住 Option 点按相同）。|먼저 가운데로 옮긴 뒤 맞춥니다(팔레트에서 Option+클릭과 같음).
column.noFromCenter|中央のボタンには「中央から」がありません。|The center buttons have no "From the center".|居中按钮没有“从中央”。|가운데 버튼에는 '가운데에서'가 없습니다.
hotkeysHint|ボタンの名前をクリックすると、InDesignを前面にして実行します（個別に移動・ページ基準）。ショートカットはInDesignが前面のときだけ働き、ほかのアプリでは同じキーが本来の働きをします。InDesign自身のショートカットと重なるキーは、下のチェックボックスがオンならInDesignを優先し、オフならこちらが優先されます。辺を揃えるボタンは、続けて押すと次の線へ進みます。中央揃えの基準が効くのは、中央のボタンと「中央から」です。1回の実行は［取り消し］1回で戻せます。|Click a button name to bring InDesign to the front and run it (each object on its own, centered on the page). Shortcuts work only while InDesign is in front; in other apps the same keys keep their meaning. Keys that InDesign's own shortcuts use are left to InDesign while the checkbox below is on; when it is off, this app wins. Pressing an edge button again moves on to the next line. The center basis applies to the center buttons and "From the center". Each run is undone with a single Undo.|点按按钮名称会将 InDesign 置于前台并运行（逐个移动、以页面为基准）。快捷键仅在 InDesign 位于前台时有效，在其他应用中按键保持原有功能。与 InDesign 自身快捷键重叠的按键，下方复选框打开时由 InDesign 优先，关闭时由本应用优先。连续按边缘按钮会移到下一条线。居中基准适用于居中按钮和“从中央”。每次运行只需一次“还原”即可撤销。|버튼 이름을 클릭하면 InDesign을 앞으로 가져와 실행합니다(객체마다 이동, 페이지 기준). 단축키는 InDesign이 앞에 있을 때만 작동하며 다른 앱에서는 같은 키가 원래 기능을 합니다. InDesign 자체 단축키와 겹치는 키는 아래 체크상자가 켜져 있으면 InDesign이, 꺼져 있으면 이 앱이 우선합니다. 가장자리 버튼을 이어서 누르면 다음 선으로 넘어갑니다. 가운데 맞춤 기준은 가운데 버튼과 '가운데에서'에 적용됩니다. 한 번의 실행은 [실행 취소] 한 번으로 되돌릴 수 있습니다.
action.upLeft|左上|Top Left|左上|왼쪽 위
action.up|上|Top|上|위
action.upRight|右上|Top Right|右上|오른쪽 위
action.left|左|Left|左|왼쪽
action.center|中央|Center|中央|가운데
action.right|右|Right|右|오른쪽
action.downLeft|左下|Bottom Left|左下|왼쪽 아래
action.down|下|Bottom|下|아래
action.downRight|右下|Bottom Right|右下|오른쪽 아래
action.centerH|水平方向中央|Horizontal Center|水平居中|가로 가운데
action.centerV|垂直方向中央|Vertical Center|垂直居中|세로 가운데
undoName|近くの線に揃える（%@）|Align to Nearest Edge (%@)|对齐到最近边缘（%@）|가장 가까운 가장자리에 맞추기(%@)
a11y.run|%@を実行|Run %@|运行%@|%@ 실행
result.noScript|同梱のスクリプトが見つかりません。アプリを入れ直してください。|The bundled script is missing. Reinstall the app.|找不到内置脚本。请重新安装应用。|포함된 스크립트를 찾을 수 없습니다. 앱을 다시 설치하세요.
variant.fromCenter|中央から|from the center|从中央|가운데에서
variant.asUnit|まとめて|as a unit|整体|하나로
variant.margin|マージン|margins|边距|여백
variant.title|%1$@（%2$@）|%1$@ (%2$@)|%1$@（%2$@）|%1$@(%2$@)
variant.separator|・|, |、|·
modifiers|割り当てたキーに ⌥ を加えると［選択をまとめて移動］、⇧ を加えると中央揃えの基準がマージン（マージンガイドの内側）になります。⌥⇧ で両方です。初期値は ⌃⌘ に U I O／J K L／M , . で、ボタンの並びと同じ配置です。|Add ⌥ to a key to move the selection as a unit, and ⇧ to center on the margins (inside the margin guides) instead of the page; ⌥⇧ does both. The defaults are ⌃⌘ with U I O / J K L / M , . laid out like the buttons.|在分配的按键上加 ⌥ 即“将所选内容作为整体移动”，加 ⇧ 则居中基准变为边距（边距参考线内侧）。⌥⇧ 同时生效。默认是 ⌃⌘ 加 U I O／J K L／M , .，与按钮排列相同。|지정한 키에 ⌥를 더하면 '선택 항목을 하나로 이동', ⇧를 더하면 가운데 맞춤 기준이 여백(여백 안내선 안쪽)이 됩니다. ⌥⇧는 둘 다입니다. 기본값은 ⌃⌘에 U I O / J K L / M , . 로 버튼 배치와 같습니다.
hotkey.formsFailed|登録できなかったキーがあります（ほかのアプリが使っている可能性があります）：%@|Some keys could not be registered (another app may be using them): %@|部分按键无法注册（可能被其他应用占用）：%@|등록하지 못한 키가 있습니다(다른 앱이 사용 중일 수 있습니다): %@
arrowKeys|上下左右は ⌃⌘＋矢印キーでも実行する（⌥・⇧ を加えた形も同じ）|Also run top, bottom, left and right with ⌃⌘ and the arrow keys (with the same ⌥ / ⇧ forms)|上、下、左、右也可用 ⌃⌘＋方向键运行（加 ⌥・⇧ 的形式相同）|위·아래·왼쪽·오른쪽은 ⌃⌘+화살표 키로도 실행(⌥·⇧를 더한 형태도 같음)
arrowKeysHint|⌃⌘↑ で上、⌃⌘← で左、⌃⌘→ で右、⌃⌘↓ で下を実行します。表のキーと重なるときは表のキーが優先されます。|⌃⌘↑ runs Top, ⌃⌘← Left, ⌃⌘→ Right and ⌃⌘↓ Bottom. Keys in the table win when they overlap.|⌃⌘↑ 运行上，⌃⌘← 运行左，⌃⌘→ 运行右，⌃⌘↓ 运行下。与表中按键重叠时以表中按键优先。|⌃⌘↑는 위, ⌃⌘←는 왼쪽, ⌃⌘→는 오른쪽, ⌃⌘↓는 아래를 실행합니다. 표의 키와 겹치면 표의 키가 우선합니다.
arrowKeys.problem|使えなかった矢印キーがあります（表のキーと重なるか、ほかのアプリが使っています）：%@|Some arrow keys are not used (they overlap a key in the table or another app uses them): %@|部分方向键无法使用（与表中按键重叠或被其他应用占用）：%@|쓰지 못한 화살표 키가 있습니다(표의 키와 겹치거나 다른 앱이 사용 중): %@
preferInDesign|InDesignのキーボードショートカットと重なるキーは、InDesignを優先する|Leave keys that InDesign's own shortcuts use to InDesign|与 InDesign 键盘快捷键重叠的按键优先由 InDesign 使用|InDesign 키보드 단축키와 겹치는 키는 InDesign을 우선
preferInDesignHint|InDesignで使っているショートカットのセットを読み、同じキー（⌥・⇧ を加えた形も）はこのアプリでは登録しません。InDesignでショートカットを変えたら、InDesignに戻ったときに読み直します。|Reads the shortcut set InDesign uses and does not register the same keys here (including the ⌥ / ⇧ forms). After you change shortcuts in InDesign, the set is read again when InDesign comes back to the front.|读取 InDesign 使用的快捷键组，相同的按键（包括加 ⌥・⇧ 的形式）不在本应用中注册。在 InDesign 中更改快捷键后，回到 InDesign 时会重新读取。|InDesign이 쓰는 단축키 세트를 읽어 같은 키(⌥·⇧를 더한 형태 포함)는 이 앱에서 등록하지 않습니다. InDesign에서 단축키를 바꾸면 InDesign으로 돌아올 때 다시 읽습니다.
preferInDesign.set|読み込んだInDesignのショートカットのセット：%@|InDesign shortcut set read: %@|已读取的 InDesign 快捷键组：%@|읽어 들인 InDesign 단축키 세트: %@
preferInDesign.noSet|InDesignのショートカットのセットはまだ読んでいません（InDesignの起動中に読みます）。|The InDesign shortcut set has not been read yet (it is read while InDesign runs).|尚未读取 InDesign 快捷键组（在 InDesign 运行时读取）。|InDesign 단축키 세트를 아직 읽지 않았습니다(InDesign 실행 중에 읽습니다).
hotkey.yielded|InDesignのショートカットを優先するため登録しません：%@|Left to InDesign's own shortcuts (not registered): %@|优先使用 InDesign 自身的快捷键（不注册）：%@|InDesign 자체 단축키를 우선하므로 등록하지 않음: %@'''
# Shared menu / settings rows carry {APP}.
rows = rows.replace('{APP}', APP)
table = [line.split('|') for line in rows.splitlines() if line]
assert all(len(r) == 5 for r in table), [r[0] for r in table if len(r) != 5]
assert len({r[0] for r in table}) == len(table), 'duplicate key'

# Help text lives in help_text.py (markup rendered by Shared/AppStandards/HelpDocument.swift).
from help_text import HELP
USAGE = ["同梱のスクリプトをInDesignで実行するために使用します。", "Used to run the bundled script in InDesign.", "用于在 InDesign 中运行内置脚本。", "포함된 스크립트를 InDesign에서 실행하는 데 사용합니다."]
for i, lang in enumerate(['ja', 'en', 'zh-Hans', 'ko']):
    p = root / 'Resources' / f'{lang}.lproj'
    p.mkdir(parents=True, exist_ok=True)
    (p / 'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0])} = {json.dumps(r[i + 1], ensure_ascii=False)};' for r in table) + '\n')
    (p / 'InfoPlist.strings').write_text(f'"CFBundleDisplayName" = "{APP}";\n"NSAppleEventsUsageDescription" = {json.dumps(USAGE[i], ensure_ascii=False)};\n')
    (p / 'Help.txt').write_text(HELP[lang])
print('resources:', len(table), 'keys x 4 languages')
