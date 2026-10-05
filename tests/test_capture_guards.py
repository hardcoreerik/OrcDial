"""Reject unsafe partial captures before touching a serial port or gallery."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class CaptureGuards(unittest.TestCase):
    def check_rejected(self, *args):
        result = subprocess.run([sys.executable, str(ROOT / 'tools/capture_screens.py'), '--port', 'INVALID_PORT', *args],
                                cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn('--only requires an explicit --output folder without manifest.json', result.stderr)

    def test_partial_requires_output(self):
        self.check_rejected('--only', 'home-demo')

    def test_existing_manifest_untouched(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / 'manifest.json'
            manifest.write_bytes(b'preserve this manifest')
            self.check_rejected('--only', 'home-demo', '--output', directory)
            self.assertEqual(manifest.read_bytes(), b'preserve this manifest')
            self.assertEqual(list(Path(directory).iterdir()), [manifest])
