from pathlib import Path
import json, plistlib
root=Path(__file__).parent
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows='''heading|文書の形式を変換|Convert your documents|转换文档格式|문서 형식 변환
subtitle|ファイルを選んで、形式とオプションを指定。|Choose files, a format, and conversion options.|选择文件、格式和转换选项。|파일, 형식, 변환 옵션을 선택하세요.
input|入力ファイル|Input files|输入文件|입력 파일
drop|ここにファイルをドロップ|Drop files here|将文件拖到此处|파일을 여기에 드롭
inputHint|Markdown・Word・Excel・Illustrator・Photoshop・InDesign・PDF・画像・字幕（SRT）など|Markdown, Word, Excel, Illustrator, Photoshop, InDesign, PDF, images, subtitles (SRT) and more|Markdown、Word、Excel、Illustrator、Photoshop、InDesign、PDF、图像、字幕（SRT）等|Markdown, Word, Excel, Illustrator, Photoshop, InDesign, PDF, 이미지, 자막(SRT) 등
chooseFiles|ファイルを選択…|Choose files…|选择文件…|파일 선택…
remove|ファイルを外す|Remove file|移除文件|파일 제거
files|ファイル|files|个文件|개 파일
clear|すべて外す|Clear all|全部移除|모두 제거
format|変換形式|Output format|输出格式|출력 형식
options|変換オプション|Options|转换选项|변환 옵션
readAs|入力形式|Input format|输入格式|입력 형식
auto|自動|Automatic|自动|자동
standalone|完全な文書として出力|Standalone document|输出完整文档|완전한 문서로 출력
toc|目次を付ける|Table of contents|添加目录|목차 추가
numbers|見出しに番号を付ける|Number sections|章节编号|제목 번호 추가
wrap|テキストの折り返し|Text wrapping|文本换行|텍스트 줄 바꿈
preserve|元の改行を保持|Preserve wrapping|保留换行|기존 줄 바꿈 유지
none|折り返さない|No wrapping|不换行|줄 바꿈 없음
pdfEngine|PDFエンジン|PDF engine|PDF 引擎|PDF 엔진
pdfReady|PDFエンジンを利用できます。|PDF engine is available.|PDF 引擎可用。|PDF 엔진을 사용할 수 있습니다.
pdfMissing|選択したPDFエンジンがありません。設定から導入できます。|The selected PDF engine is missing. Install one in Settings.|找不到所选 PDF 引擎。请在设置中安装。|선택한 PDF 엔진이 없습니다. 설정에서 설치하세요.
output|保存先|Output folder|保存位置|저장 위치
chooseOnConvert|変換時に保存先を選択|Choose a folder when converting|转换时选择保存位置|변환할 때 저장 위치 선택
selectFolder|保存先を選択…|Choose output folder…|选择保存位置…|저장 위치 선택…
preserveOriginal|原本は変更しません。同名ファイルには連番を付けます。|Originals stay intact. Existing filenames get a number.|保留原文件。同名文件会添加编号。|원본은 변경하지 않습니다. 같은 이름에는 번호를 붙입니다.
ready|ファイルを追加して変換してください。|Add files to begin.|添加文件以开始转换。|파일을 추가하여 변환하세요.
reveal|Finderで表示|Show in Finder|在 Finder 中显示|Finder에서 보기
cancel|キャンセル|Cancel|取消|취소
convert|変換|Convert|转换|변환
selected|選択済み|Selected|已选择|선택됨
unsupported|対応しないファイルやフォルダは追加されませんでした。|Unsupported files or folders were not added.|未添加不支持的文件或文件夹。|지원하지 않는 파일 또는 폴더는 추가되지 않았습니다.
engineMissing|pandocが見つかりません。設定でインストールしてください。|Pandoc is missing. Install it in Settings.|找不到 pandoc。请在设置中安装。|pandoc이 없습니다. 설정에서 설치하세요.
working|変換中…|Converting…|正在转换…|변환 중…
cancelling|中止しています…|Cancelling…|正在取消…|취소 중…
cancelled|中止しました（完成済みの出力は保持）|Cancelled (completed outputs kept)|已取消（保留已完成的输出）|취소됨(완료된 출력 유지)
success|変換が完了しました|Conversion complete|转换完成|변환 완료
failed|変換に失敗しました|Conversion failed|转换失败|변환 실패
partial|一部の変換に失敗しました|Some conversions failed|部分转换失败|일부 변환 실패
resident|ウインドウを閉じても常駐|Keep running after closing|关闭窗口后继续运行|창을 닫아도 계속 실행
residentDetail|閉じた後もメニューバーやDockから再表示できます。|Reopen from the menu bar or Dock.|可从菜单栏或 Dock 再次打开。|메뉴 막대 또는 Dock에서 다시 열 수 있습니다.
launchShortcut|アプリ起動のホットキー|App launch keyboard shortcut|启动应用快捷键|앱 실행 키보드 단축키
openShortcuts|ショートカットを開く|Open Shortcuts|打开快捷指令|단축어 열기
shortcutDetail|「アプリを開く」でCarmaChameleonを指定し、キーを設定してください。未起動時も使えます。|Create an Open App shortcut for CarmaChameleon and assign a key. It also works when the app is not running.|创建打开 CarmaChameleon 的快捷指令并分配按键，应用未运行时也可使用。|CarmaChameleon를 여는 단축어를 만들고 키를 지정하세요. 앱이 실행 중이 아니어도 사용할 수 있습니다.
engine|pandoc|pandoc|pandoc|pandoc
bundled|pandocを同梱しています。|Pandoc is bundled.|已内置 pandoc。|pandoc이 포함되어 있습니다.
customPath|独自のpandocのパス（任意）|Custom pandoc path (optional)|自定义 pandoc 路径（可选）|사용자 pandoc 경로(선택)
browse|選択…|Browse…|选择…|선택…
useBundled|同梱版に戻す|Use bundled version|恢复内置版本|포함된 버전 사용
openMainWindow|メインウインドウを開く|Open Main Window|打开主窗口|메인 윈도우 열기
settings|設定…|Settings…|设置…|설정…
settingsWindow|設定|Settings|设置|설정
help|CarmaChameleonヘルプ|CarmaChameleon Help|CarmaChameleon 帮助|CarmaChameleon 도움말
helpMenu|ヘルプ|Help|帮助|도움말
services|サービス|Services|服务|서비스
hideApp|CarmaChameleonを隠す|Hide CarmaChameleon|隐藏 CarmaChameleon|CarmaChameleon 가리기
hideOthers|ほかを隠す|Hide Others|隐藏其他|기타 가리기
showAll|すべてを表示|Show All|全部显示|모두 보기
quit|CarmaChameleonを終了|Quit CarmaChameleon|退出 CarmaChameleon|CarmaChameleon 종료
quitBusy|変換が進行中です。完了を待つか、メイン画面でキャンセルしてから終了してください。|Wait for conversion, or cancel in the main window before quitting.|请等待转换完成，或在主窗口取消后退出。|변환을 기다리거나 메인 윈도우에서 취소한 후 종료하세요.
ok|OK|OK|好|확인
about|CarmaChameleonについて|About CarmaChameleon|关于 CarmaChameleon|CarmaChameleon에 관하여
aboutDetail|ローカル文書変換ツール。pandocの非公式GUI。サポート：同梱README.md。|Local document converter. Unofficial pandoc GUI. Support: bundled README.md.|本地文档转换工具。非官方 pandoc GUI。支持：内置 README.md。|로컬 문서 변환 도구. 비공식 pandoc GUI. 지원: 포함된 README.md.
fileMenu|ファイル|File|文件|파일
editMenu|編集|Edit|编辑|편집
close|ウインドウを閉じる|Close Window|关闭窗口|윈도우 닫기
undo|取り消す|Undo|撤销|실행 취소
redo|やり直す|Redo|重做|실행 복귀
windowMenu|ウインドウ|Window|窗口|윈도우
minimize|しまう|Minimize|最小化|최소화
zoom|拡大／縮小|Zoom|缩放|확대/축소
bringAllToFront|すべてを手前に移動|Bring All to Front|前置全部窗口|모두 앞으로 가져오기
cut|カット|Cut|剪切|오려두기
copy|コピー|Copy|拷贝|복사하기
paste|ペースト|Paste|粘贴|붙여넣기
selectAll|すべてを選択|Select All|全选|모두 선택
login|ログイン時に起動|Launch at login|登录时启动|로그인 시 실행
loginOpen|ログイン項目を開く|Open Login Items|打开登录项|로그인 항목 열기
loginOn|ログイン時に自動起動します。|Launches automatically at login.|登录时自动启动。|로그인 시 자동 실행합니다.
loginApproval|システム設定で許可してください。|Approve in System Settings.|请在系统设置中允许。|시스템 설정에서 허용하세요.
loginMissing|アプリケーションフォルダから起動してください。|Launch from Applications.|请从应用程序文件夹启动。|응용 프로그램 폴더에서 실행하세요.
loginOff|自動起動はオフです。|Launch at login is off.|登录启动已关闭。|자동 실행이 꺼져 있습니다.
loginError|変更できませんでした：|Could not change setting: |无法更改设置：|설정 변경 실패: 
notInstalled|未インストール|Not installed|未安装|설치되지 않음
notChecked|最新版は未確認|Latest version not checked|尚未检查最新版本|최신 버전 미확인
updateAvailable|更新があります|Update available|有可用更新|업데이트 있음
upToDate|更新は不要です|Up to date|无需更新|최신 버전
engineInvalid|pandocを実行できません。パスを確認してください。|Could not run pandoc. Check its path.|无法运行 pandoc。请检查路径。|pandoc을 실행할 수 없습니다. 경로를 확인하세요.
checking|最新版を確認中…|Checking latest version…|正在检查最新版本…|최신 버전 확인 중…
checked|公式リリースを確認しました。|Checked the official release.|已检查官方发布版本。|공식 릴리스를 확인했습니다.
checkFailed|更新を確認できませんでした：|Could not check updates: |无法检查更新：|업데이트 확인 실패: 
networkError|通信に失敗しました。時間をおいて再試行してください。|Network request failed. Try again later.|网络请求失败，请稍后重试。|네트워크 요청 실패. 나중에 다시 시도하세요.
noVerifiedAsset|検証可能な公式配布ファイルが見つかりません。|No verifiable official download is available.|找不到可验证的官方下载。|검증 가능한 공식 다운로드가 없습니다.
installing|pandocをインストール中…|Installing pandoc…|正在安装 pandoc…|pandoc 설치 중…
hashMismatch|配布ファイルの検証に失敗しました。|Download integrity check failed.|下载文件完整性验证失败。|다운로드 무결성 검사 실패.
extractFailed|展開に失敗しました。|Could not extract download.|无法解压下载文件。|다운로드 압축 해제 실패.
installed|インストール完了。新しいpandocを使用します。|Installed. The new pandoc is now selected.|安装完成。将使用新版 pandoc。|설치 완료. 새 pandoc을 사용합니다.
installFailed|インストールできませんでした：|Could not install: |无法安装：|설치 실패: 
latest|最新バージョン：|Latest version: |最新版本：|최신 버전: 
refresh|状態を再確認|Refresh status|刷新状态|상태 새로 고침
checkLatest|最新版を確認|Check latest version|检查最新版本|최신 버전 확인
install|インストール|Install|安装|설치
installUpdate|最新版をインストール|Install latest version|安装最新版本|최신 버전 설치
installDetail|公式GitHubから取得し、SHA-256を検証してユーザー領域に保存します。管理者権限は不要です。|Downloads from official GitHub, verifies SHA-256, and installs for this user without administrator privileges.|从官方 GitHub 下载并验证 SHA-256，安装到用户目录，无需管理员权限。|공식 GitHub에서 다운로드하고 SHA-256을 확인한 후 사용자 영역에 설치합니다. 관리자 권한은 필요하지 않습니다.
waitInstall|処理が完了してから終了してください。|Wait for this operation to finish before quitting.|请等待操作完成后退出。|작업 완료 후 종료하세요.'''
rows += """
pdfEngineGroup|PDFエンジン（Typst）|PDF engine (Typst)|PDF 引擎（Typst）|PDF 엔진(Typst)
pdfEngineInvalid|Typstを実行できません。再インストールしてください。|Could not run Typst. Reinstall it.|无法运行 Typst。请重新安装。|Typst를 실행할 수 없습니다. 다시 설치하세요.
pdfInstalling|PDFエンジンをインストール中…|Installing PDF engine…|正在安装 PDF 引擎…|PDF 엔진 설치 중…
pdfInstalled|Typstをインストールしました。PDF変換に使用できます。|Typst installed. Ready for PDF conversion.|Typst 已安装，可用于 PDF 转换。|Typst가 설치되었습니다. PDF 변환에 사용할 수 있습니다.
pdfInstallDetail|「最新版を確認」→「インストール」で導入できます。公式Typstを取得し、SHA-256検証後にユーザー領域へ保存します。管理者権限は不要です。導入後はPDFエンジンにTypstを選択します。|Check latest version, then Install. Downloads official Typst, verifies SHA-256, and installs for this user without administrator privileges. Typst is selected after installation.|先检查最新版本再安装。从官方源下载 Typst，验证 SHA-256 后安装到用户目录，无需管理员权限。安装后选择 Typst。|최신 버전 확인 후 설치하세요. 공식 Typst의 SHA-256을 검증한 후 관리자 권한 없이 사용자 영역에 설치합니다. 설치 후 Typst가 선택됩니다.
texAlternative|既存のTeX環境も利用できます。MacTeXの導入は公式インストーラで行ってください。導入後は状態を再確認します。|Existing TeX engines also work. Install MacTeX using its official installer, then refresh status.|也可使用已有 TeX 环境。请通过官方安装程序安装 MacTeX，然后刷新状态。|기존 TeX 엔진도 사용할 수 있습니다. 공식 설치 프로그램으로 MacTeX를 설치한 후 상태를 새로 고침하세요.
detected|検出済み|Detected|已检测到|감지됨
openMacTeX|MacTeXの公式ダウンロードを開く|Open official MacTeX download|打开 MacTeX 官方下载|MacTeX 공식 다운로드 열기
pdfSetup|PDFエンジンを設定…|Set up PDF engine…|设置 PDF 引擎…|PDF 엔진 설정…"""
rows += """
idmlLimit|IDMLはテキスト中心の変換です。ストーリーの収録順で読み込み、ページ配置・画像・組版は再現しません。|IDML import focuses on text in packaged story order. Page layout, images and typesetting are not reproduced.|IDML 按故事收录顺序提取文本，不重现页面布局、图像和排版。|IDML은 수록된 스토리 순서로 텍스트를 가져옵니다. 페이지 레이아웃, 이미지 및 조판은 재현하지 않습니다.
idmlInvalid|IDMLの構造を読み取れません。InDesignからIDMLを書き出し直してください。|Could not read the IDML structure. Export it again from InDesign.|无法读取 IDML 结构。请从 InDesign 重新导出。|IDML 구조를 읽을 수 없습니다. InDesign에서 다시 내보내세요.
idmlTooLarge|IDMLのテキストデータが上限（20MB）を超えています。文書を分割してください。|IDML text data exceeds 20 MB. Split the document.|IDML 文本超过 20MB，请拆分文档。|IDML 텍스트가 20MB를 초과합니다. 문서를 나누세요.
idmlNoText|IDMLに変換できる本文が見つかりません。|No convertible text was found in IDML.|IDML 中没有可转换的文本。|IDML에서 변환할 텍스트를 찾을 수 없습니다."""
rows += """
pdfInputHint|PDFは本文を抽出します。文字がないページは日本語・英語のOCRを使用します。段組み・画像・組版は再現せず、OCRは誤認識する場合があります。|Extracts PDF text; pages without text use Japanese/English OCR. Layout and images are not reproduced. OCR may make mistakes.|提取 PDF 文本，无文本页使用日语/英语 OCR。不重现布局和图像，OCR 可能出错。|PDF 본문을 추출하며 텍스트가 없는 페이지는 일본어/영어 OCR을 사용합니다. 레이아웃과 이미지는 재현하지 않으며 OCR 오류가 있을 수 있습니다.
pdfInputInvalid|PDFを読み込めません。|Could not read PDF.|无法读取 PDF。|PDF를 읽을 수 없습니다.
pdfInputLocked|保護されたPDFです。パスワード解除・コピー許可済みのPDFを指定してください。|This PDF is protected. Choose an unlocked PDF with copying allowed.|PDF 受保护。请选择已解锁且允许复制的 PDF。|보호된 PDF입니다. 잠금 해제 및 복사 허용된 PDF를 선택하세요.
pdfInputLimit|PDFは500ページ・抽出テキスト20MBまでです。|PDF is limited to 500 pages and 20 MB of extracted text.|PDF 上限为 500 页和 20MB 提取文本。|PDF는 500페이지, 추출 텍스트 20MB까지 지원합니다.
pdfInputNoText|次のページから文字を読み取れませんでした。空白ページを除くか、原本を確認してください。|No text could be read from this page. Remove blank pages or check the original.|无法从此页读取文字。请删除空白页或检查原件。|해당 페이지에서 텍스트를 읽을 수 없습니다. 빈 페이지를 제거하거나 원본을 확인하세요.
idmlExportFailed|IDMLを書き出せませんでした。保存先を確認してください。|Could not write IDML. Check the output folder.|无法写入 IDML。请检查保存位置。|IDML을 저장할 수 없습니다. 저장 위치를 확인하세요.
idmlOutputHint|IDMLはA4・本文のみの編集可能なテキストとして出力します。元の書式・表構造・画像・ページ配置は再現しません。|Exports editable text on A4 pages. Original formatting, table structure, images and page layout are not reproduced.|导出为 A4 页面上的可编辑文本，不重现原格式、表结构、图像和页面布局。|A4 페이지의 편집 가능한 텍스트로 내보냅니다. 원래 서식, 표 구조, 이미지 및 페이지 배치는 재현하지 않습니다.
sameFolder|元の文書と同じ|Same as source document|与原文档相同|원본 문서와 동일
specifiedFolder|指定|Choose a folder|指定|지정
openAfterConversion|変換後にファイルを開く|Open files after conversion|转换后打开文件|변환 후 파일 열기"""
rows += """
htmlFormatting|HTMLの整形|HTML formatting|HTML 格式|HTML 서식
htmlStandard|標準|Standard|标准|기본
htmlFormattingHint|minify：タグの余分な空白・改行を削減。beautify：ブロックタグを改行・字下げ。本文・コード・CSS・JavaScriptは保持します。|minify reduces tag spacing and block separators. beautify indents block tags. Text, code, CSS and JavaScript are preserved.|minify 减少标签空白和块间换行；beautify 缩进块标签。保留文本、代码、CSS 和 JavaScript。|minify는 태그 공백을 줄이고 beautify는 블록 태그를 들여씁니다. 본문, 코드, CSS, JavaScript를 보존합니다."""
rows += """
matchPDF|PDFに合わせる（長辺1920）|Match PDF (long edge 1920)|与 PDF 一致（长边 1920）|PDF에 맞춤(긴 변 1920)
slideSize|スライドサイズ|Slide size|幻灯片尺寸|슬라이드 크기
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
keynoteHint|PDFの各ページをベクターのまま1枚ずつスライドに配置します（Keynoteが必要）。PDF以外の文書は選択中のPDFエンジンで一度PDFにしてから変換します。「変換後にファイルを開く」がオンならKeynoteで開いたままにします。|Each PDF page is placed on its own slide as vector artwork (requires Keynote). Other documents are first typeset to PDF with the selected PDF engine. With Open files after conversion on, the presentation stays open in Keynote.|PDF 每页以矢量图放到单独的幻灯片上（需要 Keynote）。其他文档先用所选 PDF 引擎生成 PDF。开启“转换后打开文件”时在 Keynote 中保持打开。|PDF 각 페이지를 벡터 그대로 슬라이드에 배치합니다(Keynote 필요). 다른 문서는 선택한 PDF 엔진으로 먼저 PDF로 만듭니다. "변환 후 파일 열기"가 켜져 있으면 Keynote에서 열어 둡니다.
keynoteNeedsPDF|PDF以外の文書をKeynoteにするにはPDFエンジンが必要です。設定から導入できます。|A PDF engine is needed to turn non-PDF documents into Keynote. Install one in Settings.|将非 PDF 文档转为 Keynote 需要 PDF 引擎。请在设置中安装。|PDF가 아닌 문서를 Keynote로 만들려면 PDF 엔진이 필요합니다. 설정에서 설치하세요.
keynoteMissing|Keynoteが見つかりません。App StoreからKeynoteをインストールしてください。|Keynote is not installed. Install it from the App Store.|未找到 Keynote。请从 App Store 安装。|Keynote가 없습니다. App Store에서 설치하세요.
automationDenied|Keynoteの操作が許可されていません。システム設定の「オートメーション」でCarmaChameleonのKeynoteをオンにしてください。|CarmaChameleon is not allowed to control Keynote. Turn on Keynote for CarmaChameleon in Automation settings.|CarmaChameleon 未被允许控制 Keynote。请在“自动化”设置中打开。|CarmaChameleon가 Keynote를 제어하도록 허용되지 않았습니다. 자동화 설정에서 켜세요.
locked|パスワードで保護されたPDFは変換できません。|Password-protected PDFs cannot be converted.|无法转换受密码保护的 PDF。|암호로 보호된 PDF는 변환할 수 없습니다.
unreadable|PDFを読み込めませんでした。|The PDF could not be read.|无法读取 PDF。|PDF를 읽을 수 없습니다.
emptyRange|指定したページ範囲にページがありません。|No pages in the chosen range.|所选范围内没有页面。|지정한 범위에 페이지가 없습니다.
writePage|ページを書き出せませんでした。|A page could not be written.|无法写出页面。|페이지를 쓸 수 없습니다.
timeout|Keynoteが応答しません。Keynoteでダイアログボックスが開いていないか確認してください。|Keynote did not respond. Check for an open dialog in Keynote.|Keynote 无响应。请检查 Keynote 中是否有打开的对话框。|Keynote가 응답하지 않습니다. Keynote에 열린 대화상자가 있는지 확인하세요.
keynoteError|Keynoteでエラーが発生しました：|Keynote reported an error: |Keynote 报告错误：|Keynote 오류: 
permission|Keynoteの操作|Keynote control|控制 Keynote|Keynote 제어
permissionWhy|Keynote形式で書き出すとき、Keynoteに新しいプレゼンテーションを作らせるため、オートメーション（Apple Events）の許可が必要です。ほかの形式には不要です。|Exporting to Keynote needs Automation (Apple Events) permission so CarmaChameleon can create the presentation in Keynote. Other formats do not need it.|导出为 Keynote 时需要自动化（Apple Events）权限，以便在 Keynote 中创建演示文稿。其他格式不需要。|Keynote로 내보낼 때 Keynote에서 프레젠테이션을 만들기 위해 자동화(Apple Events) 권한이 필요합니다. 다른 형식에는 필요하지 않습니다.
permAllowed|許可済み|Allowed|已允许|허용됨
permDenied|未許可|Not allowed|未允许|허용 안 됨
permUnknown|未確認（Keynoteの起動中に確認できます）|Unknown (checked while Keynote is running)|未确认（Keynote 运行时可确认）|확인 안 됨(Keynote 실행 중 확인 가능)
permAsk|許可を確認|Check permission|检查权限|권한 확인
permOpen|オートメーション設定を開く|Open Automation Settings|打开自动化设置|자동화 설정 열기"""
rows += """
keepStructure|構造を保持|Keep structure|保留结构|구조 유지
keepStructureHint|見出し・箇条書き・リンク・表などの構造を、記号や字下げで読みやすく残します（Markdown以外はいったんMarkdownにしてから変換）。|Keeps headings, lists, links and tables readable with marks and indents (non-Markdown input is converted to Markdown first).|用符号和缩进保留标题、列表、链接和表格等结构（非 Markdown 输入会先转换为 Markdown）。|제목, 목록, 링크, 표 등의 구조를 기호와 들여쓰기로 읽기 쉽게 유지합니다(Markdown이 아닌 입력은 먼저 Markdown으로 변환).
mtLinks|リンク|Links|链接|링크
mtLinkText|テキストのみ|Text only|仅文本|텍스트만
mtLinkAngle|テキスト <URL>|Text <URL>|文本 <URL>|텍스트 <URL>
mtLinkParen|テキスト (URL)|Text (URL)|文本 (URL)|텍스트 (URL)
mtLinkBelow|段落・リストのリンクを下にまとめる|Collect links below paragraphs and list items|将段落和列表中的链接汇总到下方|문단·목록의 링크를 아래에 모으기
mtListMarker|行頭記号|Bullet|项目符号|글머리 기호
mtNumbers|番号リスト|Numbered lists|编号列表|번호 목록
mtNumKeep|元の番号を残す|Keep numbers|保留原编号|원래 번호 유지
mtNumRenumber|連番を振り直す|Renumber|重新编号|번호 다시 매기기
mtNumMarker|記号にする|Use the bullet|改为符号|기호로 바꾸기
mtZenkakuIndent|ネストのインデントを全角スペースに|Indent nested items with full-width spaces|用全角空格缩进嵌套项|중첩 들여쓰기를 전각 공백으로
mtHeadings|見出しの記号|Heading marks|标题符号|제목 기호
mtBold|太字|Bold|粗体|굵게
mtBoldNone|記号を削除|Remove marks|删除符号|기호 삭제
mtBoldBracket|【太字】で囲む|Wrap in 【】|用【】括起|【】로 감싸기
mtTables|表|Tables|表格|표
mtTableTab|タブ区切り|Tab-separated|制表符分隔|탭 구분
mtTableAscii|罫線付き|With borders|带边框|테두리 포함
mtImages|画像|Images|图像|이미지
mtImageText|代替テキストを残す|Keep alt text|保留替代文本|대체 텍스트 유지
mtImageIgnore|削除|Remove|删除|삭제
mtBlockGap|ブロック間|Between blocks|块之间|블록 사이
mtGap0|空行なし|No blank line|无空行|빈 줄 없음
mtGap1|空行1行|1 blank line|1 个空行|빈 줄 1개
mtGap2|空行2行|2 blank lines|2 个空行|빈 줄 2개
mtCollapseBlank|空行が続く場合は1つに|Collapse repeated blank lines|合并连续空行|연속 빈 줄을 하나로
mtTrimLeading|行頭のスペースを削除|Remove leading spaces|删除行首空格|줄 앞 공백 삭제
mtStripHTML|HTMLタグを処理|Process HTML tags|处理 HTML 标签|HTML 태그 처리"""
rows += """
xlsxInvalid|Excelファイルを読み込めませんでした。.xlsx 形式か確認してください（旧形式の .xls には対応しません）。|The Excel file could not be read. Make sure it is an .xlsx file (the older .xls format is not supported).|无法读取 Excel 文件。请确认是 .xlsx 格式（不支持旧的 .xls 格式）。|Excel 파일을 읽을 수 없습니다. .xlsx 형식인지 확인하세요(이전 .xls 형식은 지원하지 않음).
xlsxTooLarge|Excelファイルが大きすぎます（読み込むXMLは合計20MBまで）。|The Excel file is too large (up to 20 MB of XML).|Excel 文件过大（XML 合计上限 20MB）。|Excel 파일이 너무 큽니다(XML 합계 20MB까지).
xlsxEmpty|Excelファイルに読み込めるシートがありません。|The Excel file has no sheets with data.|Excel 文件中没有包含数据的工作表。|Excel 파일에 데이터가 있는 시트가 없습니다."""
rows += """
formatsTitle|変換形式の表示と順番|Output formats shown and their order|显示的输出格式及顺序|표시할 출력 형식과 순서
formatsHint|チェックした形式だけをメインウインドウの「変換形式」に表示します。ドラッグまたは↑↓で順番を変えられます。少なくとも1つは表示されます。|Only checked formats appear in the main window. Drag or use ↑↓ to change the order. At least one stays visible.|主窗口只显示勾选的格式。拖动或使用 ↑↓ 更改顺序。至少保留一个。|선택한 형식만 메인 윈도우에 표시됩니다. 드래그하거나 ↑↓로 순서를 바꿀 수 있습니다. 최소 1개는 표시됩니다.
moveUp|上へ移動|Move up|上移|위로 이동
moveDown|下へ移動|Move down|下移|아래로 이동
resetFormats|初期状態に戻す|Restore defaults|恢复默认|기본값으로 복원
enginesTab|エンジン|Engines|引擎|엔진"""
rows += """
aiInvalid|Illustratorファイルを読み込めませんでした。|The Illustrator file could not be read.|无法读取 Illustrator 文件。|Illustrator 파일을 읽을 수 없습니다.
aiWriteFailed|PDFを書き出せませんでした。|The PDF could not be written.|无法写出 PDF。|PDF를 쓸 수 없습니다.
aiWithoutPDF|「PDF互換ファイルを作成」をオフにして保存された .ai です。アートワークの代わりにAdobeの案内ページを変換しました。Illustratorで「PDF互換ファイルを作成」をオンにして保存し直してください。|This .ai was saved without "Create PDF Compatible File", so Adobe's notice page was converted instead of the artwork. Re-save it in Illustrator with "Create PDF Compatible File" turned on.|此 .ai 保存时未勾选“创建 PDF 兼容文件”，因此转换的是 Adobe 的提示页而非图稿。请在 Illustrator 中勾选“创建 PDF 兼容文件”后重新保存。|이 .ai는 "PDF 호환 파일 만들기"를 끄고 저장되어 아트워크 대신 Adobe 안내 페이지가 변환되었습니다. Illustrator에서 "PDF 호환 파일 만들기"를 켜고 다시 저장하세요."""
rows += """
aiTitle|Illustrator（.ai）の変換|Illustrator (.ai) conversion|Illustrator（.ai）转换|Illustrator(.ai) 변환
aiMethod|変換方法|Method|转换方法|변환 방법
aiSimple|簡易（Illustrator不要）|Simple (no Illustrator)|简易（无需 Illustrator）|간이(Illustrator 불필요)
aiIllustrator|Illustratorで書き出す（正式）|Export with Illustrator (full)|用 Illustrator 导出（正式）|Illustrator로 내보내기(정식)
aiSimpleHint|.ai に入っているPDF用の内容を使います。「PDF互換ファイルを作成」をオフで保存した .ai は正しく変換できません。|Uses the PDF content stored in the .ai. Files saved without "Create PDF Compatible File" cannot be converted correctly.|使用 .ai 中保存的 PDF 内容。未勾选“创建 PDF 兼容文件”保存的 .ai 无法正确转换。|.ai에 저장된 PDF용 내용을 사용합니다. "PDF 호환 파일 만들기"를 끄고 저장한 .ai는 올바르게 변환되지 않습니다.
aiIllustratorHint|Illustratorでファイルを開いて書き出します（PDFは選んだPDFプリセット、画像はアートボードごと）。変換中はIllustratorが起動します。Illustratorで開いているファイルは、開いたまま書き出します。|Illustrator opens the file and exports it (PDF with the chosen preset, images per artboard). Illustrator runs during conversion. Files already open in Illustrator are exported as they are and stay open.|由 Illustrator 打开文件并导出（PDF 使用所选预设，图像按画板）。转换期间会启动 Illustrator。已在 Illustrator 中打开的文件会直接导出并保持打开。|Illustrator가 파일을 열어 내보냅니다(PDF는 선택한 사전 설정, 이미지는 대지별). 변환 중 Illustrator가 실행됩니다. Illustrator에서 열려 있는 파일은 연 상태 그대로 내보냅니다.
aiPreset|PDFプリセット|PDF preset|PDF 预设|PDF 사전 설정
aiPresetDefault|Illustratorの初期設定|Illustrator default|Illustrator 默认|Illustrator 기본값
aiApp|使用するIllustrator|Illustrator to use|使用的 Illustrator|사용할 Illustrator
aiAppNewest|最新版|Newest|最新版本|최신 버전
aiLoadPresets|IllustratorからPDFプリセットを読み込む|Load PDF presets from Illustrator|从 Illustrator 读取 PDF 预设|Illustrator에서 PDF 사전 설정 불러오기
aiLoadPresetsHint|Illustratorを起動して、使えるPDFプリセットの一覧を取得します。|Launches Illustrator and reads the available PDF presets.|启动 Illustrator 并读取可用的 PDF 预设。|Illustrator를 실행하여 사용할 수 있는 PDF 사전 설정을 가져옵니다.
aiLoadingPresets|Illustratorから読み込んでいます…|Reading from Illustrator…|正在从 Illustrator 读取…|Illustrator에서 불러오는 중…
aiPresetsLoaded|%d個のPDFプリセットを読み込みました。|Loaded %d PDF presets.|已读取 %d 个 PDF 预设。|PDF 사전 설정 %d개를 불러왔습니다.
illustratorMissing|Illustratorが見つかりません。「簡易」で変換するか、Illustratorをインストールしてください。|Illustrator is not installed. Use Simple, or install Illustrator.|未找到 Illustrator。请使用“简易”方式或安装 Illustrator。|Illustrator가 없습니다. 간이 방식을 사용하거나 Illustrator를 설치하세요.
illustratorScriptMissing|Illustrator用のスクリプトが見つかりません。アプリを入れ直してください。|The Illustrator script is missing. Reinstall the app.|找不到 Illustrator 脚本。请重新安装应用。|Illustrator 스크립트가 없습니다. 앱을 다시 설치하세요.
illustratorDenied|Illustratorの操作が許可されていません。システム設定の「オートメーション」でCarmaChameleonのAdobe Illustratorをオンにしてください。|CarmaChameleon is not allowed to control Illustrator. Turn on Adobe Illustrator for CarmaChameleon in Automation settings.|CarmaChameleon 未被允许控制 Illustrator。请在“自动化”设置中打开 Adobe Illustrator。|CarmaChameleon가 Illustrator를 제어하도록 허용되지 않았습니다. 자동화 설정에서 Adobe Illustrator를 켜세요.
illustratorTimeout|Illustratorが応答しません。Illustratorでダイアログボックスが開いていないか確認してください。|Illustrator did not respond. Check for an open dialog in Illustrator.|Illustrator 无响应。请检查 Illustrator 中是否有打开的对话框。|Illustrator가 응답하지 않습니다. Illustrator에 열린 대화상자가 있는지 확인하세요.
illustratorFailed|Illustratorで書き出せませんでした：|Illustrator could not export: |Illustrator 无法导出：|Illustrator에서 내보내지 못했습니다: 
illustratorTooOld|Illustrator CC 2018以降が必要です。|Illustrator CC 2018 or later is required.|需要 Illustrator CC 2018 或更高版本。|Illustrator CC 2018 이상이 필요합니다.
illustratorPresetMissing|IllustratorにPDFプリセットがありません：|Illustrator does not have the PDF preset: |Illustrator 中没有此 PDF 预设：|Illustrator에 PDF 사전 설정이 없습니다: 
aiExportedOpen|Illustratorで開いているドキュメントから書き出しました。|Exported from the document open in Illustrator.|已从 Illustrator 中打开的文档导出。|Illustrator에서 열려 있는 문서에서 내보냈습니다.
aiExportedUnsaved|Illustratorで開いているドキュメントから書き出しました。未保存の変更も含まれます。|Exported from the document open in Illustrator, including unsaved changes.|已从 Illustrator 中打开的文档导出，包含未保存的更改。|Illustrator에서 열려 있는 문서에서 내보냈습니다. 저장하지 않은 변경 사항도 포함됩니다.
aiBrokenLinks|リンク切れの画像があります。PDFでは画像が欠けている可能性があります。|Some linked images are missing; they may be absent from the PDF.|有缺失的链接图像，PDF 中可能缺少这些图像。|링크가 끊어진 이미지가 있습니다. PDF에서 이미지가 빠졌을 수 있습니다.
rasterImage|ラスター画像|Raster image|位图图像|래스터 이미지
filesWritten|%d個のファイル|%d files|%d 个文件|파일 %d개
rasterType|画像の形式|Image format|图像格式|이미지 형식
rasterPPI|解像度|Resolution|分辨率|해상도
rasterPPIPresets|よく使う解像度|Common resolutions|常用分辨率|자주 쓰는 해상도
rasterQuality|画質|Quality|品质|품질
rasterTransparent|背景を透明にする|Transparent background|透明背景|배경을 투명하게
rasterRange|範囲|Range|范围|범위
rasterRangeAll|すべて|All|全部|모두
rasterRangeHint|アートボード（PDF・InDesignはページ）の番号。例：1,3-5。空欄ならすべて。解像度は .ai・.indd・PDF に使い、.psd と画像は元の画素数のままです（幅・高さを指定すると拡大・縮小します）。JPEGの背景は白です。|Artboard (PDF, InDesign: page) numbers, e.g. 1,3-5. Leave empty for all. Resolution applies to .ai, .indd and PDF; .psd files and images keep their pixels (a width or height resizes them). JPEG has a white background.|画板（PDF、InDesign 为页）编号，例如 1,3-5。留空表示全部。分辨率用于 .ai、.indd 和 PDF，.psd 和图像保持原像素（指定宽度或高度时会缩放）。JPEG 背景为白色。|대지(PDF, InDesign은 페이지) 번호. 예: 1,3-5. 비워 두면 모두. 해상도는 .ai, .indd, PDF에 적용되며 .psd와 이미지는 원래 픽셀 수를 유지합니다(너비·높이를 지정하면 크기를 바꿉니다). JPEG 배경은 흰색입니다.
svgCSS|スタイル|Styling|样式|스타일
svgCSSAttributes|インラインスタイル|Inline Style|内联样式|인라인 스타일
svgCSSElements|内部CSS|Internal CSS|内部 CSS|내부 CSS
svgCSSPresentation|プレゼンテーション属性|Presentation Attributes|演示文稿属性|프레젠테이션 속성
svgCSSEntities|スタイル属性（実体参照）|Style Attributes (Entity References)|样式属性（实体引用）|스타일 속성(엔티티 참조)
svgFont|フォント|Font|字体|글꼴
svgFontText|SVG（テキストのまま）|SVG (keep text)|SVG（保留文字）|SVG(텍스트 유지)
svgFontOutline|アウトラインに変換|Convert to Outlines|转换为轮廓|윤곽선으로 변환
svgImages|画像|Images|图像|이미지
svgImagesPreserve|保持|Preserve|保留|유지
svgImagesEmbed|埋め込み|Embed|嵌入|포함
svgImagesLink|リンク|Link|链接|링크
svgID|オブジェクトID|Object IDs|对象 ID|오브젝트 ID
svgIDRegular|レイヤー名|Layer Names|图层名称|레이어 이름
svgIDMinimal|最小|Minimal|最小|최소
svgIDUnique|一意|Unique|唯一|고유
svgPrecision|小数点以下の桁数|Decimal places|小数位数|소수점 이하 자릿수
svgMinify|縮小|Minify|缩小|축소
svgResponsive|レスポンシブ|Responsive|响应|반응형
svgRangeHint|アートボードの番号。例：1,3-5。空欄ならすべて。|Artboard numbers, e.g. 1,3-5. Leave empty for all.|画板编号，例如 1,3-5。留空表示全部。|대지 번호. 예: 1,3-5. 비워 두면 모두.
svgHint|SVGは .ai から、Illustratorの「スクリーン用に書き出し」でアートボードごとに書き出します（Illustratorが必要）。|SVG is exported from .ai files per artboard with Illustrator's Export for Screens (Illustrator required).|SVG 由 .ai 文件通过 Illustrator 的“导出为多种屏幕所用格式”按画板导出（需要 Illustrator）。|SVG는 .ai에서 Illustrator의 "화면용 내보내기"로 대지별로 내보냅니다(Illustrator 필요).
imageHint|.ai はアートボードごと、PDF・.indd はページごとに1枚ずつ書き出します。.psd は統合した画像、画像ファイルはそのまま1枚にします。|.ai files give one image per artboard, PDF and .indd files one per page. A .psd gives its flattened image, an image file one image.|.ai 按画板、PDF 和 .indd 按页各导出一张。.psd 导出合并图像，图像文件导出一张。|.ai는 대지별, PDF와 .indd는 페이지별로 한 장씩 내보냅니다. .psd는 병합한 이미지, 이미지 파일은 한 장입니다.
nameTitle|ファイル名|File name|文件名|파일 이름
nameFile|元のファイル名|Source file name|源文件名|원본 파일 이름
nameNumber|アートボード番号（PDFはページ番号）|Artboard number (PDF: page number)|画板编号（PDF 为页码）|대지 번호(PDF는 페이지 번호)
nameLabel|アートボード名（InDesignはページ名）|Artboard name (InDesign: page name)|画板名称（InDesign 为页面名称）|대지 이름(InDesign은 페이지 이름)
nameDelimiter|区切り|Separator|分隔符|구분 문자
nameSpace|スペース|Space|空格|공백
namePad|番号を2桁以上にそろえる（01）|Pad numbers (01)|编号补零（01）|번호를 두 자리 이상으로(01)
nameSingle|1枚だけのときは元のファイル名のみ|Only one image: source file name only|只有一张时仅用源文件名|한 장뿐이면 원본 파일 이름만
nameSampleFile|ファイル|file|文件|파일
nameSampleArtboard|表紙|Cover|封面|표지
namePreview|例：%@|Example: %@|示例：%@|예: %@
nameHint|アートボード名はIllustratorで書き出すとき、ページ名はInDesignのときだけ使えます。同名のファイルには連番を付けます。|Artboard names are available when exporting with Illustrator, page names with InDesign. Existing names get a number.|仅在用 Illustrator 导出时可使用画板名称，用 InDesign 时可使用页面名称。同名文件会添加编号。|대지 이름은 Illustrator로, 페이지 이름은 InDesign으로 내보낼 때만 사용할 수 있습니다. 같은 이름에는 번호를 붙입니다.
psdTitle|Photoshop（.psd）の変換|Photoshop (.psd) conversion|Photoshop（.psd）转换|Photoshop(.psd) 변환
psdMethod|変換方法|Method|转换方法|변환 방법
psdSimple|簡易（Photoshop不要）|Simple (no Photoshop)|简易（无需 Photoshop）|간이(Photoshop 불필요)
psdPhotoshop|Photoshopで書き出す（正式）|Export with Photoshop (full)|用 Photoshop 导出（正式）|Photoshop으로 내보내기(정식)
psdSimpleHint|.psd に入っている統合画像を使います。「互換性を優先」をオフで保存した .psd は正しく変換できないことがあります。|Uses the composite image stored in the .psd. Files saved without "Maximize Compatibility" may not convert correctly.|使用 .psd 中保存的合并图像。未勾选“最大兼容”保存的 .psd 可能无法正确转换。|.psd에 저장된 병합 이미지를 사용합니다. "호환성 최대화"를 끄고 저장한 .psd는 올바르게 변환되지 않을 수 있습니다.
psdPhotoshopHint|Photoshopでファイルを開き、コピーを保存します。変換中はPhotoshopが起動します。Photoshopで開いているファイルは、開いたまま書き出します。|Photoshop opens the file and saves a copy. Photoshop runs during conversion. Files already open in Photoshop are exported as they are and stay open.|由 Photoshop 打开文件并存储副本。转换期间会启动 Photoshop。已在 Photoshop 中打开的文件会直接导出并保持打开。|Photoshop이 파일을 열어 사본을 저장합니다. 변환 중 Photoshop이 실행됩니다. Photoshop에서 열려 있는 파일은 연 상태 그대로 내보냅니다.
psdApp|使用するPhotoshop|Photoshop to use|使用的 Photoshop|사용할 Photoshop
photoshopMissing|Photoshopが見つかりません。「簡易」で変換するか、Photoshopをインストールしてください。|Photoshop is not installed. Use Simple, or install Photoshop.|未找到 Photoshop。请使用“简易”方式或安装 Photoshop。|Photoshop이 없습니다. 간이 방식을 사용하거나 Photoshop을 설치하세요.
photoshopDenied|Photoshopの操作が許可されていません。システム設定の「オートメーション」でCarmaChameleonのAdobe Photoshopをオンにしてください。|CarmaChameleon is not allowed to control Photoshop. Turn on Adobe Photoshop for CarmaChameleon in Automation settings.|CarmaChameleon 未被允许控制 Photoshop。请在“自动化”设置中打开 Adobe Photoshop。|CarmaChameleon가 Photoshop을 제어하도록 허용되지 않았습니다. 자동화 설정에서 Adobe Photoshop을 켜세요.
photoshopTimeout|Photoshopが応答しません。Photoshopでダイアログボックスが開いていないか確認してください。|Photoshop did not respond. Check for an open dialog in Photoshop.|Photoshop 无响应。请检查 Photoshop 中是否有打开的对话框。|Photoshop이 응답하지 않습니다. Photoshop에 열린 대화상자가 있는지 확인하세요.
photoshopFailed|Photoshopで書き出せませんでした：|Photoshop could not export: |Photoshop 无法导出：|Photoshop에서 내보내지 못했습니다: 
psdExportedOpen|Photoshopで開いているドキュメントから書き出しました。|Exported from the document open in Photoshop.|已从 Photoshop 中打开的文档导出。|Photoshop에서 열려 있는 문서에서 내보냈습니다.
psdExportedUnsaved|Photoshopで開いているドキュメントから書き出しました。未保存の変更も含まれます。|Exported from the document open in Photoshop, including unsaved changes.|已从 Photoshop 中打开的文档导出，包含未保存的更改。|Photoshop에서 열려 있는 문서에서 내보냈습니다. 저장하지 않은 변경 사항도 포함됩니다.
aiBrokenLinksImage|リンク切れの画像があります。書き出した画像では欠けている可能性があります。|Some linked images are missing; they may be absent from the output.|有缺失的链接图像，输出中可能缺少这些图像。|링크가 끊어진 이미지가 있습니다. 출력에서 이미지가 빠졌을 수 있습니다.
svgInputUnsupported|SVGに書き出せるのは .ai だけです。|Only .ai files can be exported as SVG.|只有 .ai 文件可以导出为 SVG。|SVG로 내보낼 수 있는 것은 .ai뿐입니다.
imageInputUnsupported|ラスター画像に書き出せるのは .ai・.psd・.indd・PDF・画像ファイルだけです。|Only .ai, .psd, .indd, PDF and image files can be exported as raster images.|只有 .ai、.psd、.indd、PDF 和图像文件可以导出为位图图像。|래스터 이미지로 내보낼 수 있는 것은 .ai, .psd, .indd, PDF, 이미지 파일뿐입니다.
imageRenderFailed|画像を作成できませんでした。|The image could not be created.|无法创建图像。|이미지를 만들 수 없습니다.
imageTooLarge|画像が大きすぎます。解像度を下げてください。|The image is too large. Lower the resolution.|图像过大。请降低分辨率。|이미지가 너무 큽니다. 해상도를 낮추세요.
imageWriteFailed|画像を保存できませんでした。|The image could not be saved.|无法保存图像。|이미지를 저장할 수 없습니다.
psdInvalid|画像を読み込めませんでした。|The image could not be read.|无法读取图像。|이미지를 읽을 수 없습니다.
rangeInvalid|範囲の指定を読み取れません：|The range cannot be read:|无法识别范围：|범위를 읽을 수 없습니다:
rangeOutOfBounds|範囲「%@」がありません（全%d）。|The range "%@" does not exist (%d in total).|范围“%@”不存在（共 %d）。|범위 "%@"가 없습니다(총 %d).
rasterSize|サイズ|Size|尺寸|크기
rasterWidth|幅|Width|宽度|너비
rasterHeight|高さ|Height|高度|높이
nameGroupFolder|複数のときは元のファイル名のフォルダーにまとめる|Several images: put them in a folder named after the source|多张时放入以源文件名命名的文件夹|여러 장이면 원본 파일 이름의 폴더에 모으기
csvDelimiter|区切り|Separator|分隔符|구분 문자
csvComma|カンマ（.csv）|Comma (.csv)|逗号（.csv）|쉼표(.csv)
csvTab|タブ（.tsv）|Tab (.tsv)|制表符（.tsv）|탭(.tsv)
csvHint|字幕（.srt）を「番号・時刻・ハンドル・コメント」の表にします。「ハンドル: コメント」の形の字幕は最初の「: 」で分け、それ以外はコメントだけにします。時刻は開始時刻（時:分:秒）です。|Turns subtitles (.srt) into a table of number, time, handle and comment. Text in the form "handle: comment" is split at the first ": "; other text becomes the comment. The time is the start time (h:m:s).|将字幕（.srt）转为“编号、时间、昵称、评论”表格。“昵称: 评论”形式的字幕在第一个“: ”处拆分，其他文字仅作为评论。时间为开始时间（时:分:秒）。|자막(.srt)을 "번호·시각·핸들·코멘트" 표로 만듭니다. "핸들: 코멘트" 형식은 첫 번째 ": "에서 나누고, 그 밖의 텍스트는 코멘트만으로 합니다. 시각은 시작 시각(시:분:초)입니다.
srtTime|時刻|Time|时间|시각
srtHandle|ハンドル|Handle|昵称|핸들
srtComment|コメント|Comment|评论|코멘트
srtInvalid|字幕（SRT）として読み込めませんでした。|The file could not be read as subtitles (SRT).|无法作为字幕（SRT）读取。|자막(SRT)으로 읽을 수 없습니다.
csvInputUnsupported|CSVに書き出せるのは字幕（.srt）だけです。|Only subtitles (.srt) can be exported as CSV.|只有字幕（.srt）可以导出为 CSV。|CSV로 내보낼 수 있는 것은 자막(.srt)뿐입니다.
srtFormatUnsupported|字幕（.srt）はCSVにだけ変換できます。|Subtitles (.srt) can be converted only to CSV.|字幕（.srt）只能转换为 CSV。|자막(.srt)은 CSV로만 변환할 수 있습니다.
documentFormatUnsupported|.psd・.indd・画像ファイルは、PDF・ラスター画像にだけ変換できます。|.psd, .indd and image files can be converted only to PDF or a raster image.|.psd、.indd 和图像文件只能转换为 PDF 或位图图像。|.psd, .indd, 이미지 파일은 PDF 또는 래스터 이미지로만 변환할 수 있습니다.
pdfCombineImages|画像を1つのPDFにまとめる|Combine images into one PDF|将图像合并为一个 PDF|이미지를 하나의 PDF로 합치기
pdfCombineImagesHint|追加した順に1枚ずつページにし、最初のファイルの名前で保存します。オフなら画像ごとにPDFを作ります。|Each image becomes a page in the order added; the PDF is named after the first file. When off, each image gets its own PDF.|按添加顺序每张图像为一页，以第一个文件的名称保存。关闭时每张图像各生成一个 PDF。|추가한 순서대로 한 장씩 페이지로 만들고 첫 번째 파일 이름으로 저장합니다. 끄면 이미지마다 PDF를 만듭니다.
inddTitle|InDesign（.indd）の変換|InDesign (.indd) conversion|InDesign（.indd）转换|InDesign(.indd) 변환
inddPresetDefault|InDesignの現在の書き出し設定|InDesign's current export settings|InDesign 当前的导出设置|InDesign의 현재 내보내기 설정
inddHint|InDesignでファイルを開いて書き出します（InDesignが必要）。PDFは選んだPDFプリセット、画像はページごとです。InDesignで開いているファイルは、開いたまま書き出します。|InDesign opens the file and exports it (InDesign required): PDF with the chosen preset, images per page. Files already open in InDesign are exported as they are and stay open.|由 InDesign 打开文件并导出（需要 InDesign）：PDF 使用所选预设，图像按页。已在 InDesign 中打开的文件会直接导出并保持打开。|InDesign이 파일을 열어 내보냅니다(InDesign 필요). PDF는 선택한 사전 설정, 이미지는 페이지별입니다. InDesign에서 열려 있는 파일은 연 상태 그대로 내보냅니다.
inddApp|使用するInDesign|InDesign to use|使用的 InDesign|사용할 InDesign
inddLoadPresets|InDesignからPDFプリセットを読み込む|Load PDF presets from InDesign|从 InDesign 读取 PDF 预设|InDesign에서 PDF 사전 설정 불러오기
inddLoadPresetsHint|InDesignを起動して、使えるPDFプリセットの一覧を取得します。|Launches InDesign and reads the available PDF presets.|启动 InDesign 并读取可用的 PDF 预设。|InDesign을 실행하여 사용할 수 있는 PDF 사전 설정을 가져옵니다.
inddLoadingPresets|InDesignから読み込んでいます…|Reading from InDesign…|正在从 InDesign 读取…|InDesign에서 불러오는 중…
indesignMissing|InDesignが見つかりません。.indd の変換にはInDesignが必要です。|InDesign is not installed. Converting .indd files requires InDesign.|未找到 InDesign。转换 .indd 需要 InDesign。|InDesign이 없습니다. .indd 변환에는 InDesign이 필요합니다.
indesignDenied|InDesignの操作が許可されていません。システム設定の「オートメーション」でCarmaChameleonのAdobe InDesignをオンにしてください。|CarmaChameleon is not allowed to control InDesign. Turn on Adobe InDesign for CarmaChameleon in Automation settings.|CarmaChameleon 未被允许控制 InDesign。请在“自动化”设置中打开 Adobe InDesign。|CarmaChameleon가 InDesign을 제어하도록 허용되지 않았습니다. 자동화 설정에서 Adobe InDesign을 켜세요.
indesignTimeout|InDesignが応答しません。InDesignでダイアログボックスが開いていないか確認してください。|InDesign did not respond. Check for an open dialog in InDesign.|InDesign 无响应。请检查 InDesign 中是否有打开的对话框。|InDesign이 응답하지 않습니다. InDesign에 열린 대화상자가 있는지 확인하세요.
indesignFailed|InDesignで書き出せませんでした：|InDesign could not export: |InDesign 无法导出：|InDesign에서 내보내지 못했습니다: 
indesignPresetMissing|InDesignにPDFプリセットがありません：|InDesign does not have the PDF preset: |InDesign 中没有此 PDF 预设：|InDesign에 PDF 사전 설정이 없습니다: 
indesignExportedOpen|InDesignで開いているドキュメントから書き出しました。|Exported from the document open in InDesign.|已从 InDesign 中打开的文档导出。|InDesign에서 열려 있는 문서에서 내보냈습니다.
indesignExportedUnsaved|InDesignで開いているドキュメントから書き出しました。未保存の変更も含まれます。|Exported from the document open in InDesign, including unsaved changes.|已从 InDesign 中打开的文档导出，包含未保存的更改。|InDesign에서 열려 있는 문서에서 내보냈습니다. 저장하지 않은 변경 사항도 포함됩니다."""
table=[line.split('|') for line in rows.splitlines()]
assert all(len(r)==5 for r in table)
assert len({r[0] for r in table})==len(table), 'duplicate key'
for i,lang in enumerate(['ja','en','zh-Hans','ko'],1):
 p=root/'Resources'/f'{lang}.lproj';p.mkdir(parents=True,exist_ok=True)
 (p/'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0])} = {json.dumps(r[i],ensure_ascii=False)};' for r in table)+'\n')
