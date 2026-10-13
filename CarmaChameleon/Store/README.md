# CarmaChameleon Store構成

APP_STORE_BUILD=1 CARMACHAMELEON_STORE_QA=1 zsh build.sh でStoreBuild/CarmaChameleon.appを作成する。通常のbuild/とLatest Buildsは更新しない。

- pandoc 3.12とTypst 0.15.1をバンドル内からのみ実行する。ダウンロード、ユーザー指定実行パス、Homebrew、外部TeXはStoreビルドから除外。
- Typst取得の再現手順：python3 Store/fetch-typst.py。公式リリースのSHA-256を検証し、ライセンス・NOTICEも同梱する。
- 親はApp Sandbox・ユーザー選択read/write・app-scope bookmarks。補助実行ファイルはSandbox inherit。temporary-exceptionは付けない。
- 変換直前に入力元・出力先をOpenPanelで明示的に許可し、bookmarkを保存する。取消では変換を開始しない。
- Typst root=/はpandocが抽出した画像の絶対パスを正しく解釈するため。OSのSandbox権限を増やさない。

QA用はDeveloper IDで署名する。正式配布はQAフラグを外し、CARMACHAMELEON_STORE_PROFILEにCarmaChameleon専用profileを指定する。Bundle ID・チーム・有効期限を検査し、profileなしでは配布ビルドを止める。StoreBuildのQA成果物を通常配布・提出用と扱わない。

未完了：外部アプリ連携（Keynote、Illustrator、Photoshop、InDesign）のSandbox適合、失効したbookmarkの実機試験、正式配布profile・Installer署名・提出用バージョン、実機動画。外部連携機能は無断で削除していない。Intel版エンジンは同梱しておらずarm64のみ。
