# FavoritesTidy help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
FavoritesTidyは、Default Folder X のお気に入り（Favorites.plist）を読み込み、並べ替えや区切り線によるカテゴリ分けをして書き戻します。
- 並べ替え：［並べ替え］メニューから名前順・名前の逆順・場所（パス）順・追加日の新しい順／古い順を選びます。何も選択していなければすべてのカテゴリの中で、項目を選択していればその項目があるカテゴリの中だけで並べ替えます。区切り線の位置は変わりません。
- 検索：上部の検索窓（⌘F）に入力すると、名前かパスに含むお気に入りだけを表示します。空白で区切ると、すべての語を含むものに絞ります。Esc か ⓧ で消去します。検索中はドラッグでの並べ替えはできません（並べ替えメニューや移動は使えます）。
- Dropbox：Dropbox のフォルダー内にあるお気に入りには青い「Dropbox」の印を付け、パスは Dropbox のフォルダーからの位置で表示します（マウスを置くと完全なパス）。
- ドラッグ：行をドラッグして順番を変えます。複数選択（⌘＋クリック、⇧＋クリック）してまとめて動かせます。
- 区切り線を追加（⇧⌘N）：選択した行の下（選択がなければ末尾）に区切り線を入れます。区切り線から次の区切り線までが1つのカテゴリです。
- カテゴリの名前：見出しをクリックして名前を入力します。Default Folder X の区切り線には名前を付けられないため、名前はこのアプリの中だけで使います。
- カテゴリへ移動：選択した項目を、選んだカテゴリの末尾へ移動します。行を右クリックしても選べます。
- カテゴリを上へ／下へ移動：見出しを右クリックすると、カテゴリをまるごと移動できます。
- 削除：行を選んで⌫を押すと、お気に入りや区切り線を削除します。区切り線を削除すると、前のカテゴリと結合します。
- ⌘Z で取り消し、⇧⌘Z でやり直しができます（保存するまで）。
- フォルダーが見つからない項目には ⚠ が付きます。行を右クリックすると［Finderで表示］［パスをコピー］が使えます。
- ホットキー：右端に Default Folder X で割り当てたホットキーを表示します。クリック（または行を選んで⌘K、右クリックの［ホットキーを変更…］）すると変更・解除できます。⌘ か ⌃ を含むキーだけ割り当てられ、ほかのお気に入りと同じキーは使えません。保存すると Default Folder X に反映されます。
- Default Folder X を終了／起動：下のボタンで Default Folder X を終了・起動できます。Default Folder X の起動中は、それが使っているキーを記録しようとするとそちらが反応することがあるので、終了してから記録してください。ここで終了した Default Folder X は、保存するか FavoritesTidy を終了すると起動し直します。

## Default Folder X の起動中の編集
Default Folder X の起動中に、並べ替え・ドラッグ・区切り線・移動・削除・ホットキーの変更をしようとすると、Default Folder X を終了するか確認します。［終了して編集］を選ぶと終了してから編集します。［キャンセル］では何も変えません。カテゴリの名前はこのアプリの中だけの情報なので、確認なしで編集できます。

## 保存
［保存］（⌘S）で Favorites.plist に書き込みます。Default Folder X は終了するときにお気に入りを書き出すため、起動中に書き込むと終了時に上書きされてしまいます。そのため保存では次の順に処理します。
- Default Folder X を終了する
- 終了時に書き出されたお気に入りが、読み込んだときと同じか確かめる（Default Folder X 側で変更されていたら保存を中止します）
- 保存前のファイルをバックアップする
- 書き込む
- Default Folder X を起動し直す
Default Folder X の設定で「常に名前順に並べる」がオンのときは、ここで決めた並び順はメニューに反映されません。画面に警告が出ます。
フォルダセットが複数あるときは、上のメニューで切り替えます（保存していない変更があるときは切り替えられません）。

## 元に戻す
保存の直前の Favorites.plist を、最新30件まで次のフォルダーにバックアップします。
~/Library/Application Support/FavoritesTidy/Backups
戻すには、Default Folder X を終了してから、バックアップのファイルを Favorites.plist という名前で元の場所（~/Library/Application Support/com.stclairsoft.DefaultFolderX5/フォルダセット名/）にコピーし、Default Folder X を起動します。設定の［一般］の「バックアップのフォルダーを開く」からも開けます。

