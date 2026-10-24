# -*- coding: utf-8 -*-
import json
from pathlib import Path
o = {}
def t(k, ja, en, zh, ko): o[k] = [ja, en, zh, ko]
t('searchCommands', '操作名・カテゴリ・キーで検索', 'Search commands, categories or keys', '搜索操作、类别或按键', '작업, 카테고리 또는 키 검색')
t('clearSearch', '検索をクリア', 'Clear Search', '清除搜索', '검색 지우기')
t('noSearchResults', '一致する操作がありません。', 'No matching commands.', '没有匹配的操作。', '일치하는 작업이 없습니다.')
t('result.selectOne', 'オブジェクトを1つ選択してください。', 'Select one object.', '请选择一个对象。', '객체를 하나 선택하십시오.')
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
t('fail.automation', 'Keynoteの操作が許可されていません。システム設定 →［プライバシーとセキュリティ］→［オートメーション］で、KeynoteMaestro の Keynote をオンにしてください。', 'KeynoteMaestro is not allowed to control Keynote. Turn on Keynote for KeynoteMaestro in System Settings > Privacy & Security > Automation.', '不允许 KeynoteMaestro 控制 Keynote。请在“系统设置”>“隐私与安全性”>“自动化”中为 KeynoteMaestro 打开 Keynote。', 'KeynoteMaestro가 Keynote를 제어하도록 허용되지 않았습니다. 시스템 설정 > 개인정보 보호 및 보안 > 자동화에서 KeynoteMaestro의 Keynote를 켜십시오.')
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
t('helpHeading', 'KeynoteMaestro ヘルプ', 'KeynoteMaestro Help', 'KeynoteMaestro 帮助', 'KeynoteMaestro 도움말')
ja = """## 使い方
1. KeynoteMaestroを起動したままにします（メニューバーに常駐します）。
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
- 起動・常駐：ログイン時に起動（初期値オフ）、Dockとアプリケーションスイッチャーに表示しない（オンにするとDockと⌘Tabに出ません。メニューバーのアイコンやFinderから開き直すと表示します）、ウインドウを閉じても常駐、メニューバーに表示、アクセシビリティの許可状態、再起動・終了ボタン。
- ホットキー：操作ごとのオン・オフとキーの変更（［変更…］で記録、Escで取り消し）、初期値に戻す、グループごとのオン・オフ、成功時の通知。
- 設定の共有：ホットキーの設定を書き出し・読み込み・同期します。
- 情報：バージョンとリンク。
- 設定は ⌘, で開き、⌘W で閉じます。

## 許可
- **アクセシビリティ**：Keynoteのメニュー項目を押したりキーを送ったりするために必要です。システム設定 →［プライバシーとセキュリティ］→［アクセシビリティ］で KeynoteMaestro をオンにします。
- **オートメーション**：不透明度・大きさ・トランジション・図形・PNG書き出しでKeynoteをAppleScriptで操作します。初回に確認が出たら［許可］を選びます。

## 常駐と終了
- ウインドウを閉じてもメニューバーで待機します。メニューバーのアイコン、Dock、Finderから開き直すとメインウインドウを表示します。
- 一時停止：メニューバーのメニューの「一時停止」で、再起動するまですべてのホットキーを止めます。
- 終了：メニューバーのメニューの「KeynoteMaestroを終了」、アプリのメニュー、または KeynoteMaestro が前面のときの ⌘Q。PNGの書き出し中や自動マジックムーブの処理中は終了しません。

## 困ったときは
- 何も起きない：Keynoteが前面か、アクセシビリティが許可されているか、メインウインドウの「ホットキーを有効にする」がオンかを確かめてください。
- 「登録できませんでした」：ほかのアプリ（Keyboard Maestroなど）やmacOSが同じキーを使っています。⌃←・⌃→はmacOSの「操作スペースを左右に移動」と重なることがあります。キーを変えるか、相手側を無効にしてください。Keyboard Maestroの同じマクロも、二重に動かないようオフにしてください。
- 「メニューに対象の項目が見つかりませんでした」：日本語・英語以外の表示言語では動きません。
- 「Keynoteの操作が許可されていません」：システム設定のオートメーションで許可してください。

## 削除
- KeynoteMaestroを終了し、アプリケーションフォルダーからゴミ箱へ入れます。設定は ~/Library/Preferences/jp.dtp-transit.keynotehelper.plist です。

手動起動・開き直しではメインウインドウを表示し、ログイン時の自動起動では表示しません。
"""
en = """## How to use
1. Keep KeynoteMaestro running (it stays in the menu bar).
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
- Startup & Background: launch at login (off by default), Hide from Dock and App Switcher (when on, the app stays out of the Dock and ⌘Tab; open it again from the menu bar icon or Finder), keep running after closing, show in menu bar, Accessibility status, restart and quit buttons.
- Hotkeys: turn each command on or off and change its key (Change… records, Esc cancels), reset to defaults, per-group on/off, success notifications.
- Settings Sharing: export, import and sync the hotkey settings.
- About: version and links.
- Open Settings with ⌘, and close it with ⌘W.

## Permissions
- **Accessibility**: needed to press Keynote's menu items and send keys. Turn on KeynoteMaestro in System Settings > Privacy & Security > Accessibility.
- **Automation**: opacity, size, transitions, shapes and PNG export control Keynote with AppleScript. Choose Allow when asked the first time.

## Staying open and quitting
- Closing the window keeps the app in the menu bar. The menu bar icon, the Dock or opening it again in Finder shows the main window.
- Pause: “Pause” in the menu bar menu stops all hotkeys until relaunch.
- Quit: “Quit KeynoteMaestro” in the menu bar menu or the app menu, or ⌘Q while KeynoteMaestro is in front. The app does not quit during a PNG export or Automatic Magic Move.

## Troubleshooting
- Nothing happens: check that Keynote is in front, Accessibility is allowed, and “Enable hotkey” is on in the main window.
- “Could not register”: another app (such as Keyboard Maestro) or macOS uses the key. ⌃← and ⌃→ may be taken by macOS to move between Spaces. Change the key or turn off the other one. Also turn off the same Keyboard Maestro macros so nothing runs twice.
- “The menu item was not found”: only Japanese and English Keynote menus are supported.
- “Not allowed to control Keynote”: allow it in System Settings > Automation.

## Removing
- Quit KeynoteMaestro and move it from Applications to the Trash. Settings are in ~/Library/Preferences/jp.dtp-transit.keynotehelper.plist.
"""
zh = """## 使用方法
1. 保持 KeynoteMaestro 运行（常驻在菜单栏）。
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
- 启动与常驻：登录时启动（默认关闭）、不在程序坞和应用切换器中显示（打开后不会出现在程序坞和 ⌘Tab 中；可从菜单栏图标或访达再次打开）、关闭窗口后继续运行、在菜单栏中显示、辅助功能状态、重新启动和退出按钮。
- 快捷键：逐项打开或关闭并更改按键（“更改…”录制，Esc 取消）、恢复默认值、按组打开或关闭、成功通知。
- 设置共享：导出、导入并同步快捷键设置。
- 关于：版本和链接。
- 用 ⌘, 打开设置，用 ⌘W 关闭。

## 权限
- **辅助功能**：用于点按 Keynote 的菜单项并发送按键。请在“系统设置”>“隐私与安全性”>“辅助功能”中打开 KeynoteMaestro。
- **自动化**：不透明度、大小、过渡、形状和 PNG 导出通过 AppleScript 控制 Keynote。首次询问时请选择“允许”。

## 常驻与退出
- 关闭窗口后应用会在菜单栏中等待。点按菜单栏图标、程序坞或在访达中再次打开会显示主窗口。
- 暂停：菜单栏菜单中的“暂停”会停止所有快捷键，直到重新启动。
- 退出：菜单栏菜单或应用菜单中的“退出 KeynoteMaestro”，或在 KeynoteMaestro 位于前台时按 ⌘Q。PNG 导出或自动神奇移动期间不会退出。

## 疑难解答
- 没有反应：请确认 Keynote 位于前台、已允许辅助功能、主窗口中的“启用快捷键”已打开。
- “无法注册”：其他应用（例如 Keyboard Maestro）或 macOS 正在使用该按键。⌃← 和 ⌃→ 可能被 macOS 用于切换空间。请更改按键或关闭对方的设置。也请关闭 Keyboard Maestro 中相同的宏，以免重复执行。
- “找不到该菜单项”：仅支持日语和英语的 Keynote 菜单。
- “不允许控制 Keynote”：请在“系统设置”>“自动化”中允许。

## 删除
- 退出 KeynoteMaestro，并将其从“应用程序”移到废纸篓。设置位于 ~/Library/Preferences/jp.dtp-transit.keynotehelper.plist。

手动启动或重新打开时显示主窗口，登录时自动启动不显示主窗口。
"""
ko = """## 사용 방법
1. KeynoteMaestro를 실행한 상태로 둡니다(메뉴 막대에 상주합니다).
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
- **손쉬운 사용**: Keynote의 메뉴 항목을 누르고 키를 보내는 데 필요합니다. 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 KeynoteMaestro를 켜십시오.
- **자동화**: 불투명도, 크기, 트랜지션, 도형, PNG 내보내기는 AppleScript로 Keynote를 제어합니다. 처음 물어볼 때 허용을 선택하십시오.

## 상주와 종료
- 윈도우를 닫아도 메뉴 막대에서 대기합니다. 메뉴 막대 아이콘, Dock 또는 Finder에서 다시 열면 메인 윈도우를 표시합니다.
- 일시 정지: 메뉴 막대 메뉴의 '일시 정지'는 재시작할 때까지 모든 단축키를 멈춥니다.
- 종료: 메뉴 막대 메뉴나 앱 메뉴의 'KeynoteMaestro 종료', 또는 KeynoteMaestro가 앞에 있을 때 ⌘Q. PNG 내보내기 또는 자동 매직 무브 처리 중에는 종료하지 않습니다.

## 문제 해결
- 아무 일도 일어나지 않음: Keynote가 앞에 있는지, 손쉬운 사용이 허용되었는지, 메인 윈도우의 '단축키 사용'이 켜져 있는지 확인하십시오.
- '등록할 수 없음': 다른 앱(Keyboard Maestro 등)이나 macOS가 같은 키를 사용하고 있습니다. ⌃←와 ⌃→는 macOS의 Spaces 이동과 겹칠 수 있습니다. 키를 바꾸거나 상대 쪽을 끄십시오. 두 번 실행되지 않도록 Keyboard Maestro의 같은 매크로도 끄십시오.
- '메뉴 항목을 찾을 수 없음': 일본어·영어 Keynote 메뉴만 지원합니다.
- 'Keynote 제어가 허용되지 않음': 시스템 설정 > 자동화에서 허용하십시오.

## 삭제
- KeynoteMaestro를 종료하고 응용 프로그램 폴더에서 휴지통으로 옮깁니다. 설정은 ~/Library/Preferences/jp.dtp-transit.keynotehelper.plist에 있습니다.
"""
ja += "\n\n## 検索と図形\n設定のホットキー一覧は操作名・カテゴリ・現在のキーで検索できます。⌃0はスライドと同じ大きさの図形、⌃⌥⌘0は選択した1つのオブジェクトと同じ位置・大きさの白い長方形を作り最背面へ送ります。グループ化はしません。途中でエラーになった場合はKeynoteの⌘Zで作成を取り消せます。"
en += "\n\n## Search and shapes\nSearch the hotkey settings by command, category or current key. ⌃0 creates a slide-size shape. ⌃⌥⌘0 adds a white rectangle matching one selected object's position and size and sends it to the back, without grouping. If a later step fails, undo creation in Keynote with ⌘Z."
zh += "\n\n## 搜索与形状\n在快捷键设置中按操作、类别或当前按键搜索。⌃0 创建幻灯片大小的形状。⌃⌥⌘0 创建与单个所选对象位置和尺寸相同的白色矩形并置于底层，不编组。中途失败时，可在 Keynote 中按 ⌘Z 撤销创建。"
ko += "\n\n## 검색 및 도형\n단축키 설정에서 작업, 카테고리 또는 현재 키로 검색합니다. ⌃0은 슬라이드 크기의 도형을 만듭니다. ⌃⌥⌘0은 선택한 객체 하나와 위치 및 크기가 같은 흰색 사각형을 만들고 맨 뒤로 보냅니다. 그룹화하지 않습니다. 도중에 실패하면 Keynote에서 ⌘Z로 생성을 취소할 수 있습니다."
t('helpText', ja.strip(), en.strip(), zh.strip(), ko.strip())

