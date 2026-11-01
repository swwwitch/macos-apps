# PodiumAssist 3.3.19 (97) — 2026-11-01

## Change

The advanced Zoom sheet can expose AX slider elements below the visible scroll area. Build 96 dragged those coordinates without checking clipping. Build 97 requests AXScrollToVisible, then uses bounded page scrolling until the entire slider is inside its containing scroll area. It resolves the thumb by AXValueIndicator role and rejects invalid geometry before mouse events. On failure the sheet is cancelled instead of accepting a partial change. After OK, both requested preferences must match within 0.05 before success is reported.

## Development verification

- macOS 26.7.1 (25G241): inspected the actual System Settings Zoom advanced sheet. On initial opening, the rapid zoom section was at the bottom and its slider tracks were below the viewport. Scrolling revealed both tracks. Cancelled without changes.
- Added regression checks for fully visible, below-viewport, partially clipped, above-viewport, zero-size and missing-viewport track geometry; existing automatic calculations include height 1080 -> 2.16 / 4.32. Tests passed using production ZoomSettings.swift and SystemSettingsSwitch.swift, with permission/localization/error stubs (permission always false; no system actions performed by tests).
- Isolated NO_DEPLOY=1 build passed; four-language validation passed; ad-hoc signature verified. Build 96 artifacts were not replaced.
- Launched validation build 97 and selected Zoom. Automatic setting displayed height 1080 -> maximum 4.32 / minimum 2.16. Clicking it stopped at the existing accessibility permission check. No permission switches were changed.
- Before/after preferences unchanged: closeViewFarPoint=1.890000348772321, closeViewNearPoint=3.780001395089286. No user zoom or other setting was intentionally changed.

## Still required on the authorized notarization Mac

Actual AX scrolling, thumb dragging, saved-value verification and failure cancellation must be tested with the existing signed-app permission on macOS 26.7.2. In particular repeat the reported unset closeViewFarPoint case, verify 2.16 / 4.32 at height 1080, then restore original settings. This development run does not establish that the reported failure is resolved on that Mac. Notarization, distribution and publication are owned by the requesting release chat and were not performed here.
