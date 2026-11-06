# -*- coding: utf-8 -*-
from pathlib import Path
import json
root = Path(__file__).parent
APP = 'TermTally'
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''
heading|語句の件数を数えて表記を統一|Count Terms and Unify Spelling|统计词语并统一写法|용어를 세고 표기를 통일
subtitle|テキストエディットやGoogleドキュメントで開いている文書のすべての文字を対象に、該当箇所を一覧しながら表記の揺れを統一します。|Searches all the text of the document open in TextEdit or Google Docs, lists the matches, and unifies spelling variants.|以“文本编辑”或 Google 文档中打开的文稿全部文字为对象，列出匹配位置并统一写法差异。|텍스트 편집기나 Google 문서에서 연 문서의 모든 글자를 대상으로, 해당 위치를 나열하며 표기 차이를 통일합니다.
aboutDetail|語句の件数を数え、表記の揺れを統一します。サポート：同梱のREADME.md|Counts terms and unifies spelling variants. Support: bundled README.md|统计词语并统一写法差异。支持：内置的 README.md|용어를 세고 표기 차이를 통일합니다. 지원: 포함된 README.md
sharing.note|検索のオプションと一覧の表示、該当文字の色、ウインドウを手前に表示する設定を同期します。語句は同期しません。|Syncs the search options, the list display, the match color and keeping the window on top. Terms are not synced.|同步搜索选项、列表显示、匹配文字颜色以及窗口保持在最前的设置。词语不同步。|검색 옵션, 목록 표시, 해당 글자 색, 윈도우를 항상 위에 두는 설정을 동기화합니다. 용어는 동기화하지 않습니다.
displayTab|表示|Display|显示|표시
matchInRed|該当文字に色を付ける|Color the matches|为匹配文字着色|해당 글자에 색 입히기
matchColor|該当文字の色|Match Color|匹配文字的颜色|해당 글자 색
matchColor.reset|赤に戻す|Back to Red|恢复红色|빨간색으로 되돌리기
matchInRedDetail|該当箇所の一覧で、見つかった文字を選んだ色の太字にします。オフにすると太字だけになります。除外した行と選択中の行には色が付きません。初期値の赤はダークモードに合わせて変わりますが、選んだ色は変わりません。|Shows the found text in bold in the chosen color in the match list. When off, it is only bold. Excluded and selected rows are not colored. The default red adapts to Dark Mode; a chosen color does not.|在匹配位置列表中将找到的文字显示为所选颜色的粗体。关闭后仅为粗体。已排除的行和选中的行不着色。默认红色随深色模式变化，所选颜色不变。|해당 위치 목록에서 찾은 글자를 고른 색의 굵은 글씨로 표시합니다. 끄면 굵게만 표시됩니다. 제외한 행과 선택한 행에는 색을 입히지 않습니다. 기본 빨간색은 다크 모드에 맞춰 바뀌지만 고른 색은 바뀌지 않습니다.
alwaysOnTop|ウインドウをほかのアプリより手前に表示する|Keep the window in front of other apps|窗口保持在其他应用之前|윈도우를 다른 앱보다 앞에 표시
alwaysOnTopDetail|対象の文書を見ながら操作できるよう、初期値はオンです。オフにすると普通のウインドウになります。|On by default, so you can work while looking at the document. When off, it is an ordinary window.|默认打开，以便一边查看文稿一边操作。关闭后是普通窗口。|대상 문서를 보면서 작업할 수 있도록 기본으로 켜져 있습니다. 끄면 일반 윈도우가 됩니다.
panel.keywords|語句（◉＝統一先）|Terms (◉ = Unify Target)|词语（◉＝统一目标）|용어(◉=통일 대상)
panel.target|対象|Document|对象|대상
panel.options|オプション|Options|选项|옵션
panel.matches|該当箇所|Matches|匹配位置|해당 위치
field.total|合計 :|Total:|合计：|합계:
field.contextLength|前後の文字数 :|Characters Around:|前后字数：|앞뒤 글자 수:
field.changeTo|個別に書き替え :|Rewrite This One:|逐个改写：|개별로 고쳐 쓰기:
column.paragraph|段落|Para.|段落|단락
column.context|前後の文字|Context|前后文字|앞뒤 글자
option.caseSensitive|大文字と小文字を区別|Case Sensitive|区分大小写|대소문자 구분
option.wholeWord|単語単位|Whole Word|全字匹配|단어 단위
option.excludeContained|ほかの語句に含まれる分は数えない|Do not count matches inside other terms|不计入其他词语中包含的部分|다른 용어에 포함된 것은 세지 않음
option.withinParagraph|段落内に限る|Within Paragraph|限于段落内|단락 안으로 한정
target.docs|Googleドキュメント|Google Docs|Google 文档|Google 문서
target.none|テキストエディットの書類かGoogleドキュメントをクリックしてください。|Click a TextEdit document or a Google Docs page.|请点按“文本编辑”的文稿或 Google 文档页面。|텍스트 편집기 문서나 Google 문서 페이지를 클릭하세요.
target.unsupported|%@ の文字は読み取れません。テキストエディットの書類かGoogleドキュメントをクリックしてください。|Cannot read the text of %@. Click a TextEdit document or a Google Docs page.|无法读取 %@ 的文字。请点按“文本编辑”的文稿或 Google 文档页面。|%@의 글자를 읽을 수 없습니다. 텍스트 편집기 문서나 Google 문서 페이지를 클릭하세요.
target.hint|最後に使っていた文書が対象です。［検索］を押すと、その時点のすべての文字を読み取ります。|The document you used last. Find reads all its text at that moment.|目标是最后使用的文稿。按“搜索”时读取当时的全部文字。|마지막에 사용한 문서가 대상입니다. [검색]을 누르면 그 시점의 모든 글자를 읽습니다.
button.loadSelection|選択文字を取り込む|Load Selection|载入所选文字|선택 글자 가져오기
button.collectVariants|揺れ候補を拾う|Find Variants|查找写法差异|표기 차이 찾기
tip.collectVariants|文書のすべての文字を読み取り、同じ語の表記違いと、辞書にある揺れを一覧にします。|Reads all the text of the document and lists words written in more than one way, including the variants in the dictionary.|读取文稿全部文字，列出同一个词的不同写法及词典中的写法差异。|문서의 모든 글자를 읽어 같은 단어의 다른 표기와 사전에 있는 표기 차이를 나열합니다.
status.variants|揺れ候補が %d 組見つかりました。組を選ぶと語句に入ります。|Found %d groups of variants. Pick one to use it as the terms.|找到 %d 组写法差异。选择一组即可填入词语栏。|표기 차이 %d묶음을 찾았습니다. 묶음을 고르면 용어에 들어갑니다.
status.variantsMore|欄の数に合わせて上位 %1$d 件を入れました（ほかに %2$d 件あります）|Used the top %1$d spellings (%2$d more did not fit)|已填入前 %1$d 种写法（另有 %2$d 种）|상위 %1$d개를 넣었습니다(%2$d개 더 있습니다)
status.noVariants|揺れ候補は見つかりませんでした。|No variants found.|未找到写法差异。|표기 차이를 찾지 못했습니다.
panel.variants|揺れ候補|Variants|写法差异|표기 차이
variants.empty|ボタンを押すと、文書の中で表記が揺れている語を一覧にします。|Click the button to list the words written in more than one way in the document.|按下按钮可列出文稿中写法不一的词。|버튼을 누르면 문서에서 표기가 흔들리는 단어를 나열합니다.
tip.variantList|組を選ぶと語句欄に入り、該当箇所を表示します。太字の表記が統一先になります（前回の統一先、辞書の推奨、いちばん多い表記の順）。|Pick a group to put it in the term fields and show the matches. The bold spelling becomes the unify target (the last one used, the dictionary's, then the most used).|选择一组可填入词语栏并显示匹配位置。粗体写法成为统一目标（依次为上次使用、词典推荐、最常用）。|묶음을 고르면 용어 칸에 들어가고 해당 위치를 표시합니다. 굵은 표기가 통일 대상이 됩니다(지난번 대상, 사전 추천, 가장 많은 표기 순).
kind.all|すべて|All|全部|모두
kind.katakana|カタカナ|Katakana|片假名|가타카나
kind.kanji|漢字|Kanji|汉字|한자
kind.latin|英数字|Latin|英文数字|영문·숫자
kind.suru|する／をする|する／をする|する／をする|する／をする
kind.review|要確認|To Review|需确认|확인 필요
kind.dictionary|辞書|Dictionary|词典|사전
sort.frequent|多い順|Most first|从多到少|많은 순
sort.rare|少ない順|Fewest first|从少到多|적은 순
variants.filter|種類|Kind|类型|종류
variants.sort|並び順|Order|顺序|순서
tip.variantFilter|一覧に出す組の種類を絞ります。|Limits the list to one kind of group.|按类型筛选列表。|목록을 종류별로 좁힙니다.
tip.variantSort|組の並び順を、出現数の多い順か少ない順にします。|Orders the groups by how often they appear.|按出现次数排列各组。|묶음을 나타난 횟수로 정렬합니다.
button.ignore|無視|Ignore|忽略|무시
tip.ignore|選んだ組を、次からどの文書でも出さないようにします。設定の「辞書」で元に戻せます。|Stops showing the selected group in any document. Undo this under Dictionary in Settings.|今后在任何文稿中都不再显示所选组。可在设置的“词典”中恢复。|고른 묶음을 앞으로 어떤 문서에서도 표시하지 않습니다. 설정의 [사전]에서 되돌릴 수 있습니다.
button.copyTable|一覧をコピー|Copy Table|拷贝列表|목록 복사
tip.copyTable|表示している組を、組・表記・件数・統一先の表としてコピーします。表計算アプリに貼り付けられます。|Copies the groups shown as a table of group, spelling, count and target, ready to paste into a spreadsheet.|将显示的组拷贝为组、写法、件数、统一目标的表格，可粘贴到电子表格。|표시 중인 묶음을 묶음, 표기, 건수, 통일 대상 표로 복사합니다. 스프레드시트에 붙여넣을 수 있습니다.
export.group|組|Group|组|묶음
export.spelling|表記|Spelling|写法|표기
export.count|件数|Count|件数|건수
export.target|統一先|Target|统一目标|통일 대상
status.copied|%d 組を表としてコピーしました|Copied %d groups as a table|已将 %d 组拷贝为表格|%d묶음을 표로 복사했습니다
status.bulk|Googleドキュメントの［すべて置換］で一度に置き換えました。⌘Z 1回で戻せます。|Replaced at once with Replace all in Google Docs. One ⌘Z undoes it.|已用 Google 文档的“全部替换”一次替换。按一次 ⌘Z 可恢复。|Google 문서의 [모두 바꾸기]로 한 번에 바꿨습니다. ⌘Z 한 번으로 되돌릴 수 있습니다.
error.bulkUnavailable|Googleドキュメントの［検索と置換］を操作できませんでした。|Could not use Find and replace in Google Docs.|无法操作 Google 文档的“查找和替换”。|Google 문서의 [찾기 및 바꾸기]를 조작할 수 없습니다.
error.bulkDiffers|置き換えの結果が想定と異なります。Googleドキュメントで内容を確かめ、必要なら ⌘Z で戻してください。|The result differs from what was expected. Check the document and press ⌘Z in Google Docs if needed.|替换结果与预期不同。请在 Google 文档中确认，必要时按 ⌘Z 恢复。|바꾼 결과가 예상과 다릅니다. Google 문서에서 확인하고 필요하면 ⌘Z로 되돌리세요.
dictionaryTab|辞書|Dictionary|词典|사전
dictionary.section|表記ゆれ辞書|Variant Dictionary|写法差异词典|표기 차이 사전
dictionary.bundled|定番の表記ゆれ辞書を使う|Use the common variants dictionary|使用常见写法差异词典|자주 쓰는 표기 차이 사전 사용
dictionary.bundledDetail|誤記の修正、要確認の語、「ください／下さい」のような揺れ、全角半角の記号など %d 組を同梱しています。誤記は正しい表記が文書に無くても拾います。|Bundles %d groups: misspellings, words to review, variants and full-width and half-width symbols. Misspellings are found even when the right spelling is not used.|内置 %d 组：错误写法、需确认的词、写法差异以及全半角符号。即使文稿中没有正确写法，也能找到错误写法。|오기, 확인이 필요한 단어, 표기 차이, 전각·반각 기호 등 %d묶음이 들어 있습니다. 오기는 올바른 표기가 문서에 없어도 찾습니다.
dictionary.user|自分の辞書|Your dictionary|自定义词典|내 사전
dictionary.userDetail|1行に1組です。「誤 → 正」かタブ区切りは誤記の修正で、誤記だけあれば拾います。先頭に ? を付けると要確認になります。読点かコンマで区切ると、両方が使われているときに拾います（先頭が統一先の推奨）。|One group per line. 「wrong → right」 or tab-separated is a correction, found even when only the wrong spelling is used. A leading ? makes it a word to review. Comma-separated spellings are found when two are used (the first is the recommended target).|每行一组。“错误 → 正确”或用制表符分隔表示修正，只有错误写法时也会找到。开头加 ? 表示需确认。用逗号分隔时，两种都使用才会找到（第一个为推荐目标）。|한 줄에 한 묶음입니다. "오기 → 정기" 또는 탭 구분은 수정으로, 오기만 있어도 찾습니다. 앞에 ?를 붙이면 확인 필요가 됩니다. 쉼표로 구분하면 둘 다 쓰일 때 찾습니다(첫 표기가 추천 대상).
rules.section|覚えた統一先|Remembered Targets|已记住的统一目标|기억한 통일 대상
rules.empty|組を選んで統一すると、ここに残り、次回から統一先に選ばれます。|When you unify a group, its target is kept here and chosen next time.|统一某组后，目标会保留在此，下次自动选择。|묶음을 통일하면 대상이 여기에 남고 다음부터 선택됩니다.
ignored.section|無視している組|Ignored Groups|已忽略的组|무시 중인 묶음
ignored.empty|無視している組はありません。|No groups are ignored.|没有已忽略的组。|무시 중인 묶음이 없습니다.
button.remove|削除|Remove|移除|삭제
target.pin|対象アプリを固定|Keep This Document as the Target|固定目标应用|대상 앱 고정
tip.pin|ほかのアプリに切り替えても、対象をこの文書のままにします。|Keeps this document as the target when you switch to other apps.|切换到其他应用时，目标仍保持为此文稿。|다른 앱으로 전환해도 대상을 이 문서로 유지합니다.
target.pinnedHint|ほかのアプリに切り替えても対象は変わりません。Googleドキュメントは、タブを切り替えていると操作できません。|The target stays when you switch apps. Google Docs needs its tab to stay open in front of its window.|切换应用时目标不变。Google 文档的标签页需保持在其窗口最前。|앱을 전환해도 대상은 바뀌지 않습니다. Google 문서는 그 윈도우에서 해당 탭이 앞에 있어야 합니다.
button.unify|すべてを統一…|Unify All…|全部统一…|모두 통일…
button.close|閉じる|Close|关闭|닫기
button.find|検索|Find|搜索|검색
button.stop|中止|Stop|停止|중지
button.show|表示|Show|显示|표시
button.exclude|除外する|Exclude|排除|제외
button.include|除外を解除|Include|取消排除|제외 해제
button.change|置換|Change|替换|바꾸기
button.cancel|キャンセル|Cancel|取消|취소
button.replace|置き換える|Replace|替换|바꾸기
button.openAccessibility|アクセシビリティ設定を開く|Open Accessibility Settings|打开辅助功能设置|손쉬운 사용 설정 열기
tip.keyword|returnキーでも検索します。|Press Return to find.|按 Return 键也可搜索。|Return 키로도 검색합니다.
tip.clearKeyword|語句欄を空にします。Optionキーを押しながらクリックすると、すべての語句欄を空にします。|Clears the term field. Option-click clears all the term fields.|清空词语栏。按住 Option 键点按可清空所有词语栏。|용어 칸을 비웁니다. Option 키를 누른 채 클릭하면 모든 용어 칸을 비웁니다.
tip.unifyTarget|統一先にする語句。［すべてを統一］で、ほかの欄で見つかった文字をこの語句に置き換えます。もう一度押すと外します。|The term to unify to. Unify All replaces the matches of the other fields with it. Click again to clear.|要统一成的词语。“全部统一”会将其他栏找到的文字替换为此词语。再按一次取消。|통일할 용어. [모두 통일]은 다른 칸에서 찾은 글자를 이 용어로 바꿉니다. 다시 누르면 해제합니다.
tip.excludeContained|「取引」と「取引き」のように、長い語句の一部として見つかった分を短い語句の件数から除きます。|When a term is found as part of a longer term, it is not counted for the shorter one.|较长词语中包含的部分不计入较短词语的件数。|긴 용어의 일부로 찾은 것은 짧은 용어의 건수에서 뺍니다.
tip.wholeWord|前後が同じ文字種（英数字・漢字・カタカナ）に続くものを除きます。「仕事」の中の「事」、pineapple の中の apple などです。揺れ候補の組を選ぶと自動でオンになります。|Skips matches that run on into the same script (letters, kanji, katakana), like apple in pineapple. It turns on when you pick a group of variants.|排除前后紧接相同文字类型（英文、汉字、片假名）的匹配，如 pineapple 中的 apple。选择写法差异组时自动打开。|앞뒤가 같은 문자 종류(영문, 한자, 가타카나)로 이어지는 것을 제외합니다. pineapple 안의 apple 등입니다. 표기 차이 묶음을 고르면 자동으로 켜집니다.
tip.contextLength|見つかった文字の前後に表示する文字数|Number of characters shown before and after each match|在匹配文字前后显示的字数|찾은 글자 앞뒤에 표시할 글자 수
tip.withinParagraph|一覧の前後の文字を段落の中だけにします。段落の区切り（¶）と、その先の文字は表示しません。|Keeps the characters around a match inside its paragraph. The paragraph mark (¶) and what lies beyond it are not shown.|列表中的前后文字仅限于段落内。不显示段落标记（¶）及其之外的文字。|목록의 앞뒤 글자를 단락 안으로 한정합니다. 단락 기호(¶)와 그 너머의 글자는 표시하지 않습니다.
tip.check|チェックを外すと除外します。件数と［すべてを統一］の対象から外れます。|Uncheck to exclude the match from the counts and from Unify All.|取消勾选即排除，不计入件数，也不参与“全部统一”。|체크를 해제하면 제외합니다. 건수와 [모두 통일] 대상에서 빠집니다.
tip.list|クリックで、その文字を文書で選択して表示し、［個別に書き替え］に入れます。|Click to select and show the text in the document and put it in Rewrite This One.|点按可在文稿中选择并显示该文字，并填入“逐个改写”。|클릭하면 문서에서 그 글자를 선택해 표시하고 [개별로 고쳐 쓰기]에 넣습니다.
tip.listDocs|クリックで［個別に書き替え］に入れます。ダブルクリックか［表示］で、ブラウザーを前面にしてその文字を選択します。|Click to put the text in Rewrite This One. Double-click or Show brings the browser forward and selects it.|点按可填入“逐个改写”。连按两次或按“显示”可将浏览器置于前台并选择该文字。|클릭하면 [개별로 고쳐 쓰기]에 넣습니다. 더블 클릭이나 [표시]로 브라우저를 앞으로 가져와 그 글자를 선택합니다.
tip.show|一覧で選んだ文字を文書で選択して表示します。|Selects and shows the picked text in the document.|在文稿中选择并显示所选文字。|목록에서 고른 글자를 문서에서 선택해 표시합니다.
tip.exclude|一覧で選んだ行を除外します。除外した行で押すと元に戻します。|Excludes the selected row. Click again on an excluded row to include it.|排除所选行。在已排除的行上再按一次可恢复。|고른 행을 제외합니다. 제외한 행에서 누르면 되돌립니다.
tip.changeTo|一覧で選んだ文字を、この文字に置き換えます。|The text that replaces the match picked in the list.|用此文字替换列表中所选的匹配。|목록에서 고른 글자를 이 글자로 바꿉니다.
tip.change|一覧で選んだ1か所を、［個別に書き替え］の文字に置き換えます。|Changes the match picked in the list to the Rewrite This One text.|将列表中所选的一处替换为“逐个改写”的文字。|목록에서 고른 한 곳을 [개별로 고쳐 쓰기]의 글자로 바꿉니다.
tip.loadSelection|文書で選択している文字を、最後に入力した語句欄（なければ最初の空欄）に入れます。|Puts the text selected in the document into the term field you last typed in, or the first empty one.|将文稿中选中的文字填入最后输入的词语栏（没有则填入第一个空栏）。|문서에서 선택한 글자를 마지막에 입력한 용어 칸(없으면 첫 빈칸)에 넣습니다.
tip.unify|チェックの付いた行を、統一先の語句に置き換えます。|Replaces the checked rows with the unify target.|将已勾选的行替换为统一目标词语。|체크된 행을 통일 대상 용어로 바꿉니다.
tip.find|文書のすべての文字を読み取って語句を検索します（語句欄のreturnキーでも検索）。|Reads all the text of the document and finds the terms (Return in a term field also finds).|读取文稿全部文字并搜索词语（在词语栏按 Return 键也可搜索）。|문서의 모든 글자를 읽어 용어를 검색합니다(용어 칸에서 Return 키로도 검색).
tip.stop|いま処理している1件のあとで止めます。|Stops after the current match.|处理完当前一处后停止。|지금 처리 중인 한 건 다음에 멈춥니다.
alert.unify|%1$d 件を「%2$@」に置き換えますか？|Replace %1$d matches with "%2$@"?|要将 %1$d 处替换为“%2$@”吗？|%1$d건을 "%2$@"(으)로 바꿀까요?
alert.unifyText|文書のアプリの［取り消す］で戻せます。|You can undo this with Undo in the document's app.|可用文稿所在应用的“撤销”恢复。|문서 앱의 [실행 취소]로 되돌릴 수 있습니다.
alert.unifyDocs|ブラウザーを前面にして置き換えます。除外や別の語への影響がなければ［すべて置換］で一度に、そうでなければ1件ずつ（約1秒）です。終わるまでキーボードとマウスに触らないでください。別のアプリに切り替えると止まります。|The browser comes to the front. When nothing else would be affected, Replace all does it at once; otherwise matches are replaced one by one (about 1 second each). Do not touch the keyboard or mouse until it finishes. Switching to another app stops it.|浏览器将置于前台。不影响其他内容时用“全部替换”一次完成，否则逐处替换（每处约 1 秒）。完成前请勿触碰键盘和鼠标。切换到其他应用会停止。|브라우저를 앞으로 가져옵니다. 다른 곳에 영향이 없으면 [모두 바꾸기]로 한 번에, 아니면 한 건씩(약 1초) 바꿉니다. 끝날 때까지 키보드와 마우스를 건드리지 마세요. 다른 앱으로 전환하면 멈춥니다.
status.initial|-|-|-|-
status.count|%d 件|%d|%d 处|%d건
status.total|%1$d 件（%2$@）|%1$d (%2$@)|%1$d 处（%2$@）|%1$d건(%2$@)
status.totalWithExcluded|%1$d 件（%2$@、除外 %3$d 件）|%1$d (%2$@, %3$d excluded)|%1$d 处（%2$@，排除 %3$d 处）|%1$d건(%2$@, 제외 %3$d건)
status.failed|検索できませんでした：%@|Could not search: %@|无法搜索：%@|검색할 수 없습니다: %@
status.stale|語句か設定、または対象の文書が変わりました。［検索］で検索し直してください。|Terms, settings or the document changed. Click Find again.|词语、设置或目标文稿已更改。请按“搜索”重新搜索。|용어, 설정 또는 대상 문서가 바뀌었습니다. [검색]으로 다시 검색하세요.
status.unified|%1$d 件を「%2$@」に置き換えました|Replaced %1$d with "%2$@"|已将 %1$d 处替换为“%2$@”|%1$d건을 "%2$@"(으)로 바꿨습니다
status.changed|「%1$@」を「%2$@」に置き換えました|Replaced "%1$@" with "%2$@"|已将“%1$@”替换为“%2$@”|"%1$@"을(를) "%2$@"(으)로 바꿨습니다
status.skipped|%d 件は文字が変わっていたため置き換えませんでした|%d skipped because the text had changed|%d 处因文字已更改而未替换|%d건은 글자가 바뀌어 있어 바꾸지 않았습니다
status.nothingToReplace|置き換える文字がありません|Nothing to replace|没有可替换的文字|바꿀 글자가 없습니다
status.noSelection|1行以内の文字を選択してください。|Select text within one line.|请选择一行以内的文字。|한 줄 안의 글자를 선택하세요.
status.progress|%1$d / %2$d|%1$d / %2$d|%1$d / %2$d|%1$d / %2$d
status.cancelled|中止しました。|Stopped.|已停止。|중지했습니다.
status.findAgain|［検索］で検索し直してください。|Click Find again.|请按“搜索”重新搜索。|[검색]으로 다시 검색하세요.
error.notTrusted|アクセシビリティの許可が必要です。|Accessibility permission is required.|需要辅助功能权限。|손쉬운 사용 권한이 필요합니다.
error.documentChanged|対象の文書が検索したときと異なります。何も変更していません。［検索］で検索し直してください。|The document is not the one searched. Nothing was changed. Click Find again.|目标文稿与搜索时不同。未作任何更改。请按“搜索”重新搜索。|대상 문서가 검색할 때와 다릅니다. 아무것도 바꾸지 않았습니다. [검색]으로 다시 검색하세요.
error.noText|対象の文書を読み取れません。文書をクリックしてから、もう一度試してください。|Cannot read the document. Click it, then try again.|无法读取目标文稿。请点按文稿后重试。|대상 문서를 읽을 수 없습니다. 문서를 클릭한 뒤 다시 시도하세요.
error.notFront|Googleドキュメントのウインドウを前面にできませんでした。タブを切り替えていないか確かめてください。|Could not bring the Google Docs window forward. Check that the tab was not switched.|无法将 Google 文档窗口置于前台。请确认没有切换标签页。|Google 문서 윈도우를 앞으로 가져오지 못했습니다. 탭을 바꾸지 않았는지 확인하세요.
error.interrupted|途中で別のアプリかタブに切り替わったため止めました。|Stopped because another app or tab came to the front.|因切换到其他应用或标签页而已停止。|다른 앱이나 탭으로 전환되어 멈췄습니다.
error.bodyNotFocused|Googleドキュメントの本文をクリックしてから、もう一度試してください。|Click in the Google Docs body, then try again.|请点按 Google 文档正文后重试。|Google 문서 본문을 클릭한 뒤 다시 시도하세요.
error.copyFailed|本文をコピーできませんでした。文書が空か、コピーが禁止されている可能性があります。|Could not copy the body. The document may be empty or copying may be disabled.|无法拷贝正文。文稿可能为空或已禁止拷贝。|본문을 복사할 수 없습니다. 문서가 비어 있거나 복사가 금지되었을 수 있습니다.
error.findBarFailed|Googleドキュメントの検索バーを操作できませんでした。|Could not use the Google Docs find bar.|无法操作 Google 文档的查找栏。|Google 문서의 찾기 막대를 조작할 수 없습니다.
error.findCountDiffers|文書の内容が読み取ったときと異なります（ヘッダーや脚注にも同じ語があるか、検索バーの［大文字と小文字の区別］がオンの可能性があります）。何も変更していません。|The document differs from what was read (the word may also be in a header or footnote, or Match case may be on in the find bar). Nothing was changed.|文稿内容与读取时不同（页眉或脚注中可能也有该词，或查找栏的“区分大小写”已打开）。未作任何更改。|문서 내용이 읽었을 때와 다릅니다(머리글이나 각주에도 같은 단어가 있거나 찾기 막대의 대소문자 구분이 켜져 있을 수 있습니다). 아무것도 바꾸지 않았습니다.
error.writeIgnored|文字を書き換えられませんでした。文書が読み取り専用か、このアプリが書き換えに対応していない可能性があります。|Could not change the text. The document may be read-only, or the app may not accept changes.|无法更改文字。文稿可能为只读，或该应用不接受更改。|글자를 바꿀 수 없습니다. 문서가 읽기 전용이거나 앱이 변경을 받지 않을 수 있습니다.
a11y.keyword|語句 %d|Term %d|词语 %d|용어 %d
a11y.clearKeyword|語句 %d を空にする|Clear term %d|清空词语 %d|용어 %d 비우기
a11y.unifyTarget|語句 %d を統一先にする|Make term %d the unify target|将词语 %d 设为统一目标|용어 %d을(를) 통일 대상으로
a11y.on|選択中|Selected|已选择|선택됨
a11y.off|未選択|Not selected|未选择|선택 안 됨
a11y.check|対象に含める|Include|包含在对象中|대상에 포함
openMainWindow|メインウインドウを開く|Open Main Window|打开主窗口|메인 윈도우 열기
settings|設定…|Settings…|设置…|설정…
settingsWindow|設定|Settings|设置|설정
help|{APP}ヘルプ|{APP} Help|{APP} 帮助|{APP} 도움말
helpMenu|ヘルプ|Help|帮助|도움말
quit|{APP}を終了|Quit {APP}|退出 {APP}|{APP} 종료
hide|{APP}を隠す|Hide {APP}|隐藏 {APP}|{APP} 가리기
hideOthers|ほかを隠す|Hide Others|隐藏其他|기타 가리기
showAll|すべてを表示|Show All|全部显示|모두 보기
services|サービス|Services|服务|서비스
fileMenu|ファイル|File|文件|파일
close|ウインドウを閉じる|Close Window|关闭窗口|윈도우 닫기
editMenu|編集|Edit|编辑|편집
undo|取り消す|Undo|撤销|실행 취소
redo|やり直す|Redo|重做|실행 복귀
cut|カット|Cut|剪切|오려두기
copy|コピー|Copy|拷贝|복사하기
paste|ペースト|Paste|粘贴|붙여넣기
selectAll|すべてを選択|Select All|全选|모두 선택
windowMenu|ウインドウ|Window|窗口|윈도우
minimize|しまう|Minimize|最小化|최소화
zoom|拡大／縮小|Zoom|缩放|확대/축소
bringAllToFront|すべてを手前に移動|Bring All to Front|前置全部窗口|모두 앞으로 가져오기
about|{APP}について|About {APP}|关于 {APP}|{APP}에 관하여
resident|ウインドウを閉じても常駐|Keep running after closing the window|关闭窗口后继续运行|윈도우를 닫아도 계속 실행
residentDetail|閉じた後もDockやメニューバーから再表示できます。オフにすると閉じたときに終了し、ホットキーも使えなくなります。|Reopen from the Dock or menu bar. When off, closing the window quits and the hotkeys stop.|可从 Dock 或菜单栏再次打开。关闭此项时，关闭窗口即退出，快捷键也会停止。|Dock 또는 메뉴 막대에서 다시 열 수 있습니다. 끄면 창을 닫을 때 종료되고 단축키도 멈춥니다.
launchShortcut|アプリ起動のホットキー|App launch keyboard shortcut|启动应用快捷键|앱 실행 키보드 단축키
openShortcuts|ショートカットを開く|Open Shortcuts|打开快捷指令|단축어 열기
shortcutDetail|ショートカットAppで「アプリを開く」に{APP}を指定し、キーを割り当ててください。未起動時も使えます。|In Shortcuts, create an Open App action for {APP} and assign a key. It works even when the app is not running.|在快捷指令中为 {APP} 创建“打开 App”并分配按键，应用未运行时也可使用。|단축어 앱에서 {APP}을 여는 동작을 만들고 키를 지정하세요. 앱이 실행 중이 아니어도 작동합니다.
appHotkeyHint|{APP}の起動中に押すと、どのアプリからでもメインウインドウを表示します。未起動のときは上の「ショートカットを開く」で割り当てたキーを使ってください。|While {APP} is running, press it in any app to show the main window. When it is not running, use the key assigned with Open Shortcuts above.|{APP} 运行时，在任何应用中按下即可显示主窗口。未运行时请使用上方“打开快捷指令”中分配的按键。|{APP}이 실행 중일 때 어느 앱에서든 누르면 메인 윈도우를 표시합니다. 실행 중이 아닐 때는 위의 '단축어 열기'에서 지정한 키를 사용하세요.
explain|説明|Details|说明|설명
sharing.perMac|ログイン時の起動・常駐・メニューバーの表示・アプリを呼び出すホットキー・ウインドウの位置はMacごとに設定します。|Open at login, keep running, the menu bar icon, the app hotkey and window positions are set on each Mac.|登录时启动、保持运行、菜单栏图标、调出应用的快捷键和窗口位置在每台 Mac 上分别设置。|로그인 시 실행, 계속 실행, 메뉴 막대 아이콘, 앱 호출 단축키, 윈도우 위치는 Mac마다 설정합니다.
'''
# Shared menu / settings rows carry {APP}.
rows = rows.replace('{APP}', APP)
table = [line.split('|') for line in rows.splitlines() if line]
assert all(len(r) == 5 for r in table), [r[0] for r in table if len(r) != 5]
assert len({r[0] for r in table}) == len(table), 'duplicate key'

# Help text lives in help_text.py (markup rendered by Shared/AppStandards/HelpDocument.swift).
from help_text import HELP
for i, lang in enumerate(['ja', 'en', 'zh-Hans', 'ko']):
    p = root / 'Resources' / f'{lang}.lproj'
    p.mkdir(parents=True, exist_ok=True)
    (p / 'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0])} = {json.dumps(r[i + 1], ensure_ascii=False)};' for r in table) + '\n')
    (p / 'InfoPlist.strings').write_text(f'"CFBundleDisplayName" = "{APP}";\n')
    (p / 'Help.txt').write_text(HELP[lang])
print('resources written')
