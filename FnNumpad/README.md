# FnNumpad

Fnキーを押しながら J・K・L などを押すと、テンキーのキーを入力するメニューバー常駐アプリ。Karabiner-Elements のルール「Fn+Number to KeyPad, Fn+[ / Y / H to Tab / Delete / Return」（numpad-v4.json）を単体アプリにしたもの。Fn＋, でカンマ、Fn＋Return でテンキーの Enter を加えた。

- 仕組み：アクセシビリティ権限で CGEventTap（セッション、先頭）を作り、Fn付きのキーダウンを新しいキーイベント（テンキーのフラグ付き）に置き換える。Karabiner-Elements のコードやドライバーは使っていない。
- 割り当て：Sources/KeyMap.swift。Tests/check_karabiner.py がルールファイルと突き合わせる。
- ビルド：`./build.sh`（`SKIP_PUBLISH=1` で配置しない）、テスト：`./test.sh`
