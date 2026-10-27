# VectorKeys 1.5.1（8）設定の共有・開発検証

- 担当：開発Mac MacBook-Pro-14-2024-sw.local、main。2026-10-27 JST。基点a4608b8。対象SHAは本記録を含む確定コミット。
- SettingsSharingViewを「情報」の前に追加。共通SettingsSyncでhotkeysEnabled/showUses/sortOrderを書き出し・読み込み・同期。受信後はモデルの有効状態とキー登録を更新し、表示設定はAppStorageへ反映。
- スクリプト一覧・実ファイル・項目別ホットキー・パス・起動と常駐・呼び出しキー・ウインドウ位置は共有対象外。既存Scripts.jsonには書き込まない。4言語の画面説明とヘルプを追加。
- VectorKeys/test.sh：単体・旧データ互換・Runner事前拒否・4言語キー/プレースホルダー整合・ヘルプPASS。
- Shared/SettingsSync/test.sh：ジャーナル単体と実コントローラー統合PASS（独立変更・競合・削除・再起動・I/O失敗・受信再送防止・古い結果の取消）。テスト専用の設定領域と一時ファイルで実行。
- NO_DEPLOY=1 ./build.sh：既存署名経路で成功。build/VectorKeys.app、1.5.1/8。codesign --verify --deep --strict成功。
- 最初の制限内コンパイルはSwiftUIマクロ補助起動失敗。制限外の既存ビルド経路で再実行成功。共通StartupWindowの未使用変数警告は既存。
- 未確認：設定タブの実画面、手動の書き出し・読み込み、別Macでの同期、実キー入力とIllustrator実行。Developer ID公証・配布・公開は未実施。
- この開発Macの/Applications版はbuild 6。公証Macでの1.5.0/7配置記録と混同しない。配布先・既存アプリ・ユーザー設定は変更していない。
