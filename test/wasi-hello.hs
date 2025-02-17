{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-hello-world.html
module Main (main) where

import Control.Exception (Exception, throwIO)
import qualified Data.ByteString as B
import Paths_wasmtime_hs (getDataFileName)
import Wasmtime
import Data.Int

main :: IO ()
main = do
  putStrLn "Initializing..."
  engine <- newEngine

  store <- newStore engine >>= handleException

  helloWatPath <- getDataFileName "test/wasi_hello.wat"
  watBytes <- B.readFile helloWatPath

  wasm <- handleException $ wat2wasm watBytes

  putStrLn "Compiling module..."
  myModule <- handleException $ newModule engine wasm

  putStrLn "Linking wasi..."
  linker <- newLinker engine
  linkerDefineWasiWith (wasiInheritArgv <> wasiInheritStderr <> wasiInheritStdin <> wasiInheritStdout) linker store >>= handleException

  putStrLn "Instantiating module..."
  inst <- linkerInstantiate linker store myModule >>= handleException

  putStrLn "Extracting export..."
  Just (run :: IO (Either WasmException Int32)) <-
    getExportedFunction store inst "run"

  putStrLn "Calling export..."
  _ <- run >>= handleException

  putStrLn "All finished!"

handleException :: Exception e => Either e r -> IO r
handleException = either throwIO pure
