# 共通ホットキー欄・全アプリ配布結果（2026-10-27 JST）

- ソース：44d85133f41c3c38d30feee62e56b5d542ae556d。GitHub mainへpush・SHA一致確認。基点5eb6fa1のNotMyType両版・ShotSorterと保全したローカル変更を統合。
- 共通欄採用30アプリ、コピー18か所を同期。欄クリックで記録開始、再クリック・Escでキャンセル、変更ボタン廃止。MightyEditは日英中韓の生成元とヘルプも更新。
- 49アプリビルド成功、既存test.sh 34本成功。取り込み後NotMyType両版・ShotSorter・MightyEditの4本を再ビルド。
- 最終47本のApple公証Accepted、stapler・Gatekeeper確認済み。47本とも両配置先と公証済みソースの版・build・Bundle ID・署名・全ファイル/モード/symlink一致を最終確認し、/Applicationsからの起動を確認。
- SettingsCourier（ソース1.3.2/9 < 既存1.4.2/13）とVectorKeys（ソース1.3.1/5 < 既存1.4.0/6）は配置保留。最新ソース未取得のためbuild番号だけを増やさない。
- 通常終了を妨げたClipTidy・EventDocMaker・FavoriteFolders・SettingsHopのメニューバー案内を「あとで」で閉じ、通常終了・再配置が成功。強制終了なし。
- DropboxがVectorMateのSparkleヘッダーに追加した競合コピー6件はFinal47/DropboxConflictsへ保全して除去。全47本の最終署名・内容一致を再確認。
- 設定の事前/事後スナップショット47本を保存。ウインドウ位置、メニューバー案内状態、同期日時等に差分あり。NotMyType LiteのappHotkeyはJSONキー順のみで同値。NotMyType previewMode、PodiumAssist presetsにも差分があり、実行・同期・経過中の利用者操作と区別できないため「全設定が不変」とは主張しない。復元によるユーザー操作の上書きはしない。
- 追加試験：NotMyType字形16分類・補助平面・重複分類・除外テスト成功。共通StartupWindowのpolicy・late login・explicit reopen成功。ただしDockPresenceTestsの「main window restores application menus」でフォーカス非奪取assertが失敗。AppSwitcherWindowRevealTestsは「closed main is displayed」で失敗。この2項目は未解決で、47本の配置・起動確認と区別する。
- 全機能UI、実キー入力、再ログイン、Intel実機、Adobe貼り付け、公開Release/note更新は未実施。

ローカル詳細：Shared/ReleasePreparation/20261027-AllApps-HotkeyClick/Final47/verification-final.json、deployment-final.json、notary-results.json、Manifests/、preferences-comparison.json。
旧版バックアップ：Shared/Backups/Build/。配置ログ：Final47/とRetry4/。

| アプリ | 版 | build | 結果 |
| --- | --- | --- | --- |
| BreaklineTrimmer | 1.4.0 | 15 | 公証・両配置・起動確認 |
| BrowserSwitcher | 1.7.0 | 64 | 公証・両配置・起動確認 |
| BundleIDInspector | 1.1.0 | 16 | 公証・両配置・起動確認 |
| CCAutoUpdateOff | 1.4.0 | 20 | 公証・両配置・起動確認 |
| CarmaChameleon | 0.15.0 | 51 | 公証・両配置・起動確認 |
| ClipTidy | 1.0.1 | 3 | 公証・両配置・起動確認 |
| CommandDee | 1.9.0 | 60 | 公証・両配置・起動確認 |
| ControlMate | 1.3.2 | 6 | 公証・両配置・起動確認 |
| DocklessLauncher | 1.11.0 | 30 | 公証・両配置・起動確認 |
| EventDocMaker | 1.1.0 | 2 | 公証・両配置・起動確認 |
| ExtensionLinker | 0.3.3 | 56 | 公証・両配置・起動確認 |
| FavoriteFolders | 1.3.7 | 13 | 公証・両配置・起動確認 |
| FileCaravan | 1.1.0 | 37 | 公証・両配置・起動確認 |
| FileSorter | 1.0.1 | 2 | 公証・両配置・起動確認 |
| FnNumpad | 1.1.0 | 8 | 公証・両配置・起動確認 |
| FolderHopper | 0.2.0 | 125 | 公証・両配置・起動確認 |
| HotkeyHound | 0.4.0 | 20 | 公証・両配置・起動確認 |
| IdBackgroundOff | 1.1.2 | 22 | 公証・両配置・起動確認 |
| IncrementPaste | 1.1.0 | 12 | 公証・両配置・起動確認 |
| InsertSnippets | 1.11.2 | 28 | 公証・両配置・起動確認 |
| KageTrimmer | 1.4.0 | 75 | 公証・両配置・起動確認 |
| KakkoReplace | 0.4.0 | 71 | 公証・両配置・起動確認 |
| KeynoteMaestro | 1.2.2 | 30 | 公証・両配置・起動確認 |
| KeynoteSweeper | 1.2.0 | 15 | 公証・両配置・起動確認 |
| LinkMaker | 1.3.5 | 40 | 公証・両配置・起動確認 |
| ListMatch | 1.6.0 | 14 | 公証・両配置・起動確認 |
| MarkdownKitchen | 1.47.3 | 125 | 公証・両配置・起動確認 |
| MenuShot | 1.3.3 | 9 | 公証・両配置・起動確認 |
| MightyEdit | 0.3.3 | 116 | 公証・両配置・起動確認 |
| NotMyType | 1.62.1 | 102 | 公証・両配置・起動確認 |
| NotMyType Lite | 1.9.0 | 25 | 公証・両配置・起動確認 |
| PDF2Keynote | 1.2.0 | 25 | 公証・両配置・起動確認 |
| PasteInARow | 1.5.0 | 24 | 公証・両配置・起動確認 |
| PasteMatchStyle | 1.1.0 | 13 | 公証・両配置・起動確認 |
| PodiumAssist | 3.3.19 | 85 | 公証・両配置・起動確認 |
| PrefsPreset | 1.2.1 | 27 | 公証・両配置・起動確認 |
| ProjectFolder | 1.12.0 | 28 | 公証・両配置・起動確認 |
| QuickIconExporter | 1.2.0 | 42 | 公証・両配置・起動確認 |
| SVGExporter | 1.2.4 | 10 | 公証・両配置・起動確認 |
| ScreenTake | 1.0.1 | 2 | 公証・両配置・起動確認 |
| SettingsHop | 1.7.2 | 23 | 公証・両配置・起動確認 |
| ShotSorter | 1.1.0 | 3 | 公証・両配置・起動確認 |
| SiteMirror | 1.5.3 | 16 | 公証・両配置・起動確認 |
| SpreadsheetHelper | 1.5.0 | 19 | 公証・両配置・起動確認 |
| VectorMate | 2.19.2 | 81 | 公証・両配置・起動確認 |
| YohakuTrimmer | 1.2.0 | 13 | 公証・両配置・起動確認 |
| note2markdown | 1.3.0 | 14 | 公証・両配置・起動確認 |
