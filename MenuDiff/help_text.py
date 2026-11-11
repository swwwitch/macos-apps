# -*- coding: utf-8 -*-
# MenuDiff help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
MenuDiffは、Illustrator・InDesign・Photoshopの2つのバージョンのメニュー項目を読み、違いを一覧にします。アプリやメニューを書き換えることはありません。
- ［対象アプリ］の［Ai］［Ps］［Id］で、比べるアプリを選びます。
- ［新］と［旧］でバージョンを選びます。/Applications にあるものと、保存済みのものが並びます。間のボタンで入れ替えます。選択はアプリごとに覚えます。
- 右下の［比較］（⌘R）を押します。
## 起動していないバージョン
- 起動中のバージョンは、その場でメニューを読みます。
- 起動していないバージョンは、保存済みのデータを使います。無いときは、そのバージョンを起動してメニューを読み、読み終えたら終了させます。終了させるのはMenuDiffが起動したものだけです。待っている間に使い始めた（前面にある）ときは終了させません。
- ［読み直す］で、保存済みのデータを新しくします。
- 起動を4分待ってもメニューがそろわないときは止めます。ダイアログボックスで止まっていることがあります。
## 結果の見方
- 追加・削除：片方にだけある項目です。
- 名前の変更：中身が移った先のサブメニューと、同じメニューの中で削除と追加が1つずつあったものを組にします。推定です。
- 場所の変更：同じ名前の項目が、削除側・追加側に1つずつあったものを組にします。親メニューが変わっただけのものは省きます。
- ショートカット：両方にある項目で、キーが変わったものです。読んだときに選ばれていたキーボードショートカットのセットの値です。
- ［絞り込み］でメニュー名の一部から探します。［コピー］（⇧⌘C）で表示中の一覧をタブ区切りでコピーします。行を右クリックするとパスをコピーできます。
## そろえる項目・読まない項目
- Appleメニュー、フォント・最近使用したファイル・スクリプト・ライブラリ・プリセットなど、環境ごとに中身が異なるサブメニューは読みません。
- 開いているドキュメントの名前とメールアドレスは保存しません。
- アプリメニューの年（Photoshop 2026 など）、［編集］の「〜を取り消し」「〜をやり直し」、「〜 の新規ウィンドウ」、ワークスペースの「〜をリセット」は、決まった名前にそろえます。
- 表示／非表示のようにオン・オフで名前が入れ替わる項目は、読んだときの名前になります。
## 保存先
読んだメニューは「Ai31.0.0 ja_JP.tsv」（InDesignはId、PhotoshopはPs）のような名前で保存します。既定は ~/Library/Application Support/MenuDiff/Snapshots で、設定の［保存］で変えられます。保存済みのバージョンは、アプリを削除した後も比べられます。
## 設定・ホットキー
設定（⌘,）の「起動・常駐」で、ログイン時の起動、ウインドウを閉じた後の常駐、メニューバーの表示、アプリを呼び出すホットキーを選べます。初期値はどれもオフで、ホットキーは未設定です。ウインドウを閉じると終了します。常駐をオンにすると、Dockやメニューバーから再表示できます。
## 権限・データ
メニューを読むために、アクセシビリティの許可が要ります。システム設定の［プライバシーとセキュリティ］→［アクセシビリティ］でMenuDiffをオンにしてください。読み取るのはメニューの名前とショートカットだけで、操作はしません。データは保存先のフォルダーにだけ書き、外部へは送りません（更新確認を除く）。
## 困ったとき
- 「アクセシビリティが許可されていません」：設定の［アクセシビリティ］を開き、MenuDiffをオンにします。オンなのに読めないときは、一度オフにしてからオンにし、MenuDiffを再起動します。
- 「メニューがそろいませんでした」：そのバージョンを手で起動し、ダイアログボックスを閉じてから［読み直す］を押します。
- 言語が異なるバージョンどうしでは、ほとんどの項目が追加・削除として出ます。
- 終了：［MenuDiff］メニューの「MenuDiffを終了」または⌘Qです。
- 削除：アプリをゴミ箱に入れます。設定は ~/Library/Preferences/jp.dtp-transit.aimenudiff.plist、保存したデータは保存先のフォルダーにあります。
""",
 "en": """## Basics
