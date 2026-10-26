# -*- coding: utf-8 -*-
from pathlib import Path
import json
root = Path(__file__).parent
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''heading|画面を収録して編集|Record and Edit the Screen|录制并编辑屏幕|화면 녹화 및 편집
subtitle|画面・音声・カメラを収録し、カット・ズーム・クリック表示を付けて書き出します。|Record the screen, sound and camera, then cut, zoom, show clicks and export.|录制屏幕、声音和摄像头，然后剪切、缩放、显示点按并导出。|화면, 소리, 카메라를 녹화하고 자르기, 확대, 클릭 표시를 더해 내보냅니다.
targetLabel|収録する範囲 :|Record:|录制范围：|녹화 범위:
displayChoice|画面全体（%@）|Entire screen (%@)|整个屏幕（%@）|전체 화면(%@)
refresh|一覧を更新|Refresh the list|刷新列表|목록 새로 고침
audioLabel|音声 :|Sound:|声音：|소리:
systemAudio|システム音声|System audio|系统声音|시스템 오디오
microphone|マイク|Microphone|麦克风|마이크
systemDefault|システムの設定|System default|系统默认|시스템 기본값
cameraLabel|カメラ :|Camera:|摄像头：|카메라:
camera|カメラ|Camera|摄像头|카메라
cameraOn|カメラを重ねる|Add the camera|叠加摄像头|카메라 추가
pointerLabel|ポインタ :|Pointer:|指针：|포인터:
showCursor|ポインタを表示|Show the pointer|显示指针|포인터 표시
start|収録を開始|Start Recording|开始录制|녹화 시작
startAfter|%d秒後に収録を開始|Record in %d s|%d 秒后开始录制|%d초 후 녹화 시작
cancelCountdown|キャンセル（%d）|Cancel (%d)|取消（%d）|취소(%d)
stop|停止|Stop|停止|정지
pause|一時停止|Pause|暂停|일시 정지
resume|再開|Resume|继续|재개
hotkeyHint|ほかのアプリからは %@ で開始・停止|Start or stop from any app with %@|在任何应用中按 %@ 开始或停止|어느 앱에서나 %@로 시작/정지
hudCountdown|%d秒後に収録を開始します|Recording in %d s|%d 秒后开始录制|%d초 후 녹화 시작
finishing|処理しています…|Working…|正在处理…|처리 중…
recordingLabel|収録中|Recording|正在录制|녹화 중
pausedLabel|一時停止中|Paused|已暂停|일시 정지됨
recordCanceled|収録をキャンセルしました。|Recording canceled.|已取消录制。|녹화를 취소했습니다.
recorded|「%@」（%@）を収録しました。|Recorded “%@” (%@).|已录制“%@”（%@）。|“%@”(%@)을(를) 녹화했습니다.
stoppedBecause|収録が途中で止まりました（%@）。|The recording stopped by itself (%@).|录制意外停止（%@）。|녹화가 중간에 멈췄습니다(%@).
recordFailed|収録できませんでした（%@）。もう一度お試しください。|Could not record (%@). Try again.|无法录制（%@）。请重试。|녹화하지 못했습니다(%@). 다시 시도하세요.
noTarget|収録する画面またはウインドウが見つかりません。一覧を更新して選び直してください。|The screen or window to record was not found. Refresh the list and choose again.|找不到要录制的屏幕或窗口。请刷新列表后重新选择。|녹화할 화면 또는 윈도우를 찾지 못했습니다. 목록을 새로 고친 후 다시 선택하세요.
needScreenPermission|画面収録が許可されていません。システム設定の「画面収録とシステムオーディオ録音」でScreenTakeをオンにし、ScreenTakeを開き直してください。|Screen Recording is not allowed. Turn on ScreenTake in System Settings › Screen & System Audio Recording, then reopen ScreenTake.|未允许录屏。请在系统设置的“录屏与系统录音”中打开 ScreenTake，然后重新打开 ScreenTake。|화면 기록이 허용되지 않았습니다. 시스템 설정의 '화면 및 시스템 오디오 녹음'에서 ScreenTake을 켠 다음 ScreenTake을 다시 여세요.
needMicPermission|マイクが許可されていません。システム設定の「マイク」でScreenTakeをオンにするか、マイクをオフにして収録してください。|The microphone is not allowed. Turn on ScreenTake in System Settings › Microphone, or record with the microphone off.|未允许使用麦克风。请在系统设置的“麦克风”中打开 ScreenTake，或关闭麦克风后录制。|마이크가 허용되지 않았습니다. 시스템 설정의 '마이크'에서 ScreenTake을 켜거나 마이크를 끄고 녹화하세요.
needCameraPermission|カメラが許可されていません。システム設定の「カメラ」でScreenTakeをオンにするか、カメラをオフにして収録してください。|The camera is not allowed. Turn on ScreenTake in System Settings › Camera, or record with the camera off.|未允许使用摄像头。请在系统设置的“摄像头”中打开 ScreenTake，或关闭摄像头后录制。|카메라가 허용되지 않았습니다. 시스템 설정의 '카메라'에서 ScreenTake을 켜거나 카메라를 끄고 녹화하세요.
openScreenRecording|画面収録の設定を開く|Open Screen Recording Settings|打开录屏设置|화면 기록 설정 열기
recordingsTitle|収録したもの|Recordings|录制内容|녹화한 항목
noRecordings|収録したものがここに並びます。ダブルクリックで編集を開きます。|Your recordings appear here. Double-click one to edit it.|录制内容会显示在这里。连按即可编辑。|녹화한 항목이 여기에 표시됩니다. 이중 클릭하면 편집합니다.
edit|編集|Edit|编辑|편집
revealInFinder|Finderで表示|Show in Finder|在访达中显示|Finder에서 보기
moveToTrash|ゴミ箱に入れる|Move to Trash|移到废纸篓|휴지통으로 이동
trashConfirm|「%@」をゴミ箱に入れますか？|Move “%@” to the Trash?|要将“%@”移到废纸篓吗？|“%@”을(를) 휴지통으로 이동하겠습니까?
trashDetail|収録した動画と編集内容が一緒にゴミ箱に入ります。書き出したファイルは残ります。|The recorded movie and its edits go to the Trash together. Exported files stay.|录制的影片和编辑内容会一起移到废纸篓。已导出的文件会保留。|녹화한 동영상과 편집 내용이 함께 휴지통으로 이동합니다. 내보낸 파일은 남습니다.
trashed|「%@」をゴミ箱に入れました。|Moved “%@” to the Trash.|已将“%@”移到废纸篓。|“%@”을(를) 휴지통으로 이동했습니다.
trashFailed|ゴミ箱に入れられませんでした（%@）。|Could not move to the Trash (%@).|无法移到废纸篓（%@）。|휴지통으로 이동하지 못했습니다(%@).
notRecording|選んだフォルダはScreenTakeの収録ではありません（project.json がありません）。|The chosen folder is not a ScreenTake recording (no project.json).|所选文件夹不是 ScreenTake 录制内容（没有 project.json）。|선택한 폴더는 ScreenTake 녹화가 아닙니다(project.json 없음).
openFailed|開けませんでした（%@）。|Could not open (%@).|无法打开（%@）。|열지 못했습니다(%@).
saveFailed|編集内容を保存できませんでした（%@）。|Could not save the edits (%@).|无法存储编辑内容（%@）。|편집 내용을 저장하지 못했습니다(%@).
busyExporting|書き出しが終わってから、ほかの収録を開いてください。|Open another recording after the export finishes.|请在导出完成后再打开其他录制内容。|내보내기가 끝난 후 다른 녹화를 여세요.
filePrefix|収録|Recording|录制|녹화
choose|選択|Choose|选择|선택
preview|プレビュー|Preview|预览|미리보기
play|再生|Play|播放|재생
cutRange|選択範囲を削除|Delete Selection|删除所选范围|선택 범위 삭제
cutHelp|タイムラインの映像をドラッグして範囲を選び、削除します。|Drag across the picture on the timeline to select a range, then delete it.|在时间线的画面上拖移以选择范围，然后删除。|타임라인의 화면을 드래그해 범위를 선택한 후 삭제합니다.
trimStart|先頭から再生位置までを削除|Trim to Playhead from Start|删除开头到播放位置|처음부터 재생 위치까지 삭제
trimStartHelp|再生位置より前を削除します。|Removes everything before the playhead.|删除播放位置之前的内容。|재생 위치 앞부분을 삭제합니다.
trimEnd|再生位置から末尾までを削除|Trim from Playhead to End|删除播放位置到结尾|재생 위치부터 끝까지 삭제
trimEndHelp|再生位置より後を削除します。|Removes everything after the playhead.|删除播放位置之后的内容。|재생 위치 뒷부분을 삭제합니다.
addZoom|ズームを追加|Add Zoom|添加缩放|확대 추가
addZoomHelp|選択範囲（なければ再生位置から3秒）を拡大します。|Zooms in on the selection, or 3 seconds from the playhead.|放大所选范围（没有时为播放位置起 3 秒）。|선택 범위(없으면 재생 위치부터 3초)를 확대합니다.
timelineScale|タイムラインの拡大率|Timeline scale|时间线缩放|타임라인 배율
exportButton|書き出す…|Export…|导出…|내보내기…
exportMenu|書き出す…|Export…|导出…|내보내기…
deleteSelection|選択範囲を削除|Delete Selection|删除所选范围|선택 범위 삭제
playMenu|再生|Playback|播放|재생
playPause|再生／一時停止|Play/Pause|播放/暂停|재생/일시 정지
stepBack|1フレーム戻る|Back One Frame|后退一帧|한 프레임 뒤로
stepForward|1フレーム進む|Forward One Frame|前进一帧|한 프레임 앞으로
videoLane|映像。クリックで再生位置を移動、ドラッグで範囲を選択|Picture. Click to move the playhead, drag to select a range|画面。点按移动播放位置，拖移选择范围|화면. 클릭하면 재생 위치 이동, 드래그하면 범위 선택
ruler|時間の目盛り。クリックまたはドラッグで再生位置を移動|Time ruler. Click or drag to move the playhead|时间标尺。点按或拖移以移动播放位置|시간 눈금. 클릭하거나 드래그해 재생 위치 이동
zoomBlock|ズーム %.1f倍、%@〜%@|Zoom %.1f×, %@–%@|缩放 %.1f 倍，%@–%@|확대 %.1f배, %@–%@
zoomSection|ズーム|Zoom|缩放|확대
zoomHint|［ズームを追加］で作ったズームをタイムラインでクリックすると、ここで倍率や中心を変えられます。端をドラッグすると長さ、中をドラッグすると位置が変わります。|Click a zoom on the timeline (made with Add Zoom) to change its scale and center here. Drag its ends to change the length, its middle to move it.|在时间线上点按缩放（用“添加缩放”创建）即可在此更改倍率和中心。拖移两端改变长度，拖移中间移动位置。|타임라인에서 확대(확대 추가로 만든 것)를 클릭하면 여기서 배율과 중심을 바꿀 수 있습니다. 양 끝을 드래그하면 길이, 가운데를 드래그하면 위치가 바뀝니다.
zoomScale|倍率|Scale|倍率|배율
followCursor|ポインタを追う|Follow the pointer|跟随指针|포인터 따라가기
zoomCenterX|横の位置|Across|水平位置|가로 위치
zoomCenterY|縦の位置|Down|垂直位置|세로 위치
deleteZoom|ズームを削除|Delete Zoom|删除缩放|확대 삭제
cursorSection|ポインタ|Pointer|指针|포인터
showCursorLayer|ポインタを表示|Show the pointer|显示指针|포인터 표시
cursorScale|大きさ|Size|大小|크기
smoothCursor|動きを滑らかにする|Smooth the movement|平滑移动|움직임을 부드럽게
hideCursorRange|選択範囲で隠す|Hide in Selection|在所选范围内隐藏|선택 범위에서 숨기기
showCursorRange|選択範囲で表示|Show in Selection|在所选范围内显示|선택 범위에서 표시
cursorRangeHint|タイムラインの映像をドラッグして範囲を選びます。隠した区間はポインタのレーンに点線で表示します。|Drag across the picture on the timeline to select a range. Hidden parts show as dashed boxes in the pointer lane.|在时间线的画面上拖移以选择范围。隐藏的部分在指针轨道中以虚线显示。|타임라인의 화면을 드래그해 범위를 선택합니다. 숨긴 구간은 포인터 레인에 점선으로 표시됩니다.
cursorBakedIn|この収録はポインタが映像に含まれているため、大きさや表示を変えられません。|In this recording the pointer is part of the picture, so it cannot be resized or hidden.|此录制内容的指针已包含在画面中，无法更改大小或隐藏。|이 녹화는 포인터가 화면에 포함되어 있어 크기를 바꾸거나 숨길 수 없습니다.
cursorLane|ポインタ。点線の区間は非表示|Pointer. Dashed parts are hidden|指针。虚线部分为隐藏|포인터. 점선 구간은 숨김
actionHideCursor|ポインタを隠す|Hide Pointer|隐藏指针|포인터 숨기기
actionShowCursor|ポインタを表示|Show Pointer|显示指针|포인터 표시
clicksSection|クリック|Clicks|点按|클릭
highlightClicks|クリックした位置を表示|Show where you clicked|显示点按位置|클릭한 위치 표시
clickCount|収録中のクリック：%d回|Clicks recorded: %d|录制时的点按：%d 次|녹화 중 클릭: %d회
cameraSection|カメラ|Camera|摄像头|카메라
showCamera|カメラを表示|Show the camera|显示摄像头|카메라 표시
cameraCorner|位置|Position|位置|위치
corner.topLeft|左上|Top left|左上|왼쪽 위
corner.topRight|右上|Top right|右上|오른쪽 위
corner.bottomLeft|左下|Bottom left|左下|왼쪽 아래
corner.bottomRight|右下|Bottom right|右下|오른쪽 아래
cameraShape|形|Shape|形状|모양
shape.circle|円|Circle|圆形|원
shape.rounded|角丸の四角|Rounded square|圆角方形|둥근 사각형
cameraSize|大きさ|Size|大小|크기
audioSection|音量|Volume|音量|음량
systemVolume|システム音声の音量|System audio volume|系统声音音量|시스템 오디오 음량
micVolume|マイクの音量|Microphone volume|麦克风音量|마이크 음량
exportSection|書き出し|Export|导出|내보내기
exportFormat|形式|Format|格式|형식
exportSize|大きさ|Size|大小|크기
sizeOriginal|収録のまま（%dp）|As recorded (%dp)|与录制相同（%dp）|녹화 그대로(%dp)
hevc|HEVC（H.265）で圧縮|Compress with HEVC (H.265)|使用 HEVC (H.265) 压缩|HEVC(H.265)로 압축
gifWidth|横幅|Width|宽度|너비
gifFPS|コマ数|Frame rate|帧率|프레임률
restoreCuts|削除した部分をすべて戻す|Restore All Deleted Parts|恢复所有删除的部分|삭제한 부분 모두 복원
exporting|「%@」を書き出しています…|Exporting “%@”…|正在导出“%@”…|“%@” 내보내는 중…
exported|「%@」を書き出しました。|Exported “%@”.|已导出“%@”。|“%@”을(를) 내보냈습니다.
exportCanceled|書き出しをキャンセルしました。途中のファイルは残していません。|Export canceled. No partial file was left.|已取消导出。未保留不完整的文件。|내보내기를 취소했습니다. 중간 파일은 남기지 않았습니다.
exportFailed|書き出せませんでした（%@）。|Could not export (%@).|无法导出（%@）。|내보내지 못했습니다(%@).
cancel|キャンセル|Cancel|取消|취소
actionCut|範囲の削除|Delete Range|删除范围|범위 삭제
actionTrimStart|先頭の削除|Trim Start|删除开头|처음 삭제
actionTrimEnd|末尾の削除|Trim End|删除结尾|끝 삭제
actionRestoreCuts|削除の取り消し|Restore Deleted Parts|恢复删除部分|삭제 복원
actionAddZoom|ズームの追加|Add Zoom|添加缩放|확대 추가
actionDeleteZoom|ズームの削除|Delete Zoom|删除缩放|확대 삭제
actionMoveZoom|ズームの移動|Move Zoom|移动缩放|확대 이동
actionZoomScale|倍率の変更|Change Scale|更改倍率|배율 변경
actionFollow|ポインタ追従の変更|Change Follow Pointer|更改跟随指针|포인터 따라가기 변경
actionZoomCenter|中心の変更|Change Center|更改中心|중심 변경
closeWhileExporting|書き出し中です。書き出しを中止してウインドウを閉じますか？|Exporting. Stop the export and close the window?|正在导出。要停止导出并关闭窗口吗？|내보내는 중입니다. 내보내기를 중지하고 윈도우를 닫겠습니까?
stopExport|書き出しを中止|Stop Export|停止导出|내보내기 중지
quitWhileExporting|書き出し中です。終了しますか？|Exporting. Quit anyway?|正在导出。仍要退出吗？|내보내는 중입니다. 종료하겠습니까?
quitWhileExportingDetail|書き出しを中止します。途中のファイルは残りません。収録した動画と編集内容はそのまま残ります。|The export stops and no partial file is left. The recording and its edits stay.|导出将停止，不会保留不完整的文件。录制内容和编辑内容会保留。|내보내기가 중지되며 중간 파일은 남지 않습니다. 녹화와 편집 내용은 그대로 남습니다.
quitAnyway|終了|Quit|退出|종료
startRecording|収録を開始|Start Recording|开始录制|녹화 시작
stopRecording|収録を停止|Stop Recording|停止录制|녹화 정지
cancelRecording|カウントダウンをキャンセル|Cancel Countdown|取消倒计时|카운트다운 취소
openRecording|収録を開く…|Open Recording…|打开录制内容…|녹화 열기…
permissions|権限|Permissions|权限|권한
screenRecording|画面収録|Screen Recording|录屏|화면 기록
permitted|許可済み|Allowed|已允许|허용됨
notPermitted|未許可|Not allowed|未允许|허용되지 않음
openSettings|設定を開く|Open Settings|打开设置|설정 열기
permissionsReason|画面収録は必須です（システム音声もこの許可で録ります）。マイクとカメラは、オンにして収録するときだけ許可を求めます。許可したあとはScreenTakeを開き直してください。収録した内容はこのMacにだけ保存し、送信しません。|Screen Recording is required (system audio is recorded with it too). The microphone and camera are asked for only when you record with them on. Reopen ScreenTake after allowing. Recordings stay on this Mac and are never sent.|录屏为必需（系统声音也通过此权限录制）。麦克风和摄像头仅在打开后录制时才请求。允许后请重新打开 ScreenTake。录制内容仅保存在此 Mac 上，不会发送。|화면 기록은 필수입니다(시스템 오디오도 이 권한으로 녹음). 마이크와 카메라는 켜고 녹화할 때만 권한을 요청합니다. 허용한 후 ScreenTake을 다시 여세요. 녹화 내용은 이 Mac에만 저장되며 전송되지 않습니다.
recordTab|収録|Recording|录制|녹화
recordHotkey|収録の開始・停止のホットキー|Start/stop recording hotkey|开始/停止录制快捷键|녹화 시작/정지 단축키
recordHotkeyDetail|どのアプリからでも、押すと収録を開始し、もう一度押すと停止します。カウントダウン中に押すとキャンセルします。|Press it in any app to start recording; press again to stop. During the countdown it cancels.|在任何应用中按下即可开始录制，再按一次停止。倒计时期间按下则取消。|어느 앱에서나 누르면 녹화를 시작하고, 다시 누르면 정지합니다. 카운트다운 중에 누르면 취소합니다.
countdownTitle|収録までの秒数|Countdown|倒计时|카운트다운
seconds|%d秒|%d s|%d 秒|%d초
countdownDetail|［収録を開始］を押してから収録が始まるまでの秒数です。0秒にするとすぐに始めます。|Seconds between Start Recording and the start. 0 starts at once.|从按下“开始录制”到开始录制的秒数。设为 0 会立即开始。|녹화 시작을 누른 후 녹화가 시작되기까지의 시간입니다. 0이면 바로 시작합니다.
qualityTitle|フレームレート|Frame Rate|帧率|프레임률
frameRate|フレームレート|Frame rate|帧率|프레임률
frameRateDetail|60 fpsは動きが滑らかですが、ファイルが大きくなります。画面が変わらない間はコマを記録しません。|60 fps is smoother but makes larger files. No frames are recorded while the screen does not change.|60 fps 更流畅，但文件更大。屏幕没有变化时不记录帧。|60fps는 더 부드럽지만 파일이 커집니다. 화면이 바뀌지 않는 동안은 프레임을 기록하지 않습니다.
outputTab|出力|Output|输出|출력
folderTitle|収録の保存先|Recordings Folder|录制内容存储位置|녹화 저장 위치
chooseFolder|フォルダを選択…|Choose Folder…|选择文件夹…|폴더 선택…
showFolder|フォルダを開く|Open Folder|打开文件夹|폴더 열기
resetFolder|初期値に戻す|Reset to Default|恢复默认|기본값으로 재설정
folderDetail|初期値は「ムービー」フォルダの中の「ScreenTake」です。収録ごとにフォルダを作り、収録した動画（recording.mov）と編集内容（project.json）を入れます。編集しても元の動画は書き換えません。|By default, ScreenTake in your Movies folder. Each recording gets a folder with the movie (recording.mov) and the edits (project.json). Editing never changes the recorded movie.|默认是“影片”文件夹中的“ScreenTake”。每次录制都会创建一个文件夹，存放录制的影片（recording.mov）和编辑内容（project.json）。编辑不会更改原始影片。|기본값은 '동영상' 폴더 안의 'ScreenTake'입니다. 녹화마다 폴더를 만들어 녹화한 동영상(recording.mov)과 편집 내용(project.json)을 넣습니다. 편집해도 원본 동영상은 바뀌지 않습니다.
afterRecording|収録したあと|After Recording|录制后|녹화 후
openEditorAfter|編集ウインドウを開く|Open the editor|打开编辑窗口|편집 윈도우 열기
resident|ウインドウを閉じても常駐|Keep running after closing the window|关闭窗口后继续运行|윈도우를 닫아도 계속 실행
residentDetail|閉じた後もDockやメニューバーから再表示でき、収録のホットキーも使えます。オフにすると閉じたときに終了します。|Reopen from the Dock or menu bar; the record hotkey keeps working. When off, closing the window quits.|可从 Dock 或菜单栏再次打开，录制快捷键仍可使用。关闭此项时，关闭窗口即退出。|Dock이나 메뉴 막대에서 다시 열 수 있고 녹화 단축키도 작동합니다. 끄면 윈도우를 닫을 때 종료합니다.
launchShortcut|アプリ起動のホットキー|App launch keyboard shortcut|启动应用快捷键|앱 실행 키보드 단축키
openShortcuts|ショートカットを開く|Open Shortcuts|打开快捷指令|단축어 열기
shortcutDetail|ショートカットAppで「アプリを開く」にScreenTakeを指定し、キーを割り当ててください。未起動時も使えます。|In Shortcuts, create an Open App action for ScreenTake and assign a key. It works even when the app is not running.|在快捷指令中为 ScreenTake 创建“打开 App”并分配按键。应用未运行时也可使用。|단축어에서 ScreenTake용 '앱 열기'를 만들고 키를 지정하세요. 앱이 실행 중이 아니어도 작동합니다.
appHotkeyHint|ScreenTakeの起動中に押すと、どのアプリからでもメインウインドウを表示します。初期値は未設定です。|While ScreenTake is running, press it in any app to show the main window. Not set by default.|ScreenTake 运行时，在任何应用中按下即可显示主窗口。默认未设置。|ScreenTake이 실행 중일 때 어느 앱에서나 누르면 메인 윈도우를 표시합니다. 기본값은 설정 안 됨입니다.
openMainWindow|メインウインドウを開く|Open Main Window|打开主窗口|메인 윈도우 열기
settings|設定…|Settings…|设置…|설정…
settingsWindow|設定|Settings|设置|설정
help|ScreenTakeヘルプ|ScreenTake Help|ScreenTake 帮助|ScreenTake 도움말
helpMenu|ヘルプ|Help|帮助|도움말
quit|ScreenTakeを終了|Quit ScreenTake|退出 ScreenTake|ScreenTake 종료
hide|ScreenTakeを隠す|Hide ScreenTake|隐藏 ScreenTake|ScreenTake 가리기
services|サービス|Services|服务|서비스
hideOthers|ほかを隠す|Hide Others|隐藏其他|기타 가리기
showAll|すべてを表示|Show All|全部显示|모두 보기
about|ScreenTakeについて|About ScreenTake|关于 ScreenTake|ScreenTake에 관하여
aboutDetail|画面・音声・カメラを収録し、カット・ズーム・クリック表示を付けて書き出します。サポート：同梱のREADME.md|Records the screen, sound and camera, then cuts, zooms, shows clicks and exports. Support: bundled README.md|录制屏幕、声音和摄像头，然后剪切、缩放、显示点按并导出。支持：内置 README.md|화면, 소리, 카메라를 녹화하고 자르기, 확대, 클릭 표시를 더해 내보냅니다. 지원: 포함된 README.md
fileMenu|ファイル|File|文件|파일
editMenu|編集|Edit|编辑|편집
windowMenu|ウインドウ|Window|窗口|윈도우
minimize|しまう|Minimize|最小化|최소화
zoom|拡大／縮小|Zoom|缩放|확대/축소
bringAllToFront|すべてを手前に移動|Bring All to Front|前置全部窗口|모두 앞으로 가져오기
close|ウインドウを閉じる|Close Window|关闭窗口|윈도우 닫기
undo|取り消す|Undo|撤销|실행 취소
redo|やり直す|Redo|重做|실행 복귀
cut|カット|Cut|剪切|오려두기
copy|コピー|Copy|拷贝|복사하기
paste|ペースト|Paste|粘贴|붙여넣기
selectAll|すべてを選択|Select All|全选|모두 선택'''
table = [line.split('|') for line in rows.splitlines()]
assert all(len(r) == 5 for r in table), [r[0] for r in table if len(r) != 5]
assert len({r[0] for r in table}) == len(table), 'duplicate key'

# Help text lives in help_text.py (markup rendered by Shared/AppStandards/HelpDocument.swift).
from help_text import HELP
helptexts = [HELP[l] for l in ['ja', 'en', 'zh-Hans', 'ko']]

for i, lang in enumerate(['ja', 'en', 'zh-Hans', 'ko']):
    p = root / 'Resources' / f'{lang}.lproj'
    p.mkdir(parents=True, exist_ok=True)
    (p / 'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0])} = {json.dumps(r[i + 1], ensure_ascii=False)};' for r in table) + '\n')
    (p / 'InfoPlist.strings').write_text('"CFBundleDisplayName" = "ScreenTake";\n')
    (p / 'Help.txt').write_text(helptexts[i])
print('resources:', len(table), 'keys x 4 languages')
