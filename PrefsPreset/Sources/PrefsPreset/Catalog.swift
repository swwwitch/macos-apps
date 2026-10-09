import Foundation

/// 一覧に並べる設定1項目の定義
struct PrefItem {
    let category: String
    let label: String
    /// 先頭のドメインから読み、すべてのドメインへ書く（トラックパッドは内蔵と Bluetooth の2つ）
    let domains: [String]
    let key: String
    /// 値（文字列化したもの）→ 表示名。並びはメニューの順
    let choices: KeyValuePairs<String, String>
}

let onOff: KeyValuePairs<String, String> = ["1": "オン", "0": "オフ"]
let trackpadDomains = ["com.apple.AppleMultitouchTrackpad", "com.apple.driver.AppleBluetoothMultitouch.trackpad"]
let customCategory = "追加した項目"

/// カテゴリの並びとサイドバーのアイコン
let categoryOrder: [(name: String, symbol: String)] = [
    ("全体", "macwindow"),
    ("キーボード", "keyboard"),
    ("文字入力", "character.cursor.ibeam"),
    ("マウス", "computermouse"),
    ("トラックパッド", "rectangle.and.hand.point.up.left"),
    ("サウンド", "speaker.wave.2"),
    ("Dock", "dock.rectangle"),
    ("Mission Control", "rectangle.3.group"),
    ("ホットコーナー", "rectangle.dashed"),
    ("Finder", "folder"),
    ("ウィンドウ管理", "rectangle.split.2x1"),
    ("アニメーション", "wand.and.rays"),
    ("ズーム機能", "plus.magnifyingglass"),
    ("スクリーンショット", "camera.viewfinder"),
    ("メニューバー", "menubar.rectangle"),
    ("時計", "clock"),
    ("ターミナル", "terminal"),
    ("その他", "ellipsis.circle"),
    (customCategory, "plus.circle"),
]

private func item(_ cat: String, _ label: String, _ domain: String, _ key: String, _ choices: KeyValuePairs<String, String> = [:]) -> PrefItem {
    PrefItem(category: cat, label: label, domains: [domain], key: key, choices: choices)
}

private func flag(_ cat: String, _ label: String, _ domain: String, _ key: String) -> PrefItem {
    item(cat, label, domain, key, onOff)
}

private func trackpad(_ label: String, _ key: String, _ choices: KeyValuePairs<String, String> = onOff) -> PrefItem {
    PrefItem(category: "トラックパッド", label: label, domains: trackpadDomains, key: key, choices: choices)
}

private let g = "NSGlobalDomain"
private let hotCorner: KeyValuePairs<String, String> = [
    "1": "なし", "0": "なし", "2": "Mission Control", "3": "アプリケーションウインドウ", "4": "デスクトップ",
    "5": "スクリーンセーバを開始", "6": "スクリーンセーバを無効", "10": "ディスプレイをスリープ",
    "11": "Launchpad", "12": "通知センター", "13": "画面をロック", "14": "クイックメモ",
]
private let swipeGesture: KeyValuePairs<String, String> = ["0": "オフ", "1": "オン", "2": "オン"]

