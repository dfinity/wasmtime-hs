{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-hello-world.html
module Main (main) where

import Control.Exception (Exception, throwIO)
import qualified Data.ByteString as B
import Paths_wasmtime_hs (getDataFileName)
import Wasmtime

main :: IO ()
main = do
  putStrLn "Initializing..."
  engine <- newEngine

  store <- newStore engine >>= handleException

  helloWatPath <- getDataFileName "test/hello.wat"
  watBytes <- B.readFile helloWatPath

  wasm <- handleException $ wat2wasm watBytes

  putStrLn "Compiling module..."
  myModule <- handleException $ newModule engine wasm

  putStrLn "Creating callback..."
  func <- newFuncUnchecked store hello

  putStrLn "Instantiating module..."
  inst <- newInstance store myModule [toExtern func] >>= handleException

  putStrLn "Extracting export..."
  Just (run :: IO (Either WasmException ())) <-
    getExportedFunction store inst "run"

  putStrLn "Calling export..."
  run >>= handleException

  putStrLn "All finished!"

hello :: IO (Either Trap ())
hello =
  Right <$> do
    putStrLn "Calling back..."
    putStrLn "> Hello World!"

handleException :: Exception e => Either e r -> IO r
handleException = either throwIO pure
