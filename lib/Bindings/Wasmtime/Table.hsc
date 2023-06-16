{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/table.h>

-- | <https://docs.wasmtime.dev/c-api/table_8h.html>
module Bindings.Wasmtime.Table where
#strict_import

import Bindings.Wasi
import Bindings.Wasm
import Bindings.Wasmtime.Error
import Bindings.Wasmtime.Store
import Bindings.Wasmtime.Extern
import Bindings.Wasmtime.Val
import Data.Word (Word32, Word64)

#opaque_t wasm_tabletype_t

#ccall wasm_tabletype_new , Ptr <wasm_valtype_t> -> Ptr <wasm_limits_t> -> IO (Ptr <wasm_tabletype_t>)
#ccall wasm_tabletype_element , Ptr <wasm_tabletype_t> ->                  IO (Ptr <wasm_valtype_t>)
#ccall wasm_tabletype_limits ,  Ptr <wasm_tabletype_t> ->                  IO (Ptr <wasm_limits_t>)
#ccall wasm_tabletype_delete ,  Ptr <wasm_tabletype_t> ->                  IO ()

#ccall wasmtime_table_new ,  Ptr <wasmtime_context_t> -> Ptr <wasm_tabletype_t> -> Ptr <wasmtime_val_t> -> Ptr <wasmtime_table_t> -> IO (Ptr <wasmtime_error_t>)
#ccall wasmtime_table_type , Ptr <wasmtime_context_t> -> Ptr <wasmtime_table_t> ->                                                   IO (Ptr <wasm_tabletype_t>)
#ccall wasmtime_table_get ,  Ptr <wasmtime_context_t> -> Ptr <wasmtime_table_t> -> Word32 -> Ptr <wasmtime_val_t> ->                 IO (Bool)
#ccall wasmtime_table_set ,  Ptr <wasmtime_context_t> -> Ptr <wasmtime_table_t> -> Word32 -> Ptr <wasmtime_val_t> ->                 IO (Ptr <wasmtime_error_t>)
#ccall wasmtime_table_size , Ptr <wasmtime_context_t> -> Ptr <wasmtime_table_t> ->                                                   IO (Word32)
#ccall wasmtime_table_grow , Ptr <wasmtime_context_t> -> Ptr <wasmtime_table_t> -> Word32 -> Ptr <wasmtime_val_t> -> Ptr Word32 ->   IO (Ptr <wasmtime_error_t>)
