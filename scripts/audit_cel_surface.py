"""Probe unresolved CEL surface against the pinned server (not a pass gate)."""
import json
from pathlib import Path
import subprocess
import urllib.error
import time
import oracle_openfga as oracle

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
    template = json.loads(Path('conformance-results/cel/cases.json').read_text())[0]
    cases = []
    for name, expr in PROBES.items():
        c = json.loads(json.dumps(template))
        c['model']['conditions']['cel_condition']['expression'] = expr
        c['probe'] = name
        cases.append(c)
    path = out / 'cases.json'
    path.write_text(json.dumps(cases))
    local = subprocess.run(['moon', 'run', '--target', 'native', 'cmd/oracle', '--', str(path)], text=True, capture_output=True, check=True)
    actual = json.loads(local.stdout)
    ports = [oracle.port() for _ in range(3)]
    base = f'http://127.0.0.1:{ports[0]}'
    with (out / 'server.log').open('w') as log:
        proc = subprocess.Popen([oracle.binary(), 'run', '--datastore-engine', 'memory', '--http-addr', f'127.0.0.1:{ports[0]}', '--grpc-addr', f'127.0.0.1:{ports[1]}', '--metrics-addr', f'127.0.0.1:{ports[2]}', '--playground-enabled=false', '--profiler-enabled=false', '--log-level', 'error'], stdout=log, stderr=log)
        results = []
        try:
            for _ in range(100):
                if proc.poll() is not None:
                    raise RuntimeError('oracle exited')
                try:
                    oracle.request(base, '/healthz')
                    break
                except urllib.error.URLError:
                    time.sleep(.1)
            else:
                raise RuntimeError('readiness timeout')
            for c, a in zip(cases, actual):
                store = oracle.request(base, '/stores', {'name': 'cel-surface'})['id']
                prefix = '/stores/' + store
                row = {'probe': c['probe'], 'expression': c['model']['conditions']['cel_condition']['expression'], 'local_check': a['check']}
                try:
                    mid = oracle.request(base, prefix + '/authorization-models', c['model'])['authorization_model_id']
                except RuntimeError:
                    if oracle.HTTP_ERRORS[-1]['body'].get('code') != 'invalid_authorization_model':
                        raise
                    row['official'] = oracle.HTTP_ERRORS[-1]['body']
                else:
                    oracle.request(base, prefix + '/write', {'authorization_model_id': mid, 'writes': {'tuple_keys': c['tuples']}})
                    row['official'] = oracle.request(base, prefix + '/check', {'authorization_model_id': mid, 'tuple_key': {k: c[k] for k in ['object', 'relation', 'user']}, 'context': c['context']})
                results.append(row)
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
    (out / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