# Keynote reference comparison and source-aligned display categories.
t('catalog.referenceHint', 'Keynote標準は、いただいた日本語資料の341項目を参照表示します。標準キーは変更できません。システム設定などで変更したキーやKeynoteMaestroとの競合は反映されません。チェックとキー変更はKeynoteMaestroの操作に適用されます。', 'Keynote defaults show the 341 entries from the supplied Japanese reference, in its original language. They are read-only and do not reflect macOS overrides or conflicts with KeynoteMaestro. Checkboxes and key editing affect KeynoteMaestro commands.', 'Keynote 标准列以日语原文显示所提供资料中的 341 项操作，仅供参考，不反映系统设置中的更改或与 KeynoteMaestro 的冲突。复选框和按键编辑仅适用于 KeynoteMaestro 操作。', 'Keynote 기본값은 제공된 일본어 자료의 341개 항목을 원문으로 표시합니다. 읽기 전용이며 macOS에서 변경한 키나 KeynoteMaestro와의 충돌은 반영하지 않습니다. 체크박스와 키 변경은 KeynoteMaestro 작업에 적용됩니다.')
t('catalog.scope', '表示する操作', 'Show Commands', '显示操作', '표시할 작업')
t('catalog.scope.all', 'すべて', 'All', '全部', '모두')
t('catalog.scope.maestro', 'KeynoteMaestroの操作', 'KeynoteMaestro', 'KeynoteMaestro 操作', 'KeynoteMaestro 작업')
t('catalog.scope.native', 'Keynote標準の操作', 'Keynote Defaults', 'Keynote 标准操作', 'Keynote 기본 작업')
t('catalog.category', 'カテゴリ', 'Category', '类别', '카테고리')
t('catalog.allCategories', 'すべてのカテゴリ', 'All Categories', '所有类别', '모든 카테고리')
t('catalog.results', '%d件の操作', '%d commands', '%d 项操作', '작업 %d개')
t('catalog.operation', '操作', 'Command', '操作', '작업')
t('catalog.nativeColumn', 'Keynote標準', 'Keynote Default', 'Keynote 标准', 'Keynote 기본값')
t('catalog.notListed', '標準キーの記載なし', 'No default listed', '未列出标准按键', '기본 키 기재 없음')
t('catalog.referenceOnly', '参照のみ', 'Reference only', '仅供参考', '참조 전용')
t('catalog.enableVisible', '表示中の追加操作をオン', 'Enable Visible Maestro Commands', '启用当前显示的 Maestro 操作', '표시된 Maestro 작업 켜기')
t('catalog.disableVisible', '表示中の追加操作をオフ', 'Disable Visible Maestro Commands', '停用当前显示的 Maestro 操作', '표시된 Maestro 작업 끄기')
t('catalog.loadFailed', 'Keynote標準の資料を読み込めません。アプリを再インストールしてください。', 'The Keynote reference could not be loaded. Reinstall the app.', '无法载入 Keynote 参考资料。请重新安装应用。', 'Keynote 참조 자료를 불러올 수 없습니다. 앱을 다시 설치하십시오.')
t('searchCommands', '操作名・カテゴリ・標準キー・割り当てで検索', 'Search commands, categories, default or assigned keys', '搜索操作、类别、标准按键或已分配按键', '작업, 카테고리, 기본 키 또는 지정 키 검색')
t('catalog.category.general', '一般', 'General', '通用', '일반')
t('catalog.category.navigation', 'プレゼンテーション内を移動する', 'Move Within a Presentation', '在演示文稿中移动', '프레젠테이션 내에서 이동')
t('catalog.category.textSelection', 'テキストを選択する', 'Select Text', '选择文本', '텍스트 선택')
t('catalog.category.textFormat', 'テキストをフォーマットする', 'Format Text', '格式化文本', '텍스트 포맷 지정')
t('catalog.category.findComments', 'テキストを検索する/テキストを削除する/コメントを使用する/スペルをチェックする', 'Find and Delete Text, Use Comments and Check Spelling', '查找和删除文本、使用批注及检查拼写', '텍스트 찾기 및 삭제, 주석 사용, 맞춤법 검사')
t('catalog.category.objects', 'オブジェクトを移動する/グループ化する/重ねる/サイズ変更する', 'Move, Group, Layer and Resize Objects', '移动、成组、分层及调整对象大小', '객체 이동, 그룹화, 겹치기 및 크기 조절')
t('catalog.category.editableShapes', '編集可能な図形を変更する', 'Modify Editable Shapes', '修改可编辑形状', '편집 가능한 도형 수정')
t('catalog.category.tables', '表を操作する', 'Work with Tables', '处理表格', '표 사용')
t('catalog.category.chartData', 'グラフのデータを編集する', 'Edit Chart Data', '编辑图表数据', '차트 데이터 편집')
t('catalog.category.formulas', '数式でセル参照を作成する', 'Create Cell References in Formulas', '在公式中创建单元格引用', '수식에서 셀 참조 생성')
t('catalog.category.navigator', 'ナビゲータビューを使う', 'Use Navigator View', '使用导航器视图', '내비게이터 보기 사용')
t('catalog.category.lightTable', 'ライトテーブル表示を使う', 'Use Light Table View', '使用幻灯片浏览台视图', '라이트 테이블 보기 사용')
t('catalog.category.presentation', 'プレゼンテーションを再生する/発表者モードを使用する', 'Play Presentations and Use Presenter Mode', '播放演示文稿及使用演讲者模式', '프레젠테이션 재생 및 발표자 모드 사용')
t('catalog.category.video', 'プレゼンテーション中にビデオを制御する', 'Control Video During a Presentation', '在演示文稿中控制视频', '프레젠테이션 중 비디오 제어')
t('catalog.category.transition', '追加操作：トランジション', 'Additional: Transitions', '附加操作：过渡', '추가 작업: 트랜지션')
t('catalog.category.animation', '追加操作：アニメーション', 'Additional: Animations', '附加操作：动画', '추가 작업: 애니메이션')
t('catalog.category.export', '追加操作：書き出し', 'Additional: Export', '附加操作：导出', '추가 작업: 내보내기')
t('catalog.category.sweeper', '追加操作：KeynoteSweeper', 'Additional: KeynoteSweeper', '附加操作：KeynoteSweeper', '추가 작업: KeynoteSweeper')

