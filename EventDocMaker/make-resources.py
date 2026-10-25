from pathlib import Path
import json
root = Path(__file__).parent
APP = 'EventDocMaker'
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''heading|イベントの文書を作る|Make Event Documents|生成活动文档|이벤트 문서 만들기
subtitle|イベントの表から、案内文やメールなどの定型の文書をまとめて書き出します。|Writes out the standard texts (announcements, mails and more) from the event sheet.|根据活动表批量写出公告、邮件等固定文档。|이벤트 표에서 안내문, 메일 등 정형 문서를 한꺼번에 만듭니다.
sheet|イベントの表（項目⇥値）|Event Sheet (label ⇥ value)|活动表（项目⇥值）|이벤트 표(항목⇥값)
sheetPlaceholder|Excelで「項目」と「値」の2列をコピーし、［クリップボードから読み込む］を押すか、ここにペーストします。|Copy the label and value columns in Excel, then click Load from Clipboard or paste here.|在 Excel 中拷贝“项目”和“值”两列，然后点按“从剪贴板读取”或粘贴到这里。|Excel에서 항목과 값 두 열을 복사한 뒤 '클립보드에서 읽기'를 누르거나 여기에 붙여넣으세요.
loadClipboardButton|クリップボードから読み込む|Load from Clipboard|从剪贴板读取|클립보드에서 읽기
loadClipboard|クリップボードから読み込む|Load from Clipboard|从剪贴板读取|클립보드에서 읽기
clear|消去|Clear|清除|지우기
clipboardEmpty|クリップボードに文字がありません。|The clipboard has no text.|剪贴板中没有文本。|클립보드에 텍스트가 없습니다.
noFields|項目を読み取れませんでした。「項目」と「値」の2列をコピーしてください。|No rows were found. Copy the label and value columns.|未找到项目。请拷贝“项目”和“值”两列。|항목을 찾지 못했습니다. 항목과 값 두 열을 복사하세요.
loaded|%d項目を読み込みました。|Loaded %d rows.|已读取 %d 个项目。|%d개 항목을 읽었습니다.
summary.category|種別|Category|类别|종류
summary.name|イベント名|Event|活动名称|이벤트 이름
summary.date|日付|Date|日期|날짜
summary.folder|作成先|Folder|创建位置|만들 위치
summary.missing|表に「%@」がありません|The sheet lacks “%@”|表中缺少“%@”|표에 “%@”이(가) 없습니다
summary.templates|テンプレート|Templates|模板|템플릿
summary.templateCount|%d個|%d|%d 个|%d개
listSeparator|・|, |、|, 
makeQR|QRコードも作る|Also make QR codes|同时生成二维码|QR 코드도 만들기
openAfter|作成後にフォルダーを開く|Open the folder afterwards|完成后打开文件夹|만든 후 폴더 열기
generate|文書を作る|Make Documents|生成文档|문서 만들기
generateMenu|文書を作る|Make Documents|生成文档|문서 만들기
variables|変数の一覧（%d）|Variables (%d)|变量列表（%d）|변수 목록(%d)
result.written|%d個の文書を書き出しました|Wrote %d documents|已写出 %d 个文档|문서 %d개를 만들었습니다
result.open|フォルダーを開く|Open Folder|打开文件夹|폴더 열기
result.qr|QRコード：%d個|QR codes: %d|二维码：%d 个|QR 코드: %d개
result.stores|STORES用：%@|For STORES: %@|STORES 用：%@|STORES용: %@
result.empty|値が空の変数（%d）：%@|Empty variables (%d): %@|值为空的变量（%d）：%@|값이 빈 변수(%d): %@
done|%1$d個の文書を %2$@ に書き出しました。|Wrote %1$d documents to %2$@.|已将 %1$d 个文档写入 %2$@。|%2$@에 문서 %1$d개를 만들었습니다.
failed|書き出せませんでした：%@|Could not write: %@|无法写出：%@|만들지 못했습니다: %@
rootMissing|作成先の親フォルダーがありません：%@（設定の「フォルダー」）|The parent folder is missing: %@ (Settings › Folders)|父文件夹不存在：%@（设置 › 文件夹）|상위 폴더가 없습니다: %@(설정 › 폴더)
noTemplates|テンプレートがありません：%@（設定の「フォルダー」）|No templates in %@ (Settings › Folders)|%@ 中没有模板（设置 › 文件夹）|%@에 템플릿이 없습니다(설정 › 폴더)
warn.link|最近のイベントへのリンクを作れませんでした：%@|Could not make the recent-event link: %@|无法创建最近活动的链接：%@|최근 이벤트 링크를 만들지 못했습니다: %@
warn.unreadable|テンプレート「%@」を読めませんでした（UTF-8ではない可能性）。|Could not read the template “%@” (it may not be UTF-8).|无法读取模板“%@”（可能不是 UTF-8）。|템플릿 “%@”을(를) 읽지 못했습니다(UTF-8이 아닐 수 있음).
warn.stores|STORES用のファイルを作れませんでした：%@|Could not make the STORES file: %@|无法创建 STORES 用文件：%@|STORES용 파일을 만들지 못했습니다: %@
warn.qr|QRコード（%@）を作れませんでした。|Could not make the QR code (%@).|无法生成二维码（%@）。|QR 코드(%@)를 만들지 못했습니다.
warn.missingDoc|共通の文書がないため空にしました：%@|Shared text not found, left empty: %@|未找到共用文本，按空处理：%@|공통 문서가 없어 비워 두었습니다: %@
busyQuit|書き出しの途中です。終わるまでお待ちください。|Writing is in progress. Please wait until it finishes.|正在写出，请等待完成。|쓰는 중입니다. 끝날 때까지 기다려 주세요.
foldersTab|フォルダー|Folders|文件夹|폴더
folder.root|作成先の親フォルダー|Parent folder|父文件夹|상위 폴더
folder.rootDetail|この中に「種別-仮の日付-タイトル（abc）」のフォルダーと、その中の docs フォルダーを作ります。|A folder named “category-date-title (abc)” with a docs folder inside is made here.|在此创建“类别-暂定日期-标题（abc）”文件夹及其中的 docs 文件夹。|이 안에 “종류-임시 날짜-제목(abc)” 폴더와 그 안의 docs 폴더를 만듭니다.
folder.eventDoc|EventDocフォルダー|EventDoc folder|EventDoc 文件夹|EventDoc 폴더
folder.eventDocDetail|Templates（テンプレート）・Guide・Footer・ComingInfo・Archive を読みます。|Templates, Guide, Footer, ComingInfo and Archive are read from here.|从此读取 Templates、Guide、Footer、ComingInfo 和 Archive。|Templates, Guide, Footer, ComingInfo, Archive를 여기서 읽습니다.
folder.recent|最近のイベントのリンク置き場|Recent events links|最近活动链接位置|최근 이벤트 링크 위치
folder.recentDetail|作ったイベントのフォルダーへのリンク（エイリアスのように使えるシンボリックリンク）を置きます。「なし」にすると作りません。|A symbolic link to each event folder is placed here. Choose None to skip.|在此放置指向各活动文件夹的符号链接。选择“无”则不创建。|각 이벤트 폴더로의 심볼릭 링크를 둡니다. '없음'이면 만들지 않습니다.
none|なし|None|无|없음
noneButton|なしにする|None|设为无|없음으로
change|変更…|Change…|更改…|변경…
resetFolders|すべて初期値に戻す|Restore All Defaults|全部恢复默认|모두 초기값으로
openSection|フォルダーを開くアプリ|Open Folders With|打开文件夹的应用|폴더를 열 앱
openWith|開くアプリ|Open with|打开方式|열 앱
openDetail|Path Finderが見つからないときはFinderで開きます。|Finder is used when Path Finder is not found.|找不到 Path Finder 时使用访达打开。|Path Finder가 없으면 Finder로 엽니다.
aboutDetail|イベントの表から定型の文書をまとめて書き出します。サポート：同梱のREADME.md|Writes standard event documents from the event sheet. Support: bundled README.md|根据活动表批量写出固定文档。支持：内置 README.md|이벤트 표에서 정형 문서를 한꺼번에 만듭니다. 지원: 포함된 README.md
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
    (p / 'InfoPlist.strings').write_text(f'"CFBundleDisplayName" = "{APP}";\n')
    (p / 'Help.txt').write_text(HELP[lang])
print('resources:', len(table), 'keys x 4 languages')
