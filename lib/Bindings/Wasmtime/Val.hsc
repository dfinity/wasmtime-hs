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

#starttype struct wasmtime_anyref
#field store_id   , Word64
#field __private1 , Word32
#field __private2 , Word32
#stoptype

#synonym_t wasmtime_anyref_t , <wasmtime_anyref>

#starttype struct wasmtime_externref
#field store_id   , Word64
#field __private1 , Word32
#field __private2 , Word32
#stoptype

#synonym_t wasmtime_externref_t , <wasmtime_externref>

#synonym_t wasmtime_valkind_t , Word8

#synonym_t wasmtime_v128 , Word128

#num WASMTIME_I32
#num WASMTIME_I64
#num WASMTIME_F32
#num WASMTIME_F64
#num WASMTIME_V128
#num WASMTIME_FUNCREF
#num WASMTIME_EXTERNREF
#num WASMTIME_ANYREF

#starttype union wasmtime_valunion
#field i32 , Int32
#field i64 , Int64
#field f32 , Float
#field f64 , Double
#field anyref , <wasmtime_anyref_t>
#field externref , <wasmtime_externref_t>
#field funcref , <wasmtime_func_t>
#field v128 , <wasmtime_v128>
#stoptype

#synonym_t wasmtime_valunion_t , <wasmtime_valunion>

#starttype union wasmtime_val_raw
#field i32       , Int32
#field i64       , Int64
#field f32       , Float
#field f64       , Double
#field v128      , <wasmtime_v128>
#field anyref    , Word32
#field externref , Word32
#field funcref   , Ptr ()
#stoptype

#synonym_t wasmtime_val_raw_t , <wasmtime_val_raw>

#starttype struct wasmtime_val
#field kind , <wasmtime_valkind_t>
#field of , <wasmtime_valunion_t>
#stoptype

#synonym_t wasmtime_val_t , <wasmtime_val>
