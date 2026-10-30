# RFC: authenticated capabilities + dashboard data projections

**RFC status: broad dashboard catalog remains DRAFT.** The authorized October 30
FT8-only implementation negotiates schema 1 through existing authenticated
state/heartbeat fields; see `PROTOCOL.md`. It retains protocol 4 and C6 firmware.
The larger manifest/catalog below is not implemented.
Baseline: [OrcDial `src/control/protocol.hpp`](https://github.com/hardcoreerik/OrcDial/blob/8003aa3d007fe75ca3379eebb7b90f97ec24371d/src/control/protocol.hpp), [`secure_session.hpp`](https://github.com/hardcoreerik/OrcDial/blob/8003aa3d007fe75ca3379eebb7b90f97ec24371d/src/control/secure_session.hpp), [`PROTOCOL.md`](https://github.com/hardcoreerik/OrcDial/blob/8003aa3d007fe75ca3379eebb7b90f97ec24371d/PROTOCOL.md). Receiver truth comes from OrcSDR `d2c1b56`.

## Problem

The current `ORDL` control **payload** is fixed 64 bytes, protocol `version=4`, message types 1..16, with dashboard, view, selected/item_count, 32-bit capabilities and state revision fields. That is sufficient for tuning and summary state, not bounded callsign/message strings, Dead Air multi-source validity and event provenance, dynamic control metadata, or a list of map markers. The secure transport's **outer** fragment size and 192-byte logical payload are documented, but actual application dispatch accepts today's 64-byte control codec. We must NOT assume arbitrary 192-byte payloads are already routed.

## Architecture rule

`M5Dial hardware input -> local UI semantic action -> authenticated link -> Tab5 command queue -> dashboard's actual shared handler -> authoritative revision/ack -> Dial display`

Data flow is one-way observer projection from receiver to Dial. Never let Dial parse an FT8 RF stream, invent a receiving position, write Dead Air journals or call provider APIs directly as part of phase one. Preserve ESP-NOW and existing C6 relay, secure pairing, NVS trust policy and receiver standalone function.

## Compatibility options (decision D2)

**Option A — typed extension records within existing authenticated session (preferred to prototype).** Add a *separate* versioned, length-delimited logical record type for receive-only metadata, gated by capability handshake. Old peer ignores/rejects unknown record without compromising existing `RADIO_STATE`. Needs proof that the current secure session and worker support dispatch of other logical sizes and that record dispatch is replay-safe.

**Option B — control packet extension negotiated via a new application protocol version.** Maintain a parallel v4 control reader, negotiate mutual support explicitly, and use a new packet type/version for metadata. Larger migration/test matrix, more risk to older firmware and pairing.

**Option C — chunked short records within existing 64-byte payload.** Keeps codec size but adds multi-message assembly and complicated timeout/sequence/ack semantics. Use only if other options demonstrably cannot traverse unchanged C6 bridge.

No option is chosen until local source trace and over-the-wire measurements are complete. **Do not increment the security pairing version merely because dashboard data evolves**; distinguish cryptographic session version from application projection schema version.

## Proposed feature negotiation

Authenticated after pairing, receiver sends a **capability manifest** with:
- `transport_schema` and `dashboard_catalog_revision`.
- Stable dashboard IDs and supported-ID bitset (IDs 0..20 currently). Explicitly exclude Utilities ID 11 and local Dial token 255.
- Feature flags `ft8_decode_summary`, `ft8_locator_points`, `dead_air_snapshot`, `dead_air_semantic_actions`, `network_enrichment` plus per-dashboard revision.
- Safe maxima: record byte length, item count, frequency of updates, permitted actions and available views.
- Current active dashboard and authoritative state revision.

On missing/old manifest, fall back to current legacy dashboard subset and `RADIO_STATE` rendering; do not assume unavailable actions exist. No ID reuse or existing enum renumbering. A later high-level catalog should name the views, but not send arbitrary third-party strings as control labels without validation.

## Proposed record family (names, not assigned numeric IDs)

| Record | Origin | Direction | Update trigger | Limit policy |
|---|---|---|---|---|
| `CAPABILITY_MANIFEST` | Tab5 | to Dial | session start/change | <= one bounded manifest, fetch paged if needed |
| `FT8_DECODE_SUMMARY` | FT8 decode store | to Dial | new record / selected item request | bounded text + flags, de-duplicated |
| `FT8_GRID_POINTS` | validated station grid history | to Dial | MAP open/change | capped spots per page, cache revision |
| `DEAD_AIR_STATE` | Dead Air snapshot adapter | to Dial | page change or meaningful revision | bounded typed fields, units/status |
| `DASHBOARD_ACTION_RESULT` | common receiver dispatcher | to Dial | command processed | accepted/applied/rejected, revision/reason |
| `ENRICHMENT_SUMMARY` | optional Tab5 network layer | to Dial | user request, cached response | source/time/confidence/no PII |

## Envelope requirements

Minimum fields: `record_type`, `schema_revision`, `payload_length`, `session_nonce/identity` or binding to existing authenticated session, monotonic application sequence, `dashboard_id`, `view_id`, `snapshot_revision`, `flags` and payload. Existing AES-GCM tag/session counters remain the authentication/replay boundary. The old CRC32 is not authentication.

- **Sizes:** maximum secure reassembled message documented as 192 bytes, fixed outer fragments 64 / 48 payload. Do not fill every bit of the budget; define exact packed layout, length/test vectors and parse rejects after implementation prototype.
- **Text:** strict length limits and termination; sanitize control chars, invalid encodings and unexpectedly large Unicode; do not trust network-provided text simply because Tab5 forwarded it.
- **Timing:** rate-limit metadata; prioritize control commands and heartbeats over list/map/page refreshes. No blocking crypto, rendering, SD I/O or HTTP requests on Wi-Fi/ESP-NOW callbacks, C6 hosted paths or IQ/DSP threads.
- **Acknowledgment:** existing command `ack` and revision semantics preserved. A transport send/queued acknowledgement is not proof that application action was applied. Return explicit refusal/revision, and keep idempotent command IDs for Dead Air manual marks.
- **Expiry:** each record has a producer timestamp or age/sequence; expire on dashboard change, unpair, session renewal, data-source reset and worker failure. Show `STALE` instead of silently displaying last reading as current.
- **Backpressure:** bounded queues, coalescing high-rate display refresh, no loss of action-result priority; clear dropped-record counters and request a fresh snapshot after desync.
- **Security:** only an authenticated paired peer may issue actions or request metadata. No unauthenticated callsign queries, credential forwarding to the Dial or legacy MAC-only fallback. Existing session/ratchet/Forget semantics remain unchanged.

## Dashboard-ID migration

OrcDial baseline registry: Home 0, FM 1, P25 2, ADS-B 3, Shortwave 4, Weather 5, CB 6, LoRa 7, Airband 8, Marine 9, Satellite 10, Utilities 11 (not a dashboard), Settings 12, RF Lab 13, Wi-Fi 14, POCSAG 15, AM 16, FT8 17. OrcSDR has **SSTV 18, ACARS 19, Dead Air 20**. Add new identities without moving old IDs. Require current receiver manifest to determine whether new dashboards are actually supported/active; a newer Dial connected to older receiver must show unavailable safely.

## Source tracing tasks before approval

1. Trace `Link::send`, `Link::handle`, encrypted `secure_session`, fragment/reassembly, C6 bridge and Tab5 command queue from sender to action handler.
2. Determine whether existing secure envelope carries any variable-length payload; measure real encoded overhead and heap allocation for 192-byte logical records.
3. Write golden vector tests for v4 unchanged, unknown type, malformed length, replay, mixed order, duplicate, truncated fragment and reconnect.
4. Design projection codec as a small platform-neutral C++17 module used by both repos, with canonical serialization and input sanitization.
5. Build a *fake paired two-device transport harness* with drop/reorder/fuzz and throttle before any radio hardware test.
6. Verify old/new receiver and Dial matrix on actual devices, including no-C6-update expectation; document any incompatible path honestly.

## Signoff checklist

- [ ] Dashboard action ownership and payload schema approved.
- [ ] Existing v4 control messages unchanged; old receiver/Dial degrade visibly and safely.
- [ ] Known-bad fragments, replays and unknown records cannot mutate application state.
- [ ] Text and map subscriptions have bounded heap/cpu/radio load.
- [ ] No change to installed C6 firmware required by the design without a separate explicit user decision.
- [ ] Hardware tests cover command acknowledgement and audio/IQ/USB interference; record real logs.
