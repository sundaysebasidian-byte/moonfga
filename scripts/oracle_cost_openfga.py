"""Full API cost-limit differential, including OpenFGA's IPAddress extension."""
import argparse
import json
from pathlib import Path
import subprocess
from oracle_host import condition_case


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=Path('conformance-results/rework3-cost-api'));a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    expressions=[
        'n+1==1','n-1==-1','n*2==0','n/1==0','n%2==0','-n==0','!false','n==0 || false','n!=0 && true','n==0 ? true : false',
        'int(s)==n','uint(n)==0u','double(n)==0.0','bool(s)','string(n)==s','bytes(s)==b"a"','type(dyn(n))==int',
        'size(s)==n','s.size()==n','s<s','s+s==s','s.contains(s)','s.startsWith(s)','s.endsWith(s)','s.matches("(a|aa)*b")','matches(s,s)',
        '[n][0]==n','{"a":n}.a==n','has({"a":n}.a)','n in [1,1,1,1,1,1,1,1,1,1]',
        '[1,2,3].all(x,x>n)','[1,2,3].exists(x,x>n)','[1,2,3].exists_one(x,x>n)',
        '[1,2,3].map(x,x+n).size()==3','[1,2,3].filter(x,x>n).size()==3','[1,2,3].map(x,x>n,x+n).size()==3',
        '{"a":1,"b":2}.all(k,k!="bad")','{"a":1,"b":2}.exists_one(k,k=="a")',
        'duration(s).getSeconds()==n','string(duration(s))==s','timestamp(s).getHours("UTC")==n',
        'timestamp(0)+duration("1s")==timestamp(1)','timestamp(1)-timestamp(0)==duration("1s")',
        'google.protobuf.Int64Value{value:n}==n','google.protobuf.Struct{fields:{"a":n}}.a==n',
        'ipaddress(s).in_cidr("127.0.0.0/8")','ipaddress(s)==ipaddress("127.0.0.1")','string(dyn(ipaddress(s)))==s','type(ipaddress(s))==IPAddress',
    ]
    corpus=[condition_case(e,{'n':0,'s':s}) for e in expressions for s in ['','a'*20,'a'*200,'127.0.0.1']]
    path=a.output/'corpus.json';path.write_text(json.dumps(corpus))
    summaries=[]
    for limit in [100,101,199,200,1000]:
        out=a.output/f'limit-{limit}'
        subprocess.run(['python3','scripts/oracle_openfga.py','--condition-cost-limit',str(limit),'--corpus',str(path),'--output',str(out)],check=True)
        summaries.append(json.loads((out/'summary.json').read_text()))
    summary={'models':sum(s['cases'] for s in summaries),'comparisons':sum(s['comparisons'] for s in summaries),'mismatches':sum(s['mismatches'] for s in summaries),'limits':[s['condition_cost_limit'] for s in summaries]}
    (a.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))

if __name__=='__main__':main()
