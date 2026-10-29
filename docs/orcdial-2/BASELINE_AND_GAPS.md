# Source baseline, control architecture and gaps

Review date: **2026-10-29**. OrcDial `8003aa3d007fe75ca3379eebb7b90f97ec24371d`; OrcSDR `d2c1b56baeab8a43c2658ca783bbf0b26243ae97`. Source inspection by connected GitHub reads; no local binary/toolchain analysis. Permalinks are pinned for review rather than moving `main` references.

## Repository ownership

- **OrcDial** owns M5Dial firmware, M5GFX 240x240 UI, rotary/touch input, controller mapping, secure session and tests. `platformio.ini` pins `espressif32@6.12.0`, `m5stack/M5Dial@1.0.3`, `M5Unified@0.2.24`, `M5GFX@0.2.31` and an M5Stack Stamp S3 board target.
- **OrcSDR** owns the Tab5, the active receiver, dashboard registry, FT8 decoder/records, Dead Air state/evidence and accessory receiver bridge. OrcDial is optional, and receiver authority must not migrate to the Dial.
- The OrcSDR repository also contains an embedded historical `orcdial/` tree. It is not the automatically synchronized source of truth for standalone OrcDial. Reconcile intentionally; never copy files blindly in either direction.

## Source-pinned inventory

