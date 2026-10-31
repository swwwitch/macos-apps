T = {
'editingTab': ('編集キー', 'Editing keys', '编辑按键', '편집 키'),
'numpadTab': ('テンキー入力', 'Numeric keypad', '数字键盘', '숫자 키패드'),
'ocrTab': ('文字認識', 'Text recognition', '文字识别', '텍스트 인식'),
'headerTitle': ('キー入力と文字認識をまとめて補助', 'Keyboard and text recognition tools', '键盘输入与文字识别工具', '키 입력 및 텍스트 인식 도구'),
'headerSubtitle': ('編集キー・テンキー入力・画面の文字認識', 'Editing keys, numeric keypad and screen text recognition', '编辑按键、数字键盘与屏幕文字识别', '편집 키, 숫자 키패드 및 화면 텍스트 인식'),
'conflict.control': ('ControlMateが起動中：編集キー機能を停止しています。', 'ControlMate is running: editing keys are suspended.', 'ControlMate 正在运行：编辑按键已暂停。', 'ControlMate 실행 중: 편집 키 기능이 일시 정지되었습니다.'),
'conflict.numpad': ('FnNumpadが起動中：テンキー入力を停止しています。', 'FnNumpad is running: numeric keypad is suspended.', 'FnNumpad 正在运行：数字键盘已暂停。', 'FnNumpad 실행 중: 숫자 키패드 기능이 일시 정지되었습니다.'),
'numpadEnable': ('テンキー入力を有効にする', 'Enable numeric keypad', '启用数字键盘', '숫자 키패드 활성화'),
'groupEnable': ('このグループを有効にする', 'Enable this group', '启用此组', '이 그룹 활성화'),
'explanation': ('説明', 'Explanation', '说明', '설명'),
'numpadTrigger.fn': ('fn', 'fn', 'fn', 'fn'),
'numpadTrigger.capsLock': ('Caps Lock', 'Caps Lock', 'Caps Lock', 'Caps Lock'),
'numpadTrigger.both': ('両方', 'Both', '两者', '둘 다'),
'numpadGroup.numpad': ('テンキー配列', 'Keypad layout', '数字键盘布局', '키패드 배열'),
'numpadGroup.numberRow': ('数字列', 'Number row', '数字行', '숫자 행'),
'numpadGroup.operators': ('演算記号', 'Operators', '运算符', '연산자'),
'numpadGroup.editing': ('編集キー', 'Editing keys', '编辑按键', '편집 키'),
'numpadPriority': ('テンキー変換を先に判定し、変換しなかったキーを編集キー機能へ渡します。同じ切り替えキーを選ぶとテンキー変換が優先されます。初期値は両配列ともfnです。', 'Keypad conversion runs first; unmatched keys reach editing keys. When triggers overlap, keypad conversion wins. Both layouts default to fn.', '先判断数字键盘转换，未转换的按键交给编辑功能。触发键相同时优先转换为数字键盘。两种布局默认使用 fn。', '숫자 키패드 변환을 먼저 처리하고 나머지는 편집 키로 전달합니다. 트리거가 겹치면 키패드가 우선합니다. 두 배열 모두 fn이 기본값입니다.'),
'recognizeButton': ('範囲を選択して文字認識', 'Select area and recognize text', '选择区域并识别文字', '영역을 선택하여 텍스트 인식'),
'ocr.result': ('認識結果', 'Recognized text', '识别结果', '인식 결과'),
'ocr.copyButton': ('認識結果をコピー', 'Copy recognized text', '拷贝识别结果', '인식 결과 복사'),
'ocr.formatting': ('整形・ホットキー', 'Formatting and hotkey', '格式与快捷键', '서식 및 단축키'),
'ocr.join': ('和文間の空白を削除', 'Remove spaces between Japanese characters', '删除日文字符间的空格', '일본어 문자 사이 공백 제거'),
'ocr.parens': ('括弧を全角にする', 'Use fullwidth parentheses', '使用全角括号', '괄호를 전각으로 변환'),
'ocr.autoCopy': ('認識後に自動でコピー', 'Copy automatically after recognition', '识别后自动拷贝', '인식 후 자동 복사'),
'ocr.screenPermission': ('画面収録の権限', 'Screen recording permission', '屏幕录制权限', '화면 기록 권한'),
'ocr.permission': ('範囲選択には画面収録の許可が必要です。システム設定でInputMaestroを許可してください。', 'Area selection requires screen recording permission. Allow InputMaestro in System Settings.', '区域选择需要屏幕录制权限。请在系统设置中允许 InputMaestro。', '영역 선택에는 화면 기록 권한이 필요합니다. 시스템 설정에서 InputMaestro를 허용하세요.'),
'ocr.openSettings': ('画面収録設定を開く', 'Open Screen Recording Settings', '打开屏幕录制设置', '화면 기록 설정 열기'),
'ocr.explanation': ('ShotSorterの文字認識を移植。範囲を選択すると日本語・英語をMac内で認識します。Escで範囲選択を取り消せます。認識結果は編集・コピーでき、自動コピーはクリップボードを書き換えます。ホットキーの初期値は未設定です。', 'Ported from ShotSorter. Select an area to recognize Japanese and English locally. Esc cancels selection. Edit or copy the result; automatic copying replaces the clipboard. The hotkey starts unassigned.', '移植自 ShotSorter。选择区域后在本机识别日文和英文。Esc 取消选择。可编辑或拷贝结果；自动拷贝会替换剪贴板。快捷键默认未设置。', 'ShotSorter에서 이식했습니다. 영역을 선택하면 일본어와 영어를 Mac에서 인식합니다. Esc로 선택을 취소합니다. 결과 편집 및 복사가 가능하며 자동 복사는 클립보드를 바꿉니다. 단축키 기본값은 미설정입니다.'),
'ocr.excluded': ('対象外アプリでは文字認識・自動コピーを実行しません。', 'Text recognition and automatic copying are blocked in excluded apps.', '排除的应用中不执行识别或自动拷贝。', '제외한 앱에서는 인식 및 자동 복사를 실행하지 않습니다.'),
'ocr.working': ('範囲選択・認識中…', 'Selecting area / recognizing…', '正在选择区域／识别…', '영역 선택 및 인식 중…'),
'ocr.imageFailed': ('画像を読み込めませんでした。', 'Could not read the image.', '无法读取图像。', '이미지를 읽을 수 없습니다.'),
'ocr.cancelled': ('範囲選択を取り消しました。', 'Area selection cancelled.', '已取消区域选择。', '영역 선택을 취소했습니다.'),
'ocr.none': ('文字が見つかりませんでした。', 'No text found.', '未找到文字。', '텍스트를 찾지 못했습니다.'),
'ocr.copied': ('認識結果をコピーしました。', 'Recognized text copied.', '已拷贝识别结果。', '인식 결과를 복사했습니다.'),
'ocr.ready': ('文字認識が完了しました。', 'Text recognition finished.', '文字识别完成。', '텍스트 인식이 완료되었습니다.'),
'ocr.failed': ('文字認識に失敗しました。', 'Text recognition failed.', '文字识别失败。', '텍스트 인식에 실패했습니다.'),
}

