# -*- coding: utf-8 -*-
from pathlib import Path
import json, plistlib
root = Path(__file__).resolve().parent
LANGS = ['ja', 'en', 'zh-Hans', 'ko']
APPLE_EVENTS = ['Illustratorの選択中のテキストの自動カーニングとプロポーショナルメトリクス、ファイル管理の設定を読み書きするために使います。',
                'Reads and sets the auto-kerning and proportional metrics of the selected text in Illustrator, and reads its file handling settings.',
                '用于读取和设置 Illustrator 中所选文本的自动字距调整与比例间距，以及读取文件处理设置。',
                'Illustrator에서 선택한 텍스트의 자동 커닝과 비례 메트릭을 읽고 설정하며, 파일 처리 설정을 읽는 데 사용합니다.']
rows = [
('headline', 'Illustratorの作業を補助', 'Helpers for Illustrator', 'Illustrator 辅助工具', 'Illustrator 작업 도우미'),
('subtitle', 'メトリクスにしたらプロポーショナルメトリクスをON。UIの明るさ、シェイプ形成ツールのカラー、バックグラウンド保存・書き出しも切り替えます。', 'Turns on Proportional Metrics with Metrics kerning, and switches UI brightness, the Shape Builder color and background save and export.', '设为度量标准时打开比例间距，并可切换界面亮度、形状生成器颜色以及后台存储和导出。', '메트릭으로 바꾸면 비례 메트릭을 켜고, UI 밝기·도형 구성 도구 색상·백그라운드 저장/내보내기도 전환합니다.'),
('tab.metrics', 'メトリクス', 'Metrics', '度量标准', '메트릭'),
('metrics.title', 'メトリクスとプロポーショナルメトリクス', 'Metrics and Proportional Metrics', '度量标准与比例间距', '메트릭과 비례 메트릭'),
('metrics.toggle', '自動カーニングを「メトリクス」にしたら、プロポーショナルメトリクスをONにする', 'Turn on Proportional Metrics when auto-kerning is set to Metrics', '将自动字距调整设为“度量标准”时打开比例间距', '자동 커닝을 메트릭으로 바꾸면 비례 메트릭 켜기'),
('metrics.toggleOff', '「メトリクス」以外にしたら、プロポーショナルメトリクスをOFFにする', 'Turn it off when auto-kerning is set to anything other than Metrics', '设为“度量标准”以外时关闭比例间距', '메트릭 이외로 바꾸면 비례 메트릭 끄기'),
('metrics.appliedOn', '%1$@ に%2$ld個のテキストのプロポーショナルメトリクスをONにしました', 'Turned on Proportional Metrics for %2$ld text(s) at %1$@', '已于 %1$@ 为 %2$ld 个文本打开比例间距', '%1$@에 텍스트 %2$ld개의 비례 메트릭을 켰습니다'),
('metrics.appliedOff', '%1$@ に%2$ld個のテキストのプロポーショナルメトリクスをOFFにしました', 'Turned off Proportional Metrics for %2$ld text(s) at %1$@', '已于 %1$@ 为 %2$ld 个文本关闭比例间距', '%1$@에 텍스트 %2$ld개의 비례 메트릭을 껐습니다'),
('metrics.toastOn', 'プロポーショナルメトリクスをONにしました', 'Proportional Metrics turned on', '已打开比例间距', '비례 메트릭을 켰습니다'),
('metrics.toastOff', 'プロポーショナルメトリクスをOFFにしました', 'Proportional Metrics turned off', '已关闭比例间距', '비례 메트릭을 껐습니다'),
('metrics.none', 'まだ切り替えていません', 'Nothing switched yet', '尚未切换', '아직 전환하지 않음'),
('notify.toggle', '切り替えたとき画面上部に短く表示する', 'Show a short message at the top of the screen when it switches', '切换时在屏幕上方短暂显示', '전환했을 때 화면 위쪽에 잠깐 표시'),
('watch.on', '見張り中（クリック・キー）', 'Watching (clicks and keys)', '监视中（点击和按键）', '감시 중(클릭·키)'),
('watch.onMouseOnly', '見張り中（クリックのみ。キーはアクセシビリティの許可が必要）', 'Watching (clicks only; keys need the Accessibility permission)', '监视中（仅点击；按键需要辅助功能权限）', '감시 중(클릭만. 키는 손쉬운 사용 권한 필요)'),
('watch.paused', '一時停止中', 'Paused', '已暂停', '일시 정지됨'),
('watch.off', 'オフ', 'Off', '关闭', '끔'),
('row.state', '状態', 'Status', '状态', '상태'),
('row.last', '前回の結果', 'Last result', '上次结果', '마지막 결과'),
('pause', '一時停止', 'Pause', '暂停', '일시 정지'),
('bg.menu', 'バックグラウンド保存・書き出しをオフ', 'Turn Off Background Save and Export', '关闭后台存储与导出', '백그라운드 저장·내보내기 끄기'),
('working', 'Illustratorの設定を操作しています…', 'Working in Illustrator…', '正在操作 Illustrator…', 'Illustrator를 조작하는 중…'),
('state.unknown', '読み取れませんでした', 'Could not be read', '无法读取', '읽을 수 없습니다'),
('fail.notRunning', 'Illustratorが起動していません', 'Illustrator is not running', 'Illustrator 未运行', 'Illustrator가 실행 중이 아닙니다'),
('fail.noDocument', 'ドキュメントを開いてください（ツールオプションはドキュメントが無いと開きません）', 'Open a document (tool options do not open without one)', '请打开文档（没有文档时无法打开工具选项）', '도큐먼트를 여세요(도큐먼트가 없으면 도구 옵션이 열리지 않습니다)'),
('fail.menuNotFound', 'Illustratorのメニューの項目が見つかりません。開いているダイアログボックスを閉じてから、もう一度実行してください。', 'The menu item was not found in Illustrator. Close any dialog box and try again.', '在 Illustrator 中找不到菜单项。请关闭打开的对话框后重试。', 'Illustrator에서 메뉴 항목을 찾을 수 없습니다. 열린 대화상자를 닫고 다시 실행하세요.'),
('fail.dialogNotFound', 'ダイアログボックスが開きませんでした。もう一度実行してください。', 'The dialog box did not open. Try again.', '对话框未打开。请重试。', '대화상자가 열리지 않았습니다. 다시 실행하세요.'),
('fail.controlNotFound', '項目が見つからないため、変更せずに閉じました（日本語版のIllustratorで確認済み）。', 'The control was not found, so the dialog box was closed without changes (verified with the Japanese Illustrator).', '找不到项目，因此未做更改就关闭了（已在日文版 Illustrator 中验证）。', '항목을 찾을 수 없어 변경하지 않고 닫았습니다(일본어판 Illustrator에서 확인).'),
('fail.notChanged', '操作しましたが、設定が変わっていません。Illustratorで設定を確認してください。', 'The dialog box was operated, but the setting did not change. Check it in Illustrator.', '已操作，但设置没有变化。请在 Illustrator 中检查。', '조작했지만 설정이 바뀌지 않았습니다. Illustrator에서 확인하세요.'),
('bright.title', 'UIの明るさ', 'UI Brightness', '界面亮度', 'UI 밝기'),
('bright.menuUp', 'UIを明るく', 'Make UI Brighter', '调亮界面', 'UI 밝게'),
('bright.menuDown', 'UIを暗く', 'Make UI Darker', '调暗界面', 'UI 어둡게'),
('bright.level.dark', '暗', 'Dark', '暗', '어둡게'),
('bright.level.mediumDark', 'やや暗め', 'Medium Dark', '中等深色', '약간 어둡게'),
('bright.level.mediumLight', 'やや明るめ', 'Medium Light', '中等浅色', '약간 밝게'),
('bright.level.light', '明', 'Light', '亮', '밝게'),
('bright.done', 'UIの明るさ：%@', 'UI brightness: %@', '界面亮度：%@', 'UI 밝기: %@'),
('bright.atMax', 'いちばん明るい「明」です', 'Already the lightest (Light)', '已是最亮（亮）', '이미 가장 밝습니다'),
('bright.atMin', 'いちばん暗い「暗」です', 'Already the darkest (Dark)', '已是最暗（暗）', '이미 가장 어둡습니다'),
('shape.title', 'シェイプ形成ツールのカラー', 'Shape Builder Tool Color', '形状生成器工具颜色', '도형 구성 도구 색상'),
('shape.detail', '［シェイプ形成ツールオプション］の「次のカラーを利用」を切り替えます。ツールオプションを開いて選ぶので、ドキュメントを開いておいてください。ツールはシェイプ形成ツールに切り替わります。', 'Switches Pick Color From in the Shape Builder Tool Options. The tool options are opened, so a document must be open. The Shape Builder tool becomes active.', '切换“形状生成器工具选项”中的“拾色来源”。会打开工具选项，因此需要打开文档。工具会切换为形状生成器工具。', '도형 구성 도구 옵션의 색상 선택 위치를 전환합니다. 도구 옵션을 열기 때문에 도큐먼트가 열려 있어야 합니다. 도구는 도형 구성 도구로 바뀝니다.'),
('shape.swatches', 'スウォッチ', 'Color Swatches', '色板', '색상 견본'),
('shape.artwork', 'オブジェクト', 'Artwork', '图稿', '아트워크'),
('tool.selectTitle', '選択ツール', 'Selection Tool', '选择工具', '선택 도구'),
('tool.doubleTap', '修飾キーのダブルタップで選択ツールに切り替える', 'Double-tap a modifier key to switch to the Selection tool', '连按两下修饰键切换到选择工具', '보조 키를 두 번 탭하면 선택 도구로 전환'),
('tool.tapKey', 'キー :', 'Key:', '按键：', '키:'),
('tool.controlDoubleTapDetail', 'Illustratorが前面のとき、選んだキーだけを2回続けて軽く押すと app.selectTool(\'Adobe Select Tool\') を実行します。ほかのキーやクリックを挟むと数えません。', 'While Illustrator is in front, tapping the chosen key alone twice runs app.selectTool(\'Adobe Select Tool\'). Another key or a click in between cancels it.', 'Illustrator 位于前台时，单独连按两下所选的键会执行 app.selectTool(\'Adobe Select Tool\')。中间按其他键或点按则不计。', 'Illustrator가 앞에 있을 때 선택한 키만 두 번 가볍게 누르면 app.selectTool(\'Adobe Select Tool\')를 실행합니다. 사이에 다른 키나 클릭이 있으면 세지 않습니다.'),
('tool.panelTitle', 'ツールに合わせてパネルを開く', 'Open Panels for Tools', '按工具打开面板', '도구에 맞춰 패널 열기'),
('tool.artboardPanel', 'アートボードツールを選んだらアートボードパネルを開く', 'Open the Artboards panel with the Artboard tool', '选择画板工具时打开“画板”面板', '대지 도구를 선택하면 대지 패널 열기'),
('tool.gradientPanel', 'グラデーションツールを選んだらグラデーションパネルを開く', 'Open the Gradient panel with the Gradient tool', '选择渐变工具时打开“渐变”面板', '그레이디언트 도구를 선택하면 그레이디언트 패널 열기'),
('tool.panelDetail', 'クリックやキーの後にツールを読み、ほかのツールから切り替わったときだけ開きます（［ウィンドウ］メニューに ✓ が付いていれば何もしません）。', 'The tool is read after clicks and keys; the panel opens only when the tool is switched to from another one (nothing happens when the Window menu item already has a checkmark).', '在点按或按键后读取工具，仅在从其他工具切换过来时打开（“窗口”菜单中已有 ✓ 时不执行任何操作）。', '클릭이나 키 입력 뒤에 도구를 읽고, 다른 도구에서 전환했을 때만 엽니다(윈도우 메뉴에 ✓가 있으면 아무것도 하지 않습니다).'),
('shape.menuSwatches', 'シェイプ形成ツールのカラー：スウォッチ', 'Shape Builder Color: Color Swatches', '形状生成器颜色：色板', '도형 구성 색상: 색상 견본'),
('shape.menuArtwork', 'シェイプ形成ツールのカラー：オブジェクト', 'Shape Builder Color: Artwork', '形状生成器颜色：图稿', '도형 구성 색상: 아트워크'),
('shape.done', '「次のカラーを利用」を「%@」にしました', 'Pick Color From is now %@', '“拾色来源”已设为“%@”', '색상 선택 위치를 %@(으)로 바꿨습니다'),
('shape.already', '「次のカラーを利用」はすでに「%@」です', 'Pick Color From is already %@', '“拾色来源”已是“%@”', '색상 선택 위치가 이미 %@입니다'),
('hotkey.tab', 'ホットキー', 'Hotkeys', '快捷键', '단축키'),
('hotkey.brighter', 'UIを明るく', 'Make UI brighter', '调亮界面', 'UI 밝게'),
('hotkey.darker', 'UIを暗く', 'Make UI darker', '调暗界面', 'UI 어둡게'),
('hotkey.hint', 'Illustratorが前面のときだけ使えます。ほかのアプリではキーを横取りしません。押すたびに環境設定のダイアログボックスを開いて明るさのボタンを押します（アクセシビリティの許可が必要です）。', 'Works only while Illustrator is in front; other apps keep the keys. Each press opens the Settings dialog box and clicks the brightness button (needs the Accessibility permission).', '仅在 Illustrator 位于前台时可用，不会占用其他应用的按键。每次按下都会打开设置对话框并点按亮度按钮（需要辅助功能权限）。', 'Illustrator가 앞에 있을 때만 작동하며 다른 앱의 키는 가로채지 않습니다. 누를 때마다 설정 대화상자를 열어 밝기 버튼을 누릅니다(손쉬운 사용 권한 필요).'),
('hotkey.status', '明るく %1$@／暗く %2$@（Illustratorが前面のとき）', 'Brighter %1$@ / Darker %2$@ (while Illustrator is in front)', '调亮 %1$@／调暗 %2$@（Illustrator 位于前台时）', '밝게 %1$@ / 어둡게 %2$@(Illustrator가 앞에 있을 때)'),
('hotkey.off', 'オフ', 'Off', '关闭', '끔'),
('tab.interface', '基本UI', 'Basic UI', '基本界面', '기본 UI'),
('tab.tools', 'ツール', 'Tools', '工具', '도구'),
('hotkey.open', 'ホットキーを設定…', 'Set Hotkeys…', '设置快捷键…', '단축키 설정…'),
('ui.title', '表示', 'Display', '显示', '표시'),
('ui.advancedToolbar', 'ツールバー（詳細）', 'Toolbar (Advanced)', '工具栏（高级）', '도구 막대(고급)'),
('ui.contextualTaskBar', 'コンテキストタスクバー', 'Contextual Task Bar', '上下文任务栏', '상황별 작업 표시줄'),
('ui.controlBar', 'コントロールバー', 'Control Bar', '控制栏', '컨트롤 막대'),
('ui.helpBar', 'ヘルプバー', 'Help Bar', '帮助栏', '도움말 막대'),
('ui.applicationBar', 'アプリケーションバー', 'Application Bar', '应用程序栏', '응용 프로그램 막대'),
('ui.applicationFrame', 'アプリケーションフレーム', 'Application Frame', '应用程序框架', '응용 프로그램 프레임'),
('ui.snapToGlyph', 'グリフにスナップ', 'Snap to Glyph', '对齐字形', '글리프에 물리기'),
('ui.oldSchool', 'クラシック表示', 'Classic Layout', '经典布局', '클래식 레이아웃'),
('ui.oldSchoolDetail', 'ツールバー：詳細／コントロールバー：ON／ヘルプバー：OFF／アプリケーションバー：OFF／アプリケーションフレーム：OFF／グリフにスナップ：OFF／コンテキストタスクバー：OFF。ツールバーの2段表示はスクリプトから切り替えられないため、ツールバー上端の «» で切り替えてください。', 'Toolbar: Advanced / Contextual Task Bar: off / Control Bar: on / Snap to Glyph: off / Help Bar: off / Application Bar: off / Application Frame: off. The toolbar’s two-column layout cannot be switched from here; use « » at the top of the toolbar.', '工具栏：高级／上下文任务栏：关／控制栏：开／对齐字形：关／帮助栏：关／应用程序栏：关／应用程序框架：关。工具栏的双栏显示无法在此切换，请使用工具栏顶部的 «»。', '도구 막대: 고급 / 상황별 작업 표시줄: 끔 / 컨트롤 막대: 켬 / 글리프에 물리기: 끔 / 도움말 막대: 끔 / 응용 프로그램 막대: 끔 / 응용 프로그램 프레임: 끔. 도구 막대 2열 표시는 여기서 바꿀 수 없으니 도구 막대 위쪽의 «»를 사용하세요.'),
('ui.oldSchoolDone', 'クラシック表示にしました', 'Classic layout applied', '已应用经典布局', '클래식 레이아웃을 적용했습니다'),
('ui.turnedOn', '%@をONにしました', 'Turned on: %@', '已打开：%@', '%@을(를) 켰습니다'),
('ui.turnedOff', '%@をOFFにしました', 'Turned off: %@', '已关闭：%@', '%@을(를) 껐습니다'),
('file.title', '保存・書き出し', 'Save and Export', '存储与导出', '저장·내보내기'),
('file.export', 'バックグラウンド書き出し', 'Export in Background', '后台导出', '백그라운드 내보내기'),
('file.save', 'バックグラウンド保存', 'Save in Background', '后台存储', '백그라운드 저장'),
('file.recovery', '復帰データの自動保存', 'Automatically save recovery data', '自动存储恢复数据', '복구 데이터 자동 저장'),
('file.check', '確認', 'Check', '检查', '확인'),
('file.unchecked', '読み取れませんでした（「確認」でダイアログボックスから読み込みます）', 'Could not be read (Check reads it from the dialog box)', '无法读取（点按“检查”从对话框读取）', '읽을 수 없습니다(확인을 누르면 대화상자에서 읽습니다)'),
('file.checked', '現在の設定を読み込みました', 'Read the current settings', '已读取当前设置', '현재 설정을 읽었습니다'),
('file.detail', 'Illustratorの［設定］→［ファイル管理］の項目です。現在の状態はIllustratorの設定ファイルから読みます（Illustratorで変えた分は、終了時に書き込まれるまで反映されないことがあります。「確認」はダイアログボックスを開いて読みます）。チェックを切り替えると、環境設定のダイアログボックスを開いて変えます（アクセシビリティの許可が必要です）。', 'Items of Illustrator Settings → File Handling. The state is read from Illustrator’s preference files (a change made in Illustrator may not be there until it quits; Check reads the dialog box). Each change opens the Settings dialog box (needs the Accessibility permission).', 'Illustrator“设置 → 文件处理”中的项目。当前状态从 Illustrator 的设置文件读取（在 Illustrator 中的更改可能要退出时才写入；“检查”会打开对话框读取）。每次切换都会打开设置对话框（需要辅助功能权限）。', 'Illustrator 설정 → 파일 처리의 항목입니다. 현재 상태는 Illustrator 설정 파일에서 읽습니다(Illustrator에서 바꾼 내용은 종료할 때 기록될 수 있습니다. 확인은 대화상자를 열어 읽습니다). 전환할 때마다 설정 대화상자를 엽니다(손쉬운 사용 권한 필요).'),
('bg.done', 'バックグラウンド保存・書き出しをオフにしました', 'Background save and export turned off', '已关闭后台存储与导出', '백그라운드 저장·내보내기를 껐습니다'),
('units.title', '単位', 'Units', '单位', '단위'),
('units.preset.mmPt', 'プリント（pt）', 'Print (pt)', '印刷（pt）', '인쇄(pt)'),
('units.preset.mmQH', 'プリント（級）', 'Print (Q)', '印刷（级）', '인쇄(급)'),
('units.preset.px', 'ウェブ', 'Web', '网页', '웹'),
('units.done', '単位を「%@」にしました', 'Units set to %@', '单位已设为“%@”', '단위를 %@(으)로 바꿨습니다'),
('units.general', '一般', 'General', '常规', '일반'),
('units.stroke', '線', 'Stroke', '描边', '선'),
('units.type', '文字', 'Type', '文字', '문자'),
('units.asian', '東アジア言語', 'East Asian Type', '东亚文字', '동아시아 문자'),
('units.keyIncrement', 'キー入力', 'Keyboard Increment', '键盘增量', '키보드 증감'),
('units.cornerRadius', '角丸の半径', 'Corner Radius', '圆角半径', '모퉁이 반경'),
('units.sizeIncrement', 'サイズ/行送り', 'Size/Leading', '大小/行距', '크기/행간'),
('units.baselineIncrement', 'ベースラインシフト', 'Baseline Shift', '基线偏移', '기준선 이동'),
('units.detail', 'mm・pt：一般 mm／線・文字・東アジア言語 pt（キー入力 0.1mm・角丸の半径 1mm・サイズ/行送り 1pt・ベースラインシフト 0.1pt）。mm・Q/H：一般・線 mm／文字 Q／東アジア言語 H（0.1mm・1mm・1Q・0.5H）。px：すべて px（1px・1px・1px・0.1px）。単位はスクリプトから書いても再起動まで効かないため、環境設定の［単位］を開いて矢印キーで選び、［OK］を押します。操作中はキーボードやマウスに触れないでください。', 'mm / pt: General mm; Stroke, Type and East Asian pt (keyboard 0.1 mm, corner radius 1 mm, size/leading 1 pt, baseline shift 0.1 pt). mm / Q/H: General and Stroke mm, Type Q, East Asian H (0.1 mm, 1 mm, 1 Q, 0.5 H). px: all px (1, 1, 1, 0.1 px). Units written from a script only take effect after a restart, so the Units pane of Settings is opened, the units are picked with the arrow keys and OK is pressed. Do not touch the keyboard or mouse meanwhile.', 'mm・pt：常规 mm，描边、文字、东亚文字 pt（键盘 0.1mm、圆角半径 1mm、大小/行距 1pt、基线偏移 0.1pt）。mm・Q/H：常规与描边 mm，文字 Q，东亚文字 H（0.1mm、1mm、1Q、0.5H）。px：全部 px（1、1、1、0.1px）。用脚本写入的单位要重启后才生效，因此会打开设置的“单位”，用方向键选择后按“好”。操作期间请勿触碰键盘和鼠标。', 'mm·pt: 일반 mm, 선·문자·동아시아 문자 pt(키보드 0.1mm, 모퉁이 반경 1mm, 크기/행간 1pt, 기준선 이동 0.1pt). mm·Q/H: 일반·선 mm, 문자 Q, 동아시아 문자 H(0.1mm, 1mm, 1Q, 0.5H). px: 모두 px(1, 1, 1, 0.1px). 스크립트로 쓴 단위는 재시작해야 적용되므로 설정의 단위를 열어 화살표 키로 고른 뒤 확인을 누릅니다. 조작 중에는 키보드와 마우스를 만지지 마세요.'),
('palette.title', '単位パレット', 'Units Palette', '单位面板', '단위 팔레트'),
('palette.menu', '単位パレットを表示', 'Show Units Palette', '显示单位面板', '단위 팔레트 보기'),
('palette.open', '単位パレットを開く', 'Open Units Palette', '打开单位面板', '단위 팔레트 열기'),
('palette.openHint', '単位の切り替えはパレットで行います。', 'Units are switched in the palette.', '在面板中切换单位。', '단위는 팔레트에서 전환합니다.'),
('palette.switch', '切り替える', 'Switch', '切换', '전환'),
('palette.current', '  — 現在', '  — Current', '  — 当前', '  — 현재'),
('palette.hint', 'ダブルクリック・⌘Returnで切り替え。Escで隠す', 'Double-click or ⌘Return to switch. Esc hides', '双击或 ⌘Return 切换。Esc 隐藏', '이중 클릭·⌘Return으로 전환. Esc로 숨기기'),
('hotkey.palette', '単位パレットを表示／隠す', 'Show or hide the Units Palette', '显示或隐藏单位面板', '단위 팔레트 보기/숨기기'),
('hotkey.paletteHint', '初期値は ⌃⌥⌘U。Illustratorが前面のときだけ使えます。同じキーを使う KageTrimmer は、Illustratorが前面の間はこのキーを譲ります。', 'Default ⌃⌥⌘U. Works only while Illustrator is in front; KageTrimmer, which uses the same key, gives it up while Illustrator is in front.', '默认 ⌃⌥⌘U。仅在 Illustrator 位于前台时可用；使用同一按键的 KageTrimmer 在 Illustrator 位于前台时会让出此键。', '기본값 ⌃⌥⌘U. Illustrator가 앞에 있을 때만 작동하며, 같은 키를 쓰는 KageTrimmer는 Illustrator가 앞에 있는 동안 이 키를 양보합니다.'),
('units.preset.presentation', 'プレゼン', 'Presentation', '演示', '프레젠테이션'),
('units.doneDetail', '「%@」にしました（詳細）', 'Applied %@ (detailed)', '已应用“%@”（详细）', '%@ 적용(상세)'),
('units.noDocument', '。ドキュメントがないため、ドキュメントの設定は変えていません', '. No document is open, so the document settings were left as they are', '。没有打开的文档，因此未更改文档设置', '. 열린 도큐먼트가 없어 도큐먼트 설정은 바꾸지 않았습니다'),
('palette.mode', 'モード :', 'Mode:', '模式：', '모드:'),
('palette.basic', '基本', 'Basic', '基本', '기본'),
('palette.detail', '詳細', 'Detailed', '详细', '상세'),
('palette.edit', '編集…', 'Edit…', '编辑…', '편집…'),
('palette.sep', '／', ' / ', '／', ' / '),
('palette.increments', 'キー %1$@・角丸 %2$@・サイズ %3$@・BS %4$@', 'key %1$@, corner %2$@, size %3$@, shift %4$@', '键盘 %1$@・圆角 %2$@・大小 %3$@・偏移 %4$@', '키 %1$@·모퉁이 %2$@·크기 %3$@·이동 %4$@'),
('palette.overprintOn', 'オーバープリント ON', 'Overprint on', '叠印 开', '중복 인쇄 켬'),
('palette.overprintOff', 'オーバープリント OFF', 'Overprint off', '叠印 关', '중복 인쇄 끔'),
('sets.tab', '単位セット', 'Unit Sets', '单位组合', '단위 세트'),
('sets.title', '単位パレットのセット', 'Sets of the Units Palette', '单位面板的组合', '단위 팔레트 세트'),
('sets.untitled', '（名前なし）', '(Untitled)', '（无名称）', '(이름 없음)'),
('sets.add', 'セットを複製して追加', 'Duplicate and add a set', '复制并添加组合', '세트 복제하여 추가'),
('sets.remove', 'セットを削除', 'Delete the set', '删除组合', '세트 삭제'),
('sets.up', '上へ', 'Move up', '上移', '위로'),
('sets.down', '下へ', 'Move down', '下移', '아래로'),
('sets.choose', 'セットを選んでください', 'Choose a set', '请选择组合', '세트를 선택하세요'),
('sets.reset', 'すべて初期値に戻す', 'Reset All to Defaults', '全部恢复默认', '모두 기본값으로 되돌리기'),
('sets.resetConfirm', '単位セットを初期値（プリント（pt）・プリント（級）・ウェブ・プレゼン）に戻しますか？', 'Reset the unit sets to the defaults (Print (pt), Print (Q), Web, Presentation)?', '要将单位组合恢复为默认（印刷（pt）、印刷（级）、网页、演示）吗？', '단위 세트를 기본값(인쇄(pt), 인쇄(급), 웹, 프레젠테이션)으로 되돌릴까요?'),
('sets.hint', '単位と増減量は「基本」「詳細」のどちらでも変わります。ドキュメントの設定は、単位パレットのモードが「詳細」のときだけ変わります（「変更しない」の項目はそのまま。ドキュメントの設定は開いているドキュメントに対して行います）。増減量は、キー入力・角丸の半径は一般、サイズ/行送りは文字、ベースラインシフトは東アジア言語の単位で指定します。', 'Units and increments change in both Basic and Detailed mode. Document settings change only in Detailed mode (items set to Leave unchanged stay as they are; document settings apply to the open document). Keyboard increment and corner radius are in the General unit, size/leading in the Type unit, baseline shift in the East Asian unit.', '单位和增量在“基本”和“详细”模式下都会更改。文档设置仅在“详细”模式下更改（“不更改”的项目保持原样；文档设置作用于打开的文档）。键盘增量和圆角半径使用常规单位，大小/行距使用文字单位，基线偏移使用东亚文字单位。', '단위와 증감량은 기본과 상세 모두에서 바뀝니다. 도큐먼트 설정은 상세 모드에서만 바뀝니다(변경 안 함 항목은 그대로이며, 도큐먼트 설정은 열린 도큐먼트에 적용). 키보드 증감과 모퉁이 반경은 일반 단위, 크기/행간은 문자 단위, 기준선 이동은 동아시아 단위로 지정합니다.'),
('sets.name', 'セット名', 'Set Name', '组名称', '세트 이름'),
('sets.detailTitle', '増減量', 'Increments', '增量', '증감량'),
('sets.otherTitle', 'その他（カラーモード、プレビュー）', 'Other (color mode, preview)', '其他（颜色模式、预览）', '기타(색상 모드, 미리 보기)'),
('sets.colorMode', 'カラーモード', 'Color mode', '颜色模式', '색상 모드'),
('sets.overprint', 'オーバープリントプレビュー', 'Overprint Preview', '叠印预览', '중복 인쇄 미리 보기'),
('sets.resolution', 'ラスタライズ効果の解像度', 'Raster effects resolution', '栅格效果分辨率', '래스터 효과 해상도'),
('sets.keep', '変更しない', 'Leave unchanged', '不更改', '변경 안 함'),
('sets.res72', '画面（72ppi）', 'Screen (72 ppi)', '屏幕（72ppi）', '화면(72ppi)'),
('sets.res150', '標準（150ppi）', 'Medium (150 ppi)', '中（150ppi）', '중간(150ppi)'),
('sets.res300', '高解像度（300ppi）', 'High (300 ppi)', '高（300ppi）', '고해상도(300ppi)'),
('sets.copyName', '%@ のコピー', '%@ copy', '%@ 副本', '%@ 사본'),
('sets.snapToPixel', 'ピクセルにスナップ', 'Snap to Pixel', '对齐像素', '픽셀에 물리기'),
('palette.snapOn', 'ピクセルにスナップ ON', 'Snap to pixel on', '对齐像素 开', '픽셀에 물리기 켬'),
('palette.snapOff', 'ピクセルにスナップ OFF', 'Snap to pixel off', '对齐像素 关', '픽셀에 물리기 끔'),
('sets.grid', '透明グリッドの色', 'Transparency grid colors', '透明度网格颜色', '투명도 격자 색상'),
('sets.gridMatchTop', '上側の色にそろえる', 'Match the upper color', '与上方颜色一致', '위쪽 색상에 맞추기'),
('sets.gridColor', '2色とも指定した色', 'Both to this color', '两种颜色都设为指定颜色', '두 색 모두 지정한 색'),
('prefsets.mainTab', '環境設定', 'Preferences', '首选项', '환경설정'),
('prefsets.tab', '環境設定セット', 'Preference Sets', '首选项组合', '환경설정 세트'),
('prefsets.title', '環境設定セット', 'Preference Sets', '首选项组合', '환경설정 세트'),
('prefsets.setsTitle', '環境設定のセット', 'Sets of Preferences', '首选项的组合', '환경설정 세트'),
('prefsets.preset.default', 'デフォルト', 'Default', '默认', '기본값'),
('prefsets.preset.preset1', 'プリセット1', 'Preset 1', '预设 1', '사전 설정 1'),
('prefsets.noMatch', '今の環境設定はどのセットとも一致しません', 'The current preferences match none of the sets', '当前首选项与任何组合都不一致', '현재 환경설정은 어느 세트와도 일치하지 않습니다'),
('prefsets.edit', 'セットを編集…', 'Edit Sets…', '编辑组合…', '세트 편집…'),
('prefsets.detail', 'セットを選ぶと、Illustratorの環境設定（一般・選択範囲・アートボード・テキスト・UIの明るさ・ガイド（ガイドをロックを含む）・シェイプ形成ツール・パフォーマンス・ファイル管理など）をまとめて書き換えます。UIの明るさ・シェイプ形成ツールのカラー・バックグラウンドの3項目は、今と異なるときだけダイアログボックスを開いて変えます。ガイドをロックはメニューで切り替えます（アクセシビリティの許可が必要）。ガイドをロックとシェイプ形成ツールのカラーはドキュメントが要るので、開いていなければ新規ドキュメントを作って変え、保存せずに閉じます。セットの中身は設定の「環境設定セット」タブで編集します。', 'Choosing a set rewrites Illustrator’s preferences (General, Selection, Artboards, Type, UI brightness, Guides (with Lock Guides), Shape Builder, Performance, File Handling and more) at once. UI brightness, the Shape Builder color and the three background items open their dialog boxes only when they differ, and Lock Guides is toggled from its menu (Accessibility permission needed). Lock Guides and the Shape Builder color need a document: without one, a new document is made to change them and closed without saving. The sets are edited in the Preference Sets tab of Settings.', '选择组合后，会一次性改写 Illustrator 的首选项（常规、选择、画板、文字、界面亮度、参考线（含锁定参考线）、形状生成器工具、性能、文件处理等）。界面亮度、形状生成器工具颜色和后台的 3 个项目仅在与当前不同时打开对话框更改，锁定参考线通过菜单切换（需要辅助功能权限）。锁定参考线和形状生成器工具颜色需要文档：未打开文档时会新建文档进行更改，然后不存储即关闭。组合内容在设置的“首选项组合”标签中编辑。', '세트를 고르면 Illustrator의 환경설정(일반·선택·대지·문자·UI 밝기·안내선(안내선 잠그기 포함)·도형 구성 도구·성능·파일 처리 등)을 한꺼번에 바꿉니다. UI 밝기·도형 구성 도구 색상·백그라운드 3개 항목은 현재와 다를 때만 대화상자를 열어 바꾸고, 안내선 잠그기는 메뉴로 전환합니다(손쉬운 사용 권한 필요). 안내선 잠그기와 도형 구성 도구 색상은 도큐먼트가 필요하므로, 열려 있지 않으면 새 도큐먼트를 만들어 바꾸고 저장하지 않고 닫습니다. 세트 내용은 설정의 환경설정 세트 탭에서 편집합니다.'),
('prefsets.hint', '編集は［上書き］を押すと保存されます（Illustratorには書き込みません）。［元に戻す］で最後に保存した状態に戻ります。Illustratorに反映するのは、メインウインドウの「環境設定」タブでセットを選んだときです。「今の設定を取り込む」は、選んでいるセットの値をIllustratorの今の環境設定で置き換えます。', 'Edits are saved when you click Overwrite (nothing is written to Illustrator); Revert goes back to what was last saved. Illustrator changes when a set is chosen in the Preferences tab of the main window. Use Current Settings replaces the values of the selected set with Illustrator’s current preferences.', '点按“覆盖”时保存编辑（不会写入 Illustrator）。“还原”会回到上次保存的状态。在主窗口的“首选项”标签中选择组合时才会应用到 Illustrator。“使用当前设置”会用 Illustrator 当前的首选项替换所选组合的值。', '편집은 덮어쓰기를 누르면 저장됩니다(Illustrator에는 쓰지 않습니다). 되돌리기는 마지막으로 저장한 상태로 돌아갑니다. 메인 윈도우의 환경설정 탭에서 세트를 고를 때 Illustrator에 반영됩니다. 현재 설정 가져오기는 선택한 세트의 값을 Illustrator의 현재 환경설정으로 바꿉니다.'),
('prefsets.resetConfirm', '環境設定セットを初期値（デフォルト・プリセット1）に戻しますか？', 'Reset the preference sets to the defaults (Default, Preset 1)?', '要将首选项组合恢复为默认（默认、预设 1）吗？', '환경설정 세트를 기본값(기본값, 사전 설정 1)으로 되돌릴까요?'),
('prefsets.capture', '今の設定を取り込む', 'Use Current Settings', '使用当前设置', '현재 설정 가져오기'),
('prefsets.save', '上書き', 'Overwrite', '覆盖', '덮어쓰기'),
('prefsets.revert', '元に戻す', 'Revert', '还原', '되돌리기'),
('prefsets.unsaved', '保存していない変更があります', 'Unsaved changes', '有未保存的更改', '저장하지 않은 변경 사항이 있습니다'),
('prefsets.done', '環境設定を「%@」にしました', 'Preferences set to “%@”', '已将首选项设为“%@”', '환경설정을 “%@”(으)로 바꿨습니다'),
('prefsets.partly', '環境設定を「%@」にしました（一部の項目は読み戻した値が異なります）', 'Preferences set to “%@” (some items read back differently)', '已将首选项设为“%@”（部分项目读回的值不同）', '환경설정을 “%@”(으)로 바꿨습니다(일부 항목은 다시 읽은 값이 다릅니다)'),
('prefsets.captured', '「%@」にIllustratorの今の設定を取り込みました', 'Illustrator’s current settings copied to “%@”', '已将 Illustrator 当前设置复制到“%@”', '“%@”에 Illustrator의 현재 설정을 가져왔습니다'),
('prefsets.cat.general', '一般', 'General', '常规', '일반'),
('prefsets.cat.selection', '選択範囲・アンカー表示', 'Selection & Anchor Display', '选择和锚点显示', '선택 및 고정점 표시'),
('prefsets.cat.artboard', 'アートボード', 'Artboards', '画板', '대지'),
('prefsets.cat.text', 'テキスト', 'Type', '文字', '문자'),
('prefsets.cat.interface', 'ユーザーインターフェイス', 'User Interface', '用户界面', '사용자 인터페이스'),
('prefsets.cat.guides', 'ガイド', 'Guides', '参考线', '안내선'),
('prefsets.cat.smartGuides', 'スマートガイド', 'Smart Guides', '智能参考线', '고급 안내선'),
('prefsets.cat.performance', 'パフォーマンス', 'Performance', '性能', '성능'),
('prefsets.cat.file', 'ファイル管理', 'File Handling', '文件处理', '파일 처리'),
('prefsets.cat.shapeBuilder', 'シェイプ形成ツール', 'Shape Builder Tool', '形状生成器工具', '도형 구성 도구'),
('prefsets.brightness', '明るさ :', 'Brightness:', '亮度：', '밝기:'),
('prefsets.shapeColor', '次のカラーを利用 :', 'Pick Color From:', '拾色来源：', '색상 선택 위치:'),
('prefsets.dialogTip', '今と異なるときだけ、セットを選んだときに環境設定のダイアログボックスを開いて変えます', 'Changed through the Settings dialog box when a set is chosen, only if it differs', '仅在与当前不同时，选择组合时打开首选项对话框更改', '현재와 다를 때만 세트를 고를 때 환경설정 대화상자를 열어 바꿉니다'),
('prefsets.shapeTip', '今と異なるときだけ、ツールオプションを開いて変えます（ドキュメントが開いていなければ新規ドキュメントを作り、保存せずに閉じます。ツールは元に戻します）', 'Changed through the tool options only if it differs (without an open document, a new one is made and closed without saving; the tool is restored)', '仅在与当前不同时打开工具选项更改（未打开文档时会新建文档，然后不存储即关闭；工具会恢复）', '현재와 다를 때만 도구 옵션을 열어 바꿉니다(도큐먼트가 없으면 새로 만들고 저장하지 않고 닫습니다. 도구는 원래대로 돌립니다)'),
('prefsets.lockGuides', 'ガイドをロック', 'Lock Guides', '锁定参考线', '안내선 잠그기'),
('prefsets.lockGuidesTip', '［表示］→［ガイド］→［ガイドをロック］。ドキュメントが開いていなければ、新規ドキュメントを作って切り替え、保存せずに閉じます', 'View → Guides → Lock Guides. Without an open document, a new one is made to switch it and closed without saving', '“视图 → 参考线 → 锁定参考线”。未打开文档时，会新建文档进行切换，然后不存储即关闭', '보기 → 안내선 → 안내선 잠그기. 도큐먼트가 열려 있지 않으면 새 도큐먼트를 만들어 전환하고 저장하지 않고 닫습니다'),
('prefsets.shapeColorName', 'シェイプ形成ツールのカラー', 'the Shape Builder color', '形状生成器工具颜色', '도형 구성 도구 색상'),
('prefsets.skippedNoDocument', '（ドキュメントが開いていないので、%@ は変えていません）', ' (no document is open, so %@ was not changed)', '（未打开文档，未更改%@）', '(도큐먼트가 열려 있지 않아 %@은(는) 바꾸지 않았습니다)'),
('list.separator', '・', ', ', '、', ', '),
('prefsets.failedPart', '環境設定を「%@」にしましたが、一部の項目を変えられませんでした：%@', 'Preferences set to “%@”, but some items could not be changed: %@', '已将首选项设为“%@”，但部分项目无法更改：%@', '환경설정을 “%@”(으)로 바꿨지만 일부 항목은 바꾸지 못했습니다: %@'),
('prefsets.cat.clipboard', 'クリップボードの処理', 'Clipboard Handling', '剪贴板处理', '클립보드 처리'),
('prefsets.richToolTips', '詳細なツールヒントを表示', 'Show Rich Tool Tips', '显示丰富的工具提示', '풍부한 도구 설명 표시'),
('prefsets.homeScreen', '「ホーム画面」を表示', 'Show the Home Screen', '显示“主页”屏幕', '홈 화면 표시'),
('prefsets.homeScreenTip', 'ドキュメントを開いていないときに「ホーム画面」を表示', 'Show the Home Screen When No Documents Are Open', '没有打开的文档时显示“主页”屏幕', '도큐먼트가 열려 있지 않을 때 홈 화면 표시'),
('prefsets.legacyNewDoc', '以前の「新規ドキュメント」インターフェイス', 'Legacy “File > New” Interface', '旧版“新建文档”界面', '이전 “새로 만들기” 인터페이스'),
('prefsets.legacyNewDocTip', '以前の「新規ドキュメント」インターフェイスを使用', 'Use Legacy “File > New” Interface', '使用旧版“新建文档”界面', '이전 “새로 만들기” 인터페이스 사용'),
('prefsets.printBleedWidget', '「裁ち落としを印刷」生成AIボタンを表示', 'Show “Print Bleed” generative AI buttons', '显示“打印出血”生成式 AI 按钮', '“재단 여백 인쇄” 생성형 AI 버튼 표시'),
('prefsets.zoomToSelection', '選択範囲へズーム', 'Zoom to Selection', '缩放至选区', '선택 영역으로 확대/축소'),
('prefsets.unlockOnCanvas', 'カンバス上でロック解除', 'Unlock on Canvas', '在画布上解锁', '캔버스에서 잠금 해제'),
('prefsets.unlockOnCanvasTip', 'カンバス上のオブジェクトとアートボードを選択してロック解除', 'Select and Unlock Objects and Artboards on Canvas', '在画布上选择并解锁对象和画板', '캔버스에서 오브젝트와 대지를 선택하여 잠금 해제'),
('prefsets.objectPathOnly', 'オブジェクトの選択範囲をパスに制限', 'Object Selection by Path Only', '仅按路径选择对象', '패스로만 오브젝트 선택'),
('prefsets.textPathOnly', 'テキストオブジェクトの選択範囲をパスに制限', 'Type Object Selection by Path Only', '仅按路径选择文字对象', '패스로만 문자 오브젝트 선택'),
('prefsets.anchorSize', 'アンカーポイントのサイズ :', 'Anchor Point Size:', '锚点大小：', '고정점 크기:'),
('prefsets.anchorSizeTip', 'アンカーポイント・ハンドル・バウンディングボックスの表示サイズ（4段階。anchorSizePref に 5 / 7 / 9 / 11）', 'Display size of anchor points, handles and the bounding box (four steps: anchorSizePref 5 / 7 / 9 / 11)', '锚点、手柄和定界框的显示大小（四级：anchorSizePref 为 5 / 7 / 9 / 11）', '고정점·핸들·테두리 상자의 표시 크기(4단계: anchorSizePref 5 / 7 / 9 / 11)'),
('prefsets.moveLockedArt', 'ロックまたは非表示オブジェクトを一緒に移動', 'Move Locked and Hidden Artwork', '移动锁定和隐藏的图稿', '잠긴 아트워크와 숨겨진 아트워크 이동'),
('prefsets.showArtboardName', 'アートボード名を表示', 'Show Artboard Name', '显示画板名称', '대지 이름 표시'),
('prefsets.artboardColor', 'ハイライトのカラー :', 'Highlight Color:', '高光颜色：', '강조 색상:'),
('prefsets.artboardStrokeWidth', 'ストロークの幅 :', 'Stroke Width:', '描边宽度：', '선 두께:'),
('prefsets.autoSizeAreaText', '新規エリア内文字の自動サイズ調整', 'Auto Size New Area Type', '自动调整新区域文字大小', '새 영역 문자 자동 크기 조정'),
('prefsets.recentFonts', '最近使用したフォントの表示数', 'Number of Recent Fonts', '最近使用的字体数目', '최근 사용한 글꼴 수'),
('prefsets.recentFontsTip', 'オフにすると一覧を表示しません（0として保存）。表示数は1〜30', 'Off hides the list (saved as 0). The count is 1–30.', '关闭后不显示列表（保存为 0）。数目为 1–30。', '끄면 목록을 표시하지 않습니다(0으로 저장). 표시 수는 1~30.'),
('prefsets.missingGlyphProtection', '見つからない字形の保護を有効にする', 'Enable Missing Glyph Protection', '启用缺失字形保护', '누락된 글리프 보호 활성화'),
('prefsets.alternateGlyph', '選択された文字の異体字を表示', 'Show Character Alternates', '显示字符替代字', '선택한 문자의 대체 글리프 표시'),
('prefsets.canvasColor', 'カンバスカラー :', 'Canvas Color:', '画布颜色：', '캔버스 색상:'),
('prefsets.canvasMatch', 'UIに合わせる', 'Match Brightness', '匹配用户界面亮度', 'UI에 맞추기'),
('prefsets.canvasWhite', 'ホワイト', 'White', '白色', '흰색'),
('prefsets.guideColor', 'カラー :', 'Color:', '颜色：', '색상:'),
('prefsets.guideStyle', 'スタイル :', 'Style:', '样式：', '스타일:'),
('prefsets.guideLines', 'ライン', 'Lines', '直线', '선'),
('prefsets.guideDots', '点線', 'Dots', '点线', '점선'),
('prefsets.objectHighlighting', 'オブジェクトのハイライト表示', 'Object Highlighting', '对象突出显示', '오브젝트 강조 표시'),
('prefsets.animatedZoom', 'アニメーションズーム', 'Animated Zoom', '动画缩放', '애니메이션 확대/축소'),
('prefsets.historyStates', 'ヒストリー数 :', 'History States:', '历史记录状态：', '작업 내역 수:'),
('prefsets.realTimeDrawing', 'リアルタイムの描画と編集', 'Real-Time Drawing and Editing', '实时绘制和编辑', '실시간 그리기 및 편집'),
('prefsets.editOriginalSystemDefault', '「オリジナルの編集」にシステムデフォルトを使用', 'Use System Defaults for “Edit Original”', '对“编辑原稿”使用系统默认设置', '“원본 편집”에 시스템 기본값 사용'),
('prefsets.autoActivateFonts', 'Adobe Fonts を自動アクティベート', 'Auto-activate Adobe Fonts', '自动激活 Adobe Fonts', 'Adobe Fonts 자동 활성화'),
('prefsets.saveToCloud', 'クラウドに保存', 'Save to Cloud', '存储到云', '클라우드에 저장'),
('prefsets.saveLocation', 'ファイルの保存先 :', 'Save Location:', '文件存储位置：', '파일 저장 위치:'),
('prefsets.saveComputer', 'コンピューター', 'Computer', '计算机', '컴퓨터'),
('prefsets.saveCloud', 'クラウド', 'Cloud', '云', '클라우드'),
('prefsets.updateLinks', 'リンクを更新 :', 'Update Links:', '更新链接：', '링크 업데이트:'),
('prefsets.linksAuto', '自動', 'Automatic', '自动', '자동'),
('prefsets.linksManual', '手動', 'Manual', '手动', '수동'),
('prefsets.linksAsk', '確認', 'Ask When Modified', '修改时提问', '수정 시 확인'),
('prefsets.includeSvgCode', 'SVGコードを含める', 'Include SVG Code', '包含 SVG 代码', 'SVG 코드 포함'),
('prefsets.cat.scripts', 'スクリプト', 'Scripts', '脚本', '스크립트'),
('prefsets.allowScripts', 'スクリプト実行の許可', 'Allow scripts to run', '允许运行脚本', '스크립트 실행 허용'),
('prefsets.allowScriptsTip', 'オンにすると、外部のスクリプト（.jsx）を実行する前の警告を表示しません（ShowExternalJSXWarning を false）', 'When on, no warning is shown before an external script (.jsx) runs (ShowExternalJSXWarning false)', '开启后，运行外部脚本（.jsx）前不显示警告（ShowExternalJSXWarning 为 false）', '켜면 외부 스크립트(.jsx)를 실행하기 전에 경고를 표시하지 않습니다(ShowExternalJSXWarning을 false로)'),
('prefsets.color.lightBlue', 'ライトブルー', 'Light Blue', '浅蓝色', '밝은 파랑'),
('prefsets.color.lightRed', 'サーモンピンク', 'Light Red', '浅红色', '밝은 빨강'),
('prefsets.color.green', 'グリーン', 'Green', '绿色', '초록'),
('prefsets.color.mediumBlue', 'ミディアムブルー', 'Medium Blue', '中蓝色', '중간 파랑'),
('prefsets.color.magenta', 'マゼンタ', 'Magenta', '洋红色', '마젠타'),
('prefsets.color.cyan', 'シアン', 'Cyan', '青色', '사이안'),
('prefsets.color.white', 'ホワイト', 'White', '白色', '흰색'),
('prefsets.color.lightGray', 'ライトグレー', 'Light Gray', '浅灰色', '밝은 회색'),
('prefsets.color.black', 'ブラック', 'Black', '黑色', '검정'),
('prefsets.color.yellow', 'イエロー', 'Yellow', '黄色', '노랑'),
('palette.gridMatchTop', 'グリッド：上側の色', 'Grid: upper color', '网格：上方颜色', '격자: 위쪽 색'),
('palette.gridColor', 'グリッド：#%@', 'Grid: #%@', '网格：#%@', '격자: #%@'),
('quick.title', 'クイック環境設定', 'Quick Preferences', '快速偏好设置', '빠른 환경설정'),
('quick.menu', 'クイック環境設定を表示', 'Show Quick Preferences', '显示快速偏好设置', '빠른 환경설정 보기'),
('quick.keyInput', 'キー入力', 'Keyboard Increment', '键盘增量', '키보드 증감'),
('quick.keyInputTip', '矢印キーでの移動量（環境設定 > 一般 > キー入力）。∧∨・↑↓で次の整数へ、shift＋で10の倍数へ、option＋で0.1ずつ', 'How far an arrow key moves (Settings > General > Keyboard Increment). ∧∨ / ↑↓ go to the next whole number, with Shift to multiples of 10, with Option by 0.1', '方向键的移动量（设置 > 常规 > 键盘增量）。∧∨・↑↓ 到下一个整数，shift 到 10 的倍数，option 每次 0.1', '화살표 키 이동량(설정 > 일반 > 키보드 증감). ∧∨·↑↓로 다음 정수, shift는 10의 배수, option은 0.1씩'),
('quick.stepTip', '値を増やす／減らす（shift＋クリックで10の倍数へ、option＋クリックで0.1ずつ）', 'Increase / decrease (Shift-click to multiples of 10, Option-click by 0.1)', '增加／减少（shift 点按到 10 的倍数，option 点按每次 0.1）', '늘리기/줄이기(shift 클릭은 10의 배수, option 클릭은 0.1씩)'),
('quick.unitTip', '定規の単位を切り替え（環境設定の［単位］を開いて一般を変えます）', 'Switch the ruler unit (opens the Units pane of Settings and changes General)', '切换标尺单位（打开设置的“单位”更改常规）', '눈금자 단위 전환(설정의 단위를 열어 일반을 바꿉니다)'),
('quick.unitDone', '定規の単位：%@', 'Ruler unit: %@', '标尺单位：%@', '눈금자 단위: %@'),
('quick.align', '整列オプション', 'Align Options', '对齐选项', '정렬 옵션'),
('quick.transform', '変形オプション', 'Transform Options', '变换选项', '변형 옵션'),
('quick.copyPaste', 'コピー/ペースト', 'Copy / Paste', '拷贝/粘贴', '복사/붙여넣기'),
('quick.drawing', '描画', 'Drawing', '绘图', '그리기'),
('quick.previewBounds', 'プレビュー境界を使用', 'Use Preview Bounds', '使用预览边界', '미리 보기 경계 사용'),
('quick.previewBoundsTip', '整列・分布でプレビュー境界（線幅・効果を含む）を使用', 'Use preview bounds (incl. stroke & effects) for align/distribute', '对齐/分布时使用预览边界（含描边和效果）', '정렬·분포에 미리 보기 경계(선·효과 포함) 사용'),
('quick.glyphBounds', '字形の境界に整列', 'Align to Glyph Bounds', '对齐字形边界', '글리프 경계에 정렬'),
('quick.glyphBoundsTip', 'ポイント文字・エリア内文字を字形の境界で整列', 'Align point & area type to glyph bounds', '点文字和区域文字按字形边界对齐', '포인트·영역 문자를 글리프 경계로 정렬'),
('quick.transformPatterns', 'パターン', 'Pattern Tiles', '图案', '패턴'),
('quick.transformPatternsTip', '変形時にパターンも変形する（option＋クリックで変形オプションをまとめて切り替え）', 'Transform pattern tiles when transforming (Option-click switches all transform options)', '变换时同时变换图案（option 点按一起切换变换选项）', '변형할 때 패턴도 변형(option 클릭으로 변형 옵션을 함께 전환)'),
('quick.scaleCorners', '角', 'Corners', '圆角', '모퉁이'),
('quick.scaleCornersTip', '拡大・縮小時に角（ライブコーナー）の半径も拡大・縮小（option＋クリックで変形オプションをまとめて切り替え）', 'Scale corner radius when scaling (Option-click switches all transform options)', '缩放时同时缩放圆角半径（option 点按一起切换变换选项）', '크기 조정 시 모퉁이 반경도 조정(option 클릭으로 변형 옵션을 함께 전환)'),
('quick.scaleStroke', '線幅と効果', 'Strokes & Effects', '描边和效果', '선과 효과'),
('quick.scaleStrokeTip', '拡大・縮小時に線幅と効果も拡大・縮小（option＋クリックで変形オプションをまとめて切り替え）', 'Scale strokes & effects when scaling (Option-click switches all transform options)', '缩放时同时缩放描边和效果（option 点按一起切换变换选项）', '크기 조정 시 선과 효과도 조정(option 클릭으로 변형 옵션을 함께 전환)'),
('quick.pastePlain', '書式なしペースト', 'Paste without Formatting', '无格式粘贴', '서식 없이 붙여넣기'),
('quick.pastePlainTip', '書式を保持せずにペースト', 'Paste without keeping formatting', '粘贴时不保留格式', '서식을 유지하지 않고 붙여넣기'),
('quick.pastePreserve', 'コピー元のレイヤーにペースト', 'Paste Remembers Layers', '粘贴时记住图层', '레이어 기억하여 붙여넣기'),
('quick.pastePreserveTip', 'コピー元と同じレイヤーにペースト', 'Paste into the original (source) layer', '粘贴到原图层', '원래 레이어에 붙여넣기'),
('quick.realtimeDrawing', 'リアルタイムの描画と編集', 'Real-time Drawing & Editing', '实时绘图和编辑', '실시간 그리기 및 편집'),
('quick.realtimeDrawingTip', 'リアルタイムの描画と編集を切り替え', 'Toggle real-time drawing & editing', '切换实时绘图和编辑', '실시간 그리기 및 편집 전환'),
('quick.refresh', 'プレビュー更新', 'Refresh Preview', '刷新预览', '미리 보기 새로 고침'),
('quick.refreshTip', 'GPUプレビューを更新（再描画）', 'Refresh the GPU preview (redraw)', '刷新 GPU 预览（重绘）', 'GPU 미리 보기 새로 고침(다시 그리기)'),
('hotkey.quick', 'クイック環境設定を表示／隠す', 'Show or hide Quick Preferences', '显示或隐藏快速偏好设置', '빠른 환경설정 보기/숨기기'),
('hotkey.quickHint', '初期値は ⌃⌥⌘Q。Illustratorが前面のときだけ使えます。', 'Default ⌃⌥⌘Q. Works only while Illustrator is in front.', '默认 ⌃⌥⌘Q。仅在 Illustrator 位于前台时可用。', '기본값 ⌃⌥⌘Q. Illustrator가 앞에 있을 때만 작동합니다.'),
('transform.title', 'クイック変形', 'Quick Transform', '快速变换', '빠른 변형'),
('transform.menu', 'クイック変形を表示', 'Show Quick Transform', '显示快速变换', '빠른 변형 보기'),
('transform.flip', '反転・回転', 'Flip / Rotate', '翻转・旋转', '반전·회전'),
('transform.move', '移動・複製', 'Move / Duplicate', '移动・复制', '이동·복제'),
('transform.options', 'オプション', 'Options', '选项', '옵션'),
('transform.up', '上', 'Up', '上', '위'),
('transform.down', '下', 'Down', '下', '아래'),
('transform.left', '左', 'Left', '左', '왼쪽'),
('transform.right', '右', 'Right', '右', '오른쪽'),
('transform.margin', 'マージン :', 'Margin:', '边距：', '여백:'),
('transform.marginTip', '移動・複製の間隔と、反転・回転のあとに基準点の側へずらす量（定規の単位。マイナスで重なる向き）', 'Gap for move / duplicate, and the shift toward the anchor side after flip / rotate (ruler units; negative overlaps)', '移动/复制的间距，以及翻转/旋转后向参考点一侧移动的量（标尺单位，负值为重叠方向）', '이동·복제 간격과 반전·회전 후 기준점 쪽으로 옮기는 양(눈금자 단위, 음수는 겹치는 방향)'),
('transform.previewBounds', 'プレビュー境界', 'Preview bounds', '预览边界', '미리 보기 경계'),
('transform.previewBoundsTip', '線幅・効果を含む境界で大きさと基準点を測る', 'Measure the size and anchor point with the bounds including strokes and effects', '用包含描边和效果的边界测量大小和参考点', '선과 효과를 포함한 경계로 크기와 기준점을 측정'),
('transform.flipHTip', '選択を水平方向に反転（基準点が基点）／ Option＋クリックで複製', 'Flip the selection horizontally (about the anchor point) / Option-click to duplicate', '水平翻转所选对象（以参考点为基点）／ Option 点按复制', '선택을 가로로 반전(기준점 기준) / Option 클릭으로 복제'),
('transform.flipVTip', '選択を垂直方向に反転（基準点が基点）／ Option＋クリックで複製', 'Flip the selection vertically (about the anchor point) / Option-click to duplicate', '垂直翻转所选对象（以参考点为基点）／ Option 点按复制', '선택을 세로로 반전(기준점 기준) / Option 클릭으로 복제'),
('transform.rotateCCWTip', '選択を反時計回りに90°回転（基準点が基点）／ Option＋クリックで複製', 'Rotate the selection 90° counterclockwise (about the anchor point) / Option-click to duplicate', '将所选对象逆时针旋转 90°（以参考点为基点）／ Option 点按复制', '선택을 시계 반대 방향으로 90° 회전(기준점 기준) / Option 클릭으로 복제'),
('transform.rotateCWTip', '選択を時計回りに90°回転（基準点が基点）／ Option＋クリックで複製', 'Rotate the selection 90° clockwise (about the anchor point) / Option-click to duplicate', '将所选对象顺时针旋转 90°（以参考点为基点）／ Option 点按复制', '선택을 시계 방향으로 90° 회전(기준점 기준) / Option 클릭으로 복제'),
('transform.anchorTip', '基準点（反転・回転の基点）', 'Anchor point (pivot for flip / rotate)', '参考点（翻转/旋转的基点）', '기준점(반전·회전의 기준)'),
('transform.moveTip', 'クリックで移動／ Option＋クリックで複製', 'Click to move / Option-click to duplicate', '点按移动／ Option 点按复制', '클릭으로 이동 / Option 클릭으로 복제'),
('transform.duplicateTip', '複製', 'Duplicate', '复制', '복제'),
('transform.sliderTip', 'スライダーで回転（-180〜180°・15°刻み／Shift＝90°刻み、正＝反時計回り、基準点が基点）', 'Rotate with the slider (-180 to 180°, 15° steps / Shift = 90° steps, positive = CCW, about the anchor point)', '用滑块旋转（-180〜180°，15° 步进／Shift＝90° 步进，正值＝逆时针，以参考点为基点）', '슬라이더로 회전(-180~180°, 15° 단위 / Shift = 90° 단위, 양수 = 시계 반대 방향, 기준점 기준)'),
('transform.noSelection', 'オブジェクトを選択してください。', 'Select an object.', '请选择对象。', '오브젝트를 선택하세요.'),
('transform.noBounds', '選択したオブジェクトの大きさを測れません（ロック・非表示など）。', 'The size of the selection cannot be measured (locked, hidden, etc.).', '无法测量所选对象的大小（已锁定、隐藏等）。', '선택한 오브젝트의 크기를 측정할 수 없습니다(잠금, 숨김 등).'),
('hotkey.transform', 'クイック変形を表示／隠す', 'Show or hide Quick Transform', '显示或隐藏快速变换', '빠른 변형 보기/숨기기'),
('hotkey.transformHint', '初期値は ⌃⌥⌘T。Illustratorが前面のときだけ使えます。', 'Default ⌃⌥⌘T. Works only while Illustrator is in front.', '默认 ⌃⌥⌘T。仅在 Illustrator 位于前台时可用。', '기본값 ⌃⌥⌘T. Illustrator가 앞에 있을 때만 작동합니다.'),
('closeAll.title', 'パレット', 'Palettes', '面板', '팔레트'),
('hotkey.closeAll', 'すべてのパレットを閉じる', 'Close all palettes', '关闭所有面板', '모든 팔레트 닫기'),
('hotkey.closeAllHint', '単位パレット・クイック環境設定・クイック変形を閉じます。初期値は ⌥W。Illustratorが前面のときだけ使えます。', 'Closes the Units Palette, Quick Preferences and Quick Transform. Default ⌥W. Works only while Illustrator is in front.', '关闭单位面板、快速偏好设置和快速变换。默认 ⌥W。仅在 Illustrator 位于前台时可用。', '단위 팔레트·빠른 환경설정·빠른 변형을 닫습니다. 기본값 ⌥W. Illustrator가 앞에 있을 때만 작동합니다.'),
('on', 'オン', 'On', '开', '켬'),
('off', 'オフ', 'Off', '关', '끔'),
('cancel', 'キャンセル', 'Cancel', '取消', '취소'),
('version.tab', '関連付け', 'Associations', '关联', '연결'),
('version.title', 'ファイルを開くIllustratorのバージョン', 'Illustrator Version for Opening Files', '打开文件的 Illustrator 版本', '파일을 여는 Illustrator 버전'),
('version.detail', '複数の版のIllustratorがインストールされているとき、チェックした拡張子をまとめて指定の版のIllustratorで開くようにします（ほかのアプリに関連付けられていた拡張子もIllustratorに変わります）。', 'When several versions of Illustrator are installed, opens the checked extensions in the chosen version of Illustrator (extensions associated with another app are switched to Illustrator too).', '安装了多个版本的 Illustrator 时，让勾选的扩展名都用指定版本的 Illustrator 打开（原本关联其他应用的扩展名也会改为 Illustrator）。', 'Illustrator가 여러 버전 설치되어 있을 때 체크한 확장자를 모두 지정한 버전의 Illustrator로 엽니다(다른 앱에 연결된 확장자도 Illustrator로 바뀝니다).'),
('version.none', '複数の版のIllustratorは見つかりません。', 'Only one version of Illustrator was found.', '未找到多个版本的 Illustrator。', 'Illustrator가 여러 버전 설치되어 있지 않습니다.'),
('version.open', '開く版 :', 'Open with:', '打开版本：', '열 버전:'),
('version.newest', '最新版（自動）', 'Newest (automatic)', '最新版本（自动）', '최신 버전(자동)'),
('version.apply', '切り替える', 'Switch', '切换', '전환'),
('version.applying', '切り替え中...', 'Switching...', '正在切换...', '전환 중...'),
('version.done', '%ld種類の拡張子を切り替えました。', 'Switched %ld extension(s).', '已切换 %ld 种扩展名。', '확장자 %ld개를 전환했습니다.'),
('version.hint', '最新版（自動）は、インストールされている版のうち最も新しい版で開きます。Finderの［情報を見る］などでアプリを選び直すと、その拡張子は最新版（自動）に戻ります。', 'Newest (automatic) opens files in the newest installed version. Choosing the app again elsewhere (e.g. Get Info in the Finder) resets that extension to Newest.', '“最新版本（自动）”会用已安装的最新版本打开。在访达的“显示简介”等处重新选择应用后，该扩展名会恢复为“最新版本（自动）”。', '최신 버전(자동)은 설치된 버전 중 가장 새로운 버전으로 엽니다. Finder의 정보 가져오기 등에서 앱을 다시 선택하면 그 확장자는 최신 버전(자동)으로 돌아갑니다.'),
('version.confirmTitle', '拡張子を開く版を切り替えますか？', 'Switch the version that opens these extensions?', '要切换打开这些扩展名的版本吗？', '이 확장자를 여는 버전을 전환할까요?'),
('version.confirmMessage', '対象 : %@\n\nmacOSの関連付けの記録に版を書き込み、関連付けを管理するシステムの処理（lsd）を再起動します。変更前の記録は ~/Library/Application Support/VectorMate に保存します。', 'Extensions: %@\n\nThe version is written into macOS’s file association record and the system process that manages it (lsd) is restarted. The previous record is kept in ~/Library/Application Support/VectorMate.', '对象：%@\n\n会将版本写入 macOS 的文件关联记录，并重新启动管理关联的系统进程（lsd）。更改前的记录保存在 ~/Library/Application Support/VectorMate。', '대상: %@\n\nmacOS의 파일 연결 기록에 버전을 쓰고, 연결을 관리하는 시스템 프로세스(lsd)를 다시 시작합니다. 변경 전 기록은 ~/Library/Application Support/VectorMate에 저장합니다.'),
('version.failTitle', '版を切り替えられません', 'Could not switch the version', '无法切换版本', '버전을 전환할 수 없습니다'),
('version.failConfirm', '版の切り替えを確認できなかったため、元に戻しました。', 'The switch could not be confirmed, so it was undone.', '无法确认版本切换，已恢复原状。', '전환을 확인하지 못해 원래대로 되돌렸습니다.'),
('version.failRead', '関連付けの記録を読み込めませんでした。', 'The file association record could not be read.', '无法读取文件关联记录。', '파일 연결 기록을 읽을 수 없습니다.'),
('version.failPending', 'macOSが関連付けの変更をまだ保存していません。数分待ってからもう一度実行してください。', 'macOS has not saved a recent association change yet. Wait a few minutes and try again.', 'macOS 尚未保存最近的关联更改。请等待几分钟后重试。', 'macOS가 최근 연결 변경을 아직 저장하지 않았습니다. 몇 분 후 다시 시도하세요.'),
('reload', '再読み込み', 'Reload', '重新载入', '새로 고침'),
('listSeparator', '・', ', ', '、', ', '),
('fail.automation', 'Illustratorを操作する許可がありません。システム設定の［プライバシーとセキュリティ］→［オートメーション］でVectorMateの「Adobe Illustrator」をオンにしてください。', 'Not allowed to control Illustrator. Turn on Adobe Illustrator for VectorMate in System Settings → Privacy & Security → Automation.', '没有控制 Illustrator 的权限。请在系统设置的“隐私与安全性 → 自动化”中为 VectorMate 打开“Adobe Illustrator”。', 'Illustrator 제어 권한이 없습니다. 시스템 설정의 개인정보 보호 및 보안 → 자동화에서 VectorMate의 Adobe Illustrator를 켜세요.'),
('fail.script', 'Illustratorから結果を受け取れませんでした：%@', 'No result from Illustrator: %@', '未能从 Illustrator 获得结果：%@', 'Illustrator에서 결과를 받지 못했습니다: %@'),
('openAutomation', 'オートメーション設定を開く', 'Open Automation Settings', '打开自动化设置', '자동화 설정 열기'),
('keepRunning', 'ウインドウを閉じても常駐', 'Keep running after closing the window', '关闭窗口后继续运行', '윈도우를 닫아도 계속 실행'),
('tab.other', 'その他', 'Other', '其他', '기타'),
('reset.title', 'Illustratorの設定を初期化', 'Reset Illustrator Settings', '初始化 Illustrator 设置', 'Illustrator 설정 초기화'),
('reset.button', '初期化…', 'Reset…', '初始化…', '초기화…'),
('reset.run', '終了して初期化', 'Quit and Reset', '退出并初始化', '종료 후 초기화'),
('reset.includeCache', 'キャッシュも削除', 'Also delete the cache', '同时删除缓存', '캐시도 삭제'),
('reset.needsRunning', 'Illustratorを起動しているときに使えます（その版が対象です）', 'Available while Illustrator is running (its version is reset)', 'Illustrator 运行时可用（针对该版本）', 'Illustrator가 실행 중일 때 쓸 수 있습니다(그 버전이 대상입니다)'),
('reset.confirm', 'Illustratorを終了して、設定をゴミ箱に入れますか？', 'Quit Illustrator and move its settings to the Trash?', '要退出 Illustrator 并将其设置移到废纸篓吗？', 'Illustrator를 종료하고 설정을 휴지통으로 옮길까요?'),
('reset.confirmCache', 'Illustratorを終了して、設定とキャッシュをゴミ箱に入れますか？', 'Quit Illustrator and move its settings and cache to the Trash?', '要退出 Illustrator 并将其设置和缓存移到废纸篓吗？', 'Illustrator를 종료하고 설정과 캐시를 휴지통으로 옮길까요?'),
('reset.confirmDetail', '保存していないドキュメントがあれば、Illustratorが保存を確認します。終了しなければ何も消しません。', 'Illustrator asks about unsaved documents. If it does not quit, nothing is moved.', '如有未存储的文档，Illustrator 会询问是否存储。若未退出，则不会移动任何内容。', '저장하지 않은 도큐먼트가 있으면 Illustrator가 저장 여부를 묻습니다. 종료하지 않으면 아무것도 옮기지 않습니다.'),
('reset.done', '%d 件をゴミ箱に入れ、Illustratorを起動しました', 'Moved %d items to the Trash and launched Illustrator', '已将 %d 项移到废纸篓并启动了 Illustrator', '%d개를 휴지통으로 옮기고 Illustrator를 시작했습니다'),
('reset.doneNotLaunched', '%d 件をゴミ箱に入れました（Illustratorを起動できませんでした）', 'Moved %d items to the Trash (Illustrator could not be launched)', '已将 %d 项移到废纸篓（未能启动 Illustrator）', '%d개를 휴지통으로 옮겼습니다(Illustrator를 시작하지 못했습니다)'),
('reset.notQuit', 'Illustratorが終了しなかったので、何も消していません', 'Illustrator did not quit, so nothing was moved', 'Illustrator 未退出，因此未移动任何内容', 'Illustrator가 종료되지 않아 아무것도 옮기지 않았습니다'),
('reset.noVersion', '起動中のIllustratorの版を読めませんでした', 'The version of the running Illustrator could not be read', '无法读取正在运行的 Illustrator 的版本', '실행 중인 Illustrator의 버전을 읽지 못했습니다'),
('reset.trashFailed', '%@ をゴミ箱に入れられませんでした：%@', '%@ could not be moved to the Trash: %@', '无法将 %@ 移到废纸篓：%@', '%@을(를) 휴지통으로 옮기지 못했습니다: %@'),
('tab.custom', '同期', 'Sync', '同步', '동기화'),
('sync.title', '同期フォルダー', 'Synced Folder', '同步文件夹', '동기화 폴더'),
('sync.all', 'まとめて同期', 'Sync All', '全部同步', '모두 동기화'),
('kbsc.title', 'キーボードショートカット', 'Keyboard Shortcuts', '键盘快捷键', '키보드 단축키'),
('kbsc.source', '読み込み元 :', 'Source:', '来源：', '불러올 파일:'),
('kbsc.choose', '選択…', 'Choose…', '选择…', '선택…'),
('kbsc.install', 'リンクして選ぶ', 'Link and Choose', '链接并选择', '링크 후 선택'),
('kbsc.noSource', '読み込み元のフォルダーが見つかりません：%@', 'The source folder was not found: %@', '找不到来源文件夹：%@', '불러올 폴더를 찾을 수 없습니다: %@'),
('kbsc.noFolder', 'Illustratorの設定フォルダー（Adobe Illustrator <版> Settings/ja_JP）が見つかりません', 'The Illustrator settings folder (Adobe Illustrator <version> Settings/ja_JP) was not found', '找不到 Illustrator 设置文件夹（Adobe Illustrator <版本> Settings/ja_JP）', 'Illustrator 설정 폴더(Adobe Illustrator <버전> Settings/ja_JP)를 찾을 수 없습니다'),
('kbsc.chosen', 'キーボードショートカットを「%@」にしました', 'Keyboard shortcuts set to “%@”', '已将键盘快捷键设为“%@”', '키보드 단축키를 “%@”(으)로 바꿨습니다'),
('kbsc.already', 'キーボードショートカットはすでに「%@」です', 'Keyboard shortcuts are already “%@”', '键盘快捷键已是“%@”', '키보드 단축키가 이미 “%@”입니다'),
('kbsc.restart', 'Illustratorを再起動してからもう一度［リンクして選ぶ］を押すと、「%@」を選びます', 'Restart Illustrator and click Link and Choose again to choose “%@”', '重新启动 Illustrator 后再次点按“链接并选择”即可选择“%@”', 'Illustrator를 다시 시작한 뒤 링크 후 선택을 한 번 더 누르면 “%@”을(를) 고릅니다'),
('kbsc.notRunning', 'Illustratorを起動してからもう一度［リンクして選ぶ］を押すと、「%@」を選びます', 'Launch Illustrator and click Link and Choose again to choose “%@”', '启动 Illustrator 后再次点按“链接并选择”即可选择“%@”', 'Illustrator를 시작한 뒤 링크 후 선택을 한 번 더 누르면 “%@”을(를) 고릅니다'),
('kbsc.linked', '%d 件の .kys をリンクしました。', 'Linked %d .kys files. ', '已链接 %d 个 .kys。', '.kys %d개를 링크했습니다. '),
('kbsc.set', '使用するセット :', 'Set to Use:', '使用的组合：', '사용할 세트:'),
('kbsc.noSets', '読み込み元のフォルダーに .kys がありません', 'No .kys in the source folder', '来源文件夹中没有 .kys', '불러올 폴더에 .kys가 없습니다'),
('kbsc.noKys', '読み込み元のフォルダーに .kys がありません：%@', 'No .kys in the source folder: %@', '来源文件夹中没有 .kys：%@', '불러올 폴더에 .kys가 없습니다: %@'),
('links.title.profiles', 'ドキュメントプロファイル', 'Document Profiles', '文档配置文件', '도큐먼트 프로필'),
('links.title.compositeFonts', '合成フォント', 'Composite Fonts', '复合字体', '합성 글꼴'),
('links.link', 'リンクを作成', 'Create Links', '创建链接', '링크 만들기'),
('links.noSource', '読み込み元のフォルダーが見つかりません：%@', 'The source folder was not found: %@', '找不到来源文件夹：%@', '불러올 폴더를 찾을 수 없습니다: %@'),
('links.noFolder', 'Illustratorのフォルダー（Application Support/Adobe/Adobe Illustrator <版>/ja_JP）が見つかりません', 'The Illustrator folder (Application Support/Adobe/Adobe Illustrator <version>/ja_JP) was not found', '找不到 Illustrator 文件夹（Application Support/Adobe/Adobe Illustrator <版本>/ja_JP）', 'Illustrator 폴더(Application Support/Adobe/Adobe Illustrator <버전>/ja_JP)를 찾을 수 없습니다'),
('links.done', '%d 件をリンクしました（新規 %d・張り替え %d・リンク済み %d）', 'Linked %d files (%d new, %d replaced, %d already linked)', '已链接 %d 个文件（新建 %d、替换 %d、已链接 %d）', '%d개를 링크했습니다(새로 %d, 교체 %d, 이미 링크됨 %d)'),
('links.moved', '。元のファイル %d 件を %@ に移しました', '. %d files that were there were moved to %@', '。原有的 %d 个文件已移到 %@', '. 원래 파일 %d개를 %@(으)로 옮겼습니다'),
('links.sameFolder', '読み込み元がIllustratorのフォルダーそのもの（またはその中を指すリンク）なので、リンクしません：%@', 'The source is Illustrator’s folder itself (or links into it), so nothing is linked: %@', '来源就是 Illustrator 的文件夹本身（或指向其中的链接），因此不创建链接：%@', '불러올 위치가 Illustrator 폴더 자체(또는 그 안을 가리키는 링크)이므로 링크하지 않습니다: %@'),
('links.noFiles', '読み込み元のフォルダーにファイルがありません：%@', 'No files in the source folder: %@', '来源文件夹中没有文件：%@', '불러올 폴더에 파일이 없습니다: %@'),
('other.title', 'ガイド', 'Guides', '参考线', '안내선'),
('other.guide', 'トリミング表示でもガイドを表示する', 'Show guides in Trim View too', '在剪切视图中也显示参考线', '트리밍 보기에서도 안내선 표시'),
('other.guideDetail', 'Illustratorが前面のとき、⌘; で［表示］→［ガイド］の表示・非表示を切り替えます（メニューコマンド showguide）。', 'While Illustrator is in front, ⌘; shows or hides the guides (menu command showguide).', 'Illustrator 位于前台时，⌘; 显示或隐藏参考线（菜单命令 showguide）。', 'Illustrator가 앞에 있을 때 ⌘;로 안내선을 보이거나 숨깁니다(메뉴 명령 showguide).'),
('launch.hotkey', 'アプリ起動のホットキー', 'App launch hotkey', '启动应用快捷键', '앱 실행 단축키'),
('launch.hotkeyHint', '初期値は ⌃⌥⌘;。常駐中なら、どのアプリが前面でもメインウインドウを開きます。', 'Default ⌃⌥⌘;. While the app keeps running, it opens the main window from any app.', '默认 ⌃⌥⌘;。应用常驻时，无论哪个应用在前台都会打开主窗口。', '기본값 ⌃⌥⌘;. 앱이 실행 중이면 어느 앱이 앞에 있어도 메인 윈도우를 엽니다.'),
('keepRunningHint', 'プロポーショナルメトリクスの見張りを続けるには常駐が必要です。オフにすると、メインウインドウを閉じたときに終了します。', 'Watching for Metrics needs the app to keep running. When off, closing the main window quits the app.', '持续监视需要应用保持运行。关闭此项后，关闭主窗口即退出。', '감시를 계속하려면 앱이 실행 중이어야 합니다. 끄면 메인 윈도우를 닫을 때 종료합니다.'),
('settingsButton', '設定…', 'Settings…', '设置…', '설정…'),
('settings', '設定…', 'Settings…', '设置…', '설정…'),
('settingsTitle', '設定', 'Settings', '设置', '설정'),
('about', 'VectorMateについて', 'About VectorMate', '关于 VectorMate', 'VectorMate에 관하여'),
('services', 'サービス', 'Services', '服务', '서비스'),
('hideApp', 'VectorMateを隠す', 'Hide VectorMate', '隐藏 VectorMate', 'VectorMate 가리기'),
('hideOthers', 'ほかを隠す', 'Hide Others', '隐藏其他', '기타 가리기'),
('showAll', 'すべてを表示', 'Show All', '全部显示', '모두 보기'),
('quit', 'VectorMateを終了', 'Quit VectorMate', '退出 VectorMate', 'VectorMate 종료'),
('file', 'ファイル', 'File', '文件', '파일'),
('openMainWindow', 'メインウインドウを開く', 'Open Main Window', '打开主窗口', '메인 윈도우 열기'),
('close', 'ウインドウを閉じる', 'Close Window', '关闭窗口', '윈도우 닫기'),
('edit', '編集', 'Edit', '编辑', '편집'),
('undo', '取り消す', 'Undo', '撤销', '실행 취소'),
('redo', 'やり直す', 'Redo', '重做', '실행 복귀'),
('cut', 'カット', 'Cut', '剪切', '오려두기'),
('copy', 'コピー', 'Copy', '拷贝', '복사하기'),
('paste', 'ペースト', 'Paste', '粘贴', '붙여넣기'),
('selectAll', 'すべてを選択', 'Select All', '全选', '모두 선택'),
('window', 'ウインドウ', 'Window', '窗口', '윈도우'),
('minimize', 'しまう', 'Minimize', '最小化', '최소화'),
('zoom', '拡大／縮小', 'Zoom', '缩放', '확대/축소'),
('bringAllToFront', 'すべてを手前に移動', 'Bring All to Front', '前置全部窗口', '모두 앞으로 가져오기'),
('help', 'ヘルプ', 'Help', '帮助', '도움말'),
('helpItem', 'VectorMateヘルプ', 'VectorMate Help', 'VectorMate 帮助', 'VectorMate 도움말'),
('support', 'サポート：同梱のREADME.md', 'Support: see the bundled README.md', '支持：请参阅随附的 README.md', '지원: 함께 제공된 README.md 참조'),
]
helptexts = [
'''VectorMate — Illustratorの作業を補助

メトリクスとプロポーショナルメトリクス
選択中のテキストの自動カーニングを「メトリクス」以外から「メトリクス」に変えると、OpenTypeの「プロポーショナルメトリクス」をONにします（初期値はオン）。
- 確認するのは、Illustratorでクリックしたあと、Return・Enter・Tab・⌘キーを押したあと、Illustratorが前面に来たときです。ほかのアプリが前面のときは何もしません。
- 「メトリクス」から別の方式に変えたときはOFFにします（メインウインドウでオフにできます。初期値はオン）。
- 選択を変えずにカーニングを変えたときだけ対象です。その後で手動で切り替えた場合は戻しません。
- 対象は選択中のテキストオブジェクト（最大200個）と、文字ツールで選択中の文字です。
- ONにした操作はIllustratorの取り消し（⌘Z）で戻せます。
- メニューバーのアイコンの「一時停止」で一時的に止められます。

バックグラウンド（環境設定タブ）
Illustratorの［設定］→［ファイル管理］の「バックグラウンドで書き出し」「バックグラウンドで保存」「復帰データを次の間隔で自動保存」をチェックボックスで切り替えます。状態はIllustratorの設定ファイル（Adobe Illustrator Cloud Prefs と環境設定）から読みます。Illustratorで変えた分は終了時に書き込まれるまで反映されないことがあるため、「確認」で環境設定のダイアログボックスを開いて読み、［キャンセル］で閉じることもできます。チェックを切り替えるとダイアログボックスを開いて同じ項目を変え、［OK］で閉じます。メニューバー・ファイルメニューの「バックグラウンド保存・書き出しをオフ」は2つをまとめてオフにします。操作中はキーボードやマウスに触れないでください。Illustratorが起動していないときは起動しません。

基本UI（タブ）
明るさ：Illustratorの［設定］→［ユーザーインターフェイス］の明るさ（暗・やや暗め・やや明るめ・明）をラジオボタンで選びます。Illustratorが前面のときは ⇧F2 で1段明るく、⇧F1 で1段暗くします（「ホットキーを設定…」から設定の「ホットキー」タブを開いて変更・解除できます。ほかのアプリではキーを横取りしません）。変えるたびに環境設定のダイアログボックスを開いてボタンを押し、［OK］で閉じます。続けて押した分はまとめて反映します。
表示：ツールバー（詳細）・コンテキストタスクバー・コントロールバー・ヘルプバー・アプリケーションバー・アプリケーションフレーム・グリフにスナップを、Illustratorのメニューの ✓ で読み、メニューを選んで切り替えます。
クラシック表示：ツールバー：詳細、コンテキストタスクバー：OFF、コントロールバー：ON、グリフにスナップ：OFF、ヘルプバー：OFF、アプリケーションバー：OFF、アプリケーションフレーム：OFF にまとめて揃えます。ツールバーの2段表示はスクリプトから切り替えられないため、ツールバー上端の «» で切り替えてください。

クイック環境設定
「クイック環境設定を表示」（メニューバー・ファイルメニュー・メインウインドウのボタン、または設定で割り当てたホットキー）で開く、前面に浮くパレットです（AiQuickPrefsPalette と同じ項目）。キー入力（∧∨・↑↓で次の整数へ、shift＋で10の倍数へ、option＋で0.1ずつ）と定規の単位、整列オプション（プレビュー境界・字形の境界）、変形オプション（パターン・角・線幅と効果。option＋クリックでまとめて切り替え）、コピー/ペースト（書式なしペースト・コピー元のレイヤーにペースト）、描画（リアルタイムの描画と編集・プレビュー更新）を切り替えます。定規の単位だけは環境設定の［単位］を開いて変えます。パレットが前面に来るたびに今の値を読み直します。

クイック変形
「クイック変形を表示」（メニューバー・ファイルメニュー・メインウインドウのボタン、または ⌃⌥⌘T。設定で変更可）で開く、前面に浮くパレットです（ai-scripts の QuickTransformPalette と同じ操作）。開いてもIllustratorは前面のままです。
- 反転・回転：水平・垂直に反転、90°ずつ回転します。基点は右の基準点（9か所）で選びます。スライダーは15°刻み（Shift＝90°刻み）で、離すと0に戻ります（オブジェクトは回ったまま）。
- 移動・複製：矢印で、選択全体の幅または高さ＋マージンだけ移動します。中央は同じ位置に複製します。
- Option＋クリックで、複製してから移動・反転・回転します（複製したものが選択されます）。
- マージンは定規の単位で、マイナスなら重なる向きです。反転・回転では基準点の側へずらします。プレビュー境界がオンなら線幅・効果を含めて測ります。
- 1回の操作はIllustratorの取り消し1段分です（スライダーは刻みごと）。

単位パレット
「単位パレットを表示」（メニューバー・ファイルメニュー・メインウインドウの「単位パレット」ボタン、または設定で割り当てたホットキー）で開く、前面に浮くパレットです。単位セット（初期値はプリント（pt）・プリント（級）・ウェブ・プレゼン）を一覧から選び、⌘Return・⌘クリック・ダブルクリックで切り替えます（Tab・↑↓で選択、Escで隠す。今の単位と同じセットは「— 現在」）。「基本」「詳細」のどちらでも単位と増減量（キー入力・角丸の半径・サイズ/行送り・ベースラインシフト）を変えます。「詳細」ではさらに、開いているドキュメントのカラーモード・オーバープリントプレビュー・ラスタライズ効果の解像度・透明グリッドの色と、ピクセルにスナップも変えます（透明グリッドの色は SetSameGridColors と同じく、［ドキュメント設定］の色見本をクリックしてカラーパネルの16進数欄に書きます。マウスポインタが動きます）。セットは「セットを編集…」または設定の「単位セット」タブで追加・削除・並べ替え・編集できます。単位はスクリプトから書いても再起動まで効かないため、環境設定の［単位］を開いて各ポップアップを矢印キーで目的の単位にし、4つとも合っているときだけ［OK］を押します（合わなければ［キャンセル］）。操作のあと単位を読み直して確かめます。操作中はキーボードやマウスに触れないでください。

ツール（タブ）
［シェイプ形成ツールオプション］の「次のカラーを利用」を「スウォッチ」「オブジェクト」のラジオボタンで切り替えます。シェイプ形成ツールを選んでツールオプションを開き、一覧から選んで［OK］を押します（ドキュメントを開いておいてください。ツールはシェイプ形成ツールに切り替わります）。操作中はキーボードやマウスに触れないでください。
「修飾キーのダブルタップで選択ツールに切り替える」をオンにすると、Illustratorが前面のとき、選んだキー（control・option・command・shift。初期値は control）だけを2回続けて軽く押すと選択ツールにします（app.selectTool('Adobe Select Tool')。ほかのキーやクリックを挟むと数えません）。
「アートボードツールを選んだらアートボードパネルを開く」「グラデーションツールを選んだらグラデーションパネルを開く」をオンにすると、クリックやキーの後にツールを読み、ほかのツールから切り替わったときだけ［ウィンドウ］メニューのパネルを開きます（✓ が付いていれば何もしません）。いずれも初期値はオフで、アクセシビリティの許可が必要です。

起動・常駐
見張りを続けるには常駐が必要です（初期値はオン）。「ログイン時に起動」をオンにすると、ログイン時に自動で起動します（初期値はオフ）。手動起動・開き直しではメインウインドウを表示し、ログイン時の自動起動では表示しません。「Dockとアプリケーションスイッチャーに表示しない」をオンにすると、メイン・設定ウインドウがある間はDockと⌘Tabに表示し、すべて閉じると隠します（初期値はオフ）。メニューバーのアイコン、アプリ起動のホットキー、Finderからアプリを開き直すと表示できます。

環境設定（タブ）
Illustratorの主要な環境設定（一般・選択範囲・アンカー表示・アートボード・テキスト・ユーザーインターフェイス・ガイド・スマートガイド・パフォーマンス・ファイル管理・クリップボード・スクリプト実行の許可）を、セットでまとめて切り替えます（ai-scripts の PresetManager と同じ項目）。UIの明るさ・シェイプ形成ツールのカラー・バックグラウンドの3項目（バックグラウンドで書き出し・バックグラウンドで保存・復帰データの自動保存）も含みます。ラジオボタンでセットを選ぶとすぐに書き換えます。ほとんどの項目はダイアログボックスを開かずに書き換え、UIの明るさ・シェイプ形成ツールのカラー・バックグラウンドの3項目は今と異なるときだけダイアログボックスやツールオプションを開いて変えます（アクセシビリティの許可が必要）。ガイドをロックとシェイプ形成ツールのカラーはドキュメントが要るので、開いていなければ新規ドキュメントを作って変え、保存せずに閉じます（ツールは元に戻します）。今の環境設定と同じセットが選ばれた状態で表示されます。
セットの中身は設定の「環境設定セット」タブで編集します（初期値はデフォルト・プリセット1）。＋で選んでいるセットを複製、−で削除、∧∨で並べ替えます。「今の設定を取り込む」は、選んでいるセットの値をIllustratorの今の環境設定で置き換えます。編集は［上書き］を押すと保存され（［元に戻す］で最後に保存した状態に戻ります）、Illustratorには書き込みません。

関連付け（タブ）
複数の版のIllustratorがインストールされているとき、チェックした拡張子（.ai・.ait・.eps・.svg から選択）をまとめて、指定の版のIllustratorで開くようにします。ほかのアプリに関連付けられていた拡張子もIllustratorに変わります。「開く版」で選んで［切り替える］を押すと、macOSの関連付けの記録に版を書き込み、関連付けを管理するシステムの処理（lsd）を再起動します。変更前の記録は ~/Library/Application Support/VectorMate に10世代まで保存します。最新版（自動）に戻すと、インストールされている最も新しい版で開きます。macOSが直前の関連付けの変更をまだ保存していないときは、数分待ってから実行してください。

同期（タブ）
上の「同期フォルダー」（初期値は ~/sw Dropbox/takano masahiro/sync-setting/ai）を基準に、各項目の読み込み元を相対パスで指定します（/ か ~ で始めると絶対パス。［選択…］で同期フォルダーの中を選ぶと相対パスで保存します）。キーボードショートカットは、読み込み元のフォルダー（初期値は キーボードショートカット）にある .kys をすべて、Illustratorのキーボードショートカットのセットとして使えるようにします。［リンクして選ぶ］を押すと、~/Library/Preferences/Adobe Illustrator <版> Settings/ja_JP にそれぞれシンボリックリンクを作り、［編集］→［キーボードショートカット...］で「使用するセット」で選んだセットを選んで［OK］を押します（アクセシビリティの許可が必要）。Illustratorはセットの一覧を起動時に読むため、初めてリンクしたときはIllustratorを再起動してからもう一度押してください。同じ名前の .kys ファイルがあれば ~/Library/Application Support/VectorMate/LinkBackups に移します。操作中はキーボードやマウスに触れないでください。
［まとめて同期］は、ドキュメントプロファイル・合成フォントのリンクを作成してから、キーボードショートカットの［リンクして選ぶ］を行います（結果はそれぞれの項目に出ます）。
ドキュメントプロファイルと合成フォントも、読み込み元のフォルダー（初期値は同期フォルダーの「New Document Profiles」「合成フォント」）を指定して［リンクを作成］を押すと、フォルダー内のファイルを1つずつ ~/Library/Application Support/Adobe/Adobe Illustrator <版>/ja_JP の同じ名前のフォルダーにシンボリックリンクします。読み込み元に無いファイルはそのまま残り、同じ名前の実ファイルは ~/Library/Application Support/VectorMate/LinkBackups に移します。Illustratorに反映されないときは、Illustratorを再起動してください。

その他（タブ）
「Illustratorの設定を初期化」の［初期化…］は、確認のうえ起動中のIllustratorを終了し、その版の ~/Library/Application Support/Adobe/Adobe Illustrator <版>・~/Library/Preferences/Adobe Illustrator <版> Settings（「キャッシュも削除」がオンなら ~/Library/Caches/com.adobe.illustrator も）をゴミ箱に入れて、もう一度起動します。Illustratorが終了しなければ何も消しません。同期タブで作ったリンクも消えるので、あとで作り直してください。

設定の共有
設定の「設定の共有」タブで、メトリクスの設定・ホットキー・単位セット・単位パレットのモード・環境設定セットを書き出し・読み込みできます（「書き出す…」「読み込む…」、VectorMate-Settings.plist）。読み込むと確認のうえ設定を置き換えます。「設定の同期」で iCloud Drive や Dropbox などのフォルダーを選ぶと、複数のMacで同じ設定を使えます（後から保存した内容が優先）。ログイン時の起動・常駐・メニューバーのアイコンはMacごとに設定します。

ホットキー
⇧F2・⇧F1でUIの明るさ（Illustratorが前面のとき）、⌘,で設定、⌘0で「メインウインドウを開く」、⌘Wでウインドウを閉じる、⌘Qで終了、⌘?でこのヘルプを開きます。

権限
- オートメーション（Adobe Illustrator）：選択中のテキストの読み書きと設定の読み取りに使います。最初に使うときにmacOSが許可を求めます。
- アクセシビリティ：Illustratorで押したキーを確認のきっかけにするためと、環境設定・ツールオプションのダイアログボックスを操作するために使います。未許可でもクリックの後の確認はできます。

困ったとき
「Illustratorを操作する許可がありません」は、システム設定の［プライバシーとセキュリティ］→［オートメーション］でVectorMateの「Adobe Illustrator」をオンにしてください。
プロポーショナルメトリクスがONにならないときは、Illustratorでダイアログボックスが開いていないか、VectorMateが一時停止中でないかを確認してください。
ダイアログボックスの項目は日本語版のIllustratorで確認しています。ほかの言語では見つからないことがあり、その場合は変更せずに閉じます。

プライバシー・更新
外部と通信しません。保存するのは設定（UserDefaults）だけです。アプリメニューの「アップデートを確認…」は共通の更新機能ですが、現在のビルドは更新先・署名鍵・公証が未設定のため「更新配布の準備中」と表示し、通信しません。
サポート：同梱のREADME.md（アプリ内 Contents/Resources/README.md）。''',
'''VectorMate — Helpers for Illustrator

Metrics and Proportional Metrics
When the auto-kerning of the selected text changes from another method to Metrics, Proportional Metrics (OpenType) is turned on (on by default).
- It is checked after a click in Illustrator, after Return, Enter, Tab or a ⌘ key, and when Illustrator comes to the front. Nothing happens while another app is in front.
- Changing from Metrics to another method turns it off (an option in the main window, on by default).
- Only a kerning change on the same selection counts. Changing it by hand afterwards is kept.
- Selected text objects (up to 200) and text selected with the Type tool are covered.
- Undo (⌘Z) in Illustrator reverts it.
- Pause in the menu bar icon stops it for a while.

Background (Preferences tab)
Checkboxes for Export in Background, Save in Background and Automatically Save Recovery Data in Illustrator Settings → File Handling. The state is read from Illustrator’s preference files (Adobe Illustrator Cloud Prefs and the main prefs); a change made in Illustrator may not be written until it quits, so Check can also open the Settings dialog box, read it and close it with Cancel; each change opens it, sets the item and closes it with OK. Turn Off Background Save and Export in the menu bar or File menu turns both off. Do not touch the keyboard or mouse meanwhile. Illustrator is never launched for this.

Basic UI tab
Brightness: radio buttons for the brightness in Illustrator Settings → User Interface (Dark, Medium Dark, Medium Light, Light). While Illustrator is in front, ⇧F2 makes it one step brighter and ⇧F1 darker (Set Hotkeys… opens the Hotkeys tab of Settings to change or clear them; other apps keep the keys). Each change opens the Settings dialog box, clicks the button and closes it with OK; presses made meanwhile are applied together.
Display: Toolbar (Advanced), Contextual Task Bar, Control Bar, Help Bar, Application Bar, Application Frame and Snap to Glyph are read from the checkmarks in Illustrator's menus and switched by choosing the menu item.
Classic Layout: Toolbar Advanced, Contextual Task Bar off, Control Bar on, Snap to Glyph off, Help Bar off, Application Bar off, Application Frame off in one go. The toolbar's two-column layout cannot be switched from a script; use « » at the top of the toolbar.

Quick Preferences
A floating palette opened with Show Quick Preferences (menu bar, File menu, the main window button, or a hotkey set in Settings), with the items of AiQuickPrefsPalette: keyboard increment (∧∨ / ↑↓ to the next whole number, Shift to multiples of 10, Option by 0.1) and ruler unit, Align options (preview bounds, glyph bounds), Transform options (pattern tiles, corners, strokes & effects; Option-click switches all), Copy / Paste (paste without formatting, paste remembers layers) and Drawing (real-time drawing & editing, Refresh Preview). Only the ruler unit opens the Units pane of Settings. The values are read again whenever the palette comes forward.

Quick Transform
A floating palette opened with Show Quick Transform (menu bar, File menu, the main window button, or ⌃⌥⌘T, changeable in Settings), working as QuickTransformPalette in ai-scripts. Illustrator stays in front while it is open.
- Flip / Rotate: flips horizontally or vertically and rotates by 90° about the anchor point picked on the right (nine points). The slider turns in 15° steps (90° with Shift) and goes back to 0 when released; the object keeps its rotation.
- Move / Duplicate: the arrows move the selection by its width or height plus the margin; the center duplicates in place.
- Option-click duplicates first, then moves, flips or rotates the copy (the copy is selected).
- The margin is in ruler units; negative values overlap. After a flip or rotation it shifts toward the anchor side. With Preview bounds on, strokes and effects are measured.
- Each operation is one undo step in Illustrator (the slider, one per step).

Units Palette
A floating palette opened with Show Units Palette (menu bar, File menu, the Units Palette button of the main window, or a hotkey set in Settings). Pick a unit set (by default Print (pt), Print (Q), Web, Presentation) and switch with ⌘Return, ⌘-click or double-click (Tab / ↑↓ select, Esc hides; the set matching the current units is marked). Both Basic and Detailed modes change units and increments (keyboard increment, corner radius, size/leading and baseline shift). Detailed mode also changes the open document’s color mode, Overprint Preview, raster effects resolution, transparency grid colors and Snap to Pixel change too (the grid colors are set as SetSameGridColors does: the swatches in Document Setup are clicked and the color panel’s hex field written; the pointer moves). Edit Sets… or the Unit Sets tab of Settings adds, deletes, reorders and edits the sets. Units written from a script only take effect after a restart, so the Units pane of Settings is opened, each popup is moved to the wanted unit with the arrow keys, and OK is pressed only when all four match (Cancel otherwise); the units are read again afterwards. Do not touch the keyboard or mouse meanwhile.

Tools tab
Radio buttons for Pick Color From in the Shape Builder Tool Options (Color Swatches or Artwork). The Shape Builder tool is selected, its options are opened, the item is picked and OK is pressed (a document must be open; the Shape Builder tool stays selected). Do not touch the keyboard or mouse meanwhile.
Double-tap a modifier key to switch to the Selection tool: while Illustrator is in front, tapping the chosen key (Control, Option, Command or Shift; Control by default) alone twice selects the Selection tool (app.selectTool('Adobe Select Tool'); another key or a click in between cancels it).
Open the Artboards / Gradient panel with the Artboard / Gradient tool: the tool is read after clicks and keys, and the panel opens from the Window menu only when the tool is switched to from another one (nothing happens when the item already has a checkmark). All are off by default and need the Accessibility permission.

Startup and background
The app must keep running to watch (on by default). Open at login starts it when you log in (off by default). Manual launch and reopening show the main window; automatic login launch does not. Hide from Dock and App Switcher the app appears in the Dock and ⌘Tab while main/settings windows exist, including minimized windows, and hides after all such windows close (off by default); show the app from the menu bar icon, the app launch hotkey, or by opening it again in Finder.

Preferences tab
Switches Illustrator’s main preferences (General, Selection & Anchor Display, Artboards, Type, User Interface, Guides, Smart Guides, Performance, File Handling, Clipboard, Allow scripts to run) as a set (the items of PresetManager in ai-scripts). UI brightness, the Shape Builder color and the three background items (Export in Background, Save in Background, Automatically Save Recovery Data) are included too. Choosing a set with the radio buttons rewrites them at once: most items without a dialog box; UI brightness, the Shape Builder color and the background items open their dialog box or the tool options only when they differ (Accessibility permission needed). Lock Guides and the Shape Builder color need a document: without one, a new document is made to change them and closed without saving (the tool is restored). The set matching the current preferences is shown selected.
The sets are edited in the Preference Sets tab of Settings (by default Default and Preset 1). + duplicates the selected set, − deletes it, ∧∨ reorder. Use Current Settings replaces the values of the selected set with Illustrator’s current preferences. Edits are saved when you click Overwrite (Revert goes back to what was last saved); nothing is written to Illustrator.

Associations tab
When several versions of Illustrator are installed, the checked extensions (.ai, .ait, .eps, .svg) are switched together to open in the chosen version of Illustrator, including ones associated with another app. Pick it in Open with and click Switch: the version is written into macOS’s file association record and lsd, the system process that manages it, is restarted. Up to 10 previous records are kept in ~/Library/Application Support/VectorMate. Newest (automatic) opens files in the newest installed version. If macOS has not saved a recent association change yet, wait a few minutes and try again.

Sync tab
The sources are paths relative to the Synced Folder at the top (by default ~/sw Dropbox/takano masahiro/sync-setting/ai; a path starting with / or ~ is used as is; choosing inside the Synced Folder with Choose… saves a relative path). Keyboard Shortcuts makes every .kys of the source folder (by default キーボードショートカット) available as Illustrator’s keyboard shortcut sets. Link and Choose makes a symbolic link to each in ~/Library/Preferences/Adobe Illustrator <version> Settings/ja_JP, chooses the Set to Use in Edit → Keyboard Shortcuts... and clicks OK (Accessibility permission needed). Illustrator reads the list of sets when it launches, so after the first link, restart Illustrator and click again. A .kys file with the same name is moved to ~/Library/Application Support/VectorMate/LinkBackups. Do not touch the keyboard or mouse meanwhile.
Sync All creates the links for document profiles and composite fonts, then does Link and Choose for keyboard shortcuts (each result shows under its item).
Document profiles and composite fonts work the same way: choose the source folder (by default New Document Profiles and 合成フォント in the Synced Folder) and click Create Links to link each file into the folder of the same name in ~/Library/Application Support/Adobe/Adobe Illustrator <version>/ja_JP. Files not in the source stay; a real file with the same name is moved to ~/Library/Application Support/VectorMate/LinkBackups. If Illustrator does not show them, restart Illustrator.

Other tab
Reset… under Reset Illustrator Settings asks first, quits the running Illustrator, moves ~/Library/Application Support/Adobe/Adobe Illustrator <version> and ~/Library/Preferences/Adobe Illustrator <version> Settings (and ~/Library/Caches/com.adobe.illustrator when Also delete the cache is on) to the Trash, then launches it again. If Illustrator does not quit, nothing is moved. Links made in the Sync tab go too; make them again afterwards.

Sharing settings
In the Sharing tab of Settings, Export… and Import… save and load the Metrics options, hotkeys, unit sets, Units Palette mode and preference sets (VectorMate-Settings.plist). Importing asks first, then replaces the settings. Settings Sync keeps them the same on several Macs through a folder such as iCloud Drive or Dropbox (the most recent save wins). Open at login, staying in the background and the menu bar icon are set on each Mac.

Hotkeys
⇧F2 / ⇧F1 UI brightness (while Illustrator is in front), ⌘, settings, ⌘0 open the main window, ⌘W close the window, ⌘Q quit, ⌘? this help.

Permissions
- Automation (Adobe Illustrator): reads and sets the selected text and reads the settings. macOS asks the first time.
- Accessibility: uses keys pressed in Illustrator as a cue to check, and operates the Settings and tool options dialog boxes. Without it, checks still run after clicks.

Troubleshooting
“Not allowed to control Illustrator”: turn on Adobe Illustrator for VectorMate in System Settings → Privacy & Security → Automation.
If Proportional Metrics is not turned on, check that no dialog box is open in Illustrator and that VectorMate is not paused.
The dialog box controls are verified with the Japanese Illustrator. In other languages they may not be found; the dialog box is then closed without changes.

Privacy and updates
No network access. Only the settings (UserDefaults) are saved. Check for Updates… uses the shared updater, but this build has no update feed, signing key or notarization, so it reports that updates are not configured and makes no network access.
Support: see the bundled README.md (Contents/Resources/README.md inside the app).''',
'''VectorMate — Illustrator 辅助工具

度量标准与比例间距
将所选文本的自动字距调整从其他方式改为“度量标准”时，打开 OpenType 的“比例间距”（默认开启）。
- 在 Illustrator 中点击后、按下 Return、Enter、Tab 或 ⌘ 键后，以及 Illustrator 来到前台时检查。其他应用在前台时不做任何操作。
- 从“度量标准”改为其他方式时关闭（可在主窗口中关闭此项，默认开启）。
- 仅针对在同一选择上更改字距调整的情况。之后手动切换则保持不变。
- 对象为所选文本对象（最多 200 个）和用文字工具选中的文字。
- 可在 Illustrator 中用撤销（⌘Z）还原。
- 可用菜单栏图标中的“暂停”暂时停止。

后台（首选项标签页）
用复选框切换 Illustrator“设置 → 文件处理”中的“后台导出”“后台存储”“自动存储恢复数据”。脚本无法读取其状态，因此点按“检查”时打开设置对话框读取并按“取消”关闭；每次切换都会打开对话框更改该项并按“好”关闭。菜单栏和文件菜单中的“关闭后台存储与导出”会同时关闭前两项。操作期间请勿触碰键盘和鼠标。不会为此启动 Illustrator。

基本界面（标签）
亮度：用单选按钮选择 Illustrator“设置 → 用户界面”中的亮度（暗、中等深色、中等浅色、亮）。Illustrator 位于前台时，⇧F2 调亮一级，⇧F1 调暗一级（可通过“设置快捷键…”打开设置的“快捷键”标签进行更改或清除；不会占用其他应用的按键）。
显示：工具栏（高级）、上下文任务栏、控制栏、帮助栏、应用程序栏、应用程序框架、对齐字形，根据 Illustrator 菜单的勾号读取，并通过选择菜单项切换。
经典布局：一次设为工具栏高级、上下文任务栏关、控制栏开、对齐字形关、帮助栏关、应用程序栏关、应用程序框架关。工具栏的双栏显示无法通过脚本切换，请使用工具栏顶部的 «»。

快速偏好设置
通过“显示快速偏好设置”打开的浮动面板，项目与 AiQuickPrefsPalette 相同：键盘增量与标尺单位、对齐选项、变换选项（option 点按一起切换）、拷贝/粘贴、绘图（实时绘图和编辑、刷新预览）。仅标尺单位会打开设置的“单位”更改。面板来到前面时会重新读取当前值。

快速变换
通过“显示快速变换”（菜单栏、文件菜单、主窗口的按钮或 ⌃⌥⌘T，可在设置中更改）打开的浮动面板，操作与 ai-scripts 的 QuickTransformPalette 相同。打开后 Illustrator 仍位于前台。
- 翻转・旋转：水平或垂直翻转，或每次旋转 90°。基点在右侧的参考点（9 处）中选择。滑块以 15° 为步进（Shift＝90°），松开后回到 0（对象保持旋转后的状态）。
- 移动・复制：箭头按所选对象整体的宽度或高度加边距移动。中间按钮在原位复制。
- Option 点按会先复制再移动、翻转或旋转（选中复制出的对象）。
- 边距使用标尺单位，负值为重叠方向。翻转和旋转后向参考点一侧移动。打开“预览边界”时包含描边和效果进行测量。
- 每次操作对应 Illustrator 的一步撤销（滑块为每个步进一步）。

单位面板
通过“显示单位面板”（菜单栏、文件菜单、主窗口的“单位面板”按钮或在设置中指定的快捷键）打开的浮动面板。从列表选择单位组合（默认：印刷（pt）、印刷（级）、网页、演示），按 ⌘Return、⌘点按或双击切换。“基本”和“详细”模式都会更改单位及增量（键盘增量、圆角半径、大小/行距、基线偏移）；“详细”模式还会更改打开文档的颜色模式、叠印预览、栅格效果分辨率、透明度网格颜色和对齐像素（网格颜色会点按“文档设置”中的色块并写入颜色面板的十六进制栏，鼠标指针会移动）。可通过“编辑组合…”或设置的“单位组合”标签添加、删除、排序和编辑。会打开设置的“单位”，用方向键选择各弹出菜单，四项都正确时才按“好”。操作期间请勿触碰键盘和鼠标。

工具（标签）
用单选按钮切换“形状生成器工具选项”中的“拾色来源”（色板或图稿）。会选择形状生成器工具、打开其选项、选择项目并按“好”（需要打开文档；工具会保持为形状生成器工具）。操作期间请勿触碰键盘和鼠标。
打开“连按两下修饰键切换到选择工具”后，Illustrator 位于前台时，单独连按两下所选的键（Control、Option、Command 或 Shift，默认为 Control）会切换到选择工具（app.selectTool('Adobe Select Tool')；中间按其他键或点按则不计）。
打开“选择画板工具时打开‘画板’面板”“选择渐变工具时打开‘渐变’面板”后，会在点按或按键后读取工具，仅在从其他工具切换过来时从“窗口”菜单打开面板（已有 ✓ 时不执行任何操作）。默认均为关，需要辅助功能权限。

启动与后台
持续监视需要应用保持运行（默认开启）。“登录时启动”会在登录时自动启动（默认关闭）。手动启动或重新打开时显示主窗口，登录时自动启动不显示主窗口。“不在程序坞和应用程序切换器中显示”会让图标不出现在程序坞和 ⌘Tab 切换器中（默认关闭）；可通过菜单栏图标、启动应用快捷键或在访达中再次打开应用来显示。

首选项（标签页）
以组合一次性切换 Illustrator 的主要首选项（常规、选择和锚点显示、画板、文字、用户界面、参考线、智能参考线、性能、文件处理、剪贴板、允许运行脚本）（与 ai-scripts 的 PresetManager 项目相同）。也包括界面亮度、形状生成器工具颜色和后台的 3 个项目（后台导出、后台存储、自动存储恢复数据）。用单选按钮选择组合后立即改写：大多数项目不打开对话框；界面亮度、形状生成器工具颜色和后台项目仅在与当前不同时打开对话框或工具选项更改（需要辅助功能权限）。锁定参考线和形状生成器工具颜色需要文档：未打开文档时会新建文档进行更改，然后不存储即关闭（工具会恢复）。与当前首选项一致的组合显示为已选中。
组合内容在设置的“首选项组合”标签中编辑（默认为“默认”和“预设 1”）。+ 复制所选组合，− 删除，∧∨ 调整顺序。“使用当前设置”会用 Illustrator 当前的首选项替换所选组合的值。点按“覆盖”时保存编辑（“还原”会回到上次保存的状态），不会写入 Illustrator。

关联（标签页）
安装了多个版本的 Illustrator 时，将勾选的扩展名（从 .ai、.ait、.eps、.svg 中选择）一并改为用指定版本的 Illustrator 打开，原本关联其他应用的扩展名也会改为 Illustrator。在“打开版本”中选择后点按“切换”，会将版本写入 macOS 的文件关联记录，并重新启动管理关联的系统进程（lsd）。更改前的记录最多保存 10 份到 ~/Library/Application Support/VectorMate。“最新版本（自动）”用已安装的最新版本打开。若 macOS 尚未保存最近的关联更改，请等待几分钟后重试。

同步（标签页）
各项来源是相对于顶部“同步文件夹”（默认为 ~/sw Dropbox/takano masahiro/sync-setting/ai）的路径（以 / 或 ~ 开头时为绝对路径；用“选择…”选择同步文件夹中的项目时保存为相对路径）。键盘快捷键会让来源文件夹（默认为 キーボードショートカット）中的所有 .kys 可用作 Illustrator 的键盘快捷键组合。点按“链接并选择”会在 ~/Library/Preferences/Adobe Illustrator <版本> Settings/ja_JP 中为每个文件创建符号链接，在“编辑 → 键盘快捷键...”中选择“使用的组合”并点按“确定”（需要辅助功能权限）。Illustrator 在启动时读取组合列表，因此首次链接后请重新启动 Illustrator 并再次点按。同名的 .kys 文件会移到 ~/Library/Application Support/VectorMate/LinkBackups。操作期间请勿触碰键盘和鼠标。
“全部同步”会先为文档配置文件和复合字体创建链接，再对键盘快捷键执行“链接并选择”（结果显示在各项下方）。
文档配置文件和复合字体也一样：指定来源文件夹（默认为同步文件夹中的 New Document Profiles 和 合成フォント）并点按“创建链接”，即可将其中的文件逐个以符号链接放入 ~/Library/Application Support/Adobe/Adobe Illustrator <版本>/ja_JP 中的同名文件夹。来源中没有的文件保持不变；同名的实际文件会移到 ~/Library/Application Support/VectorMate/LinkBackups。如果 Illustrator 中未显示，请重新启动 Illustrator。

其他（标签页）
“初始化 Illustrator 设置”中的“初始化…”会先确认，然后退出正在运行的 Illustrator，将 ~/Library/Application Support/Adobe/Adobe Illustrator <版本> 和 ~/Library/Preferences/Adobe Illustrator <版本> Settings（开启“同时删除缓存”时还有 ~/Library/Caches/com.adobe.illustrator）移到废纸篓并重新启动。若 Illustrator 未退出，则不会移动任何内容。在“同步”标签中创建的链接也会消失，之后请重新创建。

设置共享
在设置的“设置共享”标签中，可以导出和导入度量标准设置、快捷键、单位组合、单位面板的模式和首选项组合（VectorMate-Settings.plist）。导入时会先确认，再替换设置。在“设置同步”中选择 iCloud 云盘或 Dropbox 等文件夹，即可在多台 Mac 上使用相同的设置（以最后保存的为准）。登录时启动、保持运行和菜单栏图标在每台 Mac 上分别设置。

快捷键
⇧F2／⇧F1 界面亮度（Illustrator 位于前台时），⌘, 设置，⌘0 打开主窗口，⌘W 关闭窗口，⌘Q 退出，⌘? 打开本帮助。

权限
- 自动化（Adobe Illustrator）：用于读写所选文本和读取设置。首次使用时 macOS 会请求许可。
- 辅助功能：把在 Illustrator 中按下的键作为检查时机，并操作设置对话框。未获授权时，点击后的检查仍可进行。

故障排除
“没有控制 Illustrator 的权限”：请在系统设置的“隐私与安全性 → 自动化”中为 VectorMate 打开“Adobe Illustrator”。
比例间距没有打开时，请确认 Illustrator 中没有打开的对话框，且 VectorMate 未暂停。
后台存储与导出的复选框已在日文版 Illustrator 中验证。其他语言可能找不到，此时不做更改就关闭。

隐私与更新
不进行网络通信。只保存设置（UserDefaults）。“检查更新…”使用通用更新功能，但当前版本未配置更新源、签名密钥和公证，因此显示尚未配置，不进行网络通信。
支持：请参阅随附的 README.md（应用内 Contents/Resources/README.md）。''',
'''VectorMate — Illustrator 작업 도우미

메트릭과 비례 메트릭
선택한 텍스트의 자동 커닝을 다른 방식에서 메트릭으로 바꾸면 OpenType의 비례 메트릭을 켭니다(기본값 켬).
- Illustrator에서 클릭한 뒤, Return·Enter·Tab·⌘ 키를 누른 뒤, Illustrator가 앞으로 왔을 때 확인합니다. 다른 앱이 앞에 있을 때는 아무것도 하지 않습니다.
- 메트릭에서 다른 방식으로 바꾸면 끕니다(메인 윈도우에서 끌 수 있으며 기본값 켬).
- 같은 선택에서 커닝을 바꾼 경우만 대상입니다. 그 후 직접 전환한 경우에는 되돌리지 않습니다.
- 선택한 텍스트 오브젝트(최대 200개)와 문자 도구로 선택한 문자가 대상입니다.
- Illustrator의 실행 취소(⌘Z)로 되돌릴 수 있습니다.
- 메뉴 막대 아이콘의 일시 정지로 잠시 멈출 수 있습니다.

백그라운드(환경설정 탭)
Illustrator 설정 → 파일 처리의 백그라운드 내보내기, 백그라운드 저장, 복구 데이터 자동 저장을 체크박스로 전환합니다. 스크립트로 상태를 읽을 수 없어 확인을 누르면 설정 대화상자를 열어 읽고 취소로 닫으며, 전환할 때마다 대화상자를 열어 그 항목을 바꾸고 확인으로 닫습니다. 메뉴 막대·파일 메뉴의 백그라운드 저장·내보내기 끄기는 두 항목을 함께 끕니다. 조작 중에는 키보드와 마우스를 만지지 마세요. 이를 위해 Illustrator를 실행하지는 않습니다.

기본 UI(탭)
밝기: Illustrator 설정 → 사용자 인터페이스의 밝기(어둡게, 약간 어둡게, 약간 밝게, 밝게)를 라디오 버튼으로 고릅니다. Illustrator가 앞에 있을 때 ⇧F2로 한 단계 밝게, ⇧F1로 한 단계 어둡게 합니다(단축키 설정…으로 설정의 단축키 탭을 열어 변경·해제할 수 있으며 다른 앱의 키는 가로채지 않습니다).
표시: 도구 막대(고급), 상황별 작업 표시줄, 컨트롤 막대, 도움말 막대, 응용 프로그램 막대, 응용 프로그램 프레임, 글리프에 물리기를 Illustrator 메뉴의 체크 표시로 읽고 메뉴를 선택해 전환합니다.
클래식 레이아웃: 도구 막대 고급, 상황별 작업 표시줄 끔, 컨트롤 막대 켬, 글리프에 물리기 끔, 도움말 막대 끔, 응용 프로그램 막대 끔, 응용 프로그램 프레임 끔으로 한 번에 맞춥니다. 도구 막대 2열 표시는 스크립트로 바꿀 수 없으니 도구 막대 위쪽의 «»를 사용하세요.

빠른 환경설정
빠른 환경설정 보기로 여는 떠 있는 팔레트이며 AiQuickPrefsPalette와 같은 항목입니다: 키보드 증감과 눈금자 단위, 정렬 옵션, 변형 옵션(option 클릭으로 함께 전환), 복사/붙여넣기, 그리기(실시간 그리기 및 편집, 미리 보기 새로 고침). 눈금자 단위만 설정의 단위를 열어 바꿉니다. 팔레트가 앞으로 올 때마다 현재 값을 다시 읽습니다.

빠른 변형
빠른 변형 보기(메뉴 막대, 파일 메뉴, 메인 윈도우의 버튼 또는 ⌃⌥⌘T, 설정에서 변경 가능)로 여는 떠 있는 팔레트입니다(ai-scripts의 QuickTransformPalette와 같은 조작). 열어도 Illustrator는 앞에 그대로 있습니다.
- 반전·회전: 가로·세로로 반전하거나 90°씩 회전합니다. 기준은 오른쪽의 기준점(9곳)에서 고릅니다. 슬라이더는 15° 단위(Shift = 90° 단위)이며, 놓으면 0으로 돌아갑니다(오브젝트는 회전한 상태 그대로).
- 이동·복제: 화살표로 선택 전체의 너비 또는 높이 + 여백만큼 이동합니다. 가운데는 같은 위치에 복제합니다.
- Option 클릭으로 복제한 뒤 이동·반전·회전합니다(복제한 것이 선택됩니다).
- 여백은 눈금자 단위이며 음수는 겹치는 방향입니다. 반전·회전 후에는 기준점 쪽으로 옮깁니다. 미리 보기 경계를 켜면 선과 효과를 포함해 측정합니다.
- 한 번의 조작은 Illustrator의 실행 취소 1단계입니다(슬라이더는 단위마다).

단위 팔레트
단위 팔레트 보기(메뉴 막대, 파일 메뉴, 메인 윈도우의 단위 팔레트 버튼 또는 설정에서 지정한 단축키)로 여는 떠 있는 팔레트입니다. 목록에서 단위 세트(기본값: 인쇄(pt), 인쇄(급), 웹, 프레젠테이션)를 골라 ⌘Return·⌘클릭·이중 클릭으로 전환합니다. 기본과 상세 모드는 모두 단위와 증감량(키보드 증감·모퉁이 반경·크기/행간·기준선 이동)을 바꿉니다. 상세 모드는 추가로 열린 도큐먼트의 색상 모드·중복 인쇄 미리 보기·래스터 효과 해상도·투명도 격자 색상·픽셀에 물리기도 바꿉니다(격자 색상은 도큐먼트 설정의 색상 견본을 클릭해 색상 패널의 16진수 칸에 씁니다. 포인터가 움직입니다). 세트 편집… 또는 설정의 단위 세트 탭에서 추가·삭제·정렬·편집할 수 있습니다. 설정의 단위를 열어 각 팝업을 화살표 키로 맞추고 네 개가 모두 맞을 때만 확인을 누릅니다. 조작 중에는 키보드와 마우스를 만지지 마세요.

도구(탭)
도형 구성 도구 옵션의 색상 선택 위치(색상 견본 또는 아트워크)를 라디오 버튼으로 전환합니다. 도형 구성 도구를 선택하고 옵션을 열어 항목을 고른 뒤 확인을 누릅니다(도큐먼트가 열려 있어야 하며, 도구는 도형 구성 도구로 남습니다). 조작 중에는 키보드와 마우스를 만지지 마세요.
보조 키를 두 번 탭하면 선택 도구로 전환을 켜면, Illustrator가 앞에 있을 때 선택한 키(Control, Option, Command, Shift. 기본값은 Control)만 두 번 가볍게 누르면 선택 도구로 바꿉니다(app.selectTool('Adobe Select Tool'). 사이에 다른 키나 클릭이 있으면 세지 않습니다).
대지 도구·그레이디언트 도구를 선택하면 패널 열기를 켜면, 클릭이나 키 입력 뒤에 도구를 읽고 다른 도구에서 전환했을 때만 윈도우 메뉴의 패널을 엽니다(✓가 있으면 아무것도 하지 않습니다). 모두 기본값은 끔이며 손쉬운 사용 권한이 필요합니다.

시작 및 백그라운드
감시를 계속하려면 앱이 실행 중이어야 합니다(기본값 켬). 로그인 시 실행을 켜면 로그인할 때 자동으로 실행합니다(기본값 끔). 수동 실행 및 다시 열기에서는 메인 윈도우를 표시하고 로그인 시 자동 실행에서는 표시하지 않습니다. Dock 및 앱 전환기에 표시 안 함을 켜면 메인·설정 윈도우가 있는 동안 Dock과 ⌘Tab에 표시하고 모두 닫으면 숨깁니다(기본값 끔). 메뉴 막대 아이콘, 앱 실행 단축키 또는 Finder에서 앱을 다시 열어 표시할 수 있습니다.

환경설정(탭)
Illustrator의 주요 환경설정(일반, 선택 및 고정점 표시, 대지, 문자, 사용자 인터페이스, 안내선, 고급 안내선, 성능, 파일 처리, 클립보드, 스크립트 실행 허용)을 세트로 한꺼번에 전환합니다(ai-scripts의 PresetManager와 같은 항목). UI 밝기·도형 구성 도구 색상·백그라운드 3개 항목(백그라운드 내보내기·백그라운드 저장·복구 데이터 자동 저장)도 포함합니다. 라디오 버튼으로 세트를 고르면 바로 바꿉니다. 대부분의 항목은 대화상자 없이 바꾸고, UI 밝기·도형 구성 도구 색상·백그라운드 항목은 현재와 다를 때만 대화상자나 도구 옵션을 열어 바꿉니다(손쉬운 사용 권한 필요). 안내선 잠그기와 도형 구성 도구 색상은 도큐먼트가 필요하므로, 없으면 새 도큐먼트를 만들어 바꾸고 저장하지 않고 닫습니다(도구는 원래대로 돌립니다). 현재 환경설정과 같은 세트가 선택된 상태로 표시됩니다.
세트 내용은 설정의 환경설정 세트 탭에서 편집합니다(기본값은 기본값, 사전 설정 1). +는 선택한 세트를 복제, −는 삭제, ∧∨는 순서 변경입니다. 현재 설정 가져오기는 선택한 세트의 값을 Illustrator의 현재 환경설정으로 바꿉니다. 편집은 덮어쓰기를 누르면 저장되며(되돌리기는 마지막으로 저장한 상태로 돌아갑니다) Illustrator에는 쓰지 않습니다.

연결(탭)
Illustrator가 여러 버전 설치되어 있을 때 체크한 확장자(.ai, .ait, .eps, .svg 중 선택)를 한꺼번에 지정한 버전의 Illustrator로 열도록 합니다. 다른 앱에 연결된 확장자도 Illustrator로 바뀝니다. 열 버전에서 고르고 전환을 누르면 macOS의 파일 연결 기록에 버전을 쓰고 연결을 관리하는 시스템 프로세스(lsd)를 다시 시작합니다. 변경 전 기록은 ~/Library/Application Support/VectorMate에 10개까지 보관합니다. 최신 버전(자동)은 설치된 가장 새로운 버전으로 엽니다. macOS가 최근 연결 변경을 아직 저장하지 않았다면 몇 분 후 다시 시도하세요.

동기화(탭)
각 항목의 불러올 위치는 위쪽 동기화 폴더(기본값은 ~/sw Dropbox/takano masahiro/sync-setting/ai) 기준의 상대 경로입니다(/ 또는 ~로 시작하면 절대 경로. 선택…으로 동기화 폴더 안을 고르면 상대 경로로 저장). 키보드 단축키는 불러올 폴더(기본값은 キーボードショートカット)의 .kys를 모두 Illustrator의 키보드 단축키 세트로 쓸 수 있게 합니다. 링크 후 선택을 누르면 ~/Library/Preferences/Adobe Illustrator <버전> Settings/ja_JP에 각각 심볼릭 링크를 만들고 편집 → 키보드 단축키...에서 사용할 세트를 골라 확인을 누릅니다(손쉬운 사용 권한 필요). Illustrator는 세트 목록을 시작할 때 읽으므로 처음 링크했을 때는 Illustrator를 다시 시작한 뒤 한 번 더 누르세요. 같은 이름의 .kys 파일이 있으면 ~/Library/Application Support/VectorMate/LinkBackups로 옮깁니다. 조작 중에는 키보드나 마우스를 건드리지 마세요.
모두 동기화는 도큐먼트 프로필·합성 글꼴의 링크를 만든 뒤 키보드 단축키의 링크 후 선택을 실행합니다(결과는 각 항목에 표시).
도큐먼트 프로필과 합성 글꼴도 같습니다. 불러올 폴더(기본값은 동기화 폴더의 New Document Profiles, 合成フォント)를 지정하고 링크 만들기를 누르면 폴더의 파일을 하나씩 ~/Library/Application Support/Adobe/Adobe Illustrator <버전>/ja_JP의 같은 이름 폴더에 심볼릭 링크합니다. 불러올 폴더에 없는 파일은 그대로 남고, 같은 이름의 실제 파일은 ~/Library/Application Support/VectorMate/LinkBackups로 옮깁니다. Illustrator에 반영되지 않으면 Illustrator를 다시 시작하세요.

기타(탭)
Illustrator 설정 초기화의 초기화…는 확인한 뒤 실행 중인 Illustrator를 종료하고 ~/Library/Application Support/Adobe/Adobe Illustrator <버전>, ~/Library/Preferences/Adobe Illustrator <버전> Settings(캐시도 삭제가 켜져 있으면 ~/Library/Caches/com.adobe.illustrator도)를 휴지통으로 옮긴 뒤 다시 시작합니다. Illustrator가 종료되지 않으면 아무것도 옮기지 않습니다. 동기화 탭에서 만든 링크도 사라지므로 나중에 다시 만드세요.

설정 공유
설정의 설정 공유 탭에서 메트릭 설정, 단축키, 단위 세트, 단위 팔레트 모드, 환경설정 세트를 내보내고 가져올 수 있습니다(VectorMate-Settings.plist). 가져올 때는 확인한 뒤 설정을 바꿉니다. 설정 동기화에서 iCloud Drive나 Dropbox 같은 폴더를 선택하면 여러 Mac에서 같은 설정을 사용할 수 있습니다(나중에 저장한 내용이 우선). 로그인 시 실행, 백그라운드 유지, 메뉴 막대 아이콘은 Mac마다 설정합니다.

단축키
⇧F2·⇧F1 UI 밝기(Illustrator가 앞에 있을 때), ⌘, 설정, ⌘0 메인 윈도우 열기, ⌘W 윈도우 닫기, ⌘Q 종료, ⌘? 이 도움말.

권한
- 자동화(Adobe Illustrator): 선택한 텍스트를 읽고 쓰며 설정을 읽는 데 사용합니다. 처음 사용할 때 macOS가 허용을 요청합니다.
- 손쉬운 사용: Illustrator에서 누른 키를 확인 시점으로 쓰고, 설정 대화상자를 조작하는 데 사용합니다. 권한이 없어도 클릭 후 확인은 됩니다.

문제 해결
Illustrator 제어 권한이 없다는 메시지가 나오면 시스템 설정의 개인정보 보호 및 보안 → 자동화에서 VectorMate의 Adobe Illustrator를 켜세요.
비례 메트릭이 켜지지 않으면 Illustrator에 열린 대화상자가 없는지, VectorMate가 일시 정지 중이 아닌지 확인하세요.
백그라운드 저장·내보내기 체크박스는 일본어판 Illustrator에서 확인했습니다. 다른 언어에서는 찾지 못할 수 있으며, 그때는 변경하지 않고 닫습니다.

개인정보와 업데이트
네트워크 통신을 하지 않습니다. 설정(UserDefaults)만 저장합니다. 업데이트 확인…은 공통 업데이트 기능이지만 현재 빌드는 업데이트 주소, 서명 키, 공증이 설정되지 않아 준비 중으로 표시하고 통신하지 않습니다.
지원: 함께 제공된 README.md(앱 내부 Contents/Resources/README.md)를 참조하세요.''',
]
for idx, lang in enumerate(LANGS):
    folder = root / 'Resources' / f'{lang}.lproj'; folder.mkdir(parents=True, exist_ok=True)
    values = {r[0]: r[idx + 1] for r in rows}; values['helpContent'] = helptexts[idx]
    (folder / 'Localizable.strings').write_text('\n'.join(json.dumps(k, ensure_ascii=False) + ' = ' + json.dumps(v, ensure_ascii=False) + ';' for k, v in values.items()) + '\n')
    (folder / 'InfoPlist.strings').write_text('"NSAppleEventsUsageDescription" = ' + json.dumps(APPLE_EVENTS[idx], ensure_ascii=False) + ';\n')
