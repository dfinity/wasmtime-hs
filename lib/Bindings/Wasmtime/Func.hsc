{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/func.h>

-- | <https://docs.wasmtime.dev/c-api/func_8h.html>
module Bindings.Wasmtime.Func where
#strict_import

import Bindings.Wasm
import Bindings.Wasmtime.Extern
import Bindings.Wasmtime.Val
import Bindings.Wasmtime.Store

-- FIXME: the Ptr in the return type triggers the warning:
--
--   var/folders/7_/m1k33c791pz5v9nt2bdd89d80000gn/T/ghc91762_0/ghc_3.c:19:17: error:
--        warning: incompatible pointer to integer conversion assigning to 'ffi_arg' (aka 'unsigned long') from 'HsPtr' (aka 'void *') [-Wint-conversion]
--      |
--   19 | *(ffi_arg*)resp = cret;
--      |                 ^
--   *(ffi_arg*)resp = cret;
--                   ^ ~~~~
-- I don't know why so I asked here:
-- https://discourse.haskell.org/t/ffi-incompatible-pointer-to-integer-conversion/6339
-- and filed a GHC issue: https://gitlab.haskell.org/ghc/ghc/-/issues/23456

#callback_t wasmtime_func_callback_t , \
  Ptr () -> \
  Ptr <wasmtime_caller_t> -> \
  Ptr <wasmtime_val_t> -> \
  CSize -> \
  Ptr <wasmtime_val_t> -> \
  CSize -> \
  IO (Ptr <wasm_trap_t>)

#ccall wasmtime_func_new , \
  Ptr <wasmtime_context_t> -> \
  Ptr <wasm_functype_t> -> \
  <wasmtime_func_callback_t> -> \
  Ptr () -> \
  FunPtr (Ptr () -> IO ()) -> \
  Ptr <wasmtime_func_t> -> \
  IO ()

#opaque_t wasmtime_caller_t
