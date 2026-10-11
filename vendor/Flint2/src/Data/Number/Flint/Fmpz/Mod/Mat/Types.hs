-- FLINT 3 stores the modulus in a separate context, not in the matrix.
module Data.Number.Flint.Fmpz.Mod.Mat.Types (CFmpzModMat) where
import Data.Number.Flint.Fmpz.Mat (CFmpzMat)
type CFmpzModMat = CFmpzMat