MenuDiff reads the menus of two versions of Illustrator, InDesign or Photoshop and lists the differences. It never changes the apps or their menus.
- Choose the app with Ai, Ps or Id under Target App.
- Choose the versions in New and Old. Versions in /Applications and saved versions are listed. The button between them swaps them. The choice is remembered for each app.
- Click Compare (⌘R) at the bottom right.
## Versions that are not running
- A running version is read right away.
- For a version that is not running, saved data is used. If there is none, MenuDiff launches that version, reads its menus and quits it. Only versions that MenuDiff launched are quit, and not if you started using it (it is in front) while waiting.
- Reread updates the saved data.
- If the menus are not ready after 4 minutes, MenuDiff stops. A dialog may be waiting.
## Reading the results
- Added / Removed: items that exist on one side only.
- Renamed: a submenu paired with the one its items moved to, and one removed with one added item in the same menu. This is an estimate.
- Moved: items with the same name that appear once on each side. Items that moved only because their parent changed are hidden.
- Shortcuts: items on both sides whose key changed. The keys come from the shortcut set selected when the menus were read.
- Filter finds menu names. Copy (⇧⌘C) copies the list on screen as tab-separated text. Right-click a row to copy its path.
## Normalized and skipped items
- The Apple menu and submenus whose contents depend on the Mac (fonts, recent files, scripts, libraries, presets) are not read.
- Open document names and email addresses are not saved.
- The year in the app menu (Photoshop 2026), Undo and Redo labels in the Edit menu, “New Window for …” and the workspace Reset item get fixed names.
- Items whose names switch with their state (Show / Hide) keep the name shown when read.
## Save folder
Read menus are saved with names such as “Ai31.0.0 ja_JP.tsv” (Id for InDesign, Ps for Photoshop). The default is ~/Library/Application Support/MenuDiff/Snapshots; change it in the Saving tab of Settings. Saved versions can be compared even after the app is removed.
## Settings and shortcuts
In Settings (⌘,) > Startup & Background you can launch at login, keep running after the window closes, show the menu bar icon and set a shortcut to show the app. All are off by default and no shortcut is set. Closing the window quits; with Keep running on, reopen from the Dock or menu bar.
## Permissions and data
Reading menus requires Accessibility access. Turn on MenuDiff in System Settings > Privacy & Security > Accessibility. Only menu names and shortcuts are read; nothing is clicked. Data is written only to the save folder and nothing is sent anywhere (except update checks).
## Troubleshooting
- “Accessibility access is not allowed”: open Accessibility in Settings and turn on MenuDiff. If it is on but menus cannot be read, turn it off and on again, then restart MenuDiff.
- “Menus were not ready”: launch that version yourself, close any dialog, then click Reread.
- Versions in different languages show most items as added or removed.
- Quit: choose Quit MenuDiff in the MenuDiff menu, or press ⌘Q.
- Uninstall: move the app to the Trash. Settings are in ~/Library/Preferences/jp.dtp-transit.aimenudiff.plist; saved data is in the save folder.
""",
 "zh-Hans": """## 基本操作
