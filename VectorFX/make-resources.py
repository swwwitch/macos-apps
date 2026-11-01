# -*- coding: utf-8 -*-
from pathlib import Path
import json
root = Path(__file__).parent
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
# Command names follow Illustrator's menus in each language.
rows = '''heading|アピアランスをパレットから操作|Appearance from a Palette|从面板操作外观|팔레트에서 모양 조작
subtitle|効果・パスファインダー・線端などを、Illustratorのパレットとホットキーで実行します。|Run effects, Pathfinder, caps and more in Illustrator from a palette or hotkeys.|通过面板和快捷键在 Illustrator 中执行效果、路径查找器、端点等操作。|팔레트와 단축키로 Illustrator에서 효과, 패스파인더, 단면 등을 실행합니다.
palette.title|アピアランス|Appearance|外观|모양
palette.show|パレットを表示|Show Palette|显示面板|팔레트 보기
palette.hide|パレットを隠す|Hide Palette|隐藏面板|팔레트 가리기
palette.toggle|パレットを表示／隠す|Show/Hide Palette|显示/隐藏面板|팔레트 보기/가리기
palette.waiting|パレットはIllustratorが前面のときに表示されます。|The palette appears while Illustrator is in front.|Illustrator 位于前台时显示面板。|팔레트는 Illustrator가 앞에 있을 때 표시됩니다.
palette.empty|表示する項目がありません。メインウインドウでチェックを入れてください。|No items to show. Check items in the main window.|没有可显示的项目。请在主窗口中勾选项目。|표시할 항목이 없습니다. 메인 윈도우에서 체크하세요.
palette.optionHint|クリックで値を指定して適用、Option＋クリックでIllustratorのダイアログボックスを開きます。|Click to apply with the set values; Option-click opens Illustrator's dialog box.|单击以设定的数值应用，按住 Option 单击打开 Illustrator 的对话框。|클릭하면 지정한 값으로 적용하고, Option+클릭하면 Illustrator 대화상자를 엽니다.
detail.none|左の一覧から項目を選んでください。|Choose an item on the left.|请从左侧列表选择项目。|왼쪽 목록에서 항목을 선택하세요.
detail.run|Illustratorで実行|Run in Illustrator|在 Illustrator 中执行|Illustrator에서 실행
detail.runDialog|ダイアログボックスを開く|Open Dialog Box|打开对话框|대화상자 열기
detail.hotkey|ホットキー|Hotkey|快捷键|단축키
detail.hotkeyNote|パレットを表示していて、Illustratorが前面のときだけ使えます。そのため修飾キーなしのキー（- など）も割り当てられます。|Works only while the palette is shown and Illustrator is in front, so keys without modifiers (such as -) can be assigned.|仅在显示面板且 Illustrator 位于前台时可用，因此也可以分配不带修饰键的按键（如 -）。|팔레트가 표시되어 있고 Illustrator가 앞에 있을 때만 작동하므로 보조 키 없는 키(- 등)도 지정할 수 있습니다.
detail.values|適用する値|Values|应用的数值|적용할 값
detail.valuesNote|長さはドキュメントの単位です。適用後はアピアランスパネルで調整できます。|Lengths use the document's units. Adjust later in the Appearance panel.|长度使用文档的单位。应用后可在“外观”面板中调整。|길이는 문서 단위입니다. 적용 후 모양 패널에서 조정할 수 있습니다.
detail.resetValues|初期値に戻す|Reset to Default|恢复默认|기본값으로 되돌리기
list.showInPalette|「%@」をパレットに表示|Show “%@” in the palette|在面板中显示“%@”|“%@”을(를) 팔레트에 표시
list.showInPaletteHint|チェックを入れた項目をパレットに表示します|Checked items appear in the palette|勾选的项目显示在面板中|체크한 항목이 팔레트에 표시됩니다
script.title|スクリプトファイル|Script File|脚本文件|스크립트 파일
script.missing|スクリプトが見つかりません|Script not found|找不到脚本|스크립트를 찾을 수 없음
script.missingDetail|ファイルがありません。［ファイルを選ぶ…］で指定し直してください。|The file is missing. Choose it again with Choose File….|文件不存在。请用“选择文件…”重新指定。|파일이 없습니다. [파일 선택…]으로 다시 지정하세요.
script.choose|ファイルを選ぶ…|Choose File…|选择文件…|파일 선택…
script.reveal|Finderで表示|Show in Finder|在访达中显示|Finder에서 보기
script.reset|初期値に戻す|Reset to Default|恢复默认|기본값으로 되돌리기
kind.dialog|［効果］メニューの項目を実行し、Illustratorのダイアログボックスを開きます。|Runs the Effect menu item and opens Illustrator's dialog box.|执行“效果”菜单项并打开 Illustrator 的对话框。|[효과] 메뉴 항목을 실행하고 Illustrator 대화상자를 엽니다.
kind.menu|Illustratorのメニュー項目を実行します（ダイアログボックスなし）。|Runs the Illustrator menu item (no dialog box).|执行 Illustrator 菜单项（无对话框）。|Illustrator 메뉴 항목을 실행합니다(대화상자 없음).
kind.effect|下の値で効果を適用します（ダイアログボックスなし）。パレットではOption＋クリックでダイアログボックスを開きます。|Applies the effect with the values below (no dialog box). In the palette, Option-click opens the dialog box.|以下方数值应用效果（无对话框）。在面板中按住 Option 单击可打开对话框。|아래 값으로 효과를 적용합니다(대화상자 없음). 팔레트에서 Option+클릭하면 대화상자를 엽니다.
kind.code.buttCap|選択したパス（グループ・複合パスの中も含む）の線端を「線端なし」にします。|Sets the cap of the selected paths (also inside groups and compound paths) to Butt Cap.|将所选路径（包括编组和复合路径内）的端点设为平头端点。|선택한 패스(그룹·컴파운드 패스 안 포함)의 단면을 버트 단면으로 설정합니다.
kind.code.roundCap|選択したパス（グループ・複合パスの中も含む）の線端を「丸型線端」にします。|Sets the cap of the selected paths (also inside groups and compound paths) to Round Cap.|将所选路径（包括编组和复合路径内）的端点设为圆头端点。|선택한 패스(그룹·컴파운드 패스 안 포함)의 단면을 둥근 단면으로 설정합니다.
kind.code.projectingCap|選択したパス（グループ・複合パスの中も含む）の線端を「突出線端」にします。|Sets the cap of the selected paths (also inside groups and compound paths) to Projecting Cap.|将所选路径（包括编组和复合路径内）的端点设为方头端点。|선택한 패스(그룹·컴파운드 패스 안 포함)의 단면을 돌출 단면으로 설정합니다.
kind.code.openPath|［変形］効果で高さを0にし、［パスファインダー：アウトライン］で開いた線にします。テキストは先に長方形に変換して1 ptの丸型線端の線を付け、パスは線端を丸型にします。|Flattens to height 0 with the Transform effect and makes an open line with Pathfinder › Outline. Text is converted to a rectangle first and gets a 1 pt round-cap stroke; paths get round caps.|使用“变换”效果将高度设为 0，并用“路径查找器：轮廓”变为开放线条。文字会先转换为矩形并添加 1 pt 圆头端点描边，路径则设为圆头端点。|[변형] 효과로 높이를 0으로 만들고 [패스파인더: 윤곽선]으로 열린 선으로 만듭니다. 텍스트는 먼저 사각형으로 변환해 1 pt 둥근 단면 선을 적용하고, 패스는 단면을 둥글게 합니다.
kind.code.pasteLastStyle|ドキュメントのグラフィックスタイルのうち、一覧の最後にあるものを選択中のオブジェクトに適用します。|Applies the last graphic style in the document's list to the selected objects.|将文档图形样式列表中的最后一个样式应用到所选对象。|문서 그래픽 스타일 목록의 마지막 스타일을 선택한 개체에 적용합니다.
kind.code.expandUngroup|アピアランスを分割し、グループを解除して、選択を解除します。|Expands the appearance, ungroups and deselects.|扩展外观、取消编组并取消选择。|모양을 확장하고 그룹을 풀고 선택을 해제합니다.
kind.action|Illustratorの操作をアクションとして一時的に読み込んで実行します。|Loads the Illustrator operation as a temporary action and plays it.|将 Illustrator 操作临时载入为动作并执行。|Illustrator 작업을 임시 액션으로 불러와 실행합니다.
kind.namedAction|［アクション］パネルのセット「%2$@」にあるアクション「%1$@」を実行します。|Plays the action “%1$@” in the set “%2$@” of the Actions panel.|执行“动作”面板中动作集“%2$@”里的动作“%1$@”。|[액션] 패널의 세트 “%2$@”에 있는 액션 “%1$@”을(를) 실행합니다.
kind.script|スクリプトファイルをIllustratorで実行します。|Runs the script file in Illustrator.|在 Illustrator 中执行脚本文件。|Illustrator에서 스크립트 파일을 실행합니다.
join.miter|マイター|Miter|斜接|각지게
join.round|ラウンド|Round|圆角|둥글게
join.bevel|ベベル|Bevel|斜角|경사
unit.document|ドキュメントの単位|document units|文档单位|문서 단위
unit.perInch|/inch|/inch|/英寸|/인치
unit.perSegment|/線分|/segment|/线段|/선분
key.recordingHint|割り当てるキーを押してください。修飾キーなしでも割り当てられます。Escで取り消します。|Press the keys to assign. Keys without modifiers are allowed. Press Esc to cancel.|请按下要分配的按键，可以不带修饰键。按 Esc 取消。|지정할 키를 누르세요. 보조 키 없이도 지정할 수 있습니다. Esc로 취소합니다.
key.failed|このキーは使えません。ほかのアプリが使っているか、パレットのホットキーと同じです。|This key cannot be used: another app holds it or it is the palette hotkey.|无法使用此按键：其他应用正在使用，或与面板快捷键相同。|이 키는 사용할 수 없습니다. 다른 앱이 사용 중이거나 팔레트 단축키와 같습니다.
key.paletteKey|パレットを表示するホットキーと同じキーは割り当てられません。|This is the palette hotkey and cannot be assigned.|不能分配与显示面板快捷键相同的按键。|팔레트 표시 단축키와 같은 키는 지정할 수 없습니다.
key.takenFrom|「%@」から外して割り当てました。|Moved from “%@”.|已从“%@”移除并分配。|“%@”에서 해제하고 지정했습니다.
resident|ウインドウを閉じても常駐|Keep running after closing the window|关闭窗口后继续运行|윈도우를 닫아도 계속 실행
residentDetail|閉じた後もパレットとホットキーが使えます。オフにすると閉じたときに終了します。|The palette and hotkeys keep working after closing. When off, closing the window quits.|关闭后面板和快捷键仍可使用。关闭此项时，关闭窗口即退出。|닫은 후에도 팔레트와 단축키를 사용할 수 있습니다. 끄면 창을 닫을 때 종료됩니다.
launchShortcut|アプリ起動のホットキー|App launch keyboard shortcut|启动应用快捷键|앱 실행 키보드 단축키
openShortcuts|ショートカットを開く|Open Shortcuts|打开快捷指令|단축어 열기
shortcutDetail|ショートカットAppで「アプリを開く」にVectorFXを指定し、キーを割り当ててください。未起動時も使えます。|In Shortcuts, create an Open App action for VectorFX and assign a key. It works even when the app is not running.|在快捷指令中为 VectorFX 创建“打开 App”并分配按键，应用未运行时也可使用。|단축어 앱에서 VectorFX를 여는 동작을 만들고 키를 지정하세요. 앱이 실행 중이 아니어도 작동합니다.
appHotkeyHint|どのアプリからでもメインウインドウを表示します（起動中のとき）。初期値はありません。|Shows the main window from any app while running. No default.|应用运行时可从任何应用显示主窗口。无默认值。|실행 중일 때 어떤 앱에서든 메인 윈도우를 표시합니다. 기본값은 없습니다.
settings.paletteTab|パレット|Palette|面板|팔레트
settings.paletteKey|パレットを表示するホットキー|Palette hotkey|显示面板的快捷键|팔레트 표시 단축키
settings.paletteKeyNote|Illustratorが前面のときだけ使えます。押すたびにパレットを表示・非表示にします。|Works only while Illustrator is in front. Each press shows or hides the palette.|仅在 Illustrator 位于前台时可用。每按一次显示或隐藏面板。|Illustrator가 앞에 있을 때만 작동합니다. 누를 때마다 팔레트를 표시하거나 가립니다.
settings.typing|文字入力中|While Typing|输入文字时|텍스트 입력 중
settings.skipWhileTyping|文字入力中は修飾キーなしのホットキーを実行しない|Don't run hotkeys without modifiers while typing text|输入文字时不执行不带修饰键的快捷键|텍스트 입력 중에는 보조 키 없는 단축키를 실행하지 않음
settings.skipWhileTypingNote|Illustratorで文字ツールを使っているあいだ（文字の編集中を含む）、⌘や⌃を含まないキー（- や ⇧K など）は実行せず、そのまま文字として入力します。ダイアログボックスを開いているときも同じです。キーを押すたびにIllustratorの状態を確かめます。|While a type tool is active in Illustrator (including text editing), keys without ⌘ or ⌃ (such as - or ⇧K) are typed instead of running their command. The same applies while a dialog box is open. Illustrator is checked on each press.|在 Illustrator 中使用文字工具时（包括编辑文字），不含 ⌘ 或 ⌃ 的按键（如 - 或 ⇧K）不会执行命令，而是直接输入文字。打开对话框时也相同。每次按键时都会检查 Illustrator 的状态。|Illustrator에서 문자 도구를 사용하는 동안(텍스트 편집 포함) ⌘나 ⌃가 없는 키(- 또는 ⇧K 등)는 명령을 실행하지 않고 그대로 문자로 입력합니다. 대화상자가 열려 있을 때도 같습니다. 키를 누를 때마다 Illustrator의 상태를 확인합니다.
settings.skipNeedsAccess|アクセシビリティの許可が必要です（［起動・常駐］タブ）。許可するまでは、文字入力中もホットキーを実行します。|Needs Accessibility permission (Startup & Background tab). Until then, hotkeys also run while typing.|需要辅助功能权限（“启动与后台”标签）。授权前，输入文字时也会执行快捷键。|손쉬운 사용 권한이 필요합니다([시작 및 백그라운드] 탭). 허용하기 전까지는 텍스트 입력 중에도 단축키가 실행됩니다.
logic.title|しくみ|How It Works|工作原理|작동 방식
logic.source|Illustratorに送るExtendScript|ExtendScript Sent to Illustrator|发送到 Illustrator 的 ExtendScript|Illustrator로 보내는 ExtendScript
logic.check|ドキュメントが開いていて、オブジェクトが選択されているかを確かめます。文字の編集中（選択がテキスト範囲）のときは何もしません。|Checks that a document is open and objects are selected. Nothing happens while text is being edited (the selection is a text range).|检查是否打开了文档并选择了对象。正在编辑文字（选区为文字范围）时不执行任何操作。|문서가 열려 있고 개체가 선택되어 있는지 확인합니다. 텍스트 편집 중(선택이 텍스트 범위)일 때는 아무것도 하지 않습니다.
logic.menu|app.executeMenuCommand("%@") でIllustratorのメニュー項目を実行します。|Runs the Illustrator menu item with app.executeMenuCommand("%@").|通过 app.executeMenuCommand("%@") 执行 Illustrator 菜单项。|app.executeMenuCommand("%@")로 Illustrator 메뉴 항목을 실행합니다.
logic.dialogWait|Illustratorのダイアログボックスが開きます。閉じるまで次のコマンドは待ちます。|Illustrator's dialog box opens; the next command waits until it closes.|打开 Illustrator 的对话框，关闭前后续命令会等待。|Illustrator 대화상자가 열립니다. 닫을 때까지 다음 명령은 기다립니다.
logic.units|長さの値をドキュメントの単位（doc.rulerUnits）からptに換算します。|Converts lengths from the document's units (doc.rulerUnits) to points.|将长度从文档单位（doc.rulerUnits）换算为点。|길이 값을 문서 단위(doc.rulerUnits)에서 pt로 환산합니다.
logic.effect|選択中のオブジェクトそれぞれに、applyEffect() でLiveEffect「%1$@」を付けます（ダイアログボックスなし）。値：%2$@|Adds the LiveEffect “%1$@” to each selected object with applyEffect() (no dialog box). Values: %2$@|使用 applyEffect() 为每个所选对象添加 LiveEffect“%1$@”（无对话框）。数值：%2$@|선택한 개체마다 applyEffect()로 LiveEffect “%1$@”을(를) 적용합니다(대화상자 없음). 값: %2$@
logic.effectOption|パレットでOption＋クリック、または［ダイアログボックスを開く］のときは、代わりに app.executeMenuCommand("%@") でIllustratorのダイアログボックスを開きます。|With Option-click in the palette or Open Dialog Box, app.executeMenuCommand("%@") opens Illustrator's dialog box instead.|在面板中按住 Option 单击或点“打开对话框”时，改为通过 app.executeMenuCommand("%@") 打开 Illustrator 的对话框。|팔레트에서 Option+클릭하거나 [대화상자 열기]를 누르면 대신 app.executeMenuCommand("%@")로 Illustrator 대화상자를 엽니다.
logic.tempAction|1つの操作だけのアクションを一時ファイル（.aia）に書き出し、app.loadAction() で読み込んで app.doScript() で実行し、app.unloadAction() で取り除きます。セット名は「VectorFX Temporary」です。|Writes a one-step action to a temporary .aia, loads it with app.loadAction(), plays it with app.doScript() and removes it with app.unloadAction(). The set is named “VectorFX Temporary”.|将只有一个操作的动作写入临时文件（.aia），用 app.loadAction() 载入、app.doScript() 执行，再用 app.unloadAction() 移除。动作集名为“VectorFX Temporary”。|작업 하나만 있는 액션을 임시 파일(.aia)로 쓰고 app.loadAction()으로 불러와 app.doScript()로 실행한 뒤 app.unloadAction()으로 제거합니다. 세트 이름은 “VectorFX Temporary”입니다.
logic.events|アクションの内容：%@|Action steps: %@|动作内容：%@|액션 내용: %@
logic.namedAction|［アクション］パネルのセット「%1$@」にあるアクション「%2$@」を app.doScript() で実行します。セットが読み込まれていないと実行できません。|Plays the action “%2$@” in the set “%1$@” of the Actions panel with app.doScript(). The set must be loaded.|通过 app.doScript() 执行“动作”面板中动作集“%1$@”里的动作“%2$@”。必须已载入该动作集。|app.doScript()로 [액션] 패널의 세트 “%1$@”에 있는 액션 “%2$@”을(를) 실행합니다. 세트가 불러와져 있어야 합니다.
logic.script|下のスクリプトファイルを、do javascript (POSIX file …) でIllustratorに実行させます。選択の確認やダイアログボックスはスクリプト側の処理です。|Has Illustrator run the script file below with do javascript (POSIX file …). Selection checks and dialog boxes are up to the script.|通过 do javascript (POSIX file …) 让 Illustrator 执行下方的脚本文件。选区检查和对话框由脚本自行处理。|아래 스크립트 파일을 do javascript (POSIX file …)로 Illustrator에서 실행합니다. 선택 확인과 대화상자는 스크립트가 처리합니다.
logic.send|前面のIllustratorをアプリのパスで指定し、osascript の do javascript で送ります。結果（OK、または実行しなかった理由）を主画面とパレットの下に表示します。|Sends it to the frontmost Illustrator (addressed by its app path) with do javascript through osascript, and shows the result (OK, or why nothing ran) below the main window and the palette.|按应用路径指定前台的 Illustrator，通过 osascript 的 do javascript 发送，并在主窗口和面板下方显示结果（OK 或未执行的原因）。|앞에 있는 Illustrator를 앱 경로로 지정해 osascript의 do javascript로 보내고, 결과(OK 또는 실행하지 않은 이유)를 메인 윈도우와 팔레트 아래에 표시합니다.
logic.sendScript|前面のIllustratorをアプリのパスで指定し、osascript で送ります。スクリプトが終わると「実行しました」と表示します（スクリプトの中の成否は表示されません）。|Sends it to the frontmost Illustrator (addressed by its app path) through osascript. When the script ends, “Ran” is shown (the script's own result is not).|按应用路径指定前台的 Illustrator，通过 osascript 发送。脚本结束后显示“已执行”（不显示脚本内部的成功与否）。|앞에 있는 Illustrator를 앱 경로로 지정해 osascript로 보냅니다. 스크립트가 끝나면 “실행했습니다”를 표시합니다(스크립트 안의 성공 여부는 표시되지 않음).
logic.on|オン|on|开|켬
logic.off|オフ|off|关|끔
logic.listSeparator|、|, |，|, 
logic.code.cap|選択中のオブジェクトを順にたどり、グループの中・複合パスの中のパスまで降ります。¶線があるパス（stroked）だけ、strokeCap を StrokeCap.%CAP% にします。線のないパスとパス以外は変えません。|Walks the selected objects, down into groups and compound paths.¶Sets strokeCap to StrokeCap.%CAP% on paths with a stroke only; unstroked paths and other objects are left as they are.|依次遍历所选对象，深入到编组和复合路径内的路径。¶仅对有描边的路径（stroked）将 strokeCap 设为 StrokeCap.%CAP%；无描边的路径和其他对象不变。|선택한 개체를 차례로 살펴 그룹과 컴파운드 패스 안의 패스까지 들어갑니다.¶선이 있는 패스(stroked)만 strokeCap을 StrokeCap.%CAP%로 설정합니다. 선이 없는 패스와 그 밖의 개체는 바꾸지 않습니다.
logic.code.openPath|最初の選択がテキストかどうかを見ます。¶テキスト：［形状に変換：長方形］（Adobe Shape Effects、幅・高さに追加 0）を付けます。¶［変形］（Adobe Transform、垂直方向 0%、基準点 中央）を付けます。¶その下に［パスファインダー：アウトライン］（Adobe Pathfinder Command 6、塗りのないアートワークを残す）を付けます。どちらも内容の下に、変形→アウトラインの順で入ります。¶テキスト：記録したアクション「線を設定」（1 pt・丸型線端）を一時的に読み込んで実行します。パス：線端を丸型（StrokeCap.ROUNDENDCAP）にします。|Looks at whether the first selected object is text.¶Text: adds Convert to Shape › Rectangle (Adobe Shape Effects, extra width/height 0).¶Adds Transform (Adobe Transform, vertical 0%, reference point center).¶Adds Pathfinder › Outline below it (Adobe Pathfinder Command 6, keeping unpainted artwork). Both go under the contents, Transform above Outline.¶Text: plays the recorded action “Set Stroke” (1 pt, round cap) as a temporary action. Paths: sets round caps (StrokeCap.ROUNDENDCAP).|查看第一个所选对象是否为文字。¶文字：添加“转换为形状：矩形”（Adobe Shape Effects，额外宽高 0）。¶添加“变换”（Adobe Transform，垂直 0%，参考点为中心）。¶在其下方添加“路径查找器：轮廓”（Adobe Pathfinder Command 6，保留未上色图稿）。两者都位于内容下方，顺序为变换→轮廓。¶文字：临时载入并执行录制的动作“设置描边”（1 pt、圆头端点）。路径：设为圆头端点（StrokeCap.ROUNDENDCAP）。|첫 번째 선택이 텍스트인지 확인합니다.¶텍스트: [모양으로 변환: 사각형](Adobe Shape Effects, 추가 폭·높이 0)을 적용합니다.¶[변형](Adobe Transform, 세로 0%, 기준점 가운데)을 적용합니다.¶그 아래에 [패스파인더: 윤곽선](Adobe Pathfinder Command 6, 칠하지 않은 아트워크 유지)을 적용합니다. 둘 다 내용 아래에 변형→윤곽선 순서로 들어갑니다.¶텍스트: 기록한 액션 “선 설정”(1 pt, 둥근 단면)을 임시로 불러와 실행합니다. 패스: 단면을 둥글게(StrokeCap.ROUNDENDCAP) 합니다.
logic.code.pasteLastStyle|doc.graphicStyles の数を確かめます。0なら「ドキュメントにグラフィックスタイルがありません」と表示して終わります。¶一覧の最後のグラフィックスタイル（graphicStyles[length - 1]）を、選択中のオブジェクトそれぞれに applyTo() で適用します。|Checks doc.graphicStyles; with none, shows “The document has no graphic styles.” and stops.¶Applies the last graphic style in the list (graphicStyles[length - 1]) to each selected object with applyTo().|检查 doc.graphicStyles 的数量；为 0 时显示“文档中没有图形样式。”并结束。¶使用 applyTo() 将列表中最后一个图形样式（graphicStyles[length - 1]）应用到每个所选对象。|doc.graphicStyles 수를 확인합니다. 0이면 “문서에 그래픽 스타일이 없습니다.”를 표시하고 끝냅니다.¶목록의 마지막 그래픽 스타일(graphicStyles[length - 1])을 선택한 개체마다 applyTo()로 적용합니다.
logic.code.expandUngroup|app.executeMenuCommand("expandStyle")：［オブジェクト］＞［アピアランスを分割］。¶app.executeMenuCommand("ungroup")：グループ解除。¶app.executeMenuCommand("deselectall")：選択を解除。|app.executeMenuCommand("expandStyle"): Object › Expand Appearance.¶app.executeMenuCommand("ungroup"): Ungroup.¶app.executeMenuCommand("deselectall"): Deselect.|app.executeMenuCommand("expandStyle")：“对象”›“扩展外观”。¶app.executeMenuCommand("ungroup")：取消编组。¶app.executeMenuCommand("deselectall")：取消选择。|app.executeMenuCommand("expandStyle"): [개체] › [모양 확장].¶app.executeMenuCommand("ungroup"): 그룹 풀기.¶app.executeMenuCommand("deselectall"): 선택 해제.
settings.items|パレットの項目|Palette Items|面板项目|팔레트 항목
settings.itemsNote|表示する項目・カラー・ホットキー・効果の値はメインウインドウで変えます。下のボタンで、表示・カラー・ホットキー・値をすべて最初の状態に戻します（スクリプトファイルの場所は残ります）。|Change items, colors, hotkeys and effect values in the main window. The button below restores items, colors, hotkeys and values (script file locations are kept).|在主窗口中更改项目、颜色、快捷键和效果数值。下方按钮会恢复项目、颜色、快捷键和数值的初始状态（保留脚本文件位置）。|항목·색상·단축키·효과 값은 메인 윈도우에서 변경합니다. 아래 버튼으로 항목·색상·단축키·값을 모두 처음 상태로 되돌립니다(스크립트 파일 위치는 유지).
settings.resetAll|すべて初期値に戻す|Reset All to Defaults|全部恢复默认|모두 기본값으로 되돌리기
status.done|「%@」を実行しました。|Ran “%@”.|已执行“%@”。|“%@”을(를) 실행했습니다.
status.noIllustrator|Illustratorが起動していません。|Illustrator is not running.|Illustrator 未运行。|Illustrator가 실행 중이 아닙니다.
status.busy|実行待ちが多いため、今回の操作は見送りました。|Too many commands are waiting; this one was skipped.|等待执行的操作过多，本次操作已跳过。|대기 중인 실행이 많아 이번 작업은 건너뛰었습니다.
status.automation|Illustratorを操作する許可がありません。システム設定＞プライバシーとセキュリティ＞オートメーションで、VectorFXの「Adobe Illustrator」をオンにしてください。|VectorFX may not control Illustrator. Turn on “Adobe Illustrator” for VectorFX in System Settings › Privacy & Security › Automation.|VectorFX 无权控制 Illustrator。请在“系统设置”›“隐私与安全性”›“自动化”中为 VectorFX 打开“Adobe Illustrator”。|VectorFX가 Illustrator를 제어할 권한이 없습니다. 시스템 설정 › 개인정보 보호 및 보안 › 자동화에서 VectorFX의 'Adobe Illustrator'를 켜세요.
status.fileMissing|スクリプトが見つかりません：%@|Script not found: %@|找不到脚本：%@|스크립트를 찾을 수 없음: %@
status.err.nodoc|ドキュメントが開いていません。|No document is open.|没有打开的文档。|열린 문서가 없습니다.
status.err.nosel|オブジェクトを選択してください。|Select objects first.|请先选择对象。|먼저 개체를 선택하세요.
status.err.text|文字の編集中です。選択ツールでオブジェクトとして選んでください。|Text is being edited. Select it as an object with the Selection tool.|正在编辑文字。请用选择工具将其作为对象选中。|텍스트를 편집 중입니다. 선택 도구로 개체로 선택하세요.
status.err.action|アクション「%1$@」（セット「%2$@」）を実行できませんでした。［アクション］パネルにあるか確認してください。|Could not play the action “%1$@” (set “%2$@”). Check that it is in the Actions panel.|无法执行动作“%1$@”（动作集“%2$@”）。请确认“动作”面板中存在该动作。|액션 “%1$@”(세트 “%2$@”)을(를) 실행할 수 없습니다. [액션] 패널에 있는지 확인하세요.
status.err.nostyle|ドキュメントにグラフィックスタイルがありません。|The document has no graphic styles.|文档中没有图形样式。|문서에 그래픽 스타일이 없습니다.
status.err.file|ファイルを読み書きできませんでした。|Could not read or write a file.|无法读写文件。|파일을 읽거나 쓸 수 없습니다.
status.failed|「%1$@」を実行できませんでした：%2$@|Could not run “%1$@”: %2$@|无法执行“%1$@”：%2$@|“%1$@”을(를) 실행할 수 없습니다: %2$@
section.stylize|スタイライズ・ワープ|Stylize & Warp|风格化与变形|스타일화·변형
section.path|パス|Path|路径|패스
section.pathfinder|パスファインダー|Pathfinder|路径查找器|패스파인더
section.shape|形状に変換|Convert to Shape|转换为形状|모양으로 변환
section.distort|パスの変形|Distort & Transform|扭曲和变换|왜곡과 변형
section.misc|その他|Other|其他|기타
section.release|消去・分割|Clear & Expand|清除与扩展|지우기·확장
section.compoundShape|複合シェイプ|Compound Shape|复合形状|복합 모양
section.compoundPath|複合パス|Compound Path|复合路径|컴파운드 패스
section.caps|線端|Caps|端点|단면
cmd.roundCorners|角を丸くする|Round Corners|圆角|둥근 모퉁이
cmd.dropShadow|ドロップシャドウ|Drop Shadow|投影|그림자 만들기
cmd.warp|ワープ（円弧）|Warp (Arc)|变形（弧形）|변형(부채꼴)
cmd.extrude3D|3D 押し出し・ベベル|3D Extrude & Bevel|3D 凸出和斜角|3D 돌출과 경사
cmd.revolve3D|3D 回転体|3D Revolve|3D 绕转|3D 회전체
cmd.rotate3D|3D 回転|3D Rotate|3D 旋转|3D 회전
cmd.outlineObject|オブジェクトのアウトライン|Outline Object|轮廓化对象|개체 윤곽선
cmd.outlineStroke|パスのアウトライン|Outline Stroke|轮廓化描边|윤곽선 획
cmd.offsetPath|パスのオフセット|Offset Path|位移路径|패스 이동
cmd.pfAdd|追加|Add|相加|추가
cmd.pfIntersect|交差|Intersect|交集|교차
cmd.pfExclude|中マド|Exclude|差集|교차 영역 제외
cmd.pfSubtract|前面オブジェクトで型抜き|Subtract|减去顶层|앞면 개체 제외
cmd.pfMinusBack|背面オブジェクトで型抜き|Minus Back|减去后方对象|이면 개체 제외
cmd.pfMerge|合流|Merge|合并|병합
cmd.pfDivide|分割|Divide|分割|나누기
cmd.pfOutline|アウトライン|Outline|轮廓|윤곽선
cmd.pfCrop|切り抜き|Crop|裁剪|자르기
cmd.rectangle|長方形|Rectangle|矩形|사각형
cmd.ellipse|楕円形|Ellipse|椭圆|타원
cmd.roundedRectangle|角丸長方形|Rounded Rectangle|圆角矩形|둥근 사각형
cmd.zigzag|ジグザグ（折り返し1）|Zig Zag (1 Ridge)|波纹效果（1 个折点）|지그재그(1회)
cmd.zigzagFlat|ジグザグ（0-0）|Zig Zag (0-0)|波纹效果（0-0）|지그재그(0-0)
cmd.freeDistort|パスの自由変形|Free Distort|自由扭曲|자유 왜곡
cmd.freeDistortScript|パスの自由変形（スクリプト）|Free Distort (Script)|自由扭曲（脚本）|자유 왜곡(스크립트)
cmd.puckerBloat|パンク・膨張|Pucker & Bloat|收缩和膨胀|오목과 볼록
cmd.roughen|ラフ|Roughen|粗糙化|거칠게 하기
cmd.transform|変形|Transform|变换|변형
cmd.scribbleTweak|ランダム・ひねり|Tweak|扭拧|비틀기
cmd.twist|旋回|Twist|扭转|비틀어 돌리기
cmd.removeItem|項目を削除|Remove Item|删除所选项目|항목 삭제
cmd.duplicateItem|項目を複製|Duplicate Item|复制所选项目|항목 복제
cmd.pasteLastStyle|グラフィックスタイルを適用（最後）|Apply Last Graphic Style|应用最后一个图形样式|마지막 그래픽 스타일 적용
cmd.rasterize|ラスタライズ|Rasterize|栅格化|래스터화
cmd.sketchy|手書き風（KPTSketchy）|Sketchy (KPTSketchy)|手绘风格（KPTSketchy）|손그림 스타일(KPTSketchy)
cmd.strokeScale|すべての線幅を変更|Scale All Stroke Widths|更改所有描边粗细|모든 선 두께 변경
cmd.clearAppearance|アピアランスを消去|Clear Appearance|清除外观|모양 지우기
cmd.clearKeepFill|アピアランスを消去（塗りを残す）|Clear Appearance (Keep Fill)|清除外观（保留填色）|모양 지우기(칠 유지)
cmd.expandAppearance|アピアランスを分割|Expand Appearance|扩展外观|모양 확장
cmd.expandUngroup|アピアランスを分割（グループ解除）|Expand Appearance (Ungroup)|扩展外观（取消编组）|모양 확장(그룹 풀기)
cmd.knockout|グループの抜き|Knockout Group|挖空组|그룹 녹아웃
cmd.makeCompoundShape|複合シェイプを作成|Make Compound Shape|建立复合形状|복합 모양 만들기
cmd.releaseCompoundShape|複合シェイプを解除|Release Compound Shape|释放复合形状|복합 모양 풀기
cmd.makeCompoundPath|複合パスを作成|Make Compound Path|建立复合路径|컴파운드 패스 만들기
cmd.openPath|オープンパスにする|Make an Open Path|变为开放路径|열린 패스로 만들기
cmd.releaseCompoundPath|複合パスを解除|Release Compound Path|释放复合路径|컴파운드 패스 풀기
cmd.buttCap|線端なし|Butt Cap|平头端点|버트 단면
cmd.roundCap|丸型線端|Round Cap|圆头端点|둥근 단면
cmd.projectingCap|突出線端|Projecting Cap|方头端点|돌출 단면
param.opacity|不透明度|Opacity|不透明度|불투명도
param.offsetX|X軸オフセット|X Offset|X 位移|X 오프셋
param.offsetY|Y軸オフセット|Y Offset|Y 位移|Y 오프셋
param.blur|ぼかし|Blur|模糊|흐림 효과
param.offset|オフセット|Offset|位移|이동
param.join|角の形状|Joins|连接|연결
param.extraWidth|幅に追加|Extra Width|额外宽度|추가 폭
param.cornerRadius|角丸の半径|Corner Radius|圆角半径|모퉁이 반경
param.extraHeight|高さに追加|Extra Height|额外高度|추가 높이
param.size|大きさ|Size|大小|크기
param.ridges|折り返し|Ridges|折点|능선
param.detail|詳細|Detail|细节|세부
param.smooth|滑らかに|Smooth|平滑|매끄럽게
item.color|カラー|Color|颜色|색상
color.none|なし|None|无|없음
color.selected|選択中|Selected|已选择|선택됨
color.red|レッド|Red|红色|빨간색
color.orange|オレンジ|Orange|橙色|주황색
color.yellow|イエロー|Yellow|黄色|노란색
color.green|グリーン|Green|绿色|초록색
color.blue|ブルー|Blue|蓝色|파란색
color.purple|パープル|Purple|紫色|보라색
color.gray|グレイ|Gray|灰色|회색
settingsWindow|設定|Settings|设置|설정
help|VectorFXヘルプ|VectorFX Help|VectorFX 帮助|VectorFX 도움말
helpMenu|ヘルプ|Help|帮助|도움말
about|VectorFXについて|About VectorFX|关于 VectorFX|VectorFX에 관하여
aboutDetail|Illustratorの効果・パスファインダー・線端などをパレットとホットキーで実行します。サポート：同梱のREADME.md|Runs Illustrator effects, Pathfinder, caps and more from a palette and hotkeys. Support: bundled README.md|通过面板和快捷键执行 Illustrator 的效果、路径查找器、端点等。支持：内置 README.md|팔레트와 단축키로 Illustrator의 효과, 패스파인더, 단면 등을 실행합니다. 지원: 포함된 README.md
settings|設定…|Settings…|设置…|설정…
quit|VectorFXを終了|Quit VectorFX|退出 VectorFX|VectorFX 종료
hide|VectorFXを隠す|Hide VectorFX|隐藏 VectorFX|VectorFX 가리기
services|サービス|Services|服务|서비스
hideOthers|ほかを隠す|Hide Others|隐藏其他|기타 가리기
showAll|すべてを表示|Show All|全部显示|모두 보기
fileMenu|ファイル|File|文件|파일
openMainWindow|メインウインドウを開く|Open Main Window|打开主窗口|메인 윈도우 열기
close|ウインドウを閉じる|Close Window|关闭窗口|윈도우 닫기
editMenu|編集|Edit|编辑|편집
windowMenu|ウインドウ|Window|窗口|윈도우
minimize|しまう|Minimize|最小化|최소화
zoom|拡大／縮小|Zoom|缩放|확대/축소
bringAllToFront|すべてを手前に移動|Bring All to Front|前置全部窗口|모두 앞으로 가져오기
undo|取り消す|Undo|撤销|실행 취소
redo|やり直す|Redo|重做|실행 복귀
cut|カット|Cut|剪切|오려두기
copy|コピー|Copy|拷贝|복사하기
paste|ペースト|Paste|粘贴|붙여넣기
selectAll|すべてを選択|Select All|全选|모두 선택'''
table = [line.split('|') for line in rows.splitlines()]
assert all(len(r) == 5 for r in table), [r[0] for r in table if len(r) != 5]
assert len({r[0] for r in table}) == len(table), 'duplicate key'

# Help text lives in help_text.py (markup rendered by Shared/AppStandards/HelpDocument.swift).
from help_text import HELP

for i, lang in enumerate(['ja', 'en', 'zh-Hans', 'ko']):
    p = root / 'Resources' / f'{lang}.lproj'
    p.mkdir(parents=True, exist_ok=True)
    (p / 'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0])} = {json.dumps(r[i + 1], ensure_ascii=False)};' for r in table) + '\n')
    (p / 'InfoPlist.strings').write_text('"CFBundleDisplayName" = "VectorFX";\n' + {
        'ja': '"NSAppleEventsUsageDescription" = "パレットとホットキーの操作をIllustratorで実行するために使用します。";\n',
        'en': '"NSAppleEventsUsageDescription" = "Used to run the palette and hotkey commands in Illustrator.";\n',
        'zh-Hans': '"NSAppleEventsUsageDescription" = "用于在 Illustrator 中执行面板和快捷键的操作。";\n',
        'ko': '"NSAppleEventsUsageDescription" = "팔레트와 단축키 명령을 Illustrator에서 실행하는 데 사용합니다.";\n'}[lang])
    (p / 'Help.txt').write_text(HELP[lang])
print('resources:', len(table), 'keys x 4 languages')
