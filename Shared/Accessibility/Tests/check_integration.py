from pathlib import Path
import ast
root=Path(__file__).resolve().parents[3]
source=root/'Shared/Accessibility/AccessibilityPermission.swift'
tree=ast.parse((root/'Shared/LoginAtLaunch/sync.py').read_text())
copies=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='copies' for t in n.targets))
targets=copies['Shared/Accessibility/AccessibilityPermission.swift']
private_list=root/'Shared/PrivateApps/targets.txt'
if private_list.exists():
    targets += [t.strip() for t in private_list.read_text().splitlines() if t.strip() and not t.startswith('#') and (root/t.strip()/source.name).is_file()]
for target in targets:
    assert (root/target/source.name).read_bytes()==source.read_bytes(),target
assert 'optionTypeToSelect' not in source.read_text()
assert 'askUserIfNeeded=false' in source.read_text()
assert 'kAXPressAction' not in source.read_text()
assert 'B31' in (root/'Shared/AppStandards/BASELINE.md').read_text()
assert 'B31' in (root/'AGENTS.md').read_text()
for target in ['CommandDee/Sources/main.swift','MightyEdit/Source/main.swift','KeynoteSweeper/Source/main.swift','note2markdown/Source/main.swift']:
    assert 'Privacy_Accessibility' not in (root/target).read_text(),target
print(f'PASS: {len(targets)} canonical copies, normal-click policy, no switch presses, all standalone entry points, future-app rules')
