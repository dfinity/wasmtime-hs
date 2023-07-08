{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/val.h>

-- | <https://docs.wasmtime.dev/c-api/val_8h.html>
module Bindings.Wasmtime.Val where
#strict_import

import Bindings.Wasmtime.Extern
import Bindings.Wasmtime.Store
import Data.Int
import Data.WideWord.Word128 (Word128)

#opaque_t wasmtime_externref

#synonym_t wasmtime_externref_t , <wasmtime_externref>

#ccall_unsafe wasmtime_externref_new , \
  Ptr () -> \
  FunPtr (Ptr () -> IO ()) -> \
  IO (Ptr <wasmtime_externref_t>)

#ccall_unsafe wasmtime_externref_data , \
  Ptr <wasmtime_externref_t> -> IO (Ptr ())

#ccall_unsafe wasmtime_externref_clone , \
  Ptr <wasmtime_externref_t> -> IO (Ptr <wasmtime_externref_t>)

#ccall_unsafe wasmtime_externref_delete , \
  Ptr <wasmtime_externref_t> -> IO ()

#ccall_unsafe wasmtime_externref_from_raw , \
  Ptr <wasmtime_context_t> -> Ptr () -> IO (Ptr <wasmtime_externref_t>)

#ccall_unsafe wasmtime_externref_to_raw , \
  Ptr <wasmtime_context_t> -> \
  Ptr <wasmtime_externref_t> -> \
  IO (Ptr ())

#synonym_t wasmtime_valkind_t , Word8

#synonym_t wasmtime_v128 , Word128

#num WASMTIME_I32
#num WASMTIME_I64
#num WASMTIME_F32
#num WASMTIME_F64
#num WASMTIME_V128
#num WASMTIME_FUNCREF
#num WASMTIME_EXTERNREF

#starttype union wasmtime_valunion
#field i32 , Int32
#field i64 , Int64
#field f32 , Float
#field f64 , Double
#field funcref , <wasmtime_func>
#field externref , Ptr <wasmtime_externref_t>
#field v128 , <wasmtime_v128>
#stoptype

#synonym_t wasmtime_valunion_t , <wasmtime_valunion>

#starttype union wasmtime_val_raw
#field i32       , Int32
#field i64       , Int64
#field f32       , Float
#field f64       , Double
#field v128      , <wasmtime_v128>
#field funcref   , Ptr ()
#field externref , Ptr ()
#stoptype

#synonym_t wasmtime_val_raw_t , <wasmtime_val_raw>

#starttype struct wasmtime_val
#field kind , <wasmtime_valkind_t>
#field of , <wasmtime_valunion_t>
#stoptype

#synonym_t wasmtime_val_t , <wasmtime_val>

#ccall_unsafe wasmtime_val_delete , \
  Ptr <wasmtime_val_t> -> IO ()

#ccall_unsafe wasmtime_val_copy , \
  Ptr <wasmtime_val_t> -> Ptr <wasmtime_val_t> -> IO ()
