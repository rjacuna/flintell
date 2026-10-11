#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH SDKROOT CPPFLAGS
"$ROOT/scripts/build-deps.sh" emscripten
PREFIX="$("$ROOT/scripts/prefix.sh" emscripten)"
OUT="${1:-$ROOT/wasm-flint/dist}"
mkdir -p "$OUT"
emcc -O2 "$ROOT/wasm-flint/flintell.c" \
  -I"$PREFIX/include" -L"$PREFIX/lib" -lflint -lmpfr -lgmp \
  -sEXPORTED_FUNCTIONS='["_flintell_cancel","_flintell_factor","_flintell_factor_integer","_flintell_factor_mod","_flintell_is_prime","_flintell_curve_irreducible","_flintell_free","_flintell_version","_crit_flint_factor","_crit_flint_free","_malloc","_free"]' \
  -sEXPORTED_RUNTIME_METHODS='["ccall","cwrap","stringToNewUTF8","UTF8ToString"]' \
  -sALLOW_MEMORY_GROWTH=1 -sMODULARIZE=1 -sEXPORT_ES6=1 \
  -sENVIRONMENT=web,worker,node -sEXPORT_NAME=createFlintModule \
  -o "$OUT/flint.mjs"
cp "$ROOT/wasm-flint/index.mjs" "$OUT/index.mjs"
echo "Built $OUT/flint.mjs and flint.wasm"
