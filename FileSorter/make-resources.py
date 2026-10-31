from pathlib import Path
import json
root = Path(__file__).parent
APP = 'FileSorter'
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''heading|追加されたファイルの振り分け|Sort Added Files|分类新增的文件|추가된 파일 분류
subtitle|フォルダーに加わったファイルを、ルールに合わせて別のフォルダーへ移動します。|Moves files added to a folder to other folders according to your rules.|按规则将添加到文件夹的文件移到其他文件夹。|폴더에 추가된 파일을 규칙에 따라 다른 폴더로 이동합니다.
sort.enabled|振り分ける|Sort|分类|분류
rules|ルール（上から順に調べる）|Rules (checked from the top)|规则（从上到下检查）|규칙(위에서부터 확인)
activity|最近の処理|Recent Activity|最近的处理|최근 처리
activityEmpty|まだありません。履歴は保存せず、終了すると消えます。|None yet. Not saved; cleared when the app quits.|暂无。不会保存，退出应用时清除。|아직 없습니다. 저장하지 않으며 앱을 종료하면 지워집니다.
change|変更…|Change…|更改…|변경…
choose|選択|Choose|选择|선택
sort.keywordsSummary|名前に「%@」|Name contains “%@”|名称包含“%@”|이름에 “%@”
sort.extensionsSummary|拡張子 %@|Extension %@|扩展名 %@|확장자 %@
sort.or| または | or |或| 또는 
sort.detail|最初に当てはまったルールで移動します。ダウンロード中のファイルは書き込みが終わるまで待ちます。移動先に同じ名前があるときは末尾に番号を付けます。起動前からあったファイルは「今あるファイルを振り分ける」で移動できます。|The first matching rule moves the file. Files still downloading are moved once complete. A number is added when the name is taken. Files present before launch can be moved with Sort Existing Files.|按第一条匹配的规则移动。正在下载的文件会等待写入完成。目标位置有同名文件时会添加编号。启动前已有的文件可用“分类现有文件”移动。|처음 일치한 규칙으로 이동합니다. 다운로드 중인 파일은 쓰기가 끝날 때까지 기다립니다. 같은 이름이 있으면 번호를 붙입니다. 실행 전부터 있던 파일은 '기존 파일 분류'로 이동할 수 있습니다.
sortExistingMenu|今あるファイルを振り分ける…|Sort Existing Files…|分类现有文件…|기존 파일 분류…
sortExistingHint|監視するフォルダーに今あるファイルのうち、ルールに当てはまるものを確認してから移動します。|Moves files already in the watched folders that match a rule, after confirming.|确认后移动监视文件夹中已有且符合规则的文件。|감시 폴더에 이미 있는 파일 중 규칙에 맞는 파일을 확인 후 이동합니다.
sortExistingConfirm|%d個のファイルを移動しますか？|Move %d file(s)?|移动 %d 个文件？|파일 %d개를 이동할까요?
sortExistingButton|移動|Move|移动|이동
log.nothingToSort|今あるファイルに、ルールに当てはまるものはありません。|No existing files match a rule.|没有符合规则的现有文件。|규칙에 맞는 기존 파일이 없습니다.
newRule|新しいルール|New Rule|新建规则|새 규칙
editRule|ルールを編集|Edit Rule|编辑规则|규칙 편집
edit|編集…|Edit…|编辑…|편집…
delete|削除|Delete|删除|삭제
deleteConfirm|ルール「%@」を削除しますか？|Delete the rule “%@”?|删除规则“%@”？|규칙 “%@”을(를) 삭제할까요?
deleteConfirmDetail|この操作は取り消せません。ファイルは削除しません。|This cannot be undone. No files are deleted.|此操作无法撤销。不会删除文件。|이 작업은 취소할 수 없습니다. 파일은 삭제하지 않습니다.
save|保存|Save|存储|저장
listSeparator|、|, |、|, 
rule.name|名前|Name|名称|이름
rule.folder|監視するフォルダー|Watched folder|监视的文件夹|감시할 폴더
rule.keywords|名前に含む語|Name contains|名称包含|이름에 포함
rule.keywordsHint|例：請求書, invoice|e.g. invoice, receipt|例如：发票, invoice|예: 청구서, invoice
rule.extensions|拡張子|Extensions|扩展名|확장자
rule.extensionsHint|例：mp3, m4a|e.g. mp3, m4a|例如：mp3, m4a|예: mp3, m4a
rule.destination|移動先|Move to|移动到|이동할 곳
rule.detail|「名前に含む語」と「拡張子」はカンマで区切ります。どちらかに当てはまれば移動します（大文字と小文字は区別しません）。|Separate words and extensions with commas. A file matching either is moved (case-insensitive).|用逗号分隔词语和扩展名。符合任一项即移动（不区分大小写）。|단어와 확장자는 쉼표로 구분합니다. 어느 하나라도 일치하면 이동합니다(대소문자 구분 안 함).
preset.invoice|請求書|Invoices|发票|청구서
preset.music|音楽|Music|音乐|음악
log.cannotWatch|フォルダーを監視できません：%@|Cannot watch the folder: %@|无法监视文件夹：%@|폴더를 감시할 수 없습니다: %@
log.noDestination|「%@」を移動できません。移動先のフォルダーがありません：%@|Could not move “%@”: the destination folder is missing: %@|无法移动“%@”：目标文件夹不存在：%@|“%@”을(를) 이동할 수 없습니다. 이동할 폴더가 없습니다: %@
log.moved|「%@」を「%@」で %@ へ移動しました|Moved “%@” by “%@” to %@|已按“%2$@”将“%1$@”移到 %3$@|“%@”을(를) “%@” 규칙으로 %@에 이동했습니다
log.moveFailed|「%@」を移動できませんでした：%@|Could not move “%@”: %@|无法移动“%@”：%@|“%@”을(를) 이동하지 못했습니다: %@
notifyToggle|ファイルを移動したら通知|Notify when files are moved|移动文件时通知|파일을 이동하면 알림
aboutDetail|フォルダーに加わったファイルを、ルールに合わせて別のフォルダーへ移動します。サポート：同梱のREADME.md|Moves files added to a folder according to your rules. Support: bundled README.md|按规则移动添加到文件夹的文件。支持：内置 README.md|폴더에 추가된 파일을 규칙에 따라 이동합니다. 지원: 포함된 README.md
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
rows += "\n" + 'renameTitle|ファイル名の変更|File Renaming|文件重命名|파일 이름 변경\nexplanation|説明|Explanation|说明|설명\nshot.folders|ウォッチフォルダー|Watch Folders|监视文件夹|감시 폴더\naddFolder|フォルダーを追加…|Add Folder…|添加文件夹…|폴더 추가…\nremoveFolder|削除|Remove|移除|제거\nopenFolder|Finderで開く|Open in Finder|在访达中打开|Finder에서 열기\nresetDefault|初期値に戻す|Restore Default|恢复默认|초기값으로\nshot.enabled|新しいスクリーンショットの名前を変える|Rename new screenshots|重命名新截图|새 스크린샷 이름 바꾸기\nshot.template|名前の形式：|Name format:|名称格式：|이름 형식:\nshot.templateHint|{width}・{height}・{dpi}・{date} を使えます。例：|Use {width}, {height}, {dpi} and {date}. Example:|可使用 {width}、{height}、{dpi}、{date}。示例：|{width}, {height}, {dpi}, {date}를 쓸 수 있습니다. 예:\nlog.notImage|「%@」を画像として読めませんでした。|Could not read “%@” as an image.|无法将“%@”读取为图像。|“%@”을(를) 이미지로 읽지 못했습니다.\nlog.renameFailed|「%@」の名前を変えられませんでした：%@|Could not rename “%@”: %@|无法重命名“%@”：%@|“%@”의 이름을 바꾸지 못했습니다: %@\nlog.renamed|%@ に名前を変えました|Renamed to %@|已重命名为 %@|%@(으)로 이름을 바꿨습니다\nrenameFiles|PNGを改名…|Rename PNG Files…|重命名PNG文件…|PNG 이름 변경…\nshot.detail|新しいPNGを幅・高さ・解像度・日時で改名します。既存ファイルは自動処理しません。同名は番号を付けます。ShotSorterで同じフォルダーの監視をOFFにしてから有効にしてください。自動改名後に振り分けルールを適用します。元の名前への取り消しはできません。|Renames new PNGs using dimensions, DPI and time. Existing files are untouched automatically. Collisions get a number. Disable ShotSorter monitoring for the same folders first. Sorting rules run after automatic renaming. Original names cannot be restored automatically.|按尺寸、DPI和时间重命名新PNG。不会自动处理已有文件。同名时添加编号。请先关闭ShotSorter对相同文件夹的监视。自动重命名后应用分类规则。无法自动恢复原名。|새 PNG를 크기, DPI, 시간으로 변경합니다. 기존 파일은 자동 처리하지 않습니다. 같은 이름에는 번호를 붙입니다. 먼저 ShotSorter의 같은 폴더 감시를 끄세요. 자동 변경 후 분류 규칙을 적용합니다. 원래 이름은 자동 복원할 수 없습니다.'
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
