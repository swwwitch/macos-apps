# 保管中の最新ビルド

2026年10月21日に共有配布先のInfo.plistを読み取った公開アプリの一覧です。表は機能ごとの実機検証・公証状態を保証するものではありません。配布物の実体はDropboxのLatest Buildsで共有します。

| アプリ | バージョン | build | Bundle ID |
| --- | --- | --- | --- |
| [VectorMate](VectorMate.app) | 2.9.0 | 53 | `jp.dtp-transit.vectormate` |
| [DocklessLauncher](DocklessLauncher.app) | 1.11.0 | 25 | `jp.dtp-transit.applauncher` |
| [BrowserSwitcher](BrowserSwitcher.app) | 1.7.0 | 58 | `jp.local.BrowserSwitcher` |
| [BundleIDInspector](BundleIDInspector.app) | 1.1.0 | 13 | `jp.dtp-transit.bundleidinspector` |
| [SpreadsheetHelper](SpreadsheetHelper.app) | 1.5.0 | 15 | `jp.dtp-transit.spreadsheethelper` |
| [PasteInARow](PasteInARow.app) | 1.5.0 | 20 | `jp.dtp-transit.pasteinarow` |
| [PasteMatchStyle](PasteMatchStyle.app) | 1.1.0 | 9 | `jp.dtp-transit.pastematchstyle` |
| [IncrementPaste](IncrementPaste.app) | 1.1.0 | 8 | `jp.dtp-transit.incrementpaste` |
| [CommandDee](CommandDee.app) | 1.9.0 | 55 | `jp.local.CommandDee` |
| [HotkeyHound](HotkeyHound.app) | 0.4.0 | 15 | `jp.dtp-transit.hotkeyhound` |
| [ExtensionLinker](ExtensionLinker.app) | 0.3.0 | 47 | `local.takano.DutiGUI` |
| [FolderHopper](FolderHopper.app) | 0.2.0 | 118 | `jp.local.FolderMover` |
| [ProjectFolder](ProjectFolder.app) | 1.12.0 | 24 | `jp.dtp-transit.foldermaker` |
| [FileCaravan](FileCaravan.app) | 1.1.0 | 33 | `local.takano.FolderMover` |
| [IdBackgroundOff](IdBackgroundOff.app) | 1.1.2 | 18 | `local.takano.IdAsyncOff` |
| [CCAutoUpdateOff](CCAutoUpdateOff.app) | 1.4.0 | 15 | `local.takano.CCAutoUpdateOff` |
| [KageTrimmer](KageTrimmer.app) | 1.4.0 | 71 | `jp.dtp-transit.kagetrimmer` |
| [KeynoteSweeper](KeynoteSweeper.app) | 1.1.0 | 10 | `jp.local.KeynoteSweeper` |
| [KakkoReplace](KakkoReplace.app) | 0.4.0 | 67 | `jp.local.SuperKakkoEdit` |
| [LinkMaker](LinkMaker.app) | 1.3.0 | 31 | `jp.dtp-transit.linkmaker` |
| [MarkdownKitchen](MarkdownKitchen.app) | 1.46.0 | 112 | `jp.dtp-transit.markdownkitchen` |
| [MightyEdit](MightyEdit.app) | 0.3.0 | 109 | `jp.local.TextPalette` |
| [PDF2Keynote](PDF2Keynote.app) | 1.2.0 | 22 | `jp.local.PDF2Keynote` |
| [CarmaChameleon](CarmaChameleon.app) | 0.15.0 | 47 | `jp.local.PandocDesk` |
| [PrefsPreset](PrefsPreset.app) | 1.2.0 | 20 | `jp.dtp-transit.prefspreset` |
| [PodiumAssist](PodiumAssist.app) | 3.3.0 | 62 | `jp.local.toki` |
| [QuickIconExporter](QuickIconExporter.app) | 1.2.0 | 37 | `jp.dtp-transit.quickiconexporter` |
| [YohakuTrimmer](YohakuTrimmer.app) | 1.2.0 | 9 | `jp.dtp-transit.yohakutrimmer` |
| [note2markdown](note2markdown.app) | 1.3.0 | 10 | `jp.dtp-transit.note2markdown` |
| [ListMatch](ListMatch.app) | 1.6.0 | 11 | `jp.dtp-transit.listdiff` |
| [BreaklineTrimmer](BreaklineTrimmer.app) | 1.4.0 | 10 | `jp.dtp-transit.breaklinetrimmer` |
| [FnNumpad](FnNumpad.app) | 1.0.0 | 2 | `jp.dtp-transit.fnnumpad` |

別の Mac へまとめて入れるときは `Install Latest Apps.command` をダブルクリックします（未インストールか、こちらの方が新しいものだけを `/Applications` へ。起動中のアプリは終了して入れ替え、起動し直します）。最後に `/Applications/swApps` へ自作アプリのシンボリックリンクを作り直すので、Path Finder・Finder のお気に入りに登録しておくと一覧できます。

最終ビルドの配置先は `/Applications` とこのフォルダです。過去のDMGは [DistributionArchive](../Shared/DistributionArchive/) へ退避しました。自動コピーは [BuildTools](../Shared/BuildTools/README.md)、共通ルールは [BASELINE](../Shared/AppStandards/BASELINE.md) を参照してください。
