from pathlib import Path
import json
root = Path(__file__).parent
# Japanese, English, Simplified Chinese, Korean. All UI keys share one validated table.
rows = '''heading|Keynoteの書類を整理|Clean Up a Keynote Presentation|整理 Keynote 演示文稿|Keynote 프레젠테이션 정리
subtitle|使用されていないマスター・非表示のスライド・アニメーションを削除します。|Deletes unused masters, hidden slides and animations.|删除未使用的母版、隐藏的幻灯片和动画。|사용하지 않는 마스터, 숨긴 슬라이드, 애니메이션을 삭제합니다.
target|対象の書類|Presentation|目标演示文稿|대상 프레젠테이션
chooseFile|ファイルを開く…|Open File…|打开文件…|파일 열기…
useFront|最前面の書類に戻す|Use Front Presentation|改用最前面的演示文稿|맨 앞 프레젠테이션 사용
frontMode|Keynoteの最前面の書類が対象です|Target: Keynote's front presentation|目标：Keynote 最前面的演示文稿|대상: Keynote 맨 앞 프레젠테이션
fileMode|ドロップしたファイルが対象です（Keynoteで開いています）|Target: the dropped file (open in Keynote)|目标：拖入的文件（已在 Keynote 中打开）|대상: 드롭한 파일(Keynote에서 열림)
dropHint|.keyファイルをウインドウにドロップすると、そのファイルをKeynoteで開いて対象にします。|Drop a .key file on the window to open it in Keynote and make it the target.|将 .key 文件拖到窗口上，会在 Keynote 中打开并作为目标。|.key 파일을 윈도우에 드롭하면 Keynote에서 열고 대상으로 합니다.
unsupported|Keynoteのファイル（.key）をドロップしてください。|Drop a Keynote file (.key).|请拖入 Keynote 文件（.key）。|Keynote 파일(.key)을 드롭하세요.
oneFileOnly|最初の.keyファイルだけを対象にしました。|Only the first .key file was used.|仅使用了第一个 .key 文件。|첫 번째 .key 파일만 사용했습니다.
targetClosed|ドロップした書類が閉じられたため、最前面の書類に戻しました。|The dropped presentation was closed, so the front presentation is used.|拖入的演示文稿已关闭，已改用最前面的演示文稿。|드롭한 프레젠테이션이 닫혀 맨 앞 프레젠테이션을 사용합니다.
nothingToDelete|「%@」には削除するものがありません。|Nothing to delete in “%@”.|“%@”中没有要删除的内容。|“%@”에는 삭제할 항목이 없습니다.
refresh|再読み込み|Reload|重新载入|다시 불러오기
refreshHint|対象の書類を読み直します|Read the presentation again|重新读取演示文稿|프레젠테이션을 다시 읽습니다
noTarget|書類がありません|No presentation|没有演示文稿|프레젠테이션 없음
summary|スライド %d枚・マスター %d個|%d slides · %d masters|%d 张幻灯片 · %d 个母版|슬라이드 %d개 · 마스터 %d개
items|削除する項目|Delete|要删除的项目|삭제할 항목
deleteLayouts|使用されていないマスターを削除|Delete unused masters|删除未使用的母版|사용하지 않는 마스터 삭제
countLayouts|（%d個）| (%d)|（%d 个）| (%d개)
deleteHidden|非表示のスライドを削除|Delete hidden slides|删除隐藏的幻灯片|숨긴 슬라이드 삭제
removeTransitions|すべてのトランジションを削除|Remove all transitions|删除所有过渡效果|모든 전환 효과 삭제
confirmTransitions|トランジション：%d枚|Transitions: %d slides|过渡效果：%d 张|전환 효과: %d개
resultTransitions|トランジション：%d枚から削除|Transitions removed from %d slides|已从 %d 张幻灯片删除过渡效果|%d개 슬라이드의 전환 효과 삭제
removeBuilds|すべてのオブジェクトのアニメーションを削除|Remove all object animations|删除所有对象动画|모든 객체 애니메이션 삭제
confirmBuilds|オブジェクトのアニメーション：すべてのスライド|Object animations: every slide|对象动画：所有幻灯片|객체 애니메이션: 모든 슬라이드
resultBuilds|オブジェクトのアニメーション：%d個を削除（スライド%d枚）|Object animations removed: %d (on %d slides)|已删除对象动画：%d 个（%d 张幻灯片）|객체 애니메이션 %d개 삭제(슬라이드 %d개)
stepProgress|%d／%d|%d/%d|%d/%d|%d/%d
countSlides|（%d枚）| (%d)|（%d 张）| (%d개)
itemsHint|非表示のスライドも選ぶと、それだけが使っていたマスターも削除します。トランジションを外しても、自動で進む設定と待ち時間はそのままです。マスターとオブジェクトのアニメーションの削除中はKeynoteを操作しないでください。|With hidden slides on, masters used only by them are deleted too. Removing transitions keeps auto-advance and delays. Don't use Keynote while masters or object animations are being deleted.|同时选择隐藏的幻灯片时，仅被其使用的母版也会删除。删除过渡效果时保留自动播放和延迟设置。删除母版和对象动画期间请勿操作 Keynote。|숨긴 슬라이드도 선택하면 그 슬라이드만 사용하던 마스터도 삭제합니다. 전환 효과를 삭제해도 자동 진행과 지연 시간은 유지됩니다. 마스터와 객체 애니메이션 삭제 중에는 Keynote를 조작하지 마세요.
listColon|：|: |：|:
listSeparator|、|, |、|,
ready|Keynoteで書類を開いてください。|Open a presentation in Keynote.|请在 Keynote 中打开演示文稿。|Keynote에서 프레젠테이션을 여세요.
readyToRun|削除する項目を選んで「削除」を押してください。|Choose what to delete, then click Delete.|选择要删除的项目，然后点击“删除”。|삭제할 항목을 선택한 후 "삭제"를 누르세요.
nothingHere|削除するものはありません。|Nothing to delete.|没有要删除的内容。|삭제할 항목이 없습니다.
run|削除|Delete|删除|삭제
delete|削除|Delete|删除|삭제
cancel|キャンセル|Cancel|取消|취소
confirmTitle|「%@」から削除しますか？|Delete from “%@”?|要从“%@”中删除吗？|“%@”에서 삭제할까요?
confirmLayouts|使用されていないマスター：%d個|Unused masters: %d|未使用的母版：%d 个|사용하지 않는 마스터: %d개
confirmSlides|非表示のスライド：%d枚|Hidden slides: %d|隐藏的幻灯片：%d 张|숨긴 슬라이드: %d개
confirmNote|Keynoteの［取り消す］で1件ずつ戻せます。保存した書類は変更されないので、まとめて戻すときは保存せずに閉じてください。|Keynote's Undo restores them one at a time. The saved file is unchanged until you save, so you can also close without saving.|可用 Keynote 的“撤销”逐个恢复。保存前文件不会改变，也可以不保存直接关闭。|Keynote의 실행 취소로 하나씩 되돌릴 수 있습니다. 저장하기 전에는 파일이 바뀌지 않으므로 저장하지 않고 닫아도 됩니다.
working|削除しています…|Deleting…|正在删除…|삭제 중…
cancelling|中止しています…|Cancelling…|正在取消…|취소 중…
cancelled|中止しました（削除済みのものはそのままです）|Cancelled (items already deleted stay deleted)|已取消（已删除的项目保持删除）|취소됨(이미 삭제한 항목은 그대로)
success|削除が完了しました|Done|删除完成|삭제 완료
failed|削除できませんでした|Nothing was deleted|无法删除|삭제하지 못했습니다
partial|一部を削除できませんでした|Some items could not be deleted|部分项目无法删除|일부 항목을 삭제하지 못했습니다
resultSlides|非表示のスライド：%d枚を削除|Hidden slides deleted: %d|已删除隐藏的幻灯片：%d 张|숨긴 슬라이드 %d개 삭제
resultLayouts|マスター：%d個を削除|Masters deleted: %d|已删除母版：%d 个|마스터 %d개 삭제
resultSkipped|削除できなかったマスター：|Masters not deleted: |未删除的母版：|삭제하지 못한 마스터:
keynoteMissing|Keynoteが見つかりません。App StoreからKeynoteをインストールしてください。|Keynote is not installed. Install it from the App Store.|未找到 Keynote。请从 App Store 安装。|Keynote가 없습니다. App Store에서 설치하세요.
keynoteNotRunning|Keynoteが起動していません。Keynoteで書類を開いてください。|Keynote is not running. Open a presentation in Keynote.|Keynote 未运行。请在 Keynote 中打开演示文稿。|Keynote가 실행 중이 아닙니다. Keynote에서 프레젠테이션을 여세요.
noDocument|Keynoteで書類が開かれていません。|No presentation is open in Keynote.|Keynote 中没有打开的演示文稿。|Keynote에 열린 프레젠테이션이 없습니다.
automationDenied|Keynoteの操作が許可されていません。システム設定の「オートメーション」でKeynoteSweeperのKeynoteをオンにしてください。|KeynoteSweeper is not allowed to control Keynote. Turn on Keynote for KeynoteSweeper in Automation settings.|KeynoteSweeper 未被允许控制 Keynote。请在“自动化”设置中打开。|KeynoteSweeper가 Keynote를 제어하도록 허용되지 않았습니다. 자동화 설정에서 켜세요.
accessibilityDenied|マスターとオブジェクトのアニメーションの削除にはアクセシビリティの許可が必要です。システム設定でKeynoteSweeperを許可してください。|Deleting masters and object animations needs Accessibility permission. Allow KeynoteSweeper in System Settings.|删除母版和对象动画需要辅助功能权限。请在系统设置中允许 KeynoteSweeper。|마스터와 객체 애니메이션을 삭제하려면 손쉬운 사용 권한이 필요합니다. 시스템 설정에서 KeynoteSweeper를 허용하세요.
allHidden|すべてのスライドが非表示のため、スライドは削除しませんでした。|Every slide is hidden, so no slides were deleted.|所有幻灯片都已隐藏，因此未删除幻灯片。|모든 슬라이드가 숨겨져 있어 슬라이드를 삭제하지 않았습니다.
editorUnavailable|Keynoteの［スライドレイアウトを編集］を開けませんでした。Keynoteでダイアログボックスが開いていないか確認してください。|Could not open Edit Slide Layouts in Keynote. Check for an open dialog in Keynote.|无法打开 Keynote 的“编辑幻灯片布局”。请检查 Keynote 中是否有打开的对话框。|Keynote의 슬라이드 레이아웃 편집을 열 수 없습니다. Keynote에 열린 대화상자가 있는지 확인하세요.
documentChanged|Keynoteの最前面の書類が変わったため中止しました。|Stopped because the front Keynote presentation changed.|Keynote 最前面的演示文稿已改变，已停止。|Keynote 맨 앞의 프레젠테이션이 바뀌어 중지했습니다.
interrupted|Keynoteから別のアプリに切り替わったため中止しました。|Stopped because another app came to the front.|已切换到其他应用，已停止。|다른 앱으로 전환되어 중지했습니다.
keynoteError|Keynoteでエラーが発生しました：|Keynote reported an error: |Keynote 报告错误：|Keynote 오류:
quitBusy|削除中です。完了を待つか、キャンセルしてから終了してください。|Wait for it to finish, or cancel before quitting.|请等待完成，或取消后再退出。|끝날 때까지 기다리거나 취소한 후 종료하세요.
ok|OK|OK|好|확인
resident|ウインドウを閉じても常駐|Keep running after closing|关闭窗口后继续运行|창을 닫아도 계속 실행
residentDetail|閉じた後もDockやメニューバーから再表示できます。オフにすると閉じたときに終了します。|Reopen from the Dock or menu bar. When off, closing the window quits.|可从 Dock 或菜单栏再次打开。关闭此项时，关闭窗口即退出。|Dock 또는 메뉴 막대에서 다시 열 수 있습니다. 끄면 창을 닫을 때 종료됩니다.
launchShortcut|アプリ起動のホットキー|App launch keyboard shortcut|启动应用快捷键|앱 실행 키보드 단축키
openShortcuts|ショートカットを開く|Open Shortcuts|打开快捷指令|단축어 열기
shortcutDetail|ショートカットAppで「アプリを開く」にKeynoteSweeperを指定し、キーを割り当ててください。未起動時も使えます。|In Shortcuts, create an Open App action for KeynoteSweeper and assign a key. It works even when the app is not running.|在快捷指令中为 KeynoteSweeper 创建“打开 App”并分配按键，应用未运行时也可使用。|단축어 앱에서 KeynoteSweeper를 여는 동작을 만들고 키를 지정하세요. 앱이 실행 중이 아니어도 작동합니다.
permission|Keynoteの操作|Keynote control|控制 Keynote|Keynote 제어
permissionWhy|書類の内容を読み取り、非表示のスライドを削除するため、オートメーション（Apple Events）の許可が必要です。|Automation (Apple Events) permission lets KeynoteSweeper read the presentation and delete hidden slides.|需要自动化（Apple Events）权限才能读取演示文稿并删除隐藏的幻灯片。|프레젠테이션을 읽고 숨긴 슬라이드를 삭제하려면 자동화(Apple Events) 권한이 필요합니다.
permAllowed|許可済み|Allowed|已允许|허용됨
permDenied|未許可|Not allowed|未允许|허용 안 됨
permUnknown|未確認（Keynoteの起動中に確認できます）|Unknown (checked while Keynote is running)|未确认（Keynote 运行时可确认）|확인 안 됨(Keynote 실행 중 확인 가능)
permAsk|許可を確認|Check permission|检查权限|권한 확인
permOpen|オートメーション設定を開く|Open Automation Settings|打开自动化设置|자동화 설정 열기
openMainWindow|メインウインドウを開く|Open Main Window|打开主窗口|메인 윈도우 열기
settings|設定…|Settings…|设置…|설정…
settingsWindow|設定|Settings|设置|설정
help|KeynoteSweeperヘルプ|KeynoteSweeper Help|KeynoteSweeper 帮助|KeynoteSweeper 도움말
helpMenu|ヘルプ|Help|帮助|도움말
quit|KeynoteSweeperを終了|Quit KeynoteSweeper|退出 KeynoteSweeper|KeynoteSweeper 종료
hide|KeynoteSweeperを隠す|Hide KeynoteSweeper|隐藏 KeynoteSweeper|KeynoteSweeper 가리기
services|サービス|Services|服务|서비스
hideOthers|ほかを隠す|Hide Others|隐藏其他|기타 가리기
showAll|すべてを表示|Show All|全部显示|모두 보기
about|KeynoteSweeperについて|About KeynoteSweeper|关于 KeynoteSweeper|KeynoteSweeper에 관하여
aboutDetail|Keynoteの書類から使用されていないマスターと非表示のスライドを削除します。サポート：同梱のREADME.md|Deletes unused masters and hidden slides from Keynote presentations. Support: bundled README.md|从 Keynote 演示文稿中删除未使用的母版和隐藏的幻灯片。支持：内置 README.md|Keynote 프레젠테이션에서 사용하지 않는 마스터와 숨긴 슬라이드를 삭제합니다. 지원: 포함된 README.md
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

automation = ['Keynoteの最前面の書類を読み取り、選んだ非表示のスライドを削除するため、Keynoteを操作します。',
              'KeynoteSweeper reads the front Keynote presentation and deletes the hidden slides you choose.',
              'KeynoteSweeper 需要读取 Keynote 最前面的演示文稿，并删除您选择的隐藏幻灯片。',
              'KeynoteSweeper는 Keynote 맨 앞의 프레젠테이션을 읽고 선택한 숨긴 슬라이드를 삭제합니다.']

# Keynote › Services item titles (keys are the NSMenuItem defaults in Info.plist).
services = {'Delete Unused Masters': ['使用されていないマスターを削除', 'Delete Unused Masters', '删除未使用的母版', '사용하지 않는 마스터 삭제'],
            'Delete Hidden Slides': ['非表示のスライドを削除', 'Delete Hidden Slides', '删除隐藏的幻灯片', '숨긴 슬라이드 삭제'],
            'Remove Transitions': ['トランジションを削除', 'Remove Transitions', '删除过渡效果', '전환 효과 삭제'],
            'Remove Object Animations': ['オブジェクトのアニメーションを削除', 'Remove Object Animations', '删除对象动画', '객체 애니메이션 삭제'],
            'Remove All Animations': ['すべてのアニメーションを削除', 'Remove All Animations', '删除所有动画', '모든 애니메이션 삭제']}

# Help text lives in help_text.py (markup rendered by Shared/AppStandards/HelpDocument.swift).
from help_text import HELP
helptexts = [HELP[l] for l in ['ja', 'en', 'zh-Hans', 'ko']]

for i, lang in enumerate(['ja', 'en', 'zh-Hans', 'ko']):
    p = root / 'Resources' / f'{lang}.lproj'
    p.mkdir(parents=True, exist_ok=True)
    (p / 'Localizable.strings').write_text('\n'.join(f'{json.dumps(r[0])} = {json.dumps(r[i + 1], ensure_ascii=False)};' for r in table) + '\n')
    (p / 'InfoPlist.strings').write_text(f'"NSAppleEventsUsageDescription" = {json.dumps(automation[i], ensure_ascii=False)};\n"CFBundleDisplayName" = "KeynoteSweeper";\n')
    (p / 'Help.txt').write_text(helptexts[i])
    # UTF-16 like Apple's own ServicesMenu.strings. pbs caches titles per bundle: after changing them run pbs -flush && pbs -update.
    (p / 'ServicesMenu.strings').write_text(''.join(f'{json.dumps(k)} = {json.dumps(v[i], ensure_ascii=False)};\n' for k, v in services.items()), encoding='utf-16')
print('resources:', len(table), 'keys x 4 languages')
