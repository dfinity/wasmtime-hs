{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime.h>

-- | <https://docs.wasmtime.dev/c-api/store_8h.html>
module Bindings.Wasmtime where
#strict_import

import Bindings.Wasm
import Bindings.Wasmtime.Error

#num WASMTIME_VERSION_MAJOR
#num WASMTIME_VERSION_MINOR
#num WASMTIME_VERSION_PATCH

-- | Converts from the text format of WebAssembly to to the binary format.
--
-- See: <https://docs.wasmtime.dev/c-api/wasmtime_8h.html#af249de0b85489a54e725a27fbdd44629>.
#ccall wasmtime_wat2wasm , Ptr CChar -> CSize -> Ptr <wasm_byte_vec_t> -> IO (Ptr <wasmtime_error_t>)
