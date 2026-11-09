"""Generate portable IANA transition data from TZif; no runtime OS timezone dependency.
Regenerate with Python 3.14 and the retained tzdb input/version in docs/timezones.md.
TZif/IANA data are public domain. No upstream executable code is copied.
"""
from pathlib import Path
import hashlib
import json
import re
import struct
import argparse
import zoneinfo
from zoneinfo import available_timezones, _common, _tzpath


def seconds(text):
    sign = -1 if text.startswith('-') else 1
    parts = [int(x) for x in text.lstrip('+-').split(':')]
    return sign * sum(x * scale for x, scale in zip(parts, [3600, 60, 1]))


def rule(text):
    date, _, clock = text.partition('/')
    m,w,d = map(int,date[1:].split('.'))
    return f'({m}, {w}, {d}, {seconds(clock) if clock else 7200})'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input-dir',type=Path,help='Retained TZif tree instead of the OS database')
    args = parser.parse_args()
    if args.input_dir:
        zoneinfo.reset_tzpath([str(args.input_dir.resolve())])
    groups = {}; aliases = {}; digests = {}
    name = r'(?:[A-Za-z]+|<[^>]+>)'
    off = r'([+-]?\d+(?::\d+(?::\d+)?)?)'
    for zone in sorted(available_timezones() - {'localtime'}):
        path = _tzpath.find_tzfile(zone)
        if not path:
            raise RuntimeError('TZif file unavailable: ' + zone)
        raw = Path(path).read_bytes()
        digests[zone] = hashlib.sha256(raw).hexdigest()
        with open(path,'rb') as f: indexes, times, offsets, dst, abbr, tail = _common.load_data(f)
        initial = next((o for o,d in zip(offsets,dst) if not d), offsets[0])
        future = 'None'
        if tail and b',' in tail:
            t = tail.decode()
            match = re.fullmatch(name+off+name+r'([+-]?\d+(?::\d+(?::\d+)?)?)?,(M[^,]+),(M[^,]+)',t)
            if not match: raise RuntimeError(t)
            std = -seconds(match[1]); summer = -seconds(match[2]) if match[2] else std+3600
            future = f'Some(({std}, {summer}, {rule(match[3])}, {rule(match[4])}))'
        key = (tuple(times),tuple(offsets[i] for i in indexes),initial,future)
        i = groups.setdefault(key,len(groups)); aliases[zone] = i
    lines=['// Generated IANA TZif transition data; public domain. See docs/timezones.md.']
    for i, (times,offsets,initial,future) in enumerate(groups):
        packed=b''.join(struct.pack('<qi',t,o) for t,o in zip(times,offsets))
        pairs=''.join(f'\\x{b:02x}' for b in packed)
        lines += ['///|', f'fn tz_table_{i}() -> TZInfo {{', f'  {{ transitions: b"{pairs}", initial: {initial}, future: {future} }}', '}']
    lines += ['///|', 'fn timezone_table(index : Int) -> TZInfo {', '  match index {']
    for i in range(len(groups)): lines.append(f'    {i} => tz_table_{i}()')
    lines += ['    _ => abort("invalid timezone table index")', '  }', '}']
    lines+= ['', '///|','fn timezone_index(name : String) -> Int? {', '  match name {']
    for i in range(len(groups)):
        zones=[json.dumps(z) for z,j in aliases.items() if j==i]
        lines.append('    '+' | '.join(zones)+f' => Some({i})')
    lines+=['    _ => None','  }','}']
    Path('cel/timezones_generated.mbt').write_text('\n'.join(lines)+'\n')
    Path('docs/evidence/timezone-input-hashes.json').write_text(json.dumps(digests,indent=2)+'\n')
    print(len(aliases),'zones',len(groups),'unique tables')

if __name__ == '__main__':main()
