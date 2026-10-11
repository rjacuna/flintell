-- FunDom — fundamental domains of congruence subgroups of SL₂(ℤ).
-- Copyright (C) 2026 RJ Acuña. Mode 1 derives from Helena A. Verrill's
-- FunDomain (Copyright (C) 2001, GPL-2.0-or-later); see java/ and README.md.
-- SPDX-License-Identifier: GPL-3.0-or-later
-- | Elements of PSL₂(ℤ), as FLINT @psl2z_t@.
--
-- The Java original carried 2×2 @int@ matrices and tested equality "as
-- fractional linear transformations" by comparing against both signs. FLINT
-- has a type for exactly this: @psl2z_t@ holds a matrix in a normal form
-- (@c > 0@, or @c = 0@ and @d > 0@), so projective equality is plain
-- equality. The constructor is not exported; every 'SL2' in the program is
-- in that form with determinant one, because it was made by FLINT.
module Flint.SL2
  ( SL2, a, b, c, d, entries, showMat
  , sl2, sl2', identity, genT, genTinv, genS, genR
  , mul, inv, act, cusp
  , withSL2, peekSL2
  ) where

import Data.Ratio (numerator, denominator)
import Flint.FFI
import Flint.Z
import Foreign.C.Types (CInt)
import Foreign.Ptr (Ptr)
import System.IO.Unsafe (unsafePerformIO)

data SL2 = SL2 { a :: !Integer, b :: !Integer, c :: !Integer, d :: !Integer }
  deriving (Eq, Ord)

instance Show SL2 where
  show = showMat

showMat :: SL2 -> String
showMat (SL2 p q r s) = "[" ++ show p ++ " " ++ show q ++ "; " ++ show r ++ " " ++ show s ++ "]"

entries :: SL2 -> (Integer, Integer, Integer, Integer)
entries (SL2 p q r s) = (p, q, r, s)

-- | Load a matrix into a fresh @psl2z_t@ for the duration of an action.
withSL2 :: SL2 -> (Ptr CPSL2Z -> IO r) -> IO r
withSL2 (SL2 p q r s) f = withPSL2Z $ \g -> do
  mapM_ (\(k, x) -> psl2z_entry g k >>= (`pokeZ` x)) (zip [0 ..] [p, q, r, s])
  f g

peekSL2 :: Ptr CPSL2Z -> IO SL2
peekSL2 g = do
  [p, q, r, s] <- mapM (\k -> psl2z_entry g k >>= peekZ) [0 .. 3 :: CInt]
  return (SL2 p q r s)

-- | The only way in: normalise the sign, then accept iff @psl2z_is_correct@.
sl2 :: Integer -> Integer -> Integer -> Integer -> Maybe SL2
sl2 p q r s = unsafePerformIO $ withSL2 (SL2 p q r s) $ \g -> do
  psl2z_normal_form g
  ok <- psl2z_is_correct g
  if ok /= (0 :: CInt) then Just <$> peekSL2 g else return Nothing

sl2' :: Integer -> Integer -> Integer -> Integer -> SL2
sl2' p q r s = case sl2 p q r s of
  Just m  -> m
  Nothing -> error ("sl2': determinant is not 1 in " ++ showMat (SL2 p q r s))

identity, genT, genTinv, genS, genR :: SL2
identity = sl2' 1 0 0 1
genT     = sl2' 1 1 0 1
genTinv  = sl2' 1 (-1) 0 1
genS     = sl2' 0 (-1) 1 0
genR     = sl2' 0 (-1) 1 1    -- = S·T, of order three

mul :: SL2 -> SL2 -> SL2
mul x y = unsafePerformIO $
  withSL2 x $ \px -> withSL2 y $ \py -> withPSL2Z $ \ph -> do
    psl2z_mul ph px py
    psl2z_normal_form ph
    peekSL2 ph

inv :: SL2 -> SL2
inv x = unsafePerformIO $ withSL2 x $ \px -> withPSL2Z $ \ph -> do
  psl2z_inv ph px
  psl2z_normal_form ph
  peekSL2 ph

-- | The action on P¹(ℚ): @z ↦ (az + b)/(cz + d)@. The fraction is reduced by
-- @fmpq_set_fmpz_frac@, so cusps come back in lowest terms with a positive
-- denominator.
act :: SL2 -> QI -> QI
act (SL2 p q r s) z = unsafePerformIO $ case z of
  Inf   -> frac p r
  Fin x -> let n = numerator x; m = denominator x
           in frac (p * n + q * m) (r * n + s * m)
  where
    frac num den
      | den == 0  = return Inf
      | otherwise = withZ num $ \pn -> withZ den $ \pd -> withFmpq $ \f -> do
          fmpq_set_fmpz_frac f pn pd
          Fin <$> peekQ f

-- | The cusp of the triangle @g·F@, i.e. @g(∞) = a/c@.
cusp :: SL2 -> QI
cusp g = act g Inf
