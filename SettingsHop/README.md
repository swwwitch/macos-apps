# SettingsHop

システム設定のよく使う画面を、ボタン1つで直接開くAppKit/SwiftUIアプリ。Apple Silicon / macOS 13以降。

開ける画面（⌘1〜⌘9。プライバシーとセキュリティ・入力監視・オートメーションはキーなし）：

- システム設定（アプリを開くだけ。開いていれば最後の画面のまま前面へ）
- プライバシーとセキュリティ
  - アクセシビリティ
  - フルディスクアクセス
  - ファイルとフォルダ
  - 画面収録とシステムオーディオ録音
  - 入力監視
  - オートメーション
- ログイン項目（一般＞ログイン項目と機能拡張）
- デフォルトのWebブラウザ（デスクトップとDockを開き、アクセシビリティが許可されていればその行までスクロール）
- キーボードショートカット（キーボードの「キーボードショートカット…」シート）
- AirDropおよび連係（`com.apple.AirDrop-Handoff-Settings.extension`）

⌃⌥Q（設定で変更・無効化できる。起動中だけ有効、Carbonの RegisterEventHotKey）でどのアプリからでもメインウインドウを呼び出せる。メインウインドウのボタン、［ファイル］メニュー（⌘1〜⌘9）、メニューバーのアイコンのメニュー（表示を選んだとき）から開ける。設定の「一般」で「項目を開いたらウインドウを閉じる」を選べる（初期値オフ、メニューバーから開いたときは対象外）。

## しくみ

- システム設定の画面は `x-apple.systempreferences:` のURLを `NSWorkspace.open` で開く。
  - プライバシーとセキュリティ：`com.apple.settings.PrivacySecurity.extension`
  - 下位の画面：`com.apple.preference.security?Privacy_Accessibility`／`Privacy_AllFiles`／`Privacy_FilesAndFolders`／`Privacy_ScreenCapture`
- ログイン項目：`com.apple.LoginItems-Settings.extension`
- デフォルトのWebブラウザ：`com.apple.Desktop-Settings.extension`。アンカー（`?Browser`・`?defaultWebBrowser`・`?default-web-browser`）は試したが行までスクロールしない（macOS 26）
- キーボードショートカット：`com.apple.Keyboard-Settings.extension?Shortcuts`（シートが開く。左の一覧は前回の項目）
- 「システム設定」だけはBundle ID `com.apple.systempreferences` のアプリを開く。
- 「デフォルトのWebブラウザ」は開いたあと、アクセシビリティAPIで行のポップアップにフォーカスを当ててスクロールさせ、AXPressでメニューを開く（`Source/RowLocator.swift`。AXScrollToVisibleは成功を返すが動かない。表示名はDesktopSettings.appexのLocalizable.loctableから全言語を読む）。
- Option＋クリック（アクセシビリティ・フルディスクアクセス・画面収録・入力監視）は、直前に前面だったアプリの行を共通部品 `AccessibilitySettingsLocator.open(names:paneURL:)` で選ぶ（AXSelected。許可スイッチは触らない）。
- 権限はこの2つにだけ使い、無ければ画面を開くだけ。設定の値は読み書きしない。外部通信なし（更新確認を除く。配信先は未設定）。

## ビルド・テスト

```
./test.sh            # URL・⌘キー・SF Symbolsの単体テスト＋4言語の翻訳キー・プレースホルダー検証
./build.sh           # build/SettingsHop.app
./build.sh --deploy  # 検証後、/Applications と Latest Builds へ配置（Shared/BuildTools/publish_latest.py）
```

## ファイル

- `Source/Panes.swift`：開く画面の一覧（URL・アイコン・⌘キー）と開く処理
- `Source/main.swift`：主画面・設定・メニュー
- `make-resources.py` / `help_text.py`：4言語の文字列とヘルプを生成
- `Assets/GenerateIcon.swift`：アイコン（マスタード基調、歯車と跳ぶ矢印）

## 更新履歴

### 1.3.1（build 14、2026-10-26）

- 「デフォルトのWebブラウザ」でスクロールしたあと、ブラウザを選ぶポップアップのメニューを開く（AXPress。スペースバーと同じ）。

### 1.3.0（build 13、2026-10-26）

- 「デフォルトのWebブラウザ」を開いたあと、その行までスクロール（アクセシビリティの許可が必要。設定の［起動・常駐］に許可の欄を追加）。
- アクセシビリティ・フルディスクアクセス・画面収録をOption＋クリックすると、直前に使っていたアプリの行を選んで開く。
- メインウインドウで↑↓キーで項目を選び、Returnで開けるようにした。
- メインウインドウが前面のときは数字キー1〜9だけでも開ける（行の表示も「1」〜「9」に。メニューは⌘1〜⌘9のまま）。
- Option＋クリックと同じ操作をキーでも：⌥＋数字（ウインドウ前面時）、⌘⌥＋数字（［ファイル］メニューの代替項目。Optionを押すと項目名が「（直前のアプリを選択）」に変わる）。
- 待機中の「開く項目をクリックしてください。」を削除（開いた結果・失敗の理由は従来どおり下に表示）。
- メインウインドウの右下に「直前のアプリ」（Option＋クリックで選ばれるアプリ）をアイコン付きで表示。
- 「入力監視」「オートメーション」「AirDropおよび連係」を追加。
- ⌘キーを表示順に⌘1〜⌘9で振り直した。プライバシーとセキュリティ・入力監視・オートメーションにはキーを付けない。

### 1.2.0（build 5、2026-10-26）

- 一番下に「ログイン項目」（一般＞ログイン項目と機能拡張、⌘7）、「デフォルトのWebブラウザ」（デスクトップとDock、⌘8）、「キーボードショートカット」（⌘9）を追加。

### 1.1.0（build 2、2026-10-26）

- アプリを呼び出すホットキー（初期値 ⌃⌥Q）を追加。設定の［起動・常駐］で変更・無効化できる。

### 1.0.0（build 1、2026-10-26）

- 最初の版。
