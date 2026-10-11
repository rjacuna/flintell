/* FunDom — fundamental domains of congruence subgroups of SL₂(ℤ).
 * Copyright (C) 2026 RJ Acuña. SPDX-License-Identifier: GPL-3.0-or-later */
/* The C side of the FLINT binding, kept deliberately tiny.
 *
 * Two kinds of function live here:
 *
 *   * psl2z normal form. FLINT's psl2z_t is a matrix in PSL2(Z), canonical
 *     when c > 0, or c = 0 and d > 0. psl2z_mul and psl2z_inv produce that
 *     form; a matrix typed in by hand does not arrive in it, so the Haskell
 *     smart constructor sends it through here first.
 *
 *   * matrix allocation and entry access. FLINT 3 changed fmpz_mat_struct
 *     (`rows` became `stride`), which is what broke the Hackage Flint2
 *     binding's matrix layer (see flint2-fork/). Rather than peek the struct
 *     from Haskell at all, everything goes through FLINT's own accessors, so
 *     this stays correct if the layout changes again.
 */
#include "flintell_shims.h"

void flintell_psl2z_normal_form(psl2z_t g)
{
    if (fmpz_sgn(&g->c) < 0 || (fmpz_is_zero(&g->c) && fmpz_sgn(&g->d) < 0)) {
        fmpz_neg(&g->a, &g->a);
        fmpz_neg(&g->b, &g->b);
        fmpz_neg(&g->c, &g->c);
        fmpz_neg(&g->d, &g->d);
    }
}

fmpz_mat_struct *flintell_fmpz_mat_new(slong r, slong c)
{
    fmpz_mat_struct *m = flint_malloc(sizeof(fmpz_mat_struct));
    fmpz_mat_init(m, r, c);
    return m;
}
void flintell_fmpz_mat_free(fmpz_mat_struct *m) { fmpz_mat_clear(m); flint_free(m); }
fmpz *flintell_fmpz_mat_entry(const fmpz_mat_struct *m, slong i, slong j) { return fmpz_mat_entry(m, i, j); }

fmpq_mat_struct *flintell_fmpq_mat_new(slong r, slong c)
{
    fmpq_mat_struct *m = flint_malloc(sizeof(fmpq_mat_struct));
    fmpq_mat_init(m, r, c);
    return m;
}
void flintell_fmpq_mat_free(fmpq_mat_struct *m) { fmpq_mat_clear(m); flint_free(m); }
fmpq *flintell_fmpq_mat_entry(const fmpq_mat_struct *m, slong i, slong j) { return fmpq_mat_entry(m, i, j); }

fmpz *flintell_fmpz_new(void) { fmpz *x = flint_malloc(sizeof(fmpz)); fmpz_init(x); return x; }
void  flintell_fmpz_free(fmpz *x) { fmpz_clear(x); flint_free(x); }
fmpq *flintell_fmpq_new(void) { fmpq *x = flint_malloc(sizeof(fmpq)); fmpq_init(x); return x; }
void  flintell_fmpq_free(fmpq *x) { fmpq_clear(x); flint_free(x); }
arb_struct *flintell_arb_new(void) { arb_struct *x = flint_malloc(sizeof(arb_struct)); arb_init(x); return x; }
void        flintell_arb_free(arb_struct *x) { arb_clear(x); flint_free(x); }
acb_struct *flintell_acb_new(void) { acb_struct *x = flint_malloc(sizeof(acb_struct)); acb_init(x); return x; }
void        flintell_acb_free(acb_struct *x) { acb_clear(x); flint_free(x); }
psl2z_struct *flintell_psl2z_new(void) { psl2z_struct *g = flint_malloc(sizeof(psl2z_struct)); psl2z_init(g); return g; }
void          flintell_psl2z_free(psl2z_struct *g) { psl2z_clear(g); flint_free(g); }
fmpz *flintell_psl2z_entry(psl2z_struct *g, int k)
{
    switch (k) { case 0: return &g->a; case 1: return &g->b; case 2: return &g->c; default: return &g->d; }
}
arf_struct *flintell_arb_midref(arb_struct *x) { return arb_midref(x); }
int flintell_arf_rnd_near(void) { return ARF_RND_NEAR; }

#ifdef __wasi__
/* WASI's browser reactor has no temporary filesystem for QSieve. */
int flintell_mkstemp(char *tmpl) {
    (void) tmpl;
    flint_throw(FLINT_ERROR, "QSieve temporary files unavailable on WASI");
    return -1;
}
#endif
