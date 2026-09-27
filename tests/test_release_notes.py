"""Regression checks for GitHub's release-body limit and tagged release summaries."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, call

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release_notes', ROOT / '.github/scripts/prepare_release_notes.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseNotesTests(unittest.TestCase):
    tag = 'v0.11.0-beta'
    toc = '## Version: 0.11.0\n'
    summary = '## v0.11.0-beta - 2026-09-27\n\n- Complete batch summary.\n'

    def test_large_history_does_not_enter_release_body(self):
        history = '# Changelog\n\n' + self.summary + '\n## v0.10.8-beta - 2026-09-26\n' + 'History\n' * 20000
        self.assertEqual(module.release_notes(self.tag, self.toc, history), self.summary)

    def test_preserves_subheadings_and_all_bullets(self):
        notes = self.summary + '\n### Fixes\n\n- Another change.\n'
        self.assertEqual(module.release_notes(self.tag, self.toc, notes), notes)

    def test_rejects_wrong_tag_missing_duplicate_empty_and_oversized_notes(self):
        for toc, notes in [
            ('## Version: 0.11.1\n', self.summary),
            (self.toc, '## v0.11.0-beta - Unreleased\n- Pending.\n'),
            (self.toc, self.summary + '\n' + self.summary),
            (self.toc, self.summary.split('\n')[0] + '\n'),
            (self.toc, self.summary + 'x' * 120000),
            (self.toc, self.summary + 'x\n' * 41000),
        ]:
            with self.subTest(toc=toc, size=len(notes)), self.assertRaises(ValueError):
                module.release_notes(self.tag, toc, notes)

    def test_recovery_reads_unchanged_published_tag(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(
            module.subprocess, 'check_output',
            side_effect=[self.toc.encode(), self.summary.encode()],
        ) as read:
            destination = Path(directory) / 'notes.md'
            module.main(self.tag, destination)
            notes = destination.read_text(encoding='utf-8')
            self.assertEqual(notes, self.summary)
            self.assertEqual(read.call_args_list, [
                call(['git', 'show', f'refs/tags/{self.tag}:AzerothFieldbook.toc']),
                call(['git', 'show', f'refs/tags/{self.tag}:CHANGELOG.md']),
            ])

    def test_rejects_branch_or_option_instead_of_tag(self):
        with patch.object(module.subprocess, 'check_output') as read:
            for tag in ['main', '--help', 'v0.11.0-beta:README.md']:
                with self.assertRaises(ValueError):
                    module.main(tag, 'unused.md')
            read.assert_not_called()


if __name__ == '__main__':
    unittest.main()
