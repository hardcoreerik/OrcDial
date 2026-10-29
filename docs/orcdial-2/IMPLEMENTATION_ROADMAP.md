# Implementation roadmap, milestones and acceptance gates

**Planning date:** 2026-10-29. This is a dependency-ranked implementation plan, **not authorization to ship code**. Do not merge `main`, modify source in either repo, flash hardware or publish firmware until individually approved. Tab5 and OrcDial are separate projects with deliberate cross-repository interface changes.

## Workstream ownership

| Workstream | Repo | Owner/contract |
|---|---|---|
| Receiver dashboard registry, semantic actions, snapshot projections, FT8 data and Dead Air event ownership | `hardcoreerik/OrcSDR` | Tab5 authoritative; preserve standalone operation |
| Dial Home, launcher, graphics, control mapping, receive-only projection rendering | `hardcoreerik/OrcDial` | Bounded 240x240 M5GFX UI, no receiver data fabrication |
| App protocol schema + golden vectors | Both (shared spec, tested mirrored implementation) | No blind vendoring or wire ID collisions |
| Third-party enrichment/network cache | OrcSDR only | Explicit opt-in; no keys on Dial |
| RSA structural inspection | `F:\AI\RSA-Sandbox` only | Pinned imported sources, `rsa.py` for metrics |
| Published human findings | private `hardcoreerik/REA-Results/inbox/` | No raw sources, ELF, logs, proprietary data or generated report edits |

## Phase 0: approve design (CURRENT)

- [x] Source audit of dashboard IDs and data ownership.
- [x] FT8 / Dead Air requirements drafted from pinned source.
- [x] Hybrid Home and input direction proposed.
- [x] External provider options reviewed from current documentation.
- [ ] Full 240x240 visual concept pack + user selects direction A/B/C and gesture policy.
- [ ] Receiver data/schema design reviewed by a second implementation reviewer.
- [ ] Run local RSA source imports and source-level analysis using the companion handoff.
- [ ] Produce tested protocol feasibility proof *in isolated lab only*, then approve chosen transport option.

**Exit:** user approves D1..D3 design decisions; there is a documented protocol and UI interaction contract with screen gallery.

## Phase 1: catalog + compatibility seam

1. Stabilize dashboard IDs 0..20 across both repos; do not alter existing 0..17, Utilities=11 stays invalid, local Settings token 255 never crosses wire.
2. Receiver advertises supported dashboards/capabilities after authenticated link; Dial retains legacy fallback.
3. Introduce shared schema vectors and binary codec tests for known/unknown/old-version peers before any live UI wiring.
4. Maintain a *compatibility matrix* with old v4 peers, no-C6-update configuration, reconnections and malformed packets.

**Exit:** no renumbering or regression; 0..20 dispatch is correct and unknown actions are rejected.

## Phase 2: hybrid Home and launcher

1. Build approved wireframes in native 240x240 M5GFX graphics using existing capture tooling.
2. Implement Radio Home with direct VFO and visibly focused step/span/filter/volume.
3. Add Context Home showing authoritative active-dashboard summary.
4. Add local launcher favorites/recents, only persisted after explicit user decision; no unsupported remote open.
5. Preserve current knob hold, settings, keypad, pairing, return-home behavior until an accepted gesture migration.

**Exit:** physical usability review on M5Dial, including offline, stale, pairing, pending and fast knob-spin states; no unsolicited tuning.

## Phase 3: FT8 rich companion

1. Project a bounded, sanitized, real receiver-side FT8 decode record with stable IDs/revisions and original provenance.
2. Implement latest decode, pinned history navigation, SNR-unavailable and missing-location states.
3. Add grid-center map/distance/bearing with precise *approximate* labeling; offline and zero additional internet requirements.
4. Preserve existing FT8 Hunter semantic controls and avoid accidental frequency tuning.
5. Test message parser edge cases, repeated frames, flood, FT4 mode switching, empty/old buffers.

**Exit:** on-device known local RF/record replay confirms exactly the callsign/message/grid SNR displayed; map matches source grids.

## Phase 4: Dead Air companion

1. Expose receiver-side shared semantic dispatcher for controls currently only in touch handler.
2. Publish bounded state for six tabs, including validity, sensor age, sweep dwell/gaps and journal/clip/mic states.
3. Implement quick event mark with idempotency and *separate acknowledgement from persistence status*.
4. Add safe sweep, selected-item and clip controls; require clear explicit consent for microphone capture.
5. Test app screen ownership, retune/settle gating, SD failures, duplicate sends and disconnected device actions.

