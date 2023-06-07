{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

-- | Demo on how to use wasmtime within the ST monad.
module Main (main) where

import Control.Exception (Exception, throwIO)
import Control.Monad.ST (ST, runST)
import qualified Data.ByteString as B
import Data.STRef
import Paths_wasmtime (getDataFileName)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import Wasmtime

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering

  putStrLn "Initializing..."
  engine <- newEngine

  helloWatPath <- getDataFileName "test/hello.wat"
  watBytes <- B.readFile helloWatPath

  wasm :: Wasm <- handleException $ wat2wasm watBytes

  myModule :: Module <- handleException $ newModule engine wasm

  let x :: Int
      x = runST (st engine myModule)

  print x

st :: forall s. Engine -> Module -> ST s Int
st engine myModule = do
  store :: Store s <- newStore engine

  ctx :: Context s <- storeContext store

  stRef :: STRef s Int <- newSTRef 1

  func :: Func s <- newFunc ctx $ inc stRef

  inst :: Instance s <- newInstance ctx myModule [toExtern func]

  Just (runTypedFunc :: TypedFunc s (ST s (Either Trap ()))) <-
    getExportedTypedFunc ctx inst "run"

  Right () <- callFunc ctx runTypedFunc

  readSTRef stRef

inc :: STRef s Int -> ST s (Either Trap ())
inc stRef = Right <$> modifySTRef stRef (+ 1)

handleException :: Exception e => Either e r -> IO r
handleException = either throwIO pure
