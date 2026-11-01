#!/usr/bin/env python3
"""Render all measured distributions without dropping outliers."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
out = root/'docs/evidence'
lines = ['# Scale measurements', '', 'Times: microseconds for Check, milliseconds for ListObjects. RSS: MiB (whole process). Graph: fraction of total measured ListObjects time. Each cell is p50 / p95 / max.', '']
for label in ['baseline', 'optimized']:
    rows = json.loads((out/f'scale-{label}/summary.json').read_text())
    lines += [f'## {label}', '', '| Backend | Tuples | Fanout | Check µs | ListObjects ms | Peak RSS MiB | Graph % |', '| --- | ---: | ---: | --- | --- | ---: | ---: |']
    for r in rows:
        triple = lambda k, d: ' / '.join(f'{r[k][p]/d:.3f}' for p in ['p50','p95','max'])
        lines.append(f"| {r['target']} | {r['tuples']} | {r['fanout']} | {triple('check',1)} | {triple('list',1000)} | {r['rss_bytes']/1048576:.1f} | {r['graph_fraction']*100:.2f} |")
    lines.append('')
(out/'scale-results.md').write_text('\n'.join(lines)+'\n')
