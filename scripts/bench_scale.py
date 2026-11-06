#!/usr/bin/env python3
"""Offline isolated release measurements, 5 warmups + 30 samples per operation.
Each operation has a fresh process. Time in microseconds; nearest-rank quantiles.
No runtime changes enter the shipped engine. On timeout keep partial samples.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
SHAPES = ['direct', 'fan16', 'fan128', 'group2', 'group20', 'ttu2', 'ttu20',
          'wildcard', 'abac', 'difference', 'intersection']
OPS = ['check_hit', 'check_miss', 'objects_many', 'objects_few', 'users_many', 'users_few']


def command(args, cwd=ROOT):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()


def main():
    p = argparse.ArgumentParser(__doc__)
    p.add_argument('output', type=Path)
    p.add_argument('--targets', nargs='+', default=['native', 'js', 'wasm-gc'])
    p.add_argument('--sizes', nargs='+', type=int, default=[10000, 100000, 1000000])
    p.add_argument('--timeout', type=int, default=180)
    p.add_argument('--shapes', nargs='+', choices=SHAPES, default=SHAPES)
    p.add_argument('--operations', nargs='+', choices=OPS, default=OPS)
    a = p.parse_args()
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    lab = ROOT / '.upstream' / ('scale-' + out.name)
    lab.mkdir(parents=True, exist_ok=False)
    for name in command(['git', 'ls-files']).splitlines():
        if name.endswith(('.mbt', '.pkg', '.mod', '.json')) and not name.startswith(('docs/', 'conformance-results/')):
            dest = lab / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, dest)
    if not (ROOT / '.mooncakes').is_dir():
        raise SystemExit('Offline benchmark requires an existing .mooncakes dependency cache')
    (lab / '.mooncakes').symlink_to(ROOT / '.mooncakes', target_is_directory=True)
    (lab / 'lab').mkdir()
    shutil.copy2(ROOT / 'scripts/scale/main.mbt', lab / 'lab/main.mbt')
    imports = ['moonbitlang/core/env', 'moonbitlang/core/bench'] + [
        'sundaysebasidian-byte/moonfga/' + x for x in ['store', 'fga', 'dsl', 'engine']]
    (lab / 'lab/moon.pkg').write_text('pkgtype(kind: "executable")\nimport {\n' + ''.join('  "' + x + '",\n' for x in imports) + '}\n')
    pkg = lab / 'engine/moon.pkg'
    pkg.write_text(pkg.read_text().replace('import {', 'import {\n  "moonbitlang/core/bench",', 1))
    src = lab / 'engine/list_reverse.mbt'
    original = src.read_text()
    begin = '  let edges : Array[ReverseEdge] = []'
    end = '  // Restrict work and condition errors'
    assert original.count(begin) == original.count(end) == 1
    src.write_text(original.replace(begin, '  let graph_start = @bench.monotonic_clock_start()\n' + begin).replace(end, '  println("graph," + @bench.monotonic_clock_end(graph_start).to_string())\n' + end))
    meta = {'commit': command(['git', 'rev-parse', 'HEAD']), 'platform': platform.platform(),
            'machine': command(['sysctl', '-n', 'hw.model']), 'cpu': command(['sysctl', '-n', 'machdep.cpu.brand_string']),
            'cores': os.cpu_count(), 'memory_bytes': int(command(['sysctl', '-n', 'hw.memsize'])),
            'moon': command(['moon', 'version', '--all']), 'node': command(['node', '--version']),
            'seed': 20261106, 'warmups': 5, 'iterations': 30, 'build': 'release',
            'timeout_seconds_per_process': a.timeout, 'units': 'microseconds',
            'engine_sha256': hashlib.sha256(original.encode()).hexdigest(),
            'fixture_sha256': hashlib.sha256((ROOT/'scripts/scale/main.mbt').read_bytes()).hexdigest(),
            'host_load_at_start': os.getloadavg(),
            'started_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}
    # Avoid embedding tool installation home paths in committed evidence.
    meta['moon'] = re.sub(r' /(?:private/)?tmp/[^\n ]+', ' <toolchain>', meta['moon'])
    (out / 'environment.json').write_text(json.dumps(meta, indent=2) + '\n')
    launcher = lab / 'memory.mjs'
    launcher.write_text('let peak={rss:0,heapUsed:0,external:0};\nconst original=console.log;\nconsole.log=(...args)=>{const m=process.memoryUsage();for(const k in peak)peak[k]=Math.max(peak[k],m[k]);original(...args)};\nawait import(process.argv[2]);\noriginal("memory,"+JSON.stringify({sampled_peak:peak,final:process.memoryUsage()}));\n')
    for target in a.targets:
        build = subprocess.run(['moon', 'build', '--frozen', '--target', target, '--release', 'lab'], cwd=lab, text=True, capture_output=True)
        (out / ('build-' + target + '.json')).write_text(json.dumps({'exit_code': build.returncode, 'output': (build.stdout + build.stderr).replace(str(ROOT), '<repo>')}, indent=2) + '\n')
        rows = []
        if build.returncode:
            rows = [{'tuples': n, 'shape': s, 'operation': op, 'status': '未完成', 'reason': 'release build failed; see build JSON'} for n in a.sizes for s in a.shapes for op in a.operations]
        else:
            exe = lab / f'_build/{target}/release/build/lab/lab.{"exe" if target == "native" else "js" if target == "js" else "wasm"}'
            for n in a.sizes:
                for shape in a.shapes:
                    for op in a.operations:
                        cmd = [str(exe)] if target == 'native' else ['node', str(launcher), str(exe)] if target == 'js' else ['moonrun', str(exe), '--']
                        row = {'tuples': n, 'shape': shape, 'operation': op}
                        started = time.monotonic()
                        try:
                            r = subprocess.Popen(['/usr/bin/time', '-l'] + cmd + [str(n), shape, op], cwd=lab, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
                            stdout, stderr = r.communicate(timeout=a.timeout)
                            row.update(status='completed' if r.returncode == 0 else '未完成', exit_code=r.returncode)
                        except subprocess.TimeoutExpired as e:
                            os.killpg(r.pid, signal.SIGKILL)
                            stdout, stderr = r.communicate()
                            row.update(status='未完成', reason=f'timeout after {a.timeout}s including fixture construction')
                        row['wall_seconds'] = time.monotonic() - started
                        samples, graph = [], []
                        for line in stdout.splitlines():
                            if line.startswith('sample,'):
                                _, i, us, count = line.split(',')
                                samples.append({'iteration': int(i), 'us': float(us), 'count': int(count)})
                            elif line.startswith('graph,'): graph.append(float(line.split(',')[1]))
                            elif line.startswith('memory,'): row['process_memory_usage'] = json.loads(line[7:])
                        row.update(samples=samples, graph_us=graph)
                        if len(graph) == len(samples):
                            for sample, us in zip(samples, graph):
                                sample['graph_fraction'] = us / sample['us']
                        rss = re.search(r'(\d+)\s+maximum resident set size', stderr)
                        if rss: row['peak_rss_bytes'] = int(rss[1])
                        if row['status'] == 'completed' and len(samples) == 35:
                            v = sorted(s['us'] for s in samples[5:])
                            row['latency_us'] = {f'p{q}': v[math.ceil(q / 100 * len(v)) - 1] for q in [50, 95, 99]}
                            row['throughput_requests_s'] = len(v) * 1e6 / sum(v)
                            if graph: row['graph_fraction'] = sum(graph[5:]) / sum(v)
                        else:
                            row['status'] = '未完成'
                            row['diagnostic'] = (stdout[-2000:] + stderr[-2000:]).replace(str(ROOT), '<repo>').replace(str(lab), '<lab>')
                        rows.append(row)
                        (out / (target + '.json')).write_text(json.dumps(rows, separators=(',', ':')) + '\n')
                        print(target, n, shape, op, row['status'], flush=True)
        (out / (target + '.json')).write_text(json.dumps(rows, separators=(',', ':')) + '\n')


if __name__ == '__main__':
    main()
