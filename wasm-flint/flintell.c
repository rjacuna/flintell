/* The FLINT side of the browser build.
 *
 * The whole surface is `char * -> char *`. That is not laziness: the Haskell
 * module is wasm32-wasi and this one is Emscripten, so they are two instances
 * with two linear memories and no shared pointers. A coarse boundary — one
 * round trip per factorisation, decimal strings both ways — makes that
 * irrelevant, because the marshalling is amortised over an entire
 * factorisation.
 *
 * Wire format is FLINT's own `fmpz_poly_get_str`: "len  c0 c1 ... c_{len-1}".
 * Output: one line per irreducible factor, "<exponent> <poly_str>", with the
 * content first as "c <content>".
 */
#include <flint/fmpz.h>
#include <flint/fmpz_poly.h>
#include <flint/fmpz_poly_factor.h>
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#else
#define EMSCRIPTEN_KEEPALIVE
#endif
#if __FLINT_RELEASE < 30600
#error "flintell requires FLINT 3.6 or newer"
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

EMSCRIPTEN_KEEPALIVE
char *flintell_factor(const char *poly_str)
{
    fmpz_poly_t f;
    fmpz_poly_factor_t fac;
    char *content, *out;
    size_t cap = 1024, len = 0;
    slong i;

    fmpz_poly_init(f);
    if (fmpz_poly_set_str(f, poly_str) != 0) { fmpz_poly_clear(f); return NULL; }

    fmpz_poly_factor_init(fac);
    fmpz_poly_factor(fac, f);

    out = malloc(cap);
    if (!out) { fmpz_poly_factor_clear(fac); fmpz_poly_clear(f); return NULL; }
    out[0] = '\0';

    content = fmpz_get_str(NULL, 10, &fac->c);
    size_t content_need = strlen(content) + 4;
    if (content_need > cap) {
        char *bigger = realloc(out, content_need);
        if (!bigger) {
            flint_free(content); free(out);
            fmpz_poly_factor_clear(fac); fmpz_poly_clear(f); return NULL;
        }
        out = bigger; cap = content_need;
    }
    len += snprintf(out + len, cap - len, "c %s\n", content);
    flint_free(content);

    for (i = 0; i < fac->num; i++) {
        char *ps = fmpz_poly_get_str(fac->p + i);
        size_t need = strlen(ps) + 32;
        if (len + need > cap) {
            char *bigger;
            cap = (len + need) * 2;
            bigger = realloc(out, cap);
            if (!bigger) { flint_free(ps); free(out);
                           fmpz_poly_factor_clear(fac); fmpz_poly_clear(f); return NULL; }
            out = bigger;
        }
        len += snprintf(out + len, cap - len, "%ld %s\n", (long) fac->exp[i], ps);
        flint_free(ps);
    }

    fmpz_poly_factor_clear(fac);
    fmpz_poly_clear(f);
    return out;
}

EMSCRIPTEN_KEEPALIVE
void flintell_free(char *p) { free(p); }

/* Existing CriticalValues clients keep working during migration. */
EMSCRIPTEN_KEEPALIVE
char *crit_flint_factor(const char *s) { return flintell_factor(s); }
EMSCRIPTEN_KEEPALIVE
void crit_flint_free(char *p) { flintell_free(p); }
EMSCRIPTEN_KEEPALIVE
const char *flintell_version(void) { return FLINT_VERSION; }

/* Integer factorisation and primality share this API in native and wasm. */
#include <flint/fmpz_factor.h>
EMSCRIPTEN_KEEPALIVE
char *flintell_factor_integer(const char *text)
{
    fmpz_t n;
    fmpz_factor_t fac;
    fmpz_init(n);
    if (fmpz_set_str(n, text, 10) != 0 || fmpz_is_zero(n)) {
        fmpz_clear(n); return NULL;
    }
    fmpz_factor_init(fac);
    fmpz_factor(fac, n);
    size_t cap = 64, len = 0;
    char *out = malloc(cap);
    if (!out) { fmpz_factor_clear(fac); fmpz_clear(n); return NULL; }
    len = snprintf(out, cap, "s %d\n", fac->sign);
    for (slong i = 0; i < fac->num; ++i) {
        char *p = fmpz_get_str(NULL, 10, fac->p + i);
        size_t need = len + strlen(p) + 64;
        if (need > cap) {
            char *next = realloc(out, need);
            if (!next) {
                flint_free(p); free(out); fmpz_factor_clear(fac); fmpz_clear(n); return NULL;
            }
            out = next; cap = need;
        }
        len += snprintf(out + len, cap - len, "%s %lu\n", p, (unsigned long)fac->exp[i]);
        flint_free(p);
    }
    fmpz_factor_clear(fac); fmpz_clear(n);
    return out;
}
EMSCRIPTEN_KEEPALIVE
int flintell_is_prime(const char *text)
{
    fmpz_t n;
    fmpz_init(n);
    int result = fmpz_set_str(n, text, 10) == 0 && fmpz_cmp_ui(n, 2) >= 0 && fmpz_is_prime(n);
    fmpz_clear(n);
    return result;
}

