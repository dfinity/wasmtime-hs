{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-name-shadowing #-}
{-# OPTIONS_GHC -Wno-unused-matches #-}

module Main (main) where

import Control.Exception (throwIO)
import qualified Data.ByteString as B
import Data.Foldable (for_)
import Data.Int (Int32)
import Paths_wasmtime (getDataFileName)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import Wasmtime

-- TODO: cmd line args for num iterations

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering

  putStrLn "Initializing..."
  engine <- newEngine
  for_ ([1 .. 100] :: [Int32]) $ \_j -> do
    -- print ("j", j) -- FIXME: currently fails after 13107 iterations
    s <- newStore engine
    wasm <- wasmFromPath "test/memtest.wat"

    myModule <- handleWasmtimeError $ newModule engine wasm

    for_ ([1 .. 10] :: [Int32]) $ \i -> do
      fIo <- newFunc s ioImp
      fPure <- newFunc s pureImp

      inst <- newInstance s myModule [toExtern fIo, toExtern fPure]
      inst <- case inst of
        Left trap -> do
          print ("trapped while creating instance: ", trapCode trap)
          error "nok"
        Right inst -> pure inst

      Just memory <- getExportedMemory s inst "memory"
      Just (size :: IO (Either Trap Int32)) <- getExportedFunction s inst "size"
      Just (load :: Int32 -> IO (Either Trap Int32)) <- getExportedFunction s inst "load"
      Just (store :: Int32 -> Int32 -> IO (Either Trap ())) <- getExportedFunction s inst "store"
      Just (callImportedPure :: Int32 -> IO (Either Trap Int32)) <- getExportedFunction s inst "call_imported_pure"
      Just (callImportedIo :: IO (Either Trap ())) <- getExportedFunction s inst "call_imported_io"

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

ioImp :: IO (Either Trap ())
ioImp = Right <$> putStrLn "hello io"

pureImp :: Int32 -> IO (Either Trap Int32)
pureImp x = pure . Right $ x * (x - 1)

handleWasmtimeError :: Either WasmtimeError a -> IO a
handleWasmtimeError = either throwIO pure

wasmFromPath :: FilePath -> IO Wasm
wasmFromPath path = do
  bytes <- getDataFileName path >>= B.readFile
  handleWasmtimeError $ wat2wasm bytes
