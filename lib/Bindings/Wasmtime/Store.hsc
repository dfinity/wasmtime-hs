{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/store.h>

-- | <https://docs.wasmtime.dev/c-api/store_8h.html>
module Bindings.Wasmtime.Store where
#strict_import

import Bindings.Wasm

-- | Storage of WebAssembly objects.
--
-- See: <https://docs.wasmtime.dev/c-api/structwasmtime__store.html>
#opaque_t wasmtime_store_t

-- | Creates a new store within the specified engine.
--
-- See: <https://docs.wasmtime.dev/c-api/store_8h.html#ae8da91047bdee5022e37bcfe76024779>.
#ccall wasmtime_store_new , Ptr <wasm_engine_t> -> Ptr a -> FunPtr (Ptr a -> IO ()) -> IO (Ptr <wasmtime_store_t>)

-- | Deletes a store.
--
-- See: <https://docs.wasmtime.dev/c-api/store_8h.html#ac8d51fd98a3c469b3afadc35b31c9bdd>.
#ccall wasmtime_store_delete , Ptr <wasmtime_store_t> -> IO ()

-- | An interior pointer into a @wasmtime_store_t@ which is used as \"context\" for many functions.
--
-- See: <https://docs.wasmtime.dev/c-api/structwasmtime__context.html>.
#opaque_t wasmtime_context_t

-- | Returns the interior @wasmtime_context_t@ pointer to this store.
--
-- See: <https://docs.wasmtime.dev/c-api/store_8h.html#ad607d829009b7a087af7480ca0685fe2>.
#ccall wasmtime_store_context , Ptr <wasmtime_store_t> -> IO (Ptr <wasmtime_context_t>)
