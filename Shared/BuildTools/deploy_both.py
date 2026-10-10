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
import tempfile

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


def tag_family(app, meta):
    """Our own apps carry SWAppFamily in Info.plist; mirror it as a Finder tag (outside the signed contents)."""
    family = meta.get('SWAppFamily')
    if not family:
        return
    data = plistlib.dumps([f'{family}\n0'], fmt=plistlib.FMT_BINARY)
    subprocess.run(['xattr', '-wx', 'com.apple.metadata:_kMDItemUserTags', data.hex(), str(app)], check=True)


def verify(app):
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = Path(sys.argv[1]).resolve(strict=True)
    meta = info(source)
    bundle_id, version, build = meta['CFBundleIdentifier'], str(meta['CFBundleShortVersionString']), str(meta['CFBundleVersion'])
    verify(source)
    if os.environ.get('NO_DEPLOY') == '1':
        print(f'Verified {source}; deployment skipped (NO_DEPLOY=1).')
        return
    executable = meta['CFBundleExecutable']
    # Match only processes whose command line starts with the executable path (not shells mentioning it).
    running = subprocess.run(['pgrep', '-f', '^.*/' + re.escape(source.name) + '/Contents/MacOS/' + re.escape(executable) + '( |$)'], capture_output=True)
    if running.returncode not in (0, 1):
        sys.exit('Cannot check running applications; nothing was replaced.')
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
    # Stage both copies before replacing either destination. Keep backups for rollback.
    staged, backups, installed = {}, {}, []
    try:
        for label, dest in destinations.items():
            dest.parent.mkdir(parents=True, exist_ok=True)
            stage = Path(tempfile.mkdtemp(prefix='.sw-app-deploy-', dir=dest.parent))
            staged[label] = stage / source.name
            subprocess.run(['ditto', str(source), str(staged[label])], check=True)
            verify(staged[label])
            if manifest(staged[label]) != expected:
                raise RuntimeError(f'Content mismatch while staging {dest}.')
        for label, dest in destinations.items():
            if dest.exists():
                backup = ROOT / 'Shared/Backups/Build' / stamp / label / source.name
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(dest), str(backup))
                backups[label] = backup
            staged[label].rename(dest)
            installed.append(label)
            verify(dest)
            if manifest(dest) != expected:
                raise RuntimeError(f'Content mismatch at {dest}.')
            tag_family(dest, meta)
            print(f'{dest}  {version} ({build})  signature/content match')
    except Exception:
        for label in reversed(list(destinations)):
            dest = destinations[label]
            if label in installed and dest.exists():
                shutil.rmtree(dest)
            if label in backups:
                shutil.move(str(backups[label]), str(dest))
        raise
    finally:
        for path in staged.values():
            shutil.rmtree(path.parent, ignore_errors=True)
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
