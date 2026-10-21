# -*- coding: utf-8 -*-
import json
from pathlib import Path
o = {}
def t(k, ja, en, zh, ko): o[k] = [ja, en, zh, ko]
t('ready', '待機中です。Keynoteを前面にしてホットキーを押してください。', 'Waiting. Bring Keynote to the front and press a hotkey.', '等待中。请将 Keynote 置于前台并按快捷键。', '대기 중입니다. Keynote를 앞으로 가져와 단축키를 누르십시오.')
t('headerTitle', 'Keynoteをキーボードで手早く', 'Keynote, faster from the keyboard', '用键盘更快地操作 Keynote', '키보드로 Keynote를 빠르게')
t('headerSubtitle', 'Keynoteでは割り当てられない操作（不透明度・大きさ・トランジション・PNG書き出しなど）を含む102の操作をホットキーで実行します。', 'Runs 102 commands with hotkeys, including ones Keynote cannot assign keys to (opacity, size, transitions, PNG export and more).', '用快捷键执行 102 项操作，包括 Keynote 无法指定按键的操作（不透明度、大小、过渡、PNG 导出等）。', 'Keynote에서 키를 지정할 수 없는 작업(불투명도, 크기, 트랜지션, PNG 내보내기 등)을 포함해 102가지 작업을 단축키로 실행합니다.')
t('target', '対象アプリ', 'Target App', '目标应用', '대상 앱')
t('targetHint', 'Keynoteが前面のときだけホットキーを実行します。ほかのアプリでは同じキーを奪いません。', 'Hotkeys work only while Keynote is in front, so other apps keep the same keys.', '仅当 Keynote 位于前台时才执行快捷键，其他应用中的相同按键不受影响。', 'Keynote가 앞에 있을 때만 단축키를 실행하므로 다른 앱의 같은 키는 그대로입니다.')
t('showKeys', 'ホットキー一覧…', 'Hotkey List…', '快捷键列表…', '단축키 목록…')
t('support', 'サポート：作成を依頼したチャットへ、操作名と手順をお知らせください。', 'Support: tell the chat that requested this app the command name and the steps.', '支持：请向委托制作本应用的聊天告知操作名称和步骤。', '지원: 이 앱을 의뢰한 채팅에 작업 이름과 절차를 알려 주십시오.')
t('commandsActive', '%@個のホットキーが有効（Keynoteが前面のときだけ）', '%@ hotkeys active (only while Keynote is in front)', '%@ 个快捷键有效（仅当 Keynote 位于前台时）', '%@개의 단축키 사용 중(Keynote가 앞에 있을 때만)')
t('commandsHint', '各キーは「変更…」で変えられます（⌘か⌃を含むキー。⌥・⇧だけの初期値は⌥も可）。メニュー項目が使えないとき（選択がないときなど）は、押したキーをそのままKeynoteへ渡します。⌘や⌃を含まないキーは、テキストの入力中には文字として入力されます（テキストの操作を除く）。', 'Change any key with Change… (keys with ⌘ or ⌃; ⌥ is also accepted where the default uses ⌥ or ⇧ alone). When the menu item is not available (for example, nothing selected), the key goes to Keynote unchanged. Keys without ⌘ or ⌃ type their character while you are typing text (except the text commands).', '可用“更改…”更改按键（含 ⌘ 或 ⌃ 的按键；默认仅用 ⌥ 或 ⇧ 的也可用 ⌥）。菜单项不可用时（例如未选择任何内容），按键原样传给 Keynote。不含 ⌘ 或 ⌃ 的按键在输入文本时会作为字符输入（文本操作除外）。', '변경…으로 키를 바꿀 수 있습니다(⌘ 또는 ⌃를 포함한 키, 기본값이 ⌥ 또는 ⇧만인 경우 ⌥도 가능). 메뉴 항목을 사용할 수 없을 때(선택 항목이 없는 경우 등)는 누른 키를 그대로 Keynote에 전달합니다. ⌘이나 ⌃가 없는 키는 텍스트 입력 중에는 문자로 입력됩니다(텍스트 작업 제외).')
t('resetAllKeys', 'すべてのキーを初期値に戻す', 'Reset All Keys to Defaults', '将所有按键恢复为默认值', '모든 키를 기본값으로 재설정')
t('enableCategory', 'このグループをすべてオン', 'Turn All On', '全部打开', '모두 켜기')
t('disableCategory', 'このグループをすべてオフ', 'Turn All Off', '全部关闭', '모두 끄기')
for k, ja, en, zh, ko in [
    ('slideshow', 'スライドショー・ファイル', 'Slideshow & File', '幻灯片放映与文件', '슬라이드쇼 및 파일'),
    ('navigation', 'スライドの移動・構成', 'Slide Navigation & Structure', '幻灯片导航与结构', '슬라이드 이동 및 구성'),
    ('objects', 'オブジェクト（グループ・重ね順・作成・隠す）', 'Objects (Group, Order, Create, Hide)', '对象（组合、层次、创建、隐藏）', '객체(그룹, 순서, 생성, 가리기)'),
    ('inspector', 'インスペクタ', 'Inspector', '检查器', '속성'),
    ('transition', 'トランジション', 'Transitions', '过渡', '트랜지션'),
    ('sweeper', '書類の掃除（KeynoteSweeper）', 'Clean Up (KeynoteSweeper)', '清理文稿（KeynoteSweeper）', '문서 정리(KeynoteSweeper)'),
    ('align', '整列・均等配置', 'Align & Distribute', '对齐与分布', '정렬 및 분산'),
    ('zoom', 'ズーム', 'Zoom', '缩放', '확대/축소'),
    ('animation', 'アニメーション', 'Animation', '动画', '애니메이션'),
    ('text', 'テキスト', 'Text', '文本', '텍스트'),
    ('export', '書き出し', 'Export', '导出', '내보내기'),
    ('guidesMask', 'ガイド・マスク', 'Guides & Mask', '参考线与遮罩', '안내선 및 마스크'),
    ('size', '大きさ', 'Size', '大小', '크기'),
    ('opacity', '不透明度', 'Opacity', '不透明度', '불투명도')]:
    t('category.' + k, ja, en, zh, ko)
