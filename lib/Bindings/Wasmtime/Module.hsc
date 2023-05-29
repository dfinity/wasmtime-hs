{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/module.h>

-- | <https://docs.wasmtime.dev/c-api/module_8h.html>
module Bindings.Wasmtime.Module where
#strict_import

import Bindings.Wasm
import Bindings.Wasmtime.Error

#opaque_t wasmtime_module_t

#ccall wasmtime_module_new , \
  Ptr <wasm_engine_t> -> \
  Ptr Word8 -> \
  CSize -> \
  Ptr (Ptr <wasmtime_module_t>) -> \
  IO (Ptr <wasmtime_error_t>)

#ccall wasmtime_module_delete , Ptr <wasmtime_module_t> -> IO ()
