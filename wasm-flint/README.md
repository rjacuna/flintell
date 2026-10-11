# @flintell/wasm-flint

FLINT 3.6.0 integer polynomial factorisation, with GMP 6.3.0 and MPFR 4.2.2.
Part of the flintell repository. Activate Emscripten and run `npm run build`
from this directory, then `npm test`. Build scripts use the parent repository's
shared dependency versions and cache. After building, `npm pack` creates a
self-contained JS/Wasm package.

```js
import createFlint from '@flintell/wasm-flint';
const flint = await createFlint();
console.log(flint.version);
console.log(flint.factor([2n, -4n, 2n]));
// { content: 2n, factors: [{ coefficients: [-1n, 1n], exponent: 2 }] }
```

Coefficients are low degree first. Use bigint or decimal strings for exact
large values. The wrapper releases temporary allocations after each call.
When serving unbundled assets, keep `index.mjs`, `flint.mjs`, and `flint.wasm`
together. Emscripten options, including `locateFile`, can be passed to
`createFlint` for bundlers or custom asset locations.

The WASI archive build is separate (`../scripts/build-deps.sh wasi`); this
Emscripten module must not be linked into a GHC WASI reactor or share pointers
with one.

Integer and prime-field operations (all values stay exact):

```js
flint.factorInteger(-360n); // [{prime:-1n,exponent:1n}, {prime:2n,exponent:3n}, ...]
flint.isPrime(2n**127n - 1n); // true; proved primality
flint.factor([-1n, 0n, 1n], 7n); // factor t^2-1 over F_7
```

The optional second argument to `factor` must be prime. Its returned `content`
is the leading coefficient modulo that prime, with monic polynomial factors.
Zero returns content zero and no factors. `factorInteger(0n)` rejects zero.
Primes and coefficients may exceed a machine word; use bigint or decimal
strings. Native Haskell equivalents are `Flint.Integer.factorInteger`,
`Flint.Integer.isPrime`, and `Flint.Poly.factorMod`.

Plane-curve irreducibility over Q(x) or F_p(x):

```js
flint.curveIrreducible('y^4+1'); // true over Q(x)
flint.curveIrreducible('(y-x)*(y+x)'); // false
flint.curveIrreducible('y^2-x', 2n); // true, including inseparable extensions
```

The polynomial uses fixed names x,y. The test accepts exactly one y-dependent
factor with exponent one; x-only factors are units in k(x)[y]. It returns false
for reducible/nonreduced or constant-in-y inputs and throws on malformed input
or composite moduli. Native Haskell uses
`Flint.Curve.irreducibleOverFunctionField characteristic polynomial`.
