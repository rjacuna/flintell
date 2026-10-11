{-# LANGUAGE ForeignFunctionInterface #-}
-- FunDom — fundamental domains of congruence subgroups of SL₂(ℤ).
-- Copyright (C) 2026 RJ Acuña. Mode 1 derives from Helena A. Verrill's
-- FunDomain (Copyright (C) 2001, GPL-2.0-or-later); see java/ and README.md.
-- SPDX-License-Identifier: GPL-3.0-or-later
-- | The FLINT binding this program uses — all of it.
--
-- Opaque pointers, allocation through the C shims in @cbits/@, and plain
-- @ccall@s to documented FLINT functions. No struct is ever peeked from
-- Haskell: sizes come from @sizeof@ in C and fields from FLINT's own
-- accessors, so the binding is right for FLINT 3 and stays right if a
-- layout moves — and, having no @hsc2hs@ step and no Template Haskell, it
-- cross-compiles to @wasm32-wasi@ with the same source.
--
-- Every object is scoped: @withFmpz@ and friends allocate, run, and free.
-- The pure wrappers in "Flint.SL2", "Flint.Ball" and "Flint.Mat" build on
-- these with @unsafePerformIO@, which is sound because nothing escapes.
module Flint.FFI
  ( CFmpz, CFmpq, CArb, CAcb, CArf, CPSL2Z
  , withFmpz, withFmpq, withArb, withAcb, withPSL2Z
  , fmpz_fits_si, fmpz_get_si, fmpz_set_si, fmpz_get_str, fmpz_set_str, flint_free
  , fmpq_get_str, fmpq_set_str, fmpq_set_fmpz_frac
  , psl2z_mul, psl2z_inv, psl2z_is_correct, psl2z_entry, psl2z_normal_form
  , arb_set_si, arb_sqrt_ui, arb_mul_2exp_si, arb_add_si, arb_set_fmpq, arb_sub, arb_mul
  , arb_midref, arf_get_d, arfRndNear
  , acb_set_arb_arb, acb_get_real, acb_get_imag, acb_onei, acb_add, acb_sub, acb_div
  , acb_modular_transform
  , n_gcd
  ) where

import Control.Exception (bracket)
import Foreign.C.String (CString)
import Foreign.C.Types
import Foreign.Ptr (Ptr)
import System.IO.Unsafe (unsafePerformIO)

data CFmpz
data CFmpq
data CArb
data CAcb
data CArf
data CPSL2Z

-- Allocation ---------------------------------------------------------------------

foreign import ccall unsafe "flintell_shims.h flintell_fmpz_new"   c_fmpz_new   :: IO (Ptr CFmpz)
foreign import ccall unsafe "flintell_shims.h flintell_fmpz_free"  c_fmpz_free  :: Ptr CFmpz -> IO ()
foreign import ccall unsafe "flintell_shims.h flintell_fmpq_new"   c_fmpq_new   :: IO (Ptr CFmpq)
foreign import ccall unsafe "flintell_shims.h flintell_fmpq_free"  c_fmpq_free  :: Ptr CFmpq -> IO ()
foreign import ccall unsafe "flintell_shims.h flintell_arb_new"    c_arb_new    :: IO (Ptr CArb)
foreign import ccall unsafe "flintell_shims.h flintell_arb_free"   c_arb_free   :: Ptr CArb -> IO ()
foreign import ccall unsafe "flintell_shims.h flintell_acb_new"    c_acb_new    :: IO (Ptr CAcb)
foreign import ccall unsafe "flintell_shims.h flintell_acb_free"   c_acb_free   :: Ptr CAcb -> IO ()
foreign import ccall unsafe "flintell_shims.h flintell_psl2z_new"  c_psl2z_new  :: IO (Ptr CPSL2Z)
foreign import ccall unsafe "flintell_shims.h flintell_psl2z_free" c_psl2z_free :: Ptr CPSL2Z -> IO ()

withFmpz :: (Ptr CFmpz -> IO a) -> IO a
withFmpz = bracket c_fmpz_new c_fmpz_free

withFmpq :: (Ptr CFmpq -> IO a) -> IO a
withFmpq = bracket c_fmpq_new c_fmpq_free

withArb :: (Ptr CArb -> IO a) -> IO a
withArb = bracket c_arb_new c_arb_free

withAcb :: (Ptr CAcb -> IO a) -> IO a
withAcb = bracket c_acb_new c_acb_free

withPSL2Z :: (Ptr CPSL2Z -> IO a) -> IO a
withPSL2Z = bracket c_psl2z_new c_psl2z_free

-- Integers and rationals ------------------------------------------------------------

foreign import ccall unsafe "flint/fmpz.h fmpz_fits_si"  fmpz_fits_si :: Ptr CFmpz -> IO CInt
foreign import ccall unsafe "flint/fmpz.h fmpz_get_si"   fmpz_get_si  :: Ptr CFmpz -> IO CLong
foreign import ccall unsafe "flint/fmpz.h fmpz_set_si"   fmpz_set_si  :: Ptr CFmpz -> CLong -> IO ()
foreign import ccall unsafe "flint/fmpz.h fmpz_get_str"  fmpz_get_str :: CString -> CInt -> Ptr CFmpz -> IO CString
foreign import ccall unsafe "flint/fmpz.h fmpz_set_str"  fmpz_set_str :: Ptr CFmpz -> CString -> CInt -> IO CInt
foreign import ccall unsafe "flint/flint.h flint_free"   flint_free   :: Ptr a -> IO ()

foreign import ccall unsafe "flint/fmpq.h fmpq_get_str"       fmpq_get_str       :: CString -> CInt -> Ptr CFmpq -> IO CString
foreign import ccall unsafe "flint/fmpq.h fmpq_set_str"       fmpq_set_str       :: Ptr CFmpq -> CString -> CInt -> IO CInt
foreign import ccall unsafe "flint/fmpq.h fmpq_set_fmpz_frac" fmpq_set_fmpz_frac :: Ptr CFmpq -> Ptr CFmpz -> Ptr CFmpz -> IO ()

-- PSL₂(ℤ) ---------------------------------------------------------------------------

foreign import ccall unsafe "flint/acb_modular.h psl2z_mul"        psl2z_mul        :: Ptr CPSL2Z -> Ptr CPSL2Z -> Ptr CPSL2Z -> IO ()
foreign import ccall unsafe "flint/acb_modular.h psl2z_inv"        psl2z_inv        :: Ptr CPSL2Z -> Ptr CPSL2Z -> IO ()
foreign import ccall unsafe "flint/acb_modular.h psl2z_is_correct" psl2z_is_correct :: Ptr CPSL2Z -> IO CInt
foreign import ccall unsafe "flintell_shims.h flintell_psl2z_entry"    psl2z_entry      :: Ptr CPSL2Z -> CInt -> IO (Ptr CFmpz)
foreign import ccall unsafe "flintell_shims.h flintell_psl2z_normal_form" psl2z_normal_form :: Ptr CPSL2Z -> IO ()

-- Balls -------------------------------------------------------------------------------

foreign import ccall unsafe "flint/arb.h arb_set_si"      arb_set_si      :: Ptr CArb -> CLong -> IO ()
foreign import ccall unsafe "flint/arb.h arb_sqrt_ui"     arb_sqrt_ui     :: Ptr CArb -> CULong -> CLong -> IO ()
foreign import ccall unsafe "flint/arb.h arb_mul_2exp_si" arb_mul_2exp_si :: Ptr CArb -> Ptr CArb -> CLong -> IO ()
foreign import ccall unsafe "flint/arb.h arb_add_si"      arb_add_si      :: Ptr CArb -> Ptr CArb -> CLong -> CLong -> IO ()
foreign import ccall unsafe "flint/arb.h arb_set_fmpq"    arb_set_fmpq    :: Ptr CArb -> Ptr CFmpq -> CLong -> IO ()
foreign import ccall unsafe "flint/arb.h arb_sub"         arb_sub         :: Ptr CArb -> Ptr CArb -> Ptr CArb -> CLong -> IO ()
foreign import ccall unsafe "flint/arb.h arb_mul"         arb_mul         :: Ptr CArb -> Ptr CArb -> Ptr CArb -> CLong -> IO ()
foreign import ccall unsafe "flintell_shims.h flintell_arb_midref" arb_midref :: Ptr CArb -> IO (Ptr CArf)
foreign import ccall unsafe "flint/arf.h arf_get_d"       arf_get_d       :: Ptr CArf -> CInt -> IO CDouble
foreign import ccall unsafe "flintell_shims.h flintell_arf_rnd_near" c_arf_rnd_near :: IO CInt

-- | ARF_RND_NEAR, read from the header rather than assumed.
arfRndNear :: CInt
arfRndNear = unsafePerformIO c_arf_rnd_near
{-# NOINLINE arfRndNear #-}

foreign import ccall unsafe "flint/acb.h acb_set_arb_arb" acb_set_arb_arb :: Ptr CAcb -> Ptr CArb -> Ptr CArb -> IO ()
foreign import ccall unsafe "flint/acb.h acb_get_real"    acb_get_real    :: Ptr CArb -> Ptr CAcb -> IO ()
foreign import ccall unsafe "flint/acb.h acb_get_imag"    acb_get_imag    :: Ptr CArb -> Ptr CAcb -> IO ()
foreign import ccall unsafe "flint/acb.h acb_onei"        acb_onei        :: Ptr CAcb -> IO ()
foreign import ccall unsafe "flint/acb.h acb_add"         acb_add         :: Ptr CAcb -> Ptr CAcb -> Ptr CAcb -> CLong -> IO ()
foreign import ccall unsafe "flint/acb.h acb_sub"         acb_sub         :: Ptr CAcb -> Ptr CAcb -> Ptr CAcb -> CLong -> IO ()
foreign import ccall unsafe "flint/acb.h acb_div"         acb_div         :: Ptr CAcb -> Ptr CAcb -> Ptr CAcb -> CLong -> IO ()
foreign import ccall unsafe "flint/acb_modular.h acb_modular_transform" acb_modular_transform :: Ptr CAcb -> Ptr CPSL2Z -> Ptr CAcb -> CLong -> IO ()

-- Word-sized arithmetic --------------------------------------------------------------------

foreign import ccall unsafe "flint/ulong_extras.h n_gcd" n_gcd :: CULong -> CULong -> IO CULong