MenuDiff 读取 Illustrator、InDesign 或 Photoshop 两个版本的菜单，并列出差异。不会更改应用或其菜单。
- 在“目标应用”中用 Ai、Ps、Id 选择应用。
- 在“新”和“旧”中选择版本。会列出 /Applications 中的版本和已存储的版本。中间的按钮可交换两者。每个应用分别记住选择。
- 点按右下角的“比较”（⌘R）。
## 未运行的版本
- 正在运行的版本会立即读取。
- 未运行的版本使用已存储的数据。若没有，MenuDiff 会启动该版本、读取菜单后将其退出。只退出由 MenuDiff 启动的版本；等待期间若你开始使用（位于前台）则不退出。
- “重新读取”会更新已存储的数据。
- 等待 4 分钟菜单仍未就绪时会停止。可能有对话框在等待。
## 查看结果
- 新增／删除：只存在于一侧的项目。
- 已重命名：将子项目移入的子菜单，以及同一菜单中各有一个删除和新增的项目配成一组。这是推测。
- 已移动：名称相同、两侧各出现一次的项目。仅因父菜单变化而移动的项目会省略。
- 快捷键：两侧都有且按键发生变化的项目。按键来自读取时所选的快捷键集。
- “筛选”可按菜单名称查找。“拷贝”（⇧⌘C）以制表符分隔拷贝显示的列表。右键点按行可拷贝路径。
## 统一和跳过的项目
- 不读取 Apple 菜单以及内容因环境而异的子菜单（字体、最近使用的文件、脚本、库、预设等）。
- 不存储打开的文稿名称和电子邮件地址。
- 应用菜单中的年份（Photoshop 2026 等）、“编辑”菜单中的撤销和重做、“…的新建窗口”以及工作区的“重置”统一为固定名称。
- 随状态切换名称的项目（显示／隐藏）保留读取时的名称。
## 存储位置
已读取的菜单以“Ai31.0.0 ja_JP.tsv”（InDesign 为 Id，Photoshop 为 Ps）之类的名称存储。默认位置为 ~/Library/Application Support/MenuDiff/Snapshots，可在设置的“存储”中更改。即使删除了应用，已存储的版本仍可比较。
## 设置与快捷键
在设置（⌘,）的“启动与后台”中，可以选择登录时启动、关闭窗口后继续运行、显示菜单栏图标以及显示应用的快捷键。默认均为关闭，未设置快捷键。关闭窗口即退出；开启“继续运行”后可从 Dock 或菜单栏再次打开。
## 权限与数据
读取菜单需要辅助功能权限。请在“系统设置”>“隐私与安全性”>“辅助功能”中开启 MenuDiff。只读取菜单名称和快捷键，不进行任何操作。数据只写入存储位置的文件夹，不发送到外部（检查更新除外）。
## 疑难解答
- “未允许辅助功能”：打开设置中的“辅助功能”并开启 MenuDiff。若已开启仍无法读取，请先关闭再开启，然后重新启动 MenuDiff。
- “菜单尚未就绪”：手动启动该版本，关闭对话框后点按“重新读取”。
- 语言不同的版本之间，大多数项目会显示为新增或删除。
- 退出：在 MenuDiff 菜单中选择“退出 MenuDiff”，或按 ⌘Q。
- 卸载：将应用移到废纸篓。设置位于 ~/Library/Preferences/jp.dtp-transit.aimenudiff.plist，已存储的数据位于存储位置的文件夹。
""",
 "ko": """## 기본 조작
