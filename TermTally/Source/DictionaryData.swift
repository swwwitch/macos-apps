import Foundation

/// The bundled dictionary, in the format of the user's own one (VariantDictionary.parse):
/// 「誤 → 正」 appears as soon as the wrong spelling is found, 「? 誤 → 正」 does too but the target is left to the user
/// because the word can be right in context, and 「A、B」 appears when two of the spellings are both used.
enum DictionaryData {
    static let text = """
    ? 波線 → 破線
    パス状文字 → パス上文字
    ? 補完 → 補間
    役物 → 約物
    ? 抑える → 押さえる
    ? 改定 → 改訂
    ? 改定版 → 改訂版
    ? 意外 → 以外
    ? 内臓 → 内蔵
    ? 初稿 → 初校
    個条書き → 箇条書き
    ? 製作 → 制作
    ? 対象 → 対照

    ドラック → ドラッグ
    WIn → Win
    WIndows → Windows
    QuickLook → Quick Look
    しずらい → しづらい
    日本工業規格 → 日本産業規格
    シャギー → ジャギー
    ガーター → ガター
    レスポンシブル → レスポンシブ
    墨付き括弧 → 隅付き括弧
    激的 → 劇的
    グリーンインストール → クリーンインストール
    ? タイポ → タイポグラフィ
    字詰め → 文字詰め
    ぶら下げインデント → 突き出しインデント
    ワイアーフレーム → ワイヤーフレーム
    ヒヤリング → ヒアリング
    ダイアル → ダイヤル
    エンジニヤ → エンジニア
    フォロアー → フォロワー

    クリエーティブ、クリエイティブ
    クリエーター、クリエイター
    アクティベート、アクティベイト
    インターフェイス、インタフェース
    プレフィックス、プリフィックス
    ウイルス、ウィルス
    ウエイト、ウェイト
    ウェッブ → ウェブ
    アナリティックス → アナリティクス
    ソフトウエア、ソフトウェア
    メイン、メーン
    ? することができる → できる
    ? することが可能 → できる
    ? より → から
    ? おります → います
    ? にて → で
    ? については → は
    ? なります → です
    ? という
    ? さわる → 操作する
    ? 触る → 操作する
    ? 立ち上げる → 起動する
    ? 打つ → 入力する
    ? 落ちる → 強制終了する
    ? 凍る → フリーズする
    ? 拾う → 取得する
    ? おく → 保存する、移動する
    起点、基点、基準点
    フチ、ふち、エッジ、キワ、境界線
    ビフォア、ビフォー
    白、ホワイト
    黒、ブラック
    アンカー、アンカーポイント、ポイント
    ※、＊、*
    スペースバー、スペースキー
    アンダーバー、アンダースコア
    クオリティ、クォリティ、クオリティー
    つける、付ける
    名詞、名刺
    下線、アンダーライン
    やさしい、易しい、優しい
    半径、判型
    クリック、クイック
    x、×
    ドロップシャドウ、影、シャドウ
    ビュレット、バレット、ブレット
    カラム、コラム、段組み、段組
    コンマ、カンマ
    ルビ、読みがな、フリガナ
    マス目、升目、枡目、桝目
    音引き、伸ばし棒、長音
    拗促音、小書きのかな
    ビットマップ画像、ラスター画像
    切り抜き、トリミング
    レイアウト、レーアウト
    取り消し線、打ち消し線
    スモールキャップ、スモールキャップス、スモールキャピタル
    チャネル、チャンネル
    PC、Mac、パソコン、マシン、端末
    左揃え、左寄せ
    右揃え、右寄せ
    中央揃え、センター揃え、中央寄せ
    行頭行末揃え、ジャスティファイ
    マージン、余白
    裁断、断裁
    トレス、トレース
    パタン、パターン
    カラーモード、カラースペース
    スクリーンショット、ショット
    スクリーンキャプチャ、キャプチャ、スクリーンダンプ
    アプリケーション、ソフト、ソフトウェア

    Indesign → InDesign
    PhotoShop → Photoshop
    FireFly → Firefly
    Firefry → Firefly
    LightRoom → Lightroom
    AfterEffects → After Effects
    Adobe Max → Adobe MAX
    ツールパネル → ツールバー
    サムネイル → サムネール
    ポイントテキスト → ポイント文字
    エリア内テキスト → エリア内文字
    ? パレット → パネル
    ウィジット → ウィジェット
    キャンバス → カンバス
    インターフェース → インターフェイス
    ウインドウ → ウィンドウ
    フォルダ → フォルダー
    ? 切り替え → 切り換え
    シェープ → シェイプ
    ? 書く → 描く
    ? 先端 → 線端
    Vanishing Point → 消点
    ? 注釈 → コメント
    クローズドパス → クローズパス
    ? ベクトル → ベクター
    Adobe Systems → Adobe
    ? Adobe → アドビ
    複製を保存 → コピーを保存
    ? 環境設定 → 設定
    アクティベート、追加、インストール
    ディアクティベート、削除
    PDF変換、PDF書き出し、PDF保存、PDF作成
    ジャスティファイ → 均等配置（最終行左揃え）
    見積り → 見積もり、見積
    打合せ → 打ち合わせ
    問合せ → 問い合わせ

    ? ベット → ベッド
    ? ドック → ドッグ
    ビック → ビッグ
    グット → グッド
    ? バット → バッド
    スプレットシート → スプレッドシート
    ? バック → バッグ
    アボガド → アボカド
    ギブス → ギプス
    ? バッチ → バッジ

    カッコ → 括弧
    ナナメ → 斜め
    ? アキ → 空き
    ? ケイ → 罫
    カコミ → 囲み
    ナリユキ → 成り行き
    ケヌキ → 毛抜き
    永遠と → 延々と
    ? 脈略と → 脈々と
    ? 誠実に → 切実に

    AdobeFonts → Adobe Fonts
    AdobeFont → Adobe Fonts
    AdobeStock → Adobe Stock
    amazon → Amazon
    android → Android
    Balmuda → BALMUDA
    BALMUDA、バルミューダ
    Bang & olufsen → Bang & Olufsen
    Bang&Olufsen → Bang & Olufsen
    BOSE → Bose
    bose → Bose
    CookPad → Cookpad
    cookPad → Cookpad
    cookpad → Cookpad
    css → CSS
    DropBox → Dropbox
    facebook → Facebook
    FaceBook → Facebook
    figma → Figma
    Freee → freee
    github → GitHub
    Github → GitHub
    google → Google
    Google Map → Google Maps
    Google Maps、Google マップ
    html → HTML
    illustrator → Illustrator
    instagram → Instagram
    javascript → JavaScript
    Javascript → JavaScript
    keynote → Keynote
    KEYNOTE → Keynote
    ? line → LINE
    ? Line → LINE
    Linkedin → LinkedIn
    logicool → Logicool
    Mac book → MacBook
    Macbook → MacBook
    Mac Book Pro → MacBook Pro
    MacbookPro → MacBook Pro
    mac os → macOS
    macos → macOS
    miro → Miro
    ? Note → note
    portforio → portfolio
    plofile → profile
    Protopie → ProtoPie
    slack → Slack
    snapchat → Snapchat
    SnapChat → Snapchat
    SnowPeak → Snow Peak
    spotify → Spotify
    Tiktok → TikTok
    tiktok → TikTok
    TIPS → Tips
    User Voice → UserVoice
    WEB → Web
    Web、ウェブ
    WiFi → Wi-Fi
    wifi → Wi-Fi
    wikipedia → Wikipedia
    WikiPedia → Wikipedia
    XCode → Xcode
    xcode → Xcode
    Yahoo! Japan → Yahoo! JAPAN
    Yahoo!JAPAN → Yahoo! JAPAN
    Yahoo! News → Yahoo!ニュース
    Yahoo! ニュース → Yahoo!ニュース
    Youtube → YouTube
    zoom → Zoom
    ZOOM → Zoom
    data base → database
    time schedule → timetable
    口コミ、クチコミ
    """
}
