#!/usr/bin/env python3
"""Place build/PDF2Keynote.app in /Applications and Latest Builds, backing up any previous copy."""
from pathlib import Path
import datetime, hashlib, os, plistlib, shutil, subprocess

root = Path(__file__).resolve().parent
source = root / 'build/PDF2Keynote.app'
dests = [Path('/Applications/PDF2Keynote.app'), root.parent / 'Latest Builds/PDF2Keynote.app']
expected = 'jp.local.PDF2Keynote'

def info(p):
    with open(p / 'Contents/Info.plist', 'rb') as f:
        return plistlib.load(f)

def manifest(p):
    return {str(x.relative_to(p)): (x.stat().st_mode & 0o777, hashlib.sha256(x.read_bytes()).hexdigest()) for x in sorted(p.rglob('*')) if x.is_file()}

assert info(source)['CFBundleIdentifier'] == expected
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(source)], check=True)
for d in dests:
    if d.exists():
        assert info(d)['CFBundleIdentifier'] == expected, f'Bundle ID conflict: {d}'
if subprocess.run(['pgrep', '-f', '/PDF2Keynote.app/Contents/MacOS/PDF2Keynote'], capture_output=True).returncode == 0:
    raise SystemExit('Quit PDF2Keynote before deployment (a conversion may be running).')
backup = root / 'Backups' / ('deployment-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
for i, d in enumerate(dests):
    if d.exists():
        backup.mkdir(parents=True, exist_ok=True)
        shutil.copytree(d, backup / f'{i}-{d.name}', symlinks=True)
        shutil.rmtree(d)
    subprocess.run(['ditto', str(source), str(d)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(d)], check=True)
    assert manifest(d) == manifest(source), f'Content mismatch: {d}'
    inf = info(d)
    print(d, inf['CFBundleShortVersionString'], inf['CFBundleVersion'], 'signature/content match')
