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

T.update({
'arrows.mode': ('入力方法', 'Input mode', '输入方式', '입력 방식'),
'arrows.google': ('Google日本語入力準拠', 'Google Japanese Input style', 'Google 日语输入方式', 'Google 일본어 입력 방식'),
'arrows.custom': ('カスタム', 'Custom', '自定义', '사용자 설정'),
'arrows.inputHint': ('英字入力時に順に入力します。日本語IMEの変換中はIME側で処理します。', 'Type sequentially in Latin input. During Japanese IME composition, the IME handles input.', '在英字输入模式下依次输入。日语输入法转换期间由输入法处理。', '영문 입력에서 순서대로 입력합니다. 일본어 IME 조합 중에는 IME가 처리합니다.'),
})

T['cmd.copyToLineEnd'] = ('段落末尾まで選択してコピー', 'Select to paragraph end and copy', '选到段落末尾并拷贝', '단락 끝까지 선택해 복사')

T['copy.aliasHelp'] = (
    'コピー用の追加ホットキー：⌃⇧←（段落先頭）、⌃⇧→（段落末尾）、⌃⇧⌘→（文章末尾）。既存の⌃⌘X、⌃⌘Z、⌃⌥⌘Zも使えます。各機能のON/OFFは2つのキーに共通です。',
    'Additional copy hotkeys: ⌃⇧← (paragraph start), ⌃⇧→ (paragraph end), ⌃⇧⌘→ (text end). Existing ⌃⌘X, ⌃⌘Z and ⌃⌥⌘Z remain available. Each function switch controls both keys.',
    '新增拷贝快捷键：⌃⇧←（段落开头）、⌃⇧→（段落末尾）、⌃⇧⌘→（文末）。原有 ⌃⌘X、⌃⌘Z、⌃⌥⌘Z 仍可用。每个功能的开关同时控制两个快捷键。',
    '추가 복사 단축키: ⌃⇧←(단락 처음), ⌃⇧→(단락 끝), ⌃⇧⌘→(글 끝). 기존 ⌃⌘X, ⌃⌘Z, ⌃⌥⌘Z도 사용할 수 있습니다. 각 기능의 스위치는 두 키에 공통으로 적용됩니다.')

T.update({
'headerTitle': ('キー入力や文字認識の補助', 'Keyboard and text recognition assistance', '辅助键盘输入与文字识别', '키 입력 및 텍스트 인식 지원'),
'allPaused': ('すべての機能を一時停止中です。', 'All features are paused.', '所有功能已暂停。', '모든 기능이 일시 정지되었습니다.'),
'pauseAll': ('すべての機能を一時停止', 'Pause All Features', '暂停所有功能', '모든 기능 일시 정지'),
'resumeAll': ('すべての機能を再開', 'Resume All Features', '恢复所有功能', '모든 기능 다시 시작'),
'readyAll': ('有効な機能を待機中', 'Enabled features are ready', '已启用的功能正在待命', '활성화된 기능 대기 중'),
'openPermissions': ('起動・権限の設定を開く', 'Open Startup and Permission Settings', '打开启动与权限设置', '시작 및 권한 설정 열기'),
'keyboardDisplay': ('キーボード表示', 'Keyboard Display', '键盘显示', '키보드 표시'),
'overview.title': ('ホットキー一覧', 'Hotkey List', '快捷键列表', '단축키 목록'),
'overview.scope': ('アプリ内の重複と登録失敗を表示します。キーの置き換えは対象外・素通しの設定に従います。', 'Shows internal duplicates and registration failures. Key replacement respects excluded and pass-through apps.', '显示应用内重复及注册失败。按键替换遵循排除与直接传递设置。', '앱 내 중복과 등록 실패를 표시합니다. 키 바꾸기는 제외 및 그대로 전달 설정을 따릅니다.'),
'overview.failed': ('登録できませんでした', 'Registration failed', '注册失败', '등록 실패'),
'overview.duplicate': ('アプリ内で割り当てが重複しています', 'Duplicate assignment in this app', '应用内快捷键重复', '앱 내 단축키 중복'),
'overview.on': ('有効', 'On', '启用', '켜짐'),
'overview.off': ('無効・未設定', 'Off / Unassigned', '关闭／未设置', '꺼짐 / 미설정'),
'overview.configure': ('設定へ', 'Configure', '设置', '설정'),
'search.settings': ('設定を検索', 'Search Settings', '搜索设置', '설정 검색'),
'search.hotkeys': ('機能名・ホットキーで検索', 'Search by feature or hotkey', '按功能或快捷键搜索', '기능 또는 단축키 검색'),
'search.none': ('該当する設定はありません', 'No matching settings', '没有匹配的设置', '일치하는 설정 없음'),
'search.launch': ('ログイン 起動 常駐 Dock アクセシビリティ 画面収録', 'Login launch background Dock accessibility screen recording', '登录 启动 后台 Dock 辅助功能 屏幕录制', '로그인 시작 상주 Dock 손쉬운 사용 화면 기록'),
'search.permissions': ('アクセシビリティ 画面収録 許可 権限', 'Accessibility screen recording permission', '辅助功能 屏幕录制 许可 权限', '손쉬운 사용 화면 기록 허용 권한'),
'compat.allFeatures': ('全機能を対象外にするアプリ', 'Apps Excluded from All Features', '所有功能排除的应用', '모든 기능에서 제외할 앱'),
'editingPassthrough': ('編集キーだけ素通しにするアプリ', 'Apps That Keep Their Own Editing Keys', '仅直接传递编辑按键的应用', '편집 키만 그대로 전달할 앱'),
'excluded.explanation': ('ここに登録したアプリでは、すべての機能の自動処理と機能ホットキーを停止します。', 'All automatic features and feature hotkeys are disabled in these apps.', '在这些应用中停止所有自动处理与功能快捷键。', '등록한 앱에서는 모든 자동 처리와 기능 단축키를 중지합니다.'),
'ocr.held': ('一時停止したため、自動コピーせず認識結果を保持しました。', 'Recognition result kept without copying because features were paused.', '因功能暂停，已保留识别结果而未自动拷贝。', '일시 정지되어 자동 복사하지 않고 인식 결과를 보관했습니다.'),
'ocr.copyHeld': ('保持した認識結果をコピー', 'Copy Retained Recognition Result', '拷贝保留的识别结果', '보관한 인식 결과 복사'),
})
