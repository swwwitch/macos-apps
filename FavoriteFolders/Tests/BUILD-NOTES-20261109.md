# FavoriteFolders 1.4.0 (16) verification — 2026-11-09 JST

- Development Mac: MacBook-Pro-14-2024-sw. Branch: codex/filesorter-screenshot-rename-20261101.
- Source changes: this commit. Build baseline: bf600cff5e46c90c100c6a60f87ccde5d9fdc3f5.
- Build: `./FavoriteFolders/build.sh` (no --deploy), arm64 / macOS 13+. Successful after allowing SwiftUI compiler plugin execution outside sandbox.
- Signature: existing team certificate, TeamIdentifier PL9S9PXX96; codesign --verify --deep --strict succeeded in build script. Not notarized.
- Tests: test.sh passed, including global usage ranking, stable ties/zero counts, separator omission, original category/order preservation, empty input, existing tests and four-language key/placeholder parity.
- GUI not exercised: global ranking/search/category-return clicks, live counter updates, settings initial/reopen/minimized restore, main/settings click switching. No always-on-top setting exists; both windows use normal level.
- No launch, deployment, DMG, publication or notarization performed. Existing workspace build backed up by build.sh.
- Pre-existing Shared/SettingsSync/SettingsSync.swift worktree changes were used by the validation build, preserved and not included in this commit. They add default-on explanation visibility; do not use this artifact as a release build. Rebuild from a fully committed source before release.
- Shared SettingsSync source SHA-256: 13c087659c52b8e72204da4919e9ff9e0a8a58dfe18081b7697a80670f022d2e
- Executable SHA-256: 2312969c2a38bb2754a763c874a1653a69954073950d3d05754cce3136862140
- Bundle manifest: BUILD16-MANIFEST.json; SHA-256: 2d8f79f3df34ddda14450afe92e58491dbe68ef950e455eef7f49897ccee8c1f
