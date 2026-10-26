from pathlib import Path
import json
root = Path(__file__).parent
APP = 'VectorKeys'
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''heading|Illustratorのスクリプト|Illustrator Scripts|Illustrator 脚本|Illustrator 스크립트
subtitle|登録したスクリプトを、Illustratorが前面のときにキーボードショートカットで実行します。|Runs your scripts with keyboard shortcuts while Illustrator is in front.|在 Illustrator 位于前台时，用键盘快捷键运行已登记的脚本。|Illustrator가 앞에 있을 때 등록한 스크립트를 키보드 단축키로 실행합니다.
useHotkeysHint|オフにすると、スクリプトのショートカットをすべて一時停止します。|When off, all script shortcuts are paused.|关闭后暂停所有脚本快捷键。|끄면 모든 스크립트 단축키를 일시 정지합니다.
useHotkeysDetail|スクリプトのショートカットは、Illustratorが前面にあるときだけ登録します。ほかのアプリでは同じキーが本来の働きをします。オフにすると一時停止します（メニューバーのアイコンからも切り替えられます）。|Script shortcuts are registered only while Illustrator is in front, so the same keys keep their meaning in other apps. Turn off to pause them (also from the menu bar icon).|脚本快捷键仅在 Illustrator 位于前台时注册，因此在其他应用中按键保持原有功能。关闭可暂停（也可从菜单栏图标切换）。|스크립트 단축키는 Illustrator가 앞에 있을 때만 등록하므로 다른 앱에서는 같은 키가 원래 기능을 합니다. 끄면 일시 정지합니다(메뉴 막대 아이콘에서도 전환 가능).
state.hint|スクリプトのショートカットは、Illustratorが前面のときだけ働きます。|Script shortcuts work only while Illustrator is in front.|脚本快捷键仅在 Illustrator 位于前台时有效。|스크립트 단축키는 Illustrator가 앞에 있을 때만 작동합니다.
addMenu|スクリプトを追加…|Add Scripts…|添加脚本…|스크립트 추가…
add|追加|Add|添加|추가
add.skipped|スクリプトではないファイルを%d個とばしました（.jsx・.js・.jsxbin だけ追加できます）。|Skipped %d files that are not scripts (only .jsx, .js and .jsxbin can be added).|已跳过 %d 个非脚本文件（仅可添加 .jsx、.js 和 .jsxbin）。|스크립트가 아닌 파일 %d개를 건너뛰었습니다(.jsx, .js, .jsxbin만 추가 가능).
empty|スクリプトがまだありません。［スクリプトを追加…］で選ぶか、ここへ .jsx ファイルをドラッグしてください。|No scripts yet. Click Add Scripts… or drag .jsx files here.|还没有脚本。点按“添加脚本…”或将 .jsx 文件拖到此处。|아직 스크립트가 없습니다. [스크립트 추가…]를 클릭하거나 .jsx 파일을 여기로 드래그하세요.
selectScript|スクリプトを選んでください|Select a script|请选择脚本|스크립트를 선택하세요
count|%d本|%d scripts|%d 个|%d개
file|ファイル|File|文件|파일
reveal|Finderに表示|Show in Finder|在访达中显示|Finder에서 보기
relink|ファイルを選び直す…|Choose Another File…|重新选择文件…|파일 다시 선택…
relinkHint|移動・名前を変えたスクリプトを指定し直します。ショートカットはそのまま残ります。|Points to a moved or renamed script. The shortcut stays.|重新指定已移动或重命名的脚本。快捷键保持不变。|이동하거나 이름을 바꾼 스크립트를 다시 지정합니다. 단축키는 그대로 유지됩니다.
badge.missing|ファイルなし|Missing|文件丢失|파일 없음
badge.missingHint|ファイルが見つかりません。移動した場合は［ファイルを選び直す…］で指定し直してください。|File not found. If it was moved, use Choose Another File… to point to it.|找不到文件。如果已移动，请用“重新选择文件…”重新指定。|파일을 찾을 수 없습니다. 이동했다면 [파일 다시 선택…]으로 다시 지정하세요.
runHint|Illustratorを前面にしてから実行します。|Brings Illustrator to the front, then runs.|先将 Illustrator 置于前台再运行。|Illustrator를 앞으로 가져온 뒤 실행합니다.
hotkeyHint|Illustratorが前面のときだけ働きます。Illustrator自身のショートカットと同じキーにすると、こちらが優先されます。|Works only while Illustrator is in front. A key that Illustrator also uses runs the script instead.|仅在 Illustrator 位于前台时有效。若与 Illustrator 自身的快捷键相同，则优先运行脚本。|Illustrator가 앞에 있을 때만 작동합니다. Illustrator 자체 단축키와 같은 키라면 스크립트가 우선합니다.
hotkey.duplicate|ほかのスクリプトと同じキーです。一覧で上にあるスクリプトだけが反応します。|Same key as another script; only the one higher in the list reacts.|与另一个脚本的按键相同，只有列表中靠上的脚本会响应。|다른 스크립트와 같은 키입니다. 목록에서 위에 있는 스크립트만 반응합니다.
hotkeysSection|スクリプトのショートカット|Script Shortcuts|脚本快捷键|스크립트 단축키
deleteConfirm|このスクリプトを一覧から削除しますか？|Remove this script from the list?|从列表中删除此脚本？|이 스크립트를 목록에서 삭제할까요?
deleteConfirmDetail|ファイルそのものは削除しません。ショートカットの割り当ては消えます。|The file itself is not deleted. Its shortcut is removed.|不会删除文件本身，但会移除其快捷键。|파일 자체는 삭제하지 않습니다. 단축키 지정은 사라집니다.
saveFailed|一覧を保存できませんでした：%@|Could not save the list: %@|无法存储列表：%@|목록을 저장하지 못했습니다: %@
result.fileMissing|ファイルが見つかりません。|File not found.|找不到文件。|파일을 찾을 수 없습니다.
result.failed|エラーで止まりました：%@|Stopped with an error: %@|因错误而停止：%@|오류로 중지됨: %@
aboutDetail|登録したスクリプトを、Illustratorが前面のときにキーボードショートカットで実行します。サポート：同梱のREADME.md|Runs your scripts with keyboard shortcuts while Illustrator is in front. Support: bundled README.md|在 Illustrator 位于前台时用键盘快捷键运行已登记的脚本。支持：内置 README.md|Illustrator가 앞에 있을 때 등록한 스크립트를 키보드 단축키로 실행합니다. 지원: 포함된 README.md
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
result.noIllustrator|Illustratorが起動していません。|Illustrator is not running.|Illustrator 未运行。|Illustrator가 실행 중이 아닙니다.
result.automation|Illustratorを操作する許可がありません。システム設定＞プライバシーとセキュリティ＞オートメーションで、{APP}のAdobe Illustratorをオンにしてください。|Not allowed to control Illustrator. Turn on Adobe Illustrator for {APP} in System Settings > Privacy & Security > Automation.|没有控制 Illustrator 的权限。请在“系统设置”>“隐私与安全性”>“自动化”中为 {APP} 打开 Adobe Illustrator。|Illustrator를 제어할 권한이 없습니다. 시스템 설정 > 개인정보 보호 및 보안 > 자동화에서 {APP}의 Adobe Illustrator를 켜세요.
state.front|Illustratorが前面：ホットキー有効|Illustrator in front: hotkeys on|Illustrator 在前台：快捷键有效|Illustrator가 앞에 있음: 단축키 사용
state.back|Illustratorが背面：ホットキー待機中|Illustrator not in front: hotkeys waiting|Illustrator 不在前台：快捷键待机|Illustrator가 뒤에 있음: 단축키 대기'''
# Shared menu / settings rows carry {APP}.
rows = rows.replace('{APP}', APP)
table = [line.split('|') for line in rows.splitlines() if line]
assert all(len(r) == 5 for r in table), [r[0] for r in table if len(r) != 5]
assert len({r[0] for r in table}) == len(table), 'duplicate key'

# Help text lives in help_text.py (markup rendered by Shared/AppStandards/HelpDocument.swift).
from help_text import HELP
USAGE = ["登録したスクリプトをIllustratorで実行するために使用します。", "Used to run your registered scripts in Illustrator.", "用于在 Illustrator 中运行已登记的脚本。", "등록한 스크립트를 Illustrator에서 실행하는 데 사용합니다."]
for i, lang in enumerate(['ja', 'en', 'zh-Hans', 'ko']):
    p = root / 'Resources' / f'{lang}.lproj'
    p.mkdir(parents=True, exist_ok=True)
    (p / 'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0])} = {json.dumps(r[i + 1], ensure_ascii=False)};' for r in table) + '\n')
    (p / 'InfoPlist.strings').write_text(f'"CFBundleDisplayName" = "{APP}";\n"NSAppleEventsUsageDescription" = {json.dumps(USAGE[i], ensure_ascii=False)};\n')
    (p / 'Help.txt').write_text(HELP[lang])
print('resources:', len(table), 'keys x 4 languages')