o['helpText'] = [text + extra for text, extra in zip(o['helpText'], ['\n\n## 標準キーとの比較\n設定のホットキー一覧には、いただいた資料の14カテゴリ・341項目を参照表示します。同じ操作は標準キーとKeynoteMaestroの現在の割り当てを同じ行で比較できます。「すべて」「KeynoteMaestroの操作」「Keynote標準の操作」とカテゴリで絞り込め、標準キーも検索できます。Command・Control等の名前と⌘・⌃等の記号で検索できます。標準キーの列は読み取り専用です。システム設定等で変更した実際のキーは取得しません。複合操作は標準操作とは別の行です。トランジション・アニメーション・書き出し・KeynoteSweeperは追加カテゴリです。', '\n\n## Compare with Keynote Defaults\nThe hotkey list includes all 341 entries in the 14 categories of the supplied Japanese reference. Matching operations show the default beside your current KeynoteMaestro key. Filter by All, KeynoteMaestro or Keynote Defaults, or by category. Search includes default keys and accepts modifier names or symbols. The reference remains in Japanese and is read-only; it does not inspect macOS key overrides. Compound operations keep separate rows. Transitions, animations, export and KeynoteSweeper use additional categories.', '\n\n## 比较 Keynote 标准按键\n快捷键列表按所提供日语资料的 14 个类别显示全部 341 项操作。相同操作可在同一行比较标准按键和当前 KeynoteMaestro 按键。可按全部、KeynoteMaestro、Keynote 标准或类别筛选。搜索包括标准按键，支持修饰键名称和符号。参考资料以日语原文显示，仅供读取，不检测系统中的按键更改。复合操作单独列出；过渡、动画、导出及 KeynoteSweeper 归入附加类别。', '\n\n## Keynote 기본 키와 비교\n단축키 목록은 제공된 일본어 자료의 14개 카테고리, 341개 항목을 모두 표시합니다. 같은 작업은 기본 키와 현재 KeynoteMaestro 키를 한 행에서 비교합니다. 모두, KeynoteMaestro, Keynote 기본 작업 또는 카테고리로 필터링합니다. 기본 키 검색은 보조 키 이름과 기호를 모두 지원합니다. 참조 자료는 일본어 원문이며 읽기 전용이고 macOS에서 변경한 키는 확인하지 않습니다. 복합 작업은 별도 행으로 유지하며 트랜지션, 애니메이션, 내보내기, KeynoteSweeper는 추가 카테고리입니다.'])]
o['helpText'] = [text + extra for text, extra in zip(o['helpText'], ['\n\n標準の⌥⌘Pと重複する再生の追加割り当ては削除し、Keynoteへそのまま渡します。カラーウインドウとオブジェクトリストの同一参照行は1行にまとめます。', '\n\nThe redundant Maestro playback binding is removed; native ⌥⌘P passes through to Keynote. Identical Color window and Object List reference rows appear once.', '\n\n删除了重复的 Maestro 播放绑定，标准 ⌥⌘P 直接交给 Keynote。颜色窗口和对象列表的相同参考行仅显示一次。', '\n\n중복된 Maestro 재생 키를 제거하여 기본 ⌥⌘P를 Keynote에 그대로 전달합니다. 색상 윈도우와 객체 목록의 동일한 참조 행은 한 번만 표시합니다.'])]
o['helpText'] = [text + extra for text, extra in zip(o['helpText'], ['\n\n⌥D「同じ座標にオブジェクトの複製」は標準の複製とは別の操作です。複製後に⇧←・⇧↑を実行して左上へ10ポイント戻します。', '\n\n⌥D, Duplicate Object at Same Coordinates, is separate from native duplication. After duplicating, it sends ⇧← and ⇧↑ to move the copy 10 points left and up.', '\n\n⌥D“在相同坐标复制对象”与标准复制分开列出。复制后发送 ⇧← 和 ⇧↑，将副本向左、向上各移动 10 点。', '\n\n⌥D “같은 좌표에 객체 복제”는 기본 복제와 별도 작업입니다. 복제 후 ⇧← 및 ⇧↑로 사본을 왼쪽과 위로 각각 10포인트 이동합니다.'])]

