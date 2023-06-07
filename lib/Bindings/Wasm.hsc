{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasm.h>

-- | Bindings to the WASM C API.
--
-- See: <https://docs.wasmtime.dev/c-api/wasm_8h.html>.
module Bindings.Wasm where
#strict_import

#opaque_t wasm_engine_t

#ccall wasm_engine_new , IO (Ptr <wasm_engine_t>)

#ccall wasm_engine_new_with_config , Ptr <wasm_config_t> -> IO (Ptr <wasm_engine_t>)

#ccall wasm_engine_delete , Ptr <wasm_engine_t> -> IO ()

#integral_t wasm_byte_t

#starttype struct wasm_byte_vec_t
#field size , CSize
#field data , Ptr <wasm_byte_t>
#stoptype

#ccall wasm_byte_vec_new_uninitialized , Ptr <wasm_byte_vec_t> -> CSize -> IO ()

#ccall wasm_byte_vec_delete , Ptr <wasm_byte_vec_t> -> IO ()

#synonym_t wasm_name_t , <wasm_byte_vec_t>

#opaque_t wasm_functype_t

#cinline wasm_functype_new_0_0 , IO (Ptr <wasm_functype_t>)

#ccall wasm_functype_new , Ptr <wasm_valtype_vec_t> -> Ptr <wasm_valtype_vec_t> -> IO (Ptr <wasm_functype_t>)

#ccall wasm_functype_delete , Ptr <wasm_functype_t> -> IO ()

#starttype struct wasm_valtype_vec_t
#field size , CSize
#field data , Ptr (Ptr <wasm_valtype_t >)
#stoptype

#ccall wasm_valtype_vec_new , Ptr <wasm_valtype_vec_t> -> CSize -> Ptr (Ptr <wasm_valtype_t>) -> IO ()
#ccall wasm_valtype_vec_delete , Ptr <wasm_valtype_vec_t> -> IO ()

#ccall wasm_valtype_new , <wasm_valkind_t> -> IO (Ptr <wasm_valtype_t>)

#ccall wasm_valtype_delete , Ptr <wasm_valtype_t> -> IO ()

#starttype struct wasm_functype_vec_t
#field size , CSize
#field data , Ptr (Ptr <wasm_functype_t>)
#stoptype

#ccall wasm_functype_vec_new , Ptr <wasm_functype_vec_t> -> CSize -> Ptr <wasm_functype_t> -> IO ()

#synonym_t wasm_valkind_t , Word8

#opaque_t wasm_valtype_t

#opaque_t wasm_externtype_t

#starttype struct wasm_importtype_vec_t
#field size , CSize
#field data , Ptr (Ptr <wasm_importtype_t>)
#stoptype

#opaque_t wasm_importtype_t

#starttype struct wasm_exporttype_vec_t
#field size , CSize
#field data , Ptr (Ptr <wasm_exporttype_t>)
#stoptype

#opaque_t wasm_exporttype_t

#opaque_t wasm_config_t

#ccall wasm_config_new , IO (Ptr <wasm_config_t>)

#ccall wasm_config_delete , Ptr <wasm_config_t> -> IO ()

#ccall wasm_functype_params , Ptr <wasm_functype_t> -> IO (Ptr <wasm_valtype_vec_t)
#ccall wasm_functype_results , Ptr <wasm_functype_t> -> IO (Ptr <wasm_valtype_vec_t)
#ccall wasm_valtype_kind , Ptr <wasm_valtype_t> -> IO (<wasm_valkind_t>)

#synonym_t wasm_message_t , <wasm_byte_vec_t>

--------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------

#opaque_t wasm_frame_t

#starttype struct wasm_frame_vec_t
#field size , CSize
#field data , Ptr (Ptr <wasm_frame_t>)
#stoptype

#ccall wasm_frame_delete , Ptr <wasm_frame_t> -> IO ()

#ccall wasm_frame_vec_new_empty , Ptr <wasm_frame_vec_t> -> IO ()

#ccall wasm_frame_vec_new_uninitialized , Ptr <wasm_frame_vec_t> -> CSize -> IO ()

#ccall wasm_frame_vec_new , Ptr <wasm_frame_vec_t> -> CSize -> Ptr <wasm_frame_t> -> IO ()

#ccall wasm_frame_vec_copy , Ptr <wasm_frame_vec_t> -> Ptr <wasm_frame_vec_t> -> IO ()

#ccall wasm_frame_vec_delete , Ptr <wasm_frame_vec_t> -> IO ()

#ccall wasm_frame_copy , Ptr <wasm_frame_t> -> IO (Ptr <wasm_frame_t>)

#ccall wasm_frame_func_index , Ptr <wasm_frame_t> -> IO Word32

#ccall wasm_frame_func_offset , Ptr <wasm_frame_t> -> IO Word32

#ccall wasm_frame_module_offset , Ptr <wasm_frame_t> -> IO Word32

--------------------------------------------------------------------------------
-- Traps
--------------------------------------------------------------------------------

#opaque_t wasm_trap_t

#ccall wasm_trap_delete , Ptr <wasm_trap_t> -> IO ()

#ccall wasm_trap_copy , Ptr <wasm_trap_t> -> IO (Ptr <wasm_trap_t>)

#ccall wasm_trap_message , Ptr <wasm_trap_t> -> Ptr <wasm_message_t> -> IO ()

#ccall wasm_trap_origin , Ptr <wasm_trap_t> -> IO (Ptr <wasm_frame_t>)

#ccall wasm_trap_trace , Ptr <wasm_trap_t> -> Ptr <wasm_frame_vec_t> -> IO ()
