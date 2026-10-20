# 保管中の最新ビルド

2026-10-17に各アプリのInfo.plistから読み取った一覧です（31本、表と実物の一致を確認）。ビルド・配置に伴い更新してください。表は動作検証・公証済みを意味しません。

| アプリ | バージョン | build | Bundle ID |
| --- | --- | --- | --- |
| [VectorMate](VectorMate.app) | 2.18.5 | 74 | `jp.dtp-transit.vectormate` |
| [DocklessLauncher](DocklessLauncher.app) | 1.10.4 | 24 | `jp.dtp-transit.applauncher` |
| [BrowserSwitcher](BrowserSwitcher.app) | 1.6.37 | 57 | `jp.local.BrowserSwitcher` |
| [BundleIDInspector](BundleIDInspector.app) | 1.0.11 | 12 | `jp.dtp-transit.bundleidinspector` |
| [SpreadsheetHelper](SpreadsheetHelper.app) | 1.4.5 | 14 | `jp.dtp-transit.spreadsheethelper` |
| [PasteInARow](PasteInARow.app) | 1.4.9 | 19 | `jp.dtp-transit.pasteinarow` |
| [PasteMatchStyle](PasteMatchStyle.app) | 1.0.7 | 8 | `jp.dtp-transit.pastematchstyle` |
| [IncrementPaste](IncrementPaste.app) | 1.0.6 | 7 | `jp.dtp-transit.incrementpaste` |
| [CommandDee](CommandDee.app) | 1.8.27 | 54 | `jp.local.CommandDee` |
| [HotkeyHound](HotkeyHound.app) | 0.3.5 | 14 | `jp.dtp-transit.hotkeyhound` |
| [ExtensionLinker](ExtensionLinker.app) | 0.2.32 | 46 | `local.takano.DutiGUI` |
| [FolderHopper](FolderHopper.app) | 0.1.102 | 117 | `jp.local.FolderMover` |
| [ProjectFolder](ProjectFolder.app) | 1.11.6 | 22 | `jp.dtp-transit.foldermaker` |
| [FileCaravan](FileCaravan.app) | 1.0.17 | 32 | `local.takano.FolderMover` |
| [IdBackgroundOff](IdBackgroundOff.app) | 1.1.2 | 18 | `local.takano.IdAsyncOff` |
| [CCAutoUpdateOff](CCAutoUpdateOff.app) | 1.3.3 | 14 | `local.takano.CCAutoUpdateOff` |
| [KageTrimmer](KageTrimmer.app) | 1.3.7 | 70 | `jp.dtp-transit.kagetrimmer` |
| [KeynoteSweeper](KeynoteSweeper.app) | 1.0.8 | 9 | `jp.local.KeynoteSweeper` |
| [KakkoReplace](KakkoReplace.app) | 0.3.46 | 66 | `jp.local.SuperKakkoEdit` |
| [LinkMaker](LinkMaker.app) | 1.2.27 | 30 | `jp.dtp-transit.linkmaker` |
| [MarkdownKitchen](MarkdownKitchen.app) | 1.45.3 | 111 | `jp.dtp-transit.markdownkitchen` |
| [MightyEdit](MightyEdit.app) | 0.2.34 | 108 | `jp.local.TextPalette` |
| [PDF2Keynote](PDF2Keynote.app) | 1.1.7 | 21 | `jp.local.PDF2Keynote` |
| [CarmaChameleon](CarmaChameleon.app) | 0.14.3 | 46 | `jp.local.PandocDesk` |
| [PrefsPreset](PrefsPreset.app) | 1.1.16 | 19 | `jp.dtp-transit.prefspreset` |
| [PodiumAssist](PodiumAssist.app) | 3.2.38 | 61 | `jp.local.toki` |
| [QuickIconExporter](QuickIconExporter.app) | 1.1.1 | 36 | `jp.dtp-transit.quickiconexporter` |
| [YohakuTrimmer](YohakuTrimmer.app) | 1.1.6 | 8 | `jp.dtp-transit.yohakutrimmer` |
| [note2markdown](note2markdown.app) | 1.2.0 | 9 | `jp.dtp-transit.note2markdown` |
| [ListMatch](ListMatch.app) | 1.5.3 | 10 | `jp.dtp-transit.listdiff` |
| [BreaklineTrimmer](BreaklineTrimmer.app) | 1.3.2 | 9 | `jp.dtp-transit.breaklinetrimmer` |

別の Mac へまとめて入れるときは `Install Latest Apps.command` をダブルクリックします（未インストールか、こちらの方が新しいものだけを `/Applications` へ。起動中のアプリは終了して入れ替え、起動し直します）。最後に `/Applications/swApps` へ自作アプリのシンボリックリンクを作り直すので、Path Finder・Finder のお気に入りに登録しておくと一覧できます。

最終ビルドの配置先は `/Applications` とこのフォルダです。過去のDMGは [DistributionArchive](../Shared/DistributionArchive/) へ退避しました。自動コピーは [BuildTools](../Shared/BuildTools/README.md)、共通ルールは [BASELINE](../Shared/AppStandards/BASELINE.md) を参照してください。
