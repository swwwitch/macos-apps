# Adobe Fonts activation prototype (2026-10-25)

Full edition only. Release target: 1.59.0 (93). See the verification record below for deployment status.

- Native descriptor enable/disable API; no file moves, cache extraction, or new registrations.
- Only registered fonts or unchanged files disabled by this app can be enabled.
- Locally disabled fonts retain their library IDs and set membership.
- Activation is verified using fresh name-and-file matching; file-descriptor enabled attributes remain stale and are not used as evidence.
- Installed-font removal remains prohibited. System fonts remain locked.

Validation: universal release compilation, ja/en localization checks, and the native API test passed. Fixtures/NMTProbe20261025.ttf is a newly generated two-glyph font, not a copy of a commercial font. Run tests with a separate executable/defaults domain; they register only this fixture for the session and unregister it on completion:

```sh
swiftc Sources/NotMyType/AdobeFontActivation.swift Tests/AdobeFontActivationTests.swift -o /private/tmp/nmt-adobe-tests
/private/tmp/nmt-adobe-tests "$PWD/Tests/Fixtures/NMTProbe20261025.ttf"
```

Actual Adobe integration remains unverified: Creative Cloud Desktop shows 2,526 added fonts but zero installed fonts. The Installed Fonts page describes these as fonts usable in non-Adobe desktop applications. CoreText outside the execution sandbox also reports zero Adobe font URLs (939 total). A user-selected font must first be installed through Creative Cloud before testing actual Adobe disable/re-enable and persistence across app/Creative Cloud restart. No real Adobe font state was changed during this work.

## Actual Adobe font verification (2026-10-25)

After the user installed fonts in Creative Cloud, CoreText exposed 30 Adobe font URLs (969 total). Tested AgencyFB-Thin (.r/.30682.otf) through the production AdobeFontActivation helper, compiled into a separate test executable with its own defaults domain. It started active (scope 2), became inactive (scope 0), remained inactive after 5 seconds, and became active again (scope 2). Fresh independent observer processes confirmed each state. Disabled-file tracking was true after disabling and cleared after re-enabling. Final cleanup confirmed the original active state. No font files were moved or deleted.

This verifies the activation helper on a real Adobe font, including a short Creative Cloud coexistence check. The shipped app has not been replaced. In-app checkbox/list behavior, application restart, Creative Cloud restart, and long-term synchronization remain unverified.

Release 1.59.0 (93): signed universal build and localization checks passed; /Applications and Latest Builds deployed with signature/content parity and backups. /Applications launch confirmed. UI checkbox verification timed out and remains unverified; no UI toggle was intentionally completed.
