#!/usr/bin/env python3
# Writes Resources/<lang>.lproj/Localizable.strings and InfoPlist.strings. Edit the texts here, not the .strings files.
# Lines stay short: /usr/bin/python3 3.9 fails on very long lines with Japanese.
from pathlib import Path

LANGS = ['ja', 'en', 'zh-Hans', 'ko']

T = {
    # Menus (BASELINE「メニューの共通構成」)
    'about': ('ControlMateについて', 'About ControlMate', '关于 ControlMate', 'ControlMate에 관하여'),
    'hide': ('ControlMateを隠す', 'Hide ControlMate', '隐藏 ControlMate', 'ControlMate 가리기'),
    'quit': ('ControlMateを終了', 'Quit ControlMate', '退出 ControlMate', 'ControlMate 종료'),
    'appHelp': ('ControlMateヘルプ', 'ControlMate Help', 'ControlMate 帮助', 'ControlMate 도움말'),
    'helpHeading': ('ControlMate ヘルプ', 'ControlMate Help', 'ControlMate 帮助', 'ControlMate 도움말'),
    'hideOthers': ('ほかを隠す', 'Hide Others', '隐藏其他', '기타 가리기'),
    'showAll': ('すべてを表示', 'Show All', '全部显示', '모두 보기'),
    'services': ('サービス', 'Services', '服务', '서비스'),
    'settings': ('設定…', 'Settings…', '设置…', '설정…'),
    'settingsButton': ('設定…', 'Settings…', '设置…', '설정…'),
    'settingsTitle': ('設定', 'Settings', '设置', '설정'),
    'file': ('ファイル', 'File', '文件', '파일'),
    'edit': ('編集', 'Edit', '编辑', '편집'),
    'window': ('ウインドウ', 'Window', '窗口', '윈도우'),
    'help': ('ヘルプ', 'Help', '帮助', '도움말'),
    'openMainWindow': ('メインウインドウを開く', 'Open Main Window', '打开主窗口', '메인 윈도우 열기'),
    'closeWindow': ('ウインドウを閉じる', 'Close Window', '关闭窗口', '윈도우 닫기'),
    'undo': ('取り消す', 'Undo', '撤销', '실행 취소'),
    'redo': ('やり直す', 'Redo', '重做', '실행 복귀'),
    'cut': ('カット', 'Cut', '剪切', '오려두기'),
    'copy': ('コピー', 'Copy', '拷贝', '복사하기'),
    'paste': ('ペースト', 'Paste', '粘贴', '붙여넣기'),
    'selectAll': ('すべてを選択', 'Select All', '全选', '모두 선택'),
    'minimize': ('しまう', 'Minimize', '最小化', '최소화'),
    'zoom': ('拡大／縮小', 'Zoom', '缩放', '확대/축소'),
    'bringAllToFront': ('すべてを手前に移動', 'Bring All to Front', '前置全部窗口', '모두 앞으로 가져오기'),
    'pause': ('一時停止（再起動で解除）', 'Pause (until relaunch)', '暂停（重新启动后恢复）', '일시 정지(다시 실행하면 해제)'),
    'support': ('サポート：作成を依頼したチャットへ、置き換わらないキーとアプリをお知らせください。',
                'Support: tell us in the chat where you asked for this app which keys are not replaced, and in which apps.',
                '支持：请在委托制作此应用的聊天中告诉我们哪些键在哪些应用中没有被替换。',
                '지원: 이 앱을 요청한 채팅에서 바뀌지 않는 키와 앱을 알려 주세요.'),

    # Startup
    'keepRunning': ('ウインドウを閉じても常駐', 'Keep running when the window is closed', '关闭窗口后继续常驻', '윈도우를 닫아도 상주'),
    'keepRunningHint': ('オン：メニューバーで待機します。オフ：最後のウインドウを閉じると終了します。',
                        'On: waits in the menu bar. Off: quits when the last window closes.',
                        '开启：在菜单栏待命。关闭：关闭最后一个窗口时退出。',
                        '켜기: 메뉴 막대에서 대기합니다. 끄기: 마지막 윈도우를 닫으면 종료합니다.'),
    'appHotkeyHint': ('どのアプリからでも ControlMate のメインウインドウを開きます。初期値は未設定です。',
                      'Opens the ControlMate main window from any app. Not set at first.',
                      '可在任何应用中打开 ControlMate 主窗口。默认未设置。',
                      '어느 앱에서나 ControlMate 메인 윈도우를 엽니다. 처음에는 설정되어 있지 않습니다.'),

    # Main window
    'headerTitle': ('Emacs のキー操作を補う', 'Emacs keys in every app', '在所有应用中使用 Emacs 按键', '모든 앱에서 Emacs 키 사용'),
    'headerSubtitle': ('⌃F や ⌃K が使えないアプリでも、同じキーで移動・編集できます。',
                       'Move and edit with ⌃F, ⌃K and the others, even in apps that lack them.',
                       '即使应用不支持，也能用 ⌃F、⌃K 等键移动和编辑。',
                       '지원하지 않는 앱에서도 ⌃F, ⌃K 등으로 이동하고 편집할 수 있습니다.'),
    'statusRow': ('状態', 'Status', '状态', '상태'),
    'triggerRow': ('押すキー', 'Key to hold', '按住的键', '누르는 키'),
    'targetRow': ('前面のアプリ', 'Front app', '前台应用', '앞쪽 앱'),
    'failureRow': ('直前の操作', 'Last command', '上一个操作', '직전 작업'),
    'listSeparator': ('、', ', ', '、', ', '),
    'enable': ('キーを置き換える', 'Replace keys', '替换按键', '키 바꾸기'),
    'status.active': ('動作中', 'Active', '运行中', '작동 중'),
    'status.denied': ('アクセシビリティが未許可です。設定の［起動・常駐］から許可してください。',
                      'Accessibility is not allowed. Allow it in Settings > Startup & Background.',
                      '未获得辅助功能权限。请在“设置 > 启动与后台”中授权。',
                      '손쉬운 사용 권한이 없습니다. 설정 > 시작 및 백그라운드에서 허용하세요.'),
    'status.tapFailed': ('キーの監視を開始できませんでした。ControlMate を再起動してください。',
                         'Could not start watching keys. Restart ControlMate.',
                         '无法开始监视按键。请重新启动 ControlMate。',
                         '키 감시를 시작할 수 없습니다. ControlMate를 다시 실행하세요.'),
    'status.off': ('キーの置き換えはオフです。', 'Key replacement is off.', '按键替换已关闭。', '키 바꾸기가 꺼져 있습니다.'),
    'status.paused': ('一時停止中です（再起動で解除）。', 'Paused (until relaunch).', '已暂停（重新启动后恢复）。', '일시 정지 중입니다(다시 실행하면 해제).'),
    'status.excluded': ('%@ は対象外アプリのため、キーを置き換えていません。', '%@ is an excluded app; keys are not replaced.',
                        '%@ 是排除的应用，不替换按键。', '%@은(는) 제외할 앱이므로 키를 바꾸지 않습니다.'),
    'target.all': ('%@：すべてのキーを置き換えます。', '%@: all keys are replaced.', '%@：替换所有按键。', '%@: 모든 키를 바꿉니다.'),
    'target.passing': ('%@：%@ は素通しにします。', '%@: %@ pass through unchanged.', '%@：%@ 直接传递。', '%@: %@은(는) 그대로 전달합니다.'),
    'target.excluded': ('%@：対象外アプリ（置き換えなし）', '%@: excluded app (nothing replaced)', '%@：排除的应用（不替换）', '%@: 제외할 앱(바꾸지 않음)'),
    'triggerSummary': ('US などのキーボード：%@ ／ JIS キーボード：%@', 'US and other keyboards: %@ / JIS keyboards: %@',
                       '美式等键盘：%@ ／ JIS 键盘：%@', 'US 등 키보드: %@ / JIS 키보드: %@'),

    # Settings: keys
    'keysTab': ('キー', 'Keys', '按键', '키'),
    'conversionTitle': ('キーの置き換え', 'Key replacement', '按键替换', '키 바꾸기'),
    'enableHint': ('オフにすると、すべてのキーをそのまま渡します。', 'Off passes every key through unchanged.',
                   '关闭后，所有按键都直接传递。', '끄면 모든 키를 그대로 전달합니다.'),
    'triggerTitle': ('⌃ の代わりに押すキー', 'Key held instead of ⌃', '代替 ⌃ 按住的键', '⌃ 대신 누르는 키'),
    'trigger.ansi': ('US などのキーボード', 'US and other keyboards', '美式等键盘', 'US 등 키보드'),
    'trigger.jis': ('JIS キーボード', 'JIS keyboards', 'JIS 键盘', 'JIS 키보드'),
    'triggerKey.control': ('⌃ control', '⌃ control', '⌃ control', '⌃ control'),
    'triggerKey.capsLock': ('Caps Lock', 'Caps Lock', 'Caps Lock', 'Caps Lock'),
    'triggerKey.both': ('両方', 'Both', '两者', '둘 다'),
    'triggerHint': ('このキーを押している間だけ置き換えます。どちらのキーボードかは、押したキーごとに判定します。'
                    'Caps Lock を使ったときは、放したあとで大文字ロックを押す前の状態に戻します。'
                    'Caps Lock だけを押したときは、ふだんどおり大文字ロックが切り替わります。',
                    'Keys are replaced only while this key is held. The keyboard type is checked for each key. '
                    'After Caps Lock is used this way, the caps lock goes back to how it was before the press. '
                    'Pressing Caps Lock alone toggles the caps lock as usual.',
                    '仅在按住此键时替换。每次按键都会判断键盘类型。'
                    '以这种方式使用 Caps Lock 后，松开时大写锁定会恢复到按下前的状态。'
                    '只按 Caps Lock 时，大写锁定照常切换。',
                    '이 키를 누르고 있는 동안만 바꿉니다. 키보드 종류는 누른 키마다 판단합니다. '
                    'Caps Lock을 이렇게 사용하면 뗀 뒤 대문자 잠금을 누르기 전 상태로 되돌립니다. '
                    'Caps Lock만 누르면 평소처럼 대문자 잠금이 바뀝니다.'),
    'group.basic': ('Emacs の基本操作', 'Basic Emacs keys', 'Emacs 基本操作', 'Emacs 기본 조작'),
    'group.assist': ('入力の補助', 'Typing helpers', '输入辅助', '입력 보조'),
    'group.paragraph': ('段落と行の編集', 'Paragraphs and lines', '段落与行编辑', '단락과 행 편집'),
    'group.basic.hint': ('⇧を足すと、選択しながら移動します。⌃K でカットした文字は ControlMate の控えに入り、⌃Y でペーストします。'
                         '控えはクリップボードとは別なので、⌘C でコピーした内容は変わりません。',
                         'Add ⇧ to select while moving. Text cut with ⌃K goes into ControlMate\'s own kill buffer and ⌃Y pastes it. '
                         'The kill buffer is separate from the clipboard, so what you copied with ⌘C stays.',
                         '加按 ⇧ 可在移动时选择。用 ⌃K 剪切的文字存入 ControlMate 自己的暂存区，用 ⌃Y 粘贴。'
                         '暂存区与剪贴板分开，用 ⌘C 拷贝的内容不会改变。',
                         '⇧를 더하면 선택하면서 이동합니다. ⌃K로 오려 둔 텍스트는 ControlMate의 보관함에 들어가고 ⌃Y로 붙여넣습니다. '
                         '보관함은 클립보드와 별개이므로 ⌘C로 복사한 내용은 바뀌지 않습니다.'),
    'group.assist.hint': ('⌃J は日本語入力の変換を確定してから右へ移動します。⌃⌘X／⌃⌘K はカーソルから行頭／行末までを選択してクリップボードにコピーします。',
                          '⌃J confirms the input method\'s text, then moves right. ⌃⌘X / ⌃⌘K select from the caret to the line start / end and copy it to the clipboard.',
                          '⌃J 先确认输入法的文字，再向右移动。⌃⌘X／⌃⌘K 选择从光标到行首／行尾的文字并拷贝到剪贴板。',
                          '⌃J는 입력기의 변환을 확정한 뒤 오른쪽으로 이동합니다. ⌃⌘X / ⌃⌘K는 커서부터 행 처음 / 끝까지 선택해 클립보드에 복사합니다.'),
    'group.paragraph.hint': ('段落の移動・選択は、アクセシビリティで文字を読み取れる入力欄で使えます。⌃S をすばやく2回押すと段落をカットします。'
                             '⌃X でカットした文字は控えに入り、⌃Z（または ⌃Y）でペーストします。',
                             'Moving and selecting paragraphs work in fields whose text Accessibility can read. Press ⌃S twice quickly to cut the paragraph. '
                             'Text cut with ⌃X goes into the kill buffer; ⌃Z (or ⌃Y) pastes it.',
                             '移动和选择段落仅适用于可通过辅助功能读取文字的输入栏。快速按两次 ⌃S 可剪切段落。'
                             '用 ⌃X 剪切的文字存入暂存区，用 ⌃Z（或 ⌃Y）粘贴。',
                             '단락 이동과 선택은 손쉬운 사용으로 텍스트를 읽을 수 있는 입력란에서 작동합니다. ⌃S를 빠르게 두 번 누르면 단락을 오려둡니다. '
                             '⌃X로 오려 둔 텍스트는 보관함에 들어가고 ⌃Z(또는 ⌃Y)로 붙여넣습니다.'),
    'cmd.forward': ('1文字右へ', 'Forward one character', '向右一个字符', '오른쪽으로 한 글자'),
    'cmd.backward': ('1文字左へ', 'Back one character', '向左一个字符', '왼쪽으로 한 글자'),
    'cmd.next': ('次の行へ', 'Next line', '下一行', '다음 행'),
    'cmd.previous': ('前の行へ', 'Previous line', '上一行', '이전 행'),
    'cmd.lineStart': ('段落の先頭へ', 'Start of paragraph', '段落开头', '단락 처음'),
    'cmd.lineEnd': ('段落の末尾へ', 'End of paragraph', '段落末尾', '단락 끝'),
    'cmd.deleteForward': ('後ろの1文字を削除', 'Delete the next character', '删除后一个字符', '뒤의 한 글자 삭제'),
    'cmd.killLine': ('行末までカットして控える', 'Cut to end of line (kill)', '剪切到行尾并暂存', '행 끝까지 오려 보관'),
    'cmd.yank': ('控えた文字をペースト', 'Paste the killed text (yank)', '粘贴暂存的文字', '보관한 텍스트 붙여넣기'),
    'cmd.escape': ('Esc', 'Esc', 'Esc', 'Esc'),
    'cmd.tab': ('Tab', 'Tab', 'Tab', 'Tab'),
    'cmd.pageUp': ('Page Up', 'Page Up', 'Page Up', 'Page Up'),
    'cmd.enter': ('Enter', 'Enter', 'Enter', 'Enter'),
    'cmd.confirmRight': ('確定して右へ', 'Confirm, then move right', '确认后向右', '확정 후 오른쪽으로'),
    'cmd.home': ('Home', 'Home', 'Home', 'Home'),
    'cmd.end': ('End', 'End', 'End', 'End'),
    'cmd.copyToLineStart': ('行頭まで選択してコピー', 'Select to line start and copy', '选到行首并拷贝', '행 처음까지 선택해 복사'),
    'cmd.copyToLineEnd': ('行末まで選択してコピー', 'Select to line end and copy', '选到行尾并拷贝', '행 끝까지 선택해 복사'),
    'cmd.moveParagraphUp': ('段落を上へ移動', 'Move paragraph up', '段落上移', '단락을 위로 이동'),
    'cmd.moveParagraphDown': ('段落を下へ移動', 'Move paragraph down', '段落下移', '단락을 아래로 이동'),
    'cmd.selectParagraph': ('段落を選択してコピー', 'Select and copy paragraph', '选择并拷贝段落', '단락 선택 후 복사'),
    'cmd.killToLineStart': ('段落頭までカットして控える', 'Cut to paragraph start (kill)', '剪切到段落开头并暂存', '단락 처음까지 오려 보관'),
    'cmd.yankKilled': ('控えた文字をペースト', 'Paste the killed text (yank)', '粘贴暂存的文字', '보관한 텍스트 붙여넣기'),

    'capsAsControl': ('Caps Lock を常に ⌃ として扱う', 'Always treat Caps Lock as ⌃', '始终将 Caps Lock 视为 ⌃', 'Caps Lock을 항상 ⌃로 취급'),
    'capsAsControlHint': ('オン：Caps Lock を押している間は、上の表にないキーも ⌃ 付きで送ります（ターミナルの ⌃C、素通しにするアプリの ⌃F など）。'
                          '対象外アプリでも働きます。Caps Lock を上で選んだキーボードだけが対象です。',
                          'On: while Caps Lock is held, keys not in the table below are also sent with ⌃ (⌃C in Terminal, ⌃F in pass-through apps). '
                          'This also works in excluded apps. Only keyboards set to Caps Lock above.',
                          '开启：按住 Caps Lock 时，下表以外的键也带 ⌃ 发送（终端的 ⌃C、直接传递应用中的 ⌃F 等）。'
                          '在排除的应用中也有效。仅适用于上面设为 Caps Lock 的键盘。',
                          '켜기: Caps Lock을 누르고 있는 동안 아래 표에 없는 키도 ⌃를 붙여 보냅니다(터미널의 ⌃C, 그대로 전달할 앱의 ⌃F 등). '
                          '제외할 앱에서도 작동합니다. 위에서 Caps Lock을 고른 키보드만 해당합니다.'),
    'capsAsControlNote': ('（Caps Lock は常に ⌃）', ' (Caps Lock always ⌃)', '（Caps Lock 始终为 ⌃）', ' (Caps Lock은 항상 ⌃)'),
    'column.function': ('機能', 'Function', '功能', '기능'),
    'column.standard': ('デフォルト', 'Default', '默认', '기본'),
    'column.extended': ('拡張（このアプリのみ）', 'Extended (this app only)', '扩展（仅本应用）', '확장(이 앱만)'),
    'category.cursor': ('カーソル移動', 'Cursor movement', '光标移动', '커서 이동'),
    'category.keySend': ('キー送信', 'Key sending', '发送按键', '키 보내기'),
    'category.editing': ('テキスト編集', 'Text editing', '文本编辑', '텍스트 편집'),
    'category.killYank': ('Kill/Yank', 'Kill/Yank', 'Kill/Yank', 'Kill/Yank'),
    'category.cursor.hint': ('⇧を足すと、選択しながら移動します。⌃A／⌃E は段落の先頭・末尾へ動きます（macOS 標準と同じ）。',
                             'Add ⇧ to select while moving. ⌃A / ⌃E go to the start / end of the paragraph, as in macOS.',
                             '加按 ⇧ 可边移动边选择。⌃A／⌃E 移到段落开头／末尾（与 macOS 相同）。',
                             '⇧를 더하면 선택하면서 이동합니다. ⌃A / ⌃E는 단락 처음 / 끝으로 이동합니다(macOS와 같음).'),
    'category.keySend.hint': ('⌃J は日本語入力の変換を確定してから右へ移動します。',
                              '⌃J confirms the input method\'s text, then moves right.',
                              '⌃J 先确认输入法的文字，再向右移动。', '⌃J는 입력기의 변환을 확정한 뒤 오른쪽으로 이동합니다.'),
    'category.editing.hint': ('段落の移動・選択は、アクセシビリティで文字を読み取れる入力欄で使えます。⌃S をすばやく2回押すと段落をカットします。'
                              '⌃⌘X／⌃⌘K はカーソルから行頭／行末までを選択してクリップボードにコピーします。',
                              'Moving and selecting paragraphs work in fields whose text Accessibility can read. Press ⌃S twice quickly to cut the paragraph. '
                              '⌃⌘X / ⌃⌘K select from the caret to the line start / end and copy it to the clipboard.',
                              '移动和选择段落仅适用于可通过辅助功能读取文字的输入栏。快速按两次 ⌃S 可剪切段落。'
                              '⌃⌘X／⌃⌘K 选择从光标到行首／行尾的文字并拷贝到剪贴板。',
                              '단락 이동과 선택은 손쉬운 사용으로 텍스트를 읽을 수 있는 입력란에서 작동합니다. ⌃S를 빠르게 두 번 누르면 단락을 오려둡니다. '
                              '⌃⌘X / ⌃⌘K는 커서부터 행 처음 / 끝까지 선택해 클립보드에 복사합니다.'),
    'category.killYank.hint': ('⌃K・⌃X でカットした文字は ControlMate の控えに入り、⌃Y・⌃Z でペーストします。'
                               '控えはクリップボードとは別なので、⌘C でコピーした内容は変わりません。',
                               'Text cut with ⌃K or ⌃X goes into ControlMate\'s kill buffer; ⌃Y or ⌃Z pastes it. '
                               'The kill buffer is separate from the clipboard, so what you copied with ⌘C stays.',
                               '用 ⌃K、⌃X 剪切的文字存入 ControlMate 的暂存区，用 ⌃Y、⌃Z 粘贴。暂存区与剪贴板分开，用 ⌘C 拷贝的内容不会改变。',
                               '⌃K, ⌃X로 오려 둔 텍스트는 ControlMate의 보관함에 들어가고 ⌃Y, ⌃Z로 붙여넣습니다. '
                               '보관함은 클립보드와 별개이므로 ⌘C로 복사한 내용은 바뀌지 않습니다.'),

    # Keyboard view: what ⌃+key does, short enough for a key cap
    'short.forward': ('→', '→', '→', '→'),
    'short.backward': ('←', '←', '←', '←'),
    'short.next': ('↓', '↓', '↓', '↓'),
    'short.previous': ('↑', '↑', '↑', '↑'),
    'short.lineStart': ('段落頭', '¶ start', '段首', '단락 처음'),
    'short.lineEnd': ('段落末', '¶ end', '段尾', '단락 끝'),
    'short.pageUp': ('PgUp', 'PgUp', 'PgUp', 'PgUp'),
    'short.home': ('Home', 'Home', 'Home', 'Home'),
    'short.end': ('End', 'End', 'End', 'End'),
    'short.escape': ('⎋', '⎋', '⎋', '⎋'),
    'short.tab': ('⇥', '⇥', '⇥', '⇥'),
    'short.enter': ('Enter', 'Enter', 'Enter', 'Enter'),
    'short.confirmRight': ('確定→', '↩→', '确认→', '확정→'),
    'short.deleteForward': ('⌦', '⌦', '⌦', '⌦'),
    'short.moveParagraphUp': ('段落↑', '¶↑', '段落↑', '단락↑'),
    'short.moveParagraphDown': ('段落↓', '¶↓', '段落↓', '단락↓'),
    'short.selectParagraph': ('段落選択', 'Select ¶', '选段落', '단락 선택'),
    'short.copyToLineStart': ('←コピー', '←Copy', '←拷贝', '←복사'),
    'short.copyToLineEnd': ('→コピー', 'Copy→', '拷贝→', '복사→'),
    'short.killLine': ('Kill→', 'Kill→', 'Kill→', 'Kill→'),
    'short.killToLineStart': ('←Kill', '←Kill', '←Kill', '←Kill'),
    'short.yank': ('Yank', 'Yank', 'Yank', 'Yank'),
    'short.yankKilled': ('Yank', 'Yank', 'Yank', 'Yank'),
    'kb.layout': ('配列', 'Layout', '布局', '배열'),
    'kb.layoutAuto': ('自動（%@）', 'Automatic (%@)', '自动（%@）', '자동(%@)'),
    'kb.ansi': ('英語（US）', 'US', '美式（US）', '미국(US)'),
    'kb.jis': ('JIS', 'JIS', 'JIS', 'JIS'),
    'kb.off': ('オフ', 'off', '关', '끔'),
    'kb.triggerHelp': ('このキーを押しながら、色の付いたキーを押します。', 'Hold this key and press a coloured key.', '按住此键，再按带颜色的键。', '이 키를 누른 채 색이 있는 키를 누릅니다.'),

    # Settings: pass-through apps
    'passTab': ('素通しにするアプリ', 'Pass-Through Apps', '直接传递的应用', '그대로 전달할 앱'),
    'passExplanation': ('ここに入れたアプリでは、そのグループのキーを置き換えずにそのまま渡します。'
                        '⌃F などが元から使えるアプリや、⌃ を独自の操作に使うアプリを入れます。'
                        'どのキーも置き換えないアプリは［対象外アプリ］に入れます。',
                        'In these apps the group\'s keys pass through unchanged. Add apps that already have ⌃F and the others, '
                        'or that use ⌃ for their own commands. Apps where no key should be replaced go in Excluded Apps.',
                        '在这些应用中，该组的按键不替换而直接传递。请添加本身支持 ⌃F 等键或将 ⌃ 用于自身操作的应用。'
                        '完全不替换按键的应用请添加到“排除的应用”。',
                        '여기에 넣은 앱에서는 그 그룹의 키를 바꾸지 않고 그대로 전달합니다. ⌃F 등을 원래 지원하거나 ⌃를 자체 기능에 쓰는 앱을 넣습니다. '
                        '어떤 키도 바꾸지 않을 앱은 제외할 앱에 넣습니다.'),
    'pass.add': ('追加…', 'Add…', '添加…', '추가…'),
    'pass.remove': ('削除', 'Remove', '移除', '제거'),
    'pass.reset': ('初期値に戻す', 'Restore Defaults', '恢复默认', '기본값으로 복원'),
    'pass.missing': ('このMacにありません', 'Not on this Mac', '此 Mac 上没有', '이 Mac에 없음'),
    'pass.chooseTitle': ('素通しにするアプリを選択', 'Choose Apps to Pass Through', '选择直接传递的应用', '그대로 전달할 앱 선택'),
    'pass.unreadable': ('%@ のBundle IDを読み取れませんでした。', 'Could not read the Bundle ID of %@.', '无法读取 %@ 的 Bundle ID。', '%@의 Bundle ID를 읽을 수 없습니다.'),
    'pass.duplicate': ('%@ はすでに登録されています。', '%@ is already in the list.', '%@ 已在列表中。', '%@은(는) 이미 목록에 있습니다.'),
    'excluded.explanation': ('ここに入れたアプリでは、どのキーも置き換えません。', 'No key is replaced in these apps.',
                             '在这些应用中不替换任何按键。', '이 앱들에서는 어떤 키도 바꾸지 않습니다.'),

    # Results of editing commands
    'result.killFailed': ('カットできませんでした。入力欄にカーソルがあるか確かめてください。',
                          'Could not cut. Check that the caret is in a text field.',
                          '无法剪切。请确认光标位于输入栏中。', '오려둘 수 없습니다. 커서가 입력란에 있는지 확인하세요.'),
    'result.nothingKilled': ('まだ何も控えていません。⌃K か ⌃X でカットしてからペーストしてください。',
                             'Nothing has been killed yet. Cut with ⌃K or ⌃X first.',
                             '尚未暂存任何文字。请先用 ⌃K 或 ⌃X 剪切。', '아직 보관한 텍스트가 없습니다. 먼저 ⌃K나 ⌃X로 오려두세요.'),
    'result.cutFailed': ('カットできませんでした。', 'Could not cut.', '无法剪切。', '오려둘 수 없습니다.'),
    'result.copyFailed': ('コピーできませんでした。入力欄にカーソルがあるか確かめてください。',
                          'Could not copy. Check that the caret is in a text field.',
                          '无法拷贝。请确认光标位于输入栏中。', '복사할 수 없습니다. 커서가 입력란에 있는지 확인하세요.'),
    'result.noText': ('このアプリの入力欄の文字を読み取れないため、段落を移動できませんでした。',
                      'The text of this field cannot be read, so the paragraph was not moved.',
                      '无法读取此输入栏的文字，因此未移动段落。', '이 입력란의 텍스트를 읽을 수 없어 단락을 이동하지 못했습니다.'),
    'result.moveFailed': ('段落を入れ替えられませんでした。文字を確かめ、必要なら ⌘Z で取り消してください。',
                          'The paragraphs could not be swapped. Check the text and undo with ⌘Z if needed.',
                          '无法交换段落。请检查文字，必要时用 ⌘Z 撤销。', '단락을 바꾸지 못했습니다. 텍스트를 확인하고 필요하면 ⌘Z로 취소하세요.'),
}

