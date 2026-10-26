# ScreenTake help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
ScreenTakeは、画面（または1つのウインドウ）・システム音声・マイク・カメラをまとめて収録し、カット・ズーム・クリック表示を付けてMP4・MOV・GIFに書き出します。
- メインウインドウで「収録する範囲」（画面全体／ウインドウ）・音声・カメラ・ポインタを選び、［N秒後に収録を開始］をクリックします。
- 収録中は画面に何も重ねず、メニューバーに赤い丸と経過時間を表示します（カウントダウン中は残り秒数）。クリックすると［収録を停止］［一時停止］［再開］を選べます。ScreenTakeのウインドウは収録に写りません。
- 収録のホットキー（初期値 ⌃⌥⇧⌘6）を押すと、どのアプリからでも開始・停止できます。メニューバーのアイコンからも開始・停止できます。
- 停止すると、編集ウインドウが開きます（設定で変更できます）。収録したものはメインウインドウの一覧に並び、ダブルクリックで編集を開き直せます。

## 編集
編集ウインドウの上は書き出し結果と同じプレビュー、右は設定、下はタイムラインです。
- 再生位置の移動：目盛りをクリック・ドラッグ。Space で再生／一時停止、← → で1フレームずつ移動します。
- 範囲の削除：タイムラインの映像をドラッグして範囲を選び、［選択範囲を削除］（delete キー）。削除したところはオレンジの線で示します。
- 前後のトリミング：［先頭から再生位置までを削除］（⌘[）、［再生位置から末尾までを削除］（⌘]）。
- ズーム：［ズームを追加］（⌥⌘Z）で選択範囲（なければ再生位置から3秒）を拡大します。タイムラインのズームをクリックすると、右側で倍率・ポインタを追う／中心の位置を変えられます。端をドラッグすると長さ、中をドラッグすると位置が変わります。始めと終わりは滑らかに拡大・縮小します。
- ポインタ：ポインタは映像とは別に記録しています。表示のオン／オフ、大きさ（0.5〜3倍）、動きを滑らかにする、を変えられます。タイムラインで範囲を選んで［選択範囲で隠す］を押すと、その間だけポインタを消せます（ポインタのレーンに点線で表示。［選択範囲で表示］で戻します）。
- クリック表示：収録中にクリックした位置に輪を表示します（右クリックは青）。
- カメラ：表示・位置・形（円／角丸の四角）・大きさ。
- 音量：システム音声とマイクを別々に調整できます（0〜200%）。
- 編集はすべて ⌘Z で取り消し、⇧⌘Z でやり直せます。編集内容は自動で保存されます。［削除した部分をすべて戻す］で削除を元に戻せます。

## 書き出し
右側の「書き出し」で形式（MP4／MOV／GIF）と大きさを選び、［書き出す…］（⌘E）で保存先を指定します。
- MP4・MOV：収録のまま、2160p、1440p、1080p、720p。HEVC（H.265）をオンにすると小さくなります（古い機器では再生できないことがあります）。
- GIF：横幅（480〜1280px）とコマ数（5〜20fps）。音声は入りません。長い動画はファイルが大きくなります。
- 書き出し中は進み具合が表示され、［キャンセル］（Esc）で中止できます。中止・失敗したときは途中のファイルを残しません。同じ名前のファイルは書き出しが成功したときだけ置き換えます。

## 設定
［ScreenTake］＞［設定…］（⌘,）で開きます。
- 起動・常駐：ログイン時に起動、Dockとアプリケーションスイッチャーに表示しない、ウインドウを閉じても常駐、メニューバーのアイコン、アプリ起動のホットキー、アプリを呼び出すホットキー（初期値は未設定）、権限の状態。
- 収録：収録のホットキー、収録までの秒数（0〜10秒、初期値3秒）、フレームレート（30／60fps）。
- 出力：収録の保存先（初期値は「ムービー」＞「ScreenTake」）、収録したあと編集ウインドウを開く。
- 設定の共有：設定の書き出し・読み込みと同期。
- 情報：バージョンとリンク。

