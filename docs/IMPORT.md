# OrcDial source import

Imported from [OrcSDR](https://github.com/hardcoreerik/OrcSDR), local commit `8d5d37a0a369f75a3a672781156d33c1faa6a4d3`, branch `codex/m5dial-vfo`, on 2026-10-05. The source commit was local at import time; this import does not push the OrcSDR branch.

Copied tracked Dial source, embedded graphics, artwork provenance, protocol documentation, and protocol/controller/USB tests from `orcdial/` to this repository's root. Preserved the root license and imported the current control matrix as a compatibility snapshot. Build instructions now use repository-relative paths. Removed the receiver-stub build environment from this Dial-only project.

The Tab5 application, pairing/settings, C6 relay firmware and build scripts, receiver stub, and integration plan remain in OrcSDR. The existing Dial copy is retained there for compatibility during the split; no OrcSDR files were removed or modified by this import. In particular, its Tab5 build still references the shared protocol definitions there. Updating that boundary is a separate integration change.

No device logs, private pairing keys, Wi-Fi credentials, build caches, compiled firmware, recovery images, or screenshots were imported. No devices were flashed by this import.

Future protocol or dashboard ID changes must be coordinated with the OrcSDR receiver. The copied control matrix describes the source snapshot rather than promising compatibility with every OrcSDR release.
