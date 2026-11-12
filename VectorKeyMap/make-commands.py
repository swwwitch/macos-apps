#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds Data/Commands.tsv (kind, ID, group, Japanese name, English name).

Illustrator's "Export Text" lists every command in the reverse order of the same set saved as .kys,
with menu headings in between, so one alignment gives the exact name of every ID (plug-ins included).
Paths come from ExtendScript.txt and English names from Ai Command Palette (MIT).
"""
import csv, re, sys
from pathlib import Path

root = Path(__file__).parent / 'Data'
ENTRY = re.compile(r'/((?:\\.|[^\s{\\])*)\s*\{\s*/Context\s+(\d+)\s*/Modifiers\s+(\d+)\s*/Represent\s+(\d+)\s*/Key\s+(\d+)\s*\}')
GROUPS = ['Illustrator', 'ファイル', '編集', 'オブジェクト', '書式', '選択', '効果', '表示', 'ウィンドウ', 'ヘルプ',
          'その他の選択', 'その他のテキスト', 'その他のオブジェクト', 'その他のパネル', 'その他']


# Submenus whose only path in ExtendScript.txt is English.
SUBMENUS = {'分布', 'ツールバー', 'クロスと重なり', 'パス上オブジェクト', '3D (クラシック)', 'スペルチェック', '書き出し用に追加', 'テキストを更新',
            'AG Utilities', 'VectorScribe', 'XtreamPath3', 'ビューを回転', 'Space Fill', 'Astute Graphics', 'フィルター', 'Dynamic Shapes', '個別の設定'}


# Headings that certainly hold the plug-in commands below them (no path in ExtendScript.txt).
KNOWN_SUBMENUS = {'Space Fill', 'AG Utilities', 'ビューを回転', 'テキストを更新', 'Dynamic Shapes'}

# Same words used for a heading and for a command: (line, nth occurrence). Checked by hand against the menus.
HEADING_LINES = [('モックアップ', 0), ('XtreamPath3', 2), ('Astute Graphics', 0)]
ITEM_LINES = [('ヘルプ', 0), ('Space Fill', 1), ('モックアップ', 1)]


def occurrence(lines, text, nth):
    return [i for i, line in enumerate(lines) if line == text][nth]


def unescape(raw):
    data, out, i = raw.encode(), bytearray(), 0
    while i < len(data):
        if data[i] == 92 and i + 1 < len(data):
            digits = data[i + 1:i + 4]
            if len(digits) == 3 and all(48 <= c <= 55 for c in digits):
                out.append(int(digits, 8) & 255); i += 4; continue
            out.append(data[i + 1]); i += 2; continue
        out.append(data[i]); i += 1
    return out.decode('utf8', 'replace')


def parse_kys(path):
    text = path.read_text(encoding='utf8', errors='replace')
    split = text.find('/Tools {')
    sets = {'menu': [], 'tool': []}
    for m in ENTRY.finditer(text):
        sets['tool' if m.start() > split else 'menu'].append((unescape(m.group(1)), int(m.group(3)), int(m.group(5))))
    return sets


def shortcut(mods, key):
    if not key: return ''
    name = f'F{key - 13}' if 14 <= key <= 25 else 'Tab' if key == 9 else chr(key).upper()
    return ('Opt+' if mods & 128 else '') + ('Shift+' if mods & 32 else '') + ('Cmd+' if mods & 64 else '') + name


def known_paths():
    paths = {}
    for line in (root / 'ExtendScript.txt').read_text(encoding='utf8').splitlines():
        cols = line.split('\t')
        if len(cols) >= 2 and cols[0] and cols[1] and not line.startswith('//') and cols[1] not in paths:
            paths[cols[1]] = cols[0]
    return paths


def leaf(path):
    return re.sub(r'(\.\.\.|…)$', '', path.split(' > ')[-1]).strip()


def forced_groups(lines):
    """Line numbers of the top-level headings, found in order."""
    found, start = {}, 0
    for group in GROUPS:
        # The Help menu follows a panel-side item also called ヘルプ, so take the last one before その他の選択.
        index = lines.index(group, start) if group != 'ヘルプ' else max(i for i in range(start, lines.index('その他の選択')) if lines[i] == group)
        found[index] = group
        start = index + 1
    return found


def align(lines, items, paths):
    """Monotonic alignment: every item takes one line, and the lines left over are menu headings."""
    n, m = len(lines), len(items)
    NEG = -1e9
    forced = set(forced_groups(lines)) | {occurrence(lines, *pair) for pair in HEADING_LINES}
    taken = {occurrence(lines, *pair) for pair in ITEM_LINES}
    parents = {part.strip() for path in paths.values() for part in path.split(' > ')[:-1]} | SUBMENUS
    def score(line, item):
        ident, mods, key = item
        text = shortcut(mods, key)
        matched = bool(text) and line.endswith(text)
        name = line[:-len(text)] if matched else line
        value = 5 if matched else -30 if text else 0
        if ident in paths and leaf(paths[ident]) == name.strip():
            value += 10
        elif name.strip() in parents:
            value -= 6
        elif ident in paths:
            value -= 1
        return value
    def parent(j):
        path = paths.get(items[j][0], '')
        return ' > '.join(path.split(' > ')[:-1]) if ' > ' in path else None
    def bridge(j):
        """A heading sits between two items only when they are in different submenus."""
        if j == 0 or j == m: return 0
        a, b = parent(j - 1), parent(j)
        if a is None or b is None: return 0
        return -4 if a == b else 0.5
    # state 0: the previous line took an item, state 1: the previous line was a heading.
    # Two headings in a row are rare (a heading has items), so they cost more than one.
    best = [[[NEG, NEG] for _ in range(m + 1)] for _ in range(n + 1)]
    back = [[[None, None] for _ in range(m + 1)] for _ in range(n + 1)]
    best[0][0][0] = 0
    for i in range(1, n + 1):
        for j in range(0, min(i, m) + 1):
            for state in (0, 1):
                value = best[i - 1][j][state]
                if value <= NEG / 2 or i - 1 in taken: continue
                value += bridge(j) - (3 if state else 0)
                if value >= best[i][j][1]:
                    best[i][j][1], back[i][j][1] = value, (j, state)
            if j and i - 1 not in forced:
                gain = score(lines[i - 1], items[j - 1])
                for state in (0, 1):
                    value = best[i - 1][j - 1][state]
                    if value <= NEG / 2: continue
                    if value + gain >= best[i][j][0]:
                        best[i][j][0], back[i][j][0] = value + gain, (j - 1, state)
    assert max(best[n][m]) > NEG / 2, 'alignment failed'
    i, j, state = n, m, 0 if best[n][m][0] >= best[n][m][1] else 1
    pairs, headings = {}, []
    while i:
        previous_j, previous_state = back[i][j][state]
        if state == 0: pairs[j - 1] = i - 1
        else: headings.append(i - 1)
        i, j, state = i - 1, previous_j, previous_state
    return pairs, sorted(headings)


def main():
    sets = parse_kys(root / 'IllustratorDefault.kys')
    raw = (root / 'IllustratorDefault.txt').read_bytes().decode('utf8').split('\r')
    split = raw.index('メニューコマンド')
    tool_lines = [line for line in raw[1:split] if line.strip()]
    menu_lines = [line for line in raw[split + 1:] if line.strip()]
    tools = sets['tool'][::-1]
    # debugPalette is the only ID the text leaves out.
    menus = [item for item in sets['menu'][::-1] if item[0] != 'debugPalette']
    assert len(tool_lines) == len(tools), (len(tool_lines), len(tools))
    paths = known_paths()
    english = {}
    for name in ('AiCommandPalette-menu_commands.csv', 'AiCommandPalette-tool_commands.csv'):
        with open(root / name, encoding='utf8', newline='') as f:
            for row in csv.DictReader(f):
                if row['en']: english.setdefault(row['value'], row['en'])
    rows = []
    for line, (ident, mods, key) in zip(tool_lines, tools):
        rows.append(('tool', ident, 'ツール', line.split('\t')[0], english.get(ident, '')))
    pairs, headings = align(menu_lines, menus, paths)
    heading_set = set(headings)
    groups = forced_groups(menu_lines)
    current, group_of = '', {}
    for index in range(len(menu_lines)):
        current = groups.get(index, current); group_of[index] = current
    agree = disagree = 0
    for item_index, (ident, mods, key) in enumerate(menus):
        index = pairs[item_index]
        text = shortcut(mods, key)
        name = menu_lines[index][:-len(text)] if text and menu_lines[index].endswith(text) else menu_lines[index]
        path = paths.get(ident, '')
        if path:
            if leaf(path) == name.strip(): agree += 1
            else:
                disagree += 1
                if '-v' in sys.argv: print('differs', ident, '|', name, '|', path)
        name = name.strip()
        parts = [part.strip() for part in path.split(' > ')]
        nearest = next((menu_lines[i] for i in range(index - 1, -1, -1) if i in heading_set), '')
        if len(parts) > 2 and parts[0] == group_of[index] and leaf(path) == name:
            name = ' > '.join(parts[1:-1] + [name])            # Japanese path in the table
        elif len(parts) > 2 and nearest != group_of[index]:
            name = f'{nearest} > {name}'                       # English path or renamed: the heading above it
        elif not path and nearest in KNOWN_SUBMENUS:
            name = f'{nearest} > {name}'
        rows.append(('menu', ident, group_of[index], name, english.get(ident, '')))
    rows.append(('menu', 'debugPalette', 'その他', 'デバッグパネル (2)', ''))
    with open(root / 'Commands.tsv', 'w', encoding='utf8', newline='') as f:
        for row in rows: f.write('\t'.join(row) + '\n')
    print(f'{len(rows)} commands, {len(headings)} headings, ExtendScript names agree {agree} / differ {disagree}, English {sum(1 for r in rows if r[4])}')


main()
