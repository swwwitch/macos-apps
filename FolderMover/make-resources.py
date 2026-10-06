from pathlib import Path
import json, plistlib
root=Path(__file__).resolve().parent
rows=[
('displayGroup','表示','Display','显示','표시'),
('shortenDropbox','Dropboxのパスを簡易表示','Shorten Dropbox paths','简化 Dropbox 路径','Dropbox 경로 간략 표시'),
('shortenDropboxDetail','Dropbox-sharedより前を省略します。ポインタを重ねると完全なパスを確認できます。','Hide the prefix before Dropbox-shared. Hover to see the full path.','省略 Dropbox-shared 之前的路径。悬停可查看完整路径。','Dropbox-shared 앞의 경로를 생략합니다. 포인터를 올리면 전체 경로를 확인할 수 있습니다.'),
('headline','大量のファイルをまとめて移動','Move files in bulk','批量移动文件','파일 일괄 이동'),
('subtitle','移動元と移動先を選んで、安全にまとめて移動。','Choose two folders and move their contents safely.','选择源文件夹和目标文件夹，安全移动。','원본 및 대상 폴더를 선택해 안전하게 이동하세요.'),
('source','ソース','Source','源文件夹','원본'),('destination','コピー先','Destination','目标文件夹','대상'),
('chooseFolder','フォルダを選択…','Choose a folder…','选择文件夹…','폴더 선택…'),('dropFolder','クリックして選択、またはフォルダをドロップ','Click to choose, or drop a folder','点击选择或拖放文件夹','클릭하여 선택하거나 폴더를 드롭하세요'),
('missing','フォルダが見つかりません','Folder not found','找不到文件夹','폴더를 찾을 수 없습니다'),
('ready','フォルダを選ぶと移動できます。同名の項目は上書きしません。','Choose folders to begin. Existing items are never overwritten.','选择文件夹后即可开始。同名项目不会被覆盖。','폴더를 선택하세요. 같은 이름의 항목은 덮어쓰지 않습니다.'),
('includeFolders','フォルダも含める','Include folders','包含文件夹','폴더 포함'),('includeHidden','隠しファイルも含める','Include hidden items','包含隐藏项目','숨김 항목 포함'),('swap','移動元と移動先を入れ替える','Swap folders','交换文件夹','폴더 교환'),
('move','移動する','Move','移动','이동'),('cancel','キャンセル','Cancel','取消','취소'),('stop','停止','Stop','停止','중지'),('stoppingShort','停止待ち…','Stopping…','正在停止…','중지 중…'),
('scanning','移動する項目を確認しています…','Scanning items…','正在检查项目…','항목 확인 중…'),('moving','移動しています…','Moving…','正在移动…','이동 중…'),('stopping','実行中の移動が終わり次第、停止します。','Stopping after the current batch finishes.','当前批次完成后停止。','현재 배치가 끝나면 중지합니다.'),
('cancelled','停止しました。移動済みの項目は移動先に残ります。','Stopped. Completed items remain in the destination.','已停止。已移动的项目保留在目标文件夹。','중지했습니다. 이동한 항목은 대상에 남습니다.'),
('empty','移動する項目がありません。','No items to move.','没有可移动的项目。','이동할 항목이 없습니다.'),
('completed','移動が完了しました。','Move completed.','移动完成。','이동이 완료되었습니다.'),('completedSkipped','移動が完了しました。同名の項目はスキップしました。','Completed with existing items skipped.','移动完成。同名项目已跳过。','완료했습니다. 같은 이름의 항목은 건너뛰었습니다.'),
('partial','移動できなかった項目があります。履歴とフォルダを確認してください。','Some items could not be moved. Check the history and both folders.','部分项目未能移动。请检查记录和两个文件夹。','이동하지 못한 항목이 있습니다. 기록과 두 폴더를 확인하세요.'),
('confirmTitle','%ld件の項目を移動しますか？','Move %ld items?','移动 %ld 个项目？','항목 %ld개를 이동할까요?'),
('confirmDetail','移動した項目は移動元からなくなります。同名項目はスキップします。フォルダは中身ごと移動し、統合しません。自動取り消しはありません。','Moved items are removed from the source. Existing names are skipped. Folders move as a whole and are not merged. Automatic undo is unavailable.','已移动的项目将从源文件夹移除。同名项目会跳过。文件夹整体移动，不合并。不支持自动撤销。','이동한 항목은 원본에서 사라집니다. 같은 이름은 건너뜁니다. 폴더 전체를 이동하며 병합하지 않습니다. 자동 실행 취소는 지원하지 않습니다.'),
('counts','移動 %ld件  ·  スキップ %ld件  ·  失敗 %ld件  ·  未処理 %ld件','Moved %ld  ·  Skipped %ld  ·  Failed %ld  ·  Remaining %ld','已移动 %ld  ·  已跳过 %ld  ·  失败 %ld  ·  未处理 %ld','이동 %ld  ·  건너뜀 %ld  ·  실패 %ld  ·  남음 %ld'),
('showHistory','結果の履歴を表示','Show result history','显示结果记录','결과 기록 보기'),('historyFolder','履歴フォルダを開く','Open history folder','打开记录文件夹','기록 폴더 열기'),
('invalidFolder','通常のフォルダを選択してください。見つからない場合は選び直してください。','Choose an available ordinary folder, not an app or package.','请选择可用的普通文件夹，而非应用或软件包。','사용 가능한 일반 폴더를 선택하세요. 앱이나 패키지는 선택할 수 없습니다.'),
('nestedFolder','同じフォルダや移動元の内部には移動できません。ルートも指定できません。','The destination cannot be the source or inside it. The filesystem root cannot be a source.','目标不能是源文件夹或其内部。不能将文件系统根目录设为源。','대상은 원본과 같거나 그 안에 있을 수 없습니다. 루트는 원본으로 사용할 수 없습니다.'),
('permissionError','フォルダの読み書き権限を確認し、選び直してください。','Check folder read/write permissions and choose again.','请检查文件夹读写权限并重新选择。','폴더 읽기/쓰기 권한을 확인하고 다시 선택하세요.'),
('changedSource','確認中に項目が変更されました。選び直してください。','An item changed during scanning. Please scan again.','检查期间项目已更改。请重新检查。','확인 중 항목이 변경되었습니다. 다시 확인하세요.'),
('changedFolder','フォルダが変更・切断されました。接続と履歴を確認してください。','A folder changed or disconnected. Check the connection and history.','文件夹已更改或断开连接。请检查连接和记录。','폴더가 변경되거나 연결이 끊어졌습니다. 연결과 기록을 확인하세요.'),
('journalError','履歴を保存できないため、移動を開始しませんでした。','Move did not start because history could not be saved.','无法保存记录，因此未开始移动。','기록을 저장할 수 없어 이동하지 않았습니다.'),
('launchGroup','起動・常駐','Launch & presence','启动与驻留','실행 및 상주'),('resident','常駐','Keep running','保持运行','계속 실행'),('residentDetail','ウインドウを閉じても動作を続けます。Dockから再表示できます。','Keep running after closing the window. Reopen from the Dock.','关闭窗口后继续运行。可从 Dock 重新打开。','창을 닫아도 실행합니다. Dock에서 다시 열 수 있습니다.'),
('launchShortcut','アプリ起動のキーボードショートカット','App launch keyboard shortcut','应用启动键盘快捷键','앱 실행 키보드 단축키'),('systemSettings','システムで設定…','Configure in Shortcuts…','在快捷指令中设置…','단축어에서 설정…'),
('shortcutDetail','「ショートカット」で「アプリを開く → FolderMover」を作成し、キーボードショートカットを割り当てます。未起動時も使えます。','In Shortcuts, create “Open App → FolderMover” and assign a keyboard shortcut. This also launches the app when it is not running.','在快捷指令中创建“打开 App → FolderMover”并分配键盘快捷键。未运行时也可启动。','단축어에서 “앱 열기 → FolderMover”을 만들고 키보드 단축키를 지정하세요. 앱이 꺼져 있어도 실행할 수 있습니다.'),
('privacy','プライバシー・履歴','Privacy & history','隐私与记录','개인정보 및 기록'),('privacyDetail','外部通信なし。履歴には移動したファイルのパスを保存します。不要な履歴はFinderで削除できます。','No network access. History stores file paths locally. Delete unneeded history in Finder.','无网络通信。记录在本地保存文件路径。可在访达删除不需要的记录。','네트워크 통신을 하지 않습니다. 기록에 파일 경로를 로컬로 저장합니다. Finder에서 불필요한 기록을 삭제할 수 있습니다.'),
('about','FolderMoverについて','About FolderMover','关于 FolderMover','FolderMover 정보'),('updates','アップデートを確認…','Check for Updates…','检查更新…','업데이트 확인…'),('settings','環境設定…','Settings…','设置…','설정…'),('quit','FolderMoverを終了','Quit FolderMover','退出 FolderMover','FolderMover 종료'),('file','ファイル','File','文件','파일'),('showWindow','ウインドウを表示','Show Window','显示窗口','윈도우 보기'),('close','閉じる','Close','关闭','닫기'),('edit','編集','Edit','编辑','편집'),('undo','取り消す','Undo','撤销','실행 취소'),('cut','カット','Cut','剪切','잘라내기'),('copy','コピー','Copy','复制','복사'),('paste','ペースト','Paste','粘贴','붙여넣기'),('selectAll','すべてを選択','Select All','全选','모두 선택'),('help','ヘルプ','Help','帮助','도움말'),
('busyQuit','移動処理中は終了できません。','A move is still in progress.','正在移动，无法退出。','이동 중에는 종료할 수 없습니다.'),('busyQuitDetail','「停止」で現在の処理を安全に終えてから、もう一度終了してください。','Choose Stop to finish the current batch safely, then quit again.','点击停止以安全完成当前批次，然后再次退出。','중지를 눌러 현재 배치를 안전하게 끝낸 뒤 다시 종료하세요.'),('continue','続ける','Continue','继续','계속'),('updatesPending','更新配布の準備中','Updates are not configured','更新尚未配置','업데이트가 설정되지 않았습니다'),('updatesDetail','更新先と検証用公開鍵は未設定です。自動更新は利用できません。','An update feed and verification key have not been configured. Automatic updates are unavailable.','尚未配置更新源和验证公钥，无法自动更新。','업데이트 주소와 검증 키가 설정되지 않아 자동 업데이트를 사용할 수 없습니다.'),('support','サポート：このアプリを作成したCodexチャット','Support: the Codex chat that created this app','支持：创建此应用的 Codex 对话','지원: 이 앱을 만든 Codex 채팅'),
('login','ログイン時に起動','Launch at login','登录时启动','로그인 시 실행'),('loginOpen','ログイン項目を開く','Open Login Items','打开登录项','로그인 항목 열기'),('loginOn','Macへのログイン時に自動起動します。','Launches automatically when you log in.','登录时自动启动。','로그인 시 자동 실행합니다.'),('loginApproval','システム設定のログイン項目で許可してください。','Allow the app in System Settings → Login Items.','请在系统设置的登录项中允许此应用。','시스템 설정의 로그인 항목에서 허용하세요.'),('loginMissing','ログイン起動は未登録です。ONにすると登録します。','Login launch is not registered. Turn it on to register.','登录启动尚未注册。开启后即可注册。','로그인 실행이 등록되지 않았습니다. 켜면 등록됩니다.'),('loginOff','自動起動はOFFです。','Launch at login is off.','登录时启动已关闭。','로그인 시 실행이 꺼져 있습니다.'),('loginError','設定を変更できませんでした：','Could not change the setting: ','无法更改设置：','설정을 변경할 수 없습니다: '),
]
path_help = [
'表示設定\n環境設定の「表示」→「Dropboxのパスを簡易表示」をONにすると、左右のカードは /Dropbox-shared/… と表示します。初期値はONです。ポインタを重ねると完全なパスを確認できます。移動の確認画面と履歴は完全なパスを保持します。',
'Display settings\nSettings → Display → Shorten Dropbox paths shows /Dropbox-shared/… on both cards. Enabled by default. Hover for the full path. Confirmation and history retain full paths.',
'显示设置\n设置→显示→简化 Dropbox 路径会将两张卡片的路径显示为 /Dropbox-shared/…。默认开启。悬停可查看完整路径，确认对话框与记录保留完整路径。',
'표시 설정\n설정→표시→Dropbox 경로 간략 표시를 켜면 두 카드에 /Dropbox-shared/…로 표시합니다. 기본값은 켜짐입니다. 포인터를 올리면 전체 경로가 표시됩니다. 확인 화면과 기록에는 전체 경로를 유지합니다.'
]
helptexts=[
'''FolderMover — フォルダからフォルダへまとめて移動

基本操作
左右のカードをクリックするかフォルダをドロップします。「移動する」で件数と移動先を確認して実行します。移動元フォルダ自体ではなく直下の項目が対象です。フォルダを含めると、その中身も丸ごと移動します。同名フォルダの統合・上書きはしません。

大量ファイルと停止
/bin/mv -n を最大128項目・引数約64KB単位で実行します。進捗は直下の項目数です。フォルダ内のファイル数・転送バイト数ではありません。Escまたは停止で次のバッチに進まず、実行中のmvの終了を待ちます。大きなファイルや別ディスクへの移動では停止待ちが長くなることがあります。処理中の強制終了やドライブの取り外しは避けてください。

設定・ショートカット
⌘,で環境設定。ログイン起動は初期OFFです。常駐ONでは⌘Wや閉じるボタンでウインドウだけ閉じ、Dockまたは⌘0で再表示します。常駐OFFでは処理がなければ閉じると終了します。⌘Qで終了します。移動中は停止後に再度終了してください。ログイン起動ではウインドウを表示しません。
起動ショートカットはmacOSの「ショートカット」で「アプリを開く」アクションの対象をFolderMoverにし、詳細でキーボードショートカットを登録します。変更・解除は同じ場所で行います。アプリ独自のグローバルキー監視はありません。

権限と困ったとき
アクセシビリティ権限は不要です。選んだフォルダの読み書き権限が必要です。アクセス拒否時はFinderの「情報を見る」で権限、システム設定→プライバシーとセキュリティ→ファイルとフォルダで許可、外付けドライブの接続を確認し、選び直してください。不要なフルディスクアクセスは要求しません。
確認後に移動元の項目が置き換わっていた場合は失敗として残します。使用中のファイルや他の同期アプリによって変更されるフォルダは、変更処理が落ち着いてから移動してください。

結果・復元・途中失敗
完了、スキップ、失敗、未処理を表示します。「結果の履歴を表示」でJSONL履歴を確認できます。movedは移動確認済み、skippedは同名等で残した項目、failed/changedは失敗、attemptは実行予定です。異常終了時にattemptだけ残っていたら両フォルダをFinderで照合してください。別ディスクで失敗した場合、コピー途中の項目が移動先に残ることがあります。元ファイルを保持し、両方を確認してから対応してください。
自動Undoはありません。戻す場合は履歴のmovedにある項目だけをFinderで元のフォルダへ戻します。同名があれば上書きせず別名で保管します。フォルダ全体を逆向きに移動すると既存の別ファイルも巻き込むため避けてください。

プライバシー・更新
外部通信はありません。履歴は ~/Library/Application Support/FolderMover/History にパスを保存し、内容本文は保存しません。履歴は自動削除せずFinderから削除できます。設定はUserDefaultsに保存します。現在のビルドはローカル利用向けで、更新先・更新署名鍵・公証は未設定です。
サポート：このアプリを作成したCodexチャット。''',
'''FolderMover — Move folder contents in bulk

Operation
Click or drop a folder on each card. Choose Move and confirm the count and destination. Only immediate children of the source are selected. Included folders move with all their contents. Existing names are skipped; folders are never merged or overwritten.

Large moves and stopping
/bin/mv -n runs in batches of up to 128 items and about 64 KB of arguments. Progress counts top-level items, not bytes or nested files. Stop or Esc waits for the active batch to finish. A large file or cross-volume copy may take time to stop. Do not force quit or disconnect drives during a move.

Settings and shortcuts
⌘, opens settings; login launch defaults to off. Keep running lets ⌘W close the window while the app remains available in the Dock. ⌘0 reopens it, ⌘Q quits. During a move, stop first and quit again afterward. With Keep running off, closing the main window quits when idle. Login launch stays in the background.
For a launch shortcut, create an Open App action for FolderMover in macOS Shortcuts and assign a keyboard shortcut in its details. Edit or remove it there. The app does not monitor global keys.

Permissions and troubleshooting
Accessibility access is not needed. Selected folders need read/write access. If denied, inspect Finder Get Info permissions, System Settings → Privacy & Security → Files and Folders, and drive connections, then select again. Full Disk Access is not requested. Items replaced since scanning are reported as failed. Wait for other apps or sync operations to stop changing these folders before moving them.

Results and recovery
Moved, skipped, failed and remaining counts are shown. Result history opens a local JSONL journal. moved means verified movement, skipped means an existing item was left alone, failed/changed needs attention, and attempt lists a batch about to run. After an unexpected exit, check both folders for unfinished attempts. A failed cross-volume move may leave a partial copy at the destination; keep the original and compare both before acting.
Automatic Undo is unavailable. To restore, use Finder to return only items recorded as moved to their original paths. Never overwrite a conflict. Do not reverse-move the entire destination folder, which may include unrelated files.

Privacy and updates
No network communication. File paths, not file contents, are saved to ~/Library/Application Support/FolderMover/History. History is not automatically deleted; remove unneeded journals in Finder. Preferences use UserDefaults. This local build has no configured update feed, update verification key or notarization.
Support: the Codex chat that created this app.''',
'''FolderMover — 批量移动文件夹内容

基本操作
点击左右卡片或拖放文件夹，点击移动并确认数量和路径。只选择源文件夹的直属项目。包含文件夹时会整体移动其内容。同名项目跳过，不覆盖，不合并文件夹。

大批量与停止
使用 /bin/mv -n，每批最多128项、约64KB参数。进度为直属项目数量，不是字节或子文件数量。停止或Esc会等待当前批次结束。大文件或跨磁盘移动可能需要较长时间。请勿强制退出或断开磁盘。

设置与快捷键
⌘,打开设置，登录时启动默认关闭。保持运行时⌘W只关闭窗口，可从Dock或⌘0重新打开。⌘Q退出，移动中请先停止再退出。关闭保持运行后，空闲时关闭主窗口会退出。登录启动不显示窗口。
在macOS快捷指令中创建“打开App → FolderMover”，在详情中分配快捷键，也在那里修改或删除。本应用不监听全局按键。

权限与故障
无需辅助功能权限，需要所选文件夹的读写权限。访问被拒绝时，检查访达“显示简介”、系统设置→隐私与安全性→文件与文件夹，以及磁盘连接，然后重新选择。不要求完全磁盘访问权限。检查后被替换的项目会报告失败。请等待其他应用或同步操作停止修改文件夹。

结果与恢复
显示已移动、跳过、失败、未处理的数量。结果记录为本地JSONL。moved为已确认移动，skipped为保留原项，failed/changed需要处理，attempt为即将执行的批次。异常退出后如只有attempt，请用访达检查两个文件夹。跨磁盘失败可能留下不完整的目标副本，请保留原件并检查两边。
不支持自动撤销。恢复时只将记录中moved的项目用访达移回原路径，遇到同名时不要覆盖。不要反向移动整个目标文件夹，以免影响其他文件。

隐私与更新
没有网络通信。路径记录在 ~/Library/Application Support/FolderMover/History，不保存文件内容。记录不会自动删除，可在访达中删除。设置使用UserDefaults保存。本地版本未配置更新源、更新验证密钥或公证。
支持：创建此应用的Codex对话。''',
'''FolderMover — 폴더 내용 일괄 이동

사용 방법
각 카드에서 폴더를 선택하거나 드롭하세요. 이동을 누르고 항목 수와 경로를 확인합니다. 원본 바로 아래의 항목만 선택합니다. 폴더를 포함하면 내용 전체를 이동합니다. 같은 이름은 건너뛰며 덮어쓰기나 폴더 병합은 하지 않습니다.

대량 이동과 중지
/bin/mv -n을 최대 128개 항목, 약 64KB 인수 단위로 실행합니다. 진행률은 최상위 항목 수이며 바이트나 하위 파일 수가 아닙니다. 중지 또는 Esc는 현재 배치가 끝날 때까지 기다립니다. 큰 파일이나 다른 디스크로의 이동은 중지에 시간이 걸릴 수 있습니다. 강제 종료하거나 디스크를 분리하지 마세요.

설정과 단축키
⌘,로 설정을 엽니다. 로그인 시 실행은 기본적으로 꺼져 있습니다. 계속 실행을 켜면 ⌘W는 창만 닫고 Dock 또는 ⌘0으로 다시 열 수 있습니다. ⌘Q는 종료합니다. 이동 중에는 먼저 중지한 후 다시 종료하세요. 계속 실행을 끄면 대기 중 주 창을 닫을 때 종료합니다. 로그인 실행 시 창을 표시하지 않습니다.
macOS 단축어에서 “앱 열기 → FolderMover”을 만들고 세부사항에서 키보드 단축키를 지정하세요. 같은 곳에서 변경하거나 삭제합니다. 앱은 전역 키를 감시하지 않습니다.

권한과 문제 해결
손쉬운 사용 권한은 필요하지 않습니다. 선택한 폴더의 읽기/쓰기 권한이 필요합니다. 접근이 거부되면 Finder 정보 가져오기, 시스템 설정→개인정보 보호 및 보안→파일 및 폴더, 디스크 연결을 확인하고 다시 선택하세요. 전체 디스크 접근 권한은 요청하지 않습니다. 확인 후 교체된 항목은 실패로 표시합니다. 다른 앱이나 동기화가 폴더를 변경하는 동안에는 기다려 주세요.

결과와 복구
이동, 건너뜀, 실패, 남은 항목 수를 표시합니다. 결과 기록은 로컬 JSONL입니다. moved는 이동 확인, skipped는 기존 항목 보존, failed/changed는 확인 필요, attempt는 실행 예정 배치입니다. 비정상 종료 후 attempt만 남았다면 두 폴더를 확인하세요. 디스크 간 이동 실패 시 대상에 일부 복사본이 남을 수 있습니다. 원본을 보존하고 양쪽을 확인하세요.
자동 실행 취소는 없습니다. 복구하려면 moved로 기록된 항목만 Finder에서 원래 위치로 옮기세요. 같은 이름은 덮어쓰지 마세요. 대상 폴더 전체를 역방향으로 이동하면 다른 파일도 이동할 수 있습니다.

개인정보와 업데이트
외부 통신을 하지 않습니다. 파일 내용이 아닌 경로를 ~/Library/Application Support/FolderMover/History에 저장합니다. 기록은 자동 삭제하지 않으며 Finder에서 삭제할 수 있습니다. 설정은 UserDefaults를 사용합니다. 로컬 빌드에 업데이트 주소, 검증 키, 공증이 설정되지 않았습니다.
지원: 이 앱을 만든 Codex 채팅.'''
]
for idx,lang in enumerate(['ja','en','zh-Hans','ko']):
    folder=root/'Resources'/f'{lang}.lproj'; folder.mkdir(parents=True,exist_ok=True)
    values={r[0]:r[idx+1] for r in rows}; values['helpContent']=helptexts[idx] + '\n\n' + path_help[idx]
    (folder/'Localizable.strings').write_text('\n'.join(json.dumps(k,ensure_ascii=False)+' = '+json.dumps(v,ensure_ascii=False)+';' for k,v in values.items())+'\n')
    (folder/'Help.txt').write_text(helptexts[idx] + '\n\n' + path_help[idx])
