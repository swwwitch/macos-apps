# PodiumAssist 3.3.19 (99) — 2026-11-01

The release Mac's build98 log established failure at reveal: AXScrollToVisible returned -25206; AXScrollDownByPage returned -25204. Slider and thumb roles/geometry were valid. Original values remained unchanged.

Build99 falls back to ordinary CGEvent pixel scrolling when AX page scrolling fails or reports success without moving the track. Events target the scroll area's left padding only while System Settings is frontmost. Each movement is bounded to 200 pixels, the viewport is re-read, the loop is bounded, and no dragging occurs before the full track is visible. The pointer is now restored even when reveal fails. Diagnostic scroll-wheel entries record delta, target point and pre-scroll track.

Tests include the actual report: track (1146,816.5,195,16), viewport (901,193,470,556) produces downward -200 pixel scroll; above-viewport produces +200; visible track produces none. Production-source calculation/geometry tests passed. Isolated NO_DEPLOY build, four-language checks and signature verification passed.

Validation build99 launched on the development Mac and displayed the new flat mustard/ivory/brown lectern icon. This incorporates the user's separate icon request, preserving color tone and using the reference composition without a glass finish. Master PNG, PNG, iconset and icns are synchronized; generation prompt is in Assets/PodiumAssist-icon-design.md.

Actual wheel scrolling and subsequent factor changes remain unverified on the authorized release Mac; development app lacks accessibility permission (as established with build98). No permission switches or zoom settings changed for this build. No notarization, deployment or publication performed. Re-test Auto Set on the release Mac and capture ~/Library/Logs/PodiumAssist/zoom-last.jsonl; restore initial settings after testing. Earlier numbered artifacts were not replaced.
