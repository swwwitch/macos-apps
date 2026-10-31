# VectorFX help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
VectorFXは、Illustratorの効果・パスファインダー・複合パス・線端などの操作を、パレットのボタンとホットキーで実行します。
- パレットの表示：Illustratorが前面のときに ⌃A（初期値）。もう一度押すと隠します。メインウインドウの［パレットを表示］、［ファイル］＞［パレットを表示／隠す］（⇧⌘P）、メニューバーのアイコンからも表示できます。
- パレットはIllustratorが前面のときだけ表示されます。ほかのアプリに切り替えると隠れ、Illustratorに戻ると再び表示されます。パレットをクリックしてもIllustratorの選択は変わりません。
- 実行：パレットのボタンをクリックします。選択中のオブジェクトに対して実行します。
- 名前の後ろに「…」がある項目は、Illustratorのダイアログボックスを開きます。閉じるまで次の操作は待ちます。

## 値を指定して適用する効果
ドロップシャドウ・パスのオフセット・長方形・ジグザグ・ラフは、ダイアログボックスを出さずに、メインウインドウで決めた値で効果を適用します。長さはドキュメントの単位です。
- パレットでOptionを押しながらクリックすると、代わりにIllustratorのダイアログボックスを開きます。
- 適用した効果は、アピアランスパネルでダブルクリックして調整できます。
- 複数のオブジェクトを選んでいるときは、それぞれに効果を付けます。

## メインウインドウ
- 左の一覧：チェックを入れた項目がパレットに表示されます。右端は割り当てたホットキーです。
- 右の欄：［Illustratorで実行］（⌘Return）、ホットキーの割り当て、効果の値、スクリプトファイルの場所。
- スクリプトファイルが見つからない項目には⚠が付きます。［ファイルを選ぶ…］で指定し直してください。
- 下の欄に、最後に実行した結果（エラーの理由を含む）を表示します。パレットの下にも同じ内容が出ます。

## ホットキー
- 項目ごとのホットキーは、パレットを表示していて、Illustratorが前面のときだけ使えます。そのため ⇧K や - のような修飾キーなしのキーも割り当てられます。パレットを隠せば、そのキーはIllustratorでふだんどおり使えます。
- 割り当て：メインウインドウで項目を選び、ホットキー欄をクリックしてキーを押します。Escで取り消し。ほかの項目と同じキーを押すと、その項目から外して付け替えます。
- パレットを表示するホットキー（初期値 ⌃A）：設定の［パレット］で変更・無効化できます。
- アプリを呼び出すホットキー：設定の［起動・常駐］で割り当てると、どのアプリからでもメインウインドウを表示します（初期値なし）。
- ⌘0：メインウインドウを開く、⌘,：設定、⌘W：ウインドウを閉じる、⌘?：ヘルプ

## 設定
［VectorFX］＞［設定…］（⌘,）で開きます。
- 起動・常駐：ログイン時に起動、Dockとアプリケーションスイッチャーに表示しない、ウインドウを閉じても常駐、メニューバーのアイコン、アプリを呼び出すホットキー。
- パレット：パレットを表示するホットキー、［すべて初期値に戻す］（表示する項目・ホットキー・効果の値。スクリプトファイルの場所は残ります）。
- 設定の共有：パレットの項目・ホットキー・効果の値の書き出し・読み込みと同期。
- 情報：バージョンとリンク。

## 権限
初めて実行するとき、「VectorFXが“Adobe Illustrator”を制御しようとしています」と確認されます。［許可］を選んでください。許可しなかった場合は、システム設定＞プライバシーとセキュリティ＞オートメーションで、VectorFXの「Adobe Illustrator」をオンにします。アクセシビリティの許可は使いません。

## 常駐と終了
ウインドウを閉じても常駐し、パレットとホットキーは使えます（設定でオフにすると、閉じたときに終了します）。再表示はDockのアイコン、メニューバーのアイコン、Finderから開き直す、アプリを呼び出すホットキーのいずれか。終了は［VectorFX］＞［VectorFXを終了］（⌘Q）またはメニューバーのアイコンから。

