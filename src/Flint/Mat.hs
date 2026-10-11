{-# LANGUAGE ForeignFunctionInterface #-}
-- FunDom — fundamental domains of congruence subgroups of SL₂(ℤ).
-- Copyright (C) 2026 RJ Acuña. Mode 1 derives from Helena A. Verrill's
-- FunDomain (Copyright (C) 2001, GPL-2.0-or-later); see java/ and README.md.
-- SPDX-License-Identifier: GPL-3.0-or-later
-- | Integer and rational matrices on FLINT's @fmpz_mat@ / @fmpq_mat@, typed
-- correctly for FLINT 3.
--
-- The Hackage @Flint2@ binding peeks @fmpz_mat_struct@ directly and was
-- written for FLINT 2, whose fourth field was a row-pointer array; FLINT 3
-- made it a @stride@. This module does not read the struct at all: the
-- matrix is an opaque pointer, allocated and indexed by FLINT's own
-- accessors (see @cbits/flintell_shims.c@), so it is right for FLINT 3 and
-- stays right if the layout moves again.
--
-- All functions are pure: a matrix is copied in, the operation runs, the
-- result is copied out and the C object freed.
module Flint.Mat
  ( ZMat, zmat, zrows, zcols, zlist
  , zmul, zdet, zinv, zsolve, zrref, znullspace
  , QMat, qmat, qrows, qcols, qlist
  , qmul, qdet, qinv, qsolve, qrref
  , fromSL2, toSL2
  ) where

import Control.Exception (bracket)
import Flint.FFI (CFmpz, CFmpq, withFmpz, withFmpq)
import Flint.SL2 (SL2, entries, sl2)
import Flint.Z
import Foreign.C.Types (CInt(..), CLong(..))
import Foreign.Ptr (Ptr)
import System.IO.Unsafe (unsafePerformIO)

data CZMat
data CQMat

foreign import ccall unsafe "flintell_shims.h flintell_fmpz_mat_new"   c_zNew   :: CLong -> CLong -> IO (Ptr CZMat)
foreign import ccall unsafe "flintell_shims.h flintell_fmpz_mat_free"  c_zFree  :: Ptr CZMat -> IO ()
foreign import ccall unsafe "flintell_shims.h flintell_fmpz_mat_entry" c_zEntry :: Ptr CZMat -> CLong -> CLong -> IO (Ptr CFmpz)
foreign import ccall unsafe "flint/fmpz_mat.h fmpz_mat_mul"        c_zMul   :: Ptr CZMat -> Ptr CZMat -> Ptr CZMat -> IO ()
foreign import ccall unsafe "flint/fmpz_mat.h fmpz_mat_det"        c_zDet   :: Ptr CFmpz -> Ptr CZMat -> IO ()
foreign import ccall unsafe "flint/fmpz_mat.h fmpz_mat_inv"        c_zInv   :: Ptr CZMat -> Ptr CFmpz -> Ptr CZMat -> IO CInt
foreign import ccall unsafe "flint/fmpz_mat.h fmpz_mat_solve"      c_zSolve :: Ptr CZMat -> Ptr CFmpz -> Ptr CZMat -> Ptr CZMat -> IO CInt
foreign import ccall unsafe "flint/fmpz_mat.h fmpz_mat_rref"       c_zRref  :: Ptr CZMat -> Ptr CFmpz -> Ptr CZMat -> IO CLong
foreign import ccall unsafe "flint/fmpz_mat.h fmpz_mat_nullspace"  c_zNull  :: Ptr CZMat -> Ptr CZMat -> IO CLong

foreign import ccall unsafe "flintell_shims.h flintell_fmpq_mat_new"   c_qNew   :: CLong -> CLong -> IO (Ptr CQMat)
foreign import ccall unsafe "flintell_shims.h flintell_fmpq_mat_free"  c_qFree  :: Ptr CQMat -> IO ()
foreign import ccall unsafe "flintell_shims.h flintell_fmpq_mat_entry" c_qEntry :: Ptr CQMat -> CLong -> CLong -> IO (Ptr CFmpq)
foreign import ccall unsafe "flint/fmpq_mat.h fmpq_mat_mul"        c_qMul   :: Ptr CQMat -> Ptr CQMat -> Ptr CQMat -> IO ()
foreign import ccall unsafe "flint/fmpq_mat.h fmpq_mat_det"        c_qDet   :: Ptr CFmpq -> Ptr CQMat -> IO ()
foreign import ccall unsafe "flint/fmpq_mat.h fmpq_mat_inv"        c_qInv   :: Ptr CQMat -> Ptr CQMat -> IO CInt
foreign import ccall unsafe "flint/fmpq_mat.h fmpq_mat_solve"      c_qSolve :: Ptr CQMat -> Ptr CQMat -> Ptr CQMat -> IO CInt
foreign import ccall unsafe "flint/fmpq_mat.h fmpq_mat_rref"       c_qRref  :: Ptr CQMat -> Ptr CQMat -> IO CLong

-- Integer matrices ------------------------------------------------------------

-- | A non-empty rectangular integer matrix, rows outermost.
newtype ZMat = ZMat [[Integer]] deriving (Eq, Show)

zmat :: [[Integer]] -> Maybe ZMat
zmat rows = case rows of
  (r0 : _) | not (any null rows), all ((== length r0) . length) rows -> Just (ZMat rows)
  _ -> Nothing

zrows, zcols :: ZMat -> Int
zrows (ZMat r) = length r
zcols (ZMat r) = case r of { (r0 : _) -> length r0; [] -> 0 }

zlist :: ZMat -> [[Integer]]
zlist (ZMat r) = r

withZNew :: Int -> Int -> (Ptr CZMat -> IO a) -> IO a
withZNew r c = bracket (c_zNew (fromIntegral r) (fromIntegral c)) c_zFree

withZMat :: ZMat -> (Ptr CZMat -> IO a) -> IO a
withZMat m@(ZMat rows) f = withZNew (zrows m) (zcols m) $ \p -> do
  sequence_ [ c_zEntry p (fromIntegral i) (fromIntegral j) >>= (`pokeZ` x)
            | (i, row) <- zip [0 :: Int ..] rows, (j, x) <- zip [0 :: Int ..] row ]
  f p

readZ :: Int -> Int -> Ptr CZMat -> IO ZMat
readZ r c p = ZMat <$> mapM (\i -> mapM (\j -> c_zEntry p (fromIntegral i) (fromIntegral j) >>= peekZ) [0 .. c - 1]) [0 .. r - 1]

zmul :: ZMat -> ZMat -> Maybe ZMat
zmul x y
  | zcols x /= zrows y = Nothing
  | otherwise = Just $ unsafePerformIO $ withZMat x $ \px -> withZMat y $ \py ->
      withZNew (zrows x) (zcols y) $ \pz -> c_zMul pz px py >> readZ (zrows x) (zcols y) pz

zdet :: ZMat -> Maybe Integer
zdet x
  | zrows x /= zcols x = Nothing
  | otherwise = Just $ unsafePerformIO $ withZMat x $ \px -> withFmpz (\pd -> c_zDet pd px >> peekZ pd)

-- | @A⁻¹ = M / den@ with integral @M@; 'Nothing' if singular.
zinv :: ZMat -> Maybe (ZMat, Integer)
zinv x
  | zrows x /= zcols x = Nothing
  | otherwise = unsafePerformIO $ withZMat x $ \px -> withZNew n n $ \pm -> withFmpz (\pd -> do
      ok <- c_zInv pm pd px
      if ok == 0 then return Nothing else do
        m <- readZ n n pm
        den <- peekZ pd
        return (Just (m, den)))
  where n = zrows x

-- | Solve @A X = B@ for square nonsingular @A@: @X = M / den@.
zsolve :: ZMat -> ZMat -> Maybe (ZMat, Integer)
zsolve x y
  | zrows x /= zcols x || zrows y /= zrows x = Nothing
  | otherwise = unsafePerformIO $ withZMat x $ \px -> withZMat y $ \py -> withZNew n k $ \pm -> withFmpz (\pd -> do
      ok <- c_zSolve pm pd px py
      if ok == 0 then return Nothing else do
        m <- readZ n k pm
        den <- peekZ pd
        return (Just (m, den)))
  where n = zrows x
        k = zcols y

-- | Fraction-free reduced row echelon form: @(R, den, rank)@ with @R / den@ the rref.
zrref :: ZMat -> (ZMat, Integer, Int)
zrref x = unsafePerformIO $ withZMat x $ \px -> withZNew r c $ \pr -> withFmpz (\pd -> do
    rank <- c_zRref pr pd px
    m <- readZ r c pr
    den <- peekZ pd
    return (m, den, fromIntegral rank))
  where r = zrows x
        c = zcols x

-- | An integral basis of the right kernel, one vector per list element.
znullspace :: ZMat -> [[Integer]]
znullspace x = unsafePerformIO $ withZMat x $ \px -> withZNew c c $ \pb -> do
    k <- c_zNull pb px
    ZMat cols <- readZ c c pb
    -- FLINT stores the basis in the first k columns
    return [ [ row !! j | row <- cols ] | j <- [0 .. fromIntegral k - 1] ]
  where c = zcols x

-- Rational matrices -----------------------------------------------------------

newtype QMat = QMat [[Rational]] deriving (Eq, Show)

qmat :: [[Rational]] -> Maybe QMat
qmat rows = case rows of
  (r0 : _) | not (any null rows), all ((== length r0) . length) rows -> Just (QMat rows)
  _ -> Nothing

qrows, qcols :: QMat -> Int
qrows (QMat r) = length r
qcols (QMat r) = case r of { (r0 : _) -> length r0; [] -> 0 }

qlist :: QMat -> [[Rational]]
qlist (QMat r) = r

withQNew :: Int -> Int -> (Ptr CQMat -> IO a) -> IO a
withQNew r c = bracket (c_qNew (fromIntegral r) (fromIntegral c)) c_qFree

withQMat :: QMat -> (Ptr CQMat -> IO a) -> IO a
withQMat m@(QMat rows) f = withQNew (qrows m) (qcols m) $ \p -> do
  sequence_ [ c_qEntry p (fromIntegral i) (fromIntegral j) >>= (`pokeQ` x)
            | (i, row) <- zip [0 :: Int ..] rows, (j, x) <- zip [0 :: Int ..] row ]
  f p

readQ :: Int -> Int -> Ptr CQMat -> IO QMat
readQ r c p = QMat <$> mapM (\i -> mapM (\j -> c_qEntry p (fromIntegral i) (fromIntegral j) >>= peekQ) [0 .. c - 1]) [0 .. r - 1]

qmul :: QMat -> QMat -> Maybe QMat
qmul x y
  | qcols x /= qrows y = Nothing
  | otherwise = Just $ unsafePerformIO $ withQMat x $ \px -> withQMat y $ \py ->
      withQNew (qrows x) (qcols y) $ \pz -> c_qMul pz px py >> readQ (qrows x) (qcols y) pz

qdet :: QMat -> Maybe Rational
qdet x
  | qrows x /= qcols x = Nothing
  | otherwise = Just $ unsafePerformIO $ withQMat x $ \px -> withFmpq (\pd -> c_qDet pd px >> peekQ pd)

qinv :: QMat -> Maybe QMat
qinv x
  | qrows x /= qcols x = Nothing
  | otherwise = unsafePerformIO $ withQMat x $ \px -> withQNew n n $ \pm -> do
      ok <- c_qInv pm px
      if ok == 0 then return Nothing else Just <$> readQ n n pm
  where n = qrows x

qsolve :: QMat -> QMat -> Maybe QMat
qsolve x y
  | qrows x /= qcols x || qrows y /= qrows x = Nothing
  | otherwise = unsafePerformIO $ withQMat x $ \px -> withQMat y $ \py -> withQNew n k $ \pm -> do
      ok <- c_qSolve pm px py
      if ok == 0 then return Nothing else Just <$> readQ n k pm
  where n = qrows x
        k = qcols y

qrref :: QMat -> (QMat, Int)
qrref x = unsafePerformIO $ withQMat x $ \px -> withQNew r c $ \pr -> do
    rank <- c_qRref pr px
    m <- readQ r c pr
    return (m, fromIntegral rank)
  where r = qrows x
        c = qcols x

-- Between the two representations ----------------------------------------------

fromSL2 :: SL2 -> ZMat
fromSL2 g = let (p, q, r, s) = entries g in ZMat [[p, q], [r, s]]

-- | Accepts a 2×2 integer matrix of determinant one, checked by @fmpz_mat_det@.
toSL2 :: ZMat -> Maybe SL2
toSL2 m@(ZMat [[p, q], [r, s]])
  | zdet m == Just 1 = sl2 p q r s
toSL2 _ = Nothing
