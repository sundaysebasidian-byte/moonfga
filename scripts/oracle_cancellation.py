"""Observe pinned OpenFGA request/condition deadline races; preserve raw responses."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.error
from oracle_host import condition_case,request
import oracle_openfga as oracle


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=Path('conformance-results/rework3-cancellation'));a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    ports=[oracle.port() for _ in range(3)];base=f'http://127.0.0.1:{ports[0]}'
    with (a.output/'server.log').open('w') as log:
        proc=subprocess.Popen([oracle.binary(),'run','--datastore-engine','memory','--http-addr',f'127.0.0.1:{ports[0]}','--grpc-addr',f'127.0.0.1:{ports[1]}','--metrics-addr',f'127.0.0.1:{ports[2]}','--playground-enabled=false','--log-level','error','--max-condition-evaluation-cost','1000000000','--request-timeout','25ms','--listObjects-deadline','1ms','--listUsers-deadline','1ms'],env={**os.environ,'TZ':'UTC'},stdout=log,stderr=log)
        try:
            for _ in range(100):
                if proc.poll() is not None:raise RuntimeError('server exited')
                try:request(base,'/healthz');break
                except urllib.error.URLError:time.sleep(.05)
            else:raise RuntimeError('readiness timeout')
            c=condition_case('items.all(x,x>=0)')
            c['model']['conditions']['cel_condition']['parameters']={'items':{'type_name':'TYPE_NAME_LIST','generic_types':[{'type_name':'TYPE_NAME_INT'}]}}
            path='/stores/'+request(base,'/stores',{'name':'interrupt-probe'})['body']['id']
            model=request(base,path+'/authorization-models',c['model']);assert model['status'] in (200,201),model
            mid=model['body']['authorization_model_id']
            written=request(base,path+'/write',{'authorization_model_id':mid,'writes':{'tuple_keys':c['tuples']}});assert written['status']==200,written
            rows=[]
            for size in [0,10000,50000,100000]:
                common={'authorization_model_id':mid,'context':{'items':[0]*size}}
                for _ in range(3):
                    rows.append({'size':size,'check':request(base,path+'/check',{**common,'tuple_key':{k:c[k] for k in ['object','relation','user']}}),
                        'list_objects':request(base,path+'/list-objects',{**common,'type':'doc','relation':'viewer','user':'user:1'}),
                        'list_users':request(base,path+'/list-users',{**common,'object':{'type':'doc','id':'1'},'relation':'viewer','user_filters':[{'type':'user'}]})})
            (a.output/'results.json').write_text(json.dumps(rows,indent=2)+'\n')
            summary={api:sorted({r[api]['body'].get('code','ok') for r in rows}) for api in ['check','list_objects','list_users']}
            (a.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
        finally:proc.terminate();proc.wait(timeout=10)
    # The CEL interpreter's cancellation message is stable, unlike transport races.
    case={'expression':'[1,2,3].all(x,x>n)','context':{'n':0},'limit':100,'cancel':True}
    raw=subprocess.run(['go','run','.'],cwd='scripts/cel-oracle',env={**os.environ,'TZ':'UTC'},input=json.dumps([case]),capture_output=True,text=True,check=True)
    result=json.loads(raw.stdout);assert result[0]['category']=='evaluation' and 'context canceled' in result[0]['error'],result
    (a.output/'cel-cancelled.json').write_text(json.dumps(result,indent=2)+'\n')

if __name__=='__main__':main()
