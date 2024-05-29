{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

-- | Demo on how to use wasmtime within the ST monad.
module Main (main) where

import Control.Exception (Exception, throwIO)
import Control.Monad.ST (ST, runST)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (ExceptT (ExceptT), runExceptT, withExceptT)
import qualified Data.ByteString as B
import Data.Maybe (fromJust)
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

  let r :: Either String Int
      r = runST (st engine myModule)

  r @?= Right 2

st :: forall s. Engine -> Module -> ST s (Either String Int)
st engine myModule = runExceptT $ do
  store :: Store s <- withExceptT show $ ExceptT $ newStore engine

  stRef :: STRef s Int <- lift $ newSTRef 1

  func :: Func s <- lift $ newFuncUnchecked store $ inc stRef

  inst :: Instance s <- withExceptT show $ ExceptT $ newInstance store myModule [toExtern func]

  run :: ST s (Either WasmException ()) <-
    lift $
      fromJust <$> getExportedFunction store inst "run"

  withExceptT show $ ExceptT $ run

  lift $ readSTRef stRef

inc :: STRef s Int -> ST s (Either Trap ())
inc stRef = Right <$> modifySTRef stRef (+ 1)

handleException :: (Exception e) => Either e r -> IO r
handleException = either throwIO pure
