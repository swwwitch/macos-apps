# ICNS PNG representations; avoids iconutil failures on headless build hosts.
from pathlib import Path
import struct, subprocess, tempfile
base=Path(__file__).resolve().parent
chunks=[]
with tempfile.TemporaryDirectory() as work:
    for kind,size in [('icp4',16),('icp5',32),('icp6',64),('ic07',128),('ic08',256),('ic09',512),('ic10',1024)]:
        output=Path(work)/f'{size}.png'
        subprocess.run(['sips','-z',str(size),str(size),str(base/'KakkoReplace.png'),'--out',str(output)],check=True,stdout=subprocess.DEVNULL)
        data=output.read_bytes()
        chunks.append(kind.encode()+struct.pack('>I',len(data)+8)+data)
body=b''.join(chunks)
(base/'KakkoReplace.icns').write_bytes(b'icns'+struct.pack('>I',len(body)+8)+body)
