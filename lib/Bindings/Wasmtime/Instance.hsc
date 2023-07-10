{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/instance.h>

-- | <https://docs.wasmtime.dev/c-api/instance_8h.html>
module Bindings.Wasmtime.Instance where
#strict_import

import Bindings.Wasm
import Bindings.Wasmtime.Error
import Bindings.Wasmtime.Extern
import Bindings.Wasmtime.Store
import Bindings.Wasmtime.Module
import Data.Word (Word64)

#starttype struct wasmtime_instance
#field store_id , Word64
#field index , CSize
#stoptype

#synonym_t wasmtime_instance_t , <wasmtime_instance>

#ccall wasmtime_instance_new , \
  Ptr <wasmtime_context_t> -> \
  Ptr <wasmtime_module_t> -> \
  Ptr <wasmtime_extern_t> -> \
  CSize -> \
  Ptr <wasmtime_instance_t> -> \
  Ptr (Ptr <wasm_trap_t>) -> \
  IO (Ptr <wasmtime_error_t>)

#ccall_unsafe wasmtime_instance_export_get , \
  Ptr <wasmtime_context_t> -> \
  Ptr <wasmtime_instance_t> -> \
  Ptr CChar -> \
  CSize -> \
  Ptr <wasmtime_extern_t> -> \
  IO Bool

#ccall_unsafe wasmtime_instance_export_nth  , \
  Ptr <wasmtime_context_t> -> \
  Ptr <wasmtime_instance_t> -> \
  CSize -> \
  Ptr (Ptr CChar) -> \
  Ptr CSize -> \
  Ptr <wasmtime_extern_t> -> \
  IO Bool
