#!/usr/bin/env python3
"""Final audit of installed release copies, including nested signatures and notarization."""
import argparse,csv,json,pathlib,plistlib,subprocess,sys
from deploy_both import manifest
from distribution_paths import latest_builds_dir
from developer_id_release import code_nodes,IDENTITY
p=argparse.ArgumentParser();p.add_argument('output',type=pathlib.Path);a=p.parse_args();r=a.output.resolve();root=pathlib.Path(__file__).resolve().parents[2]
rows=json.loads((r/'FINAL-RESULTS.json').read_text());plan=json.loads((r/'build-plan.json').read_text())
assert len(rows)==len(plan), 'Some apps are missing from the result'
results=[]
for name,row in sorted(rows.items()):
 assert row['build']['build_exit']==0 and row['build'].get('test_exit') in (0,None), name+' build/test failed'
 assert row['notary']['status']=='Accepted' and row['deployment']['status']=='deployed_and_launch_verified', name+' not completed'
 source=pathlib.Path(row['source_folder'])/'SignedApps'/(name+'.app')
 expected=manifest(source)
 info=plistlib.loads((source/'Contents/Info.plist').read_bytes())
 item={'app':name,'version':info['CFBundleShortVersionString'],'build':info['CFBundleVersion'],'bundle_id':info['CFBundleIdentifier'],'copies':[]}
 for app in [pathlib.Path('/Applications')/source.name,latest_builds_dir()/source.name]:
  assert manifest(app)==expected, str(app)+' differs from the release artifact'
  for node in code_nodes(app)+[app]:
   subprocess.run(['/usr/bin/codesign','--verify','--strict',str(node)],check=True,capture_output=True)
  details=subprocess.run(['/usr/bin/codesign','-dv','--verbose=4',str(app)],check=True,capture_output=True).stderr.decode()
  assert 'Authority='+IDENTITY in details and 'Timestamp=' in details and 'runtime' in details
  subprocess.run(['xcrun','stapler','validate',str(app)],check=True,capture_output=True)
  gate=subprocess.run(['spctl','-a','-vv',str(app)],check=True,capture_output=True,text=True)
  assert 'Notarized Developer ID' in gate.stdout+gate.stderr
  item['copies'].append(str(app))
 results.append(item);print('FINAL_PASS',name,flush=True)
(r/'final-verification.json').write_text(json.dumps(results,indent=2)+'\n')
with (r/'FINAL-APPS.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=['app','version','build','bundle_id']);w.writeheader();w.writerows({k:x[k] for k in w.fieldnames} for x in results)
print('FINAL_VERIFIED',len(results),'apps,',len(results)*2,'installed copies')
