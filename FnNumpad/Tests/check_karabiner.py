"""Compare Sources/KeyMap.swift with the Karabiner-Elements rule it replaces.
The rule file's path stays out of the repository: FNNUMPAD_KARABINER_RULE, or the first line of
Tests/karabiner-rule-path.local (git-ignored). Skipped when neither gives an existing file."""
from pathlib import Path
import json, os, re, sys
local = Path(__file__).with_name('karabiner-rule-path.local')
value = os.environ.get('FNNUMPAD_KARABINER_RULE') or (local.read_text().splitlines()[0].strip() if local.exists() else '')
rule = Path(value).expanduser() if value else None
if not rule or not rule.exists():
    print('SKIP: Karabiner rule file not set (FNNUMPAD_KARABINER_RULE or Tests/karabiner-rule-path.local)'); sys.exit()
expected = []
for m in json.loads(rule.read_text())['rules'][0]['manipulators']:
    assert m['from']['modifiers'] == {'mandatory': ['fn'], 'optional': ['any']}, m
    expected.append((m['from']['key_code'], [t['key_code'] for t in m['to']]))
source = (Path(__file__).resolve().parents[1] / 'Sources/KeyMap.swift').read_text()
names = {'keypad0': 'keypad_0', 'keypad1': 'keypad_1', 'keypad2': 'keypad_2', 'keypad3': 'keypad_3', 'keypad4': 'keypad_4',
         'keypad5': 'keypad_5', 'keypad6': 'keypad_6', 'keypad7': 'keypad_7', 'keypad8': 'keypad_8', 'keypad9': 'keypad_9',
         'keypadMinus': 'keypad_hyphen', 'keypadEquals': 'keypad_equal_sign', 'keypadMultiply': 'keypad_asterisk',
         'keypadPlus': 'keypad_plus', 'keypadDecimal': 'keypad_period', 'keypadDivide': 'keypad_slash',
         'comma': 'comma', 'tab': 'tab', 'delete': 'delete_or_backspace', 'returnKey': 'return_or_enter', 'keypadEnter': 'keypad_enter'}
actual = [(k, [names[t.strip()] for t in to.split(',')]) for k, to in re.findall(r'karabiner: "([^"]+)", to: \[([^\]]+)\]', source)]
# Keys FnNumpad adds on top of the rule.
extras = [('comma', ['comma']), ('tab', ['keypad_equal_sign']), ('return_or_enter', ['keypad_enter'])]
assert [a for a in actual if a not in extras] == expected, (actual, expected)
assert all(e in actual for e in extras)
# Karabiner key_code → macOS virtual key code for the same physical key.
vk = {'m': 0x2E, 'j': 0x26, 'k': 0x28, 'l': 0x25, 'u': 0x20, 'i': 0x22, 'o': 0x1F, '7': 0x1A, '8': 0x1C, '9': 0x19, '0': 0x1D,
      '1': 0x12, '2': 0x13, '3': 0x14, '4': 0x15, '5': 0x17, '6': 0x16, 'grave_accent_and_tilde': 0x32, 'hyphen': 0x1B,
      'equal_sign': 0x18, 'p': 0x23, 'semicolon': 0x29, 'quote': 0x27, 'period': 0x2F, 'slash': 0x2C, 'n': 0x2D,
      'open_bracket': 0x21, 'comma': 0x2B, 'tab': 0x30, 'return_or_enter': 0x24, 'y': 0x10, 'h': 0x04}
for code, name in re.findall(r'from: (0x[0-9A-F]+), fromLabel: "[^"]*", karabiner: "([^"]+)"', source):
    assert int(code, 16) == vk[name], (name, code)
print(f'PASS: {len(expected)} manipulators match numpad-v4.json (keys, targets, order, virtual key codes), plus {len(extras)} added keys')
