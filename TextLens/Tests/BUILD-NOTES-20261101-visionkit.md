# TextLens VisionKit比較・検証ビルド

- 2026-11-01 JST、開発Mac MacBook-Pro-14-2024-sw.local。
- 通常版1.1.0（2）、ブランチcodex/filesorter-screenshot-rename-20261101、基点133f695d09f15873261256cd0c51b7245d228e8d。対象SHAは本記録を含むVisionKit確定コミット。
- 公開SDK（VisionKit.swiftinterface）でImageAnalyzerのmacOS 13以降対応、Configuration.locales、ImageAnalysis.transcriptを確認。Quick Lookの非公開API・UI自動コピーは使用しない。
- 生成画像の内容：1行／1列目「日本語の縦組み認識」、2行／2列目「文字を正しく読み取る」。横組みは上下2行、縦組みは上→下・右→左の2列。HiraginoSans-W3 56pt、黒字・白地。Tests/Comparison.swiftから再生成可能。

| 検証 | 従来Vision VNRecognizeTextRequest | VisionKit ImageAnalyzer |
| --- | --- | --- |
| 横組み2行 | 全文・行順一致 | 全文・行順一致 |
| 縦組み2列 | 空文字 | 全文・右列→左列順一致 |

- 実際にアプリが呼ぶTextRecognizer.recognizeで比較、改行等の空白を除き期待文字列と完全一致することをassert。ImageAnalyzer非対応の環境では従来Visionにフォールバックし、縦組みテストはSKIPと明示する。対応環境でのエラーを黙って旧方式に切り替えない。
- zsh TextLens/test.sh：整形・4言語78キー／プレースホルダー・ヘルプ・英文画像認識／原本バイト一致／不正画像・日文横組み／縦組み比較PASS。
- NO_DEPLOY=1 zsh TextLens/build.sh：PASS。証明書署名TeamIdentifier PL9S9PXX96、deep/strict PASS。成果物TextLens/build/TextLens.app。
- マニフェスト：BUILD-MANIFEST-20261101-2.txt。相対パス・権限・SHA-256・シンボリックリンク先を記録。
- 範囲選択と画像ドロップ双方の認識経路をVisionKitへ変更。初期ホットキーや保存済み設定は変更しない。共有設定のキーも維持。4言語ヘルプ・履歴・チェックリストを更新。
- 限界：実際のQuick Look出力との同一画像比較、利用者のスクリーンショット、ルビ・縦中横・句読点位置・複雑な段組み、非対応ハードウェア上のフォールバック、権限とアプリGUIでの認識実行は未確認。生成2列画像の成功をすべての縦組みへの保証とはしない。
- 公証・DMG・/Applications・Latest Builds配置・GitHub Release・note公開は未実施。開発Macから配布先へ書込なし。
