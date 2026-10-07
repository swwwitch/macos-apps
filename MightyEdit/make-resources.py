#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate MightyEdit UI localizations from one table (B15).

Outputs:
  Resources/<lang>.lproj/Localizable.strings   (ja, en, zh-Hans, ko)
  Resources/<lang>.lproj/Help.txt              (copied from Localization/Help/<lang>.txt)
  Source/LocalizationFallback.swift            (Japanese table for test binaries without a bundle)

UI labels only. Text that MightyEdit inserts into the user's document (list markers,
「合計：」, dates, typography rules) stays in Swift source and is never localized.
Columns: key | ja | en | zh-Hans | ko.  "\\n" in a cell means a line break.
"""
from pathlib import Path
import json, re, sys

root = Path(__file__).resolve().parent
LANGS = ['ja', 'en', 'zh-Hans', 'ko']

rows = r'''
app.ready|文字を選択して、ボタンをクリック|Select text, then click a button|选择文字，然后点击按钮|텍스트를 선택한 다음 버튼을 클릭하세요
menu.showPalette|パレットを表示|Show Palette|显示面板|팔레트 보기
menu.hidePalette|パレットを隠す|Hide Palette|隐藏面板|팔레트 숨기기
menu.settings|設定…|Settings…|设置…|설정…
menu.copyOnly|置き換えずにコピー|Copy Without Replacing|复制而不替换|대치하지 않고 복사
menu.openAccessibility|アクセシビリティ設定を開く…|Open Accessibility Settings…|打开辅助功能设置…|손쉬운 사용 설정 열기…
menu.revealApp|許可するアプリをFinderで表示|Show App to Allow in Finder|在 Finder 中显示要允许的应用|허용할 앱을 Finder에서 보기
menu.quit|MightyEditを終了|Quit MightyEdit|退出 MightyEdit|MightyEdit 종료
menu.help|MightyEditヘルプ|MightyEdit Help|MightyEdit 帮助|MightyEdit 도움말
menu.buttonDisplay|ボタンの表示|Button Style|按钮样式|버튼 스타일
menu.hotkeys|ホットキー|Hotkeys|快捷键|단축키
menu.about|MightyEditについて|About MightyEdit|关于 MightyEdit|MightyEdit에 관하여
menu.file|ファイル|File|文件|파일
menu.openMainWindow|メインウインドウを開く|Open Main Window|打开主窗口|메인 윈도우 열기
menu.edit|編集|Edit|编辑|편집
menu.undo|取り消す|Undo|撤销|실행 취소
menu.redo|やり直す|Redo|重做|실행 복귀
menu.cut|カット|Cut|剪切|잘라내기
menu.copy|コピー|Copy|拷贝|복사하기
menu.paste|ペースト|Paste|粘贴|붙여넣기
menu.selectAll|すべてを選択|Select All|全选|전체 선택
menu.window|ウインドウ|Window|窗口|윈도우
menu.closeWindow|ウインドウを閉じる|Close Window|关闭窗口|윈도우 닫기
help|ヘルプ|Help|帮助|도움말
help.missing|ヘルプファイルが見つかりません。同梱のREADMEを参照してください。|The help file is missing. See the bundled README.|找不到帮助文件。请参阅附带的 README。|도움말 파일을 찾을 수 없습니다. 포함된 README를 참조하세요.
settings.window|設定|Settings|设置|설정
tip.settings|設定を開く（⌘,）|Open Settings (⌘,)|打开设置（⌘,）|설정 열기(⌘,)
tip.help|使い方と困ったときの対処を表示|Show how to use MightyEdit and troubleshooting tips|显示使用方法和故障排除|사용 방법과 문제 해결 보기
header.title|選択テキストを整える|Tidy Selected Text|整理所选文本|선택한 텍스트 다듬기
header.subtitle|文字・日付・リストをボタンで変換。|Convert text, dates and lists with a click.|一键转换文字、日期和列表。|버튼으로 문자, 날짜, 목록을 변환합니다.
ax.profilePicker|表示モード|Display mode|显示模式|표시 모드
ax.accessibilitySettings|アクセシビリティ設定|Accessibility Settings|辅助功能设置|손쉬운 사용 설정
tip.openAccessibility|アクセシビリティ設定を開く|Open Accessibility Settings|打开辅助功能设置|손쉬운 사용 설정 열기
about.support|サポート：同梱のREADME|Support: bundled README|支持：附带的 README|지원: 포함된 README
fmt.labelValue|%1$@：%2$@|%1$@: %2$@|%1$@：%2$@|%1$@: %2$@
fmt.nameDetail|%1$@（%2$@）|%1$@ (%2$@)|%1$@（%2$@）|%1$@(%2$@)
target.app|アプリ|App|应用|앱
target.appLong|対象アプリ|the target app|目标应用|대상 앱
target.excluded|対象：%@（対象外のアプリ）|Target: %@ (excluded app)|目标：%@（排除的应用）|대상: %@(제외된 앱)
target.normal|対象：%1$@  ·  %2$@|Target: %1$@  ·  %2$@|目标：%1$@  ·  %2$@|대상: %1$@  ·  %2$@
target.copy|コピー|Copy|复制|복사
target.replace|選択範囲を置換|Replace selection|替换所选内容|선택 영역 대치
msg.needPermission|選択文字の操作には許可が必要です。設定でMightyEditをオンにしてください。|Permission is required to edit selected text. Turn on MightyEdit in System Settings.|处理所选文字需要权限。请在系统设置中打开 MightyEdit。|선택한 텍스트를 다루려면 권한이 필요합니다. 시스템 설정에서 MightyEdit를 켜세요.
msg.permissionOK|許可を確認しました。対象アプリで文字を選択してください。|Permission confirmed. Select text in the target app.|已确认权限。请在目标应用中选择文字。|권한을 확인했습니다. 대상 앱에서 텍스트를 선택하세요.
msg.targetChangedReselect|対象アプリが切り替わりました。選択し直して呼び出してください。|The target app changed. Select the text again and reopen this window.|目标应用已切换。请重新选择文字后再打开此窗口。|대상 앱이 바뀌었습니다. 텍스트를 다시 선택한 후 다시 여세요.
msg.targetChangedReopen|対象アプリが切り替わりました。パレットを呼び出し直してください。|The target app changed. Show the palette again.|目标应用已切换。请重新调出面板。|대상 앱이 바뀌었습니다. 팔레트를 다시 불러오세요.
msg.busyQuit|文字の加工中です。処理が終わってから終了してください。|Text is being processed. Quit after it finishes.|正在处理文字。请在处理完成后退出。|텍스트를 처리하는 중입니다. 완료된 후 종료하세요.
msg.selectedEmpty|加工しました（選択する文字はありません）|Done (no text to select)|已处理（没有可选择的文字）|처리했습니다(선택할 텍스트 없음)
msg.selected|加工した文字を選択しました|Selected the converted text|已选择处理后的文字|변환한 텍스트를 선택했습니다
msg.reselectUnsupported|加工後の自動選択に対応していない入力欄です|This field does not support reselecting the result|此输入框不支持处理后自动选择|이 입력란은 변환 후 자동 선택을 지원하지 않습니다
msg.selectInApp|操作するアプリで文字を選択してください|Select text in the app you want to edit|请在要操作的应用中选择文字|편집할 앱에서 텍스트를 선택하세요
msg.noAccess|このアプリの選択文字を取得できません|Cannot read the selected text in this app|无法获取此应用中的所选文字|이 앱에서 선택한 텍스트를 가져올 수 없습니다
msg.selectText|文字を選択してください（選択取得に非対応のアプリでは使用不可）|Select some text (apps that don’t expose their selection are not supported)|请选择文字（不支持无法获取所选内容的应用）|텍스트를 선택하세요(선택 영역을 가져올 수 없는 앱은 지원하지 않음)
msg.noChange|変更する文字がありません|Nothing to change|没有需要更改的文字|변경할 텍스트가 없습니다
msg.copied|加工した文字をコピーしました|Copied the converted text|已拷贝处理后的文字|변환한 텍스트를 복사했습니다
msg.noRange|選択範囲を確認できません。「置き換えずにコピー」をお使いください|Cannot confirm the selection. Use “Copy Without Replacing”.|无法确认所选范围。请使用“复制而不替换”。|선택 영역을 확인할 수 없습니다. ‘대치하지 않고 복사’를 사용하세요.
msg.noTarget|対象アプリを確認できません。もう一度選択してください|Cannot confirm the target app. Select the text again.|无法确认目标应用。请重新选择。|대상 앱을 확인할 수 없습니다. 다시 선택하세요.
msg.clipboardFailed|クリップボードに書き込めません|Cannot write to the clipboard|无法写入剪贴板|클립보드에 쓸 수 없습니다
msg.pasteSent|%@へ貼り付けを送信しました|Sent Paste to %@|已向%@发送粘贴|%@에 붙여넣기를 보냈습니다
err.sumNoNumbers|選択範囲に合算できる数字がありません|There are no numbers to add in the selection|所选范围内没有可求和的数字|선택 영역에 합산할 숫자가 없습니다
err.sumPrecision|正確に合算できる桁数を超えています。選択範囲を分けてください|Too many digits to add exactly. Split the selection.|位数过多，无法精确求和。请拆分所选范围。|정확히 합산할 수 있는 자릿수를 초과했습니다. 선택 영역을 나누세요.
display.both|アイコン＋テキスト|Icon and Text|图标和文本|아이콘 및 텍스트
display.iconOnly|アイコンのみ|Icon Only|仅图标|아이콘만
display.textOnly|テキストのみ|Text Only|仅文本|텍스트만
profile.minimal|超簡易|Minimal|极简|최소
profile.simple|簡易モード|Simple|简易|간단
profile.full|全部入り|Full|完整|전체
group.lines|行の編集|Lines|行编辑|줄 편집
group.lists|リスト|Lists|列表|목록
group.digits|桁区切り|Digit Grouping|千位分隔|자릿수 구분
group.characters|文字の整形|Character Formatting|字符整理|문자 정리
group.western|欧文|Latin Text|西文|로마자
group.dates|日付|Dates|日期|날짜
group.code|ソースコード|Source Code|源代码|소스 코드
group.other|その他|Other|其他|기타
group.palette|パレット操作|Palette|面板操作|팔레트
group.more|追加の操作|More Actions|更多操作|추가 동작
special.lists|その他のリスト|More Lists|更多列表|기타 목록
tab.special|スペシャル|Special|特殊|스페셜
tab.autoShow|自動表示|Auto Show|自动显示|자동 표시
display.heading|モードごとの表示設定|Display Settings by Mode|按模式设置显示|모드별 표시 설정
display.modeToEdit|設定するモード|Mode to configure|要设置的模式|설정할 모드
display.itemsHeading|表示するカテゴリ・ボタン|Categories and Buttons to Show|要显示的类别和按钮|표시할 카테고리 및 버튼
display.explanation|各モードを個別に設定できます。使用中のモードの変更はすぐに反映されます。非表示でもホットキーは利用できます。|Each mode is configured separately. Changes to the mode in use apply immediately. Hidden actions still work with hotkeys.|每种模式可分别设置。对当前模式的更改会立即生效。隐藏的操作仍可通过快捷键使用。|각 모드를 따로 설정할 수 있습니다. 사용 중인 모드의 변경 사항은 즉시 반영됩니다. 숨긴 동작도 단축키로 사용할 수 있습니다.
display.showCategory|このカテゴリを表示|Show this category|显示此类别|이 카테고리 표시
special.listsHeading|その他のリスト：利用する形式|More Lists: Formats to Use|更多列表：要使用的格式|기타 목록: 사용할 형식
special.typographyHeading|まとめて整形：適用する項目|Batch Formatting: Items to Apply|批量整理：要应用的项目|일괄 정리: 적용할 항목
op.join|改行を削除|Remove Line Breaks|删除换行|줄 바꿈 삭제
op.number|番号付きリスト|Numbered List|编号列表|번호 목록
op.bullet|箇条書き|Bulleted List|项目符号列表|글머리 기호 목록
op.removeList|リスト記号を削除|Remove List Markers|删除列表符号|목록 기호 삭제
op.markdown|Markdown箇条書き|Markdown List|Markdown 列表|Markdown 목록
op.circled|白丸数字|Circled Numbers|圆圈数字|원 숫자
op.alphabet|英字番号（A.）|Letter List (A.)|字母编号（A.）|영문자 번호(A.)
op.addCommas|カンマを付ける|Add Commas|添加逗号|쉼표 추가
op.removeCommas|カンマを削除|Remove Commas|删除逗号|쉼표 삭제
op.removeBlankLines|空白行を削除|Remove Blank Lines|删除空行|빈 줄 삭제
op.spaceLines|行間に空行を挿入|Blank Line Between Lines|行间插入空行|줄 사이에 빈 줄 삽입
op.addPeriod|行末に「。」を追加|Add “。” at Line End|在行末添加“。”|줄 끝에 ‘。’ 추가
op.removePeriod|行末の「。」を削除|Remove “。” at Line End|删除行末“。”|줄 끝 ‘。’ 삭제
op.bracketNumber|括弧付き数字|Bracketed Numbers|带括号数字|괄호 숫자
op.bracketAlphabet|括弧付きアルファベット|Bracketed Letters|带括号字母|괄호 영문자
op.beautify|Beautify（HTML整形）|Beautify (HTML)|Beautify（HTML 格式化）|Beautify(HTML 정리)
op.minify|Minify（空白圧縮）|Minify (Whitespace)|Minify（压缩空白）|Minify(공백 압축)
op.joinAll|すべての改行を削除|Remove All Line Breaks|删除所有换行|모든 줄 바꿈 삭제
op.narrowAlphanumerics|全角英数字を半角に|Full-width Letters/Digits to Half-width|全角字母数字转半角|전각 영숫자를 반각으로
op.widenKana|半角カナを全角に|Half-width Kana to Full-width|半角假名转全角|반각 가나를 전각으로
op.removeJapaneseSpaces|和欧間のスペースを削除|Remove Japanese–Latin Spaces|删除日文与西文间空格|일본어·로마자 사이 공백 삭제
op.addJapaneseSpaces|和欧間にスペースを追加|Add Japanese–Latin Spaces|在日文与西文间添加空格|일본어·로마자 사이 공백 추가
op.sum|数値を合計|Sum Numbers|数值求和|숫자 합계
op.fullwidthWestern|英数字・記号を全角に|Letters/Symbols to Full-width|字母数字和符号转全角|영숫자·기호를 전각으로
op.halfwidthWestern|英数字・記号を半角に|Letters/Symbols to Half-width|字母数字和符号转半角|영숫자·기호를 반각으로
op.capitalizeWords|単語の先頭を大文字に|Capitalize Words|单词首字母大写|단어 첫 글자 대문자
op.titleCase|タイトルケース|Title Case|标题式大小写|제목 스타일 대소문자
op.blackCircled|黒丸数字|Black Circled Numbers|黑圆数字|검은 원 숫자
op.kanji|漢数字（一、二、三、）|Kanji Numerals (一、二、三、)|汉字数字（一、二、三、）|한자 숫자(一、二、三、)
op.formalKanji|大字（壱・弐・参）|Formal Kanji (壱・弐・参)|大写汉字（壱・弐・参）|갖은자(壱・弐・参)
op.circledAlphabet|丸囲みアルファベット|Circled Letters|圆圈字母|원 영문자
op.romanUpper|ローマ数字（I, II, III）|Roman Numerals (I, II, III)|罗马数字（I, II, III）|로마 숫자(I, II, III)
op.romanLower|ローマ数字（i, ii, iii）|Roman Numerals (i, ii, iii)|罗马数字（i, ii, iii）|로마 숫자(i, ii, iii)
op.checkmark|チェック（✓）|Check Mark (✓)|勾号（✓）|체크 표시(✓)
op.emptyBox|四角（□）|Box (□)|方框（□）|사각형(□)
op.checkedBox|チェック（✅）|Check Box (✅)|勾选框（✅）|체크 상자(✅)
op.taskList|Markdownタスクリスト（- [ ]）|Markdown Task List (- [ ])|Markdown 任务列表（- [ ]）|Markdown 작업 목록(- [ ])
op.sortLines|行を並べ替え|Sort Lines|排序行|줄 정렬
op.uniqueLines|重複行を削除|Remove Duplicate Lines|删除重复行|중복 줄 삭제
op.joinWestern|改行をスペースに|Line Breaks to Spaces|换行转为空格|줄 바꿈을 공백으로
op.wrapLines|指定した文字数で改行|Wrap at Character Count|按指定字数换行|지정한 글자 수로 줄 바꿈
op.randomLines|行をシャッフル|Shuffle Lines|随机排列行|줄 섞기
op.toggleDateFormat|年月日 ↔ yyyy-mm-dd|年月日 ↔ yyyy-mm-dd|年月日 ↔ yyyy-mm-dd|年月日 ↔ yyyy-mm-dd
op.camelCase|camelCase（先頭小文字）|camelCase (lowercase first)|camelCase（首字母小写）|camelCase(첫 글자 소문자)
op.specialTypography|まとめて整形|Batch Formatting|批量整理|일괄 정리
op.dateToISO|yyyy-mm-dd形式|yyyy-mm-dd Format|yyyy-mm-dd 格式|yyyy-mm-dd 형식
op.dateToJapanese|yyyy年mm月dd日形式|yyyy年mm月dd日 Format|yyyy年mm月dd日 格式|yyyy年mm月dd日 형식
op.dateToEra|和暦に変更|To Japanese Era|转换为日本年号|일본 연호로 변환
op.dateToGregorian|西暦に変更|To Western Year|转换为公历|서력으로 변환
op.removeDateYear|年を削除|Remove Year|删除年份|연도 삭제
op.addDateYear|今年の西暦を追加|Add Current Year|添加今年年份|올해 연도 추가
op.weekdayShort|曜日を追加（火）|Add Weekday (火)|添加星期（火）|요일 추가(火)
op.weekdayLong|曜日を追加（火曜日）|Add Weekday (火曜日)|添加星期（火曜日）|요일 추가(火曜日)
op.dateToCompact|yyyymmdd形式|yyyymmdd Format|yyyymmdd 格式|yyyymmdd 형식
op.removeDatePadding|ゼロ埋めを削除|Remove Zero Padding|删除补零|0 채움 삭제
op.trimLineEdges|行頭・行末の空白を削除|Trim Spaces at Line Edges|删除行首和行尾空白|줄 앞뒤 공백 삭제
op.sortLineLength|文字数順に並べ替え|Sort by Length|按字数排序|글자 수순 정렬
op.countText|文字数・行数を数える|Count Characters and Lines|统计字数和行数|글자 수·줄 수 세기
op.affixLines|各行の先頭・末尾に追加|Add to Start/End of Lines|在每行开头和结尾添加|각 줄 앞뒤에 추가
tip.format|%1$@：%2$@|%1$@: %2$@|%1$@：%2$@|%1$@: %2$@
tip.default|既存の番号・記号を除去して各行に付加（空行は保持）|Removes existing numbers or markers and adds new ones to each line (blank lines are kept)|删除现有编号或符号后添加到每行（保留空行）|기존 번호·기호를 제거하고 각 줄에 추가(빈 줄 유지)
tip.trimLineEdges|各行の先頭・末尾にある空白・タブ・全角スペースを削除|Removes spaces, tabs and full-width spaces at the start and end of each line|删除每行开头和结尾的空格、制表符和全角空格|각 줄 앞뒤의 공백·탭·전각 공백 삭제
tip.sortLineLength|文字数の少ない順。すでに少ない順なら多い順に（同じ文字数の行順は保持）|Shortest first; if already sorted, longest first (lines of equal length keep their order)|按字数从少到多；已按此排序时改为从多到少（字数相同的行保持顺序）|짧은 순으로 정렬, 이미 짧은 순이면 긴 순으로(같은 길이의 줄 순서는 유지)
tip.countText|選択テキストの文字数・行数を別ウインドウに表示（本文は変更しない）|Shows the character and line count in a separate window (text is not changed)|在单独窗口中显示字数和行数（不更改文本）|글자 수·줄 수를 별도 윈도우에 표시(본문은 변경하지 않음)
tip.affixLines|指定文字を各行の先頭・末尾へ追加（空行も対象）|Adds the specified text to the start and end of each line (including blank lines)|在每行开头和结尾添加指定文字（包括空行）|지정한 문자를 각 줄 앞뒤에 추가(빈 줄 포함)
tip.date|選択テキスト内の日付を変換（存在しない日付は保持）|Converts dates in the selection (invalid dates are kept)|转换所选文本中的日期（保留不存在的日期）|선택한 텍스트의 날짜를 변환(존재하지 않는 날짜는 유지)
tip.narrowAlphanumerics|全角の英字・数字だけを半角に変換（記号やカナは保持）|Converts only full-width letters and digits to half-width (symbols and kana are kept)|仅将全角字母和数字转为半角（保留符号和假名）|전각 영문자·숫자만 반각으로 변환(기호와 가나는 유지)
tip.widenKana|半角カナを全角に変換（濁点・半濁点を結合）|Converts half-width kana to full-width (combining voiced sound marks)|将半角假名转为全角（合并浊音和半浊音符号）|반각 가나를 전각으로 변환(탁점·반탁점 결합)
tip.removeJapaneseSpaces|日本語と半角英数字の間の半角・全角スペースを削除|Removes half- and full-width spaces between Japanese and Latin letters/digits|删除日文与半角字母数字之间的半角和全角空格|일본어와 반각 영숫자 사이의 반각·전각 공백 삭제
tip.addJapaneseSpaces|日本語と半角英数字の間を半角スペース1つに揃える|Puts one half-width space between Japanese and Latin letters/digits|在日文与半角字母数字之间统一为一个半角空格|일본어와 반각 영숫자 사이를 반각 공백 하나로 맞춤
tip.fullwidthWestern|半角英数字・記号・スペースを全角に（カナは保持）|Converts half-width letters, digits, symbols and spaces to full-width (kana are kept)|将半角字母数字、符号和空格转为全角（保留假名）|반각 영숫자·기호·공백을 전각으로(가나는 유지)
tip.halfwidthWestern|全角英数字・記号・スペースを半角に（カナは保持）|Converts full-width letters, digits, symbols and spaces to half-width (kana are kept)|将全角字母数字、符号和空格转为半角（保留假名）|전각 영숫자·기호·공백을 반각으로(가나는 유지)
tip.capitalizeWords|英語の各単語の先頭を大文字、残りを小文字に|Capitalizes the first letter of each English word and lowercases the rest|英文单词首字母大写，其余小写|영어 단어의 첫 글자를 대문자, 나머지를 소문자로
tip.camelCase|hello world → helloWorld（空白・ハイフン・アンダースコア区切りに対応）|hello world → helloWorld (spaces, hyphens and underscores are separators)|hello world → helloWorld（支持空格、连字符和下划线分隔）|hello world → helloWorld(공백·하이픈·밑줄 구분 지원)
tip.titleCase|英語のタイトル形式（先頭・末尾と主要語を大文字に）|English title case (first, last and major words capitalized)|英文标题格式（首尾及主要单词大写）|영어 제목 형식(처음·끝과 주요 단어를 대문자로)
tip.sum|選択範囲の数字を合算し、元の文章の下に空行と合計を追加|Adds up the numbers in the selection and appends a blank line and the total|对所选范围内的数字求和，并在原文下方添加空行和合计|선택 영역의 숫자를 합산하고 원문 아래에 빈 줄과 합계를 추가
tip.wrapLines|文字数を指定して各行を折り返す（既存の改行は保持）|Wraps each line at a set number of characters (existing line breaks are kept)|按指定字数折行（保留现有换行）|지정한 글자 수로 각 줄을 줄 바꿈(기존 줄 바꿈 유지)
tip.toggleDateFormat|yyyy年mm月dd日とyyyy-mm-ddを相互変換（月日を2桁に揃える）|Converts between yyyy年mm月dd日 and yyyy-mm-dd (two-digit month and day)|在 yyyy年mm月dd日 与 yyyy-mm-dd 之间转换（月日补足两位）|yyyy年mm月dd日와 yyyy-mm-dd를 상호 변환(월·일을 두 자리로)
tip.randomLines|行単位でランダムに並べ替え（空行・重複行も保持）|Shuffles lines randomly (blank and duplicate lines are kept)|按行随机排列（保留空行和重复行）|줄 단위로 무작위 정렬(빈 줄·중복 줄 유지)
tip.sortLines|行単位で昇順に並べ替え。すでに昇順なら降順に（数字の大小を考慮）|Sorts lines in ascending order; if already ascending, descending (numbers compared by value)|按行升序排列；已为升序时改为降序（考虑数字大小）|줄을 오름차순으로 정렬, 이미 오름차순이면 내림차순으로(숫자 크기 고려)
tip.uniqueLines|完全に一致する行を削除し、最初の行と順序を保持|Removes exact duplicate lines, keeping the first one and the order|删除完全相同的行，保留第一行及顺序|완전히 같은 줄을 삭제하고 첫 줄과 순서를 유지
tip.joinWestern|空行を残し、本文の改行を半角スペース1つで連結|Joins lines with one space, keeping blank lines|保留空行，用一个半角空格连接正文换行|빈 줄은 남기고 본문 줄 바꿈을 반각 공백 하나로 연결
tip.join|空行を区切りとして残し、本文の改行を削除して連結|Removes line breaks within paragraphs, keeping blank lines as separators|保留空行作为分隔，删除正文换行并连接|빈 줄을 구분으로 남기고 본문 줄 바꿈을 삭제하여 연결
tip.joinAll|空行も含むすべての改行を削除して連結|Removes every line break, including blank lines|删除包括空行在内的所有换行并连接|빈 줄을 포함한 모든 줄 바꿈을 삭제하여 연결
tip.beautify|HTMLのブロック要素間に改行と2スペースのインデントを追加（インライン本文・コードは保持）|Adds line breaks and 2-space indents between HTML block elements (inline text and code are kept)|在 HTML 块元素间添加换行和两个空格缩进（保留行内文本和代码）|HTML 블록 요소 사이에 줄 바꿈과 2칸 들여쓰기 추가(인라인 본문·코드 유지)
tip.minify|HTMLのコメント・空白・属性・省略可能な終了タグを圧縮（インライン要素間の空白とコード本文は保護）|Compresses HTML comments, whitespace, attributes and optional end tags (spaces between inline elements and code are protected)|压缩 HTML 注释、空白、属性和可省略的结束标签（保护行内元素间空白和代码）|HTML 주석·공백·속성·생략 가능한 종료 태그 압축(인라인 요소 사이 공백과 코드는 보호)
tip.removeBlankLines|空白・タブだけの行を含む空行を削除|Removes blank lines, including lines with only spaces or tabs|删除空行（包括仅含空格或制表符的行）|공백·탭만 있는 줄을 포함한 빈 줄 삭제
tip.spaceLines|既存の空行を整理し、各行の間に空行を1つ入れる|Tidies existing blank lines and puts one blank line between lines|整理现有空行，在各行之间插入一个空行|기존 빈 줄을 정리하고 각 줄 사이에 빈 줄을 하나 넣음
tip.addPeriod|各行の末尾に。を付ける（すでにある場合は重複させない）|Adds 。 to the end of each line (not duplicated)|在每行末尾添加。（已有时不重复）|각 줄 끝에 。를 추가(이미 있으면 중복하지 않음)
tip.removePeriod|各行の末尾の。を削除（文中は保持）|Removes 。 at the end of each line (kept within sentences)|删除每行末尾的。（保留句中的）|각 줄 끝의 。를 삭제(문장 중간은 유지)
tip.addCommas|数値の整数部分を3桁ごとにカンマで区切る|Groups the integer part of numbers with commas every three digits|用逗号每三位分隔数字的整数部分|숫자의 정수 부분을 세 자리마다 쉼표로 구분
tip.removeCommas|数値の桁区切りカンマを削除する|Removes digit-grouping commas from numbers|删除数字中的千位分隔逗号|숫자의 자릿수 구분 쉼표 삭제
tip.removeList|行頭の番号や箇条書き記号を削除|Removes numbers and bullet markers at the start of lines|删除行首的编号和项目符号|줄 앞의 번호나 글머리 기호 삭제
tip.number|Control＋1：1. ／ Control＋Option＋1：［1］|Control+1: 1. / Control+Option+1: ［1］|Control+1：1. ／ Control+Option+1：［1］|Control+1: 1. / Control+Option+1: ［1］
tip.alphabet|Control＋4：A. ／ Control＋Option＋4：［A］|Control+4: A. / Control+Option+4: ［A］|Control+4：A. ／ Control+Option+4：［A］|Control+4: A. / Control+Option+4: ［A］
tip.specialLists|その他のリスト：別ウインドウでリストの種類を選んで適用|More Lists: choose a list style in a separate window and apply it|更多列表：在单独窗口中选择列表类型并应用|기타 목록: 별도 윈도우에서 목록 종류를 선택하여 적용
tip.specialTypography|まとめて整形：項目を選んでまとめて適用|Batch Formatting: choose items and apply them together|批量整理：选择项目并一次应用|일괄 정리: 항목을 선택하여 한꺼번에 적용
hotkey.none|無効|None|无|없음
hotkey.plus|＋|+|+|+
hotkey.keypad|テンキー|Keypad|小键盘|키패드
hotkey.toggleDisplay|表示形式を切り替え|Switch Button Style|切换按钮样式|버튼 스타일 전환
hotkey.menuFailure|（登録失敗：%@）| (registration failed: %@)|（注册失败：%@）| (등록 실패: %@)
hotkey.scopeSuffix|（%@）| (%@)|（%@）| (%@)
hotkey.scopeItem|適用範囲：%@|Scope: %@|适用范围：%@|적용 범위: %@
hotkey.enable|ホットキーを有効にする|Enable Hotkeys|启用快捷键|단축키 활성화
hotkey.pause|一時停止|Pause|暂停|일시 정지
hotkey.pauseUntilRelaunch|一時停止（再起動で解除）|Pause (until relaunch)|暂停（重新启动后解除）|일시 정지(다시 시작하면 해제)
hotkey.reset|割り当てを初期値に戻す|Reset to Default Assignments|将分配恢复为默认值|할당을 기본값으로 재설정
hotkey.failureNote|登録失敗：ほかのキーを選んでください|Registration failed: choose another key|注册失败：请选择其他按键|등록 실패: 다른 키를 선택하세요
hotkey.note|修飾キーとキーを選び「適用」で保存します。「無効」を選ぶと解除できます。同じキーを複数の操作には割り当てられません。登録失敗時は別のキーを選んでください。操作名の下の適用範囲は選ぶとすぐ保存します。「パレット表示中のみ」はパレットを隠している間はキーを登録せず、前面のアプリへそのまま通します。|Choose modifier keys and a key, then click Apply to save. Choose None to remove a hotkey. The same key cannot be assigned to more than one action. If registration fails, choose another key. The scope under each action name is saved as soon as you choose it. “Only While Palette Is Shown” leaves the key unregistered while the palette is hidden, so it goes straight to the front app.|选择修饰键和按键，然后点击“应用”保存。选择“无”可取消分配。同一按键不能分配给多个操作。注册失败时请选择其他按键。操作名称下方的适用范围在选择后立即保存。“仅在显示面板时”在面板隐藏期间不注册按键，按键会直接传给前台应用。|수정자 키와 키를 선택하고 ‘적용’을 눌러 저장합니다. ‘없음’을 선택하면 해제됩니다. 같은 키를 여러 동작에 할당할 수 없습니다. 등록에 실패하면 다른 키를 선택하세요. 동작 이름 아래의 적용 범위는 선택하는 즉시 저장됩니다. ‘팔레트가 표시된 동안만’은 팔레트가 숨겨진 동안 키를 등록하지 않으므로 키가 앞쪽 앱으로 그대로 전달됩니다.
hotkey.axScope|%@の適用範囲|Scope for %@|%@的适用范围|%@ 적용 범위
hotkey.scopeTip|このホットキーが働く範囲。選ぶとすぐ保存します|Where this hotkey works. Saved as soon as you choose.|此快捷键的作用范围。选择后立即保存|이 단축키가 작동하는 범위. 선택하는 즉시 저장됩니다
hotkey.rowFailure|登録失敗（%@）：別のキーを選んでください|Registration failed (%@): choose another key|注册失败（%@）：请选择其他按键|등록 실패(%@): 다른 키를 선택하세요
hotkey.axKey|%@のキー|Key for %@|%@的按键|%@ 키
hotkey.apply|適用|Apply|应用|적용
hotkey.axApply|%@に適用|Apply %@|应用到%@|%@에 적용
hotkey.reservedTitle|%@は標準の操作に使われているため設定できません。|%@ is used by a standard command and cannot be assigned.|%@用于标准操作，无法设置。|%@은(는) 표준 명령에 사용되므로 설정할 수 없습니다.
hotkey.reservedDetail|⌘A（すべてを選択）・⌘Z（取り消す）・⌘X（カット）・⌘C（コピー）・⌘V（ペースト）・⌘W（閉じる）・⌘,（設定）・⌘Q（終了）は使用できません。Control・Option・Shiftを組み合わせてください。|⌘A (Select All), ⌘Z (Undo), ⌘X (Cut), ⌘C (Copy), ⌘V (Paste), ⌘W (Close), ⌘, (Settings) and ⌘Q (Quit) cannot be used. Add Control, Option or Shift.|不能使用 ⌘A（全选）、⌘Z（撤销）、⌘X（剪切）、⌘C（拷贝）、⌘V（粘贴）、⌘W（关闭）、⌘,（设置）和 ⌘Q（退出）。请组合 Control、Option 或 Shift。|⌘A(전체 선택), ⌘Z(실행 취소), ⌘X(잘라내기), ⌘C(복사하기), ⌘V(붙여넣기), ⌘W(닫기), ⌘,(설정), ⌘Q(종료)는 사용할 수 없습니다. Control, Option, Shift를 조합하세요.
hotkey.needModifier|Control・Option・Commandのいずれかを選んでください。|Choose Control, Option or Command.|请选择 Control、Option 或 Command 中的一个。|Control, Option, Command 중 하나를 선택하세요.
hotkey.inUse|このホットキーは別の操作に割り当てられています。|This hotkey is already assigned to another action.|此快捷键已分配给其他操作。|이 단축키는 다른 동작에 할당되어 있습니다.
scope.global|すべてのアプリ|All Apps|所有应用|모든 앱
scope.palette|パレット表示中のみ|Only While Palette Is Shown|仅在显示面板时|팔레트가 표시된 동안만
palette.enableShortcut|パレットを前面に出すホットキーを有効にする|Enable the shortcut that brings the palette to the front|启用将面板置于前面的快捷键|팔레트를 앞으로 가져오는 단축키 활성화
palette.axModifiers|パレット呼び出しの修飾キー|Modifier keys for showing the palette|调出面板的修饰键|팔레트 호출 수정자 키
palette.axKey|パレット呼び出しのキー|Key for showing the palette|调出面板的按键|팔레트 호출 키
palette.initFailed|ホットキーの初期化に失敗しました（%@）。|Could not initialize the shortcut (%@).|快捷键初始化失败（%@）。|단축키를 초기화하지 못했습니다(%@).
palette.bringToFront|パレットを前面に出す|Bring palette to front|将面板置于前面|팔레트를 앞으로 가져오기
palette.shortcutTitle|パレット呼び出し|Show palette|调出面板|팔레트 호출
palette.shortcutNote|MightyEditが常駐している間、ほかのアプリからパレットを呼び出せます。未起動のアプリを起動する機能ではありません。機能実行用ホットキーの無効化・一時停止とは別に動作します。|While MightyEdit is running, you can bring up the palette from any app. This does not launch MightyEdit when it is not running. It works independently of disabling or pausing the action hotkeys.|MightyEdit 在后台运行时，可从其他应用调出面板。此功能不会启动未运行的应用，并且与停用或暂停功能快捷键无关。|MightyEdit가 실행 중인 동안 다른 앱에서 팔레트를 불러올 수 있습니다. 실행 중이 아닌 앱을 실행하는 기능은 아닙니다. 기능 단축키의 비활성화·일시 정지와는 별도로 작동합니다.
palette.resetShortcut|初期値（⌃⌥⌘U）に戻す|Reset to Default (⌃⌥⌘U)|恢复默认值（⌃⌥⌘U）|기본값(⌃⌥⌘U)으로 재설정
palette.resident|ウインドウを閉じても常駐|Keep running after closing|关闭窗口后继续运行|창을 닫아도 계속 실행
palette.residentNote|パレットを閉じてもMightyEditを終了せず、メニューバーから再表示できます。オフのときは閉じるボタンで終了します。|Closing the palette keeps MightyEdit running; show it again from the menu bar. When off, the close button quits MightyEdit.|关闭面板后 MightyEdit 不会退出，可从菜单栏再次显示。关闭此选项时，点击关闭按钮会退出。|팔레트를 닫아도 MightyEdit는 종료되지 않으며 메뉴 막대에서 다시 표시할 수 있습니다. 끄면 닫기 버튼으로 종료합니다.
status.disabled|無効|Disabled|已停用|비활성화됨
palette.notInitialized|初期化に失敗しています。再起動してください。|Initialization failed. Relaunch MightyEdit.|初始化失败。请重新启动。|초기화에 실패했습니다. 다시 시작하세요.
palette.enabledStatus|有効：%@|Enabled: %@|已启用：%@|활성화됨: %@
palette.registerFailed|登録失敗（%@）：ほかのホットキーを選んでください。|Registration failed (%@): choose another shortcut.|注册失败（%@）：请选择其他快捷键。|등록 실패(%@): 다른 단축키를 선택하세요.
excluded.title|対象外アプリ|Excluded Apps|排除的应用|제외된 앱
excluded.reason|対象外のアプリのため実行しません|Not run because this app is excluded|此应用已被排除，不执行|제외된 앱이므로 실행하지 않습니다
excluded.explanation|一覧のアプリが前面のときは、文字の加工を実行せず、機能とパレット呼び出しのホットキーを解除してキー操作をそのアプリへ通します。ほかのアプリへ切り替えると元に戻ります。一覧から外してもアプリ本体には影響しません。|While an app in this list is in front, MightyEdit does not convert text and releases its action hotkeys and palette shortcut so keystrokes go to that app. Switching to another app restores them. Removing an app from the list does not affect the app itself.|当列表中的应用位于前台时，不处理文字，并解除功能快捷键和调出面板的快捷键，按键直接传给该应用。切换到其他应用后恢复。从列表中移除不会影响应用本身。|목록의 앱이 앞쪽에 있을 때는 텍스트를 변환하지 않고 기능 단축키와 팔레트 호출 단축키를 해제하여 키 입력을 그 앱에 전달합니다. 다른 앱으로 전환하면 원래대로 돌아갑니다. 목록에서 제거해도 앱 자체에는 영향이 없습니다.
excluded.column|アプリ|App|应用|앱
excluded.axList|対象外アプリの一覧|List of excluded apps|排除的应用列表|제외된 앱 목록
excluded.add|追加…|Add…|添加…|추가…
excluded.remove|一覧から外す|Remove from List|从列表中移除|목록에서 제거
excluded.none|対象外のアプリはありません。|No apps are excluded.|没有排除的应用。|제외된 앱이 없습니다.
excluded.count|%@個のアプリを対象外にしています。|%@ app(s) excluded.|已排除 %@ 个应用。|앱 %@개를 제외하고 있습니다.
excluded.missing|アプリが見つかりません|App not found|找不到应用|앱을 찾을 수 없음
excluded.pickerTitle|対象外にするアプリを選択|Choose Apps to Exclude|选择要排除的应用|제외할 앱 선택
action.add|追加|Add|添加|추가
excluded.duplicate|「%@」はすでに一覧にあります。|“%@” is already in the list.|“%@”已在列表中。|‘%@’은(는) 이미 목록에 있습니다.
excluded.own|MightyEdit自身は追加できません。MightyEditが前面のときは、もともとホットキーを解除しています。|MightyEdit itself cannot be added. Its hotkeys are already released while MightyEdit is in front.|不能添加 MightyEdit 本身。MightyEdit 位于前台时本来就会解除快捷键。|MightyEdit 자체는 추가할 수 없습니다. MightyEdit가 앞쪽에 있을 때는 원래 단축키를 해제합니다.
excluded.invalid|「%@」はBundle IDを読み取れないため追加できません。|“%@” cannot be added because its bundle ID cannot be read.|无法读取“%@”的 Bundle ID，因此无法添加。|‘%@’은(는) Bundle ID를 읽을 수 없어 추가할 수 없습니다.
excluded.rejectedTitle|追加できないアプリがありました|Some apps could not be added|部分应用无法添加|추가할 수 없는 앱이 있습니다
auto.heading|指定アプリでパレットを自動表示|Show the Palette Automatically in Chosen Apps|在指定应用中自动显示面板|지정한 앱에서 팔레트 자동 표시
auto.enable|自動表示を有効にする|Enable auto show|启用自动显示|자동 표시 활성화
auto.explanation|指定したアプリを前面にすると、パレットを表示します。MightyEditが起動している間に動作します。|Shows the palette when a chosen app comes to the front. Works while MightyEdit is running.|当指定的应用切换到前台时显示面板。在 MightyEdit 运行期间有效。|지정한 앱이 앞쪽으로 오면 팔레트를 표시합니다. MightyEdit가 실행 중인 동안 작동합니다.
auto.addApp|アプリを追加…|Add App…|添加应用…|앱 추가…
auto.addRunning|起動中のアプリから追加|Add from Running Apps|从正在运行的应用中添加|실행 중인 앱에서 추가
auto.behavior|閉じたパレットも、対象アプリに切り替えると再表示します。別のアプリへ切り替えるとパレットを隠します。呼び出し直すと、そのアプリが新しい対象になります。MightyEdit終了中の起動やログイン時の起動を行う設定ではありません。|A closed palette reappears when you switch to a chosen app and hides when you switch to another app. Showing the palette again makes that app the new target. This setting does not launch MightyEdit when it is not running or at login.|即使面板已关闭，切换到目标应用时也会再次显示；切换到其他应用时隐藏面板。重新调出时，该应用成为新的目标。此设置不会在 MightyEdit 未运行时或登录时启动它。|닫은 팔레트도 대상 앱으로 전환하면 다시 표시되고 다른 앱으로 전환하면 숨겨집니다. 다시 불러오면 그 앱이 새 대상이 됩니다. MightyEdit가 실행 중이 아닐 때나 로그인 시 실행하는 설정은 아닙니다.
auto.removeApp|一覧から削除|Remove|从列表中删除|목록에서 삭제
auto.empty|対象アプリを追加してください。|Add the apps to watch.|请添加目标应用。|대상 앱을 추가하세요.
auto.count|%1$@個のアプリを登録済み。自動表示は%2$@です。|%1$@ app(s) added. Auto show is %2$@.|已登记 %1$@ 个应用。自动显示：%2$@。|앱 %1$@개 등록됨. 자동 표시: %2$@.
state.on|オン|on|开|켬
state.off|オフ|off|关|끔
auto.pickerTitle|自動表示の対象アプリを選択|Choose Apps for Auto Show|选择自动显示的目标应用|자동 표시 대상 앱 선택
auto.invalid| 識別情報のないアプリは追加できませんでした。| Apps without a bundle identifier could not be added.| 无法添加没有标识信息的应用。| 식별 정보가 없는 앱은 추가할 수 없었습니다.
auto.noneRunning|追加できるアプリがありません|No apps to add|没有可添加的应用|추가할 수 있는 앱이 없습니다
lines.affixNote|空行も対象。末尾の改行は保持します。|Blank lines are included. A trailing line break is kept.|包括空行。保留末尾换行。|빈 줄도 포함됩니다. 끝의 줄 바꿈은 유지합니다.
lines.countTitle|文字数・行数|Characters and Lines|字数和行数|글자 수·줄 수
lines.prefix|先頭に追加|Add at start|添加到开头|앞에 추가
lines.suffix|末尾に追加|Add at end|添加到结尾|끝에 추가
action.applySelection|選択テキストに適用|Apply to Selected Text|应用到所选文本|선택한 텍스트에 적용
stats.body|文字数（改行を除く）：%1$@\n文字数（空白・改行を除く）：%2$@\n行数：%3$@\n\n絵文字・結合文字は見た目の1文字として数えます。末尾の改行は空行として数えません。|Characters (excluding line breaks): %1$@\nCharacters (excluding spaces and line breaks): %2$@\nLines: %3$@\n\nEmoji and combined characters count as one visible character. A trailing line break is not counted as a blank line.|字数（不含换行）：%1$@\n字数（不含空白和换行）：%2$@\n行数：%3$@\n\n表情符号和组合字符按视觉上的 1 个字符计数。末尾换行不计为空行。|글자 수(줄 바꿈 제외): %1$@\n글자 수(공백·줄 바꿈 제외): %2$@\n줄 수: %3$@\n\n이모지와 결합 문자는 보이는 대로 한 글자로 셉니다. 끝의 줄 바꿈은 빈 줄로 세지 않습니다.
special.kind|リストの種類|List style|列表类型|목록 종류
special.feedback|対象アプリで文字を選択し、リストの種類をクリックすると適用します。|Select text in the target app, then click a list style to apply it.|在目标应用中选择文字，然后点击列表类型即可应用。|대상 앱에서 텍스트를 선택한 다음 목록 종류를 클릭하면 적용됩니다.
special.noneEnabled|設定で利用する機能をオンにしてください。|Turn on the formats to use in Settings.|请在设置中打开要使用的功能。|설정에서 사용할 기능을 켜세요.
special.sample|バナナ\nりんご\nパイナップル|Banana\nApple\nPineapple|香蕉\n苹果\n菠萝|바나나\n사과\n파인애플
action.selectFirst|対象アプリで文字を選択してから適用してください。|Select text in the target app, then apply.|请先在目标应用中选择文字再应用。|대상 앱에서 텍스트를 선택한 후 적용하세요.
wrap.presets|文字数のプリセット…|Character Count Presets…|字数预设…|글자 수 프리셋…
wrap.axCount|改行する文字数|Characters per line|每行字数|줄당 글자 수
wrap.axStepper|文字数を増減|Increase or decrease the character count|增减字数|글자 수 늘리기/줄이기
wrap.note|▲▼で1文字ずつ調整（1〜10,000文字）。\n既存の改行を残し、絵文字も1文字として数えます。|Use ▲▼ to adjust by one character (1–10,000).\nExisting line breaks are kept; an emoji counts as one character.|使用 ▲▼ 逐字调整（1–10,000 个字符）。\n保留现有换行，表情符号也计为 1 个字符。|▲▼로 한 글자씩 조정(1–10,000자).\n기존 줄 바꿈은 유지하며 이모지도 한 글자로 셉니다.
wrap.every|%@文字ごと|Every %@ characters|每 %@ 个字符|%@자마다
typo.narrowAlphanumerics|全角英数字を半角に|Full-width Letters/Digits to Half-width|全角字母数字转半角|전각 영숫자를 반각으로
typo.widenKana|半角カナを全角に|Half-width Kana to Full-width|半角假名转全角|반각 가나를 전각으로
typo.removeJapaneseSpaces|和欧間のスペースを削除|Remove Japanese–Latin Spaces|删除日文与西文间空格|일본어·로마자 사이 공백 삭제
typo.trimBracketSpaces|括弧内側の空白を削除|Remove Spaces Inside Brackets|删除括号内侧的空白|괄호 안쪽 공백 삭제
typo.timeColon|時刻の：を半角に|Half-width “：” in Times|将时刻中的“：”转为半角|시각의 ‘：’를 반각으로
typo.parentheticalPeriod|本文。（補足）。 → 本文（補足）。|Text。（Note）。 → Text（Note）。|正文。（补充）。 → 正文（补充）。|본문。（보충）。 → 본문（보충）。
typo.correctLongVowel|長音記号を修正|Fix Long Vowel Marks|修正长音符号|장음 기호 수정
typo.widenPunctuation|半角の句読点・括弧を全角に|Half-width Punctuation/Brackets to Full-width|半角标点和括号转全角|반각 구두점·괄호를 전각으로
typo.choose|適用する整形（複数選択）|Formatting to Apply (multiple)|要应用的整理（可多选）|적용할 정리(복수 선택)
typo.tipLongVowel|カタカナ直後の - ‐ ‑ – — ― − ｰ ─ を ー に|Changes - ‐ ‑ – — ― − ｰ ─ right after katakana to ー|将片假名后的 - ‐ ‑ – — ― − ｰ ─ 改为 ー|가타카나 바로 뒤의 - ‐ ‑ – — ― − ｰ ─ 를 ー로
typo.tipPunctuation|｡､ → 。、 ／ () → （） ／ ｢｣ → 「」。英字のピリオド・カンマは保持|｡､ → 。、 / () → （） / ｢｣ → 「」. Periods and commas in English text are kept|｡､ → 。、 ／ () → （） ／ ｢｣ → 「」。保留英文的句点和逗号|｡､ → 。、 / () → （） / ｢｣ → 「」. 영문의 마침표·쉼표는 유지
typo.sampleBefore|サンプル（整形前）|Sample (before)|示例（整理前）|샘플(정리 전)
typo.sampleAfter|サンプル（整形後）|Sample (after)|示例（整理后）|샘플(정리 후)
'''

def parse(text):
    table = []
    for line in text.strip('\n').splitlines():
        cells = line.split('|')
        if len(cells) != 5:
            sys.exit(f'bad row ({len(cells)} cells): {line[:60]}')
        table.append([cells[0]] + [c.replace('\\n', '\n') for c in cells[1:]])
    return table

table = parse(rows)
keys = [r[0] for r in table]
dupes = {k for k in keys if keys.count(k) > 1}
if dupes:
    sys.exit(f'duplicate keys: {sorted(dupes)}')

PLACEHOLDER = re.compile(r'%(?:\d+\$)?[@dlsf]')
for r in table:
    expected = sorted(PLACEHOLDER.findall(r[1]))
    for lang, value in zip(LANGS, r[1:]):
        if not value.strip():
            sys.exit(f'empty {lang} value: {r[0]}')
        if sorted(PLACEHOLDER.findall(value)) != expected:
            sys.exit(f'placeholder mismatch {lang} {r[0]}')
        if len(PLACEHOLDER.findall(value)) > 1 and re.search(r'%[@dlsf]', value):
            sys.exit(f'use positional specifiers for several arguments: {lang} {r[0]}')

def strings_literal(value):
    return json.dumps(value, ensure_ascii=False)

for index, lang in enumerate(LANGS, 1):
    folder = root / 'Resources' / f'{lang}.lproj'
    folder.mkdir(parents=True, exist_ok=True)
    body = '\n'.join(f'{strings_literal(r[0])} = {strings_literal(r[index])};' for r in table) + '\n'
    (folder / 'Localizable.strings').write_text(body, encoding='utf-8')
    help_source = root / 'Localization' / 'Help' / f'{lang}.txt'
    if not help_source.is_file() or not help_source.read_text(encoding='utf-8').strip():
        sys.exit(f'missing help: {help_source}')
    (folder / 'Help.txt').write_bytes(help_source.read_bytes())

def swift_literal(value):
    return json.dumps(value, ensure_ascii=False)

fallback = ['// Generated by make-resources.py. Do not edit.',
            '// Japanese UI text for binaries without the app bundle (unit tests).',
            'enum LocalizationFallback {',
            '    static let japanese: [String: String] = [']
fallback += [f'        {swift_literal(r[0])}: {swift_literal(r[1])},' for r in table]
fallback += ['    ]', '}', '']
target = root / 'Source' / 'LocalizationFallback.swift'
text = '\n'.join(fallback)
if not target.exists() or target.read_text(encoding='utf-8') != text:
    target.write_text(text, encoding='utf-8')
print(f'{len(table)} keys x {len(LANGS)} languages')
