{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/extern.h>

-- | <https://docs.wasmtime.dev/c-api/extern_8h.html>
module Bindings.Wasmtime.Extern where
#strict_import

import Data.Word (Word64)

#starttype struct wasmtime_func
#field store_id , Word64
#field index , CSize
#stoptype

#synonym_t wasmtime_func_t , C'wasmtime_func
