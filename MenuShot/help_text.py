# MenuShot help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
MenuShotは、メニューバーと開いたメニューだけを、背景（デスクトップやほかのウインドウ）なしで1枚のPNGに撮ります。メニューの外側は透明になります。
- ［N秒後に撮影］をクリックし、数えている間に撮りたいアプリのメニューを開きます。0になると撮影します。秒数（0〜10秒）はボタンの右の矢印で変えられます（設定の「撮影までの秒数」と同じ値）。
- メニューを開いたまま撮影のホットキー（初期値 ⌃⌥⇧⌘4）を押すと、すぐに撮影します。メニューが開いていないときに押すと、撮影までの秒数を数えます。
- メニューバーのアイコンを表示している場合は、そのメニューの［N秒後に撮影］からも始められます。
- 数えている間は［キャンセル］またはEscで取りやめます。
撮った画像はメインウインドウに表示され、［Finderで表示］で保存したファイルを選んで表示します（Path Finderが起動中ならPath Finderで。初回はオートメーションの許可を求められます）。画像はウインドウからドラッグしてほかのアプリへ渡せます。

## 写る範囲
- メニューバーから開いたメニュー：メニューバーと、開いているメニュー（サブメニューも含む）。横幅は設定の「写す範囲」で選びます（メニューバーの左端からメニューの右まで／メニューの幅だけ／メニューバー全体）。
- 右クリックのメニューやポップアップボタンのメニューなど、メニューバーから離れたメニュー：メニューだけ。
- 影は、メニューの形に合わせてMenuShotが描きます（設定でオフにできます）。
- 画像はRetinaの解像度のまま保存し、PNGの解像度（144dpiなど）を画面と同じ大きさになるように付けます。

## 設定
［MenuShot］＞［設定…］（⌘,）で開きます。
- 起動・常駐：ログイン時に起動、Dockとアプリケーションスイッチャーに表示しない、ウインドウを閉じても常駐、メニューバーのアイコン、アプリ起動のホットキー、アプリを呼び出すホットキー（初期値は未設定）、画面収録の許可状態。
- 撮影：撮影のホットキー、入力監視（許可するとメニューを開いたままホットキーで撮れます）、撮影までの秒数（0〜10秒、初期値3秒）、写す範囲、メニューに影を付ける。
- 出力：保存先（初期値はmacOSのスクリーンショットと同じ）、クリップボードにもコピー、撮影の音を鳴らす、撮影した範囲を点滅させる（初期値オン。「視差効果を減らす」がオンのときは点滅だけでフェードしません）、Quick Lookで開く（初期値オフ。オンにすると撮影後にMenuShotが前面になり、Quick Lookのパネルで画像を開きます。Escまたはスペースで閉じます）。
- 設定の共有：設定の書き出し・読み込みと同期。
- 情報：バージョンとリンク。

## ホットキー
- ⌃⌥⇧⌘4：撮影（どのアプリからでも。設定の「撮影」で変更・無効化できます）
- Return：撮影を始める（メインウインドウ）
- Esc：数えている撮影を取りやめる（メインウインドウ）
- ⌘0：メインウインドウを開く
- ⌘,：設定
- ⌘W：ウインドウを閉じる
- ⌘?：このヘルプ

## 権限
撮影には「画面収録とシステムオーディオ録音」の許可が必要です。メニューを開いたままホットキーで撮るには、設定の［撮影］で「入力監視」も許可します（ほかのアプリがメニューを表示している間は、ふつうのホットキーが届かないため）。キーは撮影のホットキーと照らし合わせるだけで、記録も送信もしません。未許可でも、メニューが閉じているときのホットキーと［N秒後に撮影］は使えます。初めて撮影するときにmacOSの確認が出ます。許可したあとはMenuShotを開き直してください。設定の［起動・常駐］の「画面収録」に状態が表示され、「画面収録の設定を開く」から設定できます。MenuShotが撮るのはメニューバーとメニューのウインドウだけで、画像は指定した保存先にだけ書き出します。外部への送信はしません。

