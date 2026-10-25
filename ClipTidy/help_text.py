# ClipTidy help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
ClipTidyは、どのアプリでコピーした文字でも、一覧のルールに合わせて自動で書き換えます。たとえばURLの余分な引数を削ったり、決まった文面を整えたりします。書き換えた内容はそのままペーストできます。
- ルールは上から順に適用します。前のルールで書き換えた結果に、次のルールを当てます。
- 一覧のチェックボックスでルールごとにオン・オフを切り替えます。
- 右上の「コピーを監視」をオフにすると、書き換えを止めます（メニューバーのアイコンや［ファイル］メニューの「監視を一時停止」でも切り替えられます）。
- 「試す」の欄に文字を入力すると、コピーせずに結果を確認できます。
- 「最近の書き換え」に直近の結果が出ます。履歴は保存せず、終了すると消えます。

## ルールの編集
＋ボタン（⌘N）で追加し、ダブルクリックか［編集…］で変更します。並べ替えはドラッグか↑↓ボタンで行います。
- 条件：この正規表現に一致するときだけ書き換えます。空欄なら検索に一致したときに書き換えます。
- 検索・置換：検索に一致した部分を置換の文字に変えます。置換が空欄なら削除します。正規表現では \\1 または $1 で一致したグループ、\\n で改行を入れます。
- 正規表現をオフにすると、検索も置換もそのままの文字として扱います。
- コピーしたアプリ：選んだアプリでコピーしたときだけ使います。
- 書き換えたら画面に表示：画面の右上に結果を数秒表示します（表示時間は設定の「一般」）。
- 「最初のルールを追加」で、最初から入っていたルールのうち一覧にないものを戻せます。

## Dropboxの共有リンク
末尾が dl=0 のDropboxの共有リンクをコピーすると、画面の右上に「Dropboxのリンクの準備ができました」と表示します。［直接ダウンロード］を押すと、クリップボードのリンクを dl=1 に変えます。表示の後に別の内容をコピーしていた場合は変えません。設定の「一般」でオフにできます。

## 設定
［ClipTidy］＞［設定…］（⌘,）で開きます。
- 起動・常駐：ログイン時に起動、Dockとアプリケーションスイッチャーに表示しない、ウインドウを閉じても常駐、メニューバーのアイコン、アプリ起動のホットキー、アプリを呼び出すホットキー（初期値 ⌃⌥T）。
- 一般：監視のオン・オフ、Dropboxの共有リンクの確認、書き換えの表示時間。
- 対象外アプリ：ここに入れたアプリが前面にあるときにコピーした内容は書き換えません。最初はIllustratorとKeynoteが入っています。
- 設定の共有：ルールなどの書き出し・読み込みと同期。
- 情報：バージョンとリンク。

## ホットキー
- ⌃⌥T：どのアプリからでもClipTidyのウインドウを表示（起動中のとき。設定の「起動・常駐」で変更・無効化できます）
- ⌘N：新しいルール
- ⌘0：メインウインドウを開く
- ⌘,：設定
- ⌘W：ウインドウを閉じる
- ⌘?：このヘルプ

## 権限とプライバシー
特別な許可は不要です。クリップボードの変化を0.3秒ごとに確かめ、変わったときだけ文字を読みます。パスワード管理アプリが「秘密」「一時的」と印を付けた内容と、画像だけの内容は読みません。書き換えるとクリップボードは書式のない文字になります。内容を外部に送ったり保存したりはしません。

## 常駐と終了
「ウインドウを閉じても常駐」がオンのときは、ウインドウを閉じても監視を続けます。DockやFinderから開き直すか、メニューバーのアイコンからウインドウを表示できます。終了するには［ClipTidy］＞［ClipTidyを終了］（⌘Q）を選びます。

