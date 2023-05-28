{-# LANGUAGE ScopedTypeVariables #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-hello-world.html
module Main (main) where

import qualified Data.ByteString as B
import Paths_wasmtime
import qualified Wasmtime

main :: IO ()
main = do
  putStrLn "Initializing..."
  engine :: Wasmtime.Engine <- Wasmtime.newEngine

  store :: Wasmtime.Store <- Wasmtime.newStore engine

  _ctx :: Wasmtime.Context <- Wasmtime.storeContext store

  helloWatPath <- getDataFileName "test/hello.wat"
  watBytes <- B.readFile helloWatPath

  wasm :: Wasmtime.Wasm <- Wasmtime.wat2wasm watBytes

  putStrLn "Compiling module..."
  _module :: Wasmtime.Module <- Wasmtime.newModule engine wasm

  -- TODO
  pure ()
