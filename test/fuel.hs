{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-name-shadowing #-}

-- | Haskell translation of: https://raw.githubusercontent.com/bytecodealliance/wasmtime/main/examples/fuel.c
module Main (main) where

import Control.Exception (Exception, throwIO, try)
import qualified Data.ByteString as B
import Data.Foldable (for_)
import Data.Int (Int32)
import Paths_wasmtime_hs (getDataFileName)
import Test.Tasty.HUnit ((@?=))
import Wasmtime

main :: IO ()
main = do
  putStrLn "Initializing..."
  engine <- newEngineWithConfig $ setConsumeFuel True
  store <- newStore engine >>= handleException
  Right () <- setFuel store 10000

  wasm <- wasmFromPath "test/fuel.wat"

  putStrLn "Compiling module..."
  myModule <- handleException $ newModule engine wasm

  putStrLn "Instantiating module..."
  inst <- newInstance store myModule [] >>= handleException

  putStrLn "Extracting exports..."
  Just (fib :: Int32 -> IO (Either WasmException Int32)) <-
    getExportedFunction store inst "fibonacci"
  Left (Trap trap) <- try $ for_ ([1 ..] :: [Int32]) $ \i -> do
    Right fuel_before <- getFuel store
    res <- fib i
    case res of
      Left ex -> putStrLn ("Exhausted fuel computing fib " ++ show i) >> throwIO ex
      Right m -> do
        Right fuel_after <- getFuel store
        let diff = fuel_after - fuel_before
        putStrLn $ "fib " ++ show i ++ " = " ++ show m ++ " consumed " ++ show diff ++ " fuel."
        Right () <- setFuel store 10000
        pure ()
  trapCode trap @?= Just TRAP_CODE_OUT_OF_FUEL

  putStrLn "Shutting down..."
  putStrLn "Done."

handleException :: (Exception e) => Either e r -> IO r
handleException = either throwIO pure

wasmFromPath :: FilePath -> IO Wasm
wasmFromPath path = do
  bytes <- getDataFileName path >>= B.readFile
  handleException $ wat2wasm bytes