## ホットキー
- ⌃⌥⇧⌘6：収録の開始・停止（どのアプリからでも。設定の「収録」で変更・無効化できます）
- ⇧⌘R：収録の開始・停止（ScreenTakeが前面のとき）
- ⌘O：収録を開く
- ⌘E：書き出す
- Space：再生／一時停止、← →：1フレーム移動、delete：選択範囲を削除、⌘[ ⌘]：前後を削除、⌥⌘Z：ズームを追加（編集ウインドウ）
- ⌘Z／⇧⌘Z：取り消す／やり直す
- ⌘0：メインウインドウを開く、⌘,：設定、⌘W：ウインドウを閉じる、⌘?：このヘルプ

## 権限
- 画面収録とシステムオーディオ録音（必須）：初めて収録するときにmacOSが確認します。許可したらScreenTakeを開き直してください。
- マイク・カメラ：オンにして収録するときだけ確認します。拒否してもマイク・カメラなしで収録できます。
- 状態は設定の「起動・常駐」の「権限」で確認でき、［設定を開く］でシステム設定を開きます。
収録した内容はこのMacにだけ保存し、どこにも送信しません（更新確認を除く。配信先は未設定）。

## 保存場所
収録ごとに「収録 2026-10-26 14.05.10」のようなフォルダを作り、収録した動画（recording.mov）と編集内容（project.json）を入れます。編集しても元の動画は書き換えません。収録に失敗したときは、途中のフォルダを残しません。

## 常駐と終了
「ウインドウを閉じても常駐」がオンのときは、ウインドウを閉じてもScreenTakeは動き続け、収録のホットキーも使えます。DockやFinderから開き直すか、メニューバーのアイコンからウインドウを表示します。終了は［ScreenTake］＞［ScreenTakeを終了］（⌘Q）。収録中に終了すると、動画を閉じて保存してから終了します。書き出し中は確認が出ます。

## 困ったとき
- 「画面収録が許可されていません」：システム設定＞プライバシーとセキュリティ＞画面収録とシステムオーディオ録音でScreenTakeをオンにし、ScreenTakeを開き直してください。
- ウインドウが一覧にない：ウインドウを表示してから一覧を更新（↻）します。しまったウインドウ・ほかの操作スペースのウインドウは出ません。
- ウインドウを収録中に動かすと、クリック位置の表示がずれることがあります。
- システム音声が入らない：ScreenTake自身の音とミュート中の音は録りません。
- ホットキーが効かない：ほかのアプリが同じキーを使っている可能性があります。設定の「収録」で別のキーにしてください。
- 削除：ScreenTakeを終了し、アプリケーションフォルダからゴミ箱に入れます。収録は保存先に残ります。
""",
 "en": """## Basics
ScreenTake records the screen (or one window), system audio, the microphone and the camera together, then lets you cut, zoom and show clicks before exporting MP4, MOV or GIF.
- In the main window choose what to record (entire screen or a window), sound, camera and pointer, then click Record in N s.
- While recording, nothing is placed over the screen: the menu bar shows a red dot and the time (the seconds left during the countdown). Click it for Stop Recording, Pause and Resume. ScreenTake's windows do not appear in the recording.
- The record hotkey (default ⌃⌥⇧⌘6) starts and stops recording from any app. The menu bar icon can start and stop it too.
- When you stop, the editor opens (changeable in Settings). Recordings are listed in the main window; double-click one to edit it again.

## Editing
The editor shows a preview of the result at the top, settings on the right and the timeline at the bottom.
- Move the playhead: click or drag the ruler. Space plays and pauses; ← → move one frame.
- Delete a range: drag across the picture on the timeline, then Delete Selection (delete key). Orange lines mark where parts were removed.
- Trim: Trim to Playhead from Start (⌘[) and Trim from Playhead to End (⌘]).
- Zoom: Add Zoom (⌥⌘Z) zooms in on the selection, or 3 seconds from the playhead. Click a zoom on the timeline to change its scale, follow the pointer or set its center on the right. Drag its ends to change the length, its middle to move it. Zooms ease in and out.
- Pointer: the pointer is recorded separately from the picture. Turn it on or off, change its size (0.5–3×) and smooth its movement. Select a range on the timeline and click Hide in Selection to remove the pointer there (dashed in the pointer lane; Show in Selection brings it back).
- Clicks: rings appear where you clicked while recording (blue for right clicks).
- Camera: show, position, shape (circle or rounded square) and size.
- Volume: system audio and microphone separately (0–200%).
- Every edit can be undone with ⌘Z and redone with ⇧⌘Z. Edits are saved automatically. Restore All Deleted Parts brings back what you removed.

