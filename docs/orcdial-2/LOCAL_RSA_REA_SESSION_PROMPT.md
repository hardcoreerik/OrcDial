# Local RSA-Sandbox / REA-Results research session

**Use this prompt in the user's local authorized research environment only**. This handoff was prepared on 2026-10-29; the commands below have **NOT** been executed in this web sandbox because the local `F:\AI` filesystem, authenticated repo clone and required toolchain are unavailable. A GitHub connector source audit is not a substitute for generated RSA structural metrics.

## Task

Perform a repeatable, **read-only source architecture + complexity analysis** of OrcDial and OrcSDR dashboard/protocol paths to support [OrcDial 2.0 proposal](README.md). Do not modify source in the originating repositories, change production firmware, create GitHub branches from RSA, or run flashing commands.

**Baselines:**
- `github:hardcoreerik/OrcDial@8003aa3d007fe75ca3379eebb7b90f97ec24371d`
- `github:hardcoreerik/OrcSDR@d2c1b56baeab8a43c2658ca783bbf0b26243ae97`

**Start by reading:**
- `F:\AI\RSA-Sandbox\AGENTS.md`
- `hardcoreerik/REA-Results/AGENTS.md`
- OrcDial `docs/orcdial-2/README.md`, `BASELINE_AND_GAPS.md`, `CAPABILITY_AND_TRANSPORT_RFC.md`, `IMPLEMENTATION_ROADMAP.md` from the planning branch.

## Execution contract

1. Work inside `F:\AI\RSA-Sandbox` only; other code repositories are read-only inputs.
2. `python rsa.py doctor`; record tool availability and versions, refuse to claim results if dependencies are missing.
3. Import snapshots through **rsa.py**, not hand-made target folders:

```powershell
Set-Location F:\AI\RSA-Sandbox
python rsa.py doctor
python rsa.py import github:hardcoreerik/OrcDial@8003aa3d007fe75ca3379eebb7b90f97ec24371d --name orcdial-20261029
python rsa.py import github:hardcoreerik/OrcSDR@d2c1b56baeab8a43c2658ca783bbf0b26243ae97 --name orcsdr-20261029
python rsa.py analyze orcdial-20261029 --skip-rea
python rsa.py analyze orcsdr-20261029 --skip-rea
python rsa.py compare orcdial-20261029 orcsdr-20261029 --label orcdial-2-seam
```

If internet import is unavailable, use documented `rsa.py import local:<path>` on **verified clean commit checkouts**, not a mutable working tree. Keep proof of ref in `target.json` and git rev-parse output; do not substitute a different HEAD silently.

4. Analyze complexity hotspots in `OrcDial/src/ui.cpp`, `src/main.cpp`, `src/control/link.cpp`, `src/control/secure_runtime.hpp`, `OrcSDR/apps/orcsdr-tab5/ui/ft8_*`, `dead_air_*`, dashboard registry and receiver bridge. Use canonical `metrics/lizard_functions.csv` for actual CCN/NLOC, then trace action/data flow in notes; **never invent metrics**.
5. Produce a dependency/ownership map for `M5Dial encoder/touch -> Dial controller -> secure packet -> C6 -> Tab5 action adapter -> FT8/Dead Air -> state ack`. Distinguish verified source path from inferred or missing links.
6. Run RSA REA binary analysis **only if genuine ELF/BIN artifacts are already available or separately authorized to build inside the local sandbox**. No firmware, binaries, or third-party source get published to REA-Results.
7. If testing protocol feasibility, create separate sandbox-only fake data fixtures: valid FT8 decode, invalid grid, missing SNR, free text, duplicate marker, stale state, old v4 peer. Clearly label mock/synthetic test input as mock, not live RF evidence.
8. Write analyst notes in permitted areas, with source path, line/function, commit, metric key/value from generated outputs and differences. **Never hand-edit generated** `metrics/*`, `rea/*`, `manifest.json` or generated `report.md` sections.

## Artifact checklist (local)

- `targets/orcdial-20261029/target.json`, `metrics/summary.json`, `metrics/lizard_functions.csv`, `notes/*.md`.
- `targets/orcsdr-20261029/target.json` and corresponding metrics.
- Comparison `comparisons/<date>_orcdial-2-seam/manifest.json`, `metrics.csv` and `report.md` generated via `rsa.py`.
- Note `orcdial_2_seam_findings.md` in appropriate target `notes/` documenting link/auth/codec, registry skew, FT8 projection, Dead Air dispatcher seam and regression risks.
- Hashes, tool versions, exact commands and date; failed or skipped stages explicitly noted.

## REA publication (requires user's established approval workflow)

The RSA repo must never be pushed; its local commits stay local. After checking source evidence and committing analysis inside RSA only:

```powershell
python rsa.py publish --dry-run --verbose
# Review redactions/secret scan, exclusions, intended private destination and diffs.
# Use established approved publish procedure when ready:
python rsa.py publish --push
```

For new findings in a web chat, put **human reviewed source-level findings**, not generated numbers, into `hardcoreerik/REA-Results/inbox/2026-10-29_orcdial-2-control-and-ft8.md` on an isolated branch. Do not hand-edit `REA-Results/INDEX.md`, `index.json`, `graph.json`, `targets/` or `comparisons/`. Do not merge the inbox note without explicit approval.

## Research questions to resolve

- Can the current v4 authenticated transport dispatch bounded variable-length metadata records without a new security session version and without a C6 firmware change?
- Which actual OrcSDR receiver action adapter handles FT8 `ft8_item`/`ft8_hunter` and what fields does it already project?
- How can Dead Air touch/direct mutations and remote semantic actions share one idempotent dispatcher?
- What are exact available heap, stack, CPU, encoded MTU and frame-time costs under a 16-marker map and 100-byte FT8 record?
- What is the smallest testable backward-compatible capability handshake?
- How should long-press settings/Home/navigation migrate with no surprising retunes?

## Handoff

Produce an RSA report with pinned metrics, specific risks, proposed implementation slices, test matrix, observations vs interpretations, unresolved issues and links to generated outputs. Do not claim a source-level audit is an over-the-wire test. Include verbose How to Run/Test steps and retain log files in the working run directory in addition to the canonical RSA outputs.