## 困ったとき
- 「オブジェクトを選択してください」：選択ツールでオブジェクトを選んでから実行します。文字の編集中（カーソルが文字の中）は実行できません。
- 「アクション…を実行できませんでした」：グループの抜きは、［アクション］パネルのセット「S2A」にあるアクション「グループの抜き」を使います。セットを読み込んでください。
- ホットキーが効かない：パレットが表示されているか、Illustratorが前面かを確認します。同じキーをほかのアプリ（Keyboard Maestroなど）が使っていると、両方が反応することがあります。
- 効果の付き方を戻したい：Illustratorで取り消し（⌘Z）します。
- 設定を最初に戻す：設定の［パレット］＞［すべて初期値に戻す］。アプリを削除するときは、アプリケーションフォルダーからVectorFX.appをゴミ箱に入れます。
""",
 "en": """## Basics
VectorFX runs Illustrator effects, Pathfinder, compound paths, caps and more from palette buttons and hotkeys.
- Show the palette: press ⌃A (default) while Illustrator is in front; press again to hide it. You can also use Show Palette in the main window, File › Show/Hide Palette (⇧⌘P) or the menu bar icon.
- The palette appears only while Illustrator is in front. It hides when you switch to another app and comes back with Illustrator. Clicking the palette keeps Illustrator's selection.
- Run: click a button in the palette. It acts on the selected objects.
- Items ending with “…” open Illustrator's dialog box; the next command waits until it closes.

## Effects applied with values
Drop Shadow, Offset Path, Rectangle, Zig Zag and Roughen are applied without a dialog box, using the values set in the main window. Lengths use the document's units.
- Option-click in the palette to open Illustrator's dialog box instead.
- Double-click the effect in the Appearance panel to adjust it later.
- With several objects selected, each gets its own effect.

## Main window
- Left list: checked items appear in the palette. The right column shows the assigned hotkey.
- Right side: Run in Illustrator (⌘Return), hotkey, effect values and the script file location.
- Items whose script file is missing show ⚠. Choose the file again with Choose File….
- The bottom line shows the last result, including why it failed. The palette shows it too.

## Hotkeys
- Item hotkeys work only while the palette is shown and Illustrator is in front, so keys without modifiers such as ⇧K or - can be used. Hide the palette and those keys type normally in Illustrator.
- Assign: select an item in the main window, click the hotkey field and press the keys. Esc cancels. A key already used by another item is moved to this one.
- Palette hotkey (default ⌃A): change or turn it off in Settings › Palette.
- Show-app hotkey: assign it in Settings › Startup & Background to show the main window from any app (no default).
- ⌘0 Open Main Window, ⌘, Settings, ⌘W Close Window, ⌘? Help

## Settings
Open with VectorFX › Settings… (⌘,).
- Startup & Background: open at login, hide from Dock and App Switcher, keep running after closing the window, menu bar icon, show-app hotkey.
- Palette: palette hotkey and Reset All to Defaults (items, hotkeys and effect values; script file locations are kept).
- Sharing: export, import and sync the palette items, hotkeys and effect values.
- About: version and links.

## Permissions
The first run asks whether VectorFX may control “Adobe Illustrator”. Choose Allow. If you did not, turn on “Adobe Illustrator” for VectorFX in System Settings › Privacy & Security › Automation. Accessibility permission is not used.

## Keep running and quitting
VectorFX keeps running after you close the window, so the palette and hotkeys keep working (turn this off in Settings to quit on close). Show it again from the Dock, the menu bar icon, by opening it from the Finder or with the show-app hotkey. Quit with VectorFX › Quit VectorFX (⌘Q) or from the menu bar icon.

## Troubleshooting
- “Select objects first”: select objects with the Selection tool. Commands do not run while text is being edited.
- “Could not play the action…”: Knockout Group plays the action “グループの抜き” in the set “S2A” of the Actions panel. Load that set.
- A hotkey does nothing: check that the palette is shown and Illustrator is in front. Another app using the same key (Keyboard Maestro, for example) may react as well.
- Undo an effect with Undo (⌘Z) in Illustrator.
- Start over: Settings › Palette › Reset All to Defaults. To remove the app, move VectorFX.app from Applications to the Trash.
""",
 "zh-Hans": """## 基本操作
VectorFX 通过面板按钮和快捷键执行 Illustrator 的效果、路径查找器、复合路径、端点等操作。
- 显示面板：在 Illustrator 位于前台时按 ⌃A（默认），再按一次隐藏。也可以使用主窗口的“显示面板”、“文件”›“显示/隐藏面板”（⇧⌘P）或菜单栏图标。
- 面板仅在 Illustrator 位于前台时显示。切换到其他应用时隐藏，回到 Illustrator 时重新显示。单击面板不会改变 Illustrator 的选择。
- 执行：单击面板中的按钮，对所选对象执行。
- 名称后带“…”的项目会打开 Illustrator 的对话框，关闭前后续操作会等待。

