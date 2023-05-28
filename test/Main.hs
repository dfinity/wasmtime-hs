{-# LANGUAGE ScopedTypeVariables #-}

module Main (main) where

import qualified Data.ByteString as B
import Paths_wasmtime
import qualified Wasmtime

-- Haskell translation of: https://docs.wasmtime.dev/examples-c-hello-world.html

main :: IO ()
main = do
  putStrLn "Initializing..."
  engine :: Wasmtime.Engine <- Wasmtime.newEngine

  store :: Wasmtime.Store <- Wasmtime.newStore engine

  _ctx :: Wasmtime.Context <- Wasmtime.storeContext store

  helloWatPath <- getDataFileName "test/hello.wat"
  watBytes <- B.readFile helloWatPath

  _wasmBytes <- Wasmtime.wat2wasm watBytes

  -- TODO
  pure ()
