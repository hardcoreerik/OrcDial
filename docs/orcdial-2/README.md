# OrcDial 2.0 — companion controller planning

**Status: proposal / planning only — NOT implementation approval.**
**Date:** 2026-10-29
**Primary repository:** hardcoreerik/OrcDial, source baseline `8003aa3d007fe75ca3379eebb7b90f97ec24371d` (main, 2026-10-09).
**Receiver repository:** hardcoreerik/OrcSDR, source baseline `d2c1b56baeab8a43c2658ca783bbf0b26243ae97` (main, 2026-10-29).
**Planning branch:** `chatgpt/orcdial-2-design-20261029`. Do not merge or modify firmware/release tags without explicit authorization.

## Product intent

Make the M5Stack M5Dial a compelling, **optional** OrcSDR control surface that can both operate the receiver and display genuinely useful decoded information. Improve the 240x240 circular UX, contextual Home, dashboard navigation, FT8 decode/location/map views, Dead Air controls, and future third-party RF/ham-data enrichment. Preserve independent usability of OrcSDR with no Dial connected.

The Tab5 owns radio state, decoding, user permissions, history, networking and any third-party queries. The Dial presents authenticated, bounded receiver-projected facts and sends semantic actions. Never fabricate RF data, decoding success, location, telemetry or acknowledgement.

## Research and design deliverables

| File | Purpose |
|---|---|
| [mockups/README.md](mockups/README.md) | Six editable 240×240 Home / FT8 / Dead Air / map / launcher / offline design concepts |
| [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) | Active branch implementation, test commands and remaining live-link gates |
| [BASELINE_AND_GAPS.md](BASELINE_AND_GAPS.md) | Repo-pinned source audit, ownership boundary, confirmed gaps and verification limits |
| [UX_AND_CONTROL_SPEC.md](UX_AND_CONTROL_SPEC.md) | Three Home concepts, default hybrid interaction, gestures and 240x240 content layouts |
| [FT8_COMPANION_SPEC.md](FT8_COMPANION_SPEC.md) | Latest decode, history, grid/direction/map, provenance and semantic controls |
| [DEAD_AIR_COMPANION_SPEC.md](DEAD_AIR_COMPANION_SPEC.md) | Six Dead Air views, controls, logging/evidence safeguards |
| [CAPABILITY_AND_TRANSPORT_RFC.md](CAPABILITY_AND_TRANSPORT_RFC.md) | Feature discovery and additive authenticated data transport, compatibility and failure handling |
| [API_ENRICHMENT_RESEARCH.md](API_ENRICHMENT_RESEARCH.md) | PSK Reporter, MQTT, callsign information, NOAA space-weather options, privacy |
| [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md) | Dependencies, phased work, owners, acceptance matrix and release gates |
| [LOCAL_RSA_REA_SESSION_PROMPT.md](LOCAL_RSA_REA_SESSION_PROMPT.md) | Read-only pinned RSA-Sandbox/REA-Results workflow to reproduce the structural analysis |
| [HANDOFF.md](HANDOFF.md) | Exact status, run/test instructions, unresolved decisions and non-actions |
| [EVIDENCE_MANIFEST.json](EVIDENCE_MANIFEST.json) | Machine-readable source/evidence pinning; not an RSA metrics artifact |

## Recommended design positions (not approved)

1. Default to **hybrid Smart Home**: Radio Home when Tab5 Home is active; a context summary when another dashboard is active; one consistent gesture reveals a separate launcher with favorites/recents.
2. Start FT8 with **local, offline decodes**, then a direction-and-distance page and a simplified map; meaningful content rather than only `3 / 12` row counts. Do not use a callsign registration address as a transmitting location.
3. Give Dead Air a genuine semantic interface, not remote touch-coordinate injection; distinguish measurement, logging, sweep, audio clip and optional microphone states.
4. Fix divergent dashboard catalogs (OrcDial has IDs 0–17; OrcSDR currently extends through SSTV=18, ACARS=19, Dead Air=20) without renumbering any existing IDs.
5. Make APIs **optional, opt-in, read-only, Tab5-owned**: PSK Reporter first, NOAA SWPC for radio conditions, callsign enrichment only on request.

## Architecture decision gates

- **D1:** Approve Home model, knob/touch gestures, and default/optional page set after reviewing 240x240 mockups.
- **D2:** Choose authenticated extension-envelope approach after inspecting existing secure-worker payload ownership and running wire-compatibility tests.
- **D3:** Define exact FT8/Dead Air receiver-side semantic read/action APIs and authoritative snapshot freshness.
- **D4:** Decide whether to ship network enrichment at all, then which providers and consent/settings policies.
- **D5:** Authorize firmware implementation, testing on real Tab5/M5Dial, and any branch merge independently.

## Evidence discipline

This is a source/document review via the GitHub connector and public service documentation. No GitHub Actions, RSA `rsa.py` analysis, C++ host tests, firmware build, hardware flash, Wi-Fi/ESP-NOW capture or live API call was performed as part of this planning branch. Current runtime behavior may differ from source-level expectations. Reports do not claim otherwise. Consult the dated source snapshot and [LOCAL_RSA_REA_SESSION_PROMPT.md](LOCAL_RSA_REA_SESSION_PROMPT.md).

## Scope boundary

**Allowed now:** documentation, architecture diagrams, verifiable source comparison, conceptual 240x240 layouts, test matrices, review of public API terms.

**Not authorized by planning alone:** changing `src/`, changing OrcSDR, altering production pairing/C6 firmware, transmitting any RF signal, querying real users' callsigns, shipping firmware, flashing hardware, merging PRs or changing `main`.
