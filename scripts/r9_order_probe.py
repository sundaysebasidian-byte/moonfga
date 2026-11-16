"""Retain Go's randomized two-key map cost outside deterministic comparisons."""
import argparse
import collections
import json
import os
from pathlib import Path
import subprocess
from cel_cost_corpus import cases, ORDER_SENSITIVE


def main():
    p=argparse.ArgumentParser();p.add_argument('--oracle',type=Path,required=True);p.add_argument('--output',type=Path,default=Path('conformance-results/r9-rework/order'));a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    assert all(''.join(c['expression'].split()) not in ORDER_SENSITIVE for c in cases())
    corpus=[{'expression':'{1:2,3:4}.exists(k,k==3)','context':{},'limit':limit} for limit in [2147483647,10] for _ in range(200)]
    expected=json.loads(subprocess.run([str(a.oracle.resolve())],input=json.dumps(corpus),env={**os.environ,'TZ':'UTC'},text=True,capture_output=True,check=True).stdout)
    assert len(expected)==len(corpus)
    summary={}
    for start,limit in [(0,2147483647),(200,10)]:
        rows=expected[start:start+200]
        summary[str(limit)]={'runs':len(rows),'costs':dict(collections.Counter(str(r['cost']) for r in rows)),'categories':dict(collections.Counter('limit' if 'cost limit exceeded' in r.get('error','') else r['category'] for r in rows))}
    for name,data in [('cases',corpus),('expected',expected),('summary',summary)]:
        (a.output/f'{name}.json').write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps(summary,indent=2))

if __name__=='__main__':main()
