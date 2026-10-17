import AppKit
import SwiftUI

/// 主画面の表示モード（一覧／ウィザード）
let mainModeKey = "mainMode"

/// ウィザードのカード1枚。settings をまとめて「変更後」に入れて適用する
struct WizardAction: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let settings: [(domain: String, key: String, value: NSObject)]
    /// 設定ファイルでは変えられないもの。カードを押すとシステム設定を開く
    var settingsURL: URL? = nil
}

private func on(_ v: Bool) -> NSObject { NSNumber(value: v) }
private let g = "NSGlobalDomain", dock = "com.apple.dock", finder = "com.apple.finder", ua = "com.apple.universalaccess"

/// エッセンシャル設定（ウィザードのカードと、一覧の同名カテゴリで使う）
let essentialSettings: [(domain: String, key: String, value: NSObject)] = [
    (g, "com.apple.swipescrolldirection", on(false)),
    (g, "com.apple.mouse.scaling", NSNumber(value: 2.5)),
    (featureFlagDomain, "redesigned_text_cursor", on(false)),
    (g, "AppleShowAllExtensions", on(true)),
    (finder, "FXPreferredViewStyle", "Nlsv" as NSString),
    (finder, "FXDefaultSearchScope", "SCcf" as NSString),
    (hotkeyDomain, "27", "50,1048576" as NSString),
    ("com.apple.screencapture", "show-thumbnail", on(false)),
    ("com.apple.controlcenter", "AutoHideMenuBarOption", NSNumber(value: 3)),
    (firstWeekdayDomain, "gregorian", NSNumber(value: 2)),
    (g, "AppleICUForce24HourTime", on(true)),
    (wallpaperDomain, "AllSpacesAndDisplays", "gray50" as NSString),
    // 以下は旧「おすすめの設定」から移したもの
    (g, "NSAutomaticCapitalizationEnabled", on(false)),
    (g, "NSAutomaticPeriodSubstitutionEnabled", on(false)),
    (g, "NSAutomaticQuoteSubstitutionEnabled", on(false)),
    (g, "NSAutomaticDashSubstitutionEnabled", on(false)),
    (g, "AppleKeyboardUIMode", NSNumber(value: 2)),
    ("com.apple.screencapture", "type", "png" as NSString),
    (nvramDomain, "StartupMute", on(false)),
    ("com.apple.WindowManager", "GloballyEnabled", on(false)),
    (finder, "AnimateWindowZoom", on(false)),
    (finder, "AnimateInfoPanes", on(false)),
    // このMacの値（システム設定のスライダーで決めたもの）。float で保存されている
    (ua, "mouseDriverCursorSize", NSNumber(value: Float(1.803315))),
    // 値が true でウィジェットを隠す（「ウィジェットを表示」がオフ）
    ("com.apple.WindowManager", "StandardHideWidgets", on(true)),
    ("com.apple.WindowManager", "StageManagerHideWidgets", on(true)),
    (g, "AppleWindowTabbingMode", "manual" as NSString),
]

