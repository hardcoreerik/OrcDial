# OrcDial changelog

## v0.1.0-beta.1 — 2026-10-05

First standalone OrcDial source release for the M5Stack M5Dial. OrcDial is an
optional OrcSDR accessory; it is not required to use OrcSDR.

### Firmware and controls

- Imported the working M5Dial firmware, controller, version-3 packet protocol,
  dashboard artwork, and host tests from the OrcSDR integration worktree. Exact
  import provenance and repository boundaries are recorded in `docs/IMPORT.md`.
- ESP-NOW follows the receiver's acknowledged dashboard and radio state. Encoder,
  button, and touch controls expose the actions listed in the control matrix.
- Saved peer addresses support reconnection after restarts. The receiver starts
  the accessory bridge after its splash and router association settle. Router
  Wi-Fi and ESP-NOW must share the C6 radio's current channel.
- Wi-Fi Direct is not an accessory transport in this release. Tab5 receiver,
  pairing/settings, and C6 relay implementation remain in OrcSDR.

### Display

- Five-second Orc badge boot splash, OrcSDR Home, illustrated dashboard selector,
  and dashboard-aware tuning/content screens.
- Reel, Dial, Odometer, Tape, and Split tuning graphics; FM uses a large frequency
  display and an active Tune/Step/Volume strip.
- Airband selector uses the control tower picture; ADS-B uses the aircraft picture.
- Text fits the circular display and individual odometer boxes. Dashboard titles
  and footer hints are positioned inward; FM step/volume labels retain readable
  space. Home's instruction is shortened to `PRESS: DASHBOARDS`.
- Frequencies use three decimal places when that preserves their exact value;
  finer values retain six. Step labels use kHz for whole-kHz steps.
- Weather's alert graphic no longer overlaps its frequency.

### Documentation and capture tools

- Added 98 native-resolution preview frames, six contact sheets, raw framebuffer
  PNGs, and a manifest with capture commands, source/firmware hashes, and image
  hashes. A separate manifest update records the final two Home captures.
- Added an optional `doc_capture` environment and USB framebuffer export tool.
  This environment disables ESP-NOW/receiver commands. Capture commands are
  excluded from the normal `dial` build; DEMO/OFFLINE labels remain visible.
- Added the OrcSDR Tab5 M5Burner web-flasher link and installation steps, including
  settings-reset behavior and the Windows settings-preserving alternative.
- Retained AGPLv3 licensing, artwork provenance, protocol documentation, the
  receiver control matrix, and source-build instructions.

### Validation and limits

- Normal and documentation firmware builds passed. The normal application was
  flashed on COM14 and reported `LINKED`, `transport=ESPNOW`, channel 11, and no
  pending command after restarting.
- All 98 captures passed dimensions, masks, image/pixel hashes, and recorded
  source/firmware checks. White/gray foreground pixels were inside the circular
  display in the 82 non-selector frames; contact sheets were visually reviewed.
- The gallery uses preview values. It is not evidence of live RF reception or
  implementation of every visible dashboard action.
- Pairing saves MAC addresses without encryption or cryptographic authentication.
  It is a prototype connection mechanism, not a production trust boundary.
- Requires a compatible OrcSDR accessory receiver and custom C6 relay. The public
  OrcSDR web-flasher listing alone does not establish OrcDial compatibility.
- Prolonged stability, all receiver/channel combinations, and production trust
  remain outside this beta's acceptance evidence. This tag does not publish an
  OrcDial M5Burner listing or a prebuilt first-install firmware package.