MenuDiff는 Illustrator, InDesign, Photoshop의 두 버전 메뉴를 읽고 차이를 나열합니다. 앱이나 메뉴를 변경하지 않습니다.
- 대상 앱의 Ai, Ps, Id에서 비교할 앱을 선택합니다.
- 새 버전과 이전 버전을 선택합니다. /Applications에 있는 버전과 저장된 버전이 표시됩니다. 가운데 버튼으로 서로 바꿉니다. 선택은 앱마다 기억합니다.
- 오른쪽 아래의 비교(⌘R)를 클릭합니다.
## 실행 중이 아닌 버전
- 실행 중인 버전은 바로 읽습니다.
- 실행 중이 아닌 버전은 저장된 데이터를 사용합니다. 없으면 MenuDiff가 그 버전을 실행해 메뉴를 읽고 종료합니다. MenuDiff가 실행한 것만 종료하며, 기다리는 동안 사용을 시작한(앞에 있는) 경우에는 종료하지 않습니다.
- 다시 읽기로 저장된 데이터를 새로 고칩니다.
- 4분을 기다려도 메뉴가 준비되지 않으면 중단합니다. 대화상자가 기다리고 있을 수 있습니다.
## 결과 보기
- 추가·삭제: 한쪽에만 있는 항목입니다.
- 이름 변경: 하위 항목이 옮겨 간 하위 메뉴와, 같은 메뉴에서 삭제와 추가가 하나씩 있는 항목을 짝지은 것입니다. 추정입니다.
- 위치 변경: 이름이 같은 항목이 양쪽에 하나씩 있는 것을 짝지은 것입니다. 상위 메뉴가 바뀌어서만 이동한 항목은 생략합니다.
- 단축키: 양쪽에 있고 키가 바뀐 항목입니다. 메뉴를 읽을 때 선택되어 있던 단축키 세트의 값입니다.
- 필터로 메뉴 이름을 찾습니다. 복사(⇧⌘C)로 표시 중인 목록을 탭으로 구분해 복사합니다. 행을 오른쪽 클릭하면 경로를 복사할 수 있습니다.
## 통일하는 항목·읽지 않는 항목
- Apple 메뉴와 환경에 따라 내용이 다른 하위 메뉴(서체, 최근 사용한 파일, 스크립트, 라이브러리, 사전 설정 등)는 읽지 않습니다.
- 열린 도큐멘트 이름과 이메일 주소는 저장하지 않습니다.
- 앱 메뉴의 연도(Photoshop 2026 등), 편집 메뉴의 실행 취소·다시 실행, '…의 새 윈도우', 작업 영역의 재설정은 고정된 이름으로 통일합니다.
- 보기/숨기기처럼 상태에 따라 이름이 바뀌는 항목은 읽을 때의 이름이 됩니다.
## 저장 위치
읽은 메뉴는 'Ai31.0.0 ja_JP.tsv'(InDesign은 Id, Photoshop은 Ps) 같은 이름으로 저장합니다. 기본 위치는 ~/Library/Application Support/MenuDiff/Snapshots이며 설정의 저장에서 바꿀 수 있습니다. 앱을 삭제한 후에도 저장된 버전은 비교할 수 있습니다.
## 설정·단축키
설정(⌘,)의 시작 및 백그라운드에서 로그인 시 실행, 윈도우를 닫은 후 계속 실행, 메뉴 막대 아이콘 표시, 앱을 표시하는 단축키를 선택할 수 있습니다. 기본값은 모두 꺼져 있고 단축키는 지정되어 있지 않습니다. 윈도우를 닫으면 종료합니다. 계속 실행을 켜면 Dock이나 메뉴 막대에서 다시 열 수 있습니다.
## 권한·데이터
메뉴를 읽으려면 손쉬운 사용 권한이 필요합니다. 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 MenuDiff를 켜세요. 메뉴 이름과 단축키만 읽고 조작은 하지 않습니다. 데이터는 저장 위치의 폴더에만 쓰고 외부로 보내지 않습니다(업데이트 확인 제외).
## 문제 해결
- '손쉬운 사용이 허용되지 않았습니다': 설정의 손쉬운 사용을 열고 MenuDiff를 켭니다. 켜져 있는데도 읽을 수 없으면 한 번 껐다가 다시 켜고 MenuDiff를 다시 시작합니다.
- '메뉴가 준비되지 않았습니다': 그 버전을 직접 실행하고 대화상자를 닫은 후 다시 읽기를 클릭합니다.
- 언어가 다른 버전끼리는 대부분의 항목이 추가·삭제로 표시됩니다.
- 종료: MenuDiff 메뉴에서 MenuDiff 종료를 선택하거나 ⌘Q를 누릅니다.
- 삭제: 앱을 휴지통으로 옮깁니다. 설정은 ~/Library/Preferences/jp.dtp-transit.aimenudiff.plist에, 저장한 데이터는 저장 위치의 폴더에 있습니다.
""",
}
