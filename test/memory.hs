{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-memory.html
module Main (main) where

import Control.Exception (Exception, throwIO)
import Control.Monad.Primitive (RealWorld)
import qualified Data.ByteString as B
import Data.Int (Int32)
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

  let mtype = newMemoryType 1 (Just 2) False
  memory <- newMemory ctx mtype >>= handleException

  putStrLn "Instantiating module..."
  inst <- newInstance ctx myModule [toExtern memory] >>= handleException

  putStrLn "Extracting exports..."
  -- Just memory <- getExportedMemory ctx inst "memory"

  -- print memory
  Just (storeFun :: TypedFunc RealWorld (Int32 -> Int32 -> IO (Either Trap ()))) <- getExportedTypedFunc ctx inst "store"
  Right () <- callFunc ctx storeFun 5 (-13)
  frozen <- freezeMemory ctx memory
  size_before <- getMemorySizePages ctx memory
  print ("size before", size_before)
  print $ B.length frozen

  _ <- growMemory ctx memory 1 >>= handleException
  size_after <- getMemorySizePages ctx memory
  print ("size after", size_after)

  print $ B.unpack $ B.take 20 frozen
  putStrLn "All finished"

handleWasmtimeError :: Either WasmtimeError a -> IO a
handleWasmtimeError = either throwIO pure

handleException :: Exception e => Either e r -> IO r
handleException = either throwIO pure

wasmFromPath :: FilePath -> IO Wasm
wasmFromPath path = do
  bytes <- getDataFileName path >>= B.readFile
  handleWasmtimeError $ wat2wasm bytes
