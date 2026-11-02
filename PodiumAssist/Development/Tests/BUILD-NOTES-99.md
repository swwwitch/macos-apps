# PodiumAssist 3.3.19 (99) — 2026-11-01

The release Mac's build98 log established failure at reveal: AXScrollToVisible returned -25206; AXScrollDownByPage returned -25204. Slider and thumb roles/geometry were valid. Original values remained unchanged.

Build99 falls back to ordinary CGEvent pixel scrolling when AX page scrolling fails or reports success without moving the track. Events target the scroll area's left padding only while System Settings is frontmost. Each movement is bounded to 200 pixels, the viewport is re-read, the loop is bounded, and no dragging occurs before the full track is visible. The pointer is now restored even when reveal fails. Diagnostic scroll-wheel entries record delta, target point and pre-scroll track.

Tests include the actual report: track (1146,816.5,195,16), viewport (901,193,470,556) produces downward -200 pixel scroll; above-viewport produces +200; visible track produces none. Production-source calculation/geometry tests passed. Isolated NO_DEPLOY build, four-language checks and signature verification passed.

Validation build99 launched on the development Mac and displayed the new flat mustard/ivory/brown lectern icon. This incorporates the user's separate icon request, preserving color tone and using the reference composition without a glass finish. Master PNG, PNG, iconset and icns are synchronized; generation prompt is in Assets/PodiumAssist-icon-design.md.

Actual wheel scrolling and subsequent factor changes remain unverified on the authorized release Mac; development app lacks accessibility permission (as established with build98). No permission switches or zoom settings changed for this build. No notarization, deployment or publication performed. Re-test Auto Set on the release Mac and capture ~/Library/Logs/PodiumAssist/zoom-last.jsonl; restore initial settings after testing. Earlier numbered artifacts were not replaced.

## 2026-11-02 — 開発Macでの配布版「自動設定」実機確認

- 対象Mac：MacBook-Pro-14-2024-sw。対象アプリ：`/Applications/PodiumAssist.app`、3.3.19（99）。対象ソース：`5082c0695e8b7ff054bb3205be0401fdba1e982f`。
- インストール済みアプリのDeveloper ID署名、stapled notarization ticket、codesign deep/strict検証、Gatekeeperのacceptedを確認。起動中の検証版98を終了し、配布版99の起動・画面上の版番号を確認した。
- 初回の「自動設定」はアクセシビリティ未許可のため停止し、倍率は変更されなかった。ユーザーが手動で許可した後に再実行した。許可スイッチはエージェントでは変更していない。
- 変更前：最大3.780001395089286、最小1.890000348772321（表示3.78／1.89）。画面の論理高さ1080から、最小1080÷500＝2.16、最大2.16×2＝4.32を算出。
- 実行ログではAXScrollToVisibleが-25206、AXScrollDownByPageが-25204となった後、scroll-wheelのdelta -200によるフォールバックを記録。続いて両スライダーのafter-dragとsaved-valuesを確認した。
- 2026-11-02 11:40:10 JST（ログ02:40:10Z）のsaved-values：最大4.320005580357143、最小2.1600024414062498。アプリ画面も最大4.32／最小2.16となり、処理中表示が解除された。計算値との微小差は約0.000006以内。自動設定による反映・保存を確認できた。
- 実行ログ：`~/Library/Logs/PodiumAssist/zoom-last.jsonl`（次回実行で上書きされる）。上記の値と時刻を本記録に転記した。
- 検証後は最大4.32／最小2.16を保持し、元の倍率には戻していない。プリセットへの保存は実行していない。今回の範囲は自動設定の倍率反映・保存までで、実際の画面ズーム操作、再起動後の保持、他ディスプレイでの挙動は未確認。
- 今回は検証記録のみの変更。ソース修正、再ビルド、再公証、再公開は行っていない。上記の初回ビルド時の未検証記述は当時の履歴として保持する。
