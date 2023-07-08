{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/extern.h>

-- | <https://docs.wasmtime.dev/c-api/extern_8h.html>
module Bindings.Wasmtime.Extern where
#strict_import

import Bindings.Wasm
import Bindings.Wasmtime.Store
import Data.Word (Word64)

#starttype struct wasmtime_func
#field store_id , Word64
#field index    , CSize
#stoptype

#synonym_t wasmtime_func_t , <wasmtime_func>

#starttype struct wasmtime_table
#field store_id , Word64
#field index    , CSize
#stoptype

#synonym_t wasmtime_table_t , <wasmtime_table>

#starttype struct wasmtime_memory
#field store_id , Word64
#field index    , CSize
#stoptype

#synonym_t wasmtime_memory_t , <wasmtime_memory>

#starttype struct wasmtime_global
#field store_id , Word64
#field index    , CSize
#stoptype

#synonym_t wasmtime_global_t , <wasmtime_global>

#synonym_t wasmtime_extern_kind_t , Word8

#num WASMTIME_EXTERN_FUNC
#num WASMTIME_EXTERN_GLOBAL
#num WASMTIME_EXTERN_TABLE
#num WASMTIME_EXTERN_MEMORY

#starttype union wasmtime_extern_union
#field func   , <wasmtime_func_t>
#field global , <wasmtime_global_t>
#field table  , <wasmtime_table_t>
#field memory , <wasmtime_memory_t>
#stoptype

#synonym_t wasmtime_extern_union_t , <wasmtime_extern_union>

#starttype struct wasmtime_extern
#field kind , <wasmtime_extern_kind_t>
#field of , <wasmtime_extern_union_t>
#stoptype

#synonym_t wasmtime_extern_t , <wasmtime_extern>

#ccall_unsafe wasmtime_extern_delete , Ptr <wasmtime_extern_t> -> IO ()

#ccall_unsafe wasmtime_extern_type , \
  Ptr <wasmtime_context_t> -> \
  Ptr <wasmtime_extern_t> -> \
  IO (Ptr <wasm_externtype_t>)