## 設定
［FavoritesTidy］＞［設定…］（⌘,）で開きます。
- 起動・常駐：ログイン時に起動、Dockとアプリケーションスイッチャーに表示しない、ウインドウを閉じても常駐、メニューバーのアイコン、アプリ起動のホットキー。
- 一般：「保存の前に確認する」（初期値オン）。オンのとき、Default Folder X の起動中に保存すると、終了と起動し直しの確認を出します。バックアップのフォルダーを開くボタン。
- 設定の共有：カテゴリの名前と「保存の前に確認する」の書き出し・読み込みと同期。
- 情報：バージョンとリンク。

## ホットキー
- ⌘S：保存
- ⌘R：読み直す
- ⇧⌘N：区切り線を追加
- ⌘F：検索
- ⌘K：選択したお気に入りのホットキーを変更
- ⌫：選択した項目を削除
- ⌘Z／⇧⌘Z：取り消す／やり直す
- ⌘0：メインウインドウを開く
- ⌘,：設定
- ⌘W：ウインドウを閉じる
- ⌘?：このヘルプ
FavoritesTidyを未起動のときから呼び出すには、設定の「アプリ起動のホットキー」の説明に従い、ショートカットAppでキーを割り当てます。

## 権限
特別な権限は使いません。読み書きするのは Default Folder X の Favorites.plist と、このアプリのバックアップだけです。Default Folder X の終了と起動は、通常のアプリの終了・起動と同じ方法で行います。外部との通信はしません（更新確認を除く。配信先は未設定）。

## 常駐と終了
「ウインドウを閉じても常駐」がオンのときは、ウインドウを閉じても動き続けます。DockやFinderからFavoritesTidyを開き直すか、メニューバーのアイコンからウインドウを表示できます。終了するには［FavoritesTidy］＞［FavoritesTidyを終了］（⌘Q）を選びます。保存していない変更があるときは、保存するかどうかを確認します。

## 困ったときは
- 「Default Folder X 側でお気に入りが変更されていた」と出る：Default Folder X でお気に入りを追加・変更した後に整理を始めた場合に出ます。［読み直す］（⌘R）で最新の内容を読み込み、もう一度整理してください。
- 「Default Folder X が終了しなかった」と出る：Default Folder X の設定ウインドウやダイアログボックスを閉じてから、もう一度保存してください。
- 並び順がメニューに反映されない：Default Folder X の設定で「常に名前順に並べる」をオフにしてください。
- ウインドウが見つからない：DockのFavoritesTidyをクリックするか、Finderからもう一度開きます。
""",
 "en": """## Basics
FavoritesTidy reads the Default Folder X favorites (Favorites.plist), lets you sort them and group them into categories with separators, and writes them back.
- Sort: choose By Name, By Name Descending, By Location (Path), Newest Added First or Oldest Added First from the Sort menu. With nothing selected, every category is sorted; with items selected, only their categories are. Separators stay where they are.
- Search: type in the search field at the top (⌘F) to show only favorites whose name or path contains the text. Separate words with spaces to require all of them. Esc or ⓧ clears it. Dragging is off while searching (the Sort menu and moving still work).
- Dropbox: favorites inside a Dropbox folder get a blue Dropbox mark, and the path is shown from that folder (hover for the full path).
- Drag: drag rows to reorder them. Select several (⌘-click, ⇧-click) to move them together.
- Add Separator (⇧⌘N): adds a separator below the selected row (or at the end). Everything from one separator to the next is a category.
- Category names: click a heading and type a name. Default Folder X separators cannot have names, so the name is used only in this app.
- Move to Category: moves the selected items to the end of the chosen category. Also in a row's shortcut menu.
- Move Category Up/Down: Control-click a heading to move the whole category.
- Delete: select rows and press ⌫ to delete favorites or separators. Deleting a separator merges its category with the previous one.
- ⌘Z undoes and ⇧⌘Z redoes (until you save).
- Items whose folder is missing show ⚠. Control-click a row for Show in Finder and Copy Path.
- Hotkeys: the hotkey assigned in Default Folder X is shown at the right. Click it (or select the row and press ⌘K, or choose Change Hotkey… from the shortcut menu) to change or clear it. The key must include ⌘ or ⌃, and a key used by another favorite cannot be assigned. Save to apply it in Default Folder X.
- Quit / Open Default Folder X: the button at the bottom quits or opens Default Folder X. While it runs, a key it uses may trigger it instead of being recorded, so quit it before recording. Default Folder X quit here is reopened when you save or quit FavoritesTidy.

