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
      Just (size :: IO (Either Trap Int32)) <- getExportedFunction ctx inst "size"
      Just (load :: Int32 -> IO (Either Trap Int32)) <- getExportedFunction ctx inst "load"
      Just (store :: Int32 -> Int32 -> IO (Either Trap ())) <- getExportedFunction ctx inst "store"
      Just (callImportedPure :: Int32 -> IO (Either Trap Int32)) <- getExportedFunction ctx inst "call_imported_pure"
      Just (callImportedIo :: IO (Either Trap ())) <- getExportedFunction ctx inst "call_imported_io"

      Right res <- size
      -- print ("size", res)
      Right () <- store i i
      Right res <- load i
      -- print ("load", res)
      Right res <- callImportedPure i
      -- print ("pure", res)
      -- Right () <- callImportedIo
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
