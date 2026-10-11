# flintell

Source: [rjacuna/flintell](https://github.com/rjacuna/flintell).

Shared Haskell and WebAssembly bindings to **FLINT 3.6.0**, extracted from
CriticalValues and FunDom. This is the arithmetic package for future work,
including a Milnor K-theory simplifier; it does not implement that simplifier.

The repository provides:

- `flintell`: opaque, scoped FLINT objects, exact integers/rationals, integer
  and rational matrices, PSL₂(ℤ), Arb/Acb projections, and integer-polynomial
  factorisation. The `Flint.*` modules build natively and with GHC's WASI backend.
- `vendor/Flint2`: the native `Data.Number.Flint.*` binding fork, retaining
  CriticalValues' imports. See [port notes](vendor/Flint2/PORTING.md) for scope.
- `wasm-flint`: an Emscripten ES module for exact polynomial factorisation,
  plus shared WASI static dependencies for direct linking into Haskell reactors.

`versions.sh` pins FLINT, GMP and MPFR and their archive checksums. The default
prefixes are `~/.cache/flintell/3.6.0/{native,emscripten,wasi}/local`. Override
the common cache root with `FLINTELL_BUILD_ROOT`, jobs with `FLINTELL_JOBS`.
The ABI-specific prefixes must remain separate.

## Native build

Prerequisites: GHC/Cabal, a native C toolchain, make, curl, tar, shasum and Python 3.
Dependencies build locally; no Homebrew libraries or global installations change.

```sh
export PATH="$HOME/.ghcup/bin:$PATH" CC=/usr/bin/clang
./scripts/build-deps.sh native
./scripts/configure-cabal.sh
cabal build all
cabal test flintell:smoke --test-show-details=direct
```

For an installed FLINT 3.6, instead put its include/library paths in
`cabal.project.local`; link FLINT, MPFR and GMP. `configure-cabal.sh` records
absolute paths for this machine and refuses to replace unrelated local settings.
Native builds use static C dependencies; binaries do not depend on this cache
at runtime. Building from source currently disables assembly for portability.

With sibling checkouts in `~/Projects`:

```sh
./scripts/configure-cabal.sh ../FunDom
./scripts/configure-cabal.sh ../CriticalValues/haskell
(cd ../FunDom && cabal build all && cabal test --test-show-details=direct)
(cd ../CriticalValues/haskell && cabal build all)
```

FunDom's Cabal project includes `../flintell`. CriticalValues includes
`../../flintell/vendor/Flint2`. There are no copied binding sources in the
consumers. New Haskell consumers should depend on `flintell` and add its path
to their `cabal.project`.

```haskell
import Flint.Poly
-- Coefficients are in ascending degree order; integers stay exact.
-- factor [2,-4,2] == Factorisation 2 [([-1,1],2)]
main = factor [2,-4,2] >>= print
```

## Emscripten / wasm-flint

Activate your Emscripten SDK, then:

```sh
source "$HOME/emsdk/emsdk_env.sh"
./wasm-flint/build.sh
node wasm-flint/test.mjs
node wasm-flint/verify.mjs
```

The generated `wasm-flint/dist/{index.mjs,flint.mjs,flint.wasm}` can be served
as static assets or imported in Node. Keep all three together.

```js
import createFlint from './wasm-flint/dist/index.mjs';
const flint = await createFlint();
flint.factor([2n, -4n, 2n]);
// {content: 2n, factors: [{coefficients: [-1n, 1n], exponent: 2}]}
```

Use bigint or decimal strings for large coefficients. The JS wrapper rejects
unsafe JavaScript integers and frees both input and output allocations.
Zero has content zero and no factors; constants have no factors. The C wire
API (`flintell_factor`/`flintell_free`) retains FLINT's decimal polynomial
format, plus the old `crit_flint_*` names for existing clients. Returned C
strings must be freed with the paired free function.

CriticalValues' `haskell/wasm/build-flint-wasm.sh` delegates here and installs
the generated assets into its `wasm/` and `web/` directories.

## WASI

```sh
./scripts/build-deps.sh wasi
./scripts/test-wasi.sh
(cd ../FunDom && ./wasm/build-web.sh wasm)
```

Set `WASI_SDK_PATH` if the SDK is not at `~/.ghc-wasm/wasi-sdk`. FunDom uses
GHC's `~/.ghc-wasm/env` and Binaryen for its reactor build. Its script reads
Haskell and C bindings directly from this repository. `FLINTELL_ROOT` can
override the sibling repository location in consumer shell scripts.

WASI and Emscripten have different ABIs and linear memories. Link the WASI
archives into the GHC reactor; do not pass pointers between separate modules.
The native Flint2/hsc2hs package is not the WASI interface; `Flint.*` is.
The wasm patches disable unavailable profiling and use FLINT's existing
MPFR/exact fallback for LLL certification rather than pretending that directed
hardware rounding works. WASI QSieve's temporary files are unsupported and
fail explicitly if reached; the supported FunDom operations do not use them.

## Provenance and licence

The `Flint.*` bindings and shims derive from FunDom, copyright 2026 RJ Acuña,
GPL-3.0-or-later. Original notices are retained. Flint2 retains Hartmut Monien's
copyright and its own licence in `vendor/Flint2/LICENSE`. FLINT, GMP and MPFR
remain separately licensed upstream dependencies; their source archives are
fetched, not vendored into this repository. The Emscripten bridge originated
in CriticalValues and is maintained here with the other project code.

## Validation

Verified on macOS arm64 with GHC 9.10.3, 2026-10-03:

- FLINT 3.6.0 built from the checksum-pinned release for native, Emscripten
  and WASI. Latest release checked against https://flintlib.org/downloads.html.
- `cabal build all` in flintell and both consumer projects.
- `cabal test flintell:smoke`: exact factor reconstruction, parity with
  Flint2, zero/constants, large integers, rationals, rectangular matrices,
  matrix windows with a larger parent stride, modulus layouts, and PSL₂.
- FunDom: **471/471** native checks, plus a rebuilt WASI reactor that rendered
  the Γ₀(11) page under Node.
- CriticalValues: **13/13** benchmark construction checks using the shared
  native fork; its rebuilt Emscripten bridge passed all seven reconstruction
  cases, including high-degree and large-coefficient inputs.
- `scripts/test-wasi.sh`: factorisation, matrix arithmetic and PSL₂ in Wasmtime.
- Emscripten wrapper tests: multiplicities, zero/constants, 1501-digit content,
  rejection of unsafe JS integers, repeated calls and exact reconstruction.
- Cabal source tarballs generated; the npm tarball was unpacked outside the
  repositories and successfully imported and used from there.

The legacy Flint2 API is not fully audited; its unported FLINT 2
modular-matrix interface is excluded.

### Exact field support

`Flint.Integer` now exposes signed prime decomposition and proved primality.
`Flint.Poly.factorMod` factors polynomials over F_p for arbitrary-size prime p,
returning the leading coefficient and monic factors with multiplicities.
Composite moduli are rejected. These operations use the same C implementation
on native, WASI, and Emscripten builds; the npm wrapper exposes `factorInteger`,
`isPrime`, and `factor(coefficients, prime)`.

The Milnor K-theory consumer in `../ClusterSchemes/milnor` uses these APIs for
Q, prime fields, and rational function fields, and also builds as a WASI command.

`Flint.Curve.irreducibleOverFunctionField characteristic polynomial` tests a
polynomial in the fixed names `x,y` over k(x)[y], using FLINT multivariate
factorization. Characteristic 0 selects Q; other values must be prime.
It accepts exactly one y-dependent factor of multiplicity one; x-only factors
are units. Reducible/nonreduced inputs return False, malformed inputs raise an
error. The Emscripten equivalent is `curveIrreducible(polynomial, prime=0n)`.
This same C implementation supports equation-only Milnor searches natively
and in WASI, including irreducible polynomials without an irreducible
reduction modulo any prime.
