{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/val.h>

-- | <https://docs.wasmtime.dev/c-api/val_8h.html>
module Bindings.Wasmtime.Val where
#strict_import

import Bindings.Wasmtime.Extern
import Data.Int
import Data.WideWord.Word128 (Word128)

#num WASMTIME_I32
#num WASMTIME_I64
#num WASMTIME_F32
#num WASMTIME_F64
#num WASMTIME_V128
#num WASMTIME_FUNCREF
#num WASMTIME_EXTERNREF

#synonym_t wasmtime_valkind_t , Word8

#starttype struct wasmtime_val
#field kind , <wasmtime_valkind_t>
#field of , <wasmtime_valunion_t>
#stoptype

#synonym_t wasmtime_val_t , <wasmtime_val>

#starttype union wasmtime_valunion
#field i32 , Int32
#field i64 , Int64
#field f32 , Float
#field f64 , Double
#field funcref , <wasmtime_func>
#field externref , Ptr <wasmtime_externref_t>
#field v128 , Word128
#stoptype

#synonym_t wasmtime_valunion_t , <wasmtime_valunion>

#starttype union wasmtime_val_raw
#field i32       , Int32
#field i64       , Int64
#field f32       , Float
#field f64       , Double
#field v128      , Word128
#field funcref   , Ptr ()
#field externref , Ptr ()
#stoptype

#synonym_t wasmtime_val_raw_t , <wasmtime_val_raw>

#opaque_t wasmtime_externref_t
