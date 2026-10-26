# ShotSorter help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
ShotSorterは常駐して次の2つを行います。メインウインドウから両方を操作できます。
- スクリーンショット：指定したフォルダーに新しいスクリーンショットが加わると、名前を「ss-幅-高さ-解像度-日時.png」に変えます。
- 文字認識：範囲を選ぶと、その部分の文字を読み取ってクリップボードにコピーします（⌘⇧1）。
下の「最近の処理」に直近の結果が出ます。履歴は保存せず、終了すると消えます。

## スクリーンショット
- ウォッチフォルダー：複数指定できます。［フォルダーを追加…］と［削除］で編集し、既存の監視先を引き継ぎます。PNGをメインウインドウへドロップしても命名ルールを適用します（監視のON/OFFに関係なく実行）。
- 対象：このフォルダーに加わったPNGのうち、名前に「ss-」を含まないもの。ShotSorterを起動する前からあったファイルは変えません。
- 名前の形式：{width}（幅）・{height}（高さ）・{dpi}（解像度）・{date}（日時 yyyyMMdd-HHmmss）を使えます。同じ名前があるときは末尾に番号を付けます。
- 画像の文字を読み取り、Finderのコメントとクリップボードへ入れます。出力先は個別にON/OFFできます。文字がない場合はクリップボードを変更しません。最後に処理した画像の文字をコピーします。

## 文字認識
⌘⇧1（または「範囲を選んで文字認識」ボタン、メニューバーのアイコン）を押し、読み取りたい範囲をドラッグします。Escで取り消せます。日本語と英語を読み取り、クリップボードにコピーして画面の右上に表示します。
- 設定の「Vision後の整形ルール」で日本語の間の空白を詰める処理と括弧の全角化を個別に選べます。改行は保持します。コメントとクリップボードの両方へ同じ整形を適用します。
- 半角の ( ) を全角の（ ）にする。

## 設定
［ShotSorter］＞［設定…］（⌘,）で開きます。
- 起動・常駐：ログイン時に起動、Dockとアプリケーションスイッチャーに表示しない、ウインドウを閉じても常駐、メニューバーのアイコン、アプリ起動のホットキー、アプリを呼び出すホットキー（初期値 ⌃⌥S）、画面収録の許可。
- ホットキー：範囲を選んで文字認識（初期値 ⌘⇧1）。
- 通知：名前の変更・文字認識の結果を通知（初期値オフ）。
- 設定の共有：名前の形式などの書き出し・読み込みと同期。フォルダーはMacごとです。
- 情報：バージョンとリンク。

## ホットキー
- ⌘⇧1：範囲を選んで文字認識（起動中、どのアプリからでも）
- ⌃⌥S：ShotSorterのウインドウを表示（起動中、どのアプリからでも）
- ⌘0：メインウインドウを開く
- ⌘,：設定
- ⌘W：ウインドウを閉じる
- ⌘?：このヘルプ

## 権限とプライバシー
- 画面収録：文字認識で選んだ範囲を撮影するときだけ使います。設定の「起動・常駐」で状態を確かめ、システム設定を開けます。
- Finderの操作：Finderのコメントを入れるために使います。最初に入れるときにmacOSが確認します。許可しないときはSpotlight用にだけ保存します。
- 文字の読み取りはMacの中で行い、外部に送りません。フォルダーの中身やファイル名を保存・送信しません。

## 常駐と終了
「ウインドウを閉じても常駐」がオンのときは、ウインドウを閉じても監視と⌘⇧1が動き続けます。DockやFinderから開き直すか、メニューバーのアイコンからウインドウを表示できます。終了するには［ShotSorter］＞［ShotSorterを終了］（⌘Q）を選びます。終了中に加わったファイルは、次に起動しても処理しません。

