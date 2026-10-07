from pathlib import Path
import re, subprocess, json
root=Path(__file__).resolve().parents[1]
resources=[]
for language in ('ja','en','zh-Hans','ko'):
    path=root/'Resources'/f'{language}.lproj'/'Localizable.strings'
    data=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(path)]))
    assert all(data.values())
    resources.append(set(data))
assert all(keys == resources[0] for keys in resources)
used=set()
for path in (root/'Sources').glob('*.swift'):
    used.update(re.findall(r'L\("([^"\n]+)"\)',path.read_text()))
assert not used-resources[0], used-resources[0]
print(f'PASS: {len(resources[0])} localization keys in 4 languages; all literal calls covered')
