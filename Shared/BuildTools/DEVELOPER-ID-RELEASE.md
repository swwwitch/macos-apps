# 全アプリのDeveloper ID配布ビルド

2026-10-20の明示依頼に基づく配布処理。通常のbuild.shやApp Store経路の既定値は変更しない。

`build_all_notarized.py --output <新しい成果物フォルダ>` は各アプリの既存ビルド入口を実行する。今回の子プロセスだけPATHの先頭へcodesignラッパーを置き、指定のDeveloper ID証明書・Hardened Runtime・タイムスタンプで署名する。公開前はNO_DEPLOY=1。Sparkleを含め、Mach-O、XPC、ヘルパーアプリ、framework、外側のアプリの順で個別署名し、署名時に--deepは使わない。既存entitlementsを保ち、get-task-allowだけ除き、Apple Eventsを使うアプリには必要なentitlementを加える。テストを持つアプリはtest.shも実行する。

`notarize_staged_apps.py <成果物フォルダ> --profile swwwitch-notary` はビルド・既存テストの完了したものからZIPを提出する。指定されたnotaryプロファイルが存在しなかったため、ユーザーの明示承認によりswwwitch-notaryを使用。Acceptedのときだけアプリにstapleし、stapler validateとspctl -a -vvのNotarized Developer IDを確認。拒否された場合はsubmission IDを使ってnotarytool logを保存し、配布を止める。

`AppReleaseLifecycle.swift` を `/private/tmp/sw-app-release-lifecycle` へコンパイル後、`deploy_notarized_apps.py <成果物フォルダ>` を実行する。終了はNSRunningApplication.terminateによる通常終了のみ。拒否・タイムアウトでは置き換えず、強制終了しない。配置は従来のdeploy_both.pyでBundle ID・buildを照合し、両方の旧版をバックアップ。全ファイル・実行権限・symlink一致、公証チケット、Gatekeeperを再確認し、/Applications版を非アクティブで起動してプロセスを確認。以前起動していなかったアプリは確認後に通常終了する。

ログと結果はbuild-results.json、notary-results.json、deployment-results.jsonに保存する。ビルド失敗、テスト失敗、公証失敗、配置失敗、起動未確認を区別する。既存の全機能の実機操作・再ログイン・Intel実機の検証を代替するものではない。
