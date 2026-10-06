# App Store公開準備（2026-10-06）

## 準備済み

- Bundle ID `local.takano.FolderMover`、version 1.0.0 / build 6を保持。カテゴリUtilities。
- `APP_STORE_BUILD=1 ./build.sh` で `StoreBuild/FolderMover.app` に別途生成。通常版やLatest Buildsへは自動配置しない。
- App Sandbox、ユーザーが選択したフォルダーへの読み書き、app-scoped bookmarksのentitlements。
- FolderHopperのFolderAccess実装を流用。選択・ドロップ時にブックマーク保存、次回起動時の復元、実行前の再許可。許可範囲外のパスだけでは実行しない。
- Store構成から独自更新メニューを除外。PrivacyInfo.xcprivacyにUserDefaultsの用途CA92.1、データ収集なし／追跡なしを記載。
- 通常版・Store構成ともコンパイル、ad-hoc署名とstrict検証成功。4言語リソース。
- 申請文面はmetadata-ja.md。プライバシー説明はprivacy.md。

## 実機確認

Sandbox候補を実行パスで確認し、Openパネルで選択した一時フォルダー間のテキスト1件をmvで移動できました。正常終了・再起動後は再選択なしで別の1件を移動でき、ディスク上の内容も一致しました。これは同一ボリュームでの基本検証です。

## 提出前に必要

- Sandbox実機で権限失効、ドロップ、同名スキップ、停止、大量移動を追加検証。通常版の17テストはStore版実機検証の代わりにはならない。
- Apple公式資料では子プロセスのSandbox継承と、動的に与えたPowerBoxアクセスを区別している。`/bin/mv`による選択フォルダーへの移動はStore構成で確認が必要。失敗する場合、専用helper/XPCでbookmarkを解決する構成等を検討し、基本動作を変えずに解決する。Sandbox例外の無制限追加はしない。
- 有効なApple Distribution IDは実機Keychainで1件確認。当該Bundle IDのApp Store配布プロファイル、Installer Distribution ID、App Store Connect上の未使用build番号を揃える。既存の別アプリ用profileを流用しない。
- Shared/TestFlight/package.pyの検査付きPKG生成経路を使用。証明書／鍵の作成、App Store Connect変更、アップロード、審査提出は未実施。
- ヘルプ／アプリ情報のサポート先を公開URLへ更新し、Store版では履歴のコンテナ内保存先とApp Store経由の更新を説明する。直接配布版向けの公証／更新未設定の説明をStoreヘルプから除く。
- 個人パスのないStore用スクリーンショットを規定寸法で用意。現状のDocs/main.pngは通常版のテスト画面であり申請済み素材ではない。
- 価格、配信地域、著作権者、審査連絡先、年齢区分、輸出コンプライアンス、公開タイミングをApp Store Connectで確定。名称の利用可否も未確認。
- プライバシー／サポートURLを公開・確認して入力。TestFlight経由のインストール、別ボリューム、失敗時復旧と設定移行を検証してから提出。

## 公式資料

- [App Review Guidelines 2.4.5](https://developer.apple.com/app-store/review/guidelines/)
- [Sandboxと継承](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html)
- [選択フォルダーへのアクセス](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- [Required Reason API](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
