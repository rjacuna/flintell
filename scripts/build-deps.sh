#!/usr/bin/env bash
# Build pinned dependencies in separate, versioned prefixes for each ABI.
set -eo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/versions.sh"
TARGET="${1:?usage: build-deps.sh native|emscripten|wasi}"
case "$TARGET" in native|emscripten|wasi) ;; *) echo "Unknown target: $TARGET" >&2; exit 2;; esac
# Host include paths poison cross compilation (notably macOS CPATH).
if [ "$TARGET" != native ]; then unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH SDKROOT CPPFLAGS; fi
BUILD="${FLINTELL_BUILD_ROOT:-$HOME/.cache/flintell}/$FLINT_VERSION/$TARGET"
PREFIX="$BUILD/local"
JOBS="${FLINTELL_JOBS:-4}"
mkdir -p "$BUILD" "$PREFIX"
cd "$BUILD"
# Check content even on a warm cache. Never mix archives from different versions.
fetch() {
  local url="$1" file="$2" sum="$3"
  if [ ! -f "$file" ]; then
    curl --fail --location --retry 3 "$url" -o "$file.part"
    mv "$file.part" "$file"
  fi
  printf '%s  %s\n' "$sum" "$file" | shasum -a 256 -c -
}
fetch "https://ftp.gnu.org/gnu/gmp/gmp-$GMP_VERSION.tar.xz" "gmp-$GMP_VERSION.tar.xz" "$GMP_SHA256"
fetch "https://www.mpfr.org/mpfr-$MPFR_VERSION/mpfr-$MPFR_VERSION.tar.xz" "mpfr-$MPFR_VERSION.tar.xz" "$MPFR_SHA256"
fetch "https://github.com/flintlib/flint/releases/download/v$FLINT_VERSION/flint-$FLINT_VERSION.tar.gz" "flint-$FLINT_VERSION.tar.gz" "$FLINT_SHA256"
HOST_CC="${FLINTELL_HOST_CC:-$(command -v clang || command -v cc)}"
export CC_FOR_BUILD="$HOST_CC" HOST_CC
configure() { ./configure "$@"; }
make_target() { make -j"$JOBS" "$@"; }
HOST_ARGS=()
FLINT_ARGS=()
export CFLAGS="-O2"
export LDFLAGS=""
case "$TARGET" in
 native)
   export CC="$HOST_CC"
   FLINT_ARGS=(--disable-shared --enable-static --disable-assembly)
   ;;
 emscripten)
   command -v emcc >/dev/null || { echo 'Activate emsdk_env.sh first.' >&2; exit 1; }
   configure() { emconfigure ./configure "$@"; }
   make_target() { emmake make -j"$JOBS" "$@"; }
   HOST_ARGS=(--host=none)
   FLINT_ARGS=(--disable-assembly --disable-pthread --disable-thread-safe)
   ;;
 wasi)
   SDK="${WASI_SDK_PATH:-$HOME/.ghc-wasm/wasi-sdk}"
   export CC="$SDK/bin/wasm32-wasi-clang" CXX="$SDK/bin/wasm32-wasi-clang++"
   export AR="$SDK/bin/llvm-ar" RANLIB="$SDK/bin/llvm-ranlib" NM="$SDK/bin/llvm-nm" LD="$SDK/bin/wasm-ld" STRIP="$SDK/bin/llvm-strip"
   export CFLAGS="$CFLAGS -D_WASI_EMULATED_SIGNAL -D_WASI_EMULATED_PROCESS_CLOCKS -D_WASI_EMULATED_GETPID"
   export LDFLAGS="-lwasi-emulated-signal -lwasi-emulated-process-clocks -lwasi-emulated-getpid"
   # config.guess gives a portable native build triple.
   [ -d "gmp-$GMP_VERSION" ] || tar xf "gmp-$GMP_VERSION.tar.xz"
   HOST_ARGS=(--host=wasm32-wasi --build="$(sh "gmp-$GMP_VERSION/config.guess")")
   FLINT_ARGS=(--disable-assembly --disable-pthread --disable-thread-safe)
   ;;
esac
if [ ! -f "$PREFIX/lib/libgmp.a" ]; then
  [ -d "gmp-$GMP_VERSION" ] || tar xf "gmp-$GMP_VERSION.tar.xz"
  (cd "gmp-$GMP_VERSION"; configure "${HOST_ARGS[@]}" --disable-assembly --disable-shared --enable-static --prefix="$PREFIX"; make_target; make_target install)
fi
if [ ! -f "$PREFIX/lib/libmpfr.a" ]; then
  [ -d "mpfr-$MPFR_VERSION" ] || tar xf "mpfr-$MPFR_VERSION.tar.xz"
  (cd "mpfr-$MPFR_VERSION"; configure "${HOST_ARGS[@]}" --with-gmp="$PREFIX" --disable-shared --enable-static --prefix="$PREFIX"; make_target; make_target install)
fi
if [ ! -f "$PREFIX/lib/libflint.a" ]; then
  [ -d "flint-$FLINT_VERSION" ] || tar xf "flint-$FLINT_VERSION.tar.gz"
  if [ "$TARGET" != native ]; then
    python3 "$ROOT/scripts/patch-wasm.py" "$BUILD/flint-$FLINT_VERSION" "$TARGET"
  fi
  (cd "flint-$FLINT_VERSION"; configure "${HOST_ARGS[@]}" "${FLINT_ARGS[@]}" --disable-shared --enable-static --with-gmp="$PREFIX" --with-mpfr="$PREFIX" --prefix="$PREFIX"; make_target; make_target install)
fi
printf '\nBuilt FLINT %s (%s): %s\n' "$FLINT_VERSION" "$TARGET" "$PREFIX"
