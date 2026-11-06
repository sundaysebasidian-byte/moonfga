#!/usr/bin/env python3
"""Exercise module CLI loading, transformations, store tests and path containment."""
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run(target, *args, success=True):
    result = subprocess.run(
        ['moon', 'run', 'cmd/main', '--target', target, '--', *map(str, args)],
        cwd=ROOT, text=True, capture_output=True,
    )
    assert result.returncode >= 0, result.stdout + result.stderr
    assert 'PanicError' not in result.stderr, result.stderr
    assert (result.returncode == 0) == success, result.stdout + result.stderr
    return result.stdout


for target in ('native', 'js'):
    run(target, 'validate', 'examples/modules/fga.mod')
    result = json.loads(run(target, 'transform', 'examples/modules/fga.mod', '--to', 'json'))
    assert result['schema_version'] == '1.2'
    assert result['type_definitions'][1]['metadata']['relations']['viewer']['source_info']['file'] == 'document.fga'
    assert 'define viewer: [user]' in run(target, 'transform', 'examples/modules/fga.mod', '--to', 'dsl')
    assert 'assertions: 1/1 passed' in run(target, 'test', 'examples/modules/store.fga.yaml')
    with tempfile.TemporaryDirectory(prefix='moonfga-modules-') as temp:
        root = Path(temp)
        (root / 'model').mkdir()
        (root / 'outside.fga').write_text('module outside\ntype user\n')
        (root / 'model' / 'escape.fga').symlink_to(root / 'outside.fga')
        mod = root / 'model' / 'fga.mod'
        for path in ('../outside.fga', 'escape.fga'):
            mod.write_text(f"schema: '1.2'\ncontents: ['{path}']\n")
            run(target, 'validate', mod, success=False)
        (root / 'model' / 'sub').symlink_to(root, target_is_directory=True)
        mod.write_text("schema: '1.2'\ncontents: ['sub/outside.fga']\n")
        run(target, 'transform', mod, '--to', 'json', success=False)
    with tempfile.TemporaryDirectory(prefix='moonfga-module-regressions-') as temp:
        root = Path(temp)
        mod = root / 'fga.mod'
        first = 'module shared\ntype user\ntype document\nextend type document\n relations\n  define viewer: [user]\n'
        second = 'extend type document\n relations\n  define editor: [user]\n'
        (root / 'a.fga').write_text(first + second)
        mod.write_text("schema: '1.2'\ncontents: [a.fga]\n")
        run(target, 'validate', mod, success=False)
        tuples = root / 'tuples.json'
        tuples.write_text(json.dumps([{'object': 'document:1', 'relation': 'editor', 'user': 'user:bob'}]))
        run(target, 'check', '--model', mod, '--object', 'document:1',
            '--relation', 'editor', '--user', 'user:bob', '--store', tuples, success=False)
        (root / 'a.fga').write_text(first)
        (root / 'b.fga').write_text('module shared\n' + second)
        mod.write_text("schema: '1.2'\ncontents: [a.fga, b.fga]\n")
        run(target, 'validate', mod)
        assert run(target, 'check', '--model', mod, '--object', 'document:1',
                   '--relation', 'editor', '--user', 'user:bob', '--store', tuples).strip() == 'true'
        mod.write_text("schema: '1.2'\ncontents: [a.fga]\nloop: &a [*a]\n")
        run(target, 'validate', mod, success=False)
        mod.write_text("version: &v '1.2'\nschema: *v\nfiles: &f [a.fga]\ncontents: *f\n")
        run(target, 'validate', mod)
    print(f'{target}: module CLI and containment passed')
