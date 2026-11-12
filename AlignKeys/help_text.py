# -*- coding: utf-8 -*-
# AlignKeys help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
AlignKeysは、InDesignのスクリプト「近くの線に揃える」（IdAlignToNearestEdgePalette.jsx）のボタンを、InDesignが前面のときにキーボードショートカットで実行します。スクリプトはアプリに入っているので、別に用意する必要はありません。
- 表の「ホットキー」の欄をクリックしてからキーを押すと割り当てます。［割り当てを解除］で外します。
- 「中央から」の欄は、いったん中央に移してから揃えるショートカットです（パレットの Option＋クリックと同じ）。中央のボタンにはありません。
- ボタンの名前をクリックすると、InDesignを前面にしてから実行します（オブジェクトごと・ページ基準）。
- ［パレットを開く］で、InDesignにスクリプトのパレットを開きます。
- 右上の「ホットキーを使う」をオフにすると、すべてのショートカットを一時停止します（メニューバーのアイコンからも切り替えられます）。
- 「最近の実行」に直近の結果が出ます。履歴は保存せず、終了すると消えます。

## 揃え方
- 上・下・左・右：その方向の辺を、その方向でいちばん近いガイド・マージンガイド・ページのエッジ・裁ち落としに揃えます。続けて押すと次の線へ進みます。
- 左上・右上・左下・右下：2つの辺を、それぞれの方向でいちばん近い線に揃えます。
- 中央・水平方向中央・垂直方向中央：中心を、ページ（またはマージンの内側）の中央に揃えます。
- 割り当てたキーのまま：オブジェクトごとに動かし、中央はページの中央です。
- ⌥ を加える：選択全体の境界を基準に、相対位置を保ったまま全体を動かします（［選択をまとめて移動］）。
- ⇧ を加える：中央をマージン（マージンガイドの内側）の中央にします。効くのは中央のボタンと「中央から」です。
- ⌥⇧ を加える：両方です。
- 初期値は ⌃⌘ に、U I O／J K L／M , . です（ボタンの3×3の並びと同じ配置）。水平方向中央・垂直方向中央と「中央から」は未設定です。欄の［初期値に戻す］で戻せます。
- 上・下・左・右は、⌃⌘＋矢印キー（↑ ↓ ← →）でも実行します（⌥・⇧ を加えた形も同じ）。表の下のチェックボックスで切り替えます。表のキーと重なるときは表のキーが優先されます。
- InDesignで開いたパレットの設定（中央揃えの基準・選択をまとめて移動）は使いません。
- 1回の実行は、InDesignの［取り消し］1回で戻せます。

## ショートカット
- ボタンのショートカット：InDesignが前面のときだけ登録します。ほかのアプリでは、同じキーが本来の働きをします。
- InDesign自身のショートカットと重なるキー：［InDesignのキーボードショートカットと重なるキーは、InDesignを優先する］がオン（初期値）なら、このアプリでは登録せず、欄の下に表示します。InDesignで使っているショートカットのセット（~/Library/Preferences/Adobe InDesign の中の .indk。無ければInDesignのデフォルト）を読み、InDesignでショートカットを変えたら、InDesignに戻ったときに読み直します。オフにすると、こちらが優先されます。
- アプリを呼び出すショートカット：設定の「起動・常駐」で割り当てると、どのアプリからでもAlignKeysのウインドウを表示します（初期値は未設定）。
- ⌘0：メインウインドウを開く
- ⌘,：設定
- ⌘W：ウインドウを閉じる
- ⌘?：このヘルプ
同じキーが2か所にあるときは（⌥・⇧ を加えたキーも含む）、表で上にあるほうだけが反応し、下のほうに注意を表示します。

## 設定の共有
設定の「設定の共有」タブで、書き出し・読み込みと設定の同期を使えます。ボタンのホットキー・矢印キーを使うかどうか・ホットキーを使うかどうかを共有します。ログイン時の起動・常駐・メニューバーの表示・アプリを呼び出すホットキー・ウインドウの位置は、Macごとに設定します。

