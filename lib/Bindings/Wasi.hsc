{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasi.h>

-- | <https://docs.wasmtime.dev/c-api/wasi_8h.html>
module Bindings.Wasi where
#strict_import

#opaque_t wasi_config_t

#ccall_unsafe wasi_config_new, IO (Ptr <wasi_config_t>)
#ccall_unsafe wasi_config_inherit_argv, Ptr <wasi_config_t> -> IO ()
#ccall_unsafe wasi_config_inherit_stdin, Ptr <wasi_config_t> -> IO ()
#ccall_unsafe wasi_config_inherit_stderr, Ptr <wasi_config_t> -> IO ()
#ccall_unsafe wasi_config_inherit_stdout, Ptr <wasi_config_t> -> IO ()