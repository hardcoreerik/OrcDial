# Optional third-party RF/SDR intelligence — provider review

Research 2026-10-29. Documentation reviewed via public websites; **no production provider calls, credentials, radio-spot subscriptions or personal callsign lookups executed**. All integrations are proposals, not existing features. OrcSDR/Tab5 is the network client and cache owner. The M5Dial receives only bounded summaries over the paired authenticated link.

## Product policy

1. Offline-first. Locally decoded FT8 messages, reported grids, bearing/distance and map are fully usable without internet.
2. **Opt-in network enrichment** at the receiver, visibly labeled with provider, acquisition time, cache age and failure state.
3. No uploading our own reception data unless the user separately opts into public spot reporting; querying PSK Reporter is read-only and does not require uploading.
4. No private home address / phone / registration number on the Dial. License lookup is not measured transmitter position. Filter PII at the Tab5 before serialization, don't simply hide it in the Dial UI.
5. No embedded credentials in source, release assets or ESP-NOW payload. Respect provider fair-use policy, errors, backoff and user choice.

## Providers

| Provider | Verified public interface | Value to OrcDial | Policy / risk | Rank |
|---|---|---|---|---|
| **PSK Reporter retrieval** | Official `https://retrieve.pskreporter.info/query` GET/POST; senderCallsign/time/mode/frequency filters | Where *other receivers* have reported a selected station; band context | Official developer guidance **no more than one data retrieval per five minutes**; external spots are neither local decodes nor proof of operator's position | P1 optional |
| **PSK Reporter MQTT relay** | `https://www.mqtt.pskreporter.info/`; `mqtt.pskreporter.info` TLS on :1884 or WSS :1886, topic `pskr/filter/v2/{band}/{mode}/{tx}/{rx}/{tx_grid}/{rx_grid}/{tx_dxcc}/{rx_dxcc}` | Near-real-time spot streaming / propagation preview | Third-party operator with independent policy, high-volume if unfiltered; focus on selected callsign/band, bounded retention; not a default background firehose | Research only |
| **NOAA SWPC** | `https://services.swpc.noaa.gov/json/` and `/products/` | Kp, solar flux, geomagnetic/space-weather status in Shortwave/Radio Home | Source timestamps, unknown/offline/aged state; NOAA JSON products changed structure in March 2026, so pin field schema and test | P1 optional |
| **Callook** | `https://callook.info/` US license lookup API | License class/status and broad state/country for selected callsign | US-only; raw result contains mailing address/derived coordinates — strip before display/storage | P2 on-demand |
| **HamQTH API v2** | `https://www.hamqth.com/developers`; `GET /api/v2/dxcc` no login; `GET /api/v2/callbook/{callsign}` requires login token | DXCC country/continent (no credential) and optional richer international callbook | Requires visible provider credit; time-bounded auth tokens; country/entity is not transmitter position | P2 |

### Primary documentation links and verified provider constraints

- PSK Reporter developer retrieval, fields, time window and 5-minute courtesy limit: https://pskreporter.info/pskdev.html
- MQTT relay provider, TCP/TLS/WebSocket ports, topic and spot fields: https://www.mqtt.pskreporter.info/
- MQTT timestamp semantics (`t` vs `t_tx`): https://www.mqtt.pskreporter.info/timing.html
- NOAA data access and JSON hosts: https://www.swpc.noaa.gov/products-and-data (canonical center); https://services.swpc.noaa.gov/json/
- NWS SWPC March 2026 data-format change notice: https://www.weather.gov/media/notification/pdf_2026/scn26-21_Data_Format_Changes_Impacting_SWPC_Products.pdf
- HamQTH v2 developer contract, login and provider-credit requirements: https://www.hamqth.com/developers
- FCC licensee privacy concerns explained by ARRL: https://www.arrl.org/fcc-licensee-privacy
- Callook API: https://callook.info/api_reference.php (verify live response schema before implementing).

## Model each fact's origin

