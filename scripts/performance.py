#!/usr/bin/env python3
"""Isolated release builds; exact-phase instrumentation never enters shipped API.
Run: python3 scripts/performance.py before|after. Raw samples include warmups
for graph timing; query summaries exclude 3 warmups, use 30 single requests.
"""
import hashlib, json, os, platform, re, shutil, subprocess, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
os.environ['PATH'] = str(Path.home()/'.moon/bin') + ':' + os.environ['PATH']
label = sys.argv[1]
lab = ROOT/'.upstream'/('perf-'+label)
resume = '--resume' in sys.argv
if lab.exists() and not resume:
    raise SystemExit(f'Refusing to overwrite {lab}; use --resume for interrupted runs')
lab.mkdir(parents=True, exist_ok=resume)
for p in ([] if resume else ROOT.iterdir()):
    if p.name.startswith('.') or p.name in ('_build','target','conformance-results'): continue
    if p.is_dir(): shutil.copytree(p, lab/p.name)
    else: shutil.copy2(p, lab/p.name)
(lab/'lab').mkdir(exist_ok=resume)
shutil.copy2(ROOT/'scripts/perf/main.mbt', lab/'lab/main.mbt')
(lab/'lab/moon.pkg').write_text('pkgtype(kind: "executable")\nimport {\n'+''.join(f'  "{x}",\n' for x in ['moonbitlang/core/env','moonbitlang/core/bench']+[f'sundaysebasidian-byte/moonfga/{x}' for x in ['store','fga','dsl','engine']])+'}\n')
if not resume:
    if '--engine-ref' in sys.argv:
        ref = sys.argv[sys.argv.index('--engine-ref') + 1]
        (lab/'engine/list_reverse.mbt').write_bytes(subprocess.check_output(['git', 'show', ref + ':engine/list_reverse.mbt'], cwd=ROOT))
    engine_hash = hashlib.sha256((lab/'engine/list_reverse.mbt').read_bytes()).hexdigest()
    p = lab/'engine/moon.pkg'
    p.write_text(p.read_text().replace('import {','import {\n  "moonbitlang/core/bench",',1))
    p = lab/'engine/list_reverse.mbt'
    s = p.read_text().replace('  let edges : Array[ReverseEdge] = []','  let graph_clock = @bench.monotonic_clock_start()\n  let edges : Array[ReverseEdge] = []',1)
    s = s.replace('  // Restrict work and condition errors', '  println("graph," + @bench.monotonic_clock_end(graph_clock).to_string())\n  // Restrict work and condition errors',1)
    p.write_text(s)
out = ROOT/'docs/evidence'/('scale-'+label)
out.mkdir(parents=True, exist_ok=resume)
meta = {'platform':platform.platform(),'seed':20261101,'samples':30,'warmups':3,'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'moon':subprocess.check_output(['moon','version','--all'],text=True),'node':subprocess.check_output(['node','--version'],text=True),'source_sha256':engine_hash if not resume else None, 'fixture_sha256':hashlib.sha256((ROOT/'scripts/perf/main.mbt').read_bytes()).hexdigest()}
if not resume: (out/'environment.json').write_text(json.dumps(meta,indent=2))
shutil.copy2(lab/'lab/main.mbt', out/'fixture.mbt')
shutil.copy2(lab/'engine/list_reverse.mbt', out/'instrumented-engine.mbt')
rows=json.loads((out/'summary.json').read_text()) if resume else []
for target in ['native','js']:
    subprocess.run(['moon','build','--target',target,'--release','lab'],cwd=lab,check=True,stdout=(out/f'build-{target}.txt').open('w'),stderr=subprocess.STDOUT)
    exe = lab/f'_build/{target}/release/build/lab/lab.{"exe" if target=="native" else "js"}'
    for n in [10000,100000,1000000]:
        for name,fan in [('low',10),('medium',n//100),('high',n//2)]:
            stem=f'{target}-{n}-{name}'
            if any(r['target']==target and r['tuples']==n and r['profile']==name for r in rows): continue
            cmd=([str(exe)] if target=='native' else ['node',str(exe)])+[str(n),str(fan)]
            r=subprocess.run(['/usr/bin/time','-l']+cmd,cwd=lab,text=True,capture_output=True)
            (out/(stem+'.csv')).write_text(r.stdout)
            (out/(stem+'.time.txt')).write_text(r.stderr)
            r.check_returncode()
            samples={k:[] for k in ['check','list','graph']}
            for line in r.stdout.splitlines():
                k,v=line.split(','); samples[k].append(float(v))
            row={'target':target,'tuples':n,'fanout':fan,'profile':name,'rss_bytes':int(re.search(r'(\d+)\s+maximum resident set size',r.stderr)[1])}
            for k in ['check','list']:
                v=sorted(samples[k]); row[k]={p:v[idx] for p,idx in [('p50',14),('p95',28),('max',29)]}
            row['graph_fraction']=sum(samples['graph'][3:])/sum(samples['list'])
            rows.append(row)
            (out/'summary.json').write_text(json.dumps(rows,indent=2))
            print(stem,row,flush=True)
