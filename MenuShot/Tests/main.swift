import CoreGraphics
import Foundation

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if condition { print("PASS:", message) } else { failures += 1; print("FAIL:", message) }
}

// A 2560×1080 display with the menu bar, a clock, VS Code's Selection menu and a submenu (frames measured on macOS 26).
let display = CGRect(x: 0, y: 0, width: 2560, height: 1080)
let bar = WindowBox(id: 27, layer: 24, frame: CGRect(x: 0, y: 0, width: 2560, height: 30))
let clock = WindowBox(id: 32, layer: 25, frame: CGRect(x: 2409, y: 0, width: 151, height: 30))
let menu = WindowBox(id: 2272, layer: 101, frame: CGRect(x: 184, y: 31, width: 350, height: 427))
let submenu = WindowBox(id: 2280, layer: 101, frame: CGRect(x: 530, y: 120, width: 200, height: 100))
let helper = WindowBox(id: 40, layer: 101, frame: CGRect(x: 0, y: 1079, width: 1, height: 1))
let window = WindowBox(id: 1157, layer: 0, frame: CGRect(x: 0, y: 31, width: 1280, height: 1049))
let all = [window, bar, clock, helper, submenu, menu]

check(MenuLayout.plan(windows: [window, bar, clock, helper], display: display, range: .fromLeft, margin: 28) == nil, "no plan without a menu (1×1 helpers do not count)")

let left = MenuLayout.plan(windows: all, display: display, range: .fromLeft, margin: 28)!
check(left.crop == CGRect(x: 0, y: 0, width: 758, height: 486), "from the left: screen edge to the submenu's right plus the margin, down to the menu's bottom plus the margin")
check(left.bar == [bar], "the clock lies outside the picture")
check(left.menus.map(\.id) == [2272, 2280], "menu first, submenu on top; ordinary windows and helpers left out")

let narrow = MenuLayout.plan(windows: all, display: display, range: .menuWidth, margin: 0)!
check(narrow.crop == CGRect(x: 184, y: 0, width: 546, height: 458), "menu width without a shadow")

let full = MenuLayout.plan(windows: all, display: display, range: .fullWidth, margin: 28)!
check(full.crop.width == 2560 && full.bar == [bar, clock], "whole menu bar includes the status items")

let context = WindowBox(id: 3000, layer: 101, frame: CGRect(x: 1000, y: 500, width: 200, height: 300))
let floating = MenuLayout.plan(windows: [bar, context], display: display, range: .fromLeft, margin: 28)!
check(floating.bar.isEmpty && floating.crop == CGRect(x: 972, y: 472, width: 256, height: 356), "a contextual menu is captured alone with its shadow")

let edge = WindowBox(id: 3001, layer: 101, frame: CGRect(x: 2450, y: 31, width: 100, height: 100))
check(MenuLayout.plan(windows: [bar, edge], display: display, range: .fromLeft, margin: 28)!.crop.maxX == 2560, "the picture stays inside the display")

// A second display to the right: its own menu bar.
let second = CGRect(x: 2560, y: 0, width: 1920, height: 1080)
let bar2 = WindowBox(id: 90, layer: 24, frame: CGRect(x: 2560, y: 0, width: 1920, height: 30))
let menu2 = WindowBox(id: 91, layer: 101, frame: CGRect(x: 2700, y: 31, width: 200, height: 200))
let plan2 = MenuLayout.plan(windows: [bar, bar2, menu, menu2], display: second, range: .fromLeft, margin: 0)!
check(plan2.crop.minX == 2560 && plan2.bar == [bar2] && plan2.menus == [menu2], "each display uses its own menu bar and menus")

check(MenuLayout.placement(of: menu.frame, in: left.crop, scale: 2) == CGRect(x: 368, y: 56, width: 700, height: 854), "placement flips to Core Graphics coordinates at 2×")

// Another app's window at the pop-up menu level (it mirrored the screen and drew the menus twice): only the front app's menus are used.
let mine = WindowBox(id: 500, layer: 101, frame: CGRect(x: 200, y: 31, width: 180, height: 200), owner: 42)
let mirror = WindowBox(id: 501, layer: 101, frame: CGRect(x: 380, y: 200, width: 400, height: 400), owner: 77)
let owned = MenuLayout.plan(windows: [bar, mine, mirror], display: display, range: .fromLeft, margin: 0, frontmost: 42)!
check(owned.menus == [mine] && owned.crop.maxX == 380, "menus of the front app only")
let status = MenuLayout.plan(windows: [bar, mine, mirror], display: display, range: .fromLeft, margin: 0, frontmost: 9)!
check(status.menus == [mirror], "a status item's menu (background app): the largest menu's owner")

print(failures == 0 ? "All tests passed" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
