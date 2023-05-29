{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/store.h>

-- | <https://docs.wasmtime.dev/c-api/store_8h.html>
module Bindings.Wasmtime.Store where
#strict_import

import Bindings.Wasm

#opaque_t wasmtime_store_t

#ccall wasmtime_store_new , \
  Ptr <wasm_engine_t> -> \
  Ptr a -> \
  FunPtr (Ptr a -> IO ()) -> \
  IO (Ptr <wasmtime_store_t>)

#ccall wasmtime_store_delete , Ptr <wasmtime_store_t> -> IO ()

#opaque_t wasmtime_context_t

#ccall wasmtime_store_context , Ptr <wasmtime_store_t> -> IO (Ptr <wasmtime_context_t>)
