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

#ccall_unsafe wasmtime_table_new ,  Ptr <wasmtime_context_t> -> Ptr <wasm_tabletype_t> -> Ptr <wasmtime_val_t> -> Ptr <wasmtime_table_t> -> IO (Ptr <wasmtime_error_t>)
#ccall_unsafe wasmtime_table_type , Ptr <wasmtime_context_t> -> Ptr <wasmtime_table_t> ->                                                   IO (Ptr <wasm_tabletype_t>)
#ccall_unsafe wasmtime_table_get ,  Ptr <wasmtime_context_t> -> Ptr <wasmtime_table_t> -> Word32 -> Ptr <wasmtime_val_t> ->                 IO (Bool)
#ccall_unsafe wasmtime_table_set ,  Ptr <wasmtime_context_t> -> Ptr <wasmtime_table_t> -> Word32 -> Ptr <wasmtime_val_t> ->                 IO (Ptr <wasmtime_error_t>)
#ccall_unsafe wasmtime_table_size , Ptr <wasmtime_context_t> -> Ptr <wasmtime_table_t> ->                                                   IO (Word32)
#ccall_unsafe wasmtime_table_grow , Ptr <wasmtime_context_t> -> Ptr <wasmtime_table_t> -> Word32 -> Ptr <wasmtime_val_t> -> Ptr Word32 ->   IO (Ptr <wasmtime_error_t>)
