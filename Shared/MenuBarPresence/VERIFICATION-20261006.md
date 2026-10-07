# 検証記録（2026-10-06）

## ビルドと配置

全8アプリの既存ビルド経路で成功。既存Bundle IDを確認し、Applications版をShared/BuildBackupsへバックアップして更新した。/ApplicationsとLatest Buildsのバージョン・build・署名検証・ファイルマニフェストの一致を確認。

| アプリ | バージョン | build | /Applicationsからの画面確認 |
| --- | --- | --- | --- |
| MightyEdit | 0.1.30 | 33 | パレット、アイコンのみ・テキストのみの1列表示 |
| BrowserSwitcher | 1.6.10 | 25 | ブラウザー一覧 |
| ExtLink | 0.2.11 | 20 | 拡張子一覧 |
| FolderHopper | 0.1.65 | 74 | 移動先一覧 |
| KageTrimmer | 1.0 | 31 | 影の調整画面 |
| QuickIconExporter | 1.0 | 9 | 書き出し画面 |
| PodiumFlight | 3.2.3 | 21 | 初回メニューバー追加案内 |
| CommandDee | 1.7.0 | 16 | 環境設定、共通メニューバー設定 |

## 自動検証

- 共有コンポーネントのON/OFF設定復元、statusItem.isVisible、テンプレート画像、繰り返しinstall時のメニュー重複防止をAppKitプローブで確認。
- MightyEditのグリッド配置テスト：1・2・3・4・7列、ボタン高44・48・74、非表示後の復元を確認。
- 全ターゲットの共有ソース同期を確認。

## 実機確認と制限

CommandDeeのアプリメニューから「メニューバー設定…」が開き、「起動・常駐」「メニューバーに追加」が表示されることを確認。PodiumFlightで初回案内の3択を確認。MightyEditで選択保存キーを確認。

全8アプリそれぞれの設定ON/OFF操作、ログイン時起動、再ログイン、実機上の全機能実行は今回未確認。CommandDeeは環境設定にアクセシビリティ「未許可」と表示されており、機能実行の確認は含まない。ユーザーのファイル操作・変換処理は実行していない。

今回の配置はローカル更新。Developer ID署名・公証・GitHub/noteへの公開を確認したものではない。
