# Installation recovery - 2026-10-27

User explicitly authorized recovery and VectorMate normal quit/relaunch. Restored installed artifacts only; canonical source ~/Git/macos-apps was not replaced by legacy Dropbox source. No product source changes or new product builds.

## Verified results

- 15 affected apps recovered (initial 14 plus KeynoteSweeper, whose Dropbox copy changed to invalid build 15 during the operation).
- Final all-app audit: 50/50 managed apps have executables, pass deep/strict codesign validation and match content/modes/symlink targets between /Applications and Latest Builds.
- All 15 recovered apps opened from /Applications; open returned success and their executable processes were observed running. LaunchServices entries refreshed individually.
- SettingsCourier and QuickIconExporter stayed running. Six extra self-links were moved out of bundles after verified backups. No settings reset or forced termination.
- SettingsCourier content matched its healthy source but executable modes differed (0755 vs 0744); the healthy /Applications modes were preserved and mirrored to Latest Builds.
- SettingsHop, ShotSorter, SiteMirror, VectorMate and KeynoteSweeper restored from verified notarized DMGs with codesign, stapler and Gatekeeper success.
- MarkdownKitchen 1.47.3 (125) retained; its older broken Dropbox copy was replaced from the valid /Applications copy. No downgrade.

## Restored versions

| App | Version | Build | Launch |
| --- | --- | --- | --- |
| ClipTidy | 1.0.1 | 3 | confirmed |
| FileSorter | 1.0.1 | 2 | confirmed |
| MenuShot | 1.3.3 | 9 | confirmed |
| InsertSnippets | 1.11.2 | 28 | confirmed |
| KakkoReplace | 0.4.0 | 71 | confirmed |
| KeynoteMaestro | 1.2.2 | 30 | confirmed |
| ListMatch | 1.6.0 | 14 | confirmed |
| QuickIconExporter | 1.2.0 | 40 | confirmed |
| SettingsCourier | 1.4.2 | 13 | confirmed |
| MarkdownKitchen | 1.47.3 | 125 | confirmed |
| SettingsHop | 1.7.2 | 23 | confirmed |
| ShotSorter | 1.0.1 | 2 | confirmed |
| SiteMirror | 1.5.3 | 16 | confirmed |
| VectorMate | 2.19.2 | 81 | confirmed |
| KeynoteSweeper | 1.2.0 | 15 | confirmed |

## Evidence / limitations

- Workspace backups, removed links, settings snapshots, staged sources and JSON verification results: .local/app-recovery-20261027. Earlier dirty source snapshot: .local/release-backups/app-integrity-20261026. Original copies are retained in backups.
- Full pre/post audit JSON: .local/app-integrity-before-recovery-20261027.json and .local/app-integrity-after-recovery-20261027.json.
- No product version increment: existing validated versions/builds reused. KeynoteSweeper was aligned to already-distributed build 15 instead of reverting to build 14.
- Settings were not edited. Settings retention is limited to preserving user data and exporting available preference domains; individual settings UI/reopen/quit functionality and permission-dependent operations were not exhaustively tested.
- No new product tests/builds/localization checks, signing, notarization, release publication or note edits performed. Five DMG sources passed notarization verification; other apps only have the signature verification stated above.
- Dropbox had conflict copies of README and the version list, while the canonical version list was absent. Preserved conflict copies and restored the canonical list using its existing Unicode spelling, retaining history and adding a dated local verification table. Remote Mac and GitHub-public versions remain unverified.
- Root cause of disappearing executables, self-links and concurrent Dropbox changes remains undetermined. This is a verified local restoration, not proof that synchronization conflicts cannot recur.

Final audit time: 2026-10-27T00:06:57.391969+09:00