T.update({
'ocr.enable': ('文字認識を有効にする', 'Enable text recognition', '启用文字识别', '텍스트 인식 활성화'),
'editingPassthrough': ('編集キーを素通しにするアプリ', 'Apps that receive editing keys unchanged', '直接传递编辑按键的应用', '편집 키를 그대로 전달할 앱'),
'numpad.triggerHelp': ('このキーを押しながら、色の付いたキーを押します。', 'Hold this key and press a colored key.', '按住此键并按下彩色按键。', '이 키를 누른 채 색이 있는 키를 누르세요.'),
})
T['ocr.explanation'] = tuple(text.replace(old, new) for text, old, new in zip(T['ocr.explanation'],
    ('ホットキーの初期値は未設定です。', 'The hotkey starts unassigned.', '快捷键默认未设置。', '단축키 기본값은 미설정입니다.'),
    ('ホットキーの初期値は⌘⇧1です。画面収録の権限は設定の「起動・常駐」で確認します。', 'The default hotkey is ⌘⇧1. Screen recording permission is in Startup & Background settings.', '默认快捷键为 ⌘⇧1。屏幕录制权限位于“启动与后台”设置。', '기본 단축키는 ⌘⇧1입니다. 화면 기록 권한은 시작 및 백그라운드 설정에서 확인합니다.')))