## Export
Choose the format (MP4, MOV, GIF) and size under Export on the right, then Export… (⌘E) and pick where to save.
- MP4 and MOV: as recorded, 2160p, 1440p, 1080p or 720p. HEVC (H.265) makes smaller files (older devices may not play them).
- GIF: width (480–1280 px) and frame rate (5–20 fps). No sound. Long movies make large files.
- Progress is shown while exporting; Cancel (Esc) stops it. A canceled or failed export leaves no partial file, and an existing file with the same name is replaced only on success.

## Settings
Open with ScreenTake › Settings… (⌘,).
- Startup & Background: open at login, hide from Dock and App Switcher, keep running after closing the window, menu bar icon, app launch shortcut, show-app hotkey (not set by default), permission status.
- Recording: record hotkey, countdown (0–10 s, default 3 s), frame rate (30 or 60 fps).
- Output: recordings folder (default Movies › ScreenTake), open the editor after recording.
- Sharing settings: export, import and sync settings.
- About: version and links.

## Hotkeys
- ⌃⌥⇧⌘6: start or stop recording (from any app; change or turn off under Recording in Settings)
- ⇧⌘R: start or stop recording (with ScreenTake in front)
- ⌘O: open a recording
- ⌘E: export
- Space: play/pause, ← →: one frame, delete: delete the selection, ⌘[ ⌘]: trim, ⌥⌘Z: add zoom (editor)
- ⌘Z / ⇧⌘Z: undo / redo
- ⌘0: main window, ⌘,: settings, ⌘W: close window, ⌘?: this help

## Permissions
- Screen & System Audio Recording (required): macOS asks the first time you record. Reopen ScreenTake after allowing it.
- Microphone and camera: asked only when you record with them on. If refused, you can still record without them.
- See the status under Permissions in the Startup & Background tab; Open Settings opens System Settings.
Recordings stay on this Mac and are never sent anywhere (except update checks; no update feed is set yet).

## Where recordings are saved
Each recording gets a folder such as “Recording 2026-10-26 14.05.10” holding the movie (recording.mov) and the edits (project.json). Editing never changes the recorded movie. A failed recording leaves no folder behind.

## Keep running and quit
With Keep running after closing the window on, ScreenTake keeps running after you close the window and the record hotkey still works. Reopen it from the Dock or Finder, or show the window from the menu bar icon. Quit with ScreenTake › Quit ScreenTake (⌘Q). Quitting while recording saves the movie first; while exporting, you are asked first.

## Troubleshooting
- “Screen Recording is not allowed”: turn on ScreenTake in System Settings › Privacy & Security › Screen & System Audio Recording, then reopen ScreenTake.
- A window is missing from the list: show the window, then refresh (↻). Minimized windows and windows in other Spaces are not listed.
- Moving a window while recording it can shift the click rings.
- No system audio: ScreenTake's own sound and muted sound are not recorded.
- The hotkey does nothing: another app may use the same key. Choose another under Recording in Settings.
- Uninstall: quit ScreenTake and move it from Applications to the Trash. Recordings stay in their folder.
""",
 "zh-Hans": """## 基本操作
ScreenTake 可同时录制屏幕（或一个窗口）、系统声音、麦克风和摄像头，并在剪切、缩放、显示点按后导出为 MP4、MOV 或 GIF。
- 在主窗口中选择录制范围（整个屏幕或窗口）、声音、摄像头和指针，然后点按“N 秒后开始录制”。
- 录制期间不会在屏幕上叠加任何内容，菜单栏会显示红点和经过时间（倒计时期间显示剩余秒数）。点按即可选择“停止录制”“暂停”“继续”。ScreenTake 的窗口不会被录入。
- 按录制快捷键（默认 ⌃⌥⇧⌘6）可在任何应用中开始或停止录制。也可以从菜单栏图标开始或停止。
- 停止后会打开编辑窗口（可在设置中更改）。录制内容列在主窗口中，连按即可再次编辑。