## 権限とプライバシー
- オートメーション（Adobe InDesign）：スクリプトの実行に使います。初めての実行で許可を求められます。
設定はこのMacのアプリの設定に保存します。外部への送信はしません。

## 終了と常駐
ウインドウを閉じても常駐し、ショートカットは働き続けます。Dockやメニューバーのアイコンから再表示できます。［AlignKeys］＞［AlignKeysを終了］（⌘Q）で終了します。

## 困ったときは
- ショートカットが効かない：InDesignが前面か、「ホットキーを使う」がオンかを確かめてください。欄に登録できない旨が出るときは、ほかのアプリがそのキーを使っています。
- 「InDesignを操作する許可がありません」：システム設定＞プライバシーとセキュリティ＞オートメーションで、AlignKeysのAdobe InDesignをオンにしてください。
- 何も動かない・メッセージが出る：InDesignでドキュメントを開き、動かせるオブジェクトを選択してください。揃える先の線が無いときは、InDesignが知らせます。
- 前の実行が終わらない：InDesignでダイアログボックスが開いていると、閉じるまで次の実行を待ちます。待ちは3件までで、それ以上は実行しません。

## 削除と復元
ショートカットは［割り当てを解除］で外します。すべて初期状態に戻すときは、アプリを終了してから、ターミナルで defaults delete jp.dtp-transit.alignkeys を実行します。
""",
 "en": """## Basics
AlignKeys runs the buttons of the InDesign script Align to Nearest Edge (IdAlignToNearestEdgePalette.jsx) with keyboard shortcuts while InDesign is in front. The script is inside the app, so there is nothing else to install.
- Click a field in the Hotkey column, then press the keys to assign. Clear removes the key.
- The From the Center column is for shortcuts that center the object first, then align (like Option-click on the palette). The center buttons have none.
- Click a button name to bring InDesign to the front and run it (each object on its own, centered on the page).
- Open the Palette opens the script's palette in InDesign.
- Turn off "Use hotkeys" at the top right to pause all shortcuts (also from the menu bar icon).
- Recent Runs shows the latest results. Not saved; cleared when the app quits.

## Alignment
- Top, bottom, left, right: aligns the edge facing that direction to the nearest guide, margin guide, page edge, or bleed edge in that direction. Press again to move on to the next line.
- Top left, top right, bottom left, bottom right: aligns two edges to the nearest line in each direction.
- Center, horizontal center, vertical center: aligns the center to the center of the page (or of the margins).
- The key as assigned: each object moves on its own, and centering uses the page.
- Add ⌥: everything moves by the same amount based on the bounds of the whole selection, keeping relative positions (Move selection as a unit).
- Add ⇧: centers on the margins (inside the margin guides). This applies to the center buttons and From the Center.
- Add ⌥⇧: both.
- The defaults are ⌃⌘ with U I O / J K L / M , . (laid out like the 3×3 buttons). Horizontal center, vertical center and From the Center start unassigned. Restore a default from its field.
- Top, bottom, left and right also run with ⌃⌘ and the arrow keys (↑ ↓ ← →), with the same ⌥ / ⇧ forms. Turn this on or off with the checkbox below the table. Keys in the table win when they overlap.
- The settings of the palette opened in InDesign (center basis, move as a unit) are not used.
- Each run is undone with a single Undo in InDesign.

## Shortcuts
- Button shortcuts: registered only while InDesign is in front, so the same keys keep their meaning in other apps.
- Keys that InDesign's own shortcuts use: with "Leave keys that InDesign's own shortcuts use to InDesign" on (the default), they are not registered here and are listed under the field. The app reads the shortcut set InDesign uses (the .indk file in ~/Library/Preferences/Adobe InDesign, or InDesign's default set) and reads it again when InDesign comes back to the front after you changed shortcuts there. When off, this app wins.
- App shortcut: assign it in Settings > Launch & Background to show the AlignKeys window from any app (none by default).
- ⌘0: Open the main window
- ⌘,: Settings
- ⌘W: Close the window
- ⌘?: This help
When two places share a key (including the keys with ⌥ or ⇧ added), only the one higher in the table reacts, and the lower one shows a note.

