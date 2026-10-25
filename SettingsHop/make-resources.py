from pathlib import Path
import json
root = Path(__file__).parent
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
# Pane names follow System Settings in each language.
rows = '''heading|システム設定を開く|Open System Settings|打开系统设置|시스템 설정 열기
subtitle|よく使う設定の画面へ直接移動します。|Jump straight to frequently used settings.|直接前往常用的设置。|자주 사용하는 설정으로 바로 이동합니다.
pane.systemSettings|システム設定|System Settings|系统设置|시스템 설정
pane.privacy|プライバシーとセキュリティ|Privacy & Security|隐私与安全性|개인정보 보호 및 보안
pane.accessibility|アクセシビリティ|Accessibility|辅助功能|손쉬운 사용
pane.fullDiskAccess|フルディスクアクセス|Full Disk Access|完全磁盘访问权限|전체 디스크 접근 권한
pane.filesAndFolders|ファイルとフォルダ|Files and Folders|文件与文件夹|파일 및 폴더
pane.screenRecording|画面収録とシステムオーディオ録音|Screen & System Audio Recording|录屏与系统录音|화면 및 시스템 오디오 녹음
pane.inputMonitoring|入力監視|Input Monitoring|输入监控|입력 모니터링
pane.automation|オートメーション|Automation|自动化|자동화
pane.airDrop|AirDropおよび連係|AirDrop & Handoff|隔空投送与接力|AirDrop 및 Handoff
pane.loginItems|ログイン項目|Login Items|登录项|로그인 항목
pane.defaultBrowser|デフォルトのWebブラウザ|Default Web Browser|默认网页浏览器|기본 웹 브라우저
pane.keyboardShortcuts|キーボードショートカット|Keyboard Shortcuts|键盘快捷键|키보드 단축키
openedNoScroll|「%@」を開きました。アクセシビリティを許可すると、その行までスクロールします（設定の［起動・常駐］）。|Opened “%@”. Allow Accessibility to scroll to that row (Settings › Launch & Residency).|已打开“%@”。允许辅助功能后会滚动到该行（设置 › 启动与常驻）。|“%@”을(를) 열었습니다. 손쉬운 사용을 허용하면 해당 행까지 스크롤합니다(설정 › 실행·상주).
rowNotFound|「%@」を開きましたが、その行を見つけられませんでした。画面を下へスクロールしてください。|Opened “%@”, but the row was not found. Scroll down the pane.|已打开“%@”，但未找到该行。请向下滚动面板。|“%@”을(를) 열었지만 해당 행을 찾지 못했습니다. 화면을 아래로 스크롤하세요.
selectNeedsAccess|「%@」の行を選ぶにはアクセシビリティの許可が必要です（設定の［起動・常駐］）。画面だけ開きました。|Selecting the “%@” row needs Accessibility permission (Settings › Launch & Residency). Only the pane was opened.|选择“%@”所在行需要辅助功能权限（设置 › 启动与常驻）。仅打开了面板。|“%@” 행을 선택하려면 손쉬운 사용 권한이 필요합니다(설정 › 실행·상주). 화면만 열었습니다.
previousApp|直前のアプリ：|Last app:|上一个应用：|직전 앱:
previousAppHint|Option＋クリックすると、一覧でこのアプリの行を選んで開きます|Option-click a list to open it with this app's row selected|按住 Option 点按列表，会选中此应用所在行并打开|목록을 Option-클릭하면 이 앱의 행을 선택해 엽니다
selectLastApp|%@（直前のアプリを選択）|%@ (Select Last App)|%@（选择上一个应用）|%@(직전 앱 선택)
openHint|システム設定でこの画面を開きます|Opens this pane in System Settings|在系统设置中打开此面板|시스템 설정에서 이 화면을 엽니다
opened|「%@」を開きました。|Opened “%@”.|已打开“%@”。|“%@”을(를) 열었습니다.
failed|「%@」を開けませんでした。システム設定が起動できるか確認してください。|Could not open “%@”. Check that System Settings can open.|无法打开“%@”。请确认系统设置能否打开。|“%@”을(를) 열 수 없습니다. 시스템 설정을 열 수 있는지 확인하세요.
generalTab|一般|General|通用|일반
afterOpen|開いたあと|After Opening|打开后|연 후
closeAfterOpen|項目を開いたらウインドウを閉じる|Close the window after opening an item|打开项目后关闭窗口|항목을 연 후 윈도우 닫기
closeAfterOpenDetail|メインウインドウのボタンやホットキー（⌘1〜⌘9）で開いたときに閉じます。メニューバーから開いたときは関係ありません。|Applies to the main window's buttons and ⌘1–⌘9. Opening from the menu bar is not affected.|适用于主窗口的按钮和 ⌘1–⌘9。从菜单栏打开时不受影响。|메인 윈도우의 버튼과 ⌘1–⌘9에 적용됩니다. 메뉴 막대에서 열 때는 영향이 없습니다.
resident|ウインドウを閉じても常駐|Keep running after closing the window|关闭窗口后继续运行|윈도우를 닫아도 계속 실행
residentDetail|閉じた後もDockやメニューバーから再表示できます。オフにすると閉じたときに終了します。|Reopen from the Dock or menu bar. When off, closing the window quits.|可从 Dock 或菜单栏再次打开。关闭此项时，关闭窗口即退出。|Dock 또는 메뉴 막대에서 다시 열 수 있습니다. 끄면 창을 닫을 때 종료됩니다.
launchShortcut|アプリ起動のホットキー|App launch keyboard shortcut|启动应用快捷键|앱 실행 키보드 단축키
openShortcuts|ショートカットを開く|Open Shortcuts|打开快捷指令|단축어 열기
shortcutDetail|ショートカットAppで「アプリを開く」にSettingsHopを指定し、キーを割り当ててください。未起動時も使えます。|In Shortcuts, create an Open App action for SettingsHop and assign a key. It works even when the app is not running.|在快捷指令中为 SettingsHop 创建“打开 App”并分配按键，应用未运行时也可使用。|단축어 앱에서 SettingsHop을 여는 동작을 만들고 키를 지정하세요. 앱이 실행 중이 아니어도 작동합니다.
appHotkeyHint|SettingsHopの起動中に押すと、どのアプリからでもシステム設定を開きます。すばやく2回押すとメインウインドウを表示します。未起動のときは上の「ショートカットを開く」で割り当てたキーを使ってください。|While SettingsHop is running, press it in any app to open System Settings; press it twice quickly to show the main window. When it is not running, use the key assigned with Open Shortcuts above.|SettingsHop 运行时，在任何应用中按下即可打开系统设置；快速按两次则显示主窗口。未运行时请使用上方“打开快捷指令”中分配的按键。|SettingsHop이 실행 중일 때 어느 앱에서든 누르면 시스템 설정을 엽니다. 빠르게 두 번 누르면 메인 윈도우를 표시합니다. 실행 중이 아닐 때는 위의 '단축어 열기'에서 지정한 키를 사용하세요.
openMainWindow|メインウインドウを開く|Open Main Window|打开主窗口|메인 윈도우 열기
settings|設定…|Settings…|设置…|설정…
settingsWindow|設定|Settings|设置|설정
help|SettingsHopヘルプ|SettingsHop Help|SettingsHop 帮助|SettingsHop 도움말
helpMenu|ヘルプ|Help|帮助|도움말
quit|SettingsHopを終了|Quit SettingsHop|退出 SettingsHop|SettingsHop 종료
hide|SettingsHopを隠す|Hide SettingsHop|隐藏 SettingsHop|SettingsHop 가리기
services|サービス|Services|服务|서비스
hideOthers|ほかを隠す|Hide Others|隐藏其他|기타 가리기
showAll|すべてを表示|Show All|全部显示|모두 보기
about|SettingsHopについて|About SettingsHop|关于 SettingsHop|SettingsHop에 관하여
aboutDetail|システム設定のよく使う画面を直接開きます。サポート：同梱のREADME.md|Opens frequently used System Settings panes directly. Support: bundled README.md|直接打开系统设置中常用的面板。支持：内置 README.md|시스템 설정에서 자주 쓰는 화면을 바로 엽니다. 지원: 포함된 README.md
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
    (p / 'InfoPlist.strings').write_text('"CFBundleDisplayName" = "SettingsHop";\n')
    (p / 'Help.txt').write_text(helptexts[i])
print('resources:', len(table), 'keys x 4 languages')
