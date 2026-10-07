# OrcDial changelog

## Unreleased — Devices and secure pairing

- Home is a full-range VFO: the knob tunes by the step and raster of whatever band the Tab5 reports, the
  band name, mode, step and volume show on the round display, a long press on the frequency opens a
  tuning keypad, and the mode chip cycles NFM, AM, WFM, USB and LSB. The band id rides in reserved
  packet byte 7 (no version change). Press now cycles frequency, step, span, filter and volume: turning on
  SPAN zooms the Tab5 spectrum and turning on FILTER widens or narrows the receive filter, with the
  two edge lines shown on the Tab5 while you adjust.
- Add Dial Settings, its own vertical menu (the last carousel stop, or a four-second hold on Home):
  Pairing (the former Devices screen), Link (channel, lock, last heard, counters), Display
  (brightness, sleep), Knob (acceleration, reverse, click), About and Reset. Tapping the top of a
  screen no longer opens pairing.
- Add a BACK button to every dashboard screen and to Home (it opens the dashboards carousel); drop the tiny bottom
  hints. While linked, a long press on the frequency opens the tuning keypad on every tunable dashboard (FM 76 to 108 MHz,
  AM 0.5 to 1.7 MHz, others 0.1 to 1766 MHz; the Tab5 validates again). The Home waveform sits above the
  frequency. The boot and offline Home titles say OrcDial in the OrcSDR wordmark gradient.
- Dial Settings screens return to Home after 60 seconds without input; the menu gains a Back entry.
- The keypad stays open, with BUSY - TRY AGAIN, when the Tab5 link refuses a tune because another command is pending,
  instead of closing and losing the entry.

- Fix intermittent boot-time connection failures: a channel lock now holds only while the peer
  acknowledges unicast frames (a valid offer heard on a neighbouring channel no longer pins the Dial to
  the wrong channel), the Dial remembers and tries its last working channel first, and a timed-out
  connect is retried up to six times with increasing delay on both devices. Disconnect, Forget, Cancel
  and pairing clear the retry intent. The policy lives in `src/control/link_policy.hpp` with host tests.
- Show link state on the outermost ring of every screen: green when linked, red when offline
  (previously green or cyan regardless of state on several screens).
- Add radio diagnostics: `ORCDIAL_RF` (send, acknowledgement and per-channel counters),
  `ORCDIAL_RF RESET`, `ORCDIAL_RF TRACE 0|1|2`, and security state, failure and channel on the periodic
  status line.

- Fix CodeRabbit findings: recover from dropped fragments without immediately
  returning to a retired exchange, retain encrypted Forget retries across
  re-pairing and failures, reset focus on receiver dashboard changes, and avoid
  duplicate DEMO labels. Protect existing screenshot manifests from partial
  captures and correct gallery text encoding.
- Keep assertions enabled in Release host tests; require Mbed TLS 3.6 LTS
  sources and validate version rejection. Add packet-reordering, revocation,
  key-generation failure and transport-level notification regressions.

- Review repairs: release failed initialization resources, preserve ordered local
  actions, block replacement pairing after failed revocation, and retry encrypted
  Forget notices. Tab5 serial mutations require authentication and storage errors
  are visible with a retry action. Independent review and hardware acceptance
  remain pending.

- Add a local Devices carousel entry, usable offline and protected from
  incoming dashboard navigation. Add confirmation before Forget & Re-pair.
- Separate Pair, Connect, Disconnect and Forget; expose persistent boot
  connection preferences and matching tablet Accessories & Companion controls.
- Replace MAC-only authorization with version-4 P-256 numeric comparison,
  persistent per-pair trust, fresh session challenges and AES-GCM controls.
- Keep the 64-byte C6 relay unchanged; move crypto and fragment work into a
  worker. Reject unauthenticated legacy controls, replay and stale sessions.
- Add published cryptographic vectors, targeted two-device host tests and
  native-resolution display-only Devices captures.
- Not released or hardware accepted. See `docs/SECURE_PAIRING.md` for gates.

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
