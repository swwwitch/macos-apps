#!/usr/bin/env python3
"""Generate CommandDee's ja / en / zh-Hans / ko resources from one table.

Output: Resources/<lang>.lproj/{Localizable.strings, InfoPlist.strings, Help.txt}
Columns: key | Japanese | English | Simplified Chinese | Korean
Japanese is the original UI wording and must stay unchanged.
"""
from pathlib import Path
import json

root = Path(__file__).resolve().parent
LANGS = ['ja', 'en', 'zh-Hans', 'ko']

rows = '''\
menu.about|CommandDeeについて|About CommandDee|关于 CommandDee|CommandDee에 관하여
menu.settings|設定…|Settings…|设置…|설정…
menu.services|サービス|Services|服务|서비스
menu.hide|CommandDeeを隠す|Hide CommandDee|隐藏 CommandDee|CommandDee 가리기
menu.hideOthers|ほかを隠す|Hide Others|隐藏其他|기타 가리기
menu.showAll|すべてを表示|Show All|全部显示|모두 보기
menu.quit|CommandDeeを終了|Quit CommandDee|退出 CommandDee|CommandDee 종료
menu.file|ファイル|File|文件|파일
menu.openMainWindow|メインウインドウを開く|Open Main Window|打开主窗口|메인 윈도우 열기
menu.closeWindow|ウインドウを閉じる|Close Window|关闭窗口|윈도우 닫기
menu.edit|編集|Edit|编辑|편집
menu.undo|取り消す|Undo|撤销|실행 취소
menu.redo|やり直す|Redo|重做|실행 복귀
menu.cut|カット|Cut|剪切|오려두기
menu.copy|コピー|Copy|拷贝|복사하기
menu.paste|ペースト|Paste|粘贴|붙여넣기
menu.selectAll|すべてを選択|Select All|全选|모두 선택
menu.window|ウインドウ|Window|窗口|윈도우
menu.minimize|しまう|Minimize|最小化|최소화
menu.zoom|拡大／縮小|Zoom|缩放|확대/축소
menu.bringAllToFront|すべてを手前に移動|Bring All to Front|前置全部窗口|모두 앞으로 가져오기
menu.help|ヘルプ|Help|帮助|도움말
menu.appHelp|CommandDeeヘルプ|CommandDee Help|CommandDee 帮助|CommandDee 도움말
shortcut.palette|パレットを表示／隠す|Show / Hide Palette|显示／隐藏面板|팔레트 보기/가리기
menu.showPalette|パレットを表示|Show Palette|显示面板|팔레트 보기
menu.hidePalette|パレットを隠す|Hide Palette|隐藏面板|팔레트 가리기
palette.subtitle|実行後の名前を確かめてからクリック|Check the resulting name, then click|确认结果名称后再点击|결과 이름을 확인한 후 클릭
palette.noSelection|Finder／Path Finderで項目を選択してください|Select items in Finder or Path Finder|请在 Finder／Path Finder 中选择项目|Finder／Path Finder에서 항목을 선택하세요
palette.selection|%1$@（%2$@）|%1$@ (%2$@)|%1$@（%2$@）|%1$@(%2$@)
palette.selectionMore|%1$@ ほか%2$d項目（%3$@）|%1$@ and %2$d more (%3$@)|%1$@ 及其他 %2$d 项（%3$@）|%1$@ 외 %2$d개(%3$@)
palette.more|ほか%d項目|+%d more|另 %d 项|외 %d개
palette.alreadyToday|変更なし（今日の日付付き）|No change (already has today's date)|无变化（已有今天的日期）|변경 없음(이미 오늘 날짜 있음)
palette.alreadyEdited|変更なし（edited付き）|No change (already marked edited)|无变化（已有 edited）|변경 없음(이미 edited 있음)
palette.swapNeedsTwo|同じフォルダの2項目を選ぶと使えます|Select 2 items in the same folder|请选择同一文件夹中的 2 个项目|같은 폴더의 항목 2개를 선택하세요
menu.enableShortcuts|ホットキーを有効にする|Enable Shortcuts|启用快捷键|단축키 활성화
status.initial|ファイル／フォルダを選択して ⌘D|Select files or folders and press ⌘D|选择文件或文件夹后按 ⌘D|파일 또는 폴더를 선택하고 ⌘D를 누르세요
status.tooltip|CommandDee — バージョン・日付付きで複製|CommandDee — Duplicate with a version or date|CommandDee — 添加版本号或日期并复制|CommandDee — 버전 또는 날짜를 붙여 복제
status.noSelection|ファイル／フォルダが選択されていません|No files or folders are selected|未选择文件或文件夹|선택된 파일 또는 폴더가 없습니다
status.selectionFailed|選択の取得に失敗しました|Could not get the selection|无法获取所选项目|선택 항목을 가져오지 못했습니다
status.needsAccessibility|アクセシビリティの許可が必要です|Accessibility permission is required|需要辅助功能权限|손쉬운 사용 권한이 필요합니다
status.enabled|ホットキー有効|Shortcuts enabled|快捷键已启用|단축키 활성화됨
status.paused|一時停止中|Paused|已暂停|일시 정지됨
progress.duplicate|%d項目を複製中…|Duplicating %d items…|正在复制 %d 个项目…|%d개 항목 복제 중…
progress.rename|%d項目を名前変更中…|Renaming %d items…|正在重命名 %d 个项目…|%d개 항목 이름 변경 중…
progress.swap|%d項目を名前入れ替え中…|Swapping the names of %d items…|正在交换 %d 个项目的名称…|%d개 항목 이름 교환 중…
done.duplicate|%d項目を複製しました|Duplicated %d items|已复制 %d 个项目|%d개 항목을 복제했습니다
done.rename|%d項目を名前変更しました|Renamed %d items|已重命名 %d 个项目|%d개 항목의 이름을 변경했습니다
done.swap|%d項目を名前入れ替えしました|Swapped the names of %d items|已交换 %d 个项目的名称|%d개 항목의 이름을 교환했습니다
done.skipped|・%d項目は今日の日付のためスキップ|; skipped %d items already dated today|；已跳过 %d 个带有今天日期的项目| · 오늘 날짜가 붙은 %d개 항목은 건너뜀
partial.duplicate|%1$d項目を複製・%2$d項目でエラー|Duplicated %1$d items; %2$d failed|已复制 %1$d 个项目，%2$d 个项目出错|%1$d개 항목 복제, %2$d개 항목 오류
partial.rename|%1$d項目を名前変更・%2$d項目でエラー|Renamed %1$d items; %2$d failed|已重命名 %1$d 个项目，%2$d 个项目出错|%1$d개 항목 이름 변경, %2$d개 항목 오류
partial.swap|%1$d項目を名前入れ替え・%2$d項目でエラー|Swapped the names of %1$d items; %2$d failed|已交换 %1$d 个项目的名称，%2$d 个项目出错|%1$d개 항목 이름 교환, %2$d개 항목 오류
alert.busyQuit|処理中です。完了してから終了してください。|Processing is in progress. Quit after it finishes.|正在处理。请在完成后再退出。|처리 중입니다. 완료된 후 종료하세요.
alert.failed|処理を完了できませんでした|The operation could not be completed|无法完成操作|작업을 완료할 수 없습니다
help.heading|ファイルの複製と名前変更|Duplicate and Rename Files|复制和重命名文件|파일 복제 및 이름 변경
help.subtitle|選択した項目にバージョン番号や日付を付ける。|Add a version number or date to the selected items.|为所选项目添加版本号或日期。|선택한 항목에 버전 번호나 날짜를 붙입니다.
help.openAccessibility|アクセシビリティ設定を開く|Open Accessibility Settings|打开辅助功能设置|손쉬운 사용 설정 열기
settings.title|設定|Settings|设置|설정
settings.hotkeys|ホットキー|Hotkeys|快捷键|단축키
settings.fileNames|ファイル名|File Names|文件名|파일 이름
settings.actionShortcuts|機能のホットキー|Action Shortcuts|功能快捷键|기능 단축키
settings.keyboardShortcuts|ホットキー|Keyboard Shortcuts|键盘快捷键|키보드 단축키
settings.suffixOrder|接尾辞の並び順|Suffix order|后缀顺序|접미사 순서
settings.separator|区切り文字|Separator|分隔符|구분 문자
settings.separatorHyphen|ハイフン（-）|Hyphen (-)|连字符（-）|하이픈(-)
settings.separatorUnderscore|アンダースコア（_）|Underscore (_)|下划线（_）|밑줄(_)
settings.skipFolder|読み飛ばす親フォルダ名|Parent folder name to skip|要跳过的父文件夹名称|건너뛸 상위 폴더 이름
settings.skipFolderPlaceholder|空欄の場合は、直上の親フォルダ名を使用|If empty, the name of the immediate parent folder is used|留空时使用直接上级文件夹的名称|비워 두면 바로 위 상위 폴더 이름을 사용
settings.resetSkipFolder|ログインユーザー名に戻す|Reset to Login User Name|恢复为登录用户名|로그인 사용자 이름으로 재설정
settings.resetShortcuts|ホットキーを初期値に戻す|Restore Default Shortcuts|恢复默认快捷键|기본 단축키로 복원
settings.shortcutInvalid|このキーは使えません。⌘・⌃・⌥のいずれかと組み合わせてください（Escでキャンセル）|This key can’t be used. Combine it with ⌘, ⌃, or ⌥ (Esc to cancel).|无法使用此键。请与 ⌘、⌃ 或 ⌥ 组合使用（按 Esc 取消）。|이 키는 사용할 수 없습니다. ⌘, ⌃, ⌥ 중 하나와 함께 누르십시오(Esc로 취소).
settings.shortcutDuplicate|「%@」はほかの操作に割り当て済みです|“%@” is already assigned to another action.|“%@”已分配给其他操作。|“%@”은(는) 이미 다른 동작에 지정되어 있습니다.
settings.recordShortcut|キーを入力（Escでキャンセル）|Type a shortcut (Esc to cancel)|按下快捷键（按 Esc 取消）|키 입력(Esc로 취소)
shortcut.unset|未設定|Not Set|未设置|설정 안 됨
shortcut.version|連番で複製|Duplicate with next version|复制并递增版本号|다음 버전으로 복제
shortcut.date|日付付きで複製|Duplicate with date|复制并添加日期|날짜를 붙여 복제
shortcut.renameDate|日付付き（名前変更）|Add date (rename)|添加日期（重命名）|날짜 붙이기(이름 변경)
shortcut.edited|edited付きで複製|Duplicate with “edited”|复制并添加 edited|edited를 붙여 복제
shortcut.parent|親フォルダ名を付け外し|Add/remove parent folder name|添加/移除父文件夹名称|상위 폴더 이름 추가/제거
shortcut.swapNames|2項目の名前を入れ替え|Swap names of 2 items|交换 2 个项目的名称|두 항목의 이름 교환
error.automation|システム設定 → プライバシーとセキュリティ → オートメーションで、CommandDeeによるFinder／Path Finderの操作を許可してください。|In System Settings → Privacy & Security → Automation, allow CommandDee to control Finder / Path Finder.|请在“系统设置”→“隐私与安全性”→“自动化”中允许 CommandDee 控制 Finder／Path Finder。|시스템 설정 → 개인정보 보호 및 보안 → 자동화에서 CommandDee가 Finder／Path Finder를 제어하도록 허용하세요.
error.selection|選択ファイルを取得できませんでした。|Could not get the selected files.|无法获取所选文件。|선택한 파일을 가져올 수 없습니다.
error.swapCount|名前の入れ替えは、同じフォルダの2項目を選択してください。|To swap names, select 2 items in the same folder.|要交换名称，请选择同一文件夹中的 2 个项目。|이름을 교환하려면 같은 폴더에 있는 두 항목을 선택하세요.
error.swapDistinct|同じフォルダにある、異なる2項目を選択してください。|Select 2 different items in the same folder.|请选择同一文件夹中的 2 个不同项目。|같은 폴더에 있는 서로 다른 두 항목을 선택하세요.
error.swapSameItem|同じ実体を指す2項目は入れ替えできません。|Two items that refer to the same file cannot be swapped.|指向同一实体的 2 个项目无法交换。|같은 실체를 가리키는 두 항목은 교환할 수 없습니다.
error.swapKind|同じ種類の2項目を選択してください（ファイル同士、フォルダ同士）。|Select 2 items of the same kind (2 files or 2 folders).|请选择 2 个同类项目（均为文件或均为文件夹）。|같은 종류의 두 항목을 선택하세요(파일끼리 또는 폴더끼리).
error.swapFailed|名前を入れ替えできませんでした。変更は行っていません。|Could not swap the names. Nothing was changed.|无法交换名称。未做任何更改。|이름을 교환할 수 없습니다. 아무것도 변경하지 않았습니다.
error.noParentName|親フォルダ名を取得できません。|Could not get the parent folder name.|无法获取父文件夹名称。|상위 폴더 이름을 가져올 수 없습니다.
error.emptyName|親フォルダ名を外すとファイル名が空になるため、処理できません。|Removing the parent folder name would leave an empty file name, so the item was not processed.|移除父文件夹名称后文件名将为空，因此无法处理。|상위 폴더 이름을 제거하면 파일 이름이 비게 되므로 처리할 수 없습니다.
error.renameExists|「%@」がすでに存在するため名前を変更しませんでした。既存ファイルは上書きしていません。|“%@” already exists, so the item was not renamed. The existing file was not overwritten.|“%@”已存在，因此未重命名。未覆盖现有文件。|“%@” 항목이 이미 있어 이름을 변경하지 않았습니다. 기존 파일은 덮어쓰지 않았습니다.
error.copyExists|「%@」がすでに存在するため複製しませんでした。既存ファイルは上書きしていません。|“%@” already exists, so the item was not duplicated. The existing file was not overwritten.|“%@”已存在，因此未复制。未覆盖现有文件。|“%@” 항목이 이미 있어 복제하지 않았습니다. 기존 파일은 덮어쓰지 않았습니다.
error.versionTooLarge|バージョン番号が大きすぎるため、次の番号を作成できません。|The version number is too large to create the next one.|版本号过大，无法创建下一个版本号。|버전 번호가 너무 커서 다음 번호를 만들 수 없습니다.
error.versionNext|次のバージョン番号を作成できません。|Could not create the next version number.|无法创建下一个版本号。|다음 버전 번호를 만들 수 없습니다.
'''