# Separate standard presets and special bindings.
t('profiles.standard', '標準キーボードショートカットセット', 'Standard Keyboard Shortcut Set', '标准键盘快捷键集', '표준 키보드 단축키 세트')
t('profiles.special', 'スペシャルキーボードショートカット', 'Special Keyboard Shortcuts', '特殊键盘快捷键', '스페셜 키보드 단축키')
t('profiles.standardTab', '標準ショートカット', 'Standard Shortcuts', '标准快捷键', '표준 단축키')
t('profiles.specialTab', 'スペシャル', 'Special', '特殊快捷键', '스페셜')
t('profiles.standardSet', 'ショートカットセット', 'Shortcut Set', '快捷键集', '단축키 세트')
t('profiles.set.system', 'デフォルト', 'Default', '默认', '기본값')
t('profiles.set.custom', 'カスタム', 'Custom', '自定义', '사용자 설정')
t('profiles.set.custom2', 'カスタム 2', 'Custom 2', '自定义 2', '사용자 설정 2')
t('profiles.enableSpecial', 'スペシャルキーボードショートカットを有効にする', 'Enable Special Keyboard Shortcuts', '启用特殊键盘快捷键', '스페셜 키보드 단축키 활성화')
t('profiles.configureStandard', '標準ショートカットを設定…', 'Configure Standard Shortcuts…', '设置标准快捷键…', '표준 단축키 설정…')
t('profiles.configureSpecial', 'スペシャルショートカットを設定…', 'Configure Special Shortcuts…', '设置特殊快捷键…', '스페셜 단축키 설정…')
t('profiles.standardHint', 'デフォルトはKeynote本来のキーを使います。カスタムとカスタム 2は別々に保存されます。変更に対応している標準操作は32件です。', 'Default uses Keynote’s own keys. Custom and Custom 2 are saved independently. 32 standard commands support remapping.', '默认使用 Keynote 自带按键。自定义和自定义 2 独立保存。32 项标准操作支持重新分配。', '기본값은 Keynote의 원래 키를 사용합니다. 사용자 설정 두 세트는 따로 저장됩니다. 표준 작업 32개는 키를 변경할 수 있습니다.')
t('profiles.specialHint', 'KeynoteMaestro独自の追加操作を設定します。標準ショートカットセットの選択とは独立してオン・オフできます。', 'Configure KeynoteMaestro’s additional commands. Enable or disable them independently of the standard shortcut set.', '设置 KeynoteMaestro 的附加操作。可独立于标准快捷键集启用或停用。', 'KeynoteMaestro의 추가 작업을 설정합니다. 표준 단축키 세트와 별개로 켜거나 끌 수 있습니다.')
o['helpText'] = [text + extra for text, extra in zip(o['helpText'], ['\n\n## 標準セットとスペシャル\nメインウインドウで標準ショートカットセット（デフォルト／カスタム／カスタム 2）を切り替え、スペシャルを独立してオン・オフできます。標準とスペシャルの設定は別タブです。デフォルトでは標準操作の追加キーを登録せずKeynote本来のキーに任せます。カスタム2種類は標準32操作のキーとオン・オフを個別保存します。残りの標準操作は参照表示です。更新前の設定はカスタムへ引き継ぎます。スペシャル70操作の設定は標準セットの切り替えやリセットで変わりません。検索はタブごとに独立します。', '\n\n## Standard Sets and Special Shortcuts\nThe main window switches Default, Custom and Custom 2 and independently enables special shortcuts. Settings has separate standard and special tabs. Default registers no Maestro keys for standard commands, leaving Keynote’s native keys in control. Each custom set independently stores keys and on/off choices for 32 standard commands. Other native entries are reference-only. Existing settings migrate into Custom. Switching or resetting standard sets preserves all 70 special command settings. Each tab has its own search.', '\n\n## 标准快捷键集与特殊快捷键\n主窗口可切换默认、自定义、自定义 2，并独立启用特殊快捷键。设置分为标准和特殊两个标签页。默认不注册标准操作的附加按键，由 Keynote 自身处理。两个自定义集独立保存32项标准操作的按键和开关，其他标准操作仅供参考。更新前的设置迁移至自定义。切换或重设标准集不会改变70项特殊操作的设置。两个标签页分别搜索。', '\n\n## 표준 세트와 스페셜 단축키\n메인 윈도우에서 기본값과 사용자 설정 두 세트를 선택하고 스페셜 단축키를 별도로 켜거나 끕니다. 설정에는 표준과 스페셜 탭이 따로 있습니다. 기본값은 표준 작업에 Maestro 키를 등록하지 않고 Keynote 자체 키를 사용합니다. 두 사용자 세트는 표준 작업 32개의 키와 켜기/끄기를 별도로 저장합니다. 나머지 기본 작업은 참조 전용입니다. 기존 설정은 첫 사용자 세트로 이전됩니다. 표준 세트를 전환하거나 재설정해도 스페셜 작업 70개의 설정은 유지됩니다. 검색은 탭마다 독립적입니다.'])]

