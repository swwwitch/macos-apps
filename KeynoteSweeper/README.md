# KeynoteSweeper

Keynoteの最前面の書類から、使用されていないマスター（スライドレイアウト）と非表示のスライドを削除するSwiftUI/AppKitアプリ。Apple Silicon / macOS 13以降。Keynoteが必要。

ダイアログ形式の画面で、チェックボックスで削除する項目を選ぶ。

- 使用されていないマスターを削除
- 非表示のスライドを削除
- すべてのトランジションを削除
- すべてのオブジェクトのアニメーション（ビルド）を削除

Keynoteの［Keynote］＞［サービス］にも「使用されていないマスターを削除」「非表示のスライドを削除」「トランジションを削除」「オブジェクトのアニメーションを削除」「すべてのアニメーションを削除」を出す（Info.plist の NSServices、NSRequiredContext で Keynote 前面時のみ・既定で有効）。サービスは最前面の書類が対象で、確認のダイアログボックスもウインドウも出さずに削除する（失敗・一部失敗のときだけウインドウを表示）。Keynoteが応答を待つため処理は非同期で始める。項目名を変えたら `pbs -flush && pbs -update`（キャッシュが残る）。

## しくみ

- 書類の読み取りと非表示のスライドの削除は、NSAppleScriptからKeynoteへのApple Events（`delete (every slide whose skipped is true)`）。
- Keynoteの辞書ではスライドレイアウトは読み取り専用で、`delete` はエラー -10000 になる。そのため、アクセシビリティAPIで［表示］＞［スライドレイアウトを編集］を開き、ナビゲータにフォーカスを当てて矢印キー（CGEvent.postToPid）で選び、Deleteキーで消す。
  - ナビゲータのサムネールはAXに出ないため、選択中のマスター名は分割グループ先頭の静的テキスト「スライドレイアウトを編集: ○○」から読む。並びはDOMの `slide layouts` と一致する。
  - 末尾へ一度送ってから上へたどる（後ろから消すので番号がずれない）。待機は決め打ちせず、名前と件数の変化をポーリングで確認する。
  - 名前が一致しないとき、件数が減らないとき、Keynoteが前面でなくなったとき、最前面の書類が変わったときは削除しない／中止する。
- マスターは名前で判定（Keynoteも名前で参照する）。同名のどれかが使われていれば全部残す。最後の1個は消さない。
- 両方を選ぶと非表示のスライドを先に消し、それだけが使っていたマスターも対象にする。
- トランジションは `transition properties` の効果を `no transition effect` にする。効果だけ渡すと継続時間・待ち時間・自動送りが既定値に戻るので、元の値を書き戻す。
- ビルド（オブジェクトのアニメーション）は辞書に無い。［表示］＞［ビルドの順番を表示］のパネルはAX APIなら表（AXTable、行＝ビルド）が見える（System Eventsの entire contents には出ない）。各スライドを `current slide` で表示し、行をAXSelectedRowsで全選択してDeleteキー。非表示スライドは `slide number` が取れないので、`current slide` の参照（slide N of document …）から番号を読む。終わったら元のスライドに戻し、開いたパネルは閉じる。
- 処理順は 非表示スライド → トランジション → ビルド → マスター。
- 削除はKeynoteの［取り消す］で戻せる（実測。ビルドはスライド単位で1回）。

## ビルド・テスト

```
./test.sh            # 単体テスト＋4言語の翻訳キー・プレースホルダー検証
./test.sh --keynote  # 実際のKeynoteで新規の書類を作って削除を検証し、保存せず閉じる
./test.sh --builds <ビルド付きの.key>  # 一時コピーでビルドの削除を検証（元のファイルは開かない）
./build.sh           # build/KeynoteSweeper.app
./build.sh --deploy  # 検証後、/Applications と Latest Builds へ配置（Shared/BuildTools/deploy_both.py）
```

`--keynote` は実行するターミナル（またはエディタ）にオートメーションとアクセシビリティの許可が必要。

## ファイル

- `Source/Sweeper.swift`：Keynoteの読み取り（KeynoteDOM）、レイアウト編集の操作（LayoutEditor）、削除処理（Sweeper）、計画（SweepPlan）
- `Source/main.swift`：主画面・設定・メニュー
- `make-resources.py` / `help_text.py`：4言語の文字列とヘルプを生成
- `Assets/GenerateIcon.swift`：アイコン（マスタード基調、スクリーンとほうき）
