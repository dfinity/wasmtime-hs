{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-memory.html
module Main (main) where

import Control.Exception (Exception, throwIO)
import Control.Exception.Base (assert)
import Control.Monad.Primitive (RealWorld)
import qualified Data.ByteString as B
import Data.Int (Int32)
import Data.Primitive.Ptr (advancePtr)
import Data.Word (Word8)
import Foreign (poke)
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

  -- let mtype = newMemoryType 1 (Just 2) False
  -- memory <- newMemory ctx mtype >>= handleException

  putStrLn "Instantiating module..."
  inst <- newInstance ctx myModule [] >>= handleException

  putStrLn "Extracting exports..."
  Just memory <- getExportedMemory ctx inst "memory"
  Just (sizeFun :: TypedFunc RealWorld (IO (Either Trap Int32))) <- getExportedTypedFunc ctx inst "size"
  Just (loadFun :: TypedFunc RealWorld (Int32 -> IO (Either Trap Int32))) <- getExportedTypedFunc ctx inst "load"
  Just (storeFun :: TypedFunc RealWorld (Int32 -> Int32 -> IO (Either Trap ()))) <- getExportedTypedFunc ctx inst "store"

  putStrLn "Checking memory..."
  size_pages <- getMemorySizePages ctx memory
  let _ = assert (size_pages == 2) ()
  size_bytes <- getMemorySizeBytes ctx memory
  let _ = assert (size_bytes == 0x20000) ()
  mem_bs <- freezeMemory ctx memory
  let _ = assert (B.head mem_bs == 0) ()
  let _ = assert (B.index mem_bs 0x1000 == 1) ()
  let _ = assert (B.index mem_bs 0x1003 == 4) ()
  -- check function calls
  Right 2 <- callFunc ctx sizeFun
  Right 0 <- callFunc ctx loadFun 0
  Right 1 <- callFunc ctx loadFun 0x1000
  Right 4 <- callFunc ctx loadFun 0x1003
  Right 0 <- callFunc ctx loadFun 0x1ffff
  Left trap_res <- callFunc ctx loadFun 0x20000
  let _ = assert (trapCode trap_res == Just TRAP_CODE_MEMORY_OUT_OF_BOUNDS) ()

  putStrLn "Mutating memory..."
  unsafeWriteByte ctx memory 0x1003 5
  Right () <- callFunc ctx storeFun 0x1002 6
  Left trap_res <- callFunc ctx storeFun 0x20000 0
  let _ = assert (trapCode trap_res == Just TRAP_CODE_MEMORY_OUT_OF_BOUNDS) ()
  mem_bs <- freezeMemory ctx memory
  let _ = assert (B.index mem_bs 0x1002 == 6) ()
  let _ = assert (B.index mem_bs 0x1003 == 5) ()
  Right 6 <- callFunc ctx loadFun 0x1002
  Right 5 <- callFunc ctx loadFun 0x1003

  putStrLn "Growing memory..."
  putStrLn "All finished"

handleWasmtimeError :: Either WasmtimeError a -> IO a
handleWasmtimeError = either throwIO pure

handleException :: Exception e => Either e r -> IO r
handleException = either throwIO pure

wasmFromPath :: FilePath -> IO Wasm
wasmFromPath path = do
  bytes <- getDataFileName path >>= B.readFile
  handleWasmtimeError $ wat2wasm bytes

-- TODO: this is unsafe and does not check if the offset is within the linear memory
-- replace with writeMemory!
unsafeWriteByte :: Context s -> Memory s -> Int -> Word8 -> IO ()
unsafeWriteByte ctx mem offset byte =
  unsafeWithMemory ctx mem $ \start_ptr _maxlen -> do
    let pos_ptr = advancePtr start_ptr offset
    poke pos_ptr byte