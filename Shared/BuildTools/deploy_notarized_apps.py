#!/usr/bin/env python3
import argparse,json,pathlib,subprocess,time,sys,traceback,os
from deploy_both import manifest
from distribution_paths import latest_builds_dir
p=argparse.ArgumentParser();p.add_argument('output',type=pathlib.Path);a=p.parse_args();out=a.output.resolve();root=pathlib.Path(__file__).resolve().parents[2]
results=[];seen=set()
def run(args):return subprocess.run([str(x) for x in args],check=True,capture_output=True,text=True)
while True:
 try: rows=json.loads((out/'notary-results.json').read_text())
 except (FileNotFoundError,json.JSONDecodeError):rows=[]
 for item in rows:
  name=item['app']
  if name in seen:continue
  seen.add(name)
  if item['status']!='Accepted':continue
  app=out/'SignedApps'/(name+'.app');dest=pathlib.Path('/Applications')/app.name
  row={'app':name,'status':'pending'}
  try:
   # Refuse to replace on graceful termination refusal; never force-kill.
   lifecycle=run(['/private/tmp/sw-app-release-lifecycle','quit',dest if dest.exists() else app])
   was_running='NOT_RUNNING' not in lifecycle.stdout
   (out/(name+'-quit.log')).write_text(lifecycle.stdout+lifecycle.stderr)
   deploy=run([sys.executable,root/'Shared/BuildTools/deploy_both.py',app]); (out/(name+'-deploy.log')).write_text(deploy.stdout+deploy.stderr)
   assert manifest(app)==manifest(dest)==manifest(latest_builds_dir()/app.name)
   launch=run(['/private/tmp/sw-app-release-lifecycle','launch',dest]);(out/(name+'-launch.log')).write_text(launch.stdout+launch.stderr)
   for copy in [dest,latest_builds_dir()/app.name]:
    run(['xcrun','stapler','validate',copy]);gate=run(['spctl','-a','-vv',copy]);assert 'Notarized Developer ID' in gate.stderr+gate.stdout
   row.update(status='deployed_and_launch_verified',was_running=was_running)
   if not was_running:
    try:run(['/private/tmp/sw-app-release-lifecycle','quit',dest])
    except subprocess.CalledProcessError:row['post_test_quit']='refused; left running'
  except Exception as e:
   row.update(status='failed',error=str(e));(out/(name+'-deployment-error.txt')).write_text(traceback.format_exc()+getattr(e,'stdout','')+getattr(e,'stderr',''))
  results.append(row);(out/'deployment-results.json').write_text(json.dumps(results,indent=2)+'\n');print('DEPLOY',name,row['status'],flush=True)
 plan=json.loads((out/'build-plan.json').read_text())
 if len(rows)==len(plan):break
 time.sleep(5)