# Help text lives in help_text.py (markup rendered by Shared/AppStandards/HelpDocument.swift).
from help_text import HELP
helptexts=[HELP[l] for l in ['ja','en','zh-Hans','ko']]
for lang,text in zip(['ja','en','zh-Hans','ko'],helptexts): (root/'Resources'/f'{lang}.lproj'/'Help.txt').write_text(text)
for lang,text in zip(['ja','en','zh-Hans','ko'],['Keynote形式で書き出すときはKeynoteに、Illustratorで.aiを変換するときはIllustratorに、Photoshopで.psdを変換するときはPhotoshopに、InDesignで.inddを変換するときはInDesignに作業を依頼します。', 'CarmaChameleon asks Keynote to create presentations, Illustrator to export .ai files, Photoshop to export .psd files, and InDesign to export .indd files when you choose those options.', 'CarmaChameleon 会在导出 Keynote 时让 Keynote 创建演示文稿，在用 Illustrator 转换 .ai 时让 Illustrator 导出，在用 Photoshop 转换 .psd 时让 Photoshop 导出，在转换 .indd 时让 InDesign 导出。', 'CarmaChameleon는 Keynote로 내보낼 때 Keynote에, Illustrator로 .ai를 변환할 때 Illustrator에, Photoshop으로 .psd를 변환할 때 Photoshop에, .indd를 변환할 때 InDesign에 작업을 요청합니다.']): (root/'Resources'/f'{lang}.lproj'/'InfoPlist.strings').write_text(f'"NSAppleEventsUsageDescription" = {json.dumps(text,ensure_ascii=False)};\n')
info=dict(CFBundleName='CarmaChameleon',CFBundleDisplayName='CarmaChameleon',CFBundleExecutable='CarmaChameleon',CFBundleIdentifier='jp.local.PandocDesk',CFBundlePackageType='APPL',CFBundleShortVersionString='0.8.1',CFBundleVersion='28',SWNoteArticleURL='https://note.com/swwwitch/m/m057948d2fbeb',NSAppleEventsUsageDescription='CarmaChameleon asks Keynote to create presentations, Illustrator to export .ai files, Photoshop to export .psd files, and InDesign to export .indd files when you choose those options.',CFBundleIconFile='CarmaChameleon.icns',CFBundleDevelopmentRegion='en',CFBundleLocalizations=['ja','en','zh-Hans','ko'],LSMinimumSystemVersion='13.0',NSHighResolutionCapable=True,LSMultipleInstancesProhibited=True,CFBundleDocumentTypes=[dict(CFBundleTypeName='Documents',CFBundleTypeRole='Viewer',LSHandlerRank='Alternate',LSItemContentTypes=['public.text','org.openxmlformats.wordprocessingml.document','org.idpf.epub-container','com.adobe.pdf','public.comma-separated-values-text','public.tab-separated-values-text','org.openxmlformats.spreadsheetml.sheet','com.adobe.illustrator.ai-image','com.adobe.photoshop-image','public.image'])])
info['CFBundleDocumentTypes'].append(dict(CFBundleTypeName='InDesign Markup',CFBundleTypeRole='Viewer',LSHandlerRank='Alternate',CFBundleTypeExtensions=['idml','indd','srt']))
with open(root/'Info.plist','wb') as f: plistlib.dump(info,f)
