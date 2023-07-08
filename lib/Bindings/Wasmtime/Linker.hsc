{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/func.h>

-- | <https://docs.wasmtime.dev/c-api/linker_8h.html>
module Bindings.Wasmtime.Linker where
#strict_import

import Bindings.Wasm
import Bindings.Wasmtime.Error
import Bindings.Wasmtime.Extern
import Bindings.Wasmtime.Store
import Bindings.Wasmtime.Func
import Bindings.Wasmtime.Instance
import Bindings.Wasmtime.Module

#opaque_t wasmtime_linker

#synonym_t wasmtime_linker_t , <wasmtime_linker>

#ccall_unsafe wasmtime_linker_new , Ptr <wasm_engine_t> -> IO (Ptr <wasmtime_linker_t>)

#ccall_unsafe wasmtime_linker_delete , Ptr <wasmtime_linker_t> -> IO ()

#ccall_unsafe wasmtime_linker_allow_shadowing , Ptr <wasmtime_linker_t> -> Bool -> IO ()

#ccall_unsafe wasmtime_linker_define , \
  Ptr <wasmtime_linker_t> -> \
  Ptr <wasmtime_context_t> -> \
  Ptr CChar -> \
  CSize -> \
  Ptr CChar -> \
  CSize -> \
  Ptr <wasmtime_extern_t> -> \
  IO (Ptr <wasmtime_error_t>)

#ccall_unsafe wasmtime_linker_define_func , \
  Ptr <wasmtime_linker_t> -> \
  Ptr CChar -> \
  CSize -> \
  Ptr CChar -> \
  CSize -> \
  Ptr <wasm_functype_t> -> \
  <wasmtime_func_callback_t> -> \
  Ptr () -> \
  FunPtr (Ptr () -> IO ()) -> \
  IO (Ptr <wasmtime_error_t>)

#ccall_unsafe wasmtime_linker_define_func_unchecked , \
  Ptr <wasmtime_linker_t> -> \
  Ptr CChar -> \
  CSize -> \
  Ptr CChar -> \
  CSize -> \
  Ptr <wasm_functype_t> -> \
  <wasmtime_func_unchecked_callback_t> -> \
  Ptr () -> \
  FunPtr (Ptr () -> IO ()) -> \
  IO (Ptr <wasmtime_error_t>)

#ccall_unsafe wasmtime_linker_define_wasi , \
  Ptr <wasmtime_linker_t> -> \
  IO (Ptr <wasmtime_error_t>)

#ccall_unsafe wasmtime_linker_define_instance , \
  Ptr <wasmtime_linker_t> -> \
  Ptr <wasmtime_context_t> -> \
  Ptr CChar -> \
  CSize -> \
  Ptr <wasmtime_instance_t> -> \
  IO (Ptr <wasmtime_error_t>)

#ccall wasmtime_linker_instantiate , \
  Ptr <wasmtime_linker_t> -> \
  Ptr <wasmtime_context_t> -> \
  Ptr <wasmtime_module_t> -> \
  Ptr <wasmtime_instance_t> -> \
  Ptr (Ptr <wasm_trap_t>) -> \
  IO (Ptr <wasmtime_error_t>)

#ccall_unsafe wasmtime_linker_module , \
  Ptr <wasmtime_linker_t> -> \
  Ptr <wasmtime_context_t> -> \
  Ptr CChar -> \
  CSize -> \
  Ptr <wasmtime_module_t> -> \
  IO (Ptr <wasmtime_error_t>)

#ccall_unsafe wasmtime_linker_get_default , \
  Ptr <wasmtime_linker_t> -> \
  Ptr <wasmtime_context_t> -> \
  Ptr CChar -> \
  CSize -> \
  Ptr <wasmtime_func_t> -> \
  IO (Ptr <wasmtime_error_t>)

#ccall_unsafe wasmtime_linker_get , \
  Ptr <wasmtime_linker_t> -> \
  Ptr <wasmtime_context_t> -> \
  Ptr CChar -> \
  CSize -> \
  Ptr CChar -> \
  CSize -> \
  Ptr <wasmtime_extern_t> -> \
  IO Bool