## 困ったときは
- 名前が変わらない：「新しいスクリーンショットの名前を変える」がオンか、監視したいフォルダーが一覧にあるかを確かめてください。名前に「ss-」を含むファイルは対象外です。
- 文字認識で何も読み取れない・壁紙だけが写る：画面収録の許可を確かめてください。許可した後はShotSorterを開き直す必要があることがあります。
- Finderのコメントが表示されない：システム設定の「プライバシーとセキュリティ」＞「オートメーション」で、ShotSorterの「Finder」をオンにしてください。
""",
 "en": """## Basics
ShotSorter keeps running and does two things. Both are available in the main window.
- Screenshots: when a new screenshot is added to the chosen folder, it is renamed “ss-width-height-resolution-date.png”.
- Text Recognition: select an area to read its text and copy it to the clipboard (⌘⇧1).
Recent Activity at the bottom shows the latest results. It is not saved and is cleared when the app quits.

## Screenshots
- Watch Folders: add or remove multiple folders. Your existing folder is retained. Drop PNG files into the main window to apply the naming rule even when watching is off.
- Applies to: PNG files added to this folder whose name does not contain “ss-”. Files present before ShotSorter started are not changed.
- Name format: use {width}, {height}, {dpi} and {date} (yyyyMMdd-HHmmss). A number is added when the name is taken.
- Recognized text is written to Finder comments and the clipboard, with separate switches. Empty results leave the clipboard unchanged. The last completed image supplies the copied text.

## Text Recognition
Press ⌘⇧1 (or the Recognize Text in Area button, or the menu bar icon) and drag over the area to read. Press Esc to cancel. Japanese and English text is read, copied to the clipboard and shown at the top right.
- Settings > Formatting After Vision offers separate choices for removing spaces between Japanese characters and full-width parentheses. Line breaks are preserved. Comments and clipboard text use the same formatting.
- Change ( ) to full-width （ ）.

## Settings
Open with ShotSorter > Settings… (⌘,).
- Launch & Residency: open at login, hide from the Dock and App Switcher, keep running after closing the window, menu bar icon, app launch keyboard shortcut, the hotkey that shows the window (default ⌃⌥S) and Screen Recording permission.
- Hotkeys: Recognize Text in Area (default ⌘⇧1).
- Notifications: notify about renames and recognized text (off at first).
- Sharing: export, import and sync of the name format and other choices. The folder stays on each Mac.
- About: version and links.

## Hotkeys
- ⌘⇧1: recognize text in an area (while running, from any app)
- ⌃⌥S: show the ShotSorter window (while running, from any app)
- ⌘0: open the main window
- ⌘,: settings
- ⌘W: close the window
- ⌘?: this help

## Permissions and privacy
- Screen Recording: used only to capture the area selected for text recognition. Check it and open System Settings from Launch & Residency.
- Controlling Finder: used to set Finder comments; macOS asks the first time. Without permission the comment is saved for Spotlight only.
- Text is recognized on your Mac and never sent anywhere. Folder contents and file names are not saved or sent.

## Keeping it running and quitting
With Keep running after closing the window on, watching and ⌘⇧1 keep working after the window is closed. Reopen from the Dock or Finder, or from the menu bar icon. To quit, choose ShotSorter > Quit ShotSorter (⌘Q). Files added while the app is not running are not processed later.

## Troubleshooting
- Screenshots are not renamed: check that Rename new screenshots is on and the folder matches macOS's screenshot location (a note appears when it does not). Names containing “ss-” are skipped.
- Text recognition finds nothing or only the wallpaper: check Screen Recording permission. After allowing it, ShotSorter may need to be reopened.
- The Finder comment does not appear: in System Settings > Privacy & Security > Automation, turn on Finder for ShotSorter.
""",
 "zh-Hans": """## 基本操作
ShotSorter 常驻运行并完成以下两项工作。可在主窗口中操作两者。
- 截图：所选文件夹中新增截图时，将其重命名为“ss-宽-高-分辨率-日期时间.png”。
- 文字识别：选择区域后识别其中的文字并拷贝到剪贴板（⌘⇧1）。
底部的“最近的处理”显示最近的结果。不会保存，退出应用时清除。

