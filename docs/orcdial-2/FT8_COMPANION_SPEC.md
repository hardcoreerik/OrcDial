# FT8 / FT4 companion intelligence — proposed design

**Status:** planning, not implemented. **Source:** OrcDial `8003aa3` and OrcSDR `d2c1b56`; see [baseline audit](BASELINE_AND_GAPS.md).

## The actual gap

Tab5's `ft8::Decode` already has real information: `utc_epoch`, `snr_db`, `dt_ms`, `audio_hz`, `message[48]`, `callsign[16]`, `grid[9]`, `kind`, `mode`, `flags`, `dial_hz` and `band_index`. Its `DecodeStore` has bounded recent history (64 records). `ft8_model.hpp` exposes `maidenhead_valid`, `maidenhead_center` and `distance_bearing`. The current Dial's `RADIO_STATE` does not convey strings or true decode history; existing `src/ui.cpp` displays a result index/count in Decodes/Map/Heard.

### Non-goal

OrcDial does **not** run an FT8 demodulator, infer messages from frequency, scrape Tab5 pixels, or transmit FT8. The receiver must provide the decoded record, with its provenance. FT8, FT4 and supported JS8 modes should be distinguished; never assume every page is FT8 if mode changes.

## User scenarios and information priority

**F1: Passive discovery.** With FT8 running on Tab5 and the Dial showing FT8, show the latest *validated* decode with callsign/message preview, grid when transmitted and SNR only when decoder reports it. Show `NO DECODES` rather than a synthetic sample. Update when the Tab5 reports a new sequence, not on a timer guess.

**F2: Browse history.** Turning the encoder while `HISTORY` focus is visible selects among bounded real decodes; the count is stable relative to an explicit snapshot revision. New arrivals do not steal selection while the user is browsing. Short press opens details.

**F3: Where is it?** For a valid, *station-reported* Maidenhead locator, display area center and approximate great-circle distance/bearing if the user's receiver position is known. Four-character locators cover broad cells; do not imply the named city or the exact transmitting station. For callsign-only messages, say `GRID --` and disable the geographic arrow rather than querying a license address as a substitute.

**F4: Mini map.** Use a locally stored coarse outline and project 1..N grid centers of recent local decodes (proposed maximum 16, validate budget). Zoom optional; select a dot by rotating, label the selected callsign/grid, and distinguish old spots. Markers reflect stations actually decoded by this receiver, not all worldwide FT8 traffic.

**F5: Hunter.** Retain existing bounded `ft8_band`, `ft8_hunter`, `ft8_fine` and `ft8_item` actions. FAST HUNT, DECODE HUNT and STOP must be explicitly separate; never misrepresent ENERGY as a valid decode.

## Minimum projected record (draft, not an approved byte layout)

Receiver-owned typed record `FT8_DECODE_SUMMARY` with:
- `schema_revision`, `record_id`/monotonic history sequence, `session_id`, `state_revision`, source=local Tab5 decoder.
- `utc_epoch` and `clock_valid`; if clock not valid, time-since-boot or `TIME --`, not a fabricated UTC.
- `mode`, `band_index` and captured-slot `dial_hz` (never merely the frequency at UI display time).
- `snr_db` **with SNR-valid flag**, `dt_ms`/`audio_hz` only when provided and useful.
- `decode_kind` (CQ/QSO/free/unknown), `flags` for assisted/AP, resolved hash, multi-frame and other decoder origin distinctions.
- Bounded null-terminated `callsign` (16), `grid` (9), and `message` (48). For a free-text message with no callsign, show message instead of inventing a call.
- Optional validated geo: `grid_precision`, receiver-known flag, station grid-center latitude/longitude or bearing/distance, explicitly `approximate`.

These are **requirements**, not a claim that the existing 64-byte `RADIO_STATE` can hold them. The transport RFC covers bounded, authenticated extensions and unknown-field compatibility. A safe compact record may use variable lengths, explicit flags and a strict maximum size; validate wire encoding before committing field offsets.

### Provenance rules

