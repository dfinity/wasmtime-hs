{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-name-shadowing #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-memory.html
module Main (main) where

import Control.Exception (Exception, throwIO)
import Control.Monad.Primitive (MonadPrim)
import qualified Data.ByteString as B
import Data.Int (Int32)
import Data.Word (Word8)
import Paths_wasmtime_hs (getDataFileName)
import Test.Tasty.HUnit ((@?=))
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import Wasmtime

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering -- Mysteriously, if removing the buffering specification, the test fails to run in `nix build`.

  putStrLn "Initializing..."
  engine <- newEngine
  store <- newStore engine >>= handleException
  wasm <- wasmFromPath "test/memory.wat"

  putStrLn "Compiling module..."
  myModule <- handleWasmtimeError $ newModule engine wasm

  putStrLn "Instantiating module..."
  inst <- newInstance store myModule [] >>= handleException

  putStrLn "Extracting exports..."
  Just memory <- getExportedMemory store inst "memory"
  Just (sizeFun :: IO (Either WasmException Int32)) <-
    getExportedFunction store inst "size"
  Just (loadFun :: Int32 -> IO (Either WasmException Int32)) <-
    getExportedFunction store inst "load"
  Just (storeFun :: Int32 -> Int32 -> IO (Either WasmException ())) <-
    getExportedFunction store inst "store"

  putStrLn "Checking memory..."
  2 <- getMemorySizePages store memory
  0x20000 <- getMemorySizeBytes store memory
  mem_bs <- readMemory store memory
  B.head mem_bs @?= 0
  B.index mem_bs 0x1000 @?= 1
  B.index mem_bs 0x1003 @?= 4
  Right 2 <- sizeFun
  Right 0 <- loadFun 0
  Right 1 <- loadFun 0x1000
  Right 4 <- loadFun 0x1003
  Right 0 <- loadFun 0x1ffff
  Left (Trap trap_res) <- loadFun 0x20000
  trapCode trap_res @?= Just TRAP_CODE_MEMORY_OUT_OF_BOUNDS

  putStrLn "Mutating memory..."
  Right () <- writeByte store memory 0x1003 5
  Right _ <- storeFun 0x1002 6
  Left (Trap trap_res) <- storeFun 0x20000 0
  trapCode trap_res @?= Just TRAP_CODE_MEMORY_OUT_OF_BOUNDS
  mem_bs <- readMemory store memory
  B.index mem_bs 0x1002 @?= 6
  B.index mem_bs 0x1003 @?= 5
  Right 6 <- loadFun 0x1002
  Right 5 <- loadFun 0x1003

  putStrLn "Growing memory..."
  Right 2 <- growMemory store memory 1
  3 <- getMemorySizePages store memory
  0x30000 <- getMemorySizeBytes store memory
  Right 0 <- loadFun 0x20000
  Right () <- storeFun 0x20000 0
  Left (Trap trap_res) <- loadFun 0x30000
  trapCode trap_res @?= Just TRAP_CODE_MEMORY_OUT_OF_BOUNDS
  Left (Trap trap_res) <- storeFun 0x30000 0
  trapCode trap_res @?= Just TRAP_CODE_MEMORY_OUT_OF_BOUNDS
  Left _ <- growMemory store memory 1
  Right 3 <- growMemory store memory 0

  putStrLn "Creating stand-alone memory..."
  let mem_type = newMemoryType 5 (Just 5) Bit32
  Right memory2 <- newMemory store mem_type
  5 <- getMemorySizePages store memory2

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

writeByte ::
  MonadPrim s m =>
  Store s ->
  Memory s ->
  Int ->
  Word8 ->
  m (Either MemoryAccessError ())
writeByte store mem offset byte = writeMemory store mem offset $ B.singleton byte
