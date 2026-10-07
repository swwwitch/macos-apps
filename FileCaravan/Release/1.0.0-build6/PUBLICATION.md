# 公開・検証記録

- note: https://note.com/swwwitch/n/n3b88097a8bf4
- GitHub: https://github.com/swwwitch/macos-apps/tree/main/FolderMover
- Release: https://github.com/swwwitch/macos-apps/releases/tag/FolderMover-v1.0.0-build6
- note添付: https://note.com/api/v2/attachments/download/d2450ac5e0d16adba9c62e6a59ce1392
- noteタグ7件を公開ページで確認。自動翻訳とAI学習提供はこの記事でOFF。
- GitHubダウンロードDMGと元DMGのSHA256一致。hdiutil verify VALID、読み取り専用mount内strict署名成功。
- 通常版はApplicationsとLatest Buildsの内容一致・起動確認。保存値は元の2フォルダーへ復元したが、起動中の画面ではコピー先に検証用Destination-Greenが残ることを確認。UI操作の中断が繰り返されたため、実行前のコピー先再選択が必要。
- Store候補は公開DMGに含めていない。AppStore/README.mdに準備と残作業を記録。
