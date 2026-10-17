// MenuShortcut（保存形式）⇄ KeyCombo（共通の記録欄）の往復を、初期値のキーと矢印・Return で確かめる。
// test.sh が KeyCombo と MenuShortcut の定義を本体から抜き出して一緒にコンパイルする。
import AppKit

var failures = 0
func check(_ shortcut: MenuShortcut) {
    guard let combo = shortcut.combo else { print("FAIL no combo for \(shortcut.display)"); failures += 1; return }
    guard let back = MenuShortcut(combo: combo) else { print("FAIL no shortcut for \(combo.label)"); failures += 1; return }
    if back != shortcut { print("FAIL \(shortcut.display) -> \(combo.label) -> \(back.display)"); failures += 1 }
}
let samples: [MenuShortcut] = [
    .init("b", .command), .init("i", [.command, .shift]), .init("7", [.command, .shift]), .init("0", [.command, .option]),
    .init("[", .command), .init("]", [.command, .option]), .init("\r", .command), .init("x", [.command, .shift]),
    .init(MenuShortcut.upArrow, [.control, .shift]), .init(MenuShortcut.downArrow, [.control, .shift]), .init(" ", .control),
] + MenuShortcut.reserved.filter { $0.key != "+" && $0.key != "?" }
samples.forEach(check)
// テンキーの Enter は Return として保存する
let enter = MenuShortcut(combo: KeyCombo(code: 76, modifiers: KeyCombo.command))
if enter != MenuShortcut("\r", .command) { print("FAIL keypad enter"); failures += 1 }
// 文字にならないキー（F5）は保存しない
if MenuShortcut(combo: KeyCombo(code: 96, modifiers: KeyCombo.command)) != nil { print("FAIL F5"); failures += 1 }
print(failures == 0 ? "MenuShortcutCombo: all passed (\(samples.count) round trips)" : "MenuShortcutCombo: \(failures) failed")
exit(failures == 0 ? 0 : 1)
