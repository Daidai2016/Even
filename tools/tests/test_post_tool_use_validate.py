"""Run Hook regressions in disposable repositories under work/ (no network/commits)."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HOOK = ROOT / '.codex/hooks/post_tool_use_validate_v1.1.0.ps1'


class ValidationHookTest(unittest.TestCase):
    def setUp(self):
        parent = ROOT / 'work/instruction-audit-tests'
        parent.mkdir(parents=True, exist_ok=True)
        self.repo = Path(tempfile.mkdtemp(prefix='hook-', dir=parent))
        self.run_command(['git', 'init', '-q'])
        (self.repo / '.git/info/exclude').write_text('tools/\nwork/\n*.txt\n', encoding='utf-8')
        (self.repo / 'tools').mkdir()
        self.validator = self.repo / 'tools/validate_repository.ps1'
        self.validator.write_text('''param([switch]$ChangedOnly,[switch]$Quiet,[switch]$NoPause)
if (-not ($ChangedOnly -and $Quiet -and $NoPause)) { exit 9 }
[IO.File]::AppendAllText((Join-Path (Get-Location) 'runs.txt'), "run`n")
if (Test-Path -LiteralPath 'fail.txt') { Write-Output 'fixture validation error'; exit 1 }
exit 0
''', encoding='utf-8-sig')

    def tearDown(self):
        # Preserve fixtures for inspection; work/instruction-audit-tests is ignored.
        pass

    def run_command(self, command, **kwargs):
        return subprocess.run(command, cwd=self.repo, check=True, capture_output=True, **kwargs)

    def invoke(self, tool='shell_command', session='fixture-session'):
        result = self.run_command(
            ['powershell.exe', '-NoProfile', '-File', str(HOOK)],
            input=json.dumps({'tool_name': tool, 'session_id': session}).encode(), timeout=20)
        output = result.stdout.decode('utf-8-sig', errors='replace').strip()
        return json.loads(output) if output else None

    def count(self):
        path = self.repo / 'runs.txt'
        return len(path.read_text().splitlines()) if path.exists() else 0

    def change(self, value):
        (self.repo / 'sample.ps1').write_text(value, encoding='utf-8-sig')

    def test_clean_and_unrelated_calls(self):
        self.assertIsNone(self.invoke())
        (self.repo / 'note.txt').write_text('unrelated')
        self.assertIsNone(self.invoke())
        self.change('Write-Output 1')
        self.assertIsNone(self.invoke(tool='unmatched_tool'))
        self.assertEqual(self.count(), 0)

    def test_same_content_skips_but_edits_revalidate(self):
        self.change('Write-Output 1')
        self.assertIsNone(self.invoke())
        self.assertIsNone(self.invoke())
        self.assertEqual(self.count(), 1)
        self.change('Write-Output 2')
        self.invoke(tool='apply_patch')
        self.assertEqual(self.count(), 2)
        self.invoke(session='another-session')
        self.assertEqual(self.count(), 3)

    def test_failures_are_advisory_and_recovery_runs(self):
        self.change('Write-Output 1')
        (self.repo / 'fail.txt').write_text('fail')
        response = self.invoke()
        self.assertNotIn('decision', response)
        self.assertEqual(response['hookSpecificOutput']['hookEventName'], 'PostToolUse')
        self.assertIn('fixture validation error', response['hookSpecificOutput']['additionalContext'])
        self.assertIsNone(self.invoke())
        self.assertEqual(self.count(), 1)
        # Change validator behavior without deleting fixture files.
        self.validator.write_text('param([switch]$ChangedOnly,[switch]$Quiet,[switch]$NoPause)\n'
            '[IO.File]::AppendAllText((Join-Path (Get-Location) "runs.txt"), "run`n")\nexit 0\n',
            encoding='utf-8-sig')
        self.assertIsNone(self.invoke())
        self.assertEqual(self.count(), 2)

    def test_cache_corruption_does_not_claim_success(self):
        self.change('Write-Output 1')
        self.invoke()
        cache = next((self.repo / 'work/hook-validation').glob('*.txt'))
        cache.write_text('invalid-cache')
        self.invoke()
        self.assertEqual(self.count(), 2)


if __name__ == '__main__':
    unittest.main()
