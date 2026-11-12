# -*- coding: utf-8 -*-
# VectorKeyMap help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
VectorKeyMapは、Illustratorのキーボードショートカットのセット（.kysファイル）を読み、コマンドごとに一覧にします。初期設定とカスタマイズしたセットを並べて、差分を確かめられます。Illustratorを起動していなくても使えます。セットを書き換えることはありません。
- 「基準」に比べる元のセット、「比較先」に確かめたいセットを選びます。起動時は、基準が初期設定、比較先がIllustratorで使用中のセットです。
- 間のボタンで基準と比較先を入れ替えます。
- 上の切り替えで、差分・変更・追加・解除・同じ・重複・キーあり・すべてを絞り込みます。件数も出ます。
- 分類の一覧でメニューやツールに絞り込み、検索欄で名前・ID・キーを探します。「⌘E」「cmd+e」「shift+」のように探せます。⌘Fで検索欄へ移ります。
- 列の見出しを押すと並べ替えます。「コマンド」はメニューの順、「基準」「比較先」はキーの順です。
## キーボード
右上の［キーボード］で、キーボードの図に切り替えます。空いているキーは緑の破線で、枠だけの空欄になります。
- 上の切り替えで修飾キーの組み合わせ（なし・⇧・⌘・⇧⌘・⌥・⌥⇧・⌥⌘・⌥⇧⌘）を選びます。横の数字は空きの数です。
- 緑の破線は空き、白は使用中でコマンド名が出ます。紫はmacOSのキーボードショートカットが使っています。黄色は文字の編集中だけ使われています。
- キーを押すと、そのキーの8通りの組み合わせが下に出ます。
- ［比較先］［基準］で表示するセットを、［JIS］［US］でキーボードの種類を選びます。種類の初期値は接続中のキーボードです。
- Shiftで入力する記号（JISの + や =）は、Shiftの組み合わせの位置に出します。⌘+ と ⇧⌘; は同じ押し方です。
- ［空きキーをコピー］で、選んでいる組み合わせの空きキーをコピーします。
- 「空き」が分かるのはIllustratorのセットとmacOSのショートカットだけです。Keyboard Maestroなどほかのアプリが使うキーは含みません。
- return・delete・Spaceなどは対象外とし、空きの数に入れません。
## 状態の意味
- 変更：どちらにもキーがあり、キーが異なります。
- 追加：基準にキーがなく、比較先にあります。
- 解除：基準のキーが、比較先で外されています。
- 同じ：同じキーです。
- 記載なし：比較先のファイルにそのコマンドが載っていません。古い版で保存したセットで起こります。
- なし：どちらにもキーがありません（「すべて」で出ます）。
- 重複：比較先で同じキーが複数のコマンドに付いています。行に ⚠ が付き、行を選ぶと相手が下に出ます。
- 「文字編集中」は、文字を編集している間だけ効くキーです。
## 初期設定について
Illustratorに同梱の「Illustrator 初期設定.kys」は実際の既定値と一致しません（パネルなどのIDが古いままで、新しいコマンドも載っていません）。このため、Illustrator 30で初期設定のセットを保存した.kysを同梱し、基準にしています。
新しい版で既定値が変わったときは、次の手順で基準を入れ替えられます。
- Illustratorの［編集］メニュー →［キーボードショートカット…］を開き、セットを「Illustrator 初期設定」にして［保存…］で別名を付けます。
- VectorKeyMapに戻ると一覧に出るので、「基準」で選びます。
## セットの追加
- ［セットを追加…］（⌘O）で.kysファイルを選ぶか、ウインドウへドラッグします。ほかの人のセットや古い版のセットも比べられます。
- ［ファイル］→［追加したセットを一覧から外す］で外します。ファイルは削除しません。
- Illustratorの設定フォルダーにある.kysは自動で一覧に出ます。VectorKeyMapに戻ると読み直します。
- Illustratorで変更したキーは、セットを保存するまで.kysに反映されません。
## 書き出し
- ［表をコピー］は表示中の行をタブ区切りでコピーします。表計算アプリに貼り付けられます。
- ［書き出し］は表示中の行をCSV（Excelで開けるUTF-8）かMarkdownで保存します。
- 行を選んで⌘Cでコピーできます。右クリックでIDだけをコピーできます。IDはスクリプトの app.executeMenuCommand などに使えます。
## 設定・ホットキー
設定（⌘,）の「起動・常駐」で、ログイン時の起動、ウインドウを閉じた後の常駐、メニューバーの表示、アプリを呼び出すホットキーを選べます。初期値はどれもオフで、ホットキーは未設定です。ウインドウを閉じると終了します。常駐をオンにすると、Dockやメニューバーから再表示できます。
## 権限・データ
特別な権限は要りません。読むのはIllustratorの設定フォルダーと選んだファイルだけで、外部へは送りません。保存するのは選んだセットの場所だけです。
## 制限
- 名前はIllustrator 30の日本語版から作った表によります。表にないIDはそのまま表示し、分類は「未分類」です。英語の名前は Ai Command Palette の表によるもので、ない場合は日本語で表示します。
- 名前の表には作者の環境のプラグイン（Astute Graphics・XtreamPath など）も含みます。
- メニューの階層は分かる範囲で表示します。
## 困ったとき
- 比較先に使用中のセットが出ない：Illustratorを終了すると環境設定に保存されます。［セットを追加…］で.kysを選ぶこともできます。
- 「読み込めません」と出る：キーボードショートカットの.kysファイルか確かめてください。
- 終了：［VectorKeyMap］メニューの「VectorKeyMapを終了」または⌘Qです。
- 削除：アプリをゴミ箱に入れます。設定は ~/Library/Preferences/jp.dtp-transit.vectorkeymap.plist です。
""",
 "en": """## Basics