# Help.txt: one document rendered by HelpDocument (## section, ### subsection, - bullets, **bold**, ※ note).
# Every language keeps the same ## / ### structure (test.sh checks the counts).
help_texts = {
'ja': '''Finder／Path Finderで選択したファイルやフォルダに、バージョン番号や日付を付けて複製・名前変更するメニューバー常駐アプリです。

## 基本操作
1. Finder／Path Finderでファイルやフォルダを選択します。複数選択・フォルダにも対応します。
2. 次のホットキーを押します。

### 複製と名前変更
- **⌘D**：連番で複製（同じフォルダの最大バージョン番号＋1）
- **⌃D**：複製せず、末尾に今日の日付を追加・更新して名前変更
- **⌃⌘D**：末尾に今日の日付を追加・更新して複製
- **⌃⌘E**：末尾に -edited を追加して複製（日付や番号はそのまま）
- **⌃F**：末尾の -親フォルダ名 を付け外しして名前変更
- **⌃⌘S**：同じフォルダで選んだ2項目の名前を入れ替え

⌃は複製せずに名前を変え、⌘・⌃⌘は複製します（⌃⌘Sは名前の入れ替え）。D＝date（日付）、E＝edited／edit、F＝folder（親フォルダ）、S＝switch（入れ替え）。

### パレット
- ⌃⌥⌘D（どのアプリからでも）か、メニューバーのアイコンの「パレットを表示」で、各操作のボタンを並べたパレットが開きます。もう一度⌃⌥⌘Dを押すと隠れます。キーは設定で変更できます。
- Finder／Path Finderで選んでいる項目について、各ボタンに実行後の名前を表示します（変わる部分を色付き）。複数選択では先頭の項目を表示し、ボタンにポインタを置くと全項目の結果を確認できます。
- パレットはほかのアプリの前面に表示されたままで、クリックしてもFinderの選択は外れません。

### アプリの操作
- **⌘0**：メインウインドウを開く
- **⌘,**：設定
- **⌘W**：ウインドウを閉じる
- **⌘Q**：CommandDeeを終了（このアプリの画面で）

## 例
- **⌘D**：v2・v5 がある場合 → v6（欠番は無視）
- **⌃D**：aaa.txt → aaa-YYYYMMDD.txt（名前変更）
- **⌃⌘D**：aaa.txt → aaa-YYYYMMDD.txt（複製）
- **⌃⌘E**：aaa.txt → aaa-edited.txt

## 複製と名前変更のルール
- 拡張子を維持し、元ファイルや既存のコピーは上書きしません。
- 末尾の日付は6桁・8桁とも認識し、8桁に更新します。
- 今日の日付が付いた項目はスキップします（⌃D・⌃⌘D）。edited が付いた項目は ⌃⌘E でスキップします。
- 別の同名項目がある場合は処理せず、お知らせします。

### 名前の入れ替え
- ファイル同士・フォルダ同士で実行します。
- 名前全体（拡張子を含む）を交換し、内容と更新日時は各項目に保持します。
- 最大番号や更新日時での自動判定はしません。
- 戻すには、同じ2項目を選んで再実行します。

## 設定
メニューバーのアイコンから「設定…」（⌘,）を選びます。
- **区切り文字**：接尾辞（v番号・edited・日付・親フォルダ名）の前に付ける文字を、ハイフン（-）かアンダースコア（_）から選べます。v番号・edited・日付は選んだ文字で区切られたものだけを読み取ります。親フォルダ名はどちらで付いていても外せます。
- **接尾辞の並び順**：v番号・edited・日付の順番を選べます。既存の名前も読み取り、次の操作から指定順で出力します。
- **機能のホットキー**：ボタンを押して、修飾キーと文字キーを入力すると変更できます。Escでキャンセル。同じ組み合わせは重複して登録できません。
- **読み飛ばす親フォルダ名**：完全一致で上の階層を参照します。空欄で無効化できます。

## アクセス許可
- 初回はアクセシビリティを許可してください。このウインドウの「アクセシビリティ設定を開く」から設定を開けます。
- 操作時に表示される、Finder／Path Finderの操作許可も必要です。

## 常駐と終了
- ウインドウを閉じても、メニューバーに常駐します。
- 終了するには、このアプリの画面で⌘Qを押すか、メニューバーのアイコンから「CommandDeeを終了」を選びます。

## ヘルプとnote記事
- このヘルプは、メニューバーのアイコンの「ヘルプ」から「CommandDeeヘルプ」を選ぶと開きます。ヘルプメニューの「CommandDeeヘルプ」（⌘?）でも開けます。
- 同じ「ヘルプ」の「note記事を開く」で、noteの解説記事をブラウザで開きます。

## アップデートとメニューバー
- アプリメニューの「アップデートを確認…」「アップデートを自動確認」は、更新の配信先と署名鍵が設定されるまで準備中と表示し、通信しません。
- アプリメニューの「メニューバー設定…」で、メニューバーのアイコンを表示するかを切り替えます。非表示でもアプリは終了しません。''',
'en': '''A menu bar app that duplicates or renames the files and folders selected in Finder / Path Finder, adding a version number or date.

## Basic Use
1. Select files or folders in Finder / Path Finder. Multiple items and folders are supported.
2. Press one of the shortcuts below.

### Duplicate and Rename
- **⌘D**: duplicate with the next version (the highest version number in the folder + 1)
- **⌃D**: rename without duplicating, adding or updating today's date at the end
- **⌃⌘D**: duplicate, adding or updating today's date at the end
- **⌃⌘E**: duplicate, adding -edited at the end (the date and version stay as they are)
- **⌃F**: rename by adding or removing -parent folder name at the end
- **⌃⌘S**: swap the names of 2 items selected in the same folder

⌃ renames without duplicating; ⌘ and ⌃⌘ duplicate (⌃⌘S swaps names). D = date, E = edited / edit, F = folder, S = switch.

### Palette
- Press ⌃⌥⌘D in any app, or choose Show Palette from the menu bar icon, to open a palette with a button for each action. Press ⌃⌥⌘D again to hide it. You can change the key in Settings.
- For the items selected in Finder or Path Finder, each button shows the resulting name, with the changed part in color. With several items, the first one is shown; hold the pointer over a button to see the result for every item.
- The palette stays in front of other apps, and clicking it does not change the Finder selection.

### App Commands
- **⌘0**: Open Main Window
- **⌘,**: Settings
- **⌘W**: Close Window
- **⌘Q**: Quit CommandDee (in this app's window)

## Examples
- **⌘D**: v2 and v5 exist → v6 (gaps are ignored)
- **⌃D**: aaa.txt → aaa-YYYYMMDD.txt (rename)
- **⌃⌘D**: aaa.txt → aaa-YYYYMMDD.txt (duplicate)
- **⌃⌘E**: aaa.txt → aaa-edited.txt

## Duplicate and Rename Rules
- Extensions are kept, and neither the original nor existing copies are overwritten.
- A trailing 6- or 8-digit date is recognized and updated to 8 digits.
- Items already dated today are skipped (⌃D, ⌃⌘D). Items already marked "edited" are skipped by ⌃⌘E.
- If another item with the same name exists, nothing is changed and you are notified.

### Swapping Names
- Works between 2 files or 2 folders.
- The full names (including extensions) are exchanged, while each item keeps its contents and modification date.
- There is no automatic decision based on the highest number or modification date.
- To undo, select the same 2 items and run it again.

## Settings
Choose Settings… (⌘,) from the menu bar icon.
- **Separator**: choose a hyphen (-) or an underscore (_) before each suffix (version number, "edited", date, parent folder name). Version numbers, "edited" and dates are read only after the chosen separator; a parent folder name is removed after either one.
- **Suffix order**: choose the order of the version number, "edited" and the date. Existing names are read as well, and the next operation writes them in the chosen order.
- **Action Shortcuts**: click a button and type a modifier key with a character key to change it. Press Esc to cancel. A combination that is already in use cannot be assigned twice.
- **Parent folder name to skip**: uses an exact match and refers to the folder above. Leave the field empty to turn it off.

## Permissions
- On first use, allow Accessibility. Click Open Accessibility Settings in this window to open the settings.
- You also need to allow control of Finder / Path Finder when macOS asks.

## Running in the Background and Quitting
- CommandDee stays in the menu bar after you close the window.
- To quit, press ⌘Q in this app's window, or choose Quit CommandDee from the menu bar icon.

## Help and the note Article
- To open this help, choose Help > CommandDee Help from the menu bar icon. You can also choose CommandDee Help (⌘?) in the Help menu.
- Choose Open the note Article in the same Help submenu to read the article on note in your browser.

## Updates and the Menu Bar
- Check for Updates… and Automatically Check for Updates in the app menu show that updates are not configured, and make no network access, until an update feed and signing key are set up.
- Choose Menu Bar Settings… in the app menu to show or hide the menu bar icon. Hiding it does not quit the app.''',
'zh-Hans': '''一款常驻菜单栏的应用，可为在 Finder／Path Finder 中选择的文件和文件夹添加版本号或日期并复制或重命名。

## 基本操作
1. 在 Finder／Path Finder 中选择文件或文件夹。支持多选和文件夹。
2. 按下以下快捷键。

### 复制与重命名
- **⌘D**：复制并递增版本号（同一文件夹中最大的版本号 + 1）
- **⌃D**：不复制，在末尾添加或更新今天的日期并重命名
- **⌃⌘D**：在末尾添加或更新今天的日期并复制
- **⌃⌘E**：在末尾添加 -edited 并复制（日期和版本号保持不变）
- **⌃F**：添加或移除末尾的 -父文件夹名称 并重命名
- **⌃⌘S**：交换在同一文件夹中所选 2 个项目的名称

⌃ 不复制直接重命名，⌘ 和 ⌃⌘ 会复制（⌃⌘S 为交换名称）。D = date（日期），E = edited / edit，F = folder（父文件夹），S = switch（交换）。

### 面板
- 在任意应用中按 ⌃⌥⌘D，或从菜单栏图标选择“显示面板”，会打开排列着各操作按钮的面板。再次按 ⌃⌥⌘D 即可隐藏。可在设置中更改按键。
- 针对在 Finder／Path Finder 中选中的项目，每个按钮会显示执行后的名称（变化部分以颜色标出）。选择多个项目时显示第一个项目，将指针悬停在按钮上可查看所有项目的结果。
- 面板始终显示在其他应用前面，点击它不会改变 Finder 中的选择。

### 应用操作
- **⌘0**：打开主窗口
- **⌘,**：设置
- **⌘W**：关闭窗口
- **⌘Q**：退出 CommandDee（在本应用的窗口中）

## 示例
- **⌘D**：已有 v2 和 v5 → v6（忽略缺号）
- **⌃D**：aaa.txt → aaa-YYYYMMDD.txt（重命名）
- **⌃⌘D**：aaa.txt → aaa-YYYYMMDD.txt（复制）
- **⌃⌘E**：aaa.txt → aaa-edited.txt

## 复制与重命名规则
- 保留扩展名，不覆盖原文件或已有的副本。
- 末尾的 6 位和 8 位日期均可识别，并更新为 8 位。
- 已带有今天日期的项目会被跳过（⌃D、⌃⌘D）。已带有 edited 的项目在 ⌃⌘E 时会被跳过。
- 如果已有其他同名项目，则不处理并给出提示。

### 交换名称
- 适用于 2 个文件或 2 个文件夹之间。
- 交换完整名称（包括扩展名），各项目的内容和修改日期保持不变。
- 不会根据最大版本号或修改日期自动判断。
- 要恢复，请选择相同的 2 个项目再次执行。

## 设置
在菜单栏图标中选择“设置…”（⌘,）。
- **分隔符**：可选择在后缀（版本号、edited、日期、父文件夹名称）前使用连字符（-）或下划线（_）。版本号、edited 和日期只读取以所选分隔符分隔的部分；父文件夹名称无论用哪种分隔符都可移除。
- **后缀顺序**：可选择版本号、edited 和日期的顺序。也会读取现有名称，从下一次操作起按指定顺序输出。
- **功能快捷键**：点击按钮，然后按下修饰键和字符键即可更改。按 Esc 取消。不能重复登记相同的组合。
- **要跳过的父文件夹名称**：按完全一致匹配并参照上一级文件夹。留空即可停用。

## 权限
- 首次使用时请允许辅助功能权限。可点击本窗口中的“打开辅助功能设置”打开设置。
- 操作时 macOS 询问的 Finder／Path Finder 控制权限也需要允许。

## 后台运行与退出
- 关闭窗口后，应用仍常驻菜单栏。
- 要退出，请在本应用的窗口中按 ⌘Q，或在菜单栏图标中选择“退出 CommandDee”。

## 帮助与 note 文章
- 在菜单栏图标的“帮助”中选择“CommandDee 帮助”即可打开本帮助。也可在帮助菜单中选择“CommandDee 帮助”（⌘?）。
- 在同一“帮助”子菜单中选择“打开 note 文章”，即可在浏览器中阅读 note 上的介绍文章。

## 更新与菜单栏
- 在配置更新源和签名密钥之前，应用菜单中的“检查更新…”和“自动检查更新”会显示尚未配置，且不会进行网络通信。
- 在应用菜单中选择“菜单栏设置…”，可切换是否在菜单栏中显示图标。隐藏图标不会退出应用。''',
'ko': '''Finder／Path Finder에서 선택한 파일과 폴더에 버전 번호나 날짜를 붙여 복제하거나 이름을 변경하는 메뉴 막대 앱입니다.

## 기본 조작
1. Finder／Path Finder에서 파일이나 폴더를 선택합니다. 여러 항목 선택과 폴더도 지원합니다.
2. 다음 단축키를 누릅니다.

### 복제와 이름 변경
- **⌘D**: 다음 버전으로 복제(같은 폴더의 가장 큰 버전 번호 + 1)
- **⌃D**: 복제하지 않고 끝에 오늘 날짜를 추가 또는 갱신하여 이름 변경
- **⌃⌘D**: 끝에 오늘 날짜를 추가 또는 갱신하여 복제
- **⌃⌘E**: 끝에 -edited를 추가하여 복제(날짜와 버전 번호는 그대로)
- **⌃F**: 끝의 -상위 폴더 이름을 추가하거나 제거하여 이름 변경
- **⌃⌘S**: 같은 폴더에서 선택한 두 항목의 이름 교환

⌃는 복제하지 않고 이름을 바꾸고, ⌘·⌃⌘는 복제합니다(⌃⌘S는 이름 교환). D = date(날짜), E = edited / edit, F = folder(상위 폴더), S = switch(교환).

### 팔레트
- 어느 앱에서든 ⌃⌥⌘D를 누르거나 메뉴 막대 아이콘에서 '팔레트 보기'를 선택하면 각 동작의 버튼이 나열된 팔레트가 열립니다. ⌃⌥⌘D를 다시 누르면 가려집니다. 키는 설정에서 변경할 수 있습니다.
- Finder／Path Finder에서 선택한 항목에 대해 각 버튼에 실행 후의 이름을 표시합니다(바뀌는 부분은 색으로 표시). 여러 항목을 선택하면 첫 번째 항목을 표시하며, 버튼 위에 포인터를 올리면 모든 항목의 결과를 볼 수 있습니다.
- 팔레트는 다른 앱 앞에 계속 표시되며, 클릭해도 Finder의 선택이 바뀌지 않습니다.

### 앱 조작
- **⌘0**: 메인 윈도우 열기
- **⌘,**: 설정
- **⌘W**: 윈도우 닫기
- **⌘Q**: CommandDee 종료(이 앱의 윈도우에서)

## 예
- **⌘D**: v2와 v5가 있는 경우 → v6(빠진 번호는 무시)
- **⌃D**: aaa.txt → aaa-YYYYMMDD.txt (이름 변경)
- **⌃⌘D**: aaa.txt → aaa-YYYYMMDD.txt (복제)
- **⌃⌘E**: aaa.txt → aaa-edited.txt

## 복제와 이름 변경 규칙
- 확장자를 유지하며 원본 파일이나 기존 사본을 덮어쓰지 않습니다.
- 끝의 6자리·8자리 날짜를 모두 인식하고 8자리로 갱신합니다.
- 오늘 날짜가 붙은 항목은 건너뜁니다(⌃D, ⌃⌘D). edited가 붙은 항목은 ⌃⌘E에서 건너뜁니다.
- 같은 이름의 다른 항목이 있으면 처리하지 않고 알려 줍니다.

### 이름 교환
- 파일끼리 또는 폴더끼리 실행합니다.
- 전체 이름(확장자 포함)을 교환하며 내용과 수정일은 각 항목에 그대로 유지합니다.
- 가장 큰 번호나 수정일로 자동 판단하지 않습니다.
- 되돌리려면 같은 두 항목을 선택하고 다시 실행합니다.

## 설정
메뉴 막대 아이콘에서 ‘설정…’(⌘,)을 선택합니다.
- **구분 문자**: 접미사(버전 번호, edited, 날짜, 상위 폴더 이름) 앞에 붙일 문자를 하이픈(-) 또는 밑줄(_) 중에서 선택할 수 있습니다. 버전 번호, edited, 날짜는 선택한 문자로 구분된 것만 읽습니다. 상위 폴더 이름은 어느 쪽으로 붙어 있어도 제거할 수 있습니다.
- **접미사 순서**: 버전 번호, edited, 날짜의 순서를 선택할 수 있습니다. 기존 이름도 읽어 다음 작업부터 지정한 순서로 출력합니다.
- **기능 단축키**: 버튼을 누른 후 보조 키와 문자 키를 입력하면 변경할 수 있습니다. Esc로 취소합니다. 같은 조합은 중복 등록할 수 없습니다.
- **건너뛸 상위 폴더 이름**: 완전히 일치할 때 위 단계의 폴더를 참조합니다. 비워 두면 사용하지 않습니다.

## 권한
- 처음 사용할 때 손쉬운 사용 권한을 허용하세요. 이 윈도우의 ‘손쉬운 사용 설정 열기’로 설정을 열 수 있습니다.
- 작업 시 표시되는 Finder／Path Finder 제어 허용도 필요합니다.

## 백그라운드 실행과 종료
- 윈도우를 닫아도 메뉴 막대에 상주합니다.
- 종료하려면 이 앱의 윈도우에서 ⌘Q를 누르거나 메뉴 막대 아이콘에서 ‘CommandDee 종료’를 선택합니다.

## 도움말과 note 글
- 메뉴 막대 아이콘의 ‘도움말’에서 ‘CommandDee 도움말’을 선택하면 이 도움말이 열립니다. 도움말 메뉴의 ‘CommandDee 도움말’(⌘?)로도 열 수 있습니다.
- 같은 ‘도움말’ 하위 메뉴의 ‘note 글 열기’를 선택하면 note의 소개 글을 브라우저에서 엽니다.

## 업데이트와 메뉴 막대
- 앱 메뉴의 ‘업데이트 확인…’과 ‘자동으로 업데이트 확인’은 업데이트 배포처와 서명 키가 설정될 때까지 준비 중으로 표시되며 통신하지 않습니다.
- 앱 메뉴의 ‘메뉴 막대 설정…’에서 메뉴 막대 아이콘의 표시 여부를 전환합니다. 숨겨도 앱은 종료되지 않습니다.''',
}

