from pathlib import Path
import json
root = Path(__file__).parent
APP = 'ShotSorter'
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''shot.folders|ウォッチフォルダー|Watch Folders|监视文件夹|감시 폴더
addFolder|フォルダーを追加…|Add Folder…|添加文件夹…|폴더 추가…
removeFolder|削除|Remove|移除|제거
drop.hint|PNGファイルをこのウインドウへドロップすると命名ルールを適用します。|Drop PNG files into this window to apply the naming rule.|将 PNG 文件拖到此窗口以应用命名规则。|이 창에 PNG 파일을 놓으면 이름 규칙을 적용합니다.
shot.ocrClipboard|読み取った文字をクリップボードにもコピーする|Also copy recognized text to the clipboard|同时将识别文字拷贝到剪贴板|인식한 텍스트를 클립보드에도 복사
ocr.settings|Vision後の整形ルール|Formatting After Vision|Vision 识别后的格式规则|Vision 인식 후 서식 규칙
ocr.keepLines|読み取った文字の改行は保持します。コメントとコピーに同じ整形を適用します。|Line breaks are preserved. The same formatting applies to comments and copied text.|保留识别文字的换行。注释与复制文本使用相同格式。|줄바꿈을 유지합니다. 메모와 복사한 텍스트에 같은 서식을 적용합니다.
heading|スクリーンショットの整理と文字認識|Screenshots and Text Recognition|截图整理与文字识别|스크린샷 정리와 문자 인식
subtitle|新しいスクリーンショットの名前を変え、選んだ範囲の文字を読み取ります。|Renames new screenshots and reads text in a selected area.|重命名新截图，并识别所选区域的文字。|새 스크린샷 이름을 바꾸고 선택한 영역의 텍스트를 읽습니다.
pane.screenshots|スクリーンショット|Screenshots|截图|스크린샷
pane.ocr|文字認識|Text Recognition|文字识别|문자 인식
activity|最近の処理|Recent Activity|最近的处理|최근 처리
activityEmpty|まだありません。履歴は保存せず、終了すると消えます。|None yet. Not saved; cleared when the app quits.|暂无。不会保存，退出应用时清除。|아직 없습니다. 저장하지 않으며 앱을 종료하면 지워집니다.
change|変更…|Change…|更改…|변경…
choose|選択|Choose|选择|선택
openFolder|Finderで開く|Open in Finder|在访达中打开|Finder에서 열기
resetDefault|初期値に戻す|Restore Default|恢复默认|초기값으로
shot.enabled|新しいスクリーンショットの名前を変える|Rename new screenshots|重命名新截图|새 스크린샷 이름 바꾸기
shot.folder|フォルダー：|Folder:|文件夹：|폴더:
shot.locationDiffers|macOSのスクリーンショットの保存先は %@ です。|macOS saves screenshots to %@.|macOS 将截图存储在 %@。|macOS는 스크린샷을 %@에 저장합니다.
shot.template|名前の形式：|Name format:|名称格式：|이름 형식:
shot.templateHint|{width}・{height}・{dpi}・{date} を使えます。例：|Use {width}, {height}, {dpi} and {date}. Example:|可使用 {width}、{height}、{dpi}、{date}。示例：|{width}, {height}, {dpi}, {date}를 쓸 수 있습니다. 예:
shot.ocrComment|画像の文字を読み取り、Finderのコメントに入れる|Read the text in the image into the Finder comment|识别图像中的文字并写入访达注释|이미지의 텍스트를 읽어 Finder 메모에 넣기
shot.detail|指定フォルダーに加わったPNGのうち、名前に「ss-」を含まないものが対象です。起動前からあったファイルは変えません。同じ名前があるときは末尾に番号を付けます。|Applies to PNG files added to the watched folders whose name does not contain “ss-”. Files present before launch are not changed. A number is added when the name is taken.|适用于添加到监视文件夹且名称不含“ss-”的 PNG。启动前已有的文件不会更改。名称重复时会添加编号。|감시 폴더에 추가된 PNG 중 이름에 “ss-”가 없는 파일이 대상입니다. 실행 전부터 있던 파일은 바꾸지 않습니다. 같은 이름이 있으면 번호를 붙입니다.
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
ocr.needsPermissionDetail|システム設定の「画面収録とシステムオーディオ録音」でShotSorterをオンにしてください。|Turn on ShotSorter in Screen & System Audio Recording in System Settings.|请在系统设置的“录屏与系统录音”中开启 ShotSorter。|시스템 설정의 화면 및 시스템 오디오 녹음에서 ShotSorter를 켜세요.
ocr.allow|システム設定を開く|Open System Settings|打开系统设置|시스템 설정 열기
log.cannotWatch|フォルダーを監視できません：%@|Cannot watch the folder: %@|无法监视文件夹：%@|폴더를 감시할 수 없습니다: %@
log.notImage|「%@」を画像として読めませんでした。|Could not read “%@” as an image.|无法将“%@”读取为图像。|“%@”을(를) 이미지로 읽지 못했습니다.
log.renameFailed|「%@」の名前を変えられませんでした：%@|Could not rename “%@”: %@|无法重命名“%@”：%@|“%@”의 이름을 바꾸지 못했습니다: %@
log.renamed|%@ に名前を変えました|Renamed to %@|已重命名为 %@|%@(으)로 이름을 바꿨습니다
log.commentSpotlight|（コメントはSpotlight用にだけ保存。Finderの操作の許可がありません）| (comment saved for Spotlight only; no permission to control Finder)|（注释仅保存供聚焦使用；没有控制访达的权限）| (메모는 Spotlight용으로만 저장. Finder 제어 권한 없음)
log.commentFailed|（コメントを入れられませんでした）| (could not set the comment)|（无法写入注释）| (메모를 넣지 못했습니다)
log.ocr|%d文字を読み取ってコピーしました|Recognized and copied %d characters|已识别并拷贝 %d 个字符|%d자를 인식해 복사했습니다
perm.screen|画面収録|Screen Recording|录屏|화면 기록
perm.allowed|許可済み|Allowed|已允许|허용됨
perm.notAllowed|未許可|Not allowed|未允许|허용되지 않음
perm.screenDetail|「範囲を選んで文字認識」で、選んだ範囲を撮影するために使います。スクリーンショットの名前の変更には不要です。|Used to capture the selected area for Recognize Text in Area. Not needed for renaming screenshots.|用于“选择区域识别文字”时截取所选区域。重命名截图不需要。|“영역을 선택해 문자 인식”에서 선택한 영역을 촬영하는 데 사용합니다. 스크린샷 이름 바꾸기에는 필요 없습니다.
perm.request|許可を求める|Request Permission|请求权限|권한 요청
perm.openSettings|画面収録の設定を開く|Open Screen Recording Settings|打开录屏设置|화면 기록 설정 열기
perm.finderDetail|Finderのコメントは、Finderを操作して入れます。最初に入れるときにmacOSが許可を確認します。許可しないときはSpotlight用にだけ保存します（Finderの「情報を見る」には表示されません）。|Finder comments are set by controlling Finder; macOS asks once. Without permission the comment is saved for Spotlight only (not shown in Finder’s Get Info).|访达注释通过控制访达写入，macOS 会在首次时询问。未允许时仅保存供聚焦使用（不会显示在访达的“显示简介”中）。|Finder 메모는 Finder를 제어해 넣으며 처음에 macOS가 확인합니다. 허용하지 않으면 Spotlight용으로만 저장합니다(Finder 정보 가져오기에는 표시되지 않음).
hotkeyTab|ホットキー|Hotkeys|快捷键|단축키
hotkey.ocr|範囲を選んで文字認識|Recognize Text in Area|选择区域识别文字|영역을 선택해 문자 인식
hotkey.ocrDetail|どのアプリからでも、範囲を選んで文字を読み取ります（ShotSorterの起動中）。|Selects an area and reads its text from any app (while ShotSorter is running).|在任何应用中选择区域并识别文字（ShotSorter 运行时）。|어느 앱에서든 영역을 선택해 텍스트를 읽습니다(ShotSorter 실행 중).
notifyToggle|名前の変更・文字認識の結果を通知|Notify about renames and recognized text|通知重命名和文字识别的结果|이름 변경·문자 인식 결과 알림
aboutDetail|スクリーンショットの名前を変え、画面の文字を読み取ります。サポート：同梱のREADME.md|Renames screenshots and reads text on screen. Support: bundled README.md|重命名截图并识别屏幕文字。支持：内置 README.md|스크린샷 이름을 바꾸고 화면의 텍스트를 읽습니다. 지원: 포함된 README.md
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
generalTab|一般|General|通用|일반'''
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
    events = ['スクリーンショットの文字をFinderのコメントに入れるために、Finderを操作します。',
              'ShotSorter controls Finder to put the text of screenshots into their Finder comments.',
              'ShotSorter 会控制访达，将截图中的文字写入访达注释。',
              'ShotSorter는 스크린샷의 텍스트를 Finder 메모에 넣기 위해 Finder를 제어합니다.'][i]
    (p / 'InfoPlist.strings').write_text(f'"CFBundleDisplayName" = "{APP}";\n"NSAppleEventsUsageDescription" = {json.dumps(events, ensure_ascii=False)};\n')
    (p / 'Help.txt').write_text(HELP[lang])
print('resources:', len(table), 'keys x 4 languages')
