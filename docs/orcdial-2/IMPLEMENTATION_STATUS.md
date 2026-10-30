# OrcDial 2.0 — implementation slice 1, animated UI + FT8 preview

**Development snapshot:** 2026-10-29. **Status: ACTIVE DEVELOPMENT / NOT HARDWARE ACCEPTED / NOT RELEASED.**
**Branch:** `chatgpt/orcdial-2-animated-ui-ft8-20261029`, stacked on planning branch `chatgpt/orcdial-2-design-20261029` (draft PR #14, planning PR #13).
**Receiver branch:** `hardcoreerik/OrcSDR:chatgpt/orcdial-2-ft8-projection-20261029` (draft PR #226).
**No source files merged to main.** The earlier slice-1 firmware was flashed on
COM14 during the preceding authorized session and boot identity verified at
`eb34e83`; that was not two-device FT8 acceptance. The October 30 integration
changes below have not been flashed.

## October 30 integration continuation

The matching OrcSDR development branch now connects real FT8 result draining to
a bounded latest-decode producer and the existing authenticated transport.
Explicit schema-1 negotiation uses existing state/heartbeat fields, with a
3500 ms lease. The Dial now gates metadata on the advertised feature, expires
records after 60 seconds, preserves text across duplicate summaries and rejects
invalid reserved fields or locator associations. No pairing protocol or C6
firmware change was required. See `PROTOCOL.md` and OrcSDR's
`docs/ORCDIAL_FT8_INTEGRATION.md` for the exact contract and validation gates.

The older October 29 notes and evidence ledger below describe the original
slice. The new publisher and capability negotiation supersede the first two
NOT-yet-implemented bullets only; history/multi-station mapping and physical
acceptance remain incomplete.

## Delivered code

- `src/ui_motion.hpp`: allocation-free deterministic phase/breath/progress timers; cheap 240x240 decorative animation, state-responsive VFO focus/pending arcs and dashboard-colored rings.
- `src/ui.cpp`: three faint aurora ribbons behind actual Home VFO digits, slow circuit-style orbital accent and fine radial ticks; FT8 latest-decode card when *received through authenticated link*, valid SNR/grid/message flags, mini offline one-station Maidenhead area-center graticule; violet Dead Air six-tab **read-only** shell (`DETAILS PENDING` until Tab5 publishes state).
- `src/dashboard.hpp`: stable additive IDs SSTV=18, ACARS=19, DEAD_AIR=20; previous IDs untouched. New carousel identities and procedural mini-icons. `src/controller.hpp` refuses implicit actions for these new dashboards until shared semantic receiver handlers exist.
- `src/ft8_projection.hpp`: strict v4 64-byte receiver-only metadata types 17 and 18. Pairing/session protocol, old control types 1..16, crypto and packet length remain unchanged. Rejects invalid role/CRC, sender/sequence mismatch, non-ASCII, hidden bytes and unsupported fields.
- `src/control/link.cpp`: accepts projection records only after authenticated secure-runtime delivery, real RADIO_STATE connection, matching sender identity and active FT8 dashboard; clears on disconnect/sender/dashboard change; ignores out-of-order old records.
- `src/maidenhead_grid.hpp`: offline 4/6/8-character grid-to-area-center conversion. Requires Tab5's specific 'CQ grid associated' flag for the UI to plot a dot.
- Host tests: `tests/ui_motion_test.cpp`, `tests/maidenhead_grid_test.cpp`, `tests/ft8_projection_test.cpp`, updated dashboard/controller/protocol tests. Cross-repo golden bytes shared with OrcSDR emitter tests. Registered through `tests/CMakeLists.txt`.

## Important NOT yet implemented

- **Historical October 29 limitation, superseded October 30:** no live Tab5 publisher then. OrcSDR's new `apps/orcsdr-tab5/ui/ft8_dial_preview.hpp` prepares frames only; it intentionally does not transmit, modify the C6 bridge or call the model from app main. User must not interpret a silent/old Dial as broken because it shows no new decode.
- **Historical October 29 limitation, superseded October 30:** no negotiated peer capability then. A Tab5 must not start sending Type17/18 to older Dials without an explicit negotiated feature/allowlist; old receivers/old Dials must retain their control behavior.
- FT8 history item 2+ is still represented by the Tab5-provided index/count. Map currently shows one validated *latest* CQ locator, not all-stations tracking, no distance/bearing (receiver position not yet projected).
- Dead Air is visual/UI shell only, not remote event/sweep/microphone/clip control and not live dBFS telemetry.
- No PSK Reporter, NOAA, callbook API, actual native M5GFX capture, pairing/coexistence performance measurement, human readability hardware test or firmware flash.

## 64-byte FT8 wire appendix (experimental)

Documented frame format for future capability-gated receiver producer. The secure transport delivers 64 plaintext bytes already authenticated with existing v4 pairing; these fields are not a new encryption mode.

| Offset | Brief: type=17 | Text: type=18 |
|---:|---|---|
| 0..3 | ORDL magic 0x4c44524f LE | same |
| 4..7 | protocol 4, type 17/18, role receiver=2, band=0 | same |
| 8..11 | existing RADIO_STATE sender identity | same |
| 12..15 | monotonic decoded record ID, nonzero | same ID |
| 16..19 | reserved 0 | reserved 0 |
| 20..23 | decode UTC epoch or zero | ASCII printable message prefix |
| 24..27 | captured-slot RF dial Hz | continuation of printable message |
| 28..43 | callsign[16], ASCII+NUL+zero padding | continuation |
| 44..52 | grid[9], ASCII+NUL+zero padding if CQ-associated | continuation |
| 53 | signed SNR in dB; 0 if unavailable | continuation |
| 54 | bitmask: UTC, SNR, grid assoc, assisted/AP, message truncated | continuation |
| 55 | DigitalMode 0..6 | continuation |
| 56..59 | zero reserved | continuation; total text payload 40 bytes max incl NUL (39 visible chars) |
| 60..63 | v4 CRC32 LE of 0..59 | same |

**Do not transmit Type 17/18 until explicit capability negotiation.** CRC detects accidental corruption, not authentication; the existing secure session is mandatory. Constrain metadata rate, use separate sequence IDs from radio-state control, protect DSP priority and disallow mutations from the metadata type.

**Golden bytes:** Decoder tests in both repos assert two identical 128-char lowercase hex wire vectors for `CQ W1AW FN31`, sender 123, record 808, captured dial 14.074 MHz, UTC 1793303100 and SNR -12. These are **synthetic deterministic test fixtures**, not received stations.

## How to build / test (local full checkout)

### Standalone small host tests (no SDK)

Run from the standalone OrcDial repo root, in PowerShell with a C++17 compiler on PATH:

```powershell
New-Item -ItemType Directory -Force -Path .pio/orcdial2-host | Out-Null
g++ -std=c++17 -O2 -Wall -Wextra -Werror tests/ui_motion_test.cpp -o .pio/orcdial2-host/ui_motion_test.exe
g++ -std=c++17 -O2 -Wall -Wextra -Werror tests/maidenhead_grid_test.cpp -o .pio/orcdial2-host/maidenhead_grid_test.exe
g++ -std=c++17 -O2 -Wall -Wextra -Werror tests/ft8_projection_test.cpp -o .pio/orcdial2-host/ft8_projection_test.exe
& .pio/orcdial2-host/ui_motion_test.exe 2>&1 | Tee-Object .pio/orcdial2-host/ui_motion_test.log
& .pio/orcdial2-host/maidenhead_grid_test.exe 2>&1 | Tee-Object .pio/orcdial2-host/maidenhead_grid_test.log
& .pio/orcdial2-host/ft8_projection_test.exe 2>&1 | Tee-Object .pio/orcdial2-host/ft8_projection_test.log
```

On Linux/WSL, remove `.exe` and optionally add `-fsanitize=address,undefined -fno-omit-frame-pointer` to each compilation. CMake `ctest` exercises them as part of the existing full release check.

### Complete OrcDial validation (no flash)

```powershell
python tools/release_check.py --mbedtls-source C:/Espressif/frameworks/esp-idf-v5.5.4/components/mbedtls/mbedtls
```

This runs native C++ tests in Debug/Release, screen capture regression fixtures, PlatformIO `dial` and `doc_capture` firmware builds. It logs each subprocess in `.pio/release-checks/<UTC timestamp>/`. Hardware acceptance remains `INCOMPLETE` until a person tests real devices.

### OrcSDR receiver encoder test (no flash)

From OrcSDR root in WSL, `bash tools/test-ft8.sh`; the branch adds `ft8_dial_preview_tests` (release + ASan/UBSan) to the existing FT8 suite. For a focused invocation:

```bash
mkdir -p .pio/orcdial2-host
g++ -std=c++17 -O2 -Wall -Wextra -Werror -pedantic -Iapps/orcsdr-tab5/ui \
  tests/ft8_dial_preview_tests.cpp apps/orcsdr-tab5/ui/ft8_model.cpp \
  -o .pio/orcdial2-host/ft8_dial_preview_tests
.pio/orcdial2-host/ft8_dial_preview_tests 2>&1 | tee .pio/orcdial2-host/ft8_dial_preview_tests.log
```

### Genuine hardware integration (future, explicitly authorized separate gate)

1. Save both current release firmware images/recovery and their hashes; identify actual COM ports (do not assume example COM14/COM17).
2. Build both repositories' matching branch commits; production OrcDial uses `pio run -e dial`, Tab5 uses OrcSDR's pinned native ESP-IDF toolchain.
3. Verify already-paired v4 connection, complete two-way radio-state/command ack and no regression while Wi-Fi/router available/unavailable.
4. Only after capability handshake implemented, turn on decode metadata producer and verify exactly a real on-air local FT8 decode source appears with matching callsign/grid/capture frequency/flags and text preview. Record both logs and test files in run folders.
5. Exercise packet truncation/sequence replay/peer swap, AP roaming, live DSP/audio and PSRAM headroom. Capture 240×240 display images and check text legibility at physical size.
6. Do not approve merge/release until both independent reviewers and user sign off.

## Evidence ledger (as of development commit)

- GitHub writes: verified for both branches. Draft PRs open.
- Isolated sandbox reimplementation of **ui_motion_test** and **maidenhead_grid_test**: passed optimized + ASan/UBSan on g++14 (see local sandbox logs). These tests were manually mirrored from GitHub source; **not** a native full-repository compile.
- GitHub Actions CI on draft PRs: triggered; see check status on PR pages. Do not infer PASS while in progress.
- Complete PlatformIO/native Tab5 firmware builds locally: NOT RUN (sandbox clone/network unavailable).
- Physical two-device RF/display/ESP-NOW testing: NOT RUN.


Current exact source commits, firmware hashes, host/build results and unclosed
hardware gates: [integration validation](INTEGRATION_VALIDATION.md).