info_plist = {
    'NSAppleEventsUsageDescription': [
        'Finder／Path Finderで選択したファイルやフォルダを取得し、複製または名前変更します。',
        'CommandDee gets the files and folders selected in Finder / Path Finder to duplicate or rename them.',
        'CommandDee 获取在 Finder／Path Finder 中选择的文件和文件夹，以便复制或重命名。',
        'CommandDee가 Finder／Path Finder에서 선택한 파일과 폴더를 가져와 복제하거나 이름을 변경합니다.',
    ],
}

table = [line.split('|') for line in rows.splitlines() if line.strip()]
assert all(len(r) == 5 for r in table), [r for r in table if len(r) != 5]
assert len({r[0] for r in table}) == len(table), 'duplicate key'
assert all(len(v) == 4 for v in info_plist.values())
assert len({tuple(l.split(' ', 1)[0] for l in t.splitlines() if l.startswith('#')) for t in help_texts.values()}) == 1, 'Help.txt heading structure differs'
assert not any(l.startswith('# ') for t in help_texts.values() for l in t.splitlines()), 'no # title line'


def strings_line(key, value):
    return f'{json.dumps(key)} = {json.dumps(value, ensure_ascii=False)};'


for i, lang in enumerate(LANGS, 1):
    folder = root / 'Resources' / f'{lang}.lproj'
    folder.mkdir(parents=True, exist_ok=True)
    (folder / 'Localizable.strings').write_text('\n'.join(strings_line(r[0], r[i]) for r in table) + '\n', encoding='utf-8')
    (folder / 'InfoPlist.strings').write_text('\n'.join(strings_line(k, v[i - 1]) for k, v in info_plist.items()) + '\n', encoding='utf-8')
    (folder / 'Help.txt').write_text(help_texts[lang] + '\n', encoding='utf-8')