## Editing while Default Folder X runs
While Default Folder X is running, sorting, dragging, separators, moving, deleting or changing a hotkey first asks to quit it. Quit and Edit quits it and then edits; Cancel changes nothing. Category names are only in this app and can be edited without asking.

## Saving
Save (⌘S) writes Favorites.plist. Default Folder X writes its favorites when it quits, so a file written while it runs would be overwritten. Saving therefore:
- quits Default Folder X
- checks that the favorites it wrote are the same as when they were read (if they were changed in Default Folder X, saving stops)
- backs up the current file
- writes the file
- opens Default Folder X again
When Default Folder X is set to keep favorites sorted, the order set here does not appear in its menu. A warning is shown.
With several folder sets, switch them with the menu at the top (not while there are unsaved changes).

## Restoring
The Favorites.plist taken right before each save is backed up (up to the newest 30) in:
~/Library/Application Support/FavoritesTidy/Backups
To restore, quit Default Folder X, copy a backup as Favorites.plist to ~/Library/Application Support/com.stclairsoft.DefaultFolderX5/<folder set>/, and open Default Folder X. Open Backups Folder in Settings › General opens the folder.

## Settings
Choose FavoritesTidy > Settings… (⌘,).
- Launch & Residency: Open at login, Hide from Dock and App Switcher, Keep running after closing the window, the menu bar icon and the app launch keyboard shortcut.
- General: Confirm before saving (on by default) asks before quitting and reopening Default Folder X to save. Open Backups Folder.
- Settings Sharing: export, import and sync category names and the Confirm before saving choice.
- About: version and links.

## Keyboard shortcuts
- ⌘S: Save
- ⌘R: Reload
- ⇧⌘N: Add Separator
- ⌘F: Find
- ⌘K: Change Hotkey of the selected favorite
- ⌫: delete the selected items
- ⌘Z / ⇧⌘Z: Undo / Redo
- ⌘0: Open Main Window
- ⌘,: Settings
- ⌘W: Close Window
- ⌘?: this help
To call FavoritesTidy even when it is not running, follow the app launch keyboard shortcut note in Settings and assign a key in Shortcuts.

## Permissions
No special permission is used. FavoritesTidy reads and writes only Default Folder X's Favorites.plist and its own backups. Default Folder X is quit and opened the same way as any app. No network access (except checking for updates; no update feed is set yet).

## Keeping running and quitting
With “Keep running after closing the window” on, FavoritesTidy keeps running after you close the window. Open it again from the Dock or Finder, or show the window from the menu bar icon. To quit, choose FavoritesTidy > Quit FavoritesTidy (⌘Q). With unsaved changes, you are asked whether to save.

## Troubleshooting
- “The favorites were changed in Default Folder X”: you changed favorites in Default Folder X after starting to tidy. Reload (⌘R) and tidy again.
- “Default Folder X did not quit”: close Default Folder X's settings window or dialogs and save again.
- The order does not appear in the menu: turn off keeping favorites sorted in Default Folder X's settings.
- The window is gone: click FavoritesTidy in the Dock, or open it again from Finder.
""",
 "zh-Hans": """## 基本操作
