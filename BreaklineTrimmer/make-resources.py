#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Writes Resources/<lang>.lproj (Localizable.strings, Help.txt, InfoPlist.strings) and Info.plist.
Edit the strings here, then run this script; the version and build in Info.plist are kept."""
from pathlib import Path
import json, plistlib

root = Path(__file__).resolve().parent
LANGS = ['ja', 'en', 'zh-Hans', 'ko']

rows = [
# Main window
('headline', '省略線でトリミング', 'Trim with Break Lines', '用省略线裁切', '생략선으로 트리밍'),
('subtitle', '取り除く範囲をドラッグで描くと、残りを詰めて切り口に省略線を引き、PNG・JPEG・PSDで書き出します。', 'Drag over the area to remove: the rest closes up, break lines are drawn along the cut, and it is saved as PNG, JPEG or PSD.', '拖动绘制要去除的范围，剩余部分会靠拢，并在切口画上省略线，以 PNG、JPEG 或 PSD 导出。', '제거할 범위를 드래그해 그리면 나머지를 붙이고 절단면에 생략선을 그려 PNG, JPEG, PSD로 내보냅니다.'),
('sourceTitle', '元画像', 'Original', '原图', '원본 이미지'),
('previewTitle', 'プレビュー', 'Preview', '预览', '미리보기'),
('pixelSize', '%ld × %ld px', '%ld × %ld px', '%ld × %ld 像素', '%ld × %ld px'),
('dropHere', '画像をここにドロップ', 'Drop an image here', '将图像拖放到此处', '이미지를 여기에 드롭'),
('dropHint', 'PNG・JPEG・HEIC・PSDなど。透明な部分はそのまま残ります。\nファイルメニューの「処理する画像を開く…」（⌘O）や、画像のペースト（⌘V）でも読み込めます。', 'PNG, JPEG, HEIC, PSD and more. Transparent areas stay transparent.\nYou can also use File > Open Image to Trim… (⌘O) or paste an image (⌘V).', '支持 PNG、JPEG、HEIC、PSD 等。透明部分保持透明。\n也可以使用“文件”菜单中的“打开要处理的图像…”（⌘O）或粘贴图像（⌘V）。', 'PNG, JPEG, HEIC, PSD 등. 투명한 부분은 그대로 유지됩니다.\n파일 메뉴의 \'처리할 이미지 열기…\'(⌘O)나 이미지 붙여넣기(⌘V)로도 불러올 수 있습니다.'),
('openImageButton', '処理する画像を開く…', 'Open Image to Trim…', '打开要处理的图像…', '처리할 이미지 열기…'),
('canvasLabel', '元画像', 'Original image', '原图', '원본 이미지'),
('canvasHint', '青いガイドをドラッグすると、取り除く範囲の端を動かせます。範囲の内側をドラッグすると移動し、外側をドラッグすると描き直します。', 'Drag a blue guide to move that edge of the area to remove. Drag inside the area to move it, or outside it to draw a new one.', '拖动蓝色参考线可移动要去除范围的边缘。在范围内拖动可移动它，在范围外拖动可重新绘制。', '파란색 가이드를 드래그하면 제거할 범위의 가장자리를 움직일 수 있습니다. 범위 안쪽을 드래그하면 이동하고, 바깥쪽을 드래그하면 다시 그립니다.'),
('previewLabel', '結果のプレビュー', 'Result preview', '结果预览', '결과 미리보기'),
('previewBackground', '背景', 'Background', '背景', '배경'),
('previewBackgroundHelp', '透明な部分に敷く背景です。プレビューに加えて、保存・コピーする画像にも反映します。', 'What fills the transparent areas, in the preview and in the saved or copied image.', '填充透明部分的背景。除预览外，也会应用到存储或拷贝的图像。', '투명한 부분에 까는 배경입니다. 미리보기뿐 아니라 저장하거나 복사하는 이미지에도 반영됩니다.'),
('background.transparent', '透明', 'Transparent', '透明', '투명'),
('background.white', '白', 'White', '白色', '흰색'),
('background.gray', 'グレー', 'Gray', '灰色', '회색'),
('background.black', '黒', 'Black', '黑色', '검은색'),
('previewEmpty', '画像を開くと、結果をここに表示します。', 'Open an image to see the result here.', '打开图像后，结果会显示在这里。', '이미지를 열면 결과를 여기에 표시합니다.'),
('help', 'ヘルプ', 'Help', '帮助', '도움말'),
('settingsButton', '設定…', 'Settings…', '设置…', '설정…'),
('copyButton', 'コピー', 'Copy', '拷贝', '복사하기'),
('copyHelp', '結果の画像を、透明部分を保ったままクリップボードにコピーします（⇧⌘C）', 'Copy the result to the clipboard, keeping transparency (⇧⌘C)', '将结果图像拷贝到剪贴板，保留透明部分（⇧⌘C）', '결과 이미지를 투명한 부분을 유지한 채 클립보드에 복사합니다(⇧⌘C)'),
('saveButton', '%@で保存…', 'Save as %@…', '存储为 %@…', '%@로 저장…'),
('saveHelp', '結果をPNG・JPEG・PSDのいずれかで保存します。形式は右側の「ファイル形式」、保存先とファイル名は設定の「出力」で決めます。元画像は変更しません（⌘S）', 'Save the result as PNG, JPEG or PSD; the format is set under File format on the right, the location and name in the Output settings. The original is not changed (⌘S)', '将结果存储为 PNG、JPEG 或 PSD。格式在右侧的“文件格式”中指定，存储位置和文件名在设置的“输出”中指定。不会更改原图（⌘S）', "결과를 PNG, JPEG, PSD 중 하나로 저장합니다. 형식은 오른쪽 '파일 형식'에서, 저장 위치와 파일 이름은 설정의 '출력'에서 정합니다. 원본 이미지는 변경하지 않습니다(⌘S)"),
('saveButtonDirect', '%@で保存', 'Save as %@', '存储为 %@', '%@로 저장'),
('saveMenuDirect', '%@で保存', 'Save as %@', '存储为 %@', '%@로 저장'),
('folderMissing', '保存先のフォルダが見つかりません（%@）。保存する場所を選んでください。', 'The destination folder was not found (%@). Choose where to save.', '找不到存储文件夹（%@）。请选择存储位置。', '저장할 폴더를 찾을 수 없습니다(%@). 저장할 위치를 선택하세요.'),
('outputTab', '出力', 'Output', '输出', '출력'),
('outputLocationSection', '保存先', 'Save to', '存储位置', '저장 위치'),
('locationSame', '元画像と同じフォルダ', 'The original image\'s folder', '与原图相同的文件夹', '원본 이미지와 같은 폴더'),
('locationDesktop', 'デスクトップ', 'Desktop', '桌面', '데스크탑'),
('locationFixed', '指定したフォルダ', 'A chosen folder', '指定的文件夹', '지정한 폴더'),
('locationAsk', '毎回指定する', 'Ask each time', '每次指定', '매번 지정'),
('folderNotSet', '未設定', 'Not set', '未设置', '설정 안 됨'),
('chooseFolderButton', '選択…', 'Choose…', '选择…', '선택…'),
('chooseFolderTitle', '保存先のフォルダを選択', 'Choose the Destination Folder', '选择存储文件夹', '저장할 폴더 선택'),
('chooseFolderPrompt', '選択', 'Choose', '选择', '선택'),
('outputLocationHint', '「毎回指定する」以外では、保存するときに場所を尋ねません。同じ名前のファイルがあるときは置き換えず、「名前-breakline 2.png」のように番号を付けます。ペーストした画像を「元画像と同じフォルダ」で保存するときは、場所を尋ねます。指定したフォルダはMacごとの設定です。', 'Except with Ask each time, saving does not ask where. An existing file is never replaced: the new one is numbered, like “name-breakline 2.png”. A pasted image saved with The original image\'s folder asks where. The chosen folder is set on each Mac.', '除“每次指定”外，存储时不会询问位置。已有同名文件时不会替换，而是加上编号，如“名称-breakline 2.png”。以“与原图相同的文件夹”存储粘贴的图像时会询问位置。指定的文件夹需在每台 Mac 上分别设置。', '\'매번 지정\' 외에는 저장할 때 위치를 묻지 않습니다. 같은 이름의 파일이 있으면 바꾸지 않고 \'이름-breakline 2.png\'처럼 번호를 붙입니다. 붙여넣은 이미지를 \'원본 이미지와 같은 폴더\'로 저장할 때는 위치를 묻습니다. 지정한 폴더는 Mac마다 설정합니다.'),
('formatSection', 'ファイル形式', 'File format', '文件格式', '파일 형식'),
('jpegFillsWhite', 'JPEGは透明を持てないため、透明な部分は白になります。', 'JPEG has no transparency: transparent areas become white.', 'JPEG 无法保存透明，透明部分会变为白色。', 'JPEG는 투명을 담을 수 없어 투명한 부분은 흰색이 됩니다.'),
('formatHint', 'PNGとPSDは透明な部分を保ちます。JPEGは透明を持てないため、背景が「透明」のときは白で塗ります（画質90%）。コピーは常にPNGです。', 'PNG and PSD keep transparent areas. JPEG cannot hold transparency, so a Transparent background is saved as white (quality 90%). Copy always uses PNG.', 'PNG 和 PSD 保留透明部分。JPEG 无法保存透明，因此背景为“透明”时以白色填充（品质 90%）。拷贝始终使用 PNG。', "PNG와 PSD는 투명한 부분을 유지합니다. JPEG는 투명을 담을 수 없어 배경이 '투명'이면 흰색으로 칠합니다(화질 90%). 복사는 항상 PNG입니다."),
('afterSaveSection', '保存後', 'After saving', '存储后', '저장 후'),
('openAfterSave', '保存したファイルを開く', 'Open the saved file', '打开存储的文件', '저장한 파일 열기'),
('openAfterSaveHint', '形式ごとに決まっているアプリ（PNG・JPEGはプレビューなど）で開きます。', 'Opens it in the default app for its format (such as Preview for PNG and JPEG).', '用该格式的默认应用打开（如 PNG、JPEG 用“预览”）。', '형식별 기본 앱(PNG, JPEG는 미리보기 등)으로 엽니다.'),
('fileNameSection', 'ファイル名', 'File name', '文件名', '파일 이름'),
('suffixLabel', '元のファイル名に付ける文字', 'Added to the original name', '附加到原文件名的文字', '원래 파일 이름에 붙일 문자'),
('restoreDefault', '初期値に戻す', 'Restore Default', '恢复默认值', '초기값으로 되돌리기'),
('suffixExample', '例：photo.jpg → %@', 'Example: photo.jpg → %@', '例如：photo.jpg → %@', '예: photo.jpg → %@'),
('suffixHint', '初期値は「-breakline」です。「/」と「:」は使えません。空にすると元の名前のまま（拡張子は形式に合わせて .png・.jpg・.psd）になります。', 'The default is “-breakline”. “/” and “:” cannot be used. Leave it empty to keep the original name (with .png, .jpg or .psd for the format).', '默认值为“-breakline”。不能使用“/”和“:”。留空则保持原名称（扩展名随格式为 .png、.jpg 或 .psd）。', "초기값은 '-breakline'입니다. '/'와 ':'는 사용할 수 없습니다. 비워 두면 원래 이름 그대로(확장자는 형식에 따라 .png, .jpg, .psd)가 됩니다."),
# Status
('statusNoImage', '画像を開いてください。', 'Open an image.', '请打开图像。', '이미지를 여세요.'),
('statusDrawBand', '元画像の上をドラッグして、取り除く範囲を描いてください。', 'Drag over the original to draw the area to remove.', '请在原图上拖动，绘制要去除的范围。', '원본 이미지 위를 드래그해 제거할 범위를 그리세요.'),
('statusSizes', '%ld × %ld px → %ld × %ld px', '%ld × %ld px → %ld × %ld px', '%ld × %ld 像素 → %ld × %ld 像素', '%ld × %ld px → %ld × %ld px'),
('splitTopBottom', '上下に切り分け', 'Split top and bottom', '上下切分', '위아래로 분할'),
('splitLeftRight', '左右に切り分け', 'Split left and right', '左右切分', '좌우로 분할'),
('keepOneSide', '範囲の側だけを残す', 'Keeps the covered side only', '只保留范围所在的一侧', '범위 쪽만 남김'),
('bandCoversAllY', '範囲が画像の上端から下端までを覆っています。どちらかの端は空けてください。', 'The area covers the image from its top edge to its bottom edge. Leave one of the ends clear.', '范围覆盖了图像从上边缘到下边缘的部分。请留出其中一端。', '범위가 이미지의 위쪽 끝부터 아래쪽 끝까지 덮고 있습니다. 어느 한쪽 끝은 비워 두세요.'),
('bandCoversAllX', '範囲が画像の左端から右端までを覆っています。どちらかの端は空けてください。', 'The area covers the image from its left edge to its right edge. Leave one of the ends clear.', '范围覆盖了图像从左边缘到右边缘的部分。请留出其中一端。', '범위가 이미지의 왼쪽 끝부터 오른쪽 끝까지 덮고 있습니다. 어느 한쪽 끝은 비워 두세요.'),
('notImage', '画像ファイルではないため開けませんでした。', 'This is not an image file, so it was not opened.', '这不是图像文件，因此无法打开。', '이미지 파일이 아니므로 열 수 없습니다.'),
('cannotOpen', '「%@」を開けませんでした。画像の形式を確認してください。', 'Could not open “%@”. Check the image format.', '无法打开“%@”。请检查图像格式。', '\'%@\'을(를) 열 수 없습니다. 이미지 형식을 확인하세요.'),
('noImageToPaste', 'クリップボードに画像がありません。', 'There is no image on the clipboard.', '剪贴板中没有图像。', '클립보드에 이미지가 없습니다.'),
('pastedImage', 'ペーストした画像', 'Pasted image', '粘贴的图像', '붙여넣은 이미지'),
('droppedImage', 'ドロップした画像', 'Dropped image', '拖放的图像', '드롭한 이미지'),
('openPanelTitle', '処理する画像を開く', 'Open Image to Trim', '打开要处理的图像', '처리할 이미지 열기'),
('savePanelTitle', '%@で保存', 'Save as %@', '存储为 %@', '%@로 저장'),
('cannotReplaceOriginal', '元画像には上書きできません。別の名前か場所を選んでください。', 'The original cannot be replaced. Choose another name or location.', '不能覆盖原图。请选择其他名称或位置。', '원본 이미지에는 덮어쓸 수 없습니다. 다른 이름이나 위치를 선택하세요.'),
('saving', '保存しています…', 'Saving…', '正在存储…', '저장하는 중…'),
('saved', '「%@」を保存しました（%ld × %ld px）。', 'Saved “%@” (%ld × %ld px).', '已存储“%@”（%ld × %ld 像素）。', '\'%@\'을(를) 저장했습니다(%ld × %ld px).'),
('saveFailed', '書き出せませんでした：%@', 'Could not export: %@', '无法导出：%@', '내보낼 수 없습니다: %@'),
('copied', '結果の画像をコピーしました（%ld × %ld px）。', 'Copied the result (%ld × %ld px).', '已拷贝结果图像（%ld × %ld 像素）。', '결과 이미지를 복사했습니다(%ld × %ld px).'),
# Mask shape panel (labels from the script's dialog)
('panelMask', 'マスク用の図形', 'Mask shape', '遮罩形状', '마스크 도형'),
('panelMaskHelp', '描いた範囲をもとに、取り除く範囲と残す範囲を調整します。', 'Adjusts the areas to remove and keep, starting from the area you drew.', '以绘制的范围为基础，调整要去除和保留的范围。', '그린 범위를 바탕으로 제거할 범위와 남길 범위를 조정합니다.'),
('width', '幅', 'Width', '宽度', '폭'),
('height', '高さ', 'Height', '高度', '높이'),
('offsetY', '上下位置', 'Offset', '上下位置', '상하 위치'),
('offsetX', '左右位置', 'Offset', '左右位置', '좌우 위치'),
('maskScaleHelp', '取り除く範囲の大きさです。100%で描いた範囲のとおりになります。', 'Size of the area to remove. 100% matches the area you drew.', '要去除的范围大小。100% 与绘制的范围相同。', '제거할 범위의 크기입니다. 100%면 그린 범위와 같습니다.'),
('maskCrossScaleHelp', '画像を切りそろえる範囲の大きさです。100%で描いた範囲のとおりになります。', 'Size the image is trimmed to. 100% matches the area you drew.', '裁齐图像的范围大小。100% 与绘制的范围相同。', '이미지를 잘라 맞출 범위의 크기입니다. 100%면 그린 범위와 같습니다.'),
('offsetYHelp', '取り除く範囲の位置です。プラスで下へ、マイナスで上へ動きます。', 'Position of the area to remove. A positive value moves it down, a negative one up.', '要去除的范围的位置。正值向下移动，负值向上移动。', '제거할 범위의 위치입니다. 양수면 아래로, 음수면 위로 움직입니다.'),
('offsetXHelp', '取り除く範囲の位置です。プラスで右へ、マイナスで左へ動きます。', 'Position of the area to remove. A positive value moves it right, a negative one left.', '要去除的范围的位置。正值向右移动，负值向左移动。', '제거할 범위의 위치입니다. 양수면 오른쪽으로, 음수면 왼쪽으로 움직입니다.'),
# Cut edge panel
('panelCutEdge', '切り口', 'Cut edge', '切口', '절단면'),
('panelCutEdgeHelp', '切り口の形と、詰めたあとの間隔を指定します。', 'Sets the shape of the cut edge and the gap after closing up.', '指定切口的形状以及靠拢后的间距。', '절단면의 모양과 붙인 뒤의 간격을 지정합니다.'),
('style.flag', '旗', 'Flag', '旗形', '깃발'),
('style.rise', '上昇', 'Rise', '上升', '상승'),
('style.riseStraight', '直線', 'Straight', '直线', '직선'),
('style.jagged', 'ギザギザ', 'Jagged', '锯齿', '지그재그'),
('styleHelp.flag', '切り口を波形にします。', 'Makes the cut edge wavy.', '使切口呈波浪形。', '절단면을 물결 모양으로 만듭니다.'),
('styleHelp.rise', '切り口を、片側へせり上がるカーブにします。', 'Curves the cut edge up toward one side.', '使切口成为向一侧升起的曲线。', '절단면을 한쪽으로 올라가는 곡선으로 만듭니다.'),
('styleHelp.riseStraight', '切り口を斜めの直線にします。', 'Slants the cut edge in a straight line.', '使切口成为倾斜的直线。', '절단면을 비스듬한 직선으로 만듭니다.'),
('styleHelp.jagged', '切り口をギザギザにします。', 'Makes the cut edge jagged.', '使切口呈锯齿状。', '절단면을 지그재그로 만듭니다.'),
('warpAmount', 'カーブ', 'Bend', '弯曲', '커브'),
('warpAmountHelp', '切り口を曲げる量です（-100〜100%、画像の高さ（左右に切るときは幅）に対する割合）。直線では傾きの量になります。0でまっすぐに切り、マイナスで逆向きになります。', 'How much the cut edge bends (-100 to 100%, relative to the image height, or the width for a left-right cut); for Straight, how much it slants. 0 cuts straight across; negative values reverse the direction.', '切口弯曲的程度（-100 到 100%，相对于图像高度；左右切分时为宽度）。直线时为倾斜量。0 为笔直切开，负值则方向相反。', '절단면을 구부리는 양입니다(-100~100%, 이미지 높이(좌우로 자를 때는 폭)에 대한 비율). 직선에서는 기울기의 양이 됩니다. 0이면 똑바로 자르고, 음수면 반대 방향이 됩니다.'),
('jaggedSize', '大きさ', 'Size', '大小', '크기'),
('jaggedSizeHelp', 'ギザギザの山の高さです。0でまっすぐに切ります。', 'Height of the jagged ridges. 0 cuts straight across.', '锯齿的高度。0 为笔直切开。', '지그재그 산의 높이입니다. 0이면 똑바로 자릅니다.'),
('jaggedRidges', '折り返し', 'Ridges', '折返', '꺾임'),
('jaggedRidgesHelp', '切り口の端から端までの折り返しの数です（0〜100）。0でまっすぐに切ります。', 'Number of ridges across the cut edge (0 to 100). 0 cuts straight across.', '切口从一端到另一端的折返数（0 到 100）。0 为笔直切开。', '절단면 끝에서 끝까지의 꺾임 수입니다(0~100). 0이면 똑바로 자릅니다.'),
('gap', '間隔', 'Gap', '间距', '간격'),
('gapHelp', '切り詰めたあとの、2つのパーツのあいだの距離です。片側だけ残すときは使いません。', 'Distance between the two parts after closing up. Unused when only one side is kept.', '靠拢后两个部分之间的距离。只保留一侧时不使用。', '붙인 뒤 두 부분 사이의 거리입니다. 한쪽만 남길 때는 사용하지 않습니다.'),
# Break line panel
('panelBreakLine', '省略線', 'Break lines', '省略线', '생략선'),
('panelBreakLineHelp', '切り口に沿って引く線を設定します。', 'Sets up the lines drawn along the cut edge.', '设置沿切口绘制的线。', '절단면을 따라 그리는 선을 설정합니다.'),
('addRule', '省略線を追加', 'Add break lines', '添加省略线', '생략선 추가'),
('addRuleHelp', '切り口に沿った省略線を、パーツごとに追加します。', 'Adds a break line along the cut edge of each part.', '沿每个部分的切口添加省略线。', '부분마다 절단면을 따라 생략선을 추가합니다.'),
('ruleColor', '線の色', 'Color', '线条颜色', '선 색상'),
('ruleColorHelp', '省略線の色です。不透明度も指定できます。', 'Color of the break lines. Opacity can be set too.', '省略线的颜色。也可以指定不透明度。', '생략선의 색상입니다. 불투명도도 지정할 수 있습니다.'),
('ruleColorBlack', '黒に戻す', 'Black', '恢复黑色', '검은색으로'),
('strokeWidth', '線幅', 'Weight', '线宽', '선 두께'),
('strokeWidthHelp', '省略線の線幅です（ピクセル）。', 'Stroke weight of the break lines, in pixels.', '省略线的线宽（像素）。', '생략선의 두께입니다(픽셀).'),
('strokeCap', '線端', 'Cap', '端点', '선 끝'),
('strokeCapHelp', '省略線の線端です。丸型にすると線の両端（破線は各線分の端）が丸くなります。', 'Cap of the break lines. A round cap rounds the line ends (each dash when dashed).', '省略线的端点。选择圆头时线的两端（虚线时为每段的端点）会变圆。', '생략선의 선 끝입니다. 둥글게 하면 선의 양 끝(파선은 각 선분의 끝)이 둥글어집니다.'),
('buttCap', 'なし', 'Butt', '平头', '없음'),
('roundCap', '丸型', 'Round', '圆头', '둥근 모양'),
('ruleStyle', '線種', 'Line style', '线型', '선 종류'),
('ruleStyleHelp', '省略線の線種です。破線は分割数で線分の数を決めます。', 'Line style of the break lines. A dashed line is set by the number of segments.', '省略线的线型。虚线由分段数决定线段数量。', '생략선의 선 종류입니다. 파선은 분할 수로 선분의 수를 정합니다.'),
('solid', '実線', 'Solid', '实线', '실선'),
('dashed', '破線', 'Dashed', '虚线', '파선'),
('dashSegments', '分割数', 'Segments', '分段数', '분할 수'),
('dashSegmentsHelp', '線分の本数です。線分と間隔は同じ長さで、両端が線分で終わります。', 'Number of dashes. Dash and gap are equal, and both ends finish with a dash.', '线段的数量。线段与间隔等长，两端以线段结束。', '선분의 개수입니다. 선분과 간격은 같은 길이이며, 양 끝은 선분으로 끝납니다.'),
('resetDefaults', 'すべて初期値に戻す', 'Restore All Defaults', '全部恢复默认值', '모두 초기값으로 되돌리기'),
('resetDefaultsHelp', 'マスク用の図形・切り口・省略線の項目を初期値に戻します（描いた範囲は変わりません）。', 'Restores the mask shape, cut edge and break line settings to their defaults (the drawn area stays).', '将遮罩形状、切口和省略线的项目恢复为默认值（绘制的范围不变）。', '마스크 도형, 절단면, 생략선 항목을 초기값으로 되돌립니다(그린 범위는 바뀌지 않음).'),
# Settings
('settingsTitle', '設定', 'Settings', '设置', '설정'),
('keepRunning', 'ウインドウを閉じても常駐', 'Keep running after closing the window', '关闭窗口后保持运行', '윈도우를 닫아도 계속 실행'),
('keepRunningHint', 'オフにすると、メインウインドウを閉じたときに終了します。', 'When off, closing the main window quits the app.', '关闭此项时，关闭主窗口即退出应用。', '끄면 메인 윈도우를 닫을 때 종료합니다.'),
('quitWhileSavingTitle', '保存中は終了できません', 'Cannot quit while saving', '存储时无法退出', '저장하는 동안에는 종료할 수 없습니다'),
('quitWhileSavingInfo', '保存が終わってから、もう一度終了してください。', 'Quit again after the save finishes.', '请在存储完成后再次退出。', '저장이 끝난 뒤 다시 종료하세요.'),
('ok', 'OK', 'OK', '好', '확인'),
('support', 'サポート：アプリ内の README.md と、ヘルプメニューの「note記事を開く」を参照してください。', 'Support: see README.md in the app and Help > Open the note Article.', '支持：请参阅应用内的 README.md 和“帮助”菜单中的“打开 note 文章”。', '지원: 앱 안의 README.md와 도움말 메뉴의 \'note 글 열기\'를 참조하세요.'),
# Menus
('about', 'BreaklineTrimmerについて', 'About BreaklineTrimmer', '关于 BreaklineTrimmer', 'BreaklineTrimmer에 관하여'),
('settings', '設定…', 'Settings…', '设置…', '설정…'),
('services', 'サービス', 'Services', '服务', '서비스'),
('hideApp', 'BreaklineTrimmerを隠す', 'Hide BreaklineTrimmer', '隐藏 BreaklineTrimmer', 'BreaklineTrimmer 가리기'),
('hideOthers', 'ほかを隠す', 'Hide Others', '隐藏其他', '기타 가리기'),
('showAll', 'すべてを表示', 'Show All', '全部显示', '모두 보기'),
('quit', 'BreaklineTrimmerを終了', 'Quit BreaklineTrimmer', '退出 BreaklineTrimmer', 'BreaklineTrimmer 종료'),
('file', 'ファイル', 'File', '文件', '파일'),
('openMainWindow', 'メインウインドウを開く', 'Open Main Window', '打开主窗口', '메인 윈도우 열기'),
('openImageMenu', '処理する画像を開く…', 'Open Image to Trim…', '打开要处理的图像…', '처리할 이미지 열기…'),
('saveMenu', '%@で保存…', 'Save as %@…', '存储为 %@…', '%@로 저장…'),
('copyResultMenu', '結果の画像をコピー', 'Copy Result Image', '拷贝结果图像', '결과 이미지 복사하기'),
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
('helpItem', 'BreaklineTrimmerヘルプ', 'BreaklineTrimmer Help', 'BreaklineTrimmer 帮助', 'BreaklineTrimmer 도움말'),
]

helptexts = [
# ja
'''画像の一部を取り除いて残りを詰め、切り口に省略線を引いて、PNG・JPEG・PSDで書き出します。Illustratorのスクリプト「省略線でトリミング（TrimWithBreakLine）」をビットマップ画像用にしたアプリです。

## 使い方
1. 画像をメインウインドウにドロップするか、**ファイル**メニューの**処理する画像を開く…**（⌘O）で開きます。Finderの「このアプリケーションで開く」、Dockのアイコンへのドロップ、画像のペースト（⌘V）でも開けます。
2. **元画像**の上をドラッグして、取り除く範囲（Illustratorの「マスク用の図形」にあたります）を描きます。範囲の上下（左右に切るときは左右）にある青いガイドをドラッグすると、その端だけを動かせます。範囲の内側をドラッグすると移動し、外側をドラッグすると描き直します。開いた直後は、画像の中央に横長の範囲が入っています。
3. 右側の**マスク用の図形**・**切り口**・**省略線**を調整します。**プレビュー**に結果がすぐに表示されます。右上の**透明**・**白**・**グレー**・**黒**で、透明な部分の背景を切り替えられます（保存・コピーする画像にも反映します）。元画像では、取り除かれる部分が暗く、切り口が赤い線で表示されます。
4. **PNGで保存…**（⌘S、形式は右側の**ファイル形式**で選んだもの）で保存するか、**コピー**（⇧⌘C）でクリップボードに入れます。

## 切り分け方
- 範囲が画像を横方向に大きくまたいでいるときは上下に、縦方向に大きくまたいでいるときは左右に切り分けます（範囲そのものの縦横比ではなく、画像に対する割合で決めます）。
- 範囲が画像の端まで届いているときは、範囲の側だけを残して反対側を切り落とします。このときは間隔を使いません。上端から下端（左端から右端）までを覆う範囲は切り分けられません。
- 画像は、範囲の幅（左右に切り分けるときは高さ）に切りそろえます。
- 詰めるときは、上下なら上、左右なら左のパーツを動かさず、もう一方を寄せます。

## マスク用の図形
- **幅**・**高さ**：描いた範囲を、中心を基準に伸縮します（%）。切り分ける方向は取り除く範囲の大きさ、切り口に沿った方向は画像を切りそろえる範囲の大きさになります。
- **上下位置**／**左右位置**：取り除く範囲をずらします（ピクセル）。プラスで下（右）へ、マイナスで上（左）へ動きます。

## 切り口
- 形は**旗**（波形）・**上昇**（片側へせり上がるカーブ）・**直線**（斜めの直線）・**ギザギザ**から選びます。
- **カーブ**：曲げる量です（-100〜100%）。画像の高さ（左右に切り分けるときは幅）に対する割合で、0でまっすぐに切り、マイナスで逆向きになります。直線では傾きの量になります。
- **大きさ**・**折り返し**：ギザギザの山の高さ（ピクセル）と、端から端までの折り返しの数です。どちらかが0のときはまっすぐに切ります。
- **間隔**：詰めたあとの2つのパーツのあいだの距離です（ピクセル）。あいだは透明になります。

## 省略線
- **省略線を追加**：切り口に沿った線を、パーツごとに引きます。
- **線の色**・**線幅**：色は不透明度も含めて選べます（初期値は黒）。線幅はピクセルで指定します。
- **線端**：**なし**か**丸型**です。丸型にすると線の両端（破線は各線分の端）が丸くなります。
- **線種**・**分割数**：**破線**にすると、分割数の本数の線分で切り口を埋めます。線分と間隔は同じ長さで、両端が線分で終わります。

Illustrator版の「グループ化」は、ビットマップには当てはまらないため省きました。設定は次回の起動時にも引き継ぎます。**すべて初期値に戻す**で、これらの項目を初期値に戻します（描いた範囲は変わりません）。

## 保存とコピー
右側の**ファイル形式**で選んだ**PNG**（初期値）・**JPEG**・**PSD**で書き出します。背景が**透明**のときは、透明な部分も切り口の外や間隔の部分も透明になり、**白**・**グレー**・**黒**のときはその色で塗ります。JPEGは透明を持てないため、背景が**透明**でも白で塗ります（画質90%）。PSDは1枚の画像（レイヤーなし）として書き出します。コピーは形式にかかわらずPNGです。パーツは整数のピクセル単位で動かすので、残った部分のピクセルは拡大・縮小されません。解像度（dpi）の情報は引き継ぎ、写真の向きの情報は向きを直した画像として書き出します。元画像は変更しません。保存先とファイル名は設定の「出力」タブで決めます。保存先は**元画像と同じフォルダ**（初期値）・**デスクトップ**・**指定したフォルダ**・**毎回指定する**から選び、「毎回指定する」以外では場所を尋ねずに保存します。ファイル名は元の名前に「-breakline」（変更できます）を付けたもので、同じ名前がある場合は置き換えず「元の名前-breakline 2.png」のように番号を付けます。「出力」タブの**保存したファイルを開く**をオンにすると、保存したあと形式ごとに決まっているアプリで開きます。元画像そのものを保存先に選ぶことはできません。

## 設定
アプリメニューの**設定…**（⌘,）で開きます。「起動・常駐」タブで次の項目を設定できます。

- **ログイン時に起動**（初期値オフ）
- **起動時にメインウインドウを表示しない**（初期値オフ）
- **Dockとアプリケーションスイッチャーに表示しない**（初期値オフ。オンにすると、Dockと⌘Tabの切り替えにアイコンを出しません。メニューバーのアイコン（表示しているとき）か、Finderでアプリを開き直すと表示できます）
- **ウインドウを閉じても常駐**（初期値オン。オフにすると、メインウインドウを閉じたときに終了します）
- **メニューバーに表示**

「出力」タブでは保存先とファイル名を設定します（上の「保存とコピー」を参照）。「設定の共有」タブでは、マスク用の図形・切り口・省略線・ファイル名・保存先の種類の設定を**書き出す…**で BreaklineTrimmer-Settings.plist に保存し、**読み込む…**で別のMacに読み込めます。「設定の同期」で iCloud Drive や Dropbox などのフォルダーを選ぶと、同じフォルダーを選んだMacどうしで設定がそろいます。画像と描いた範囲は含みません。ログイン時の起動・常駐・メニューバー・指定したフォルダはMacごとに設定します。

## ホットキー
- **⌘O**：処理する画像を開く
- **⌘S**：保存（PNG・JPEG・PSD）
- **⇧⌘C**：結果の画像をコピー
- **⌘C／⌘V**：入力欄の外では、結果の画像をコピー／画像をペーストして開く
- **⌘0**：メインウインドウを開く
- **⌘,**：設定
- **⌘?**：ヘルプ
- **⌘W**：ウインドウを閉じる
- **⌘Q**：BreaklineTrimmerを終了

グローバルなホットキーは使いません。

## アクセス許可
特別な許可は必要ありません。読むのは開いた・ドロップした・ペーストした画像だけで、書き込むのは保存先に選んだファイルだけです。外部との通信はしません（アップデートの確認は、配信先が設定されるまで準備中と表示し、通信しません）。

## 起動と終了
- **ウインドウを閉じても常駐**がオンのときは、ウインドウを閉じてもアプリは終了せず、開いている画像と範囲もそのまま残ります。Dockのアイコン、**ファイル**メニューの**メインウインドウを開く**（⌘0）、メニューバーのアイコン（表示しているとき）で再表示できます。
- ログイン時に起動したときや、**起動時にメインウインドウを表示しない**がオンのときは、メインウインドウを表示せずに起動します。ファイルを渡して起動したときは表示します。
- 終了するには、アプリメニューの**BreaklineTrimmerを終了**（⌘Q）を選びます。保存中は終了できません。保存が終わってから、もう一度終了してください。

## 困ったとき
- 「範囲が画像の上端から下端までを覆っています」と表示されたら、範囲を描き直して、どちらかの端を空けてください。
- 思った向きに切り分けられないときは、範囲を、切り分けたい方向に長く描いてください。
- 切り口のカーブが大きすぎるときは、**カーブ**の値を小さくしてください（画像の高さや幅に対する割合です）。
- 開けない画像は、プレビューで開けるか確認し、PNGやJPEGに書き出してから開いてください。
- ヘルプメニューの**note記事を開く**で、アプリの紹介記事（note）をブラウザーで開けます。

## アプリの削除
1. **ログイン時に起動**をオフにします。
2. アプリを終了します。
3. BreaklineTrimmerをゴミ箱に入れます。
''',
# en
'''Removes part of an image, closes up the rest, draws break lines along the cut, and saves it as PNG, JPEG or PSD. It is the bitmap version of the Illustrator script Trim with Break Lines (TrimWithBreakLine).

## How to use
1. Drop an image on the main window, or choose **File** > **Open Image to Trim…** (⌘O). You can also use Open With in Finder, drop on the Dock icon, or paste an image (⌘V).
2. Drag over the **Original** to draw the area to remove (the mask shape in Illustrator). Drag a blue guide (the top and bottom edges, or left and right for a left-right split) to move just that edge. Drag inside the area to move it, or outside it to draw a new one. Right after opening, a wide area sits across the middle of the image.
3. Adjust **Mask shape**, **Cut edge** and **Break lines** on the right. The **Preview** updates right away. **Transparent**, **White**, **Gray** and **Black** at its top right change what fills transparent areas (also in the saved or copied image). On the original, the parts that go away are dimmed and the cut edges are shown in red.
4. Choose **Save as PNG…** (⌘S; the format chosen under **File format** on the right), or **Copy** (⇧⌘C) to put it on the clipboard.

## How the image is split
- When the area spans more of the image across, the image is split into top and bottom; when it spans more of it vertically, into left and right (decided by how much of the image it covers, not by its own shape).
- When the area reaches an edge of the image, only that side is kept and the rest is trimmed away; the gap is not used then. An area from the top edge to the bottom edge (or left to right) cannot be split.
- The image is trimmed to the width of the area (its height for a left-right split).
- When closing up, the top part (or the left part) stays and the other one moves.

## Mask shape
- **Width** and **Height**: scale the drawn area from its center (%). Along the split direction this sets the area to remove; along the cut edge, the size the image is trimmed to.
- **Offset**: moves the area to remove (pixels). Positive values move it down (or right), negative values up (or left).

## Cut edge
- Choose the shape: **Flag** (wavy), **Rise** (curving up toward one side), **Straight** (a slanted line) or **Jagged**.
- **Bend**: how much it bends (-100 to 100%), relative to the image height (the width for a left-right split). 0 cuts straight across; negative values reverse the direction. For Straight, it is the slant.
- **Size** and **Ridges**: the height of the jagged ridges (pixels) and how many there are from end to end. When either is 0, the cut is straight.
- **Gap**: the distance between the two parts after closing up (pixels). The space between them is transparent.

## Break lines
- **Add break lines**: draws a line along the cut edge of each part.
- **Color** and **Weight**: the color can include opacity (black at first). The weight is in pixels.
- **Cap**: **Butt** or **Round**. A round cap rounds the line ends (each dash when dashed).
- **Line style** and **Segments**: with **Dashed**, the cut edge is filled with that many dashes. Dash and gap are equal, and both ends finish with a dash.

Group with parts from the Illustrator version does not apply to bitmaps and is left out. The settings carry over to the next launch. **Restore All Defaults** resets these items (the drawn area stays).

## Saving and copying
The result is saved as **PNG** (the default), **JPEG** or **PSD**, as chosen under **File format** on the right. With the **Transparent** background, transparent areas and the areas outside the cut and in the gap stay transparent; with **White**, **Gray** or **Black** they are filled with that color. JPEG cannot hold transparency, so it is filled with white even with **Transparent** (quality 90%). PSD is saved as a single image without layers. Copy always uses PNG. Parts move by whole pixels, so the remaining pixels are never scaled. The resolution (dpi) is kept, and a photo's orientation is applied to the saved image. The original is not changed. Where and under what name it is saved is set in the Output tab of the settings. Save to **The original image's folder** (the default), **Desktop**, **A chosen folder** or **Ask each time**; except with Ask each time, it saves without asking. The name is the original name plus “-breakline” (you can change it); an existing file is never replaced, and the new one is numbered like “name-breakline 2.png”. With **Open the saved file** on in the Output tab, the file opens in the default app for its format after saving. The original itself cannot be chosen as the destination.

## Settings
Open them with **Settings…** (⌘,) in the app menu. The Startup & Background tab has:

- **Open at login** (off at first)
- **Hide main window at startup** (off at first)
- **Hide from Dock and App Switcher** (off at first. When on, the app does not appear in the Dock or the ⌘Tab switcher. Show it from the menu bar icon (when shown) or by opening the app again in Finder)
- **Keep running after closing the window** (on at first; when off, closing the main window quits)
- **Show in menu bar**

The Output tab sets where files are saved and how they are named (see Saving and copying above). In the Sharing tab, **Export…** saves the mask shape, cut edge, break line, file name and save location settings to BreaklineTrimmer-Settings.plist and **Import…** reads them on another Mac. Settings Sync with a folder such as iCloud Drive or Dropbox keeps Macs that use the same folder in step. Images and drawn areas are not included. Open at login, keep running, the menu bar and the chosen folder are set on each Mac.

## Hotkeys
- **⌘O**: Open Image to Trim
- **⌘S**: Save (PNG, JPEG or PSD)
- **⇧⌘C**: Copy the result image
- **⌘C / ⌘V**: outside text fields, copy the result image / paste an image to open it
- **⌘0**: Open the main window
- **⌘,**: Settings
- **⌘?**: Help
- **⌘W**: Close the window
- **⌘Q**: Quit BreaklineTrimmer

The app uses no global hotkeys.

## Permissions
No special permission is needed. The app reads only the images you open, drop or paste, and writes only the file you choose to save. It does not connect to the internet (Check for Updates shows that updates are being prepared until a distribution feed is set, and does not connect).

## Running and quitting
- With **Keep running after closing the window** on, closing the window does not quit the app, and the open image and area stay as they are. Show the window again from the Dock icon, **File** > **Open Main Window** (⌘0), or the menu bar icon (when shown).
- When opened at login, or with **Hide main window at startup** on, the app starts without showing the main window. It shows the window when files are handed to it.
- To quit, choose **Quit BreaklineTrimmer** (⌘Q) in the app menu. The app cannot quit while saving; quit again after the save finishes.

## Troubleshooting
- If you see “The area covers the image from its top edge to its bottom edge”, draw the area again and leave one of the ends clear.
- If the image is split the wrong way, draw the area longer in the direction you want to cut across.
- If the curve of the cut is too big, lower **Bend** (it is a share of the image height or width).
- If an image does not open, check that Preview can open it, then export it as PNG or JPEG and open that.
- Help > **Open the note Article** opens the app's introduction on note in your browser.

## Uninstalling
1. Turn off **Open at login**.
2. Quit the app.
3. Move BreaklineTrimmer to the Trash.
''',
# zh-Hans
'''去除图像的一部分并将其余部分靠拢，在切口画上省略线，并导出为 PNG、JPEG 或 PSD。这是 Illustrator 脚本“用省略线裁切（TrimWithBreakLine）”的位图版本。

## 使用方法
1. 将图像拖放到主窗口，或选择**文件**菜单中的**打开要处理的图像…**（⌘O）。也可以使用访达的“打开方式”、拖放到 Dock 图标，或粘贴图像（⌘V）。
2. 在**原图**上拖动，绘制要去除的范围（相当于 Illustrator 中的“遮罩形状”）。拖动范围上下（左右切分时为左右）的蓝色参考线，可以只移动该边缘。在范围内拖动可移动它，在范围外拖动可重新绘制。刚打开时，图像中央会放置一个横向范围。
3. 在右侧调整**遮罩形状**、**切口**和**省略线**。**预览**会立即显示结果。右上角的**透明**、**白色**、**灰色**、**黑色**可切换透明部分的背景（也会应用到存储或拷贝的图像）。原图中，被去除的部分会变暗，切口以红线显示。
4. 选择**存储为 PNG…**（⌘S，格式为右侧**文件格式**中所选）存储，或选择**拷贝**（⇧⌘C）放入剪贴板。

## 切分方式
- 范围在横向上跨越图像较多时上下切分，在纵向上跨越较多时左右切分（按占图像的比例判断，而不是范围本身的长宽比）。
- 范围到达图像边缘时，只保留范围所在的一侧，切掉另一侧。此时不使用间距。覆盖从上边缘到下边缘（或从左边缘到右边缘）的范围无法切分。
- 图像会裁齐到范围的宽度（左右切分时为高度）。
- 靠拢时，上下切分保持上方部分不动，左右切分保持左侧部分不动，移动另一部分。

## 遮罩形状
- **宽度**、**高度**：以中心为基准缩放绘制的范围（%）。切分方向上为要去除的范围大小，沿切口方向上为裁齐图像的范围大小。
- **上下位置**／**左右位置**：移动要去除的范围（像素）。正值向下（右）移动，负值向上（左）移动。

## 切口
- 形状可选**旗形**（波浪）、**上升**（向一侧升起的曲线）、**直线**（倾斜的直线）或**锯齿**。
- **弯曲**：弯曲的程度（-100 到 100%）。相对于图像高度（左右切分时为宽度），0 为笔直切开，负值方向相反。直线时为倾斜量。
- **大小**、**折返**：锯齿的高度（像素）和从一端到另一端的折返数。任一为 0 时笔直切开。
- **间距**：靠拢后两个部分之间的距离（像素）。中间为透明。

## 省略线
- **添加省略线**：沿每个部分的切口画一条线。
- **线条颜色**、**线宽**：颜色可包含不透明度（默认为黑色）。线宽以像素指定。
- **端点**：**平头**或**圆头**。选择圆头时线的两端（虚线时为每段的端点）会变圆。
- **线型**、**分段数**：选择**虚线**时，用指定数量的线段填满切口。线段与间隔等长，两端以线段结束。

Illustrator 版中的“编组”不适用于位图，因此省略。设置会延续到下次启动。**全部恢复默认值**可将这些项目恢复为默认值（绘制的范围不变）。

## 存储与拷贝
以右侧**文件格式**中所选的 **PNG**（默认）、**JPEG** 或 **PSD** 导出。背景为**透明**时，透明部分以及切口之外和间距部分均为透明；为**白色**、**灰色**、**黑色**时以该颜色填充。JPEG 无法保存透明，因此即使背景为**透明**也以白色填充（品质 90%）。PSD 作为单张图像（无图层）导出。拷贝不论格式均为 PNG。各部分以整数像素移动，因此保留部分的像素不会被缩放。会保留分辨率（dpi）信息，照片的方向信息会以校正方向后的图像导出。不会更改原图。存储位置和文件名在设置的“输出”标签页中指定。存储位置可选**与原图相同的文件夹**（默认）、**桌面**、**指定的文件夹**或**每次指定**；除“每次指定”外，存储时不会询问位置。文件名为原名称加上“-breakline”（可更改），如有同名文件不会替换，而是加上编号，如“原名称-breakline 2.png”。打开“输出”标签页中的**打开存储的文件**后，存储后会用该格式的默认应用打开文件。不能选择原图本身作为存储位置。

## 设置
从应用菜单的**设置…**（⌘,）打开。“启动与后台”标签页中可以设置以下项目。

- **登录时启动**（默认关闭）
- **启动时不显示主窗口**（默认关闭）
- **不在程序坞和应用程序切换器中显示**（默认关闭。开启后不在程序坞和 ⌘Tab 切换器中显示图标。可通过菜单栏图标（显示时）或在访达中再次打开应用来显示）
- **关闭窗口后保持运行**（默认开启。关闭时，关闭主窗口即退出应用）
- **在菜单栏中显示**

“输出”标签页用于设置存储位置和文件名（参见上面的“存储与拷贝”）。在“设置共享”标签页中，可以用**导出…**将遮罩形状、切口、省略线、文件名和存储位置类型的设置存储到 BreaklineTrimmer-Settings.plist，并用**导入…**在其他 Mac 上读取。在“设置同步”中选择 iCloud Drive 或 Dropbox 等文件夹后，选择同一文件夹的 Mac 之间设置会保持一致。不包含图像和绘制的范围。登录时启动、保持运行、菜单栏和指定的文件夹需在每台 Mac 上分别设置。

## 快捷键
- **⌘O**：打开要处理的图像
- **⌘S**：存储（PNG、JPEG 或 PSD）
- **⇧⌘C**：拷贝结果图像
- **⌘C／⌘V**：在输入栏之外时，拷贝结果图像／粘贴图像并打开
- **⌘0**：打开主窗口
- **⌘,**：设置
- **⌘?**：帮助
- **⌘W**：关闭窗口
- **⌘Q**：退出 BreaklineTrimmer

不使用全局快捷键。

## 权限
不需要特别的权限。只读取你打开、拖放或粘贴的图像，只写入你选择存储的文件。不进行外部通信（在设置发布地址之前，检查更新会显示为准备中，不进行通信）。

## 启动与退出
- **关闭窗口后保持运行**开启时，关闭窗口不会退出应用，打开的图像和范围也会保留。可通过 Dock 图标、**文件**菜单中的**打开主窗口**（⌘0）或菜单栏图标（显示时）再次显示窗口。
- 登录时启动，或**启动时不显示主窗口**开启时，启动时不显示主窗口。传入文件启动时会显示。
- 要退出，请选择应用菜单中的**退出 BreaklineTrimmer**（⌘Q）。存储时无法退出，请在存储完成后再次退出。

## 疑难解答
- 如果显示“范围覆盖了图像从上边缘到下边缘的部分”，请重新绘制范围，并留出其中一端。
- 如果切分方向不符合预期，请沿想要切分的方向将范围画长。
- 如果切口的弯曲过大，请减小**弯曲**的值（它是相对于图像高度或宽度的比例）。
- 无法打开的图像，请确认能否用“预览”打开，导出为 PNG 或 JPEG 后再打开。
- 使用“帮助”菜单中的**打开 note 文章**，可以在浏览器中打开应用的介绍文章（note）。

## 删除应用
1. 关闭**登录时启动**。
2. 退出应用。
3. 将 BreaklineTrimmer 移到废纸篓。
''',
# ko
'''이미지의 일부를 제거하고 나머지를 붙인 뒤, 절단면에 생략선을 그려 PNG, JPEG, PSD로 내보냅니다. Illustrator 스크립트 '생략선으로 트리밍(TrimWithBreakLine)'을 비트맵 이미지용으로 만든 앱입니다.

## 사용 방법
1. 이미지를 메인 윈도우에 드롭하거나 **파일** 메뉴의 **처리할 이미지 열기…**(⌘O)로 엽니다. Finder의 '다음으로 열기', Dock 아이콘에 드롭, 이미지 붙여넣기(⌘V)로도 열 수 있습니다.
2. **원본 이미지** 위를 드래그해 제거할 범위(Illustrator의 '마스크 도형'에 해당)를 그립니다. 범위 위아래(좌우로 자를 때는 좌우)에 있는 파란색 가이드를 드래그하면 그 가장자리만 움직일 수 있습니다. 범위 안쪽을 드래그하면 이동하고, 바깥쪽을 드래그하면 다시 그립니다. 연 직후에는 이미지 가운데에 가로로 긴 범위가 들어 있습니다.
3. 오른쪽의 **마스크 도형**, **절단면**, **생략선**을 조정합니다. **미리보기**에 결과가 바로 표시됩니다. 오른쪽 위의 **투명**, **흰색**, **회색**, **검은색**으로 투명한 부분의 배경을 바꿀 수 있습니다(저장하거나 복사하는 이미지에도 반영됩니다). 원본 이미지에서는 제거되는 부분이 어둡게, 절단면이 빨간 선으로 표시됩니다.
4. **PNG로 저장…**(⌘S, 형식은 오른쪽 **파일 형식**에서 고른 것)으로 저장하거나 **복사하기**(⇧⌘C)로 클립보드에 넣습니다.

## 분할 방식
- 범위가 이미지를 가로 방향으로 크게 걸치면 위아래로, 세로 방향으로 크게 걸치면 좌우로 분할합니다(범위 자체의 가로세로 비율이 아니라 이미지에 대한 비율로 정합니다).
- 범위가 이미지 끝까지 닿아 있으면 범위 쪽만 남기고 반대쪽을 잘라 냅니다. 이때는 간격을 사용하지 않습니다. 위쪽 끝부터 아래쪽 끝(왼쪽 끝부터 오른쪽 끝)까지 덮는 범위는 분할할 수 없습니다.
- 이미지는 범위의 폭(좌우로 분할할 때는 높이)에 맞춰 잘라 냅니다.
- 붙일 때는 위아래면 위, 좌우면 왼쪽 부분을 움직이지 않고 다른 쪽을 붙입니다.

## 마스크 도형
- **폭**, **높이**: 그린 범위를 중심을 기준으로 늘이거나 줄입니다(%). 분할 방향은 제거할 범위의 크기, 절단면을 따른 방향은 이미지를 잘라 맞출 범위의 크기가 됩니다.
- **상하 위치**/**좌우 위치**: 제거할 범위를 옮깁니다(픽셀). 양수면 아래(오른쪽)로, 음수면 위(왼쪽)로 움직입니다.

## 절단면
- 모양은 **깃발**(물결), **상승**(한쪽으로 올라가는 곡선), **직선**(비스듬한 직선), **지그재그** 중에서 고릅니다.
- **커브**: 구부리는 양입니다(-100~100%). 이미지 높이(좌우로 분할할 때는 폭)에 대한 비율이며, 0이면 똑바로 자르고 음수면 반대 방향이 됩니다. 직선에서는 기울기의 양이 됩니다.
- **크기**, **꺾임**: 지그재그 산의 높이(픽셀)와 끝에서 끝까지의 꺾임 수입니다. 어느 한쪽이 0이면 똑바로 자릅니다.
- **간격**: 붙인 뒤 두 부분 사이의 거리입니다(픽셀). 사이는 투명해집니다.

## 생략선
- **생략선 추가**: 부분마다 절단면을 따라 선을 그립니다.
- **선 색상**, **선 두께**: 색상은 불투명도를 포함해 고를 수 있습니다(기본값은 검은색). 선 두께는 픽셀로 지정합니다.
- **선 끝**: **없음** 또는 **둥근 모양**입니다. 둥근 모양으로 하면 선의 양 끝(파선은 각 선분의 끝)이 둥글어집니다.
- **선 종류**, **분할 수**: **파선**으로 하면 분할 수만큼의 선분으로 절단면을 채웁니다. 선분과 간격은 같은 길이이며, 양 끝은 선분으로 끝납니다.

Illustrator 버전의 '그룹화'는 비트맵에는 해당하지 않으므로 생략했습니다. 설정은 다음 실행 시에도 이어집니다. **모두 초기값으로 되돌리기**로 이 항목들을 초기값으로 되돌립니다(그린 범위는 바뀌지 않음).

## 저장과 복사
오른쪽 **파일 형식**에서 고른 **PNG**(기본값), **JPEG**, **PSD**로 내보냅니다. 배경이 **투명**이면 투명한 부분과 절단면 바깥, 간격 부분이 투명해지고, **흰색**, **회색**, **검은색**이면 그 색으로 칠합니다. JPEG는 투명을 담을 수 없어 배경이 **투명**이어도 흰색으로 칠합니다(화질 90%). PSD는 레이어 없는 한 장의 이미지로 내보냅니다. 복사는 형식과 관계없이 PNG입니다. 부분은 정수 픽셀 단위로 움직이므로 남은 부분의 픽셀은 확대·축소되지 않습니다. 해상도(dpi) 정보는 이어받고, 사진의 방향 정보는 방향을 바로잡은 이미지로 내보냅니다. 원본 이미지는 변경하지 않습니다. 저장 위치와 파일 이름은 설정의 '출력' 탭에서 정합니다. 저장 위치는 **원본 이미지와 같은 폴더**(기본값), **데스크탑**, **지정한 폴더**, **매번 지정** 중에서 고르며, '매번 지정' 외에는 위치를 묻지 않고 저장합니다. 파일 이름은 원래 이름에 '-breakline'(변경 가능)을 붙인 것으로, 같은 이름이 있으면 바꾸지 않고 '원래 이름-breakline 2.png'처럼 번호를 붙입니다. '출력' 탭의 **저장한 파일 열기**를 켜면 저장한 뒤 형식별 기본 앱으로 엽니다. 원본 이미지 자체를 저장 위치로 선택할 수는 없습니다.

## 설정
앱 메뉴의 **설정…**(⌘,)으로 엽니다. '시작 및 백그라운드' 탭에서 다음 항목을 설정할 수 있습니다.

- **로그인 시 실행**(기본값 끔)
- **시작 시 메인 윈도우 표시 안 함**(기본값 끔)
- **Dock 및 앱 전환기에 표시 안 함**(기본값 끔. 켜면 Dock과 ⌘Tab 전환기에 아이콘을 표시하지 않습니다. 메뉴 막대 아이콘(표시 중일 때) 또는 Finder에서 앱을 다시 열어 표시할 수 있습니다)
- **윈도우를 닫아도 계속 실행**(기본값 켬. 끄면 메인 윈도우를 닫을 때 종료합니다)
- **메뉴 막대에 표시**

'출력' 탭에서는 저장 위치와 파일 이름을 설정합니다(위의 '저장과 복사' 참조). '설정 공유' 탭에서는 마스크 도형, 절단면, 생략선, 파일 이름, 저장 위치 종류 설정을 **내보내기…**로 BreaklineTrimmer-Settings.plist에 저장하고 **가져오기…**로 다른 Mac에서 불러올 수 있습니다. '설정 동기화'에서 iCloud Drive나 Dropbox 같은 폴더를 선택하면 같은 폴더를 선택한 Mac끼리 설정이 맞춰집니다. 이미지와 그린 범위는 포함하지 않습니다. 로그인 시 실행, 계속 실행, 메뉴 막대, 지정한 폴더는 Mac마다 설정합니다.

## 단축키
- **⌘O**: 처리할 이미지 열기
- **⌘S**: 저장(PNG, JPEG, PSD)
- **⇧⌘C**: 결과 이미지 복사하기
- **⌘C/⌘V**: 입력란 밖에서는 결과 이미지 복사하기/이미지를 붙여넣어 열기
- **⌘0**: 메인 윈도우 열기
- **⌘,**: 설정
- **⌘?**: 도움말
- **⌘W**: 윈도우 닫기
- **⌘Q**: BreaklineTrimmer 종료

전역 단축키는 사용하지 않습니다.

## 권한
특별한 권한은 필요하지 않습니다. 열거나 드롭하거나 붙여넣은 이미지만 읽고, 저장 위치로 선택한 파일에만 씁니다. 외부와 통신하지 않습니다(업데이트 확인은 배포 주소가 설정될 때까지 준비 중으로 표시하며 통신하지 않습니다).

## 실행과 종료
- **윈도우를 닫아도 계속 실행**이 켜져 있으면 윈도우를 닫아도 앱은 종료되지 않으며, 열어 둔 이미지와 범위도 그대로 남습니다. Dock 아이콘, **파일** 메뉴의 **메인 윈도우 열기**(⌘0), 메뉴 막대 아이콘(표시 중일 때)으로 다시 표시할 수 있습니다.
- 로그인 시 실행했을 때나 **시작 시 메인 윈도우 표시 안 함**이 켜져 있을 때는 메인 윈도우를 표시하지 않고 시작합니다. 파일을 넘겨 실행했을 때는 표시합니다.
- 종료하려면 앱 메뉴의 **BreaklineTrimmer 종료**(⌘Q)를 선택합니다. 저장하는 동안에는 종료할 수 없습니다. 저장이 끝난 뒤 다시 종료하세요.

## 문제 해결
- '범위가 이미지의 위쪽 끝부터 아래쪽 끝까지 덮고 있습니다'라고 표시되면 범위를 다시 그려 어느 한쪽 끝을 비워 두세요.
- 원하는 방향으로 분할되지 않으면 분할하고 싶은 방향으로 범위를 길게 그리세요.
- 절단면의 커브가 너무 크면 **커브** 값을 줄이세요(이미지 높이나 폭에 대한 비율입니다).
- 열리지 않는 이미지는 미리보기로 열 수 있는지 확인하고, PNG나 JPEG로 내보낸 뒤 여세요.
- 도움말 메뉴의 **note 글 열기**로 앱 소개 글(note)을 브라우저에서 열 수 있습니다.

## 앱 삭제
1. **로그인 시 실행**을 끕니다.
2. 앱을 종료합니다.
3. BreaklineTrimmer을 휴지통에 넣습니다.
''',
]

for index, lang in enumerate(LANGS):
    folder = root / 'Resources' / f'{lang}.lproj'
    folder.mkdir(parents=True, exist_ok=True)
    values = {row[0]: row[index + 1] for row in rows}
    (folder / 'Localizable.strings').write_text(
        '\n'.join(json.dumps(k, ensure_ascii=False) + ' = ' + json.dumps(v, ensure_ascii=False) + ';' for k, v in values.items()) + '\n')
    (folder / 'Help.txt').write_text(helptexts[index].strip() + '\n')
    (folder / 'InfoPlist.strings').write_text('"CFBundleDisplayName" = "BreaklineTrimmer";\n')

info = {
    'CFBundleName': 'BreaklineTrimmer', 'CFBundleDisplayName': 'BreaklineTrimmer', 'CFBundleIdentifier': 'jp.dtp-transit.breaklinetrimmer',
    'CFBundleExecutable': 'BreaklineTrimmer', 'CFBundlePackageType': 'APPL', 'CFBundleIconFile': 'BreaklineTrimmer.icns',
    'CFBundleInfoDictionaryVersion': '6.0', 'LSMinimumSystemVersion': '14.0', 'LSMultipleInstancesProhibited': True,
    'NSHighResolutionCapable': True, 'CFBundleDevelopmentRegion': 'en', 'CFBundleLocalizations': LANGS,
    'NSPrincipalClass': 'NSApplication', 'LSApplicationCategoryType': 'public.app-category.graphics-design',
    'SWAppFamily': 'swwwitch', 'NSHumanReadableCopyright': '© 2026 swwwitch',
    # No article of its own yet: the summary magazine (the About tab then shows no separate article row).
    'SWNoteArticleURL': 'https://note.com/swwwitch/m/m057948d2fbeb',
    'ITSAppUsesNonExemptEncryption': False,
    'CFBundleShortVersionString': '1.0.0', 'CFBundleVersion': '1',
    'CFBundleDocumentTypes': [{'CFBundleTypeName': 'Image', 'CFBundleTypeRole': 'Viewer', 'LSHandlerRank': 'Alternate',
                               'LSItemContentTypes': ['public.image']}],
}
# Version and build come from the existing Info.plist, so regeneration never reverts them.
plist_path = root / 'Info.plist'
current = plistlib.loads(plist_path.read_bytes()) if plist_path.exists() else {}
info.update({k: current[k] for k in ('CFBundleShortVersionString', 'CFBundleVersion') if k in current})
plist_path.write_bytes(plistlib.dumps(info))
print('Wrote Resources/*.lproj and Info.plist')
