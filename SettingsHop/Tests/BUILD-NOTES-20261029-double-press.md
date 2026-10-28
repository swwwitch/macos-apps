# SettingsHop 1.8.0 (24) 検証ビルド — 2026-10-29

- 実行Mac: MacBookPro13-M5-2025.local（公証Mac）。ブランチ: codex/settingshop-double-press。
- ビルド対象SHA: `0ce65a5415cb219e0f6f35313c2747517b0ff699`（GitHub mainへpush済み）。ソース変更を確定後、NO_DEPLOY=1でビルド。
- 自動テスト: PASS（既存Pane/Layout/URL、2回押しの境界・超過・3回目、4言語のキー/ヘルプ整合）。初回sandboxではLaunch Services参照が失敗し、通常権限で再実行して合格。
- ビルド・署名: 成功。Developer ID Application: masahiro takano (PL9S9PXX96)、Hardened Runtime、タイムスタンプ、内側から署名しcodesign --deep --strict検証。
- 成果物: 正本 `.local/settingshop-doublepress-20261029/source/SettingsHop/build/SettingsHop.app`。
- 実行ファイルSHA-256: `539f50b972483c334c25052f7b2cab957d969f778f3128117f32224b567bce03`。
- GUI: 検証成果物を起動し1.8.0 (24)のメイン画面を確認。旧版はメニューから通常終了。起動前後のユーザー設定差分なし。
- 実キー確認（2026-10-29、ユーザー回答「3項目とも正常」）: ⌃⌥Qの1回でメイン表示、すばやく2回でメインを閉じてシステム設定、押しっぱなしで2回扱いにならない、の3項目を確認済み。ホットキーによるメイン再表示も確認済み。
- 公証・DMG・/ApplicationsとLatest Buildsへの配置・GitHub Release・note・Store提出: 未実施（今回の実装・検証・ビルド範囲外）。
- 保全: 正本 `.local/settingshop-doublepress-20261029/local-work-before.tar.gz`。無関係な作業は保持。