## 保存とクリップボード
ファイル名は「メニュー 2026-10-26 2.10.33.png」の形式です。同じ名前があるときは番号を付け、既存のファイルを上書きしません。「クリップボードにもコピー」がオンのときは、保存したものと同じ画像をクリップボードに入れます（それまでのクリップボードの内容は置き換わります）。

## 常駐と終了
「ウインドウを閉じても常駐」がオンのときは、ウインドウを閉じても動き続け、撮影のホットキーも使えます。DockやFinderからMenuShotを開き直すか、メニューバーのアイコンからウインドウを表示できます。終了するには［MenuShot］＞［MenuShotを終了］（⌘Q）を選びます。

## 困ったときは
- 「開いているメニューが見つかりませんでした」：撮影の瞬間にメニューが開いている必要があります。秒数を増やすか、メニューを開いたままホットキーを押してください。
- 「画面収録が許可されていません」：システム設定＞プライバシーとセキュリティ＞画面収録とシステムオーディオ録音でMenuShotをオンにし、MenuShotを開き直します。
- ホットキーが効かない：メニューを開いたまま押すときは、設定の［撮影］で「入力監視」を許可してください。メニューが無いときも効かない場合は、ほかのアプリが同じキーを使っている可能性があります。設定の「撮影」で別のキーにしてください。
- メニューバーの背景が透明になる：macOS 26の「メニューバーの背景を表示」がオフのときは、メニューバーの文字だけが写ります。
- メニューバーのアイコンの一部が写らない：Bartenderなど、メニューバーを覆うアプリの表示は写りません。
- 削除：MenuShotを終了し、アプリケーションフォルダからゴミ箱に入れます。撮った画像は保存先に残ります。
""",
 "en": """## Basics
MenuShot captures only the menu bar and the open menus into one PNG, without the background (the desktop and other windows). Everything outside the menus is transparent.
- Click Capture in N s, then open the menu you want while it counts down. It captures at 0. Change the seconds (0–10) with the arrows to the right of the button (the same value as Delay in Settings).
- With a menu open, press the capture hotkey (⌃⌥⇧⌘4 by default) to capture at once. Pressed with no menu open, it counts down the delay.
- If the menu bar icon is shown, you can also start from Capture in N s in its menu.
- While counting down, click Cancel or press Esc to stop.
The picture appears in the main window; Show in Finder selects the saved file (in Path Finder when it is running; the first time, macOS asks for Automation permission). Drag the picture from the window into other apps.

## What is captured
- A menu opened from the menu bar: the menu bar and the open menus (submenus included). Choose the width under Range in Settings (from the left of the menu bar to the right of the menu, only the width of the menu, or the whole menu bar).
- Menus away from the menu bar, such as contextual menus or pop-up button menus: only the menus.
- MenuShot draws the shadow around the menus (it can be turned off in Settings).
- Pictures keep the Retina resolution, with the PNG resolution (such as 144 dpi) set so they open at their on-screen size.

## Settings
Choose MenuShot > Settings… (⌘,).
- Startup & Background: open at login, hide from Dock and App Switcher, keep running after closing the window, menu bar icon, app launch keyboard shortcut, show-app hotkey (not set by default), Screen Recording status.
- Capture: capture hotkey, Input Monitoring (allow it to use the hotkey with a menu open), delay (0–10 s, 3 s by default), range, add a shadow to the menu.
- Output: save folder (by default the same as macOS screenshots), also copy to the clipboard, play the capture sound, flash the captured area (on by default; with Reduce Motion it flashes without fading), open in Quick Look (off by default; when on, MenuShot comes to the front after capturing and shows the picture in the Quick Look panel; close it with Esc or Space).
- Settings Sharing: export, import and sync settings.
- About: version and links.

## Hotkeys
- ⌃⌥⇧⌘4: capture (from any app; change or turn off under Capture in Settings)
- Return: start capturing (main window)
- Esc: cancel the countdown (main window)
- ⌘0: Open Main Window
- ⌘,: Settings
- ⌘W: Close Window
- ⌘?: this help

