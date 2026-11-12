from pathlib import Path
import json
root = Path(__file__).parent
APP = 'LayoutKeys'
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''heading|InDesignでスクリプトを高速実行|Run InDesign Scripts Fast|在 InDesign 中快速运行脚本|InDesign에서 스크립트를 빠르게 실행
subtitle|登録したスクリプトを、InDesignが前面のときにキーボードショートカットで実行します。|Runs your scripts with keyboard shortcuts while InDesign is in front.|在 InDesign 位于前台时，用键盘快捷键运行已登记的脚本。|InDesign이 앞에 있을 때 등록한 스크립트를 키보드 단축키로 실행합니다.
useHotkeysHint|オフにすると、スクリプトのショートカットをすべて一時停止します。|When off, all script shortcuts are paused.|关闭后暂停所有脚本快捷键。|끄면 모든 스크립트 단축키를 일시 정지합니다.
useHotkeysDetail|スクリプトのショートカットは、InDesignが前面にあるときだけ登録します。ほかのアプリでは同じキーが本来の働きをします。オフにすると一時停止します（メニューバーのアイコンからも切り替えられます）。|Script shortcuts are registered only while InDesign is in front, so the same keys keep their meaning in other apps. Turn off to pause them (also from the menu bar icon).|脚本快捷键仅在 InDesign 位于前台时注册，因此在其他应用中按键保持原有功能。关闭可暂停（也可从菜单栏图标切换）。|스크립트 단축키는 InDesign이 앞에 있을 때만 등록하므로 다른 앱에서는 같은 키가 원래 기능을 합니다. 끄면 일시 정지합니다(메뉴 막대 아이콘에서도 전환 가능).
state.hint|スクリプトのショートカットは、InDesignが前面のときだけ働きます。|Script shortcuts work only while InDesign is in front.|脚本快捷键仅在 InDesign 位于前台时有效。|스크립트 단축키는 InDesign이 앞에 있을 때만 작동합니다.
addMenu|スクリプトを追加…|Add Scripts…|添加脚本…|스크립트 추가…
add|追加|Add|添加|추가
add.skipped|スクリプトではないファイルを%d個とばしました（.jsx・.js・.jsxbin だけ追加できます）。|Skipped %d files that are not scripts (only .jsx, .js and .jsxbin can be added).|已跳过 %d 个非脚本文件（仅可添加 .jsx、.js 和 .jsxbin）。|스크립트가 아닌 파일 %d개를 건너뛰었습니다(.jsx, .js, .jsxbin만 추가 가능).
empty|スクリプトがまだありません。［スクリプトを追加…］で選ぶか、ここへ .jsx ファイルをドラッグしてください。|No scripts yet. Click Add Scripts… or drag .jsx files here.|还没有脚本。点按“添加脚本…”或将 .jsx 文件拖到此处。|아직 스크립트가 없습니다. [스크립트 추가…]를 클릭하거나 .jsx 파일을 여기로 드래그하세요.
selectScript|スクリプトを選んでください|Select a script|请选择脚本|스크립트를 선택하세요
count|%d本|%d scripts|%d 个|%d개
uses.count|%d回|%d runs|%d 次|%d회
uses.detail|実行回数：%d回（最終：%@）|Runs: %d (last: %@)|运行次数：%d 次（最近：%@）|실행 횟수: %d회(최근: %@)
uses.never|まだ実行していません|Not run yet|尚未运行|아직 실행하지 않음
uses.hint|ショートカットと［実行］ボタンで、エラーなく終わった回数です。|Runs that finished without an error, from the shortcut or the Run button.|通过快捷键和“运行”按钮无错误完成的次数。|단축키와 [실행] 버튼으로 오류 없이 끝난 횟수입니다.
file|ファイル|File|文件|파일
reveal|Finderに表示|Show in Finder|在访达中显示|Finder에서 보기
relink|ファイルを選び直す…|Choose Another File…|重新选择文件…|파일 다시 선택…
relinkHint|移動・名前を変えたスクリプトを指定し直します。ショートカットはそのまま残ります。|Points to a moved or renamed script. The shortcut stays.|重新指定已移动或重命名的脚本。快捷键保持不变。|이동하거나 이름을 바꾼 스크립트를 다시 지정합니다. 단축키는 그대로 유지됩니다.
badge.missing|ファイルなし|Missing|文件丢失|파일 없음
badge.missingHint|ファイルが見つかりません。移動した場合は［ファイルを選び直す…］で指定し直してください。|File not found. If it was moved, use Choose Another File… to point to it.|找不到文件。如果已移动，请用“重新选择文件…”重新指定。|파일을 찾을 수 없습니다. 이동했다면 [파일 다시 선택…]으로 다시 지정하세요.
runHint|InDesignを前面にしてから実行します。|Brings InDesign to the front, then runs.|先将 InDesign 置于前台再运行。|InDesign을 앞으로 가져온 뒤 실행합니다.
hotkeyHint|InDesignが前面のときだけ働きます。InDesign自身のショートカットと同じキーにすると、こちらが優先されます。|Works only while InDesign is in front. A key that InDesign also uses runs the script instead.|仅在 InDesign 位于前台时有效。若与 InDesign 自身的快捷键相同，则优先运行脚本。|InDesign이 앞에 있을 때만 작동합니다. InDesign 자체 단축키와 같은 키라면 스크립트가 우선합니다.
hotkey.duplicate|ほかのスクリプトと同じキーです。一覧で上にあるスクリプトだけが反応します。|Same key as another script; only the one higher in the list reacts.|与另一个脚本的按键相同，只有列表中靠上的脚本会响应。|다른 스크립트와 같은 키입니다. 목록에서 위에 있는 스크립트만 반응합니다.
hotkeysSection|スクリプトのショートカット|Script Shortcuts|脚本快捷键|스크립트 단축키
deleteConfirm|このスクリプトを一覧から削除しますか？|Remove this script from the list?|从列表中删除此脚本？|이 스크립트를 목록에서 삭제할까요?
deleteConfirmDetail|ファイルそのものは削除しません。ショートカットの割り当ては消えます。|The file itself is not deleted. Its shortcut is removed.|不会删除文件本身，但会移除其快捷键。|파일 자체는 삭제하지 않습니다. 단축키 지정은 사라집니다.
saveFailed|一覧を保存できませんでした：%@|Could not save the list: %@|无法存储列表：%@|목록을 저장하지 못했습니다: %@
result.fileMissing|ファイルが見つかりません。|File not found.|找不到文件。|파일을 찾을 수 없습니다.
result.failed|エラーで止まりました：%@|Stopped with an error: %@|因错误而停止：%@|오류로 중지됨: %@
aboutDetail|登録したスクリプトを、InDesignが前面のときにキーボードショートカットで実行します。サポート：同梱のREADME.md|Runs your scripts with keyboard shortcuts while InDesign is in front. Support: bundled README.md|在 InDesign 位于前台时用键盘快捷键运行已登记的脚本。支持：内置 README.md|InDesign이 앞에 있을 때 등록한 스크립트를 키보드 단축키로 실행합니다. 지원: 포함된 README.md
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
search|検索|Search|搜索|검색
recent|最近の実行|Recent Runs|最近运行|최근 실행
recentEmpty|まだありません。履歴は保存せず、終了すると消えます。|None yet. Not saved; cleared when the app quits.|暂无。不会保存，退出应用时清除。|아직 없습니다. 저장하지 않으며 앱을 종료하면 지워집니다.
a11y.error|失敗|Failed|失败|실패
a11y.success|成功|Succeeded|成功|성공
run|実行|Run|运行|실행
delete|削除|Delete|删除|삭제
name|名前|Name|名称|이름
enabled|ホットキーを有効にする|Enable the hotkey|启用快捷键|단축키 사용
enabledHint|ホットキーのオン・オフ|Hotkey on or off|快捷键开关|단축키 켜기/끄기
hotkey|ホットキー|Hotkey|快捷键|단축키
hotkey.failed|このキーを登録できませんでした。ほかのアプリが使っている可能性があります。|This key could not be registered; another app may be using it.|无法注册此按键，可能被其他应用占用。|이 키를 등록하지 못했습니다. 다른 앱이 사용 중일 수 있습니다.
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
variables|スクリプトの変数|Script Variables|脚本变量|스크립트 변수
variables.default|初期値（%@）|Default (%@)|初始值（%@）|초기값(%@)
variables.empty|初期値は空|Empty by default|初始值为空|초기값은 비어 있음
variables.stale|ファイルに無くなった変数の値が残っています：%@|Values remain for variables no longer in the file: %@|仍保留文件中已不存在的变量值：%@|파일에 더 이상 없는 변수의 값이 남아 있습니다: %@
variables.clearStale|取り除く|Remove|移除|제거
variables.reload|読み直す|Reload|重新读取|다시 읽기
variables.reloadHint|ファイルを書き換えたときに、変数の一覧を読み直します。|Reads the variables again after the file was edited.|文件修改后重新读取变量列表。|파일을 수정한 뒤 변수 목록을 다시 읽습니다.
variables.hint|値を入れた変数だけ、実行のたびにファイルの初期値を差し替えて実行します。ファイルそのものは書き換えません。空欄はファイルの初期値のままです。|Only the variables with a value are changed, on each run, in a copy of the file. The file itself is not changed. Empty fields keep the file's initial values.|只有填写了值的变量会在每次运行时替换文件中的初始值，文件本身不会被修改。空栏保持文件的初始值。|값을 넣은 변수만 실행할 때마다 파일의 초기값을 바꿔 실행합니다. 파일 자체는 수정하지 않습니다. 빈 칸은 파일의 초기값을 그대로 씁니다.
varKeys.count|キー%d個|%d keys|%d 个按键|키 %d개
varKeys.asSet|上の設定のまま|As set above|按上方设置|위 설정 그대로
varKeys.add|行を追加|Add Row|添加行|행 추가
varKeys.remove|この行を削除|Remove this row|删除此行|이 행 삭제
varKeys.fill|%@ の候補ごとに追加|Add a Row for Each %@|为每个 %@ 候选添加|%@ 후보마다 추가
varKeys.fillHint|まだ行の無い候補を1つずつ行にします。キーは空のままなので、行ごとに割り当ててください。|Adds a row for each choice that has none yet. Assign a key to each row.|为尚无行的每个候选添加一行。请为每行分配按键。|아직 행이 없는 후보마다 행을 만듭니다. 행마다 키를 지정하세요.
varKeys.hint|行ごとに変数の値を選んでキーを割り当てると、そのキーでは値を差し替えて実行します。「—」の変数は上の設定（空ならファイルの初期値）のままです。|Pick values and a key for each row: that key runs the script with those values. Variables left at "—" keep the setting above (or the file's initial value).|为每行选择变量值并分配按键，该按键会以这些值运行脚本。“—”的变量保持上方设置（为空则为文件的初始值）。|행마다 변수 값을 고르고 키를 지정하면 그 키로 값을 바꿔 실행합니다. '—'인 변수는 위 설정(비어 있으면 파일의 초기값)을 그대로 씁니다.
varKeys.fillAll|すべての組み合わせを追加（%d通り）|Add All Combinations (%d)|添加所有组合（%d 种）|모든 조합 추가(%d가지)
varKeys.fillAllHint|候補のある変数の値をすべて組み合わせて、まだ行の無い組み合わせを1つずつ行にします。キーは行ごとに割り当ててください。|Adds a row for each combination of the variables' choices that has no row yet. Assign a key to each row.|将有候选的变量值全部组合，为尚无行的每种组合添加一行。请为每行分配按键。|후보가 있는 변수 값을 모두 조합해 아직 행이 없는 조합마다 행을 만듭니다. 행마다 키를 지정하세요.
explain|説明|Details|说明|설명
sharing.note|ホットキーを使うかどうかを同期します。|Syncs whether the hotkeys are used.|同步是否使用快捷键。|단축키 사용 여부를 동기화합니다.
sharing.perMac|スクリプトの一覧（ファイルの場所・変数・ホットキー）、ログイン時の起動・常駐・メニューバーの表示・アプリを呼び出すホットキー・ウインドウの位置はMacごとに設定します。一覧は書き出し・読み込みで移せます。|The script list (file locations, variables and hotkeys), open at login, keep running, the menu bar icon, the app hotkey and window positions are set on each Mac. Move the list with export and import.|脚本列表（文件位置、变量和快捷键）、登录时启动、保持运行、菜单栏图标、调出应用的快捷键和窗口位置在每台 Mac 上分别设置。列表可通过导出和导入转移。|스크립트 목록(파일 위치·변수·단축키), 로그인 시 실행, 계속 실행, 메뉴 막대 아이콘, 앱 호출 단축키, 윈도우 위치는 Mac마다 설정합니다. 목록은 내보내기와 가져오기로 옮길 수 있습니다.
sharing.fileNote|スクリプトの一覧（名前・ファイルの場所・変数の値・ホットキー・変数ごとのホットキー）と、ホットキーを使うかどうかを書き出します。読み込むと、このMacの一覧がファイルの内容に置き換わります。ファイルの場所は書き出したMacのままなので、別のMacでは同じ場所にスクリプトを置いてください。|Exports the script list (names, file locations, variable values, hotkeys and variable hotkeys) and whether the hotkeys are used. Importing replaces this Mac's list with the file's. File locations stay as on the exporting Mac, so put the scripts in the same places on the other Mac.|导出脚本列表（名称、文件位置、变量值、快捷键和变量快捷键）以及是否使用快捷键。导入会将此 Mac 的列表替换为文件内容。文件位置保持导出时的 Mac 上的位置，请在另一台 Mac 上将脚本放在相同位置。|스크립트 목록(이름·파일 위치·변수 값·단축키·변수별 단축키)과 단축키 사용 여부를 내보냅니다. 가져오면 이 Mac의 목록이 파일 내용으로 바뀝니다. 파일 위치는 내보낸 Mac 그대로이므로 다른 Mac에서도 같은 위치에 스크립트를 두세요.
sharing.badLibrary|ファイルのスクリプトの一覧を読めませんでした。一覧はそのままです。|Could not read the script list in the file. The list is unchanged.|无法读取文件中的脚本列表。列表保持不变。|파일의 스크립트 목록을 읽지 못했습니다. 목록은 그대로입니다.
state.back|InDesignが背面：ホットキー待機中|InDesign not in front: hotkeys waiting|InDesign 不在前台：快捷键待机|InDesign이 뒤에 있음: 단축키 대기'''
# Shared menu / settings rows carry {APP}.
rows = rows.replace('{APP}', APP)
table = [line.split('|') for line in rows.splitlines() if line]
assert all(len(r) == 5 for r in table), [r[0] for r in table if len(r) != 5]
assert len({r[0] for r in table}) == len(table), 'duplicate key'

# Help text lives in help_text.py (markup rendered by Shared/AppStandards/HelpDocument.swift).
from help_text import HELP
USAGE = ["登録したスクリプトをInDesignで実行するために使用します。", "Used to run your registered scripts in InDesign.", "用于在 InDesign 中运行已登记的脚本。", "등록한 스크립트를 InDesign에서 실행하는 데 사용합니다."]
for i, lang in enumerate(['ja', 'en', 'zh-Hans', 'ko']):
    p = root / 'Resources' / f'{lang}.lproj'
    p.mkdir(parents=True, exist_ok=True)
    (p / 'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0])} = {json.dumps(r[i + 1], ensure_ascii=False)};' for r in table) + '\n')
    (p / 'InfoPlist.strings').write_text(f'"CFBundleDisplayName" = "{APP}";\n"NSAppleEventsUsageDescription" = {json.dumps(USAGE[i], ensure_ascii=False)};\n')
    (p / 'Help.txt').write_text(HELP[lang])
print('resources:', len(table), 'keys x 4 languages')
