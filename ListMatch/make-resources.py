from pathlib import Path
import json, plistlib
root = Path(__file__).resolve().parent
LANGS = ['ja', 'en', 'zh-Hans', 'ko']
rows = [
('headline', '2つのリストを比較', 'Compare two lists', '比较两个列表', '두 목록 비교'),
('subtitle', '左右にリストを貼り付けると、片方にしかない項目を下に表示します。', 'Paste a list on each side to see the items that are only on one side.', '在左右两侧粘贴列表，下方会显示只在一侧出现的项。', '좌우에 목록을 붙여넣으면 한쪽에만 있는 항목을 아래에 표시합니다.'),
('leftList', '左のリスト', 'Left List', '左侧列表', '왼쪽 목록'),
('rightList', '右のリスト', 'Right List', '右侧列表', '오른쪽 목록'),
('leftListLabel', '左のリスト（1行に1項目）', 'Left list (one item per line)', '左侧列表（每行一项）', '왼쪽 목록(한 행에 한 항목)'),
('rightListLabel', '右のリスト（1行に1項目）', 'Right list (one item per line)', '右侧列表（每行一项）', '오른쪽 목록(한 행에 한 항목)'),
('inputPlaceholder', 'リストを貼り付けるか、テキストファイルをドロップ', 'Paste a list, or drop a text file', '粘贴列表，或拖放文本文件', '목록을 붙여넣거나 텍스트 파일을 드롭'),
('inputPlaceholderEmail', 'メールアドレスを含むテキストを貼り付けるか、ファイルをドロップ（宛先欄・CSV・署名など）', 'Paste text containing e-mail addresses, or drop a file (address fields, CSV, signatures…)', '粘贴包含电子邮件地址的文本，或拖放文件（收件人栏、CSV、签名等）', '이메일 주소가 포함된 텍스트를 붙여넣거나 파일을 드롭(받는 사람 칸, CSV, 서명 등)'),
('modeLabel', '比較の単位', 'Compare by', '比较单位', '비교 단위'),
('modeLines', '行ごと', 'Lines', '按行', '행 단위'),
('modeEmail', 'メールアドレスのみ', 'E-mail Addresses Only', '仅电子邮件地址', '이메일 주소만'),
('modeHelp', '「メールアドレスのみ」では、名前やカンマなどが混じったテキストからメールアドレスだけを取り出して比べます', 'E-mail Addresses Only picks out just the addresses from text mixed with names, commas and so on', '“仅电子邮件地址”会从混有姓名、逗号等的文本中只取出电子邮件地址进行比较', '이메일 주소만은 이름이나 쉼표 등이 섞인 텍스트에서 이메일 주소만 꺼내 비교합니다'),
('modeLinesMenu', '行ごとに比較', 'Compare Lines', '按行比较', '행 단위로 비교'),
('modeEmailMenu', 'メールアドレスのみを比較', 'Compare E-mail Addresses Only', '仅比较电子邮件地址', '이메일 주소만 비교'),
('addressCount', 'アドレス%ld件', '%ld addresses', '%ld 个地址', '주소 %ld개'),
('skippedCount', '（アドレスのない行%ld）', '(%ld lines without an address)', '（无地址的行 %ld）', '(주소 없는 행 %ld)'),
('emailModeSettingsNote', '「メールアドレスのみ」で比較しているあいだは、全角と半角の設定は使いません（全角のアドレスも半角として取り出します）。', 'While comparing e-mail addresses only, the width setting is not used (full-width addresses are read as half-width).', '仅比较电子邮件地址时，不使用全角/半角设置（全角地址也会按半角提取）。', '이메일 주소만 비교하는 동안에는 전각/반각 설정을 사용하지 않습니다(전각 주소도 반각으로 꺼냅니다).'),
('fileLabel', '連携しているファイル：%@', 'Linked file: %@', '已关联的文件：%@', '연결된 파일: %@'),
('fileMissing', 'ファイルが見つかりません', 'File not found', '找不到文件', '파일을 찾을 수 없음'),
('unsaved', '未保存', 'Unsaved', '未存储', '저장 안 됨'),
('saveButton', '保存', 'Save', '存储', '저장'),
('saveHelp', 'このリストを読み込んだファイルに上書き保存します（元の内容はバックアップに控えます）', 'Save this list over the file it was read from (the previous contents are backed up)', '将此列表覆盖存储到载入它的文件（原内容会备份）', '이 목록을 불러온 파일에 덮어써 저장합니다(원래 내용은 백업)'),
('revealInFinder', 'Finderで表示', 'Show in Finder', '在访达中显示', 'Finder에서 보기'),
('unlink', '連携を解除', 'Unlink', '取消关联', '연결 해제'),
('unlinkHelp', 'リストはそのまま残し、ファイルとの連携だけを外します', 'Keep the list and only unlink it from the file', '保留列表，仅取消与文件的关联', '목록은 그대로 두고 파일과의 연결만 해제합니다'),
('unlinked', '「%@」との連携を解除しました。', 'Unlinked from “%@”.', '已取消与“%@”的关联。', '"%@"과(와)의 연결을 해제했습니다.'),
('cancel', 'キャンセル', 'Cancel', '取消', '취소'),
('overwrite', '上書き', 'Overwrite', '覆盖', '덮어쓰기'),
('changedTitle', '「%@」はほかのアプリで変更されています', '“%@” was changed by another app', '“%@”已被其他应用更改', '"%@"이(가) 다른 앱에서 변경되었습니다'),
('changedInfo', '上書きすると、ほかのアプリでの変更は失われます（上書き前の内容はバックアップに控えます）。', 'Overwriting loses the changes made in the other app (the current contents are backed up first).', '覆盖后，在其他应用中的更改将丢失（覆盖前的内容会备份）。', '덮어쓰면 다른 앱에서 변경한 내용이 사라집니다(덮어쓰기 전 내용은 백업).'),
('saveCancelled', '保存を取り消しました。', 'Save canceled.', '已取消存储。', '저장을 취소했습니다.'),
('errorSave', '保存できませんでした：%@', 'Could not save: %@', '无法存储：%@', '저장할 수 없습니다: %@'),
('statusSaved', '保存しました：%@', 'Saved: %@', '已存储：%@', '저장했습니다: %@'),
('saveLeft', '左のリストを保存', 'Save Left List', '存储左侧列表', '왼쪽 목록 저장'),
('saveRight', '右のリストを保存', 'Save Right List', '存储右侧列表', '오른쪽 목록 저장'),
('mergeSave', 'マージして保存…', 'Merge and Save…', '合并并存储…', '병합하여 저장…'),
('mergeHelp', '左右のリストを重複なしでまとめ、1行に1項目の新しいファイルに保存します', 'Combine both lists without repeats and save them to a new file, one item per line', '将左右列表去重合并，存储为每行一项的新文件', '좌우 목록을 중복 없이 합쳐 한 행에 한 항목인 새 파일로 저장합니다'),
('mergeTitle', 'マージして保存', 'Merge and Save', '合并并存储', '병합하여 저장'),
('mergeFileName', 'マージ', 'merged', '合并', '병합'),
('mergeSuffix', 'マージ', 'merged', '合并', '병합'),
('nothingToMerge', 'マージする項目がありません。', 'There is nothing to merge.', '没有可合并的项。', '병합할 항목이 없습니다.'),
('statusMerged', '%1$ld件をマージして保存しました：%2$@', 'Merged and saved %1$ld items: %2$@', '已合并并存储 %1$ld 项：%2$@', '%1$ld개를 병합하여 저장했습니다: %2$@'),
('addToRight', '右のリストに追加', 'Add to Right List', '添加到右侧列表', '오른쪽 목록에 추가'),
('addToLeft', '左のリストに追加', 'Add to Left List', '添加到左侧列表', '왼쪽 목록에 추가'),
('addToRightHelp', '左にしかないものを右のリストの末尾に加えます（⌘Zで取り消せます）', 'Append the items only in the left list to the end of the right list (⌘Z undoes it)', '将仅在左侧的项添加到右侧列表末尾（可用 ⌘Z 撤销）', '왼쪽에만 있는 항목을 오른쪽 목록 끝에 추가합니다(⌘Z로 취소 가능)'),
('addToLeftHelp', '右にしかないものを左のリストの末尾に加えます（⌘Zで取り消せます）', 'Append the items only in the right list to the end of the left list (⌘Z undoes it)', '将仅在右侧的项添加到左侧列表末尾（可用 ⌘Z 撤销）', '오른쪽에만 있는 항목을 왼쪽 목록 끝에 추가합니다(⌘Z로 취소 가능)'),
('addToRightMenu', '左にしかないものを右のリストに追加', 'Add Items Only in Left to Right List', '将仅在左侧的项添加到右侧列表', '왼쪽에만 있는 항목을 오른쪽 목록에 추가'),
('addToLeftMenu', '右にしかないものを左のリストに追加', 'Add Items Only in Right to Left List', '将仅在右侧的项添加到左侧列表', '오른쪽에만 있는 항목을 왼쪽 목록에 추가'),
('addedToRight', '%ld件を右のリストに追加しました。', 'Added %ld items to the right list.', '已将 %ld 项添加到右侧列表。', '오른쪽 목록에 %ld개를 추가했습니다.'),
('addedToLeft', '%ld件を左のリストに追加しました。', 'Added %ld items to the left list.', '已将 %ld 项添加到左侧列表。', '왼쪽 목록에 %ld개를 추가했습니다.'),
('clearHelp', '左右のリストを空にし、ファイルとの連携も外します（ファイルは変更しません）', 'Empty both lists and unlink their files (the files are not changed)', '清空两侧列表并取消文件关联（不更改文件）', '양쪽 목록을 비우고 파일 연결도 해제합니다(파일은 변경하지 않음)'),
('quitUnsavedTitle', '保存していない変更があります', 'You have unsaved changes', '有未存储的更改', '저장하지 않은 변경 사항이 있습니다'),
('quitUnsavedInfo', '%@ への変更は保存されていません。終了すると失われます。', 'Changes to %@ have not been saved. They are lost if you quit.', '对 %@ 的更改尚未存储。退出后将丢失。', '%@의 변경 사항이 저장되지 않았습니다. 종료하면 사라집니다.'),
('quitAnyway', '保存しないで終了', 'Quit Without Saving', '退出而不存储', '저장하지 않고 종료'),
('commonItems', '共通', 'Common', '共有', '공통'),
('copyResult', '「%@」をコピー', 'Copy “%@”', '拷贝“%@”', '"%@" 복사하기'),
('copiedResult', '「%1$@」%2$ld件をコピーしました。', 'Copied %2$ld items from “%1$@”.', '已拷贝“%1$@”中的 %2$ld 项。', '"%1$@" %2$ld개를 복사했습니다.'),
('copyCommonMenu', '共通の項目をコピー', 'Copy Common Items', '拷贝共有的项', '공통 항목 복사하기'),
('saveResultButton', '保存…', 'Save…', '存储…', '저장…'),
('saveResult', '「%@」を保存', 'Save “%@”', '存储“%@”', '"%@" 저장'),
('saveResultHelp', '「%@」を1行に1項目のテキストファイルに保存します', 'Save “%@” to a text file, one item per line', '将“%@”存储为每行一项的文本文件', '"%@"을(를) 한 행에 한 항목인 텍스트 파일로 저장합니다'),
('saveResultTitle', '「%@」を保存', 'Save “%@”', '存储“%@”', '"%@" 저장'),
('saveLeftOnlyMenu', '左にしかないものを保存…', 'Save Items Only in Left…', '存储仅在左侧的项…', '왼쪽에만 있는 항목 저장…'),
('saveCommonMenu', '共通の項目を保存…', 'Save Common Items…', '存储共有的项…', '공통 항목 저장…'),
('saveRightOnlyMenu', '右にしかないものを保存…', 'Save Items Only in Right…', '存储仅在右侧的项…', '오른쪽에만 있는 항목 저장…'),
('nothingToSave', '保存する項目がありません。', 'There is nothing to save.', '没有可存储的项。', '저장할 항목이 없습니다.'),
('statusResultSaved', '%1$ld件を保存しました：%2$@', 'Saved %1$ld items: %2$@', '已存储 %1$ld 项：%2$@', '%1$ld개를 저장했습니다: %2$@'),
('resultClickHelp', '項目をクリックすると、元のリストのその位置を選択します', 'Click an item to select it in the list it comes from', '点按某项可在原列表中选中它', '항목을 클릭하면 원래 목록에서 그 위치를 선택합니다'),
('removeDuplicates', '重複を削除', 'Remove Duplicates', '删除重复项', '중복 삭제'),
('removeDuplicatesHelp', '同じ項目の2つ目以降を取り除きます（⌘Zで取り消せます）', 'Remove the second and later copies of each item (⌘Z undoes it)', '删除每项的第二个及以后的重复（可用 ⌘Z 撤销）', '같은 항목의 두 번째 이후를 삭제합니다(⌘Z로 취소 가능)'),
('duplicatesRemoved', '重複%ld件を削除しました。', 'Removed %ld duplicates.', '已删除 %ld 个重复项。', '중복 %ld개를 삭제했습니다.'),
('dedupeLeftMenu', '左のリストの重複を削除', 'Remove Duplicates in Left List', '删除左侧列表中的重复项', '왼쪽 목록의 중복 삭제'),
('dedupeRightMenu', '右のリストの重複を削除', 'Remove Duplicates in Right List', '删除右侧列表中的重复项', '오른쪽 목록의 중복 삭제'),
('columnLabel', '列', 'Column', '列', '열'),
('columnAll', 'すべての項目', 'All Fields', '所有字段', '모든 항목'),
('columnNumber', '%ld列目', 'Column %ld', '第 %ld 列', '%ld열'),
('columnHelp', '区切り文字で分けた各行のうち、この列だけを比べます（CSVのメール列など）。区切り文字を選ぶと使えます', 'Compare only this column of each row split at the separators (such as the e-mail column of a CSV). Available when a separator is chosen', '只比较按分隔符拆分后各行的这一列（如 CSV 的邮件列）。选择分隔符后可用', '구분 문자로 나눈 각 행 중 이 열만 비교합니다(CSV의 메일 열 등). 구분 문자를 선택하면 사용할 수 있습니다'),
('skipHeader', '1行目は見出し', 'First row is a header', '首行为标题', '첫 행은 제목'),
('skippedColumnCount', '（その列のない行%ld）', '(%ld rows without that column)', '（无该列的行 %ld）', '(그 열이 없는 행 %ld)'),
('replaceUnsavedTitle', '「%@」の変更は保存されていません', 'Changes to “%@” have not been saved', '对“%@”的更改尚未存储', '"%@"의 변경 사항이 저장되지 않았습니다'),
('replaceUnsavedInfo', '別のファイルを読み込むと、その変更は失われます。', 'Loading another file loses those changes.', '载入其他文件将丢失这些更改。', '다른 파일을 불러오면 그 변경 사항이 사라집니다.'),
('replace', '読み込む', 'Load', '载入', '불러오기'),
('splitLabel', 'リストと結果（境界をドラッグして高さを変更）', 'Lists and results (drag the divider to resize)', '列表与结果（拖移分隔线调整高度）', '목록과 결과(경계를 드래그하여 높이 변경)'),
('leftOnly', '左にしかないもの', 'Only in Left', '仅在左侧', '왼쪽에만 있음'),
('rightOnly', '右にしかないもの', 'Only in Right', '仅在右侧', '오른쪽에만 있음'),
('itemCount', '%ld件', '%ld items', '%ld 项', '%ld개'),
('duplicateCount', '（重複%ld）', '(%ld duplicates)', '（重复 %ld）', '(중복 %ld)'),
('noItems', 'なし', 'None', '无', '없음'),
('copyButton', 'コピー', 'Copy', '拷贝', '복사하기'),
('copyLeftOnly', '左にしかないものをコピー', 'Copy Items Only in Left', '拷贝仅在左侧的项', '왼쪽에만 있는 항목 복사하기'),
('copyRightOnly', '右にしかないものをコピー', 'Copy Items Only in Right', '拷贝仅在右侧的项', '오른쪽에만 있는 항목 복사하기'),
('copiedLeft', '左にしかないもの%ld件をコピーしました。', 'Copied %ld items only in the left list.', '已拷贝仅在左侧的 %ld 项。', '왼쪽에만 있는 %ld개를 복사했습니다.'),
('copiedRight', '右にしかないもの%ld件をコピーしました。', 'Copied %ld items only in the right list.', '已拷贝仅在右侧的 %ld 项。', '오른쪽에만 있는 %ld개를 복사했습니다.'),
('nothingToCopy', 'コピーする項目がありません。', 'There is nothing to copy.', '没有可拷贝的项。', '복사할 항목이 없습니다.'),
('statusEmpty', '左右のリストに貼り付けると、すぐに比較します。', 'Paste lists on both sides to compare them right away.', '在两侧粘贴列表后会立即比较。', '양쪽에 목록을 붙여넣으면 바로 비교합니다.'),
('statusSame', '左右のリストは同じです（%ld件）。', 'Both lists have the same items (%ld).', '两个列表的项相同（%ld 项）。', '두 목록의 항목이 같습니다(%ld개).'),
('statusSummary', '共通：%1$ld件　左だけ：%2$ld件　右だけ：%3$ld件', 'Common: %1$ld   Left only: %2$ld   Right only: %3$ld', '共有：%1$ld   仅左侧：%2$ld   仅右侧：%3$ld', '공통: %1$ld   왼쪽만: %2$ld   오른쪽만: %3$ld'),
('errorOpen', '「%@」をテキストとして読み込めませんでした（UTF-8・UTF-16・Shift_JISのテキストに対応）。', 'Could not read “%@” as text (UTF-8, UTF-16 and Shift_JIS text are supported).', '无法将“%@”作为文本读取（支持 UTF-8、UTF-16 和 Shift_JIS 文本）。', '"%@"을(를) 텍스트로 읽을 수 없습니다(UTF-8, UTF-16, Shift_JIS 텍스트 지원).'),
('clear', '左右のリストを消去', 'Clear Both Lists', '清除两侧列表', '양쪽 목록 지우기'),
('clearMenu', '左右のリストを消去', 'Clear Both Lists', '清除两侧列表', '양쪽 목록 지우기'),
('openLeft', '左のリストにファイルを読み込む…', 'Load File into Left List…', '将文件载入左侧列表…', '왼쪽 목록에 파일 불러오기…'),
('openRight', '右のリストにファイルを読み込む…', 'Load File into Right List…', '将文件载入右侧列表…', '오른쪽 목록에 파일 불러오기…'),
('openLeftTitle', '左のリストに読み込むファイル', 'File for the Left List', '载入左侧列表的文件', '왼쪽 목록에 불러올 파일'),
('openRightTitle', '右のリストに読み込むファイル', 'File for the Right List', '载入右侧列表的文件', '오른쪽 목록에 불러올 파일'),
('compareTab', '比較', 'Comparison', '比较', '비교'),
('matchSection', '同じ項目とみなす条件', 'Matching', '视为相同的条件', '같은 항목으로 보는 조건'),
('ignoreCase', '大文字と小文字を区別しない', 'Ignore uppercase and lowercase', '不区分大小写', '대소문자를 구분하지 않음'),
('ignoreCaseHint', 'メールアドレスの比較に向いています（初期値オン）。', 'Suited to e-mail addresses (on by default).', '适合比较电子邮件地址（默认开启）。', '이메일 주소 비교에 적합합니다(기본값 켬).'),
('ignoreWidth', '全角と半角を区別しない', 'Ignore full-width and half-width forms', '不区分全角和半角', '전각과 반각을 구분하지 않음'),
('ignoreWidthHint', '「ＡＢＣ１」と「ABC1」、「ｶﾞ」と「ガ」を同じとみなします。', 'Treats “ＡＢＣ１” and “ABC1” (and half-width katakana) as the same.', '将“ＡＢＣ１”与“ABC1”（以及半角片假名）视为相同。', '"ＡＢＣ１"과 "ABC1"(반각 가타카나 포함)을 같은 것으로 봅니다.'),
('separatorLabel', '区切り文字（改行のほかに）', 'Also split at', '分隔符（除换行外）', '구분 문자(줄바꿈 외)'),
('separatorHelp', '1行に複数の項目がある表計算の行や宛先欄を貼り付けるときに、項目の区切りにする文字を選びます。全角のスペース・カンマも含みます', 'Choose the characters that separate items when a line holds several (spreadsheet rows, address fields). Full-width spaces and commas are included', '粘贴一行中有多项的电子表格行或收件人栏时，选择用来分隔项的字符。包括全角空格和逗号', '한 행에 여러 항목이 있는 스프레드시트 행이나 받는 사람 칸을 붙여넣을 때 항목을 나눌 문자를 선택합니다. 전각 공백과 쉼표 포함'),
('separatorEmailNote', 'メールアドレスのみでは使いません', 'Not used for e-mail addresses', '仅电子邮件地址时不使用', '이메일 주소만에서는 사용 안 함'),
('splitAtSpaces', 'スペース', 'Space', '空格', '공백'),
('splitAtCommas', 'カンマ', 'Comma', '逗号', '쉼표'),
('splitAtTabs', 'タブ', 'Tab', '制表符', '탭'),
('displaySection', '表示', 'Display', '显示', '표시'),
('dimCommon', '共通の項目を薄く表示する', 'Dim common items', '淡化显示共有的项', '공통 항목을 흐리게 표시'),
('dimCommonHint', '左右のリストで、もう一方にもある項目を薄い色で表示します。表示だけで、リストやファイルの内容は変わりません（初期値オン）。', 'In both lists, items also found in the other list are shown in a lighter color. Only the display changes, not the list or the file (on by default).', '在左右列表中，另一侧也有的项以较浅的颜色显示。仅改变显示，不改变列表或文件内容（默认开启）。', '좌우 목록에서 다른 쪽에도 있는 항목을 옅은 색으로 표시합니다. 표시만 바뀌며 목록이나 파일 내용은 바뀌지 않습니다(기본값 켬).'),
('resultSection', '結果', 'Results', '结果', '결과'),
('sortResults', '結果を並べ替える', 'Sort the results', '对结果排序', '결과 정렬'),
('sortResultsHint', 'オフのときは元のリストの順に表示します。', 'When off, the results keep the order of the original list.', '关闭时按原列表的顺序显示。', '끄면 원래 목록의 순서대로 표시합니다.'),
('keepRunning', 'ウインドウを閉じても常駐', 'Keep running after closing the window', '关闭窗口后继续运行', '윈도우를 닫아도 계속 실행'),
('keepRunningHint', 'オフにすると、メインウインドウを閉じたときに終了します。貼り付けたリストは保存されません。', 'When off, closing the main window quits the app. Pasted lists are not saved.', '关闭此项后，关闭主窗口即退出。粘贴的列表不会被保存。', '끄면 메인 윈도우를 닫을 때 종료합니다. 목록은 저장되지 않습니다.'),
('settingsButton', '設定…', 'Settings…', '设置…', '설정…'),
('settings', '設定…', 'Settings…', '设置…', '설정…'),
('settingsTitle', '設定', 'Settings', '设置', '설정'),
('about', 'ListMatchについて', 'About ListMatch', '关于 ListMatch', 'ListMatch에 관하여'),
('services', 'サービス', 'Services', '服务', '서비스'),
('hideApp', 'ListMatchを隠す', 'Hide ListMatch', '隐藏 ListMatch', 'ListMatch 가리기'),
('hideOthers', 'ほかを隠す', 'Hide Others', '隐藏其他', '기타 가리기'),
('showAll', 'すべてを表示', 'Show All', '全部显示', '모두 보기'),
('quit', 'ListMatchを終了', 'Quit ListMatch', '退出 ListMatch', 'ListMatch 종료'),
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
('helpItem', 'ListMatchヘルプ', 'ListMatch Help', 'ListMatch 帮助', 'ListMatch 도움말'),
('support', 'サポート：同梱のREADME.md', 'Support: see the bundled README.md', '支持：请参阅随附的 README.md', '지원: 함께 제공된 README.md 참조'),
]
helptexts = [
'''ListMatch — 2つのリストを比較

使い方
1. 左のリストと右のリストに、1行に1項目ずつ貼り付けます（メールアドレス・名前・品番など）。テキストファイル（.txt・.csv など）を枠へドロップするか、ファイルメニューの「左のリストにファイルを読み込む…」（⌘O）・「右のリストにファイルを読み込む…」（⌥⌘O）で読み込むこともできます。
読み込んだファイルはリストと連携し、リストの上にファイル名とフォルダーを表示します（後述）。
2. 入力するとすぐに比較し、ウインドウの下に結果を表示します。リストと結果の境界をドラッグすると、高さの配分を変えられます（次回も同じ配分で開きます）。共通の件数は中央の行に出ます。
3. 結果の「コピー」ボタン（⇧⌘L・⇧⌘R）で、1行に1項目のテキストとしてクリップボードに入れます。結果の欄は選択してコピーすることもできます。
「左右のリストを消去」で両方を空にし、ファイルとの連携も外します（ファイルは変更しません）。
「左にしかないもの」の下の「右のリストに追加」で、その項目を右のリストの末尾に加えます。「右にしかないもの」の下の「左のリストに追加」も同様です（⌘Zで取り消せます）。追加したリストがファイルと連携していれば「保存」で書き戻せます。
「マージして保存…」（⇧⌘S）で、左右のリストを重複なしでまとめ（左のリストの順に、右にしかないものを続けます）、1行に1項目のUTF-8テキストとして新しいファイルに保存します。
結果は「左にしかないもの」「共通」「右にしかないもの」の3つです。それぞれ「コピー」でクリップボードへ、「保存…」で1行に1項目のテキストファイルに保存できます。結果の項目をクリックすると、元のリストのその位置を選択します（共通の項目は左右とも）。
リストに重複があると、見出しの横に件数と「重複を削除」ボタンが出ます。同じ項目の2つ目以降を取り除きます（⌘Zで取り消せます）。メールアドレスのみでは、アドレスがすべて前に出てきた行を取り除きます。
FinderでListMatchのアイコンへファイルをドロップするか、「このアプリケーションで開く」でも読み込めます。2つなら左と右へ、1つなら空いている側（左が先）へ入ります。

CSVの列を比べる
区切り文字を選ぶと、左右のリストの見出しの下で、リストごとに「列」を指定できます。「2列目」などを選ぶと、各行のその列だけを比べます（CSVのメール列など）。片方をCSVの列、もう片方を普通のリストにして比べられます。「1行目は見出し」をオンにすると先頭の行を除きます。ダブルクォートで囲まれた中の区切り文字（"鈴木, 花子"）は区切りません。その列がない行は無視し、件数を見出しの横に出します。列を選んでいるあいだは、リストを1行1項目に並べ直しません。

ファイルとの連携
ドロップや⌘O・⌥⌘Oで読み込んだファイルは、リストの上にアイコン・ファイル名・フォルダーを表示します。リストを書き換えると「未保存」と表示し、「保存」（左⌘S・右⌥⌘S）で元のファイルに上書きします。文字コードは読み込んだときのまま（表せない文字があればUTF-8）です。上書き前の内容は ~/Library/Application Support/ListMatch/Backups に控えます（新しい20件）。ほかのアプリでファイルが変更されていたら、上書きする前に確認します。虫めがねのボタンでFinderに表示、×のボタンで連携を解除します（リストは残ります）。保存していない変更があるまま終了しようとすると確認します。

比べ方
- 行の前後の空白・タブ、空の行は無視します。
- 同じリストの中で重なった行は1件とみなし、見出しの横に重複の件数を出します。結果には最初に出てきた行の書き方で表示します。
- 結果は元のリストの順です（設定で並べ替えられます）。

メールアドレスのみ
リストの上の「比較の単位」を「メールアドレスのみ」にすると（ファイルメニューの「メールアドレスのみを比較」でも可）、貼り付けたテキストからメールアドレスだけを取り出して比べます。「山田 太郎 <taro@example.jp>」のような宛先欄、カンマ区切りの複数アドレス、CSVの行、署名などをそのまま貼り付けられます。1行に複数のアドレスがあればすべて取り出します。全角のアドレス（ａ＠ｅｘａｍｐｌｅ．ｊｐ）は半角として取り出します。アドレスのない行は無視し、その行数を見出しの横に出します。大文字と小文字は設定に従います（初期値は区別しない）。「行ごと」に戻すと、1行を1項目として比べます。

設定
「比較」タブ：共通の項目を薄く表示する（初期値オン。左右のリストで、もう一方にもある項目を薄い色で表示します。表示だけでリストやファイルは変わりません）、大文字と小文字を区別しない（初期値オン）、全角と半角を区別しない（初期値オフ）、結果を並べ替える（初期値オフ）。
区切り文字はリストの上（比較の単位の右）で選びます：改行のほかにスペース・カンマ・タブ（初期値はすべてオフ。全角のスペースとカンマも含む）。区切り文字をオンにしたとき、ファイルを読み込んだとき、ペーストしたときは、リストを1行に1項目に並べ直して表示します（⌘Zで戻せます。ファイルと連携していれば「未保存」になり、「保存」するまでファイルは変わりません）。入力中の文字は並べ直しません。設定の変更はすぐに結果に反映します。
「起動・常駐」タブ：ログイン時に起動（初期値オフ）、Dockとアプリケーションスイッチャーに表示しない（初期値オフ。オンにするとウインドウを開いていてもDockと⌘Tabの切り替えに出しません。メニューバーのアイコンか、Finderからアプリを開き直すと表示できます）、ウインドウを閉じても常駐（初期値オン）、メニューバーに表示（初期値オフ）。

設定の共有
「設定の共有」タブで、「比較」タブの設定と、区切り文字・比較の単位・列・「1行目は見出し」の選択を書き出し・読み込みできます（「書き出す…」「読み込む…」、ListMatch-Settings.plist）。読み込むと確認のうえ設定を置き換えます。「設定の同期」で iCloud Drive や Dropbox などのフォルダーを選ぶと、複数のMacで同じ設定を使えます（後から保存した内容が優先）。ログイン時の起動・常駐・メニューバーの表示はMacごとに設定します。リストの内容は含みません。

ホットキー
⌘Oで左のリストにファイルを読み込む、⌥⌘Oで右のリストにファイルを読み込む、⌘Sで左のリストを保存、⌥⌘Sで右のリストを保存、⇧⌘Sでマージして保存、⇧⌘Lで左にしかないものをコピー、⇧⌘Rで右にしかないものをコピー、⌘,で設定、⌘0で「メインウインドウを開く」、⌘Wでウインドウを閉じる、⌘Qで終了、⌘?でこのヘルプを開きます。入力欄では⌘Z（取り消す）・⇧⌘Z（やり直す）・カット・コピー・ペーストが使えます。

常駐と終了
メインウインドウを閉じてもアプリは終了せず、入力したリストもそのまま残ります。Dockのアイコンをクリックするか、ファイルメニューの「メインウインドウを開く」で再表示します。終了は⌘Q、またはアプリメニューの「ListMatchを終了」です。貼り付けたリストは保存しないため、終了すると消えます。ファイルと連携したリストは「保存」で書き戻せます。

権限
特別な許可は必要ありません。読み書きするのは、自分で選んだりドロップしたりしたファイルと、保存先に選んだファイル、バックアップのフォルダーだけです。

困ったとき
同じはずの項目が「しかないもの」に出る：大文字・小文字や全角・半角の違いがないか確認し、設定の「比較」タブで区別しないようにしてください。行の中の余分な空白（「a @x.jp」など）は同じとみなしません。
1行に複数の項目がある：リストの上の「区切り文字」で、スペース・カンマ・タブから区切りに使う文字を選んでください。メールアドレスなら「メールアドレスのみ」も使えます。
ファイルを読み込めない：UTF-8・UTF-16・Shift_JISのテキストに対応しています。Excelなどのファイルは、テキスト（CSV）で書き出してから読み込んでください。

プライバシー
比較はすべてこのMac上で行い、リストを外部に送りません。貼り付けたリストは保存しません。アプリが保存するのは設定（UserDefaults）と、上書き前のバックアップだけです。
「アップデートを確認…」は共通の更新機能ですが、このビルドでは配信先と署名が未設定のため準備中と表示し、通信しません。
サポート：同梱のREADME.md（アプリ内の Contents/Resources/README.md）をご覧ください。
手動起動・開き直しではメインウインドウを表示し、ログイン時の自動起動では表示しません。
''',
'''ListMatch — Compare two lists

How to use
1. Paste one item per line into the left list and the right list (e-mail addresses, names, product codes…). You can also drop a text file (.txt, .csv…) on a list, or use File → Load File into Left List… (⌘O) / Load File into Right List… (⌥⌘O).
A loaded file stays linked to its list; its name and folder appear above the list (see below).
2. The lists are compared as you type and the results appear at the bottom of the window. Drag the boundary between the lists and the results to change their heights (remembered). The number of common items appears in the middle line.
3. Copy (⇧⌘L / ⇧⌘R) puts a result on the clipboard, one item per line. You can also select text in a result and copy it.
Clear Both Lists empties both lists and unlinks their files (the files are not changed).
Add to Right List below Only in Left appends those items to the end of the right list; Add to Left List below Only in Right does the same the other way (⌘Z undoes it). If that list is linked to a file, Save writes it back.
Merge and Save… (⇧⌘S) combines both lists without repeats (the left list, then the items only in the right list) and saves them to a new UTF-8 text file, one item per line.
The results are Only in Left, Common and Only in Right. Copy puts one on the clipboard and Save… writes it to a text file, one item per line. Click an item in a result to select it in the list it comes from (both lists for common items).
When a list has duplicates, the count and a Remove Duplicates button appear next to its title. It removes the second and later copies (⌘Z undoes it). With E-mail Addresses Only, lines whose addresses all appeared earlier are removed.
You can also drop files on the ListMatch icon in Finder or use Open With. Two files go left and right; one goes to the empty side (left first).

Comparing a CSV column
When a separator is chosen, each list gets its own Column choice below its title. With Column 2, for example, only that column of each row is compared (such as the e-mail column of a CSV). One list can be a CSV column and the other a plain list. First row is a header leaves out the first row. Separators inside double quotes ("Suzuki, Hanako") do not split. Rows without that column are ignored and counted next to the list title. While a column is chosen, lists are not rearranged one item per line.

Linked files
A file you drop or open with ⌘O / ⌥⌘O shows its icon, name and folder above the list. When you change the list it is marked Unsaved; Save (left ⌘S, right ⌥⌘S) writes it back to the file in its original encoding (UTF-8 if some characters do not fit). The previous contents are copied to ~/Library/Application Support/ListMatch/Backups (newest 20). If another app changed the file, you are asked before it is overwritten. The magnifying glass shows the file in Finder and × unlinks it (the list stays). Quitting with unsaved changes asks first.

How lists are compared
- Spaces and tabs at the start and end of a line, and empty lines, are ignored.
- A line repeated within the same list counts once; the number of duplicates appears next to the list title. Results use the first way the item was written.
- Results keep the order of the original list (they can be sorted in Settings).

E-mail Addresses Only
Set Compare by (above the lists) to E-mail Addresses Only (or choose File → Compare E-mail Addresses Only) to pick out just the e-mail addresses from the pasted text. You can paste address fields such as “Taro Yamada <taro@example.jp>”, comma-separated addresses, CSV rows or signatures as they are. Every address on a line is used. Full-width addresses are read as half-width. Lines without an address are ignored and counted next to the list title. Case follows the setting (ignored by default). Switch back to Lines to compare one item per line.

Settings
Comparison: Dim common items (on by default; items also in the other list are shown lighter, the list and file are not changed), Ignore uppercase and lowercase (on by default), Ignore full-width and half-width forms (off), Sort the results (off).
Separators are chosen above the lists (next to Compare by): Space, Comma and Tab besides line breaks (all off by default; full-width spaces and commas included). When you turn a separator on, load a file or paste, the list is rearranged one item per line (⌘Z undoes it; a linked file is marked Unsaved and does not change until you save). Typing is not rearranged. Setting changes apply to the results right away.
Startup & Background: Launch at login (off), Hide from Dock and App Switcher (off; when on, the app stays out of the Dock and ⌘Tab even with a window open — show it from the menu-bar icon or by opening the app again in Finder), Keep running after closing the window (on), Show in menu bar (off).

Sharing settings
In the Sharing tab, Export… and Import… save and load the Compare tab settings and the separator, comparison unit, column and header-row choices as ListMatch-Settings.plist. Importing asks first, then replaces the settings. Settings Sync keeps them the same on several Macs through a folder such as iCloud Drive or Dropbox (the most recent save wins). Open at login, keep running and the menu bar icon are set on each Mac. The lists themselves are not included.

Hotkeys
⌘O load a file into the left list, ⌥⌘O load a file into the right list, ⌘S save the left list, ⌥⌘S save the right list, ⇧⌘S merge and save, ⇧⌘L copy the items only in the left list, ⇧⌘R copy the items only in the right list, ⌘, settings, ⌘0 Open Main Window, ⌘W close the window, ⌘Q quit, ⌘? this help. Undo (⌘Z), Redo (⇧⌘Z), cut, copy and paste work in the lists.

Running and quitting
Closing the main window does not quit the app, and the lists stay as they are. Click the Dock icon or choose File → Open Main Window to show it again. Quit with ⌘Q or Quit ListMatch in the app menu. Pasted lists are not saved, so they are gone after quitting. A list linked to a file can be saved back with Save.

Permissions
No special permission is needed. The app reads and writes only the files you choose, drop or save to, and its backup folder.

Troubleshooting
An item that should match appears in a result: check for differences in case or in full-width/half-width forms and turn on the matching options in the Comparison tab. Extra spaces inside a line (such as “a @x.jp”) still make a difference.
Several items on one line: choose Space, Comma or Tab under Also split at above the lists. For e-mail addresses, E-mail Addresses Only also works.
A file cannot be read: UTF-8, UTF-16 and Shift_JIS text are supported. Export spreadsheets as text (CSV) first.

Privacy
All comparison happens on this Mac; the lists are never sent anywhere. Pasted lists are not saved. The app stores only its settings (UserDefaults) and backups made before overwriting.
Check for Updates… is the shared update feature, but this build has no update feed or signing key yet, so it shows that updates are being prepared and makes no connection.
Support: see the bundled README.md (Contents/Resources/README.md in the app).
Manual launch and reopening show the main window; automatic login launch does not.
''',
'''ListMatch — 比较两个列表

使用方法
1. 在左侧列表和右侧列表中每行粘贴一项（电子邮件地址、姓名、货号等）。也可以将文本文件（.txt、.csv 等）拖放到列表上，或使用“文件”>“将文件载入左侧列表…”（⌘O）／“将文件载入右侧列表…”（⌥⌘O）。
载入的文件会与列表关联，文件名和文件夹显示在列表上方（见下文）。
2. 输入时立即比较，结果显示在窗口下方。拖移列表与结果之间的分隔线可调整高度（下次保持）。共有的项数显示在中间一行。
3. 点按结果的“拷贝”（⇧⌘L／⇧⌘R）可将结果以每行一项的文本放入剪贴板。也可以在结果中选择文本后拷贝。
“清除两侧列表”清空两侧并取消文件关联（不更改文件）。
“仅在左侧”下方的“添加到右侧列表”会将这些项添加到右侧列表末尾；“仅在右侧”下方的“添加到左侧列表”同理（可用 ⌘Z 撤销）。若该列表已关联文件，可用“存储”写回。
“合并并存储…”（⇧⌘S）将左右列表去重合并（左侧列表在前，后接仅在右侧的项），以每行一项的 UTF-8 文本存储为新文件。
结果分为“仅在左侧”“共有”“仅在右侧”三项。可用“拷贝”放入剪贴板，用“存储…”存储为每行一项的文本文件。点按结果中的项可在原列表中选中它（共有的项在左右两侧都会选中）。
列表中有重复时，标题旁会显示数量和“删除重复项”按钮，可删除每项的第二个及以后的重复（可用 ⌘Z 撤销）。在“仅电子邮件地址”下，会删除所有地址都已出现过的行。
也可以在访达中将文件拖放到 ListMatch 图标上，或使用“打开方式”。两个文件分别载入左右，一个文件载入空着的一侧（优先左侧）。

比较 CSV 的列
选择分隔符后，可在左右列表标题下方分别指定“列”。例如选择“第 2 列”，只比较各行的该列（如 CSV 的邮件列）。可以一侧用 CSV 的列、另一侧用普通列表进行比较。开启“首行为标题”会排除第一行。双引号内的分隔符（"铃木, 花子"）不会拆分。没有该列的行会被忽略，数量显示在标题旁。选择列时不会将列表重新排列为每行一项。

文件关联
拖放或用 ⌘O／⌥⌘O 载入的文件会在列表上方显示图标、文件名和文件夹。更改列表后显示“未存储”，“存储”（左 ⌘S、右 ⌥⌘S）会按原编码覆盖原文件（无法表示的字符改用 UTF-8）。覆盖前的内容备份到 ~/Library/Application Support/ListMatch/Backups（最新 20 个）。如果文件已被其他应用更改，覆盖前会确认。放大镜按钮在访达中显示，× 按钮取消关联（列表保留）。有未存储的更改时退出会先确认。

比较方式
- 忽略行首尾的空格和制表符以及空行。
- 同一列表中重复的行只算一项，列表标题旁显示重复数。结果按首次出现时的写法显示。
- 结果按原列表的顺序显示（可在设置中排序）。

仅电子邮件地址
将列表上方的“比较单位”设为“仅电子邮件地址”（或选择“文件”>“仅比较电子邮件地址”），会从粘贴的文本中只取出电子邮件地址进行比较。可直接粘贴“Taro Yamada <taro@example.jp>”这样的收件人栏、逗号分隔的多个地址、CSV 行或签名。一行中的所有地址都会被取出。全角地址按半角提取。没有地址的行会被忽略，其行数显示在列表标题旁。大小写按设置处理（默认不区分）。切换回“按行”即可按每行一项比较。

设置
“比较”：淡化显示共有的项（默认开启；另一侧也有的项以较浅颜色显示，不改变列表或文件）、不区分大小写（默认开启）、不区分全角和半角（默认关闭）、对结果排序（默认关闭）。
分隔符在列表上方（比较单位右侧）选择：除换行外还可选空格、逗号、制表符（默认全部关闭，包括全角空格和逗号）。开启分隔符、载入文件或粘贴时，列表会重新排列为每行一项（可用 ⌘Z 撤销；已关联的文件显示“未存储”，存储前文件不会改变）。输入中的文字不会重新排列。设置的更改会立即反映到结果中。
“启动与后台”：登录时启动（关闭）、不在程序坞和应用程序切换器中显示（关闭；开启后即使窗口打开也不会出现在程序坞和 ⌘Tab 中，可通过菜单栏图标或在访达中再次打开应用来显示）、关闭窗口后继续运行（开启）、在菜单栏中显示（关闭）。

设置共享
在“设置共享”标签中，可以导出和导入“比较”标签的设置，以及分隔符、比较单位、列和“第一行是标题”的选择（“导出…”“导入…”，ListMatch-Settings.plist）。导入时会先确认，再替换设置。在“设置同步”中选择 iCloud 云盘或 Dropbox 等文件夹，即可在多台 Mac 上使用相同的设置（以最后保存的为准）。登录时启动、保持运行和菜单栏图标在每台 Mac 上分别设置。不包含列表内容。

快捷键
⌘O 将文件载入左侧列表，⌥⌘O 将文件载入右侧列表，⌘S 存储左侧列表，⌥⌘S 存储右侧列表，⇧⌘S 合并并存储，⇧⌘L 拷贝仅在左侧的项，⇧⌘R 拷贝仅在右侧的项，⌘, 设置，⌘0 打开主窗口，⌘W 关闭窗口，⌘Q 退出，⌘? 打开本帮助。列表中可使用撤销（⌘Z）、重做（⇧⌘Z）、剪切、拷贝和粘贴。

后台运行与退出
关闭主窗口不会退出应用，输入的列表也会保留。点按程序坞图标或选择“文件”>“打开主窗口”即可重新显示。按 ⌘Q 或在应用菜单中选择“退出 ListMatch”退出。粘贴的列表不会保存，退出后即消失。已关联文件的列表可用“存储”写回。

权限
不需要特殊权限。只读写你选择、拖放或存储到的文件以及备份文件夹。

疑难解答
应相同的项出现在结果中：请检查大小写或全角／半角的差异，并在“比较”中开启相应选项。行内多余的空格（如“a @x.jp”）仍视为不同。
一行中有多个项：请在列表上方的“分隔符”中选择空格、逗号或制表符。电子邮件地址也可使用“仅电子邮件地址”。
无法读取文件：支持 UTF-8、UTF-16 和 Shift_JIS 文本。电子表格请先导出为文本（CSV）。

隐私
所有比较都在这台 Mac 上进行，列表不会发送到任何地方。粘贴的列表不会保存。应用只保存设置（UserDefaults）和覆盖前的备份。
“检查更新…”是通用更新功能，但此版本尚未设置更新源和签名密钥，因此显示为准备中，不会进行通信。
支持：请参阅随附的 README.md（应用内的 Contents/Resources/README.md）。
手动启动或重新打开时显示主窗口，登录时自动启动不显示主窗口。
''',
'''ListMatch — 두 목록 비교

사용 방법
1. 왼쪽 목록과 오른쪽 목록에 한 행에 한 항목씩 붙여넣습니다(이메일 주소, 이름, 품번 등). 텍스트 파일(.txt, .csv 등)을 목록에 드롭하거나, 파일 메뉴의 왼쪽 목록에 파일 불러오기…(⌘O) / 오른쪽 목록에 파일 불러오기…(⌥⌘O)로 불러올 수도 있습니다.
불러온 파일은 목록과 연결되며, 목록 위에 파일 이름과 폴더가 표시됩니다(아래 참조).
2. 입력하는 즉시 비교하여 윈도우 아래에 결과를 표시합니다. 목록과 결과의 경계를 드래그하면 높이를 바꿀 수 있습니다(다음에도 유지). 공통 항목 수는 가운데 행에 표시됩니다.
3. 결과의 복사하기(⇧⌘L / ⇧⌘R)로 한 행에 한 항목인 텍스트를 클립보드에 넣습니다. 결과에서 텍스트를 선택해 복사할 수도 있습니다.
양쪽 목록 지우기는 양쪽 목록을 비우고 파일 연결도 해제합니다(파일은 변경하지 않음).
왼쪽에만 있음 아래의 오른쪽 목록에 추가는 해당 항목을 오른쪽 목록 끝에 추가합니다. 오른쪽에만 있음 아래의 왼쪽 목록에 추가도 같습니다(⌘Z로 취소 가능). 그 목록이 파일과 연결되어 있으면 저장으로 다시 쓸 수 있습니다.
병합하여 저장…(⇧⌘S)은 좌우 목록을 중복 없이 합쳐(왼쪽 목록 다음에 오른쪽에만 있는 항목) 한 행에 한 항목인 UTF-8 텍스트로 새 파일에 저장합니다.
결과는 왼쪽에만 있음, 공통, 오른쪽에만 있음의 세 가지입니다. 복사하기로 클립보드에 넣고, 저장…으로 한 행에 한 항목인 텍스트 파일에 저장할 수 있습니다. 결과의 항목을 클릭하면 원래 목록에서 그 위치를 선택합니다(공통 항목은 양쪽 모두).
목록에 중복이 있으면 제목 옆에 개수와 중복 삭제 버튼이 나타납니다. 같은 항목의 두 번째 이후를 삭제합니다(⌘Z로 취소 가능). 이메일 주소만에서는 주소가 모두 앞에 나온 행을 삭제합니다.
Finder에서 ListMatch 아이콘에 파일을 드롭하거나 다음으로 열기로도 불러올 수 있습니다. 두 개면 왼쪽과 오른쪽에, 하나면 비어 있는 쪽(왼쪽 우선)에 들어갑니다.

CSV 열 비교
구분 문자를 선택하면 좌우 목록 제목 아래에서 목록마다 열을 지정할 수 있습니다. 예를 들어 2열을 선택하면 각 행의 그 열만 비교합니다(CSV의 메일 열 등). 한쪽은 CSV의 열, 다른 쪽은 일반 목록으로 비교할 수 있습니다. 첫 행은 제목을 켜면 첫 행을 제외합니다. 큰따옴표 안의 구분 문자("스즈키, 하나코")는 나누지 않습니다. 그 열이 없는 행은 무시하고 개수를 제목 옆에 표시합니다. 열을 선택한 동안에는 목록을 한 행에 한 항목으로 다시 배열하지 않습니다.

파일 연결
드롭하거나 ⌘O / ⌥⌘O로 불러온 파일은 목록 위에 아이콘, 파일 이름, 폴더를 표시합니다. 목록을 바꾸면 저장 안 됨으로 표시되고, 저장(왼쪽 ⌘S, 오른쪽 ⌥⌘S)으로 원래 인코딩 그대로 원본 파일에 덮어씁니다(표현할 수 없는 문자가 있으면 UTF-8). 덮어쓰기 전 내용은 ~/Library/Application Support/ListMatch/Backups에 백업합니다(최신 20개). 다른 앱에서 파일이 변경되었으면 덮어쓰기 전에 확인합니다. 돋보기 버튼은 Finder에서 보기, × 버튼은 연결 해제입니다(목록은 남음). 저장하지 않은 변경 사항이 있으면 종료 전에 확인합니다.

비교 방법
- 행 앞뒤의 공백과 탭, 빈 행은 무시합니다.
- 같은 목록 안에서 반복된 행은 한 개로 보고, 목록 제목 옆에 중복 개수를 표시합니다. 결과는 처음 나온 행의 표기로 표시합니다.
- 결과는 원래 목록의 순서입니다(설정에서 정렬 가능).

이메일 주소만
목록 위의 비교 단위를 이메일 주소만으로 하면(파일 메뉴의 이메일 주소만 비교도 가능) 붙여넣은 텍스트에서 이메일 주소만 꺼내 비교합니다. "Taro Yamada <taro@example.jp>" 같은 받는 사람 칸, 쉼표로 구분된 여러 주소, CSV 행, 서명 등을 그대로 붙여넣을 수 있습니다. 한 행의 주소는 모두 꺼냅니다. 전각 주소는 반각으로 꺼냅니다. 주소가 없는 행은 무시하고 그 행 수를 목록 제목 옆에 표시합니다. 대소문자는 설정을 따릅니다(기본값은 구분하지 않음). 행 단위로 되돌리면 한 행을 한 항목으로 비교합니다.

설정
비교 탭: 공통 항목을 흐리게 표시(기본값 켬, 다른 쪽에도 있는 항목을 옅은 색으로 표시하며 목록이나 파일은 바뀌지 않음), 대소문자를 구분하지 않음(기본값 켬), 전각과 반각을 구분하지 않음(끔), 결과 정렬(끔).
구분 문자는 목록 위(비교 단위 오른쪽)에서 선택합니다: 줄바꿈 외에 공백, 쉼표, 탭(기본값은 모두 끔, 전각 공백과 쉼표 포함). 구분 문자를 켜거나 파일을 불러오거나 붙여넣으면 목록을 한 행에 한 항목으로 다시 배열해 표시합니다(⌘Z로 되돌릴 수 있음. 연결된 파일은 저장 안 됨으로 표시되며 저장하기 전에는 파일이 바뀌지 않음). 입력 중인 문자는 다시 배열하지 않습니다. 설정 변경은 결과에 바로 반영됩니다.
시작 및 백그라운드 탭: 로그인 시 실행(끔), Dock 및 앱 전환기에 표시 안 함(끔. 켜면 윈도우가 열려 있어도 Dock과 ⌘Tab에 표시하지 않습니다. 메뉴 막대 아이콘이나 Finder에서 앱을 다시 열어 표시할 수 있습니다), 윈도우를 닫아도 계속 실행(켬), 메뉴 막대에 표시(끔).

설정 공유
설정 공유 탭에서 비교 탭의 설정과 구분 문자, 비교 단위, 열, 첫 행은 머리글 선택을 내보내고 가져올 수 있습니다(내보내기…, 가져오기…, ListMatch-Settings.plist). 가져올 때는 확인한 뒤 설정을 바꿉니다. 설정 동기화에서 iCloud Drive나 Dropbox 같은 폴더를 선택하면 여러 Mac에서 같은 설정을 사용할 수 있습니다(나중에 저장한 내용이 우선). 로그인 시 실행, 계속 실행, 메뉴 막대 아이콘은 Mac마다 설정합니다. 목록 내용은 포함하지 않습니다.

단축키
⌘O 왼쪽 목록에 파일 불러오기, ⌥⌘O 오른쪽 목록에 파일 불러오기, ⌘S 왼쪽 목록 저장, ⌥⌘S 오른쪽 목록 저장, ⇧⌘S 병합하여 저장, ⇧⌘L 왼쪽에만 있는 항목 복사하기, ⇧⌘R 오른쪽에만 있는 항목 복사하기, ⌘, 설정, ⌘0 메인 윈도우 열기, ⌘W 윈도우 닫기, ⌘Q 종료, ⌘? 이 도움말. 목록에서는 실행 취소(⌘Z), 실행 복귀(⇧⌘Z), 오려두기, 복사하기, 붙여넣기를 사용할 수 있습니다.

백그라운드 실행과 종료
메인 윈도우를 닫아도 앱은 종료되지 않으며 입력한 목록도 그대로 남습니다. Dock 아이콘을 클릭하거나 파일 메뉴의 메인 윈도우 열기로 다시 표시합니다. ⌘Q 또는 앱 메뉴의 ListMatch 종료로 종료합니다. 붙여넣은 목록은 저장되지 않으므로 종료하면 사라집니다. 파일과 연결된 목록은 저장으로 다시 쓸 수 있습니다.

권한
특별한 권한이 필요하지 않습니다. 직접 선택, 드롭, 저장한 파일과 백업 폴더만 읽고 씁니다.

문제 해결
같아야 할 항목이 결과에 나타남: 대소문자나 전각/반각 차이가 있는지 확인하고 비교 탭에서 해당 옵션을 켜세요. 행 안의 여분의 공백(예: "a @x.jp")은 여전히 다른 것으로 봅니다.
한 행에 여러 항목이 있음: 목록 위의 구분 문자에서 공백, 쉼표, 탭 중 사용할 문자를 선택하세요. 이메일 주소라면 이메일 주소만도 사용할 수 있습니다.
파일을 읽을 수 없음: UTF-8, UTF-16, Shift_JIS 텍스트를 지원합니다. 스프레드시트는 먼저 텍스트(CSV)로 내보내세요.

개인정보
모든 비교는 이 Mac에서 이루어지며 목록을 외부로 보내지 않습니다. 붙여넣은 목록은 저장하지 않습니다. 앱은 설정(UserDefaults)과 덮어쓰기 전 백업만 저장합니다.
업데이트 확인…은 공통 업데이트 기능이지만, 이 빌드는 배포 주소와 서명이 설정되지 않아 준비 중으로 표시하고 통신하지 않습니다.
지원: 함께 제공된 README.md(앱 내부 Contents/Resources/README.md)를 참조하세요.''',
]
for idx, lang in enumerate(LANGS):
    folder = root / 'Resources' / f'{lang}.lproj'; folder.mkdir(parents=True, exist_ok=True)
    values = {r[0]: r[idx + 1] for r in rows}; values['helpContent'] = helptexts[idx]
    (folder / 'Localizable.strings').write_text('\n'.join(json.dumps(k, ensure_ascii=False) + ' = ' + json.dumps(v, ensure_ascii=False) + ';' for k, v in values.items()) + '\n')
    (folder / 'Help.txt').write_text(helptexts[idx].rstrip() + '\n')
    (folder / 'InfoPlist.strings').write_text('"CFBundleDisplayName" = "ListMatch";\n')
