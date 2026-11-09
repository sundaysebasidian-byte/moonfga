"""Well-known protobuf CEL descriptors and portable wire-format oracle cases."""
import struct
import random
import json
from pathlib import Path


def expressions(seed):
    exprs=[]
    def add(e):exprs.append(e)
    for name,default,val in [('BoolValue','false','true'),('BytesValue','b""','b"hi"'),('StringValue','""','"hi"'),('DoubleValue','0.0','1.0'),('FloatValue','0.0','1.5'),('Int32Value','0','123'),('Int64Value','0','123'),('UInt32Value','0u','123u'),('UInt64Value','0u','123u')]:
     t='google.protobuf.'+name
     for e in [f'{t}{{}} == {default}',f'{t}{{value:{val}}} == {val}',f'type({t}{{}}) == {t}', f'{t} == type({default})',f'{t}{{value:"bad"}} == {default}',f'{t}{{missing:1}} == {default}',f'{t}{{value:{val},value:{val}}} == {val}',f'has({t}{{}}.value)',f'{t}{{}}.value == {default}'] :add(e)
    for name in ['Timestamp','Duration','Any','Empty','Struct','ListValue','Value','FieldMask','NullValue','Struct.FieldsEntry']:
     add(f'type(google.protobuf.{name}{{}}) == google.protobuf.{name}')
    for e in ['google.protobuf.Value{number_value:1} == 1.0', 'google.protobuf.Value{null_value:1} == null','google.protobuf.Struct{fields:{1:2}} == {}','google.protobuf.Value{struct_value:{"a":1}}.a==1.0','google.protobuf.Value{list_value:[b"hi"]}[0] == "aGk="','google.protobuf.Any{typeUrl:"foo"} == 1','google.protobuf.NullValue.NULL_VALUE == 0', 'google.protobuf.Value{number_value:double("NaN")} == "NaN"','google.protobuf.Value{number_value:double("+Inf")} == "Infinity"', 'google.protobuf.Struct{fields:{"x":double("+Inf")}}.x == "Infinity"', 'google.protobuf.ListValue{values:[timestamp(0)]}[0] == "1970-01-01T00:00:00Z"','google.protobuf.ListValue{values:[duration("1s")]}[0]=="1s"', '[google.protobuf.Empty{},google.protobuf.Empty{},google.protobuf.Empty{}].size()==3']:add(e)
    for sec in [-9223372036854775808,-9223372036854775807,-9223372036854776,-62135596801,-1,0,253402300800,9223372036854776,9223372036854775807]:
     for suf in ['>timestamp(0)','==google.protobuf.Timestamp{seconds:'+str(sec)+'}', '.getFullYear() > 0','.getHours() >=0','.getMilliseconds()==0','+ duration("0s") == timestamp(0)', '-timestamp(0) ==duration("0s")', '']: 
      obj=f'google.protobuf.Timestamp{{seconds:{sec}}}'
      add('int('+obj+') == '+str(sec) if suf=='' else obj+suf)
     # exact str/getters compare into oracle outcomes with const expected manually guessed
     add('string('+obj+') == "x"')
    def blit(b):return 'b"'+''.join('\\x%02x'%c for c in b)+'"'
    for name,payload in [('BoolValue',b'\x08\x01'),('Int64Value',b'\x08\x01'),('Int32Value',b'\x08\xff\xff\xff\xff\x0f'),('UInt32Value',b'\x08\xff\xff\xff\xff\x1f'),('DoubleValue',b'\x09'+struct.pack('<d',1.0)),('FloatValue',b'\x0d'+struct.pack('<f',1.5)),('BytesValue',b'\x0a\x02hi'),('StringValue',b'\x0a\x02hi'),('Empty',b''),('Value',b'\x11'+struct.pack('<d',1.5)),('ListValue',b'\x0a\x09\x11'+struct.pack('<d',1.5)),('Any',b''),('FieldMask',b''),('no.Such',b'')]:
     t='google.protobuf.'+name
     for p in [payload,b'',b'\x80',b'\x00',b'\x0f',b'\x08\x01',b'\x0a\x00',payload+b'\x18\x01',payload+b'\x2b\x08\x01\x2c']:
      obj=f'google.protobuf.Any{{type_url:"type.googleapis.com/{t}", value:{blit(p)}}}'
      add('type('+obj+') == int')
    yield from json.loads(Path(__file__).with_name("cel_protobuf_time_cases.json").read_text())
    for e in exprs:
        yield e
    for name in ["Int64Value","UInt64Value","BoolValue","StringValue","BytesValue","DoubleValue"]:
        t = "google.protobuf."+name
        for value in ['dyn("bad")','dyn(1)','dyn(1u)','dyn(1.0)','dyn(true)','dyn(null)']:
            yield f'{t}{{value:{value}}} == dyn(0)'
    for e in [
        'google.protobuf.Struct.FieldsEntry{}.key == ""',
        '!has(google.protobuf.Struct.FieldsEntry{}.value)',
        'has(google.protobuf.Struct.FieldsEntry{value:null}.value)',
        'google.protobuf.Struct.FieldsEntry{value:1}.value == 1.0',
        'google.protobuf.Struct.FieldsEntry{key:"x",value:1}.key == "x"',
        'google.protobuf.Struct.FieldsEntry{value:b"hi"}.value == "aGk="',
        'google.protobuf.Value{null_value:2147483648} == null',
        'google.protobuf.Value{null_value:9223372036854775807} == null',
        'google.protobuf.Duration{seconds:1,nanos:2147483648} == duration("1s")',
        'google.protobuf.Int64Value{value:null} == null',
    ]: yield e
    rng = random.Random(seed ^ 0xB0F)
    for _ in range(128):
        n=rng.randrange(-2**63,2**63)
        unsigned=n % 2**64
        encoded=[]
        while unsigned>127:
            encoded.append(128 | (unsigned&127));unsigned >>= 7
        encoded.append(unsigned)
        payload=bytes([8]+encoded)
        yield f'google.protobuf.Any{{type_url:"google.protobuf.Int64Value",value:{blit(payload)}}} == {n}'
        n=rng.choice([-2**63, -2**31, -1, 0, 2**31-1, 2**63-1])
        yield f'google.protobuf.Int32Value{{value:{n}}} == {n}'
