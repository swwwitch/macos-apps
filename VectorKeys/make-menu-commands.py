# Builds Resources/MenuCommands.tsv (menu path <TAB> executeMenuCommand ID) from the user's AT-doc/ExtendScript.txt.
# The source is only read. Rows with a menu path (" > ") and an ID are kept; ones noted 廃止 (removed) are left out.
from pathlib import Path
import sys
source = Path(sys.argv[1] if len(sys.argv) > 1 else
              Path.home() / 'sw Dropbox/takano masahiro/Dropbox-shared/AT-doc/ExtendScript.txt')
rows, seen = [], set()
for line in source.read_text(encoding='utf-8').splitlines():
    cols = line.split('\t')
    if len(cols) not in (2, 3) or cols[0].startswith('//') or ' > ' not in cols[0]:
        continue
    path, command = cols[0].strip(), cols[1].strip()
    if not command or (len(cols) == 3 and cols[2].startswith('廃止')) or (path, command) in seen:
        continue
    seen.add((path, command)); rows.append(f'{path}\t{command}')
out = Path(__file__).parent / 'Resources' / 'MenuCommands.tsv'
out.write_text('\n'.join(rows) + '\n', encoding='utf-8')
print('menu commands:', len(rows))