info={'CFBundleName':'FolderMover','CFBundleDisplayName':'FolderMover','CFBundleIdentifier':'local.takano.FolderMover','CFBundleExecutable':'FolderMover','CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.0.0','CFBundleVersion':'5','CFBundleIconFile':'FolderMover.icns','LSMinimumSystemVersion':'13.0','LSMultipleInstancesProhibited':True,'NSHighResolutionCapable':True,'CFBundleDevelopmentRegion':'en','CFBundleLocalizations':['ja','en','zh-Hans','ko'],'NSPrincipalClass':'NSApplication'}
(root/'Info.plist').write_bytes(plistlib.dumps(info))
p=root/'Source/LoginAtLaunch.swift';s=p.read_text()
for literal,key in [('ログイン時に起動','login'),('ログイン項目を開く','loginOpen'),('Macへのログイン時に自動起動します。','loginOn'),('システム設定のログイン項目で許可してください。','loginApproval'),('アプリをアプリケーションフォルダに移動して再起動してください。','loginMissing'),('自動起動はOFFです。','loginOff')]:
    s=s.replace('"'+literal+'"','L("'+key+'")')
s=s.replace('"設定を変更できませんでした：\\(error.localizedDescription)"','L("loginError") + error.localizedDescription')
p.write_text(s)