#include <flint/fmpz_mod.h>
#include <flint/fmpz_mod_poly.h>
#include <flint/fmpz_mod_poly_factor.h>
/* Same factor wire format as Z[x], with monic factors and leading coefficient
 * as content. Reject nonprime moduli before entering finite-field algorithms. */
EMSCRIPTEN_KEEPALIVE
char *flintell_factor_mod(const char *prime, const char *poly_str)
{
    if (!flintell_is_prime(prime)) return NULL;
    fmpz_t p;
    fmpz_init(p); fmpz_set_str(p, prime, 10);
    fmpz_mod_ctx_t ctx;
    fmpz_mod_ctx_init(ctx, p);
    fmpz_poly_t input, lifted;
    fmpz_poly_init(input); fmpz_poly_init(lifted);
    fmpz_mod_poly_t poly;
    fmpz_mod_poly_init(poly, ctx);
    fmpz_mod_poly_factor_t fac;
    fmpz_mod_poly_factor_init(fac, ctx);
    char *out = NULL;
    if (fmpz_poly_set_str(input, poly_str) != 0) goto cleanup;
    fmpz_mod_poly_set_fmpz_poly(poly, input, ctx);
    if (fmpz_mod_poly_length(poly, ctx) > 1) fmpz_mod_poly_factor(fac, poly, ctx);
    char *content = fmpz_mod_poly_length(poly, ctx) ?
      fmpz_get_str(NULL, 10, fmpz_mod_poly_lead(poly, ctx)) : NULL;
    size_t cap = (content ? strlen(content) : 1) + 32, len;
    out = malloc(cap);
    if (!out) { if (content) flint_free(content); goto cleanup; }
    len = snprintf(out, cap, "c %s\n", content ? content : "0");
    if (content) flint_free(content);
    for (slong i = 0; i < fac->num; ++i) {
        fmpz_mod_poly_get_fmpz_poly(lifted, fac->poly + i, ctx);
        char *s = fmpz_poly_get_str(lifted);
        size_t need = len + strlen(s) + 64;
        if (need > cap) {
            char *next = realloc(out, need);
            if (!next) { flint_free(s); free(out); out = NULL; goto cleanup; }
            out = next; cap = need;
        }
        len += snprintf(out + len, cap - len, "%ld %s\n", (long)fac->exp[i], s);
        flint_free(s);
    }
cleanup:
    fmpz_mod_poly_factor_clear(fac, ctx);
    fmpz_mod_poly_clear(poly, ctx);
    fmpz_poly_clear(input); fmpz_poly_clear(lifted);
    fmpz_mod_ctx_clear(ctx); fmpz_clear(p);
    return out;
}

#include <flint/fmpq_mpoly.h>
#include <flint/fmpq_mpoly_factor.h>
#include <flint/fmpz_mod_mpoly.h>
#include <flint/fmpz_mod_mpoly_factor.h>
/* Test irreducibility over k(x)[y]. x-only factors are units here.
 * prime="0" selects Q; otherwise prime must be a proven prime.
 * Return -1 on malformed input/factorisation failure, 0 on a reducible or
 * constant-in-y polynomial, and 1 on exactly one simple y-dependent factor.
 */
