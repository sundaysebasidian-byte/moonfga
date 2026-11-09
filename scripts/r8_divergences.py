"""Consolidated divergence corpus: every known server-vs-MoonFGA mismatch family."""
import json
from pathlib import Path

NP = {'n': {'type_name': 'TYPE_NAME_INT'}}


def case(expr, context=None, parameters=None, validate=True):
    parameters = parameters if parameters is not None else NP
    return {
        'family': 'cel', 'validate_model': validate,
        'model': {
            'schema_version': '1.1',
            'type_definitions': [
                {'type': 'user'},
                {'type': 'doc', 'relations': {'viewer': {'this': {}}},
                 'metadata': {'relations': {'viewer': {'directly_related_user_types': [{'type': 'user', 'condition': 'cel_condition'}]}}}},
            ],
            'conditions': {'cel_condition': {'name': 'cel_condition', 'expression': expr, 'parameters': parameters}},
        },
        'tuples': [{'object': 'doc:1', 'relation': 'viewer', 'user': 'user:1', 'condition': {'name': 'cel_condition'}}],
        'object': 'doc:1', 'relation': 'viewer', 'user': 'user:1',
        'context': context if context is not None else {'n': 0},
    }


E = []

# A. server evaluates / MoonFGA rejects model
E += [case('(null + null) == null'),
      case('{1.0:1}[1.0] == 1'),
      case('{1.0:1, 2.0:2}.size() == 2'),
      case('{1.0:1}[dyn(1.0)] == 1'),
      case('dyn({1.0:1}) == dyn({1.0:1})'),
      case('{ipaddress("127.0.0.1"):1}.size() == 1'),
      case('"a".matches("[\\\\d-a]")')]
# B. server rejects model / MoonFGA accepts and evaluates
E += [case('0X1f == 31'),
      case('0X10u == 16u'),
      case('1.e3 == 1000.0'),
      case('1. == 1.0'),
      case('double("-nan") != double("-nan")'),
      case('(' * 250 + '1' + ')' * 250 + ' == 1'),
      case('size(' + '[' * 250 + '1' + ']' * 250 + ') == 1'),
      case('false?false?true:false:false == true')]
# C. unary cost: server True/False, MoonFGA E2000 at default budget 100
E += [case('!' * 98 + '(n == 0) == true'),
      case('-' * 99 + 'n == -1', context={'n': 1})]
# D. regex repeat counts with leading zeros: literal upstream, integer repeat locally
E += [case('"a".matches("a{01}")'),
      case('"aa".matches("a{01}")'),
      case('"".matches("a{00}")'),
      case('"a".matches("a{01,}")'),
      case('"aa".matches("a{01,2}")'),
      case('"".matches("a{0,01}")'),
      case('"a".matches("a{000001}")'),
      case('"aa".matches("a{01,01}")')]

if __name__ == '__main__':
    out = Path("conformance-results/r8-divergences")
    out.mkdir(parents=True, exist_ok=True)
    json.dump(E, open(out / "corpus.json", "w"))
    print(len(E), "cases")
