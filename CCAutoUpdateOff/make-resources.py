from pathlib import Path
import json, plistlib
root = Path(__file__).resolve().parent
LANGS = ['ja', 'en', 'zh-Hans', 'ko']
APPLE_EVENTS = ['自動更新の状態を「メール」アプリでメール送信するために使います。', 'Sends the auto-update status by mail through the Mail app.', '用于通过“邮件”应用发送自动更新状态。', 'Mail 앱으로 자동 업데이트 상태를 메일로 보내는 데 사용합니다.']
rows = [
('headline', 'Creative Cloudの自動更新を見張る', 'Watch Creative Cloud auto-updates', '监视 Creative Cloud 自动更新', 'Creative Cloud 자동 업데이트 감시'),
('subtitle', 'アプリの自動更新がオンになっていたら、通知やメールで知らせます。設定は変更しません。', 'Tells you by notification or mail when app auto-update is on. Settings are never changed.', '应用自动更新开启时，通过通知或邮件提醒。不会更改设置。', '앱 자동 업데이트가 켜져 있으면 알림이나 메일로 알려 줍니다. 설정은 변경하지 않습니다.'),
('globalRow', '自動更新（全体）', 'Auto-update (all apps)', '自动更新（全部）', '자동 업데이트(전체)'),
('stateOff', 'オフ', 'Off', '关闭', '끔'),
('stateOn', 'オン', 'On', '开启', '켬'),
('levelOff', '自動更新（全体）はオフです。アプリは自動更新されません。', 'Auto-update is off. No app updates automatically.', '自动更新已关闭。应用不会自动更新。', '자동 업데이트가 꺼져 있습니다. 앱은 자동으로 업데이트되지 않습니다.'),
('levelCaution', '自動更新（全体）はオンですが、アプリはすべてオフです。新しく入れたアプリは自動更新されることがあります。', 'Auto-update is on, but every app is off. Newly installed apps may update automatically.', '自动更新已开启，但所有应用均为关闭。新安装的应用可能会自动更新。', '자동 업데이트는 켜져 있지만 모든 앱이 꺼져 있습니다. 새로 설치한 앱은 자동 업데이트될 수 있습니다.'),
('levelOn', '自動更新されるアプリがあります：%@', 'These apps update automatically: %@', '以下应用会自动更新：%@', '자동 업데이트되는 앱이 있습니다: %@'),
('listSeparator', '、', ', ', '、', ', '),
('notFound', 'Creative Cloudの設定ファイルが見つかりません', 'Creative Cloud preferences were not found', '未找到 Creative Cloud 偏好设置文件', 'Creative Cloud 설정 파일을 찾을 수 없습니다'),
('notFoundDetail', 'Creative Cloudにサインインして、一度［環境設定］→［アプリ］を開いてください。', 'Sign in to Creative Cloud and open Preferences → Apps once.', '请登录 Creative Cloud，并打开一次“偏好设置 → 应用”。', 'Creative Cloud에 로그인하고 환경설정 → 앱을 한 번 여세요.'),
('invalidFile', 'Creative Cloudの設定ファイルを読み取れません。', 'The Creative Cloud preferences file could not be read.', '无法读取 Creative Cloud 偏好设置文件。', 'Creative Cloud 설정 파일을 읽을 수 없습니다.'),
('note', '切り替えはCreative Cloudの［環境設定］→［アプリ］で行います。このアプリは設定ファイルを読むだけで、変更しません。', 'Change the switches in Creative Cloud Preferences → Apps. This app only reads the settings file and never changes it.', '请在 Creative Cloud 的“偏好设置 → 应用”中切换。本应用只读取设置文件，不做更改。', '스위치는 Creative Cloud 환경설정 → 앱에서 변경합니다. 이 앱은 설정 파일을 읽기만 하고 변경하지 않습니다.'),
('reload', '再読み込み', 'Reload', '重新载入', '새로 고침'),
('openCC', 'Creative Cloudを開く', 'Open Creative Cloud', '打开 Creative Cloud', 'Creative Cloud 열기'),
('settingsButton', '設定…', 'Settings…', '设置…', '설정…'),
('settings', '設定…', 'Settings…', '设置…', '설정…'),
('settingsTitle', 'CCAutoUpdateOff 設定', 'CCAutoUpdateOff Settings', 'CCAutoUpdateOff 设置', 'CCAutoUpdateOff 설정'),
('notifyTab', '通知・メール', 'Notifications & Mail', '通知与邮件', '알림 및 메일'),
('notifySection', '通知', 'Notifications', '通知', '알림'),
('notifyToggle', '自動更新がオンになったら通知する', 'Notify when auto-update turns on', '自动更新开启时通知', '자동 업데이트가 켜지면 알림'),
('notifyHint', 'オンになったとき（新しいアプリが増えたときを含む）に1回通知します。通知をクリックするとCreative Cloudを開きます。', 'Notifies once when it turns on, including when a new app appears. Clicking the notification opens Creative Cloud.', '开启时（包括新增应用时）通知一次。点击通知会打开 Creative Cloud。', '켜졌을 때(새 앱이 추가된 경우 포함) 한 번 알립니다. 알림을 클릭하면 Creative Cloud를 엽니다.'),
('notifyDenied', '通知が許可されていません。システム設定の［通知］でCCAutoUpdateOffを許可してください。', 'Notifications are not allowed. Allow CCAutoUpdateOff in System Settings → Notifications.', '未允许通知。请在系统设置的“通知”中允许 CCAutoUpdateOff。', '알림이 허용되지 않았습니다. 시스템 설정의 알림에서 CCAutoUpdateOff를 허용하세요.'),
('openNotificationSettings', '通知の設定を開く', 'Open Notification Settings', '打开通知设置', '알림 설정 열기'),
('notifyTest', 'テスト通知', 'Send Test Notification', '发送测试通知', '테스트 알림'),
('notifyTitle', 'Creative Cloudの自動更新がオンです', 'Creative Cloud auto-update is on', 'Creative Cloud 自动更新已开启', 'Creative Cloud 자동 업데이트가 켜져 있습니다'),
('notifyBody', '自動更新されるアプリ：%@', 'Apps that update automatically: %@', '会自动更新的应用：%@', '자동 업데이트되는 앱: %@'),
('notifyTestBody', 'テスト通知です。', 'This is a test notification.', '这是测试通知。', '테스트 알림입니다.'),
('mailSection', 'メール送信', 'Mail', '发送邮件', '메일 보내기'),
('mailToggle', '自動更新がオンの間、1日1回メールで知らせる', 'Email me once a day while auto-update is on', '自动更新开启期间每天发送一封邮件', '자동 업데이트가 켜져 있는 동안 하루 한 번 메일로 알림'),
('mailTo', '宛先 :', 'To:', '收件人：', '받는 사람:'),
('mailTime', '送信時刻 :', 'Send at:', '发送时间：', '보낼 시각:'),
('mailHint', 'Macの「メール」アプリに設定したアカウントから送ります（最初の1回だけ「メール」の制御の許可を求められます）。件名にMac名、本文にMac名とホスト名を添えます。指定時刻にスリープ中の場合は復帰後に送ります。', 'Sent from the account set up in the Mail app (macOS asks once for permission to control Mail). The subject includes the Mac name; the body includes the Mac and host names. If asleep at the scheduled time, mail is sent after waking.', '使用“邮件”应用中设置的账户发送（首次会请求控制“邮件”的权限）。主题包含 Mac 名称，正文包含 Mac 和主机名称。到设定时间仍在睡眠时，唤醒后发送。', 'Mac의 Mail 앱에 설정된 계정으로 보냅니다(처음 한 번 Mail 제어 권한을 요청합니다). 제목에는 Mac 이름, 본문에는 Mac과 호스트 이름을 포함합니다. 예약 시각에 잠자기 상태이면 깨어난 뒤 보냅니다.'),
('mailTest', 'テスト送信', 'Send Test Mail', '发送测试邮件', '테스트 메일 보내기'),
('mailSending', '送信中…', 'Sending…', '正在发送…', '보내는 중…'),
('mailSent', '%1$@ に送信しました（%2$@）。', 'Sent to %1$@ (%2$@).', '已发送到 %1$@（%2$@）。', '%1$@(으)로 보냈습니다(%2$@).'),
('mailTestSent', '%1$@ にテストメールを送信しました（%2$@）。届いたか確認してください。', 'Test mail sent to %1$@ (%2$@). Check that it arrived.', '已向 %1$@ 发送测试邮件（%2$@）。请确认是否收到。', '%1$@(으)로 테스트 메일을 보냈습니다(%2$@). 도착했는지 확인하세요.'),
('mailInvalidAddress', 'メールアドレスを確認してください。', 'Check the email address.', '请检查邮件地址。', '메일 주소를 확인하세요.'),
('mailDenied', '「メール」を制御する許可がありません。システム設定の［プライバシーとセキュリティ］→［オートメーション］でCCAutoUpdateOffの「メール」をオンにしてください。', 'Not allowed to control Mail. Turn on Mail for CCAutoUpdateOff in System Settings → Privacy & Security → Automation.', '没有控制“邮件”的权限。请在系统设置的“隐私与安全性 → 自动化”中为 CCAutoUpdateOff 打开“邮件”。', 'Mail 제어 권한이 없습니다. 시스템 설정의 개인정보 보호 및 보안 → 자동화에서 CCAutoUpdateOff의 Mail을 켜세요.'),
('mailFailed', '送信できませんでした：', 'Could not send: ', '无法发送：', '보낼 수 없습니다: '),
('mailSubject', '[CCAutoUpdateOff] Creative Cloudの自動更新がオンです（%@）', '[CCAutoUpdateOff] Creative Cloud auto-update is on (%@)', '[CCAutoUpdateOff] Creative Cloud 自动更新已开启（%@）', '[CCAutoUpdateOff] Creative Cloud 자동 업데이트가 켜져 있습니다(%@)'),
('mailTestSubject', '[CCAutoUpdateOff] テストメール（%@）', '[CCAutoUpdateOff] Test mail (%@)', '[CCAutoUpdateOff] 测试邮件（%@）', '[CCAutoUpdateOff] 테스트 메일 (%@)'),
('mailTestBody', 'これはCCAutoUpdateOffのテストメールです。現在の状態は次のとおりです。', 'This is a test mail from CCAutoUpdateOff. The current state is:', '这是 CCAutoUpdateOff 的测试邮件。当前状态如下：', 'CCAutoUpdateOff의 테스트 메일입니다. 현재 상태는 다음과 같습니다.'),
('mailSourceMac', '送信元のMac：%@', 'Source Mac: %@', '发送来源 Mac：%@', '보낸 Mac: %@'),
('mailSourceHost', 'ホスト名：%@', 'Host name: %@', '主机名：%@', '호스트 이름: %@'),
('mailIntro', '%@ のCreative Cloudの自動更新の設定：', 'Creative Cloud auto-update settings on %@:', '%@ 上的 Creative Cloud 自动更新设置：', '%@의 Creative Cloud 자동 업데이트 설정:'),
('mailHowTo', 'オフにするには、Creative Cloudの［環境設定］→［アプリ］でスイッチを切り替えてください。オンの間は1日1回お知らせします。', 'To turn it off, use the switches in Creative Cloud Preferences → Apps. You will get this once a day while it is on.', '要关闭，请在 Creative Cloud 的“偏好设置 → 应用”中切换开关。开启期间每天提醒一次。', '끄려면 Creative Cloud 환경설정 → 앱에서 스위치를 변경하세요. 켜져 있는 동안 하루 한 번 알립니다.'),
('removeOldOn', '「以前のバージョンを削除」がオンのアプリがあります：%@', '“Remove previous versions” is on for: %@', '以下应用开启了“删除以前的版本”：%@', '"이전 버전 제거"가 켜진 앱이 있습니다: %@'),
('removeOldTitle', '「以前のバージョンを削除」がオンです', '“Remove previous versions” is on', '“删除以前的版本”已开启', '"이전 버전 제거"가 켜져 있습니다'),
('mailSubjectRemoveOld', '[CCAutoUpdateOff] 「以前のバージョンを削除」がオンです（%@）', '[CCAutoUpdateOff] “Remove previous versions” is on (%@)', '[CCAutoUpdateOff] “删除以前的版本”已开启（%@）', '[CCAutoUpdateOff] "이전 버전 제거"가 켜져 있습니다(%@)'),
('targetSection', '知らせる内容', 'What to report', '提醒内容', '알릴 내용'),
('targetAutoUpdate', '自動更新がオンのアプリ（常に対象）', 'Apps with auto-update on (always)', '开启自动更新的应用（始终）', '자동 업데이트가 켜진 앱(항상)'),
('removeOldToggle', '「以前のバージョンを削除」がオンのアプリも知らせる', 'Also report apps with “Remove previous versions” on', '同时提醒开启了“删除以前的版本”的应用', '"이전 버전 제거"가 켜진 앱도 알림'),
('removeOldHint', 'Creative Cloudの［環境設定］→［アプリ］→ 各アプリの［詳細オプション］の項目です。オンだと、更新したときに古いバージョンが削除されます。自動更新が効いているアプリだけが対象です（自動更新がオフのアプリはCreative Cloudでも操作できません）。', 'The option under Advanced options for each app in Creative Cloud Preferences → Apps. When on, the old version is removed when the app auto-updates. Only apps whose auto-update is in effect count (Creative Cloud greys the option out otherwise).', '位于 Creative Cloud“偏好设置 → 应用”中各应用的“高级选项”。开启后，自动更新时会删除旧版本。仅针对自动更新生效的应用（否则 Creative Cloud 中也无法操作）。', 'Creative Cloud 환경설정 → 앱에서 각 앱의 고급 옵션 항목입니다. 켜져 있으면 자동 업데이트할 때 이전 버전이 제거됩니다. 자동 업데이트가 적용되는 앱만 대상입니다(그 외에는 Creative Cloud에서도 조작할 수 없음).'),
('columnApp', 'アプリ名', 'App', '应用', '앱'),
('globalRowShort', '自動更新', 'Auto-update', '自动更新', '자동 업데이트'),
('removeOldShortTitle', '以前のバージョンを削除', 'Remove previous versions', '删除以前的版本', '이전 버전 제거'),
('colon', '：', ': ', '：', ': '),
('mailFieldSeparator', '／', ' / ', '／', ' / '),
('keepRunning', 'ウインドウを閉じても常駐', 'Keep running after closing the window', '关闭窗口后继续运行', '윈도우를 닫아도 계속 실행'),
('keepRunningHint', '見張りを続けるには常駐が必要です。オフにすると、ウインドウを閉じたときに終了します。', 'Watching needs the app to keep running. When off, closing the window quits the app.', '持续监视需要应用保持运行。关闭此项后，关闭窗口即退出。', '감시를 계속하려면 앱이 실행 중이어야 합니다. 끄면 윈도우를 닫을 때 종료합니다.'),
('about', 'CCAutoUpdateOffについて', 'About CCAutoUpdateOff', '关于 CCAutoUpdateOff', 'CCAutoUpdateOff에 관하여'),
('services', 'サービス', 'Services', '服务', '서비스'),
('hideApp', 'CCAutoUpdateOffを隠す', 'Hide CCAutoUpdateOff', '隐藏 CCAutoUpdateOff', 'CCAutoUpdateOff 가리기'),
('hideOthers', 'ほかを隠す', 'Hide Others', '隐藏其他', '기타 가리기'),
('showAll', 'すべてを表示', 'Show All', '全部显示', '모두 보기'),
('quit', 'CCAutoUpdateOffを終了', 'Quit CCAutoUpdateOff', '退出 CCAutoUpdateOff', 'CCAutoUpdateOff 종료'),
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
('helpItem', 'CCAutoUpdateOffヘルプ', 'CCAutoUpdateOff Help', 'CCAutoUpdateOff 帮助', 'CCAutoUpdateOff 도움말'),
('support', 'サポート：同梱のREADME.md', 'Support: see the bundled README.md', '支持：请参阅随附的 README.md', '지원: 함께 제공된 README.md 참조'),
]
helptexts = [
'''CCAutoUpdateOff — Creative Cloudの自動更新を見張る

しくみ
Creative Cloudの［環境設定］→［アプリ］の「自動更新」と、アプリごとのスイッチは、~/Library/Application Support/Adobe/OOBE/com.adobe.accc.apps.<ユーザーID>.prefs に保存され、切り替えるとすぐに書き込まれます。このアプリはそのファイルを読むだけで、変更はしません。ファイルが変わったときと1時間ごと、スリープからの復帰時に読み直します。

表示の意味
- オフ：自動更新しない
- オン：自動更新する
設定ファイルに値が書かれていないアプリも、Creative Cloudの画面ではオンになるため「オン」と表示します。全体の「自動更新」をオフにすると、Creative Cloudはアプリごとの値を消すため、全体をオンに戻すと各アプリはオンに戻ります
全体の「自動更新」がオフなら、アプリは自動更新されません。このとき一覧のアプリ別の「自動更新」は「—」と表示します。全体がオンで、オンのアプリが1つでもあると「自動更新されるアプリがあります」と表示し、知らせます。全体がオンでアプリがすべてオフのときは、新しく入れたアプリが自動更新されることがあるため注意として表示します（通知・メールはしません）。

オフにするには
「Creative Cloudを開く」で起動し、［環境設定］→［アプリ］でスイッチを切り替えます。全体の「自動更新」をオフにすると、アプリ別のスイッチは操作できなくなります。アプリ別に切り替えたいときは、先に全体をオンにしてください。

通知
設定の「通知・メール」→「通知」で、自動更新がオンになったときにmacOSの通知を出せます（初期値はオン）。同じ状態の間は繰り返しません。新しいアプリが増えたときは改めて通知します。通知をクリックするとCreative Cloudを開きます。初回にmacOSが通知の許可を求めます。

以前のバージョンを削除
設定の「知らせる内容」で「「以前のバージョンを削除」がオンのアプリも知らせる」をオンにすると（初期値はオン）、各アプリの［詳細オプション］→「以前のバージョンを削除」（設定ファイルの removeOlderVersions）がオンのアプリも通知・メールの対象になります。一覧の「以前のバージョンを削除」列で、アプリごとの状態を確認できます。自動更新が効いているアプリだけが対象です。自動更新（全体）やそのアプリの自動更新がオフのときは、Creative Cloudでも［詳細オプション］を操作できないため、一覧では「—」と表示します。全体がオフのときは、アプリの行を薄く表示します。

メール送信
設定の「メール送信」をオンにして宛先を入れると、自動更新がオンの間、1日1回メールで知らせます（初期値はオフ）。「送信時刻」で送る時刻を指定できます（初期値は9:00）。その時刻を過ぎてからオンになった日は、気づいた時点で送ります。Macの「メール」アプリに設定したアカウントから送ります。最初の1回だけ、macOSが「メール」の制御の許可を求めます。「テスト送信」で届くか確認してください。送信時刻にMacがスリープしている場合は、復帰後に送ります。

起動・常駐
見張りを続けるには常駐が必要です（初期値はオン）。「ログイン時に起動」をオンにすると、Macにログインしたときに自動で起動します（初期値はオフ）。「Dockとアプリケーションスイッチャーに表示しない」をオンにすると（初期値はオフ）、メイン・設定ウインドウがある間はDockと⌘Tabに表示し、すべて閉じると隠します。メニューバーのアイコン（表示しているとき）か、Finderでアプリを開き直すと表示できます。 ⌘Tabのアプリケーションスイッチャーでアプリを選ぶと、メインウインドウを表示します。最小化中なら元に戻します。ログイン時の自動起動では表示しません。メニューバーのアイコンは状態を表します：雲にチェック＝オフ、雲に「!」＝注意（以前のバージョンを削除がオンを含む）、塗りつぶした雲に「!」＝自動更新されるアプリあり、斜線の雲＝読み取れない。

設定の共有
設定の「設定の共有」タブで、知らせる内容・通知・メール送信（宛先と送信時刻）の設定を書き出し・読み込みできます（「書き出す…」「読み込む…」、CCAutoUpdateOff-Settings.plist）。読み込むと確認のうえ設定を置き換えます。「設定の同期」で iCloud Drive や Dropbox などのフォルダーを選ぶと、複数のMacで同じ設定を使えます（後から保存した内容が優先）。ログイン時の起動・常駐・メニューバーのアイコンはMacごとに設定します。

ショートカット
⌘,で設定、⌘Rで再読み込み、⌘0で「メインウインドウを開く」、⌘Wでウインドウを閉じる、⌘Qで終了、⌘?でこのヘルプを開きます。

権限
通知の許可と、メール送信を使う場合の「メール」の制御の許可だけを使います。管理者パスワード、アクセシビリティ、フルディスクアクセスは不要です。

困ったとき
「設定ファイルが見つかりません」は、Creative Cloudにサインインしていないか、まだ［アプリ］を開いていない場合です。
通知が出ないときは、システム設定の［通知］でCCAutoUpdateOffを許可してください。
メールが送れないときは、システム設定の［プライバシーとセキュリティ］→［オートメーション］でCCAutoUpdateOffの「メール」をオンにし、「メール」アプリで送信できるか確認してください。
組織の管理者が自動更新をロックしている場合は、管理者の設定が優先されます。

プライバシー・更新
このアプリ自身は外部と通信しません。メール送信をオンにした場合だけ、「メール」アプリが状態（アプリ名とオン／オフ、Macの名前）を宛先に送ります。保存するのは設定（UserDefaults）だけです。アプリメニューの「アップデートを確認…」は共通の更新機能ですが、現在のビルドは更新先・署名鍵・公証が未設定のため「更新配布の準備中」と表示し、通信しません。
サポート：同梱のREADME.md（アプリ内 Contents/Resources/README.md）。''',
'''CCAutoUpdateOff — Watch Creative Cloud auto-updates

How it works
Auto-update in Creative Cloud Preferences → Apps, and each app's switch, are stored in ~/Library/Application Support/Adobe/OOBE/com.adobe.accc.apps.<user ID>.prefs and written as soon as you flip them. This app only reads that file and never changes it. It re-reads when the file changes, every hour, and after the Mac wakes.

What the states mean
- Off: no automatic updates
- On: updates automatically
Apps without a value in the settings file are shown as On, as in Creative Cloud. Turning the global switch off clears every app's value, so turning it back on turns every app back on
If the global Auto-update is off, nothing updates, and the per-app Auto-update column shows “—”. If it is on and at least one app is on, the app reports it. If it is on but every app is off, a caution is shown because newly installed apps may update (no notification or mail).

Turning it off
Choose Open Creative Cloud and use the switches in Preferences → Apps. With the global switch off, the per-app switches cannot be changed; turn the global switch on first if you want to change them.

Notifications
Notifications & Mail → Notifications shows a macOS notification when auto-update turns on (on by default). It is not repeated while nothing changes, and is sent again when a new app appears. Clicking it opens Creative Cloud. macOS asks for permission the first time.

Remove previous versions
With “Also report apps with Remove previous versions on” (on by default), apps whose Advanced options → Remove previous versions (removeOlderVersions) is checked are reported too. Only apps whose auto-update is in effect count; otherwise the list shows “—” (Creative Cloud greys the option out). While the global switch is off, the app rows are dimmed.

Mail
Turn on Mail and enter an address to get one mail a day while auto-update is on (off by default). Send at sets the time (9:00 by default); if it turns on after that time, the mail goes out when it is noticed. It is sent from the account set up in the Mail app. macOS asks once for permission to control Mail. Use Send Test Mail to check. If the Mac is asleep at the send time, it goes out after waking.

Startup and background
The app must keep running to watch (on by default). Open at login starts it when you log in (off by default). Hide from Dock and App Switcher (off by default) the app appears in the Dock and ⌘Tab while main/settings windows exist, including minimized windows, and hides after all such windows close; show it from the menu bar icon (when shown) or by opening the app again in Finder. Selecting the app in the ⌘Tab application switcher shows its main window and restores it if minimized. Automatic login launch stays quiet. The menu bar icon shows the state: cloud with a check = off, cloud with ! = caution (including Remove previous versions), filled cloud with ! = apps update automatically, crossed-out cloud = cannot read.

Sharing settings
In the Sharing tab of Settings, Export… and Import… save and load what to report, notifications and mail (address and send time) as CCAutoUpdateOff-Settings.plist. Importing asks first, then replaces the settings. Settings Sync keeps them the same on several Macs through a folder such as iCloud Drive or Dropbox (the most recent save wins). Open at login, staying in the background and the menu bar icon are set on each Mac.

Shortcuts
⌘, settings, ⌘R reload, ⌘0 open the main window, ⌘W close the window, ⌘Q quit, ⌘? this help.

Permissions
Only notification permission and, for mail, permission to control Mail. No administrator password, Accessibility or Full Disk Access.

Troubleshooting
Preferences not found: you are not signed in to Creative Cloud, or Apps has never been opened.
No notifications: allow CCAutoUpdateOff in System Settings → Notifications.
Mail not sent: turn on Mail for CCAutoUpdateOff in System Settings → Privacy & Security → Automation, and check that Mail can send.
If your organization's admin has locked auto-update, the admin setting wins.

Privacy and updates
The app itself makes no network access. Only when Mail is on does the Mail app send the state (app names, on/off, the Mac's name) to your address. Only the settings (UserDefaults) are saved. Check for Updates… uses the shared updater, but this build has no update feed, signing key or notarization, so it reports that updates are not configured and makes no network access.
Support: see the bundled README.md (Contents/Resources/README.md inside the app).''',
'''CCAutoUpdateOff — 监视 Creative Cloud 自动更新

原理
Creative Cloud“偏好设置 → 应用”中的“自动更新”和各应用的开关保存在 ~/Library/Application Support/Adobe/OOBE/com.adobe.accc.apps.<用户 ID>.prefs 中，切换后会立即写入。本应用只读取该文件，不做更改。文件变化时、每小时以及 Mac 唤醒后都会重新读取。

状态说明
- 关闭：不自动更新
- 开启：自动更新
设置文件中没有值的应用在 Creative Cloud 中也显示为开启，因此显示为“开启”。关闭全部开关时 Creative Cloud 会清除各应用的值，重新打开后各应用都会恢复为开启
全部“自动更新”关闭时不会自动更新，列表中各应用的“自动更新”显示为“—”。全部开启且有任一应用开启时会提醒。全部开启但所有应用关闭时显示注意（不通知、不发邮件），因为新安装的应用可能会自动更新。

如何关闭
点击“打开 Creative Cloud”，在“偏好设置 → 应用”中切换开关。全部开关关闭时无法更改各应用的开关，如需更改请先打开全部开关。

通知
“通知与邮件 → 通知”会在自动更新开启时显示 macOS 通知（默认开启）。状态不变时不会重复；新增应用时会再次通知。点击通知会打开 Creative Cloud。首次会请求通知权限。

删除以前的版本
开启“同时提醒开启了删除以前的版本的应用”（默认开启）后，各应用“高级选项 → 删除以前的版本”（removeOlderVersions）开启的应用也会被提醒。仅针对自动更新生效的应用，否则列表显示“—”（Creative Cloud 中也无法操作）。全部开关关闭时，各应用行会变淡显示。

发送邮件
开启“发送邮件”并填写地址后，自动更新开启期间每天发送一封邮件（默认关闭）。可在“发送时间”中指定时间（默认 9:00）；若在该时间之后才开启，则在检测到时发送。使用“邮件”应用中设置的账户发送，首次会请求控制“邮件”的权限。请用“发送测试邮件”确认。发送时间时 Mac 处于睡眠状态，会在唤醒后发送。

启动与后台
持续监视需要应用保持运行（默认开启）。“登录时启动”会在登录时自动启动（默认关闭）。开启“不在程序坞和应用程序切换器中显示”（默认关闭）后，即使窗口打开也不在程序坞和 ⌘Tab 切换器中显示图标；可通过菜单栏图标（显示时）或在访达中再次打开应用来显示。 在 ⌘Tab 应用程序切换器中选择应用会显示主窗口，并恢复已最小化的主窗口。登录时自动启动仍不显示主窗口。菜单栏图标表示状态：云朵带勾＝关闭，云朵带“!”＝注意（含删除以前的版本），实心云朵带“!”＝有应用会自动更新，带斜线的云朵＝无法读取。

设置共享
在设置的“设置共享”标签中，可以导出和导入提醒内容、通知和发送邮件（收件人与发送时间）的设置（“导出…”“导入…”，CCAutoUpdateOff-Settings.plist）。导入时会先确认，再替换设置。在“设置同步”中选择 iCloud 云盘或 Dropbox 等文件夹，即可在多台 Mac 上使用相同的设置（以最后保存的为准）。登录时启动、保持运行和菜单栏图标在每台 Mac 上分别设置。

快捷键
⌘, 设置，⌘R 重新载入，⌘0 打开主窗口，⌘W 关闭窗口，⌘Q 退出，⌘? 打开本帮助。

权限
只使用通知权限，以及发送邮件时控制“邮件”的权限。不需要管理员密码、辅助功能或完全磁盘访问权限。

故障排除
“未找到偏好设置文件”表示未登录 Creative Cloud，或从未打开过“应用”。
没有通知时，请在系统设置的“通知”中允许 CCAutoUpdateOff。
无法发送邮件时，请在系统设置的“隐私与安全性 → 自动化”中为 CCAutoUpdateOff 打开“邮件”，并确认“邮件”应用可以发送。
如果组织管理员锁定了自动更新，管理员的设置优先。

隐私与更新
本应用自身不进行网络通信。仅在开启“发送邮件”时，由“邮件”应用把状态（应用名称、开关、Mac 名称）发送到您的地址。只保存设置（UserDefaults）。“检查更新…”使用通用更新功能，但当前版本未配置更新源、签名密钥和公证，因此显示尚未配置，不进行网络通信。
支持：请参阅随附的 README.md（应用内 Contents/Resources/README.md）。''',
'''CCAutoUpdateOff — Creative Cloud 자동 업데이트 감시

작동 방식
Creative Cloud 환경설정 → 앱의 자동 업데이트와 앱별 스위치는 ~/Library/Application Support/Adobe/OOBE/com.adobe.accc.apps.<사용자 ID>.prefs에 저장되며, 전환하면 바로 기록됩니다. 이 앱은 그 파일을 읽기만 하고 변경하지 않습니다. 파일이 바뀔 때, 1시간마다, Mac이 깨어난 후에 다시 읽습니다.

상태의 의미
- 끔: 자동 업데이트하지 않음
- 켬: 자동 업데이트함
설정 파일에 값이 없는 앱도 Creative Cloud에서는 켬으로 표시되므로 "켬"으로 표시합니다. 전체를 끄면 Creative Cloud가 앱별 값을 지우므로, 전체를 다시 켜면 각 앱도 켬으로 돌아갑니다
전체 자동 업데이트가 꺼져 있으면 업데이트되지 않으며, 목록의 앱별 자동 업데이트는 "—"로 표시합니다. 전체가 켜져 있고 켜진 앱이 하나라도 있으면 알립니다. 전체가 켜져 있지만 모든 앱이 꺼져 있으면, 새로 설치한 앱이 자동 업데이트될 수 있어 주의로 표시합니다(알림·메일 없음).

끄는 방법
Creative Cloud 열기로 실행하고 환경설정 → 앱에서 스위치를 변경하세요. 전체 스위치가 꺼져 있으면 앱별 스위치를 변경할 수 없으니 먼저 전체를 켜세요.

알림
알림 및 메일 → 알림에서 자동 업데이트가 켜지면 macOS 알림을 표시합니다(기본값 켬). 상태가 같으면 반복하지 않으며, 새 앱이 추가되면 다시 알립니다. 알림을 클릭하면 Creative Cloud를 엽니다. 처음에 알림 권한을 요청합니다.

이전 버전 제거
"이전 버전 제거"가 켜진 앱도 알림을 켜면(기본값 켬) 각 앱의 고급 옵션 → 이전 버전 제거(removeOlderVersions)가 켜진 앱도 알림과 메일 대상이 됩니다. 자동 업데이트가 적용되는 앱만 대상이며, 그 외에는 목록에 "—"로 표시합니다(Creative Cloud에서도 조작할 수 없음). 전체가 꺼져 있으면 앱 행을 흐리게 표시합니다.

메일 보내기
메일 보내기를 켜고 주소를 입력하면 자동 업데이트가 켜져 있는 동안 하루 한 번 메일로 알립니다(기본값 끔). 보낼 시각에서 시각을 지정할 수 있습니다(기본값 9:00). 그 시각 이후에 켜진 날은 감지한 시점에 보냅니다. Mail 앱에 설정된 계정으로 보내며, 처음 한 번 Mail 제어 권한을 요청합니다. 테스트 메일 보내기로 확인하세요. 보낼 시각에 Mac이 잠자기 중이면 깨어난 후 보냅니다.

시작 및 백그라운드
감시를 계속하려면 앱이 실행 중이어야 합니다(기본값 켬). 로그인 시 실행을 켜면 로그인할 때 자동으로 실행합니다(기본값 끔). Dock 및 앱 전환기에 표시 안 함을 켜면(기본값 끔) 메인·설정 윈도우가 있는 동안 Dock과 ⌘Tab에 표시하고 모두 닫으면 숨깁니다. 메뉴 막대 아이콘(표시 중일 때) 또는 Finder에서 앱을 다시 열어 표시할 수 있습니다. 메뉴 막대 아이콘은 상태를 나타냅니다: 체크 표시 구름=끔, ! 구름=주의(이전 버전 제거 포함), 채워진 ! 구름=자동 업데이트되는 앱 있음, 사선 구름=읽을 수 없음.

설정 공유
설정의 설정 공유 탭에서 알릴 내용, 알림, 메일 보내기(받는 사람과 보낼 시각) 설정을 내보내고 가져올 수 있습니다(내보내기…, 가져오기…, CCAutoUpdateOff-Settings.plist). 가져올 때는 확인한 뒤 설정을 바꿉니다. 설정 동기화에서 iCloud Drive나 Dropbox 같은 폴더를 선택하면 여러 Mac에서 같은 설정을 사용할 수 있습니다(나중에 저장한 내용이 우선). 로그인 시 실행, 백그라운드 유지, 메뉴 막대 아이콘은 Mac마다 설정합니다.

단축키
⌘, 설정, ⌘R 새로 고침, ⌘0 메인 윈도우 열기, ⌘W 윈도우 닫기, ⌘Q 종료, ⌘? 이 도움말.

권한
알림 권한과, 메일을 보낼 때 Mail 제어 권한만 사용합니다. 관리자 암호, 손쉬운 사용, 전체 디스크 접근 권한은 필요하지 않습니다.

문제 해결
설정 파일을 찾을 수 없음은 Creative Cloud에 로그인하지 않았거나 앱을 한 번도 열지 않은 경우입니다.
알림이 나오지 않으면 시스템 설정의 알림에서 CCAutoUpdateOff를 허용하세요.
메일이 보내지지 않으면 시스템 설정의 개인정보 보호 및 보안 → 자동화에서 CCAutoUpdateOff의 Mail을 켜고, Mail 앱에서 보낼 수 있는지 확인하세요.
조직 관리자가 자동 업데이트를 잠근 경우 관리자 설정이 우선합니다.

개인정보와 업데이트
이 앱 자체는 네트워크 통신을 하지 않습니다. 메일 보내기를 켠 경우에만 Mail 앱이 상태(앱 이름, 켬/끔, Mac 이름)를 주소로 보냅니다. 설정(UserDefaults)만 저장합니다. 업데이트 확인…은 공통 업데이트 기능이지만 현재 빌드는 업데이트 주소, 서명 키, 공증이 설정되지 않아 준비 중으로 표시하고 통신하지 않습니다.
지원: 함께 제공된 README.md(앱 내부 Contents/Resources/README.md)를 참조하세요.''',
]
for idx, lang in enumerate(LANGS):
    folder = root / 'Resources' / f'{lang}.lproj'; folder.mkdir(parents=True, exist_ok=True)
    values = {r[0]: r[idx + 1] for r in rows}; values['helpContent'] = helptexts[idx]
    (folder / 'Localizable.strings').write_text('\n'.join(json.dumps(k, ensure_ascii=False) + ' = ' + json.dumps(v, ensure_ascii=False) + ';' for k, v in values.items()) + '\n')
    (folder / 'Help.txt').write_text(helptexts[idx] + '\n')
    (folder / 'InfoPlist.strings').write_text('"NSAppleEventsUsageDescription" = ' + json.dumps(APPLE_EVENTS[idx], ensure_ascii=False) + ';\n')
