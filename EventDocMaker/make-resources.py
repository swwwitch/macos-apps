from pathlib import Path
import json
root = Path(__file__).parent
APP = 'EventDocMaker'
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''untitled|（名前なし）|(Untitled)|（未命名）|(이름 없음)
saveFailed|保存できませんでした：%@|Could not save: %@|无法存储：%@|저장하지 못했습니다: %@
noEventSelected|イベントを選んでください。|Select an event.|请选择活动。|이벤트를 선택하세요.
filled|%d項目を表から入力しました。|Filled %d fields from the sheet.|已从表中填入 %d 个项目。|표에서 %d개 항목을 입력했습니다.
import.choose|取り込む|Import|导入|가져오기
import.reading|Excelを読んでいます…|Reading the workbook…|正在读取 Excel…|Excel을 읽는 중…
import.failed|Excelを読めませんでした：%@|Could not read the workbook: %@|无法读取 Excel：%@|Excel을 읽지 못했습니다: %@
import.none|Excelにイベントが見つかりませんでした（シート「新しいまとめ」のA列に「#」の行が必要）。|No events were found (the sheet 新しいまとめ needs a “#” row in column A).|未找到活动（工作表“新しいまとめ”的 A 列需要“#”行）。|이벤트를 찾지 못했습니다(시트 新しいまとめ의 A열에 “#” 행 필요).
import.confirm|%1$d件のイベントのうち、%2$d件を新しく取り込みますか？|Import %2$d new of %1$d events?|在 %1$d 个活动中导入 %2$d 个新活动？|%1$d개 이벤트 중 %2$d개를 새로 가져올까요?
import.confirmDetail|イベントのフォルダーがあるものはその中の event.json に、無いものは EventDoc/EventData に保存します。Excelは変更しません。|Events whose folder exists are saved as event.json in it; the others go to EventDoc/EventData. The workbook is not changed.|有文件夹的活动存为其中的 event.json，其余存入 EventDoc/EventData。不会更改 Excel。|폴더가 있는 이벤트는 그 안의 event.json에, 없는 것은 EventDoc/EventData에 저장합니다. Excel은 바꾸지 않습니다.
import.button|取り込む|Import|导入|가져오기
import.overwrite|すでにある%d件もExcelの値で上書きする|Also overwrite the %d events already here with the workbook’s values|同时用 Excel 的值覆盖已有的 %d 个活动|이미 있는 %d개도 Excel 값으로 덮어쓰기
import.done|取り込み：新規%1$d件・上書き%2$d件・そのまま%3$d件|Imported: %1$d new, %2$d overwritten, %3$d unchanged|导入：新增 %1$d、覆盖 %2$d、未变 %3$d|가져오기: 새로 %1$d개, 덮어쓰기 %2$d개, 그대로 %3$d개
xlsx.unreadable|Excelの「%@」を読めません。|Cannot read “%@” in the workbook.|无法读取 Excel 中的“%@”。|Excel의 “%@”을(를) 읽을 수 없습니다.
xlsx.noSheet|シート「%@」がありません。|The sheet “%@” is missing.|缺少工作表“%@”。|시트 “%@”이(가) 없습니다.
deleteConfirm|イベント「%@」を削除しますか？|Delete the event “%@”?|删除活动“%@”？|이벤트 “%@”을(를) 삭제할까요?
deleteConfirmDetail|イベントの情報（event.json）をゴミ箱に入れます。イベントのフォルダーと作った文書はそのままです。|The event’s data (event.json) goes to the Trash. The event folder and its documents stay.|活动信息（event.json）将移到废纸篓。活动文件夹和已生成的文档保留。|이벤트 정보(event.json)를 휴지통으로 옮깁니다. 이벤트 폴더와 만든 문서는 그대로입니다.
delete|削除|Delete|删除|삭제
reloaded|%d件のイベントを読み直しました。|Reloaded %d events.|已重新读取 %d 个活动。|이벤트 %d개를 다시 읽었습니다.
newEvent|新しいイベント|New Event|新建活动|새 이벤트
duplicateEvent|イベントを複製|Duplicate Event|复制活动|이벤트 복제
deleteEvent|イベントを削除…|Delete Event…|删除活动…|이벤트 삭제…
importSheetMenu|Excelから取り込む…|Import from Excel…|从 Excel 导入…|Excel에서 가져오기…
importSheet|Excelから取り込む…|Import from Excel…|从 Excel 导入…|Excel에서 가져오기…
fillFromClipboard|クリップボードの表から入力|Fill from Copied Sheet|从剪贴板中的表填入|클립보드의 표에서 입력
reload|読み直す|Reload|重新读取|다시 읽기
events|イベント（%d）|Events (%d)|活动（%d）|이벤트(%d)
searchPlaceholder|検索（イベント名・#・日付・出演者）|Search (event, #, date, speaker)|搜索（活动、#、日期、出演者）|검색(이벤트, #, 날짜, 출연자)
search|イベントを検索|Search events|搜索活动|이벤트 검색
noFolderYet|イベントのフォルダーがまだ無いため、EventDataに保存しています|Saved in EventData until the event folder exists|活动文件夹尚不存在，暂存于 EventData|이벤트 폴더가 아직 없어 EventData에 저장합니다
folderNeeds|「種別」「仮の日付」「タイトル（abc）」を入れると作成先のフォルダーが決まります|Enter 種別, 仮の日付 and タイトル（abc） to set the folder|填写 種別、仮の日付 和 タイトル（abc） 后即可确定文件夹|種別, 仮の日付, タイトル（abc）를 넣으면 폴더가 정해집니다
tab.before|開催前|Before|活动前|개최 전
tab.after|終了後|After|结束后|종료 후
tab.documents|文書を作る|Documents|生成文档|문서 만들기
noEvent|イベントがありません。新しく作るか、Excelから取り込んでください。|No events. Create one or import from Excel.|没有活动。请新建或从 Excel 导入。|이벤트가 없습니다. 새로 만들거나 Excel에서 가져오세요.
group.basic|基本|Basics|基本|기본
group.schedule|日時・申し込み|Date & Registration|日期与报名|일시·신청
group.streaming|配信|Streaming|直播|방송
group.speaker|出演者|Speakers|出演者|출연자
group.profile|講演者のプロフィール|Speaker Profile|讲者简介|강연자 프로필
group.sales|販売・売上|Sales|销售|판매
group.survey|アンケート|Survey|问卷|설문
group.results|参加・視聴|Attendance & Viewing|参加与观看|참가·시청
group.youtube|YouTube|YouTube|YouTube|YouTube
group.videos|動画・アーカイブ|Videos & Archives|视频与存档|동영상·아카이브
group.speakerAfter|出演者（終了後）|Speakers (After)|出演者（结束后）|출연자(종료 후)
group.x|X|X|X|X
group.xAds|X広告|X Ads|X 广告|X 광고
group.cssAds|CSS Nite広告|CSS Nite Ads|CSS Nite 广告|CSS Nite 광고
group.surveyResults|アンケート結果・謝礼|Survey Results & Fees|问卷结果与酬劳|설문 결과·사례
heading|イベントの文書を作る|Make Event Documents|生成活动文档|이벤트 문서 만들기
subtitle|イベントごとの情報を管理し、案内文やメールなどの定型の文書をまとめて書き出します。|Keeps each event’s details and writes out its standard texts (announcements, mails and more).|管理每个活动的信息，并批量写出公告、邮件等固定文档。|이벤트마다 정보를 관리하고 안내문, 메일 등 정형 문서를 한꺼번에 만듭니다.
clipboardEmpty|クリップボードに文字がありません。|The clipboard has no text.|剪贴板中没有文本。|클립보드에 텍스트가 없습니다.
noFields|項目を読み取れませんでした。Excelで「項目」と「値」の2列をコピーしてください。|No rows were found. Copy the label and value columns.|未找到项目。请拷贝“项目”和“值”两列。|항목을 찾지 못했습니다. 항목과 값 두 열을 복사하세요.
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
