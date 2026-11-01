from pathlib import Path
import json
root = Path(__file__).parent
APP = 'TextLens'
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''processingTab|処理|Processing|处理|처리
resultDisplay|認識結果の表示|Recognition Result Display|识别结果显示|인식 결과 표시
explanation|説明|Explanation|说明|설명
ocr.settings|Vision後の整形ルール|Formatting After Vision|Vision 识别后的格式规则|Vision 인식 후 서식 규칙
ocr.keepLines|認識した文字の改行を保持し、コピー前に整形します。|Recognized line breaks are preserved; formatting is applied before copying.|保留识别的换行，并在拷贝前应用格式。|인식한 줄바꿈을 유지하고 복사 전에 서식을 적용합니다.
heading|文字認識の結果と整形|Recognized Text and Formatting|识别文字与格式处理|인식한 텍스트와 서식
subtitle|選んだ範囲の文字を読み取り、結果と整形ルールを確認します。|Read text in a selected area and review the result and formatting rules.|识别所选区域的文字，查看结果和格式规则。|선택한 영역의 텍스트를 읽고 결과와 서식 규칙을 확인합니다.
pane.ocr|文字認識|Text Recognition|文字识别|문자 인식
activity|最近の処理|Recent Activity|最近的处理|최근 처리
activityEmpty|まだありません。履歴は保存せず、終了すると消えます。|None yet. Not saved; cleared when the app quits.|暂无。不会保存，退出应用时清除。|아직 없습니다. 저장하지 않으며 앱을 종료하면 지워집니다.
change|変更…|Change…|更改…|변경…
choose|選択|Choose|选择|선택
openFolder|Finderで開く|Open in Finder|在访达中打开|Finder에서 열기
resetDefault|初期値に戻す|Restore Default|恢复默认|초기값으로
recognizeButton|範囲を選んで文字認識|Recognize Text in Area|选择区域识别文字|영역을 선택해 문자 인식
recognizeMenu|範囲を選んで文字認識…|Recognize Text in Area…|选择区域识别文字…|영역을 선택해 문자 인식…
ocr.join|日本語の間の空白を詰める|Remove spaces between Japanese characters|删除日文字符之间的空格|일본어 문자 사이의 공백 제거
ocr.parens|半角の ( ) を全角の（ ）にする|Change ( ) to full-width （ ）|将半角 ( ) 改为全角（ ）|반각 ( )를 전각 （ ）로
ocr.panel|読み取った文字を画面の右上に表示|Show the recognized text at the top right|在右上角显示识别的文字|인식한 텍스트를 오른쪽 위에 표시
ocr.last|最後に読み取った文字|Last Recognized Text|最近识别的文字|마지막으로 인식한 텍스트
ocr.lastEmpty|まだありません。|None yet.|暂无。|아직 없습니다.
ocr.detail|範囲を選ぶとその部分の文字（日本語・英語）を読み取り、クリップボードにコピーします。Escで取り消せます。画面収録の許可が必要です。|Select an area to read its Japanese and English text and copy it. Press Esc to cancel. Screen Recording permission is required.|选择区域后识别其中的日文和英文并拷贝。按 Esc 取消。需要录屏权限。|영역을 선택하면 일본어·영어 텍스트를 읽어 복사합니다. Esc로 취소합니다. 화면 기록 권한이 필요합니다.
ocr.copied|読み取った文字をコピーしました|Recognized text copied|已拷贝识别的文字|인식한 텍스트를 복사했습니다
ocr.none|文字が見つかりませんでした|No text found|未找到文字|텍스트를 찾지 못했습니다
ocr.needsPermission|画面収録の許可が必要です|Screen Recording permission is required|需要录屏权限|화면 기록 권한이 필요합니다
ocr.needsPermissionDetail|システム設定の「画面収録とシステムオーディオ録音」でTextLensをオンにしてください。|Turn on TextLens in Screen & System Audio Recording in System Settings.|请在系统设置的“录屏与系统录音”中开启 TextLens。|시스템 설정의 화면 및 시스템 오디오 녹음에서 TextLens를 켜세요.
ocr.allow|システム設定を開く|Open System Settings|打开系统设置|시스템 설정 열기
log.notImage|「%@」を画像として読めませんでした。|Could not read “%@” as an image.|无法将“%@”读取为图像。|“%@”을(를) 이미지로 읽지 못했습니다.
log.ocr|%d文字を読み取ってコピーしました|Recognized and copied %d characters|已识别并拷贝 %d 个字符|%d자를 인식해 복사했습니다
perm.screen|画面収録|Screen Recording|录屏|화면 기록
perm.allowed|許可済み|Allowed|已允许|허용됨
perm.notAllowed|未許可|Not allowed|未允许|허용되지 않음
perm.screenDetail|画面上の選択範囲を撮影するために使います。画像ファイルの文字認識には不要です。|Used to capture a selected screen area. Not needed for image files.|用于截取屏幕所选区域。识别图像文件不需要此权限。|선택한 화면 영역을 촬영하는 데 사용합니다. 이미지 파일 인식에는 필요 없습니다.
perm.request|許可を求める|Request Permission|请求权限|권한 요청
perm.openSettings|画面収録の設定を開く|Open Screen Recording Settings|打开录屏设置|화면 기록 설정 열기
hotkeyTab|ホットキー|Hotkeys|快捷键|단축키
hotkey.ocr|範囲を選んで文字認識|Recognize Text in Area|选择区域识别文字|영역을 선택해 문자 인식
hotkey.ocrDetail|どのアプリからでも、範囲を選んで文字を読み取ります（TextLensの起動中）。|Selects an area and reads its text from any app (while TextLens is running).|在任何应用中选择区域并识别文字（TextLens 运行时）。|어느 앱에서든 영역을 선택해 텍스트를 읽습니다(TextLens 실행 중).
notifyToggle|文字認識の結果を通知|Notify about recognition results|通知文字识别结果|문자 인식 결과 알림
aboutDetail|画面や画像の文字を読み取り、整形してコピーします。|Recognize text in screen areas and images, format it and copy it.|识别屏幕区域和图像中的文字，整理并拷贝。|화면 영역과 이미지의 텍스트를 인식하고 정리하여 복사합니다.
resident|ウインドウを閉じても常駐|Keep running after closing the window|关闭窗口后继续运行|윈도우를 닫아도 계속 실행
residentDetail|閉じた後もDockやメニューバーから再表示できます。オフにすると閉じたときに終了します。|Reopen from the Dock or menu bar. When off, closing the window quits.|可从 Dock 或菜单栏再次打开。关闭此项时，关闭窗口即退出。|Dock 또는 메뉴 막대에서 다시 열 수 있습니다. 끄면 창을 닫을 때 종료됩니다.
launchShortcut|アプリ起動のホットキー|App launch keyboard shortcut|启动应用快捷键|앱 실행 키보드 단축키
openShortcuts|ショートカットを開く|Open Shortcuts|打开快捷指令|단축어 열기
shortcutDetail|ショートカットAppで「アプリを開く」に{APP}を指定し、キーを割り当ててください。未起動時も使えます。|In Shortcuts, create an Open App action for {APP} and assign a key. It works even when the app is not running.|在快捷指令中为 {APP} 创建“打开 App”并分配按键，应用未运行时也可使用。|단축어 앱에서 {APP}을 여는 동작을 만들고 키를 지정하세요. 앱이 실행 중이 아니어도 작동합니다.
appHotkeyHint|{APP}の起動中に押すと、どのアプリからでもメインウインドウを表示します。未起動のときは上の「ショートカットを開く」で割り当てたキーを使ってください。|While {APP} is running, press it in any app to show the main window. When it is not running, use the key assigned with Open Shortcuts above.|{APP} 运行时，在任何应用中按下即可显示主窗口。未运行时请使用上方“打开快捷指令”中分配的按键。|{APP}이 실행 중일 때 어느 앱에서든 누르면 메인 윈도우를 표시합니다. 실행 중이 아닐 때는 위의 '단축어 열기'에서 지정한 키를 사용하세요.
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
ok|OK|OK|好|확인
generalTab|一般|General|通用|일반
drop.ocr|画像ファイルをドロップして文字認識（原本は変更しません）。|Drop an image file to recognize text (the original is unchanged).|拖入图像文件识别文字（不修改原件）。|이미지 파일을 놓아 텍스트를 인식합니다(원본은 변경하지 않습니다).
excluded.detail|対象外アプリが前面の間は、文字認識のホットキーを登録せず、そのアプリへキーを通します。|While an excluded app is in front, the recognition hotkey is unregistered so the key reaches that app.|排除的应用在前台时取消注册识别快捷键，让按键传递给该应用。|제외한 앱이 앞에 있으면 인식 단축키 등록을 해제하여 키가 해당 앱에 전달되도록 합니다.
sharing.detail|文字認識後の整形と結果表示の設定を共有します。|Shares recognition formatting and result display preferences.|共享识别后的格式和结果显示设置。|인식 후 서식과 결과 표시 설정을 공유합니다.
sharing.perMac|ログイン起動・常駐・ホットキー・対象外アプリ・通知はMacごとに設定します。|Login, residency, hotkeys, excluded apps and notifications are per Mac.|登录启动、常驻、快捷键、排除应用和通知按 Mac 设置。|로그인 실행, 상주, 단축키, 제외 앱 및 알림은 Mac마다 설정합니다.
busy.quit|文字認識の終了を待ってから終了してください。範囲選択はEscで取り消せます。|Wait for recognition to finish before quitting. Press Esc to cancel area selection.|请等待识别结束后退出。按 Esc 取消区域选择。|인식이 끝난 후 종료하세요. Esc로 영역 선택을 취소할 수 있습니다.'''
# Shared menu / settings rows carry {APP}.
rows = rows.replace('{APP}', APP)
table = [line.split('|') for line in rows.splitlines() if line]
assert all(len(r) == 5 for r in table), [r[0] for r in table if len(r) != 5]
assert len({r[0] for r in table}) == len(table), 'duplicate key'

# Help text lives in help_text.py (markup rendered by Shared/AppStandards/HelpDocument.swift).
from help_text import HELP
for i, lang in enumerate(['ja', 'en', 'zh-Hans', 'ko']):
    p = root / 'Resources' / f'{lang}.lproj'
    p.mkdir(parents=True, exist_ok=True)
    (p / 'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0])} = {json.dumps(r[i + 1], ensure_ascii=False)};' for r in table) + '\n')
    (p / 'InfoPlist.strings').write_text(f'"CFBundleDisplayName" = "{APP}";\n')
    (p / 'Help.txt').write_text(HELP[lang])
print('resources:', len(table), 'keys x 4 languages')
