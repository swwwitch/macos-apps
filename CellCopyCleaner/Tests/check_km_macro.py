"""Compares CleanRules.swift with the original Keyboard Maestro macro, code point by code point."""
from pathlib import Path
import json, plistlib, subprocess, tempfile
root = Path(__file__).resolve().parents[1]
macro_file = root.parent / 'コピー時、セル内改行使用時に付加される「"」を削除.kmmacros'
if not macro_file.exists():
    print('SKIP: KM macro not found at', macro_file)
    raise SystemExit(0)
group = plistlib.loads(macro_file.read_bytes())[0]
macro = group['Macros'][0]
trigger = macro['Triggers'][0]
assert (trigger['KeyCode'], trigger['Modifiers']) == (8, 2304), trigger  # ⌥⌘C
action = macro['Actions'][0]
assert action['Conditions']['ConditionList'][0]['Application']['BundleIdentifier'] == 'com.microsoft.Excel'
then_ops = [a for a in action['ThenActions'] if a['MacroActionType'] == 'SearchReplace']
else_ops = [a for a in action['ElseActions'] if a['MacroActionType'] == 'SearchReplace']
assert [a['MacroActionType'] for a in action['ThenActions']] == ['CutCopyPaste', 'Filter', 'SearchReplace', 'DeletePastClipboard']
assert action['ThenActions'][1]['Action'] == 'RemoveStyles'
with tempfile.TemporaryDirectory() as work:
    binary = Path(work) / 'dump'
    subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(Path(work) / 'mc'), str(root / 'Sources/CleanRules.swift'),
                    str(root / 'Tests/DumpRules/main.swift'), '-o', str(binary)], check=True)
    rules = json.loads(subprocess.check_output([str(binary)]))
cp = lambda s: [hex(ord(c)) for c in s]
assert then_ops[0]['Action'] == 'IgnoreCaseRegEx' and cp(rules['excel']) == cp(then_ops[0]['Search']) and then_ops[0]['Replace'] == ''
regex_steps = [a for a in else_ops if a['Action'] == 'IgnoreCaseRegEx']
string_steps = [a for a in else_ops if a['Action'] == 'IgnoreCaseString']
assert [[cp(a['Search']), cp(a['Replace'])] for a in regex_steps] == [[cp(p), cp(t)] for p, t in rules['steps']]
assert len(string_steps) == 1 and [cp(string_steps[0]['Search']), cp(string_steps[0]['Replace'])] == [cp(x) for x in rules['apostrophe']]
assert [a for a in else_ops] == regex_steps + string_steps  # order a, b, c, then d
km_targets = sorted(t['BundleIdentifier'] for t in group['Targeting']['TargetingApps'])
assert km_targets == sorted(t[0] for t in rules['targets']), km_targets
print('PASS: rules match the KM macro (Excel', ' '.join(cp(rules['excel'])), '; browser steps a-d; 4 target Bundle IDs; trigger KeyCode 8 / 2304)')