let wizardActions: [WizardAction] = [
    WizardAction(id: "essentials", title: "エッセンシャル設定",
                 detail: "ナチュラルなスクロールのオフ、拡張子の表示、Finder のリスト表示、⌘` のウインドウ切り替え、月曜始まりの24時間表示、黒50%の壁紙など、基本の設定をまとめてそろえます。",
                 symbol: "star", tint: .brown, settings: essentialSettings),
    WizardAction(id: "animation", title: "アニメーションと視差効果を無効化",
                 detail: "ウィンドウの開閉・Dock・Finder・Mission Control の動きを止め、視差効果を減らします。",
                 symbol: "wand.and.rays", tint: .purple, settings: [
        (g, "NSAutomaticWindowAnimationsEnabled", on(false)),
        (g, "NSWindowResizeTime", NSNumber(value: 0.001)),
        (g, "QLPanelAnimationDuration", NSNumber(value: 0)),
        (finder, "DisableAllAnimations", on(true)),
        (finder, "AnimateWindowZoom", on(false)),
        (finder, "AnimateInfoPanes", on(false)),
        (dock, "launchanim", on(false)),
        (dock, "mineffect", "scale" as NSString),
        (dock, "expose-animation-duration", NSNumber(value: 0.1)),
        ("com.apple.universalaccess", "reduceMotion", on(true)),
    ]),
    WizardAction(id: "dock", title: "Dockを限りなく無効化",
                 detail: "Dockを隠し、ポインタを画面の端に寄せても出てこないようにします。起動中のアプリだけを小さく表示し、ホットコーナーもすべて切ります。",
                 symbol: "dock.rectangle", tint: .orange, settings: [
        (dock, "autohide", on(true)),
        (dock, "autohide-delay", NSNumber(value: 1000)),
        (dock, "autohide-time-modifier", NSNumber(value: 0)),
        (dock, "static-only", on(true)),
        (dock, "show-recents", on(false)),
        (dock, "tilesize", NSNumber(value: 16)),
        (dock, "magnification", on(false)),
        (dock, "launchanim", on(false)),
        // ホットコーナーは 1 が「なし」
        (dock, "wvous-tl-corner", NSNumber(value: 1)),
        (dock, "wvous-tr-corner", NSNumber(value: 1)),
        (dock, "wvous-bl-corner", NSNumber(value: 1)),
        (dock, "wvous-br-corner", NSNumber(value: 1)),
    ]),
    WizardAction(id: "stage", title: "ステージマネージャを無効化",
                 detail: "ステージマネージャを切り、壁紙をクリックしてもデスクトップを表示しないようにします。",
                 symbol: "rectangle.split.2x1", tint: .teal, settings: [
        ("com.apple.WindowManager", "GloballyEnabled", on(false)),
        ("com.apple.WindowManager", "EnableStandardClickToShowDesktop", on(false)),
    ]),
    WizardAction(id: "missionControl", title: "Mission Controlを無効化",
                 detail: "ジェスチャ・ショートカット（⌃↑ ⌃↓）・ウィンドウを上端へドラッグする操作で開かないようにします。",
                 symbol: "rectangle.3.group", tint: .blue, settings: [
        (dock, "showMissionControlGestureEnabled", on(false)),
        (dock, "showAppExposeGestureEnabled", on(false)),
        (dock, "enterMissionControlByTopWindowDrag", on(false)),
        (trackpadDomains[0], "TrackpadThreeFingerVertSwipeGesture", NSNumber(value: 0)),
        (trackpadDomains[0], "TrackpadFourFingerVertSwipeGesture", NSNumber(value: 0)),
        (hotkeyDomain, "32", "off" as NSString),
        (hotkeyDomain, "33", "off" as NSString),
    ]),
    // 値は作者のMacの設定（2026-10-14）。拡大率は float のまま写す
    WizardAction(id: "zoom", title: "画面ズームを有効に",
                 detail: "F1 でズーム機能のオン／オフ、F2 で拡大、⌥⌘- で縮小できるようにします。フルスクリーンで拡大し、画像はスムーズにせず、トラックパッドとスクロールのジェスチャは使いません。",
                 symbol: "plus.magnifyingglass", tint: .indigo, settings: [
        (ua, "closeViewHotkeysEnabled", on(true)),
        (ua, "closeViewTrackpadGestureZoomEnabled", on(false)),
        (ua, "closeViewScrollWheelToggle", on(false)),
        (ua, "closeViewZoomMode", NSNumber(value: 0)),
        (ua, "closeViewZoomFocusFollowModeKey", NSNumber(value: 0)),
        (ua, "closeViewNearPoint", NSNumber(value: 2.336353934151784)),
        (ua, "closeViewFarPoint", NSNumber(value: 1.8903125)),
        (hotkeyDomain, "15", "122,8388608" as NSString),
        (hotkeyDomain, "17", "120,8388608" as NSString),
        (hotkeyDomain, "19", "27,1572864" as NSString),
        (ua, "closeViewSmoothImages", on(false)),
    ]),
    // ディスプレイの時間は作者のMacの設定（2026-10-17）
    WizardAction(id: "security", title: "セキュリティを強化",
                 detail: "ファイアウォールとステルスモードをオンにし、AirDrop で受信しない・プリンタを共有しないようにします。ダウンロードしたアプリの確認ダイアログを出し、ディスプレイはバッテリーで2分・電源アダプタで10分でオフ、オフになったらすぐにパスワードを要求します。",
                 symbol: "lock.shield", tint: .gray, settings: [
        (firewallDomain, "globalstate", on(true)),
        (firewallDomain, "stealthmode", on(true)),
        ("com.apple.sharingd", "DiscoverableMode", "Off" as NSString),
        ("com.apple.LaunchServices", "LSQuarantine", on(true)),
        (printerSharingDomain, "_share_printers", on(false)),
        (screenLockDomain, "delay", "0" as NSString),
        (displaySleepDomain, "b", NSNumber(value: 2)),
        (displaySleepDomain, "c", NSNumber(value: 10)),
    ]),
    // FileVault の有効化はパスワードと復旧キーの扱いが要り、共有サービスの状態は管理者権限がないと読めないので、システム設定を開く
    WizardAction(id: "fileVault", title: "FileVaultをオン",
                 detail: "ディスクを暗号化します。設定ファイルからは切り替えられないため、システム設定の「プライバシーとセキュリティ」を開きます。FileVault の「オンにする…」を押してください。",
                 symbol: "lock.doc", tint: .gray, settings: [],
                 settingsURL: URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?FileVault")),
    WizardAction(id: "sharing", title: "共有サービスをオフ",
                 detail: "システム設定の「共有」を開きます。使っていなければ、リモートログイン・画面共有・ファイル共有・Bluetooth 共有・リモートマネジメントをすべてオフにしてください。",
                 symbol: "person.2.slash", tint: .gray, settings: [],
                 settingsURL: URL(string: "x-apple.systempreferences:com.apple.Sharing-Settings.extension")),
    WizardAction(id: "textCorrection", title: "英文の自動修正を無効化",
                 detail: "大文字化・スペルの自動変換・ピリオド・引用符・ダッシュの置換と、入力中の予測を切ります。",
                 symbol: "character.cursor.ibeam", tint: .green, settings: [
        (g, "NSAutomaticCapitalizationEnabled", on(false)),
        (g, "NSAutomaticSpellingCorrectionEnabled", on(false)),
        (g, "WebAutomaticSpellingCorrectionEnabled", on(false)),
        (g, "NSAutomaticPeriodSubstitutionEnabled", on(false)),
        (g, "NSAutomaticQuoteSubstitutionEnabled", on(false)),
        (g, "NSAutomaticDashSubstitutionEnabled", on(false)),
        (g, "NSAutomaticInlinePredictionEnabled", on(false)),
    ]),
    WizardAction(id: "siri", title: "Siriを無効化",
                 detail: "Siriを切り、メニューバーのアイコンと呼びかけでの起動を止めます。",
                 symbol: "waveform", tint: .pink, settings: [
        ("com.apple.assistant.support", "Assistant Enabled", on(false)),
        ("com.apple.Siri", "StatusMenuVisible", on(false)),
        ("com.apple.Siri", "VoiceTriggerUserEnabled", on(false)),
    ]),
    WizardAction(id: "notifications", title: "通知をオフ",
                 detail: "通知は設定ファイルからは切り替えられないため、システム設定の「集中モード」を開きます。「おやすみモード」をオンにしてください。",
                 symbol: "bell.slash", tint: .red, settings: [],
                 settingsURL: URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension")),
]

struct WizardView: View {
    @ObservedObject var store = Store.shared
    @State private var selected = Set<String>()
    @State private var confirmApply = false

    private func entryID(_ s: (domain: String, key: String, value: NSObject)) -> String { s.domain + "\u{1}" + s.key }

    /// すべての値がすでにそうなっているか
    func isDone(_ action: WizardAction) -> Bool {
        !action.settings.isEmpty && action.settings.allSatisfy { s in
            store.entries.first { $0.id == entryID(s) }?.current == s.value
        }
    }

    var columns: [GridItem] { [GridItem(.adaptive(minimum: 280), spacing: 16)] }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("やりたいことを選んでください")).font(.largeTitle.weight(.bold))
                Text(L("選んだカードの設定をまとめて書き込みます。細かく変えたいときは「一覧」に切り替えます。"))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 16)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(wizardActions) { card($0) }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
            Divider()
            footer
        }
        .alert(L("%@件の設定をMacに適用しますか？", String(pendingIDs.count)), isPresented: $confirmApply) {
            Button(L("適用")) { applySelected() }
            Button(L("キャンセル"), role: .cancel) {}
        } message: {
            Text(L("元の値はバックアップします。DockやFinderなどは再起動します。"))
        }
    }

    private func card(_ action: WizardAction) -> some View {
        let done = isDone(action)
        let isOn = selected.contains(action.id)
        return Button {
            if let url = action.settingsURL { NSWorkspace.shared.open(url); return }
            if isOn { selected.remove(action.id) } else { selected.insert(action.id) }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: action.symbol)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(action.tint.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Spacer()
                    if action.settingsURL != nil {
                        Image(systemName: "arrow.up.forward.app").font(.title2).foregroundStyle(.secondary)
                    } else if done && !isOn {
                        Label(L("設定済み"), systemImage: "checkmark.seal.fill")
                            .font(.callout.weight(.semibold)).foregroundStyle(.green)
                    } else {
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .font(.title).foregroundStyle(isOn ? Color.accentColor : Color.secondary.opacity(0.5))
                    }
                }
                Text(L(action.title)).font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(L(action.detail)).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isOn ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isOn ? 3 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(itemList(action))
        .accessibilityLabel(L(action.title))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// ツールチップに、書き換える項目の名前を並べる
    private func itemList(_ action: WizardAction) -> String {
        action.settings.compactMap { s in store.entries.first { $0.id == entryID(s) }.map { "・" + L($0.item.label) } }
            .joined(separator: "\n")
    }

    /// 選んだカードのうち、今の値と異なる項目
    private var pendingIDs: Set<String> {
        var ids = Set<String>()
        for action in wizardActions where selected.contains(action.id) {
            for s in action.settings {
                let id = entryID(s)
                if store.entries.first(where: { $0.id == id })?.current != s.value { ids.insert(id) }
            }
        }
        return ids
    }

    private func applySelected() {
        for action in wizardActions where selected.contains(action.id) {
            for s in action.settings { store.setTarget(entryID(s), .value(s.value)) }
        }
        store.apply(only: pendingIDs)
        selected.removeAll()
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(selected.isEmpty ? L("カードを押して選びます") : L("%@件を選択中", String(selected.count)))
                .foregroundStyle(.secondary)
            Spacer()
            Button(L("選択を解除")) { selected.removeAll() }
                .disabled(selected.isEmpty)
            Button { confirmApply = true } label: {
                Text(L("選んだ設定を適用")).padding(.horizontal, 12).padding(.vertical, 4)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(pendingIDs.isEmpty || store.isApplying)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }
}
