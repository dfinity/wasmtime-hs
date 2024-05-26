{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/store.h>

-- | <https://docs.wasmtime.dev/c-api/store_8h.html>
module Bindings.Wasmtime.Store where
#strict_import

import Bindings.Wasi
import Bindings.Wasm
import Bindings.Wasmtime.Error
import Data.Word (Word64)

#opaque_t wasmtime_store

#synonym_t wasmtime_store_t , <wasmtime_store>

#opaque_t wasmtime_context

#synonym_t wasmtime_context_t , <wasmtime_context>

#ccall_unsafe wasmtime_store_new , \
  Ptr <wasm_engine_t> -> \
  Ptr a -> \
  FunPtr (Ptr a -> IO ()) -> \
  IO (Ptr <wasmtime_store_t>)

#ccall_unsafe wasmtime_store_context , Ptr <wasmtime_store_t> -> IO (Ptr <wasmtime_context_t>)

#ccall_unsafe wasmtime_store_limiter , \
  Ptr <wasmtime_store_t> -> \
  Int64 -> \
  Int64 -> \
  Int64 -> \
  Int64 -> \
  Int64 -> \
  IO ()

#ccall_unsafe wasmtime_store_delete , Ptr <wasmtime_store_t> -> IO ()

#ccall_unsafe wasmtime_context_get_data , \
  Ptr <wasmtime_context_t> -> IO (Ptr ())

#ccall_unsafe wasmtime_context_set_data , \
  Ptr <wasmtime_context_t> -> Ptr () -> IO ()

#ccall_unsafe wasmtime_context_gc , \
  Ptr <wasmtime_context_t> -> IO ()

#ccall_unsafe wasmtime_context_set_fuel , \
  Ptr <wasmtime_context_t> -> Word64 -> IO (Ptr <wasmtime_error_t>)

#ccall_unsafe wasmtime_context_get_fuel , \
  Ptr <wasmtime_context_t> -> Ptr Word64 -> IO (Ptr <wasmtime_error_t>)

#ccall_unsafe wasmtime_context_set_wasi, \
  Ptr <wasmtime_context_t> -> Ptr <wasi_config_t> -> IO (Ptr <wasmtime_error_t>)

#ccall_unsafe wasmtime_context_set_epoch_deadline , \
  Ptr <wasmtime_context_t> -> Word64 -> IO ()

#ccall_unsafe wasmtime_store_epoch_deadline_callback , \
  Ptr <wasmtime_store_t> ->\
  FunPtr (Ptr <wasmtime_context_t> -> Ptr () -> Ptr Word64 -> IO (Ptr <wasmtime_error_t>)) -> \
  Ptr () \
  -> IO ()

#callback_t store_epoch_deadline_callback , \
  Ptr <wasmtime_context_t> -> \
  Ptr () -> \
  Ptr Word64 -> \
  IO (Ptr <wasmtime_error_t>)