info = {'CFBundleName': 'CCAutoUpdateOff', 'CFBundleDisplayName': 'CCAutoUpdateOff', 'CFBundleIdentifier': 'local.takano.CCAutoUpdateOff', 'CFBundleExecutable': 'CCAutoUpdateOff', 'CFBundlePackageType': 'APPL', 'CFBundleIconFile': 'CCAutoUpdateOff.icns', 'LSMinimumSystemVersion': '13.0', 'LSMultipleInstancesProhibited': True, 'NSHighResolutionCapable': True, 'CFBundleDevelopmentRegion': 'en', 'CFBundleLocalizations': LANGS, 'NSPrincipalClass': 'NSApplication', 'LSApplicationCategoryType': 'public.app-category.utilities', 'SWNoteArticleURL': 'https://note.com/dtp_tranist/n/n22872a3cbb8d', 'SWAppFamily': 'swwwitch', 'NSHumanReadableCopyright': '© 2026 swwwitch', 'CFBundleShortVersionString': '1.0.0', 'CFBundleVersion': '1', 'NSAppleEventsUsageDescription': 'Sends the auto-update status by mail through the Mail app.'}
# Version and build come from the existing Info.plist, so regeneration never reverts them.
plist_path = root / 'Info.plist'; current = plistlib.loads(plist_path.read_bytes()) if plist_path.exists() else {}
info.update({k: current[k] for k in ('CFBundleShortVersionString', 'CFBundleVersion') if k in current})
plist_path.write_bytes(plistlib.dumps(info))
