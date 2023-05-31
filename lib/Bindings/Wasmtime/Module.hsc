{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/module.h>

-- | <https://docs.wasmtime.dev/c-api/module_8h.html>
module Bindings.Wasmtime.Module where
#strict_import

import Bindings.Wasm
import Bindings.Wasmtime.Error

#opaque_t wasmtime_module

#synonym_t wasmtime_module_t , <wasmtime_module>

#ccall wasmtime_module_new , \
  Ptr <wasm_engine_t> -> \
  Ptr Word8 -> \
  CSize -> \
  Ptr (Ptr <wasmtime_module_t>) -> \
  IO (Ptr <wasmtime_error_t>)

#ccall wasmtime_module_delete , \
  Ptr <wasmtime_module_t> -> IO ()

#ccall wasmtime_module_clone , \
  Ptr <wasmtime_module_t> -> IO (Ptr <wasmtime_module_t>)

#ccall wasmtime_module_imports , \
  Ptr <wasmtime_module_t> -> Ptr <wasm_importtype_vec_t> -> IO ()

#ccall wasmtime_module_exports , \
  Ptr <wasmtime_module_t> -> Ptr <wasm_exporttype_vec_t> -> IO ()

#ccall wasmtime_module_validate , \
  Ptr <wasm_engine_t> -> Ptr Word8 -> CSize -> IO (Ptr <wasmtime_error_t>)

#ccall wasmtime_module_serialize , \
  Ptr <wasmtime_module_t> -> Ptr <wasm_byte_vec_t> -> IO (Ptr <wasmtime_error_t>)

#ccall wasmtime_module_deserialize , \
  Ptr <wasm_engine_t> -> \
  Ptr Word8 -> \
  CSize -> \
  Ptr (Ptr <wasmtime_module_t>) -> \
  IO (Ptr <wasmtime_error_t>)

#ccall wasmtime_module_deserialize_file , \
  Ptr <wasm_engine_t> -> \
  Ptr CChar -> \
  Ptr (Ptr <wasmtime_module_t>) -> \
  IO (Ptr <wasmtime_error_t>)
