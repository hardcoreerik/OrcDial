# Dead Air companion — truthful observation control

**Status:** planning only. Receiver source: [Dead Air model](https://github.com/hardcoreerik/OrcSDR/blob/d2c1b56baeab8a43c2658ca783bbf0b26243ae97/apps/orcsdr-tab5/ui/dead_air_model.hpp), [dashboard actions](https://github.com/hardcoreerik/OrcSDR/blob/d2c1b56baeab8a43c2658ca783bbf0b26243ae97/apps/orcsdr-tab5/ui/dead_air_dashboard.hpp), [app dispatcher](https://github.com/hardcoreerik/OrcSDR/blob/d2c1b56baeab8a43c2658ca783bbf0b26243ae97/apps/orcsdr-tab5/ui/dead_air_app.cpp). Linked Dial absent in current standalone `src/dashboard.hpp`.

> Dead Air is allowed to be weird. Dead Air is not allowed to lie about what it measured.

## Receiver-side facts to preserve

Current Dead Air has six pages: Overview, Spectrum, Audio, Environment, Events, Review. `Snapshot` has receiver-ready and settled flags; RF/audio relative `dBFS` readings; optional environmental readings with valid/stale/unavailable; event-journal health; sweep state/preset/dwell and known unobserved gaps; receiver/microphone clip enable/state and review/replay status. `ActionKind` contains sweep start/stop, tune step, set demod, toggle clips/mic, select/verify/play/stop clip and other actions. Some Events tab behavior (manual mark and sensitivity) and tab switches are applied directly in `handle_touch`; these need a **shared semantic action API** so remote actions use identical policy and state.

Earlier Dead Air development-handoff notes represent a prior milestone, not current runtime evidence. Current app source manages sweep, clip and mic paths; physical acceptance still needs separate evidence.

## Suggested Dial contexts

| Tab | Default readout | Rotate | Press | Allowed condition |
|---|---|---|---|---|
| Overview | Session elapsed, receiver READY/SETTLING, actual event count, journal status | Select safe quick action | Open tab/action | Valid snapshot only |
| Spectrum | Current tuned Hz, relative RF power, settled/sweep state | When stopped, band-step tune; when focus changed, cycle sweep presets/dwell | Explicit start/stop sweep confirmation | No tune while sweep owns receiver |
| Audio | Measured dBFS RMS/peak and source status | Select audio info/mute control | Toggle mute explicitly | No synthetic waveform; no microphone implicit opt-in |
| Environment | Temperature/RH/pressure if connected/current | Browse sensor | Show status/age/source | Missing/stale reading shows -- |
| Events | Last event type/time, sensitivity and genuine event count | Select event or sensitivity | **Mark Event** on explicit marked control, preferably press/confirm | Must enqueue and report receiver result |
| Review | Selected real clip ID, source, state, verification result | Select clip | Play/stop, inspect hash verification | Only when clip exists and SD state permits |

Back / Home returns to the Dial launcher or context without changing a log entry or receiver tuning.

### One-press manual event

Valuable, but needs explicit arming and feedback. Proposal: on Events, a clearly labeled `PRESS: MARK` action; one press sends `MARK_EVENT` with a unique ID, the receiver acknowledges the durable event/queue acceptance vs SD journal persistence separately. If storage not ready, render `MARK QUEUED` or `LOG FAILED` accurately. No repeated marker when a frame retries; retries share the same command sequence/idempotency key. The Dial must NOT create a local fictional event to conceal network loss.

### Sweep design

Show **HOPPING / SETTLING / LISTENING** and `UNOBSERVED` as different states. One tuner visits one frequency at a time; never draw an apparent continuously monitored multi-frequency spectrum. Controls: stopped -> choose preset/dwell/tuning; running -> STOP only. Reject conflicting tuning/mode actions in the shared receiver dispatcher. A press should not remotely start an investigation sweep merely because it was on the Home screen.

### Microphone and clips

Receiver's built-in microphone capture is separate from demodulated radio audio, optional and explicitly toggled; a client must never silently enable it. Distinguish:
- RF audio level measured from receiver demodulator vs room audio captured by microphone.
- Event journal JSONL recording vs saved audio clip vs an unavailable general-purpose recorder.
- Clip enabled/capturing/writing/saved/failed vs microphone off/listening/paused/failed.
- SD not mounted, out of space, writing failure, replay stopped and verified/mismatch.
For sensitive controls, require an explicit selected control and consider a short hold/confirm if accidental action has consequences.

## Proposed semantic receiver seam (NOT a packet assignment)

`DEAD_AIR_GET_STATE` yields a bounded typed snapshot with `revision`, `freshness`, `page`, availability flags, typed measurements/unit/source/age, sweep state, event counts and current selected item. `DEAD_AIR_ACTION` accepts stable action identifiers like `SET_PAGE`, `SELECT_ITEM`, `STEP_FREQUENCY`, `CYCLE_DEMOD`, `SET_SENSITIVITY`, `START_SWEEP`, `STOP_SWEEP`, `MARK_EVENT`, `TOGGLE_CLIPS`, `TOGGLE_MIC`, `VERIFY_CLIP`, `PLAY_CLIP` and `STOP_REPLAY`, with bounded typed arguments.

Actions must go through the **same Tab5 handler** used by touch, enforce ownership and current dashboard, return actual applied/rejected/unsupported status and authoritative state revision, and not be interpreted as generic frequency deltas on the Dial. No direct mutation of EventModel, DSP or SD objects from ESP-NOW callbacks.

### Screen visual language

- Violet/cyan style allowed for Dead Air identity; observed levels only, unit always `dBFS` unless a calibrated source exists.
- No ghost-likelihood %, voice classifications, or made-up waveforms.
- Distinguish `NO SENSOR`, `WARMING UP`, `STALE`, `NO EVENT`, `WRITING` and `FAILED`.
- Cached events may be viewed offline only with `SAVED / NOT LIVE` label and known acquisition source/time.
- Header link state is not a detector state. Make both unambiguous.

## Minimum state contract per view

| Field | Validity conditions |
|---|---|
| Frequency/demod | Current receiver snapshot + settled flag |
| RF relative level | dBFS with source measured and freshness; never dBm without calibration |
| Audio level | Only when actual demodulated samples flowing |
| Environment | present + valid + age <= policy; otherwise reason |
| Event count/last marker | Receiver EventModel snapshot revision; receiver-generated identity |
| Sweep status | generated scan schedule + paused/unobserved gaps |
| Clip count/selected | storage index with actual saved metadata |
| Journal health | active/failed/unavailable; queue losses and saved counts separate |
| Microphone | explicit receiver state; never inferred from audio tab |

## Design acceptance (pending)

- [ ] Opening Dead Air on Tab5 is reflected by dashboard ID 20 on Dial, with no stale FT8 page.
- [ ] All six logical tabs selectable by semantic commands, including after Tab5 switches tabs.
- [ ] Manual marker logged exactly once across lost/replayed delivery; ack and journal persistence distinguishable.
- [ ] Sweep start/stop rejects incompatible tune and accurately reports blind intervals.
- [ ] Sensor unplug/staleness and empty event history show proper unavailable states.
- [ ] Optional microphone cannot be activated by entering a view, reconnection, stale button press or accidental resends.
- [ ] Playing clips does not claim live RF audio or cause phantom detector events.
- [ ] A disconnected Dial cannot change receiver state.
- [ ] Validated on actual Tab5/M5Dial, with serial logs, timestamps, command IDs, screenshots and no audio/IQ regressions.

## Explicit exclusion

No paranormal detections, spiritual assertions, invented numerical readings or unmeasured source attribution. The feature is a measurable investigation log and its control surface, not a ghost detector.
