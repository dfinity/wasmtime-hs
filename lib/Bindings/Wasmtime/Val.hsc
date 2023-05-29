{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/val.h>

-- | <https://docs.wasmtime.dev/c-api/val_8h.html>
module Bindings.Wasmtime.Val where
#strict_import

#num WASMTIME_I32
#num WASMTIME_I64
#num WASMTIME_F32
#num WASMTIME_F64
#num WASMTIME_V128
#num WASMTIME_FUNCREF
#num WASMTIME_EXTERNREF
