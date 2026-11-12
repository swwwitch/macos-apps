# -*- coding: utf-8 -*-
"""LayoutMate help (ja, en, zh-Hans, ko). make-resources.py writes it to Localizable.strings (helpContent) and Help.txt."""

HELP = [
'''LayoutMate — InDesignの作業を補助

LayoutMateは、InDesignの設定の切り替えと、マウス・キー操作の補助をまとめた常駐アプリです。メインウインドウ上部の「バックグラウンド書き出し」「UI」「ツール」「関連付け」で切り替えます。

バックグラウンド書き出し
InDesignのアプリ内の Contents/MacOS に空のファイル DisableAsyncExports.txt を置くと、PDFなどの書き出しがバックグラウンドではなく通常の処理で行われます。各行の「オフにする」で配置、「元に戻す」で削除、「すべてオフにする」でまとめてオフにします。InDesignのアプリ内は保護されているため、変更時にmacOSの管理者認証が表示されます（パスワードは保存しません）。反映はInDesignの次回起動からです。/Applications 以外のInDesignは「InDesignを追加…」（⌘O）で選びます。InDesignのアップデートでファイルが消え「オン」に戻ることがあります。

UI
UIの明るさ：InDesignの［環境設定］→［インターフェイス］のカラーテーマ（暗・やや暗め・やや明るめ・明）を選びます。InDesignが前面のとき、⇧F2で1段明るく、⇧F1で1段暗くします（設定の「ホットキー」で変更・解除できます）。
表示：アプリケーションフレーム、コンテキストタスクバー、ツールバー（2列）を切り替えます。いずれも起動中のInDesign（前面のもの、なければ起動しているもの）に対して、スクリプトで読み書きします。
アプリケーションバー：~/Library/Preferences/Adobe InDesign の各バージョンのワークスペースのXMLで、アプリケーションバーの is-closed を書き換えます。InDesignは終了するときにワークスペースを書き戻すため、InDesignの起動中は変更できません。アプリケーションフレームを使っているときは効きません。

ツール
選択ツール：「修飾キーのダブルタップで選択ツールに切り替える」をオンにすると、InDesignが前面のとき、選んだキー（control・option・command・shift。初期値は control）だけを2回続けて軽く押すと選択ツールにします（文字の編集も終わります）。ほかのキーやクリックを挟むと数えません。
ドラッグでパン：「マウスボタンのドラッグで画面をパンする」をオンにすると、InDesignが前面のとき、選んだボタン（右ボタン・中ボタン。初期値は右ボタン）でのドラッグをスペース＋ドラッグ（手のひらツール）に置き換えます。動かさずに離すと元のクリックを送ります（右ボタンのコンテキストメニューは押したときではなく離したときに開きます）。修飾キーを押しているとき、文字ツールの使用中、InDesign以外のウインドウ（パレットなど）の上ではそのまま通します。
どちらも初期値はオフで、アクセシビリティの許可が必要です。

関連付け
複数の版のInDesignがインストールされているとき、チェックした拡張子（.indd・.idml）をまとめて指定の版で開くようにします。macOSの関連付けの記録に版を書き込み、関連付けを管理するシステムの処理（lsd）を再起動します。変更前の記録は ~/Library/Application Support/LayoutMate に保存します。

設定（⌘,）
起動・常駐：ログイン時に起動（初期値オフ。ログイン時の自動起動ではウインドウを表示しません）、Dockとアプリケーションスイッチャーに表示しない、ウインドウを閉じても常駐（初期値オン）、アプリ起動のホットキー（初期値は未設定）、メニューバーのアイコン、アクセシビリティの許可の状態。
ホットキー：UIの明るさのホットキー（⇧F2・⇧F1）の有効・変更・解除。InDesignが前面のときだけ登録するので、ほかのアプリの⇧F1・⇧F2は妨げません。
情報：バージョン・build・リンク。

権限
アクセシビリティ：ツール（選択ツール・ドラッグでパン）がマウスやキーの操作を受け取るために使います。設定の「起動・常駐」で状態を確認し、「アクセシビリティ設定を開く」から許可してください。
オートメーション（InDesignの操作）：UI・ツールでInDesignの状態を読み書きするために使います。初回にmacOSの確認が表示されます。拒否した場合はシステム設定の［プライバシーとセキュリティ］→［オートメーション］で許可してください。

常駐と終了
常駐がオンのとき、ウインドウを閉じても動き続けます。Dock、メニューバーのアイコン、Finderからアプリを開き直す、アプリ起動のホットキーでウインドウを開けます。⌘Qで終了します。⌘0でメインウインドウ、⌘Rで再読み込み、⌘?でこのヘルプを開きます。

困ったとき
ツールが効かない：設定の「起動・常駐」でアクセシビリティが「許可済み」か確認してください。
UIの値が読めない：InDesignが起動しているか、ダイアログボックスを開いていないか確認し、［再読み込み］を押してください。オートメーションが拒否されている場合は上の手順で許可してください。
関連付けが切り替わらない：macOSが直前の変更をまだ保存していないことがあります。数分待ってからもう一度実行してください。
''',
'''LayoutMate — Helpers for InDesign

LayoutMate is a background app that switches InDesign settings and helps with mouse and key operations. Use Background Export, UI, Tools and Associations at the top of the main window.

Background Export
An empty DisableAsyncExports.txt in Contents/MacOS inside InDesign makes PDF and other exports run in the foreground instead of the background. Turn Off places it, Restore removes it, and Turn Off All turns off every version at once. The inside of InDesign is protected, so macOS asks for an administrator password (it is not stored). Changes apply the next time InDesign starts. Choose InDesign outside /Applications with Add InDesign… (⌘O). Updating InDesign can remove the file and turn background export back on.

UI
UI Brightness: chooses the color theme in InDesign's Settings → Interface (Dark, Medium Dark, Medium Light, Light). While InDesign is in front, ⇧F2 makes it one step brighter and ⇧F1 one step darker (change or clear the keys in Settings → Hotkeys).
Display: switches the Application Frame, the Contextual Task Bar and the two-column toolbar in the running InDesign (the one in front, otherwise one that runs) with a script.
Application Bar: rewrites is-closed of the application bar in the workspace XML of each version in ~/Library/Preferences/Adobe InDesign. InDesign writes its workspace back when it quits, so this cannot be changed while InDesign runs. It has no effect with the Application Frame.

Tools
Selection Tool: with "Double-tap a modifier key to switch to the Selection tool" on, tapping the chosen key (Control, Option, Command or Shift; Control by default) alone twice while InDesign is in front selects the Selection tool (text editing ends). Another key or a click in between cancels it.
Drag to Pan: with "Pan the view by dragging with a mouse button" on, a drag with the chosen button (right or middle; right by default) while InDesign is in front is turned into Space + drag (the Hand tool). Releasing without moving sends the original click (the right-button context menu opens on release instead of on press). Presses with modifier keys, while a type tool is in use, or over windows of other apps (such as palettes) pass through unchanged.
Both are off by default and need the Accessibility permission.

Associations
When several versions of InDesign are installed, opens the checked extensions (.indd, .idml) with the chosen version. The version is written into macOS's association record and the system process that manages associations (lsd) is restarted. The previous record is saved in ~/Library/Application Support/LayoutMate.

Settings (⌘,)
Startup & Background: Open at login (off by default; no window when opened at login), Hide from Dock and App Switcher, Keep running after closing the window (on by default), the app hotkey (unset by default), the menu bar icon, and the Accessibility permission state.
Hotkeys: turn on, change or clear the UI brightness hotkeys (⇧F2, ⇧F1). They are registered only while InDesign is in front, so ⇧F1 and ⇧F2 stay with every other app.
About: version, build and links.

Permissions
Accessibility: lets the tools (Selection Tool, Drag to Pan) receive mouse and key events. Check it in Settings → Startup & Background and allow it with Open Accessibility Settings.
Automation (controlling InDesign): reads and writes InDesign's state for UI and Tools. macOS asks the first time. If it was denied, allow it in System Settings → Privacy & Security → Automation.

Running and quitting
With Keep running on, closing the window keeps the app running. Open the window from the Dock, the menu bar icon, by opening the app again in the Finder or with the app hotkey. ⌘Q quits. ⌘0 opens the main window, ⌘R reloads and ⌘? opens this help.

Troubleshooting
The tools do nothing: check that Accessibility is Allowed in Settings → Startup & Background.
UI values cannot be read: check that InDesign runs and has no dialog box open, then press Reload. If Automation was denied, allow it as described above.
The association does not switch: macOS may not have saved a recent change yet. Wait a few minutes and try again.
''',
'''LayoutMate — InDesign 辅助工具

LayoutMate 是一款常驻应用，用于切换 InDesign 的设置并辅助鼠标和按键操作。在主窗口顶部的“后台导出”“UI”“工具”“关联”之间切换。

后台导出
在 InDesign 应用内的 Contents/MacOS 中放置空文件 DisableAsyncExports.txt 后，PDF 等导出将以常规方式而非后台进行。各行的“关闭”放置文件，“恢复”删除文件，“全部关闭”一次关闭所有版本。InDesign 应用内部受到保护，更改时 macOS 会要求输入管理员密码（不会保存）。更改在下次启动 InDesign 时生效。不在 /Applications 中的 InDesign 请通过“添加 InDesign…”（⌘O）选择。更新 InDesign 可能会删除该文件并恢复为“开启”。

UI
界面亮度：选择 InDesign“设置”→“界面”的颜色主题（暗、中暗、中亮、亮）。InDesign 位于前台时，⇧F2 调亮一级，⇧F1 调暗一级（可在设置的“快捷键”中更改或清除）。
显示：通过脚本切换正在运行的 InDesign（前台的，否则为正在运行的）的应用程序框架、上下文任务栏和双栏工具栏。
应用程序栏：改写 ~/Library/Preferences/Adobe InDesign 中各版本工作区 XML 里应用程序栏的 is-closed。InDesign 退出时会写回工作区，因此 InDesign 运行期间无法更改。使用应用程序框架时无效。

工具
选择工具：打开“连按两下修饰键切换到选择工具”后，InDesign 位于前台时，单独连按两下所选的键（Control、Option、Command 或 Shift，默认为 Control）会切换到选择工具（同时结束文字编辑）。中间按其他键或点按则不计。
拖动平移：打开“用鼠标按键拖动来平移视图”后，InDesign 位于前台时，将所选按键（右键或中键，默认为右键）的拖动转换为空格键＋拖动（抓手工具）。不移动就松开时发送原来的点按（右键的上下文菜单在松开时而不是按下时打开）。按住修饰键时、使用文字工具时或在其他应用的窗口（如面板）上时按原样传递。
两者默认关闭，需要辅助功能权限。

关联
安装了多个版本的 InDesign 时，用所选版本打开勾选的扩展名（.indd、.idml）。版本会写入 macOS 的关联记录，并重新启动管理关联的系统进程（lsd）。更改前的记录保存在 ~/Library/Application Support/LayoutMate。

设置（⌘,）
启动与后台：登录时启动（默认关闭；登录时自动启动不显示窗口）、在程序坞和应用切换器中隐藏、关闭窗口后保持运行（默认开启）、启动应用的快捷键（默认未设置）、菜单栏图标以及辅助功能权限状态。
快捷键：启用、更改或清除界面亮度快捷键（⇧F2、⇧F1）。仅在 InDesign 位于前台时注册，不影响其他应用的 ⇧F1、⇧F2。
关于：版本、build 和链接。

权限
辅助功能：供工具（选择工具、拖动平移）接收鼠标和按键事件。请在设置的“启动与后台”中确认状态，并通过“打开辅助功能设置”授权。
自动化（控制 InDesign）：用于在 UI 和工具中读写 InDesign 的状态。首次使用时 macOS 会询问。如被拒绝，请在系统设置的“隐私与安全性”→“自动化”中授权。

运行与退出
开启“保持运行”时，关闭窗口后应用仍会继续运行。可从程序坞、菜单栏图标、在访达中再次打开应用或使用启动应用的快捷键打开窗口。⌘Q 退出。⌘0 打开主窗口，⌘R 重新载入，⌘? 打开本帮助。

故障排除
工具不起作用：请在设置的“启动与后台”中确认辅助功能为“已允许”。
无法读取 UI 的值：请确认 InDesign 正在运行且没有打开对话框，然后按“重新载入”。如果自动化被拒绝，请按上述步骤授权。
关联没有切换：macOS 可能尚未保存最近的更改。请等待几分钟后重试。
''',
'''LayoutMate — InDesign 작업 도우미

LayoutMate는 InDesign의 설정을 전환하고 마우스·키 조작을 돕는 상주 앱입니다. 메인 윈도우 위쪽의 백그라운드 내보내기, UI, 도구, 연결로 전환합니다.

백그라운드 내보내기
InDesign 앱 내부의 Contents/MacOS에 빈 파일 DisableAsyncExports.txt를 두면 PDF 등의 내보내기가 백그라운드가 아닌 일반 처리로 진행됩니다. 각 행의 끄기는 파일을 배치하고, 되돌리기는 삭제하며, 모두 끄기는 모든 버전을 한꺼번에 끕니다. InDesign 앱 내부는 보호되어 있어 변경할 때 macOS가 관리자 암호를 요청합니다(저장하지 않음). 변경 사항은 다음 InDesign 실행부터 적용됩니다. /Applications 밖의 InDesign은 InDesign 추가…(⌘O)로 선택합니다. InDesign을 업데이트하면 파일이 사라져 켬으로 돌아갈 수 있습니다.

UI
UI 밝기: InDesign 설정 → 인터페이스의 색상 테마(어두움, 약간 어두움, 약간 밝음, 밝음)를 선택합니다. InDesign이 앞에 있을 때 ⇧F2로 한 단계 밝게, ⇧F1로 한 단계 어둡게 합니다(설정의 단축키에서 변경·해제).
표시: 실행 중인 InDesign(앞에 있는 것, 없으면 실행 중인 것)의 응용 프로그램 프레임, 상황별 작업 표시줄, 2열 도구 막대를 스크립트로 전환합니다.
응용 프로그램 막대: ~/Library/Preferences/Adobe InDesign에 있는 각 버전 작업 영역 XML의 응용 프로그램 막대 is-closed를 바꿉니다. InDesign은 종료할 때 작업 영역을 다시 쓰므로 InDesign 실행 중에는 바꿀 수 없습니다. 응용 프로그램 프레임을 사용할 때는 효과가 없습니다.

도구
선택 도구: 보조 키를 두 번 탭하면 선택 도구로 전환을 켜면, InDesign이 앞에 있을 때 선택한 키(Control, Option, Command, Shift. 기본값은 Control)만 두 번 가볍게 누르면 선택 도구로 바뀝니다(문자 편집도 끝납니다). 중간에 다른 키나 클릭이 있으면 세지 않습니다.
드래그로 이동: 마우스 버튼 드래그로 화면 이동을 켜면, InDesign이 앞에 있을 때 선택한 버튼(오른쪽 또는 가운데, 기본값은 오른쪽)의 드래그를 스페이스＋드래그(손 도구)로 바꿉니다. 움직이지 않고 놓으면 원래 클릭을 보냅니다(오른쪽 버튼의 컨텍스트 메뉴는 누를 때가 아니라 놓을 때 열립니다). 보조 키를 누르고 있을 때, 문자 도구를 사용하는 중, 다른 앱의 윈도우(팔레트 등) 위에서는 그대로 전달합니다.
둘 다 기본값은 끔이며 손쉬운 사용 권한이 필요합니다.

연결
InDesign이 여러 버전 설치되어 있을 때 체크한 확장자(.indd, .idml)를 선택한 버전으로 열도록 합니다. macOS의 연결 기록에 버전을 쓰고 연결을 관리하는 시스템 프로세스(lsd)를 다시 시작합니다. 변경 전 기록은 ~/Library/Application Support/LayoutMate에 저장합니다.

설정(⌘,)
시작 및 백그라운드: 로그인 시 실행(기본값 끔. 로그인 시 자동 실행에서는 창을 표시하지 않음), Dock 및 앱 전환기에서 숨기기, 창을 닫아도 계속 실행(기본값 켬), 앱 실행 단축키(기본값 미설정), 메뉴 막대 아이콘, 손쉬운 사용 권한 상태.
단축키: UI 밝기 단축키(⇧F2, ⇧F1)의 사용·변경·해제. InDesign이 앞에 있을 때만 등록하므로 다른 앱의 ⇧F1, ⇧F2를 방해하지 않습니다.
정보: 버전, build, 링크.

권한
손쉬운 사용: 도구(선택 도구, 드래그로 이동)가 마우스와 키 이벤트를 받는 데 사용합니다. 설정의 시작 및 백그라운드에서 상태를 확인하고 손쉬운 사용 설정 열기에서 허용하세요.
자동화(InDesign 제어): UI와 도구에서 InDesign의 상태를 읽고 쓰는 데 사용합니다. 처음에 macOS가 확인을 요청합니다. 거부했다면 시스템 설정 → 개인정보 보호 및 보안 → 자동화에서 허용하세요.

실행과 종료
계속 실행이 켜져 있으면 창을 닫아도 계속 실행됩니다. Dock, 메뉴 막대 아이콘, Finder에서 앱 다시 열기, 앱 실행 단축키로 창을 엽니다. ⌘Q로 종료합니다. ⌘0은 메인 윈도우, ⌘R은 새로 고침, ⌘?는 이 도움말입니다.

문제 해결
도구가 작동하지 않음: 설정의 시작 및 백그라운드에서 손쉬운 사용이 허용됨인지 확인하세요.
UI 값을 읽을 수 없음: InDesign이 실행 중이고 대화상자가 열려 있지 않은지 확인한 뒤 새로 고침을 누르세요. 자동화가 거부되었다면 위 방법으로 허용하세요.
연결이 바뀌지 않음: macOS가 직전 변경을 아직 저장하지 않았을 수 있습니다. 몇 분 기다린 뒤 다시 실행하세요.
''',
]
