{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/engine.h>

-- | <https://docs.wasmtime.dev/c-api/engine_8h.html>
module Bindings.Wasmtime.Engine where
#strict_import

import Bindings.Wasm

#ccall wasmtime_engine_increment_epoch , Ptr <wasm_engine_t> -> IO ()
