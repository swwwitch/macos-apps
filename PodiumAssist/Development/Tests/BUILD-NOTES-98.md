# PodiumAssist 3.3.19 (98) — 2026-11-01

Build 97 still failed on the notarization Mac; visibility alone is not an established root cause.

Build 98 resolves an identifier-bearing container to a descendant AXSlider and finds AXValueIndicator through nested children (bounded traversal). Invalid AX geometry types are rejected. Failures distinguish slider-role, value-range, scroll-area-frame, reveal, knob-geometry and drag-result.

Each apply replaces ~/Library/Logs/PodiumAssist/zoom-last.jsonl. Capture this file immediately after the failed Auto Set, before another Zoom operation. JSONL records include identified and resolved control metadata (roles, IDs, values, min/max, enabled, frames, supported actions), scroll-to-visible result, scroll-area lookup/viewport, page-scroll result, thumb tree, drag coordinates and before/after value, cancel action result and saved preferences. Nested metadata is stringified within JSON fields. It does not collect window titles or unrelated app content.

Development validation on macOS 26.7.1:
- Production-source automatic factor and slider viewport geometry regression tests passed.
- Isolated NO_DEPLOY build, four-language checks and ad-hoc signature verification passed.
- Validation app 98 launched; Auto Set recorded begin with minimum 2.16/maximum 4.32, then stopped at the existing accessibility permission check. No permission toggles changed.
- Settings unchanged: minimum 1.890000348772321, maximum 3.780001395089286.

Unverified: descendant resolution, scrolling, dragging, save verification and cancellation with real authorized access on macOS 26.7.2. This is a diagnostic/candidate correction, not a confirmed fix. Reproduce the initial min=1 (unset preference), max=2.44421875 case on the notarization Mac and capture the diagnostic file. Restore user settings after testing. No notarization, deployment or publication performed here; build 97 artifacts unchanged.