t('native.sent', '標準キーをKeynoteへ送信しました。', 'Sent the original key to Keynote.', '已向 Keynote 发送标准按键。', 'Keynote에 기본 키를 보냈습니다.')
t('native.mouseOnly', 'マウス操作：キー単独では割り当てできません。', 'Mouse gesture: cannot be assigned to a key alone.', '鼠标操作：无法仅用按键执行。', '마우스 동작: 키만으로 지정할 수 없습니다.')
t('native.styleRequired', 'Keynote側で対象スタイルとキーを設定してください。', 'Configure the target style and its key in Keynote.', '请在 Keynote 中设置目标样式和按键。', 'Keynote에서 대상 스타일과 키를 설정하십시오.')
t('profiles.standardHint', 'デフォルトはKeynote本来のキーを使います。カスタムとカスタム 2は別々に保存されます。キーで実行できる標準操作に割り当てを追加できます。', 'Default uses Keynote’s own keys. Custom and Custom 2 are saved independently. Assign keys to standard operations that can be performed from the keyboard.', '默认使用 Keynote 自带按键。两个自定义集独立保存，可为键盘可执行的标准操作分配按键。', '기본값은 Keynote 원래 키를 사용합니다. 두 사용자 세트는 별도로 저장되며 키보드로 실행 가능한 표준 작업에 키를 지정할 수 있습니다.')
t('catalog.referenceHint', 'Keynote標準列は原典のキーです。カスタム列で別のキーを割り当てると、前面のKeynoteへ元のキーを送信します。対象の選択や表示モードなど、元の操作と同じ前提条件が必要です。マウス操作は対象外です。', 'The Keynote Default column shows the source key. Assigning a custom key sends that original key to frontmost Keynote. The same selection, view and editing context are required. Mouse gestures are excluded.', 'Keynote 标准列显示原按键。自定义按键会向前台 Keynote 发送原按键，需要相同的选择、视图和编辑上下文。鼠标操作除外。', '기본값 열은 원래 키를 표시합니다. 사용자 키는 맨 앞 Keynote에 원래 키를 보냅니다. 동일한 선택, 보기 및 편집 상태가 필요하며 마우스 동작은 제외됩니다.')
o['helpText'] = [text + extra for text, extra in zip(o['helpText'], ['\n\n## 標準キーの割り当て\n「参照のみ」だったキー操作もカスタム／カスタム 2で変更できます。新しい欄は未設定から始まり、割り当てたキーで元の標準キーをKeynoteへ送ります。方向をまとめた操作は方向別に、スライド番号は数字別に設定します。割り当て解除で元に戻り、カスタム同士は独立保存します。マウスのみの操作とスタイルの個別指定はKeynote側で行います。元の操作と同じ選択・表示モードが必要です。メイン画面の一括スイッチは廃止し、標準セットとスペシャルを個別に設定します。', '\n\n## Assign Native Keys\nPreviously reference-only keyboard actions can be assigned in Custom or Custom 2. New fields start unassigned and send the original shortcut to Keynote. Direction groups and slide numbers have individual bindings. Clear removes the extra binding. Mouse-only gestures and individual style bindings remain in Keynote. The original selection and view context are required. The main-window master switch is replaced by standard-set selection and the special switch.', '\n\n## 分配标准按键\n原先仅供参考的键盘操作现在可在两个自定义集中分配。新字段初始未设置，触发后向 Keynote 发送原按键。方向组和幻灯片数字分别设置。清除可取消附加绑定。纯鼠标操作及具体样式设置仍在 Keynote 中进行，需要原操作的选择和视图上下文。主窗口总开关已移除，分别使用标准集选择和特殊快捷键开关。', '\n\n## 표준 키 지정\n참조 전용이던 키보드 작업도 두 사용자 세트에서 지정할 수 있습니다. 새 항목은 미설정으로 시작하며 지정한 키가 원래 키를 Keynote에 보냅니다. 방향과 슬라이드 숫자는 각각 설정합니다. 지우기로 추가 키를 해제합니다. 마우스 전용 동작과 개별 스타일은 Keynote에서 설정하고 원래 작업과 같은 선택 및 보기 상태가 필요합니다. 메인 전체 스위치는 제거되며 표준 세트와 스페셜 스위치를 각각 사용합니다.'])]
# Document-wide Auto Magic Move (default off; no existing assignment is migrated).
t('autoMagicMove.running', '自動マジックムーブ：表示対象のスライドを比較しています…', 'Automatic Magic Move: comparing shown slides…', '自动神奇移动：正在比较未跳过的幻灯片…', '자동 매직 무브: 표시할 슬라이드를 비교하는 중…')
t('autoMagicMove.done', 'マジックムーブを設定したスライド：%@枚', 'Slides set to Magic Move: %@', '已设置神奇移动的幻灯片：%@ 张', '매직 무브를 설정한 슬라이드: %@개')
t('autoMagicMove.partial', 'マジックムーブを%@枚に設定後、処理が停止しました（エラー %@）。', 'Stopped after setting Magic Move on %@ slides (error %@).', '已为 %@ 张幻灯片设置神奇移动后停止（错误 %@）。', '슬라이드 %@개에 매직 무브를 설정한 뒤 중단되었습니다(오류 %@).')
t('autoMagicMove.hint', '書類全体を対象に、次の表示スライドと共通するオブジェクトがあればマジックムーブ0.7秒を設定します。スキップ・最後の表示スライド・不一致の効果は保持。初期値オフ。', 'Across the document, apply 0.7 s Magic Move when the next shown slide shares an object. Preserve skipped, last shown and nonmatching slides. Off by default.', '在整个文稿中，若与下一个未跳过的幻灯片有共同对象，则设置 0.7 秒神奇移动。保留跳过、最后显示及不匹配幻灯片的效果。默认关闭。', '문서 전체에서 다음 표시 슬라이드와 공통 객체가 있으면 0.7초 매직 무브를 설정합니다. 건너뛴 슬라이드, 마지막 표시 슬라이드 및 불일치 효과는 유지합니다. 기본값은 꺼짐입니다.')
t('quitBusy', '処理中は終了できません。処理が終わってから終了してください。', 'Cannot quit while a task is running. Quit after it finishes.', '处理期间无法退出。请等待处理完成后退出。', '작업 중에는 종료할 수 없습니다. 작업이 끝난 후 종료하십시오.')
o['headerSubtitle'] = [text.replace('102', '103') for text in o['headerSubtitle']]
o['helpText'] = [text + extra for text, extra in zip(o['helpText'], [
    '\n\n## 自動マジックムーブ\n設定の［スペシャル］→［トランジション］でオンにし、⌃⌥⇧⌘Mを押します（キーは変更できます。初期値オフ）。前面のKeynote書類全体で、スキップされていないスライド同士を順に比較します。画像・ムービー・オーディオは種類とファイル名、図形・テキストは種類とテキスト、文字のない図形は種類と丸めた幅×高さで照合します。共通オブジェクトがある手前のスライドだけをマジックムーブ0.7秒にします。不一致の効果、スキップしたスライド、最後の表示スライドは変更しません。実行前に書類を保存または複製してください。処理中は書類を編集・閉じず、結果の設定枚数を確認してください。途中で失敗した場合は、設定済みの枚数とエラーを表示します。',
    '\n\n## Automatic Magic Move\nEnable it under Settings > Special > Transitions, then press ⌃⌥⇧⌘M (editable; off by default). Compare consecutive shown slides across the front Keynote document. Images, movies and audio match by kind and file name; shapes and text by kind and text; empty shapes by kind and rounded width × height. Apply 0.7 s Magic Move only to the earlier slide of a matching pair. Preserve nonmatching transitions, skipped slides and the last shown slide. Save or duplicate the document first. Do not edit or close it during the task. The result reports the number of slides set; partial failures report that count and an error.',
    '\n\n## 自动神奇移动\n在“设置”>“特殊快捷键”>“过渡”中启用，按 ⌃⌥⇧⌘M（可更改，默认关闭）。比较前台 Keynote 文稿中连续的未跳过幻灯片。图片、影片和音频按类型与文件名匹配；形状和文本按类型与文本匹配；无文字形状按类型与四舍五入后的宽×高匹配。仅对匹配对中前一张设置 0.7 秒神奇移动。保留不匹配的效果、跳过的幻灯片及最后一张显示的幻灯片。先保存或复制文稿，处理时勿编辑或关闭。结果显示设置张数；部分失败时显示已设置张数与错误。',
    '\n\n## 자동 매직 무브\n설정 > 스페셜 > 트랜지션에서 켠 뒤 ⌃⌥⇧⌘M을 누릅니다(키 변경 가능, 기본 꺼짐). 전면 Keynote 문서 전체에서 건너뛰지 않은 연속 슬라이드를 비교합니다. 이미지·동영상·오디오는 종류와 파일명, 도형·텍스트는 종류와 텍스트, 글자가 없는 도형은 종류와 반올림한 너비×높이로 비교합니다. 일치하는 쌍의 앞 슬라이드에만 0.7초 매직 무브를 설정합니다. 불일치 효과, 건너뛴 슬라이드, 마지막 표시 슬라이드는 유지합니다. 먼저 문서를 저장하거나 복제하고 처리 중 편집하거나 닫지 마십시오. 설정한 슬라이드 수를 표시하며 부분 실패 시 설정 수와 오류를 표시합니다.'
])]

