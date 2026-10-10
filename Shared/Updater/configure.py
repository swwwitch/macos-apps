#!/usr/bin/env python3
"""Embed Sparkle, with a fail-closed optional PUBLIC configuration plist."""
import base64
import os
from pathlib import Path
import plistlib
import subprocess
import sys
from urllib.parse import urlsplit

def validate(config):
    if set(config) != {'SUFeedURL', 'SUPublicEDKey'}:
        raise ValueError('Config must contain exactly SUFeedURL and SUPublicEDKey')
    url = urlsplit(config['SUFeedURL'])
    if url.scheme != 'https' or not url.hostname or url.username or url.password or url.fragment:
        raise ValueError('A credential-free HTTPS feed URL is required')
    if url.hostname in ('localhost', 'example.com', 'example.org', 'example.net') or url.hostname.endswith(('.example', '.invalid', '.localhost')):
        raise ValueError('A real distribution host is required')
    key = base64.b64decode(config['SUPublicEDKey'], validate=True)
    if len(key) != 32 or not any(key):
        raise ValueError('A valid 32-byte public Ed25519 key is required')
    return config

def saved_public_key(bundle_id):
    path = Path(__file__).resolve().parent/'PublicKeys'/(bundle_id + '.plist')
    if not path.exists():
        return None
    config = plistlib.loads(path.read_bytes())
    if set(config) != {'SUPublicEDKey'}:
        raise ValueError('Public key file must contain only SUPublicEDKey')
    key = config['SUPublicEDKey']
    decoded = base64.b64decode(key, validate=True)
    if len(decoded) != 32 or not any(decoded):
        raise ValueError('Invalid saved public key')
    return key

def configure(app, sdk):
    path = app/'Contents/Info.plist'
    info = plistlib.loads(path.read_bytes())
    for key in list(info):
        if key.startswith(('SU', 'SPU')): del info[key]
    config_file = os.environ.get('UPDATE_PUBLIC_CONFIG')
    if config_file:
        info.update(validate(plistlib.loads(Path(config_file).read_bytes())))
        print('Signed update configuration included for', info['CFBundleIdentifier'])
    else:
        key = saved_public_key(info['CFBundleIdentifier'])
        if key:
            info['SUPublicEDKey'] = key
        print('Updates unconfigured (no feed; no network checks):', info['CFBundleIdentifier'])
    info.update(SUVerifyUpdateBeforeExtraction=True, SURequireSignedFeed=True, SUSignedFeedFailureExpirationInterval=0,
                SUPromptUserOnFirstLaunch=True, SUAllowsAutomaticUpdates=False,
                SUAutomaticallyUpdate=False, SUEnableSystemProfiling=False,
                SUShowReleaseNotes=False)
    path.write_bytes(plistlib.dumps(info,sort_keys=False))
    dest=app/'Contents/Frameworks/Sparkle.framework'
    dest.parent.mkdir(parents=True,exist_ok=True)
    subprocess.run(['ditto',str(sdk/'Sparkle.framework'),str(dest)],check=True)
    subprocess.run(['xattr','-cr',str(dest)],check=True)
    # Locally built apps remain ad-hoc. Release signing must sign nested code inside-out.
    subprocess.run(['codesign','--force','--deep','--sign','-',str(dest)],check=True)
if __name__ == '__main__': configure(Path(sys.argv[1]),Path(sys.argv[2]))