## Sharing settings
Use the Settings Sharing tab in Settings for export, import and sync. The button hotkeys, whether the arrow keys are used and whether the hotkeys are used are shared. Open at login, keep running, the menu bar icon, the app hotkey and window positions are set on each Mac.

## Permissions and privacy
- Automation (Adobe InDesign): used to run the script. You are asked the first time.
Settings are saved in this Mac's preferences for the app. Nothing is sent outside.

## Quitting and staying open
Closing the window keeps the app running and the shortcuts working. Reopen it from the Dock or the menu bar icon. Quit with AlignKeys > Quit AlignKeys (⌘Q).

## Troubleshooting
- A shortcut does nothing: check that InDesign is in front and "Use hotkeys" is on. If the field says the key could not be registered, another app is using it.
- "Not allowed to control InDesign": turn on Adobe InDesign for AlignKeys in System Settings > Privacy & Security > Automation.
- Nothing moves or a message appears: open a document in InDesign and select objects that can be moved. When there is no line to align to, InDesign tells you.
- An earlier run does not finish: while a dialog box is open in InDesign, the next run waits until it is closed. Up to 3 runs wait; more are skipped.

## Removing and restoring
Clear removes a shortcut. To reset everything, quit the app and run defaults delete jp.dtp-transit.alignkeys in Terminal.
""",
 "zh-Hans": """## 基本操作
AlignKeys 在 InDesign 位于前台时，用键盘快捷键运行 InDesign 脚本“对齐到最近边缘”（IdAlignToNearestEdgePalette.jsx）的按钮。脚本已内置于应用中，无需另外准备。
- 点按表中“快捷键”栏后按下按键即可分配。点按“清除”可移除。
- “从中央”栏用于先移到中央再对齐的快捷键（与在面板上按住 Option 点按相同）。居中按钮没有此栏。
- 点按按钮名称会先将 InDesign 置于前台再运行（逐个移动、以页面为基准）。
- 点按“打开面板”会在 InDesign 中打开脚本的面板。
- 关闭右上角的“使用快捷键”可暂停所有快捷键（也可从菜单栏图标切换）。
- “最近运行”显示最近的结果。不会保存，退出应用时清除。

## 对齐方式
- 上、下、左、右：将该方向的边对齐到该方向最近的参考线、边距参考线、页面边缘或出血。连续按会移到下一条线。
- 左上、右上、左下、右下：将两条边分别对齐到各方向最近的线。
- 中央、水平居中、垂直居中：将中心对齐到页面（或边距内侧）的中央。
- 按分配的按键：逐个移动对象，居中以页面为基准。
- 加 ⌥：以整个选区的边界为基准，保持相对位置整体移动（将所选内容作为整体移动）。
- 加 ⇧：居中到边距（边距参考线内侧）的中央。适用于居中按钮和“从中央”。
- 加 ⌥⇧：两者同时生效。
- 默认是 ⌃⌘ 加 U I O／J K L／M , .（与 3×3 按钮排列相同）。水平居中、垂直居中和“从中央”默认未设置。可在栏中恢复默认值。
- 上、下、左、右也可用 ⌃⌘＋方向键（↑ ↓ ← →）运行（加 ⌥・⇧ 的形式相同）。用表下方的复选框切换。与表中按键重叠时以表中按键优先。
- 不使用在 InDesign 中打开的面板设置（居中对齐基准、将所选内容作为整体移动）。
- 每次运行在 InDesign 中只需一次“还原”即可撤销。

## 快捷键
- 按钮快捷键：仅在 InDesign 位于前台时注册，因此在其他应用中按键保持原有功能。
- 与 InDesign 自身快捷键重叠的按键：“与 InDesign 键盘快捷键重叠的按键优先由 InDesign 使用”打开时（默认），本应用不注册，并在栏下方显示。应用会读取 InDesign 使用的快捷键组（~/Library/Preferences/Adobe InDesign 中的 .indk，没有则为 InDesign 的默认组），在 InDesign 中更改快捷键后，回到 InDesign 时重新读取。关闭时本应用优先。
- 调出应用的快捷键：在设置的“启动与常驻”中分配后，可从任何应用显示 AlignKeys 窗口（默认未设置）。
- ⌘0：打开主窗口
- ⌘,：设置
- ⌘W：关闭窗口
- ⌘?：本帮助
同一按键用于两处时（包括加了 ⌥ 或 ⇧ 的按键），只有表中靠上的会响应，靠下的会显示提示。