# Keep the existing help sections consistent with the current two-control UI.
help_replacements = [
    {'メインウインドウ：「ホットキーを有効にする」ですべてのホットキーをまとめてオン・オフします。': 'メインウインドウ：標準セットを選択し、スペシャルを独立してオン・オフします。',
     'メインウインドウの「ホットキーを有効にする」がオンか': '標準セットとスペシャルの有効状態・個別操作のオンオフが適切か',
     '残りの標準操作は参照表示です。': 'キーで実行できるほかの標準操作にも割り当てを追加できます。',
     'スペシャル70操作': 'スペシャル71操作', '設定の［ホットキー］': '設定の［スペシャル］'},
    {'Main window: “Enable hotkey” turns all hotkeys on or off at once.': 'Main window: select the standard set and independently enable or disable special shortcuts.',
     '“Enable hotkey” is on in the main window.': 'the standard set, Special switch and individual command are enabled as needed.',
     'Other native entries are reference-only.': 'Other keyboard-based standard operations can also be assigned.',
     '70 special command': '71 special command'},
    {'主窗口：“启用快捷键”可一次打开或关闭所有快捷键。': '主窗口：选择标准集，并独立启用或停用特殊快捷键。',
     '主窗口中的“启用快捷键”已打开。': '标准集、特殊快捷键及对应操作的开关设置正确。',
     '其他标准操作仅供参考。': '也可为其他键盘可执行的标准操作指定按键。',
     '70项特殊操作': '71项特殊操作'},
    {"메인 윈도우: '단축키 사용'으로 모든 단축키를 한 번에 켜거나 끕니다.": '메인 윈도우: 표준 세트를 선택하고 스페셜 단축키를 별도로 켜거나 끕니다.',
     "메인 윈도우의 '단축키 사용'이 켜져 있는지": '표준 세트, 스페셜 스위치 및 해당 작업이 알맞게 켜져 있는지',
     '나머지 기본 작업은 참조 전용입니다.': '키보드로 실행할 수 있는 다른 기본 작업에도 키를 지정할 수 있습니다.',
     '스페셜 작업 70개': '스페셜 작업 71개'}
]
for index, replacements in enumerate(help_replacements):
    for old, new in replacements.items():
        o['helpText'][index] = o['helpText'][index].replace(old, new)


