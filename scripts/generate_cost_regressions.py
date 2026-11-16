"""Embed pinned successful runtime costs without Go/network/runtime file access."""
import argparse
import json
from pathlib import Path


def main():
    p=argparse.ArgumentParser();p.add_argument('directory',type=Path);a=p.parse_args()
    cases=json.loads((a.directory/'unlimited.json').read_text())
    expected=json.loads((a.directory/'expected.json').read_text())
    assert len(cases)==len(expected)
    assert not json.loads((a.directory/'mismatches.json').read_text())
    records=[]
    for c,e in zip(cases,expected):
        if e['category']!='ok':continue
        records.append('    ('+', '.join([json.dumps(c['expression'],ensure_ascii=False),json.dumps(json.dumps(c['context'],ensure_ascii=False),ensure_ascii=False),str(e['cost'])])+'),')
    lines=['// cel-go v0.31.0 optimized actual costs; regenerate with scripts/generate_cost_regressions.py.']
    for start in range(0,len(records),256):
        lines+=['///|',f'test "pinned CEL costs {start//256+1}" {{','  cost_cases([']+records[start:start+256]+['  ])','}']
    lines+=['''
///|
fn cost_cases(cases : Array[(String,String,Int32)]) -> Unit raise {
  for (source,context,expected) in cases {
    let fields = match @json.parse(context) { Object(m) => m; _ => abort("invalid cost context") }
    let env : Map[String,@fga.CelValue] = Map([])
    fields.each(fn(k,v) {
      env[k] = if k == "n" { match v { Number(x,..) => @fga.VInt(x.to_int64()); _ => abort("invalid n") } }
        else { @fga.json_to_cel_value_raw(v) }
    })
    let expr = @cel.compile(source)
    let (_,cost) = @cel.eval_expr_with_cost(expr,env,2147483647)
    assert_eq(cost,expected,msg=source)
    ignore(@cel.eval_expr_with_limit(expr,env,expected))
    if expected > 0 {
      let exceeded = try { ignore(@cel.eval_expr_with_limit(expr,env,expected-1)); false }
        catch { e => @fga.error_message(e).contains("cost limit exceeded") }
      assert_true(exceeded,msg=source)
    }
  }
}
''']
    Path('cel/cost_oracle_test.mbt').write_text('\n'.join(lines)+'\n')
    print(f'embedded {len(records)} pinned cost / boundary regressions')

if __name__=='__main__':main()