HELP_JA = '''## 使い方
1. 初回は設定の［起動・常駐］→［アクセシビリティ］で ControlMate を許可します。
2. 文字を入力できる欄で、⌃（control）を押しながら F・B・N・P などを押します。
3. Emacs と同じキーでカーソルを動かしたり、行や段落を編集したりできます。

## ⌃ の代わりに押すキー
- 初期値は US などのキーボードが ⌃、JIS キーボードが Caps Lock です。
- 設定の［キー］→［⌃ の代わりに押すキー］で、⌃・Caps Lock・両方 から選べます。
- Caps Lock を使ったときは、放したあとで大文字ロックを押す前の状態に戻します。
- ［Caps Lock を常に ⌃ として扱う］をオンにすると、表にないキーも ⌃ 付きで送ります（ターミナルの ⌃C など）。
- Karabiner-Elements などで Caps Lock を別のキーに変えていると、Caps Lock としては使えません。

## キーの一覧
### Emacs の基本操作
- ⌃F／⌃B／⌃N／⌃P：右・左・下・上へ。⇧を足すと選択しながら移動
- ⌃A／⌃E：段落の先頭・末尾へ（macOS 標準と同じ）
- ⌃D：後ろの1文字を削除
- ⌃K：行末までカットして控える（行末では改行をカット）
- ⌃Y：控えた文字をペースト
- ⌃G：Esc、⌃I：Tab、⌃U：Page Up
### 入力の補助
- ⌃M：Enter、⌃J：確定して右へ
- ⌃,／⌃.：Home／End
- ⌃⌘X／⌃⌘K：行頭まで／行末まで選択してコピー
### 段落と行の編集
- ⌃⇧↑／⌃⇧↓：段落を上下の段落と入れ替え
- ⌃S：段落を選択してコピー。すばやく2回押すとカット
- ⌃X：段落の先頭までカットして控える
- ⌃Z：控えた文字をペースト

## 控え（キルバッファ）
- ⌃K と ⌃X でカットした文字は、クリップボードとは別の ControlMate の控えに入ります。
- ⌃Y・⌃Z で控えをペーストします。⌘C・⌘V のクリップボードは変わりません。
- 続けて ⌃K を押すと、控えにつなげて入れます（⌃K ⌃K で行と改行をまとめて控える）。
- 控えはメモリーだけにあり、ControlMate を終了すると消えます。

## アプリごとの動き
- ［素通しにするアプリ］：グループごとに、キーを置き換えずにそのまま渡すアプリを登録します。
  ⌃F などが元から使えるアプリ（Safari・Chrome など）は初期値で入っています。
- ［対象外アプリ］：どのキーも置き換えないアプリです。
- Visual Studio Code では、段落の移動にアプリ自身の ⌥↑／⌥↓ を使います。
- メインウインドウに、前面のアプリでどのグループを置き換えるかを表示します。

## 権限
- アクセシビリティ：キーを受け取って置き換えるため、また入力欄の文字を読み取って選択するために使います。
  未許可の間は、どのキーも置き換えません。
- 文字やキー入力を記録・送信することはありません。

## 常駐と終了
- ウインドウを閉じてもメニューバーで待機します（設定で変更できます）。
- メニューバーのアイコンから、メインウインドウ・設定・一時停止・ヘルプ・終了を選べます。
- 終了は ControlMate のメニューまたはメニューバーのアイコンの［ControlMateを終了］です。

## 制限
- 段落の移動・選択、⌃K の行末判定は、アクセシビリティで文字を読み取れる入力欄で動きます。
  読み取れない欄では、⌃K・⌃X・⌃S は見た目の行を ⇧⌘→ などで選んで代わりに処理します。
- Chrome や Firefox の一部の入力欄は、選択の変更を受け付けません。
  そのため段落の操作は、初期値で素通しにしています。
- カット・ペーストはアプリのメニューの ⌘X・⌘V を使います。取り消しはアプリの ⌘Z です。

## 困ったときは
- 置き換わらない：メインウインドウの［状態］と［前面のアプリ］を確かめます。
  アクセシビリティの許可、［キーを置き換える］、素通し・対象外の登録を確認してください。
- ほかのアプリと同じキーが二重に動く：同じキーを使う常駐アプリやマクロを止めてください。
- 段落の操作が失敗した：［直前の操作］に理由を表示します。文字を確かめ、必要なら ⌘Z で取り消します。

## 削除
ControlMate を終了してから、アプリケーションフォルダーの ControlMate をゴミ箱に入れます。
システム設定のアクセシビリティの一覧からも削除できます。'''