let catalog: [PrefItem] = [
    // 全体
    flag("全体", "すべてのファイル名拡張子を表示", g, "AppleShowAllExtensions"),
    item("全体", "スクロールバーの表示", g, "AppleShowScrollBars",
         ["Automatic": "自動", "WhenScrolling": "スクロール時", "Always": "常に"]),
    item("全体", "タイトルバーのダブルクリック", g, "AppleActionOnDoubleClick",
         ["Maximize": "ズーム", "Fill": "フィル", "Minimize": "しまう", "None": "何もしない"]),
    flag("全体", "ダブルクリックでしまう（旧設定）", g, "AppleMiniaturizeOnDoubleClick"),
    item("全体", "書類をタブで開く", g, "AppleWindowTabbingMode",
         ["always": "常に", "fullscreen": "フルスクリーン時", "manual": "手動"]),
    flag("全体", "アプリ終了時にウィンドウを保持", g, "NSQuitAlwaysKeepsWindows"),
    item("全体", "最近使った項目の数", g, "NSRecentDocumentsLimit"),
    flag("全体", "ウィンドウを開くアニメーション", g, "NSAutomaticWindowAnimationsEnabled"),
    item("全体", "Quick Look のアニメーション時間", g, "QLPanelAnimationDuration"),
    item("全体", "ツールチップ表示までの時間（ms）", g, "NSInitialToolTipDelay"),
    flag("全体", "⌃⌘ドラッグでウィンドウを移動", g, "NSWindowShouldDragOnGesture"),
    flag("全体", "保存パネルを展開して開く", g, "NSNavPanelExpandedStateForSaveMode"),
    item("全体", "スプリングロードの遅延（秒）", g, "com.apple.springing.delay"),
    item("全体", "フォルダを開くアプリ", g, "NSFileViewer"),
    item("全体", "フォントのアンチエイリアス閾値", g, "AppleAntiAliasingThreshold"),
    item("全体", "NSConvolutionOverride1", g, "NSConvolutionOverride1"),

    // キーボード
    item("キーボード", "キーのリピート速度", g, "KeyRepeat"),
    item("キーボード", "リピート入力認識までの時間", g, "InitialKeyRepeat"),
    flag("キーボード", "F1、F2などを標準のファンクションキーとして使用", g, "com.apple.keyboard.fnState"),
    item("キーボード", "fn（地球儀）キーを押して", "com.apple.HIToolbox", "AppleFnUsageType",
         ["0": "何もしない", "1": "入力ソースを変更", "2": "絵文字と記号を表示", "3": "音声入力を開始"]),
    item("キーボード", "キーボードナビゲーション", g, "AppleKeyboardUIMode", ["0": "オフ", "2": "オン", "3": "オン"]),
    // 値が true でインジケータを表示（UIKit の機能フラグ redesigned_text_cursor）
    flag("キーボード", "キャップスロックインジケータを表示する", featureFlagDomain, "redesigned_text_cursor"),
    // 1048576 は ⌘
    item("キーボード", "ショートカット：次のウインドウを操作対象にする", hotkeyDomain, "27", ["50,1048576": "⌘`", "off": "オフ"]),

    // 文字入力
    flag("文字入力", "長押しでアクセント文字を表示", g, "ApplePressAndHoldEnabled"),
    flag("文字入力", "文頭を自動的に大文字にする", g, "NSAutomaticCapitalizationEnabled"),
    flag("文字入力", "スペルを自動変換", g, "NSAutomaticSpellingCorrectionEnabled"),
    flag("文字入力", "ダッシュを自動置換", g, "NSAutomaticDashSubstitutionEnabled"),
    flag("文字入力", "スペース2回でピリオドを入力", g, "NSAutomaticPeriodSubstitutionEnabled"),
    flag("文字入力", "スマート引用符", g, "NSAutomaticQuoteSubstitutionEnabled"),

    // マウス
    item("マウス", "マウスの軌跡の速さ", g, "com.apple.mouse.scaling"),
    item("マウス", "ポインタのサイズ（1〜4）", "com.apple.universalaccess", "mouseDriverCursorSize"),
    flag("マウス", "ページ間をスワイプ（スクロール）", g, "AppleEnableSwipeNavigateWithScrolls"),

    // トラックパッド
    item("トラックパッド", "トラックパッドの軌跡の速さ", g, "com.apple.trackpad.scaling"),
    flag("トラックパッド", "ナチュラルなスクロール", g, "com.apple.swipescrolldirection"),
    flag("トラックパッド", "強めのクリックと触覚フィードバック", g, "com.apple.trackpad.forceClick"),
    trackpad("タップでクリック", "Clicking"),
    trackpad("副ボタンのクリック（2本指）", "TrackpadRightClick"),
    trackpad("副ボタンのクリック（右下隅）", "TrackpadCornerSecondaryClick", ["0": "オフ", "2": "オン"]),
    trackpad("クリックの強さ", "FirstClickThreshold", ["0": "弱い", "1": "中", "2": "強い"]),
    trackpad("強めのクリックを抑制", "ForceSuppressed"),
    trackpad("サイレントクリック", "ActuateDetents", ["0": "オン", "1": "オフ"]),
    trackpad("3本指のドラッグ", "TrackpadThreeFingerDrag"),
    trackpad("ドラッグ（ダブルタップ）", "Dragging"),
    trackpad("ドラッグロック", "DragLock"),
    trackpad("拡大／縮小（ピンチ）", "TrackpadPinch"),
    trackpad("回転", "TrackpadRotate"),
    trackpad("スマートズーム（2本指ダブルタップ）", "TrackpadTwoFingerDoubleTapGesture"),
    trackpad("通知センター（右端から2本指）", "TrackpadTwoFingerFromRightEdgeSwipeGesture", swipeGesture),
    trackpad("調べる（3本指タップ）", "TrackpadThreeFingerTapGesture", swipeGesture),
    trackpad("3本指の左右スワイプ", "TrackpadThreeFingerHorizSwipeGesture", swipeGesture),
    trackpad("3本指の上下スワイプ", "TrackpadThreeFingerVertSwipeGesture", swipeGesture),
    trackpad("4本指の左右スワイプ", "TrackpadFourFingerHorizSwipeGesture", swipeGesture),
    trackpad("4本指の上下スワイプ", "TrackpadFourFingerVertSwipeGesture", swipeGesture),
    trackpad("4本指のピンチ", "TrackpadFourFingerPinchGesture", swipeGesture),
    trackpad("5本指のピンチ", "TrackpadFiveFingerPinchGesture", swipeGesture),
    trackpad("慣性スクロール", "TrackpadMomentumScroll"),
    trackpad("マウス接続時にトラックパッドを無視", "USBMouseStopsTrackpad"),

    // サウンド
    flag("サウンド", "起動時にサウンドを再生", nvramDomain, "StartupMute"),
    item("サウンド", "警告音の音量", g, "com.apple.sound.beep.volume"),
    flag("サウンド", "警告音で画面を点滅", g, "com.apple.sound.beep.flash"),
    flag("サウンド", "ユーザーインターフェイスのサウンドエフェクト", g, "com.apple.sound.uiaudio.enabled"),

    // Dock
    flag("Dock", "Dockを自動的に表示／非表示", "com.apple.dock", "autohide"),
    item("Dock", "自動表示までの遅延（秒）", "com.apple.dock", "autohide-delay"),
    item("Dock", "自動表示のアニメーション時間", "com.apple.dock", "autohide-time-modifier"),
    item("Dock", "サイズ", "com.apple.dock", "tilesize"),
    flag("Dock", "拡大", "com.apple.dock", "magnification"),
    item("Dock", "拡大時のサイズ", "com.apple.dock", "largesize"),
    item("Dock", "画面上の位置", "com.apple.dock", "orientation",
         ["left": "左", "bottom": "下", "right": "右"]),
    item("Dock", "ウィンドウをしまうときのエフェクト", "com.apple.dock", "mineffect",
         ["genie": "ジニー", "scale": "スケール", "suck": "吸い込み"]),
    flag("Dock", "ウィンドウをアプリケーションアイコンにしまう", "com.apple.dock", "minimize-to-application"),
    flag("Dock", "起動中のアプリをアニメーションで表示", "com.apple.dock", "launchanim"),
    flag("Dock", "起動中のアプリにインジケータを表示", "com.apple.dock", "show-process-indicators"),
    flag("Dock", "提案されたアプリと最近使用したアプリを表示", "com.apple.dock", "show-recents"),
    flag("Dock", "起動中のアプリだけ表示", "com.apple.dock", "static-only"),

    // Mission Control
    flag("Mission Control", "最新の使用状況に基づいて操作スペースを並べ替え", "com.apple.dock", "mru-spaces"),
    flag("Mission Control", "ウィンドウをアプリケーションごとにグループ化", "com.apple.dock", "expose-group-apps"),
    flag("Mission Control", "ウィンドウを上端へドラッグして Mission Control", "com.apple.dock", "enterMissionControlByTopWindowDrag"),
    flag("Mission Control", "アプリ切替時にその操作スペースへ移動", g, "AppleSpacesSwitchOnActivate"),
    item("Mission Control", "ディスプレイごとに個別の操作スペース", "com.apple.spaces", "spans-displays",
         ["0": "オン", "1": "オフ"]),
    flag("Mission Control", "Mission Control のジェスチャ", "com.apple.dock", "showMissionControlGestureEnabled"),
    flag("Mission Control", "アプリ Exposé のジェスチャ", "com.apple.dock", "showAppExposeGestureEnabled"),
    flag("Mission Control", "デスクトップを表示のジェスチャ", "com.apple.dock", "showDesktopGestureEnabled"),
    flag("Mission Control", "Launchpad のジェスチャ", "com.apple.dock", "showLaunchpadGestureEnabled"),

    // ホットコーナー
    item("ホットコーナー", "左上", "com.apple.dock", "wvous-tl-corner", hotCorner),
    item("ホットコーナー", "右上", "com.apple.dock", "wvous-tr-corner", hotCorner),
    item("ホットコーナー", "左下", "com.apple.dock", "wvous-bl-corner", hotCorner),
    item("ホットコーナー", "右下", "com.apple.dock", "wvous-br-corner", hotCorner),

    // Finder
    flag("Finder", "デスクトップにアイコンを表示", "com.apple.finder", "CreateDesktop"),
    flag("Finder", "すべてのアニメーションを無効", "com.apple.finder", "DisableAllAnimations"),
    item("Finder", "既定の表示方法", "com.apple.finder", "FXPreferredViewStyle",
         ["icnv": "アイコン", "Nlsv": "リスト", "clmv": "カラム", "glyv": "ギャラリー"]),
    item("Finder", "検索の範囲", "com.apple.finder", "FXDefaultSearchScope",
         ["SCev": "このMac", "SCcf": "現在のフォルダ", "SCsp": "前回の検索範囲"]),
    item("Finder", "新規ウィンドウで表示", "com.apple.finder", "NewWindowTarget",
         ["PfCm": "コンピュータ", "PfVo": "ボリューム", "PfHm": "ホーム", "PfDe": "デスクトップ",
          "PfDo": "書類", "PfAF": "最近の項目", "PfID": "iCloud Drive", "PfLo": "その他"]),
    item("Finder", "新規ウィンドウのフォルダ", "com.apple.finder", "NewWindowTargetPath"),
    flag("Finder", "フォルダをタブで開く", "com.apple.finder", "FinderSpawnTab"),
    flag("Finder", "デスクトップに内蔵ディスクを表示", "com.apple.finder", "ShowHardDrivesOnDesktop"),
    flag("Finder", "デスクトップに外部ディスクを表示", "com.apple.finder", "ShowExternalHardDrivesOnDesktop"),
    flag("Finder", "デスクトップにリムーバブルメディアを表示", "com.apple.finder", "ShowRemovableMediaOnDesktop"),
    flag("Finder", "デスクトップに接続中のサーバを表示", "com.apple.finder", "ShowMountedServersOnDesktop"),
    flag("Finder", "サイドバーに最近使ったタグを表示", "com.apple.finder", "ShowRecentTags"),
    flag("Finder", "パスバーを表示", "com.apple.finder", "ShowPathbar"),
    flag("Finder", "ステータスバーを表示", "com.apple.finder", "ShowStatusBar"),
    flag("Finder", "タイトルにフルパスを表示", "com.apple.finder", "_FXShowPosixPathInTitle"),
    flag("Finder", "フォルダを常に先頭に表示", "com.apple.finder", "_FXSortFoldersFirst"),
    flag("Finder", "拡張子を変更する前に警告", "com.apple.finder", "FXEnableExtensionChangeWarning"),
    flag("Finder", "ゴミ箱を空にする前に警告", "com.apple.finder", "WarnOnEmptyTrash"),
    flag("Finder", "30日後にゴミ箱から項目を削除", "com.apple.finder", "FXRemoveOldTrashItems"),
    flag("Finder", "不可視ファイルを表示", "com.apple.finder", "AppleShowAllFiles"),
    flag("Finder", "ネットワークに .DS_Store を作らない", "com.apple.desktopservices", "DSDontWriteNetworkStores"),
    flag("Finder", "USBに .DS_Store を作らない", "com.apple.desktopservices", "DSDontWriteUSBStores"),

    // ウィンドウ管理
    flag("ウィンドウ管理", "画面の端へドラッグしてタイル表示", "com.apple.WindowManager", "EnableTilingByEdgeDrag"),
    flag("ウィンドウ管理", "メニューバーへドラッグしてフルスクリーン表示", "com.apple.WindowManager", "EnableTopTilingByEdgeDrag"),
    flag("ウィンドウ管理", "optionキーを押しながらタイル表示", "com.apple.WindowManager", "EnableTilingOptionAccelerator"),
    flag("ウィンドウ管理", "タイル表示したウィンドウに余白", "com.apple.WindowManager", "EnableTiledWindowMargins"),
    flag("ウィンドウ管理", "壁紙クリックでデスクトップを表示", "com.apple.WindowManager", "EnableStandardClickToShowDesktop"),
    flag("ウィンドウ管理", "デスクトップ項目を隠す", "com.apple.WindowManager", "StandardHideDesktopIcons"),
    flag("ウィンドウ管理", "ウィジェットを隠す", "com.apple.WindowManager", "StandardHideWidgets"),
    flag("ウィンドウ管理", "ステージマネージャ", "com.apple.WindowManager", "GloballyEnabled"),
    flag("ウィンドウ管理", "ステージマネージャでデスクトップ項目を隠す", "com.apple.WindowManager", "HideDesktop"),
    flag("ウィンドウ管理", "ステージマネージャでウィジェットを隠す", "com.apple.WindowManager", "StageManagerHideWidgets"),
    flag("ウィンドウ管理", "ステージマネージャで最近使ったアプリを隠す", "com.apple.WindowManager", "AutoHide"),
    item("ウィンドウ管理", "アプリのウィンドウを表示", "com.apple.WindowManager", "AppWindowGroupingBehavior",
         ["0": "すべて同時に", "1": "1つずつ"]),

    // アニメーション
    flag("アニメーション", "ウィンドウのズームアニメーション", "com.apple.finder", "AnimateWindowZoom"),
    flag("アニメーション", "情報ウィンドウのアニメーション", "com.apple.finder", "AnimateInfoPanes"),
    // reduceMotion（視差効果を減らす）が 1 のとき視差効果はオフ
    item("アニメーション", "視差効果", "com.apple.universalaccess", "reduceMotion", ["0": "オン", "1": "オフ"]),

    // ズーム機能（アクセシビリティ）
    flag("ズーム機能", "キーボードショートカットを使って拡大・縮小", "com.apple.universalaccess", "closeViewHotkeysEnabled"),
    flag("ズーム機能", "トラックパッドのジェスチャを使って拡大・縮小", "com.apple.universalaccess", "closeViewTrackpadGestureZoomEnabled"),
    flag("ズーム機能", "スクロールジェスチャと修飾キーを使って拡大・縮小", "com.apple.universalaccess", "closeViewScrollWheelToggle"),
    item("ズーム機能", "ズーム方法", "com.apple.universalaccess", "closeViewZoomMode", ["0": "フルスクリーン"]),
    item("ズーム機能", "カーソルに追従", "com.apple.universalaccess", "closeViewZoomFocusFollowModeKey", ["0": "オフ", "1": "オン"]),
    item("ズーム機能", "最大拡大率", "com.apple.universalaccess", "closeViewNearPoint"),
    item("ズーム機能", "最小縮小率", "com.apple.universalaccess", "closeViewFarPoint"),
    // 値は "キーコード,修飾キー"。8388608 は fn（ファンクションキー）、1572864 は ⌥⌘
    item("ズーム機能", "ショートカット：ズーム機能のオン／オフ", hotkeyDomain, "15",
         ["122,8388608": "F1", "120,8388608": "F2", "28,1572864": "⌥⌘8", "off": "オフ"]),
    item("ズーム機能", "ショートカット：拡大", hotkeyDomain, "17",
         ["120,8388608": "F2", "122,8388608": "F1", "24,1572864": "⌥⌘=", "off": "オフ"]),

    // スクリーンショット
    item("スクリーンショット", "保存先", "com.apple.screencapture", "location"),
    item("スクリーンショット", "ファイル形式", "com.apple.screencapture", "type",
         ["png": "PNG", "jpg": "JPEG", "heic": "HEIC", "tiff": "TIFF", "pdf": "PDF", "gif": "GIF", "bmp": "BMP"]),
    item("スクリーンショット", "ファイル名", "com.apple.screencapture", "name"),
    flag("スクリーンショット", "フローティングサムネールを表示", "com.apple.screencapture", "show-thumbnail"),
    flag("スクリーンショット", "ウィンドウの影を付けない", "com.apple.screencapture", "disable-shadow"),
    flag("スクリーンショット", "ファイル名に日付を含める", "com.apple.screencapture", "include-date"),
    flag("スクリーンショット", "マウスポインタを表示", "com.apple.screencapture", "showsCursor"),

    // メニューバー
    item("メニューバー", "メニューバーを自動的に非表示", "com.apple.controlcenter", "AutoHideMenuBarOption",
         ["0": "常に", "1": "デスクトップのみ", "2": "フルスクリーンのみ", "3": "しない"]),
    flag("メニューバー", "フルスクリーンでメニューバーを表示", g, "AppleMenuBarVisibleInFullscreen"),
    item("メニューバー", "メニューバーの文字サイズ", g, "AppleMenuBarFontSize", ["large": "大"]),

    // 時計
    flag("時計", "曜日を表示", "com.apple.menuextra.clock", "ShowDayOfWeek"),
    flag("時計", "午前／午後を表示", "com.apple.menuextra.clock", "ShowAMPM"),
    item("時計", "日付を表示", "com.apple.menuextra.clock", "ShowDate",
         ["0": "スペースがある場合", "1": "常に", "2": "しない"]),
    flag("時計", "秒を表示", "com.apple.menuextra.clock", "ShowSeconds"),
    flag("時計", "区切り文字を点滅", "com.apple.menuextra.clock", "FlashDateSeparators"),
    flag("時計", "アナログ", "com.apple.menuextra.clock", "IsAnalog"),

    // ターミナル
    item("ターミナル", "起動時のプロファイル", "com.apple.Terminal", "Startup Window Settings"),
    item("ターミナル", "デフォルトのプロファイル", "com.apple.Terminal", "Default Window Settings"),
    flag("ターミナル", "ターミナルのウインドウフォーカスを使用", "com.apple.Terminal", "FocusFollowsMouse"),

    // その他
    flag("その他", "ダウンロードしたアプリの確認ダイアログ", "com.apple.LaunchServices", "LSQuarantine"),
]

