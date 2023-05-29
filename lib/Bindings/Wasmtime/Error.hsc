{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/error.h>

-- | <https://docs.wasmtime.dev/c-api/error_8h.html>
module Bindings.Wasmtime.Error where
#strict_import

import Bindings.Wasm

#opaque_t wasmtime_error_t

#ccall wasmtime_error_delete , Ptr <wasmtime_error_t> -> IO ()

#ccall wasmtime_error_message , Ptr <wasmtime_error_t> -> Ptr <wasm_name_t> -> IO ()