## 困ったときは
- 書き換わらない：「コピーを監視」がオンか、前面のアプリが対象外アプリに入っていないか、ルールがオンか、「コピーしたアプリ」の指定が合っているかを確かめてください。「試す」の欄で結果を確認できます。
- 書き換えたくない内容まで変わった：ルールの「条件」を絞るか、そのアプリを対象外アプリに入れてください。
- ルールが赤字の警告になる：正規表現の書き方が正しくありません。編集画面の下に理由が出ます。
""",
 "en": """## Basics
ClipTidy rewrites text copied in any app according to the rules in its list, for example removing extra URL parameters or tidying a fixed message. The rewritten text is ready to paste.
- Rules apply from the top. Each rule sees the result of the rules above it.
- Use the checkbox in the list to turn each rule on or off.
- Turn off Watch the clipboard at the top right to stop rewriting (also from the menu bar icon or File > Pause Watching).
- Type in Try It to preview the result without copying.
- Recent Rewrites shows the latest results. They are not saved and are cleared when the app quits.

## Editing rules
Add with + (⌘N); double-click or choose Edit… to change. Reorder by dragging or with the arrow buttons.
- Condition: rewrite only when this regular expression matches. When empty, the rule applies whenever Find matches.
- Find / Replace: the match is replaced with Replace; an empty Replace removes it. With regular expressions, \\1 or $1 inserts a group and \\n a line break.
- With Regular expression off, Find and Replace are used as plain text.
- Copied in: use the rule only for copies made in the chosen app.
- Show when rewritten: shows the result at the top right for a few seconds (time set in Settings > General).
- Add Starter Rules brings back starter rules that are missing from the list.

## Dropbox shared links
When you copy a Dropbox shared link ending in dl=0, a panel at the top right says the link is ready. Direct Download changes the link on the clipboard to dl=1. If something else was copied in the meantime, nothing is changed. Turn this off in Settings > General.

## Settings
Open with ClipTidy > Settings… (⌘,).
- Launch & Residency: open at login, hide from the Dock and App Switcher, keep running after closing the window, menu bar icon, app launch keyboard shortcut and the hotkey that shows the window (default ⌃⌥T).
- General: watching on or off, the Dropbox link prompt and how long rewrites are shown.
- Excluded Apps: content copied while one of these apps is in front is never rewritten. Illustrator and Keynote are listed at first.
- Sharing: export, import and sync of the rules and other settings.
- About: version and links.

## Hotkeys
- ⌃⌥T: show the ClipTidy window from any app (while running; change or turn off in Launch & Residency)
- ⌘N: new rule
- ⌘0: open the main window
- ⌘,: settings
- ⌘W: close the window
- ⌘?: this help

## Permissions and privacy
No special permission is needed. ClipTidy checks every 0.3 seconds whether the clipboard changed and reads the text only after a change. Content marked secret or temporary by password managers and image-only content is never read. Rewritten text is placed on the clipboard as plain text. Nothing is sent anywhere or saved.

## Keeping it running and quitting
With Keep running after closing the window on, watching continues after the window is closed. Reopen from the Dock or Finder, or from the menu bar icon. To quit, choose ClipTidy > Quit ClipTidy (⌘Q).

## Troubleshooting
- Nothing is rewritten: check that Watch the clipboard is on, the front app is not an excluded app, the rule is on and Copied in matches. Try It shows the result.
- Too much is rewritten: narrow the rule's Condition or add the app to Excluded Apps.
- A rule shows a red warning: the regular expression is invalid; the reason appears in the editor.
""",
 "zh-Hans": """## 基本操作
ClipTidy 会按列表中的规则自动改写在任何应用中复制的文本，例如删除网址中多余的参数，或整理固定的文案。改写后的文本可直接粘贴。
- 规则从上到下应用，每条规则作用于上一条规则改写后的结果。
- 用列表中的复选框逐条开启或关闭规则。
- 关闭右上角的“监视剪贴板”即可停止改写（也可通过菜单栏图标或“文件”>“暂停监视”切换）。
- 在“试用”中输入文本，无需复制即可预览结果。
- “最近的改写”显示最近的结果。不会保存，退出应用时清除。

