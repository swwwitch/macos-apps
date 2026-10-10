from pathlib import Path
import json, plistlib
root = Path(__file__).resolve().parent
LANGS = ['ja', 'en', 'zh-Hans', 'ko']
rows = [
('headline', 'InDesignの「バックグラウンド書き出し／保存」をオフ', 'Turn off InDesign background export', '关闭 InDesign 后台导出', 'InDesign 백그라운드 내보내기 끄기'),
('subtitle', '各バージョンの Contents/MacOS に DisableAsyncExports.txt を配置します。', 'Places DisableAsyncExports.txt in Contents/MacOS of each version.', '在各版本的 Contents/MacOS 中放置 DisableAsyncExports.txt。', '각 버전의 Contents/MacOS에 DisableAsyncExports.txt를 배치합니다.'),
('stateOff', 'バックグラウンド書き出し／保存：オフ', 'Background export: Off', '后台导出：关闭', '백그라운드 내보내기: 끔'),
('stateOn', 'バックグラウンド書き出し／保存：オン（標準）', 'Background export: On (default)', '后台导出：开启（默认）', '백그라운드 내보내기: 켬(기본값)'),
('stateInvalid', '状態を確認できません', 'Status unavailable', '无法确认状态', '상태를 확인할 수 없음'),
('invalidDetail', '同じ名前の項目が通常のファイルではありません。Finderで確認してください。', 'An item with this name is not a regular file. Check it in Finder.', '同名项目不是普通文件。请在访达中确认。', '같은 이름의 항목이 일반 파일이 아닙니다. Finder에서 확인하세요.'),
('running', '起動中', 'Running', '运行中', '실행 중'),
('turnOff', 'オフにする', 'Turn Off', '关闭', '끄기'),
('restore', '元に戻す', 'Restore', '恢复', '되돌리기'),
('turnOffAll', 'すべてオフにする', 'Turn Off All', '全部关闭', '모두 끄기'),
('reload', '再読み込み', 'Reload', '重新载入', '새로 고침'),
('reveal', 'Finderで表示', 'Show in Finder', '在访达中显示', 'Finder에서 보기'),
('addApp', 'InDesignを追加…', 'Add InDesign…', '添加 InDesign…', 'InDesign 추가…'),
('found', '%ld件のInDesignを検出しました。反映はInDesignの次回起動からです。', 'Found %ld InDesign installations. Changes apply the next time InDesign starts.', '检测到 %ld 个 InDesign。更改将在下次启动 InDesign 时生效。', 'InDesign %ld개를 찾았습니다. 변경 사항은 다음 InDesign 실행부터 적용됩니다.'),
('notFound', 'InDesignが見つかりません', 'InDesign was not found', '未找到 InDesign', 'InDesign을 찾을 수 없습니다'),
('notFoundDetail', '/Applications 以外にある場合は「InDesignを追加…」で選んでください。', 'If it is outside /Applications, choose it with Add InDesign….', '如果不在 /Applications 中，请通过“添加 InDesign…”选择。', '/Applications 밖에 있다면 InDesign 추가…로 선택하세요.'),
('notInDesign', '選んだアプリはInDesignではありません（InDesign Serverは対象外です）。', 'The selected app is not InDesign (InDesign Server is not supported).', '所选应用不是 InDesign（不支持 InDesign Server）。', '선택한 앱은 InDesign이 아닙니다(InDesign Server는 지원하지 않음).'),
('nothingToDo', '変更が必要なInDesignはありませんでした。表示を最新の状態にしました。', 'Nothing needed changing. The list has been refreshed.', '没有需要更改的 InDesign。列表已刷新。', '변경할 InDesign이 없습니다. 목록을 새로 고쳤습니다.'),
('authPrompt', 'InDesignのアプリ内にファイルを配置・削除するため、管理者パスワードが必要です。', 'An administrator password is needed to add or remove a file inside the InDesign app.', '需要管理员密码才能在 InDesign 应用内放置或删除文件。', 'InDesign 앱 내부에 파일을 배치하거나 삭제하려면 관리자 암호가 필요합니다.'),
('authCancelled', '認証がキャンセルされたため、変更していません。', 'Authentication was cancelled. Nothing was changed.', '已取消认证，未做任何更改。', '인증이 취소되어 변경하지 않았습니다.'),
('failed', '変更できませんでした：', 'Could not make the change: ', '无法更改：', '변경할 수 없습니다: '),
('invalidPath', '想定外の場所のため中止しました。', 'Stopped because the location was unexpected.', '位置异常，已中止。', '예상하지 못한 위치여서 중단했습니다.'),
('partial', '一部を変更できませんでした（成功 %ld件・失敗 %ld件）。各行の状態を確認してください。', 'Some changes failed (%ld succeeded, %ld failed). Check the status of each row.', '部分更改失败（成功 %ld 个，失败 %ld 个）。请确认各行状态。', '일부를 변경하지 못했습니다(성공 %ld개, 실패 %ld개). 각 행의 상태를 확인하세요.'),
('doneOff', '%ld件をオフにしました。InDesignの次回起動から反映されます。', 'Turned off for %ld. Takes effect the next time InDesign starts.', '已关闭 %ld 个。将在下次启动 InDesign 时生效。', '%ld개를 껐습니다. 다음 InDesign 실행부터 적용됩니다.'),
('doneOn', '%ld件を元に戻しました。InDesignの次回起動から反映されます。', 'Restored %ld. Takes effect the next time InDesign starts.', '已恢复 %ld 个。将在下次启动 InDesign 时生效。', '%ld개를 되돌렸습니다. 다음 InDesign 실행부터 적용됩니다.'),
('restartNote', '起動中のInDesignは、終了して起動し直すと反映されます。', 'Quit and reopen any running InDesign to apply.', '正在运行的 InDesign 需要退出并重新启动后生效。', '실행 중인 InDesign은 종료 후 다시 실행해야 적용됩니다.'),
('updateNote', 'InDesignのアップデートや再インストールでファイルが消え、「オン」に戻ることがあります。その場合はもう一度オフにしてください。', 'Updating or reinstalling InDesign can remove the file and turn background export back on. Turn it off again if that happens.', '更新或重新安装 InDesign 可能会删除该文件并恢复为“开启”。此时请再次关闭。', 'InDesign을 업데이트하거나 다시 설치하면 파일이 사라져 켬으로 돌아갈 수 있습니다. 그럴 때는 다시 끄세요.'),
('about', 'IdBackgroundOffについて', 'About IdBackgroundOff', '关于 IdBackgroundOff', 'IdBackgroundOff에 관하여'),
('services', 'サービス', 'Services', '服务', '서비스'),
('hideApp', 'IdBackgroundOffを隠す', 'Hide IdBackgroundOff', '隐藏 IdBackgroundOff', 'IdBackgroundOff 가리기'),
('hideOthers', 'ほかを隠す', 'Hide Others', '隐藏其他', '기타 가리기'),
('showAll', 'すべてを表示', 'Show All', '全部显示', '모두 보기'),
('quit', 'IdBackgroundOffを終了', 'Quit IdBackgroundOff', '退出 IdBackgroundOff', 'IdBackgroundOff 종료'),
('file', 'ファイル', 'File', '文件', '파일'),
('openMainWindow', 'メインウインドウを開く', 'Open Main Window', '打开主窗口', '메인 윈도우 열기'),
('close', 'ウインドウを閉じる', 'Close Window', '关闭窗口', '윈도우 닫기'),
('edit', '編集', 'Edit', '编辑', '편집'),
('undo', '取り消す', 'Undo', '撤销', '실행 취소'),
('redo', 'やり直す', 'Redo', '重做', '실행 복귀'),
('cut', 'カット', 'Cut', '剪切', '오려두기'),
('copy', 'コピー', 'Copy', '拷贝', '복사하기'),
('paste', 'ペースト', 'Paste', '粘贴', '붙여넣기'),
('selectAll', 'すべてを選択', 'Select All', '全选', '모두 선택'),
('window', 'ウインドウ', 'Window', '窗口', '윈도우'),
('minimize', 'しまう', 'Minimize', '最小化', '최소화'),
('zoom', '拡大／縮小', 'Zoom', '缩放', '확대/축소'),
('bringAllToFront', 'すべてを手前に移動', 'Bring All to Front', '前置全部窗口', '모두 앞으로 가져오기'),
('help', 'ヘルプ', 'Help', '帮助', '도움말'),
('helpItem', 'IdBackgroundOffヘルプ', 'IdBackgroundOff Help', 'IdBackgroundOff 帮助', 'IdBackgroundOff 도움말'),
('support', 'サポート：同梱のREADME.md', 'Support: see the bundled README.md', '支持：请参阅随附的 README.md', '지원: 함께 제공된 README.md 참조'),
]
helptexts = [
'''IdBackgroundOff — InDesignの「バックグラウンド書き出し／保存」をオフ

しくみ
InDesignのアプリ内の Contents/MacOS フォルダに、空のファイル DisableAsyncExports.txt を置くと、PDFなどの書き出しがバックグラウンド処理ではなく通常の処理で行われます。このアプリはそのファイルの配置と削除だけを行います。ファイルの中身は空で、InDesignの設定ファイルや書類には触れません。

基本操作
起動すると /Applications と ~/Applications にあるInDesign（2025、2026 など）を一覧表示します。各行の「オフにする」で配置、「元に戻す」で削除します。「すべてオフにする」は、オンのままのバージョンをまとめてオフにします。虫めがねのボタンでFinderに表示します。
別の場所にあるInDesignは「InDesignを追加…」（⌘O）で選びます。InDesign Serverは対象外です。
反映はInDesignの次回起動からです。起動中のInDesignは終了して起動し直してください。

管理者パスワード
InDesignのアプリ内は管理者の権限で保護されているため、変更時にmacOSの認証ダイアログが表示されます。パスワードはmacOSが扱い、このアプリは保存しません。キャンセルした場合は何も変更しません。アクセシビリティ、フルディスクアクセスなどの権限は不要です。

アップデートしたとき
InDesignのアップデートや再インストールでファイルが消え、「オン」に戻ることがあります。毎年秋のメジャーバージョンは別のフォルダ（例：Adobe InDesign 2027）にインストールされるため、新しいバージョンは改めてオフにしてください。アプリに戻ると状態を読み直します。⌘Rでも再読み込みできます。

終了とショートカット
常駐はしません。ウインドウを閉じる（⌘W）か⌘Qで終了します。⌘Rで再読み込み、⌘Oで「InDesignを追加…」、⌘0で「メインウインドウを開く」、⇧⌘Zで「やり直す」、⌘?でこのヘルプを開きます。設定画面はありません。

メニューバー
アプリメニューの「メニューバー設定…」で「メニューバーに追加」をオンにすると、メニューバーにアイコンを表示します（初期値はオフ）。アイコンのメニューから「メインウインドウを開く」「ヘルプ」（IdBackgroundOffヘルプ／note記事を開く）「IdBackgroundOffを終了」を選べます。アイコンを表示している間は、ウインドウを閉じても終了せず、アイコンや⌘0から再表示できます。

困ったとき・元に戻す方法
「状態を確認できません」は、同じ名前のフォルダやリンクがある場合です。このアプリは変更しないので、Finderで確認してください。
アプリを使わずに戻す場合は、InDesignのアプリを右クリック→「パッケージの内容を表示」→ Contents → MacOS の DisableAsyncExports.txt をゴミ箱に入れます。
一部だけ失敗した場合は、結果の件数と各行の状態を確認し、もう一度実行してください。

プライバシー・更新
外部通信はありません。保存するのは「InDesignを追加…」で選んだアプリのパス、ウインドウ位置、メニューバー表示の選択（UserDefaults）だけです。アプリメニューの「アップデートを確認…」「アップデートを自動確認」は共通の更新機能ですが、現在のビルドはローカル利用向けのad-hoc署名で、更新先・署名鍵・公証が未設定のため「更新配布の準備中」と表示し、通信しません。
参考：https://note.com/dtp_tranist/n/nf94bf905c478
サポート：同梱のREADME.md（アプリ内 Contents/Resources/README.md）。''',
'''IdBackgroundOff — Turn off InDesign background export

How it works
Placing an empty file named DisableAsyncExports.txt in the Contents/MacOS folder inside InDesign makes exports such as PDF run in the foreground instead of as background tasks. This app only adds or removes that file. The file is empty, and InDesign preferences and documents are not touched.

Basic use
The app lists InDesign versions (2025, 2026 and so on) found in /Applications and ~/Applications. Turn Off adds the file and Restore removes it. Turn Off All handles every version that is still on. The magnifier button shows the location in Finder.
Use Add InDesign… (⌘O) for a copy in another location. InDesign Server is not supported.
Changes take effect the next time InDesign starts. Quit and reopen InDesign if it is running.

Administrator password
The inside of the InDesign app is protected, so macOS asks for an administrator password when you make a change. macOS handles the password; this app never stores it. If you cancel, nothing is changed. Accessibility, Full Disk Access and similar permissions are not required.

After updating InDesign
An update or reinstall can remove the file and turn background export back on. Each autumn's major version installs into a new folder (for example Adobe InDesign 2027), so turn it off again for the new version. The list is re-read when you return to the app, or with ⌘R.

Quitting and shortcuts
The app does not stay running. Closing the window (⌘W) or ⌘Q quits it. ⌘R reloads, ⌘O adds InDesign, ⌘0 opens the main window (Open Main Window), ⇧⌘Z redoes, and ⌘? opens this help. There is no settings window.

Menu bar
Turn on Add to Menu Bar in Menu Bar Settings… in the app menu to show an icon in the menu bar (off by default). Its menu offers Open Main Window, Help (IdBackgroundOff Help / Open the note Article) and Quit IdBackgroundOff. While the icon is shown, closing the window does not quit the app; reopen it from the icon or with ⌘0.

Troubleshooting and manual restore
Status unavailable means a folder or link with the same name exists. The app leaves it alone; check it in Finder.
To restore without the app, Control-click InDesign, choose Show Package Contents, open Contents → MacOS and move DisableAsyncExports.txt to the Trash.
If only some changes failed, check the counts and each row, then try again.

Privacy and updates
No network access. Only the paths of apps chosen with Add InDesign…, the window position and the menu bar choice are saved (UserDefaults). Check for Updates… and Automatically Check for Updates in the app menu use the shared updater, but this build is ad-hoc signed for local use with no update feed, signing key or notarization, so it reports that updates are not configured and makes no network access.
Reference (Japanese): https://note.com/dtp_tranist/n/nf94bf905c478
Support: see the bundled README.md (Contents/Resources/README.md inside the app).''',
'''IdBackgroundOff — 关闭 InDesign 后台导出

原理
在 InDesign 应用内的 Contents/MacOS 文件夹中放置名为 DisableAsyncExports.txt 的空文件后，PDF 等导出将不再作为后台任务运行。本应用只负责放置或删除该文件。文件为空，不会改动 InDesign 的偏好设置或文档。

基本操作
应用会列出 /Applications 和 ~/Applications 中的 InDesign（2025、2026 等）。“关闭”放置文件，“恢复”删除文件。“全部关闭”会处理所有仍为开启的版本。放大镜按钮可在访达中显示位置。
其他位置的 InDesign 可通过“添加 InDesign…”（⌘O）选择。不支持 InDesign Server。
更改将在下次启动 InDesign 时生效。若 InDesign 正在运行，请退出后重新启动。

管理员密码
InDesign 应用内部受到保护，因此更改时 macOS 会要求输入管理员密码。密码由 macOS 处理，本应用不会保存。取消时不做任何更改。不需要辅助功能、完全磁盘访问等权限。

更新 InDesign 之后
更新或重新安装可能会删除该文件并恢复为开启。每年秋季的大版本会安装到新的文件夹（例如 Adobe InDesign 2027），请为新版本再次关闭。返回本应用或按 ⌘R 时会重新读取状态。

退出与快捷键
本应用不驻留。关闭窗口（⌘W）或按 ⌘Q 即退出。⌘R 重新载入，⌘O 添加 InDesign，⌘0 打开主窗口，⇧⌘Z 重做，⌘? 打开本帮助。没有设置窗口。

菜单栏
在应用菜单的“菜单栏设置…”中开启“添加到菜单栏”后，会在菜单栏显示图标（默认关闭）。图标菜单提供“打开主窗口”“帮助”（IdBackgroundOff 帮助／打开 note 文章）和“退出 IdBackgroundOff”。显示图标期间，关闭窗口不会退出，可从图标或用 ⌘0 重新打开。

故障排除与手动恢复
“无法确认状态”表示存在同名的文件夹或链接。本应用不会更改它，请在访达中确认。
不使用本应用恢复时，按住 Control 点按 InDesign，选择“显示包内容”，打开 Contents → MacOS，将 DisableAsyncExports.txt 移到废纸篓。
若只有部分更改失败，请确认数量和各行状态后重试。

隐私与更新
无网络通信。仅保存通过“添加 InDesign…”选择的应用路径、窗口位置和菜单栏显示选择（UserDefaults）。应用菜单中的“检查更新…”和“自动检查更新”使用通用更新功能，但当前版本为本地使用的 ad-hoc 签名，未配置更新源、签名密钥和公证，因此会显示尚未配置，不进行网络通信。
参考（日语）：https://note.com/dtp_tranist/n/nf94bf905c478
支持：请参阅随附的 README.md（应用内 Contents/Resources/README.md）。''',
'''IdBackgroundOff — InDesign 백그라운드 내보내기 끄기

작동 방식
InDesign 앱 내부의 Contents/MacOS 폴더에 DisableAsyncExports.txt라는 빈 파일을 두면 PDF 등의 내보내기가 백그라운드 작업이 아닌 일반 처리로 실행됩니다. 이 앱은 그 파일을 배치하거나 삭제하기만 합니다. 파일은 비어 있으며 InDesign 환경 설정이나 문서는 변경하지 않습니다.

기본 사용법
/Applications와 ~/Applications에 있는 InDesign(2025, 2026 등)을 목록으로 표시합니다. 끄기는 파일을 배치하고 되돌리기는 삭제합니다. 모두 끄기는 아직 켜져 있는 모든 버전을 처리합니다. 돋보기 버튼으로 Finder에서 위치를 표시합니다.
다른 위치의 InDesign은 InDesign 추가…(⌘O)로 선택하세요. InDesign Server는 지원하지 않습니다.
변경 사항은 다음 InDesign 실행부터 적용됩니다. 실행 중이라면 종료 후 다시 실행하세요.

관리자 암호
InDesign 앱 내부는 보호되어 있어 변경할 때 macOS가 관리자 암호를 요청합니다. 암호는 macOS가 처리하며 이 앱은 저장하지 않습니다. 취소하면 아무것도 변경하지 않습니다. 손쉬운 사용, 전체 디스크 접근 권한 등은 필요하지 않습니다.

InDesign 업데이트 후
업데이트나 재설치로 파일이 사라져 켬으로 돌아갈 수 있습니다. 매년 가을의 메이저 버전은 새 폴더(예: Adobe InDesign 2027)에 설치되므로 새 버전에서 다시 끄세요. 앱으로 돌아오거나 ⌘R을 누르면 상태를 다시 읽습니다.

종료와 단축키
상주하지 않습니다. 창을 닫거나(⌘W) ⌘Q를 누르면 종료합니다. ⌘R은 새로 고침, ⌘O는 InDesign 추가, ⌘0은 메인 윈도우 열기, ⇧⌘Z는 실행 복귀, ⌘?는 이 도움말입니다. 설정 창은 없습니다.

메뉴 막대
앱 메뉴의 메뉴 막대 설정…에서 메뉴 막대에 추가를 켜면 메뉴 막대에 아이콘을 표시합니다(기본값은 꺼짐). 아이콘 메뉴에서 메인 윈도우 열기, 도움말(IdBackgroundOff 도움말 / note 글 열기), IdBackgroundOff 종료를 선택할 수 있습니다. 아이콘을 표시하는 동안에는 창을 닫아도 종료하지 않으며 아이콘이나 ⌘0으로 다시 열 수 있습니다.

문제 해결과 수동 복원
상태를 확인할 수 없음은 같은 이름의 폴더나 링크가 있는 경우입니다. 앱은 이를 변경하지 않으니 Finder에서 확인하세요.
앱 없이 되돌리려면 InDesign을 Control-클릭하고 패키지 내용 보기 → Contents → MacOS에서 DisableAsyncExports.txt를 휴지통으로 옮기세요.
일부만 실패했다면 결과 수와 각 행의 상태를 확인한 뒤 다시 실행하세요.

개인정보와 업데이트
네트워크 통신을 하지 않습니다. InDesign 추가…로 선택한 앱의 경로, 창 위치, 메뉴 막대 표시 선택(UserDefaults)만 저장합니다. 앱 메뉴의 업데이트 확인… 및 업데이트 자동 확인은 공통 업데이트 기능이지만, 현재 빌드는 로컬용 ad-hoc 서명이며 업데이트 주소, 서명 키, 공증이 설정되지 않아 준비 중으로 표시하고 통신하지 않습니다.
참고(일본어): https://note.com/dtp_tranist/n/nf94bf905c478
지원: 함께 제공된 README.md(앱 내부 Contents/Resources/README.md)를 참조하세요.''',
]
for idx, lang in enumerate(LANGS):
    folder = root / 'Resources' / f'{lang}.lproj'; folder.mkdir(parents=True, exist_ok=True)
    values = {r[0]: r[idx + 1] for r in rows}; values['helpContent'] = helptexts[idx]
    (folder / 'Localizable.strings').write_text('\n'.join(json.dumps(k, ensure_ascii=False) + ' = ' + json.dumps(v, ensure_ascii=False) + ';' for k, v in values.items()) + '\n')
    (folder / 'Help.txt').write_text(helptexts[idx] + '\n')
