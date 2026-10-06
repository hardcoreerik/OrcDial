# OrcDial regression and release checks

From the repository root, with Python (Pillow and pyserial), CMake, a C++17
compiler, PlatformIO and Mbed TLS 3.6 LTS sources installed:

```powershell
python tools/release_check.py --mbedtls-source C:/Espressif/frameworks/esp-idf-v5.5.4/components/mbedtls/mbedtls
```

Use `--pio <executable>` if PlatformIO is not on PATH. Later runs can omit
`--mbedtls-source` when reusing the configured build directory. This command
does not flash, reset devices, change trust or open serial ports.

The suite runs the four native tests in Debug and Release, tests partial-capture
safeguards, verifies the saved Devices gallery and builds `dial` and `doc_capture`.
Native tests cover cryptographic vectors, pairing/confirmation failures,
authenticated controls, tampering/replay, fragmentation recovery, legacy rejection
and runtime initialization failures. They cannot prove real radio timing, actual
power-loss storage behavior or audible sound quality. Saved gallery checks verify
documentation fixtures, not live screen behavior.

Each run saves command output, source revision/dirty status, firmware hashes and
JSON/Markdown results under `.pio/release-checks/<UTC timestamp>/`. Exit 1 means
a local or observed hardware failure. Exit 0 means local checks passed; read
`hardware_result` before claiming hardware acceptance. Default hardware status
is INCOMPLETE. Independent security review is a separate publication gate.

## After flashing both applications

Preserve recovery firmware and serial logs first. Flash **production `dial`**,
never `doc_capture`, and the matching Tab5 application. This suite does not update
the C6. Coordinate serial ownership: a monitor and a script cannot own the same
port. Serial smoke scripts check version 4 without initiating pairing:

```powershell
python tests/serial_smoke.py --port COM14
python tests/host_probe.py --port COM17
python tools/release_check.py --hardware
```

The last command reruns local checks and asks for observed pass/fail/skip plus
evidence for each hardware case. A pass without evidence is recorded as skipped.
Record both firmware revisions/hashes, antenna/band, speaker/audio setup, router
channel and log paths. Perform trust deletion/re-pair tests only on test devices.
Compare codes on BOTH screens before approving. Restore the initial dashboard,
frequency, step and volume after control tests.

Hardware cases cover both startup orders, USB/battery, connection from either
device, absent router/accessory, loss/retry, intentional disconnect from each
side, boot toggle, offline revocation, Devices navigation and supported dashboard
controls. Finally verify stable Wi-Fi, acknowledged tuning, moving spectrum and
waterfall, and normal audio on the Tab5. Interrupting actual storage writes and
power during confirmation needs a separately coordinated hardware test; host
fault injection does not replace it.

Do not publish a beta merely because local checks pass. Hardware acceptance and
independent security review remain separate requirements. Leave `v0.1.0-beta.1`
unchanged.
