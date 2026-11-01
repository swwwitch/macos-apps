#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/textlens-icon.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swift -module-cache-path "$stage/cache" make-icon.swift TextLens.png
python3 - <<'PY'
from pathlib import Path
import subprocess, tempfile, struct
with tempfile.TemporaryDirectory() as work:
    parts=[]
    for tag,n in [('icp4',16),('icp5',32),('icp6',64),('ic07',128),('ic08',256),('ic09',512),('ic10',1024)]:
        dest=Path(work)/f'{n}.png'
        subprocess.run(['sips','-z',str(n),str(n),'TextLens.png','--out',str(dest)],check=True,stdout=subprocess.DEVNULL)
        data=dest.read_bytes();parts.append(tag.encode()+struct.pack('>I',len(data)+8)+data)
    body=b''.join(parts)
    Path('TextLens.icns').write_bytes(b'icns'+struct.pack('>I',len(body)+8)+body)
PY
