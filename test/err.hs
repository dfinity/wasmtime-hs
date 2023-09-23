module Main (main) where

import Control.Exception
import Control.Monad
import qualified Data.ByteString.Char8 as BC
import Wasmtime

-- This loop must not crash with a malloc error
-- cabal run err --test-show-details=streaming
main :: IO ()
main = forM_ [0 :: Int .. 1000000] $ \i -> do
  when (i `mod` 100 == 0) $ do
    putStrLn $ "Try #" ++ show i
  either throwIO pure $ wat2wasm $ BC.pack "(module)"