HELP_EN = '''## Getting started
1. First allow ControlMate in Settings > Startup & Background > Accessibility.
2. In any text field, hold ⌃ (control) and press F, B, N, P and the other keys.
3. Move the caret and edit lines and paragraphs with the same keys as Emacs.

## Key held instead of ⌃
- At first: ⌃ on US and other keyboards, Caps Lock on JIS keyboards.
- Choose ⌃, Caps Lock or Both in Settings > Keys > Key held instead of ⌃.
- After Caps Lock is used this way, the caps lock goes back to how it was before the press.
- With Always treat Caps Lock as ⌃ on, other keys are sent with ⌃ too (⌃C in Terminal and so on).
- If Karabiner-Elements or similar turns Caps Lock into another key, it cannot be used here.

## Keys
### Basic Emacs keys
- ⌃F / ⌃B / ⌃N / ⌃P: right, left, down, up. Add ⇧ to select while moving
- ⌃A / ⌃E: start / end of the paragraph, as in macOS
- ⌃D: delete the next character
- ⌃K: cut to end of line into the kill buffer (at the end, the line break)
- ⌃Y: paste the kill buffer
- ⌃G: Esc, ⌃I: Tab, ⌃U: Page Up
### Typing helpers
- ⌃M: Enter, ⌃J: confirm, then move right
- ⌃, / ⌃.: Home / End
- ⌃⌘X / ⌃⌘K: select to line start / end and copy
### Paragraphs and lines
- ⌃⇧↑ / ⌃⇧↓: swap the paragraph with the one above / below
- ⌃S: select and copy the paragraph; press twice quickly to cut it
- ⌃X: cut to the start of the paragraph into the kill buffer
- ⌃Z: paste the kill buffer

## Kill buffer
- Text cut with ⌃K and ⌃X goes into ControlMate's kill buffer, separate from the clipboard.
- ⌃Y and ⌃Z paste it. The ⌘C / ⌘V clipboard does not change.
- Pressing ⌃K again joins the new text to the buffer (⌃K ⌃K takes the line and its break).
- The kill buffer lives in memory only and is gone when ControlMate quits.

## Per-app behavior
- Pass-Through Apps: for each group, apps that get the keys unchanged.
  Apps that already have ⌃F and the others (Safari, Chrome…) are in the lists at first.
- Excluded Apps: no key is replaced in these.
- In Visual Studio Code, moving paragraphs uses the app's own ⌥↑ / ⌥↓.
- The main window shows which groups are replaced in the front app.

## Permissions
- Accessibility: to receive and replace keys, and to read and select text in fields.
  Without it, no key is replaced.
- Text and keystrokes are never recorded or sent anywhere.

## Staying open and quitting
- Closing the window keeps ControlMate in the menu bar (can be changed in Settings).
- The menu bar icon offers the main window, Settings, Pause, Help and Quit.
- Quit with Quit ControlMate in the app menu or the menu bar icon.

## Limits
- Moving and selecting paragraphs, and where ⌃K stops, need text that Accessibility can read.
  Elsewhere ⌃K, ⌃X and ⌃S select the visual line with ⇧⌘→ and similar keys instead.
- Some fields in Chrome and Firefox ignore selection changes,
  so paragraph commands pass through there at first.
- Cut and paste use the app's ⌘X and ⌘V menu items. Undo with the app's ⌘Z.

## Troubleshooting
- Keys are not replaced: check Status and Front app in the main window,
  the Accessibility permission, Replace keys, and the pass-through and excluded lists.
- A key acts twice: stop other background apps or macros that use the same key.
- A paragraph command failed: Last command shows why. Check the text and undo with ⌘Z if needed.

## Removing
Quit ControlMate and move it from the Applications folder to the Trash.
You can also remove it from the Accessibility list in System Settings.'''