## 共享设置
在设置的“共享设置”标签中可以导出、导入和同步设置。共享按钮快捷键、是否使用方向键以及是否使用快捷键。登录时启动、保持运行、菜单栏图标、调出应用的快捷键和窗口位置在每台 Mac 上分别设置。

## 权限与隐私
- 自动化（Adobe InDesign）：用于运行脚本。首次运行时会请求许可。
设置保存在此 Mac 的应用偏好设置中。不会向外部发送任何内容。

## 退出与常驻
关闭窗口后应用仍会常驻，快捷键继续有效。可从 Dock 或菜单栏图标再次打开。选择“AlignKeys”>“退出 AlignKeys”（⌘Q）退出。

## 疑难解答
- 快捷键无效：请确认 InDesign 位于前台、“使用快捷键”已打开。栏中显示无法注册时，表示按键被其他应用占用。
- “没有控制 InDesign 的权限”：请在“系统设置”>“隐私与安全性”>“自动化”中为 AlignKeys 打开 Adobe InDesign。
- 没有移动或出现信息：请在 InDesign 中打开文档并选择可移动的对象。没有可对齐的线时，InDesign 会提示。
- 之前的运行未结束：InDesign 中打开对话框时，下一次运行会等待到对话框关闭。最多等待 3 次，超出的会被跳过。

## 删除与恢复
点按“清除”可移除快捷键。若要全部恢复初始状态，请退出应用后在终端中运行 defaults delete jp.dtp-transit.alignkeys。
""",
 "ko": """## 기본 조작
AlignKeys는 InDesign이 앞에 있을 때 InDesign 스크립트 '가장 가까운 가장자리에 맞추기'(IdAlignToNearestEdgePalette.jsx)의 버튼을 키보드 단축키로 실행합니다. 스크립트가 앱에 들어 있으므로 따로 준비할 필요가 없습니다.
- 표의 '단축키' 칸을 클릭한 뒤 키를 누르면 지정됩니다. [지우기]로 뺍니다.
- '가운데에서' 칸은 먼저 가운데로 옮긴 뒤 맞추는 단축키입니다(팔레트에서 Option+클릭과 같음). 가운데 버튼에는 없습니다.
- 버튼 이름을 클릭하면 InDesign을 앞으로 가져온 뒤 실행합니다(객체마다, 페이지 기준).
- [팔레트 열기]로 InDesign에서 스크립트의 팔레트를 엽니다.
- 오른쪽 위의 '단축키 사용'을 끄면 모든 단축키를 일시 정지합니다(메뉴 막대 아이콘에서도 전환 가능).
- '최근 실행'에 최근 결과가 표시됩니다. 저장하지 않으며 앱을 종료하면 지워집니다.

## 맞춤 방식
- 위·아래·왼쪽·오른쪽: 그 방향의 가장자리를 그 방향에서 가장 가까운 안내선·여백 안내선·페이지 가장자리·도련에 맞춥니다. 이어서 누르면 다음 선으로 넘어갑니다.
- 왼쪽 위·오른쪽 위·왼쪽 아래·오른쪽 아래: 두 가장자리를 각 방향에서 가장 가까운 선에 맞춥니다.
- 가운데·가로 가운데·세로 가운데: 중심을 페이지(또는 여백 안쪽)의 가운데에 맞춥니다.
- 지정한 키 그대로: 객체마다 옮기고 가운데는 페이지의 가운데입니다.
- ⌥를 더함: 선택 전체의 경계를 기준으로 상대 위치를 유지한 채 전체를 옮깁니다('선택 항목을 하나로 이동').
- ⇧를 더함: 가운데를 여백(여백 안내선 안쪽)의 가운데로 합니다. 가운데 버튼과 '가운데에서'에 적용됩니다.
- ⌥⇧를 더함: 둘 다입니다.
- 기본값은 ⌃⌘에 U I O / J K L / M , . 입니다(3×3 버튼 배치와 같음). 가로 가운데·세로 가운데와 '가운데에서'는 지정되어 있지 않습니다. 칸에서 기본값으로 되돌릴 수 있습니다.
- 위·아래·왼쪽·오른쪽은 ⌃⌘+화살표 키(↑ ↓ ← →)로도 실행합니다(⌥·⇧를 더한 형태도 같음). 표 아래의 체크상자로 전환합니다. 표의 키와 겹치면 표의 키가 우선합니다.
- InDesign에서 연 팔레트의 설정(가운데 맞춤 기준, 선택 항목을 하나로 이동)은 쓰지 않습니다.
- 한 번의 실행은 InDesign에서 [실행 취소] 한 번으로 되돌릴 수 있습니다.

