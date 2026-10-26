# App integrity audit

Checked: 2026-10-26T23:59:49.392708+09:00

Scope: 50 managed apps, not third-party apps. Read-only checks: executable presence/permission, deep strict codesign verification, file hashes/modes/symlinks.

| App | Applications version (build) | Latest Builds version (build) | Findings |
| --- | --- | --- | --- |
| BreaklineTrimmer.app | 1.4.0 (15) | 1.4.0 (15) | content matches |
| BrowserSwitcher.app | 1.7.0 (64) | 1.7.0 (64) | content matches |
| BundleIDInspector.app | 1.1.0 (16) | 1.1.0 (16) | content matches |
| CCAutoUpdateOff.app | 1.4.0 (20) | 1.4.0 (20) | content matches |
| CarmaChameleon.app | 0.15.0 (51) | 0.15.0 (51) | content matches |
| ClipTidy.app | 1.0.1 (3) | 1.0.1 (3) | Applications: executable_missing, signature_invalid; content DIFFERS |
| CommandDee.app | 1.9.0 (60) | 1.9.0 (60) | content matches |
| ControlMate.app | 1.3.2 (6) | 1.3.2 (6) | content matches |
| DocklessLauncher.app | 1.11.0 (30) | 1.11.0 (30) | content matches |
| EventDocMaker.app | 1.1.0 (2) | 1.1.0 (2) | content matches |
| ExtensionLinker.app | 0.3.3 (56) | 0.3.3 (56) | content matches |
| FavoriteFolders.app | 1.3.7 (13) | 1.3.7 (13) | content matches |
| FileCaravan.app | 1.1.0 (37) | 1.1.0 (37) | content matches |
| FileSorter.app | 1.0.1 (2) | 1.0.1 (2) | Applications: executable_missing, signature_invalid; content DIFFERS |
| FnNumpad.app | 1.1.0 (8) | 1.1.0 (8) | content matches |
| FolderHopper.app | 0.2.0 (125) | 0.2.0 (125) | content matches |
| HotkeyHound.app | 0.4.0 (20) | 0.4.0 (20) | content matches |
| IdBackgroundOff.app | 1.1.2 (22) | 1.1.2 (22) | content matches |
| IncrementPaste.app | 1.1.0 (12) | 1.1.0 (12) | content matches |
| InsertSnippets.app | 1.11.2 (28) | 1.11.2 (28) | Applications: signature_invalid; content DIFFERS |
| KageTrimmer.app | 1.4.0 (75) | 1.4.0 (75) | content matches |
| KakkoReplace.app | 0.4.0 (71) | 0.4.0 (71) | Applications: signature_invalid; content DIFFERS |
| KeynoteMaestro.app | 1.2.2 (30) | 1.2.2 (30) | Applications: signature_invalid; content DIFFERS |
| KeynoteSweeper.app | 1.2.0 (14) | 1.2.0 (14) | content matches |
| LinkMaker.app | 1.3.5 (39) | 1.3.5 (39) | content matches |
| ListMatch.app | 1.6.0 (14) | 1.6.0 (14) | Applications: signature_invalid; content DIFFERS |
| MarkdownKitchen.app | 1.47.3 (125) | 1.47.0 (119) | LatestBuilds: signature_invalid; content DIFFERS |
| MenuShot.app | 1.3.3 (9) | 1.3.3 (9) | Applications: executable_missing, signature_invalid; content DIFFERS |
| MightyEdit.app | 0.3.3 (116) | 0.3.3 (116) | content matches |
| NotMyType Lite.app | 1.8.1 (23) | 1.8.1 (23) | content matches |
| NotMyType.app | 1.61.1 (99) | 1.61.1 (99) | content matches |
| PDF2Keynote.app | 1.2.0 (25) | 1.2.0 (25) | content matches |
| PasteInARow.app | 1.5.0 (24) | 1.5.0 (24) | content matches |
| PasteMatchStyle.app | 1.1.0 (13) | 1.1.0 (13) | content matches |
| PodiumAssist.app | 3.3.19 (84) | 3.3.19 (84) | content matches |
| PrefsPreset.app | 1.2.1 (27) | 1.2.1 (27) | content matches |
| ProjectFolder.app | 1.12.0 (28) | 1.12.0 (28) | content matches |
| QuickIconExporter.app | 1.2.0 (40) | 1.2.0 (40) | Applications: signature_invalid; content DIFFERS |
| SVGExporter.app | 1.2.4 (10) | 1.2.4 (10) | content matches |
| ScreenTake.app | 1.0.1 (2) | 1.0.1 (2) | content matches |
| SettingsCourier.app | 1.4.2 (13) | 1.4.2 (13) | Applications: signature_invalid; content DIFFERS |
| SettingsHop.app | 1.7.2 (23) | unknown (unknown) | Applications: executable_missing, signature_invalid; LatestBuilds: inspection_failed; content DIFFERS |
| ShotSorter.app | 1.0.1 (2) | unknown (unknown) | Applications: executable_missing, signature_invalid; LatestBuilds: inspection_failed; content DIFFERS |
| SiteMirror.app | 1.5.3 (16) | unknown (unknown) | Applications: executable_missing, signature_invalid; LatestBuilds: inspection_failed; content DIFFERS |
| SpreadsheetHelper.app | 1.5.0 (19) | 1.5.0 (19) | content matches |
| VectorKeys.app | 1.4.0 (6) | 1.4.0 (6) | content matches |
| VectorMaestro.app | 1.1.0 (2) | 1.1.0 (2) | content matches |
| VectorMate.app | 2.19.2 (81) | 2.19.2 (81) | Applications: signature_invalid; LatestBuilds: signature_invalid; content matches |
| YohakuTrimmer.app | 1.2.0 (13) | 1.2.0 (13) | content matches |
| note2markdown.app | 1.3.0 (14) | 1.3.0 (14) | content matches |

## Evidence and limits

- Missing executables in /Applications: ClipTidy, FileSorter, MenuShot, SettingsHop, ShotSorter, SiteMirror.
- Six apps have unsealed contents in bundle root: InsertSnippets, KakkoReplace, KeynoteMaestro, ListMatch, QuickIconExporter, SettingsCourier. Each has a same-name .app symlink pointing back to itself inside its bundle root. Creator remains unknown.
- MarkdownKitchen Latest Builds and VectorMate both copies fail sealed-resource verification in Sparkle Installer.xpc.
- SettingsHop, ShotSorter and SiteMirror changed presence in Latest Builds during inspection. Concurrent release/sync activity is possible; these are NOT verified recovery sources.
- 36 apps pass both signatures and content equality. 14 apps have installation anomalies. Signature validity does not establish notarization or runtime behavior.

## Development steps 1 and 2

- Canonical source: ~/Git/macos-apps. Existing tracked/staged changes and untracked files preserved under .local/release-backups/app-integrity-20261026. No legacy Dropbox source used.
- Initial GitHub main verified with ls-remote: a8baaf13d4e9cc1d52581b687775c04b23641eef. Individual public Release assets were not inspected.
- Added read-only reusable auditor and four passing tests for missing binaries, executable permission/content mismatch, absent app/invalid plist and signature errors.
- No product source or version/build changes. Audit-only work does not require a product version increment.
- Existing changes to deploy_both.py and Install Latest Apps.command belong to other work and are excluded.
- Repairs, product builds/localization checks, launch/reopen/quit/settings retention remain NOT PERFORMED. Existing concurrent release work must not be duplicated. Overall recovery is INCOMPLETE.
- No notarization, installation, or publication performed.
