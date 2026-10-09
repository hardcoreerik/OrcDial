#!/usr/bin/env bash
# CI toolchain for OrcDial on ubuntu-latest: pinned PlatformIO + esptool + test deps in a venv,
# and Mbed TLS 3.6 sources for the host tests (tools/release_check.py --mbedtls-source).
#   tools/ci/setup.sh [MBEDTLS_DIR]   (default: $RUNNER_TEMP/mbedtls); adds the venv to GITHUB_PATH.
set -euo pipefail
venv=${CI_VENV:-$HOME/.venv-orcdial-ci}
mbedtls=${1:-${RUNNER_TEMP:-/tmp}/mbedtls}
python3 -m venv "$venv"
"$venv/bin/pip" install -q --upgrade pip
"$venv/bin/pip" install -q "platformio==6.2.0" "esptool==4.9.0" "pillow>=10" "pyserial>=3.5"
if [ ! -f "$mbedtls/include/mbedtls/build_info.h" ]; then
  git clone -q --depth 1 --branch v3.6.5 --recurse-submodules --shallow-submodules \
    https://github.com/Mbed-TLS/mbedtls.git "$mbedtls"
fi
if [ -n "${GITHUB_PATH:-}" ]; then echo "$venv/bin" >> "$GITHUB_PATH"; fi
if [ -n "${GITHUB_ENV:-}" ]; then echo "MBEDTLS_SOURCE=$mbedtls" >> "$GITHUB_ENV"; fi
echo "venv $venv, mbedtls $mbedtls"

# Temporary: since #6 the host runtime_test needs tests/runtime_stubs/esp_heap_caps.h (fixed by
# PR #7, tests only). Until that lands, create the same empty stub in the CI workspace only (not
# committed) so the host tests still run. No-op once the file exists in the repo.
stub=tests/runtime_stubs/esp_heap_caps.h
if [ -d tests/runtime_stubs ] && [ ! -f "$stub" ]; then
  printf '#pragma once\n#include "runtime_platform.hpp"\n' > "$stub"
  echo "::warning::CI created the empty host stub $stub (PR #7 adds it to the repo)"
fi
