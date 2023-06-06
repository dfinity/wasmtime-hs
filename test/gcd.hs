{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-gcd.html
module Main (main) where

import Control.Exception (throwIO)
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

  wasm <- handleWasmtimeError $ wat2wasm watBytes

  myModule <- handleWasmtimeError $ newModule engine wasm

  inst <- newInstance ctx myModule []

  Just e <- getExport ctx inst "gcd"

  let Just (gcdFunc :: Func RealWorld) = fromExtern e
  let Just (gcdTypedFunc :: TypedFunc RealWorld (Int32 -> Int32 -> IO Int32)) = toTypedFunc ctx gcdFunc

  let a = 6
      b = 27
  r <- callFunc ctx gcdTypedFunc a b

  printf "gcd(%d, %d) = %d\n" a b r

handleWasmtimeError :: Either WasmtimeError a -> IO a
handleWasmtimeError = either throwIO pure
