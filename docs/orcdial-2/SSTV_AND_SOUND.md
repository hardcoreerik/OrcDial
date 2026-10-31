# SSTV Receive/Tune and sound controls

Implemented October 30, 2026. This is an RX companion, not an SSTV transmitter
or an image preview. The Tab5 owns decoding and the SD archive.

## Using the Dial

- Open SSTV on the tablet. Receive shows frequency, detected mode, session
  state, line progress and actual SD archive status. Tap the header or press
  the knob on Receive to open Tune.
- In Tune, turn the knob to change frequency. Press it to cycle frequency,
  step and gain focus. The mode and automatic-gain controls use tablet actions.
  Frequency changes are blocked while receiving; abort first.
- Receive SAVE and ABORT require two presses within four seconds for the
  same session. SAVE needs an image and available SD; ABORT needs reception.
- Tap the speaker icon near the upper left to mute/unmute immediately.
  Settings → SOUND controls alerts, master mute, volume and individual receive,
  complete, saved, error and lost-link alerts. Alerts default off. Master mute
  also silences clicks. No CW sidetone or RF transmit path was added.
- Sound settings persist. Short alerts have one pending slot and a 500 ms
  minimum interval; simultaneous events can coalesce. Receiver restarts do
  not reuse the Dial's alert identities.

## Serial controls

`ORCDIAL_SOUND STATUS|ON|OFF|MUTE|UNMUTE|STOP|VOLUME 0..255|TEST|OPEN`

`ORCDIAL_SOUND EVENT RECEIVE|COMPLETE|SAVED|ERROR|LINK_LOST ON|OFF`

`ORCDIAL_SSTV STATUS|PAGE|SAVE|ABORT|MODE|GAIN_AUTO`

Repeat SAVE or ABORT to confirm. Existing `ORCDIAL_ROTATE` and `ORCDIAL_PRESS`
use the same semantic actions as the encoder. TEST is simulated sound only.
STATUS exposes alert configuration, pending/active/driver state and played count.
`ORCDIAL_STATUS` also emits `ORCDIAL_IDENTITY self=<32 hex> peer=<32 hex>` so
paired bench tools can verify the specified receiver before sending controls.
These are public companion identities; no pairing key or session proof is emitted.
This diagnostic is a follow-up to the 0.2.0-beta.1 release.

The authenticated RADIO_STATE SSTV projection uses dashboard 18 and schema bit
30. It carries session/state/mode, rows, complete images, SD saves/failures,
pending saves, signal/receiving/SD/gain flags and actual gain. Missing schema
shows unavailable controls; pairing and packet security remain unchanged.
The shared contract is `src/sstv_control.hpp`, mirrored in OrcSDR's `orcdial/src`.

## Validation

- Production Dial build passed; application-only COM14 flash at 0x10000 passed
  hash verification. Installed source `298fa94bcd302c2a0fca7893fd43fddbb0b81379`,
  1,152,960 bytes, SHA256
  `3274017778e9a3c6a14dd81404a769c3d7b3f8fed1b52c574b77a1316710ef8c`.
  NVS and pairing were preserved. Tablet application source is `7b348ead`.
- `ctest --test-dir .pio/ft8-host --output-on-failure`: 11/11 passed, including
  sound sequencing and preference persistence. Sound sanitizer checks passed.
- `python -m unittest discover -s tests -p test_ft8_live_layout.py -v`: passed.
  Production SSTV/FT8 draw functions were exercised with a recording display;
  ordinary updates add no screen-level clear. No new framebuffer allocation.
- Paired internal Robot36 injection: actual decoder line progress/completion
  reached the Dial; confirmed save advanced the tablet archive counter;
  retuning was blocked while receiving. Confirmed abort recorded ABORTED partial
  image; the first press preserved reception. This is synthetic audio, not RF.
- Live sound driver checks passed for test, mute, stop and disabled events.
  Physical sound quality, touch/encoder feel, native pixel appearance and
  over-the-air SSTV reception remain unverified.

Build/flash evidence is retained locally under `.pio/hardware-slice1/sstv-sound/`.
Paired test evidence and repeatable script usage are documented in the OrcSDR
companion checkout's `docs/SSTV_DIAL_IMPLEMENTATION.md`.