## Permissions
Capturing needs Screen & System Audio Recording permission. To use the hotkey with a menu open, also allow Input Monitoring under Capture in Settings (ordinary hotkeys do not arrive while another app shows a menu). Keys are only compared with the capture hotkey, never recorded or sent. Without it, the hotkey still works with no menu open, and so does Capture in N s. macOS asks the first time you capture. Reopen MenuShot after allowing it. The status is shown under Screen Recording in Settings > Startup & Background, with Open Screen Recording Settings. MenuShot captures only the menu bar and menu windows and writes pictures only to the chosen folder. Nothing is sent anywhere.

## Saving and the clipboard
Files are named like “Menu 2026-10-26 2.10.33.png”. When the name exists, a number is added; existing files are never overwritten. With Also copy to the clipboard on, the same picture goes to the clipboard (replacing what was there).

## Keeping it running and quitting
With Keep running after closing the window on, MenuShot keeps running after you close the window, and the capture hotkey still works. Reopen it from the Dock or Finder, or show the window from the menu bar icon. To quit, choose MenuShot > Quit MenuShot (⌘Q).

## Troubleshooting
- “No open menu was found”: a menu must be open at the moment of capture. Increase the delay, or press the hotkey with the menu open.
- “Screen Recording is not allowed”: turn on MenuShot in System Settings > Privacy & Security > Screen & System Audio Recording, then reopen MenuShot.
- The hotkey does nothing: to press it with a menu open, allow Input Monitoring under Capture in Settings. If it does nothing even with no menu open, another app may use the same key; choose another key under Capture in Settings.
- The menu bar background is transparent: when Show menu bar background is off in macOS 26, only the menu bar text is captured.
- Some menu bar icons are missing: what apps such as Bartender draw over the menu bar is not captured.
- Uninstall: quit MenuShot and move it from Applications to the Trash. Captured pictures stay in the save folder.
""",
 "zh-Hans": """## 基本操作
MenuShot 仅将菜单栏和打开的菜单截取为一张 PNG，不含背景（桌面和其他窗口）。菜单以外的部分为透明。
- 点按“N 秒后截取”，在倒数期间打开要截取的应用菜单。倒数到 0 时截取。秒数（0–10 秒）可用按钮右侧的箭头更改（与设置中的“延迟”相同）。
- 在菜单打开时按截取快捷键（默认 ⌃⌥⇧⌘4）会立即截取。没有打开的菜单时按下，会倒数延迟秒数。
- 如果显示了菜单栏图标，也可以从其菜单中的“N 秒后截取”开始。
- 倒数期间点按“取消”或按 Esc 可停止。
截取的图像会显示在主窗口中，点按“在访达中显示”会选中存储的文件（Path Finder 运行时在 Path Finder 中；首次会请求自动化权限）。可以将图像从窗口拖到其他应用。

## 截取范围
- 从菜单栏打开的菜单：菜单栏和打开的菜单（包括子菜单）。宽度在设置的“范围”中选择（从菜单栏左端到菜单右侧／仅菜单的宽度／整个菜单栏）。
- 远离菜单栏的菜单（如右键菜单或弹出按钮的菜单）：仅菜单。
- 阴影由 MenuShot 按菜单的形状绘制（可在设置中关闭）。
- 图像保持 Retina 分辨率，并设置 PNG 分辨率（如 144 dpi），使其以屏幕上的大小打开。

## 设置
选取“MenuShot”>“设置…”（⌘,）。
- 启动与后台：登录时启动、在程序坞和应用切换器中隐藏、关闭窗口后继续运行、菜单栏图标、启动应用快捷键、显示应用快捷键（默认未设置）、录屏权限状态。
- 截取：截取快捷键、输入监控（允许后可在菜单打开时用快捷键截取）、延迟（0–10 秒，默认 3 秒）、范围、为菜单添加阴影。
- 输出：存储位置（默认与 macOS 截屏相同）、同时拷贝到剪贴板、播放截取声音、闪烁截取的区域（默认打开。打开“减弱动态效果”时只闪烁不渐隐）、用快速查看打开（默认关闭。打开后，截取完成时 MenuShot 会来到前台，并在快速查看面板中打开图像。按 Esc 或空格键关闭）。
- 设置共享：导出、导入和同步设置。
- 关于：版本和链接。