VectorKeyMap reads Illustrator keyboard shortcut sets (.kys files) and lists them by command. Put the defaults next to a customized set to see the differences. Illustrator does not have to be running, and sets are never changed.
- Choose the starting point in Baseline and the set to check in Compare with. At launch the baseline is the defaults and the compared set is the one Illustrator uses.
- The button between them swaps the two.
- The switch above the list filters by Differences, Changed, Added, Removed, Same, Conflicts, With Keys and All, with counts.
- Narrow to a menu or tools with the category list, and search names, IDs and keys, such as ⌘E, cmd+e or shift+. ⌘F moves to the search field.
- Click a column heading to sort. Command uses the menu order; Baseline and Compared use key order.
## Keyboard
Keyboard at the top right switches to a picture of the keyboard, with free keys shown as empty slots with a green dashed outline.
- The switch above it chooses the modifiers (none, ⇧, ⌘, ⇧⌘, ⌥, ⌥⇧, ⌥⌘, ⌥⇧⌘). The numbers are the free keys.
- A green dashed outline is free and white is in use, with the command name. Purple is used by a macOS keyboard shortcut. Yellow is used only while editing text.
- Click a key to see its eight combinations below.
- Choose the set to show with Compared and Baseline, and the keyboard type with JIS and US. The type starts as the connected keyboard.
- A symbol typed with Shift appears under the Shift combination, because that is how it is pressed.
- Copy Free Keys copies the free keys of the chosen combination.
- Free covers only the Illustrator set and macOS shortcuts. Keys used by other apps such as Keyboard Maestro are not included.
- Return, Delete, Space and the like are not assignable here and do not count as free.
## What the statuses mean
- Changed: both have a key, and the keys differ.
- Added: no key in the baseline, a key in the compared set.
- Removed: the baseline key has been taken off in the compared set.
- Same: the same key.
- Not listed: the compared file does not list the command. This happens with sets saved in older versions.
- None: no key in either (shown under All).
- Conflicts: one key is on several commands in the compared set. The row shows ⚠, and selecting it names the others below the list.
- In text marks a key that works only while editing text.
## About the defaults
The "Illustrator Defaults" .kys that ships with Illustrator does not match the real defaults: panel IDs are out of date and new commands are missing. So the app bundles a .kys saved from the default set in Illustrator 30, and uses that as the baseline.
When a new version changes the defaults, replace the baseline like this.
- In Illustrator, open Edit > Keyboard Shortcuts…, choose the default set and use Save… to give it a new name.
- Return to VectorKeyMap, where it appears in the list, and choose it as the Baseline.
## Adding sets
- Use Add Set… (⌘O) to choose a .kys file, or drag one onto the window. You can compare someone else's set or one from an older version.
- File > Remove Added Set from List takes it off the list. The file is not deleted.
- .kys files in Illustrator's settings folders are listed automatically and read again when you return to the app.
- Keys changed in Illustrator reach the .kys only after you save the set.
## Export
- Copy Table copies the rows on screen as tab-separated text, ready for a spreadsheet.
- Export saves the rows on screen as CSV (UTF-8, opens in Excel) or Markdown.
- Select rows and press ⌘C to copy them. Right-click to copy only the IDs, which work with app.executeMenuCommand in scripts.
## Settings and hotkeys
In Settings (⌘,), Startup & Background has open at login, keep running after closing the window, the menu bar icon and the hotkey that shows the app. All are off by default and no hotkey is set, so closing the window quits. With keep running on, reopen from the Dock or the menu bar.
## Permissions and data
No special permission is needed. The app reads only Illustrator's settings folders and the files you choose, and sends nothing out. It stores only where your chosen sets are.
## Limitations
- Names come from a table made from Japanese Illustrator 30. IDs missing from the table appear as they are, under Uncategorized. English names come from the Ai Command Palette table, and Japanese is shown when there is none.
- The table includes the plug-ins of the author's setup (Astute Graphics, XtreamPath and others).
- Menu levels are shown as far as they are known.
## Troubleshooting
- The set in use is not marked: Illustrator writes its preferences when it quits. You can also pick the .kys with Add Set….
- "Cannot read": check that the file is a keyboard shortcut .kys.
- To quit, choose Quit VectorKeyMap or press ⌘Q.
- To remove the app, move it to the Trash. Its settings are in ~/Library/Preferences/jp.dtp-transit.vectorkeymap.plist.
""",
 "zh-Hans": """## 基本操作