**Exit:** physical test shows verified receiver event journal entry exactly once, truthful status under failures and zero interference with audio/IQ.

## Phase 5: wider dashboard control overhaul

Follow the verified control matrix rather than inventing functionality:
- FM/AM/Shortwave/Weather/Marine/CB: actual frequency, channel, mode and valid controls only.
- ADS-B, LoRa, Wi-Fi, P25, POCSAG: list/detail selection, never generic tuning by default.
- SSTV and ACARS: add visible identifiers, tested action/snapshot contracts and effective navigation.
- RF Lab/Settings: capability-gated parameters with acknowledgment and rejection surfaces.
- Introduce a provider-neutral UI card base and snapshot validity patterns to reduce duplicated hand-coded layouts only after benchmarks show it fits flash/RAM.

**Exit:** every dashboard's selected action maps to the exact Tab5 handler or explicitly shows unsupported.

## Phase 6: optional enrichment experiments

1. Opt-in NOAA SWPC mini-conditions panel; validate current JSON and data-age checks.
2. Opt-in PSK Reporter retrieval for selected callsign with ≥5-minute refresh and cache; label external data.
3. Only then test filtered MQTT, HamQTH DXCC and on-demand license status lookup.
4. Privacy/security review for source attribution, data minimization, credential handling and absent network.

**Exit:** offline flows unaffected; no full addresses on Dial; external API failure/429 cannot freeze tuning.

## Validation matrix (planned, not run)

| Case | Host tests | Hardware tests | Pass criterion |
|---|---|---|---|
| Legacy v4 receiver / updated Dial | decode/capability rejection vectors | connect both startup orders | Legacy functions preserved, new controls unavailable |
| New receiver / old Dial | unaffected old codec | pair/connect/current v4 | Does not crash or falsely claim new support |
| FT8 real local decode | golden payload + malformed/fuzz | known decode RF/fixture with live Tab5, log both | Correct callsign, grid, flags, message; no fake SNR |
| FT8 grid + map | Maidenhead table and wrap tests | screenshots / dial spin | Marker from validated grid only, right precision |
| FT8 mode/Hunter | action dispatch/pending tests | real FT8/FT4 reception | No generic unintended tuning, status truthful |
| Dead Air manual mark | duplicate seq/reconnect + storage failure | verify SD JSONL and screen | One event, correct persistence status |
| Dead Air sweep | blocked conflicting action tests | moving RF, gaps, Wi-Fi/audio | One tuner and blind intervals never omitted |
| Dead Air microphone | no implicit start tests | opt-in/offline/interruption/replay | Mic only starts when deliberately selected |
| Visual UX | 240x240 layout/circular clipping/capture hash checks | 1:1 readability and touch | No text clipping or inaccessible action |
| Network failure | parsers with 4xx/429/timeout fixtures | disable internet, keep local router | Decoding/control unaffected |
| Security & radio coexistence | auth/replay/fragment fuzz | paired 2-device soak | No unauth controls, bounded retries, no DSP loss |

### Commands (only when implementation begins)

From the standalone OrcDial repo, preserve logs/results per [existing release checks](../RELEASE_CHECKS.md):

```powershell
# Source + host + firmware validation; no flashing.
python tools/release_check.py --mbedtls-source C:/Espressif/frameworks/esp-idf-v5.5.4/components/mbedtls/mbedtls
pio run -e dial
pio run -e doc_capture
```

OrcSDR's FT8-host harness, from its own root:

```powershell
.\tools\test-ft8.ps1
# On Linux/WSL:
# bash tools/test-ft8.sh
```

Only after explicitly authorized device flashing, use original repo serial smoke scripts: `python tests/serial_smoke.py --port COM14` (M5Dial) and `python tests/host_probe.py --port COM17` (Tab5), substituting actual ports; no assumptions that COM14/17 still match. For Orion/ESP32-P4 firmware use OrcSDR's pinned ESP-IDF toolchain/build helper, not the M5Dial PlatformIO environment.

Record revision/hash, tool versions, log paths, RF frequency/antenna, router channel, pairing state and hardware outcome. **Log current commands in their working folder**, and preserve OrcDial's `.pio/release-checks/<UTC timestamp>/` outputs. Do not call a host PASS hardware acceptance.

## Stop conditions

Any unauthenticated operation, new C6 firmware requirement not approved, FT8 invented/incorrect decode, false Dead Air measurement, unexpected microphone activation, persistent link disruption, watchdog reset, loss of audio/IQ or changed v4 packet contract stops rollout until the cause is independently diagnosed.
