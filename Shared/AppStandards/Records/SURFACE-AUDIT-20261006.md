# 共通グレー背景とタイトルバー

- 対象：BrowserSwitcher、CommandDee、ExtLink、FolderHopper、KageTrimmer、QuickIconExporter、PodiumFlight、MightyEdit、SuperKakkoReplace。
- 共通部品：AppSurface.swift。各ビルドからsync-surface.pyで同一ソースを同期。明色#ECECEC、暗色はsRGB 0.16。
- メインのコンテンツ見出しと本文に同色を使用。タイトルバーのボタン操作・スタイルは変更しない。メイン画面のタイトル文字は空、または非表示。設定画面・ヘルプ等の用途名は今回の主画面改修範囲外。
- SwiftUIでは背景のsafe-area拡張を無効化し、ネイティブタイトルバーに広げない。

## 検証を分離した記録

- ソース：9本の適用位置を確認。設定値を変更するコードは追加していない。
- ビルド：9本成功。MightyEditは既存の証明書で署名（制限外のキーチェーン参照が必要）。
- 配布：SURFACE-DEPLOY-20261006.txtおよびSURFACE-DEPLOY-SWIFTUI-20261006.txt参照。Bundle ID照合、旧版バックアップ、署名、全内容一致を確認。
- 実画面：KageTrimmerとMightyEditでグレーの見出し・本文、色を変更しないタイトルバー、メイン画面名の非表示を確認。
- ExtLink：グレー表示と空タイトルを目視。safe-area拡張抑制の最終修正版は再確認待ち。
- CommandDee：起動・設定画面を確認。主画面の確認は未完了。
- BrowserSwitcherとQuickIconExporter：UIツールでRunning application not found。起動確認未完了。
- FolderHopper、PodiumFlight、SuperKakkoReplace：更新後の実画面は未確認。
- 自動テスト：色・見出しのみの変更につき機能テストは未実施。ダークモードの実画面も未確認。
- UI取得で最大約12分の待機が発生し、全アプリの最終実機確認は未完了。
