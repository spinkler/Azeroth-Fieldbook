"""Publish one complete release summary, retaining repository changelog history."""
from pathlib import Path
import re
import subprocess
import sys


def release_notes(tag, toc, changelog):
    version = re.search(r'^## Version: (\S+)$', toc, re.MULTILINE)
    if not version or tag not in {
        f'v{version[1]}', f'v{version[1]}-alpha', f'v{version[1]}-beta'
    }:
        raise ValueError('Release tag does not match the TOC version/channel')
    headings = list(re.finditer(r'^## .+$', changelog, re.MULTILINE))
    matches = [i for i, heading in enumerate(headings)
               if re.fullmatch(r'## ' + re.escape(tag) + r' - \d{4}-\d{2}-\d{2}', heading[0])]
    if len(matches) != 1:
        raise ValueError('Expected exactly one dated changelog heading for the release tag')
    index = matches[0]
    start = headings[index].start()
    end = headings[index + 1].start() if index + 1 < len(headings) else len(changelog)
    notes = changelog[start:end].strip() + '\n'
    if not notes.partition('\n')[2].strip():
        raise ValueError('Release summary is empty')
    # Leave space below GitHub's 125,000-character limit for newline conversion.
    if len(notes.replace('\n', '\r\n')) > 120000:
        raise ValueError('Release summary exceeds the publication size budget')
    return notes


def main(tag, destination):
    if not re.fullmatch(r'v\d+\.\d+\.\d+(?:-alpha|-beta)?', tag):
        raise ValueError('Expected a versioned release tag')
    ref = f'refs/tags/{tag}'
    def read_file(name):
        return subprocess.check_output(['git', 'show', f'{ref}:{name}']).decode('utf-8').replace('\r\n', '\n')
    notes = release_notes(tag, read_file('AzerothFieldbook.toc'), read_file('CHANGELOG.md'))
    Path(destination).write_text(notes, encoding='utf-8', newline='\n')
    print(f'Prepared {tag} release notes: {len(notes)} characters')


if __name__ == '__main__':
    main(*sys.argv[1:])
