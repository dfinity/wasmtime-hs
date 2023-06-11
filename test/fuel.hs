{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-name-shadowing #-}

-- | Haskell translation of: https://github.com/bytecodealliance/wasmtime/blob/main/examples/fuel.c
module Main (main) where

import Control.Exception (Exception, throwIO, try)
import Control.Monad.Primitive (MonadPrim, RealWorld)
import qualified Data.ByteString as B
import Data.Foldable (for_)
import Data.Int (Int32)
import Data.Word (Word64, Word8)
import GHC.IO.Exception (IOErrorType (IllegalOperation))
import GHC.RTS.Flags (ConcFlags (ctxtSwitchTicks))
import Paths_wasmtime (getDataFileName)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import Test.Tasty.HUnit ((@?=))
import Wasmtime

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering

  putStrLn "Initializing..."
  engine <- newEngineWithConfig $ setConsumeFuel True
  store <- newStore engine
  ctx <- storeContext store
  Right () <- addFuel ctx 10000

  wasm <- wasmFromPath "test/fuel.wat"

  putStrLn "Compiling module..."
  myModule <- handleWasmtimeError $ newModule engine wasm

  putStrLn "Instantiating module..."
  inst <- newInstance ctx myModule [] >>= handleException

  putStrLn "Extracting exports..."
  Just (fib :: TypedFunc RealWorld (Int32 -> IO (Either Trap Int32))) <- getExportedTypedFunc ctx inst "fibonacci"
  (Left trap :: Either Trap ()) <- try $ for_ ([1 ..] :: [Int32]) $ \i -> do
    Just fuel_before <- fuelConsumed ctx
    res <- callFunc ctx fib i
    case res of
      Left trap -> putStrLn ("Exhausted fuel computing fib " ++ show i) >> throwIO trap
      Right m -> do
        Just fuel_after <- fuelConsumed ctx
        let diff = fuel_after - fuel_before
        putStrLn $ "fib " ++ show i ++ " = " ++ show m ++ " consumed " ++ show diff ++ " fuel."
        addFuel ctx diff
        pure ()
  trapCode trap @?= Just TRAP_CODE_OUT_OF_FUEL

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