## 以数值应用的效果
投影、位移路径、矩形、波纹效果和粗糙化不显示对话框，而是使用主窗口中设定的数值应用效果。长度使用文档单位。
- 在面板中按住 Option 单击可改为打开 Illustrator 的对话框。
- 应用后可在“外观”面板中双击效果进行调整。
- 选择多个对象时，每个对象分别添加效果。

## 主窗口
- 左侧列表：勾选的项目显示在面板中，右端为分配的快捷键。
- 右侧：“在 Illustrator 中执行”（⌘Return）、快捷键、效果数值、脚本文件位置。
- 找不到脚本文件的项目显示 ⚠，请用“选择文件…”重新指定。
- 底部显示上次执行的结果（包括失败原因），面板底部也会显示。

## 快捷键
- 各项目的快捷键仅在显示面板且 Illustrator 位于前台时可用，因此也可以使用 ⇧K 或 - 等不带修饰键的按键。隐藏面板后，这些键在 Illustrator 中照常使用。
- 分配：在主窗口选择项目，单击快捷键栏并按键。按 Esc 取消。若按键已被其他项目使用，会从该项目移到此项目。
- 显示面板的快捷键（默认 ⌃A）：在“设置”›“面板”中更改或关闭。
- 显示应用快捷键：在“设置”›“启动与后台”中分配后，可从任何应用显示主窗口（无默认值）。
- ⌘0 打开主窗口，⌘, 设置，⌘W 关闭窗口，⌘? 帮助

## 设置
通过“VectorFX”›“设置…”（⌘,）打开。
- 启动与后台：登录时启动、在程序坞和应用切换器中隐藏、关闭窗口后继续运行、菜单栏图标、显示应用快捷键。
- 面板：显示面板的快捷键、“全部恢复默认”（项目、快捷键和效果数值；保留脚本文件位置）。
- 设置共享：导出、导入并同步面板项目、快捷键和效果数值。
- 关于：版本和链接。

## 权限
首次执行时会询问是否允许 VectorFX 控制“Adobe Illustrator”，请选择“允许”。若未允许，请在“系统设置”›“隐私与安全性”›“自动化”中为 VectorFX 打开“Adobe Illustrator”。不使用辅助功能权限。

## 常驻与退出
关闭窗口后仍继续运行，面板和快捷键可继续使用（在设置中关闭后，关闭窗口即退出）。可通过程序坞图标、菜单栏图标、在访达中重新打开或显示应用快捷键再次显示。通过“VectorFX”›“退出 VectorFX”（⌘Q）或菜单栏图标退出。

## 疑难解答
- “请先选择对象”：用选择工具选择对象后再执行。正在编辑文字时无法执行。
- “无法执行动作…”：“挖空组”使用“动作”面板中动作集“S2A”里的动作“グループの抜き”，请载入该动作集。
- 快捷键无效：确认面板已显示且 Illustrator 位于前台。其他应用（如 Keyboard Maestro）使用相同按键时，可能会同时响应。
- 撤销效果：在 Illustrator 中撤销（⌘Z）。
- 恢复初始设置：“设置”›“面板”›“全部恢复默认”。删除应用时，将“应用程序”中的 VectorFX.app 移到废纸篓。
""",
 "ko": """## 기본 조작
VectorFX는 Illustrator의 효과, 패스파인더, 컴파운드 패스, 단면 등을 팔레트 버튼과 단축키로 실행합니다.
- 팔레트 표시: Illustrator가 앞에 있을 때 ⌃A(기본값)를 누르고, 다시 누르면 가립니다. 메인 윈도우의 [팔레트 보기], [파일] › [팔레트 보기/가리기](⇧⌘P), 메뉴 막대 아이콘으로도 표시할 수 있습니다.
- 팔레트는 Illustrator가 앞에 있을 때만 표시됩니다. 다른 앱으로 전환하면 가려지고 Illustrator로 돌아오면 다시 표시됩니다. 팔레트를 클릭해도 Illustrator의 선택은 바뀌지 않습니다.
- 실행: 팔레트의 버튼을 클릭합니다. 선택한 개체에 실행합니다.
- 이름 뒤에 “…”가 있는 항목은 Illustrator 대화상자를 엽니다. 닫을 때까지 다음 작업은 기다립니다.

