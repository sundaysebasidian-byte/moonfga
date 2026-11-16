"""Compare cel-go v0.31.0 optimized runtime cost and cost-limit categories.
Go is only needed to regenerate expected results; offline MoonBit tests embed them.
The oracle's static estimate bounds are retained, not used by MoonFGA runtime.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
from cel_cost_corpus import cases


def category(row):
    return "limit" if "cost limit exceeded" in row.get("error","") else row["category"]


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--output',type=Path,default=Path('conformance-results/rework3-cost'))
    p.add_argument('--corpus',type=Path)
    p.add_argument('--oracle',type=Path,help='Prebuilt scripts/cel-oracle driver (cel-go v0.31.0)')
    a=p.parse_args(); a.output.mkdir(parents=True,exist_ok=True)
    corpus=json.loads(a.corpus.read_text()) if a.corpus else list({json.dumps(c,sort_keys=True):c for c in cases()}.values())
    oracle_command=[str(a.oracle.resolve())] if a.oracle else ["go","run","."]
    result=subprocess.run(oracle_command,cwd='scripts/cel-oracle',env={**os.environ,'TZ':'UTC'},input=json.dumps(corpus),text=True,capture_output=True,check=True)
    expected=json.loads(result.stdout)
    assert len(expected)==len(corpus)
    exclusions=[{'input':c,'official':e} for c,e in zip(corpus,expected) if e['category']=='compile']
    (a.output/'compile-exclusions.json').write_text(json.dumps(exclusions,ensure_ascii=False,indent=2)+'\n')
    valid=[(c,e) for c,e in zip(corpus,expected) if e['category']!='compile']
    compiled_rejections=len(corpus)-len(valid)
    corpus=[c for c,e in valid]; expected=[e for c,e in valid]
    (a.output/'unlimited.json').write_text(json.dumps(corpus))
    def local(path):
        r=subprocess.run(['moon','run','--target','native','cmd/cel-cost','--',str(path)],capture_output=True,text=True,check=True)
        return json.loads(r.stdout)
    actual=local(a.output/'unlimited.json')
    assert len(actual)==len(corpus)
    mismatches=[]
    for i,(c,e,v) in enumerate(zip(corpus,expected,actual)):
        if e['category'] != v['category'] or (e['category']=='ok' and e.get('cost') != v.get('cost')):
            mismatches.append({'case':i,'input':c,'official':e,'local':v})
        elif e.get('value_type') in ('string','bool','int','uint') and v['category']=='ok':
            value=json.loads(v['value'])
            text=str(value).lower() if isinstance(value,bool) else str(value)
            if e['value']!=text:mismatches.append({'case':i,'input':c,'official':e,'local':v,'kind':'value'})
    limited=[]
    for c,e in zip(corpus,expected):
        if e['category']!='ok': continue
        for limit in sorted({0,100,max(0,e['cost']-1),e['cost'],e['cost']+1}):
            limited.append({**c,'limit':limit})
    result=subprocess.run(oracle_command,cwd='scripts/cel-oracle',env={**os.environ,'TZ':'UTC'},input=json.dumps(limited),text=True,capture_output=True,check=True)
    limit_expected=json.loads(result.stdout)
    (a.output/'limited.json').write_text(json.dumps(limited))
    limit_actual=local(a.output/'limited.json')
    assert len(limit_expected)==len(limited)==len(limit_actual)
    for i,(c,e,v) in enumerate(zip(limited,limit_expected,limit_actual)):
        if category(e)!=category(v):
            mismatches.append({'limited_case':i,'input':c,'official':e,'local':v})
    for name,data in [('expected',expected),('actual',actual),('limit-expected',limit_expected),('limit-actual',limit_actual),('mismatches',mismatches)]:
        (a.output/f'{name}.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    # Demonstrate the upstream source of order-sensitive map macro costs.
    pairs='{'+','.join(f'"k{i}":{i}' for i in range(20))+'}'
    order_cases=[{'expression':pairs+'.exists(k,k=="k0")','context':{},'limit':100} for _ in range(64)]
    order_cases += [{'expression':'{1:2,3:4}.exists(k,k==3)','context':{},'limit':10} for _ in range(64)]
    order_result=json.loads(subprocess.run(oracle_command,cwd='scripts/cel-oracle',env={**os.environ,'TZ':'UTC'},input=json.dumps(order_cases),text=True,capture_output=True,check=True).stdout)
    (a.output/'map-order-probe.json').write_text(json.dumps({'cases':order_cases,'results':order_result},indent=2)+'\n')
    summary={'oracle_timezone':'UTC','programs':len(corpus),'compile_exclusions':compiled_rejections,'cost_comparisons':sum(e['category']=='ok' for e in expected),'evaluation_error_comparisons':sum(e['category']=='evaluation' for e in expected),'limit_comparisons':len(limited),'mismatches':len(mismatches),'order_probe_observed_costs':sorted({e.get('cost') for e in order_result}),'order_probe_categories':sorted({category(e) for e in order_result})}
    (a.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
    return bool(mismatches)

if __name__=='__main__':raise SystemExit(main())
