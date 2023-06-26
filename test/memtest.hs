{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main (main) where

import Control.Exception (Exception, throwIO)
import Control.Monad.Primitive (MonadPrim, RealWorld)
import qualified Data.ByteString as B
import Data.Foldable (for_)
import Data.Int (Int32)
import Data.Word (Word8)
import Paths_wasmtime (getDataFileName)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import System.Mem (performGC)
import Test.Tasty.HUnit ((@?=))
import Wasmtime
import Wasmtime (callFunc)

-- TODO: cmd line args for num iterations

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering

  putStrLn "Initializing..."
  engine <- newEngine
  for_ ([1 .. 100] :: [Int32]) $ \j -> do
    -- print ("j", j) -- FIXME: currently fails after 13107 iterations
    store <- newStore engine
    ctx <- storeContext store
    wasm <- wasmFromPath "test/memtest.wat"

    myModule <- handleWasmtimeError $ newModule engine wasm

    for_ ([1 .. 10] :: [Int32]) $ \i -> do
      fIo <- newFunc ctx io_imp
      fPure <- newFunc ctx pure_imp

      inst <- newInstance ctx myModule [toExtern fIo, toExtern fPure]
      inst <- case inst of
        Left trap -> do
          print ("trapped while creating instance: ", trapCode trap)
          error "nok"
        Right inst -> pure inst

      Just memory <- getExportedMemory ctx inst "memory"
      Just (size :: TypedFunc RealWorld (IO (Either Trap Int32))) <- getExportedTypedFunc ctx inst "size"
      Just (load :: TypedFunc RealWorld (Int32 -> IO (Either Trap Int32))) <- getExportedTypedFunc ctx inst "load"
      Just (store :: TypedFunc RealWorld (Int32 -> Int32 -> IO (Either Trap ()))) <- getExportedTypedFunc ctx inst "store"
      Just (callImportedPure :: TypedFunc RealWorld (Int32 -> IO (Either Trap Int32))) <- getExportedTypedFunc ctx inst "call_imported_pure"
      Just (callImportedIo :: TypedFunc RealWorld (IO (Either Trap ()))) <- getExportedTypedFunc ctx inst "call_imported_io"

      Right res <- callFunc ctx size
      -- print ("size", res)
      Right () <- callFunc ctx store i i
      Right res <- callFunc ctx load i
      -- print ("load", res)
      Right res <- callFunc ctx callImportedPure i
      -- print ("pure", res)
      -- Right () <- callFunc ctx callImportedIo
      -- putStrLn "--------------"
      pure ()
  -- performGC
  -- putStrLn "=================="
  putStrLn "end"

io_imp :: IO (Either Trap ())
io_imp = Right <$> putStrLn "hello io"

pure_imp :: Int32 -> IO (Either Trap Int32)
pure_imp x = pure . Right $ x * (x - 1)

handleWasmtimeError :: Either WasmtimeError a -> IO a
handleWasmtimeError = either throwIO pure

wasmFromPath :: FilePath -> IO Wasm
wasmFromPath path = do
  bytes <- getDataFileName path >>= B.readFile
  handleWasmtimeError $ wat2wasm bytes

wasmFromPath' :: FilePath -> IO Wasm
wasmFromPath' path = do
  bytes <- getDataFileName path >>= B.readFile
  pure $ unsafeWasmFromBytes bytes
