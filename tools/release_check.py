"""Repeatable local regression checks. Never flashes or opens a serial port."""
import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HARDWARE = [
    ('pair', 'Fresh pairing: matching codes, BOTH approvals, trust survives restart.'),
    ('reject', 'Reject/cancel/timeout pairing: no trust or receiver controls enabled.'),
    ('dial_first', 'Dial starts first; Tab5 connects after splash and channel settling.'),
    ('tablet_first', 'Tab5 starts first; Dial reconnects on USB and battery.'),
    ('either_connect', 'Connect initiated from either device establishes a session.'),
    ('missing', 'Absent accessory/router: tablet remains usable; standalone link works after bounded Wi-Fi attempt.'),
    ('loss', 'Unexpected link loss: bounded retry reconnects without opening pairing.'),
    ('disconnect', 'Disconnect from EACH device: both stay disconnected until explicit Connect or restart.'),
    ('boot_toggle', 'Boot-connect off/on persists and controls automatic connection after restart.'),
    ('revoke', 'Forget while peer offline: stale peer cannot control; fresh pairing needs both approvals.'),
    ('devices', 'Devices works offline; receiver updates do not leave Devices/verification/confirmation; text fits.'),
    ('controls', 'Each supported dashboard: correct focus and controls, acknowledged tuning; restore original radio state.'),
    ('receiver', 'Router Wi-Fi stable, spectrum/waterfall moving, normal audio; inspect serial logs for faults.'),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mbedtls-source', type=Path, help='Mbed TLS 3.6 source tree; needed for a fresh host build.')
    parser.add_argument('--build-dir', type=Path, default=ROOT / '.pio/release-check-host')
    parser.add_argument('--pio', default='pio', help='PlatformIO executable.')
    parser.add_argument('--hardware', action='store_true', help='Record operator-observed acceptance; does not operate devices.')
    args = parser.parse_args()
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    output = ROOT / '.pio/release-checks' / stamp
    output.mkdir(parents=True)
    def git(*cmd):
        return subprocess.check_output(['git', *cmd], cwd=ROOT, text=True).strip()
    report = {'utc': stamp, 'commit': git('rev-parse', 'HEAD'),
              'dirty': bool(git('status', '--porcelain')), 'checks': [], 'hardware': [],
              'release_gates': {'independent_security_review': 'NOT VERIFIED BY THIS SUITE'}}

    def run(name, command):
        log = output / (name + '.log')
        print(f'Running {name}: {subprocess.list2cmdline(command)}', flush=True)
        try:
            with log.open('w', encoding='utf-8') as stream:
                result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
            code = result.returncode
        except OSError as error:
            log.write_text(str(error), encoding='utf-8')
            code = 127
        report['checks'].append({'name': name, 'command': command, 'result': 'PASS' if code == 0 else 'FAIL', 'exit': code, 'log': str(log)})
        print(f'{name}: {report["checks"][-1]["result"]}', flush=True)
        return code == 0

    config = ['cmake', '-S', 'tests', '-B', str(args.build_dir)]
    if args.mbedtls_source:
        config.append('-DMBEDTLS_SOURCE_DIR=' + str(args.mbedtls_source.resolve()))
    if run('configure', config):
        for mode in ('Debug', 'Release'):
            if run('build-' + mode, ['cmake', '--build', str(args.build_dir), '--config', mode]):
                run('test-' + mode, ['ctest', '--test-dir', str(args.build_dir), '-C', mode, '--output-on-failure'])
    run('capture-guards', [sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_capture_guards.py'])
    run('devices-captures', [sys.executable, 'tools/validate_captures.py', 'docs/screenshots/devices'])
    run('production-firmware', [args.pio, 'run', '-e', 'dial'])
    run('documentation-firmware', [args.pio, 'run', '-e', 'doc_capture'])
    report['firmware_sha256'] = {}
    for env in ('dial', 'doc_capture'):
        firmware = ROOT / '.pio/build' / env / 'firmware.bin'
        if firmware.exists():
            report['firmware_sha256'][env] = hashlib.sha256(firmware.read_bytes()).hexdigest()
    for key, instruction in HARDWARE:
        answer = 'SKIP'
        notes = ''
        if args.hardware:
            print('\n' + instruction)
            answer = input('Observed result [pass/fail/skip]: ').strip().upper()
            if answer not in ('PASS', 'FAIL', 'SKIP'):
                answer = 'SKIP'
            notes = input('Evidence/log path and setup notes: ').strip()
            if answer == 'PASS' and not notes:
                answer = 'SKIP'
                notes = 'No evidence supplied.'
        report['hardware'].append({'name': key, 'instruction': instruction, 'result': answer, 'evidence': notes})
    local_pass = all(c['result'] == 'PASS' for c in report['checks'])
    report['local_result'] = 'PASS' if local_pass else 'FAIL'
    report['hardware_result'] = ('FAIL' if any(c['result'] == 'FAIL' for c in report['hardware']) else
                                 'PASS' if all(c['result'] == 'PASS' for c in report['hardware']) else 'INCOMPLETE')
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    lines = [f'# OrcDial regression report — {stamp}', '', f'Commit: `{report["commit"]}`; dirty: {report["dirty"]}',
             f'Local: **{report["local_result"]}**. Hardware: **{report["hardware_result"]}**.',
             'Independent security review: not verified by this suite. This report does not authorize publication.', '']
    for check in report['checks']:
        lines.append(f'- {check["name"]}: {check["result"]}; command: `{subprocess.list2cmdline(check["command"])}`; log: `{check["log"]}`')
    lines += ['', 'Hardware observations:']
    lines += [f'- {c["name"]}: {c["result"]}. {c["evidence"]}' for c in report['hardware']]
    (output / 'report.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'Local {report["local_result"]}; hardware {report["hardware_result"]}. Report: {output / "report.md"}')
    return 1 if not local_pass or report['hardware_result'] == 'FAIL' else 0


if __name__ == '__main__':
    sys.exit(main())
