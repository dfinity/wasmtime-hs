{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasi.h>

-- | <https://docs.wasmtime.dev/c-api/wasi_8h.html>
module Bindings.Wasi where
#strict_import

#opaque_t wasi_config_t
