#!/usr/bin/env bash
# Linux CI build of the M5Dial firmware (PlatformIO env "dial") plus the merged image.
#   tools/ci/build-dial.sh --out DIR [--build-id "nightly abc1234 2026-10-09"] [--name OrcDial-M5Dial-nightly-abc1234]
# Writes DIR/<name>.bin (complete image for 0x0: bootloader 0x0, partitions 0x8000,
# boot_app0 0xE000, app 0x10000; the same four files `pio run -t upload` writes) and
# DIR/<name>.elf. The build ID is passed as the ORCDIAL_BUILD_ID macro through
# PLATFORMIO_BUILD_FLAGS; firmware that doesn't use the macro is unaffected.
set -euo pipefail
out="" build_id="" name=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out=$2; shift 2 ;;
    --build-id) build_id=$2; shift 2 ;;
    --name) name=$2; shift 2 ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -n "$out" ] || { echo "usage: $0 --out DIR [--build-id ID] [--name NAME]" >&2; exit 2; }
case "$build_id" in *[!A-Za-z0-9._:+\ -]*) echo "build id has unsupported characters: $build_id" >&2; exit 2 ;; esac
[ ${#build_id} -le 39 ] || { echo "build id longer than 39 characters" >&2; exit 2; }
repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$repo"
name=${name:-OrcDial-M5Dial-$(git rev-parse --short=7 HEAD)}
pio=${PIO:-pio}
if [ -n "$build_id" ]; then
  export PLATFORMIO_BUILD_FLAGS="'-DORCDIAL_BUILD_ID=\"$build_id\"'"
fi
"$pio" run -e dial
b=.pio/build/dial
boot_app0="${PLATFORMIO_CORE_DIR:-$HOME/.platformio}/packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin"
[ -f "$boot_app0" ] || { echo "boot_app0.bin not found at $boot_app0" >&2; exit 1; }
python3 - "$b/partitions.bin" <<'PY'
import sys, hashlib
t = open(sys.argv[1], "rb").read()
want = {"nvs": (0x9000, 0x5000), "otadata": (0xE000, 0x2000), "app0": (0x10000, 0x330000)}
got = {}
for i in range(0, len(t), 32):
    e = t[i:i + 32]
    if e[:2] != b"\xaa\x50":
        break
    got[e[12:28].rstrip(b"\0").decode()] = (int.from_bytes(e[4:8], "little"), int.from_bytes(e[8:12], "little"))
for k, v in want.items():
    if got.get(k) != v:
        sys.exit(f"partition {k} is {got.get(k)}, expected {v}: the browser installer's NVS-safe layout changed")
print("partition layout ok:", ", ".join(f"{k} {o:#x}/{s:#x}" for k, (o, s) in got.items()))
PY
app_size=$(stat -c %s "$b/firmware.bin")
[ "$app_size" -le $((0x330000)) ] || { echo "app is $app_size bytes, larger than app0" >&2; exit 1; }
mkdir -p "$out"
# Same flash parameters `pio run -t upload` passes for this board (qio board -> dio, 80m, 8MB).
python3 -m esptool --chip esp32s3 merge_bin -o "$out/$name.bin" \
  --flash_mode dio --flash_freq 80m --flash_size 8MB \
  0x0 "$b/bootloader.bin" 0x8000 "$b/partitions.bin" 0xe000 "$boot_app0" 0x10000 "$b/firmware.bin"
cp "$b/firmware.elf" "$out/$name.elf"
echo "DIAL_BUILD_OK app=$app_size merged=$(stat -c %s "$out/$name.bin") build_id='$build_id'"
