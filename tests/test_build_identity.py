"""Check source identity stamping against real clean and edited Git trees."""
import importlib.util
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('build_identity', ROOT / 'tools/ci/build-identity.py')
identity = importlib.util.module_from_spec(spec)
spec.loader.exec_module(identity)
spec = importlib.util.spec_from_file_location('build_info', ROOT / 'tools/ci/write-build-info.py')
build_info = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build_info)


class BuildIdentityTest(unittest.TestCase):
    def test_clean_and_dirty_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-C', str(root), *args], text=True).strip()
            git('init', '-q')
            git('config', 'user.name', 'Test')
            git('config', 'user.email', 'test@example.invalid')
            (root / 'source.txt').write_text('original')
            git('add', 'source.txt')
            git('commit', '-qm', 'test source')
            self.assertEqual(identity.source_identity(root), (git('rev-parse', 'HEAD'), False))
            git('tag', 'v0.1.0-beta.1')
            with patch.object(build_info, 'git', git):
                self.assertEqual(build_info.latest_base_tag(), 'v0.1.0-beta.1')
                git('tag', 'orcdial-v0.1.0-beta.1')
                (root / 'source.txt').write_text('next source')
                git('commit', '-qam', 'next source')
                git('tag', 'v9.0.0')
                self.assertEqual(build_info.latest_base_tag(), 'orcdial-v0.1.0-beta.1')
            (root / 'source.txt').write_text('modified')
            self.assertEqual(identity.source_identity(root), (git('rev-parse', 'HEAD'), True))

    def test_non_repository_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(subprocess.CalledProcessError):
                identity.source_identity(Path(directory))


if __name__ == '__main__':
    unittest.main()
