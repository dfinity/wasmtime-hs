{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/error.h>

-- | <https://docs.wasmtime.dev/c-api/error_8h.html>
module Bindings.Wasmtime.Error where
#strict_import

import Bindings.Wasm

#opaque_t wasmtime_error

#synonym_t wasmtime_error_t , <wasmtime_error>

#ccall_unsafe wasmtime_error_delete , Ptr <wasmtime_error_t> -> IO ()

#ccall_unsafe wasmtime_error_message , Ptr <wasmtime_error_t> -> Ptr <wasm_name_t> -> IO ()

#ccall_unsafe wasmtime_error_exit_status , Ptr <wasmtime_error_t> -> Ptr Int -> IO Bool

#ccall_unsafe wasmtime_error_wasm_trace , Ptr <wasmtime_error_t> -> Ptr <wasm_frame_vec_t> -> IO ()
