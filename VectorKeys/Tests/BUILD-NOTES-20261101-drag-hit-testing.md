# VectorKeys 1.17.2（30）ドラッグ全幅化・診断

- 2026-11-01 JST、開発Mac MacBook-Pro-14-2024-sw.local、作業ブランチcodex/filesorter-screenshot-rename-20261101、基点c2a1efb7。対象SHAは本記録を含む確定コミット。公証担当01a17433-ccf5-7700-9f23-43efbe62689aの明示依頼。29の確定ソースを同番号で作り替えない。
- ドラッグ元と、グループ／未分類のドロップ先にframe(maxWidth: infinity, minHeight: 24, alignment: leading)とcontentShape(Rectangle)を設定。文字やアイコン以外の行内空白も対象にする。
- ドラッグ元はonDragで開始時点の選択集合を取得してNSStringのNSItemProviderへ格納。ドロップ先も同じUTF-8／plain textをonDropで受け取り、NSStringの読み取り後に主スレッドでモデルへ適用。既存のID／グループ存在検証と一括Undo・重複防止は維持。
- ComponentDragPayloadを共通化し、空／別形式／過大データを拒否。ログにコード・パス・コンポーネント名・ID・グループ名を含めない。
- 診断はsubsystem jp.dtp-transit.vectorkeys、category component-drag。drag-begin count=N → drop-enter → drop-receive providers=N readable=N → drop-applied count=N。読み取り失敗はdrop-decode-failed、不正IDはdrop-rejected。行進入時は背景色も変わる。
- drag-beginが出なければ開始前（CUAのドラッグ経路・開始閾値等）、drop-enterが出なければ開始後のターゲット進入、drop-receive後にappliedがなければ読み取り／検証段階として切り分ける。ログだけでアクション作成済みとはせず、対象グループの件数・使用数・Undoも確認する。
- test.sh PASS：ペイロード往復・空／別形式／過大の拒否、NSItemProviderが受信可能な文字列とUTF-8／plain-text型を提供すること、実際のCombine Storeの空コード登録／追加編集削除／Undo／Redo／一括登録と重複防止、既存単体・Runner・4言語整合とヘルプ。
- NO_DEPLOY=1でワークスペースビルド。既存Apple Distribution署名（PL9S9PXX96）・codesign deep/strict PASS。既存StartupWindow.swiftの未使用変数警告あり。
- 開発側では起動・ドラッグ実機・公証・/Applications／Latest Builds配置・公開を実施していない。公証担当が新SHAで再ビルドして実機検証する。29の実機不合格だったドラッグが30で成功したとはまだ報告しない。ユーザーデータ・設定は変更していない。
- マニフェストSHA-256：9356d72b5837445dbb52b115c7b8bb6529d799f2b0abb05b6cda36dc742cfd2c
