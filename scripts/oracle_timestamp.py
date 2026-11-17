"""Exact timestamp getter values/errors and HTTP comparisons against pinned oracles."""
import argparse
import json
import os
from pathlib import Path
import subprocess
from oracle_cel import expression_cases, timestamp_offset_cases
from oracle_host import condition_case


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=Path('conformance-results/timestamp'))
    args = parser.parse_args()
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    driver = (out / 'celoracle').resolve()
    subprocess.run(['go', 'build', '-o', str(driver), '.'], cwd='scripts/cel-oracle', check=True)
    direct = [{'expression': expr.removesuffix(' >= -1'), 'context': context, 'limit': 100}
              for expr, context in timestamp_offset_cases()]
    expected = json.loads(subprocess.run([str(driver)], input=json.dumps(direct),
                          env={**os.environ, 'TZ': 'UTC'}, text=True,
                          capture_output=True, check=True).stdout)
    assert len(expected) == len(direct)
    corpus = out / 'direct.json'
    corpus.write_text(json.dumps(direct, indent=2) + '\n')
    actual = json.loads(subprocess.run(['moon', 'run', '--target', 'native', 'cmd/cel-cost', '--', str(corpus)],
                        text=True, capture_output=True, check=True).stdout)
    assert len(actual) == len(expected)
    mismatches = []
    for c, e, a in zip(direct, expected, actual):
        if e['category'] != a['category'] or (e['category'] == 'ok' and
                (e['value_type'] != 'int' or int(e['value']) != json.loads(a['value']))):
            mismatches.append({'input': c, 'official': e, 'local': a})
    for name, data in [('direct-expected', expected), ('direct-actual', actual), ('direct-mismatches', mismatches)]:
        (out / f'{name}.json').write_text(json.dumps(data, indent=2) + '\n')
    assert not mismatches, mismatches[:3]
    # Keep all timestamp predicates from the seeded generator, plus exact values
    # obtained independently above, including mirrored runtime error categories.
    cases = [condition_case(spec[0], spec[1]) for spec in expression_cases(20261108)
             if 'timestamp(' in spec[0]]
    for c, e in zip(direct, expected):
        assert e['category'] in ('ok', 'evaluation'), e
        suffix = f" == {e['value']}" if e['category'] == 'ok' else ' >= -1'
        cases.append(condition_case(c['expression'] + suffix, c['context']))
    http_corpus = out / 'http-corpus.json'
    http_corpus.write_text(json.dumps(cases, indent=2) + '\n')
    subprocess.run(['python3', 'scripts/oracle_openfga.py', '--corpus', str(http_corpus),
                    '--output', str(out / 'http')], check=True)
    summary = {'direct_comparisons': len(direct),
               'direct_successes': sum(e['category'] == 'ok' for e in expected),
               'direct_evaluation_errors': sum(e['category'] == 'evaluation' for e in expected),
               'direct_mismatches': len(mismatches),
               'http': json.loads((out / 'http/summary.json').read_text())}
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
