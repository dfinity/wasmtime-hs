{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

#include <bindings.dsl.h>
#include <wasmtime/config.h>

-- | <https://docs.wasmtime.dev/c-api/config_8h.html>
module Bindings.Wasmtime.Config where
#strict_import

import Bindings.Wasm
import Bindings.Wasmtime.Error
import Data.Word (Word64)

#synonym_t wasmtime_strategy_t , Word8
#synonym_t wasmtime_opt_level_t , Word8
#synonym_t wasmtime_profiling_strategy_t , Word8

#integral_t enum wasmtime_strategy_enum
#num WASMTIME_STRATEGY_AUTO
#num WASMTIME_STRATEGY_CRANELIFT

#integral_t enum wasmtime_opt_level_enum
#num WASMTIME_OPT_LEVEL_NONE
#num WASMTIME_OPT_LEVEL_SPEED
#num WASMTIME_OPT_LEVEL_SPEED_AND_SIZE

#integral_t enum wasmtime_profiling_strategy_enum
#num WASMTIME_PROFILING_STRATEGY_NONE
#num WASMTIME_PROFILING_STRATEGY_JITDUMP
#num WASMTIME_PROFILING_STRATEGY_VTUNE
#num WASMTIME_PROFILING_STRATEGY_PERFMAP

#ccall_unsafe 	wasmtime_config_debug_info_set ,                      Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_consume_fuel_set ,                    Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_epoch_interruption_set ,              Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_max_wasm_stack_set ,                  Ptr <wasm_config_t> -> CSize -> IO ()
#ccall_unsafe 	wasmtime_config_wasm_threads_set ,                    Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_wasm_reference_types_set ,            Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_wasm_simd_set ,                       Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_wasm_relaxed_simd_set ,               Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_wasm_relaxed_simd_deterministic_set , Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_wasm_bulk_memory_set ,                Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_wasm_multi_value_set ,                Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_wasm_multi_memory_set ,               Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_wasm_memory64_set ,                   Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_strategy_set ,                        Ptr <wasm_config_t> -> <wasmtime_strategy_t> -> IO ()
#ccall_unsafe 	wasmtime_config_parallel_compilation_set ,            Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_cranelift_debug_verifier_set ,        Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_cranelift_nan_canonicalization_set ,  Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_cranelift_opt_level_set ,             Ptr <wasm_config_t> -> <wasmtime_opt_level_t> -> IO ()
#ccall_unsafe 	wasmtime_config_profiler_set ,                        Ptr <wasm_config_t> -> <wasmtime_profiling_strategy_t> -> IO ()
-- #ccall_unsafe 	wasmtime_config_static_memory_forced_set ,            Ptr <wasm_config_t> -> Bool -> IO ()
#ccall_unsafe 	wasmtime_config_static_memory_maximum_size_set ,      Ptr <wasm_config_t> -> Word64 -> IO ()
#ccall_unsafe 	wasmtime_config_static_memory_guard_size_set ,        Ptr <wasm_config_t> -> Word64 -> IO ()
#ccall_unsafe 	wasmtime_config_dynamic_memory_guard_size_set ,       Ptr <wasm_config_t> -> Word64 -> IO ()
#ccall_unsafe   wasmtime_config_cache_config_load ,                   Ptr <wasm_config_t> -> Ptr CChar -> IO (Ptr <wasmtime_error_t)
