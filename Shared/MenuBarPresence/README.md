# 共通メニューバー機能

8アプリ共通の初回案内・表示設定・テンプレートアイコンを管理する。各ターゲットのMenuBarPresence.swiftはsync.pyで同期する。ビルド前に同期し、ここを正本として編集する。

- 初回案内：「メニューバーに追加」「追加しない」「あとで」。選択はBundle IDごとに保存。
- 既存のメニューバー項目があるアプリはその項目を再利用。未選択の間は従来の表示を維持する。
- 新設するアプリは選択前に常駐アイコンを勝手に追加しない。
- 後からアプリメニューの「メニューバー設定…」で変更できる。OFFはアイコン非表示であり、アプリ終了やログイン設定変更ではない。
- モノクロ画像はNSImage.isTemplate=true。ライト／ダーク表示の描画はmacOSに任せる。
- PodiumFlightの既存のタイマー表示は保持する。
- ステータスメニューの既存機能、機能ホットキー、ユーザー設定を置換しない。
- 日本語・英語・簡体字中国語・韓国語の共通ラベルを同梱。

対象：MightyEdit、BrowserSwitcher、ExtensionLinker、FolderHopper、KageTrimmer、QuickIconExporter、PodiumFlight、CommandDee。