## 快捷键
- ⌃⌥⇧⌘4：截取（在任何应用中。可在设置的“截取”中更改或关闭）
- Return：开始截取（主窗口）
- Esc：取消倒数（主窗口）
- ⌘0：打开主窗口
- ⌘,：设置
- ⌘W：关闭窗口
- ⌘?：本帮助

## 权限
截取需要“录屏与系统录音”权限。若要在菜单打开时用快捷键截取，还需在设置的“截取”中允许“输入监控”（其他应用显示菜单时普通快捷键无法送达）。按键仅与截取快捷键比对，不会记录或发送。未允许时，没有打开菜单时的快捷键和“N 秒后截取”仍可使用。首次截取时 macOS 会询问。允许后请重新打开 MenuShot。设置的“启动与后台”中的“录屏”会显示状态，并可通过“打开录屏设置”进行设置。MenuShot 仅截取菜单栏和菜单窗口，图像只写入所选的存储位置，不会向外部发送任何内容。

## 存储与剪贴板
文件名格式为“菜单 2026-10-26 2.10.33.png”。存在同名文件时会加上编号，不会覆盖已有文件。打开“同时拷贝到剪贴板”时，会将与存储内容相同的图像放入剪贴板（替换原有内容）。

## 后台运行与退出
打开“关闭窗口后继续运行”时，关闭窗口后 MenuShot 仍会运行，截取快捷键也可使用。可从程序坞或访达重新打开，或从菜单栏图标显示窗口。要退出，请选取“MenuShot”>“退出 MenuShot”（⌘Q）。

## 疑难解答
- “未找到打开的菜单”：截取时菜单必须处于打开状态。请增加延迟，或在菜单打开时按快捷键。
- “未允许录屏”：在系统设置 > 隐私与安全性 > 录屏与系统录音中打开 MenuShot，然后重新打开 MenuShot。
- 快捷键无效：若要在菜单打开时按下，请在设置的“截取”中允许“输入监控”。没有打开菜单时也无效的话，可能有其他应用使用了相同的按键，请在设置的“截取”中改用其他按键。
- 菜单栏背景为透明：macOS 26 中“显示菜单栏背景”关闭时，只会截取菜单栏的文字。
- 部分菜单栏图标未截取：Bartender 等覆盖菜单栏的应用所绘制的内容不会被截取。
- 删除：退出 MenuShot，并将其从“应用程序”文件夹移到废纸篓。截取的图像会保留在存储位置。
""",
 "ko": """## 기본 조작
MenuShot은 메뉴 막대와 열린 메뉴만 배경(데스크탑과 다른 윈도우) 없이 하나의 PNG로 캡처합니다. 메뉴 바깥은 투명해집니다.
- 'N초 후 캡처'를 클릭하고 카운트다운 동안 캡처할 앱의 메뉴를 엽니다. 0이 되면 캡처합니다. 초(0–10초)는 버튼 오른쪽의 화살표로 바꿀 수 있습니다(설정의 '대기 시간'과 같은 값).
- 메뉴를 연 채 캡처 단축키(기본값 ⌃⌥⇧⌘4)를 누르면 바로 캡처합니다. 열린 메뉴가 없을 때 누르면 대기 시간을 셉니다.
- 메뉴 막대 아이콘을 표시한 경우 그 메뉴의 'N초 후 캡처'로도 시작할 수 있습니다.
- 카운트다운 중에는 '취소'를 클릭하거나 Esc를 눌러 중지합니다.
캡처한 이미지는 메인 윈도우에 표시되며, 'Finder에서 보기'로 저장한 파일을 선택해 보여 줍니다(Path Finder가 실행 중이면 Path Finder에서. 처음에는 자동화 권한을 요청합니다). 이미지를 윈도우에서 다른 앱으로 드래그할 수 있습니다.

