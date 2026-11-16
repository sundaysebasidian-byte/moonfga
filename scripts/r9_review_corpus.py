"""r9 review repros plus generated index/identity-conversion boundary families."""
import argparse
import json
from pathlib import Path
from oracle_host import condition_case

BIG = 2147483647


def cost_cases():
    context = {'n': 0, 's': 'a', 't': '0'}
    for size in [1, 2, 3, 7, 15, 16, 17, 31, 64]:
        xs = '[' + ','.join(['1'] * size) + ']'
        dynamic = '[' + ','.join(['n+1'] + ['1'] * (size-1)) + ']'
        for target in [xs, dynamic, f'dyn({xs})', f'[{xs}][0]', f'[{xs}][n]']:
            for index in ['0', 'n', 'n+0', 'dyn(n)', 'int(t)']:
                yield {'family': 'index', 'expression': f'{target}[{index}]', 'context': context, 'limit': BIG}
        for value in ['1', 'n+1']:
            pairs = '{' + ','.join(['"a":'+value] + [f'"k{i}":1' for i in range(1,size)]) + '}'
            for index in ['"a"', 's', 's+""', 'dyn(s)', 'string(s)']:
                yield {'family': 'index', 'expression': f'{pairs}[{index}]', 'context': context, 'limit': BIG}
        for target,index in [(f'[{xs}].map(v,v[n])',''),(f'[{dynamic}].map(v,v[0])','')]:
            yield {'family':'index','expression':target,'context':context,'limit':BIG}
    for source in ['[1,2,3][n]', '{"a":1}[s]', '[1,2,3][n]==1', '[n,2,3][1]', '[1,2,3][0]',
                   '{0:1}[n]', '{0:1}[0]', '{n:1}[0]', '{0:n}[n]', '{"a":1}.a',
                   's[n]', '"abc"[0]', 'bytes(s)[n]', 'dyn(s)[n]']:
        yield {'family':'index','expression':source,'context':context,'limit':BIG}
    for source in [
        '[1][[n][0]]', '[1][[n][n]]', '[1][{"a":n}.a]',
        '[1][n==0 ? n : 0]', '{"a":1}[{"a":s}.a]',
        '[[0]].all(v,[1][v[n]]==1)',
        '[{"a":0}].all(v,[1][v.a]==1)',
        '{"a":{"b":n}}.a.b', '{"a":{"b":n}}[s]["b"]',
        '[{"a":1}].all(v,v[s]==1)', '[{"a":1}].all(v,v.a==1)',
        '[{"a":1}].all(v,has(v.a))', 'has({"a":{"b":n}}.a.b)',
        '{true:1}[n==0]', '{0u:1}[uint(n)]',
        '[1][true?0:n]', '[1][false?n:0]', '[1][n==0?n+0:n]',
        '(n==0?[1]:[2])[n]', '(true?[1]:[2])[0]',
        '[[1]].all(v,(n==0?v:v)[n]==1)',
        '{true:1}[has({"a":1}.a)]',

    ]:
        yield {'family':'index','expression':source,'context':context,'limit':BIG}
    for count in range(1,41):
        zeros='['+','.join(['0']*count)+']'
        for indexed in ['[1][n]', '{"a":1}[s]', '[n+1][n]', '{"a":n+1}[s]', '[[1]][n][n]', '[1][i]']:
            yield {'family':'index-macro','expression':f'{zeros}.all(i,{indexed}==1)','context':context,'limit':BIG}
    for size in [0,1,9,10,11,19,20,21,100,1000]:
        for source in ['string(s)','bytes(bytes(s))','string(string(s))','string(bytes(s))','bytes(string(s))']:
            yield {'family':'identity','expression':source,'context':{'n':0,'s':'a'*size},'limit':BIG}
    for value in ['1234567.0','123456.0','0.00001','1e20','-1e20','1.0']:
        for layers in range(1,5):
            source='string('*layers + value+'+double(n)' + ')'*layers
            yield {'family':'identity','expression':source,'context':{'n':0,'s':''},'limit':BIG}
    for value in ['-9.223372036854775808e18','-9.2233720368547748e18','-9.223372036854777856e18','9.223372036854775808e18']:
        for source in [f'int({value}+double(n))<0', 'int(double(s))<0']:
            yield {'family':'int-boundary','expression':source,'context':{'n':0,'s':value},'limit':BIG}
    for stamp in ['0001-01-01T00:00:00Z','1970-01-01T00:00:00Z','2026-01-01T00:00:00Z','9999-12-31T23:59:59Z']:
        for duration in ['-9223372036854775808ns','-9223372036854775807ns','9223372036854775807ns']:
            for op in ['-','+']:
                yield {'family':'timestamp-boundary','expression':f'timestamp(s){op}duration(t)>timestamp(s)','context':{'n':0,'s':stamp,'t':duration},'limit':BIG}


def api_cases():
    for c in cost_cases():
        expression=c['expression']
        if c['family'] in ('index','identity'):
            # Exercise a Boolean condition, including checker rejection of string indexing.
            expression=f'({expression})==({expression})'
        case=condition_case(expression,c['context'])
        if 't' in c['context']:
            case['model']['conditions']['cel_condition']['parameters']['t']={'type_name':'TYPE_NAME_STRING'}
        case['family']=c['family']
        yield case
    for count in [13,14,15,16,17]:
        zeros='['+','.join(['0']*count)+']'
        for variable,kind,value,lookup in [('x','INT',0,'[1][x]'),('k','STRING','a','{"a":1}[k]')]:
            c=condition_case(f'{zeros}.all(i,{lookup}==1)',{variable:value})
            c['model']['conditions']['cel_condition']['parameters']={variable:{'type_name':'TYPE_NAME_'+kind}}
            yield c
    for value in [-9.223372036854775808e18,-9.2233720368547748e18]:
        c=condition_case('int(x)<0',{'x':value})
        c['model']['conditions']['cel_condition']['parameters']={'x':{'type_name':'TYPE_NAME_DOUBLE'}}
        yield c
    for stamp in ['0001-01-01T00:00:00Z','2026-01-01T00:00:00Z']:
        c=condition_case('ts-d>ts',{'ts':stamp,'d':'-9223372036854775808ns'})
        c['model']['conditions']['cel_condition']['parameters']={'ts':{'type_name':'TYPE_NAME_TIMESTAMP'},'d':{'type_name':'TYPE_NAME_DURATION'}}
        yield c


    for expression in [
        'int(-9.223372036854775808e18)<0',
        'timestamp("0001-01-01T00:00:00Z")-duration("-9223372036854775808ns")>timestamp("0001-01-01T00:00:00Z")',
        'timestamp("2026-01-01T00:00:00Z")-duration("-9223372036854775808ns")>timestamp("2026-01-01T00:00:00Z")',
    ]:
        yield condition_case(expression)


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=Path('conformance-results/r9-rework/review'));a=p.parse_args()
    a.output.mkdir(parents=True,exist_ok=True)
    for name,values in [('cost',cost_cases()),('index',(c for c in cost_cases() if c['family'].startswith('index'))),('api',api_cases())]:
        rows=list(values);(a.output/f'{name}.json').write_text(json.dumps(rows,ensure_ascii=False)+'\n');print(name,len(rows))

if __name__=='__main__':main()