## 编辑
编辑窗口上方是与导出结果相同的预览，右侧是设置，下方是时间线。
- 移动播放位置：点按或拖移标尺。空格键播放/暂停，← → 逐帧移动。
- 删除范围：在时间线的画面上拖移选择范围，然后点按“删除所选范围”（delete 键）。删除处以橙色线标示。
- 修剪：“删除开头到播放位置”（⌘[）、“删除播放位置到结尾”（⌘]）。
- 缩放：“添加缩放”（⌥⌘Z）会放大所选范围（没有时为播放位置起 3 秒）。点按时间线上的缩放，可在右侧更改倍率、跟随指针或中心位置。拖移两端改变长度，拖移中间移动位置。开始和结束会平滑过渡。
- 指针：指针与画面分开录制。可打开或关闭、更改大小（0.5–3 倍）并平滑移动。在时间线上选择范围后点按“在所选范围内隐藏”，即可在该范围内隐藏指针（在指针轨道中以虚线显示；“在所选范围内显示”可恢复）。
- 点按：在录制时点按的位置显示圆环（右键为蓝色）。
- 摄像头：显示、位置、形状（圆形或圆角方形）和大小。
- 音量：可分别调整系统声音和麦克风（0–200%）。
- 所有编辑都可用 ⌘Z 撤销、⇧⌘Z 重做，并会自动存储。“恢复所有删除的部分”可还原删除。

## 导出
在右侧“导出”中选择格式（MP4、MOV、GIF）和大小，然后点按“导出…”（⌘E）并选择存储位置。
- MP4 和 MOV：与录制相同、2160p、1440p、1080p 或 720p。打开 HEVC (H.265) 可减小文件（旧设备可能无法播放）。
- GIF：宽度（480–1280 px）和帧率（5–20 fps）。不含声音。影片较长时文件会很大。
- 导出时会显示进度，点按“取消”（Esc）可停止。取消或失败时不会保留不完整的文件，同名文件仅在成功时替换。

## 设置
通过“ScreenTake”>“设置…”（⌘,）打开。
- 启动与后台：登录时启动、不在程序坞和应用程序切换器中显示、关闭窗口后继续运行、菜单栏图标、启动应用快捷键、显示应用快捷键（默认未设置）、权限状态。
- 录制：录制快捷键、倒计时（0–10 秒，默认 3 秒）、帧率（30 或 60 fps）。
- 输出：录制内容存储位置（默认“影片”>“ScreenTake”）、录制后打开编辑窗口。
- 设置共享：导出、导入和同步设置。
- 关于：版本和链接。

## 快捷键
- ⌃⌥⇧⌘6：开始或停止录制（任何应用中；可在设置的“录制”中更改或停用）
- ⇧⌘R：开始或停止录制（ScreenTake 在前台时）
- ⌘O：打开录制内容
- ⌘E：导出
- 空格：播放/暂停，← →：逐帧，delete：删除所选范围，⌘[ ⌘]：修剪，⌥⌘Z：添加缩放（编辑窗口）
- ⌘Z / ⇧⌘Z：撤销 / 重做
- ⌘0：主窗口，⌘,：设置，⌘W：关闭窗口，⌘?：此帮助

## 权限
- 录屏与系统录音（必需）：首次录制时 macOS 会询问。允许后请重新打开 ScreenTake。
- 麦克风和摄像头：仅在打开后录制时询问。拒绝后仍可在不使用它们的情况下录制。
- 可在“启动与后台”标签页的“权限”中查看状态，“打开设置”会打开系统设置。
录制内容仅保存在此 Mac 上，不会发送到任何地方（检查更新除外；尚未设置更新源）。

## 存储位置
每次录制都会创建“录制 2026-10-26 14.05.10”之类的文件夹，存放录制的影片（recording.mov）和编辑内容（project.json）。编辑不会更改原始影片。录制失败时不会留下文件夹。

## 后台运行与退出
打开“关闭窗口后继续运行”时，关闭窗口后 ScreenTake 仍会运行，录制快捷键也可使用。可从程序坞或访达重新打开，或从菜单栏图标显示窗口。通过“ScreenTake”>“退出 ScreenTake”（⌘Q）退出。录制时退出会先存储影片；导出时会先询问。

