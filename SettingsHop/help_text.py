# SettingsHop help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
SettingsHopのウインドウで項目をクリックすると、システム設定のその画面を開きます。
- システム設定（⌘1）：システム設定を開きます。すでに開いているときは、最後に表示していた画面のまま前面に出ます。
- プライバシーとセキュリティ：一番上から表示します（アクセシビリティが許可されていない場合は、前回見ていた場所から表示されることがあります）
- アクセシビリティ（⌘2）
- フルディスクアクセス（⌘3）
- ファイルとフォルダ（⌘4）
- 画面収録とシステムオーディオ録音（⌘5）
- 入力監視
- オートメーション
- セキュリティ：プライバシーとセキュリティの下の方の「セキュリティ」欄（アプリケーションの実行許可・FileVaultなど）
- ログイン項目（⌘6）：一般＞ログイン項目と機能拡張
- デフォルトのWebブラウザ（⌘7）：デスクトップとDockを開き、アクセシビリティが許可されていれば「デフォルトのWebブラウザ」の行までスクロールし、ブラウザを選ぶメニューを開きます。

## Option＋クリック
アクセシビリティ（⌘2）・フルディスクアクセス（⌘3）・画面収録とシステムオーディオ録音（⌘5）・入力監視は、Optionを押しながらクリック（またはOption＋Return、⌥＋数字、⌘⌥＋数字）すると、直前に使っていたアプリの行を選んだ状態で開きます。たとえば作業中のアプリで⌃⌥Qを押し、Option＋クリックすると、そのアプリの行が選ばれます。選ばれるアプリは、メインウインドウの右下の「直前のアプリ」に表示されます。許可スイッチは自分で操作してください。アクセシビリティの許可が必要です。
- キーボードショートカット（⌘8）：キーボードの「キーボードショートカット…」を開きます。左の一覧は前回表示していた項目のままです。
- AirDropおよび連係（⌘9）：一般＞AirDropおよび連係
同じ項目は［ファイル］メニューにもあります。メニューバーのアイコンを表示している場合は、そのメニューからも開けます。

## 設定
［SettingsHop］＞［設定…］（⌘,）で開きます。
- 起動・常駐：ログイン時に起動、Dockとアプリケーションスイッチャーに表示しない、ウインドウを閉じても常駐、メニューバーのアイコン、アプリ起動のホットキー、アプリを呼び出すホットキー（初期値 ⌃⌥Q）。
- 一般：「項目を開いたらウインドウを閉じる」をオンにすると、メインウインドウのボタンや⌘1〜⌘9で開いたあとウインドウを閉じます。メニューバーから開いたときは関係ありません。
- 設定の共有：設定の書き出し・読み込みと同期。
- 情報：バージョンとリンク。

## ホットキー
- ⌃⌥Q：どのアプリからでもSettingsHopのウインドウを表示（起動中のとき。設定の「起動・常駐」で変更・無効化できます）
- 1〜9（または⌘1〜⌘9）：各項目を開く（プライバシーとセキュリティ・入力監視・オートメーション・セキュリティを除く）（SettingsHopが前面のとき）
- ↑↓：項目を選ぶ、Return：選んだ項目を開く（メインウインドウ）
- ⌘0：メインウインドウを開く
- ⌘,：設定
- ⌘W：ウインドウを閉じる
- ⌘?：このヘルプ
⌃⌥Q で呼び出したあと⌘1〜⌘9を押すと、キーボードだけで目的の画面を開けます。SettingsHopを未起動のときから呼び出すには、設定の「アプリ起動のホットキー」の説明に従い、ショートカットAppでキーを割り当てます。

## 権限
アクセシビリティの許可は、「デフォルトのWebブラウザ」の行へのスクロールと、Option＋クリックでのアプリの行の選択にだけ使います。設定の［起動・常駐］の「アクセシビリティ設定を開く」から許可できます。未許可でも画面は開きます。許可スイッチの変更や、設定の値の読み書きはしません。

## 常駐と終了
「ウインドウを閉じても常駐」がオンのときは、ウインドウを閉じても動き続けます。DockやFinderからSettingsHopを開き直すか、メニューバーのアイコンからウインドウを表示できます。終了するには［SettingsHop］＞［SettingsHopを終了］（⌘Q）を選びます。

