"""Pinned server Local/TZ and deadline probes. No Go installation required."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.request
import oracle_openfga as oracle


def condition_case(expression, context=None):
    return {'validate_model':True, 'model':{'schema_version':'1.1',
        'type_definitions':[{'type':'user'}, {'type':'doc','relations':{'viewer':{'this':{}}},
            'metadata':{'relations':{'viewer':{'directly_related_user_types':[{'type':'user','condition':'cel_condition'}]}}}}],
        'conditions':{'cel_condition':{'name':'cel_condition','expression':expression,'parameters':{
            'n':{'type_name':'TYPE_NAME_INT'},'s':{'type_name':'TYPE_NAME_STRING'}}}}},
        'tuples':[{'object':'doc:1','relation':'viewer','user':'user:1','condition':{'name':'cel_condition'}}],
        'object':'doc:1','relation':'viewer','user':'user:1','context':context or {'n':0,'s':''}}


def request(base,path,data=None):
    payload=None if data is None else json.dumps(data).encode()
    try:
        with urllib.request.urlopen(urllib.request.Request(base+path,payload,{'Content-Type':'application/json'}),timeout=15) as r:
            return {'status':r.status,'body':json.load(r)}
    except urllib.error.HTTPError as e:
        return {'status':e.code,'body':json.load(e)}


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=Path('conformance-results/rework3-host'));a=p.parse_args()
    a.output.mkdir(parents=True,exist_ok=True);rows=[];local_cases=[]
    for zone,hours in [('',[0,0]),('UTC',[0,0]),('America/Los_Angeles',[16,17]),('Asia/Kolkata',[5,5])]:
        ports=[oracle.port() for _ in range(3)];base=f'http://127.0.0.1:{ports[0]}'
        with (a.output/f'server-{len(rows)}.log').open('w') as log:
            proc=subprocess.Popen([oracle.binary(),'run','--datastore-engine','memory','--http-addr',f'127.0.0.1:{ports[0]}','--grpc-addr',f'127.0.0.1:{ports[1]}','--metrics-addr',f'127.0.0.1:{ports[2]}','--playground-enabled=false','--log-level','error','--listObjects-deadline','1ns','--listUsers-deadline','1ns'],env={**os.environ,'TZ':zone},stdout=log,stderr=log)
            try:
                for _ in range(100):
                    if proc.poll() is not None:raise RuntimeError('server exited')
                    try:request(base,'/healthz');break
                    except urllib.error.URLError:time.sleep(.05)
                else:raise RuntimeError('readiness timeout')
                for stamp,hour in zip(['2026-01-01T00:00:00Z','2026-07-01T00:00:00Z'],hours):
                    for suffix,expected in [('getHours("Local")',hour),('getHours()',0)]:
                        local_cases.append((zone,condition_case(f'timestamp("{stamp}").{suffix} == {expected}')))
                local_cases.append((zone,condition_case('string(timestamp("2026-01-01T00:00:00+08:00")) == "2026-01-01T00:00:00+08:00"')))
                for tz,c in local_cases[-5:]:
                    path='/stores/'+request(base,'/stores',{'name':'host-probe'})['body']['id']
                    model=request(base,path+'/authorization-models',c['model']);assert model['status'] in (200,201),model
                    mid=model['body']['authorization_model_id'];common={'authorization_model_id':mid,'context':c['context']}
                    written=request(base,path+'/write',{'authorization_model_id':mid,'writes':{'tuple_keys':c['tuples']}});assert written['status']==200,written
                    result=request(base,path+'/check',{**common,'tuple_key':{k:c[k] for k in ['object','relation','user']}})
                    assert result['body'].get('allowed') is True,result
                    objects=request(base,path+'/list-objects',{**common,'type':'doc','relation':'viewer','user':'user:1'})
                    users=request(base,path+'/list-users',{**common,'object':{'type':'doc','id':'1'},'relation':'viewer','user_filters':[{'type':'user'}]})
                    rows.append({'TZ':tz,'expression':c['model']['conditions']['cel_condition']['expression'],'check':result,'list_objects_1ns':objects,'list_users_1ns':users})
            finally:proc.terminate();proc.wait(timeout=10)
    # Replay Check expectations against portable engine, supplying only explicit Local zones.
    corpus=[]
    for zone,c in local_cases:
        if zone:c['local_timezone']=zone
        corpus.append(c)
    path=a.output/'cases.json';path.write_text(json.dumps(corpus))
    actual=json.loads(subprocess.run(['moon','run','--target','native','cmd/oracle','--',str(path)],check=True,text=True,capture_output=True).stdout)
    assert len(actual)==len(rows)
    assert all(r['check'] is True for r in actual),actual
    (a.output/'results.json').write_text(json.dumps(rows,indent=2)+'\n')
    summary={'timezone_checks':len(rows),'local_checks_matched':len(actual),'list_objects_deadline_categories':sorted({r['list_objects_1ns']['body'].get('code','ok') for r in rows}),'list_users_deadline_categories':sorted({r['list_users_1ns']['body'].get('code','ok') for r in rows})}
    (a.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))

if __name__=='__main__':main()
