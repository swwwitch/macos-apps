# FnNumpad

Fnキーを押しながら J・K・L などを押すと、テンキーのキーを入力するメニューバー常駐アプリ。Karabiner-Elements のルール「Fn+Number to KeyPad, Fn+[ / Y / H to Tab / Delete / Return」（numpad-v4.json）を単体アプリにしたもの。Fn＋, でカンマ、Fn＋Tab でテンキーの =、Fn＋Return でテンキーの Enter を加えた。

- 仕組み：アクセシビリティ権限で CGEventTap（セッション、先頭）を作り、Fn付きのキーダウンを新しいキーイベント（テンキーのフラグ付き）に置き換える。Karabiner-Elements のコードやドライバーは使っていない。
- 割り当て：Sources/KeyMap.swift。Tests/check_karabiner.py がルールファイルと突き合わせる。
- ビルド：`./build.sh`（`SKIP_PUBLISH=1` で配置しない）、テスト：`./test.sh`

## 配布版

- バージョン：1.0.0（build 2）
- ビルド更新日時：2026年10月21日 12:00:30（日本時間）
- macOS 13以降・Appleシリコン対応。Developer ID署名・Apple公証済み。
- [紹介とダウンロード（note）](https://note.com/swwwitch/n/n415171ce5e04)
- Fn＋Tabでテンキーの「＝」を入力。

App Store版は未申請。現行の他アプリへのキー置換とApp Sandboxの互換性を解決できておらず、入力方式を変えると用途が大きく変わるため、App Store向け再設計は見送った。通常配布版は継続する。

## 2026-10-25 Dock非表示時のメニュー修正（1.0.0 build 5）

メイン・設定ウインドウがある間はアプリメニューを使用でき、最小化中もDock・⌘Tabに残ります。最後の対象ウインドウを閉じると再び隠し、非アクティブパレットと保存済みの設定値を保持します。

Developer ID署名・アプリ/DMG公証Accepted。両配置先の内容・署名・公証チケットと、/Applications版の起動を確認。 各アプリの画面操作と実ログインの確認範囲は別途配布記録に記載。