/// アプリに同梱する「おすすめの設定」。読み込むと「変更後」に入る（書き込むのは「適用」を押したとき）
let recommended: [(domain: String, key: String, value: NSObject)] = [
    (g, "NSAutomaticCapitalizationEnabled", NSNumber(value: false)),
    (g, "NSAutomaticPeriodSubstitutionEnabled", NSNumber(value: false)),
    (g, "NSAutomaticQuoteSubstitutionEnabled", NSNumber(value: false)),
    (g, "NSAutomaticDashSubstitutionEnabled", NSNumber(value: false)),
    (g, "AppleKeyboardUIMode", NSNumber(value: 2)),
    ("com.apple.screencapture", "type", "png" as NSString),
    (nvramDomain, "StartupMute", NSNumber(value: false)),
    ("com.apple.dock", "expose-group-apps", NSNumber(value: false)),
    // spans-displays は true で「ディスプレイごとに個別の操作スペース」がオフ
    ("com.apple.spaces", "spans-displays", NSNumber(value: true)),
    ("com.apple.WindowManager", "GloballyEnabled", NSNumber(value: false)),
    ("com.apple.Terminal", "FocusFollowsMouse", NSNumber(value: true)),
    ("com.apple.finder", "AnimateWindowZoom", NSNumber(value: false)),
    ("com.apple.finder", "AnimateInfoPanes", NSNumber(value: false)),
    ("com.apple.universalaccess", "reduceMotion", NSNumber(value: true)),
    ("com.apple.universalaccess", "closeViewHotkeysEnabled", NSNumber(value: true)),
    ("com.apple.universalaccess", "closeViewTrackpadGestureZoomEnabled", NSNumber(value: false)),
    ("com.apple.universalaccess", "closeViewScrollWheelToggle", NSNumber(value: false)),
    ("com.apple.universalaccess", "closeViewZoomMode", NSNumber(value: 0)),
    ("com.apple.universalaccess", "closeViewZoomFocusFollowModeKey", NSNumber(value: 0)),
    ("com.apple.universalaccess", "closeViewNearPoint", NSNumber(value: 2.336353934151787)),
    ("com.apple.universalaccess", "closeViewFarPoint", NSNumber(value: 1.8903124999999998)),
    (hotkeyDomain, "15", "122,8388608" as NSString),
    (hotkeyDomain, "17", "120,8388608" as NSString),
    (hotkeyDomain, "27", "50,1048576" as NSString),
    (featureFlagDomain, "redesigned_text_cursor", NSNumber(value: false)),
    // このMacの値（システム設定のスライダーで決めたもの）。float で保存されている
    ("com.apple.universalaccess", "mouseDriverCursorSize", NSNumber(value: Float(1.803315))),
]
