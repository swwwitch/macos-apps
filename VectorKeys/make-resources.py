from pathlib import Path
import json
root = Path(__file__).parent
APP = 'VectorKeys'
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''heading|Illustratorでスクリプトを高速実行|Run Illustrator Scripts Fast|在 Illustrator 中快速运行脚本|Illustrator에서 스크립트를 빠르게 실행
subtitle|登録したスクリプトを、Illustratorが前面のときにキーボードショートカットで実行します。|Runs your scripts with keyboard shortcuts while Illustrator is in front.|在 Illustrator 位于前台时，用键盘快捷键运行已登记的脚本。|Illustrator가 앞에 있을 때 등록한 스크립트를 키보드 단축키로 실행합니다.
useHotkeysHint|オフにすると、スクリプトのショートカットをすべて一時停止します。|When off, all script shortcuts are paused.|关闭后暂停所有脚本快捷键。|끄면 모든 스크립트 단축키를 일시 정지합니다.
state.hint|スクリプトのショートカットは、Illustratorが前面のときだけ働きます。|Script shortcuts work only while Illustrator is in front.|脚本快捷键仅在 Illustrator 位于前台时有效。|스크립트 단축키는 Illustrator가 앞에 있을 때만 작동합니다.
addMenu|スクリプトを追加…|Add Scripts…|添加脚本…|스크립트 추가…
add|追加|Add|添加|추가
add.skipped|スクリプトではないファイルを%d個とばしました（.jsx・.js・.jsxbin だけ追加できます）。|Skipped %d files that are not scripts (only .jsx, .js and .jsxbin can be added).|已跳过 %d 个非脚本文件（仅可添加 .jsx、.js 和 .jsxbin）。|스크립트가 아닌 파일 %d개를 건너뛰었습니다(.jsx, .js, .jsxbin만 추가 가능).
empty|スクリプトがまだありません。［スクリプトを追加…］で選ぶか、ここへ .jsx ファイルをドラッグしてください。|No scripts yet. Click Add Scripts… or drag .jsx files here.|还没有脚本。点按“添加脚本…”或将 .jsx 文件拖到此处。|아직 스크립트가 없습니다. [스크립트 추가…]를 클릭하거나 .jsx 파일을 여기로 드래그하세요.
selectScript|スクリプトを選んでください|Select a script|请选择脚本|스크립트를 선택하세요
count|%d本|%d scripts|%d 个|%d개
legacy.badge|旧メニュー手順・実行不可|Legacy menu step — unavailable|旧菜单步骤・不可运行|이전 메뉴 단계 · 실행 불가
legacy.unsupported|以前のメニュー手順を含むため、この項目は実行しません。保存データは残しています。メニュー手順を削除すると、残ったスクリプトだけを実行できます。|This item contains legacy menu steps and will not run. Its saved data is retained. Remove those steps to run the remaining scripts.|此项目包含旧菜单步骤，因此不会运行。已保留保存的数据。删除菜单步骤后即可运行其余脚本。|이전 메뉴 단계가 있어 이 항목은 실행하지 않습니다. 저장 데이터는 보존됩니다. 메뉴 단계를 삭제하면 남은 스크립트를 실행할 수 있습니다.
steps|スクリプト|Scripts|脚本|스크립트
steps.count|手順%d|%d steps|%d 个步骤|단계 %d개
steps.empty|手順がありません。下のボタンで挿入してください。|No steps. Insert one with the buttons below.|没有步骤。请用下方按钮插入。|단계가 없습니다. 아래 버튼으로 넣으세요.
step.addScript|スクリプトの実行|Run Script|运行脚本|스크립트 실행
stepMenu|手順の操作|Step actions|步骤操作|단계 작업
moveUp|上へ|Move Up|上移|위로
moveDown|下へ|Move Down|下移|아래로
addItem|追加|Add|添加|추가
result.fileMissingStep|手順%dのファイルが見つかりません。|The file of step %d was not found.|找不到步骤 %d 的文件。|단계 %d의 파일을 찾을 수 없습니다.
result.failedStep|手順%dでエラー：%@|Error at step %d: %@|步骤 %d 出错：%@|단계 %d 오류: %@
undo.steps|手順の変更|Change Steps|更改步骤|단계 변경
undo.add|追加|Add|添加|추가
tools.kmOff|選んだスクリプトのKMマクロをオフにする|Turn Off the Selected Scripts’ KM Macros|关闭所选脚本的 KM 宏|선택한 스크립트의 KM 매크로 끄기
tools.kmOn|選んだスクリプトのKMマクロをオンに戻す|Turn the Selected Scripts’ KM Macros Back On|重新打开所选脚本的 KM 宏|선택한 스크립트의 KM 매크로 다시 켜기
km.turnOffButton|KMの元のマクロをオフにする（%d本）|Turn Off the Original KM Macros (%d)|关闭 KM 中的原始宏（%d 个）|KM의 원래 매크로 끄기(%d개)
km.turnedOff|Keyboard Maestroのマクロを%d本オフにしました|Turned off %d Keyboard Maestro macros|已关闭 %d 个 Keyboard Maestro 宏|Keyboard Maestro 매크로 %d개를 껐습니다
km.turnedOn|Keyboard Maestroのマクロを%d本オンに戻しました|Turned %d Keyboard Maestro macros back on|已重新打开 %d 个 Keyboard Maestro 宏|Keyboard Maestro 매크로 %d개를 다시 켰습니다
km.denied|Keyboard Maestroを操作する許可がありません。システム設定＞プライバシーとセキュリティ＞オートメーションで、VectorKeysのKeyboard Maestroをオンにしてください。|Not allowed to control Keyboard Maestro. Turn on Keyboard Maestro for VectorKeys in System Settings > Privacy & Security > Automation.|没有控制 Keyboard Maestro 的权限。请在“系统设置”>“隐私与安全性”>“自动化”中为 VectorKeys 打开 Keyboard Maestro。|Keyboard Maestro를 제어할 권한이 없습니다. 시스템 설정 > 개인정보 보호 및 보안 > 자동화에서 VectorKeys의 Keyboard Maestro를 켜세요.
km.failed|Keyboard Maestroのマクロを切り替えられませんでした：%@|Could not switch the Keyboard Maestro macros: %@|无法切换 Keyboard Maestro 宏：%@|Keyboard Maestro 매크로를 전환하지 못했습니다: %@
undo.import|取り込み|Import|导入|가져오기
undo.delete|削除|Delete|删除|삭제
undo.rename|名前の変更|Rename|重命名|이름 변경
undo.category|カテゴリの変更|Change Category|更改类别|카테고리 변경
undo.newCategory|カテゴリの作成|New Category|新建类别|카테고리 만들기
undo.renameCategory|カテゴリ名の変更|Rename Category|重命名类别|카테고리 이름 변경
undo.deleteCategory|カテゴリの削除|Delete Category|删除类别|카테고리 삭제
tools.stats|統計…|Statistics…|统计…|통계…
stats.title|使用回数の統計|Run Statistics|使用次数统计|사용 횟수 통계
stats.total|合計%d回・使ったスクリプト%d本／全%d本|%d runs in all · %d of %d scripts used|共 %d 次 · 已使用 %d 个／共 %d 个|합계 %d회 · 사용한 스크립트 %d개 / 전체 %d개
stats.uses|回数|Runs|次数|횟수
stats.last|最終実行|Last Run|最近运行|최근 실행
stats.hint|使った回数の多い順です（エラーなく終わった実行を数えます）。行をダブルクリックすると、メインウインドウでそのスクリプトを選びます。|Most runs first (runs that finished without an error). Double-click a row to select the script in the main window.|按使用次数从多到少排列（统计无错误完成的运行）。双击某行可在主窗口中选中该脚本。|사용 횟수가 많은 순입니다(오류 없이 끝난 실행을 셉니다). 행을 더블클릭하면 메인 윈도우에서 그 스크립트를 선택합니다.
tools.replace|アイテム名の検索と置換…|Find and Replace in Names…|在名称中查找和替换…|이름 찾기 및 바꾸기…
replace.title|アイテム名の検索と置換|Find and Replace in Names|在名称中查找和替换|이름 찾기 및 바꾸기
replace.detail|選んだ%d本の名前が対象です。ファイル名は変わりません。|Applies to the names of the %d selected scripts. File names stay.|对所选 %d 个脚本的名称生效。文件名不变。|선택한 스크립트 %d개의 이름이 대상입니다. 파일 이름은 바뀌지 않습니다.
replace.find|検索|Find|查找|찾기
replace.with|置換|Replace|替换为|바꾸기
replace.regex|正規表現|Regular expression|正则表达式|정규 표현식
replace.caseSensitive|大文字と小文字を区別|Match case|区分大小写|대소문자 구분
replace.to|置換後|becomes|替换为|바뀐 이름
replace.changes|%d本が変わります|%d names change|%d 个名称将更改|이름 %d개가 바뀝니다
replace.button|置換|Replace|替换|바꾸기
replace.badPattern|正規表現が正しくありません。|The regular expression is not valid.|正则表达式无效。|정규 표현식이 올바르지 않습니다.
replace.done|%d本の名前を置換しました|Replaced %d names|已替换 %d 个名称|이름 %d개를 바꿨습니다
viewMenu|表示|View|显示|보기
toolsMenu|ツール|Tools|工具|도구
tools.stripNumbering|KMマクロのナンバリングを削除|Remove KM Macro Numbering|删除 KM 宏编号|KM 매크로 번호 삭제
tools.stripped|%d本の名前から番号を外しました|Removed the numbering from %d names|已从 %d 个名称中删除编号|이름 %d개에서 번호를 지웠습니다
selectedCount|%d本を選択中|%d scripts selected|已选择 %d 个|%d개 선택됨
selectedHint|選んだスクリプトを左のカテゴリへドラッグしても振り分けられます。⌘クリック・⇧クリックで選択を増やせます。|You can also drag the selected scripts onto a category on the left. ⌘-click or ⇧-click to select more.|也可以将所选脚本拖到左侧的类别。⌘点按或⇧点按可增加选择。|선택한 스크립트를 왼쪽 카테고리로 드래그해도 나눌 수 있습니다. ⌘클릭·⇧클릭으로 선택을 늘릴 수 있습니다.
category.mixed|（複数）|(Mixed)|（多个）|(여러 개)
category|カテゴリ|Category|类别|카테고리
category.all|すべて|All|全部|전체
category.none|未分類|Uncategorized|未分类|미분류
category.new|新しいカテゴリ|New Category|新建类别|새 카테고리
category.newTitle|新しいカテゴリの名前|Name of the new category|新类别的名称|새 카테고리 이름
category.renameTitle|カテゴリの名前を変更|Rename the category|重命名类别|카테고리 이름 변경
category.rename|名前を変更…|Rename…|重命名…|이름 변경…
category.delete|カテゴリを削除|Delete Category|删除类别|카테고리 삭제
category.deleteConfirm|カテゴリ「%@」を削除しますか？|Delete the category “%@”?|删除类别“%@”？|카테고리 “%@”을(를) 삭제할까요?
category.deleteDetail|中のスクリプトは削除せず、未分類に移します。|The scripts in it are kept and become uncategorized.|其中的脚本不会被删除，而是移到未分类。|안의 스크립트는 삭제하지 않고 미분류로 옮깁니다.
category.name|カテゴリ名|Category name|类别名称|카테고리 이름
taps.label|押し方|Press|按法|누르는 방법
taps.single|1回押す|Press once|按一次|한 번 누르기
taps.double|2回押す|Press twice|按两次|두 번 누르기
taps.hint|「2回押す」は続けて2回押したときに実行します。同じキーに「1回押す」のスクリプトもあると、そちらは2回目を待つ分（約0.3秒）遅れて実行します。|Press twice runs on two presses in a row. When the same key also has a Press once script, that one waits for a second press (about 0.3 s) before it runs.|“按两次”在连续按两次时运行。若同一按键还有“按一次”的脚本，该脚本会等待第二次按下（约 0.3 秒）后再运行。|'두 번 누르기'는 연속으로 두 번 눌렀을 때 실행합니다. 같은 키에 '한 번 누르기' 스크립트도 있으면 그쪽은 두 번째 누름을 기다리는 만큼(약 0.3초) 늦게 실행됩니다.
sort.label|並べ替え|Sort|排序|정렬
sort.manual|手動|Manual|手动|수동
sort.name|名前順|By Name|按名称|이름순
sort.hotkey|ショートカット順|By Shortcut|按快捷键|단축키순
sort.hint|一覧の並べ方。ドラッグで並べ替えられるのは「手動」で検索していないときです。同じキーが重なったときは、手動の並びで上にあるスクリプトが反応します。|How the list is ordered. Drag to reorder in Manual while not searching. When scripts share a key, the one higher in the manual order reacts.|列表的排序方式。在“手动”且未搜索时可拖移重新排序。多个脚本使用同一按键时，手动顺序中靠上的脚本会响应。|목록 정렬 방식. '수동'이고 검색하지 않을 때 드래그로 순서를 바꿀 수 있습니다. 같은 키를 쓰는 스크립트가 있으면 수동 순서에서 위에 있는 것이 반응합니다.
showUses|使用回数を表示|Show run counts|显示使用次数|사용 횟수 표시
uses.count|%d回|%d runs|%d 次|%d회
uses.detail|実行回数：%d回（最終：%@）|Runs: %d (last: %@)|运行次数：%d 次（最近：%@）|실행 횟수: %d회(최근: %@)
uses.never|まだ実行していません|Not run yet|尚未运行|아직 실행하지 않음
uses.hint|ショートカットと［実行］ボタンで、エラーなく終わった回数です。|Runs that finished without an error, from the shortcut or the Run button.|通过快捷键和“运行”按钮无错误完成的次数。|단축키와 [실행] 버튼으로 오류 없이 끝난 횟수입니다.
km.import|Keyboard Maestroから取り込む…|Import from Keyboard Maestro…|从 Keyboard Maestro 导入…|Keyboard Maestro에서 가져오기…
km.title|Keyboard Maestroからの取り込み|Import from Keyboard Maestro|从 Keyboard Maestro 导入|Keyboard Maestro에서 가져오기
km.added|%d本を追加しました。|Added %d scripts.|已添加 %d 个脚本。|스크립트 %d개를 추가했습니다.
km.already|%d本は登録済みのため追加しませんでした。|%d were already in the list.|%d 个已在列表中，未添加。|%d개는 이미 등록되어 추가하지 않았습니다.
km.skipped|VectorKeysで実行できない手順を含むため、%d本は取り込みませんでした：|%d macros were not imported because they have steps VectorKeys cannot run:|%d 个宏含有 VectorKeys 无法运行的步骤，因此未导入：|VectorKeys에서 실행할 수 없는 단계가 있어 %d개는 가져오지 않았습니다:
km.more|ほか%d本|and %d more|另有 %d 个|외 %d개
km.reason.notScript|実行できる手順なし|nothing it can run|无可运行的步骤|실행할 수 있는 단계 없음
km.reason.severalSteps|実行できない手順あり|steps it cannot run|含无法运行的步骤|실행할 수 없는 단계 있음
km.reason.variable|変数を使用|uses variables|使用变量|변수 사용
km.reason.notJSX|.jsx以外のファイル|not a .jsx file|非 .jsx 文件|.jsx 이외의 파일
km.saveFailed|コードをファイルに保存できませんでした：%@|Could not save the code as a file: %@|无法将代码存储为文件：%@|코드를 파일로 저장하지 못했습니다: %@
km.unreadable|読み込めないファイル：%@|Could not read: %@|无法读取：%@|읽을 수 없는 파일: %@
km.turnOff|同じショートカットのマクロがKeyboard Maestroで有効なままだと、スクリプトが2回実行されます。下のボタンか［ツール］からオフにできます。|If the same macros stay on in Keyboard Maestro, the scripts run twice. Turn them off with the button below or from Tools.|如果 Keyboard Maestro 中的同名宏仍然启用，脚本会运行两次。可用下方按钮或“工具”关闭它们。|Keyboard Maestro에서 같은 매크로가 켜져 있으면 스크립트가 두 번 실행됩니다. 아래 버튼이나 [도구]에서 끌 수 있습니다.
listSeparator|、|, |、|, 
reveal|Finderに表示|Show in Finder|在访达中显示|Finder에서 보기
relink|ファイルを選び直す…|Choose Another File…|重新选择文件…|파일 다시 선택…
badge.missing|ファイルなし|Missing|文件丢失|파일 없음
badge.missingHint|ファイルが見つかりません。移動した場合は［ファイルを選び直す…］で指定し直してください。|File not found. If it was moved, use Choose Another File… to point to it.|找不到文件。如果已移动，请用“重新选择文件…”重新指定。|파일을 찾을 수 없습니다. 이동했다면 [파일 다시 선택…]으로 다시 지정하세요.
runHint|Illustratorを前面にしてから実行します。|Brings Illustrator to the front, then runs.|先将 Illustrator 置于前台再运行。|Illustrator를 앞으로 가져온 뒤 실행합니다.
hotkeyHint|Illustratorが前面のときだけ働きます。Illustrator自身のショートカットと同じキーにすると、こちらが優先されます。|Works only while Illustrator is in front. A key that Illustrator also uses runs the script instead.|仅在 Illustrator 位于前台时有效。若与 Illustrator 自身的快捷键相同，则优先运行脚本。|Illustrator가 앞에 있을 때만 작동합니다. Illustrator 자체 단축키와 같은 키라면 스크립트가 우선합니다.
hotkey.duplicate|ほかのスクリプトと同じキーです。一覧で上にあるスクリプトだけが反応します。|Same key as another script; only the one higher in the list reacts.|与另一个脚本的按键相同，只有列表中靠上的脚本会响应。|다른 스크립트와 같은 키입니다. 목록에서 위에 있는 스크립트만 반응합니다.
deleteConfirm|選んだスクリプトを一覧から削除しますか？|Remove the selected scripts from the list?|从列表中删除所选脚本？|선택한 스크립트를 목록에서 삭제할까요?
deleteConfirmDetail|ファイルそのものは削除しません。ショートカットの割り当ては消えます。|The file itself is not deleted. Its shortcut is removed.|不会删除文件本身，但会移除其快捷键。|파일 자체는 삭제하지 않습니다. 단축키 지정은 사라집니다.
saveFailed|一覧を保存できませんでした：%@|Could not save the list: %@|无法存储列表：%@|목록을 저장하지 못했습니다: %@
aboutDetail|登録したスクリプトを、Illustratorが前面のときにキーボードショートカットで実行します。サポート：同梱のREADME.md|Runs your scripts with keyboard shortcuts while Illustrator is in front. Support: bundled README.md|在 Illustrator 位于前台时用键盘快捷键运行已登记的脚本。支持：内置 README.md|Illustrator가 앞에 있을 때 등록한 스크립트를 키보드 단축키로 실행합니다. 지원: 포함된 README.md
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
resident|ウインドウを閉じても常駐|Keep running after closing the window|关闭窗口后继续运行|윈도우를 닫아도 계속 실행
residentDetail|閉じた後もDockやメニューバーから再表示できます。オフにすると閉じたときに終了し、ホットキーも使えなくなります。|Reopen from the Dock or menu bar. When off, closing the window quits and the hotkeys stop.|可从 Dock 或菜单栏再次打开。关闭此项时，关闭窗口即退出，快捷键也会停止。|Dock 또는 메뉴 막대에서 다시 열 수 있습니다. 끄면 창을 닫을 때 종료되고 단축키도 멈춥니다.
launchShortcut|アプリ起動のホットキー|App launch keyboard shortcut|启动应用快捷键|앱 실행 키보드 단축키
openShortcuts|ショートカットを開く|Open Shortcuts|打开快捷指令|단축어 열기
shortcutDetail|ショートカットAppで「アプリを開く」に{APP}を指定し、キーを割り当ててください。未起動時も使えます。|In Shortcuts, create an Open App action for {APP} and assign a key. It works even when the app is not running.|在快捷指令中为 {APP} 创建“打开 App”并分配按键，应用未运行时也可使用。|단축어 앱에서 {APP}을 여는 동작을 만들고 키를 지정하세요. 앱이 실행 중이 아니어도 작동합니다.
appHotkeyHint|{APP}の起動中に押すと、どのアプリからでもメインウインドウを表示します。未起動のときは上の「ショートカットを開く」で割り当てたキーを使ってください。|While {APP} is running, press it in any app to show the main window. When it is not running, use the key assigned with Open Shortcuts above.|{APP} 运行时，在任何应用中按下即可显示主窗口。未运行时请使用上方“打开快捷指令”中分配的按键。|{APP}이 실행 중일 때 어느 앱에서든 누르면 메인 윈도우를 표시합니다. 실행 중이 아닐 때는 위의 '단축어 열기'에서 지정한 키를 사용하세요.
pauseHotkeys|ホットキーを一時停止|Pause Hotkeys|暂停快捷键|단축키 일시 정지
resumeHotkeys|ホットキーを再開|Resume Hotkeys|恢复快捷键|단축키 재개
useHotkeys|ホットキーを使う|Use hotkeys|使用快捷键|단축키 사용
search|検索|Search|搜索|검색
recent|最近の実行|Recent Runs|最近运行|최근 실행
recentEmpty|まだありません。履歴は保存せず、終了すると消えます。|None yet. Not saved; cleared when the app quits.|暂无。不会保存，退出应用时清除。|아직 없습니다. 저장하지 않으며 앱을 종료하면 지워집니다.
a11y.error|失敗|Failed|失败|실패
a11y.success|成功|Succeeded|成功|성공
run|実行|Run|运行|실행
delete|削除|Delete|删除|삭제
name|名前|Name|名称|이름
enabledHint|ホットキーのオン・オフ|Hotkey on or off|快捷键开关|단축키 켜기/끄기
hotkey|ホットキー|Hotkey|快捷键|단축키
hotkey.failed|このキーを登録できませんでした。ほかのアプリが使っている可能性があります。|This key could not be registered; another app may be using it.|无法注册此按键，可能被其他应用占用。|이 키를 등록하지 못했습니다. 다른 앱이 사용 중일 수 있습니다.
result.success|完了|Done|完成|완료
result.busy|前の実行が続いているため、実行しませんでした。|Skipped: earlier runs are still going.|已跳过：之前的运行仍在进行。|건너뜀: 이전 실행이 아직 진행 중입니다.
result.noIllustrator|Illustratorが起動していません。|Illustrator is not running.|Illustrator 未运行。|Illustrator가 실행 중이 아닙니다.
result.automation|Illustratorを操作する許可がありません。システム設定＞プライバシーとセキュリティ＞オートメーションで、{APP}のAdobe Illustratorをオンにしてください。|Not allowed to control Illustrator. Turn on Adobe Illustrator for {APP} in System Settings > Privacy & Security > Automation.|没有控制 Illustrator 的权限。请在“系统设置”>“隐私与安全性”>“自动化”中为 {APP} 打开 Adobe Illustrator。|Illustrator를 제어할 권한이 없습니다. 시스템 설정 > 개인정보 보호 및 보안 > 자동화에서 {APP}의 Adobe Illustrator를 켜세요.
state.front|Illustratorが前面：ホットキー有効|Illustrator in front: hotkeys on|Illustrator 在前台：快捷键有效|Illustrator가 앞에 있음: 단축키 사용
state.back|Illustratorが背面：ホットキー待機中|Illustrator not in front: hotkeys waiting|Illustrator 不在前台：快捷键待机|Illustrator가 뒤에 있음: 단축키 대기'''
# Shared menu / settings rows carry {APP}.
rows = rows.replace('{APP}', APP)
table = [line.split('|') for line in rows.splitlines() if line]
assert all(len(r) == 5 for r in table), [r[0] for r in table if len(r) != 5]
assert len({r[0] for r in table}) == len(table), 'duplicate key'

# Help text lives in help_text.py (markup rendered by Shared/AppStandards/HelpDocument.swift).
from help_text import HELP
USAGE = ["登録したスクリプトをIllustratorで実行し、取り込んだKeyboard Maestroの元のマクロをオン・オフするために使用します。", "Used to run your registered scripts in Illustrator and to turn imported Keyboard Maestro macros off or on.", "用于在 Illustrator 中运行已登记的脚本，以及关闭或打开已导入的 Keyboard Maestro 宏。", "등록한 스크립트를 Illustrator에서 실행하고 가져온 Keyboard Maestro 매크로를 끄고 켜는 데 사용합니다."]
for i, lang in enumerate(['ja', 'en', 'zh-Hans', 'ko']):
    p = root / 'Resources' / f'{lang}.lproj'
    p.mkdir(parents=True, exist_ok=True)
    (p / 'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0])} = {json.dumps(r[i + 1], ensure_ascii=False)};' for r in table) + '\n')
    (p / 'InfoPlist.strings').write_text(f'"CFBundleDisplayName" = "{APP}";\n"NSAppleEventsUsageDescription" = {json.dumps(USAGE[i], ensure_ascii=False)};\n')
    (p / 'Help.txt').write_text(HELP[lang])
print('resources:', len(table), 'keys x 4 languages')
