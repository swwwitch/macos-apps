# 全アプリの二重起動防止点検（2026-11-05）

対象：正本 ~/Git/macos-apps の現存する54アプリのソース。未コミットの開発中変更を含む。配布アプリとの一致・実機での同時起動は未検証。

- 排他ロック実装あり：2（NotMyType通常版・Lite版）。直近のソース修正であり、配布確認ではない。
- 起動済みプロセスを調べる処理あり、排他ロックを検出せず：51。時間差の起動対策はあるが、同時起動での単一起動を保証するものではない。
- CommandDee：build.sh:34 に LSMultipleInstancesProhibited=true。アプリ内で自分の起動済みプロセスを判定する処理を確認できず。
- ShotSorterは廃止記録に従い対象外。VectorMaestroはBackups/buildのみで現行ソースなし。
- 通常版とLite版は別アプリとして数える。App Store派生版・古いバックアップ・配布済みバイナリは今回の検証対象外。

## 点検一覧

| アプリ | ソース確認結果 | 起動処理の根拠 |
|---|---|---|
| AlignKeys | 起動済みプロセス確認あり・同時起動の排他なし | [AlignKeys/Source/main.swift:37](</Users/takano/Git/macos-apps/AlignKeys/Source/main.swift:37>) |
| BreaklineTrimmer | 起動済みプロセス確認あり・同時起動の排他なし | [BreaklineTrimmer/Source/main.swift:1256](</Users/takano/Git/macos-apps/BreaklineTrimmer/Source/main.swift:1256>) / [BreaklineTrimmer/Source/main.swift:1280](</Users/takano/Git/macos-apps/BreaklineTrimmer/Source/main.swift:1280>) |
| BrowserSwitcher | 起動済みプロセス確認あり・同時起動の排他なし | [BrowserSwitcher/Source/main.swift:582](</Users/takano/Git/macos-apps/BrowserSwitcher/Source/main.swift:582>) / [BrowserSwitcher/Source/main.swift:610](</Users/takano/Git/macos-apps/BrowserSwitcher/Source/main.swift:610>) |
| BundleIDInspector | 起動済みプロセス確認あり・同時起動の排他なし | [BundleIDInspector/Sources/BundleIDInspector/BundleIDInspectorApp.swift:6](</Users/takano/Git/macos-apps/BundleIDInspector/Sources/BundleIDInspector/BundleIDInspectorApp.swift:6>) / [BundleIDInspector/Sources/BundleIDInspector/BundleIDInspectorApp.swift:163](</Users/takano/Git/macos-apps/BundleIDInspector/Sources/BundleIDInspector/BundleIDInspectorApp.swift:163>) |
| CCAutoUpdateOff | 起動済みプロセス確認あり・同時起動の排他なし | [CCAutoUpdateOff/Source/main.swift:385](</Users/takano/Git/macos-apps/CCAutoUpdateOff/Source/main.swift:385>) |
| CarmaChameleon | 起動済みプロセス確認あり・同時起動の排他なし | [CarmaChameleon/Source/main.swift:674](</Users/takano/Git/macos-apps/CarmaChameleon/Source/main.swift:674>) / [CarmaChameleon/Source/main.swift:716](</Users/takano/Git/macos-apps/CarmaChameleon/Source/main.swift:716>) |
| ClipTidy | 起動済みプロセス確認あり・同時起動の排他なし | [ClipTidy/Source/main.swift:87](</Users/takano/Git/macos-apps/ClipTidy/Source/main.swift:87>) |
| CommandDee | OS設定あり／アプリ内の自アプリ確認なし | [CommandDee/build.sh:34](</Users/takano/Git/macos-apps/CommandDee/build.sh:34>) / [CommandDee/Sources/main.swift:62](</Users/takano/Git/macos-apps/CommandDee/Sources/main.swift:62>) |
| ControlMate | 起動済みプロセス確認あり・同時起動の排他なし | [ControlMate/Sources/main.swift:611](</Users/takano/Git/macos-apps/ControlMate/Sources/main.swift:611>) / [ControlMate/Sources/main.swift:622](</Users/takano/Git/macos-apps/ControlMate/Sources/main.swift:622>) |
| DocklessLauncher | 起動済みプロセス確認あり・同時起動の排他なし | [DocklessLauncher/Sources/main.swift:928](</Users/takano/Git/macos-apps/DocklessLauncher/Sources/main.swift:928>) / [DocklessLauncher/Sources/main.swift:939](</Users/takano/Git/macos-apps/DocklessLauncher/Sources/main.swift:939>) |
| EventDocMaker | 起動済みプロセス確認あり・同時起動の排他なし | [EventDocMaker/Source/main.swift:152](</Users/takano/Git/macos-apps/EventDocMaker/Source/main.swift:152>) |
| ExtensionLinker | 起動済みプロセス確認あり・同時起動の排他なし | [ExtensionLinker/Development/Sources/DutiGUI/DutiGUIApp.swift:9](</Users/takano/Git/macos-apps/ExtensionLinker/Development/Sources/DutiGUI/DutiGUIApp.swift:9>) / [ExtensionLinker/Development/Sources/DutiGUI/DutiGUIApp.swift:524](</Users/takano/Git/macos-apps/ExtensionLinker/Development/Sources/DutiGUI/DutiGUIApp.swift:524>) |
| FavoriteFolders | 起動済みプロセス確認あり・同時起動の排他なし | [FavoriteFolders/Source/DFX.swift:13](</Users/takano/Git/macos-apps/FavoriteFolders/Source/DFX.swift:13>) / [FavoriteFolders/Source/main.swift:787](</Users/takano/Git/macos-apps/FavoriteFolders/Source/main.swift:787>) |
| FileCaravan | 起動済みプロセス確認あり・同時起動の排他なし | [FileCaravan/Source/main.swift:206](</Users/takano/Git/macos-apps/FileCaravan/Source/main.swift:206>) |
| FileSorter | 起動済みプロセス確認あり・同時起動の排他なし | [FileSorter/Source/main.swift:174](</Users/takano/Git/macos-apps/FileSorter/Source/main.swift:174>) |
| FnNumpad | 起動済みプロセス確認あり・同時起動の排他なし | [FnNumpad/Sources/main.swift:446](</Users/takano/Git/macos-apps/FnNumpad/Sources/main.swift:446>) / [FnNumpad/Sources/main.swift:457](</Users/takano/Git/macos-apps/FnNumpad/Sources/main.swift:457>) |
| FolderHopper | 起動済みプロセス確認あり・同時起動の排他なし | [FolderHopper/Development/Source/main.swift:681](</Users/takano/Git/macos-apps/FolderHopper/Development/Source/main.swift:681>) / [FolderHopper/Development/Source/main.swift:1364](</Users/takano/Git/macos-apps/FolderHopper/Development/Source/main.swift:1364>) |
| HotkeyHound | 起動済みプロセス確認あり・同時起動の排他なし | [HotkeyHound/Sources/HotkeyHound/HotkeyHoundApp.swift:6](</Users/takano/Git/macos-apps/HotkeyHound/Sources/HotkeyHound/HotkeyHoundApp.swift:6>) / [HotkeyHound/Sources/HotkeyHound/HotkeyHoundApp.swift:163](</Users/takano/Git/macos-apps/HotkeyHound/Sources/HotkeyHound/HotkeyHoundApp.swift:163>) |
| IdBackgroundOff | 起動済みプロセス確認あり・同時起動の排他なし | [IdBackgroundOff/Source/main.swift:320](</Users/takano/Git/macos-apps/IdBackgroundOff/Source/main.swift:320>) |
| IncrementPaste | 起動済みプロセス確認あり・同時起動の排他なし | [IncrementPaste/Sources/main.swift:560](</Users/takano/Git/macos-apps/IncrementPaste/Sources/main.swift:560>) / [IncrementPaste/Sources/main.swift:571](</Users/takano/Git/macos-apps/IncrementPaste/Sources/main.swift:571>) |
| InputMaestro | 起動済みプロセス確認あり・同時起動の排他なし | [InputMaestro/Sources/main.swift:644](</Users/takano/Git/macos-apps/InputMaestro/Sources/main.swift:644>) / [InputMaestro/Sources/main.swift:655](</Users/takano/Git/macos-apps/InputMaestro/Sources/main.swift:655>) |
| InsertSnippets | 起動済みプロセス確認あり・同時起動の排他なし | [InsertSnippets/Sources/main.swift:982](</Users/takano/Git/macos-apps/InsertSnippets/Sources/main.swift:982>) |
| KageTrimmer | 起動済みプロセス確認あり・同時起動の排他なし | [KageTrimmer/Development/Sources/SoftShadowApp.swift:222](</Users/takano/Git/macos-apps/KageTrimmer/Development/Sources/SoftShadowApp.swift:222>) / [KageTrimmer/Development/Sources/SoftShadowApp.swift:744](</Users/takano/Git/macos-apps/KageTrimmer/Development/Sources/SoftShadowApp.swift:744>) |
| KakkoReplace | 起動済みプロセス確認あり・同時起動の排他なし | [KakkoReplace/Sources/main.swift:433](</Users/takano/Git/macos-apps/KakkoReplace/Sources/main.swift:433>) / [KakkoReplace/Sources/main.swift:444](</Users/takano/Git/macos-apps/KakkoReplace/Sources/main.swift:444>) |
| KeynoteMaestro | 起動済みプロセス確認あり・同時起動の排他なし | [KeynoteMaestro/Sources/main.swift:1094](</Users/takano/Git/macos-apps/KeynoteMaestro/Sources/main.swift:1094>) / [KeynoteMaestro/Sources/main.swift:1105](</Users/takano/Git/macos-apps/KeynoteMaestro/Sources/main.swift:1105>) |
| KeynoteSweeper | 起動済みプロセス確認あり・同時起動の排他なし | [KeynoteSweeper/Source/main.swift:404](</Users/takano/Git/macos-apps/KeynoteSweeper/Source/main.swift:404>) / [KeynoteSweeper/Source/main.swift:449](</Users/takano/Git/macos-apps/KeynoteSweeper/Source/main.swift:449>) |
| LayoutKeys | 起動済みプロセス確認あり・同時起動の排他なし | [LayoutKeys/Source/main.swift:37](</Users/takano/Git/macos-apps/LayoutKeys/Source/main.swift:37>) |
| LinkMaker | 起動済みプロセス確認あり・同時起動の排他なし | [LinkMaker/Sources/main.swift:502](</Users/takano/Git/macos-apps/LinkMaker/Sources/main.swift:502>) / [LinkMaker/Sources/main.swift:513](</Users/takano/Git/macos-apps/LinkMaker/Sources/main.swift:513>) |
| ListMatch | 起動済みプロセス確認あり・同時起動の排他なし | [ListMatch/Source/main.swift:743](</Users/takano/Git/macos-apps/ListMatch/Source/main.swift:743>) |
| MarkdownKitchen | 起動済みプロセス確認あり・同時起動の排他なし | [MarkdownKitchen/Sources/MarkdownKitchen/MarkdownKitchenApp.swift:6](</Users/takano/Git/macos-apps/MarkdownKitchen/Sources/MarkdownKitchen/MarkdownKitchenApp.swift:6>) / [MarkdownKitchen/Sources/MarkdownKitchen/MarkdownKitchenApp.swift:304](</Users/takano/Git/macos-apps/MarkdownKitchen/Sources/MarkdownKitchen/MarkdownKitchenApp.swift:304>) |
| MenuShot | 起動済みプロセス確認あり・同時起動の排他なし | [MenuShot/Source/main.swift:399](</Users/takano/Git/macos-apps/MenuShot/Source/main.swift:399>) |
| MightyEdit | 起動済みプロセス確認あり・同時起動の排他なし | [MightyEdit/Source/main.swift:1253](</Users/takano/Git/macos-apps/MightyEdit/Source/main.swift:1253>) / [MightyEdit/Source/main.swift:1263](</Users/takano/Git/macos-apps/MightyEdit/Source/main.swift:1263>) |
| NotMyType | 排他ロックあり（実機未確認） | [NotMyType/Sources/NotMyType/NotMyTypeApp.swift:239](</Users/takano/Git/macos-apps/NotMyType/Sources/NotMyType/NotMyTypeApp.swift:239>) |
| NotMyType Lite | 排他ロックあり（実機未確認） | [NotMyType Lite/Sources/NotMyTypeLite/NotMyTypeApp.swift:225](</Users/takano/Git/macos-apps/NotMyType Lite/Sources/NotMyTypeLite/NotMyTypeApp.swift:225>) |
| PDF2Keynote | 起動済みプロセス確認あり・同時起動の排他なし | [PDF2Keynote/Source/main.swift:400](</Users/takano/Git/macos-apps/PDF2Keynote/Source/main.swift:400>) |
| PasteInARow | 起動済みプロセス確認あり・同時起動の排他なし | [PasteInARow/Sources/main.swift:721](</Users/takano/Git/macos-apps/PasteInARow/Sources/main.swift:721>) / [PasteInARow/Sources/main.swift:732](</Users/takano/Git/macos-apps/PasteInARow/Sources/main.swift:732>) |
| PasteMaestro | 起動済みプロセス確認あり・同時起動の排他なし | [PasteMaestro/Sources/main.swift:751](</Users/takano/Git/macos-apps/PasteMaestro/Sources/main.swift:751>) / [PasteMaestro/Sources/main.swift:762](</Users/takano/Git/macos-apps/PasteMaestro/Sources/main.swift:762>) |
| PasteMatchStyle | 起動済みプロセス確認あり・同時起動の排他なし | [PasteMatchStyle/Sources/main.swift:494](</Users/takano/Git/macos-apps/PasteMatchStyle/Sources/main.swift:494>) / [PasteMatchStyle/Sources/main.swift:505](</Users/takano/Git/macos-apps/PasteMatchStyle/Sources/main.swift:505>) |
| PodiumAssist | 起動済みプロセス確認あり・同時起動の排他なし | [PodiumAssist/Development/Sources/Toki/TokiApp.swift:50](</Users/takano/Git/macos-apps/PodiumAssist/Development/Sources/Toki/TokiApp.swift:50>) / [PodiumAssist/Development/Sources/Toki/TokiApp.swift:1828](</Users/takano/Git/macos-apps/PodiumAssist/Development/Sources/Toki/TokiApp.swift:1828>) |
| PrefsPreset | 起動済みプロセス確認あり・同時起動の排他なし | [PrefsPreset/Sources/PrefsPreset/PrefsPresetApp.swift:6](</Users/takano/Git/macos-apps/PrefsPreset/Sources/PrefsPreset/PrefsPresetApp.swift:6>) / [PrefsPreset/Sources/PrefsPreset/PrefsPresetApp.swift:172](</Users/takano/Git/macos-apps/PrefsPreset/Sources/PrefsPreset/PrefsPresetApp.swift:172>) |
| ProjectFolder | 起動済みプロセス確認あり・同時起動の排他なし | [ProjectFolder/Sources/main.swift:896](</Users/takano/Git/macos-apps/ProjectFolder/Sources/main.swift:896>) / [ProjectFolder/Sources/main.swift:907](</Users/takano/Git/macos-apps/ProjectFolder/Sources/main.swift:907>) |
| QuickIconExporter | 起動済みプロセス確認あり・同時起動の排他なし | [QuickIconExporter/Development/Sources/IconDrop/IconDropApp.swift:6](</Users/takano/Git/macos-apps/QuickIconExporter/Development/Sources/IconDrop/IconDropApp.swift:6>) / [QuickIconExporter/Development/Sources/IconDrop/IconDropApp.swift:145](</Users/takano/Git/macos-apps/QuickIconExporter/Development/Sources/IconDrop/IconDropApp.swift:145>) |
| SVGExporter | 起動済みプロセス確認あり・同時起動の排他なし | [SVGExporter/Development/Sources/SVGExporter/SVGExporterApp.swift:6](</Users/takano/Git/macos-apps/SVGExporter/Development/Sources/SVGExporter/SVGExporterApp.swift:6>) |
| ScreenTake | 起動済みプロセス確認あり・同時起動の排他なし | [ScreenTake/Source/main.swift:585](</Users/takano/Git/macos-apps/ScreenTake/Source/main.swift:585>) |
| SettingsCourier | 起動済みプロセス確認あり・同時起動の排他なし | [SettingsCourier/Sources/SettingsCourier/SettingsCourierApp.swift:6](</Users/takano/Git/macos-apps/SettingsCourier/Sources/SettingsCourier/SettingsCourierApp.swift:6>) / [SettingsCourier/Sources/SettingsCourier/SettingsCourierApp.swift:175](</Users/takano/Git/macos-apps/SettingsCourier/Sources/SettingsCourier/SettingsCourierApp.swift:175>) |
| SettingsHop | 起動済みプロセス確認あり・同時起動の排他なし | [SettingsHop/Source/main.swift:260](</Users/takano/Git/macos-apps/SettingsHop/Source/main.swift:260>) |
| SiteMirror | 起動済みプロセス確認あり・同時起動の排他なし | [SiteMirror/Sources/SiteMirror/SiteMirrorApp.swift:6](</Users/takano/Git/macos-apps/SiteMirror/Sources/SiteMirror/SiteMirrorApp.swift:6>) / [SiteMirror/Sources/SiteMirror/SiteMirrorApp.swift:191](</Users/takano/Git/macos-apps/SiteMirror/Sources/SiteMirror/SiteMirrorApp.swift:191>) |
| SpreadsheetHelper | 起動済みプロセス確認あり・同時起動の排他なし | [SpreadsheetHelper/Sources/main.swift:654](</Users/takano/Git/macos-apps/SpreadsheetHelper/Sources/main.swift:654>) / [SpreadsheetHelper/Sources/main.swift:665](</Users/takano/Git/macos-apps/SpreadsheetHelper/Sources/main.swift:665>) |
| TextLens | 起動済みプロセス確認あり・同時起動の排他なし | [TextLens/Source/main.swift:155](</Users/takano/Git/macos-apps/TextLens/Source/main.swift:155>) |
| VectorFX | 起動済みプロセス確認あり・同時起動の排他なし | [VectorFX/Source/main.swift:22](</Users/takano/Git/macos-apps/VectorFX/Source/main.swift:22>) |
| VectorKeys | 起動済みプロセス確認あり・同時起動の排他なし | [VectorKeys/Source/main.swift:40](</Users/takano/Git/macos-apps/VectorKeys/Source/main.swift:40>) |
| VectorMate | 起動済みプロセス確認あり・同時起動の排他なし | [VectorMate/Source/main.swift:1292](</Users/takano/Git/macos-apps/VectorMate/Source/main.swift:1292>) / [VectorMate/Source/main.swift:1306](</Users/takano/Git/macos-apps/VectorMate/Source/main.swift:1306>) |
| YohakuTrimmer | 起動済みプロセス確認あり・同時起動の排他なし | [YohakuTrimmer/Development/Sources/YohakuTrimmerApp.swift:205](</Users/takano/Git/macos-apps/YohakuTrimmer/Development/Sources/YohakuTrimmerApp.swift:205>) / [YohakuTrimmer/Development/Sources/YohakuTrimmerApp.swift:548](</Users/takano/Git/macos-apps/YohakuTrimmer/Development/Sources/YohakuTrimmerApp.swift:548>) |
| note2markdown | 起動済みプロセス確認あり・同時起動の排他なし | [note2markdown/Source/main.swift:499](</Users/takano/Git/macos-apps/note2markdown/Source/main.swift:499>) |

## 残る確認・改善

- CommandDeeに起動済みインスタンスへの引き継ぎと終了処理を追加する。
- 他51アプリは排他ロックなどの同時起動対策を検討し、起動の早い段階で実行する。
- 再起動・ログイン起動・ウインドウを閉じた状態での再表示・ファイルを渡した起動を各アプリで検証する。
- 修正時は後から起動した側の終了処理がフォント解除・設定保存などを実行しないことも確認する。
- 今回は点検と記録のみ。全アプリの修正・ビルド・配布を実施済みとは扱わない。
