{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-hello-world.html
module Main (main) where

import Control.Exception (throwIO)
import qualified Data.ByteString as B
import Paths_wasmtime (getDataFileName)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import Wasmtime

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering

  putStrLn "Initializing..."
  engine :: Engine <-
    newEngineWithConfig $
      setConsumeFuel True
        . setDebugInfo False
        . setDebugInfo True

  store :: Store <- newStore engine

  ctx :: Context <- storeContext store

  helloWatPath <- getDataFileName "test/hello.wat"
  watBytes <- B.readFile helloWatPath

  wasm :: Wasm <- either throwIO pure $ wat2wasm watBytes

  putStrLn "Compiling module..."
  myModule :: Module <- newModule engine wasm

  putStrLn "Creating callback..."
  func :: Func <- newFunc ctx hello

  putStrLn "Instantiating module..."
  let funcExtern :: Extern = toExtern func

  inst :: Instance <- newInstance ctx myModule [funcExtern]

  putStrLn "Extracting export..."
  Just (e :: Extern) <- getExport ctx inst "run"

  let Just (_runFunc :: Func) = fromExtern e

  putStrLn "Calling export..."

  -- TODO
  pure ()

hello :: IO ()
hello = do
  putStrLn "Calling back..."
  putStrLn "> Hello World!"
