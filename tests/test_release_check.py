"""Check runner failure reporting and actual host configuration selection."""
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('release_check', Path(__file__).resolve().parents[1] / 'tools/release_check.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class ReleaseCheck(unittest.TestCase):
    def execute(self, run):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch.object(runner, 'ROOT', root), patch.object(sys, 'argv', ['release_check.py']), \
                    patch.object(runner.subprocess, 'check_output', return_value='abc'), \
                    patch.object(runner.subprocess, 'run', side_effect=run):
                code = runner.main()
            report = json.loads(next((root / '.pio/release-checks').glob('*/report.json')).read_text())
            return code, report

    def test_distinct_configurations(self):
        commands = []
        def run(command, **kwargs):
            commands.append(command)
            return subprocess.CompletedProcess(command, 0)
        code, _ = self.execute(run)
        self.assertEqual(code, 0)
        configure = [c for c in commands if c[:2] == ['cmake', '-S']]
        self.assertEqual(len(configure), 2)
        self.assertIn('-DCMAKE_BUILD_TYPE=Debug', configure[0])
        self.assertIn('-DCMAKE_BUILD_TYPE=Release', configure[1])
        self.assertNotEqual(configure[0][configure[0].index('-B') + 1], configure[1][configure[1].index('-B') + 1])

    def test_timeout_still_writes_failed_report(self):
        def run(command, **kwargs):
            if command[0] == 'pio':
                raise subprocess.TimeoutExpired(command, 1)
            return subprocess.CompletedProcess(command, 0)
        code, report = self.execute(run)
        self.assertEqual(code, 1)
        self.assertEqual(report['local_result'], 'FAIL')
        self.assertEqual(next(c for c in report['checks'] if c['name'] == 'production-firmware')['result'], 'FAIL')

    def test_each_child_has_a_timeout(self):
        def run(command, **kwargs):
            self.assertGreater(kwargs.get('timeout', 0), 0, command)
            return subprocess.CompletedProcess(command, 0)
        self.execute(run)