- No labels like `GPS`, `TX LOCATION` or `LIVE POSITION` for a decoded grid. Prefer `REPORTED GRID` or `GRID CENTER`.
- Keep local decode time distinct from PSK Reporter spot time and licensing-database update time.
- A caller's FCC/ham callbook registration is **not** evidence of on-air transmitter coordinates.
- Never render `SNR -12` when `decode_flag_snr_unavailable` is set.
- Keep invalid/ambiguous grid, special callsign, portable suffix, and unidentified free text intact (bounded/sanitized); do not silently guess a jurisdiction.

## Screen spec: FT8 240x240

1. **LIVE:** top `FT8 / 20m`; primary card `LATEST DECODE` or `WAITING`; callsign or text line; grid/status + SNR; bottom toggle `BAND/HISTORY` (and retained Hunter action). The historical FT8 band frequency remains accessible.
2. **DECODES:** one visible selected record at a time; big callsign and decoded message scroll/truncate with explicit detail action; slot time + SNR valid; knob cycles record sequence.
3. **MAP:** static bounded world/coarse-region outline, center markers derived from valid grids only; selected callsign; `NO GRID LOCATORS` when empty; never fake points. Default coarse world projection may be illegible on 240x240; usability review chooses world vs region vs polar plot.
4. **DIRECTION:** optional but recommended focused page. North-up bearing arrow plus numeric bearing and approximate distance from receiver to grid center, explicitly not an antenna reading. Disable if either position is unknown.
5. **HUNTER:** existing actions/status and results; avoid auto-hunt from passive page entry.
6. **HEARD:** unique callsign, first/last seen if known, selected-band context.
7. **SETUP:** read-only status at first; no silent remote configuration.

**Page-count decision:** existing Tab5 FT8 uses six logical tabs; OrcDial may use internal subpages (e.g., DIRECTION as a MAP detail) without changing global tab indices. This requires a UX decision; do not silently redefine current wire `view` values 0..5.

## Mapping algorithm (offline)

For each validated station-reported grid from **successful local decodes**, call the existing receiver `maidenhead_center`. Use center of represented cell, store precision and present coordinate as approximate. Compute great-circle distance/bearing only from a known receiver position; display units in km/mi per setting later. A coarse equirectangular background: `x=(lon+180)/360*diameter`, `y=(90-lat)/180*height`, with dateline wrapping/clipping and circular viewport mask. If projection distorts polar regions, treat the visual as a locator overview rather than a precise measurement.

Never assume the grid always belongs to the decoded callsign: different FT8 message types have different fields; the Tab5 parser/decoder must explicitly identify the locator association. Do not plot unidentified messages or hashed/unresolved identities as confirmed station dots.

## UI wireframe (text only)

`
        [ FT8 · 20m ]
      ┌──────────────┐
      │ LATEST DECODE│
      │   W1AW       │   illustrative only
      │ FN31  -12 dB │
      │ 14.074 MHz   │
      └──────────────┘
       TURN: HISTORY
`

The example values are conceptual; code should source every value from an authenticated receiver record.

## State machine

`NO_LINK -> LINKED_NO_DECODER -> WAITING -> VALID_LOCAL_DECODE -> STALE`, plus `HISTORY_PINNED` as UI selection state. On any dashboard/session change clear old projected record or explicitly mark it as historical; do not present it as newly received. Handle duplicate record sequence once; rate-limit notifications and prevent a burst of decodes from overwhelming the Dial.

## Acceptance (all pending)

- [ ] One legitimate FT8 decode sent by Tab5 appears with byte-exact callsign and normalized message content on Dial.
- [ ] UI handles callsign-only, grid-only, free text, invalid grid, known/unknown UTC, SNR missing, repeated and assisted decodes.
- [ ] Selected history record stays selected across a new decode; list changes preserve stable record IDs.
- [ ] Map dots correspond only to validated, associated station grids; grid-center approximation is labeled.
- [ ] No network or PSK Reporter required to display latest decode / direction / map.
- [ ] Replay, old peers, truncation, oversized text and malformed UTF-8 safely rejected or sanitized.
- [ ] RF decode throughput and audio remain unaffected under a burst of encrypted metadata.
- [ ] Real 240x240 hardware screenshots and rotary usability are captured and manually reviewed.

See [CAPABILITY_AND_TRANSPORT_RFC.md](CAPABILITY_AND_TRANSPORT_RFC.md) and [API_ENRICHMENT_RESEARCH.md](API_ENRICHMENT_RESEARCH.md).