## 困ったときは
- 目的の画面ではなくシステム設定のトップが開く：macOSのバージョンによって画面の識別名が変わることがあります。お使いのmacOSでは開けない可能性があります。
- 「開けませんでした」と表示される：システム設定が起動できるか確認してください。
- ウインドウが見つからない：DockのSettingsHopをクリックするか、Finderからもう一度開きます。
""",
 "en": """## Basics
Click an item in the SettingsHop window to open that pane in System Settings.
- System Settings (⌘1): opens System Settings. If it is already open, it comes to the front showing the last pane.
- Privacy & Security: shown from the top (without Accessibility permission it may open where you left it)
- Accessibility (⌘2)
- Full Disk Access (⌘3)
- Files and Folders (⌘4)
- Screen & System Audio Recording (⌘5)
- Input Monitoring
- Automation
- Security: the Security section near the bottom of Privacy & Security (allowing apps, FileVault and more)
- Login Items (⌘6): General > Login Items & Extensions
- Default Web Browser (⌘7): opens Desktop & Dock and, with Accessibility allowed, scrolls to the Default web browser row and opens its menu of browsers.

## Option-click
Option-click Accessibility (⌘2), Full Disk Access (⌘3), Screen & System Audio Recording (⌘5) or Input Monitoring (or Option-Return, ⌥ plus the digit, or ⌘⌥ plus the digit) to open the list with the app you used last selected. For example, press ⌃⌥Q in the app you are working in, then Option-click. The app that will be selected is shown as Last app at the lower right of the main window. Change the permission switch yourself. Accessibility permission is needed.
- Keyboard Shortcuts (⌘8): opens Keyboard Shortcuts… in Keyboard, on the section shown last.
- AirDrop & Handoff (⌘9): General > AirDrop & Handoff
The same items are in the File menu. When the menu bar icon is shown, its menu opens them too.

## Settings
Choose SettingsHop > Settings… (⌘,).
- Launch & Residency: Open at login, Hide from Dock and App Switcher, Keep running after closing the window, the menu bar icon, the app launch keyboard shortcut and the show app shortcut (⌃⌥Q by default).
- General: with “Close the window after opening an item” on, the window closes after you open an item with its button or ⌘1–⌘9. Opening from the menu bar is not affected.
- Settings Sharing: export, import and sync settings.
- About: version and links.

## Keyboard shortcuts
- ⌃⌥Q: show the SettingsHop window from any app (while it is running; change or turn it off in Launch & Residency settings)
- 1–9 (or ⌘1–⌘9): open each item (except Privacy & Security, Input Monitoring, Automation and Security) (while SettingsHop is active)
- ↑↓: choose an item, Return: open it (main window)
- ⌘0: Open Main Window
- ⌘,: Settings
- ⌘W: Close Window
- ⌘?: this help
Press ⌃⌥Q, then ⌘1–⌘9, to open a pane from the keyboard alone. To call SettingsHop even when it is not running, follow the app launch keyboard shortcut note in Settings and assign a key in Shortcuts.

## Permissions
Accessibility permission is used only to scroll to the Default web browser row and to select an app's row with Option-click. Allow it with Open Accessibility Settings in Settings › Launch & Residency. Without it, the panes still open. SettingsHop never changes permission switches or reads or changes settings.

## Keeping running and quitting
With “Keep running after closing the window” on, SettingsHop keeps running after you close the window. Open it again from the Dock or Finder, or show the window from the menu bar icon. To quit, choose SettingsHop > Quit SettingsHop (⌘Q).

## Troubleshooting
- System Settings opens at the top instead of the pane: pane identifiers can change between macOS versions, so that pane may not open on your macOS.
- “Could not open” appears: check that System Settings can open.
- The window is gone: click SettingsHop in the Dock, or open it again from Finder.
""",
 "zh-Hans": """## 基本操作
在 SettingsHop 窗口中点击项目，即可在系统设置中打开对应面板。
- 系统设置（⌘1）：打开系统设置。如果已经打开，则保持上次显示的面板并移到最前。
- 隐私与安全性：从顶部显示（未允许辅助功能时，可能显示上次查看的位置）
- 辅助功能（⌘2）
- 完全磁盘访问权限（⌘3）
- 文件与文件夹（⌘4）
- 录屏与系统录音（⌘5）
- 输入监控
- 自动化
- 安全性：“隐私与安全性”下方的“安全性”部分（允许应用程序、文件保险箱等）
- 登录项（⌘6）：通用 > 登录项与扩展
- 默认网页浏览器（⌘7）：打开“桌面与程序坞”，允许辅助功能时会滚动到“默认网页浏览器”一行并打开浏览器菜单。

