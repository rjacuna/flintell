"""Disable unsupported profiling and fail explicitly for unavailable WASI APIs."""
from pathlib import Path
import sys
import re
root, target = Path(sys.argv[1]), sys.argv[2]
p = root / 'src/profiler.h'
s = p.read_text()
guard = '#if (defined(__unix__) && !defined(__CYGWIN__)) || defined(__APPLE__)'
if guard in s:
    s = s.replace(guard, guard.replace('#if ', '#if (') + ') && !defined(__EMSCRIPTEN__) && !defined(__wasi__)')
p.write_text(s)
# WebAssembly has no directed hardware rounding. FLINT already has a
# conservative no-fenv branch (return 0), causing its caller to use MPFR
# or exact certification. Select that branch instead of rounding aliases.
for p in (root / 'src/fmpz_lll').glob('is_reduced_d*.c'):
    s = re.sub(r'^#if HAVE_FENV_H$', '#if HAVE_FENV_H && !defined(__wasi__) && !defined(__EMSCRIPTEN__)', p.read_text(), flags=re.M)
    p.write_text(s)
if target == 'wasi':
    # QSieve requires filesystem temporaries. Do not pretend that it works
    # in a browser without a filesystem. The shim is included in every link.
    p = root / 'src/qsieve/factor.c'
    s = p.read_text()
    s = s.replace('fd = mkstemp(', 'fd = flintell_mkstemp(')
    if 'flintell_mkstemp(' in s and 'extern int flintell_mkstemp' not in s:
        s = 'extern int flintell_mkstemp(char *);\n' + s
    p.write_text(s)
