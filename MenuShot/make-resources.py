from pathlib import Path
import json
root = Path(__file__).parent
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''heading|メニューを撮影|Capture Menus|截取菜单|메뉴 캡처
subtitle|メニューバーと開いたメニューだけを、背景なしで撮ります。|Captures only the menu bar and the open menus, without the background.|仅截取菜单栏和打开的菜单，不含背景。|메뉴 막대와 열린 메뉴만 배경 없이 캡처합니다.
noPicture|撮影した画像がここに表示されます。|The captured picture appears here.|截取的图像会显示在这里。|캡처한 이미지가 여기에 표시됩니다.
captureAfter|%d秒後に撮影|Capture in %d s|%d 秒后截取|%d초 후 캡처
captureNow|撮影|Capture|截取|캡처
captureMenuItem|撮影|Capture|截取|캡처
cancelCountdown|キャンセル（%d）|Cancel (%d)|取消（%d）|취소(%d)
hotkeyHint|メニューを開いたまま %@ でも撮影できます|Or press %@ with a menu open|也可以在菜单打开时按 %@|메뉴를 연 채 %@를 눌러도 됩니다
revealInFinder|Finderで表示|Show in Finder|在访达中显示|Finder에서 보기
canceled|撮影をキャンセルしました。|Capture canceled.|已取消截取。|캡처를 취소했습니다.
saved|「%@」を保存しました。|Saved “%@”.|已存储“%@”。|“%@”을(를) 저장했습니다.
savedAndCopied|「%@」を保存し、クリップボードにコピーしました。|Saved “%@” and copied it to the clipboard.|已存储“%@”并拷贝到剪贴板。|“%@”을(를) 저장하고 클립보드에 복사했습니다.
noMenu|開いているメニューが見つかりませんでした。撮影までの間にメニューを開いてください。|No open menu was found. Open a menu before the capture.|未找到打开的菜单。请在截取前打开菜单。|열린 메뉴를 찾지 못했습니다. 캡처 전에 메뉴를 여세요.
needPermission|画面収録が許可されていません。システム設定の「画面収録とシステムオーディオ録音」でMenuShotをオンにし、MenuShotを開き直してください。|Screen Recording is not allowed. Turn on MenuShot in System Settings › Screen & System Audio Recording, then reopen MenuShot.|未允许录屏。请在系统设置的“录屏与系统录音”中打开 MenuShot，然后重新打开 MenuShot。|화면 기록이 허용되지 않았습니다. 시스템 설정의 '화면 및 시스템 오디오 녹음'에서 MenuShot을 켠 다음 MenuShot을 다시 여세요.
captureFailed|撮影できませんでした（%@）。もう一度お試しください。|Could not capture (%@). Try again.|无法截取（%@）。请重试。|캡처하지 못했습니다(%@). 다시 시도하세요.
filePrefix|メニュー|Menu|菜单|메뉴
choose|選択|Choose|选择|선택
screenRecording|画面収録|Screen Recording|录屏|화면 기록
permitted|許可済み|Allowed|已允许|허용됨
notPermitted|未許可|Not allowed|未允许|허용되지 않음
screenRecordingReason|メニューバーとメニューのウインドウを撮るために使います。ほかのウインドウやデスクトップは撮りません。許可したあとはMenuShotを開き直してください。|Used to capture the menu bar and menu windows. Other windows and the desktop are not captured. Reopen MenuShot after allowing it.|用于截取菜单栏和菜单窗口，不会截取其他窗口或桌面。允许后请重新打开 MenuShot。|메뉴 막대와 메뉴 윈도우를 캡처하는 데 사용합니다. 다른 윈도우나 데스크탑은 캡처하지 않습니다. 허용한 후 MenuShot을 다시 여세요.
openScreenRecording|画面収録の設定を開く|Open Screen Recording Settings|打开录屏设置|화면 기록 설정 열기
captureTab|撮影|Capture|截取|캡처
captureHotkey|撮影のホットキー|Capture hotkey|截取快捷键|캡처 단축키
captureHotkeyDetail|メニューを開いたまま押すと、すぐに撮影します。メニューが開いていないときは、撮影までの秒数を数えてから撮影します。|Press it with a menu open to capture at once. With no menu open, it counts down the delay first.|在菜单打开时按下会立即截取。没有打开的菜单时，会先倒数延迟秒数再截取。|메뉴를 연 채 누르면 바로 캡처합니다. 열린 메뉴가 없으면 대기 시간을 센 뒤 캡처합니다.
inputMonitoring|入力監視|Input Monitoring|输入监控|입력 모니터링
inputMonitoringReason|メニューを開いたままホットキーで撮るために使います（メニューの表示中は、ふつうのホットキーが届きません）。キーは照らし合わせるだけで、記録も送信もしません。未許可のときは、メニューが閉じているときだけ効きます。|Lets the hotkey work with a menu open (ordinary hotkeys do not arrive while a menu is shown). Keys are only compared, never recorded or sent. Without it, the hotkey works only with no menu open.|用于在菜单打开时用快捷键截取（菜单显示时普通快捷键无法送达）。按键仅作比对，不会记录或发送。未允许时仅在没有打开菜单时有效。|메뉴를 연 채 단축키로 캡처하는 데 사용합니다(메뉴 표시 중에는 일반 단축키가 전달되지 않음). 키는 비교만 하며 기록하거나 전송하지 않습니다. 허용하지 않으면 메뉴가 닫혀 있을 때만 작동합니다.
allowInputMonitoring|入力監視を許可…|Allow Input Monitoring…|允许输入监控…|입력 모니터링 허용…
flashScreen|撮影した範囲を点滅させる|Flash the captured area|闪烁截取的区域|캡처한 영역 깜박이기
delayTitle|撮影までの秒数|Delay|延迟|대기 시간
seconds|%d秒|%d s|%d 秒|%d초
delayDetail|［撮影］ボタンやメニューバーのアイコンから撮るとき、この間にメニューを開きます。0秒にするとすぐに撮影します。|When capturing from the Capture button or the menu bar icon, open the menu during this time. 0 captures at once.|从“截取”按钮或菜单栏图标截取时，请在这段时间内打开菜单。设为 0 会立即截取。|캡처 버튼이나 메뉴 막대 아이콘으로 캡처할 때 이 시간 동안 메뉴를 엽니다. 0이면 바로 캡처합니다.
rangeTitle|写す範囲|Range|范围|범위
range.fromLeft|メニューバーの左端からメニューの右まで|From the left of the menu bar to the right of the menu|从菜单栏左端到菜单右侧|메뉴 막대 왼쪽 끝부터 메뉴 오른쪽까지
range.menuWidth|メニューの幅だけ|Only the width of the menu|仅菜单的宽度|메뉴 너비만
range.fullWidth|メニューバー全体|The whole menu bar|整个菜单栏|메뉴 막대 전체
rangeDetail|右クリックのメニューなど、メニューバーから離れたメニューは、メニューだけを撮ります。|Menus away from the menu bar, such as contextual menus, are captured on their own.|远离菜单栏的菜单（如右键菜单）只截取菜单本身。|메뉴 막대에서 떨어진 메뉴(오른쪽 클릭 메뉴 등)는 메뉴만 캡처합니다.
shadow|メニューに影を付ける|Add a shadow to the menu|为菜单添加阴影|메뉴에 그림자 추가
outputTab|出力|Output|输出|출력
folderTitle|保存先|Save To|存储位置|저장 위치
chooseFolder|フォルダを選択…|Choose Folder…|选择文件夹…|폴더 선택…
showFolder|フォルダを開く|Open Folder|打开文件夹|폴더 열기
resetFolder|初期値に戻す|Reset to Default|恢复默认|기본값으로 재설정
folderDetail|初期値はmacOSのスクリーンショットと同じ保存先です。同じ名前のファイルがあるときは番号を付けて保存し、上書きしません。|By default, the same folder as macOS screenshots. Files with the same name get a number instead of being overwritten.|默认与 macOS 截屏的存储位置相同。存在同名文件时会加上编号，不会覆盖。|기본값은 macOS 스크린샷과 같은 위치입니다. 같은 이름의 파일이 있으면 번호를 붙여 저장하며 덮어쓰지 않습니다.
afterCapture|撮影したあと|After Capturing|截取后|캡처 후
copyToClipboard|クリップボードにもコピー|Also copy to the clipboard|同时拷贝到剪贴板|클립보드에도 복사
playSound|撮影の音を鳴らす|Play the capture sound|播放截取声音|캡처 소리 재생
openQuickLook|Quick Lookで開く|Open in Quick Look|用快速查看打开|훑어보기로 열기
resident|ウインドウを閉じても常駐|Keep running after closing the window|关闭窗口后继续运行|윈도우를 닫아도 계속 실행
residentDetail|閉じた後もDockやメニューバーから再表示でき、撮影のホットキーも使えます。オフにすると閉じたときに終了します。|Reopen from the Dock or menu bar; the capture hotkey keeps working. When off, closing the window quits.|可从 Dock 或菜单栏再次打开，截取快捷键仍可使用。关闭此项时，关闭窗口即退出。|Dock 또는 메뉴 막대에서 다시 열 수 있고 캡처 단축키도 계속 작동합니다. 끄면 창을 닫을 때 종료됩니다.
launchShortcut|アプリ起動のホットキー|App launch keyboard shortcut|启动应用快捷键|앱 실행 키보드 단축키
openShortcuts|ショートカットを開く|Open Shortcuts|打开快捷指令|단축어 열기
shortcutDetail|ショートカットAppで「アプリを開く」にMenuShotを指定し、キーを割り当ててください。未起動時も使えます。|In Shortcuts, create an Open App action for MenuShot and assign a key. It works even when the app is not running.|在快捷指令中为 MenuShot 创建“打开 App”并分配按键，应用未运行时也可使用。|단축어 앱에서 MenuShot을 여는 동작을 만들고 키를 지정하세요. 앱이 실행 중이 아니어도 작동합니다.
appHotkeyHint|MenuShotの起動中に押すと、どのアプリからでもメインウインドウを表示します。初期値は未設定です。|While MenuShot is running, press it in any app to show the main window. Not set by default.|MenuShot 运行时，在任何应用中按下即可显示主窗口。默认未设置。|MenuShot이 실행 중일 때 어느 앱에서든 누르면 메인 윈도우를 표시합니다. 기본값은 설정되지 않음입니다.
openMainWindow|メインウインドウを開く|Open Main Window|打开主窗口|메인 윈도우 열기
settings|設定…|Settings…|设置…|설정…
settingsWindow|設定|Settings|设置|설정
help|MenuShotヘルプ|MenuShot Help|MenuShot 帮助|MenuShot 도움말
helpMenu|ヘルプ|Help|帮助|도움말
quit|MenuShotを終了|Quit MenuShot|退出 MenuShot|MenuShot 종료
hide|MenuShotを隠す|Hide MenuShot|隐藏 MenuShot|MenuShot 가리기
services|サービス|Services|服务|서비스
hideOthers|ほかを隠す|Hide Others|隐藏其他|기타 가리기
showAll|すべてを表示|Show All|全部显示|모두 보기
about|MenuShotについて|About MenuShot|关于 MenuShot|MenuShot에 관하여
aboutDetail|メニューバーと開いたメニューだけを背景なしで撮ります。サポート：同梱のREADME.md|Captures only the menu bar and open menus without the background. Support: bundled README.md|仅截取菜单栏和打开的菜单，不含背景。支持：内置 README.md|메뉴 막대와 열린 메뉴만 배경 없이 캡처합니다. 지원: 포함된 README.md
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
selectAll|すべてを選択|Select All|全选|모두 선택'''
table = [line.split('|') for line in rows.splitlines()]
assert all(len(r) == 5 for r in table), [r[0] for r in table if len(r) != 5]
assert len({r[0] for r in table}) == len(table), 'duplicate key'

# Help text lives in help_text.py (markup rendered by Shared/AppStandards/HelpDocument.swift).
from help_text import HELP
helptexts = [HELP[l] for l in ['ja', 'en', 'zh-Hans', 'ko']]

for i, lang in enumerate(['ja', 'en', 'zh-Hans', 'ko']):
    p = root / 'Resources' / f'{lang}.lproj'
    p.mkdir(parents=True, exist_ok=True)
    (p / 'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0])} = {json.dumps(r[i + 1], ensure_ascii=False)};' for r in table) + '\n')
    (p / 'InfoPlist.strings').write_text('"CFBundleDisplayName" = "MenuShot";\n')
    (p / 'Help.txt').write_text(helptexts[i])
print('resources:', len(table), 'keys x 4 languages')
