# Circular UI + input model (proposal)

**Target:** M5Dial 240x240 circular M5GFX display, one rotary encoder with press, touch and persistent paired link. Source baseline is in [BASELINE_AND_GAPS](BASELINE_AND_GAPS.md). **Not approved and not implemented.**

## Primary principle

The Dial should show *what the receiver is doing* and let one gesture operate the next likely function. UI density is not a measure of capability. Never take a knob movement to mean a frequency retune unless the current selected action is visibly and explicitly TUNE.

## Three visual directions for 240x240 review

| Direction | Layout | Strength | Concern |
|---|---|---|---|
| A — Instrument | Huge center frequency/readout, 3 small mode chips, narrow link ring, bottom focus strip | Immediate physical radio control | Not enough room for decodes or logs |
| B — Context Card | Top dashboard identity, central live fact (callsign/event/selected station), status strip, bottom action chip | Best FT8/Dead Air companion | Might hide VFO unless explicit Home contract |
| C — Navigator | Icon/art inside circular safe area, large title and two-line preview, obvious press label | Friendly standalone launcher | Extra steps for frequent adjustments |

Recommendation: **A for Radio Home; B for an active non-Home dashboard; C for the launcher.** This is a *hybrid* proposal; user approval is outstanding.

### Pixel-space safety

- Canvas 240x240, centered at (120,120), circular inner radius **about 104 px** after outer status ring and padding.
- A rectangle centered at y=120 is clipped at the circle; usable half-width approx `sqrt(104^2 - (y-120)^2)`. For instance, near y=45 usable width is ~144 px; y=120 offers 208 px. These are derived geometry guidance, not measured font bounds.
- Core data occupies approximately y=64..151; secondary readout y=151..190; navigation/gesture prompts y=194..222.
- No critical text or touch target outside inner circle; bound touch geometry to circular hit-test, not just x/y rectangles.
- Prefer high contrast, tested font sizes, truncation rules, and full words over unlabeled blinking icons.
- Link ring: green authenticated/current, amber pending/stale, red disconnected. Do not treat green as RF-signal validity.
- Replace decorative waveform with a measured trace **only** if real data and provenance are available; otherwise clearly decorative or omit it.

## Proposed screen architecture

`Boot -> (Home/Context) <-> Launcher -> Selected Dashboard -> Quick Controls / Details`

- **Radio Home**: exactly when receiver is on Home; giant frequency, band, mode, focused step/span/filter/volume and last acknowledged value. Rotating tunes only with visible `TUNE` focus. Long-touch frequency can open the existing keypad. Never silently switch dashboards on mere knob movement.
- **Context Home**: for active FT8/Dead Air/other non-Home dashboard. Main card shows *current real fact* and one primary safe action; screen-specific actions are below a view-selector. Must never make a remote dashboard appear linked when it is offline.
- **Launcher**: user-initiated, works offline with last cached titles clearly labelled. Favor favorites and recent real dashboards; hide undiscovered unsupported actions. Settings remains explicitly local on the Dial.

## Input / gesture contract to decide

| Gesture | Home / Context | Launcher | Dashboard detail |
|---|---|---|---|
| Rotate | Edit explicitly focused control; for context cards move through actual items | Select next available dashboard | Context-specific, shown on screen |
| Short press | Act on visibly selected control; no hidden destructive action | Open selected dashboard if supported | Activate safe selected action / navigate |
| Long press ~1 s | Proposed: open launcher, **conflicts with existing hold-to-Home**; must choose final binding | Return to previous | Return to context/Home |
| Hold ~4 s | Preserve discoverable access to Dial Settings | Settings (if explicitly requested) | Settings only via confirmed gesture |
| Tap top | Proposed mode/view selection | Filter/favorite? | Next supported view; never simulated remote touch |
| Tap center | Focus/inspect selected data | Open selected dashboard | Context action only |
| Tap bottom | Consistent BACK/LAUNCHER target | Back | Back |

**Blocking conflict:** Current firmware holds the button to return Home and uses four seconds on Home for settings. Do not implement the proposed one-second launcher hold until an input migration is explicitly approved. Prefer retaining all existing gestures and using a visible on-screen LAUNCH control if unsure. Acceptance includes expert muscle memory.

## State and error UX

- `LINKED` = authenticated link established. `OFFLINE` = cannot control receiver. `PENDING` = command queued, not yet applied. `REJECTED` = receiver refused. `STALE` = snapshot timed out. Never optimistically display a received action as applied.
- If Tab5 switches dashboards, transition with a visible dashboard identifier. Suppress stale FT8 or Dead Air content from the previous dashboard.
- Hot updates: leave selected/history item pinned while browsing; do not steal selection every 7.5/15 seconds during FT4/FT8 receive.
- New fact badge can show `NEW` for a limited interval; user may ignore it, and it never changes the knob's meaning.
- Must support OFFLINE launch, pair-pending, no-decoder, no-grid, unsynchronized clock, empty history, no map, no sensors, slow network, and old receiver firmware.

## First UI review pack before firmware

The initial six **static SVG mockups** are now committed at [mockups/README.md](mockups/README.md). They are concept artwork, not live M5GFX screenshots. The user still needs to choose direction and gesture policy before implementation.


Create **three native-resolution 240x240 concept families**, each with Radio Home, Context FT8 latest decode, FT8 Map, Dead Air live, Launcher, Offline and Stale. Use actual M5GFX screenshot capture later; initial source-free wireframes are not evidence of firmware rendering. Track review results: legibility at 1:1 physical size; number of interactions from Home to desired action; accidental retune/destructive-press rate; whether primary information is intelligible at a glance.

## Approved UI criteria (proposed gates)

1. Frequent tasks take **no more than two meaningful inputs** from the appropriate context screen; evaluate with human test scenarios (not a measured current result).
2. Touch targets fit the visible circular hit area; every encoder action has an on-screen label.
3. Full protocol state remains truthful and accessible. Layout never covers a missing-value status.
4. No fake or inferred station names, signal strengths, waterfall traces, location claims or API results.
5. No regression to existing fast tuning, keypad access, pairing and global Home/Back recovery.