t('fail.busy', '前の操作を実行中です。終わってからもう一度押してください。', 'The previous command is still running. Press the key again when it finishes.', '上一个操作仍在执行。完成后请再按一次。', '이전 작업이 실행 중입니다. 끝난 후 다시 누르십시오.')
t('fail.menu', 'Keynoteのメニューに対象の項目が見つかりませんでした（日本語・英語のメニューに対応）。', 'The menu item was not found in Keynote (Japanese and English menus are supported).', '在 Keynote 中找不到该菜单项（支持日语和英语菜单）。', 'Keynote에서 해당 메뉴 항목을 찾을 수 없습니다(일본어·영어 메뉴 지원).')
t('fail.button', 'アニメーションインスペクタの［プレビュー］が見つかりませんでした。アニメーションを設定したオブジェクトを選択してください。', 'The Preview button of the Animate inspector was not found. Select an object that has an animation.', '找不到动画检查器中的“预览”按钮。请选择设置了动画的对象。', '애니메이션 속성의 미리보기 버튼을 찾을 수 없습니다. 애니메이션이 있는 객체를 선택하십시오.')
t('fail.event', '操作を最後まで送れませんでした。Keynoteの状態を確かめてからもう一度押してください。', 'The command could not be completed. Check Keynote and press the key again.', '无法完成操作。请检查 Keynote 后再按一次。', '작업을 완료할 수 없습니다. Keynote를 확인한 후 다시 누르십시오.')
t('fail.noDocument', 'Keynoteで書類を開いてください。', 'Open a presentation in Keynote.', '请在 Keynote 中打开演示文稿。', 'Keynote에서 프레젠테이션을 여십시오.')
t('fail.automation', 'Keynoteの操作が許可されていません。システム設定 →［プライバシーとセキュリティ］→［オートメーション］で、KeynoteHelper の Keynote をオンにしてください。', 'KeynoteHelper is not allowed to control Keynote. Turn on Keynote for KeynoteHelper in System Settings > Privacy & Security > Automation.', '不允许 KeynoteHelper 控制 Keynote。请在“系统设置”>“隐私与安全性”>“自动化”中为 KeynoteHelper 打开 Keynote。', 'KeynoteHelper가 Keynote를 제어하도록 허용되지 않았습니다. 시스템 설정 > 개인정보 보호 및 보안 > 자동화에서 KeynoteHelper의 Keynote를 켜십시오.')
t('fail.script', 'Keynoteで実行できませんでした（エラー %@）。テキストの編集中でないか、対象を選択しているか確かめてください。', 'Keynote could not run it (error %@). Make sure you are not editing text and that something is selected.', 'Keynote 无法执行（错误 %@）。请确认没有在编辑文本，并且已选择对象。', 'Keynote에서 실행할 수 없습니다(오류 %@). 텍스트를 편집 중이 아닌지, 대상을 선택했는지 확인하십시오.')
t('fail.sweeper', 'Keynoteの［サービス］にKeynoteSweeperの項目がありません。KeynoteSweeperをインストールして一度起動し、システム設定 →［キーボード］→［キーボードショートカット］→［サービス］で項目がオンか確かめてください。', 'KeynoteSweeper’s item is not in Keynote > Services. Install and open KeynoteSweeper once, then check that the item is on in System Settings > Keyboard > Keyboard Shortcuts > Services.', 'Keynote 的“服务”中没有 KeynoteSweeper 的项目。请安装并打开一次 KeynoteSweeper，然后在“系统设置”>“键盘”>“键盘快捷键”>“服务”中确认该项目已打开。', 'Keynote의 서비스에 KeynoteSweeper 항목이 없습니다. KeynoteSweeper를 설치하고 한 번 실행한 후 시스템 설정 > 키보드 > 키보드 단축키 > 서비스에서 항목이 켜져 있는지 확인하십시오.')
t('sweeper.started', '「%@」をKeynoteSweeperで始めました。失敗したときはKeynoteSweeperのウインドウに表示されます。', 'Started “%@” in KeynoteSweeper. Failures are shown in KeynoteSweeper’s window.', '已在 KeynoteSweeper 中开始“%@”。失败时会显示在 KeynoteSweeper 的窗口中。', 'KeynoteSweeper에서 “%@”을(를) 시작했습니다. 실패하면 KeynoteSweeper 윈도우에 표시됩니다.')
t('success.done', '「%@」を実行しました。', 'Ran “%@”.', '已执行“%@”。', '“%@”을(를) 실행했습니다.')
t('result.done', '「%@」を設定しました。', 'Set “%@”.', '已设置“%@”。', '“%@”을(를) 설정했습니다.')
t('result.objects', '「%@」：%@個のオブジェクトを変更しました。', '“%@”: changed %@ objects.', '“%@”：已更改 %@ 个对象。', '“%@”: 객체 %@개를 변경했습니다.')
t('result.hidden', '%@個のオブジェクトを隠しました（不透明度0%%）。戻すときは「隠したオブジェクトを再表示」を使います。', 'Hid %@ objects (opacity 0%%). Use “Show Hidden Objects” to bring them back.', '已隐藏 %@ 个对象（不透明度 0%%）。使用“显示隐藏的对象”可恢复。', '객체 %@개를 가렸습니다(불투명도 0%%). 되돌리려면 “가린 객체 보기”를 사용하십시오.')
t('result.shown', 'このスライドの不透明度0%%のオブジェクト%@個を100%%に戻しました。', 'Set %@ objects with opacity 0%% on this slide back to 100%%.', '已将此幻灯片上 %@ 个不透明度为 0%% 的对象恢复为 100%%。', '이 슬라이드에서 불투명도 0%%인 객체 %@개를 100%%로 되돌렸습니다.')
t('result.noneHidden', 'このスライドに不透明度0%のオブジェクトはありません。', 'No objects with opacity 0% on this slide.', '此幻灯片上没有不透明度为 0% 的对象。', '이 슬라이드에 불투명도 0%인 객체가 없습니다.')
t('result.selectFirst', 'オブジェクトを選択してから押してください。', 'Select objects first, then press the key.', '请先选择对象，然后按键。', '객체를 선택한 후 키를 누르십시오.')
t('result.selectTwo', 'オブジェクトを2つ以上選択してから押してください。', 'Select two or more objects first, then press the key.', '请先选择两个或更多对象，然后按键。', '객체를 두 개 이상 선택한 후 키를 누르십시오.')
t('export.running', 'PNGを書き出しています…（スライドが多いと時間がかかります）', 'Exporting PNG… (takes longer with many slides)', '正在导出 PNG…（幻灯片较多时需要更长时间）', 'PNG를 내보내는 중…(슬라이드가 많으면 시간이 걸립니다)')
t('export.done', '%@ を書類と同じフォルダーに書き出しました。', 'Exported %@ to the presentation’s folder.', '已将 %@ 导出到演示文稿所在的文件夹。', '%@을(를) 프레젠테이션과 같은 폴더에 내보냈습니다.')
t('export.needsSave', 'PNGは書類と同じフォルダーに書き出します。先に書類を保存してください。', 'The PNG goes next to the presentation. Save the presentation first.', 'PNG 会导出到演示文稿旁边。请先存储演示文稿。', 'PNG는 프레젠테이션 옆에 내보냅니다. 먼저 프레젠테이션을 저장하십시오.')
t('export.failed', 'PNGを書き出せませんでした（エラー %@）。', 'Could not export the PNG (error %@).', '无法导出 PNG（错误 %@）。', 'PNG를 내보낼 수 없습니다(오류 %@).')
t('quitBusy', 'PNGの書き出し中は終了できません。書き出しが終わってから終了してください。', 'Cannot quit while a PNG export is running. Quit after it finishes.', 'PNG 导出期间无法退出。请在导出完成后退出。', 'PNG 내보내기 중에는 종료할 수 없습니다. 끝난 후 종료하십시오.')
t('help.defaultKeys', 'ホットキー（初期値）', 'Hotkeys (defaults)', '快捷键（默认值）', '단축키(기본값)')
t('helpHeading', 'KeynoteHelper ヘルプ', 'KeynoteHelper Help', 'KeynoteHelper 帮助', 'KeynoteHelper 도움말')
ja = """## 使い方
1. KeynoteHelperを起動したままにします（メニューバーに常駐します）。
2. Keynoteを前面にして、下の一覧のホットキーを押します。
- ホットキーはKeynoteが前面のときだけ実行します。ほかのアプリでは同じキーを奪いません。
- 結果は画面上部に短く表示し、メインウインドウの「直前の結果」とメニューバーのメニューの先頭にも残します。失敗したときは理由を必ず表示します。
- メニュー項目が使えないとき（オブジェクトを選択していないときなど）は、押したキーをそのままKeynoteへ渡します。
- ⌘や⌃を含まないキー（⌥L、⇧1 など）は、テキストの入力中は文字として入力されます（テキストの操作を除く）。

## Keynoteでは設定できない操作
- **不透明度**：⇧1〜⇧9で10〜90%、⇧0と⇧`で100%。
- **隠す・再表示**：⌘3で選択したオブジェクトの不透明度を0%にして選択を解除、⌥⌘3で表示中のスライドの不透明度0%のオブジェクトを100%に戻します。
- **大きさ**：90%・110%・50%・200%（中心を保つ）、幅±1pt、スライドの幅・高さいっぱい・幅の80%（スライドの中央へ）、同じ幅・同じ高さ（中心を保つ）。
- **トランジション**：このスライドを「なし」「ディゾルブ0.3秒」「マジックムーブ0.7秒」に。
- **書類の掃除（KeynoteSweeper）**：使用されていないマスター・非表示のスライド・すべてのトランジション・オブジェクトのアニメーション・すべてのアニメーションの削除を⌃⌥⌘1〜⌃⌥⌘5、マジックムーブ以外のトランジションの削除を⌃⌥0で、KeynoteSweeperのサービス（Keynote ▸ サービス）として実行します。確認なしで削除するため、⌃⌥0（Keyboard Maestroで使っていたキー）以外の初期値はオフです。設定の［ホットキー］でオンにしてください。KeynoteSweeperが必要です。結果や失敗はKeynoteSweeperが表示します。
- **図形**：スライドと同じ大きさの図形、中央の十字線、選択したオブジェクトと同じ大きさの背景の図形を後ろに置いてグループ化。色や太さはテーマの図形・線のスタイルに従います。
- **その場に複製**：複製して、ずれた分（⇧←・⇧↑）を戻します。
- **まとめて中央へ**：グループ化→中央揃え→グループ解除で、並びを崩さずにスライドの中央へ。
- **このスライドをPNGで書き出す**：書類と同じフォルダーに「書類名-p番号.png」で書き出し、Finderで表示します。同名のファイルがあるときは「-2」などを付け、上書きしません。Keynoteはいったんすべてのスライドを一時フォルダーへ書き出すため、スライドが多いと時間がかかります。未保存の書類では使えません。
- **アニメーションをプレビュー**：アニメーションインスペクタの［プレビュー］を押します。

## 元に戻す
- メニュー項目の操作とAppleScriptによる変更は、Keynoteの「取り消す」（⌘Z）で戻せます。KeynoteSweeperによる削除の取り消しはKeynoteSweeperのヘルプを参照してください。
- PNGの書き出しは書類を変更しません。

## 設定
- メインウインドウ：「ホットキーを有効にする」ですべてのホットキーをまとめてオン・オフします。
- 起動・常駐：ログイン時に起動（初期値オフ）、起動時にメインウインドウを表示しない、Dockとアプリケーションスイッチャーに表示しない（オンにするとDockと⌘Tabに出ません。メニューバーのアイコンやFinderから開き直すと表示します）、ウインドウを閉じても常駐、メニューバーに表示、アクセシビリティの許可状態、再起動・終了ボタン。
- ホットキー：操作ごとのオン・オフとキーの変更（［変更…］で記録、Escで取り消し）、初期値に戻す、グループごとのオン・オフ、成功時の通知。
- 設定の共有：ホットキーの設定を書き出し・読み込み・同期します。
- 情報：バージョンとリンク。
- 設定は ⌘, で開き、⌘W で閉じます。

## 許可
- **アクセシビリティ**：Keynoteのメニュー項目を押したりキーを送ったりするために必要です。システム設定 →［プライバシーとセキュリティ］→［アクセシビリティ］で KeynoteHelper をオンにします。
- **オートメーション**：不透明度・大きさ・トランジション・図形・PNG書き出しでKeynoteをAppleScriptで操作します。初回に確認が出たら［許可］を選びます。

## 常駐と終了
- ウインドウを閉じてもメニューバーで待機します。メニューバーのアイコン、Dock、Finderから開き直すとメインウインドウを表示します。
- 一時停止：メニューバーのメニューの「一時停止」で、再起動するまですべてのホットキーを止めます。
- 終了：メニューバーのメニューの「KeynoteHelperを終了」、アプリのメニュー、または KeynoteHelper が前面のときの ⌘Q。PNGの書き出し中は終了しません。

## 困ったときは
- 何も起きない：Keynoteが前面か、アクセシビリティが許可されているか、メインウインドウの「ホットキーを有効にする」がオンかを確かめてください。
- 「登録できませんでした」：ほかのアプリ（Keyboard Maestroなど）やmacOSが同じキーを使っています。⌃←・⌃→はmacOSの「操作スペースを左右に移動」と重なることがあります。キーを変えるか、相手側を無効にしてください。Keyboard Maestroの同じマクロも、二重に動かないようオフにしてください。
- 「メニューに対象の項目が見つかりませんでした」：日本語・英語以外の表示言語では動きません。
- 「Keynoteの操作が許可されていません」：システム設定のオートメーションで許可してください。

## 削除
- KeynoteHelperを終了し、アプリケーションフォルダーからゴミ箱へ入れます。設定は ~/Library/Preferences/jp.dtp-transit.keynotehelper.plist です。
"""
en = """## How to use
1. Keep KeynoteHelper running (it stays in the menu bar).
2. With Keynote in front, press a hotkey from the list below.
- Hotkeys work only while Keynote is in front, so other apps keep the same keys.
- The result appears briefly at the top of the screen and stays as “Last result” in the main window and at the top of the menu bar menu. Failures always show the reason.
- When the menu item is not available (for example, nothing is selected), the key goes to Keynote unchanged.
- Keys without ⌘ or ⌃ (⌥L, ⇧1 …) type their character while you are typing text (except the text commands).

## Commands Keynote cannot assign
- **Opacity**: ⇧1–⇧9 for 10–90%, ⇧0 or ⇧` for 100%.
- **Hide and show**: ⌘3 sets the selected objects to opacity 0% and deselects them; ⌥⌘3 sets objects with opacity 0% on the current slide back to 100%.
- **Size**: 90%, 110%, 50%, 200% (centers kept), width ±1 pt, fill the slide width or height or 80% of the width (moved to the slide center), same width or height (centers kept).
- **Transitions**: this slide to None, Dissolve 0.3 s or Magic Move 0.7 s.
- **Clean up (KeynoteSweeper)**: deletes unused masters, hidden slides, all transitions, object animations or all animations (⌃⌥⌘1–⌃⌥⌘5), and transitions except Magic Move (⌃⌥0), through KeynoteSweeper’s services (Keynote > Services). They delete without asking, so all but ⌃⌥0 (the Keyboard Maestro key) are off by default; turn them on in Settings > Hotkeys. KeynoteSweeper is required and reports the results and failures.
- **Shapes**: a slide-size shape, center cross lines, and a background shape of the same frame placed behind the selected object and grouped with it. Colors and widths follow the theme's shape and line styles.
- **Duplicate in place**: duplicates and moves the copy back (⇧← ⇧↑).
- **Center as a group**: Group → Align → Ungroup moves the objects to the slide center without changing their layout.
- **Export this slide as PNG**: writes “name-p<number>.png” next to the presentation and shows it in Finder. An existing file is never replaced (“-2” etc. is added). Keynote first exports every slide to a temporary folder, so large presentations take longer. Unsaved presentations are not supported.
- **Preview animation**: presses Preview in the Animate inspector.

## Undo
- Menu commands and AppleScript changes can be undone with Keynote's Undo (⌘Z). For undoing KeynoteSweeper’s deletions, see KeynoteSweeper’s help.
- PNG export does not change the presentation.

## Settings
- Main window: “Enable hotkey” turns all hotkeys on or off at once.
- Startup & Background: launch at login (off by default), hide main window at startup, Hide from Dock and App Switcher (when on, the app stays out of the Dock and ⌘Tab; open it again from the menu bar icon or Finder), keep running after closing, show in menu bar, Accessibility status, restart and quit buttons.
- Hotkeys: turn each command on or off and change its key (Change… records, Esc cancels), reset to defaults, per-group on/off, success notifications.
- Settings Sharing: export, import and sync the hotkey settings.
- About: version and links.
- Open Settings with ⌘, and close it with ⌘W.

## Permissions
- **Accessibility**: needed to press Keynote's menu items and send keys. Turn on KeynoteHelper in System Settings > Privacy & Security > Accessibility.
- **Automation**: opacity, size, transitions, shapes and PNG export control Keynote with AppleScript. Choose Allow when asked the first time.

## Staying open and quitting
- Closing the window keeps the app in the menu bar. The menu bar icon, the Dock or opening it again in Finder shows the main window.
- Pause: “Pause” in the menu bar menu stops all hotkeys until relaunch.
- Quit: “Quit KeynoteHelper” in the menu bar menu or the app menu, or ⌘Q while KeynoteHelper is in front. The app does not quit during a PNG export.

## Troubleshooting
- Nothing happens: check that Keynote is in front, Accessibility is allowed, and “Enable hotkey” is on in the main window.
- “Could not register”: another app (such as Keyboard Maestro) or macOS uses the key. ⌃← and ⌃→ may be taken by macOS to move between Spaces. Change the key or turn off the other one. Also turn off the same Keyboard Maestro macros so nothing runs twice.
- “The menu item was not found”: only Japanese and English Keynote menus are supported.
- “Not allowed to control Keynote”: allow it in System Settings > Automation.

## Removing
- Quit KeynoteHelper and move it from Applications to the Trash. Settings are in ~/Library/Preferences/jp.dtp-transit.keynotehelper.plist.
"""
zh = """## 使用方法
1. 保持 KeynoteHelper 运行（常驻在菜单栏）。
2. 将 Keynote 置于前台，按下方列表中的快捷键。
- 仅当 Keynote 位于前台时才执行快捷键，其他应用中的相同按键不受影响。
- 结果会在屏幕顶部短暂显示，并保留在主窗口的“上次结果”和菜单栏菜单顶部。失败时总会显示原因。
- 菜单项不可用时（例如未选择对象），按键原样传给 Keynote。
- 不含 ⌘ 或 ⌃ 的按键（⌥L、⇧1 等）在输入文本时会作为字符输入（文本操作除外）。

## Keynote 无法指定按键的操作
- **不透明度**：⇧1–⇧9 为 10–90%，⇧0 或 ⇧` 为 100%。
- **隐藏与显示**：⌘3 将所选对象的不透明度设为 0% 并取消选择；⌥⌘3 将当前幻灯片上不透明度为 0% 的对象恢复为 100%。
- **大小**：90%、110%、50%、200%（保持中心）、宽度 ±1 pt、填满幻灯片宽度或高度、宽度的 80%（移到幻灯片中央）、相同宽度或高度（保持中心）。
- **过渡**：将此幻灯片设为无、溶解 0.3 秒或神奇移动 0.7 秒。
- **清理文稿（KeynoteSweeper）**：通过 KeynoteSweeper 的服务（Keynote > 服务）删除未使用的母版、隐藏的幻灯片、所有过渡、对象动画或所有动画（⌃⌥⌘1–⌃⌥⌘5），以及神奇移动以外的过渡效果（⌃⌥0）。由于不经确认直接删除，除 ⌃⌥0（Keyboard Maestro 中使用的按键）外默认关闭；请在“设置”>“快捷键”中打开。需要 KeynoteSweeper，结果和失败由 KeynoteSweeper 显示。
- **形状**：与幻灯片同样大小的形状、中心十字线，以及在所选对象后面放置同样大小的背景形状并组合。颜色和粗细取决于主题的形状和线条样式。
- **原位复制**：复制后将副本移回原位（⇧← ⇧↑）。
- **作为一组居中**：组合 → 对齐 → 取消组合，在不改变排列的情况下移到幻灯片中央。
- **将此幻灯片导出为 PNG**：在演示文稿旁边写入“名称-p编号.png”并在访达中显示。不会覆盖已有文件（会添加“-2”等）。Keynote 会先将所有幻灯片导出到临时文件夹，因此幻灯片较多时需要更长时间。不支持未存储的演示文稿。
- **预览动画**：点按动画检查器中的“预览”。

## 撤销
- 菜单操作和 AppleScript 的更改可以用 Keynote 的“撤销”（⌘Z）还原。撤销 KeynoteSweeper 的删除请参阅 KeynoteSweeper 的帮助。
- PNG 导出不会更改演示文稿。

## 设置
- 主窗口：“启用快捷键”可一次打开或关闭所有快捷键。
- 启动与常驻：登录时启动（默认关闭）、启动时不显示主窗口、不在程序坞和应用切换器中显示（打开后不会出现在程序坞和 ⌘Tab 中；可从菜单栏图标或访达再次打开）、关闭窗口后继续运行、在菜单栏中显示、辅助功能状态、重新启动和退出按钮。
- 快捷键：逐项打开或关闭并更改按键（“更改…”录制，Esc 取消）、恢复默认值、按组打开或关闭、成功通知。
- 设置共享：导出、导入并同步快捷键设置。
- 关于：版本和链接。
- 用 ⌘, 打开设置，用 ⌘W 关闭。

## 权限
- **辅助功能**：用于点按 Keynote 的菜单项并发送按键。请在“系统设置”>“隐私与安全性”>“辅助功能”中打开 KeynoteHelper。
- **自动化**：不透明度、大小、过渡、形状和 PNG 导出通过 AppleScript 控制 Keynote。首次询问时请选择“允许”。

## 常驻与退出
- 关闭窗口后应用会在菜单栏中等待。点按菜单栏图标、程序坞或在访达中再次打开会显示主窗口。
- 暂停：菜单栏菜单中的“暂停”会停止所有快捷键，直到重新启动。
- 退出：菜单栏菜单或应用菜单中的“退出 KeynoteHelper”，或在 KeynoteHelper 位于前台时按 ⌘Q。PNG 导出期间不会退出。

## 疑难解答
- 没有反应：请确认 Keynote 位于前台、已允许辅助功能、主窗口中的“启用快捷键”已打开。
- “无法注册”：其他应用（例如 Keyboard Maestro）或 macOS 正在使用该按键。⌃← 和 ⌃→ 可能被 macOS 用于切换空间。请更改按键或关闭对方的设置。也请关闭 Keyboard Maestro 中相同的宏，以免重复执行。
- “找不到该菜单项”：仅支持日语和英语的 Keynote 菜单。
- “不允许控制 Keynote”：请在“系统设置”>“自动化”中允许。

## 删除
- 退出 KeynoteHelper，并将其从“应用程序”移到废纸篓。设置位于 ~/Library/Preferences/jp.dtp-transit.keynotehelper.plist。
"""
ko = """## 사용 방법
1. KeynoteHelper를 실행한 상태로 둡니다(메뉴 막대에 상주합니다).
2. Keynote를 앞으로 가져와 아래 목록의 단축키를 누릅니다.
- 단축키는 Keynote가 앞에 있을 때만 실행하므로 다른 앱의 같은 키는 그대로입니다.
- 결과는 화면 위쪽에 잠깐 표시되고, 메인 윈도우의 '마지막 결과'와 메뉴 막대 메뉴의 맨 위에도 남습니다. 실패하면 항상 이유를 표시합니다.
- 메뉴 항목을 사용할 수 없을 때(객체를 선택하지 않은 경우 등)는 누른 키를 그대로 Keynote에 전달합니다.
- ⌘이나 ⌃가 없는 키(⌥L, ⇧1 등)는 텍스트 입력 중에는 문자로 입력됩니다(텍스트 작업 제외).

## Keynote에서 키를 지정할 수 없는 작업
- **불투명도**: ⇧1~⇧9는 10~90%, ⇧0 또는 ⇧`는 100%.
- **가리기와 보기**: ⌘3은 선택한 객체의 불투명도를 0%로 하고 선택을 해제합니다. ⌥⌘3은 현재 슬라이드에서 불투명도 0%인 객체를 100%로 되돌립니다.
- **크기**: 90%, 110%, 50%, 200%(중심 유지), 폭 ±1pt, 슬라이드 폭·높이에 맞추기, 폭의 80%(슬라이드 가운데로), 같은 폭·같은 높이(중심 유지).
- **트랜지션**: 이 슬라이드를 없음, 디졸브 0.3초, 매직 이동 0.7초로.
- **문서 정리(KeynoteSweeper)**: KeynoteSweeper의 서비스(Keynote > 서비스)로 사용하지 않는 마스터, 숨긴 슬라이드, 모든 트랜지션, 객체 애니메이션, 모든 애니메이션(⌃⌥⌘1~⌃⌥⌘5), 매직 이동 이외의 전환 효과(⌃⌥0)를 삭제합니다. 확인 없이 삭제하므로 ⌃⌥0(Keyboard Maestro에서 쓰던 키) 외에는 기본값이 끔입니다. 설정 > 단축키에서 켜십시오. KeynoteSweeper가 필요하며 결과와 실패는 KeynoteSweeper가 표시합니다.
- **도형**: 슬라이드 크기의 도형, 가운데 십자선, 선택한 객체와 같은 크기의 배경 도형을 뒤에 두고 그룹화. 색상과 두께는 테마의 도형·선 스타일을 따릅니다.
- **제자리에 복제**: 복제한 후 어긋난 만큼(⇧← ⇧↑) 되돌립니다.
- **묶어서 가운데로**: 그룹화 → 정렬 → 그룹 해제로 배치를 유지한 채 슬라이드 가운데로 옮깁니다.
- **이 슬라이드를 PNG로 내보내기**: 프레젠테이션과 같은 폴더에 '이름-p번호.png'로 내보내고 Finder에서 보여 줍니다. 같은 이름의 파일은 덮어쓰지 않습니다('-2' 등을 붙임). Keynote가 먼저 모든 슬라이드를 임시 폴더로 내보내므로 슬라이드가 많으면 시간이 걸립니다. 저장하지 않은 프레젠테이션에서는 사용할 수 없습니다.
- **애니메이션 미리보기**: 애니메이션 속성의 미리보기 버튼을 누릅니다.

## 실행 취소
- 메뉴 작업과 AppleScript로 한 변경은 Keynote의 실행 취소(⌘Z)로 되돌릴 수 있습니다. KeynoteSweeper로 삭제한 내용의 실행 취소는 KeynoteSweeper 도움말을 참조하십시오.
- PNG 내보내기는 프레젠테이션을 변경하지 않습니다.

## 설정
- 메인 윈도우: '단축키 사용'으로 모든 단축키를 한 번에 켜거나 끕니다.
- 시작 및 상주: 로그인 시 실행(기본값 끔), 시작 시 메인 윈도우 숨기기, Dock 및 앱 전환기에서 숨기기(켜면 Dock과 ⌘Tab에 나타나지 않습니다. 메뉴 막대 아이콘이나 Finder에서 다시 열면 표시됩니다), 윈도우를 닫아도 상주, 메뉴 막대에 표시, 손쉬운 사용 권한 상태, 재시작 및 종료 버튼.
- 단축키: 작업별 켜기/끄기와 키 변경(변경…으로 기록, Esc로 취소), 기본값으로 재설정, 그룹별 켜기/끄기, 성공 알림.
- 설정 공유: 단축키 설정을 내보내고 가져오고 동기화합니다.
- 정보: 버전과 링크.
- 설정은 ⌘,로 열고 ⌘W로 닫습니다.

## 권한
- **손쉬운 사용**: Keynote의 메뉴 항목을 누르고 키를 보내는 데 필요합니다. 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 KeynoteHelper를 켜십시오.
- **자동화**: 불투명도, 크기, 트랜지션, 도형, PNG 내보내기는 AppleScript로 Keynote를 제어합니다. 처음 물어볼 때 허용을 선택하십시오.

## 상주와 종료
- 윈도우를 닫아도 메뉴 막대에서 대기합니다. 메뉴 막대 아이콘, Dock 또는 Finder에서 다시 열면 메인 윈도우를 표시합니다.
- 일시 정지: 메뉴 막대 메뉴의 '일시 정지'는 재시작할 때까지 모든 단축키를 멈춥니다.
- 종료: 메뉴 막대 메뉴나 앱 메뉴의 'KeynoteHelper 종료', 또는 KeynoteHelper가 앞에 있을 때 ⌘Q. PNG 내보내기 중에는 종료하지 않습니다.

## 문제 해결
- 아무 일도 일어나지 않음: Keynote가 앞에 있는지, 손쉬운 사용이 허용되었는지, 메인 윈도우의 '단축키 사용'이 켜져 있는지 확인하십시오.
- '등록할 수 없음': 다른 앱(Keyboard Maestro 등)이나 macOS가 같은 키를 사용하고 있습니다. ⌃←와 ⌃→는 macOS의 Spaces 이동과 겹칠 수 있습니다. 키를 바꾸거나 상대 쪽을 끄십시오. 두 번 실행되지 않도록 Keyboard Maestro의 같은 매크로도 끄십시오.
- '메뉴 항목을 찾을 수 없음': 일본어·영어 Keynote 메뉴만 지원합니다.
- 'Keynote 제어가 허용되지 않음': 시스템 설정 > 자동화에서 허용하십시오.

## 삭제
- KeynoteHelper를 종료하고 응용 프로그램 폴더에서 휴지통으로 옮깁니다. 설정은 ~/Library/Preferences/jp.dtp-transit.keynotehelper.plist에 있습니다.
"""
t('helpText', ja.strip(), en.strip(), zh.strip(), ko.strip())
Path(__file__).with_name('own.json').write_text(json.dumps(o, ensure_ascii=False))