## 编辑规则
用 +（⌘N）添加，双击或选择“编辑…”修改。拖动或用箭头按钮调整顺序。
- 条件：仅在匹配此正则表达式时改写。留空时只要“查找”匹配就改写。
- 查找／替换：将匹配部分替换为“替换”中的文本；“替换”留空则删除。正则表达式中 \\1 或 $1 插入分组，\\n 插入换行。
- 关闭“正则表达式”后，“查找”和“替换”按普通文本处理。
- 复制所在应用：仅对在所选应用中复制的内容使用此规则。
- 改写后显示：在右上角显示结果几秒（时长在“设置”>“通用”中设定）。
- “添加初始规则”可恢复列表中缺少的初始规则。

## Dropbox 共享链接
复制末尾为 dl=0 的 Dropbox 共享链接时，右上角会提示链接已准备好。点按“直接下载”会将剪贴板中的链接改为 dl=1。如果期间复制了其他内容，则不做更改。可在“设置”>“通用”中关闭。

## 设置
通过“ClipTidy”>“设置…”（⌘,）打开。
- 启动与常驻：登录时启动、不在程序坞和应用程序切换器中显示、关闭窗口后继续运行、菜单栏图标、启动应用快捷键，以及显示窗口的快捷键（默认 ⌃⌥T）。
- 通用：开启或关闭监视、Dropbox 链接提示、改写提示的显示时间。
- 排除的应用：这些应用位于前台时复制的内容不会被改写。初始包含 Illustrator 和 Keynote。
- 设置共享：规则等设置的导出、导入和同步。
- 关于：版本和链接。

## 快捷键
- ⌃⌥T：在任何应用中显示 ClipTidy 窗口（运行时；可在“启动与常驻”中更改或停用）
- ⌘N：新建规则
- ⌘0：打开主窗口
- ⌘,：设置
- ⌘W：关闭窗口
- ⌘?：本帮助

## 权限与隐私
无需特殊权限。ClipTidy 每 0.3 秒检查剪贴板是否变化，仅在变化后读取文本。不会读取密码管理器标记为机密或临时的内容，也不会读取仅含图像的内容。改写后的文本以无格式文本放回剪贴板。不会发送或保存任何内容。

## 常驻与退出
开启“关闭窗口后继续运行”时，关闭窗口后仍继续监视。可从程序坞或访达重新打开，或通过菜单栏图标显示窗口。要退出，请选择“ClipTidy”>“退出 ClipTidy”（⌘Q）。

## 疑难解答
- 没有改写：请确认“监视剪贴板”已开启、前台应用不在排除列表中、规则已开启且“复制所在应用”匹配。可在“试用”中查看结果。
- 改写了不想改的内容：请收紧规则的“条件”，或将该应用加入排除的应用。
- 规则显示红色警告：正则表达式无效，原因显示在编辑窗口中。
""",
 "ko": """## 기본 조작
ClipTidy는 어느 앱에서 복사한 텍스트든 목록의 규칙에 따라 자동으로 바꿉니다. 예를 들어 URL의 불필요한 매개변수를 지우거나 정해진 문구를 정리합니다. 바뀐 텍스트는 그대로 붙여넣을 수 있습니다.
- 규칙은 위에서부터 적용합니다. 각 규칙은 위 규칙이 바꾼 결과에 적용됩니다.
- 목록의 체크박스로 규칙마다 켜고 끕니다.
- 오른쪽 위의 '클립보드 감시'를 끄면 변환을 멈춥니다(메뉴 막대 아이콘이나 파일 > 감시 일시 정지로도 전환할 수 있습니다).
- '시험'에 텍스트를 입력하면 복사하지 않고 결과를 확인할 수 있습니다.
- '최근 변환'에 최근 결과가 표시됩니다. 저장하지 않으며 앱을 종료하면 지워집니다.

