{-# LANGUAGE ForeignFunctionInterface #-}
module Flint.Curve (irreducibleOverFunctionField) where
import Foreign.C.String
import Foreign.C.Types
foreign import ccall safe "flintell_curve_irreducible" c_irreducible :: CString -> CString -> IO CInt
-- | Exact FLINT factorisation test in k(x)[y], k=Q (characteristic 0)
-- or F_p (proven prime p). Input is a polynomial in the fixed names x,y.
-- Factors in x alone are units. Repeated y-dependent factors are rejected.
irreducibleOverFunctionField :: Integer -> String -> IO Bool
irreducibleOverFunctionField characteristic polynomial=
  withCString(show characteristic) $ \p->withCString polynomial $ \s->do
    result<-c_irreducible p s
    if result<0 then ioError(userError "FLINT curve factorisation failed: invalid polynomial or characteristic")
    else pure(result==1)