info = {'CFBundleName': 'ListMatch', 'CFBundleDisplayName': 'ListMatch', 'CFBundleIdentifier': 'jp.dtp-transit.listdiff', 'CFBundleExecutable': 'ListMatch', 'CFBundlePackageType': 'APPL', 'CFBundleIconFile': 'ListMatch.icns', 'LSMinimumSystemVersion': '13.0', 'LSMultipleInstancesProhibited': True, 'NSHighResolutionCapable': True, 'CFBundleDevelopmentRegion': 'en', 'CFBundleLocalizations': LANGS, 'NSPrincipalClass': 'NSApplication', 'LSApplicationCategoryType': 'public.app-category.productivity', 'SWAppFamily': 'swwwitch', 'NSHumanReadableCopyright': '© 2026 swwwitch', 'SWNoteArticleURL': 'https://note.com/swwwitch/n/n27269d6eaf5b', 'CFBundleShortVersionString': '1.0.0', 'CFBundleVersion': '1', 'CFBundleDocumentTypes': [{'CFBundleTypeName': 'Text', 'CFBundleTypeRole': 'Editor', 'LSHandlerRank': 'Alternate', 'LSItemContentTypes': ['public.plain-text', 'public.comma-separated-values-text', 'public.tab-separated-values-text', 'public.text']}]}
# Version and build come from the existing Info.plist, so regeneration never reverts them.
plist_path = root / 'Info.plist'; current = plistlib.loads(plist_path.read_bytes()) if plist_path.exists() else {}
info.update({k: current[k] for k in ('CFBundleShortVersionString', 'CFBundleVersion') if k in current})
plist_path.write_bytes(plistlib.dumps(info))