## 按住 Option 点按
按住 Option 点按辅助功能（⌘2）、完全磁盘访问权限（⌘3）、录屏与系统录音（⌘5）或输入监控（或 Option-Return、⌥+数字、⌘⌥+数字），会在打开时选中上一个使用的应用所在行。例如在正在使用的应用中按 ⌃⌥Q，再按住 Option 点按。将被选中的应用显示在主窗口右下角的“上一个应用”。授权开关请手动操作。需要辅助功能权限。
- 键盘快捷键（⌘8）：打开“键盘”中的“键盘快捷键…”，显示上次查看的部分。
- 隔空投送与接力（⌘9）：通用 > 隔空投送与接力
“文件”菜单中也有相同的项目。显示菜单栏图标时，也可从其菜单打开。

## 设置
选取 SettingsHop >“设置…”（⌘,）。
- 启动与常驻：登录时启动、不在程序坞和应用切换器中显示、关闭窗口后继续运行、菜单栏图标、启动应用快捷键、显示应用快捷键（默认 ⌃⌥Q）。
- 通用：打开“打开项目后关闭窗口”后，通过主窗口的按钮或 ⌘1–⌘9 打开项目后会关闭窗口。从菜单栏打开时不受影响。
- 设置共享：导出、导入和同步设置。
- 关于：版本和链接。

## 快捷键
- ⌃⌥Q：在任何应用中显示 SettingsHop 窗口（运行时；可在“启动与常驻”设置中更改或停用）
- 1–9（或 ⌘1–⌘9）：打开各项目（隐私与安全性、输入监控、自动化、安全性除外）（SettingsHop 在最前时）
- ↑↓：选择项目，Return：打开所选项目（主窗口）
- ⌘0：打开主窗口
- ⌘,：设置
- ⌘W：关闭窗口
- ⌘?：本帮助
按 ⌃⌥Q 后再按 ⌘1–⌘9，仅用键盘即可打开目标面板。要在 SettingsHop 未运行时也能调用，请按照设置中“启动应用快捷键”的说明，在快捷指令中分配按键。

## 权限
辅助功能权限仅用于滚动到“默认网页浏览器”一行，以及按住 Option 点按时选中应用所在行。可在设置 › 启动与常驻中的“打开辅助功能设置”授权。未授权时仍会打开面板。SettingsHop 不更改授权开关，也不读取或更改任何设置。

## 常驻与退出
打开“关闭窗口后继续运行”时，关闭窗口后 SettingsHop 仍继续运行。可从程序坞或访达再次打开，或从菜单栏图标显示窗口。要退出，请选取 SettingsHop >“退出 SettingsHop”（⌘Q）。

## 疑难解答
- 打开的是系统设置首页而不是目标面板：面板标识可能因 macOS 版本而变化，您的 macOS 可能无法打开该面板。
- 显示“无法打开”：请确认系统设置能否打开。
- 找不到窗口：点击程序坞中的 SettingsHop，或从访达再次打开。
""",
 "ko": """## 기본 조작
SettingsHop 윈도우에서 항목을 클릭하면 시스템 설정의 해당 화면을 엽니다.
- 시스템 설정(⌘1): 시스템 설정을 엽니다. 이미 열려 있으면 마지막으로 표시한 화면 그대로 앞으로 가져옵니다.
- 개인정보 보호 및 보안: 맨 위부터 표시합니다(손쉬운 사용이 허용되지 않으면 마지막으로 본 위치에서 열릴 수 있음)
- 손쉬운 사용(⌘2)
- 전체 디스크 접근 권한(⌘3)
- 파일 및 폴더(⌘4)
- 화면 및 시스템 오디오 녹음(⌘5)
- 입력 모니터링
- 자동화
- 보안: 개인정보 보호 및 보안 아래쪽의 '보안' 영역(응용 프로그램 허용, FileVault 등)
- 로그인 항목(⌘6): 일반 > 로그인 항목 및 확장 프로그램
- 기본 웹 브라우저(⌘7): 데스크탑 및 Dock을 열고, 손쉬운 사용이 허용되어 있으면 '기본 웹 브라우저' 행까지 스크롤하고 브라우저 메뉴를 엽니다.

