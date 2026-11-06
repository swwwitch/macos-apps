# TermTally 1.2.0（4）Acrobat検証 — 2026-11-07

- 開発Mac：MacBook-Pro-14-2024-sw.local。ブランチcodex/filesorter-screenshot-rename-20261101。基点cd061f2b。対象SHAは本記録を含むコミット。
- AcrobatのAXDocument属性で現在のローカルPDFを取得。PDFKitで保存済みの全ページを抽出。未保存変更・画像文字・OCR・Acrobat内の位置選択は対象外と明示。ページ番号はPDFの物理ページ（1始まり）。PDF内部の文字順と画面上の読み順は一致を保証しない。
- 元のPDFに書き込む経路なし。isPDF/resultsArePDFで置換・選択取り込みを無効化。Acrobatターゲットのreplaceも変更せず終了。対象URL変更時は読み取りを拒否。
- test.sh PASS：検索・辞書、4言語キー・プレースホルダー・ヘルプ、UTF-16ページ範囲・空ページ・ファイル不存在。実PDF126ページ、文字未抽出8ページ、UTF16 17511文字を確認し、抽出前後のファイル全バイト一致。
- NO_DEPLOY=1 build.sh：コンパイル・証明書署名・deep/strict検証成功。既存のSwift 6移行関連等の警告あり。
- CUA：workspace版1.2.0（4）起動。Acrobatを前面化後に対象PDFを認識。「揺れ候補を拾う」で41組と先頭候補の自動選択、ページ115の該当箇所、126ページ/未抽出8ページの案内を確認。該当行を選択しても個別置換欄・置換・すべてを統一・表示は無効。
- クリックのみでは該当行選択の変化なし。アウトラインへフォーカス後Downで行選択を確認。マウス選択の既存挙動は別の確認項目。
- Reader版・ロック/コピー禁止PDF・クラウドのみの文書・未保存PDF・画像だけのPDF・タブ切替/ピン固定の実機試験は未実施。各エラー分岐を実装済み。画像混在ページは画像部分を抽出できないことを常時表示。
- 他作業の未コミットShared/SettingsSync/SettingsSync.swift（showsNotes既定true）を参照。未変更・commit対象外。配布前は共通部品を含む確定ソースで再ビルド。
- 原本変更・公証・/Applications配置・Latest Builds配置・公開なし。旧検証版はBackupsへ保全。
- 参考：Apple PDFDocument.allowsCopying https://developer.apple.com/documentation/pdfkit/pdfdocument/allowscopying
