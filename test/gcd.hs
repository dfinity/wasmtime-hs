{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-gcd.html
module Main (main) where

import Control.Exception (Exception, throwIO)
import qualified Data.ByteString as B
import Data.Int (Int32)
import Paths_wasmtime_hs (getDataFileName)
import Text.Printf (printf)
import Wasmtime

main :: IO ()
main = do
  engine <- newEngine

  store <- newStore engine >>= handleException

  helloWatPath <- getDataFileName "test/gcd.wat"
  watBytes <- B.readFile helloWatPath

  wasm <- handleException $ wat2wasm watBytes

  myModule <- handleException $ newModule engine wasm

  inst <- newInstance store myModule [] >>= handleException

  Just (wasmGCD :: Int32 -> Int32 -> IO (Either WasmException Int32)) <-
    getExportedFunction store inst "gcd"

  let a = 6
      b = 27

  r <- wasmGCD a b >>= handleException
  printf "gcd(%d, %d) = %d\n" a b r

handleException :: Exception e => Either e r -> IO r
handleException = either throwIO pure