| Fact | Evidence | Status |
|---|---|---|
| OrcDial has `Dashboard` IDs Home 0 through FT8 17; skips Utilities 11 | [OrcDial dashboard.hpp](https://github.com/hardcoreerik/OrcDial/blob/8003aa3d007fe75ca3379eebb7b90f97ec24371d/src/dashboard.hpp) | Verified in source |
| OrcSDR registry continues SSTV 18, ACARS 19, DEAD AIR 20 | [OrcSDR dashboard_registry.hpp](https://github.com/hardcoreerik/OrcSDR/blob/d2c1b56baeab8a43c2658ca783bbf0b26243ae97/apps/orcsdr-tab5/ui/dashboard_registry.hpp) | Verified in source |
| Current OrcDial draws FT8 without callsign or decode message strings | [OrcDial ui.cpp](https://github.com/hardcoreerik/OrcDial/blob/8003aa3d007fe75ca3379eebb7b90f97ec24371d/src/ui.cpp) | Verified in source |
| FT8 decodes have `callsign[16]`, `grid[9]`, `message[48]`, timestamp, mode, SNR and origin flags | [OrcSDR ft8_model.hpp](https://github.com/hardcoreerik/OrcSDR/blob/d2c1b56baeab8a43c2658ca783bbf0b26243ae97/apps/orcsdr-tab5/ui/ft8_model.hpp) | Verified in source |
| Maidenhead validation, grid-center and distance/bearing helpers exist in OrcSDR | [OrcSDR ft8_model.hpp](https://github.com/hardcoreerik/OrcSDR/blob/d2c1b56baeab8a43c2658ca783bbf0b26243ae97/apps/orcsdr-tab5/ui/ft8_model.hpp) | Verified in source |
| FT8's standalone design explicitly omitted callsign strings from compact `RADIO_STATE` | [FT8 OrcDial design](https://github.com/hardcoreerik/OrcSDR/blob/d2c1b56baeab8a43c2658ca783bbf0b26243ae97/docs/ft8/FT8_ORCDIAL_DESIGN.md) | Verified in documentation |
| OrcDial `RadioState` currently has generic index/count/capabilities, but no text or valid geo fields | [OrcDial state.hpp](https://github.com/hardcoreerik/OrcDial/blob/8003aa3d007fe75ca3379eebb7b90f97ec24371d/src/state.hpp) | Verified in source |
| Existing control payload is a fixed 64-byte version-4 `ORDL` codec | [OrcDial protocol.hpp](https://github.com/hardcoreerik/OrcDial/blob/8003aa3d007fe75ca3379eebb7b90f97ec24371d/src/control/protocol.hpp), [PROTOCOL.md](https://github.com/hardcoreerik/OrcDial/blob/8003aa3d007fe75ca3379eebb7b90f97ec24371d/PROTOCOL.md) | Verified in source |
| Secure session uses fixed 64-byte outer fragments and logical messages up to 192 bytes (per docs) | [SECURE_PAIRING.md](https://github.com/hardcoreerik/OrcDial/blob/8003aa3d007fe75ca3379eebb7b90f97ec24371d/docs/SECURE_PAIRING.md) | Documented; actual extension path NOT validated |
| Dead Air has six pages and an action model for sweep, tune, sensitivity, mark event, clips | [dead_air_model.hpp](https://github.com/hardcoreerik/OrcSDR/blob/d2c1b56baeab8a43c2658ca783bbf0b26243ae97/apps/orcsdr-tab5/ui/dead_air_model.hpp), [dead_air_dashboard.hpp](https://github.com/hardcoreerik/OrcSDR/blob/d2c1b56baeab8a43c2658ca783bbf0b26243ae97/apps/orcsdr-tab5/ui/dead_air_dashboard.hpp) | Verified in source |
| Current touch handling changes Dead Air tabs, sensitivity and manual events internally, bypassing the action switch in several cases | [dead_air_dashboard.cpp](https://github.com/hardcoreerik/OrcSDR/blob/d2c1b56baeab8a43c2658ca783bbf0b26243ae97/apps/orcsdr-tab5/ui/dead_air_dashboard.cpp) | Verified in source |
| OrcDial has a documented whole-repo release check suite and explicit hardware acceptance gate | [RELEASE_CHECKS.md](https://github.com/hardcoreerik/OrcDial/blob/8003aa3d007fe75ca3379eebb7b90f97ec24371d/docs/RELEASE_CHECKS.md) | Verified in docs, not executed now |

## Concrete gaps

**G01 — Dashboard registry skew.** Existing wire IDs must remain fixed. Standalone Dial cannot select or label SSTV, ACARS or Dead Air until its catalog and receiver feature advertisement are reconciled. Never assume visible locally means remotely actionable.

**G02 — Missing FT8 content projection.** FT8 `RADIO_STATE` carries band/index/status but not the decoded callsign, message, grid, SNR provenance, or timestamp. A Dial-side callsign parser has no input and cannot solve this alone. The Tab5 should select, sanitize and send a small decode summary.

**G03 — Ambiguous FT8 semantics.** Callsign location, Maidenhead grid-center, licensee mailing address, live transmitter position and PSK Reporter receiver locations are distinct. Mixing them would create false precision.

**G04 — Dead Air's actions are not a reusable remote API.** Some meaningful changes happen directly in the touch handler rather than through an exported semantic dispatcher. The integration should refactor both touch and remote controls to a single owner on the Tab5, avoiding fake coordinate taps.

**G05 — Capability negotiation insufficient.** Existing flags are per-dashboard but do not advertise per-view labels, control availability, schema revision, data freshness or new text-record support. Prior beta receivers must fail safely and the Dial must show unavailable, never dispatch a guessed command.

**G06 — Home conflict.** The existing Home doubles as online full-range VFO and offline launcher. New contextual views need a clear consistent way to preserve tuning without accidental dashboard switches, including automatic screen changes from Tab5.

**G07 — Security and threading concerns.** Control/session code already has replay protection, sequencing, pending command semantics and bounded queues. New high-rate data must not block the C6 bridge, DSP, UI task or encrypted control path; cap rates, lengths and buffers.

**G08 — Tests vs real hardware.** Existing documentation reports historical FT8 host tests and pairing captures, but our planning review ran neither. Physical UX, packet timing, real Wi-Fi channel coexistence and UI readability remain unverified.

## Research recommendations and caution

1. Keep the wire IDs 0..20 stable; avoid using a local `devices_entry=255` as a receiver dashboard.
2. Only update a live Dial view from the Tab5's authoritative snapshot; use a labeled `STALE` or `OFFLINE` condition for old text.
3. Lock down the extra data envelope before rendering a map; drawing a useful map does not require a full FFT or a rich JSON stream.
4. Let Tab5 compute location from the **station-reported grid**; never equate grid center with an antenna coordinate.
5. The file `docs/dead-air/DEVELOPMENT_HANDOFF.md` in OrcSDR is an *earlier milestone* and contains outdated unimplemented warnings; check actual modern Dead Air source and acceptance records before relying on any status claim.
6. Re-check baseline after any OrcSDR commit; reconcile interface changes rather than cherry-picking stale `orcdial/` source.

## Unverified

- Exact Tab5 bridge implementation's byte-size limits for new authenticated projections (requires code-level trace and local hardware exercise).
- Availability of a safe receiver-side decoded-record selection API callable without UI ownership.
- Captured receiver/Dial latency, display FPS, power, PSRAM heap and RF/audio impact under streaming metadata.
- Hardware acceptance of secure v4 pairing across current releases.
