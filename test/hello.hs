{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-hello-world.html
module Main (main) where

import Control.Exception (Exception, throwIO)
import Control.Monad (void)
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

  wasm <- handleException $ wat2wasm watBytes

  putStrLn "Compiling module..."
  myModule <- handleException $ newModule engine wasm

  putStrLn "Creating callback..."
  func <- newFunc ctx hello

  putStrLn "Instantiating module..."
  inst <- newInstance ctx myModule [toExtern func] >>= handleException

  putStrLn "Extracting export..."
  Just ((runTypedFunc :: TypedFunc RealWorld (IO (Either Trap (List '[]))))) <-
    getExportedTypedFunc ctx inst "run"

  putStrLn "Calling export..."
  void $ callFunc ctx runTypedFunc >>= handleException

  putStrLn "All finished!"

hello :: IO (Either Trap (List '[]))
hello =
  Right <$> do
    putStrLn "Calling back..."
    putStrLn "> Hello World!"
    pure Nil

handleException :: Exception e => Either e r -> IO r
handleException = either throwIO pure