| Display item | Origin | Correct label | Wrong label |
|---|---|---|---|
| Local decoder result | Tab5 DSP | `LOCAL DECODE` | `PSK REPORTED` |
| Local decoded grid | Transmitted Maidenhead grid within validated message | `STATION-REPORTED GRID` | `PRECISE TX GPS` |
| Distance to a grid | Tab5 great-circle geometry | `TO GRID CENTER (APPROX)` | `EXACT DISTANCE` |
| PSK Reporter spot | Internet report from external receiver | `OTHER RECEIVER REPORTED`, time, source | `WE HEARD` |
| FCC/callbook region | Public registration or DXCC entity | `LICENSE REGION` / `DXCC COUNTRY` | `TRANSMITTING FROM` |
| Space weather | NOAA measurements/forecasts | `NOAA SWPC · UPDATED...` | `LOCAL BAND OPEN` if not locally measured |

Never combine remote SNR (from someone else's receiver) with local SNR without explicit separate labeling. Foreign callsign prefixes, portable/mobile suffixes and license registries may not locate the RF transmitter.

## PSK Reporter query approach

**Phase 1:** manual `VIEW PROPAGATION` action on selected valid callsign from FT8; Tab5 constructs a conservative, time-filtered query (selected senderCallsign and mode, optional band), enforces minimum 5-minute refresh interval per source and caches results for a bounded duration. If no network or no reports, present `NO RECENT REPORTS` or `NETWORK OFFLINE`, not an invented world-map dot.

**Phase 2 research:** MQTT subscription filtered to selected callsign and desired band/mode. Validate TLS, broker TOS, reconnect/backoff and peak spot throughput with a separate test harness before contemplating an always-on receiver. A receiving station's call and grid are also public RF reporting data, not verified identity/location.

## Callsign lookup policy (privacy by design)

- Default OFF; selection explicitly initiated for a single callsign, not continuous mass-querying of every decode.
- Public FCC records can include name/mailing address; a registered address is not a station transmitter. Store/emit only license status, class, jurisdiction/state and country, with source and age.
- Do not cache unneeded personal information, allow full-address fields into debug logs, or forward personal data to the M5Dial.
- Callook is US focused; choose provider based on user consent and record types, not guesses from a prefix.
- HamQTH `DXCC` offers country/continent without lookup credentials, but uses callsign-origin/entity inference and is not live RF position. User login required for v2 full callbook; secrets stay in secure receiver settings.

## NOAA SWPC Home/Shortwave widget

Candidate `SOLAR` mini-view: Kp with UTC observation time, 10.7cm solar flux where available, NOAA alerts when current. Treat space weather as **context**, not a direct prediction that this particular frequency is currently receivable. Validate new JSON formats and numeric units, cache for a deliberately chosen interval, expire old data and avoid network requests from the UI or IQ task.

## Open engineering decisions

- Select one provider for initial network proof of concept (recommended: NOAA for broad Home value or PSK Reporter for direct FT8 value).
- Decide if an initial version should exclude all APIs until locally decoded information works well.
- Choose asynchronous HTTP client and secure credential storage on existing Tab5 connectivity; measure TLS heap and router/Wi-Fi/ESP-NOW coexistence.
- Decide if PSK spots may be stored persistently; default to RAM-only bounded cache, no personal data.
- Decide how local vs external map marker glyphs differ, and whether remote spots should ever appear on the same map without an explicit overlay toggle.

## Verification backlog

- [ ] Live provider schema inspection, rate/TOS review, 4xx/429 and stale-cache handling.
- [ ] Source-attribution UX: receiver-local and remote spot never confused.
- [ ] No unprompted callsign lookup; privacy fields removed before cache/log/transport.
- [ ] Captured HTTP/MQTT traffic redacted and token-free.
- [ ] RF/ESP-NOW/FT8 decode tests pass while asynchronous API requests fail/retry.
- [ ] Provider-offline mode is functionally useful; opt-out remains persistent.
