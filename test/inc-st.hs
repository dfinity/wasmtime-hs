{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

-- | Demo on how to use wasmtime within the ST monad.
module Main (main) where

import Control.Exception (Exception, throwIO)
import Control.Monad.ST (ST, runST)
import qualified Data.ByteString as B
import Data.STRef
import Paths_wasmtime_hs (getDataFileName)
import Test.Tasty.HUnit ((@?=))
import Wasmtime

main :: IO ()
main = do
  putStrLn "Initializing..."
  engine <- newEngine

  helloWatPath <- getDataFileName "test/hello.wat"
  watBytes <- B.readFile helloWatPath

  wasm :: Wasm <- handleException $ wat2wasm watBytes

  myModule :: Module <- handleException $ newModule engine wasm

  let i :: Int
      i = runST (st engine myModule)

  i @?= 2

st :: forall s. Engine -> Module -> ST s Int
st engine myModule = do
  Right (store :: Store s) <- newStore engine

  stRef :: STRef s Int <- newSTRef 1

  func :: Func s <- newFuncUnchecked store $ inc stRef

  Right (inst :: Instance s) <- newInstance store myModule [toExtern func]

  Just (run :: ST s (Either WasmException ())) <-
    getExportedFunction store inst "run"

  Right () <- run

  readSTRef stRef

inc :: STRef s Int -> ST s (Either Trap ())
inc stRef = Right <$> modifySTRef stRef (+ 1)

handleException :: Exception e => Either e r -> IO r
handleException = either throwIO pure
