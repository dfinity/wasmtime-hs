{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/module.h>

-- | <https://docs.wasmtime.dev/c-api/module_8h.html>
module Bindings.Wasmtime.Module where
#strict_import

import Bindings.Wasm
import Bindings.Wasmtime.Error

-- | A compiled Wasmtime module.
--
-- See: <https://docs.wasmtime.dev/c-api/structwasmtime__module.html>.
#opaque_t wasmtime_module_t

-- | Compiles a WebAssembly binary into a @wasmtime_module_t@.
--
-- See: <https://docs.wasmtime.dev/c-api/module_8h.html#aa9ce0ce436f27b54ccacf044d346776a>.
#ccall wasmtime_module_new , Ptr <wasm_engine_t> -> Ptr Word8 -> CSize -> Ptr (Ptr <wasmtime_module_t>) -> IO (Ptr <wasmtime_error_t>)


-- | Deletes a module.
--
-- See: <https://docs.wasmtime.dev/c-api/module_8h.html#ae903f562628cf2c342dfb30b9ac714b6>.
#ccall wasmtime_module_delete , Ptr <wasmtime_module_t> -> IO ()
