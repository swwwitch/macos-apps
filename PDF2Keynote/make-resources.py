from pathlib import Path
import json
root = Path(__file__).parent
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''heading|PDFをKeynoteに変換|Convert PDF to Keynote|将 PDF 转换为 Keynote|PDF를 Keynote로 변환
subtitle|各ページをベクターのままスライドに配置します。|Each page becomes a slide, kept as vector artwork.|每一页作为矢量图放到一张幻灯片上。|각 페이지를 벡터 그대로 슬라이드에 배치합니다.
input|PDFファイル|PDF files|PDF 文件|PDF 파일
drop|ここにPDFをドロップ|Drop PDFs here|将 PDF 拖到此处|PDF를 여기에 드롭
inputHint|1つのPDFから1つのプレゼンテーションを作ります|One Keynote presentation per PDF|每个 PDF 生成一个演示文稿|PDF마다 프레젠테이션 1개를 만듭니다
chooseFiles|PDFを選択…|Choose PDFs…|选择 PDF…|PDF 선택…
remove|ファイルを外す|Remove file|移除文件|파일 제거
files|ファイル|files|个文件|개 파일
pages|ページ|pages|页|페이지
clear|すべて外す|Clear all|全部移除|모두 제거
options|変換オプション|Options|转换选项|변환 옵션
slideSize|スライドサイズ|Slide size|幻灯片尺寸|슬라이드 크기
matchPDF|PDFに合わせる（長辺1920）|Match PDF (long edge 1920)|与 PDF 一致（长边 1920）|PDF에 맞춤(긴 변 1920)
placement|配置|Placement|放置方式|배치
fit|ページ全体を収める|Fit entire page|完整显示页面|페이지 전체 맞춤
fill|スライドを埋める|Fill slide|填满幻灯片|슬라이드 채우기
fillHint|はみ出した部分はスライドの外に残ります。Keynoteで位置を調整できます。|Overflow stays outside the slide. Adjust it in Keynote.|超出部分保留在幻灯片外，可在 Keynote 中调整。|넘치는 부분은 슬라이드 밖에 남습니다. Keynote에서 조정할 수 있습니다.
box|使用する枠|Page box|页面框|페이지 상자
box.crop|トリミング（CropBox）|Crop box|裁剪框 (CropBox)|재단 상자(CropBox)
box.trim|仕上がり（TrimBox）|Trim box|成品框 (TrimBox)|마감 상자(TrimBox)
box.bleed|裁ち落とし（BleedBox）|Bleed box|出血框 (BleedBox)|도련 상자(BleedBox)
box.media|メディア（MediaBox）|Media box|媒体框 (MediaBox)|미디어 상자(MediaBox)
box.art|アート（ArtBox）|Art box|作品框 (ArtBox)|아트 상자(ArtBox)
pageRange|ページ範囲を指定|Page range|指定页面范围|페이지 범위 지정
from|開始ページ|First page|起始页|시작 페이지
to|終了ページ|Last page|结束页|끝 페이지
rangeHint|すべてのPDFに同じ範囲を使います。ページ数を超えた分は最終ページまでになります。|Applies to every PDF. Pages beyond the end are ignored.|应用于所有 PDF。超出的页码将被忽略。|모든 PDF에 적용됩니다. 마지막 페이지를 넘는 범위는 무시됩니다.
output|保存先|Save to|保存位置|저장 위치
sameFolder|元のPDFと同じフォルダ|Same folder as the PDF|与 PDF 相同的文件夹|PDF와 같은 폴더
desktop|デスクトップ|Desktop|桌面|데스크탑
specifiedFolder|指定したフォルダ|Chosen folder|指定文件夹|지정한 폴더
chooseOnConvert|変換時に保存先を選択|Choose a folder when converting|转换时选择保存位置|변환할 때 저장 위치 선택
selectFolder|保存先を選択…|Choose folder…|选择保存位置…|저장 위치 선택…
openAfter|変換後にKeynoteで開いたままにする|Keep open in Keynote after converting|转换后在 Keynote 中保持打开|변환 후 Keynote에서 열어 두기
preserveOriginal|元のPDFは変更しません。同名のファイルがあるときは番号を付けて保存します。|The original PDF is unchanged. Existing names get a number.|不修改原 PDF。同名文件会添加编号。|원본 PDF는 변경하지 않습니다. 같은 이름에는 번호를 붙입니다.
ready|PDFを追加して変換してください。|Add PDFs to begin.|添加 PDF 以开始转换。|PDF를 추가하여 변환하세요.
reveal|Finderで表示|Show in Finder|在 Finder 中显示|Finder에서 보기
cancel|キャンセル|Cancel|取消|취소
convert|変換|Convert|转换|변환
unsupported|PDF以外のファイルやフォルダは追加しませんでした。|Only PDF files were added.|仅添加了 PDF 文件。|PDF 파일만 추가되었습니다.
working|変換中…|Converting…|正在转换…|변환 중…
cancelling|中止しています…|Cancelling…|正在取消…|취소 중…
cancelled|中止しました（完成したファイルは残しています）|Cancelled (finished files kept)|已取消（保留已完成的文件）|취소됨(완료된 파일 유지)
success|変換が完了しました|Conversion complete|转换完成|변환 완료
failed|変換に失敗しました|Conversion failed|转换失败|변환 실패
partial|一部の変換に失敗しました|Some conversions failed|部分转换失败|일부 변환 실패
keynoteMissing|Keynoteが見つかりません。App StoreからKeynoteをインストールしてください。|Keynote is not installed. Install it from the App Store.|未找到 Keynote。请从 App Store 安装。|Keynote가 없습니다. App Store에서 설치하세요.
automationDenied|Keynoteの操作が許可されていません。システム設定の「オートメーション」でPDF2KeynoteのKeynoteをオンにしてください。|PDF2Keynote is not allowed to control Keynote. Turn on Keynote for PDF2Keynote in Automation settings.|PDF2Keynote 未被允许控制 Keynote。请在“自动化”设置中打开。|PDF2Keynote가 Keynote를 제어하도록 허용되지 않았습니다. 자동화 설정에서 켜세요.
locked|パスワードで保護されたPDFは変換できません。|Password-protected PDFs cannot be converted.|无法转换受密码保护的 PDF。|암호로 보호된 PDF는 변환할 수 없습니다.
unreadable|PDFを読み込めませんでした。|The PDF could not be read.|无法读取 PDF。|PDF를 읽을 수 없습니다.
emptyRange|指定したページ範囲にページがありません。|No pages in the chosen range.|所选范围内没有页面。|지정한 범위에 페이지가 없습니다.
writePage|ページを書き出せませんでした。|A page could not be written.|无法写出页面。|페이지를 쓸 수 없습니다.
timeout|Keynoteが応答しません。Keynoteでダイアログボックスが開いていないか確認してください。|Keynote did not respond. Check for an open dialog in Keynote.|Keynote 无响应。请检查 Keynote 中是否有打开的对话框。|Keynote가 응답하지 않습니다. Keynote에 열린 대화상자가 있는지 확인하세요.
keynoteError|Keynoteでエラーが発生しました：|Keynote reported an error: |Keynote 报告错误：|Keynote 오류:
quitBusy|変換中です。完了を待つか、キャンセルしてから終了してください。|Wait for the conversion, or cancel it before quitting.|请等待转换完成，或取消后再退出。|변환이 끝날 때까지 기다리거나 취소한 후 종료하세요.
ok|OK|OK|好|확인
resident|ウインドウを閉じても常駐|Keep running after closing|关闭窗口后继续运行|창을 닫아도 계속 실행
residentDetail|閉じた後もDockやメニューバーから再表示できます。オフにすると閉じたときに終了します。|Reopen from the Dock or menu bar. When off, closing the window quits.|可从 Dock 或菜单栏再次打开。关闭此项时，关闭窗口即退出。|Dock 또는 메뉴 막대에서 다시 열 수 있습니다. 끄면 창을 닫을 때 종료됩니다.
launchShortcut|アプリ起動のホットキー|App launch keyboard shortcut|启动应用快捷键|앱 실행 키보드 단축키
openShortcuts|ショートカットを開く|Open Shortcuts|打开快捷指令|단축어 열기
shortcutDetail|ショートカットAppで「アプリを開く」にPDF2Keynoteを指定し、キーを割り当ててください。未起動時も使えます。|In Shortcuts, create an Open App action for PDF2Keynote and assign a key. It works even when the app is not running.|在快捷指令中为 PDF2Keynote 创建“打开 App”并分配按键，应用未运行时也可使用。|단축어 앱에서 PDF2Keynote를 여는 동작을 만들고 키를 지정하세요. 앱이 실행 중이 아니어도 작동합니다.
permission|Keynoteの操作|Keynote control|控制 Keynote|Keynote 제어
permissionWhy|Keynoteに新しいプレゼンテーションを作らせるため、オートメーション（Apple Events）の許可が必要です。許可しないとスライドを作成できません。|Automation (Apple Events) permission lets PDF2Keynote create presentations in Keynote. Without it, no slides can be created.|需要自动化（Apple Events）权限才能在 Keynote 中创建演示文稿。未允许时无法创建幻灯片。|Keynote에서 프레젠테이션을 만들려면 자동화(Apple Events) 권한이 필요합니다. 허용하지 않으면 슬라이드를 만들 수 없습니다.
permAllowed|許可済み|Allowed|已允许|허용됨
permDenied|未許可|Not allowed|未允许|허용 안 됨
permUnknown|未確認（Keynoteの起動中に確認できます）|Unknown (checked while Keynote is running)|未确认（Keynote 运行时可确认）|확인 안 됨(Keynote 실행 중 확인 가능)
permAsk|許可を確認|Check permission|检查权限|권한 확인
permOpen|オートメーション設定を開く|Open Automation Settings|打开自动化设置|자동화 설정 열기
login|ログイン時に起動|Open at login|登录时启动|로그인 시 실행
loginOpen|ログイン項目を開く|Open Login Items|打开登录项|로그인 항목 열기
loginOn|Macへのログイン時に自動起動します。|Opens automatically when you log in.|登录时自动启动。|로그인할 때 자동으로 실행합니다.
loginApproval|システム設定のログイン項目で許可してください。|Approve it in Login Items in System Settings.|请在系统设置的登录项中允许。|시스템 설정의 로그인 항목에서 허용하세요.
loginMissing|アプリをアプリケーションフォルダに移動して再起動してください。|Move the app to Applications and relaunch it.|请将应用移到“应用程序”文件夹并重新启动。|앱을 응용 프로그램 폴더로 옮긴 후 다시 실행하세요.
loginOff|自動起動はオフです。|Not opening at login.|登录时不启动。|로그인 시 실행 안 함.
loginError|設定を変更できませんでした：|Could not change the setting: |无法更改设置：|설정을 변경할 수 없습니다:
openMainWindow|メインウインドウを開く|Open Main Window|打开主窗口|메인 윈도우 열기
settings|設定…|Settings…|设置…|설정…
settingsWindow|設定|Settings|设置|설정
help|PDF2Keynoteヘルプ|PDF2Keynote Help|PDF2Keynote 帮助|PDF2Keynote 도움말
helpMenu|ヘルプ|Help|帮助|도움말
quit|PDF2Keynoteを終了|Quit PDF2Keynote|退出 PDF2Keynote|PDF2Keynote 종료
hide|PDF2Keynoteを隠す|Hide PDF2Keynote|隐藏 PDF2Keynote|PDF2Keynote 가리기
services|サービス|Services|服务|서비스
hideOthers|ほかを隠す|Hide Others|隐藏其他|기타 가리기
showAll|すべてを表示|Show All|全部显示|모두 보기
about|PDF2Keynoteについて|About PDF2Keynote|关于 PDF2Keynote|PDF2Keynote에 관하여
aboutDetail|PDFの各ページをKeynoteのスライドに配置します。サポート：同梱のREADME.md|Places each PDF page on a Keynote slide. Support: bundled README.md|将 PDF 每页放到 Keynote 幻灯片上。支持：内置 README.md|PDF 각 페이지를 Keynote 슬라이드에 배치합니다. 지원: 포함된 README.md
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

