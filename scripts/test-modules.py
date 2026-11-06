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
    print(f'{target}: module CLI and containment passed')
