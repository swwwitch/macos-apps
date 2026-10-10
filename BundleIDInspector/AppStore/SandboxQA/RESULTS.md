# Sandbox実機検証

検証日: 2026-10-09。候補は1.0.5 build6。APP_STORE_BUILD=1 / NO_DEPLOY=1でコンパイルし、別配置のAppStore/SandboxQA/BundleIDInspector.appをapp-sandboxとuser-selected.read-onlyでad-hoc署名。codesign --verify --deep --strict成功。Sparkleなし。実行中パスがこの候補であることをpsで確認。/ApplicationsおよびLatest Buildsは変更なし。

- 起動: PASS。
- NSOpenPanelから/Applications/BrowserSwitcher.appを選択: PASS。
- Bundle ID jp.local.BrowserSwitcher・1.6.26 (46)・アイコン表示: PASS。
- 単体コピー／すべてコピー: アプリの成功表示を確認。クリップボード内容の独立した読取確認は未完了。
- パスコピー: Finderの移動先シートへの貼付けで/Applications/BrowserSwitcher.appを確認。
- Finderで表示: メニュー実行後、Finderの対象選択は確認できず。Finderのウインドウメニューにはホームtakanoのみ。この項目はPASSにしない。拒否ログは見つからず、Sandboxが原因とも断定しない。
- ドロップ／Dockへの受渡し: 未実施。
- 複数追加、通常ファイル拒否、設定、ログイン起動、閉じる／再表示、再起動: 未確認。

製品コード変更なし。検証候補は通常配布物／Store提出物ではない。製品ビルド番号とDMGは変更していない。UI成功表示だけで全Sandbox適合を認定しない。

追加確認（2026-10-09）: pbpasteでjp.local.BrowserSwitcherのコピー内容一致を確認。Cmd+,で設定表示成功。ログイン時起動はOFF・検証用配置なので/Applicationsへ移動を案内。設定値は変更していない。Finder表示は継続未確認。ウインドウ再表示の操作中にユーザー操作による中断が発生したため未確認。ドロップはユーザーへ操作確認を依頼中。

追加確認: ユーザーがFinderから.appをドロップでき、Bundle IDが表示されたと明示回答。直後の検証版AXでAdobe Illustrator 2026 / com.adobe.illustrator / 30.7.0 (30.7.0)を確認。ドロップ: PASS（ユーザー実操作＋UI確認）。通常版へ戻さずSandbox検証版で実施。Finder表示はユーザー操作による自動操作中断が繰り返されたため、手動確認を依頼中。Sandbox原因の失敗と断定しない。
