{-# LANGUAGE ScopedTypeVariables #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-hello-world.html
module Main (main) where

import qualified Data.ByteString as B
import Paths_wasmtime (getDataFileName)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import Wasmtime

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering

  putStrLn "Initializing..."
  engine :: Engine <- newEngine

  store :: Store <- newStore engine

  ctx :: Context <- storeContext store

  helloWatPath <- getDataFileName "test/hello.wat"
  watBytes <- B.readFile helloWatPath

  wasm :: Wasm <- wat2wasm watBytes

  putStrLn "Compiling module..."
  myModule :: Module <- newModule engine wasm

  func :: Func <- newFunc ctx hello

  let funcExtern :: Extern = extern func

  _instance :: Instance <- newInstance ctx myModule [funcExtern]

  -- TODO
  pure ()

hello :: IO ()
hello = do
  putStrLn "Calling back..."
  putStrLn "> Hello World!"
