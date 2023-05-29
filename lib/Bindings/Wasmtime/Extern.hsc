{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/extern.h>

-- | <https://docs.wasmtime.dev/c-api/extern_8h.html>
module Bindings.Wasmtime.Extern where
#strict_import

#opaque_t wasmtime_func_t