FavoritesTidy 读取 Default Folder X 的个人收藏（Favorites.plist），可排序并用分隔线分成类别，然后写回。
- 排序：从“排序”菜单选择按名称、按名称倒序、按位置（路径）、最近添加的在前或最早添加的在前。未选择任何项目时在每个类别内排序；选择项目时只在其所在类别内排序。分隔线位置不变。
- 搜索：在顶部的搜索栏（⌘F）中输入，只显示名称或路径包含该文本的个人收藏。用空格分隔多个词时须全部包含。按 Esc 或 ⓧ 清除。搜索时无法拖移排序（排序菜单和移动仍可用）。
- Dropbox：位于 Dropbox 文件夹内的个人收藏带有蓝色“Dropbox”标记，路径从该文件夹起显示（悬停可看完整路径）。
- 拖移：拖移行以更改顺序。可多选（⌘-点按、⇧-点按）后一起移动。
- 添加分隔线（⇧⌘N）：在所选行下方（未选择时在末尾）添加分隔线。从一条分隔线到下一条分隔线为一个类别。
- 类别名称：点按标题并输入名称。Default Folder X 的分隔线无法命名，因此名称仅在本应用内使用。
- 移到类别：将所选项目移到所选类别的末尾。也可在行的快捷菜单中选择。
- 上移/下移类别：按住 Control 点按标题，可整体移动类别。
- 删除：选择行后按 ⌫ 删除个人收藏或分隔线。删除分隔线会与上一个类别合并。
- ⌘Z 撤销，⇧⌘Z 重做（保存前）。
- 找不到文件夹的项目显示 ⚠。按住 Control 点按行可使用“在访达中显示”和“拷贝路径”。
- 快捷键：右侧显示在 Default Folder X 中分配的快捷键。点按它（或选择行后按 ⌘K，或在快捷菜单中选择“更改快捷键…”）可更改或清除。按键须包含 ⌘ 或 ⌃，不能使用其他个人收藏已用的按键。保存后会应用到 Default Folder X。
- 退出/打开 Default Folder X：底部的按钮可退出或打开 Default Folder X。它运行时，录制它正在使用的按键可能会触发它，请先退出再录制。在此退出的 Default Folder X 会在保存或退出 FavoritesTidy 时重新打开。

## Default Folder X 运行时的编辑
Default Folder X 运行时，排序、拖移、分隔线、移动、删除或更改快捷键前会先询问是否退出它。选择“退出并编辑”会退出后再编辑；“取消”不做任何更改。类别名称仅在本应用内使用，可直接编辑。

## 保存
“保存”（⌘S）写入 Favorites.plist。Default Folder X 会在退出时写出个人收藏，因此在其运行时写入的文件会被覆盖。保存时按以下顺序处理：
- 退出 Default Folder X
- 确认其写出的个人收藏与读取时相同（若已在 Default Folder X 中更改，则停止保存）
- 备份当前文件
- 写入文件
- 重新打开 Default Folder X
Default Folder X 设为始终按名称排序时，此处设置的顺序不会反映到菜单中，并会显示警告。
有多个文件夹组时，用顶部的菜单切换（有未保存的更改时无法切换）。

## 恢复
每次保存前的 Favorites.plist 会备份（最多最近 30 份）到：
~/Library/Application Support/FavoritesTidy/Backups
要恢复，请退出 Default Folder X，将备份文件以 Favorites.plist 为名拷贝到 ~/Library/Application Support/com.stclairsoft.DefaultFolderX5/<文件夹组>/，然后打开 Default Folder X。也可从设置 › 通用中的“打开备份文件夹”打开该文件夹。

## 设置
选取 FavoritesTidy >“设置…”（⌘,）。
- 启动与常驻：登录时启动、不在程序坞和应用切换器中显示、关闭窗口后继续运行、菜单栏图标、启动应用快捷键。
- 通用：“保存前确认”（默认打开），在 Default Folder X 运行时保存前确认退出并重新打开。“打开备份文件夹”按钮。
- 设置共享：导出、导入和同步类别名称及“保存前确认”的选择。
- 关于：版本和链接。

## 快捷键
- ⌘S：保存
- ⌘R：重新读取
- ⇧⌘N：添加分隔线
- ⌘F：查找
- ⌘K：更改所选个人收藏的快捷键
- ⌫：删除所选项目
- ⌘Z / ⇧⌘Z：撤销 / 重做
- ⌘0：打开主窗口
- ⌘,：设置
- ⌘W：关闭窗口
- ⌘?：本帮助
要在 FavoritesTidy 未运行时也能调用，请按照设置中“启动应用快捷键”的说明，在快捷指令中分配按键。

## 权限
不使用特殊权限。FavoritesTidy 只读写 Default Folder X 的 Favorites.plist 和自己的备份。退出和打开 Default Folder X 的方式与普通应用相同。不进行网络通信（检查更新除外；尚未设置更新源）。

## 常驻与退出
打开“关闭窗口后继续运行”时，关闭窗口后 FavoritesTidy 仍继续运行。可从程序坞或访达再次打开，或从菜单栏图标显示窗口。要退出，请选取 FavoritesTidy >“退出 FavoritesTidy”（⌘Q）。有未保存的更改时会询问是否保存。

