"""Generate portable character data through Go's public unicode APIs."""
from pathlib import Path
import json
import subprocess


def main():
    data = subprocess.check_output(['go','run','scripts/export_unicode.go'])
    Path('.upstream').mkdir(exist_ok=True)
    Path('.upstream/unicode.json').write_bytes(data)
    x = json.loads(data)
    lines=['// Generated from public Go unicode API data; see docs/timezones.md.']
    for i,(k,v) in enumerate(sorted(x['Tables'].items())):
        lines += ['///|', f'fn unicode_table_{i}() -> Array[(Int, Int)] {{', '  ['+', '.join(f'({a}, {b})' for a,b in v)+']', '}']
    lines += ['///|','fn unicode_property(name : String) -> Array[(Int,Int)]? {', '  match name {']
    for i,(k,v) in enumerate(sorted(x['Tables'].items())):
        lines.append('    '+json.dumps(k)+f' => Some(unicode_table_{i}()),')
    lines += ['    _ => None', '  }','}', '///|','fn unicode_simple_fold(n : Int) -> Int {', '  match n {']
    orbits={}
    for k,v in sorted(x['Folds'].items(),key=lambda x:int(x[0])):
        lines.append(f'    {k} => {v},')
        orbits.setdefault(v,[]).append(int(k))
    lines += ['    _ => n','  }','}', '///|','fn unicode_simple_orbit(n : Int) -> Array[Int] {','  match n {']
    for k,v in sorted(orbits.items()):
        lines.append(f'    {k} => {v},')
    lines += ['    _ => []','  }','}']
    Path('cel/unicode_generated.mbt').write_text('\n'.join(lines)+'\n')
    print('Unicode',x['Version'])


if __name__ == '__main__':main()
