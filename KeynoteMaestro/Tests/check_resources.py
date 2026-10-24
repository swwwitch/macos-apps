from pathlib import Path
import re, subprocess, json
root=Path(__file__).resolve().parents[1]
resources=[]
for language in ('ja','en','zh-Hans','ko'):
    path=root/'Resources'/f'{language}.lproj'/'Localizable.strings'
    data=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(path)]))
    assert all(data.values()), language
    # Format placeholders must match the Japanese source.
    if language == 'ja': base = data
    for key, value in data.items():
        assert value.count('%@') == base[key].count('%@'), (language, key)
    resources.append(set(data))
assert all(keys == resources[0] for keys in resources)
used=set()
for path in (root/'Sources').glob('*.swift'):
    text = path.read_text()
    used.update(re.findall(r'L\("([^"\n]+)"\)',text))
    # Keys chosen with a ternary inside L(...).
    for inner in re.findall(r'\bL\(([^()\n]*\? *"[^()\n]*)\)', text):
        used.update(re.findall(r'"([^"\n]+)"', inner))
assert not used-resources[0], used-resources[0]
print(f'PASS: {len(resources[0])} localization keys in 4 languages; placeholders match; all literal calls covered ({len(used)} used)')

expected_palette = ["ディゾルブ", "なし", "マジックムーブ", "マジックムーブ（自動）", "スライドの幅いっぱい", "スライドの高さいっぱい", "スライドの幅の80%", "同じ高さに（最大）", "同じ幅に（最大）", "同じ幅に（最小）", "アニメーションをコピー", "アニメーションをペースト", "スライドと同じ大きさの図形を作成", "選択オブジェクトに背景の図形を追加（グループ化）"]
palette_keys = ['transitionDissolve', 'transitionNone', 'transitionMagicMove', 'autoMagicMove', 'fillWidth', 'fillHeight', 'width80', 'sameHeight', 'sameWidth', 'sameWidthNarrowest', 'copyAnimation', 'pasteAnimation', 'slideSizeShape', 'whiteBackground']
assert [base['palette.' + key] for key in palette_keys] == expected_palette
assert [base['palette.' + key] for key in ['transitionHeading', 'centerHeading', 'alignHeading']] == ['トランジション', '中央', 'オブジェクトの揃え']
assert all('palette.' + key in resources[0] for key in palette_keys)
print('PASS: exact Japanese palette button labels, section headings and four-language coverage')
