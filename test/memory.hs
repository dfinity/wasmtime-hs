{-# LANGUAGE OverloadedLists #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-memory.html
module Main (main) where

import Control.Exception (throwIO)
import qualified Data.ByteString as B
import Paths_wasmtime (getDataFileName)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import Wasmtime

-- either throwIO pure $ wat2wasm . B.readFile <$> getDataFileName path

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering

  engine <- newEngine
  store <- newStore engine
  ctx <- storeContext store
  wasm <- wasmFromPath "test/memory.wat"

  putStrLn "Compiling module..."
  myModule <- handleWasmtimeError $ newModule engine wasm

  putStrLn "Instantiating module..."
  inst <- newInstance ctx myModule []

  putStrLn "Extracting exports..."
  -- memory <- getExport ctx inst "memory"
  putStrLn "All finished"

handleWasmtimeError :: Either WasmtimeError a -> IO a
handleWasmtimeError = either throwIO pure

wasmFromPath :: FilePath -> IO Wasm
wasmFromPath path = do
  bytes <- getDataFileName path >>= B.readFile
  handleWasmtimeError $ wat2wasm bytes
