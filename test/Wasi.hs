module Main where
import Flint.Poly
import Flint.Mat
import Flint.SL2
import Control.Monad (unless)
main :: IO ()
main = do
  reduced<-cancel [6,-12,6] [-9,0,9]
  unless (reduced==([-2,2],[3,3])) (error "rational-function cancellation")

  v <- flintVersion
  unless (v == "3.6.0") (error "wrong FLINT version")
  f <- factor [2,-4,2]
  unless (f == Factorisation 2 [([-1,1],2)]) (error "factorisation")
  let Just a = zmat [[1,2,3],[4,5,6]]
      Just b = zmat [[7,8],[9,10],[11,12]]
      Just ab = zmul a b
  unless (zlist ab == [[58,64],[139,154]]) (error "matrix stride")
  unless (mul genT (inv genT) == identity) (error "PSL2")
  putStrLn ("WASI: FLINT " ++ v ++ "; factorisation, matrices and PSL2 passed")
