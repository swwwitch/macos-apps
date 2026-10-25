from pathlib import Path
import json
root = Path(__file__).parent
APP = 'ClipTidy'
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''heading|コピーした文字を整える|Tidy Copied Text|整理复制的文本|복사한 텍스트 정리
subtitle|コピーしたURLや文章を、ルールに合わせて自動で書き換えます。|Rewrites copied URLs and text automatically with your rules.|按规则自动改写复制的网址和文本。|복사한 URL과 텍스트를 규칙에 따라 자동으로 바꿉니다.
watching|コピーを監視|Watch the clipboard|监视剪贴板|클립보드 감시
watchingHint|オフにすると、コピーした内容を書き換えません。|When off, copied content is left as is.|关闭后不会改写复制的内容。|끄면 복사한 내용을 바꾸지 않습니다.
rules|ルール（上から順に適用）|Rules (applied from the top)|规则（从上到下应用）|규칙(위에서부터 적용)
edit|編集…|Edit…|编辑…|편집…
duplicate|複製|Duplicate|复制|복제
delete|削除|Delete|删除|삭제
newRule|新しいルール|New Rule|新建规则|새 규칙
newRuleMenu|新しいルール…|New Rule…|新建规则…|새 규칙…
editRule|ルールを編集|Edit Rule|编辑规则|규칙 편집
moveUp|上へ|Move Up|上移|위로
moveDown|下へ|Move Down|下移|아래로
restorePresets|最初のルールを追加|Add Starter Rules|添加初始规则|기본 규칙 추가
restorePresetsHint|最初から入っていたルールのうち、一覧にないものを追加します。|Adds the starter rules missing from the list.|添加列表中缺少的初始规则。|목록에 없는 기본 규칙을 추가합니다.
presetsPresent|最初のルールはすべて一覧にあります。|All starter rules are already in the list.|所有初始规则都已在列表中。|기본 규칙이 모두 목록에 있습니다.
presetsAdded|最初のルールを%d件追加しました。|Added %d starter rule(s).|已添加 %d 条初始规则。|기본 규칙 %d개를 추가했습니다.
tryIt|試す|Try It|试用|시험
tryPlaceholder|ここに文字を入力すると、書き換えの結果を表示します|Type text here to preview the result|在此输入文本以预览结果|여기에 텍스트를 입력하면 결과를 미리 봅니다
tryNone|書き換えるルールはありません。|No rule applies.|没有适用的规则。|적용되는 규칙이 없습니다.
tryApplied|適用：%@|Applied: %@|已应用：%@|적용: %@
tryNoMatch|このルールは当てはまりません。|This rule does not apply.|此规则不适用。|이 규칙은 해당되지 않습니다.
history|最近の書き換え|Recent Rewrites|最近的改写|최근 변환
historyEmpty|まだありません。履歴は保存せず、終了すると消えます。|None yet. Not saved; cleared when the app quits.|暂无。不会保存，退出应用时清除。|아직 없습니다. 저장하지 않으며 앱을 종료하면 지워집니다.
listSeparator|、|, |、|, 
copyName|%@ のコピー|%@ Copy|%@ 副本|%@ 사본
deleteConfirm|ルール「%@」を削除しますか？|Delete the rule “%@”?|删除规则“%@”？|규칙 “%@”을(를) 삭제할까요?
deleteConfirmDetail|この操作は取り消せません。|This cannot be undone.|此操作无法撤销。|이 작업은 취소할 수 없습니다.
save|保存|Save|存储|저장
rule.name|名前|Name|名称|이름
rule.condition|条件|Condition|条件|조건
rule.conditionHint|この正規表現に一致するときだけ書き換えます（空欄なら常に）。|Rewrite only when this regular expression matches (empty: always).|仅在匹配此正则表达式时改写（留空则始终）。|이 정규 표현식과 일치할 때만 바꿉니다(비우면 항상).
rule.find|検索|Find|查找|찾기
rule.replace|置換|Replace|替换|바꾸기
rule.replaceHint|空欄なら削除します。正規表現では \\1・$1 で一致した部分、\\n で改行を入れます。|Empty removes the match. With regular expressions, \\1 or $1 inserts a group and \\n a line break.|留空则删除。正则表达式中 \\1 或 $1 插入分组，\\n 为换行。|비우면 삭제합니다. 정규 표현식에서는 \\1·$1로 그룹, \\n으로 줄바꿈을 넣습니다.
rule.regex|正規表現|Regular expression|正则表达式|정규 표현식
rule.caseSensitive|大文字と小文字を区別|Case sensitive|区分大小写|대소문자 구분
rule.announce|書き換えたら画面に表示|Show when rewritten|改写后显示|변환하면 화면에 표시
rule.app|コピーしたアプリ|Copied in|复制所在应用|복사한 앱
rule.anyApp|すべてのアプリ|Any app|任何应用|모든 앱
rule.chooseApp|アプリを選択…|Choose App…|选择应用…|앱 선택…
rule.removed|（削除）|(remove)|（删除）|(삭제)
rule.invalid|「%@」の正規表現が正しくありません。|The regular expression in “%@” is invalid.|“%@”中的正则表达式无效。|“%@”의 정규 표현식이 올바르지 않습니다.
preset.vimeo|VimeoのURLの余分な引数|Vimeo URL extra parameters|Vimeo 网址多余参数|Vimeo URL 불필요한 매개변수
preset.vimeoShare|VimeoのURLの ?share=copy|Vimeo URL ?share=copy|Vimeo 网址 ?share=copy|Vimeo URL ?share=copy
preset.facebook|FacebookのURLの ?acontext|Facebook URL ?acontext|Facebook 网址 ?acontext|Facebook URL ?acontext
preset.mailto|先頭の mailto: を削除|Remove leading mailto:|删除开头的 mailto:|앞의 mailto: 삭제
preset.twitter|mobile.twitter.com を twitter.com に|mobile.twitter.com to twitter.com|mobile.twitter.com 改为 twitter.com|mobile.twitter.com을 twitter.com으로
preset.notion|NotionのページURLを短く|Shorten Notion page URLs|缩短 Notion 页面网址|Notion 페이지 URL 줄이기
preset.letao|ルタオのギフト案内文|LeTAO gift message|LeTAO 礼品消息|LeTAO 선물 메시지
notice.rewritten|%@ で書き換えました|Rewritten by %@|已按 %@ 改写|%@(으)로 변환했습니다
dropbox.ready|Dropboxのリンクの準備ができました|Dropbox link is ready|Dropbox 链接已准备好|Dropbox 링크가 준비되었습니다
dropbox.file|ファイル：「%@」|File: “%@”|文件：“%@”|파일: “%@”
dropbox.folder|フォルダー：「%@」|Folder: “%@”|文件夹：“%@”|폴더: “%@”
dropbox.detail|［直接ダウンロード］を押すと、リンクの末尾を dl=1 に変えます。|Direct Download changes the end of the link to dl=1.|“直接下载”会将链接末尾改为 dl=1。|직접 다운로드를 누르면 링크 끝을 dl=1로 바꿉니다.
dropbox.direct|直接ダウンロード|Direct Download|直接下载|직접 다운로드
dropbox.changed|Dropboxのリンクを直接ダウンロード用（dl=1）にしました。|Changed the Dropbox link to a direct download (dl=1).|已将 Dropbox 链接改为直接下载（dl=1）。|Dropbox 링크를 직접 다운로드(dl=1)로 바꿨습니다.
dropbox.newer|その後に別の内容がコピーされたため、Dropboxのリンクは変えませんでした。|Something else was copied since, so the Dropbox link was left as is.|此后复制了其他内容，因此未更改 Dropbox 链接。|그 후 다른 내용을 복사해서 Dropbox 링크를 바꾸지 않았습니다.
rewroteStatus|書き換えました：%@|Rewrote: %@|已改写：%@|변환함: %@
ruleErrors|正規表現が正しくないため使えなかったルール：%@|Rules skipped because of an invalid regular expression: %@|因正则表达式无效而跳过的规则：%@|정규 표현식이 올바르지 않아 건너뛴 규칙: %@
pausedStatus|監視を一時停止しています。|Watching is paused.|已暂停监视。|감시를 일시 정지했습니다.
watchingStatus|コピーを監視しています。|Watching copies.|正在监视复制。|복사를 감시하고 있습니다.
pause|監視を一時停止|Pause Watching|暂停监视|감시 일시 정지
resume|監視を再開|Resume Watching|继续监视|감시 재개
watchSection|監視|Watching|监视|감시
watchDetail|オフにしている間にコピーした内容は、オンに戻しても書き換えません。パスワード管理アプリが「秘密」と印を付けた内容は読みません。|Content copied while off is not rewritten later. Content marked secret by password managers is never read.|关闭期间复制的内容在重新开启后也不会改写。不会读取密码管理器标记为机密的内容。|끈 동안 복사한 내용은 다시 켜도 바꾸지 않습니다. 암호 관리 앱이 비밀로 표시한 내용은 읽지 않습니다.
dropboxSection|Dropbox|Dropbox|Dropbox|Dropbox
dropboxPrompt|共有リンクをコピーしたら知らせる|Notify when a shared link is copied|复制共享链接时提示|공유 링크를 복사하면 알림
dropboxPromptDetail|末尾が dl=0 のDropboxの共有リンクをコピーすると、画面の右上に知らせ、直接ダウンロード用（dl=1）に変えられます。|When a Dropbox shared link ending in dl=0 is copied, a panel at the top right offers to change it to a direct download (dl=1).|复制末尾为 dl=0 的 Dropbox 共享链接时，右上角会提示并可改为直接下载（dl=1）。|끝이 dl=0인 Dropbox 공유 링크를 복사하면 오른쪽 위에 알리고 직접 다운로드(dl=1)로 바꿀 수 있습니다.
noticeSection|書き換えの表示|Rewrite Notice|改写提示|변환 표시
noticeSeconds|表示時間|Display time|显示时间|표시 시간
seconds|%d秒|%d s|%d 秒|%d초
noticeDetail|「書き換えたら画面に表示」をオンにしたルールで、画面の右上に結果を表示する時間です。|How long the result stays at the top right for rules with “Show when rewritten”.|开启“改写后显示”的规则在右上角显示结果的时长。|“변환하면 화면에 표시”를 켠 규칙의 결과를 오른쪽 위에 표시하는 시간입니다.
excludedExplanation|対象外アプリが前面にあるときにコピーした内容は、書き換えもDropboxの確認もしません。|Content copied while an excluded app is in front is neither rewritten nor checked for Dropbox links.|在排除的应用位于前台时复制的内容不会被改写，也不会检查 Dropbox 链接。|제외할 앱이 앞에 있을 때 복사한 내용은 바꾸지 않고 Dropbox 링크도 확인하지 않습니다.
aboutDetail|コピーした文字をルールに合わせて自動で書き換えます。サポート：同梱のREADME.md|Rewrites copied text automatically with your rules. Support: bundled README.md|按规则自动改写复制的文本。支持：内置 README.md|복사한 텍스트를 규칙에 따라 자동으로 바꿉니다. 지원: 포함된 README.md
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
