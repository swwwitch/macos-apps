#!/usr/bin/env python3
"""Compile using the installed Keynote dictionary even if Launch Services is stale."""
import pathlib
import subprocess
import sys
import tempfile

source = pathlib.Path(__file__).with_name('Keynote.applescript')
result = subprocess.run(['osacompile', '-o', sys.argv[1], str(source)], capture_output=True)
if result.returncode:
    keynote = pathlib.Path('/Applications/Keynote.app')
    if not keynote.is_dir():
        sys.stderr.buffer.write(result.stderr)
        sys.exit(result.returncode)
    with tempfile.TemporaryDirectory(prefix='keynote-compile-') as folder:
        fallback = pathlib.Path(folder) / 'Keynote.applescript'
        fallback.write_text(source.read_text().replace('application id "com.apple.Keynote"', 'application "/Applications/Keynote.app"'))
        subprocess.run(['osacompile', '-o', sys.argv[1], str(fallback)], check=True)