t('palette.shapeHeading', '図形', 'Shapes', '形状', '도형')
t('palette.whiteBackground', '選択オブジェクトに背景の図形を追加（グループ化）', 'Add Background to Selection (Group)', '为所选对象添加背景形状（组合）', '선택한 객체에 배경 도형 추가(그룹)')
t('palette.slideSizeShape', 'スライドと同じ大きさの図形を作成', 'Create a Slide-Sized Shape', '创建与幻灯片同样大小的形状', '슬라이드 크기의 도형 만들기')
t('palette.showHotkey', 'パレットを表示', 'Show Palette', '显示面板', '팔레트 표시')
t('palette.showHotkeyHint', 'Keynoteが前面のときだけ使えます。初期値は未設定。「変更…」で割り当て、「解除」で削除します。登録結果はKeynoteへ戻ったときに確認します。', 'Available only while Keynote is in front. Unassigned initially. Use Change… to assign and Clear to remove. Registration is checked when you return to Keynote.', '仅在 Keynote 位于前台时有效，初始未设置。使用“更改…”分配，“清除”移除。返回 Keynote 时检查注册结果。', 'Keynote가 앞에 있을 때만 사용하며 처음에는 지정하지 않습니다. 변경…으로 지정하고 지우기로 해제합니다. Keynote로 돌아갈 때 등록 결과를 확인합니다.')
for key, ja, en, zh, ko in [
    ('transitionDissolve', 'ディゾルブ', 'Dissolve', '叠化', '디졸브'),
    ('transitionNone', 'なし', 'None', '无', '없음'),
    ('transitionMagicMove', 'マジックムーブ', 'Magic Move', '神奇移动', '매직 무브'),
    ('autoMagicMove', '自動マジックムーブ', 'Auto Magic Move', '自动神奇移动', '자동 매직 무브'),
    ('fillWidth', '幅いっぱい', 'Full Width', '填满宽度', '전체 너비'),
    ('fillHeight', '高さいっぱい', 'Full Height', '填满高度', '전체 높이'),
    ('width80', '幅80%', '80% Width', '宽度80%', '너비 80%'),
    ('sameHeight', '高さ（最大）', 'Height (Largest)', '高度（最大）', '높이(최대)'),
    ('sameWidth', '幅（最大）', 'Width (Largest)', '宽度（最大）', '너비(최대)'),
    ('sameWidthNarrowest', '幅（最小）', 'Width (Smallest)', '宽度（最小）', '너비(최소)'),
    ('copyAnimation', 'アニメーションをコピー', 'Copy Animation', '拷贝动画', '애니메이션 복사'),
    ('pasteAnimation', 'アニメーションをペースト', 'Paste Animation', '粘贴动画', '애니메이션 붙여넣기'),
    ('slideSizeShape', 'スライド大の図形', 'Slide-Sized Shape', '幻灯片大小形状', '슬라이드 크기 도형'),
    ('whiteBackground', '背景追加・グループ化', 'Add Background & Group', '添加背景并组合', '배경 추가 및 그룹'),
]: t('palette.button.' + key, ja, en, zh, ko)
t('palette.tab', 'パレット', 'Palette', '面板', '팔레트')
t('palette.transitionHeading', 'トランジション', 'Transitions', '过渡', '트랜지션')
t('palette.centerHeading', '中央', 'Centered', '居中', '가운데')
t('palette.alignHeading', 'オブジェクトの揃え', 'Match Object Sizes', '统一对象大小', '객체 크기 맞추기')
t('palette.animationHeading', 'アニメーション', 'Animation', '动画', '애니메이션')
t('palette.settings', 'パレットの設定…', 'Palette Settings…', '面板设置…', '팔레트 설정…')
t('palette.empty', '表示する項目がありません。設定から項目を選んでください。', 'No items are visible. Choose items in Palette Settings.', '没有显示的项目。请在面板设置中选择项目。', '표시할 항목이 없습니다. 팔레트 설정에서 항목을 선택하십시오.')
t('palette.visibilityHint', 'パレットに表示するボタンを選択します。初期値はすべて表示。変更はすぐに反映され、再起動後も保持されます。ホットキーの有効状態やキー割り当ては変更しません。', 'Choose which buttons appear in the palette. All are visible initially. Changes apply immediately and persist after restart, independently of hotkey enable states and assignments.', '选择面板中显示的按钮。初始显示全部。更改立即生效并在重启后保留，与快捷键启用状态和分配独立。', '팔레트에 표시할 버튼을 선택합니다. 처음에는 모두 표시합니다. 변경은 즉시 적용되고 재시작 후 유지되며 단축키 활성화와 지정은 바꾸지 않습니다.')
t('palette.showAll', 'すべて表示', 'Show All', '全部显示', '모두 표시')
t('palette.hideAll', 'すべて非表示', 'Hide All', '全部隐藏', '모두 숨기기')
t('palette.transitionDissolve', 'ディゾルブ', 'Dissolve', '叠化', '디졸브')
t('palette.transitionNone', 'なし', 'None', '无', '없음')
t('palette.transitionMagicMove', 'マジックムーブ', 'Magic Move', '神奇移动', '매직 무브')
t('palette.title', 'Keynoteパレット', 'Keynote Palette', 'Keynote 面板', 'Keynote 팔레트')
t('palette.open', 'パレットを開く', 'Open Palette', '打开面板', '팔레트 열기')
t('palette.target', 'Keynoteで対象の書類とオブジェクトを選択してください。', 'Select the document and objects in Keynote.', '请在 Keynote 中选择目标文稿和对象。', 'Keynote에서 대상 문서와 객체를 선택하십시오.')
for key, ja, en, zh, ko in [
    ('autoMagicMove', 'マジックムーブ（自動）', 'Magic Move (Automatic)', '神奇移动（自动）', '매직 무브(자동)'),
    ('fillWidth', 'スライドの幅いっぱい', 'Fit Slide Width', '填满幻灯片宽度', '슬라이드 너비에 맞추기'),
    ('fillHeight', 'スライドの高さいっぱい', 'Fit Slide Height', '填满幻灯片高度', '슬라이드 높이에 맞추기'),
    ('width80', 'スライドの幅の80%', '80% of Slide Width', '幻灯片宽度的 80%', '슬라이드 너비의 80%'),
    ('sameHeight', '同じ高さに（最大）', 'Same Height (Largest)', '相同高度（最大）', '같은 높이로(최대)'),
    ('sameWidth', '同じ幅に（最大）', 'Same Width (Largest)', '相同宽度（最大）', '같은 너비로(최대)'),
    ('sameWidthNarrowest', '同じ幅に（最小）', 'Same Width (Smallest)', '相同宽度（最小）', '같은 너비로(최소)'),
    ('copyAnimation', 'アニメーションをコピー', 'Copy Animation', '拷贝动画', '애니메이션 복사'),
    ('pasteAnimation', 'アニメーションをペースト', 'Paste Animation', '粘贴动画', '애니메이션 붙여넣기'),
]: t('palette.' + key, ja, en, zh, ko)
for index, section in enumerate([
    "\n\n## パレット\nメイン画面・ファイルメニュー・メニューバーメニューの「パレットを開く」から表示します。閉じるボタンで閉じ、同じ入口から再表示できます。位置を保存し、画面外なら中央へ戻します。パレットをクリックしてもKeynoteの選択を保ちます。Keynoteを前面にして対象書類・オブジェクトを選んでください。他アプリ・権限なし・一時停止・処理中は実行しません。ホットキーの個別オンオフとボタン操作は独立しています。「パレットを表示」のキーを設定で指定できます。初期値は未設定で、Keynoteが前面のときだけ有効です。表示中なら同じパレットを手前に戻します。ボタンの短い表記の正式名はツールチップで確認できます。「トランジション」にディゾルブ・なし・マジックムーブ・マジックムーブ（自動）、「中央」に3項目、「オブジェクトの揃え」に3項目、その後にアニメーションのコピー/ペーストを表示します。通常と自動のマジックムーブは別操作です。設定の「パレット」で14ボタンの表示を個別に選択でき、初期値はすべて表示です。空のグループは見出しと不要な区切りを隠します。全項目OFFでもパレットの設定ボタンから戻せます。「スライドと同じ大きさの図形を作成」は対象スライドと同じ幅・高さの図形を1個作成します。その次の「選択オブジェクトに背景の図形を追加（グループ化）」は元の選択と同じ大きさの背景1個を背面に作り、その2個だけをグループ化します。\n標準ショートカットの設定は初期820×620ポイント、最小720×560ポイントで、一覧を縦スクロールできます。\n背景図形の追加（グループ化）は1つのトップレベルオブジェクトを選択し、背景1個を作成して背面に送り、元の選択とだけグループ化します。背景の既定スタイルは変更しません。",
    "\n\n## Palette\nChoose Open Palette in the main window, File menu or menu bar menu. Close it with its close button and reopen it from the same entry. Its position is saved and restored onscreen. Clicking it preserves the Keynote selection. Bring Keynote forward and select the target document and objects. Actions stop for other apps, missing permissions, pause or an operation in progress. Buttons are independent of individual hotkey enable switches. Assign Show Palette in Palette Settings; it is initially unassigned and works only in Keynote. When already visible, the same palette is brought forward. Tooltips provide full names for the shortened button labels. Transitions contains Dissolve, None, Magic Move and Magic Move (Automatic); Centered has three slide-size actions, Match Object Sizes has three actions, followed by Copy/Paste Animation. Regular and automatic Magic Move are distinct. Settings > Palette selects the 14 visible buttons, all initially shown. Empty groups hide their headings and redundant dividers. Palette Settings remains available when all items are hidden. Create a Slide-Sized Shape makes exactly one shape matching the target slide width and height. The following Add Background to Selection (Group) creates one background behind the original selection and groups exactly those two objects.\nStandard shortcut settings start at 820×620 points, with a 720×560 minimum and vertical scrolling.\nAdd Background (Group) requires one top-level object. It creates one background, sends it behind, and groups only the original and background. Its default style is preserved.",
    "\n\n## 面板\n从主窗口、文件菜单或菜单栏菜单选择“打开面板”。可关闭并从相同入口重新打开。位置会保存，超出屏幕时返回中央。点击面板保留 Keynote 选择。请将 Keynote 置于前台并选择目标文稿和对象。其他应用、缺少权限、暂停或处理中不执行。按钮与各快捷键的启用状态独立，可在面板设置中分配“显示面板”，初始未设置且仅在 Keynote 中有效。已显示时将同一面板移到前面。短按钮名的完整名称可通过工具提示查看。“过渡”包含叠化、无、神奇移动和神奇移动（自动），“居中”包含三项幻灯片大小操作，“统一对象大小”包含三项操作，之后是拷贝/粘贴动画。普通和自动神奇移动是不同操作。在“设置”的“面板”中可分别选择14个按钮的显示，初始全部显示。空组隐藏标题和多余分隔线。全部隐藏后仍可打开面板设置重新显示。幻灯片大小按钮创建一个与目标幻灯片同样宽高的形状。其后的背景按钮在原对象后方创建一个同样大小的背景，并仅组合这两个对象。\n标准快捷键设置初始为 820×620 点，最小 720×560 点，列表可垂直滚动。\n添加背景（组合）要求选择一个顶层对象。创建一个背景并发送到后面，仅组合原对象和背景。保留背景的默认样式。",
    "\n\n## 팔레트\n메인 윈도우, 파일 메뉴 또는 메뉴 막대 메뉴에서 팔레트 열기를 선택합니다. 닫기 버튼으로 닫고 같은 항목에서 다시 엽니다. 위치를 저장하고 화면 밖이면 중앙으로 돌립니다. 팔레트를 클릭해도 Keynote 선택을 유지합니다. Keynote를 앞으로 가져와 대상 문서와 객체를 선택하십시오. 다른 앱, 권한 없음, 일시 정지 또는 처리 중에는 실행하지 않습니다. 버튼은 개별 단축키 활성화와 독립적이며 팔레트 설정에서 팔레트 표시 키를 지정할 수 있으며 처음에는 미지정이고 Keynote에서만 작동합니다. 이미 표시 중이면 같은 팔레트를 앞으로 가져옵니다. 짧은 버튼 이름의 전체 이름은 도구 설명에 표시합니다. 트랜지션에는 디졸브, 없음, 매직 무브, 매직 무브(자동), 가운데에는 슬라이드 크기 작업 3개, 객체 크기 맞추기에는 3개, 그 뒤에 애니메이션 복사/붙여넣기를 표시합니다. 일반 매직 무브와 자동은 별도 작업입니다. 설정의 팔레트에서 14개 버튼 표시를 선택하며 처음에는 모두 표시합니다. 빈 그룹은 제목과 불필요한 구분선을 숨깁니다. 모두 숨겨도 팔레트 설정에서 다시 표시할 수 있습니다. 슬라이드 크기 버튼은 대상 슬라이드와 너비·높이가 같은 도형 하나를 만듭니다. 다음 배경 버튼은 원본 뒤에 같은 크기의 배경 하나를 만들고 그 둘만 그룹화합니다.\n표준 단축키 설정은 초기 820×620포인트, 최소 720×560포인트이며 목록은 세로 스크롤됩니다.\n배경 추가(그룹)는 최상위 객체 하나를 선택해야 합니다. 배경 하나를 만들고 뒤로 보낸 후 원본과 배경만 그룹화합니다. 배경 기본 스타일을 유지합니다."
]): o['helpText'][index] += section

Path(__file__).with_name('own.json').write_text(json.dumps(o, ensure_ascii=False))
