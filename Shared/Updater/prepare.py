#!/usr/bin/env python3
"""Download an exact upstream SDK after checksum verification; never creates keys."""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import urllib.request
VERSION = '2.10.0'
SHA256 = 'c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c'
ROOT = Path(__file__).resolve().parent
TARGETS = ['BrowserSwitcher/Source', 'DutiGUI/Sources/DutiGUI', 'FolderHopper/Development/Source', 'SoftShadow/Sources', 'Toki/Development/Sources/Toki', 'mac-png/Sources/IconDrop']

def prepare():
    for target in TARGETS:
        if (ROOT.parents[1]/target/'UpdateSupport.swift').read_bytes() != (ROOT/'UpdateSupport.swift').read_bytes():
            raise SystemExit('Updater source drift: ' + target)
    cache = ROOT/'vendor'/VERSION
    if (cache/'Sparkle.framework').is_dir():
        return cache
    cache.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=cache.parent) as temp:
        stage = Path(temp)
        archive = stage/'Sparkle.tar.xz'
        local = os.environ.get('SPARKLE_ARCHIVE')
        if local:
            archive.write_bytes(Path(local).read_bytes())
        else:
            urllib.request.urlretrieve(f'https://github.com/sparkle-project/Sparkle/releases/download/{VERSION}/Sparkle-{VERSION}.tar.xz', archive)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
            raise SystemExit('Sparkle checksum mismatch')
        extracted = stage/'sdk'; extracted.mkdir()
        subprocess.run(['tar','-xf',str(archive),'-C',str(extracted)],check=True)
        subprocess.run(['codesign','--verify','--deep','--strict',str(extracted/'Sparkle.framework')],check=True)
        extracted.rename(cache)
    return cache
if __name__ == '__main__': print(prepare())
