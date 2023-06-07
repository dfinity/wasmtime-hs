{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-gcd.html
module Main (main) where

import Control.Exception (Exception, throwIO)
import Control.Monad.Primitive (RealWorld)
import qualified Data.ByteString as B
import Data.Int (Int32)
import Paths_wasmtime (getDataFileName)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import Text.Printf (printf)
import Wasmtime

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering

  engine <- newEngine

  store <- newStore engine

  ctx <- storeContext store

  helloWatPath <- getDataFileName "test/gcd.wat"
  watBytes <- B.readFile helloWatPath

  wasm <- handleException $ wat2wasm watBytes

  myModule <- handleException $ newModule engine wasm

  inst <- newInstance ctx myModule []

  Just (gcdTypedFunc :: TypedFunc RealWorld (Int32 -> Int32 -> IO (Either Trap Int32))) <-
    getExportedTypedFunc ctx inst "gcd"

  let a = 6
      b = 27
  r <- callFunc ctx gcdTypedFunc a b >>= handleException

  printf "gcd(%d, %d) = %d\n" a b r

handleException :: Exception e => Either e r -> IO r
handleException = either throwIO pure