## 截图
- 监视文件夹：可添加或移除多个文件夹，保留已有监视位置。将 PNG 拖到主窗口也可应用命名规则，不受监视开关影响。
- 对象：添加到此文件夹且名称不含“ss-”的 PNG。ShotSorter 启动前已有的文件不会更改。
- 名称格式：可使用 {width}（宽）、{height}（高）、{dpi}（分辨率）、{date}（日期时间 yyyyMMdd-HHmmss）。名称重复时会添加编号。
- 将识别文字写入访达注释和剪贴板，可分别开关。空结果不更改剪贴板，复制最后处理完成的图像文字。

## 文字识别
按 ⌘⇧1（或“选择区域识别文字”按钮、菜单栏图标），然后拖移选择要识别的区域。按 Esc 取消。识别日文和英文，拷贝到剪贴板并在右上角显示。
- 在设置的“Vision 识别后的格式规则”中分别选择删除日文字符间空格和括号全角化。保留换行，注释和剪贴板使用相同格式。
- 将半角 ( ) 改为全角（ ）。

## 设置
通过“ShotSorter”>“设置…”（⌘,）打开。
- 启动与常驻：登录时启动、不在程序坞和应用程序切换器中显示、关闭窗口后继续运行、菜单栏图标、启动应用快捷键、显示窗口的快捷键（默认 ⌃⌥S）以及录屏权限。
- 快捷键：选择区域识别文字（默认 ⌘⇧1）。
- 通知：通知重命名和文字识别的结果（初始关闭）。
- 设置共享：名称格式等设置的导出、导入和同步。文件夹在每台 Mac 上分别设置。
- 关于：版本和链接。

## 快捷键
- ⌘⇧1：选择区域识别文字（运行时，在任何应用中）
- ⌃⌥S：显示 ShotSorter 窗口（运行时，在任何应用中）
- ⌘0：打开主窗口
- ⌘,：设置
- ⌘W：关闭窗口
- ⌘?：本帮助

## 权限与隐私
- 录屏：仅用于截取文字识别时所选的区域。可在“启动与常驻”中查看状态并打开系统设置。
- 控制访达：用于写入访达注释，macOS 会在首次时询问。未允许时仅保存供聚焦使用。
- 文字识别在本机进行，不会发送到外部。不会保存或发送文件夹内容和文件名。

## 常驻与退出
开启“关闭窗口后继续运行”时，关闭窗口后监视和 ⌘⇧1 仍继续工作。可从程序坞或访达重新打开，或通过菜单栏图标显示窗口。要退出，请选择“ShotSorter”>“退出 ShotSorter”（⌘Q）。应用未运行期间新增的文件之后也不会处理。

## 疑难解答
- 截图没有重命名：请确认“重命名新截图”已开启，且文件夹与 macOS 的截图位置相同（不同时会显示提示）。名称含“ss-”的文件不处理。
- 文字识别没有结果或只拍到墙纸：请检查录屏权限。允许后可能需要重新打开 ShotSorter。
- 访达注释没有显示：请在“系统设置”>“隐私与安全性”>“自动化”中为 ShotSorter 开启“访达”。
""",
 "ko": """## 기본 조작
ShotSorter는 상주하며 다음 두 가지를 합니다. 메인 윈도우에서 두 기능을 사용할 수 있습니다.
- 스크린샷: 지정한 폴더에 새 스크린샷이 추가되면 이름을 “ss-폭-높이-해상도-일시.png”로 바꿉니다.
- 문자 인식: 영역을 선택하면 그 부분의 텍스트를 읽어 클립보드에 복사합니다(⌘⇧1).
아래 '최근 처리'에 최근 결과가 표시됩니다. 저장하지 않으며 앱을 종료하면 지워집니다.

