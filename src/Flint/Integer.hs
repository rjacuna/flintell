{-# LANGUAGE ForeignFunctionInterface #-}
module Flint.Integer (factorInteger, isPrime) where
import Control.Exception (bracket)
import Foreign.C.String
import Foreign.C.Types
import Foreign.Ptr (nullPtr)
import Text.Read (readMaybe)
foreign import ccall safe "flintell_factor_integer" c_factor :: CString -> IO CString
foreign import ccall safe "flintell_is_prime" c_prime :: CString -> IO CInt
foreign import ccall unsafe "flintell_free" c_free :: CString -> IO ()
-- | Signed prime decomposition. Zero is not in the multiplicative group.
factorInteger :: Integer -> IO [(Integer,Integer)]
factorInteger 0 = ioError (userError "Cannot factor zero in the multiplicative group")
factorInteger n = withCString (show n) $ \s -> bracket (c_factor s) c_free $ \p ->
  if p==nullPtr then ioError (userError "FLINT integer factorisation failed")
  else do
    t <- peekCString p
    case parse (lines t) of
      Nothing -> ioError (userError "Invalid FLINT integer factorisation response")
      Just xs -> pure xs
  where
    parse (h:ls) = do
      sign <- case words h of ["s",v] -> readMaybe v; _ -> Nothing
      xs <- mapM (\line -> case words line of
        [p,e] -> (,) <$> readMaybe p <*> readMaybe e
        _ -> Nothing) ls
      if sign==(-1::Integer) then Just ((-1,1):xs) else if sign==1 then Just xs else Nothing
    parse _ = Nothing
isPrime :: Integer -> IO Bool
isPrime n = withCString (show n) $ \s -> (/=0) <$> c_prime s
