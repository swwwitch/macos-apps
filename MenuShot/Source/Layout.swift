import CoreGraphics

/// A window on screen, in global top-left coordinates (points), as ScreenCaptureKit and CGWindowList report it.
struct WindowBox: Equatable {
    let id: UInt32
    let layer: Int
    let frame: CGRect
    /// Process that owns the window (0 when unknown).
    var owner: Int32 = 0
}

/// How much of the menu bar goes into the picture when the menu hangs from it.
enum BarRange: String, CaseIterable {
    /// From the left edge of the screen (the Apple menu) to the right of the menu.
    case fromLeft
    /// Only the width of the menu (and its shadow).
    case menuWidth
    /// The whole menu bar, including the status items on the right.
    case fullWidth
}

/// Decides what to capture: which windows, drawn in which order, inside which rectangle.
/// Pure geometry so it can be tested without a screen.
enum MenuLayout {
    /// kCGMainMenuWindowLevel, kCGStatusWindowLevel, kCGPopUpMenuWindowLevel.
    static let menuBarLayer = 24, statusLayer = 25, menuLayer = 101
    /// A menu counts as hanging from the menu bar when its top is within this distance of the bar's bottom.
    static let attachTolerance: CGFloat = 12

    struct Plan: Equatable {
        /// Area of the picture, in global points.
        let crop: CGRect
        /// Menu bar and status item windows, drawn first without a shadow.
        let bar: [WindowBox]
        /// Menu windows, back to front (submenus last), drawn with a shadow.
        let menus: [WindowBox]
    }

    /// `margin`: room kept around the menus for the shadow (0 without a shadow).
    /// `frontmost`: the active app, whose menus win when other apps also have windows at the pop-up menu level.
    /// Returns nil when no menu is open on `display`.
    static func plan(windows: [WindowBox], display: CGRect, range: BarRange, margin: CGFloat, frontmost: Int32 = 0) -> Plan? {
        // Tiny pop-up level windows (1×1 helpers of other apps) are not menus.
        let candidates = windows.filter { $0.layer == menuLayer && $0.frame.width >= 8 && $0.frame.height >= 8 && display.intersects($0.frame) }
        guard !candidates.isEmpty else { return nil }
        // Only one app's menus: other apps can keep windows at this level (a window mirroring the screen at that level drew the menus a second time, 2026-10-26).
        // The front app owns the menu bar menus; a status item's menu belongs to a background app, so fall back to the largest menu's owner.
        let owner = candidates.contains { $0.owner == frontmost } ? frontmost
            : candidates.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }!.owner
        let menus = candidates.filter { $0.owner == owner }.sorted { $0.id < $1.id }
        guard let first = menus.first else { return nil }
        let union = menus.dropFirst().reduce(first.frame) { $0.union($1.frame) }
        let menuBar = windows.first { $0.layer == menuBarLayer && abs($0.frame.minY - display.minY) < 1 && display.intersects($0.frame) }
        let barBottom = menuBar?.frame.maxY ?? display.minY
        let attached = menuBar != nil && union.minY - barBottom <= attachTolerance

        guard attached else {
            // A context menu or a pop-up button's menu: only the menus and their shadow.
            return Plan(crop: union.insetBy(dx: -margin, dy: -margin).intersection(display).integral, bar: [], menus: menus)
        }
        let left: CGFloat, right: CGFloat
        switch range {
        case .fromLeft: left = display.minX; right = union.maxX + margin
        case .menuWidth: left = union.minX - margin; right = union.maxX + margin
        case .fullWidth: left = display.minX; right = display.maxX
        }
        let crop = CGRect(x: left, y: display.minY, width: right - left, height: union.maxY + margin - display.minY).intersection(display).integral
        // Status items (clock, Control Center…) are separate windows; keep those inside the picture.
        let bar = [menuBar!] + windows.filter { $0.layer == statusLayer && $0.frame.intersects(crop) && abs($0.frame.minY - display.minY) < 1 }
        return Plan(crop: crop, bar: bar, menus: menus)
    }

    /// Where a window lands in a bitmap of `crop` at `scale` (Core Graphics, origin at the bottom left).
    static func placement(of frame: CGRect, in crop: CGRect, scale: CGFloat) -> CGRect {
        CGRect(x: (frame.minX - crop.minX) * scale, y: (crop.maxY - frame.maxY) * scale, width: frame.width * scale, height: frame.height * scale)
    }
}
