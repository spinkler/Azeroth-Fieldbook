"""Run the complete suite, including script-style Lua assertions, in isolation."""
from pathlib import Path
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime


def validate_addon():
    toc = (ROOT / 'AzerothFieldbook.toc').read_text(encoding='utf-8')
    manifest = [line.strip() for line in toc.splitlines()
                if line.strip() and not line.startswith('#')]
    runtime = LuaRuntime()
    assert len(manifest) == len(set(manifest)), 'Duplicate TOC entry'
    assert set(manifest) == {p.name for p in ROOT.glob('*.lua')}, 'TOC/runtime file mismatch'
    for name in manifest:
        runtime.compile((ROOT / name).read_text(encoding='utf-8'), name=name)
    ET.parse(ROOT / 'Bindings.xml')
    version = re.search(r'^## Version: (\S+)$', toc, re.MULTILINE).group(1)
    readme = (ROOT / 'README.md').read_text(encoding='utf-8')
    changelog = (ROOT / 'CHANGELOG.md').read_text(encoding='utf-8')
    assert readme.startswith(f'# Azeroth Fieldbook {version} '), 'README version mismatch'
    assert re.search(r'^## v(?:[0-9.]+ - v)?' + re.escape(version) + r'(?:\s|\-)', changelog, re.MULTILINE), 'Missing current changelog'
    tag = os.environ.get('GITHUB_REF', '')
    if tag.startswith('refs/tags/'):
        assert tag.removeprefix('refs/tags/') in {
            f'v{version}', f'v{version}-alpha', f'v{version}-beta'
        }, 'Release tag does not match the TOC version/channel'
    print(f'PASS: {len(manifest)} Lua 5.1 files, manifest, bindings and version {version}', flush=True)


def main():
    validate_addon()
    tests = sorted((ROOT / 'tests').glob('test_*.py'))
    if not tests:
        raise RuntimeError('No test scripts found')
    failed = []
    for test in tests:
        print(f'RUN {test.name}', flush=True)
        result = subprocess.run([sys.executable, '-B', '-X', 'utf8', str(test)], cwd=ROOT)
        if result.returncode:
            failed.append(test.name)
    print(f'RESULT: {len(tests)} test files, {len(failed)} failed', flush=True)
    if failed:
        print('Failed: ' + ', '.join(failed), file=sys.stderr)
    return bool(failed)


if __name__ == '__main__':
    sys.exit(main())
