# -*- coding: utf-8 -*-
from pathlib import Path
import json
root = Path(__file__).parent
APP = 'VectorKeyMap'
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''
view.table|表|Table|表格|표
view.keyboard|キーボード|Keyboard|键盘|키보드
a11y.view|表示の切り替え|View|视图|보기
a11y.modifiers|修飾キー|Modifier keys|修饰键|보조 키
a11y.keyboardSide|表示するセット|Set to show|显示的集|표시할 세트
a11y.keyboardKind|キーボードの種類|Keyboard type|键盘类型|키보드 종류
tip.keyboardSide|キーボードに表示するセットを選びます。|Chooses the set shown on the keyboard.|选择键盘上显示的集。|키보드에 표시할 세트를 선택합니다.
field.freeCount|空きの数 :|Free:|空闲：|빈 키:
modifier.none|なし|None|无|없음
keyboard.jis|JIS|JIS|JIS|JIS
keyboard.ansi|US|US|US|US
key.free|空き|Free|空闲|비어 있음
key.used|使用中|In use|使用中|사용 중
key.textOnly|文字編集中のみ使用|Text editing only|仅文字编辑时使用|문자 편집 중에만 사용
key.system|macOSが使用|Used by macOS|macOS 使用|macOS 사용
key.unavailable|対象外|Not assignable|不可分配|지정 불가
key.hint|キーを押すと、すべての修飾キーの組み合わせを確かめられます。|Click a key to see every modifier combination.|点按按键可查看所有修饰键组合。|키를 누르면 모든 보조 키 조합을 확인할 수 있습니다.
key.unplaced|このキーボードにないキー : %@|Keys not on this keyboard: %@|此键盘上没有的按键：%@|이 키보드에 없는 키: %@
key.summary|空き %1$d／%2$dキー|%1$d of %2$d keys free|%2$d 个按键中 %1$d 个空闲|%2$d개 키 중 %1$d개 비어 있음
button.copyFree|空きキーをコピー|Copy Free Keys|拷贝空闲按键|빈 키 복사
tip.copyFree|選んでいる修飾キーの空きキーをコピーします。|Copies the free keys of the chosen modifiers.|拷贝所选修饰键的空闲按键。|선택한 보조 키의 빈 키를 복사합니다.
heading|キーボードショートカットを比較|Compare Keyboard Shortcuts|比较键盘快捷键|키보드 단축키 비교
subtitle|Illustratorのキーボードショートカットの差分と空きキーを確かめます。|Shows how Illustrator shortcut sets differ, and which keys are free.|查看 Illustrator 快捷键集的差异和空闲按键。|Illustrator 단축키 세트의 차이와 빈 키를 확인합니다.
aboutDetail|Illustratorのキーボードショートカットを一覧にして比較します。サポート：同梱のREADME.md|Lists and compares Illustrator keyboard shortcuts. Support: bundled README.md|列出并比较 Illustrator 键盘快捷键。支持：内置的 README.md|Illustrator 키보드 단축키를 나열하고 비교합니다. 지원: 내장된 README.md
field.baseline|基準 :|Baseline:|基准：|기준:
field.target|比較先 :|Compare with:|比较对象：|비교 대상:
tip.swap|基準と比較先を入れ替える|Swap the baseline and the compared set|交换基准和比较对象|기준과 비교 대상 바꾸기
button.addSet|セットを追加…|Add Set…|添加集…|세트 추가…
tip.addSet|.kysファイルを選んで一覧に足します。ウインドウへのドラッグでも追加できます。|Choose a .kys file to add to the list. You can also drag one onto the window.|选择 .kys 文件添加到列表。也可以拖到窗口上。|.kys 파일을 선택해 목록에 추가합니다. 윈도우로 드래그해도 됩니다.
button.add|追加|Add|添加|추가
source.bundled|Illustrator 初期設定（同梱）|Illustrator Defaults (bundled)|Illustrator 默认设置（内置）|Illustrator 기본 설정(내장)
source.detected|%1$@（Illustrator %2$@）|%1$@ (Illustrator %2$@)|%1$@（Illustrator %2$@）|%1$@(Illustrator %2$@)
source.active|%1$@（Illustrator %2$@・使用中）|%1$@ (Illustrator %2$@, in use)|%1$@（Illustrator %2$@，使用中）|%1$@(Illustrator %2$@, 사용 중)
source.added|%@（追加したファイル）|%@ (added file)|%@（已添加的文件）|%@(추가한 파일)
filter.diff|差分|Differences|差异|차이
filter.changed|変更|Changed|已更改|변경
filter.added|追加|Added|已添加|추가
filter.removed|解除|Removed|已移除|해제
filter.same|同じ|Same|相同|동일
filter.conflict|重複|Conflicts|冲突|중복
filter.assigned|キーあり|With Keys|有按键|키 있음
filter.all|すべて|All|全部|전체
a11y.filter|絞り込み|Filter|筛选|필터
a11y.noKey|キーなし|No key|无按键|키 없음
a11y.conflict|同じキーのコマンドがあります|Another command has the same key|其他命令使用相同按键|같은 키를 쓰는 명령이 있습니다
group.all|すべての分類|All Categories|所有类别|모든 분류
group.ツール|ツール|Tools|工具|도구
group.Illustrator|Illustrator|Illustrator|Illustrator|Illustrator
group.ファイル|ファイル|File|文件|파일
group.編集|編集|Edit|编辑|편집
group.オブジェクト|オブジェクト|Object|对象|오브젝트
group.書式|書式|Type|文字|문자
group.選択|選択|Select|选择|선택
group.効果|効果|Effect|效果|효과
group.表示|表示|View|视图|보기
group.ウィンドウ|ウィンドウ|Window|窗口|윈도우
group.ヘルプ|ヘルプ|Help|帮助|도움말
group.その他の選択|その他の選択|Other Select|其他选择|기타 선택
group.その他のテキスト|その他のテキスト|Other Text|其他文字|기타 문자
group.その他のオブジェクト|その他のオブジェクト|Other Object|其他对象|기타 오브젝트
group.その他のパネル|その他のパネル|Other Panels|其他面板|기타 패널
group.その他|その他|Other|其他|기타
group.未分類|未分類|Uncategorized|未分类|미분류
search.placeholder|名前・ID・キーで検索|Search name, ID or key|搜索名称、ID 或按键|이름, ID, 키로 검색
tip.search|「⌘E」「cmd+e」のようにキーでも探せます。|You can also search keys, such as ⌘E or cmd+e.|也可以搜索按键，例如 ⌘E 或 cmd+e。|⌘E, cmd+e처럼 키로도 찾을 수 있습니다.
column.status|状態|Status|状态|상태
column.group|分類|Category|类别|분류
column.command|コマンド|Command|命令|명령
column.baseline|基準|Baseline|基准|기준
column.target|比較先|Compared|比较对象|비교 대상
column.id|ID|ID|ID|ID
column.conflict|同じキー|Same Key|相同按键|같은 키
status.changed|変更|Changed|已更改|변경
status.added|追加|Added|已添加|추가
status.removed|解除|Removed|已移除|해제
status.unlisted|記載なし|Not listed|未列出|목록에 없음
status.same|同じ|Same|相同|동일
status.unassigned|なし|None|无|없음
context.mark|文字編集中|In text|文字编辑中|문자 편집 중
tip.context|文字を編集している間だけ効くキーです。|This key works only while editing text.|此按键仅在编辑文字时有效。|문자를 편집하는 동안에만 작동하는 키입니다.
empty.rows|該当する項目はありません|Nothing to show|没有符合条件的项目|해당 항목이 없습니다
summary|割り当て：基準 %1$d件・比較先 %2$d件／表示 %3$d件|Assigned: baseline %1$d, compared %2$d / showing %3$d|已分配：基准 %1$d 项，比较对象 %2$d 项／显示 %3$d 项|할당: 기준 %1$d개, 비교 대상 %2$d개 / 표시 %3$d개
detail.conflict|同じキー : %@|Same key: %@|相同按键：%@|같은 키: %@
detail.selected|%d件を選択中|%d selected|已选择 %d 项|%d개 선택됨
button.copyTable|表をコピー|Copy Table|拷贝表格|표 복사
tip.copyTable|表示中の行をタブ区切りでコピーします。|Copies the rows on screen as tab-separated text.|以制表符分隔拷贝显示的行。|표시 중인 행을 탭으로 구분해 복사합니다.
button.export|書き出し|Export|导出|내보내기
tip.export|表示中の行をファイルに書き出します。|Saves the rows on screen to a file.|将显示的行存储到文件。|표시 중인 행을 파일로 저장합니다.
export.csv|CSV…|CSV…|CSV…|CSV…
export.markdown|Markdown…|Markdown…|Markdown…|Markdown…
button.close|閉じる|Close|关闭|닫기
menu.copyID|IDをコピー|Copy ID|拷贝 ID|ID 복사
menu.copyRows|行をコピー|Copy Rows|拷贝行|행 복사
menu.removeSet|追加したセットを一覧から外す|Remove Added Set from List|从列表中移除已添加的集|추가한 세트를 목록에서 제거
menu.exportCSV|CSVに書き出す…|Export as CSV…|导出为 CSV…|CSV로 내보내기…
menu.exportMarkdown|Markdownに書き出す…|Export as Markdown…|导出为 Markdown…|Markdown으로 내보내기…
note.copied|%d件をコピーしました。|Copied %d rows.|已拷贝 %d 项。|%d개를 복사했습니다.
note.exported|「%1$@」に%2$d件を書き出しました。|Saved %2$d rows to “%1$@”.|已将 %2$d 项存储到“%1$@”。|“%1$@”에 %2$d개를 저장했습니다.
note.exportFailed|書き出せませんでした : %@|Could not save: %@|无法存储：%@|저장하지 못했습니다: %@
error.cannotRead|「%@」を読み込めません。キーボードショートカットの.kysファイルか確かめてください。|Cannot read “%@”. Check that it is a keyboard shortcut .kys file.|无法读取“%@”。请确认它是键盘快捷键 .kys 文件。|“%@”을(를) 읽을 수 없습니다. 키보드 단축키 .kys 파일인지 확인하세요.
error.notKys|追加できるのは.kysファイルだけです。|Only .kys files can be added.|只能添加 .kys 文件。|.kys 파일만 추가할 수 있습니다.
note.activeDefault|Illustratorで使用中のセットは初期設定です。|Illustrator is using its default set.|Illustrator 正在使用默认集。|Illustrator에서 기본 세트를 사용 중입니다.
note.noCustom|カスタマイズしたセットが見つかりません。Illustratorで保存するか、［セットを追加…］で.kysファイルを選んでください。|No customized set found. Save one in Illustrator, or choose a .kys file with Add Set….|未找到自定义集。请在 Illustrator 中存储，或用“添加集…”选择 .kys 文件。|사용자 정의 세트를 찾을 수 없습니다. Illustrator에서 저장하거나 세트 추가…로 .kys 파일을 선택하세요.
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