## 캡처 범위
- 메뉴 막대에서 연 메뉴: 메뉴 막대와 열린 메뉴(하위 메뉴 포함). 너비는 설정의 '범위'에서 선택합니다(메뉴 막대 왼쪽 끝부터 메뉴 오른쪽까지／메뉴 너비만／메뉴 막대 전체).
- 메뉴 막대에서 떨어진 메뉴(오른쪽 클릭 메뉴, 팝업 버튼 메뉴 등): 메뉴만.
- 그림자는 MenuShot이 메뉴 모양에 맞춰 그립니다(설정에서 끌 수 있습니다).
- 이미지는 Retina 해상도를 유지하며, 화면과 같은 크기로 열리도록 PNG 해상도(144dpi 등)를 지정합니다.

## 설정
'MenuShot' > '설정…'(⌘,)을 선택합니다.
- 시작 및 백그라운드: 로그인 시 실행, Dock 및 앱 전환기에서 숨기기, 윈도우를 닫아도 계속 실행, 메뉴 막대 아이콘, 앱 실행 키보드 단축키, 앱 표시 단축키(기본값은 설정되지 않음), 화면 기록 권한 상태.
- 캡처: 캡처 단축키, 입력 모니터링(허용하면 메뉴를 연 채 단축키로 캡처), 대기 시간(0–10초, 기본값 3초), 범위, 메뉴에 그림자 추가.
- 출력: 저장 위치(기본값은 macOS 스크린샷과 같음), 클립보드에도 복사, 캡처 소리 재생, 캡처한 영역 깜박이기(기본값 켬. '동작 줄이기'가 켜져 있으면 페이드 없이 깜박임), 훑어보기로 열기(기본값 끔. 켜면 캡처 후 MenuShot이 앞으로 오고 훑어보기 패널에서 이미지를 엽니다. Esc나 스페이스 바로 닫습니다).
- 설정 공유: 설정 내보내기, 가져오기 및 동기화.
- 정보: 버전과 링크.

## 단축키
- ⌃⌥⇧⌘4: 캡처(어느 앱에서든. 설정의 '캡처'에서 변경하거나 끌 수 있습니다)
- Return: 캡처 시작(메인 윈도우)
- Esc: 카운트다운 취소(메인 윈도우)
- ⌘0: 메인 윈도우 열기
- ⌘,: 설정
- ⌘W: 윈도우 닫기
- ⌘?: 이 도움말

## 권한
캡처하려면 '화면 및 시스템 오디오 녹음' 권한이 필요합니다. 메뉴를 연 채 단축키로 캡처하려면 설정의 '캡처'에서 '입력 모니터링'도 허용하세요(다른 앱이 메뉴를 표시하는 동안에는 일반 단축키가 전달되지 않음). 키는 캡처 단축키와 비교만 하며 기록하거나 전송하지 않습니다. 허용하지 않아도 메뉴가 닫혀 있을 때의 단축키와 'N초 후 캡처'는 사용할 수 있습니다. 처음 캡처할 때 macOS가 확인을 요청합니다. 허용한 후 MenuShot을 다시 여세요. 설정의 '시작 및 백그라운드'에 있는 '화면 기록'에 상태가 표시되며, '화면 기록 설정 열기'로 설정할 수 있습니다. MenuShot은 메뉴 막대와 메뉴 윈도우만 캡처하고, 이미지는 지정한 저장 위치에만 저장합니다. 외부로 전송하지 않습니다.

## 저장과 클립보드
파일 이름은 '메뉴 2026-10-26 2.10.33.png' 형식입니다. 같은 이름이 있으면 번호를 붙이고 기존 파일을 덮어쓰지 않습니다. '클립보드에도 복사'가 켜져 있으면 저장한 것과 같은 이미지를 클립보드에 넣습니다(기존 내용은 바뀝니다).

