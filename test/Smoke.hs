module Main where
import Control.Exception (bracket_)
import Foreign.Marshal.Alloc (alloca)
import qualified Data.Number.Flint.Fmpz as OldZ
import qualified Data.Number.Flint.NMod as OldN
import qualified Data.Number.Flint.NMod.Mat as OldNMat
import qualified Data.Number.Flint.NMod.Poly.Mat as OldNP
import Control.Monad (unless, forM_)
import Data.List (sort)
import Data.Ratio ((%))
import qualified Flint.Integer as FI
import Flint.Poly
import Flint.Mat
import Flint.SL2
import Flint.Z
import qualified Data.Number.Flint.Fmpz.Poly as Old
import qualified Data.Number.Flint.Fmpz.Poly.Factor as Old
import qualified Data.Number.Flint.Fmpz.Mat as OldMat
import Foreign.C.String
import Foreign.Storable
import Foreign.Marshal.Array (advancePtr)
import Flint.FFI (flint_free)

assert :: String -> Bool -> IO ()
assert msg ok = unless ok (error msg)
normalise :: [Integer] -> [Integer]
normalise = reverse . dropWhile (==0) . reverse
mulP :: [Integer] -> [Integer] -> [Integer]
mulP a b = normalise [sum [a!!i * b!!(k-i) | i <- [0..length a-1], k-i>=0, k-i<length b] | k <- [0..length a+length b-2]]
reconstruct :: Factorisation -> [Integer]
reconstruct (Factorisation c fs) = normalise $ map (*c) $ foldl mulP [1] [p | (p,e) <- fs, _ <- [1..e]]
legacy :: [Integer] -> IO [[Integer]]
legacy cs = fmap snd $ Old.withNewFmpzPoly $ \p -> do
  _ <- withCString (show (length cs) ++ "  " ++ unwords (map show cs)) (Old.fmpz_poly_set_str p)
  fmap snd $ Old.withNewFmpzPolyFactor $ \fac -> do
    Old.fmpz_poly_factor fac p
    Old.CFmpzPolyFactor _ arr _ n _ <- peek fac
    mapM (\i -> do
      ptr <- Old.fmpz_poly_get_str (arr `advancePtr` i)
      str <- peekCString ptr
      flint_free ptr
      pure (map read (drop 1 (words str)))) [0 .. fromIntegral n - 1]
main :: IO ()
main = do
  forM_ [([], [1]), ([0,0], [-2,2]), ([6,-12,6],[-9,0,9]),
         ([10^80,2*10^80,10^80],[10^40,10^40]), ([1,2,0],[3,0])] $ \(n,d)->do
    (a,b)<-cancel n d
    assert "exact rational-function cancellation" (not(null b) && mulP a d==mulP n b)
  reduced<-cancel [6,-12,6] [-9,0,9]
  assert "common polynomial and content removed" (reduced==([-2,2],[3,3]))

  forM_ [-360,-1,1,2^127-1,2^200*3^25] $ \n -> do
    fs <- FI.factorInteger n
    assert "integer factor reconstruction" (product [p^e | (p,e)<-fs] == n)
  FI.isPrime (2^127-1) >>= assert "large prime"
  FI.isPrime 15 >>= assert "composite" . not
  v <- flintVersion
  assert "FLINT version" (v == "3.6.0")
  forM_ [[], [0], [7], [-12], [-1,0,0,0,1], [2,-4,2], [10^40,0,1], [-108,36,-216,72,-108,36], [1,2,0,0], [10^1500]] $ \cs -> do
    f <- factor cs
    assert ("factor reconstruction: " ++ take 50 (show cs)) (reconstruct f == normalise cs)
    old <- legacy cs
    assert "Flint2 / opaque bindings agree" (sort old == sort (map fst (factors f)))
  forM_ [2,7,2^127-1] $ \p -> do
    f <- factorMod p [-1,0,1]
    assert "modular factor reconstruction" (map (`mod` p) (reconstruct f) == [p-1,0,1])
  withZ (10^100) $ \z -> peekZ z >>= assert "large integer" . (==10^100)
  withQ ((10^80+1)%17) $ \q -> peekQ q >>= assert "rational" . (==(10^80+1)%17)
  let Just a = zmat [[1,2,3],[4,5,6]]
      Just b = zmat [[7,8],[9,10],[11,12]]
      Just ab = zmul a b
  assert "rectangular matrix stride" (zlist ab == [[58,64],[139,154]])
  -- Exercise the corrected Flint2 Storable stride, not just compilation.
  _ <- OldMat.withNewFmpzMat 2 3 $ \p -> do
    OldMat.CFmpzMat _ rows cols stride <- peek p
    assert "Flint2 stride layout" (rows == 2 && cols == 3 && stride == 3)
  _ <- OldMat.withNewFmpzMat 3 4 $ \p -> do
    forM_ [(i,j) | i <- [0..2], j <- [0..3]] $ \(i,j) ->
      OldMat.fmpz_mat_entry p i j >>= (\x -> OldZ.fmpz_set_si x (10*i+j))
    alloca $ \w -> bracket_ (OldMat.fmpz_mat_window_init w p 1 1 3 3) (OldMat.fmpz_mat_window_clear w) $ do
      OldMat.CFmpzMat _ rows cols stride <- peek w
      assert "window shape/stride" (rows == 2 && cols == 2 && stride == 4)
      x <- OldMat.fmpz_mat_entry w 1 1 >>= OldZ.fmpz_get_si
      assert "window entry uses parent stride" (x == 22)
  nm <- OldNMat.newNModMat 2 3 17
  _ <- OldNMat.withNModMat nm $ \p -> do
    OldNMat.CNModMat _ _ _ stride modp <- peek p
    OldN.CNMod modulus _ _ <- peek modp
    assert "embedded nmod context" (stride == 3 && modulus == 17)
  npm <- OldNP.newNModPolyMat 2 3 17
  _ <- OldNP.withNModPolyMat npm $ \p -> do
    OldNP.CNModPolyMat _ _ _ stride modulus <- peek p
    assert "polynomial matrix scalar modulus" (stride == 3 && modulus == 17)
  assert "PSL2 inverse" (mul genT (inv genT) == identity)
  putStrLn ("flintell: FLINT " ++ v ++ "; native factorisation, Flint2 parity, matrices and exact arithmetic passed")
