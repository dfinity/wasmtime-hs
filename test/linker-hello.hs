{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-hello-world.html
-- but using a 'Linker' to define the "hello" function.
module Main (main) where

import Control.Exception (Exception, throwIO)
import qualified Data.ByteString as B
import Paths_wasmtime_hs (getDataFileName)
import System.Mem (performGC)
import Wasmtime

main :: IO ()
main = do
  engine <- newEngine

  linker <- newLinker engine
  linkerDefineFunc linker "" "hello" hello >>= handleException

  helloWatPath <- getDataFileName "test/hello.wat"
  watBytes <- B.readFile helloWatPath

  wasm <- handleException $ wat2wasm watBytes

  myModule <- handleException $ newModule engine wasm

  store <- newStore engine >>= handleException

  inst <- linkerInstantiate linker store myModule >>= handleException

  -- Force the linker to be garbage collected to test if calling "run" and thus
  -- "hello" still works as expected.
  performGC

  Just (run :: IO (Either WasmException ())) <-
    getExportedFunction store inst "run"

  run >>= handleException

hello :: IO (Either Trap ())
hello =
  Right <$> do
    putStrLn "Calling back..."
    putStrLn "> Hello World!"

handleException :: Exception e => Either e r -> IO r
handleException = either throwIO pure
