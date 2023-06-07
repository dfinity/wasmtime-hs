{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-hello-world.html
module Main (main) where

import Control.Exception (throwIO)
import Control.Monad.Primitive (RealWorld)
import qualified Data.ByteString as B
import Paths_wasmtime (getDataFileName)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import Wasmtime

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering

  putStrLn "Initializing..."
  engine <- newEngine

  store <- newStore engine

  ctx <- storeContext store

  helloWatPath <- getDataFileName "test/hello.wat"
  watBytes <- B.readFile helloWatPath

  wasm <- handleWasmtimeError $ wat2wasm watBytes

  putStrLn "Compiling module..."
  myModule <- handleWasmtimeError $ newModule engine wasm

  putStrLn "Creating callback..."
  func <- newFunc ctx hello

  putStrLn "Instantiating module..."
  let funcExtern = toExtern func

  inst <- newInstance ctx myModule [funcExtern]

  putStrLn "Extracting export..."
  Just ((runTypedFunc :: TypedFunc RealWorld (IO ()))) <-
    getExportedTypedFunc ctx inst "run"

  putStrLn "Calling export..."
  callFunc ctx runTypedFunc

  putStrLn "All finished!"

  -- TODO
  pure ()

hello :: IO ()
hello = do
  putStrLn "Calling back..."
  putStrLn "> Hello World!"

handleWasmtimeError :: Either WasmtimeError a -> IO a
handleWasmtimeError = either throwIO pure