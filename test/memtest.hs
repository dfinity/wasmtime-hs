module Main (main) where

import Control.Exception (Exception, throwIO, try)
import Control.Monad.Primitive (RealWorld)
import qualified Data.ByteString as B
import Data.Foldable (for_)
import Data.Int (Int32)
import Paths_wasmtime (getDataFileName)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import Test.Tasty.HUnit ((@?=))
import Wasmtime

main :: IO ()
main = do
  putStrLn "ok"