VectorKeyMap 读取 Illustrator 的键盘快捷键集（.kys 文件），并按命令列出。可以把默认设置和自定义集并排比较差异。无需启动 Illustrator，也不会更改任何集。
- 在“基准”中选择比较的起点，在“比较对象”中选择要检查的集。启动时，基准为默认设置，比较对象为 Illustrator 正在使用的集。
- 中间的按钮可交换两者。
- 列表上方的切换可按差异、已更改、已添加、已移除、相同、冲突、有按键、全部筛选，并显示数量。
- 用类别列表缩小到某个菜单或工具，在搜索栏查找名称、ID 和按键，例如 ⌘E、cmd+e、shift+。⌘F 可移到搜索栏。
- 点按列标题可排序。“命令”按菜单顺序，“基准”和“比较对象”按按键顺序。
## 键盘
右上角的“键盘”切换到键盘图，空闲按键显示为绿色虚线的空框。
- 上方的切换选择修饰键组合（无、⇧、⌘、⇧⌘、⌥、⌥⇧、⌥⌘、⌥⇧⌘）。数字是空闲按键数。
- 绿色虚线为空闲，白色为使用中并显示命令名。紫色由 macOS 键盘快捷键使用。黄色仅在编辑文字时使用。
- 点按按键可在下方查看它的八种组合。
- 用“比较对象”“基准”选择显示的集，用 JIS、US 选择键盘类型。类型初始为已连接的键盘。
- 用 Shift 输入的符号显示在 Shift 组合的位置，因为实际就是这样按的。
- “拷贝空闲按键”拷贝所选组合的空闲按键。
- “空闲”只考虑 Illustrator 的集和 macOS 快捷键，不包括 Keyboard Maestro 等其他应用使用的按键。
- Return、Delete、Space 等不可分配，不计入空闲数。
## 状态的含义
- 已更改：两边都有按键，但按键不同。
- 已添加：基准没有按键，比较对象有。
- 已移除：基准的按键在比较对象中被去掉。
- 相同：按键相同。
- 未列出：比较文件中没有该命令。用旧版本存储的集可能出现这种情况。
- 无：两边都没有按键（在“全部”中显示）。
- 冲突：比较对象中同一按键用于多个命令。该行显示 ⚠，选中后在列表下方显示其他命令。
- “文字编辑中”表示仅在编辑文字时有效的按键。
## 关于默认设置
Illustrator 自带的默认 .kys 与实际默认值不一致：面板的 ID 已过时，也缺少新命令。因此本应用内置了在 Illustrator 30 中存储的默认集 .kys，并以它为基准。
新版本更改默认值时，可按以下步骤更换基准。
- 在 Illustrator 中打开“编辑 > 键盘快捷键…”，选择默认集，用“存储…”另存为新名称。
- 回到 VectorKeyMap，它会出现在列表中，在“基准”中选择它。
## 添加集
- 用“添加集…”（⌘O）选择 .kys 文件，或拖到窗口上。也可以比较他人的集或旧版本的集。
- “文件 > 从列表中移除已添加的集”可将其移除，不会删除文件。
- Illustrator 设置文件夹中的 .kys 会自动列出，回到应用时重新读取。
- 在 Illustrator 中更改的按键要存储集后才会写入 .kys。
## 导出
- “拷贝表格”以制表符分隔拷贝显示的行，可粘贴到电子表格。
- “导出”将显示的行存储为 CSV（UTF-8，可用 Excel 打开）或 Markdown。
- 选中行后按 ⌘C 拷贝。右键可只拷贝 ID，可用于脚本的 app.executeMenuCommand。
## 设置和快捷键
在设置（⌘,）的“启动与后台”中可选择登录时启动、关闭窗口后继续运行、菜单栏图标和显示应用的快捷键。默认全部关闭，也未设置快捷键，因此关闭窗口即退出。开启继续运行后，可从 Dock 或菜单栏再次打开。
## 权限和数据
不需要特殊权限。只读取 Illustrator 的设置文件夹和你选择的文件，不向外发送。只保存所选集的位置。
## 限制
- 名称来自根据日文版 Illustrator 30 制作的表。表中没有的 ID 按原样显示，归入“未分类”。英文名称来自 Ai Command Palette 的表，没有时显示日文。
- 表中包含作者环境的增效工具（Astute Graphics、XtreamPath 等）。
- 菜单层级在已知范围内显示。
## 疑难解答
- 未标出使用中的集：Illustrator 退出时才写入偏好设置。也可用“添加集…”选择 .kys。
- 显示“无法读取”：请确认是键盘快捷键 .kys 文件。
- 退出：选择“退出 VectorKeyMap”或按 ⌘Q。
- 删除：将应用移到废纸篓。设置位于 ~/Library/Preferences/jp.dtp-transit.vectorkeymap.plist。
""",
 "ko": """## 기본 조작