## 疑难解答
- 显示“个人收藏已在 Default Folder X 中更改”：开始整理后在 Default Folder X 中更改了个人收藏。请“重新读取”（⌘R）后再整理。
- 显示“Default Folder X 未退出”：请关闭 Default Folder X 的设置窗口或对话框后再次保存。
- 顺序未反映到菜单：请在 Default Folder X 的设置中关闭始终按名称排序。
- 找不到窗口：点击程序坞中的 FavoritesTidy，或从访达再次打开。
""",
 "ko": """## 기본 조작
FavoritesTidy는 Default Folder X 즐겨찾기(Favorites.plist)를 읽어 정렬하고 구분선으로 카테고리를 나눈 뒤 다시 기록합니다.
- 정렬: [정렬] 메뉴에서 이름순, 이름 역순, 위치(경로)순, 최근 추가순, 오래된 추가순을 선택합니다. 아무것도 선택하지 않으면 모든 카테고리 안에서, 항목을 선택하면 그 항목이 있는 카테고리 안에서만 정렬합니다. 구분선 위치는 바뀌지 않습니다.
- 검색: 위쪽 검색란(⌘F)에 입력하면 이름이나 경로에 포함된 즐겨찾기만 표시합니다. 공백으로 구분하면 모든 단어를 포함하는 것만 남깁니다. Esc 또는 ⓧ로 지웁니다. 검색 중에는 드래그로 정렬할 수 없습니다(정렬 메뉴와 이동은 사용 가능).
- Dropbox: Dropbox 폴더 안의 즐겨찾기에는 파란 'Dropbox' 표시가 붙고, 경로는 그 폴더 기준으로 표시합니다(마우스를 올리면 전체 경로).
- 드래그: 행을 드래그해 순서를 바꿉니다. 여러 개를 선택(⌘-클릭, ⇧-클릭)해 함께 옮길 수 있습니다.
- 구분선 추가(⇧⌘N): 선택한 행 아래(선택이 없으면 맨 끝)에 구분선을 넣습니다. 한 구분선에서 다음 구분선까지가 하나의 카테고리입니다.
- 카테고리 이름: 제목을 클릭해 이름을 입력합니다. Default Folder X 구분선에는 이름을 붙일 수 없어 이름은 이 앱에서만 사용합니다.
- 카테고리로 이동: 선택한 항목을 고른 카테고리의 끝으로 옮깁니다. 행을 Control-클릭해도 선택할 수 있습니다.
- 카테고리 위로/아래로 이동: 제목을 Control-클릭하면 카테고리 전체를 옮길 수 있습니다.
- 삭제: 행을 선택하고 ⌫를 누르면 즐겨찾기나 구분선을 삭제합니다. 구분선을 삭제하면 이전 카테고리와 합쳐집니다.
- ⌘Z로 실행 취소, ⇧⌘Z로 실행 복귀(저장 전까지).
- 폴더를 찾을 수 없는 항목에는 ⚠가 붙습니다. 행을 Control-클릭하면 [Finder에서 보기] [경로 복사하기]를 사용할 수 있습니다.
- 단축키: 오른쪽에 Default Folder X에서 지정한 단축키를 표시합니다. 클릭하면(또는 행을 선택하고 ⌘K, Control-클릭의 [단축키 변경…]) 변경하거나 해제할 수 있습니다. ⌘ 또는 ⌃를 포함해야 하며, 다른 즐겨찾기와 같은 키는 지정할 수 없습니다. 저장하면 Default Folder X에 반영됩니다.
- Default Folder X 종료/열기: 아래 버튼으로 Default Folder X를 종료하거나 엽니다. 실행 중에는 그 앱이 쓰는 키를 기록하려 하면 그쪽이 반응할 수 있으니 종료한 후 기록하세요. 여기서 종료한 Default Folder X는 저장하거나 FavoritesTidy를 종료하면 다시 엽니다.

## Default Folder X 실행 중 편집
Default Folder X 실행 중에 정렬, 드래그, 구분선, 이동, 삭제, 단축키 변경을 하려고 하면 종료할지 먼저 묻습니다. [종료하고 편집]을 선택하면 종료한 후 편집하고, [취소]는 아무것도 바꾸지 않습니다. 카테고리 이름은 이 앱에서만 쓰므로 묻지 않고 편집할 수 있습니다.