info = {'CFBundleName': 'IdBackgroundOff', 'CFBundleDisplayName': 'IdBackgroundOff', 'CFBundleIdentifier': 'local.takano.IdAsyncOff', 'CFBundleExecutable': 'IdBackgroundOff', 'CFBundlePackageType': 'APPL', 'CFBundleIconFile': 'IdBackgroundOff.icns', 'LSMinimumSystemVersion': '13.0', 'LSMultipleInstancesProhibited': True, 'NSHighResolutionCapable': True, 'CFBundleDevelopmentRegion': 'en', 'CFBundleLocalizations': LANGS, 'NSPrincipalClass': 'NSApplication', 'LSApplicationCategoryType': 'public.app-category.utilities', 'SWNoteArticleURL': 'https://note.com/dtp_tranist/n/nec393e9218e9', 'SWAppFamily': 'swwwitch', 'NSHumanReadableCopyright': '© 2026 swwwitch', 'CFBundleShortVersionString': '1.0.0', 'CFBundleVersion': '1'}
# Version and build come from the existing Info.plist, so regeneration never reverts them.
plist_path = root / 'Info.plist'; current = plistlib.loads(plist_path.read_bytes()) if plist_path.exists() else {}
info.update({k: current[k] for k in ('CFBundleShortVersionString', 'CFBundleVersion') if k in current})
plist_path.write_bytes(plistlib.dumps(info))
