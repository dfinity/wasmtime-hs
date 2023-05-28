{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasm.h>

-- | Bindings to the WASM C API.
--
-- See: <https://docs.wasmtime.dev/c-api/wasm_8h.html>.
module Bindings.Wasm where
#strict_import

-- | Compilation environment and configuration.
--
-- See: <https://docs.wasmtime.dev/c-api/structwasm__engine__t.html>.
#opaque_t wasm_engine_t

-- | Creates a new engine with the default configuration.
--
-- See: <https://docs.wasmtime.dev/c-api/wasm_8h.html#a4fd2b09177e1160bef3acc277b2e1a83>.
#ccall wasm_engine_new , IO (Ptr <wasm_engine_t>)

-- | Deletes an engine.
--
-- <https://docs.wasmtime.dev/c-api/wasm_8h.html#a32ad13942474e27dea2df9d7345d11c6>.
#ccall wasm_engine_delete , Ptr <wasm_engine_t> -> IO ()

-- | A type definition for a number that occupies a single byte of data.
--
-- See: <https://docs.wasmtime.dev/c-api/wasm_8h.html#ae4abba49d0f5afb561fa8051fa8abe66>.
#integral_t wasm_byte_t

#starttype struct wasm_byte_vec_t
#field size , CSize
#field data , Ptr <wasm_byte_t>
#stoptype

-- | Initializes a byte vector with the specified capacity.
--
-- See: <https://docs.wasmtime.dev/c-api/wasm_8h.html#a738d4aaf2c41bc26fadc75cdf08de3be>.
#ccall wasm_byte_vec_new_uninitialized , Ptr <wasm_byte_vec_t> -> CSize -> IO ()

-- | Deletes a byte vector.
--
-- See: <https://docs.wasmtime.dev/c-api/wasm_8h.html#a8440e3864cec0bbe80ce33378f73a122>.
#ccall wasm_byte_vec_delete , Ptr <wasm_byte_vec_t> -> IO ()

-- | Convenience for hinting that an argument only accepts utf-8 input.
--
-- See: <https://docs.wasmtime.dev/c-api/wasm_8h.html#a5a6e9ac85b29c62a9fb679a974a7cdaa>.
#synonym_t wasm_name_t , <wasm_byte_vec_t>

-- | An opaque object representing the type of a function.
--
-- See: <https://docs.wasmtime.dev/c-api/structwasm__functype__t.html>.
#opaque_t wasm_functype_t

#cinline wasm_functype_new_0_0 , IO (Ptr <wasm_functype_t>)

-- | Deletes a type.
--
-- See: <https://docs.wasmtime.dev/c-api/wasm_8h.html#a37522fa30054f355ae3f58b28a884e7a>.
#ccall wasm_functype_delete , Ptr <wasm_functype_t> -> IO ()