EMSCRIPTEN_KEEPALIVE
int flintell_curve_irreducible(const char *prime, const char *text)
{
    const char *vars[2] = {"x", "y"};
    int answer = -1;
    if (strcmp(prime, "0") == 0) {
        fmpq_mpoly_ctx_t ctx;
        fmpq_mpoly_ctx_init(ctx, 2, ORD_LEX);
        fmpq_mpoly_t a, b;
        fmpq_mpoly_init(a, ctx); fmpq_mpoly_init(b, ctx);
        fmpq_mpoly_factor_t fac;
        fmpq_mpoly_factor_init(fac, ctx);
        if (fmpq_mpoly_set_str_pretty(a, text, vars, ctx) != 0) goto qcleanup;
        if (fmpq_mpoly_degree_si(a, 1, ctx) <= 0) { answer = 0; goto qcleanup; }
        if (!fmpq_mpoly_factor(fac, a, ctx)) goto qcleanup;
        slong count = 0;
        answer = 1;
        for (slong i = 0; i < fmpq_mpoly_factor_length(fac, ctx); ++i) {
            fmpq_mpoly_factor_get_base(b, fac, i, ctx);
            if (fmpq_mpoly_degree_si(b, 1, ctx) > 0) {
                ++count;
                if (fmpq_mpoly_factor_get_exp_si(fac, i, ctx) != 1) answer = 0;
            }
        }
        if (count != 1) answer = 0;
qcleanup:
        fmpq_mpoly_factor_clear(fac, ctx);
        fmpq_mpoly_clear(a, ctx); fmpq_mpoly_clear(b, ctx);
        fmpq_mpoly_ctx_clear(ctx);
    } else {
        if (!flintell_is_prime(prime)) return -1;
        fmpz_t p;
        fmpz_init(p); fmpz_set_str(p, prime, 10);
        fmpz_mod_mpoly_ctx_t ctx;
        fmpz_mod_mpoly_ctx_init(ctx, 2, ORD_LEX, p);
        fmpz_mod_mpoly_t a, b;
        fmpz_mod_mpoly_init(a, ctx); fmpz_mod_mpoly_init(b, ctx);
        fmpz_mod_mpoly_factor_t fac;
        fmpz_mod_mpoly_factor_init(fac, ctx);
        if (fmpz_mod_mpoly_set_str_pretty(a, text, vars, ctx) != 0) goto pcleanup;
        if (fmpz_mod_mpoly_degree_si(a, 1, ctx) <= 0) { answer = 0; goto pcleanup; }
        if (!fmpz_mod_mpoly_factor(fac, a, ctx)) goto pcleanup;
        slong count = 0;
        answer = 1;
        for (slong i = 0; i < fmpz_mod_mpoly_factor_length(fac, ctx); ++i) {
            fmpz_mod_mpoly_factor_get_base(b, fac, i, ctx);
            if (fmpz_mod_mpoly_degree_si(b, 1, ctx) > 0) {
                ++count;
                if (fmpz_mod_mpoly_factor_get_exp_si(fac, i, ctx) != 1) answer = 0;
            }
        }
        if (count != 1) answer = 0;
pcleanup:
        fmpz_mod_mpoly_factor_clear(fac, ctx);
        fmpz_mod_mpoly_clear(a, ctx); fmpz_mod_mpoly_clear(b, ctx);
        fmpz_mod_mpoly_ctx_clear(ctx); fmpz_clear(p);
    }
    return answer;
}

/* Cancel a common polynomial/content factor in an exact rational function.
 * Both arrays have the same cleared coefficient denominator. */
EMSCRIPTEN_KEEPALIVE
char *flintell_cancel(const char *numerator_str, const char *denominator_str)
{
    fmpz_poly_t a, b, g, na, db;
    char *ns = NULL, *ds = NULL, *out = NULL;
    fmpz_poly_init(a); fmpz_poly_init(b); fmpz_poly_init(g);
    fmpz_poly_init(na); fmpz_poly_init(db);
    if (fmpz_poly_set_str(a, numerator_str) != 0 ||
        fmpz_poly_set_str(b, denominator_str) != 0 || fmpz_poly_is_zero(b)) goto done;
    fmpz_poly_gcd(g, a, b);
    fmpz_poly_divexact(na, a, g); fmpz_poly_divexact(db, b, g);
    ns = fmpz_poly_get_str(na); ds = fmpz_poly_get_str(db);
    out = malloc(strlen(ns) + strlen(ds) + 3);
    if (out) sprintf(out, "%s\n%s\n", ns, ds);
done:
    if (ns) flint_free(ns);
    if (ds) flint_free(ds);
    fmpz_poly_clear(a); fmpz_poly_clear(b); fmpz_poly_clear(g);
    fmpz_poly_clear(na); fmpz_poly_clear(db);
    return out;
}
