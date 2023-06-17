{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasm.h>

-- | Bindings to the WASM C API.
--
-- See: <https://docs.wasmtime.dev/c-api/wasm_8h.html>.
module Bindings.Wasm where
#strict_import

--------------------------------------------------------------------------------
-- Bytes, Names and Messages
--------------------------------------------------------------------------------

#integral_t wasm_byte_t

#starttype struct wasm_byte_vec_t
#field size , CSize
#field data , Ptr <wasm_byte_t>
#stoptype

#ccall wasm_byte_vec_new_uninitialized , Ptr <wasm_byte_vec_t> -> CSize -> IO ()

#ccall wasm_byte_vec_delete , Ptr <wasm_byte_vec_t> -> IO ()

#synonym_t wasm_name_t , <wasm_byte_vec_t>

#synonym_t wasm_message_t , <wasm_byte_vec_t>

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

#opaque_t wasm_config_t

#ccall wasm_config_new , IO (Ptr <wasm_config_t>)

#ccall wasm_config_delete , Ptr <wasm_config_t> -> IO ()

--------------------------------------------------------------------------------
-- Engine
--------------------------------------------------------------------------------

#opaque_t wasm_engine_t

#ccall wasm_engine_new , IO (Ptr <wasm_engine_t>)

#ccall wasm_engine_new_with_config , Ptr <wasm_config_t> -> IO (Ptr <wasm_engine_t>)

#ccall wasm_engine_delete , Ptr <wasm_engine_t> -> IO ()

--------------------------------------------------------------------------------
-- Val Types
--------------------------------------------------------------------------------

#starttype struct wasm_valtype_vec_t
#field size , CSize
#field data , Ptr (Ptr <wasm_valtype_t >)
#stoptype

#ccall wasm_valtype_vec_new , Ptr <wasm_valtype_vec_t> -> CSize -> Ptr (Ptr <wasm_valtype_t>) -> IO ()
#ccall wasm_valtype_vec_delete , Ptr <wasm_valtype_vec_t> -> IO ()

#ccall wasm_valtype_new , <wasm_valkind_t> -> IO (Ptr <wasm_valtype_t>)

#ccall wasm_valtype_delete , Ptr <wasm_valtype_t> -> IO ()

#synonym_t wasm_valkind_t , Word8

#opaque_t wasm_valtype_t

--------------------------------------------------------------------------------
-- Extern Types
--------------------------------------------------------------------------------

#opaque_t wasm_externtype_t

#ccall wasm_externtype_delete , Ptr <wasm_externtype_t> -> IO ()

#ccall wasm_externtype_copy , Ptr <wasm_externtype_t> -> IO (Ptr <wasm_externtype_t>)

#ccall wasm_externtype_kind , Ptr <wasm_externtype_t> -> IO <wasm_externkind_t>

#synonym_t wasm_externkind_t , Word8

#num WASM_EXTERN_FUNC
#num WASM_EXTERN_GLOBAL
#num WASM_EXTERN_TABLE
#num WASM_EXTERN_MEMORY

#ccall wasm_functype_as_externtype         , Ptr <wasm_functype_t>   -> IO (Ptr <wasm_externtype_t>)
#ccall wasm_tabletype_as_externtype        , Ptr <wasm_tabletype_t>  -> IO (Ptr <wasm_externtype_t>)
#ccall wasm_globaltype_as_externtype       , Ptr <wasm_globaltype_t> -> IO (Ptr <wasm_externtype_t>)
#ccall wasm_memorytype_as_externtype       , Ptr <wasm_memorytype_t> -> IO (Ptr <wasm_externtype_t>)

#ccall wasm_externtype_as_functype         , Ptr <wasm_externtype_t> -> IO (Ptr <wasm_functype_t>)
#ccall wasm_externtype_as_tabletype        , Ptr <wasm_externtype_t> -> IO (Ptr <wasm_tabletype_t>)
#ccall wasm_externtype_as_memorytype       , Ptr <wasm_externtype_t> -> IO (Ptr <wasm_memorytype_t>)
#ccall wasm_externtype_as_globaltype       , Ptr <wasm_externtype_t> -> IO (Ptr <wasm_globaltype_t>)

--------------------------------------------------------------------------------
-- Import Types
--------------------------------------------------------------------------------

#opaque_t wasm_importtype_t

#starttype struct wasm_importtype_vec_t
#field size , CSize
#field data , Ptr (Ptr <wasm_importtype_t>)
#stoptype

#ccall wasm_importtype_delete , Ptr <wasm_importtype_t> -> IO ()

#ccall wasm_importtype_vec_delete , Ptr <wasm_importtype_vec_t> -> IO ()

#ccall wasm_importtype_copy , Ptr <wasm_importtype_t> -> IO (Ptr <wasm_importtype_t>)

#ccall wasm_importtype_module , Ptr <wasm_importtype_t> -> IO (Ptr <wasm_name_t>)

#ccall wasm_importtype_name , Ptr <wasm_importtype_t> -> IO (Ptr <wasm_name_t>)

#ccall wasm_importtype_type , Ptr <wasm_importtype_t> -> IO (Ptr <wasm_externtype_t>)

--------------------------------------------------------------------------------
-- Export Types
--------------------------------------------------------------------------------

#opaque_t wasm_exporttype_t

#starttype struct wasm_exporttype_vec_t
#field size , CSize
#field data , Ptr (Ptr <wasm_exporttype_t>)
#stoptype

#ccall wasm_exporttype_delete , Ptr <wasm_exporttype_t> -> IO ()

#ccall wasm_exporttype_vec_delete , Ptr <wasm_exporttype_vec_t> -> IO ()

#ccall wasm_exporttype_copy , Ptr <wasm_exporttype_t> -> IO (Ptr <wasm_exporttype_t>)

#ccall wasm_exporttype_name , Ptr <wasm_exporttype_t> -> IO (Ptr <wasm_name_t>)

#ccall wasm_exporttype_type , Ptr <wasm_exporttype_t> -> IO (Ptr <wasm_externtype_t>)

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

--------------------------------------------------------------------------------
-- Func Types
--------------------------------------------------------------------------------

#opaque_t wasm_functype_t

#starttype struct wasm_functype_vec_t
#field size , CSize
#field data , Ptr (Ptr <wasm_functype_t>)
#stoptype

#ccall wasm_functype_delete , Ptr <wasm_functype_t> -> IO ()

#ccall wasm_functype_vec_new , Ptr <wasm_functype_vec_t> -> CSize -> Ptr <wasm_functype_t> -> IO ()

#ccall wasm_functype_new , Ptr <wasm_valtype_vec_t> -> Ptr <wasm_valtype_vec_t> -> IO (Ptr <wasm_functype_t>)

#cinline wasm_functype_new_0_0 , IO (Ptr <wasm_functype_t>)

#ccall wasm_functype_copy , Ptr <wasm_functype_t> -> IO (Ptr <wasm_functype_t>)

#ccall wasm_functype_params , Ptr <wasm_functype_t> -> IO (Ptr <wasm_valtype_vec_t)
#ccall wasm_functype_results , Ptr <wasm_functype_t> -> IO (Ptr <wasm_valtype_vec_t)
#ccall wasm_valtype_kind , Ptr <wasm_valtype_t> -> IO (<wasm_valkind_t>)

--------------------------------------------------------------------------------
-- Global Types
--------------------------------------------------------------------------------

#opaque_t wasm_globaltype_t

#starttype struct wasm_globaltype_vec_t
#field size , CSize
#field data , Ptr (Ptr <wasm_globaltype_t >)
#stoptype

#ccall wasm_globaltype_delete , Ptr <wasm_globaltype_t> -> IO ()

#ccall wasm_globaltype_vec_new_empty , Ptr <wasm_globaltype_vec_t> -> IO ()

#ccall wasm_globaltype_vec_new_uninitialized , Ptr <wasm_globaltype_vec_t> -> CSize -> IO ()

#ccall wasm_globaltype_vec_new , Ptr <wasm_globaltype_vec_t> -> CSize -> Ptr <wasm_globaltype_t> -> IO ()

#ccall wasm_globaltype_vec_copy , Ptr <wasm_globaltype_vec_t> -> Ptr <wasm_globaltype_vec_t> -> IO ()

#ccall wasm_globaltype_vec_delete , Ptr <wasm_globaltype_vec_t> -> IO ()

#ccall wasm_globaltype_copy , Ptr <wasm_globaltype_t> -> IO (Ptr <wasm_globaltype_t>)

#ccall wasm_globaltype_new , Ptr <wasm_valtype_t> -> <wasm_mutability_t> -> IO (Ptr <wasm_globaltype_t>)

#ccall wasm_globaltype_content , Ptr <wasm_globaltype_t> -> IO (Ptr <wasm_valtype_t>)

#ccall wasm_globaltype_mutability , Ptr <const wasm_globaltype_t> -> IO <wasm_mutability_t>

#synonym_t wasm_mutability_t , Word8

--------------------------------------------------------------------------------
-- Table Types
--------------------------------------------------------------------------------

#opaque_t wasm_tabletype_t

#ccall wasm_tabletype_new , Ptr <wasm_valtype_t> -> Ptr <wasm_limits_t> -> IO (Ptr <wasm_tabletype_t>)
#ccall wasm_tabletype_element , Ptr <wasm_tabletype_t> ->                  IO (Ptr <wasm_valtype_t>)
#ccall wasm_tabletype_limits ,  Ptr <wasm_tabletype_t> ->                  IO (Ptr <wasm_limits_t>)
#ccall wasm_tabletype_delete ,  Ptr <wasm_tabletype_t> ->                  IO ()

#ccall wasm_tabletype_copy , Ptr <wasm_tabletype_t> -> IO (Ptr <wasm_tabletype_t>)

#starttype struct wasm_limits_t
#field min , CSize
#field max , CSize
#stoptype

#num wasm_limits_max_default

--------------------------------------------------------------------------------
-- Memory types
--------------------------------------------------------------------------------

#opaque_t wasm_memorytype_t

#ccall wasm_memorytype_delete , Ptr <wasm_memorytype_t> -> IO ()

#ccall wasm_memorytype_copy , Ptr <wasm_memorytype_t> -> IO (Ptr <wasm_memorytype_t>)