T['ocr.explanation'] = (
    '⌘⇧1で範囲選択を開始し、日本語・英語をMac内で認識します。Escで取り消せます。自動コピーがONの場合、認識結果をクリップボードへコピーします。画面収録の権限は設定の「起動・常駐」で確認します。',
    'Press ⌘⇧1 to select an area and recognize Japanese and English locally. Esc cancels. When automatic copying is on, the result is copied to the clipboard. Screen recording permission is in Startup & Background settings.',
    '按 ⌘⇧1 选择区域并在本机识别日文和英文。Esc 取消。开启自动拷贝时，结果会拷贝到剪贴板。屏幕录制权限位于“启动与后台”设置。',
    '⌘⇧1로 영역을 선택하여 일본어와 영어를 Mac에서 인식합니다. Esc로 취소합니다. 자동 복사가 켜져 있으면 결과를 클립보드로 복사합니다. 화면 기록 권한은 시작 및 백그라운드 설정에서 확인합니다.')

T.update({
'appCompatibility': ('アプリ対応', 'App Compatibility', '应用兼容性', '앱 호환성'),
'cmd.copyToLineStart': ('段落先頭まで選択してコピー', 'Select to paragraph start and copy', '选到段落开头并拷贝', '단락 처음까지 선택해 복사'),
})

T.update({
'symbols.tab': ('修飾キーと矢印キー', 'Modifier and Arrow Symbols', '修饰键与箭头符号', '보조 키 및 화살표 기호'),
'symbols.enable': ('修飾キーと矢印の記号入力を有効にする', 'Enable modifier and arrow symbol input', '启用修饰键与箭头符号输入', '보조 키 및 화살표 기호 입력 활성화'),
'symbols.modifiers': ('修飾キー', 'Modifier symbols', '修饰键符号', '보조 키 기호'),
'symbols.arrows': ('矢印キー', 'Arrow symbols', '箭头符号', '화살표 기호'),
'symbols.explanation': ('InsertSnippetsの記号入力を移植。指定のホットキーで⌃⌥⌘⇧や←↓→↑を文字として入力します。キー操作やカーソル移動ではありません。対象外アプリと自アプリでは実行せず、クリップボードは入力後に復元します。', 'Ported from InsertSnippets: hotkeys insert ⌃⌥⌘⇧ and ←↓→↑ as text. They do not press modifiers or move the cursor. Excluded apps and this app are skipped. The clipboard is restored after insertion.', '移植自 InsertSnippets。快捷键将 ⌃⌥⌘⇧ 和 ←↓→↑ 作为文字输入，不是按键操作或光标移动。在排除的应用和本应用中不执行。输入后恢复剪贴板。', 'InsertSnippets에서 이식했습니다. 단축키로 ⌃⌥⌘⇧ 및 ←↓→↑를 문자로 입력합니다. 키 누르기나 커서 이동이 아닙니다. 제외한 앱과 이 앱에서는 실행하지 않으며 입력 후 클립보드를 복원합니다.'),
})

T.update({
'symbols.enableModifiers': ('修飾キーの記号入力を有効にする', 'Enable modifier symbol input', '启用修饰键符号输入', '보조 키 기호 입력 활성화'),
'symbols.enableArrows': ('矢印の記号入力を有効にする', 'Enable arrow symbol input', '启用箭头符号输入', '화살표 기호 입력 활성화'),
})
