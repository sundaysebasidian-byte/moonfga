"""Independent CEL expression corpus; official release Check/List API oracle."""
import argparse
import json
from pathlib import Path
import random
import subprocess


def expressions(seed):
    fixed = [
        'b"" == bytes("")', 'b"abc" == bytes("abc")',
        'b"a" + b"b" == b"ab"', 'b"a" < b"b"',
        'b"a" <= b"a"', 'b"b" > b"a"', 'b"b" >= b"b"',
        'size(b"😀") == 4', 'b"😀".size() == 4',
        'string(b"hello") == "hello"', 'string(bytes("😀")) == "😀"',
        'b"a" in [b"b", b"a"]', '{"b": b"x"}.b == b"x"',
        '[b"x", 1, true][0] == b"x"', 'bytes(b"x") == b"x"',
        r'b"\xff" > b"\x7f"', r'b"\000\377".size() == 2',
        r'b"\a\b\f\n\r\t\v\?".size() == 8',
        r'b"\x41" == b"A"', r'"\u4e2d\U0001f600" == "中😀"',
        r'br"\x41" == bytes(r"\x41")',
        'b"""a\nb""" == bytes("a\\nb")',
        'string(b"\\xff" + bytes(s)) == "x"',
        'int(dyn(18446744073709551615u + uint(n))) == 0',
        'int(dyn(9223372036854775808.0 + double(n))) == 0',
        'uint("18446744073709551615") == 18446744073709551615u',
        'double("1.5") == 1.5', 'bool("true") && !bool("false")',
        'string("abc") == "abc"', 'string(1u) == "1"',
        'dyn(b"x") == b"x"', 'has({"a": b"x"}.a)', '!has({"a": 1}.b)',
        '[1,2] + [3] == [1,2,3]',
        '[0,1].exists(x, x == 0 || 1 / x == 1)',
        '[0,1].exists(x, 1 / x == 1)',
        '[0,1].all(x, 1 / x == 0)',
        '[1,0].all(x, x == 0)',
        '[0,1].exists_one(x, 1 / x == 1)',
        '9223372036854775807 + (1 + n) == 0',
        '(-9223372036854775807 - 1) - (1 + n) == 0',
        '9223372036854775807 * (2 + n) == 0',
        '(-9223372036854775807 - 1) / (-1 + n) == 0',
        '(-9223372036854775807 - 1) % (-1 + n) == 0',
        '-(-9223372036854775807 - 1 + n) == 0',
        '18446744073709551615u + uint(1 + n) == 0u',
        'uint(n) - 1u == 0u', '18446744073709551615u * uint(2 + n) == 0u',
        '1 / n == 0', '1u / uint(n) == 0u',
        '(1 / n == 0) || true', '(1 / n == 0) && false',
    ]
    rng = random.Random(seed)
    for _ in range(128):
        text = ''.join(rng.choice('aZ中😀\n\t') for _ in range(rng.randrange(12)))
        literal = json.dumps(text, ensure_ascii=False)
        fixed.extend([f'size(bytes({literal})) == {len(text.encode())}',
                      f'string(bytes({literal})) == {literal}'])
    return fixed


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--seed', type=int, default=20261108)
    p.add_argument('--output', type=Path, default=Path('conformance-results/cel'))
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=True)
    cases = []
    for expression in expressions(a.seed):
        cases.append({'family': 'cel', 'model': {'schema_version': '1.1',
            'type_definitions': [{'type': 'user'}, {'type': 'doc',
                'relations': {'viewer': {'this': {}}},
                'metadata': {'relations': {'viewer': {'directly_related_user_types': [{'type': 'user', 'condition': 'cel_condition'}]}}}}],
            'conditions': {'cel_condition': {'name': 'cel_condition', 'expression': expression, 'parameters': {'n': {'type_name': 'TYPE_NAME_INT'}, 's': {'type_name': 'TYPE_NAME_STRING'}}}}},
            'tuples': [{'object': 'doc:1', 'relation': 'viewer', 'user': 'user:1', 'condition': {'name': 'cel_condition'}}],
            'object': 'doc:1', 'relation': 'viewer', 'user': 'user:1', 'context': {'n': 0, 's': ''}})
    corpus = a.output / 'corpus.json'
    corpus.write_text(json.dumps(cases, ensure_ascii=False, indent=2) + '\n')
    subprocess.run(['python3', 'scripts/oracle_openfga.py', '--corpus', str(corpus), '--seed', str(a.seed), '--output', str(a.output)], check=True)
    summary_path = a.output / 'summary.json'
    summary = json.loads(summary_path.read_text())
    summary.update(fixed_expressions=52, generated_expressions=256, generator_seed=a.seed)
    summary_path.write_text(json.dumps(summary, indent=2) + '\n')


if __name__ == '__main__':
    main()
