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


def expression_cases(seed):
    for e in expressions(seed):
        yield e, {'n': 0, 's': ''}
    fixed = [
        '1 < 2.0', '1 + 2.0 == 3.0', '1 == 1.0', '1', 'missing == 1',
        'int(true) == 1', 'size(1) == 1', 'true + false', 'true ? 1 : "x"',
        '"a".size(1) == 1', 'has({"a":1}.a())', 'has({"a":1}.a)',
        '{1:"a"}[1] == "a"', '{1u:"a"}[dyn(1)] == "a"',
        '{true:1}[true] == 1', '{"1":1, 1:2}.size() == 2',
        '{1:"a", 1u:"b"}.size() == 2', '{dyn(1):1, dyn(1):2}.size() == 2',
        '{"a":1,"b":2}.all(k, k in ["a","b"])',
        '{1:2,3:4}.exists(k, k == 3)',
        '{1:2,3:4}.exists_one(k, k > 0)',
        '{"a":1}.map(k, k + "x") == ["ax"]',
        '[1,2,3].map(x, x > 1, x * 2) == [4,6]',
        '{1:2,3:4}.filter(k, k == 1) == [1]',
        '9007199254740993 == 9007199254740992', 'int("9007199254740993") == 9007199254740993', 'dyn(int("9007199254740993")) == dyn(9007199254740992.0)',
        'dyn(int("9007199254740993")) > dyn(9007199254740992.0)',
        '{1:"a"}[dyn(1.0)] == "a"', '{1u:"b"}[dyn(1)] == "b"', '{1:"a",1u:"b"}[1] == "a"',
        'type(b"a") == bytes', 'type(1) == int', 'type([1]) == list',
        'type({1:1}) == map', 'type(type(1)) == type', 'type(null) == null_type',
        'dyn(9007199254740993) == dyn(9007199254740992.0)',
        'dyn(9007199254740993) > dyn(9007199254740992.0)',
        'dyn(18446744073709551615u) < dyn(18446744073709551616.0)',
        'dyn(-1) < dyn(0u)', 'dyn(0u) > dyn(-0.5)',
        '1.0 / 0.0 > 0.0', '0.0 / 0.0 == 0.0 / 0.0',
        '!(0.0 / 0.0 < 1.0)', 'string(1.0 / 0.0) == "+Inf"',
        'string(0.0 / 0.0) == "NaN"',
    ]
    for e in fixed:
        yield e, {'n': 0, 's': ''}
    for e in ['true || n > 0', 'false && n > 0', 'n > 0 || true',
              'n > 0 && false', 'true', 'n > 0', 'true ? true : n > 0',
              '[0,1].exists(x, x == 0 || n > 0)',
              '[0,1].all(x, x != 0 && n > 0)',
              '[0,1].exists_one(x, x == 0 || n > 0)']:
        yield e, {}
    for stamp in ['1969-12-31T23:59:59.123456789Z', '2026-03-08T09:59:59Z', '2026-03-08T10:00:00Z', '2026-11-01T09:00:00Z', '2026-01-02T03:04:05+08:00', '1900-01-01T00:00:00Z', '2050-07-01T00:00:00Z']:
        for zone in [None, 'UTC', '-08:00', '+05:30', 'America/Los_Angeles', 'Europe/London', 'Australia/Sydney', 'Asia/Shanghai', 'No/Such_Zone']:
            for method in ['getFullYear','getMonth','getDate','getDayOfMonth','getDayOfWeek','getDayOfYear','getHours','getMinutes','getSeconds','getMilliseconds']:
                arg = '' if zone is None else json.dumps(zone)
                e = f'timestamp({json.dumps(stamp)}).{method}({arg}) >= -1'
                yield e, {'n':0,'s':''}
                # Compare exact getter value via JSON numeric context, not just range.
                if zone != 'No/Such_Zone':
                    from datetime import datetime, timezone, timedelta
                    from zoneinfo import ZoneInfo
                    dt = datetime.fromisoformat(stamp.replace('Z','+00:00'))
                    tz = timezone.utc if zone is None or zone == 'UTC' else timezone(timedelta(hours=-8)) if zone == '-08:00' else timezone(timedelta(hours=5, minutes=30)) if zone == '+05:30' else ZoneInfo(zone)
                    dt = dt.astimezone(tz)
                    values = {'getFullYear':dt.year,'getMonth':dt.month-1,'getDate':dt.day,'getDayOfMonth':dt.day-1,'getDayOfWeek':(dt.weekday()+1)%7,'getDayOfYear':dt.timetuple().tm_yday-1,'getHours':dt.hour,'getMinutes':dt.minute,'getSeconds':dt.second,'getMilliseconds':dt.microsecond//1000}
                    yield e.replace('>= -1', f'== {values[method]}'), {'n':0,'s':''}
    for duration in ['0', '1h2m3.004005006s', '-1.5s', '.5s', '1.s', '9223372036854775807ns', '-9223372036854775808ns', '9223372036854775808ns', '0.000000000999999999s', '1e3s']:
        for method in ['getHours','getMinutes','getSeconds','getMilliseconds']:
            yield f'duration(s).{method}() == n', {'n':0,'s':duration}
        yield 'string(duration(s)) == s', {'n':0,'s':duration}
        yield 'int(duration(s)) == n', {'n':0,'s':duration}
    for e in [
        'timestamp(0) == timestamp("1970-01-01T00:00:00Z")',
        'int(timestamp("1969-12-31T23:59:59.5Z")) == -1',
        'duration(duration("1s")) == duration("1s")',
        'timestamp(timestamp("2026-01-01T00:00:00Z")) == timestamp("2026-01-01T00:00:00Z")',
        'timestamp("9999-12-31T23:59:59Z") + duration("1s") == timestamp(0)',
        'duration("9223372036854775807ns") + duration("1ns") == duration("0")',
        'timestamp("9999-12-31T23:59:59Z") - timestamp("0001-01-01T00:00:00Z") == duration("0")',
        'string(duration("1.500000001s")) == "1.500000001s"',
    ]:
        yield e, {'n':0,'s':''}
    patterns = [r'(ab)+', r'(?P<word>ab)', r'(?<word>ab)', r'(?:ab)', r'a{2,4}', r'a{2,}', r'a{1001}', r'a+?', r'(?i)ab', r'(?i:a)(?-i:b)', r'(?m)^ab$', r'(?s)a.b', r'(?U)a+', r'\\bword\\b', r'\\Bword', r'\\p{Han}+', r'\\pL+', r'\\P{Greek}+', r'\\x{1F600}', r'\\Q(a+)\\E', r'[[:alpha:]]+', r'[^a-z]+', r'[a-z\\d]+', r'(?i)[a-z]+', r'[a-z]+', r'(a|aa)*b', r'(a)\\1', r'(?=a)', r'(?<=a)', r'\\C', r'[z-a]', r'a**', r'\\z', r'\\A', r'\\d+', r'\\s+', r'\\w+', r'(?i)k', r'(?i)s']
    # Use dynamic patterns to exercise runtime errors, and literal patterns to
    # independently exercise official model-construction failures.
    patterns = [p.replace('\\\\', '\\') for p in patterns]
    for pattern in patterns:
        for text in ['', 'abab', 'aaa', 'a\nb', 'ab\n', 'word!', '中😀', 'Κλ', 'Kſ', '(a+)', 'a'*64]:
            yield f'{json.dumps(text,ensure_ascii=False)}.matches(s)', {'n':0,'s':pattern}
        yield f'"ab".matches({json.dumps(pattern)})', {'n':0,'s':''}
    for value in ['', '1', '+1', '-1', ' 1', '1 ', '0x10', '01', '1_0', '1e2', '1.5', 'NaN', 'Inf', '+Inf', '-Inf', 'Infinity', 'true', 'TRUE', 'True', 'false', 'False', '0', 't', '9223372036854775808', '18446744073709551615', '18446744073709551616']:
        for target in ['int','uint','double','bool']:
            yield f'type({target}(s)) == {target}', {'n':0,'s':value}
    for e in ['null == 1', 'null == "x"', 'null == []', '{"a":1,"a":2}.a == 2', '{1:1,1:2}[1] == 2', 'matches("a", "a")', 'type(duration("1s")) == google.protobuf.Duration', 'type(timestamp(0)) == google.protobuf.Timestamp', 'string(b"\\xff") == "x"', 'int("bad") == 1', '-9223372036854775808 < 0', '9223372036854775808 > 0', '0x10 == 16', '.5 == 0.5', '[1,].size() == 1', '{"a":1,}.a == 1']:
        yield e, {'n':0,'s':''}
    for value in [0, 1, -1, 1.5, 9223372036854775808, -9223372036854775809, None, True, '1', '+1', '1.0', '.5', '1e3', '9223372036854775807', '9223372036854775808', '-9223372036854775809', '18446744073709551615', '9223372036854775807.1', 'NaN', 'Inf', '0.1', '0.5', '1e300', '1p2']:
        for kind in ['INT', 'UINT', 'DOUBLE', 'ANY']:
            yield 'type(n) == int', {'n':value}, {'n':{'type_name':'TYPE_NAME_'+kind}}
    for kind, value, expression in [
        ({'type_name':'TYPE_NAME_ANY'}, {'a':[1,True,None]}, 'type(n.a[0]) == double'),
        ({'type_name':'TYPE_NAME_LIST','generic_types':[{'type_name':'TYPE_NAME_LIST','generic_types':[{'type_name':'TYPE_NAME_INT'}]}]}, [[1,2],[3]], 'n[0][1] == 2'),
        ({'type_name':'TYPE_NAME_MAP','generic_types':[{'type_name':'TYPE_NAME_LIST','generic_types':[{'type_name':'TYPE_NAME_ANY'}]}]}, {'a':[1,'x']}, 'type(n.a[0]) == double'),
    ]:
        yield expression, {'n':value}, {'n':kind}
    for stamp in ['2026-01-01T00:00:00', '2026-01-01t00:00:00Z', '2026-01-01 00:00:00Z', '2026-01-01T00:00:60Z', '0000-01-01T00:00:00Z', '2026-01-01T00:00:00.123456789123Z', '2026-01-01T00:00:00+24:00', '2026-01-01T00:00:00+01:60', '2026-01-01T00:00:00z']:
        yield 'type(timestamp(s)) == google.protobuf.Timestamp', {'n':0,'s':stamp}
        yield 'type(n) == google.protobuf.Timestamp', {'n':stamp}, {'n':{'type_name':'TYPE_NAME_TIMESTAMP'}}
    for e in [
        'timestamp("9999-12-31T23:59:59Z").getFullYear("+23:00") == 10000',
        'timestamp("0001-01-01T00:00:00Z").getFullYear("-23:00") == 0',
        'string(dyn([1])) == "[1]"', 'string(dyn(null)) == "null"',
        'has({1:1}.a)', '{1:1}.a == 1',
        '[1].map(x,true) == [true]',
    ]:
        yield e, {'n':0,'s':''}
    for pattern in [r'(?-)', r'(?)', r'(?i-)', r'a{1}{2}', r'(a{100}){100}', r'\\P{^Greek}', r'\\x{D800}']:
        pattern=pattern.replace('\\\\','\\')
        yield '"a".matches(s)', {'n':0,'s':pattern}
        yield f'"a".matches({json.dumps(pattern)})', {'n':0,'s':''}
    for value in ['1e-10','1e-5','1e-4','1e5','1e6','1e10','1e100','1e300','1e-300','-0.0','0x1p2','0x1.8p+2']:
        yield 'string(double(s)) == s', {'n':0,'s':value}
    for e in ['[] == [1]', '{} == {"x":1}', '[].all(x, x > 0)', 'size([]) == 0']:
        yield e, {'n':0,'s':''}
    for count in [8,9,24,25,32,33,49,50,51]:
        items='['+','.join(['1']*count)+']'
        for macro,body in [('filter','x < n'),('map','true')]:
            yield f'{items}.{macro}(x, {body}).size() == n', {'n':0,'s':''}
    for value, candidates in [('1e6',['1e+06','1000000','1e+6']),('1e-5',['1e-05','0.00001','1e-5']),('1e20',['1e+20','100000000000000000000']),('-0.0',['-0','0','-0.0']),('0x1p2',['4','4.0'])]:
        for candidate in candidates:
            yield f'string(double(s)) == {json.dumps(candidate)}', {'n':0,'s':value}
    for context in [{}, {'extra':1}]:
        yield 'true', context, {}
    for count in list(range(15,56)) + [100,1000]:
        items = '[' + ','.join(['1']*count) + ']'
        for macro in ['all', 'exists', 'exists_one', 'map', 'filter']:
            predicate = 'x >= n' if macro in ['all','exists_one','filter'] else 'x < n' if macro == 'exists' else 'x + n'
            call = f'{items}.{macro}(x, {predicate})'
            yield call if macro in ['all','exists','exists_one'] else f'{call}.size() > 0', {'n':0,'s':''}
    for length in [1,10,99,100,101,199,200,500,1000]:
        yield 's.matches("a+")', {'n':0,'s':'a'*length}
        yield 's.contains("z")', {'n':0,'s':'a'*length}
    rng = random.Random(seed ^ 0xCE1)
    for _ in range(512):
        x = rng.choice([-9223372036854775807, -9007199254740993, -1, 0, 1, 9007199254740993, 9223372036854775807])
        y = rng.choice(['-9223372036854775808.0', '-9007199254740992.0', '-0.5', '0.0', '0.5', '9007199254740992.0', '18446744073709551616.0'])
        op = rng.choice(['==', '!=', '<', '<=', '>', '>='])
        yield f'dyn({x}) {op} dyn({y})', {'n':0,'s':''}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--seed', type=int, default=20261108)
    p.add_argument('--output', type=Path, default=Path('conformance-results/cel'))
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=True)
    cases = []
    for spec in expression_cases(a.seed):
        expression, context = spec[:2]
        parameters = spec[2] if len(spec) > 2 else {'n': {'type_name': 'TYPE_NAME_INT'}, 's': {'type_name': 'TYPE_NAME_STRING'}}
        cases.append({'family': 'cel', 'validate_model': True, 'model': {'schema_version': '1.1',
            'type_definitions': [{'type': 'user'}, {'type': 'doc',
                'relations': {'viewer': {'this': {}}},
                'metadata': {'relations': {'viewer': {'directly_related_user_types': [{'type': 'user', 'condition': 'cel_condition'}]}}}}],
            'conditions': {'cel_condition': {'name': 'cel_condition', 'expression': expression, 'parameters': parameters}}},
            'tuples': [{'object': 'doc:1', 'relation': 'viewer', 'user': 'user:1', 'condition': {'name': 'cel_condition'}}],
            'object': 'doc:1', 'relation': 'viewer', 'user': 'user:1', 'context': context})
    corpus = a.output / 'corpus.json'
    corpus.write_text(json.dumps(cases, ensure_ascii=False, indent=2) + '\n')
    subprocess.run(['python3', 'scripts/oracle_openfga.py', '--corpus', str(corpus), '--seed', str(a.seed), '--output', str(a.output)], check=True)
    summary_path = a.output / 'summary.json'
    summary = json.loads(summary_path.read_text())
    results = json.loads((a.output / "expected.json").read_text())
    summary.update(generator_seed=a.seed, model_rejections=sum(isinstance(e["check"],str) and e["check"].startswith("M:") for e in results), model_rejection_categories={kind:sum(e["check"] == kind for e in results) for kind in ["M:invalid_authorization_model","M:validation_error"]}, evaluation_errors=sum(e["check"] == "E2000" for e in results))
    summary_path.write_text(json.dumps(summary, indent=2) + '\n')


if __name__ == '__main__':
    main()