automation = ['PDFの各ページをスライドとして配置するため、Keynoteに新しいプレゼンテーションを作成させます。',
              'PDF2Keynote asks Keynote to create a presentation and place each PDF page on a slide.',
              'PDF2Keynote 需要让 Keynote 创建演示文稿，并将 PDF 每页放到幻灯片上。',
              'PDF2Keynote는 Keynote에 프레젠테이션을 만들고 PDF 각 페이지를 슬라이드에 배치하도록 요청합니다.']

# Help text lives in help_text.py (markup rendered by Shared/AppStandards/HelpDocument.swift).
from help_text import HELP
helptexts = [HELP[l] for l in ['ja', 'en', 'zh-Hans', 'ko']]

for i, lang in enumerate(['ja', 'en', 'zh-Hans', 'ko']):
    p = root / 'Resources' / f'{lang}.lproj'
    p.mkdir(parents=True, exist_ok=True)
    (p / 'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0])} = {json.dumps(r[i + 1], ensure_ascii=False)};' for r in table) + '\n')
    (p / 'InfoPlist.strings').write_text(f'"NSAppleEventsUsageDescription" = {json.dumps(automation[i], ensure_ascii=False)};\n"CFBundleDisplayName" = "PDF2Keynote";\n')
    (p / 'Help.txt').write_text(helptexts[i])
print('resources:', len(table), 'keys x 4 languages')
