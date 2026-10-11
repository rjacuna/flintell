{-# LANGUAGE ForeignFunctionInterface #-}
-- | Exact Z[x] factorisation, native and WASI. Coefficients are low to high.
-- No FLINT layout is read by Haskell. The returned factors include exponents
-- and signed content, so the input can be reconstructed without information loss.
module Flint.Poly (Factorisation(..), factor, factorMod, cancel, flintVersion) where

import Control.Exception (bracket)
import Foreign.C.String (CString, withCString, peekCString)
import Foreign.Ptr (nullPtr)
import Text.Read (readMaybe)

data Factorisation = Factorisation
  { content :: Integer
  , factors :: [([Integer], Int)]
  } deriving (Eq, Show)

foreign import ccall safe "flintell_factor" c_factor :: CString -> IO CString
foreign import ccall safe "flintell_cancel" c_cancel :: CString -> CString -> IO CString
foreign import ccall safe "flintell_factor_mod" c_factor_mod :: CString -> CString -> IO CString
foreign import ccall unsafe "flintell_free" c_free :: CString -> IO ()
foreign import ccall unsafe "flintell_version" c_version :: IO CString

flintVersion :: IO String
flintVersion = c_version >>= peekCString

-- | Zero (including []) has content zero and no factors; constants have no
-- factors. Trailing zero coefficients are accepted and normalised by FLINT.
factor :: [Integer] -> IO Factorisation
factor = factorWith c_factor

-- | Factor over F_p, rejecting composite moduli. Content is the leading
-- coefficient modulo p and all nonconstant factors are monic.
factorMod :: Integer -> [Integer] -> IO Factorisation
factorMod p cs = withCString (show p) $ \prime -> factorWith (c_factor_mod prime) cs

-- | Cancel common factors/content in an integer numerator and denominator.
-- The quotient is unchanged; the caller can then make the denominator monic.
cancel :: [Integer] -> [Integer] -> IO ([Integer],[Integer])
cancel numerator denominator = withCString (wire numerator) $ \n ->
  withCString (wire denominator) $ \d -> bracket (c_cancel n d) c_free $ \out ->
    if out==nullPtr then ioError(userError "FLINT rational-function cancellation failed") else do
      result<-peekCString out
      case lines result of
        [ns,ds] -> case (parse ns,parse ds) of
          (Just a,Just b) | not(null b)->pure(a,b)
          _->bad
        _->bad
  where
    wire cs=show(length cs)++"  "++unwords(map show cs)
    parse s=case words s of
      n:xs->do count<-readMaybe n;cs<-mapM readMaybe xs
               if count==length cs then Just cs else Nothing
      _->Nothing
    bad=ioError(userError "Invalid FLINT cancellation response")

factorWith :: (CString -> IO CString) -> [Integer] -> IO Factorisation
factorWith call cs = withCString wire $ \input -> bracket (call input) c_free $ \out ->
  if out == nullPtr then ioError (userError "FLINT factorisation failed")
  else do
    result <- peekCString out
    case parse result of
      Just f -> pure f
      Nothing -> ioError (userError "Invalid FLINT factorisation response")
  where
    wire = show (length cs) ++ "  " ++ unwords (map show cs)
    parse s = case lines s of
      c:fs -> do
        n <- case words c of { ["c", v] -> readMaybe v; _ -> Nothing }
        Factorisation n <$> mapM parseFactor fs
      _ -> Nothing
    parseFactor line = case words line of
      e:n:xs -> do
        multiplicity <- readMaybe e
        count <- readMaybe n
        coeffs <- mapM readMaybe xs
        if multiplicity > 0 && count == length coeffs then Just (coeffs, multiplicity) else Nothing
      _ -> Nothing
