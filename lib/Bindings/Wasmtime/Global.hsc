{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/global.h>

-- | <https://docs.wasmtime.dev/c-api/global_8h.html>
module Bindings.Wasmtime.Global where
#strict_import

import Bindings.Wasi
import Bindings.Wasm
import Bindings.Wasmtime.Store
import Bindings.Wasmtime.Extern
import Bindings.Wasmtime.Val
import Bindings.Wasmtime.Error

#ccall wasmtime_global_new , \
  Ptr <wasmtime_context_t> -> \
  Ptr <wasm_globaltype_t> -> \
  Ptr <wasmtime_val_t> -> \
  Ptr <wasmtime_global_t> -> \
  IO (Ptr <wasmtime_error_t>)

#ccall wasmtime_global_type , \
  Ptr <wasmtime_context_t> -> \
  Ptr <wasmtime_global_t> -> \
  IO (Ptr <wasm_globaltype_t>)

#ccall wasmtime_global_get , \
  Ptr <wasmtime_context_t> -> \
  Ptr <wasmtime_global_t> -> \
  Ptr <wasmtime_val_t> -> \
  IO ()

#ccall wasmtime_global_set , \
  Ptr <wasmtime_context_t> -> \
  Ptr <wasmtime_global_t> -> \
  Ptr <wasmtime_val_t> -> \
  IO (Ptr <wasmtime_error_t>)
