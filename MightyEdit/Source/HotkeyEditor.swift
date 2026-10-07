import AppKit
import Carbon

struct HotkeyBinding: Equatable {
    var key: UInt32
    var modifiers: UInt32
    static let modifierChoices: [(String, UInt32)] = [("⌃", UInt32(controlKey)), ("⌥", UInt32(optionKey)), ("⇧", UInt32(shiftKey)), ("⌘", UInt32(cmdKey))]
    static let baseKeys: [(String, UInt32)] = [("A",0),("B",11),("C",8),("D",2),("E",14),("F",3),("G",5),("H",4),("I",34),("J",38),("K",40),("L",37),("M",46),("N",45),("O",31),("P",35),("Q",12),("R",15),("S",1),("T",17),("U",32),("V",9),("W",13),("X",7),("Y",16),("Z",6),("0",29),("1",18),("2",19),("3",20),("4",21),("5",23),("6",22),("7",26),("8",28),("9",25),(",",43),("-",27),("=",24)]
    static var keys: [(String, UInt32)] {
        let jis = KBGetLayoutType(Int16(LMGetKbdType())) == kKeyboardJIS
        let symbols: [(String, UInt32)] = jis
            ? [(".",47),("/",44),(";",41),(":",39),("@",33),("[",30),("]",42),("¥",93),("_",94)]
            : [(".",47),("/",44),(";",41),("'",39),("[",33),("]",30),("\\",42),("`",50)]
        // Key codes are what is saved; only the visible keypad label is localized.
        let keypad: [(String, UInt32)] = [("0",82),("1",83),("2",84),("3",85),("4",86),("5",87),("6",88),("7",89),
                                          ("8",91),("9",92),(".",65),("+",69),("-",78),("*",67),("/",75),("=",81),
                                          ("Enter",76),("Clear",71)]
        return baseKeys + symbols + [
            ("F1",122),("F2",120),("F3",99),("F4",118),("F5",96),
            ("F6",97),("F7",98),("F8",100),("F9",101),("F10",109),
            ("F11",103),("F12",111),("F13",105),("F14",107),("F15",113),
            ("F16",106),("F17",64),("F18",79),("F19",80),("F20",90),
            ("←",123),("→",124),("↓",125),("↑",126),
            ("Home",115),("End",119),("Page Up",116),("Page Down",121),
            ("Space",49),("Tab",48),("Return",36),("Delete ⌫",51),("Delete ⌦",117),("Escape",53)
        ] + keypad.map { (L("hotkey.keypad") + " " + $0.0, $0.1) }
    }
    var encoded: Int { 1000 + Int(modifiers) * 128 + Int(key) }
    static func decode(_ value: Int) -> Self? {
        guard value >= 1000 else { return nil }
        let v = value - 1000
        let result = Self(key: UInt32(v % 128), modifiers: UInt32(v / 128))
        return keys.contains { $0.1 == result.key } ? result : nil
    }
    var actual: Self {
        if key == 24 && KBGetLayoutType(Int16(LMGetKbdType())) == kKeyboardJIS {
            return Self(key: 27, modifiers: modifiers | UInt32(shiftKey))
        }
        return self
    }
    var label: String { Self.modifierChoices.filter { modifiers & $0.1 != 0 }.map { $0.0 }.joined() + (Self.keys.first { $0.1 == key }?.0 ?? "") }
    /// ⌘ alone with A/Z/X/C/V/W/Q/, stays with the standard edit, window and app menus.
    static let reservedCommandKeys: Set<UInt32> = [0, 6, 7, 8, 9, 12, 13, 43]
    var hasRequiredModifier: Bool { modifiers & UInt32(controlKey | optionKey | cmdKey) != 0 }
    var isReservedStandard: Bool { modifiers == UInt32(cmdKey) && Self.reservedCommandKeys.contains(key) }
    var valid: Bool { hasRequiredModifier && !isReservedStandard }
}

/// BrowserSwitcher-style modifier checkboxes, key picker and explicit Apply.
final class HotkeyEditor: NSStackView {
    private var checks: [NSButton] = []
    private let keyMenu = NSPopUpButton()
    private let applySelection: (HotkeyBinding?) -> Bool
    init(title: String, binding: HotkeyBinding?, apply: @escaping (HotkeyBinding?) -> Bool) {
        applySelection = apply
        super.init(frame: .zero)
        orientation = .horizontal; spacing = 8
        for (i, choice) in HotkeyBinding.modifierChoices.enumerated() {
            let check = NSButton(checkboxWithTitle: choice.0, target: nil, action: nil)
            check.toolTip = ["Control", "Option", "Shift", "Command"][i]
            check.setAccessibilityLabel(title + " " + check.toolTip!)
            checks.append(check); addArrangedSubview(check)
        }
        keyMenu.addItems(withTitles: [L("hotkey.none")] + HotkeyBinding.keys.map { $0.0 })
        keyMenu.setAccessibilityLabel(L("hotkey.axKey", title))
        keyMenu.widthAnchor.constraint(equalToConstant: 132).isActive = true
        addArrangedSubview(keyMenu)
        let button = NSButton(title: L("hotkey.apply"), target: self, action: #selector(commit))
        button.bezelStyle = .rounded
        button.setAccessibilityLabel(L("hotkey.axApply", title))
        addArrangedSubview(button)
        load(binding)
    }
    required init?(coder: NSCoder) { fatalError() }
    func load(_ binding: HotkeyBinding?) {
        for (index, check) in checks.enumerated() { check.state = (binding?.modifiers ?? 0) & HotkeyBinding.modifierChoices[index].1 != 0 ? .on : .off }
        keyMenu.selectItem(at: binding.flatMap { b in HotkeyBinding.keys.firstIndex { $0.1 == b.key }.map { $0 + 1 } } ?? 0)
    }
    @objc private func commit() {
        let mods = checks.enumerated().reduce(UInt32(0)) { $0 | ($1.element.state == .on ? HotkeyBinding.modifierChoices[$1.offset].1 : 0) }
        let selection = keyMenu.indexOfSelectedItem > 0 ? HotkeyBinding(key: HotkeyBinding.keys[keyMenu.indexOfSelectedItem - 1].1, modifiers: mods) : nil
        if let selection, !selection.valid {
            let alert = NSAlert()
            if selection.isReservedStandard {
                alert.messageText = L("hotkey.reservedTitle", selection.label)
                alert.informativeText = L("hotkey.reservedDetail")
            } else {
                alert.messageText = L("hotkey.needModifier")
            }
            alert.runModal(); return
        }
        if !applySelection(selection) {
            let alert = NSAlert(); alert.messageText = L("hotkey.inUse"); alert.runModal()
        }
    }
}