## 스크린샷
- 감시 폴더: 여러 폴더를 추가·제거하며 기존 폴더를 유지합니다. 감시가 꺼져 있어도 PNG를 메인 윈도우에 놓으면 이름 규칙을 적용합니다.
- 대상: 이 폴더에 추가된 PNG 중 이름에 “ss-”가 없는 파일. ShotSorter 실행 전부터 있던 파일은 바꾸지 않습니다.
- 이름 형식: {width}(폭), {height}(높이), {dpi}(해상도), {date}(일시 yyyyMMdd-HHmmss)를 쓸 수 있습니다. 같은 이름이 있으면 번호를 붙입니다.
- 인식한 텍스트를 Finder 메모와 클립보드에 넣으며 각각 끌 수 있습니다. 빈 결과는 클립보드를 바꾸지 않으며 마지막 처리한 이미지의 텍스트를 복사합니다.

## 문자 인식
⌘⇧1(또는 '영역을 선택해 문자 인식' 버튼, 메뉴 막대 아이콘)를 누르고 읽을 영역을 드래그합니다. Esc로 취소합니다. 일본어와 영어를 읽어 클립보드에 복사하고 오른쪽 위에 표시합니다.
- 설정의 “Vision 인식 후 서식 규칙”에서 일본어 문자 사이 공백 제거와 전각 괄호를 각각 선택합니다. 줄바꿈을 유지하며 메모와 클립보드에 같은 서식을 적용합니다.
- 반각 ( )를 전각 （ ）로 바꿉니다.

## 설정
ShotSorter > 설정…(⌘,)으로 엽니다.
- 실행·상주: 로그인 시 실행, Dock 및 앱 전환기에 표시 안 함, 윈도우를 닫아도 계속 실행, 메뉴 막대 아이콘, 앱 실행 키보드 단축키, 윈도우를 표시하는 단축키(기본 ⌃⌥S), 화면 기록 권한.
- 단축키: 영역을 선택해 문자 인식(기본 ⌘⇧1).
- 알림: 이름 변경·문자 인식 결과 알림(처음에는 끔).
- 설정 공유: 이름 형식 등의 내보내기·가져오기와 동기화. 폴더는 Mac마다 설정합니다.
- 정보: 버전과 링크.

## 단축키
- ⌘⇧1: 영역을 선택해 문자 인식(실행 중, 어느 앱에서든)
- ⌃⌥S: ShotSorter 윈도우 표시(실행 중, 어느 앱에서든)
- ⌘0: 메인 윈도우 열기
- ⌘,: 설정
- ⌘W: 윈도우 닫기
- ⌘?: 이 도움말

## 권한과 개인정보
- 화면 기록: 문자 인식에서 선택한 영역을 촬영할 때만 사용합니다. 실행·상주에서 상태를 확인하고 시스템 설정을 열 수 있습니다.
- Finder 제어: Finder 메모를 넣는 데 사용합니다. 처음에 macOS가 확인합니다. 허용하지 않으면 Spotlight용으로만 저장합니다.
- 문자 인식은 Mac 안에서 하며 외부로 보내지 않습니다. 폴더 내용과 파일 이름을 저장·전송하지 않습니다.

## 상주와 종료
'윈도우를 닫아도 계속 실행'이 켜져 있으면 윈도우를 닫아도 감시와 ⌘⇧1가 계속 작동합니다. Dock이나 Finder에서 다시 열거나 메뉴 막대 아이콘에서 윈도우를 표시할 수 있습니다. 종료하려면 ShotSorter > ShotSorter 종료(⌘Q)를 선택합니다. 실행하지 않는 동안 추가된 파일은 나중에도 처리하지 않습니다.

## 문제 해결
- 이름이 바뀌지 않음: '새 스크린샷 이름 바꾸기'가 켜져 있는지, 폴더가 macOS의 저장 위치와 같은지 확인하세요(다르면 화면에 표시합니다). 이름에 “ss-”가 있는 파일은 대상이 아닙니다.
- 문자 인식에서 아무것도 읽지 못하거나 배경화면만 찍힘: 화면 기록 권한을 확인하세요. 허용한 뒤 ShotSorter를 다시 열어야 할 수 있습니다.
- Finder 메모가 표시되지 않음: 시스템 설정 > 개인정보 보호 및 보안 > 자동화에서 ShotSorter의 Finder를 켜세요.
""",
}
