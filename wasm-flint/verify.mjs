import createFlintModule from "./dist/flint.mjs";
const m = await createFlintModule();
const factor = (s) => {
  const i = m.stringToNewUTF8(s);
  const o = m.ccall("crit_flint_factor", "number", ["number"], [i]);
  m._free(i); if (!o) return null;
  const r = m.UTF8ToString(o); m.ccall("crit_flint_free", null, ["number"], [o]); return r;
};
const mul = (a, b) => { const r = Array(a.length + b.length - 1).fill(0n);
  for (let i = 0; i < a.length; i++) for (let j = 0; j < b.length; j++) r[i+j] += a[i]*b[j];
  while (r.length > 1 && r[r.length-1] === 0n) r.pop(); return r; };
const wire = (cs) => `${cs.length}  ${cs.join(" ")}`;

// each case: reconstruct content * prod(factor^exp) and compare with the input
const cases = [
  ["X^12-1",            [-1n,0n,0n,0n,0n,0n,0n,0n,0n,0n,0n,0n,1n]],
  ["(X-1)..(X-6)",      [720n,-1764n,1624n,-735n,175n,-21n,1n]],
  ["S3 (deg 8)",        [576n,0n,-960n,0n,352n,0n,-40n,0n,1n]],
  ["big coeffs",        [100003n,-89n,0n,1234567n,0n,7n]],
  ["12*(X^2+1)^2*(X-3)",[ -108n,36n,-216n,72n,-108n,36n ]],
  ["huge",              [123456789012345678901234567890n, 0n, 0n, 987654321n, 1n]],
  ["deg 20 sparse",     Array.from({length:21},(_,i)=> i===0? -7n : i===20? 3n : 0n)],
];
let bad = 0;
for (const [name, cs] of cases) {
  const out = factor(wire(cs));
  if (!out) { console.log(`${name}: FACTOR FAILED`); bad++; continue; }
  let content = 1n, prod = [1n], nf = 0;
  for (const line of out.split("\n")) {
    const w = line.trim().split(/\s+/).filter(Boolean);
    if (!w.length) continue;
    if (w[0] === "c") { content = BigInt(w[1]); continue; }
    const exp = parseInt(w[0]), f = w.slice(2).map(BigInt); nf++;
    for (let k = 0; k < exp; k++) prod = mul(prod, f);
  }
  prod = prod.map(x => x * content);
  const ok = prod.length === cs.length && prod.every((x,i) => x === cs[i]);
  if (!ok) bad++;
  console.log(`${ok ? "ok  " : "FAIL"}  ${name.padEnd(22)} ${nf} irreducible factor(s)`);
}
console.log(bad ? `\n${bad} FAILURES` : "\nall reconstruct exactly");

if (bad) process.exitCode = 1;
