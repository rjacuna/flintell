import assert from 'node:assert/strict';
import createFlint from './dist/index.mjs';
const flint = await createFlint();
assert.equal(flint.version, '3.6.0');
assert.deepEqual(flint.factor([]), {content: 0n, factors: []});
assert.deepEqual(flint.factor([0n]), {content: 0n, factors: []});
assert.deepEqual(flint.factor([-12n]), {content: -12n, factors: []});
assert.deepEqual(flint.factor([2n,-4n,2n]), {content: 2n, factors: [{coefficients: [-1n,1n], exponent: 2}]});
assert.deepEqual(flint.factor([10n**1500n]), {content: 10n**1500n, factors: []});
assert.throws(() => flint.factor([Number.MAX_SAFE_INTEGER+1]), TypeError);
for(let i=0; i<100; i++) assert.equal(flint.factor([-1n,0n,1n]).factors.length, 2);
console.log(`wasm-flint: FLINT ${flint.version}; zero, constants, multiplicity, huge content and repeated calls passed`);

assert.equal(flint.isPrime(2n**127n-1n), true);
assert.equal(flint.isPrime(15n), false);
assert.equal(flint.isPrime(-7n), false);
assert.deepEqual(flint.factorInteger(-360n), [
  {prime:-1n,exponent:1n},{prime:2n,exponent:3n},{prime:3n,exponent:2n},{prime:5n,exponent:1n}
]);
assert.deepEqual(flint.factorInteger(1n), []);
assert.throws(() => flint.factorInteger(0n), RangeError);
assert.throws(() => flint.isPrime(Number.MAX_SAFE_INTEGER+1), TypeError);
console.log('wasm-flint: integer prime decomposition and primality passed');

for (const p of [2n, 7n, 2n**127n-1n]) {
  const f = flint.factor([-1n,0n,1n], p);
  assert.equal(f.content, 1n);
  let product = [f.content];
  for (const {coefficients: cs, exponent} of f.factors) for (let e=0;e<exponent;e++) {
    const next = Array(product.length+cs.length-1).fill(0n);
    product.forEach((a,i)=>cs.forEach((b,j)=>{next[i+j]=(next[i+j]+a*b)%p;}));
    product = next;
  }
  assert.deepEqual(product, [p-1n,0n,1n]);
}
assert.deepEqual(flint.factor([7n], 7n), {content:0n,factors:[]});
assert.deepEqual(flint.factor([3n], 7n), {content:3n,factors:[]});
assert.throws(()=>flint.factor([1n,1n],15n));
console.log('wasm-flint: prime-field polynomial factorisation passed');

assert.equal(flint.curveIrreducible('y^4+1'), true);
assert.equal(flint.curveIrreducible('y^2+x^2-1'), true);
assert.equal(flint.curveIrreducible('(y-x)*(y+x)'), false);
assert.equal(flint.curveIrreducible('(y-x)^2'), false);
assert.equal(flint.curveIrreducible('y^2-x', 2n), true);
assert.equal(flint.curveIrreducible('y^2+x^2-1', 2n), false);
assert.throws(()=>flint.curveIrreducible('y^2-x', 15n));
console.log('wasm-flint: exact curve irreducibility tests passed');
