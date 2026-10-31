# VectorKeys 1.13.0（22）検証用

- 2026-10-31 JST、開発Mac MacBook-Pro-14-2024-sw.local、main、基点37e6f72。対象SHAは本記録を含む確定コミット。
- ウォッチフォルダー設定にサブディレクトリの自動グループ化（初期OFF）を追加。階層を親/子のカテゴリ名として作成。同じ相対階層は同じカテゴリ。空フォルダーも対象。新規・未分類の単一ファイル項目のみ自動配属し、既存の分類・手動設定は保持。
- 除外フォルダー名を改行区切りで編集・保存。初期single-function／backup。任意の深さで大文字小文字を区別せず完全一致するディレクトリと配下を、走査・タグ取り込み・カテゴリ作成から除外。登録済み項目を自動削除しない。
- 設定はMac固有のUserDefaults（watchAutoGroup／watchExcludedNames）。変更時は走査世代を更新し、古い結果を適用しない。設定共有の対象外。
- test.sh PASS：既存単体・Runner・4言語キー／プレースホルダー・ヘルプ。新規テスト：深い階層のBACKUP除外、除外先のカテゴリ非作成、階層カテゴリ作成、既存手動分類保持、初期OFF。
- 実機UI・再起動後の設定復元・15秒監視でのカテゴリ追加は未確認。公証・配布先配置・公開は未実施。

- NO_DEPLOYビルド・Apple Distribution署名（PL9S9PXX96）・codesign deep/strict検証PASS。成果物VectorKeys/build/VectorKeys.app。マニフェストSHA-256：`e40c8dd98d40901310fd07192b0c6a106b07afe528ecf17447e37f4f2ca1e08c`。
