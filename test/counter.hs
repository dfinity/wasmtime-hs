{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}

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
import Wasmtime (callFunc)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering

  putStrLn "Initializing..."
  engine <- newEngine
  store <- newStore engine
  ctx <- storeContext store
  --   wasm <- wasmFromPath "test/c.wat"
  wasm <- wasmFromPath' "test/c.wasm"

  putStrLn "Compiling module..."
  myModule <- handleWasmtimeError $ newModule engine wasm

  f <- newFunc ctx msg_reply

  putStrLn "Instantiating module..."
  inst <- newInstance ctx myModule [toExtern f]
  inst <- case inst of
    Left trap -> do
      print ("trap", trap)
      error "nok"
    Right inst -> do
      putStrLn "ok got inst"
      pure inst

  putStrLn "Extracting exports..."
  --   Just memory <- getExportedMemory ctx inst "memory"
  Just (init :: TypedFunc RealWorld (IO (Either Trap ()))) <- getExportedTypedFunc ctx inst "canister_init"
  res <- callFunc ctx init
  print ("res", res)

msg_reply :: IO (Either Trap ())
msg_reply = return $ Right ()

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
