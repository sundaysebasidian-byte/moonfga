"""Probe unresolved CEL surface against the pinned server (not a pass gate)."""
import json
from pathlib import Path
import subprocess
import time

PROBES = {
    'cross_type_compare': '1 < 2.0',
    'mixed_arithmetic': '1 + 2.0 == 3.0',
    'type': 'type(b"a") == bytes',
    'timestamp_getFullYear': 'timestamp("2026-01-02T03:04:05Z").getFullYear() == 2026',
    'timestamp_timezone': 'timestamp("2026-01-02T03:04:05Z").getHours("America/Los_Angeles") == 19',
    'duration_getHours': 'duration("2h").getHours() == 2',
    'map_numeric_key': '{1: "a"}[1] == "a"',
    'map_macro': '{"a": 1}.exists(k, k == "a")',
    'map_three_args': '[1,2].map(x, x > 1, x * 2) == [4]',
    'regex_group': '"ab".matches("(ab)+")',
    'regex_count': '"aaa".matches("a{3}")',
    'regex_flag': '"A".matches("(?i)a")',
    'regex_unicode': '"中".matches("\\\\p{Han}")',
    'timestamp_int': 'timestamp(0) == timestamp("1970-01-01T00:00:00Z")',
    'int_duration': 'int(duration("2s")) == 2',
    'double_zero': '1.0 / 0.0 > 0.0',
    'constant_overflow': '9223372036854775807 + 1 == 0',
}


def main():
    out = Path('conformance-results/cel-surface')
    out.mkdir(parents=True, exist_ok=True)
    template = json.loads(Path('conformance-results/rework1-cel/cases.json').read_text())[0]
    probes = [(name, expr, {'n':0,'s':''}) for name,expr in PROBES.items()]
    probes += [
        ('host_local_zone', 'timestamp("2026-01-01T00:00:00Z").getHours("Local") >= 0', {'n':0,'s':''}),
        ('numeric_context_exponent_bound', 'n > 0', {'n':'1e100001','s':''}),
        ('constant_type_macro_cost', '['+','.join(['1']*25)+'].map(x,type(x)).size() == 25', {'n':0,'s':''}),
        ('regex_program_bound', '"a".matches('+json.dumps('('+'a'*101+'){1000}')+')', {'n':0,'s':''}),
    ]
    cases=[]
    for name,expr,context in probes:
        c=json.loads(json.dumps(template))
        c.update(probe=name,context=context,validate_model=True)
        c['model']['conditions']['cel_condition']['expression']=expr
        cases.append(c)
    local = json.loads(json.dumps(cases[17]))
    local['probe'] = 'configured_host_local_zone'
    local['local_timezone'] = 'America/Los_Angeles'
    local['model']['conditions']['cel_condition']['expression'] = 'timestamp("2026-01-01T00:00:00Z").getHours("Local") == 16'
    cases.append(local)
    path=out/'corpus.json'
    path.write_text(json.dumps(cases))
    started=time.time_ns()
    result=subprocess.run(['python3','scripts/oracle_openfga.py','--corpus',str(path),'--output',str(out)],check=False)
    required=[out/name for name in ['summary.json','actual.json','expected.json','mismatches.json']]
    if result.returncode not in (0,1) or any(not p.exists() or p.stat().st_mtime_ns < started for p in required):
        raise RuntimeError('surface oracle did not complete')
    actual=json.loads((out/'actual.json').read_text())
    expected=json.loads((out/'expected.json').read_text())
    if len(actual) != len(cases) or len(expected) != len(cases):
        raise RuntimeError('surface oracle result count mismatch')
    rows=[{'probe':c['probe'],'expression':c['model']['conditions']['cel_condition']['expression'],'context':c['context'],'local':a,'official':e,'matches':a==e} for c,a,e in zip(cases,actual,expected)]
    (out/'results.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'probes':len(rows),'matched':sum(r['matches'] for r in rows),'known_differences':[r['probe'] for r in rows if not r['matches']]},indent=2))


if __name__ == '__main__':
    main()
