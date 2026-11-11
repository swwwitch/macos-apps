# -*- coding: utf-8 -*-
from pathlib import Path
import json
root = Path(__file__).parent
APP = 'MenuDiff'
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''
source.title|%1$@（%2$@）|%1$@ (%2$@)|%1$@（%2$@）|%1$@ (%2$@)
category.added|追加|Added|新增|추가
category.removed|削除|Removed|删除|삭제
category.renamed|名前の変更|Renamed|已重命名|이름 변경
category.moved|場所の変更|Moved|已移动|위치 변경
category.shortcuts|ショートカット|Shortcuts|快捷键|단축키
state.running|起動中|Running|运行中|실행 중
state.saved|保存済み %@|Saved %@|已存储 %@|저장됨 %@
state.notRead|未取得（比較時に起動）|Not read yet (launched when comparing)|尚未读取（比较时启动）|아직 읽지 않음(비교할 때 실행)
state.noApp|アプリなし|App not installed|未安装应用|앱 없음
state.separator|・|, |，|, 
compared.title|%1$@（%2$d項目）→ %3$@（%4$d項目）|%1$@ (%2$d items) → %3$@ (%4$d items)|%1$@（%2$d 项）→ %3$@（%4$d 项）|%1$@(%2$d개) → %3$@(%4$d개)
warning.localeMismatch|言語が異なります（%1$@ / %2$@）。ほとんどの項目が追加・削除として出ます。|The languages differ (%1$@ / %2$@). Most items will appear as added or removed.|语言不同（%1$@ / %2$@）。大多数项目会显示为新增或删除。|언어가 다릅니다(%1$@ / %2$@). 대부분의 항목이 추가·삭제로 표시됩니다.
status.reread|%1$@ を読み直しました（%2$d項目）。|Reread %1$@ (%2$d items).|已重新读取 %1$@（%2$d 项）。|%1$@을(를) 다시 읽었습니다(%2$d개).
status.copied|%d件をコピーしました。|Copied %d rows.|已拷贝 %d 项。|%d개를 복사했습니다.
error.notTrusted|アクセシビリティが許可されていません。設定の［アクセシビリティ］から許可してください。|Accessibility access is not allowed. Allow it under Accessibility in Settings.|未允许辅助功能。请在设置的“辅助功能”中允许。|손쉬운 사용이 허용되지 않았습니다. 설정의 손쉬운 사용에서 허용하세요.
error.noMenuBar|メニューバーを読めませんでした。|Could not read the menu bar.|无法读取菜单栏。|메뉴 막대를 읽을 수 없습니다.
error.launchFailed|起動できませんでした : %@|Could not launch: %@|无法启动：%@|실행할 수 없습니다: %@
error.timedOut|起動を待ちましたが、メニューがそろいませんでした。手で起動してから［読み直す］を押してください。|Waited for the app to launch, but its menus were not ready. Launch it yourself, then click Reread.|已等待启动，但菜单尚未就绪。请手动启动后点按“重新读取”。|실행을 기다렸지만 메뉴가 준비되지 않았습니다. 직접 실행한 다음 다시 읽기를 클릭하세요.
error.nothingToRead|%@ はアプリも保存済みのデータもありません。|%@ has neither an installed app nor saved data.|%@ 既没有已安装的应用，也没有已存储的数据。|%@에는 설치된 앱도 저장된 데이터도 없습니다.
progress.reading|%@ のメニューを読んでいます…|Reading the menus of %@…|正在读取 %@ 的菜单…|%@의 메뉴를 읽는 중…
progress.launching|%@ を起動しています…|Launching %@…|正在启动 %@…|%@ 실행 중…
progress.waiting|%@ のメニューがそろうのを待っています…|Waiting for the menus of %@…|正在等待 %@ 的菜单…|%@의 메뉴를 기다리는 중…
progress.quitting|%@ を終了しています…|Quitting %@…|正在退出 %@…|%@ 종료 중…
progress.leftRunning|%@ は使用中のため終了しませんでした。|%@ is in use, so it was left running.|%@ 正在使用，因此未退出。|%@이(가) 사용 중이므로 종료하지 않았습니다.
heading|メニューをバージョン間で比較|Compare Menus Between Versions|比较不同版本的菜单|버전 간 메뉴 비교
subtitle|Illustrator・InDesign・Photoshop の2つのバージョンのメニュー項目を読み、追加・削除・名前や場所の変更・ショートカットの変化を一覧にします。|Reads the menus of two versions of Illustrator, InDesign or Photoshop and lists added, removed, renamed and moved items and changed shortcuts.|读取 Illustrator、InDesign 或 Photoshop 两个版本的菜单，列出新增、删除、重命名、移动的项目以及快捷键的变化。|Illustrator, InDesign, Photoshop의 두 버전 메뉴를 읽고 추가·삭제·이름 변경·위치 변경된 항목과 단축키 변화를 나열합니다.
notice.accessibility|メニューを読むには、アクセシビリティの許可が必要です（未許可）。|Accessibility access is required to read menus (not allowed).|读取菜单需要辅助功能权限（未允许）。|메뉴를 읽으려면 손쉬운 사용 권한이 필요합니다(허용 안 됨).
button.openAccessibility|アクセシビリティを開く|Open Accessibility|打开辅助功能|손쉬운 사용 열기
field.app|対象アプリ|Target App|目标应用|대상 앱
field.new|新|New|新|새 버전
field.old|旧|Old|旧|이전 버전
tip.swap|新と旧を入れ替えます|Swap new and old|交换新旧|새 버전과 이전 버전 바꾸기
button.reread|読み直す|Reread|重新读取|다시 읽기
tip.reread|起動していなければ起動して読み、読み終えたら終了します。|Launches the app if needed, reads its menus, then quits it.|如未运行则启动并读取，读取后退出。|실행 중이 아니면 실행해서 읽고, 다 읽으면 종료합니다.
note.noInstall|%@ が見つかりません。|%@ was not found.|未找到 %@。|%@을(를) 찾을 수 없습니다.
button.openFolder|保存先を開く|Open Save Folder|打开存储位置|저장 위치 열기
tip.openFolder|読んだメニューを保存しているフォルダーを開きます。|Opens the folder where read menus are saved.|打开存储已读取菜单的文件夹。|읽은 메뉴를 저장하는 폴더를 엽니다.
button.compare|比較|Compare|比较|비교
tip.app|%@ のバージョンを比べます|Compare versions of %@|比较 %@ 的版本|%@의 버전 비교
search.placeholder|絞り込み|Filter|筛选|필터
button.copy|コピー|Copy|拷贝|복사
tip.copy|表示中の一覧をタブ区切りでコピーします。|Copies the list on screen as tab-separated text.|以制表符分隔拷贝显示的列表。|표시 중인 목록을 탭으로 구분해 복사합니다.
a11y.category|種類|Kind|类型|종류
menu.copyPath|パスをコピー|Copy Path|拷贝路径|경로 복사
menu.copyOldPath|旧のパスをコピー|Copy Old Path|拷贝旧路径|이전 경로 복사
empty.rows|なし|None|无|없음
note.renamed|子の項目が移った先のサブメニューと、同じメニューの中で削除と追加が1つずつあったものを組にしています。|Pairs a submenu with the one its items moved to, and one removed with one added item in the same menu.|将子项目移入的子菜单，以及同一菜单中各有一个删除和新增的项目配成一组。|하위 항목이 옮겨 간 하위 메뉴와, 같은 메뉴에서 삭제와 추가가 하나씩 있는 항목을 짝지었습니다.
note.moved|同じ名前の項目が、削除側・追加側に1つずつあったものを組にしています。|Pairs items with the same name that appear once on each side.|将名称相同、删除和新增各出现一次的项目配成一组。|이름이 같은 항목이 삭제 쪽과 추가 쪽에 하나씩 있는 것을 짝지었습니다.
note.impliedMoves|親メニューの名前・場所が変わっただけのもの（%d件）は省いています。| Items that moved only because their parent menu changed (%d) are hidden.|仅因父菜单变化而移动的项目（%d 项）已省略。| 상위 메뉴가 바뀌어서만 이동한 항목(%d개)은 생략했습니다.
note.shortcuts|読んだときに選ばれていたキーボードショートカットのセットの値です。|Shortcuts come from the shortcut set selected when the menus were read.|快捷键来自读取时所选的快捷键集。|단축키는 메뉴를 읽을 때 선택되어 있던 단축키 세트의 값입니다.
menu.compare|比較|Compare|比较|비교
menu.copyRows|一覧をコピー|Copy List|拷贝列表|목록 복사
menu.openFolder|保存先を開く|Open Save Folder|打开存储位置|저장 위치 열기
settings.saveTab|保存|Saving|存储|저장
settings.folder|保存先|Save Folder|存储位置|저장 위치
button.chooseFolder|選ぶ…|Choose…|选取…|선택…
button.defaultFolder|既定に戻す|Use Default|使用默认|기본값 사용
button.choose|選ぶ|Choose|选取|선택
settings.folderDetail|読んだメニューを「Ai31.0.0 ja_JP.tsv」（InDesign は Id、Photoshop は Ps）のような名前で保存します。保存済みのバージョンは、アプリを起動しなくても比較できます。|Read menus are saved with names such as “Ai31.0.0 ja_JP.tsv” (Id for InDesign, Ps for Photoshop). Saved versions can be compared without launching the app.|已读取的菜单以“Ai31.0.0 ja_JP.tsv”（InDesign 为 Id，Photoshop 为 Ps）之类的名称存储。已存储的版本无需启动应用即可比较。|읽은 메뉴는 “Ai31.0.0 ja_JP.tsv”(InDesign은 Id, Photoshop은 Ps) 같은 이름으로 저장됩니다. 저장된 버전은 앱을 실행하지 않고도 비교할 수 있습니다.
aboutDetail|Illustrator・InDesign・Photoshop のメニューをバージョン間で比較します。サポート：同梱のREADME.md|Compares the menus of Illustrator, InDesign and Photoshop between versions. Support: bundled README.md|在不同版本之间比较 Illustrator、InDesign 和 Photoshop 的菜单。支持：内置的 README.md|Illustrator, InDesign, Photoshop의 메뉴를 버전 간에 비교합니다. 지원: 내장된 README.md
openMainWindow|メインウインドウを開く|Open Main Window|打开主窗口|메인 윈도우 열기
settings|設定…|Settings…|设置…|설정…
settingsWindow|設定|Settings|设置|설정
help|{APP}ヘルプ|{APP} Help|{APP} 帮助|{APP} 도움말
helpMenu|ヘルプ|Help|帮助|도움말
quit|{APP}を終了|Quit {APP}|退出 {APP}|{APP} 종료
hide|{APP}を隠す|Hide {APP}|隐藏 {APP}|{APP} 가리기
hideOthers|ほかを隠す|Hide Others|隐藏其他|기타 가리기
showAll|すべてを表示|Show All|全部显示|모두 보기
services|サービス|Services|服务|서비스
fileMenu|ファイル|File|文件|파일
close|ウインドウを閉じる|Close Window|关闭窗口|윈도우 닫기
editMenu|編集|Edit|编辑|편집
undo|取り消す|Undo|撤销|실행 취소
redo|やり直す|Redo|重做|실행 복귀
cut|カット|Cut|剪切|오려두기
copy|コピー|Copy|拷贝|복사하기
paste|ペースト|Paste|粘贴|붙여넣기
selectAll|すべてを選択|Select All|全选|모두 선택
windowMenu|ウインドウ|Window|窗口|윈도우
minimize|しまう|Minimize|最小化|최소화
zoom|拡大／縮小|Zoom|缩放|확대/축소
bringAllToFront|すべてを手前に移動|Bring All to Front|前置全部窗口|모두 앞으로 가져오기
about|{APP}について|About {APP}|关于 {APP}|{APP}에 관하여
resident|ウインドウを閉じても常駐|Keep running after closing the window|关闭窗口后继续运行|윈도우를 닫아도 계속 실행
residentDetail|オンにすると、閉じた後もDockやメニューバーから再表示できます。オフ（初期値）では閉じると終了します。|When on, reopen from the Dock or menu bar. When off (the default), closing the window quits.|开启后可从 Dock 或菜单栏再次打开。关闭（默认）时，关闭窗口即退出。|켜면 Dock 또는 메뉴 막대에서 다시 열 수 있습니다. 끄면(기본값) 창을 닫을 때 종료됩니다.
launchShortcut|アプリ起動のホットキー|App launch keyboard shortcut|启动应用快捷键|앱 실행 키보드 단축키
openShortcuts|ショートカットを開く|Open Shortcuts|打开快捷指令|단축어 열기
shortcutDetail|ショートカットAppで「アプリを開く」に{APP}を指定し、キーを割り当ててください。未起動時も使えます。|In Shortcuts, create an Open App action for {APP} and assign a key. It works even when the app is not running.|在快捷指令中为 {APP} 创建“打开 App”并分配按键，应用未运行时也可使用。|단축어 앱에서 {APP}을 여는 동작을 만들고 키를 지정하세요. 앱이 실행 중이 아니어도 작동합니다.
appHotkeyHint|{APP}の起動中に押すと、どのアプリからでもメインウインドウを表示します。未起動のときは上の「ショートカットを開く」で割り当てたキーを使ってください。|While {APP} is running, press it in any app to show the main window. When it is not running, use the key assigned with Open Shortcuts above.|{APP} 运行时，在任何应用中按下即可显示主窗口。未运行时请使用上方“打开快捷指令”中分配的按键。|{APP}이 실행 중일 때 어느 앱에서든 누르면 메인 윈도우를 표시합니다. 실행 중이 아닐 때는 위의 '단축어 열기'에서 지정한 키를 사용하세요.
'''
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
    (p / 'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0], ensure_ascii=False)} = {json.dumps(r[i + 1], ensure_ascii=False)};' for r in table) + '\n')
    (p / 'InfoPlist.strings').write_text(f'"CFBundleDisplayName" = "{APP}";\n')
    (p / 'Help.txt').write_text(HELP[lang])
print('resources written')