## 규칙 편집
+(⌘N)로 추가하고, 두 번 클릭하거나 편집…으로 변경합니다. 드래그하거나 화살표 버튼으로 순서를 바꿉니다.
- 조건: 이 정규 표현식과 일치할 때만 바꿉니다. 비우면 찾기가 일치할 때 바꿉니다.
- 찾기·바꾸기: 일치한 부분을 바꾸기의 텍스트로 바꿉니다. 바꾸기가 비어 있으면 삭제합니다. 정규 표현식에서는 \\1 또는 $1로 그룹, \\n으로 줄바꿈을 넣습니다.
- 정규 표현식을 끄면 찾기와 바꾸기를 일반 텍스트로 다룹니다.
- 복사한 앱: 선택한 앱에서 복사했을 때만 사용합니다.
- 변환하면 화면에 표시: 오른쪽 위에 결과를 몇 초 표시합니다(시간은 설정 > 일반).
- '기본 규칙 추가'로 목록에 없는 기본 규칙을 되돌릴 수 있습니다.

## Dropbox 공유 링크
끝이 dl=0인 Dropbox 공유 링크를 복사하면 오른쪽 위에 링크가 준비되었다고 표시합니다. 직접 다운로드를 누르면 클립보드의 링크를 dl=1로 바꿉니다. 그 사이 다른 내용을 복사했다면 바꾸지 않습니다. 설정 > 일반에서 끌 수 있습니다.

## 설정
ClipTidy > 설정…(⌘,)으로 엽니다.
- 실행·상주: 로그인 시 실행, Dock 및 앱 전환기에 표시 안 함, 윈도우를 닫아도 계속 실행, 메뉴 막대 아이콘, 앱 실행 키보드 단축키, 윈도우를 표시하는 단축키(기본 ⌃⌥T).
- 일반: 감시 켜기·끄기, Dropbox 링크 확인, 변환 표시 시간.
- 제외할 앱: 이 앱이 앞에 있을 때 복사한 내용은 바꾸지 않습니다. 처음에는 Illustrator와 Keynote가 들어 있습니다.
- 설정 공유: 규칙 등의 내보내기·가져오기와 동기화.
- 정보: 버전과 링크.

## 단축키
- ⌃⌥T: 어느 앱에서든 ClipTidy 윈도우 표시(실행 중일 때. 실행·상주에서 변경·해제 가능)
- ⌘N: 새 규칙
- ⌘0: 메인 윈도우 열기
- ⌘,: 설정
- ⌘W: 윈도우 닫기
- ⌘?: 이 도움말

## 권한과 개인정보
특별한 권한은 필요 없습니다. 0.3초마다 클립보드가 바뀌었는지 확인하고, 바뀌었을 때만 텍스트를 읽습니다. 암호 관리 앱이 비밀·임시로 표시한 내용과 이미지뿐인 내용은 읽지 않습니다. 바꾼 텍스트는 서식 없는 텍스트로 클립보드에 넣습니다. 내용을 외부로 보내거나 저장하지 않습니다.

## 상주와 종료
'윈도우를 닫아도 계속 실행'이 켜져 있으면 윈도우를 닫아도 감시를 계속합니다. Dock이나 Finder에서 다시 열거나 메뉴 막대 아이콘에서 윈도우를 표시할 수 있습니다. 종료하려면 ClipTidy > ClipTidy 종료(⌘Q)를 선택합니다.

## 문제 해결
- 바뀌지 않음: '클립보드 감시'가 켜져 있는지, 앞의 앱이 제외할 앱이 아닌지, 규칙이 켜져 있는지, '복사한 앱'이 맞는지 확인하세요. '시험'에서 결과를 볼 수 있습니다.
- 바꾸고 싶지 않은 내용까지 바뀜: 규칙의 조건을 좁히거나 그 앱을 제외할 앱에 넣으세요.
- 규칙에 빨간 경고가 표시됨: 정규 표현식이 올바르지 않습니다. 편집 화면 아래에 이유가 표시됩니다.
""",
}
