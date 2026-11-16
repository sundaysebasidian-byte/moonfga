"""Deterministic generated runtime-cost corpus; sizes straddle CEL cost boundaries."""
import json


def cases():
    sizes = list(range(0, 42)) + [49,50,51,63,64,99,100,101,199,200,201,499,500,999,1000]
    for n in sizes:
        xs = '[' + ','.join(['1'] * n) + ']'
        pairs = '{' + ','.join(f'"k{i}":{i}' for i in range(n)) + '}'
        context = {'n':0, 's':'a中😀' * n, 't':'a' * (n//2)}
        expressions = [
            'size(s)', 's.size()', 's == t', 's != t', 's < t', 's <= t', 's > t', 's >= t',
            's + t', 'bytes(s)', 'string(bytes(s))', 's.contains(t)', 's.startsWith(t)', 's.endsWith(t)',
            's.matches(t)', 'matches(s,t)', 's.matches("(a|中|😀)+")', 's.matches("a.*z")',
            f'{xs}.size()', f'{xs} == {xs}', f'{xs} + [n]', f'n in {xs}', f'dyn(n) in {xs}',
            f'[n] == {xs}', f'{pairs}.size()', f'{pairs} == {pairs}', f'"k0" in {pairs}',
            f'{xs}.all(x,x>n)', f'{xs}.exists(x,x>n)', f'{xs}.exists_one(x,x>n)',
            f'{xs}.map(x,x+n)', f'{xs}.filter(x,x>n)', f'{xs}.map(x,x>n,x+n)',
            f'{pairs}.all(k,k!="bad")', f'{pairs}.exists(k,k!="bad")', f'{pairs}.exists_one(k,k=="k0")',
            f'{pairs}.map(k,k+"x")', f'{pairs}.filter(k,k=="k0")',
        ]
        # Constant folding, macro lowering and dynamically sized values interact.
        for body in ['true','!true','1+1','int("1")','[1]','{"a":1}','type(1)','bytes(s)','s+t','s==t','s.contains(t)','s.matches(t)']:
            expressions.append(f'{xs}.map(x,{body}).size()')
        for e in expressions:
            yield {'expression':e, 'context':context,'limit':2147483647}
    for value in ['n','uint(n)','double(n)','true','s','bytes(s)','duration("1.5s")','timestamp("2026-01-01T00:00:00Z")']:
        for fun in ['int','uint','double','string','bool','bytes','type','dyn']:
            # Only type-valid overloads are included in exact-cost comparisons.
            yield {'expression':f'{fun}({value})','context':{'n':0,'s':'1'},'limit':2147483647}
    for method in ['getFullYear','getMonth','getDate','getDayOfMonth','getDayOfWeek','getDayOfYear','getHours','getMinutes','getSeconds','getMilliseconds']:
        for zone in ['', '"UTC"', '"Local"','"America/Los_Angeles"','"+05:30"']:
            yield {'expression':f'timestamp(s).{method}({zone})','context':{'n':0,'s':'2026-03-08T10:00:00Z'},'limit':2147483647}
    for e in ['has({"a":n}.a)','[n][0]','{"a":n}.a','{"a":n}["a"]','n+1','n-1','n*2','n/1','n%2','-n','!false','n==0 || false','n!=0 && true','n==0 ? n+1 : n-1', 'duration(s).getHours()', 'duration(s).getMinutes()', 'duration(s).getSeconds()', 'duration(s).getMilliseconds()', 'duration(s)+duration("1s")','timestamp(0)+duration(s)','timestamp(0)-duration(s)','timestamp(1)-timestamp(0)']:
        yield {'expression':e,'context':{'n':0,'s':'1.5s'},'limit':2147483647}
    # Reuse the full existing supported-overload surface, including protobuf/Any,
    # nested macros, temporal arithmetic, escapes, regex flags and conversions.
    from oracle_cel import expression_cases
    for spec in expression_cases(20261108):
        expression, context = spec[:2]
        if len(spec) > 2:
            continue  # This driver declares n:int, s:string, t:string only.
        if 'n' not in context or 's' not in context or not isinstance(context['n'],int) or not isinstance(context['s'],str):
            continue
        yield {'expression':expression,'context':context,'limit':2147483647}
    import random
    rng=random.Random(20261116)
    for _ in range(256):
        ns=rng.randrange(-(1<<63),1<<63)
        for expr in ['string(duration(s))','string(duration(s)).size()','string(duration(s))==s']:
            yield {'expression':expr,'context':{'n':0,'s':str(ns)+'ns'},'limit':2147483647}
