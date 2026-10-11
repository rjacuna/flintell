-- FunDom — fundamental domains of congruence subgroups of SL₂(ℤ).
-- Copyright (C) 2026 RJ Acuña. Mode 1 derives from Helena A. Verrill's
-- FunDomain (Copyright (C) 2001, GPL-2.0-or-later); see java/ and README.md.
-- SPDX-License-Identifier: GPL-3.0-or-later
-- | Marshalling between Haskell's exact 'Integer' / 'Rational' and FLINT's
-- @fmpz_t@ / @fmpq_t@.
--
-- Every FLINT computation in this project starts and ends here: values live
-- in Haskell as immutable exact numbers and visit the C heap only for the
-- duration of one operation. Nothing crosses as a floating-point number
-- until the final projection to screen pixels in "Flint.Ball".
module Flint.Z
  ( QI(..), showQI, finite
  , peekZ, pokeZ, withZ
  , peekQ, pokeQ, withQ
  ) where

import Data.Ratio ((%), numerator, denominator)
import Flint.FFI
import Foreign.C.String (peekCString, withCString)
import Foreign.C.Types (CLong)
import Foreign.Ptr (Ptr, nullPtr)

-- | A point of P¹(ℚ): a rational number or ∞. Cusps and the ideal endpoints
-- of geodesics live here.
data QI = Inf | Fin !Rational
  deriving (Eq, Ord, Show)

showQI :: QI -> String
showQI Inf = "∞"
showQI (Fin r)
  | denominator r == 1 = show (numerator r)
  | otherwise          = show (numerator r) ++ "/" ++ show (denominator r)

finite :: QI -> Maybe Rational
finite Inf     = Nothing
finite (Fin r) = Just r

peekZ :: Ptr CFmpz -> IO Integer
peekZ p = do
  fits <- fmpz_fits_si p
  if fits /= 0
    then fromIntegral <$> fmpz_get_si p
    else do
      cs <- fmpz_get_str nullPtr 10 p
      s  <- peekCString cs
      flint_free cs
      return (read s)

pokeZ :: Ptr CFmpz -> Integer -> IO ()
pokeZ p n
  | n >= fromIntegral (minBound :: CLong) && n <= fromIntegral (maxBound :: CLong)
              = fmpz_set_si p (fromIntegral n)
  | otherwise = withCString (show n) $ \cs -> fmpz_set_str p cs 10 >> return ()

withZ :: Integer -> (Ptr CFmpz -> IO a) -> IO a
withZ n f = withFmpz (\p -> pokeZ p n >> f p)

peekQ :: Ptr CFmpq -> IO Rational
peekQ p = do
  cs <- fmpq_get_str nullPtr 10 p
  s  <- peekCString cs
  flint_free cs
  return $ case break (== '/') s of
    (n, [])    -> read n % 1
    (n, _ : d) -> read n % read d

pokeQ :: Ptr CFmpq -> Rational -> IO ()
pokeQ p r = withCString (show (numerator r) ++ "/" ++ show (denominator r)) $ \cs ->
  fmpq_set_str p cs 10 >> return ()

withQ :: Rational -> (Ptr CFmpq -> IO a) -> IO a
withQ r f = withFmpq (\p -> pokeQ p r >> f p)
