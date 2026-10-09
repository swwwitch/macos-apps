# KakkoReplace App Store candidate

Build from sw_app: `python3 Shared/AppStandards/StoreManual/build.py KakkoReplace --build <unused-number>`

Current candidate: 1.0 (32), StoreBuild/KakkoReplace-build32.app. Ad-hoc sandbox signature only. Not ready for upload or final distribution.

Uses existing pure processing and preserves Bundle ID and direct distribution sources. No AppleEvents, Accessibility calls, global key interception or Sparkle.

Compile, signature verification and existing processing tests passed. Runtime UI/sandbox QA, localization extraction and release signing remain pending. See BASELINE-CHECKLIST.md.
