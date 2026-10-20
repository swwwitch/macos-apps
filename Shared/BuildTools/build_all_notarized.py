#!/usr/bin/env python3
"""Run each existing app build with explicit inside-out Developer ID signing; stage before deployment."""
import argparse, concurrent.futures, datetime, json, os, pathlib, shlex, subprocess, sys
ROOT=pathlib.Path(__file__).resolve().parents[2]
def entries():
    result=[]
    for folder in sorted(ROOT.iterdir()):
        if not folder.is_dir() or folder.name in ('Shared','Latest Builds','Unsorted','.git'): continue
        candidates=[folder/'build.sh',folder/'Development/build.sh',folder/'Development/build-app.sh']
        found=[p for p in candidates if p.is_file()]
        if found: result.append(found[0])
    return result
def main():
    p=argparse.ArgumentParser(); p.add_argument('--output',type=pathlib.Path,required=True); p.add_argument('--apps',nargs='*'); a=p.parse_args()
    out=a.output.resolve(); out.mkdir(parents=True,exist_ok=True)
    shim=out/'bin'; shim.mkdir(exist_ok=True)
    helper=ROOT/'Shared/BuildTools/developer_id_release.py'
    (shim/'codesign').write_text('#!/bin/sh\nexec /usr/bin/python3 '+shlex.quote(str(helper))+' codesign-wrapper "$@"\n'); (shim/'codesign').chmod(0o755)
    env=os.environ.copy(); env.update(PATH=str(shim)+':'+env['PATH'],NO_DEPLOY='1',RELEASE_OUTPUT=str(out),PYTHONPYCACHEPREFIX='/private/tmp/sw-app-release-python-cache')
    scripts=[s for s in entries() if not a.apps or s.relative_to(ROOT).parts[0] in a.apps]
    (out/'build-plan.json').write_text(json.dumps([str(s.relative_to(ROOT)) for s in scripts],indent=2))
    results=[]
    for script in scripts:
        name=script.relative_to(ROOT).parts[0]; print('BUILD',name,flush=True)
        log=out/(name+'-build.log')
        with log.open('w') as f:
            proc=subprocess.run([script.read_text().splitlines()[0].removeprefix('#!').strip(),str(script)],cwd=script.parent,env=env,stdout=f,stderr=subprocess.STDOUT)
        row={'app':name,'build_script':str(script),'build_exit':proc.returncode,'build_log':str(log),'signed_snapshot':(out/'SignedApps'/(name+'.app')).exists()}
        test=script.parent/'test.sh'
        if not test.exists(): test=ROOT/name/'test.sh'
        if proc.returncode==0 and test.exists():
            testlog=out/(name+'-test.log')
            with testlog.open('w') as f: check=subprocess.run(['zsh',str(test)],cwd=test.parent,env=env,stdout=f,stderr=subprocess.STDOUT)
            row.update(test_exit=check.returncode,test_log=str(testlog))
        else: row['test_exit']=None
        results.append(row); (out/'build-results.json').write_text(json.dumps(results,indent=2)+'\n')
        print('RESULT',name,json.dumps(row),flush=True)
if __name__=='__main__':main()
