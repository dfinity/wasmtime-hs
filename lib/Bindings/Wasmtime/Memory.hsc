{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/memory.h>

-- | <https://docs.wasmtime.dev/c-api/memory_8h.html>
module Bindings.Wasmtime.Memory where
#strict_import

import Bindings.Wasm
import Bindings.Wasmtime.Error
import Bindings.Wasmtime.Extern
import Bindings.Wasmtime.Store
import Data.Word (Word8, Word64)

#opaque_t wasm_memorytype_t 

#ccall wasmtime_memorytype_new ,     Word64 -> Bool -> Word64 -> Bool ->        IO (Ptr <wasm_memorytype_t>)
#ccall wasmtime_memorytype_minimum , Ptr <wasm_memorytype_t> ->                 IO (Word64)
#ccall wasmtime_memorytype_maximum , Ptr <wasm_memorytype_t> -> Ptr <Word64> -> IO (Bool)
#ccall wasmtime_memorytype_is64 ,    Ptr <wasm_memorytype_t> ->                 IO (Bool)

#ccall wasmtime_memory_new ,       Ptr <wasmtime_context_t> -> Ptr <wasm_memorytype_t> -> Ptr <wasmtime_memory_t> -> IO (Ptr <wasmtime_error_t>)
#ccall wasmtime_memory_type ,      Ptr <wasmtime_context_t> -> Ptr <wasmtime_memory_t> ->                            IO (Ptr <wasm_memorytype_t>)
#ccall wasmtime_memory_data ,      Ptr <wasmtime_context_t> -> Ptr <wasmtime_memory_t> ->                            IO (Ptr Word8)
#ccall wasmtime_memory_data_size , Ptr <wasmtime_context_t> -> Ptr <wasmtime_memory_t> ->                            IO (CSize)
#ccall wasmtime_memory_size ,      Ptr <wasmtime_context_t> -> Ptr <wasmtime_memory_t> ->                            IO (Word64)
#ccall wasmtime_memory_grow ,      Ptr <wasmtime_context_t> -> Ptr <wasmtime_memory_t> -> Word64 -> Ptr Word64 ->    IO (Ptr <wasmtime_error_t>)
