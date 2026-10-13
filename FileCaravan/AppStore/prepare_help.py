import pathlib, sys
resources = pathlib.Path(sys.argv[1])
messages = {
'ja': ('- 移動履歴はアプリのコンテナ内に保存する内部ログです。ユーザーのファイルは、選択した移動先へ移動します。「結果の履歴を表示」からログを開けます。', '- 更新はApp Storeから行います。独自の更新機能はありません。'),
'en': ('- Move history is an internal log in the app container. User files are moved to the selected destination. Use Show result history to open the log.', '- Updates are provided through the App Store. There is no separate updater.'),
'zh-Hans': ('- 移动历史是应用容器中的内部日志。用户文件移动到所选目标文件夹。使用显示结果历史打开日志。', '- 通过 App Store 更新。没有独立更新功能。'),
'ko': ('- 이동 기록은 앱 컨테이너의 내부 로그입니다. 사용자 파일은 선택한 대상 폴더로 이동합니다. 결과 기록 보기로 로그를 엽니다.', '- 업데이트는 App Store에서 제공합니다. 별도의 업데이트 기능은 없습니다.'),
}
for language, (history, update) in messages.items():
    path = resources / (language + '.lproj') / 'Help.txt'
    lines = path.read_text().splitlines()
    lines = [history if 'FolderMover/History' in line else update if 'App Store' in line else line for line in lines]
    path.write_text('\n'.join(lines) + '\n')
