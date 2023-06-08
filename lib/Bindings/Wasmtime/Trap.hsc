{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/trap.h>

-- | <https://docs.wasmtime.dev/c-api/trap_8h.html>
module Bindings.Wasmtime.Trap where
#strict_import

import Bindings.Wasm

#synonym_t wasmtime_trap_code_t , Word8

#num WASMTIME_TRAP_CODE_STACK_OVERFLOW
#num WASMTIME_TRAP_CODE_MEMORY_OUT_OF_BOUNDS
#num WASMTIME_TRAP_CODE_HEAP_MISALIGNED
#num WASMTIME_TRAP_CODE_TABLE_OUT_OF_BOUNDS
#num WASMTIME_TRAP_CODE_INDIRECT_CALL_TO_NULL
#num WASMTIME_TRAP_CODE_BAD_SIGNATURE
#num WASMTIME_TRAP_CODE_INTEGER_OVERFLOW
#num WASMTIME_TRAP_CODE_INTEGER_DIVISION_BY_ZERO
#num WASMTIME_TRAP_CODE_BAD_CONVERSION_TO_INTEGER
#num WASMTIME_TRAP_CODE_UNREACHABLE_CODE_REACHED
#num WASMTIME_TRAP_CODE_INTERRUPT
#num WASMTIME_TRAP_CODE_OUT_OF_FUEL

#ccall wasmtime_trap_new , Ptr CChar -> CSize -> IO (Ptr <wasm_trap_t>)

#ccall wasmtime_trap_code , Ptr <wasm_trap_t> -> Ptr <wasmtime_trap_code_t> -> IO Bool

#ccall wasmtime_frame_func_name , Ptr <wasm_frame_t> -> IO (Ptr <wasm_name_t>)

#ccall wasmtime_frame_module_name , Ptr <wasm_frame_t> -> IO (Ptr <wasm_name_t>)
