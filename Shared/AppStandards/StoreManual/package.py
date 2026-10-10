#!/usr/bin/env python3
"""Sign isolated manual Store candidates; no deployment or upload."""
import argparse, hashlib, importlib.util, plistlib, shutil, subprocess, tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('profile_validation',root/'Shared/AppStore/TestFlight/package.py')
validation=importlib.util.module_from_spec(spec);spec.loader.exec_module(validation)
p=argparse.ArgumentParser();p.add_argument('app',choices=['MightyEdit','KakkoReplace','CommandDee']);p.add_argument('--build',required=True);args=p.parse_args()
name=args.app; source=root/name/'AppStore/StoreBuild'/f'{name}-build{args.build}.app'
profile=root/'Shared/AppStore/Resubmission/20261008/Profiles'/f'{name}.provisionprofile'
output=root/'Shared/AppStore/Resubmission/20261008/Signed'/f'{name}-{args.build}'
if output.exists():raise SystemExit('Refusing existing output')
info=plistlib.loads((source/'Contents/Info.plist').read_bytes())
expected={'MightyEdit':'jp.local.TextPalette','KakkoReplace':'jp.local.SuperKakkoEdit','CommandDee':'jp.local.CommandDee'}[name]
assert info['CFBundleIdentifier']==expected and info['CFBundleName']==name
assert not any(k.startswith('SU') for k in info) and not (source/'Contents/Frameworks/Sparkle.framework').exists()
subprocess.run(['codesign','--verify','--deep','--strict',str(source)],check=True)
rights=plistlib.loads(subprocess.check_output(['codesign','-d','--entitlements',':-',str(source)],stderr=subprocess.PIPE))
assert rights=={'com.apple.security.app-sandbox':True,'com.apple.security.files.user-selected.read-write':True}
d=plistlib.loads(subprocess.check_output(['security','cms','-D','-i',str(profile)],stderr=subprocess.PIPE))
e,team=validation.validate_profile(d,expected,require_beta=False);assert team=='PL9S9PXX96'
for key in ['com.apple.application-identifier','application-identifier','com.apple.developer.team-identifier','beta-reports-active']:
 if key in e:rights[key]=e[key]
with tempfile.TemporaryDirectory(prefix='manual-store-signed-') as temp:
 stage=Path(temp);app=stage/f'{name}.app';shutil.copytree(source,app)
 shutil.copy2(profile,app/'Contents/embedded.provisionprofile')
 info['LSApplicationCategoryType']='public.app-category.productivity'
 (app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
 ent=stage/'rights.plist';ent.write_bytes(plistlib.dumps(rights))
 subprocess.run(['xattr','-cr',str(app)],check=True)
 subprocess.run(['codesign','--force','--sign','301A41C0A37B6B578B7477229015992E8AA34E44','--entitlements',str(ent),str(app)],check=True)
 subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
 prefix=str(stage/'cert');subprocess.run(['codesign','-d','--extract-certificates='+prefix,str(app)],check=True)
 assert (stage/'cert0').read_bytes() in d['DeveloperCertificates']
 pkg=stage/f'{name}.pkg'
 subprocess.run(['productbuild','--component',str(app),'/Applications','--sign','50388060CAB5CD01C725D4A284A7AE0349BCB037',str(pkg)],check=True)
 subprocess.run(['pkgutil','--check-signature',str(pkg)],check=True)
 output.mkdir(parents=True);shutil.copytree(app,output/app.name);shutil.copy2(pkg,output/pkg.name)
 (output/'SHA256.txt').write_text(hashlib.sha256(pkg.read_bytes()).hexdigest()+'  '+pkg.name+'\n')
print(output)
