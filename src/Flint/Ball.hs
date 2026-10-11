-- FunDom — fundamental domains of congruence subgroups of SL₂(ℤ).
-- Copyright (C) 2026 RJ Acuña. Mode 1 derives from Helena A. Verrill's
-- FunDomain (Copyright (C) 2001, GPL-2.0-or-later); see java/ and README.md.
-- SPDX-License-Identifier: GPL-3.0-or-later
-- | The only place a floating-point number is produced.
--
-- A triangle's vertices are the images of ρ = −½ + i√3⁄2, ρ + 1 and (for the
-- side-pairing markers) i and ±½ + i(1+√2)⁄2 under an element of PSL₂(ℤ).
-- They are computed by @acb_modular_transform@ as complex balls, and the
-- view transform — subtract the centre, multiply by the zoom — is done in
-- @arb@ at a precision chosen from the zoom, so the screen coordinate is
-- accurate to a fraction of a pixel however far in the user has zoomed. The
-- Java original did this in @double@ and stored the polygon in @int@, which
-- is why its zoom stopped at 2·10⁸ and its arcs flattened near the real
-- axis long before that.
module Flint.Ball
  ( Prec, precFor
  , View(..), Screen, axisY
  , Base(..), project, projectX, lengthPx
  , DiskView(..), precForDisk, projectDisk
  ) where

import Data.Ratio (numerator, denominator)
import Flint.FFI
import Flint.SL2
import Flint.Z (withQ)
import Foreign.C.Types (CLong)
import Foreign.Ptr (Ptr)
import System.IO.Unsafe (unsafePerformIO)

type Prec = CLong

-- | The viewport: pixel size, the height of the real axis above the bottom
-- edge, pixels per unit, and the real part at the horizontal centre.
data View = View
  { vW, vH, vY0 :: !Int
  , vScale      :: !Rational
  , vCx         :: !Rational
  } deriving (Show)

type Screen = (Double, Double)

-- | Screen y of the real axis.
axisY :: View -> Double
axisY v = fromIntegral (vH v - vY0 v)

-- | 64 bits, plus the size of the zoom and the centre: enough that the
-- rounding to a double at the very end is the only rounding that happens.
precFor :: View -> Prec
precFor v = fromIntegral (80 + bits (vScale v) + bits (vCx v))
  where
    bits r  = ilog (abs (numerator r)) + ilog (denominator r)
    ilog n  = length (takeWhile (> 0) (iterate (`div` 2) n))

-- | Points of the standard triangle, and of its sides, that get transported.
data Base
  = Rho    -- ^ −½ + i√3⁄2, the left elliptic vertex
  | Rho1   -- ^  ½ + i√3⁄2, the right one
  | PtI    -- ^ i, the midpoint of the bottom (S) side
  | EdgeL  -- ^ −½ + i(1+√2)⁄2, a point on the left (T⁻¹) side
  | EdgeR  -- ^  ½ + i(1+√2)⁄2, a point on the right (T) side
  deriving (Eq, Show)

basePt :: Prec -> Base -> Ptr CAcb -> IO ()
basePt p base z = withArb $ \re -> withArb $ \im -> do
    case base of
      Rho   -> half re (-1) >> sqrtHalf im 3
      Rho1  -> half re 1    >> sqrtHalf im 3
      PtI   -> arb_set_si re 0 >> arb_set_si im 1
      EdgeL -> half re (-1) >> edgeIm im
      EdgeR -> half re 1    >> edgeIm im
    acb_set_arb_arb z re im
  where
    half r k     = arb_set_si r k >> arb_mul_2exp_si r r (-1)
    sqrtHalf r n = arb_sqrt_ui r n p >> arb_mul_2exp_si r r (-1)
    edgeIm r     = arb_sqrt_ui r 2 p >> arb_add_si r r 1 p >> arb_mul_2exp_si r r (-1)

mid :: Ptr CArb -> IO Double
mid r = do
  m <- arb_midref r
  realToFrac <$> arf_get_d m arfRndNear

-- | (re − cx)·scale and im·scale in arb; only then to double.
toScreen :: Prec -> View -> Ptr CAcb -> IO Screen
toScreen p v w = withArb $ \re -> withArb $ \im -> withArb $ \sc -> withArb $ \cx -> do
    acb_get_real re w
    acb_get_imag im w
    withQ (vScale v) $ \q -> arb_set_fmpq sc q p
    withQ (vCx v)    $ \q -> arb_set_fmpq cx q p
    arb_sub re re cx p
    arb_mul re re sc p
    arb_mul im im sc p
    x <- mid re
    y <- mid im
    return (fromIntegral (vW v) / 2 + x, axisY v - y)

-- | Screen positions of the transported base points, one @acb_modular_transform@ each.
project :: Prec -> View -> SL2 -> [Base] -> [Screen]
project p v g bases = unsafePerformIO $ withSL2 g $ \pg ->
  mapM (\bs -> withAcb $ \z -> withAcb $ \w -> do
      basePt p bs z
      acb_modular_transform w pg z p
      toScreen p v w) bases

-- | Screen x of an exact rational abscissa. Exact until the final rounding.
projectX :: View -> Rational -> Double
projectX v x = fromIntegral (vW v) / 2 + fromRational ((x - vCx v) * vScale v)

-- | A length in the plane, in pixels.
lengthPx :: View -> Rational -> Double
lengthPx v r = fromRational (r * vScale v)

-- The disk ----------------------------------------------------------------------

-- | The unit disk on the screen: centre and radius in pixels.
data DiskView = DiskView { dvCx, dvCy, dvR :: !Double } deriving (Show)

precForDisk :: DiskView -> Prec
precForDisk _ = 96

-- | The Cayley transform @w ↦ (w − i)/(w + i)@ of the transported base
-- points, in @acb@, then to the screen.
projectDisk :: Prec -> DiskView -> SL2 -> [Base] -> [Screen]
projectDisk p dv g bases = unsafePerformIO $ withSL2 g $ \pg -> mapM (one pg) bases
  where
    one pg bs = withAcb $ \z -> withAcb $ \w -> withAcb $ \i -> withAcb $ \num -> withAcb $ \den -> do
        basePt p bs z
        acb_modular_transform w pg z p
        acb_onei i
        acb_sub num w i p
        acb_add den w i p
        acb_div num num den p
        (x, y) <- reIm num
        return (dvCx dv + dvR dv * x, dvCy dv - dvR dv * y)
    reIm w = withArb $ \re -> withArb $ \im -> do
        acb_get_real re w
        acb_get_imag im w
        x <- mid re
        y <- mid im
        return (x, y)
