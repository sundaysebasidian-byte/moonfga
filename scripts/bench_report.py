#!/usr/bin/env python3
"""Render all recorded matrix cells, including failed operations."""
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
lines = ['# Release query matrix', '',
         'Time: milliseconds, nearest-rank p50 / p95 / p99 (30 measured requests, 5 warmups retained).',
         'Req/s excludes fixture setup; RSS is whole-process macOS time -l high water, MiB.',
         'Graph is sum(build time) / sum(ListObjects time), excluding warmups. No outliers removed.', '',
         '| Backend | Tuples | Shape | Operation | Results | p50 / p95 / p99 ms | Req/s | RSS MiB | Graph % |',
         '| --- | ---: | --- | --- | ---: | --- | ---: | ---: | ---: |']
summary = []
for target in ['native', 'js', 'wasm-gc']:
    rows = json.loads((root / f'{target}.json').read_text())
    for n in sorted({r['tuples'] for r in rows}):
        selected = [r for r in rows if r['tuples'] == n]
        item = {'target': target, 'tuples': n, 'completed': sum(r['status'] == 'completed' for r in selected), 'total': len(selected)}
        for op in sorted({r['operation'] for r in selected}):
            measured = [r for r in selected if r['operation'] == op and r['status'] == 'completed']
            if measured:
                item[op] = {'p95_us_min': min(r['latency_us']['p95'] for r in measured), 'p95_us_max': max(r['latency_us']['p95'] for r in measured)}
        summary.append(item)
    for r in rows:
        prefix = f"| {target} | {r['tuples']} | {r['shape']} | {r['operation']} |"
        if r['status'] != 'completed':
            lines.append(prefix + ' 未完成: ' + r.get('reason', f"exit {r.get('exit_code')}") + f" ({len(r.get('samples', []))}/35 samples) | — | — | — | — |")
            continue
        q = ' / '.join(f"{r['latency_us'][f'p{x}']/1000:.4f}" for x in [50, 95, 99])
        rss = f"{r['peak_rss_bytes']/1048576:.1f}" if 'peak_rss_bytes' in r else '—'
        graph = f"{r['graph_fraction']*100:.1f}" if 'graph_fraction' in r else '—'
        lines.append(prefix + f" {r['samples'][0]['count']} | {q} | {r['throughput_requests_s']:.2f} | {rss} | {graph} |")
(root / 'results.md').write_text('\n'.join(lines) + '\n')
(root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