info = {'CFBundleName': 'VectorMate', 'CFBundleDisplayName': 'VectorMate', 'CFBundleIdentifier': 'jp.dtp-transit.vectormate', 'CFBundleExecutable': 'VectorMate',
        'CFBundlePackageType': 'APPL', 'CFBundleIconFile': 'VectorMate.icns', 'LSMinimumSystemVersion': '13.0', 'LSMultipleInstancesProhibited': True,
        'NSHighResolutionCapable': True, 'CFBundleDevelopmentRegion': 'en', 'CFBundleLocalizations': LANGS,
        'NSPrincipalClass': 'NSApplication', 'LSApplicationCategoryType': 'public.app-category.graphics-design',
        'SWNoteArticleURL': 'https://note.com/dtp_tranist/n/n8554a434e90a', 'SWAppFamily': 'swwwitch', 'NSHumanReadableCopyright': '© 2026 swwwitch',
        'CFBundleShortVersionString': '1.0.0', 'CFBundleVersion': '1', 'NSAppleEventsUsageDescription': APPLE_EVENTS[1]}
# Version and build come from the existing Info.plist, so regeneration never reverts them.
plist_path = root / 'Info.plist'; current = plistlib.loads(plist_path.read_bytes()) if plist_path.exists() else {}
info.update({k: current[k] for k in ('CFBundleShortVersionString', 'CFBundleVersion') if k in current})
plist_path.write_bytes(plistlib.dumps(info))