## 백그라운드 실행과 종료
'윈도우를 닫아도 계속 실행'이 켜져 있으면 윈도우를 닫아도 MenuShot이 계속 실행되며 캡처 단축키도 쓸 수 있습니다. Dock이나 Finder에서 MenuShot을 다시 열거나 메뉴 막대 아이콘에서 윈도우를 표시할 수 있습니다. 종료하려면 'MenuShot' > 'MenuShot 종료'(⌘Q)를 선택합니다.

## 문제 해결
- '열린 메뉴를 찾지 못했습니다': 캡처하는 순간 메뉴가 열려 있어야 합니다. 대기 시간을 늘리거나 메뉴를 연 채 단축키를 누르세요.
- '화면 기록이 허용되지 않았습니다': 시스템 설정 > 개인정보 보호 및 보안 > 화면 및 시스템 오디오 녹음에서 MenuShot을 켜고 MenuShot을 다시 여세요.
- 단축키가 작동하지 않음: 메뉴를 연 채 누르려면 설정의 '캡처'에서 '입력 모니터링'을 허용하세요. 메뉴가 없을 때도 작동하지 않으면 다른 앱이 같은 키를 사용하고 있을 수 있으니 설정의 '캡처'에서 다른 키로 바꾸세요.
- 메뉴 막대 배경이 투명함: macOS 26에서 '메뉴 막대 배경 표시'가 꺼져 있으면 메뉴 막대의 글자만 캡처됩니다.
- 메뉴 막대 아이콘 일부가 캡처되지 않음: Bartender 등 메뉴 막대를 덮는 앱이 그리는 내용은 캡처되지 않습니다.
- 삭제: MenuShot을 종료하고 응용 프로그램 폴더에서 휴지통으로 옮깁니다. 캡처한 이미지는 저장 위치에 남습니다.
""",
}

for _lang, _text in {
'ja': '\nメニュー経路\n撮影直前の選択メニューを読み取ります。設定の［出力］→［メニュー経路］で7形式と「をクリック」の有無を選択・保存します。ショートカット後は［撮影］［テキストのみ］を選びます。テキストのみは画像を保存せずコピーします。末尾除去機能はありません。起動・常駐のアクセシビリティ設定から権限を許可してください。未許可や未選択の場合は経路を取得できません。コマンドは実行しません。',
'en': '\nMenu Path\nThe selected path is read before capture. Choose one of seven formats and the optional Japanese click suffix in Settings > Output > Menu Path. After the hotkey choose Capture or Text Only (no image saved). Trailing text is preserved. Grant Accessibility permission in Startup settings. Unavailable paths cannot be copied. No command is executed.',
'zh-Hans': '\n菜单路径\n截图前读取选中的路径。在设置的输出中选择七种格式和日文点击后缀。快捷键后选择拍摄或仅文本。仅文本不保存图片。不会移除末尾文字。请在启动设置中授予辅助功能权限。不会执行命令。',
'ko': '\n메뉴 경로\n촬영 전 선택 경로를 읽습니다. 설정의 출력에서 일곱 형식과 일본어 클릭 안내를 선택합니다. 단축키 후 촬영 또는 텍스트만을 선택합니다. 텍스트만은 이미지를 저장하지 않습니다. 끝 문자열을 제거하지 않습니다. 시작 설정에서 손쉬운 사용 권한을 허용하세요. 명령은 실행하지 않습니다.'
}.items():
    HELP[_lang] += _text + '\n'

for _lang in HELP:
    HELP[_lang] += "\n" + {"ja": "入力監視は起動・常駐にあります。アプリ呼出用の内蔵ホットキーは削除され、撮影用のみ使用します。", "en": "Input Monitoring is in Startup settings. Only the capture hotkey is registered; the app invocation hotkey is removed.", "zh-Hans": "输入监控位于启动设置。仅保留拍摄快捷键，已移除唤起应用快捷键。", "ko": "입력 모니터링은 시작 설정에 있습니다. 앱 호출 단축키를 제거하고 촬영 단축키만 사용합니다."}[_lang] + "\n"