VectorKeyMap은 Illustrator의 키보드 단축키 세트(.kys 파일)를 읽어 명령별로 나열합니다. 기본 설정과 사용자 정의 세트를 나란히 놓고 차이를 확인할 수 있습니다. Illustrator를 실행하지 않아도 되고 세트를 변경하지 않습니다.
- 기준에서 비교의 출발점을, 비교 대상에서 확인할 세트를 선택합니다. 시작할 때 기준은 기본 설정, 비교 대상은 Illustrator에서 사용 중인 세트입니다.
- 사이의 버튼으로 둘을 바꿉니다.
- 목록 위의 전환으로 차이, 변경, 추가, 해제, 동일, 중복, 키 있음, 전체를 필터링하고 개수도 표시합니다.
- 분류 목록으로 메뉴나 도구를 좁히고, 검색란에서 이름, ID, 키를 찾습니다. ⌘E, cmd+e, shift+ 처럼 찾을 수 있습니다. ⌘F로 검색란으로 이동합니다.
- 열 제목을 누르면 정렬합니다. 명령은 메뉴 순서, 기준과 비교 대상은 키 순서입니다.
## 키보드
오른쪽 위의 키보드를 누르면 키보드 그림으로 바뀌고 빈 키가 녹색 점선의 빈칸으로 표시됩니다.
- 위의 전환으로 보조 키 조합(없음, ⇧, ⌘, ⇧⌘, ⌥, ⌥⇧, ⌥⌘, ⌥⇧⌘)을 선택합니다. 숫자는 빈 키의 개수입니다.
- 녹색 점선은 비어 있음, 흰색은 사용 중이며 명령 이름이 나옵니다. 보라색은 macOS 키보드 단축키가 사용합니다. 노란색은 문자 편집 중에만 사용됩니다.
- 키를 누르면 아래에 8가지 조합이 나옵니다.
- 비교 대상, 기준으로 표시할 세트를, JIS, US로 키보드 종류를 선택합니다. 종류의 초기값은 연결된 키보드입니다.
- Shift로 입력하는 기호는 실제로 누르는 대로 Shift 조합 위치에 표시합니다.
- 빈 키 복사는 선택한 조합의 빈 키를 복사합니다.
- 비어 있음은 Illustrator 세트와 macOS 단축키만 반영합니다. Keyboard Maestro 등 다른 앱이 쓰는 키는 포함하지 않습니다.
- Return, Delete, Space 등은 지정 대상이 아니며 빈 키 수에 넣지 않습니다.
## 상태의 의미
- 변경: 양쪽에 키가 있고 키가 다릅니다.
- 추가: 기준에는 키가 없고 비교 대상에는 있습니다.
- 해제: 기준의 키가 비교 대상에서 제거되었습니다.
- 동일: 같은 키입니다.
- 목록에 없음: 비교 파일에 그 명령이 없습니다. 이전 버전에서 저장한 세트에서 일어납니다.
- 없음: 양쪽 모두 키가 없습니다(전체에서 표시).
- 중복: 비교 대상에서 같은 키가 여러 명령에 지정되어 있습니다. 행에 ⚠가 표시되고 선택하면 목록 아래에 상대가 나옵니다.
- 문자 편집 중은 문자를 편집하는 동안에만 작동하는 키입니다.
## 기본 설정에 대해
Illustrator에 포함된 기본 .kys는 실제 기본값과 일치하지 않습니다. 패널 ID가 오래되었고 새 명령도 없습니다. 그래서 Illustrator 30에서 기본 세트를 저장한 .kys를 내장해 기준으로 사용합니다.
새 버전에서 기본값이 바뀌면 다음 순서로 기준을 바꿀 수 있습니다.
- Illustrator에서 편집 > 키보드 단축키…를 열고 기본 세트를 선택한 뒤 저장…으로 새 이름을 붙입니다.
- VectorKeyMap으로 돌아오면 목록에 나오므로 기준에서 선택합니다.
## 세트 추가
- 세트 추가…(⌘O)로 .kys 파일을 선택하거나 윈도우로 드래그합니다. 다른 사람의 세트나 이전 버전의 세트도 비교할 수 있습니다.
- 파일 > 추가한 세트를 목록에서 제거로 뺍니다. 파일은 삭제하지 않습니다.
- Illustrator 설정 폴더의 .kys는 자동으로 목록에 나오고, 앱으로 돌아오면 다시 읽습니다.
- Illustrator에서 바꾼 키는 세트를 저장해야 .kys에 반영됩니다.
## 내보내기
- 표 복사는 표시 중인 행을 탭으로 구분해 복사합니다. 스프레드시트에 붙여 넣을 수 있습니다.
- 내보내기는 표시 중인 행을 CSV(UTF-8, Excel에서 열림) 또는 Markdown으로 저장합니다.
- 행을 선택하고 ⌘C로 복사합니다. 오른쪽 클릭으로 ID만 복사할 수 있고, ID는 스크립트의 app.executeMenuCommand에 쓸 수 있습니다.
## 설정과 단축키
설정(⌘,)의 시작 및 백그라운드에서 로그인 시 실행, 윈도우를 닫은 뒤 계속 실행, 메뉴 막대 아이콘, 앱 표시 단축키를 선택합니다. 기본값은 모두 꺼져 있고 단축키도 없어서 윈도우를 닫으면 종료됩니다. 계속 실행을 켜면 Dock이나 메뉴 막대에서 다시 열 수 있습니다.
## 권한과 데이터
특별한 권한이 필요 없습니다. Illustrator 설정 폴더와 선택한 파일만 읽고 외부로 보내지 않습니다. 선택한 세트의 위치만 저장합니다.
## 제한
- 이름은 일본어판 Illustrator 30으로 만든 표를 따릅니다. 표에 없는 ID는 그대로 표시되고 미분류가 됩니다. 영어 이름은 Ai Command Palette의 표를 따르고, 없으면 일본어로 표시합니다.
- 표에는 작성자 환경의 플러그인(Astute Graphics, XtreamPath 등)도 포함됩니다.
- 메뉴 계층은 알 수 있는 범위에서 표시합니다.
## 문제 해결
- 사용 중인 세트가 표시되지 않음: Illustrator는 종료할 때 환경 설정을 씁니다. 세트 추가…로 .kys를 선택할 수도 있습니다.
- 읽을 수 없다고 나옴: 키보드 단축키 .kys 파일인지 확인하세요.
- 종료: VectorKeyMap 종료를 선택하거나 ⌘Q를 누릅니다.
- 삭제: 앱을 휴지통으로 옮깁니다. 설정은 ~/Library/Preferences/jp.dtp-transit.vectorkeymap.plist에 있습니다.
""",
}
