# OrcDial 2.0 planning handoff

**Date:** 2026-10-29
**Status:** Documentation/planning-only proposal, not working firmware.
**OrcDial design branch:** `chatgpt/orcdial-2-design-20261029` (base: `8003aa3d007fe75ca3379eebb7b90f97ec24371d`).
**OrcSDR reference:** `d2c1b56baeab8a43c2658ca783bbf0b26243ae97` on `main`.
**REA human findings branch:** `chatgpt/orcdial-2-research-20261029` in private `hardcoreerik/REA-Results`.

## What was done

- Read both repositories' relevant public committed sources through authenticated GitHub connector, including existing OrcDial README/protocol/controller/UI, FT8 decoder/model/docs, Dead Air model/app/actions and current Tab5 registry.
- Verified RSA-Sandbox/REA-Results project instructions before planning cross-repository research.
- Produced source-pinned baseline/gap analysis, UI interaction proposal, FT8 local decode/map spec, Dead Air six-page semantics, compatibility RFC, opt-in network API/provider comparison and phased implementation/acceptance roadmap.
- Prepared exact local `rsa.py` import/analyze/compare/publish workflow, clearly marked unrun.
- Preserved all release code and versioned security pairing; no source changes, binary analysis, flashing or merge.

## Top findings

1. OrcDial on this pinned main stops at FT8 dashboard ID 17. OrcSDR includes SSTV 18, ACARS 19 and Dead Air 20. Beware stale embedded `OrcSDR/orcdial/` source.
2. OrcSDR has FT8 `Decode` records with callsign/grid/message/SNR/time; current Dial 64-byte control state carries only index/count/status, making its `DECODES` view visually uninformative.
3. Dead Air's current app has real sweep, clip, mic and evidence code. Its UI has direct touch-side state mutations that need a shared semantic receiver API before remote Dial actions are safe.
4. Current secure v4 session has protected 64-byte control packets and documented up-to-192-byte logical reassembly; metadata transport is *not* automatically supported. Test this before a wire design is chosen.
5. PSK Reporter can enrich local FT8, but offline local grids/direction/map must be complete first; callbook mailing addresses cannot be used as RF transmitter locations.

## Recommendations awaiting decisions

- **D1:** Hybrid Smart Home (instrument on receiver Home, context card for FT8/Dead Air, dedicated launcher), while preserving existing long-press/settings behavior.
- **D2:** Feature-negotiated, authenticated receiver projection schema, exact codec chosen by standalone bench/harness and backward compatibility tests.
- **D3:** Local FT8 latest-decode/history/approximate-grid and Dead Air semantic dispatcher as the first feature workstreams.
- **D4:** Opt-in, receiver-owned API layer later, PSK Reporter and/or NOAA SWPC as first experiment.
- **D5:** Explicit owner approval before any firmware change, test-device flash, merge or release.

## How to run/test this handoff now

This branch has **documentation only**. Reviewing these files does not require compiling any code.

1. Checkout or view `chatgpt/orcdial-2-design-20261029` in OrcDial. Open [README.md](README.md) and each linked spec in order.
2. Compare pinned commits in [BASELINE_AND_GAPS.md](BASELINE_AND_GAPS.md) against the most recent OrcSDR registry, FT8 and Dead Air sources.
3. Review the conceptual UI sketches and choose D1 gesture mapping and Home behavior; inspect them at 240x240 physical scale (not only scaled desktop).
4. In the independent local RSA sandbox, read [LOCAL_RSA_REA_SESSION_PROMPT.md](LOCAL_RSA_REA_SESSION_PROMPT.md) and run its `rsa.py doctor/import/analyze/compare` commands only when your local environment is ready. Save run logs alongside the commands in the working run folder, as well as RSA-generated run artifacts. This was **not** executed here.
5. Only after firmware development is separately approved: from OrcDial root run `python tools/release_check.py --mbedtls-source <mbedtls-source>`; from OrcSDR root run its FT8 host tests. Physical testing is a distinct explicit step and must preserve serial logs, board ports, hashes and original paired trust.

## Verification ledger

| Task | Result |
|---|---|
| GitHub read access and source pinning | VERIFIED |
| Documentation branch commits | COMPLETED |
| REA research branch setup | COMPLETED |
| Local RSA `doctor/import/analyze/compare` | NOT RUN — no access to F: local sandbox and git clone DNS unavailable |
| Host C++ regression/tests | NOT RUN — no repo checkout/toolchain in this GitHub-source session |
| Firmware builds | NOT RUN |
| Radio/ESP-NOW/Dial physical interaction | NOT RUN |
| Third-party API runtime tests/spot collection | NOT RUN |
| Existing app/control compatibility | UNVERIFIED until wire + hardware tests |
| Changes merged to `main` | NO |

## Reviewer's first questions

1. Should Home's VFO always keep precedence, or should the active dashboard's context card automatically show?
2. Is FT8's primary Dial page latest decode, selected history, or an always-visible miniature map? Proposed latest decode, with map as next view.
3. What quick Dead Air action deserves one-press availability? Proposed explicit `MARK EVENT` on Events, not always-on global press.
4. Which input gesture can open a launcher without breaking existing hold-to-Home and hold-for-Settings muscle memory?
5. Is the first API experiment PSK Reporter or NOAA, and should enrichment remain disabled by default?

Do not call the design complete or release ready until user signs off D1-D5 and hardware evidence exists.
