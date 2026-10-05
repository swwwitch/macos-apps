#!/usr/bin/env python3
"""Copy a verified app into Latest Builds, preserving the previous bundle."""
import argparse
import datetime
import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]

def run(*args):
    subprocess.run(args, check=True)

def manifest(root):
    result = {}
    for p in sorted(root.rglob('*')):
        key = str(p.relative_to(root))
        if p.is_symlink():
            result[key] = ('link', os.readlink(p))
        elif p.is_file():
            result[key] = (p.stat().st_mode & 0o777, hashlib.sha256(p.read_bytes()).hexdigest())
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    args = parser.parse_args()
    source = args.app.resolve(strict=True)
    info = plistlib.loads((source / 'Contents/Info.plist').read_bytes())
    if source.suffix != '.app' or ' ' in source.stem:
        parser.error('Use an .app bundle with no spaces in its name.')
    run('codesign', '--verify', '--deep', '--strict', str(source))
    destination = ROOT / 'Latest Builds' / source.name
    destination.parent.mkdir(exist_ok=True)
    if destination.exists() and destination.resolve() == source:
        print('Already published:', destination)
        return
    if destination.exists():
        old = plistlib.loads((destination / 'Contents/Info.plist').read_bytes())
        if old.get('CFBundleIdentifier') != info.get('CFBundleIdentifier'):
            parser.error('Bundle ID differs from the existing app; nothing was replaced.')
        current, incoming = str(old.get('CFBundleVersion', '')), str(info.get('CFBundleVersion', ''))
        if current.isdigit() and incoming.isdigit() and int(incoming) < int(current):
            parser.error(f'Older build {incoming} cannot replace build {current}.')
    staging = Path(tempfile.mkdtemp(prefix='.publish-', dir=destination.parent))
    replacement = staging / source.name
    backup = None
    try:
        run('ditto', '--norsrc', '--noextattr', str(source), str(replacement))
        run('xattr', '-cr', str(replacement))
        run('codesign', '--verify', '--deep', '--strict', str(replacement))
        if manifest(source) != manifest(replacement):
            raise RuntimeError('Copy verification failed; existing app was not replaced.')
        if destination.exists() or destination.is_symlink():
            stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
            backup = ROOT / 'Shared/BuildBackups' / stamp / source.name
            backup.parent.mkdir(parents=True)
            destination.rename(backup)
        try:
            replacement.rename(destination)
        except Exception:
            if backup is not None:
                backup.rename(destination)
            raise
        print('Published and verified:', destination)
    finally:
        shutil.rmtree(staging)

if __name__ == '__main__':
    main()
