#!/usr/bin/env bash
set -eo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "${GHC_WASM_ENV:-$HOME/.ghc-wasm/env}"
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH SDKROOT CPPFLAGS
PREFIX="$("$ROOT/scripts/prefix.sh" wasi)"
OUT="${TMPDIR:-/tmp}/flintell-wasi-test"
mkdir -p "$OUT"
wasm32-wasi-ghc -O1 -i"$ROOT/src" -outputdir "$OUT" \
  -I"$PREFIX/include" -I"$ROOT/cbits" \
  -optc-D_WASI_EMULATED_SIGNAL \
  -optl-L"$PREFIX/lib" -optl-lflint -optl-lmpfr -optl-lgmp \
  -optl-lwasi-emulated-signal -optl-lwasi-emulated-process-clocks -optl-lwasi-emulated-getpid \
  "$ROOT/test/Wasi.hs" "$ROOT/cbits/flintell_shims.c" "$ROOT/wasm-flint/flintell.c" \
  -o "$OUT/smoke.wasm"
wasmtime "$OUT/smoke.wasm"