## 값을 지정해 적용하는 효과
그림자 만들기, 패스 이동, 사각형, 지그재그, 거칠게 하기는 대화상자 없이 메인 윈도우에서 정한 값으로 효과를 적용합니다. 길이는 문서 단위입니다.
- 팔레트에서 Option을 누른 채 클릭하면 대신 Illustrator 대화상자를 엽니다.
- 적용한 효과는 모양 패널에서 더블클릭해 조정할 수 있습니다.
- 여러 개체를 선택하면 각각에 효과를 적용합니다.

## 메인 윈도우
- 왼쪽 목록: 체크한 항목이 팔레트에 표시됩니다. 오른쪽 끝은 지정한 단축키입니다.
- 오른쪽: [Illustrator에서 실행](⌘Return), 단축키, 효과 값, 스크립트 파일 위치.
- 스크립트 파일을 찾을 수 없는 항목에는 ⚠가 표시됩니다. [파일 선택…]으로 다시 지정하세요.
- 아래쪽에 마지막 실행 결과(실패 이유 포함)를 표시합니다. 팔레트 아래에도 표시됩니다.

## 단축키
- 항목별 단축키는 팔레트가 표시되어 있고 Illustrator가 앞에 있을 때만 작동하므로 ⇧K나 - 같은 보조 키 없는 키도 사용할 수 있습니다. 팔레트를 가리면 그 키는 Illustrator에서 평소대로 사용됩니다.
- 지정: 메인 윈도우에서 항목을 선택하고 단축키 칸을 클릭한 뒤 키를 누릅니다. Esc로 취소합니다. 다른 항목이 사용 중인 키는 그 항목에서 해제하고 이 항목에 지정합니다.
- 팔레트 표시 단축키(기본값 ⌃A): 설정 › 팔레트에서 변경하거나 끌 수 있습니다.
- 앱 표시 단축키: 설정 › 시작 및 백그라운드에서 지정하면 어떤 앱에서든 메인 윈도우를 표시합니다(기본값 없음).
- ⌘0 메인 윈도우 열기, ⌘, 설정, ⌘W 윈도우 닫기, ⌘? 도움말

## 설정
[VectorFX] › [설정…](⌘,)으로 엽니다.
- 시작 및 백그라운드: 로그인 시 실행, Dock 및 앱 전환기에서 가리기, 윈도우를 닫아도 계속 실행, 메뉴 막대 아이콘, 앱 표시 단축키.
- 팔레트: 팔레트 표시 단축키, [모두 기본값으로 되돌리기](항목·단축키·효과 값. 스크립트 파일 위치는 유지).
- 설정 공유: 팔레트 항목·단축키·효과 값의 내보내기·가져오기와 동기화.
- 정보: 버전과 링크.

## 권한
처음 실행할 때 VectorFX가 'Adobe Illustrator'를 제어하도록 허용할지 묻습니다. [허용]을 선택하세요. 허용하지 않았다면 시스템 설정 › 개인정보 보호 및 보안 › 자동화에서 VectorFX의 'Adobe Illustrator'를 켜세요. 손쉬운 사용 권한은 사용하지 않습니다.

## 상주와 종료
윈도우를 닫아도 계속 실행되어 팔레트와 단축키를 사용할 수 있습니다(설정에서 끄면 닫을 때 종료). Dock 아이콘, 메뉴 막대 아이콘, Finder에서 다시 열기, 앱 표시 단축키로 다시 표시합니다. [VectorFX] › [VectorFX 종료](⌘Q) 또는 메뉴 막대 아이콘에서 종료합니다.

## 문제 해결
- '먼저 개체를 선택하세요': 선택 도구로 개체를 선택한 뒤 실행합니다. 텍스트를 편집 중일 때는 실행할 수 없습니다.
- '액션 …을(를) 실행할 수 없습니다': 그룹 녹아웃은 [액션] 패널의 세트 'S2A'에 있는 액션 'グループの抜き'를 사용합니다. 세트를 불러오세요.
- 단축키가 작동하지 않음: 팔레트가 표시되어 있는지, Illustrator가 앞에 있는지 확인하세요. 다른 앱(Keyboard Maestro 등)이 같은 키를 사용하면 둘 다 반응할 수 있습니다.
- 효과 되돌리기: Illustrator에서 실행 취소(⌘Z)합니다.
- 처음 상태로: 설정 › 팔레트 › 모두 기본값으로 되돌리기. 앱을 삭제하려면 응용 프로그램 폴더의 VectorFX.app을 휴지통으로 옮깁니다.
""",
}
