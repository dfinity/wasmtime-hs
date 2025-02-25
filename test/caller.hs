{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

-- | Haskell translation of: https://docs.wasmtime.dev/examples-c-hello-world.html
-- but using a 'Linker' to define the "hello" function.
module Main (main) where

import Control.Exception (Exception, throwIO)
import qualified Data.ByteString as B
import Paths_wasmtime_hs (getDataFileName)
import Data.Int
import Test.Tasty.HUnit ((@?=))
import Wasmtime
import Control.Monad.Primitive

main :: IO ()
main = do
  engine <- newEngine
  
  store <- newStore engine >>= handleException

  linker <- newLinker engine 
  linkerDefineFuncWithCaller linker "" "someFunc" someFunc >>= handleException

  watPath <- getDataFileName "test/caller.wat"
  watBytes <- B.readFile watPath

  wasm <- handleException $ wat2wasm watBytes

  myModule <- handleException $ newModule engine wasm

  inst <- linkerInstantiate linker store myModule >>= handleException

  -- run x = someFunc (x + 1)
  Just (run :: Int32 -> IO (Either WasmException Int32)) <-
    getExportedFunction store inst "run"

  result <- run 2 >>= handleException
  result @?= 6

someFunc :: s ~ PrimState IO => Caller s -> Int32 -> IO (Either Trap Int32)
someFunc caller x =  do
  putStrLn $ "> someFunc got: " <> show x
  Just (double :: Int32 -> IO (Either WasmException Int32)) <- getExportedFunctionFromCaller caller "double"
  result <- double x >>= handleException
  pure $ Right result

handleException :: Exception e => Either e r -> IO r
handleException = either throwIO pure