## 단축키
- 버튼 단축키: InDesign이 앞에 있을 때만 등록하므로 다른 앱에서는 같은 키가 원래 기능을 합니다.
- InDesign 자체 단축키와 겹치는 키: 'InDesign 키보드 단축키와 겹치는 키는 InDesign을 우선'이 켜져 있으면(기본값) 이 앱에서는 등록하지 않고 칸 아래에 표시합니다. InDesign이 쓰는 단축키 세트(~/Library/Preferences/Adobe InDesign 안의 .indk, 없으면 InDesign 기본 세트)를 읽고, InDesign에서 단축키를 바꾸면 InDesign으로 돌아올 때 다시 읽습니다. 끄면 이 앱이 우선합니다.
- 앱을 불러오는 단축키: 설정의 '실행 및 상주'에서 지정하면 어느 앱에서든 AlignKeys 윈도우를 표시합니다(기본값은 없음).
- ⌘0: 메인 윈도우 열기
- ⌘,: 설정
- ⌘W: 윈도우 닫기
- ⌘?: 이 도움말
같은 키가 두 곳에 있으면(⌥·⇧를 더한 키 포함) 표에서 위에 있는 것만 반응하고 아래쪽에 안내를 표시합니다.

## 설정 공유
설정의 '설정 공유' 탭에서 내보내기, 가져오기와 동기화를 사용할 수 있습니다. 버튼 단축키, 화살표 키 사용 여부, 단축키 사용 여부를 공유합니다. 로그인 시 실행, 계속 실행, 메뉴 막대 아이콘, 앱 호출 단축키, 윈도우 위치는 Mac마다 설정합니다.

## 권한과 개인정보
- 자동화(Adobe InDesign): 스크립트 실행에 사용합니다. 처음 실행할 때 허용을 요청합니다.
설정은 이 Mac의 앱 환경설정에 저장합니다. 외부로 아무것도 보내지 않습니다.

## 종료와 상주
윈도우를 닫아도 상주하며 단축키는 계속 작동합니다. Dock이나 메뉴 막대 아이콘에서 다시 열 수 있습니다. [AlignKeys] > [AlignKeys 종료](⌘Q)로 종료합니다.

## 문제 해결
- 단축키가 작동하지 않음: InDesign이 앞에 있는지, '단축키 사용'이 켜져 있는지 확인하세요. 칸에 등록할 수 없다고 나오면 다른 앱이 그 키를 사용 중입니다.
- 'InDesign을 제어할 권한이 없습니다': 시스템 설정 > 개인정보 보호 및 보안 > 자동화에서 AlignKeys의 Adobe InDesign을 켜세요.
- 아무것도 움직이지 않거나 메시지가 나옴: InDesign에서 문서를 열고 옮길 수 있는 객체를 선택하세요. 맞출 선이 없으면 InDesign이 알려 줍니다.
- 이전 실행이 끝나지 않음: InDesign에서 대화상자가 열려 있으면 닫을 때까지 다음 실행을 기다립니다. 대기는 3건까지이며 그 이상은 실행하지 않습니다.

## 삭제와 복원
[지우기]로 단축키를 뺍니다. 모두 처음 상태로 되돌리려면 앱을 종료한 뒤 터미널에서 defaults delete jp.dtp-transit.alignkeys를 실행합니다.
""",
}
