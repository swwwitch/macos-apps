from pathlib import Path
import plistlib,subprocess,datetime,shutil,hashlib
root=Path(__file__).resolve().parent
source=root/'build/CarmaChameleon.app'
dests=[Path('/Applications/CarmaChameleon.app'),root.parent/'Latest Builds/CarmaChameleon.app']
expected='jp.local.PandocDesk'
def info(p):
 with open(p/'Contents/Info.plist','rb') as f:return plistlib.load(f)
def manifest(p):
 return {str(x.relative_to(p)):hashlib.sha256(x.read_bytes()).hexdigest() for x in p.rglob('*') if x.is_file()}
assert info(source)['CFBundleIdentifier']==expected
for d in dests:
 if d.exists(): assert info(d)['CFBundleIdentifier']==expected, f'Bundle ID conflict: {d}'
result=subprocess.run(['pgrep','-f','/CarmaChameleon.app/Contents/MacOS/CarmaChameleon'],capture_output=True,text=True)
if result.returncode==0:raise RuntimeError('Quit CarmaChameleon before deployment')
backup=root/'Backups'/('deployment-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
for i,d in enumerate(dests):
 if d.exists():
  backup.mkdir(parents=True,exist_ok=True);shutil.copytree(d,backup/str(i));shutil.rmtree(d)
 subprocess.run(['ditto',str(source),str(d)],check=True)
 subprocess.run(['codesign','--verify','--deep','--strict',str(d)],check=True)
 assert manifest(d)==manifest(source)
 inf=info(d);print(d,inf['CFBundleShortVersionString'],inf['CFBundleVersion'],'signature/content match')
