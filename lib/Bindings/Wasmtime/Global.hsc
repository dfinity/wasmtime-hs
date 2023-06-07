{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/extern.h>

-- | <https://docs.wasmtime.dev/c-api/global_8h.html>
module Bindings.Wasmtime.Global where
#strict_import

import Bindings.Wasm
import Bindings.Wasmtime.Store
import Data.Word (Word8, Word64)

#ccall wasmtime_global_new ,  Ptr <wasmtime_context_t> -> Ptr <wasm_globaltype_new> -> Ptr <wasmtime_val_t> -> Ptr <wasmtime_global_t> -> IO (Ptr <wasmtime_error_t>)
#ccall wasmtime_global_type , Ptr <wasmtime_context_t> -> Ptr <wasmtime_global_t> ->                                                      IO (Ptr <wasm_globaltype_t>)
#ccall wasmtime_global_get ,  Ptr <wasmtime_context_t> -> Ptr <wasmtime_global_t> -> Ptr <wasmtime_val_t> ->                              IO ()
#ccall wasmtime_global_set ,  Ptr <wasmtime_context_t> -> Ptr <wasmtime_global_t> -> Ptr <wasmtime_val_t> ->                              IO (Ptr <wasmtime_error_t>)