## 故障排除
- “未允许录屏”：请在系统设置 > 隐私与安全性 > 录屏与系统录音中打开 ScreenTake，然后重新打开 ScreenTake。
- 列表中没有某个窗口：显示该窗口后刷新列表（↻）。最小化的窗口和其他空间中的窗口不会列出。
- 录制窗口时移动窗口，点按圆环的位置可能会偏移。
- 没有系统声音：不会录制 ScreenTake 自身的声音和静音的声音。
- 快捷键无效：其他应用可能使用了相同的按键。请在设置的“录制”中改用其他按键。
- 删除：退出 ScreenTake，然后将其从“应用程序”文件夹移到废纸篓。录制内容会保留在存储位置。
""",
 "ko": """## 기본 조작
ScreenTake은 화면(또는 윈도우 하나), 시스템 오디오, 마이크, 카메라를 함께 녹화하고 자르기, 확대, 클릭 표시를 더해 MP4, MOV, GIF로 내보냅니다.
- 메인 윈도우에서 녹화 범위(전체 화면 또는 윈도우), 소리, 카메라, 포인터를 선택하고 'N초 후 녹화 시작'을 클릭합니다.
- 녹화 중에는 화면에 아무것도 겹치지 않고, 메뉴 막대에 빨간 점과 경과 시간을 표시합니다(카운트다운 중에는 남은 시간). 클릭하면 녹화 정지, 일시 정지, 재개를 선택할 수 있습니다. ScreenTake의 윈도우는 녹화되지 않습니다.
- 녹화 단축키(기본값 ⌃⌥⇧⌘6)를 누르면 어느 앱에서나 녹화를 시작/정지합니다. 메뉴 막대 아이콘에서도 시작/정지할 수 있습니다.
- 정지하면 편집 윈도우가 열립니다(설정에서 변경 가능). 녹화한 항목은 메인 윈도우 목록에 표시되며 이중 클릭하면 다시 편집합니다.

## 편집
편집 윈도우 위쪽은 내보내기 결과와 같은 미리보기, 오른쪽은 설정, 아래쪽은 타임라인입니다.
- 재생 위치 이동: 눈금을 클릭하거나 드래그합니다. Space로 재생/일시 정지, ← →로 한 프레임씩 이동합니다.
- 범위 삭제: 타임라인의 화면을 드래그해 범위를 선택하고 '선택 범위 삭제'(delete 키)를 누릅니다. 삭제한 곳은 주황색 선으로 표시됩니다.
- 앞뒤 자르기: '처음부터 재생 위치까지 삭제'(⌘[), '재생 위치부터 끝까지 삭제'(⌘]).
- 확대: '확대 추가'(⌥⌘Z)로 선택 범위(없으면 재생 위치부터 3초)를 확대합니다. 타임라인의 확대를 클릭하면 오른쪽에서 배율, 포인터 따라가기, 중심 위치를 바꿀 수 있습니다. 양 끝을 드래그하면 길이, 가운데를 드래그하면 위치가 바뀝니다. 시작과 끝은 부드럽게 확대/축소됩니다.
- 포인터: 포인터는 화면과 따로 녹화됩니다. 켜기/끄기, 크기(0.5–3배), 움직임을 부드럽게를 바꿀 수 있습니다. 타임라인에서 범위를 선택하고 '선택 범위에서 숨기기'를 누르면 그 구간만 포인터를 지웁니다(포인터 레인에 점선으로 표시. '선택 범위에서 표시'로 되돌림).
- 클릭 표시: 녹화 중 클릭한 위치에 원을 표시합니다(오른쪽 클릭은 파란색).
- 카메라: 표시, 위치, 모양(원 또는 둥근 사각형), 크기.
- 음량: 시스템 오디오와 마이크를 따로 조절합니다(0–200%).
- 모든 편집은 ⌘Z로 실행 취소, ⇧⌘Z로 실행 복귀할 수 있으며 자동으로 저장됩니다. '삭제한 부분 모두 복원'으로 삭제를 되돌립니다.

## 내보내기
오른쪽 '내보내기'에서 형식(MP4, MOV, GIF)과 크기를 고르고 '내보내기…'(⌘E)를 눌러 저장 위치를 지정합니다.
- MP4와 MOV: 녹화 그대로, 2160p, 1440p, 1080p, 720p. HEVC(H.265)를 켜면 파일이 작아집니다(오래된 기기에서는 재생되지 않을 수 있음).
- GIF: 너비(480–1280px)와 프레임률(5–20fps). 소리는 들어가지 않습니다. 긴 동영상은 파일이 커집니다.
- 내보내는 중에는 진행 상황이 표시되며 '취소'(Esc)로 중지합니다. 취소하거나 실패하면 중간 파일을 남기지 않으며, 같은 이름의 파일은 성공했을 때만 바꿉니다.

