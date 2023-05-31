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

#ccall wasmtime_store_new , \
  Ptr <wasm_engine_t> -> \
  Ptr a -> \
  FunPtr (Ptr a -> IO ()) -> \
  IO (Ptr <wasmtime_store_t>)

#ccall wasmtime_store_context , Ptr <wasmtime_store_t> -> IO (Ptr <wasmtime_context_t>)

#ccall wasmtime_store_limiter , \
  Ptr <wasmtime_store_t> -> \
  Int64 -> \
  Int64 -> \
  Int64 -> \
  Int64 -> \
  Int64 -> \
  IO ()

#ccall wasmtime_store_delete , Ptr <wasmtime_store_t> -> IO ()

#ccall wasmtime_context_get_data , \
  Ptr <wasmtime_context_t> -> IO (Ptr ())

#ccall wasmtime_context_set_data , \
  Ptr <wasmtime_context_t> -> Ptr () -> IO ()

#ccall wasmtime_context_gc , \
  Ptr <wasmtime_context_t> -> IO ()

#ccall wasmtime_context_add_fuel , \
  Ptr <wasmtime_context_t> -> Word64 -> IO (Ptr <wasmtime_error_t>)

#ccall wasmtime_context_fuel_consumed ,\
  Ptr <wasmtime_context_t> -> Ptr Word64 -> IO Bool

-- Specified in docs but not present in libwasmtime
-- #ccall wasmtime_context_fuel_remaining , \
--   Ptr <wasmtime_context_t> -> Ptr Word64 -> IO Bool

#ccall wasmtime_context_consume_fuel , \
  Ptr <wasmtime_context_t> -> Word64 -> Ptr Word64 -> IO (Ptr <wasmtime_error_t>)

#ccall wasmtime_context_set_wasi, \
  Ptr <wasmtime_context_t> -> Ptr <wasi_config_t> -> IO (Ptr <wasmtime_error_t>)

#ccall wasmtime_context_set_epoch_deadline , \
  Ptr <wasmtime_context_t> -> Word64 -> IO ()

-- Specified in docs but not present in libwasmtime
-- #ccall wasmtime_store_epoch_deadline_callback , \
--   Ptr <wasmtime_store_t> ->\
--   FunPtr (Ptr <wasmtime_context_t> -> Ptr () -> Ptr Word64 -> IO (Ptr <wasmtime_error_t>)) -> \
--   Ptr () \
--   -> IO ()
