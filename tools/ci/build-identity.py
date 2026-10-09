"""Stamp every PlatformIO build with its Git source identity."""
import subprocess


def source_identity(root):
    def git(*args):
        return subprocess.check_output(['git', '-C', str(root), *args], text=True, stderr=subprocess.PIPE).strip()
    return git('rev-parse', 'HEAD'), bool(git('status', '--porcelain'))


if 'Import' in globals():
    Import('env')
    commit, dirty = source_identity(env['PROJECT_DIR'])
    env.Append(CPPDEFINES=[('ORCDIAL_SOURCE_COMMIT', '\\"' + commit + '\\"'),
                          ('ORCDIAL_SOURCE_DIRTY', int(dirty))])