HELP_ZH = '''## 使用方法
1. 首次使用时，在“设置 > 启动与后台 > 辅助功能”中授权 ControlMate。
2. 在可输入文字的栏中，按住 ⌃（control）再按 F、B、N、P 等键。
3. 即可用与 Emacs 相同的键移动光标、编辑行和段落。

## 代替 ⌃ 按住的键
- 默认：美式等键盘为 ⌃，JIS 键盘为 Caps Lock。
- 可在“设置 > 按键 > 代替 ⌃ 按住的键”中选择 ⌃、Caps Lock 或两者。
- 以这种方式使用 Caps Lock 后，大写锁定会恢复到按下前的状态。
- 开启“始终将 Caps Lock 视为 ⌃”后，其他键也带 ⌃ 发送（终端的 ⌃C 等）。
- 若用 Karabiner-Elements 等将 Caps Lock 改为其他键，则无法在此使用。

## 按键一览
### Emacs 基本操作
- ⌃F／⌃B／⌃N／⌃P：向右、左、下、上。加按 ⇧ 可边移动边选择
- ⌃A／⌃E：段落开头／末尾（与 macOS 相同）
- ⌃D：删除后一个字符
- ⌃K：剪切到行尾并暂存（在行尾时剪切换行）
- ⌃Y：粘贴暂存的文字
- ⌃G：Esc，⌃I：Tab，⌃U：Page Up
### 输入辅助
- ⌃M：Enter，⌃J：确认后向右
- ⌃,／⌃.：Home／End
- ⌃⌘X／⌃⌘K：选到行首／行尾并拷贝
### 段落与行编辑
- ⌃⇧↑／⌃⇧↓：与上／下段落交换
- ⌃S：选择并拷贝段落；快速按两次则剪切
- ⌃X：剪切到段落开头并暂存
- ⌃Z：粘贴暂存的文字

## 暂存区
- 用 ⌃K 和 ⌃X 剪切的文字存入 ControlMate 自己的暂存区，与剪贴板分开。
- 用 ⌃Y、⌃Z 粘贴。⌘C／⌘V 的剪贴板不变。
- 连续按 ⌃K 会接续存入（⌃K ⌃K 可一起暂存行和换行）。
- 暂存区只在内存中，退出 ControlMate 后消失。

## 各应用的行为
- “直接传递的应用”：按组登记不替换按键的应用。本身支持 ⌃F 等键的应用（Safari、Chrome 等）默认已加入。
- “排除的应用”：不替换任何按键。
- 在 Visual Studio Code 中，移动段落使用应用自身的 ⌥↑／⌥↓。
- 主窗口显示前台应用中替换哪些组。

## 权限
- 辅助功能：用于接收并替换按键，以及读取并选择输入栏中的文字。未授权时不替换任何按键。
- 不会记录或发送文字和按键。

## 常驻与退出
- 关闭窗口后在菜单栏待命（可在设置中更改）。
- 菜单栏图标中可选择主窗口、设置、暂停、帮助和退出。
- 通过应用菜单或菜单栏图标中的“退出 ControlMate”退出。

## 限制
- 移动和选择段落、⌃K 判断行尾，需要可通过辅助功能读取文字的输入栏。
  其他输入栏中，⌃K、⌃X、⌃S 改用 ⇧⌘→ 等键选择显示的行。
- Chrome 和 Firefox 的部分输入栏不接受选择的更改，因此段落操作默认直接传递。
- 剪切和粘贴使用应用菜单的 ⌘X、⌘V。用应用的 ⌘Z 撤销。

## 疑难解答
- 未替换：查看主窗口的“状态”和“前台应用”，确认辅助功能权限、“替换按键”以及直接传递和排除的设置。
- 同一按键执行两次：请停用使用相同按键的其他常驻应用或宏。
- 段落操作失败：“上一个操作”中显示原因。请检查文字，必要时用 ⌘Z 撤销。

## 删除
退出 ControlMate 后，将其从“应用程序”文件夹移到废纸篓。也可以从系统设置的辅助功能列表中移除。'''

