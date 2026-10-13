#!/usr/bin/env python3
"""Validate the app-specific distribution profile; never reuse another app's profile."""
import datetime, os, pathlib, plistlib, subprocess, sys
app=pathlib.Path(sys.argv[1]); out=pathlib.Path(sys.argv[2])
ent=plistlib.loads(pathlib.Path('Store/App.entitlements').read_bytes())
if os.environ.get('CARMACHAMELEON_STORE_QA') != '1':
    profile_path=os.environ.get('CARMACHAMELEON_STORE_PROFILE','')
    if not profile_path: sys.exit('Store distribution requires CARMACHAMELEON_STORE_PROFILE. For local QA only, set CARMACHAMELEON_STORE_QA=1.')
    profile=pathlib.Path(profile_path)
    data=subprocess.check_output(['security','cms','-D','-i',str(profile)])
    p=plistlib.loads(data); e=p['Entitlements']
    appid=e.get('com.apple.application-identifier',e.get('application-identifier',''))
    bundle=plistlib.loads((app/'Contents/Info.plist').read_bytes())['CFBundleIdentifier']
    if appid != 'PL9S9PXX96.'+bundle or p.get('TeamIdentifier') != ['PL9S9PXX96']: sys.exit('Profile does not match CarmaChameleon and the signing team.')
    if p['ExpirationDate'] <= datetime.datetime.utcnow(): sys.exit('Profile expired.')
    if e.get('get-task-allow') or e.get('com.apple.security.get-task-allow') or p.get('ProvisionsAllDevices') or p.get('ProvisionedDevices'):
        sys.exit('An App Store distribution profile is required, not a development or direct-distribution profile.')
    for key in ['com.apple.application-identifier','application-identifier','com.apple.developer.team-identifier']:
        if key in e: ent[key]=e[key]
    (app/'Contents/embedded.provisionprofile').write_bytes(profile.read_bytes())
out.write_bytes(plistlib.dumps(ent))
