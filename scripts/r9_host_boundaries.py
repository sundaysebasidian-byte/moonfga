"""Pinned Go TZ fallback, opt-in Local offsets and synchronous validation."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.error
from oracle_host import condition_case, request
import oracle_openfga as oracle


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=Path('conformance-results/r9-rework/host'))
    out=parser.parse_args().output;out.mkdir(parents=True,exist_ok=True)
    rows=[];cases=[]
    for zone,go_hour,local_hour in [('+05:30',10,15),('-08:00',10,2),('05:30',10,15),('EST',5,5),('Etc/GMT+12',22,22),('America/Los_Angeles',3,3),('Asia/Kolkata',15,15)]:
        ports=[oracle.port() for _ in range(3)];base=f'http://127.0.0.1:{ports[0]}'
        c=condition_case(f'timestamp("2026-03-08T10:00:00Z").getHours("Local")=={go_hour}')
        with (out/f'server-{len(rows)}.log').open('w') as log:
            proc=subprocess.Popen([oracle.binary(),'run','--datastore-engine','memory','--http-addr',f'127.0.0.1:{ports[0]}','--grpc-addr',f'127.0.0.1:{ports[1]}','--metrics-addr',f'127.0.0.1:{ports[2]}','--playground-enabled=false','--log-level','error'],env={**os.environ,'TZ':zone},stdout=log,stderr=log)
            try:
                for _ in range(100):
                    if proc.poll() is not None:raise RuntimeError('oracle exited')
                    try:request(base,'/healthz');break
                    except urllib.error.URLError:time.sleep(.05)
                else:raise RuntimeError('readiness timeout')
                path='/stores/'+request(base,'/stores',{'name':'r9-host'})['body']['id']
                model=request(base,path+'/authorization-models',c['model']);assert model['status']==201,model
                mid=model['body']['authorization_model_id'];common={'authorization_model_id':mid,'context':c['context']}
                written=request(base,path+'/write',{'authorization_model_id':mid,'writes':{'tuple_keys':c['tuples']}});assert written['status']==200,written
                check=request(base,path+'/check',{**common,'tuple_key':{k:c[k] for k in ['object','relation','user']}})
                assert check['body'].get('allowed') is True,check
                invalid=request(base,path+'/check',{**common,'tuple_key':{'object':'doc:1','relation':'missing','user':'user:1'}})
                assert invalid['status']==400 and invalid['body']['code']=='validation_error',invalid
                rows.append({'TZ':zone,'server_Local_hour':go_hour,'default_MoonFGA_Local_hour':go_hour,'opt_in_MoonFGA_Local_hour':local_hour,'offset_extension':go_hour!=local_hour,'server_check':check,'server_invalid_relation':invalid})
            finally:proc.terminate();proc.wait(timeout=10)
        c['local_timezone']=zone;cases.append(c)
    corpus=out/'cases.json';corpus.write_text(json.dumps(cases))
    actual=json.loads(subprocess.run(['moon','run','--target','native','cmd/oracle','--',str(corpus)],text=True,capture_output=True,check=True).stdout)
    assert len(actual)==len(rows)
    for row,result in zip(rows,actual):
        assert result['check'] is True,(row,result)
        assert result['list_objects']==['doc:1'],(row,result)
        assert result['list_users']==['user:1'],(row,result)
        row['local_check']=result['check']
    extension_cases=[]
    for c,row in zip(cases,rows):
        if row['offset_extension']:
            enabled=json.loads(json.dumps(c))
            enabled['allow_numeric_local_timezone']=True
            enabled['model']['conditions']['cel_condition']['expression']=f'timestamp("2026-03-08T10:00:00Z").getHours("Local")=={row["opt_in_MoonFGA_Local_hour"]}'
            extension_cases.append(enabled)
    extension_corpus=out/'opt-in-cases.json';extension_corpus.write_text(json.dumps(extension_cases))
    extension_actual=json.loads(subprocess.run(['moon','run','--target','native','cmd/oracle','--',str(extension_corpus)],text=True,capture_output=True,check=True).stdout)
    assert len(extension_actual)==3
    assert all(r['check'] is True and r['list_objects']==['doc:1'] and r['list_users']==['user:1'] for r in extension_actual),extension_actual
    (out/'opt-in-results.json').write_text(json.dumps(extension_actual,indent=2)+'\n')
    (out/'results.json').write_text(json.dumps(rows,indent=2)+'\n')
    summary={'named_zones_matched':4,'numeric_Local_fallbacks_matched':3,'default_local_api_assertions':21,'opt_in_api_assertions':9,'server_validation_errors':7,'mismatches':0}
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2))

if __name__=='__main__':main()
