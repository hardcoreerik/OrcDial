# OrcDial

OrcDial is an optional M5Stack M5Dial accessory for [OrcSDR](https://github.com/hardcoreerik/OrcSDR). It uses the encoder, button, touch display, and ESP-NOW to follow the active OrcSDR dashboard and control supported radio functions. OrcSDR remains usable without a Dial.

This repository owns the **M5Dial firmware**, dashboard graphics, controller/protocol code, tests, and future Dial releases. Tab5 pairing/settings, the receiver bridge, and the C6 radio relay remain in OrcSDR. See [the import record](docs/IMPORT.md) for the exact source snapshot and repository boundary.

The first source release is **v0.1.0-beta.1**. See the [changelog](CHANGELOG.md) for its features, validation, and known limits.

## Install OrcSDR on the Tab5

OrcSDR is available through the [M5Burner web flasher](https://burner.m5stack.com/share/firmware/JXFU4H):

1. Open the link in **Chrome or Edge** on your computer.
2. Connect the **Tab5** by USB and close any serial monitor using its port.
3. Click **Burn to device**, select the Tab5 serial port when prompted, and follow the flasher instructions.
4. Restart the Tab5 after flashing completes.

**M5Burner installation resets saved settings**, including Wi-Fi profiles, location, and screen rotation. To preserve them, use the Windows settings-preserving installer from [OrcSDR Releases](https://github.com/hardcoreerik/OrcSDR/releases/latest).

This listing installs OrcSDR on the Tab5. For the OrcSDR build requirements for this accessory, see [Pairing](#pairing).

## Build and flash OrcDial on the M5Dial

Install PlatformIO Core or the PlatformIO IDE extension. From this repository's root:

```sh
pio run -e dial
pio run -e dial -t upload --upload-port COM14
pio device monitor -p COM14 -b 115200
```

Replace COM14 with your Dial's port. Platform, board, and library versions are pinned in [platformio.ini](platformio.ini). A build produces `.pio/build/dial/firmware.bin`; that application image alone is not a complete first-install or M5Burner package. This source release does not publish an OrcDial M5Burner listing or a prebuilt first-install package.

## Display and controls

- Five-second boot splash with the Orc badge and "OrcDial" in the OrcSDR wordmark gradient, then Home and a side carousel with illustrated dashboard pictures.
- **Home is a full-range VFO** when the Tab5 shows Home: the knob tunes the whole range by the step and raster of the band the Tab5 reports, and the round display shows the band name, mode, frequency, step, span or filter, and volume over a decorative waveform. Press cycles frequency, step, span, filter and volume; turning on SPAN zooms the Tab5 spectrum and turning on FILTER widens or narrows the receive filter, with the two edge lines shown on the Tab5 while you adjust. A long press on the frequency opens a tuning keypad (on every tunable dashboard too, limited to that band), tapping the mode area cycles NFM, AM, WFM, USB and LSB, and BACK opens the dashboards carousel. Offline, Home is the launcher.
- Every dashboard screen ends in a BACK button that returns to the carousel; holding the knob returns to Home.
- **Dial Settings** (the last carousel stop, or hold the knob for four seconds on Home) is its own vertical menu: Pairing, Link (channel, lock, last heard, counters), Display (brightness, sleep), Knob (acceleration, reverse, click), About, Reset and Back. Settings screens return to Home after 60 seconds without input.
- Dashboard-aware tuning views, including Reel, Dial, Odometer, Tape, and Split frequency graphics.
- Rotate to browse dashboards; press to open one. On a tuner dashboard, rotate to change the focused control and press to cycle frequency, step, gain, and volume where supported.
- The receiver owns the actual radio state. The Dial shows acknowledged state and labels disconnected previews OFFLINE.

Supported and pending receiver actions are recorded in [the control matrix](docs/ORCDIAL_CONTROL_MATRIX.md). A visible dashboard does not imply every action is implemented.

See the [screen gallery](docs/screenshots/README.md) for native-resolution PNGs of the splash, Home, dashboard selector, dashboards, and additional control views. These are labeled documentation previews captured from the Dial, suitable for the README, wiki, and OrcSDR cross-links.

## Pairing

The unreleased branch requires version-4 applications on both devices. Open
**Settings → Accessories & Companion** on the Tab5 and **Dial Settings → Pairing** on the
Dial (the last stop of the dashboard carousel, or hold the knob for four seconds on Home). Pair on both, compare the six-digit code and confirm on BOTH devices.
Pair establishes persistent trust. Connect, Disconnect and Forget & Re-pair are
separate actions; boot connection defaults on after successful pairing.

See [secure pairing](docs/SECURE_PAIRING.md) for commands, protocol and gates.
The published `v0.1.0-beta.1` tag still uses the earlier MAC-only prototype; it is
unchanged. Do not mix its firmware with the unreleased version-4 application.

## USB diagnostics and tests

Dial commands include `ORCDIAL_STATUS`, `ORCDIAL_PAIR START`, `ORCDIAL_RESTART`, `ORCDIAL_DASHBOARD <id>`, `ORCDIAL_FOCUS NEXT`, and `ORCDIAL_ROTATE <delta>`. Status includes link, channel, dashboard, frequency, acknowledgment, pending-command state, and transport. A queued response is not proof that OrcSDR applied an action.

```sh
python tests/serial_smoke.py --port COM14
python tests/host_probe.py --port COM17
```

These version-4 scripts require attached hardware. They check status and command parsing without opening pairing, changing trust, tuning or flashing. Stop any monitor using the same port first. A status response alone does not prove RF delivery or pairing.

Run the repeatable [regression and release checks](docs/RELEASE_CHECKS.md) with `python tools/release_check.py --mbedtls-source <mbedtls-3.6-source>`. It builds and tests Debug/Release host programs, capture safeguards, Devices images, and both Dial firmware configurations, saving logs and JSON/Markdown results. Add `--hardware` to record the acceptance checklist after flashing; skipped checks remain incomplete.

The small native C++ assertion programs are `tests/protocol_test.cpp` and `tests/controller_test.cpp`; they need a C++17 host compiler. [PROTOCOL.md](PROTOCOL.md) documents the version-4 encrypted control payload.

## Validation and limits

The imported snapshot was built and flashed during OrcSDR integration work. Serial checks covered initial pairing, automatic reconnection after restarts, dashboard synchronization, and acknowledged FM tuning with router Wi-Fi connected. Active audio and IQ counters reported zero drops in those bounded checks. This is not a claim of prolonged stability, offline-router recovery, channel-change acceptance, or audible sound-quality verification. One earlier receiver build experienced a watchdog reset whose exact cause was not established.

Import/build validation in this repository is separate from flashing or testing this new checkout on hardware. Publishing source here does not create a firmware release.

## License and artwork

The imported project preserves OrcSDR's [GNU Affero General Public License v3](LICENSE). Dependency licenses remain their own. Dashboard source artwork and generation notes are retained in [art/README.md](art/README.md).
