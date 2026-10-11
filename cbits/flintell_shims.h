/* FunDom — fundamental domains of congruence subgroups of SL₂(ℤ).
 * Copyright (C) 2026 RJ Acuña. SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef FLINTELL_SHIMS_H
#define FLINTELL_SHIMS_H
#include <flint/flint.h>
#if __FLINT_RELEASE < 30600
#error "flintell requires FLINT 3.6 or newer"
#endif
#include <flint/acb_modular.h>
#include <flint/fmpz_mat.h>
#include <flint/fmpq_mat.h>

void   flintell_psl2z_normal_form(psl2z_t g);

fmpz_mat_struct *flintell_fmpz_mat_new(slong r, slong c);
void             flintell_fmpz_mat_free(fmpz_mat_struct *m);
fmpz            *flintell_fmpz_mat_entry(const fmpz_mat_struct *m, slong i, slong j);

fmpq_mat_struct *flintell_fmpq_mat_new(slong r, slong c);
void             flintell_fmpq_mat_free(fmpq_mat_struct *m);
fmpq            *flintell_fmpq_mat_entry(const fmpq_mat_struct *m, slong i, slong j);


/* Allocation and access shims: every FLINT object this program touches is
 * made and freed here, so the Haskell side never knows a struct's size or
 * layout — which is also what makes the same code build for wasm32-wasi. */
#include <flint/fmpq.h>
#include <flint/arb.h>
#include <flint/acb.h>
fmpz         *flintell_fmpz_new(void);
void          flintell_fmpz_free(fmpz *x);
fmpq         *flintell_fmpq_new(void);
void          flintell_fmpq_free(fmpq *x);
arb_struct   *flintell_arb_new(void);
void          flintell_arb_free(arb_struct *x);
acb_struct   *flintell_acb_new(void);
void          flintell_acb_free(acb_struct *x);
psl2z_struct *flintell_psl2z_new(void);
void          flintell_psl2z_free(psl2z_struct *g);
fmpz         *flintell_psl2z_entry(psl2z_struct *g, int k);
arf_struct   *flintell_arb_midref(arb_struct *x);
int           flintell_arf_rnd_near(void);
#endif