HELP_KO = '''## 사용 방법
1. 처음에는 설정 > 시작 및 백그라운드 > 손쉬운 사용에서 ControlMate를 허용합니다.
2. 텍스트를 입력할 수 있는 곳에서 ⌃(control)를 누른 채 F, B, N, P 등을 누릅니다.
3. Emacs와 같은 키로 커서를 움직이고 행과 단락을 편집할 수 있습니다.

## ⌃ 대신 누르는 키
- 처음에는 US 등 키보드는 ⌃, JIS 키보드는 Caps Lock입니다.
- 설정 > 키 > ⌃ 대신 누르는 키에서 ⌃, Caps Lock, 둘 다 중에서 고를 수 있습니다.
- Caps Lock을 이렇게 사용하면 뗀 뒤 대문자 잠금을 누르기 전 상태로 되돌립니다.
- Caps Lock을 항상 ⌃로 취급을 켜면 다른 키도 ⌃를 붙여 보냅니다(터미널의 ⌃C 등).
- Karabiner-Elements 등으로 Caps Lock을 다른 키로 바꾸면 여기서 사용할 수 없습니다.

## 키 목록
### Emacs 기본 조작
- ⌃F / ⌃B / ⌃N / ⌃P: 오른쪽, 왼쪽, 아래, 위. ⇧를 더하면 선택하면서 이동
- ⌃A / ⌃E: 단락 처음 / 끝(macOS와 같음)
- ⌃D: 뒤의 한 글자 삭제
- ⌃K: 행 끝까지 오려 보관(행 끝에서는 줄바꿈)
- ⌃Y: 보관한 텍스트 붙여넣기
- ⌃G: Esc, ⌃I: Tab, ⌃U: Page Up
### 입력 보조
- ⌃M: Enter, ⌃J: 확정 후 오른쪽으로
- ⌃, / ⌃.: Home / End
- ⌃⌘X / ⌃⌘K: 행 처음 / 끝까지 선택해 복사
### 단락과 행 편집
- ⌃⇧↑ / ⌃⇧↓: 위 / 아래 단락과 바꾸기
- ⌃S: 단락 선택 후 복사, 빠르게 두 번 누르면 오려두기
- ⌃X: 단락 처음까지 오려 보관
- ⌃Z: 보관한 텍스트 붙여넣기

## 보관함
- ⌃K와 ⌃X로 오려 둔 텍스트는 클립보드와 별개인 ControlMate의 보관함에 들어갑니다.
- ⌃Y, ⌃Z로 붙여넣습니다. ⌘C / ⌘V의 클립보드는 바뀌지 않습니다.
- ⌃K를 이어서 누르면 보관함에 이어 붙입니다(⌃K ⌃K로 행과 줄바꿈을 함께 보관).
- 보관함은 메모리에만 있으며 ControlMate를 종료하면 사라집니다.

## 앱별 동작
- 그대로 전달할 앱: 그룹별로 키를 바꾸지 않고 그대로 전달할 앱을 등록합니다.
  ⌃F 등을 원래 지원하는 앱(Safari, Chrome 등)은 처음부터 들어 있습니다.
- 제외할 앱: 어떤 키도 바꾸지 않습니다.
- Visual Studio Code에서는 단락 이동에 앱 자체의 ⌥↑ / ⌥↓를 사용합니다.
- 메인 윈도우에 앞쪽 앱에서 어떤 그룹을 바꾸는지 표시합니다.

## 권한
- 손쉬운 사용: 키를 받아 바꾸고, 입력란의 텍스트를 읽고 선택하는 데 사용합니다.
  허용하지 않으면 어떤 키도 바꾸지 않습니다.
- 텍스트나 키 입력을 기록하거나 보내지 않습니다.

## 상주와 종료
- 윈도우를 닫아도 메뉴 막대에서 대기합니다(설정에서 변경 가능).
- 메뉴 막대 아이콘에서 메인 윈도우, 설정, 일시 정지, 도움말, 종료를 고를 수 있습니다.
- 앱 메뉴나 메뉴 막대 아이콘의 ControlMate 종료로 끝냅니다.

## 제한
- 단락 이동과 선택, ⌃K의 행 끝 판단은 손쉬운 사용으로 텍스트를 읽을 수 있는 입력란에서 작동합니다.
  읽을 수 없는 곳에서는 ⌃K, ⌃X, ⌃S가 ⇧⌘→ 등으로 보이는 행을 선택해 대신 처리합니다.
- Chrome과 Firefox의 일부 입력란은 선택 변경을 받지 않으므로 단락 조작은 처음부터 그대로 전달합니다.
- 오려두기와 붙여넣기는 앱 메뉴의 ⌘X, ⌘V를 사용합니다. 취소는 앱의 ⌘Z입니다.

## 문제 해결
- 바뀌지 않음: 메인 윈도우의 상태와 앞쪽 앱을 확인하고,
  손쉬운 사용 권한, 키 바꾸기, 그대로 전달할 앱과 제외할 앱을 확인하세요.
- 같은 키가 두 번 작동함: 같은 키를 쓰는 다른 상주 앱이나 매크로를 멈추세요.
- 단락 조작 실패: 직전 작업에 이유가 표시됩니다. 텍스트를 확인하고 필요하면 ⌘Z로 취소하세요.

## 삭제
ControlMate를 종료한 뒤 응용 프로그램 폴더에서 휴지통으로 옮깁니다.
시스템 설정의 손쉬운 사용 목록에서도 제거할 수 있습니다.'''

T['helpText'] = (HELP_JA, HELP_EN, HELP_ZH, HELP_KO)


def quote(text):
    return text.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')


root = Path(__file__).resolve().parent
for index, lang in enumerate(LANGS):
    folder = root / 'Resources' / f'{lang}.lproj'
    folder.mkdir(parents=True, exist_ok=True)
    lines = [f'"{key}" = "{quote(values[index])}";' for key, values in T.items()]
    (folder / 'Localizable.strings').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    (folder / 'InfoPlist.strings').write_text('"CFBundleDisplayName" = "ControlMate";\n', encoding='utf-8')
print(f'Wrote {len(T)} keys in {len(LANGS)} languages')
