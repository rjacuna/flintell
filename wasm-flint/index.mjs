// Exact integer coefficients as bigint or decimal strings, low degree first.
import createFlintModule from './flint.mjs';
export default async function createFlint(options = {}) {
  const m = await createFlintModule(options);
  function integer(value) {
    if (typeof value === 'number' && !Number.isSafeInteger(value))
      throw new TypeError('Use bigint or decimal strings for large integers');
    return BigInt(value);
  }
  return {
    version: m.ccall('flintell_version', 'string', [], []),
    cancel(numerator, denominator) {
      const wire = cs => {
        const values = Array.from(cs, integer);
        return `${values.length}  ${values.join(' ')}`;
      };
      const n = m.stringToNewUTF8(wire(numerator));
      const d = m.stringToNewUTF8(wire(denominator));
      let output = 0;
      try {
        output = m.ccall('flintell_cancel', 'number', ['number', 'number'], [n, d]);
        if (!output) throw new Error('FLINT rational-function cancellation failed');
        const arrays = m.UTF8ToString(output).trim().split('\n').map(line => {
          const [count, ...values] = line.trim().split(/\s+/);
          if (BigInt(count) !== BigInt(values.length)) throw new Error('Invalid FLINT response');
          return values.map(BigInt);
        });
        if (arrays.length !== 2 || arrays[1].length === 0) throw new Error('Invalid FLINT response');
        return {numerator: arrays[0], denominator: arrays[1]};
      } finally {
        if (output) m.ccall('flintell_free', null, ['number'], [output]);
        m._free(n); m._free(d);
      }
    },
    curveIrreducible(polynomial, characteristic = 0n) {
      const result = m.ccall('flintell_curve_irreducible', 'number', ['string', 'string'],
        [integer(characteristic).toString(), String(polynomial)]);
      if (result < 0) throw new Error('FLINT curve factorisation failed');
      return result === 1;
    },
    isPrime(value) {
      return !!m.ccall('flintell_is_prime', 'number', ['string'], [integer(value).toString()]);
    },
    factorInteger(value) {
      const n = integer(value);
      if (n === 0n) throw new RangeError('Zero has no multiplicative prime decomposition');
      const input = m.stringToNewUTF8(n.toString());
      let output = 0;
      try {
        output = m.ccall('flintell_factor_integer', 'number', ['number'], [input]);
        if (!output) throw new Error('FLINT integer factorisation failed');
        const [head, ...lines] = m.UTF8ToString(output).trim().split('\n');
        if (head !== 's 1' && head !== 's -1') throw new Error('Invalid FLINT response');
        const factors = lines.map(line => {
          const [prime, exponent] = line.trim().split(/\s+/).map(BigInt);
          return {prime, exponent};
        });
        if (head === 's -1') factors.unshift({prime: -1n, exponent: 1n});
        return factors;
      } finally {
        if (output) m.ccall('flintell_free', null, ['number'], [output]);
        m._free(input);
      }
    },
    factor(coefficients, prime = undefined) {
      const cs = Array.from(coefficients, x => {
        if (typeof x === 'number' && !Number.isSafeInteger(x))
          throw new TypeError('Use bigint or decimal strings for large integers');
        return BigInt(x);
      });
      const input = m.stringToNewUTF8(`${cs.length}  ${cs.join(' ')}`);
      let output = 0;
      try {
        output = prime === undefined
          ? m.ccall('flintell_factor', 'number', ['number'], [input])
          : m.ccall('flintell_factor_mod', 'number', ['string', 'number'], [integer(prime).toString(), input]);
        if (!output) throw new Error('FLINT factorisation failed');
        const [head, ...lines] = m.UTF8ToString(output).trim().split('\n');
        return {
          content: BigInt(head.split(' ')[1]),
          factors: lines.map(line => {
            const [exponent, length, ...values] = line.trim().split(/\s+/);
            if (values.length !== Number(length)) throw new Error('Invalid FLINT response');
            return { coefficients: values.map(BigInt), exponent: Number(exponent) };
          })
        };
      } finally {
        if (output) m.ccall('flintell_free', null, ['number'], [output]);
        m._free(input);
      }
    }
  };
}
