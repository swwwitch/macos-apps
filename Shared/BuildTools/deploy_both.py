#!/usr/bin/env python3
"""Place a verified app in /Applications and Latest Builds (AGENTS.md / BASELINE B18).

- Refuses if an existing copy has a different Bundle ID or a newer integer build.
- Refuses while the app is running (quit it first; a busy app refuses to quit by itself).
- Backs up existing copies to Shared/Backups/Build/<stamp>/{Applications,LatestBuilds}/.
- Verifies the signature and that every file (mode + SHA-256) matches the source.
- Updates the app's row in Latest Builds/README.md (version, build).
Usage: deploy_both.py path/to/Name.app
"""
import datetime
import hashlib
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def info(app):
    return plistlib.loads((app / 'Contents/Info.plist').read_bytes())


def manifest(app):
    result = {}
    for p in sorted(app.rglob('*')):
        key = str(p.relative_to(app))
        if p.is_symlink():
            result[key] = ('link', os.readlink(p))
        elif p.is_file():
            result[key] = (p.stat().st_mode & 0o777, hashlib.sha256(p.read_bytes()).hexdigest())
    return result


def verify(app):
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = Path(sys.argv[1]).resolve(strict=True)
    meta = info(source)
    bundle_id, version, build = meta['CFBundleIdentifier'], str(meta['CFBundleShortVersionString']), str(meta['CFBundleVersion'])
    verify(source)
    executable = meta['CFBundleExecutable']
    running = subprocess.run(['pgrep', '-f', f'/{source.name}/Contents/MacOS/{executable}'], capture_output=True)
    if running.returncode == 0:
        sys.exit(f'{source.stem} is running; quit it before deployment.')
    destinations = {'Applications': Path('/Applications') / source.name, 'LatestBuilds': ROOT / 'Latest Builds' / source.name}
    for dest in destinations.values():
        if dest.exists():
            old = info(dest)
            if old.get('CFBundleIdentifier') != bundle_id:
                sys.exit(f'Bundle ID differs at {dest}; nothing was replaced.')
            current = str(old.get('CFBundleVersion', ''))
            if current.isdigit() and build.isdigit() and int(build) < int(current):
                sys.exit(f'Build {build} is older than {current} at {dest}; nothing was replaced.')
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    expected = manifest(source)
    for label, dest in destinations.items():
        if dest.exists():
            backup = ROOT / 'Shared/Backups/Build' / stamp / label / source.name
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(dest), str(backup))
        subprocess.run(['ditto', str(source), str(dest)], check=True)
        verify(dest)
        if manifest(dest) != expected:
            sys.exit(f'Content mismatch at {dest}.')
        print(f'{dest}  {version} ({build})  signature/content match')
    readme = ROOT / 'Latest Builds/README.md'
    text = readme.read_text()
    row = re.compile(r'^\| \[' + re.escape(source.stem) + r'\]\(' + re.escape(source.name) + r'\) \| [^|]* \| [^|]* \|', re.M)
    updated, count = row.subn(f'| [{source.stem}]({source.name}) | {version} | {build} |', text)
    if count:
        readme.write_text(updated)
        print('Latest Builds/README.md updated')
    else:
        print('Latest Builds/README.md has no row for', source.stem, '- add it by hand')


if __name__ == '__main__':
    main()
