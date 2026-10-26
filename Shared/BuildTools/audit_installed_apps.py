#!/usr/bin/env python3
"""Read-only audit of managed installed apps; never launches or replaces apps."""
import argparse
import concurrent.futures
import datetime
import json
import os
from pathlib import Path
import plistlib
import subprocess
from deploy_both import manifest
from distribution_paths import latest_builds_dir


def inspect(app):
    row = {'path': str(app), 'issues': []}
    if not app.exists():
        row['issues'].append('app_missing')
        return row
    try:
        meta = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        for key in ('CFBundleIdentifier', 'CFBundleShortVersionString', 'CFBundleVersion', 'CFBundleExecutable'):
            row[key] = meta.get(key)
        executable = meta.get('CFBundleExecutable')
        binary = app / 'Contents/MacOS' / (executable or '')
        if not executable or not binary.is_file():
            row['issues'].append('executable_missing')
        elif not os.access(binary, os.X_OK):
            row['issues'].append('executable_not_executable')
        else:
            result = subprocess.run(['file', '-b', str(binary)], capture_output=True, text=True, timeout=20)
            row['executable_format'] = result.stdout.strip()
        result = subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], capture_output=True, text=True, timeout=90)
        row['signature_valid'] = result.returncode == 0
        if result.returncode:
            row['issues'].append('signature_invalid')
            row['signature_error'] = result.stderr.strip()
    except (OSError, ValueError, plistlib.InvalidFileException, subprocess.TimeoutExpired) as error:
        row['issues'].append('inspection_failed')
        row['error'] = str(error)
    return row


def audit_pair(name, latest, applications):
    left, right = inspect(applications / name), inspect(latest / name)
    row = {'app': name, 'Applications': left, 'LatestBuilds': right}
    if (applications / name).is_dir() and (latest / name).is_dir():
        try:
            row['content_matches'] = manifest(applications / name) == manifest(latest / name)
        except OSError as error:
            row['comparison_error'] = str(error)
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    latest, applications = latest_builds_dir(), Path('/Applications')
    names = {p.name for p in latest.glob('*.app')}
    # Also include managed apps that are absent from Latest Builds.
    for app in applications.glob('*.app'):
        try:
            meta = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
            if meta.get('SWAppFamily'):
                names.add(app.name)
        except (OSError, ValueError, plistlib.InvalidFileException):
            pass
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(lambda name: audit_pair(name, latest, applications), sorted(names)))
    report = {'checked_at': datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(),
              'scope': 'Latest Builds top-level apps and /Applications apps with SWAppFamily',
              'read_only': True, 'apps': rows}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f'Checked {len(rows)} apps; report: {args.output}')
    for row in rows:
        issues = [f'{label}: {",".join(row[label]["issues"])}' for label in ('Applications', 'LatestBuilds') if row[label]['issues']]
        if row.get('content_matches') is False:
            issues.append('content_mismatch')
        if issues:
            print(row['app'] + ': ' + '; '.join(issues))


if __name__ == '__main__':
    main()
