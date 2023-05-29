{-# LANGUAGE ScopedTypeVariables #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-hello-world.html
module Main (main) where

import qualified Data.ByteString as B
import Paths_wasmtime (getDataFileName)
import Wasmtime

main :: IO ()
main = do
  putStrLn "Initializing..."
  engine :: Engine <- newEngine

  store :: Store <- newStore engine

  ctx :: Context <- storeContext store

  helloWatPath <- getDataFileName "test/hello.wat"
  watBytes <- B.readFile helloWatPath

  wasm :: Wasm <- wat2wasm watBytes

  putStrLn "Compiling module..."
  _module :: Module <- newModule engine wasm

  _helloFuncType :: FuncType (IO ()) <- newFuncType

  let hello :: IO ()
      hello = do
        putStrLn "Calling back..."
        putStrLn "> Hello World!"

  _func :: Func <- newFunc ctx hello

  -- TODO
  pure ()
