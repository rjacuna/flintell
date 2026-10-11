# Flint2 in flintell

Based on CriticalValues' patched Flint2 0.1.0.5 (upstream Hartmut Monien).
The local version is 0.1.0.6. `Flint2.cabal` is authoritative; obsolete hpack
and Stack manifests have been removed so they cannot regenerate old settings.

This native compatibility package preserves `Data.Number.Flint.*` imports.
For new code, prefer flintell's scoped `Flint.*` modules, which also compile
for WASI and avoid peeking C layouts from Haskell.

Changes beyond the old FLINT 3.4 build patch:

- Eleven FLINT 3 matrix records now represent `stride` as `CLong`, rather
  than interpreting it as an array of row pointers.
- Matrix entry helpers use that stride, including for windows into a larger
  matrix. NMod matrices return a pointer to the embedded modulus context;
  NMod polynomial matrices expose their scalar modulus as a limb.
- `CPSL2ZWord` reads the actual vendored `psl2z_word_struct` from `csrc/psl2z.h`.
  The old patch incorrectly redirected its fields to `psl2z_struct`.
- The FLINT 2 `Fmpz.Mod.Mat` modules are excluded from the library/umbrella:
  FLINT 3 moved the modulus into a separate context, so replacing struct
  offsets alone cannot repair those function signatures. Source is retained
  for a future port, but it is not an available module.
- Redundant inline definitions in hsc2hs probes and the vendored DLog C
  source are no longer emitted: FLINT supplies those symbols, and static
  linking otherwise produces duplicate definitions.
- C dependencies are configured via the project's include/library paths;
  all consumers use the same pinned native build as flintell.

Compilation is not an ABI audit of all historical Flint2 functions. The
supported/tested consumer path is integer polynomial factorisation, with
matrix-layout smoke tests. The full legacy API should not be assumed verified
against FLINT 3.6. The opaque `Flint.*` API is the maintained cross-platform
surface. See the repository's tests and validation notes for concrete coverage.