## 설정
'ScreenTake' > '설정…'(⌘,)으로 엽니다.
- 시작 및 백그라운드: 로그인 시 실행, Dock 및 앱 전환기에 표시 안 함, 윈도우를 닫아도 계속 실행, 메뉴 막대 아이콘, 앱 실행 키보드 단축키, 앱 표시 단축키(기본값 설정 안 됨), 권한 상태.
- 녹화: 녹화 단축키, 카운트다운(0–10초, 기본값 3초), 프레임률(30 또는 60fps).
- 출력: 녹화 저장 위치(기본값 '동영상' > 'ScreenTake'), 녹화 후 편집 윈도우 열기.
- 설정 공유: 설정 내보내기, 가져오기, 동기화.
- 정보: 버전과 링크.

## 단축키
- ⌃⌥⇧⌘6: 녹화 시작/정지(어느 앱에서나. 설정의 '녹화'에서 변경하거나 끌 수 있음)
- ⇧⌘R: 녹화 시작/정지(ScreenTake이 앞에 있을 때)
- ⌘O: 녹화 열기
- ⌘E: 내보내기
- Space: 재생/일시 정지, ← →: 한 프레임, delete: 선택 범위 삭제, ⌘[ ⌘]: 앞뒤 삭제, ⌥⌘Z: 확대 추가(편집 윈도우)
- ⌘Z / ⇧⌘Z: 실행 취소 / 실행 복귀
- ⌘0: 메인 윈도우, ⌘,: 설정, ⌘W: 윈도우 닫기, ⌘?: 이 도움말

## 권한
- 화면 및 시스템 오디오 녹음(필수): 처음 녹화할 때 macOS가 묻습니다. 허용한 후 ScreenTake을 다시 여세요.
- 마이크와 카메라: 켜고 녹화할 때만 묻습니다. 거부해도 마이크와 카메라 없이 녹화할 수 있습니다.
- 상태는 '시작 및 백그라운드' 탭의 '권한'에서 확인하며, '설정 열기'로 시스템 설정을 엽니다.
녹화 내용은 이 Mac에만 저장되며 어디로도 전송되지 않습니다(업데이트 확인 제외. 배포처는 아직 설정되지 않음).

## 저장 위치
녹화마다 '녹화 2026-10-26 14.05.10' 같은 폴더를 만들어 녹화한 동영상(recording.mov)과 편집 내용(project.json)을 넣습니다. 편집해도 원본 동영상은 바뀌지 않습니다. 녹화에 실패하면 폴더를 남기지 않습니다.

## 백그라운드 실행과 종료
'윈도우를 닫아도 계속 실행'이 켜져 있으면 윈도우를 닫아도 ScreenTake이 계속 실행되며 녹화 단축키도 작동합니다. Dock이나 Finder에서 다시 열거나 메뉴 막대 아이콘에서 윈도우를 표시합니다. 'ScreenTake' > 'ScreenTake 종료'(⌘Q)로 종료합니다. 녹화 중에 종료하면 동영상을 먼저 저장하고, 내보내는 중에는 먼저 확인합니다.

## 문제 해결
- '화면 기록이 허용되지 않았습니다': 시스템 설정 > 개인정보 보호 및 보안 > 화면 및 시스템 오디오 녹음에서 ScreenTake을 켜고 ScreenTake을 다시 여세요.
- 목록에 윈도우가 없음: 윈도우를 표시한 후 목록을 새로 고칩니다(↻). 최소화한 윈도우와 다른 스페이스의 윈도우는 표시되지 않습니다.
- 녹화 중에 윈도우를 옮기면 클릭 표시 위치가 어긋날 수 있습니다.
- 시스템 오디오가 녹음되지 않음: ScreenTake 자신의 소리와 음소거된 소리는 녹음하지 않습니다.
- 단축키가 작동하지 않음: 다른 앱이 같은 키를 사용하고 있을 수 있습니다. 설정의 '녹화'에서 다른 키로 바꾸세요.
- 삭제: ScreenTake을 종료하고 응용 프로그램 폴더에서 휴지통으로 옮깁니다. 녹화는 저장 위치에 남습니다.
""",
}
