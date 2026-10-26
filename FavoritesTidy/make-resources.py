from pathlib import Path
import json
root = Path(__file__).parent
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''heading|お気に入りを整理|Tidy Favorites|整理个人收藏|즐겨찾기 정리
subtitle|Default Folder X のお気に入りを並べ替え、区切り線でカテゴリに分けます。|Sort Default Folder X favorites and group them with separators.|对 Default Folder X 的个人收藏排序，并用分隔线分组。|Default Folder X 즐겨찾기를 정렬하고 구분선으로 묶습니다.
folderSet|フォルダセット：|Folder set:|文件夹组：|폴더 세트:
folderSetFixed|フォルダセット：%@|Folder set: %@|文件夹组：%@|폴더 세트: %@
setLocked|保存してから切り替えてください|Save before switching|请先保存再切换|저장한 후 전환하세요
sortMenu|並べ替え|Sort|排序|정렬
sortScopeAll|すべてのカテゴリの中で|Within every category|在每个类别内|모든 카테고리 안에서
sortScopeSelected|選択した項目のカテゴリの中で|Within the selected items' categories|在所选项目的类别内|선택한 항목의 카테고리 안에서
sort.name|名前順|By Name|按名称|이름순
sort.nameDescending|名前の逆順|By Name, Descending|按名称倒序|이름 역순
sort.path|場所（パス）順|By Location (Path)|按位置（路径）|위치(경로)순
sort.newest|追加日の新しい順|Newest Added First|最近添加的在前|최근 추가순
sort.oldest|追加日の古い順|Oldest Added First|最早添加的在前|오래된 추가순
sortAction|並べ替え|Sort|排序|정렬
sortedAll|すべてのカテゴリの中を%@に並べ替えました。|Sorted every category %@.|已将每个类别按%@排序。|모든 카테고리를 %@으로 정렬했습니다.
sortedSelected|%1$@に並べ替えました（%2$d個のカテゴリ）。|Sorted %1$@ (%2$d categories).|已按%1$@排序（%2$d 个类别）。|%1$@으로 정렬했습니다(카테고리 %2$d개).
addSeparator|区切り線を追加|Add Separator|添加分隔线|구분선 추가
separatorAdded|区切り線を追加しました。見出しに名前を付けられます（このアプリの中だけで使います）。|Separator added. You can name its heading (used only in this app).|已添加分隔线。可以为标题命名（仅在本应用内使用）。|구분선을 추가했습니다. 제목에 이름을 붙일 수 있습니다(이 앱에서만 사용).
moveTo|カテゴリへ移動|Move to Category|移到类别|카테고리로 이동
moveAction|移動|Move|移动|이동
movedTo|「%@」の末尾へ移動しました。|Moved to the end of “%@”.|已移到“%@”的末尾。|“%@”의 끝으로 이동했습니다.
moveCategory|カテゴリの移動|Move Category|移动类别|카테고리 이동
moveCategoryUp|カテゴリを上へ移動|Move Category Up|上移类别|카테고리 위로 이동
moveCategoryDown|カテゴリを下へ移動|Move Category Down|下移类别|카테고리 아래로 이동
deleteSeparator|区切り線を削除（前のカテゴリと結合）|Delete Separator (Merge with Previous)|删除分隔线（与上一个类别合并）|구분선 삭제(이전 카테고리와 합치기)
deleteAction|削除|Delete|删除|삭제
deleted|%d個の項目を削除しました。⌘Zで取り消せます。|Deleted %d items. Press ⌘Z to undo.|已删除 %d 个项目。按 ⌘Z 可撤销。|항목 %d개를 삭제했습니다. ⌘Z로 실행 취소할 수 있습니다.
removeFavorite|お気に入りから削除|Remove from Favorites|从个人收藏中移除|즐겨찾기에서 제거
revealInFinder|Finderで表示|Show in Finder|在访达中显示|Finder에서 보기
copyPath|パスをコピー|Copy Path|拷贝路径|경로 복사하기
missing|フォルダーが見つかりません|Folder not found|找不到文件夹|폴더를 찾을 수 없음
hotkeyLabel|ホットキー %@|Hotkey %@|快捷键 %@|단축키 %@
firstCategory|先頭（区切り線より前）|Top (before the first separator)|顶部（第一条分隔线之前）|맨 위(첫 구분선 앞)
unnamedCategory|名前のないカテゴリ|Unnamed category|未命名类别|이름 없는 카테고리
categoryNameLabel|カテゴリの名前|Category name|类别名称|카테고리 이름
categoryHint|名前はこのアプリの中だけで使います。Default Folder X のメニューには区切り線だけが出ます。|The name is used only in this app. Default Folder X's menu shows just the separator.|名称仅在本应用内使用。Default Folder X 的菜单只显示分隔线。|이름은 이 앱에서만 사용합니다. Default Folder X 메뉴에는 구분선만 표시됩니다.
itemCount|%d項目|%d items|%d 项|%d개
loaded|%1$d個のお気に入り・%2$d個のカテゴリを読み込みました。|Loaded %1$d favorites in %2$d categories.|已读取 %1$d 个个人收藏、%2$d 个类别。|즐겨찾기 %1$d개, 카테고리 %2$d개를 읽었습니다.
noSet|Default Folder X のフォルダセットが見つかりません。|No Default Folder X folder set was found.|找不到 Default Folder X 的文件夹组。|Default Folder X 폴더 세트를 찾을 수 없습니다.
readFailed|読み込めませんでした：%@|Could not read: %@|无法读取：%@|읽을 수 없습니다: %@
staysSortedWarning|Default Folder X の設定で「常に名前順に並べる」がオンです。ここで決めた並び順は Default Folder X のメニューに反映されません。|Default Folder X is set to keep favorites sorted, so the order set here does not appear in its menu.|Default Folder X 已设为始终排序个人收藏，此处设置的顺序不会反映到其菜单中。|Default Folder X가 즐겨찾기를 항상 정렬하도록 설정되어 있어, 여기서 정한 순서가 메뉴에 반영되지 않습니다.
dfxNotFound|Default Folder X が見つかりません。保存はできますが、終了と起動し直しは行いません。|Default Folder X was not found. Saving still works, but it is not quit and reopened.|找不到 Default Folder X。仍可保存，但不会退出并重新打开它。|Default Folder X를 찾을 수 없습니다. 저장은 되지만 종료 후 다시 열지는 않습니다.
hotkeyChange|ホットキーを変更…|Change Hotkey…|更改快捷键…|단축키 변경…
hotkeyAction|ホットキーの変更|Change Hotkey|更改快捷键|단축키 변경
hotkeyFor|「%@」のホットキー|Hotkey for “%@”|“%@”的快捷键|‘%@’의 단축키
hotkeyChanged|「%1$@」のホットキーを %2$@ にしました。保存すると Default Folder X に反映されます。|Set the hotkey for “%1$@” to %2$@. Save to apply it in Default Folder X.|已将“%1$@”的快捷键设为 %2$@。保存后会应用到 Default Folder X。|‘%1$@’의 단축키를 %2$@(으)로 지정했습니다. 저장하면 Default Folder X에 반영됩니다.
hotkeyCleared|「%@」のホットキーを解除しました。保存すると Default Folder X に反映されます。|Cleared the hotkey for “%@”. Save to apply it in Default Folder X.|已清除“%@”的快捷键。保存后会应用到 Default Folder X。|‘%@’의 단축키를 해제했습니다. 저장하면 Default Folder X에 반영됩니다.
hotkeyNote|［変更…］を押してから割り当てるキーを押します。ほかのお気に入りと同じキーは使えません。保存すると Default Folder X に反映されます。|Click Change…, then press the keys. A key used by another favorite cannot be assigned. Save to apply it in Default Folder X.|点按“更改…”后按下要分配的按键。不能使用其他个人收藏已用的按键。保存后会应用到 Default Folder X。|[변경…]을 누른 후 지정할 키를 누릅니다. 다른 즐겨찾기와 같은 키는 사용할 수 없습니다. 저장하면 Default Folder X에 반영됩니다.
hotkeyNoteRunning|［変更…］を押してから割り当てるキーを押します。Default Folder X の起動中は、Default Folder X が使っているキーを押すとそちらが反応することがあります。そのときは［Default Folder X を終了］してから記録してください（保存すると起動し直します）。|Click Change…, then press the keys. While Default Folder X is running, a key it uses may trigger it instead. If so, click Quit Default Folder X first (it is reopened when you save).|点按“更改…”后按下按键。Default Folder X 运行时，按下它正在使用的按键可能会触发它。此时请先点按“退出 Default Folder X”再录制（保存时会重新打开）。|[변경…]을 누른 후 키를 누릅니다. Default Folder X 실행 중에는 그 앱이 쓰는 키를 누르면 그쪽이 반응할 수 있습니다. 그럴 때는 [Default Folder X 종료] 후 기록하세요(저장하면 다시 엽니다).
done|完了|Done|完成|완료
quitDFX|Default Folder X を終了|Quit Default Folder X|退出 Default Folder X|Default Folder X 종료
launchDFX|Default Folder X を起動|Open Default Folder X|打开 Default Folder X|Default Folder X 열기
quitDFXHint|ホットキーの記録や、手作業での Favorites.plist の確認の前に終了できます。保存するかこのアプリを終了すると起動し直します。|Quit it before recording hotkeys or checking Favorites.plist by hand. It is reopened when you save or quit this app.|可在录制快捷键或手动检查 Favorites.plist 前退出。保存或退出本应用时会重新打开。|단축키 기록이나 Favorites.plist 직접 확인 전에 종료할 수 있습니다. 저장하거나 이 앱을 종료하면 다시 엽니다.
dfxQuit|Default Folder X を終了しました。保存するか FavoritesTidy を終了すると起動し直します。|Quit Default Folder X. It is reopened when you save or quit FavoritesTidy.|已退出 Default Folder X。保存或退出 FavoritesTidy 时会重新打开。|Default Folder X를 종료했습니다. 저장하거나 FavoritesTidy를 종료하면 다시 엽니다.
dfxLaunched|Default Folder X を起動しました。|Opened Default Folder X.|已打开 Default Folder X。|Default Folder X를 열었습니다.
quitFailed2|Default Folder X が終了しませんでした。開いているダイアログボックスを閉じてから、もう一度押してください。|Default Folder X did not quit. Close any open dialog and try again.|Default Folder X 未退出。请关闭打开的对话框后再试。|Default Folder X가 종료되지 않았습니다. 열려 있는 대화상자를 닫고 다시 시도하세요.
editQuitTitle|Default Folder X を終了してから編集します|Quit Default Folder X before editing|编辑前先退出 Default Folder X|편집하기 전에 Default Folder X를 종료합니다
editQuitDetail|Default Folder X は終了するときにお気に入りを書き出すため、起動したままだと編集が上書きされることがあります。終了して編集を続けますか？保存するか FavoritesTidy を終了すると起動し直します。|Default Folder X writes its favorites when it quits, so edits made while it runs can be overwritten. Quit it and continue? It is reopened when you save or quit FavoritesTidy.|Default Folder X 会在退出时写出个人收藏，运行时所做的编辑可能被覆盖。要退出它并继续编辑吗？保存或退出 FavoritesTidy 时会重新打开。|Default Folder X는 종료할 때 즐겨찾기를 기록하므로 실행 중에 한 편집이 덮어쓰일 수 있습니다. 종료하고 편집을 계속할까요? 저장하거나 FavoritesTidy를 종료하면 다시 엽니다.
quitAndEdit|終了して編集|Quit and Edit|退出并编辑|종료하고 편집
editCanceled|編集を取りやめました（Default Folder X は起動したままです）。|Edit canceled (Default Folder X is still running).|已取消编辑（Default Folder X 仍在运行）。|편집을 취소했습니다(Default Folder X는 계속 실행 중).
searchPlaceholder|名前・パスで検索|Search names and paths|搜索名称和路径|이름·경로 검색
searchLabel|お気に入りを検索|Search favorites|搜索个人收藏|즐겨찾기 검색
searchCount|%d件|%d found|%d 项|%d개
clearSearch|検索を消去|Clear Search|清除搜索|검색 지우기
findMenu|検索|Find|查找|찾기
inDropbox|Dropbox内|In Dropbox|在 Dropbox 中|Dropbox 안
reload|読み直す|Reload|重新读取|다시 읽기
reloadTitle|保存していない変更を破棄して読み直しますか？|Discard unsaved changes and reload?|放弃未保存的更改并重新读取？|저장하지 않은 변경 사항을 버리고 다시 읽을까요?
reloadDetail|Default Folder X のお気に入りを読み込み直します。|Reads the Default Folder X favorites again.|将重新读取 Default Folder X 的个人收藏。|Default Folder X 즐겨찾기를 다시 읽습니다.
save|保存|Save|保存|저장
saveMenu|保存|Save|保存|저장
quittingDFX|Default Folder X を終了しています…|Quitting Default Folder X…|正在退出 Default Folder X…|Default Folder X를 종료하는 중…
quitFailed|Default Folder X が終了しなかったため、保存を中止しました。Default Folder X で開いているダイアログボックスを閉じてから、もう一度保存してください。|Saving stopped because Default Folder X did not quit. Close any dialog open in Default Folder X and save again.|由于 Default Folder X 未退出，已停止保存。请关闭 Default Folder X 中打开的对话框后再次保存。|Default Folder X가 종료되지 않아 저장을 중단했습니다. Default Folder X에서 열려 있는 대화상자를 닫고 다시 저장하세요.
changedOutside|Default Folder X 側でお気に入りが変更されていたため、保存を中止しました。［読み直す］で最新の内容を読み込んでから、もう一度整理してください。|Saving stopped because the favorites were changed in Default Folder X. Click Reload to read the latest favorites, then tidy them again.|由于个人收藏已在 Default Folder X 中更改，已停止保存。请点按“重新读取”读取最新内容后再整理。|Default Folder X에서 즐겨찾기가 변경되어 저장을 중단했습니다. [다시 읽기]로 최신 내용을 읽은 후 다시 정리하세요.
backupFailed|バックアップを作れなかったため、保存を中止しました。|Saving stopped because the backup could not be made.|无法创建备份，已停止保存。|백업을 만들 수 없어 저장을 중단했습니다.
writeFailed|書き込めませんでした：%@|Could not write: %@|无法写入：%@|쓸 수 없습니다: %@
saved|保存して Default Folder X を起動し直しました。|Saved and reopened Default Folder X.|已保存并重新打开 Default Folder X。|저장하고 Default Folder X를 다시 열었습니다.
savedNoDFX|保存しました（Default Folder X は起動していませんでした）。|Saved (Default Folder X was not running).|已保存（Default Folder X 未运行）。|저장했습니다(Default Folder X는 실행 중이 아니었습니다).
relaunchFailed|Default Folder X を起動し直せませんでした。手動で開いてください。|Could not reopen Default Folder X. Open it yourself.|无法重新打开 Default Folder X。请手动打开。|Default Folder X를 다시 열 수 없습니다. 직접 여세요.
confirmSaveTitle|Default Folder X を終了して保存しますか？|Quit Default Folder X and save?|退出 Default Folder X 并保存？|Default Folder X를 종료하고 저장할까요?
confirmSaveDetail|Default Folder X は終了するときにお気に入りを書き出すため、いったん終了してから書き込み、起動し直します。保存前のファイルはバックアップします。|Default Folder X writes its favorites when it quits, so it is quit, the file is written, and it is opened again. The previous file is backed up.|Default Folder X 会在退出时写出个人收藏，因此将先退出它，写入文件后再重新打开。保存前的文件会被备份。|Default Folder X는 종료할 때 즐겨찾기를 기록하므로, 종료한 뒤 파일을 쓰고 다시 엽니다. 저장 전 파일은 백업합니다.
unsavedTitle|保存していない変更があります|You have unsaved changes|有未保存的更改|저장하지 않은 변경 사항이 있습니다
unsavedDetail|終了する前に保存しますか？保存すると Default Folder X をいったん終了して起動し直します。|Save before quitting? Saving quits and reopens Default Folder X.|退出前要保存吗？保存时会退出并重新打开 Default Folder X。|종료하기 전에 저장할까요? 저장하면 Default Folder X를 종료했다가 다시 엽니다.
dontSave|保存しない|Don’t Save|不存储|저장 안 함
cancel|キャンセル|Cancel|取消|취소
ok|OK|OK|好|확인
busyQuit|保存の途中です|Saving is in progress|正在保存|저장하는 중입니다
busyQuitDetail|保存が終わってから終了してください。|Quit after saving finishes.|请在保存完成后退出。|저장이 끝난 후 종료하세요.
generalTab|一般|General|通用|일반
saveGroup|保存|Saving|保存|저장
confirmBeforeSave|保存の前に確認する|Confirm before saving|保存前确认|저장하기 전에 확인
confirmBeforeSaveDetail|Default Folder X の起動中に保存するとき、終了と起動し直しの確認を出します。|When Default Folder X is running, asks before quitting and reopening it to save.|Default Folder X 运行时保存，会先确认退出并重新打开。|Default Folder X 실행 중에 저장할 때 종료 후 다시 열기를 확인합니다.
backupDetail|保存の直前の Favorites.plist を最新%d件までバックアップします。|Keeps up to %d backups of Favorites.plist taken right before each save.|保存前的 Favorites.plist 最多备份最近 %d 份。|저장 직전의 Favorites.plist를 최근 %d개까지 백업합니다.
openBackups|バックアップのフォルダーを開く|Open Backups Folder|打开备份文件夹|백업 폴더 열기
resident|ウインドウを閉じても常駐|Keep running after closing the window|关闭窗口后继续运行|윈도우를 닫아도 계속 실행
residentDetail|閉じた後もDockやメニューバーから再表示できます。オフにすると閉じたときに終了します。|Reopen from the Dock or menu bar. When off, closing the window quits.|可从 Dock 或菜单栏再次打开。关闭此项时，关闭窗口即退出。|Dock 또는 메뉴 막대에서 다시 열 수 있습니다. 끄면 창을 닫을 때 종료됩니다.
launchShortcut|アプリ起動のホットキー|App launch keyboard shortcut|启动应用快捷键|앱 실행 키보드 단축키
openShortcuts|ショートカットを開く|Open Shortcuts|打开快捷指令|단축어 열기
shortcutDetail|ショートカットAppで「アプリを開く」にFavoritesTidyを指定し、キーを割り当ててください。未起動時も使えます。|In Shortcuts, create an Open App action for FavoritesTidy and assign a key. It works even when the app is not running.|在快捷指令中为 FavoritesTidy 创建“打开 App”并分配按键，应用未运行时也可使用。|단축어 앱에서 FavoritesTidy를 여는 동작을 만들고 키를 지정하세요. 앱이 실행 중이 아니어도 작동합니다.
openMainWindow|メインウインドウを開く|Open Main Window|打开主窗口|메인 윈도우 열기
settings|設定…|Settings…|设置…|설정…
settingsWindow|設定|Settings|设置|설정
help|FavoritesTidyヘルプ|FavoritesTidy Help|FavoritesTidy 帮助|FavoritesTidy 도움말
helpMenu|ヘルプ|Help|帮助|도움말
quit|FavoritesTidyを終了|Quit FavoritesTidy|退出 FavoritesTidy|FavoritesTidy 종료
hide|FavoritesTidyを隠す|Hide FavoritesTidy|隐藏 FavoritesTidy|FavoritesTidy 가리기
services|サービス|Services|服务|서비스
hideOthers|ほかを隠す|Hide Others|隐藏其他|기타 가리기
showAll|すべてを表示|Show All|全部显示|모두 보기
about|FavoritesTidyについて|About FavoritesTidy|关于 FavoritesTidy|FavoritesTidy에 관하여
aboutDetail|Default Folder X のお気に入りを並べ替え・カテゴリ分けします。サポート：同梱のREADME.md|Sorts and groups Default Folder X favorites. Support: bundled README.md|对 Default Folder X 的个人收藏排序和分组。支持：内置 README.md|Default Folder X 즐겨찾기를 정렬하고 묶습니다. 지원: 포함된 README.md
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
delete|削除|Delete|删除|삭제
selectAll|すべてを選択|Select All|全选|모두 선택'''
table = [line.split('|') for line in rows.splitlines()]
assert all(len(r) == 5 for r in table), [r[0] for r in table if len(r) != 5]
assert len({r[0] for r in table}) == len(table), 'duplicate key'

# Help text lives in help_text.py (markup rendered by Shared/AppStandards/HelpDocument.swift).
from help_text import HELP
langs = ['ja', 'en', 'zh-Hans', 'ko']

for i, lang in enumerate(langs):
    p = root / 'Resources' / f'{lang}.lproj'
    p.mkdir(parents=True, exist_ok=True)
    (p / 'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0])} = {json.dumps(r[i + 1], ensure_ascii=False)};' for r in table) + '\n')
    (p / 'InfoPlist.strings').write_text('"CFBundleDisplayName" = "FavoritesTidy";\n')
    (p / 'Help.txt').write_text(HELP[lang])
print('resources:', len(table), 'keys x 4 languages')
