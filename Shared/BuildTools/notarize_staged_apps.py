#!/usr/bin/env python3
import argparse,json,pathlib,subprocess,time,traceback
from developer_id_release import notarize,code_nodes,run
p=argparse.ArgumentParser();p.add_argument('output',type=pathlib.Path);p.add_argument('--profile',required=True);a=p.parse_args();out=a.output.resolve()
results=[];seen=set()
while True:
 plan=json.loads((out/'build-plan.json').read_text())
 try: builds=json.loads((out/'build-results.json').read_text())
 except (FileNotFoundError,json.JSONDecodeError): builds=[]
 for b in builds:
  name=b['app']
  if name in seen:continue
  seen.add(name)
  if b['build_exit'] or b.get('test_exit') not in (None,0) or not b['signed_snapshot']:
   results.append({'app':name,'status':'build_or_test_failed'});continue
  app=out/'SignedApps'/(name+'.app');print('NOTARIZE',name,flush=True)
  try:
   row=notarize(app,out/'Notarization',a.profile)
   for node in code_nodes(app)+[app]:run(['/usr/bin/codesign','--verify','--strict',node],capture_output=True)
   row['signature_verified']=True
  except Exception as e:
   row={'app':name,'status':'failed','error':str(e)}
   (out/(name+'-notary-error.txt')).write_text(traceback.format_exc())
  results.append(row);(out/'notary-results.json').write_text(json.dumps(results,indent=2)+'\n');print('NOTARY_RESULT',name,row['status'],flush=True)
 (out/'notary-results.json').write_text(json.dumps(results,indent=2)+'\n')
 if len(builds)==len(plan):break
 time.sleep(5)