## 저장
[저장](⌘S)으로 Favorites.plist에 씁니다. Default Folder X는 종료할 때 즐겨찾기를 기록하므로 실행 중에 쓴 파일은 덮어쓰여집니다. 그래서 저장은 다음 순서로 처리합니다.
- Default Folder X 종료
- 종료 시 기록된 즐겨찾기가 읽었을 때와 같은지 확인(Default Folder X에서 변경되었으면 저장 중단)
- 현재 파일 백업
- 쓰기
- Default Folder X 다시 열기
Default Folder X가 항상 이름순으로 정렬하도록 설정되어 있으면 여기서 정한 순서가 메뉴에 반영되지 않습니다. 경고가 표시됩니다.
폴더 세트가 여러 개이면 위쪽 메뉴로 전환합니다(저장하지 않은 변경 사항이 있으면 전환할 수 없음).

## 되돌리기
저장 직전의 Favorites.plist를 최근 30개까지 다음 폴더에 백업합니다.
~/Library/Application Support/FavoritesTidy/Backups
되돌리려면 Default Folder X를 종료하고, 백업 파일을 Favorites.plist라는 이름으로 ~/Library/Application Support/com.stclairsoft.DefaultFolderX5/<폴더 세트>/에 복사한 뒤 Default Folder X를 엽니다. 설정 › 일반의 '백업 폴더 열기'로도 열 수 있습니다.

## 설정
FavoritesTidy > 설정…(⌘,)을 선택합니다.
- 실행·상주: 로그인 시 실행, Dock 및 앱 전환기에서 숨기기, 윈도우를 닫아도 계속 실행, 메뉴 막대 아이콘, 앱 실행 키보드 단축키.
- 일반: '저장하기 전에 확인'(기본값 켬). Default Folder X 실행 중에 저장할 때 종료 후 다시 열기를 확인합니다. 백업 폴더 열기 버튼.
- 설정 공유: 카테고리 이름과 '저장하기 전에 확인' 선택의 내보내기·가져오기와 동기화.
- 정보: 버전과 링크.

## 키보드 단축키
- ⌘S: 저장
- ⌘R: 다시 읽기
- ⇧⌘N: 구분선 추가
- ⌘F: 찾기
- ⌘K: 선택한 즐겨찾기의 단축키 변경
- ⌫: 선택한 항목 삭제
- ⌘Z / ⇧⌘Z: 실행 취소 / 실행 복귀
- ⌘0: 메인 윈도우 열기
- ⌘,: 설정
- ⌘W: 윈도우 닫기
- ⌘?: 이 도움말
FavoritesTidy가 실행 중이 아닐 때도 호출하려면 설정의 '앱 실행 키보드 단축키' 안내에 따라 단축어 앱에서 키를 지정하세요.

## 권한
특별한 권한은 사용하지 않습니다. Default Folder X의 Favorites.plist와 이 앱의 백업만 읽고 씁니다. Default Folder X의 종료와 실행은 일반 앱과 같은 방법으로 합니다. 외부 통신은 하지 않습니다(업데이트 확인 제외, 배포처 미설정).

## 상주와 종료
'윈도우를 닫아도 계속 실행'이 켜져 있으면 윈도우를 닫아도 계속 실행됩니다. Dock이나 Finder에서 FavoritesTidy를 다시 열거나 메뉴 막대 아이콘에서 윈도우를 표시할 수 있습니다. 종료하려면 FavoritesTidy > FavoritesTidy 종료(⌘Q)를 선택합니다. 저장하지 않은 변경 사항이 있으면 저장할지 묻습니다.

## 문제 해결
- 'Default Folder X에서 즐겨찾기가 변경되어'가 표시됨: 정리를 시작한 후 Default Folder X에서 즐겨찾기를 변경했습니다. [다시 읽기](⌘R) 후 다시 정리하세요.
- 'Default Folder X가 종료되지 않아'가 표시됨: Default Folder X의 설정 윈도우나 대화상자를 닫고 다시 저장하세요.
- 순서가 메뉴에 반영되지 않음: Default Folder X 설정에서 항상 이름순 정렬을 끄세요.
- 윈도우가 보이지 않음: Dock의 FavoritesTidy를 클릭하거나 Finder에서 다시 엽니다.
""",
}
