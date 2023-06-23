{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-name-shadowing #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-memory.html
module Main (main) where

import Control.Exception (Exception, throwIO)
import Control.Monad.Primitive (MonadPrim, RealWorld)
import qualified Data.ByteString as B
import Data.Int (Int32)
import Data.Word (Word8)
import Paths_wasmtime (getDataFileName)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import Test.Tasty.HUnit ((@?=))
import Wasmtime

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering

  putStrLn "Initializing..."
  engine <- newEngine
  store <- newStore engine
  ctx <- storeContext store
  wasm <- wasmFromPath "test/memory.wat"

  putStrLn "Compiling module..."
  myModule <- handleWasmtimeError $ newModule engine wasm

  putStrLn "Instantiating module..."
  inst <- newInstance ctx myModule [] >>= handleException

  putStrLn "Extracting exports..."
  Just memory <- getExportedMemory ctx inst "memory"
  Just (sizeFun :: TypedFunc RealWorld (IO (Either Trap Int32))) <- getExportedTypedFunc ctx inst "size"
  Just (loadFun :: TypedFunc RealWorld (Int32 -> IO (Either Trap Int32))) <- getExportedTypedFunc ctx inst "load"
  Just (storeFun :: TypedFunc RealWorld (Int32 -> Int32 -> IO (Either Trap ()))) <- getExportedTypedFunc ctx inst "store"

  putStrLn "Checking memory..."
  2 <- getMemorySizePages ctx memory
  0x20000 <- getMemorySizeBytes ctx memory
  mem_bs <- readMemory ctx memory
  B.head mem_bs @?= 0
  B.index mem_bs 0x1000 @?= 1
  B.index mem_bs 0x1003 @?= 4
  Right 2 <- callFunc ctx sizeFun
  Right 0 <- callFunc ctx loadFun 0
  Right 1 <- callFunc ctx loadFun 0x1000
  Right 4 <- callFunc ctx loadFun 0x1003
  Right 0 <- callFunc ctx loadFun 0x1ffff
  Left trap_res <- callFunc ctx loadFun 0x20000
  trapCode trap_res @?= Just TRAP_CODE_MEMORY_OUT_OF_BOUNDS

  putStrLn "Mutating memory..."
  Right () <- writeByte ctx memory 0x1003 5
  Right _ <- callFunc ctx storeFun 0x1002 6
  Left trap_res <- callFunc ctx storeFun 0x20000 0
  trapCode trap_res @?= Just TRAP_CODE_MEMORY_OUT_OF_BOUNDS
  mem_bs <- readMemory ctx memory
  B.index mem_bs 0x1002 @?= 6
  B.index mem_bs 0x1003 @?= 5
  Right 6 <- callFunc ctx loadFun 0x1002
  Right 5 <- callFunc ctx loadFun 0x1003

  putStrLn "Growing memory..."
  Right 2 <- growMemory ctx memory 1
  3 <- getMemorySizePages ctx memory
  0x30000 <- getMemorySizeBytes ctx memory
  Right 0 <- callFunc ctx loadFun 0x20000
  Right () <- callFunc ctx storeFun 0x20000 0
  Left trap_res <- callFunc ctx loadFun 0x30000
  trapCode trap_res @?= Just TRAP_CODE_MEMORY_OUT_OF_BOUNDS
  Left trap_res <- callFunc ctx storeFun 0x30000 0
  trapCode trap_res @?= Just TRAP_CODE_MEMORY_OUT_OF_BOUNDS
  Left _ <- growMemory ctx memory 1
  Right 3 <- growMemory ctx memory 0

  putStrLn "Creating stand-alone memory..."
  let mem_type = newMemoryType 5 (Just 5) Bit32
  Right memory2 <- newMemory ctx mem_type
  5 <- getMemorySizePages ctx memory2

  putStrLn "Shutting down..."
  putStrLn "Done."

handleWasmtimeError :: Either WasmtimeError a -> IO a
handleWasmtimeError = either throwIO pure

handleException :: Exception e => Either e r -> IO r
handleException = either throwIO pure

wasmFromPath :: FilePath -> IO Wasm
wasmFromPath path = do
  bytes <- getDataFileName path >>= B.readFile
  handleWasmtimeError $ wat2wasm bytes

writeByte :: MonadPrim s m => Context s -> Memory s -> Int -> Word8 -> m (Either MemoryAccessError ())
writeByte ctx mem offset byte = writeMemory ctx mem offset $ B.singleton byte
