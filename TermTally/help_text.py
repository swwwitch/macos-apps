# -*- coding: utf-8 -*-
# TermTally help (markup rendered by Shared/AppStandards/HelpDocument.swift). Keep the 4 languages parallel.
HELP = {
 "ja": """## 基本操作
TermTallyは、最大5つの語句が文書にそれぞれいくつあるかを数え、該当箇所を一覧しながら表記の揺れを統一します。InDesignのスクリプト「IdCountTermPalette」のMac版で、ドキュメントの代わりに、テキストエディットの書類やGoogleドキュメントで開いているページのすべての文字を対象にします。
- 対象にしたい文書を一度クリックしてから、このウインドウに戻ります。「対象」に文書の名前が出ます。
- 語句欄に語を入れて［検索］を押します（returnキーでも検索）。各欄の右に件数、右側に該当箇所が出ます。
- 欄の左の丸を押して統一先を選び（◉が統一先）、［すべてを統一…］を押すと、ほかの欄で見つかった文字を統一先に置き換えます。
- 一覧のチェックを外した行は除外され、件数と［すべてを統一…］の対象から外れます。
- 一覧で行を選び、［個別に書き替え］を直して［置換］を押すと、その1か所だけを置き換えます。
- 語句欄の × で欄を空にします。Optionキーを押しながら × をクリックすると、すべての語句欄を空にします。
- ［選択文字を取り込む］は、文書で選択している文字を語句欄に入れます。
- ［揺れ候補を拾う］は、語句を入れなくても、文書の中で表記が揺れている語を組にして一覧にします（ユーザビリティ／ユーザビリティー、Apple／apple／APPLE、取引／取り引きなど）。組を選ぶと語句欄に入り、いちばん多い表記が統一先になり、該当箇所が出ます。
- 組にする違い：大文字小文字・全角半角（数字を含む）・長音・中黒・ウィとウイ・ヴァとバ・送り仮名。拾うのはカタカナの語・英数字の語・漢字と送り仮名の語です。候補なので、別の語が組になることもあります。
- 「調整する／調整をする」「確認しました／確認をしました」のように、を の有無が異なる言い方も組にします。する・します・した・して などの形ごとの組で、形が異なるもの（確認する／確認をします）は組にしません。
- 表記ゆれ辞書：文字種が異なる揺れ（ください／下さい、できる／出来る、こと／事、ウェブ／Web）や全角半角の記号は、同梱の辞書で拾います。設定の「辞書」で自分の辞書を足せます。
- 辞書の誤記（ドラック→ドラッグ、facebook→Facebook など）は、正しい表記が文書に無くても拾います。件数0の正しい表記が組に入り、統一先になります。
- 要確認：「対象／対照」「より／から」のように文脈で正しい場合もある語です。統一先は選ばれないので、一覧で確かめ、必要なら ◉ を選ぶか1か所ずつ直します。一覧の上の絞り込みで「要確認」だけを出したり外したりできます。
- 統一先：太字の表記が統一先になります。前回その組で統一した表記、辞書の推奨、いちばん多い表記の順に選びます。統一すると覚えます。
- ［無視］で選んだ組を次から出さないようにします（右クリックでも可）。設定の「辞書」で元に戻せます。
- 一覧の上で種類（カタカナ・漢字・英数字・する／をする・辞書・要確認）と並び順を変えられます。
- ［一覧をコピー］で、組・表記・件数・統一先の表をコピーします。表計算アプリに貼り付けられます。

## オプション
- ほかの語句に含まれる分は数えない：「取引」と「取引き」のように、長い語句の中で見つかった分を短い語句の件数から除きます。
- 大文字と小文字を区別：オフのときは Apple と apple を同じ語として数えます。
- 単語単位：前後が同じ文字種（英数字・漢字・カタカナ）に続くものを除きます（「仕事」の中の「事」、pineapple の中の apple など）。揺れ候補の組を選ぶと自動でオンになります。
- 段落内に限る：一覧の前後の文字を段落の中だけにします。段落の区切り（¶）と、その先の文字は表示しません。
- 該当文字に色を付ける（設定の「表示」、初期値オン）：一覧の該当文字を色付きの太字にします。色は標準のカラーピッカーで変えられ、［赤に戻す］で初期値に戻ります。オフにすると太字だけになります。
- 前後の文字数：一覧に出す前後の文字数です（0〜20）。
- 語句や検索の条件を変えたら、［検索］で検索し直すまで置き換えはできません。

## 対象の文書
- テキストエディットなど、本文を丸ごとアクセシビリティで読めるアプリ（ウェブの入力欄やVS Codeなど、見えている部分しか読めないものは対象にしません）：背面のまま読み書きします。一覧の行をクリックすると、その文字を選択して表示します。置換は文書のアプリの［取り消す］で戻せます（テキストエディットは［すべてを統一…］も1回で戻ります）。書式は置き換える文字のものを保ちます。
- Googleドキュメント（Safari・Chrome・Firefoxなど）：本文がアクセシビリティに出ないので、キー操作で扱います。ブラウザーが一瞬前面に出ます。
  - ［検索］は ⌘A・⌘C で本文を読み取り、カーソルを文書の先頭に移します。
  - 一覧の行をダブルクリックするか［表示］を押すと、Googleドキュメントの検索バーでその文字まで移動して選択します。
  - ［すべてを統一…］は、除外がなく別の語にも影響しないときはGoogleドキュメントの［すべて置換］で一度に行い、⌘Z 1回で戻せます。それ以外は1件約1秒で、文字を選択してコピーし、読み取ったときと同じことを確かめてから貼り付けます。どちらも書式は置き換える文字のものを保ちます。
  - 置き換えている間はキーボードとマウスに触らないでください。別のアプリやタブに切り替えると、そこで止まります。［中止］でも止まります。
  - 1件ずつ置き換えたときの取り消しはGoogleドキュメントの ⌘Z で1件ずつです。［ファイル］の変更履歴からも戻せます。
  - 読み取れるのは開いているタブの本文です。ヘッダー・フッター・脚注は対象外で、同じ語がそこにあると検索バーの件数が合わないため、置き換えずに止まります。
  - クリップボードは終わると元に戻します（途中でほかのアプリがコピーした場合は、その内容を残します）。

## 対象アプリを固定
- 「対象」の［対象アプリを固定］をオンにすると、調べものやメールの確認でほかのアプリに移っても、対象がいまの文書のまま変わりません。
- テキストエディットなどは背面のまま読み書きします。Googleドキュメントは操作のときに固定したウインドウを前面に出します。そのウインドウで別のタブに切り替えていると操作できないので、タブを戻してください。
- 固定はアプリを終了すると解除されます。対象のアプリを終了したときも解除されます。

## ウインドウ
- 「ウインドウをほかのアプリより手前に表示する」（設定の「表示」、初期値オン）で、文書を見ながら操作できます。
- ［閉じる］かEsc、⌘Wでウインドウを閉じます。常駐中はメニューバーのアイコンやDockから再表示できます。
- 語句と設定は次回の起動でも残ります。

## ショートカット
- return：検索（［個別に書き替え］の欄では置換）
- ⌘0：メインウインドウを開く
- ⌘,：設定
- ⌘W：ウインドウを閉じる
- ⌘Q：終了
- アプリを呼び出すショートカット：設定の「起動・常駐」で割り当てると、どのアプリからでもウインドウを表示します（初期値は未設定）。

## 権限
- アクセシビリティ：文書の文字を読み書きし、Googleドキュメントへキーを送るために必要です。許可がないと検索できません。主画面か設定の「起動・常駐」からシステム設定を開けます。
- 読み取った文字はこのMacの中だけで扱い、保存も送信もしません。更新確認のほかに外部通信はしません。

## 困ったとき
- 「対象」が変わらない：文書を一度クリックしてから、このウインドウに戻ってください。読めないアプリをクリックしても、前の文書のままです。
- 「文字は読み取れません」：本文をアクセシビリティに出していないアプリは対象にできません。
- 「本文をクリックして」と出る（Googleドキュメント）：タイトル欄やコメントにカーソルがあります。本文をクリックしてください。
- 「文書の内容が読み取ったときと異なります」：文書を編集したか、ヘッダー・脚注に同じ語があるか、検索バーの［大文字と小文字の区別］がオンです。［検索］で検索し直すか、該当箇所を手で直してください。
- 終了できない：置き換え中は終了しません。止まってからもう一度終了してください。

## 削除
アプリをゴミ箱に入れます。設定は ~/Library/Preferences/jp.dtp-transit.termtally.plist です。
""",
 "en": """## Basics
TermTally counts how many times each of up to five terms appears in a document, lists where they are, and unifies spelling variants. It is the Mac version of the InDesign script IdCountTermPalette: instead of an InDesign document, it works on all the text of a TextEdit document or a page open in Google Docs.
- Click the document once, then come back to this window. Its name appears under Document.
- Type terms and click Find (or press Return). Counts appear next to the fields and the matches on the right.
- Pick the unify target with the circle left of a field (◉ marks it), then click Unify All… to replace what the other fields found.
- Unchecked rows are excluded from the counts and from Unify All.
- Pick a row, edit Rewrite This One, and click Change to change just that one place.
- The × clears a term field. Option-click it to clear all the term fields.
- Load Selection puts the text selected in the document into a term field.
- Find Variants needs no terms: it lists the words written in more than one way in the document (Apple / apple / APPLE, and so on). Pick a group to put it in the term fields: the most used spelling becomes the unify target and the matches appear.
- What counts as the same word: differences in case, width (numbers too), long vowels, middle dots, small kana, ヴ and okurigana. Katakana words, Latin words and kanji words with okurigana are looked at. These are candidates, so different words can end up in one group.
- Phrases that differ only by を, such as 調整する／調整をする, also form groups. Each form of する has its own group, so 確認する and 確認をします are not paired.
- Variant dictionary: variants in different scripts (ください／下さい, ウェブ／Web) and full-width and half-width symbols come from the bundled dictionary. Add your own under Dictionary in Settings.
- Misspellings in the dictionary (ドラック→ドラッグ, facebook→Facebook) are found even when the right spelling is not used: it joins the group with a count of 0 and becomes the target.
- To Review: words that can be right in context, such as 対象／対照. No target is chosen, so check the list and pick one or fix each place.
- Target: the bold spelling becomes the target: the one last used for that group, the dictionary's, then the most used. Unifying remembers it.
- Ignore stops showing the selected group (right-click also works). Undo it under Dictionary in Settings.
- Above the list you can choose a kind (Katakana, Kanji, Latin, する／をする, Dictionary, To Review) and the order.
- Copy Table copies group, spelling, count and target as a table for a spreadsheet.

## Options
- Do not count matches inside other terms: a term found inside a longer term is not counted for the shorter one.
- Case Sensitive: when off, Apple and apple count as the same word.
- Whole Word: skips matches that run on into the same script (letters, kanji, katakana), like apple in pineapple. It turns on when you pick a group of variants.
- Within Paragraph: keeps the characters around a match inside its paragraph. The paragraph mark (¶) and what lies beyond it are not shown.
- Color the matches (Display in Settings, on by default): shows the found text in colored bold in the list. Change the color with the standard color picker; Back to Red restores it. When off, it is only bold.
- Characters Around: how much text the list shows around a match (0 to 20).
- After changing terms or search conditions, click Find again before replacing.

## Documents
- TextEdit and other apps whose whole text Accessibility can read (web text fields and apps like VS Code, which show only part of it, are not used): read and changed from behind. Clicking a row selects and shows the text. Use Undo in that app to go back (in TextEdit, Unify All undoes in one step). The formatting of the replaced text is kept.
- Google Docs (Safari, Chrome, Firefox and others): the body is not visible to Accessibility, so keystrokes are used and the browser comes forward briefly.
  - Find reads the body with ⌘A and ⌘C and moves the cursor to the start of the document.
  - Double-click a row or click Show to go to the text with the Google Docs find bar and select it.
  - Unify All uses Replace all in Google Docs when nothing is excluded and no other word is affected: it is done at once and one ⌘Z undoes it. Otherwise it takes about 1 second per match: the text is selected, copied and compared with what was read before it is pasted over. The formatting of the replaced text is kept either way.
  - Do not touch the keyboard or mouse while replacing. Switching to another app or tab stops it, and so does Stop.
  - After replacing one by one, undo is ⌘Z in Google Docs, one match at a time. Version history also works.
  - Only the body of the open tab is read. Headers, footers and footnotes are not; if the same word is there, the find bar's count differs and replacing stops without changing anything.
  - The clipboard is restored afterwards, unless another app copied something in the meantime.

## Keeping the Target
- Turn on Keep This Document as the Target under Document: switching to other apps for research or mail leaves the target as it is.
- TextEdit and the like are read and changed from behind. Google Docs brings the kept window forward when needed; if another tab is showing in that window, switch back first.
- It ends when you quit TermTally or the target app.

## Window
- Keep the window in front of other apps (Display in Settings, on by default) lets you work while looking at the document.
- Close, Esc or ⌘W closes the window. While the app keeps running, reopen it from the menu bar icon or the Dock.
- Terms and settings stay for the next launch.

## Shortcuts
- Return: Find (Change in the Rewrite This One field)
- ⌘0: Open the main window
- ⌘,: Settings
- ⌘W: Close the window
- ⌘Q: Quit
- App hotkey: set in Launch & Residency in Settings to show the window from any app (none by default).

## Permissions
- Accessibility: needed to read and change document text and to send keys to Google Docs. Find does not work without it. System Settings opens from the main window or from Settings.
- Text is handled only on this Mac and is neither saved nor sent. There is no network use except update checks.

## Troubleshooting
- Document does not change: click the document, then come back. Clicking an app that cannot be read keeps the previous document.
- Cannot read the text: apps that do not expose their text to Accessibility cannot be used.
- Click in the Google Docs body: the cursor is in the title or a comment. Click the body.
- The document differs from what was read: it was edited, the word is also in a header or footnote, or Match case is on in the find bar. Find again, or fix that place by hand.
- The app does not quit: it does not quit while replacing. Quit again after it stops.

## Removing
Move the app to the Trash. Settings are in ~/Library/Preferences/jp.dtp-transit.termtally.plist.
""",
 "zh-Hans": """## 基本操作
TermTally 统计最多 5 个词语在文稿中各出现多少次，列出位置，并统一写法差异。它是 InDesign 脚本 IdCountTermPalette 的 Mac 版，以“文本编辑”的文稿或 Google 文档中打开的页面的全部文字为对象。
- 先点按一次目标文稿，再回到此窗口。“对象”中会显示文稿名称。
- 在词语栏输入词语并按“搜索”（也可按 Return 键）。各栏右侧显示件数，右边列出匹配位置。
- 用栏左侧的圆圈选择统一目标（◉ 为统一目标），按“全部统一…”后，其他栏找到的文字会替换为统一目标。
- 取消勾选的行被排除，不计入件数，也不参与“全部统一”。
- 选择一行，修改“逐个改写”并按“替换”，只替换这一处。
- 用栏旁的 × 清空该栏。按住 Option 键点按 × 可清空所有词语栏。
- “载入所选文字”将文稿中选中的文字填入词语栏。
- “查找写法差异”无需输入词语，即可列出文稿中写法不一的词（如 Apple／apple／APPLE）。选择一组后填入词语栏，最常用的写法成为统一目标，并显示匹配位置。
- 视为同一个词的差异：大小写、全半角（含数字）、长音、中点、小写假名、ヴ、送假名。查找对象为片假名词、英文词、汉字加送假名的词。这些只是候补，不同的词也可能归为一组。
- 仅 を 有无不同的说法（如 確認する／確認をする）也会成组。する 的各形式分别成组，形式不同的（確認する／確認をします）不成组。
- 写法差异词典：不同文字类型的差异（ください／下さい、ウェブ／Web）及全半角符号由内置词典查找。可在设置的“词典”中添加自定义词典。
- 词典中的错误写法（ドラック→ドラッグ、facebook→Facebook 等）即使文稿中没有正确写法也能找到。件数为 0 的正确写法加入组并成为统一目标。
- 需确认：如 対象／対照，在上下文中可能正确的词。不会自动选择统一目标，请在列表中确认，再选择目标或逐处修改。
- 统一目标：粗体写法成为统一目标，依次为上次使用、词典推荐、最常用。统一后会记住。
- “忽略”使所选组不再显示（也可右键点按）。可在设置的“词典”中恢复。
- 可在列表上方选择类型（片假名、汉字、英文数字、词典）和顺序。
- “拷贝列表”将组、写法、件数、统一目标拷贝为表格，可粘贴到电子表格。

## 选项
- 不计入其他词语中包含的部分：在较长词语中找到的部分不计入较短词语。
- 区分大小写：关闭时 Apple 和 apple 算作同一个词。
- 全字匹配：排除前后紧接相同文字类型（英文、汉字、片假名）的匹配，如 pineapple 中的 apple。选择写法差异组时自动打开。
- 限于段落内：列表中的前后文字仅限于段落内。不显示段落标记（¶）及其之外的文字。
- 为匹配文字着色（设置的“显示”，默认打开）：在列表中将匹配文字显示为彩色粗体。可用标准颜色选择器更改颜色，“恢复红色”可恢复默认。关闭后仅为粗体。
- 前后字数：列表中显示的前后字数（0～20）。
- 更改词语或搜索条件后，需重新搜索才能替换。

## 目标文稿
- “文本编辑”等可通过辅助功能读取全部正文的应用（网页输入栏和 VS Code 等只能读取可见部分的应用不作为对象）：在后台读写。点按列表中的行会选择并显示该文字。可用该应用的“撤销”恢复（“文本编辑”中“全部统一”一次即可恢复）。保留被替换文字的格式。
- Google 文档（Safari、Chrome、Firefox 等）：正文不向辅助功能公开，因此使用按键操作，浏览器会短暂置于前台。
  - “搜索”用 ⌘A 和 ⌘C 读取正文，并将光标移到文稿开头。
  - 连按两次某行或按“显示”，会用 Google 文档的查找栏移动到该文字并选择。
  - “全部统一”在没有排除且不影响其他词时使用 Google 文档的“全部替换”一次完成，按一次 ⌘Z 可恢复。否则每处约 1 秒：先选择并拷贝文字，确认与读取时相同后再粘贴。两种方式都保留被替换文字的格式。
  - 替换期间请勿触碰键盘和鼠标。切换到其他应用或标签页会停止，按“停止”也会停止。
  - 逐处替换后的撤销使用 Google 文档的 ⌘Z，逐处进行。也可用版本历史恢复。
  - 只读取打开的标签页的正文。页眉、页脚和脚注不在对象内；如果其中有相同的词，查找栏的件数不一致，会不作更改并停止。
  - 完成后恢复剪贴板（期间其他应用拷贝过内容时保留该内容）。

## 固定目标应用
- 打开“对象”中的“固定目标应用”后，切换到其他应用查资料或看邮件时，目标仍为当前文稿。
- “文本编辑”等在后台读写。Google 文档在操作时将固定的窗口置于前台；如果该窗口切换到了其他标签页，请切换回来。
- 退出本应用或目标应用时解除固定。

## 窗口
- “窗口保持在其他应用之前”（设置的“显示”，默认打开）可一边查看文稿一边操作。
- 按“关闭”、Esc 或 ⌘W 关闭窗口。保持运行时可从菜单栏图标或 Dock 再次打开。
- 词语和设置在下次启动时保留。

## 快捷键
- Return：搜索（在“逐个改写”栏中为替换）
- ⌘0：打开主窗口
- ⌘,：设置
- ⌘W：关闭窗口
- ⌘Q：退出
- 调出应用的快捷键：在设置的“启动和常驻”中分配后，可从任何应用显示窗口（默认未设置）。

## 权限
- 辅助功能：用于读写文稿文字并向 Google 文档发送按键。未授权时无法搜索。可从主窗口或设置打开系统设置。
- 文字只在这台 Mac 上处理，不保存也不发送。除更新检查外没有网络通信。

## 故障排除
- “对象”没有变化：点按文稿后再回到此窗口。点按无法读取的应用时仍保持之前的文稿。
- 无法读取文字：不向辅助功能公开正文的应用无法使用。
- 提示点按正文：光标在标题或评论中。请点按正文。
- 文稿内容与读取时不同：文稿已编辑、页眉或脚注中有相同的词，或查找栏的“区分大小写”已打开。请重新搜索或手动修改。
- 无法退出：替换期间不会退出。停止后再次退出。

## 删除
将应用移到废纸篓。设置位于 ~/Library/Preferences/jp.dtp-transit.termtally.plist。
""",
 "ko": """## 기본 조작
TermTally는 최대 5개의 용어가 문서에 각각 몇 개 있는지 세고, 해당 위치를 나열하며 표기 차이를 통일합니다. InDesign 스크립트 IdCountTermPalette의 Mac 버전으로, 텍스트 편집기 문서나 Google 문서에서 연 페이지의 모든 글자를 대상으로 합니다.
- 대상 문서를 한 번 클릭한 뒤 이 윈도우로 돌아옵니다. [대상]에 문서 이름이 표시됩니다.
- 용어 칸에 단어를 넣고 [검색]을 누릅니다(Return 키로도 검색). 각 칸 오른쪽에 건수, 오른쪽에 해당 위치가 표시됩니다.
- 칸 왼쪽의 동그라미로 통일 대상을 고르고(◉가 통일 대상) [모두 통일…]을 누르면 다른 칸에서 찾은 글자를 통일 대상으로 바꿉니다.
- 체크를 해제한 행은 제외되어 건수와 [모두 통일…] 대상에서 빠집니다.
- 행을 고르고 [개별로 고쳐 쓰기]을 고쳐 [바꾸기]를 누르면 그 한 곳만 바꿉니다.
- 칸의 ×로 칸을 비웁니다. Option 키를 누른 채 ×를 클릭하면 모든 용어 칸을 비웁니다.
- [선택 글자 가져오기]는 문서에서 선택한 글자를 용어 칸에 넣습니다.
- [표기 차이 찾기]는 용어를 넣지 않아도 문서에서 표기가 흔들리는 단어를 묶어 나열합니다(Apple／apple／APPLE 등). 묶음을 고르면 용어 칸에 들어가고, 가장 많은 표기가 통일 대상이 되며, 해당 위치가 표시됩니다.
- 같은 단어로 묶는 차이: 대소문자, 전각·반각(숫자 포함), 장음, 가운뎃점, 작은 가나, ヴ, 오쿠리가나. 찾는 대상은 가타카나 단어, 영문 단어, 한자와 오쿠리가나 단어입니다. 후보이므로 다른 단어가 묶일 수도 있습니다.
- 確認する／確認をする처럼 を의 유무만 다른 표현도 묶습니다. する의 형태별로 묶으므로 형태가 다른 것(確認する／確認をします)은 묶지 않습니다.
- 표기 차이 사전: 문자 종류가 다른 차이(ください／下さい, ウェブ／Web)와 전각·반각 기호는 포함된 사전으로 찾습니다. 설정의 [사전]에서 내 사전을 추가할 수 있습니다.
- 사전의 오기(ドラック→ドラッグ, facebook→Facebook 등)는 올바른 표기가 문서에 없어도 찾습니다. 건수 0의 올바른 표기가 묶음에 들어가 통일 대상이 됩니다.
- 확인 필요: 対象／対照처럼 문맥에 따라 맞을 수도 있는 단어입니다. 통일 대상을 고르지 않으므로 목록에서 확인하고 대상을 고르거나 한 곳씩 고치세요.
- 통일 대상: 굵은 표기가 대상이 됩니다. 지난번 대상, 사전 추천, 가장 많은 표기 순입니다. 통일하면 기억합니다.
- [무시]는 고른 묶음을 앞으로 표시하지 않습니다(오른쪽 클릭도 가능). 설정의 [사전]에서 되돌릴 수 있습니다.
- 목록 위에서 종류(가타카나, 한자, 영문·숫자, 사전)와 순서를 바꿀 수 있습니다.
- [목록 복사]는 묶음, 표기, 건수, 통일 대상을 표로 복사합니다.

## 옵션
- 다른 용어에 포함된 것은 세지 않음: 긴 용어 안에서 찾은 것은 짧은 용어의 건수에서 뺍니다.
- 대소문자 구분: 끄면 Apple과 apple을 같은 단어로 셉니다.
- 단어 단위: 앞뒤가 같은 문자 종류(영문, 한자, 가타카나)로 이어지는 것을 제외합니다(pineapple 안의 apple 등). 표기 차이 묶음을 고르면 자동으로 켜집니다.
- 단락 안으로 한정: 목록의 앞뒤 글자를 단락 안으로 한정합니다. 단락 기호(¶)와 그 너머의 글자는 표시하지 않습니다.
- 해당 글자에 색 입히기(설정의 [표시], 기본 켬): 목록에서 해당 글자를 색이 있는 굵은 글씨로 표시합니다. 표준 색상 선택기로 색을 바꿀 수 있고 [빨간색으로 되돌리기]로 기본값이 됩니다. 끄면 굵게만 표시됩니다.
- 앞뒤 글자 수: 목록에 표시할 앞뒤 글자 수입니다(0~20).
- 용어나 검색 조건을 바꾸면 다시 검색해야 바꿀 수 있습니다.

## 대상 문서
- 텍스트 편집기처럼 손쉬운 사용으로 본문 전체를 읽을 수 있는 앱(웹 입력란이나 VS Code처럼 보이는 부분만 읽히는 것은 대상이 아닙니다): 뒤에 둔 채 읽고 씁니다. 목록의 행을 클릭하면 그 글자를 선택해 표시합니다. 그 앱의 [실행 취소]로 되돌릴 수 있습니다(텍스트 편집기는 [모두 통일…]도 한 번에 되돌립니다). 바뀌는 글자의 서식을 유지합니다.
- Google 문서(Safari, Chrome, Firefox 등): 본문이 손쉬운 사용에 나타나지 않아 키 입력으로 다룹니다. 브라우저가 잠시 앞으로 나옵니다.
  - [검색]은 ⌘A와 ⌘C로 본문을 읽고 커서를 문서 처음으로 옮깁니다.
  - 행을 더블 클릭하거나 [표시]를 누르면 Google 문서의 찾기 막대로 그 글자까지 이동해 선택합니다.
  - [모두 통일…]은 제외가 없고 다른 단어에 영향이 없으면 Google 문서의 [모두 바꾸기]로 한 번에 처리하며 ⌘Z 한 번으로 되돌립니다. 그 외에는 건당 약 1초로, 글자를 선택해 복사하고 읽었을 때와 같은지 확인한 뒤 붙여넣습니다. 어느 쪽이든 바뀌는 글자의 서식을 유지합니다.
  - 바꾸는 동안 키보드와 마우스를 건드리지 마세요. 다른 앱이나 탭으로 전환하면 멈추고, [중지]로도 멈춥니다.
  - 한 건씩 바꾼 경우 실행 취소는 Google 문서의 ⌘Z로 한 건씩입니다. 버전 기록으로도 되돌릴 수 있습니다.
  - 읽는 것은 열려 있는 탭의 본문입니다. 머리글, 바닥글, 각주는 대상이 아니며, 그곳에 같은 단어가 있으면 찾기 막대의 건수가 맞지 않아 아무것도 바꾸지 않고 멈춥니다.
  - 끝나면 클립보드를 되돌립니다(도중에 다른 앱이 복사했다면 그 내용을 남깁니다).

## 대상 앱 고정
- [대상]의 [대상 앱 고정]을 켜면 자료를 찾거나 메일을 확인하려고 다른 앱으로 옮겨도 대상이 지금 문서로 유지됩니다.
- 텍스트 편집기 등은 뒤에 둔 채 읽고 씁니다. Google 문서는 조작할 때 고정한 윈도우를 앞으로 가져옵니다. 그 윈도우에서 다른 탭으로 바꿨다면 탭을 되돌리세요.
- 이 앱이나 대상 앱을 종료하면 해제됩니다.

## 윈도우
- [윈도우를 다른 앱보다 앞에 표시](설정의 [표시], 기본 켬)로 문서를 보면서 작업할 수 있습니다.
- [닫기], Esc, ⌘W로 윈도우를 닫습니다. 계속 실행 중이면 메뉴 막대 아이콘이나 Dock에서 다시 엽니다.
- 용어와 설정은 다음 실행에도 남습니다.

## 단축키
- Return: 검색([개별로 고쳐 쓰기] 칸에서는 바꾸기)
- ⌘0: 메인 윈도우 열기
- ⌘,: 설정
- ⌘W: 윈도우 닫기
- ⌘Q: 종료
- 앱을 부르는 단축키: 설정의 [실행 및 상주]에서 지정하면 어느 앱에서든 윈도우를 표시합니다(기본 없음).

## 권한
- 손쉬운 사용: 문서 글자를 읽고 쓰고 Google 문서에 키를 보내는 데 필요합니다. 허용하지 않으면 검색할 수 없습니다. 메인 윈도우나 설정에서 시스템 설정을 열 수 있습니다.
- 글자는 이 Mac 안에서만 다루며 저장하거나 보내지 않습니다. 업데이트 확인 외에 외부 통신은 없습니다.

## 문제 해결
- [대상]이 바뀌지 않음: 문서를 클릭한 뒤 이 윈도우로 돌아오세요. 읽을 수 없는 앱을 클릭하면 이전 문서가 유지됩니다.
- 글자를 읽을 수 없음: 본문을 손쉬운 사용에 내놓지 않는 앱은 대상이 될 수 없습니다.
- 본문을 클릭하라는 표시: 커서가 제목이나 댓글에 있습니다. 본문을 클릭하세요.
- 문서 내용이 읽었을 때와 다름: 문서를 편집했거나, 머리글이나 각주에 같은 단어가 있거나, 찾기 막대의 대소문자 구분이 켜져 있습니다. 다시 검색하거나 직접 고치세요.
- 종료되지 않음: 바꾸는 동안에는 종료하지 않습니다. 멈춘 뒤 다시 종료하세요.

## 삭제
앱을 휴지통으로 옮깁니다. 설정은 ~/Library/Preferences/jp.dtp-transit.termtally.plist에 있습니다.
""",
}
