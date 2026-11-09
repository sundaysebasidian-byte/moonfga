"""Review r8 reproductions and systematic CEL lexical/grammar/cost boundaries."""
import json

def cases():
    # The original independently authored 25 cases, retained verbatim.
    from r8_divergences import E
    for c in E:
        d=c['model']['conditions']['cel_condition']
        yield d['expression'],c['context'],d['parameters']
    context={'n':1,'s':'a'*40}
    for e in ['!!n==1','--n==1','!-n==1','-!true==1']:
        yield e,{'n':1,'s':''}
    for count in [1,2,3,50,97,98,99,100,200,400]:
        for op,tail in [('!','(n==1)==true'),('-','n == -1')]:
            yield op*count+tail,context
    for text in ['0x10','0X10','0xFF','0XFF','0x','0X','01','00','00.1','1.','0.','1.e3','1.e+2','1.e-2','.1','.1e3','1.0','1e3','1e','1e+','1_0','0x1u','0X1U','0xffU','18446744073709551616u']:
        yield f'dyn({text})==dyn(1)',context
    for text in ['NaN','nan','NAN','+NaN','-NaN','-nan','+nan','Inf','-Inf','+Inf','Infinity','-infinity',' 1','1 ','1.','1.e3','0x10','0X1p0','0x1p0','1_0','0x1_ffp0']:
        yield f'double({json.dumps(text)}) != 0.0',context
        yield 'double(s) != 0.0',dict(context,s=text)
    for pattern in ['a{'+x+'}' for x in ['0','00','01','000001','1','1,','01,','1,01','0,01','01,01',',1','1,0','1000','1001','999999999999999999','999999999999999999x','1x','1,2,3']]+['a*{01}','a{1}{01}','a{1}{2}','{1}','{01}']:
        for value in ['', 'a','aa',pattern]:
            yield f'{json.dumps(value)}.matches({json.dumps(pattern)})',context
    classes=[r'[\d-a]',r'[a-\d]',r'[\d-\w]',r'[\w-a]',r'[\s-z]',r'[\D-a]',r'[\p{Han}-a]',r'[[:digit:]-a]',r'[a-[:digit:]]',r'[a-]',r'[-a]',r'[]a]',r'[^]a]',r'[z-a]',r'[a-\x7a]',r'[\x61-z]',r'[a-b-c]',r'[\b]',r'[\q]',r'[\Qab\E]']
    for pattern in classes:
        for value in ['a','-','1','中','z','\n']:
            yield f'{json.dumps(value)}.matches({json.dumps(pattern)})',context
    for key in ['int','1.0','-0.0','double("NaN")','double("Inf")','ipaddress("127.0.0.1")','null','duration("1s")','timestamp(0)']:
        for expression in [f'{{{key}:1}}.size()==1',f'{{{key}:1}}[dyn({key})]==1',f'dyn({key}) in {{{key}:1}}',f'dyn({{{key}:1}})==dyn({{{key}:1}})']:
            yield expression,context
    for e in ['{1.0:1}[dyn(1)]==1','{1:1}[dyn(1.0)]==1','dyn(1) in {1.0:1}','(null+null)==null','(null-null)==null','(null*null)==null','(null/null)==null','(null%null)==null','-null==null','null<null','false?false?true:false:false==true','false?(false?true:false):false==true','false?true:false?true:false']:
        yield e,context
    for depth in [1,100,248,249,250,251]:
        yield '('*depth+'1'+')'*depth+'==1',context
        yield 'size('+'['*depth+'1'+']'*depth+')==1',context
    for count in [1,8,16,32,64]:
        for body in ['n+1','-n','!true','int("1")','type(n)']:
            yield '['+','.join(['1']*count)+f'].map(x,{body}).size()=={count}',context
