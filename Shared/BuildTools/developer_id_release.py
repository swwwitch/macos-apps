#!/usr/bin/env python3
"""Explicit inside-out Developer ID signing and app notarization. Never invokes --deep."""
import argparse, hashlib, json, os, pathlib, plistlib, subprocess, sys, tempfile
IDENTITY = 'Developer ID Application: masahiro takano (PL9S9PXX96)'
MAGIC = {bytes.fromhex(x) for x in ('cffaedfe','cefaedfe','feedfacf','feedface','cafebabe','bebafeca','cafebabf','bfbafeca')}
def run(args, **kw):
    return subprocess.run([str(x) for x in args], check=True, **kw)
def code_nodes(app):
    nodes=[]
    for p in app.rglob('*'):
        if p.is_symlink(): continue
        if p.is_dir() and p.suffix in ('.app','.framework','.xpc','.appex','.bundle'):
            if p.suffix != '.bundle' or (p/'Contents/MacOS').exists(): nodes.append(p)
        elif p.is_file():
            with p.open('rb') as f: magic=f.read(4)
            if magic in MAGIC: nodes.append(p)
    return sorted(nodes, key=lambda p: len(p.parts), reverse=True)
def sign_one(path, temp, explicit=None):
    ent={}
    prior=subprocess.run(['/usr/bin/codesign','-d','--entitlements',':-',str(path)],capture_output=True)
    try: ent=plistlib.loads(prior.stdout)
    except Exception: pass
    if explicit: ent.update(plistlib.loads(pathlib.Path(explicit).read_bytes()))
    if path.suffix == '.app':
        info=plistlib.loads((path/'Contents/Info.plist').read_bytes())
        if info.get('NSAppleEventsUsageDescription'): ent['com.apple.security.automation.apple-events']=True
    ent.pop('com.apple.security.get-task-allow',None)
    cmd=['/usr/bin/codesign','--force','--sign',IDENTITY,'--options','runtime','--timestamp']
    if ent:
        f=temp/(hashlib.sha256(str(path).encode()).hexdigest()+'.plist')
        f.write_bytes(plistlib.dumps(ent)); cmd+=['--entitlements',f]
    run(cmd+[path])
def sign(path, explicit=None):
    with tempfile.TemporaryDirectory(dir='/private/tmp') as folder:
        temp=pathlib.Path(folder)
        nodes=code_nodes(path) if path.is_dir() else []
        for node in nodes: sign_one(node,temp)
        sign_one(path,temp,explicit)
        for node in nodes+[path]: run(['/usr/bin/codesign','--verify','--strict',node])
    details=run(['/usr/bin/codesign','-dv','--verbose=4',path],capture_output=True).stderr.decode()
    if 'Authority='+IDENTITY not in details or 'runtime' not in details or 'Timestamp=' not in details:
        raise RuntimeError('Developer ID / runtime / timestamp verification failed: '+str(path))
def notarize(app, out, profile):
    info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
    name=app.stem; version=info['CFBundleShortVersionString']; build=info['CFBundleVersion']
    folder=out/name; folder.mkdir(parents=True,exist_ok=True)
    archive=folder/f'{name}-{version}-build{build}.zip'
    if archive.exists(): raise RuntimeError('Refusing to overwrite notarization ZIP: '+str(archive))
    run(['ditto','-c','-k','--keepParent',app,archive])
    response=subprocess.run(['xcrun','notarytool','submit',str(archive),'--keychain-profile',profile,'--wait','--output-format','json'],capture_output=True,text=True)
    (folder/'notary-submit.json').write_text(response.stdout)
    (folder/'notary-stderr.txt').write_text(response.stderr)
    response.check_returncode(); result=json.loads(response.stdout)
    if result['status'] != 'Accepted':
        run(['xcrun','notarytool','log',result['id'],'--keychain-profile',profile,folder/'notary-log.json'])
        raise RuntimeError('Notarization '+result['status']+'; see '+str(folder/'notary-log.json'))
    run(['xcrun','stapler','staple',app]); run(['xcrun','stapler','validate',app])
    gate=run(['spctl','-a','-vv',app],capture_output=True)
    output=gate.stdout.decode()+gate.stderr.decode()
    (folder/'gatekeeper.txt').write_text(output)
    if 'Notarized Developer ID' not in output: raise RuntimeError('Gatekeeper did not confirm notarization')
    return {'app':name,'version':version,'build':build,'submission_id':result['id'],'status':'Accepted','zip':str(archive),'zip_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'gatekeeper':output}
def wrapper(args):
    # Only this explicit release run prepends the wrapper to PATH. Existing build scripts stay intact.
    args=[a for a in args if a != '--deep']
    if '--sign' not in args:
        run(['/usr/bin/codesign']+args); return
    path=pathlib.Path(args[-1]).resolve()
    explicit=args[args.index('--entitlements')+1] if '--entitlements' in args else None
    sign(path,explicit)
    if path.suffix == '.app' and not any(p.suffix == '.app' for p in path.parents):
        out=pathlib.Path(os.environ['RELEASE_OUTPUT'])/'SignedApps'/path.name
        out.parent.mkdir(parents=True,exist_ok=True)
        if out.exists(): raise RuntimeError('Refusing to overwrite signed snapshot: '+str(out))
        run(['ditto',path,out]); print('SIGNED_SNAPSHOT',out,flush=True)
if __name__ == '__main__':
    if len(sys.argv)>1 and sys.argv[1]=='codesign-wrapper': wrapper(sys.argv[2:])
    else:
        p=argparse.ArgumentParser(); p.add_argument('app',type=pathlib.Path); p.add_argument('--output',required=True,type=pathlib.Path); p.add_argument('--profile',default='notary'); p.add_argument('--sign-only',action='store_true'); a=p.parse_args()
        sign(a.app)
        if not a.sign_only:
            result=notarize(a.app,a.output,a.profile); (a.output/a.app.stem/'result.json').write_text(json.dumps(result,indent=2)+'\n')
