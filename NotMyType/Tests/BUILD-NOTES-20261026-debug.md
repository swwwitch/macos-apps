# Debug menu and sidebar follow-up (2026-10-26)

- User authorized build in thread 01a17147-6826-7911-8e42-cc45a77f2daf.
- Full edition: Tools > Debug opens Adobe Fonts, OH MY FONT, Fontworks LETS, and Morisawa Fonts folders in Finder. User folders resolve against the current home directory; missing folders show an alert without creating anything. Fontworks link renamed and changed to https://lets.fontworks.co.jp/fonts.
- Both editions: All Fonts remains visible and selectable when Library is collapsed. Existing sidebarExpanded.library preference retained; other sections unchanged.
- Japanese/English strings and help updated. Both localization checks pass. Both arm64 and x86_64 compilations pass through the existing NO_DEPLOY build route. Icon packaging initially failed under restricted execution; the existing icon packaging and signing steps then succeeded with normal tool access. Both app bundles pass codesign --verify --deep --strict with the existing local Apple Distribution identity (not Developer ID notarization).
- Existing make-strings.py has pre-existing missing/unused translation-table entries. New keys were added consistently to translations.tsv and both Localizable.strings files; unrelated translations were preserved.
- Full 97 / Lite 22 version bumps and cache dialog changes are owned by the notarization Mac release thread 01a16bb3-a7cc-76c1-b27f-c7ab19a4f8da. This changeset deliberately does not bump versions or deploy a parallel release.
- Pending integrated runtime checks: collapse/re-expand Library and select All Fonts in both editions; verify all four Debug destinations and missing-folder alerts in full; confirm no Debug menu or changed LETS web link in Lite. Notarization and deployment are not established by compilation.
