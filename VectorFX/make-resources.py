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
kind.code.flatten|テキストを1つ選んで実行します。長方形（幅＋1・高さ＋3）に変換し、［変形］効果で上端を基準に高さを0にして、フォントサイズの半分だけ下げて線にします。|Run with one text object selected. Converts it to a rectangle (width +1, height +3), flattens it to height 0 at the top with the Transform effect and moves it down by half the font size to make a line.|选中一个文字对象后执行。先转换为矩形（宽 +1、高 +3），再用“变换”效果以顶边为基准将高度设为 0，并下移字体大小的一半形成线条。|텍스트 하나를 선택하고 실행합니다. 사각형(폭 +1, 높이 +3)으로 변환한 뒤 [변형] 효과로 위쪽 기준 높이를 0으로 만들고 글자 크기의 절반만큼 내려 선으로 만듭니다.
kind.code.flattenLine|［変形］効果で高さを0にし、［パスファインダー：アウトライン］で線にします。テキストは長方形に変換し、上端を基準にフォントサイズの半分だけ下げて、1 ptの丸型線端の線を付けます。パス以外は線端を丸型にします。アピアランスパネルで「変形」を「アウトライン」の上に移し、「アウトライン」の［分割およびアウトライン適用時に塗りのないアートワークを削除］をオフにすると線が見えます。|Flattens to height 0 with the Transform effect and turns it into a line with Pathfinder › Outline. Text is converted to a rectangle, moved down from the top by half the font size and given a 1 pt round-cap stroke; other objects get round caps. In the Appearance panel, move Transform above Outline and turn off Outline's option to remove unpainted artwork to see the line.|使用“变换”效果将高度设为 0，并用“路径查找器：轮廓”变为线条。文字会先转换为矩形，以顶边为基准下移字体大小的一半，并添加 1 pt 圆头端点描边；其他对象设为圆头端点。在“外观”面板中将“变换”移到“轮廓”上方，并关闭“轮廓”中删除未上色图稿的选项即可看到线条。|[변형] 효과로 높이를 0으로 만들고 [패스파인더: 윤곽선]으로 선으로 만듭니다. 텍스트는 사각형으로 변환해 위쪽 기준으로 글자 크기의 절반만큼 내리고 1 pt 둥근 단면 선을 적용합니다. 그 밖의 개체는 단면을 둥글게 합니다. 모양 패널에서 '변형'을 '윤곽선' 위로 옮기고 '윤곽선'의 칠하지 않은 아트워크 삭제 옵션을 끄면 선이 보입니다.
kind.code.openPath|［変形］効果で高さを0にし、［パスファインダー：アウトライン］で開いた線にします。テキストは先に長方形に変換して1 ptの丸型線端の線を付け、パスは線端を丸型にします。|Flattens to height 0 with the Transform effect and makes an open line with Pathfinder › Outline. Text is converted to a rectangle first and gets a 1 pt round-cap stroke; paths get round caps.|使用“变换”效果将高度设为 0，并用“路径查找器：轮廓”变为开放线条。文字会先转换为矩形并添加 1 pt 圆头端点描边，路径则设为圆头端点。|[변형] 효과로 높이를 0으로 만들고 [패스파인더: 윤곽선]으로 열린 선으로 만듭니다. 텍스트는 먼저 사각형으로 변환해 1 pt 둥근 단면 선을 적용하고, 패스는 단면을 둥글게 합니다.
kind.code.resetBlack|アピアランスを消去し、塗りを黒・線なし・不透明度100%にします。|Clears the appearance, then sets a black fill, no stroke and 100% opacity.|清除外观，然后设为黑色填色、无描边、不透明度 100%。|모양을 지운 뒤 검정 칠, 선 없음, 불투명도 100%로 설정합니다.
kind.code.resetWhite|アピアランスを消去し、塗りを白・線なし・不透明度100%にします。|Clears the appearance, then sets a white fill, no stroke and 100% opacity.|清除外观，然后设为白色填色、无描边、不透明度 100%。|모양을 지운 뒤 흰색 칠, 선 없음, 불투명도 100%로 설정합니다.
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
settings.items|パレットの項目|Palette Items|面板项目|팔레트 항목
settings.itemsNote|表示する項目・ホットキー・効果の値はメインウインドウで変えます。下のボタンで、表示・ホットキー・値をすべて最初の状態に戻します（スクリプトファイルの場所は残ります）。|Change items, hotkeys and effect values in the main window. The button below restores items, hotkeys and values (script file locations are kept).|在主窗口中更改项目、快捷键和效果数值。下方按钮会恢复项目、快捷键和数值的初始状态（保留脚本文件位置）。|항목·단축키·효과 값은 메인 윈도우에서 변경합니다. 아래 버튼으로 항목·단축키·값을 모두 처음 상태로 되돌립니다(스크립트 파일 위치는 유지).
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
status.err.needtext|テキストを1つ選択してください。|Select one text object.|请选择一个文字对象。|텍스트 개체 하나를 선택하세요.
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
cmd.flattenLine|変形：つぶして線にする|Transform: Flatten to a Line|变换：压扁成线|변형: 납작하게 선으로
cmd.flatten|変形：テキストを線にする（＋1・＋3）|Transform: Text to a Line (+1, +3)|变换：文字变为线条（+1、+3）|변형: 텍스트를 선으로(+1, +3)
cmd.removeItem|項目を削除|Remove Item|删除所选项目|항목 삭제
cmd.duplicateItem|項目を複製|Duplicate Item|复制所选项目|항목 복제
cmd.addFill|新規塗りを追加|Add New Fill|添加新填色|새 칠 추가
cmd.addStroke|新規線を追加|Add New Stroke|添加新描边|새 선 추가
cmd.resetBlack|リセットして塗りを黒、線なし|Reset: Black Fill, No Stroke|重置：黑色填色、无描边|초기화: 검정 칠, 선 없음
cmd.resetWhite|リセットして塗りを白、線なし|Reset: White Fill, No Stroke|重置：白色填色、无描边|초기화: 흰색 칠, 선 없음
cmd.textBlack|テキストの塗りを黒＋アウトライン|Text: Black Fill + Outline Object|文字：黑色填色 + 轮廓化对象|텍스트: 검정 칠 + 개체 윤곽선
cmd.textWhite|テキストの塗りを白＋アウトライン|Text: White Fill + Outline Object|文字：白色填色 + 轮廓化对象|텍스트: 흰색 칠 + 개체 윤곽선
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