## Option-클릭
손쉬운 사용(⌘2), 전체 디스크 접근 권한(⌘3), 화면 및 시스템 오디오 녹음(⌘5), 입력 모니터링을 Option 키를 누른 채 클릭하면(또는 Option-Return, ⌥+숫자, ⌘⌥+숫자) 직전에 사용한 앱의 행을 선택한 상태로 엽니다. 예를 들어 작업 중인 앱에서 ⌃⌥Q를 누른 후 Option-클릭합니다. 선택될 앱은 메인 윈도우 오른쪽 아래의 '직전 앱'에 표시됩니다. 권한 스위치는 직접 조작하세요. 손쉬운 사용 권한이 필요합니다.
- 키보드 단축키(⌘8): 키보드의 '키보드 단축키…'를 엽니다. 왼쪽 목록은 마지막으로 표시한 항목 그대로입니다.
- AirDrop 및 Handoff(⌘9): 일반 > AirDrop 및 Handoff
같은 항목이 [파일] 메뉴에도 있습니다. 메뉴 막대 아이콘을 표시한 경우 그 메뉴에서도 열 수 있습니다.

## 설정
SettingsHop > 설정…(⌘,)을 선택합니다.
- 실행·상주: 로그인 시 실행, Dock 및 앱 전환기에서 숨기기, 윈도우를 닫아도 계속 실행, 메뉴 막대 아이콘, 앱 실행 키보드 단축키, 앱 표시 단축키(기본값 ⌃⌥Q).
- 일반: '항목을 연 후 윈도우 닫기'를 켜면 메인 윈도우의 버튼이나 ⌘1–⌘9로 연 후 윈도우를 닫습니다. 메뉴 막대에서 열 때는 영향이 없습니다.
- 설정 공유: 설정 내보내기·가져오기와 동기화.
- 정보: 버전과 링크.

## 키보드 단축키
- ⌃⌥Q: 어느 앱에서든 SettingsHop 윈도우 표시(실행 중일 때. 설정의 '실행·상주'에서 변경하거나 끌 수 있음)
- 1–9(또는 ⌘1–⌘9): 각 항목 열기(개인정보 보호 및 보안, 입력 모니터링, 자동화, 보안 제외)(SettingsHop이 앞에 있을 때)
- ↑↓: 항목 선택, Return: 선택한 항목 열기(메인 윈도우)
- ⌘0: 메인 윈도우 열기
- ⌘,: 설정
- ⌘W: 윈도우 닫기
- ⌘?: 이 도움말
⌃⌥Q를 누른 후 ⌘1–⌘9를 누르면 키보드만으로 원하는 화면을 열 수 있습니다. SettingsHop이 실행 중이 아닐 때도 호출하려면 설정의 '앱 실행 키보드 단축키' 안내에 따라 단축어 앱에서 키를 지정하세요.

## 권한
손쉬운 사용 권한은 '기본 웹 브라우저' 행으로의 스크롤과 Option-클릭으로 앱 행을 선택할 때만 사용합니다. 설정 › 실행·상주의 '손쉬운 사용 설정 열기'에서 허용할 수 있습니다. 권한이 없어도 화면은 열립니다. 권한 스위치를 바꾸거나 설정 값을 읽고 쓰지 않습니다.

## 상주와 종료
'윈도우를 닫아도 계속 실행'이 켜져 있으면 윈도우를 닫아도 계속 실행됩니다. Dock이나 Finder에서 SettingsHop을 다시 열거나 메뉴 막대 아이콘에서 윈도우를 표시할 수 있습니다. 종료하려면 SettingsHop > SettingsHop 종료(⌘Q)를 선택합니다.

## 문제 해결
- 원하는 화면 대신 시스템 설정의 첫 화면이 열림: macOS 버전에 따라 화면 식별자가 바뀔 수 있어 사용 중인 macOS에서는 열리지 않을 수 있습니다.
- '열 수 없습니다'가 표시됨: 시스템 설정을 열 수 있는지 확인하세요.
- 윈도우가 보이지 않음: Dock의 SettingsHop을 클릭하거나 Finder에서 다시 엽니다.
""",
}
