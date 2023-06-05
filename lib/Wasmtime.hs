{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -Wno-unused-top-binds #-}

-- | High-level Haskell API to the wasmtime C API.
module Wasmtime
  ( -- * Engine
    Engine,
    newEngine,
    newEngineWithConfig,

    -- * Config
    Config,
    setDebugInfo,
    setConsumeFuel,
    setEpochInterruption,
    setMaxWasmStack,
    setWasmThreads,
    setWasmReferenceTypes,
    setWasmSimd,
    setWasmRelaxedSimd,
    setWasmRelaxedSimdDeterministic,
    setWasmBulkMemory,
    setWasmMultiValue,
    setWasmMultiMemory,
    setWasmMemory64,
    setStrategy,
    setParallelCompilation,
    setCraneliftDebugVerifier,
    setCaneliftNanCanonicalization,
    setCraneliftOptLevel,
    setProfilerSet,
    -- setStaticMemoryForced, -- seems absent
    setStaticMemoryMaximumSize,
    setStaticMemoryGuardSize,
    setDynamicMemoryGuardSize,
    loadCacheConfig,
    Strategy,
    autoStrategy,
    craneliftStrategy,
    OptLevel,
    noneOptLevel,
    speedOptLevel,
    speedAndSizeOptLevel,
    ProfilingStrategy,
    noneProfilingStrategy,
    jitDumpProfilingStrategy,
    vTuneProfilingStrategy,
    perfMapProfilingStrategy,

    -- * Store
    Store,
    newStore,
    Context,
    storeContext,

    -- * Conversion
    Wasm,
    wasmToBytes,
    unsafeFromByteString,
    wat2wasm,

    -- * Module
    Module,
    newModule,

    -- * Function types
    FuncType,
    newFuncType,

    -- * Functions
    Func,
    newFunc,

    -- * ...
    TypedFunc,
    fromFunc,
    FuncCall,
    funcCall,

    -- * Externs
    Extern,
    Externable,
    extern,
    fromExtern,

    -- * Instances
    Instance,
    newInstance,
    getExport,

    -- * Errors
    WasmException (..),
    WasmtimeError,
  )
where

import Bindings.Wasm
import Bindings.Wasmtime
import Bindings.Wasmtime.Config
import Bindings.Wasmtime.Error
import Bindings.Wasmtime.Extern
import Bindings.Wasmtime.Func
import Bindings.Wasmtime.Instance
import Bindings.Wasmtime.Module
import Bindings.Wasmtime.Store
import Bindings.Wasmtime.Val
import Control.Exception (Exception, mask_, throwIO, try)
import Control.Monad (when)
import Data.Bits (Bits (xor))
import qualified Data.ByteString as B
import qualified Data.ByteString.Internal as BI
import Data.Foldable (for_)
import Data.Functor (($>))
import Data.Int (Int32, Int64)
import Data.Kind (Type)
import Data.Proxy (Proxy (..))
import Data.Traversable (for)
import Data.Typeable (Typeable)
import Data.WideWord.Word128 (Word128)
import Data.Word (Word64, Word8)
import Foreign.C.String (peekCStringLen, withCString, withCStringLen)
import Foreign.C.Types (CChar, CSize)
import qualified Foreign.Concurrent
import Foreign.ForeignPtr (ForeignPtr, mallocForeignPtr, newForeignPtr, withForeignPtr)
import Foreign.Marshal.Alloc (alloca, malloc)
import Foreign.Marshal.Array
import Foreign.Ptr (Ptr, castPtr, nullFunPtr, nullPtr)
import Foreign.Storable (Storable, peek, poke, pokeElemOff)
import System.IO.Unsafe (unsafePerformIO)
import Type.Reflection (TypeRep, eqTypeRep, typeRep, (:~~:) (HRefl))

--------------------------------------------------------------------------------
-- Engine
--------------------------------------------------------------------------------

-- | Compilation environment and configuration.
newtype Engine = Engine {unEngine :: ForeignPtr C'wasm_engine_t}

newEngine :: IO Engine
newEngine = mask_ $ do
  engine_ptr <- c'wasm_engine_new
  checkAllocation engine_ptr
  Engine <$> newForeignPtr p'wasm_engine_delete engine_ptr

withEngine :: Engine -> (Ptr C'wasm_engine_t -> IO a) -> IO a
withEngine engine = withForeignPtr (unEngine engine)

-- | Create an 'Engine' by modifying the default 'Config'.
newEngineWithConfig :: (Config -> Config) -> IO Engine
newEngineWithConfig cfg_update = mask_ $ do
  -- Config will be deallocated by Engine
  cfg_ptr <- unConfig . cfg_update <$> newConfig
  engine_ptr <- c'wasm_engine_new_with_config cfg_ptr
  checkAllocation engine_ptr
  Engine <$> newForeignPtr p'wasm_engine_delete engine_ptr

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

-- | Global 'Engine' configuration.
--
-- Unless otherwise noted, the flags default to False.
--
-- For details, see <https://docs.wasmtime.dev/api/wasmtime/struct.Config.html>
newtype Config = Config {unConfig :: Ptr C'wasm_config_t}

-- | Creates a new configuration object with the default configuration specified.
newConfig :: IO Config
newConfig = Config <$> c'wasm_config_new

setConfig :: (Ptr C'wasm_config_t -> a -> IO b) -> a -> Config -> Config
setConfig f x conf = unsafePerformIO $ f (unConfig conf) x $> conf

-- | Configures whether DWARF debug information will be emitted during compilation.
setDebugInfo :: Bool -> Config -> Config
setDebugInfo = setConfig c'wasmtime_config_debug_info_set

-- | Configures whether execution of WebAssembly will “consume fuel” to either halt or yield execution as desired.
setConsumeFuel :: Bool -> Config -> Config
setConsumeFuel = setConfig c'wasmtime_config_consume_fuel_set

-- | Enables epoch-based interruption.
setEpochInterruption :: Bool -> Config -> Config
setEpochInterruption = setConfig c'wasmtime_config_epoch_interruption_set

-- | Configures the maximum amount of stack space available for executing WebAssembly code.
--
-- Defaults to 512 KiB.
setMaxWasmStack :: CSize -> Config -> Config
setMaxWasmStack = setConfig c'wasmtime_config_max_wasm_stack_set

-- | Configures whether the WebAssembly threads proposal will be enabled for compilation.
setWasmThreads :: Bool -> Config -> Config
setWasmThreads = setConfig c'wasmtime_config_wasm_threads_set

-- | Configures whether the WebAssembly reference types proposal will be enabled for compilation.
--
-- Defaults to True.
setWasmReferenceTypes :: Bool -> Config -> Config
setWasmReferenceTypes = setConfig c'wasmtime_config_wasm_reference_types_set

-- | Configures whether the WebAssembly SIMD proposal will be enabled for compilation.
--
-- Defaults to True.
setWasmSimd :: Bool -> Config -> Config
setWasmSimd = setConfig c'wasmtime_config_wasm_simd_set

-- | Configures whether the WebAssembly Relaxed SIMD proposal will be enabled for compilation.
setWasmRelaxedSimd :: Bool -> Config -> Config
setWasmRelaxedSimd = setConfig c'wasmtime_config_wasm_relaxed_simd_set

-- | This option can be used to control the behavior of the relaxed SIMD proposal’s instructions.
setWasmRelaxedSimdDeterministic :: Bool -> Config -> Config
setWasmRelaxedSimdDeterministic = setConfig c'wasmtime_config_wasm_relaxed_simd_deterministic_set

-- | Configures whether the WebAssembly bulk memory operations proposal will be enabled for compilation.
--
-- Defaults to True.
setWasmBulkMemory :: Bool -> Config -> Config
setWasmBulkMemory = setConfig c'wasmtime_config_wasm_bulk_memory_set

-- | Configures whether the WebAssembly multi-value proposal will be enabled for compilation.
--
-- Defaults to True.
setWasmMultiValue :: Bool -> Config -> Config
setWasmMultiValue = setConfig c'wasmtime_config_wasm_multi_value_set

-- | Configures whether the WebAssembly multi-memory proposal will be enabled for compilation.
setWasmMultiMemory :: Bool -> Config -> Config
setWasmMultiMemory = setConfig c'wasmtime_config_wasm_multi_memory_set

-- | Configures whether the WebAssembly memory64 proposal will be enabled for compilation.
setWasmMemory64 :: Bool -> Config -> Config
setWasmMemory64 = setConfig c'wasmtime_config_wasm_memory64_set

-- | Configures which compilation strategy will be used for wasm modules.
--
-- Defaults to 'autoStrategy'
setStrategy :: Strategy -> Config -> Config
setStrategy (Strategy s) = setConfig c'wasmtime_config_strategy_set s

-- | Configure wether wasmtime should compile a module using multiple threads.
--
-- Defaults to True.
setParallelCompilation :: Bool -> Config -> Config
setParallelCompilation = setConfig c'wasmtime_config_parallel_compilation_set

-- | Configures whether the debug verifier of Cranelift is enabled or not.
setCraneliftDebugVerifier :: Bool -> Config -> Config
setCraneliftDebugVerifier = setConfig c'wasmtime_config_cranelift_debug_verifier_set

-- | Configures whether Cranelift should perform a NaN-canonicalization pass.
setCaneliftNanCanonicalization :: Bool -> Config -> Config
setCaneliftNanCanonicalization = setConfig c'wasmtime_config_cranelift_nan_canonicalization_set

-- | Configures the Cranelift code generator optimization level.
--
-- Defaults to 'noneOptLevel'
setCraneliftOptLevel :: OptLevel -> Config -> Config
setCraneliftOptLevel (OptLevel ol) = setConfig c'wasmtime_config_cranelift_opt_level_set ol

-- | Creates a default profiler based on the profiling strategy chosen.
setProfilerSet :: ProfilingStrategy -> Config -> Config
setProfilerSet (ProfilingStrategy ps) = setConfig c'wasmtime_config_profiler_set ps

-- Seems absent

-- | Indicates that the “static” style of memory should always be used.
-- setStaticMemoryForced :: Bool -> Config -> Config
-- setStaticMemoryForced = setConfig c'wasmtime_config_static_memory_forced_set

-- | Configures the maximum size, in bytes, where a linear memory is considered static, above which it’ll be considered dynamic.
--
-- The default value for this property depends on the host platform. For 64-bit platforms there’s lots of address space available, so the default configured here is 4GB. WebAssembly linear memories currently max out at 4GB which means that on 64-bit platforms Wasmtime by default always uses a static memory. This, coupled with a sufficiently sized guard region, should produce the fastest JIT code on 64-bit platforms, but does require a large address space reservation for each wasm memory.
-- For 32-bit platforms this value defaults to 1GB. This means that wasm memories whose maximum size is less than 1GB will be allocated statically, otherwise they’ll be considered dynamic.
setStaticMemoryMaximumSize :: Word64 -> Config -> Config
setStaticMemoryMaximumSize = setConfig c'wasmtime_config_static_memory_maximum_size_set

-- | Configures the size, in bytes, of the guard region used at the end of a static memory’s address space reservation.
--
-- The default value for this property is 2GB on 64-bit platforms. This allows eliminating almost all bounds checks on loads/stores with an immediate offset of less than 2GB. On 32-bit platforms this defaults to 64KB.
setStaticMemoryGuardSize :: Word64 -> Config -> Config
setStaticMemoryGuardSize = setConfig c'wasmtime_config_static_memory_guard_size_set

-- | Configures the size, in bytes, of the guard region used at the end of a dynamic memory’s address space reservation.
--
-- Defaults to 64KB
setDynamicMemoryGuardSize :: Word64 -> Config -> Config
setDynamicMemoryGuardSize = setConfig c'wasmtime_config_dynamic_memory_guard_size_set

-- | Loads cache configuration specified at filePath.
loadCacheConfig :: FilePath -> Config -> Config
loadCacheConfig = setConfig $ \ptr filePath ->
  withCString filePath (c'wasmtime_config_cache_config_load ptr)

-- Config Enums

-- | Configures which compilation strategy will be used for wasm modules.
newtype Strategy = Strategy C'wasmtime_strategy_t

-- | Select compilation strategy automatically (currently defaults to cranelift)
autoStrategy :: Strategy
autoStrategy = Strategy c'WASMTIME_STRATEGY_AUTO

-- | Cranelift aims to be a reasonably fast code generator which generates high quality machine code
craneliftStrategy :: Strategy
craneliftStrategy = Strategy c'WASMTIME_STRATEGY_CRANELIFT

-- | Configures the Cranelift code generator optimization level.
newtype OptLevel = OptLevel C'wasmtime_opt_level_t

-- | No optimizations performed, minimizes compilation time.
noneOptLevel :: OptLevel
noneOptLevel = OptLevel c'WASMTIME_OPT_LEVEL_NONE

-- | Generates the fastest possible code, but may take longer.
speedOptLevel :: OptLevel
speedOptLevel = OptLevel c'WASMTIME_OPT_LEVEL_SPEED

-- | Similar to speed, but also performs transformations aimed at reducing code size.
speedAndSizeOptLevel :: OptLevel
speedAndSizeOptLevel = OptLevel c'WASMTIME_OPT_LEVEL_SPEED_AND_SIZE

-- | Select which profiling technique to support.
newtype ProfilingStrategy = ProfilingStrategy C'wasmtime_profiling_strategy_t

-- | No profiler support.
noneProfilingStrategy :: ProfilingStrategy
noneProfilingStrategy = ProfilingStrategy c'WASMTIME_PROFILING_STRATEGY_NONE

-- | Collect profiling info for “jitdump” file format, used with perf on Linux.
jitDumpProfilingStrategy :: ProfilingStrategy
jitDumpProfilingStrategy = ProfilingStrategy c'WASMTIME_PROFILING_STRATEGY_JITDUMP

-- | Collect profiling info using the “ittapi”, used with VTune on Linux.
vTuneProfilingStrategy :: ProfilingStrategy
vTuneProfilingStrategy = ProfilingStrategy c'WASMTIME_PROFILING_STRATEGY_VTUNE

-- | Collect function name information as the “perf map” file format, used with perf on Linux.
perfMapProfilingStrategy :: ProfilingStrategy
perfMapProfilingStrategy = ProfilingStrategy c'WASMTIME_PROFILING_STRATEGY_PERFMAP

--------------------------------------------------------------------------------
-- Store
--------------------------------------------------------------------------------

-- | A collection of instances and wasm global items.
newtype Store = Store {unStore :: ForeignPtr C'wasmtime_store_t}

newStore :: Engine -> IO Store
newStore engine = withEngine engine $ \engine_ptr -> mask_ $ do
  wasmtime_store_ptr <- c'wasmtime_store_new engine_ptr nullPtr nullFunPtr
  checkAllocation wasmtime_store_ptr
  Store <$> newForeignPtr p'wasmtime_store_delete wasmtime_store_ptr

withStore :: Store -> (Ptr C'wasmtime_store_t -> IO a) -> IO a
withStore store = withForeignPtr (unStore store)

data Context = Context
  { -- | Usage of a @wasmtime_context_t@ must not outlive the original @wasmtime_store_t@
    -- so we keep a reference to a 'Store' to ensure it's not garbage collected.
    storeContextStore :: !Store,
    storeContextPtr :: !(Ptr C'wasmtime_context_t)
  }

storeContext :: Store -> IO Context
storeContext store =
  withStore store $ \wasmtime_store_ptr -> do
    wasmtime_ctx_ptr <- c'wasmtime_store_context wasmtime_store_ptr
    pure
      Context
        { storeContextStore = store,
          storeContextPtr = wasmtime_ctx_ptr
        }

withContext :: Context -> (Ptr C'wasmtime_context_t -> IO a) -> IO a
withContext ctx f = withStore (storeContextStore ctx) $ \_store_ptr ->
  f $ storeContextPtr ctx

--------------------------------------------------------------------------------
-- Conversion
--------------------------------------------------------------------------------

-- | WASM code.
newtype Wasm = Wasm {wasmToBytes :: B.ByteString}

-- | Convert bytes into WASM. This function doesn't check if the bytes
-- are actual WASM code hence it's unsafe.
unsafeFromByteString :: B.ByteString -> Wasm
unsafeFromByteString = Wasm

-- | Converts from the text format of WebAssembly to the binary format.
--
-- Throws a 'WasmtimeError' in case conversion fails.
wat2wasm :: B.ByteString -> Either WasmtimeError Wasm
wat2wasm (BI.BS inp_fp inp_size) =
  unsafePerformIO $ try $ withForeignPtr inp_fp $ \(inp_ptr :: Ptr Word8) ->
    alloca $ \(wasm_byte_vec_ptr :: Ptr C'wasm_byte_vec_t) -> mask_ $ do
      let cchar_ptr :: Ptr CChar
          cchar_ptr = castPtr inp_ptr
      error_ptr <-
        c'wasmtime_wat2wasm
          cchar_ptr
          (fromIntegral inp_size)
          wasm_byte_vec_ptr
      checkWasmtimeError error_ptr
      data_ptr :: Ptr CChar <- peek $ p'wasm_byte_vec_t'data wasm_byte_vec_ptr
      size <- peek $ p'wasm_byte_vec_t'size wasm_byte_vec_ptr
      let word_ptr :: Ptr Word8
          word_ptr = castPtr data_ptr
      out_fp <-
        Foreign.Concurrent.newForeignPtr word_ptr $
          c'wasm_byte_vec_delete wasm_byte_vec_ptr
      pure $ Wasm $ BI.fromForeignPtr0 out_fp $ fromIntegral size

--------------------------------------------------------------------------------
-- Module
--------------------------------------------------------------------------------

newtype Module = Module {unModule :: ForeignPtr C'wasmtime_module_t}

newModule :: Engine -> Wasm -> IO Module
newModule engine (Wasm (BI.BS inp_fp inp_size)) =
  withForeignPtr inp_fp $ \(inp_ptr :: Ptr Word8) ->
    withEngine engine $ \engine_ptr ->
      alloca $ \module_ptr_ptr -> mask_ $ do
        error_ptr <-
          c'wasmtime_module_new
            engine_ptr
            inp_ptr
            (fromIntegral inp_size)
            module_ptr_ptr
        checkWasmtimeError error_ptr
        module_ptr <- peek module_ptr_ptr
        Module <$> newForeignPtr p'wasmtime_module_delete module_ptr

withModule :: Module -> (Ptr C'wasmtime_module_t -> IO a) -> IO a
withModule m = withForeignPtr (unModule m)

--------------------------------------------------------------------------------
-- Function Types
--------------------------------------------------------------------------------

newtype FuncType = FuncType {unFuncType :: ForeignPtr C'wasm_functype_t}

withFuncType :: FuncType -> (Ptr C'wasm_functype_t -> IO a) -> IO a
withFuncType funcType = withForeignPtr (unFuncType funcType)

newFuncType :: forall f. FuncKind f => Proxy f -> IO FuncType
newFuncType _proxy = do
  withKinds ps $ \(params_ptr :: Ptr C'wasm_valtype_vec_t) ->
    withKinds rs $ \(result_ptr :: Ptr C'wasm_valtype_vec_t) -> do
      functype_ptr <- c'wasm_functype_new params_ptr result_ptr
      FuncType <$> newForeignPtr p'wasm_functype_delete functype_ptr
  where
    ps = params (Proxy @f)
    rs = result (Proxy @f)

withKinds :: [C'wasm_valkind_t] -> (Ptr C'wasm_valtype_vec_t -> IO a) -> IO a
withKinds kinds f =
  allocaArray n $ \(valtypes_ptr :: Ptr (Ptr C'wasm_valtype_t)) -> mask_ $ do
    for_ (zip [0 ..] kinds) $ \(ix, k) -> do
      -- FIXME: is the following a memory leak?
      valtype_ptr <- c'wasm_valtype_new k
      pokeElemOff valtypes_ptr ix valtype_ptr
    (valtype_vec_ptr :: Ptr C'wasm_valtype_vec_t) <- malloc
    c'wasm_valtype_vec_new valtype_vec_ptr (fromIntegral n) valtypes_ptr
    f valtype_vec_ptr
  where
    n = length kinds

class FuncKind f where
  params :: Proxy f -> [C'wasm_valkind_t]
  result :: Proxy f -> [C'wasm_valkind_t]

instance (Kind a, FuncKind b) => FuncKind (a -> b) where
  params _proxy = kind (Proxy @a) : params (Proxy @b)
  result _proxy = result (Proxy @b)

instance Results r => FuncKind (IO r) where
  params _proxy = []
  result _proxy = results (Proxy @r)

class Kind a where
  kind :: Proxy a -> C'wasm_valkind_t

instance Kind Int32 where kind _proxy = c'WASMTIME_I32

instance Kind Int64 where kind _proxy = c'WASMTIME_I64

instance Kind Float where kind _proxy = c'WASMTIME_F32

instance Kind Double where kind _proxy = c'WASMTIME_F64

instance Kind Word128 where kind _proxy = c'WASMTIME_V128

-- TODO:
-- instance Kind ? where kind _proxy = c'WASMTIME_FUNCREF
-- instance Kind ? where kind _proxy = c'WASMTIME_EXTERNREF

class Results r where
  results :: Proxy r -> [C'wasm_valkind_t]
  numResults' :: Proxy r -> Int

instance Results () where
  results _proxy = []
  numResults' _proxy = 0

-- The instance:
--
-- instance {-# OVERLAPPABLE #-} Kind a => Results a where
--   results proxy = [kind proxy]
--
-- leads to:
--
--   Overlapping instances for Results ()
--
-- when type checking:
--
--   newFuncType :: IO (IO ())
--
-- I don't understand why yet but in the mean time we just have
-- individual instances for all primitive types:

instance Results Int32 where
  results proxy = [kind proxy]
  numResults' _proxy = 1

instance Results Int64 where
  results proxy = [kind proxy]
  numResults' _proxy = 1

instance Results Float where
  results proxy = [kind proxy]
  numResults' _proxy = 1

instance Results Double where
  results proxy = [kind proxy]
  numResults' _proxy = 1

instance Results Word128 where
  results proxy = [kind proxy]
  numResults' _proxy = 1

instance (Kind a, Kind b) => Results (a, b) where
  results _proxy = [kind (Proxy @a), kind (Proxy @b)]
  numResults' _proxy = 2

instance (Kind a, Kind b, Kind c) => Results (a, b, c) where
  results _proxy = [kind (Proxy @a), kind (Proxy @b), kind (Proxy @c)]
  numResults' _proxy = 3

instance (Kind a, Kind b, Kind c, Kind d) => Results (a, b, c, d) where
  results _proxy = [kind (Proxy @a), kind (Proxy @b), kind (Proxy @c), kind (Proxy @d)]
  numResults' _proxy = 4

--------------------------------------------------------------------------------
-- Functions
--------------------------------------------------------------------------------

-- | Representation of a function in Wasmtime.
--
-- Functions are represented with a 64-bit identifying integer in Wasmtime. They
-- do not have any destructor associated with them. Functions cannot
-- interoperate between 'Store' instances and if the wrong function is passed to
-- the wrong store then it may trigger an assertion to abort the process.
newtype Func = Func {unFunc :: C'wasmtime_func_t} deriving (Show, Typeable)

newFunc ::
  forall f r.
  ( FuncKind f,
    Apply f,
    Result f ~ IO r,
    Show r
  ) =>
  Context ->
  f ->
  IO Func
newFunc ctx f = withContext ctx $ \ctx_ptr -> do
  funcType :: FuncType <- newFuncType (Proxy @f)
  withFuncType funcType $ \functype_ptr -> do
    callback_funptr <- mk'wasmtime_func_callback_t callback
    alloca $ \(func_ptr :: Ptr C'wasmtime_func_t) -> do
      c'wasmtime_func_new ctx_ptr functype_ptr callback_funptr nullPtr nullFunPtr func_ptr
      Func <$> peek func_ptr
  where
    callback ::
      Ptr () -> -- env
      Ptr C'wasmtime_caller_t -> -- caller
      Ptr C'wasmtime_val_t -> -- args
      CSize -> -- nargs
      Ptr C'wasmtime_val_t -> -- results
      CSize -> -- nresults
      IO (Ptr C'wasm_trap_t)
    callback _env _caller args_ptr nargs _result_ptr _nresults = do
      mbResult <- apply f args_ptr (fromIntegral nargs)
      case mbResult of
        Nothing -> error "TODO"
        Just (action :: Result f) -> do
          r <- action
          print r
      -- TODO
      pure nullPtr

class Apply f where
  type Result f :: Type
  apply :: f -> Ptr C'wasmtime_val_t -> Int -> IO (Maybe (Result f))

instance (KindMatch a, Apply b, Storable a) => Apply (a -> b) where
  type Result (a -> b) = Result b
  apply _ _ 0 = pure Nothing
  apply f p n = do
    k :: C'wasmtime_valkind_t <- peek $ p'wasmtime_val'kind p
    if kindMatches (Proxy @a) k
      then do
        let valunion_ptr :: Ptr C'wasmtime_valunion_t
            valunion_ptr = p'wasmtime_val'of p

            val_ptr :: Ptr a
            val_ptr = castPtr valunion_ptr
        val :: a <- peek val_ptr
        apply (f val) (advancePtr p 1) (n - 1)
      else pure Nothing

instance Apply (IO r) where
  type Result (IO r) = IO r
  apply x _ 0 = pure $ Just x
  apply _ _ _ = pure Nothing

class KindMatch a where
  kindMatches :: Proxy a -> C'wasmtime_valkind_t -> Bool

instance KindMatch Int32 where kindMatches _proxy k = k == c'WASMTIME_I32

instance KindMatch Int64 where kindMatches _proxy k = k == c'WASMTIME_I64

instance KindMatch Float where kindMatches _proxy k = k == c'WASMTIME_F32

instance KindMatch Double where kindMatches _proxy k = k == c'WASMTIME_F64

instance KindMatch Word128 where kindMatches _proxy k = k == c'WASMTIME_V128

-- TODO:
-- instance KindMatch ? where kindMatches _proxy k = k == c'WASMTIME_FUNCREF
-- instance KindMatch ? where kindMatches _proxy k = k == c'WASMTIME_EXTERNREF

--------------------------------------------------------------------------------
-- Exports have internally known types, but when we export them into the haskell world,
-- we want them to have a haskell-style type, and apply them to arguments like normal functions.
-- We achieve this by turning a Func into a TypedFunc f, where f is a user-supplied type expectation.
-- This can then be recursively reduced using funcCall... TODO

-- | Annotate a Func with its type f
newtype TypedFunc f = TypedFunc Func

-- | Type-hint an expected type f for the Func, and let the Context "typecheck"
--
-- Just (someTypedExportedFunc :: TypedFunc (IO ())) <- fromFunc ctx someExportedFunc
fromFunc :: forall f. FuncKind f => Context -> Func -> IO (Maybe (TypedFunc f))
fromFunc ctx func = do
  withContext ctx $ \ctx_ptr -> do
    -- funcType :: FuncType <- newFuncType $ Proxy @f
    let desired_params = params $ Proxy @f
    let desired_results = result $ Proxy @f
    -- allocate ptr for func
    alloca $ \func_ptr -> do
      -- write func to func_ptr
      poke func_ptr $ unFunc func
      -- pass pointer
      (functype_ptr :: Ptr C'wasm_functype_t) <- c'wasmtime_func_type ctx_ptr func_ptr
      (func_params_ptr :: Ptr C'wasm_valtype_vec_t) <- c'wasm_functype_params functype_ptr
      (func_results_ptr :: Ptr C'wasm_valtype_vec_t) <- c'wasm_functype_results functype_ptr
      func_params <- peek func_params_ptr
      func_results <- peek func_results_ptr
      -- go through parameters:
      (actual_params :: [C'wasm_valkind_t]) <- for [0 .. fromIntegral (c'wasm_valtype_vec_t'size func_params)] $ \ix -> do
        let cur_pos = advancePtr (c'wasm_valtype_vec_t'data func_params) ix
        cur_kind_ptr <- peek cur_pos
        c'wasm_valtype_kind cur_kind_ptr
      (actual_results :: [C'wasm_valkind_t]) <- for [0 .. fromIntegral (c'wasm_valtype_vec_t'size func_results)] $ \ix -> do
        let cur_pos = advancePtr (c'wasm_valtype_vec_t'data func_results) ix
        cur_kind_ptr <- peek cur_pos
        c'wasm_valtype_kind cur_kind_ptr
      if not (desired_params == actual_params && desired_results == actual_results)
        then pure Nothing
        else pure $ Just $ TypedFunc func

-- | Call exported wasm functions like a haskell function.
funcCall :: forall f. FuncCall f => Context -> TypedFunc f -> f
funcCall ctx x = unsafePerformIO $ do
  let nargs = numArgs $ Proxy @f
  let nres = numResults $ Proxy @f
  let n = max nargs nres
  -- make space for the params/results: a vector of C'wasmtime_val_raw_t
  allocaArray n $ \(val_raw_ptr :: Ptr C'wasmtime_val_raw_t) -> do
    -- make space for the trap
    alloca $ \(trap_ptr :: Ptr (Ptr C'wasm_trap_t)) -> do
      pure $ funcCall' 0 3 val_raw_ptr trap_ptr ctx x

class FuncCall f where
  numArgs :: Proxy f -> Int
  numResults :: Proxy f -> Int

  -- | Since we have a function with known type, we use wasmtime_func_call_unchecked, which is faster and uses less memory and piping
  --
  -- position into params/results pointer, params/results pointer, trap pointer
  funcCall' :: Int -> Int -> Ptr C'wasmtime_val_raw_t -> Ptr (Ptr C'wasm_trap_t) -> Context -> TypedFunc f -> f

instance FuncCall b => FuncCall (a -> b) where
  numArgs :: Proxy (a -> b) -> Int
  numArgs _ = 1 + numArgs (Proxy @b)

  numResults :: Proxy (a -> b) -> Int
  numResults _ = numResults (Proxy @b)

  funcCall' :: FuncCall b => Int -> Int -> Ptr C'wasmtime_val_raw_t -> Ptr (Ptr C'wasm_trap_t) -> Context -> TypedFunc (a -> b) -> a -> b
  funcCall' pos len param_ptr trap_ptr ctx (TypedFunc x) = do
    -- write current param to param array at current position
    undefined

instance Results r => FuncCall (IO r) where
  numArgs :: Proxy (IO r) -> Int
  numArgs _ = 0

  numResults :: Proxy (IO r) -> Int
  numResults _ = numResults' (Proxy @r)

  funcCall' :: Int -> Int -> Ptr C'wasmtime_val_raw_t -> Ptr (Ptr C'wasm_trap_t) -> Context -> TypedFunc (IO r) -> IO r
  funcCall' pos len param_ptr trap_ptr ctx (TypedFunc x) = do
    withContext ctx $ \ctx_ptr ->
      alloca $ \func_ptr -> do
        poke func_ptr $ unFunc x
        error_ptr <- c'wasmtime_func_call_unchecked ctx_ptr func_ptr param_ptr (fromIntegral len) trap_ptr
        -- TODO: handle error
        -- TODO: extract results from param_ptr and load them into r
        undefined

--------------------------------------------------------------------------------
-- Externs
--------------------------------------------------------------------------------

-- | Container for different kinds of extern items like @'Func's@
-- that can be passed to 'newInstance' and exported from @'Instance's@.
data Extern where
  Extern :: forall e. (Externable e) => TypeRep e -> e -> Extern

-- | Class of types that can be imported and exported from @'Instance's@.
class (Storable (CType e), Typeable e) => Externable e where
  type CType e :: Type
  getCExtern :: e -> CType e
  externKind :: Proxy e -> C'wasmtime_extern_kind_t

instance Externable Func where
  type CType Func = C'wasmtime_func
  getCExtern = unFunc
  externKind _proxy = c'WASMTIME_EXTERN_FUNC

-- | Turn any externable value into the 'Extern' container.
extern :: forall e. Externable e => e -> Extern
extern = Extern (typeRep :: TypeRep e)

withExterns :: [Extern] -> (Ptr C'wasmtime_extern -> CSize -> IO a) -> IO a
withExterns externs f = allocaArray n $ \externs_ptr0 ->
  let go _externs_ptr [] = f externs_ptr0 $ fromIntegral n
      go externs_ptr ((Extern _typeRep (e :: e)) : es) = do
        poke (p'wasmtime_extern'kind externs_ptr) $ externKind (Proxy @e)
        poke (castPtr (p'wasmtime_extern'of externs_ptr)) $ getCExtern e
        go (advancePtr externs_ptr 1) es
   in go externs_ptr0 externs
  where
    n = length externs

fromExtern :: forall e. Externable e => Extern -> Maybe e
fromExtern (Extern t v)
  | Just HRefl <- t `eqTypeRep` rep = Just v
  | otherwise = Nothing
  where
    rep = typeRep :: TypeRep e

--------------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------------

-- | Representation of a instance in Wasmtime.
newtype Instance = Instance {unInstance :: ForeignPtr C'wasmtime_instance_t}

-- | Instantiate a wasm module.
--
-- This function will instantiate a WebAssembly module with the provided
-- imports, creating a WebAssembly instance. The returned instance can then
-- afterwards be inspected for exports.
newInstance :: Context -> Module -> [Extern] -> IO Instance
newInstance ctx m externs =
  withContext ctx $ \ctx_ptr ->
    withModule m $ \mod_ptr ->
      withExterns externs $ \externs_ptr n -> do
        inst_fp <- mallocForeignPtr
        withForeignPtr inst_fp $ \(inst_ptr :: Ptr C'wasmtime_instance_t) ->
          alloca $ \(trap_ptr :: Ptr (Ptr C'wasm_trap_t)) -> do
            error_ptr <-
              c'wasmtime_instance_new
                ctx_ptr
                mod_ptr
                externs_ptr
                n
                inst_ptr
                trap_ptr
            checkWasmtimeError error_ptr
            -- TODO: handle traps!!!
            pure $ Instance inst_fp

withInstance :: Instance -> (Ptr C'wasmtime_instance_t -> IO a) -> IO a
withInstance inst = withForeignPtr (unInstance inst)

getExport :: Context -> Instance -> String -> IO (Maybe Extern)
getExport ctx inst name =
  withContext ctx $ \ctx_ptr ->
    withInstance inst $ \(inst_ptr :: Ptr C'wasmtime_instance_t) ->
      withCStringLen name $ \(name_ptr, len) ->
        alloca $ \(extern_ptr :: Ptr C'wasmtime_extern) -> do
          found <-
            c'wasmtime_instance_export_get
              ctx_ptr
              inst_ptr
              name_ptr
              (fromIntegral len)
              extern_ptr
          if found
            then do
              let kind_ptr :: Ptr C'wasmtime_extern_kind_t
                  kind_ptr = p'wasmtime_extern'kind extern_ptr

                  of_ptr :: Ptr C'wasmtime_extern_union_t
                  of_ptr = p'wasmtime_extern'of extern_ptr
              k <- peek kind_ptr
              if k == c'WASMTIME_EXTERN_FUNC
                then do
                  let func_ptr :: Ptr C'wasmtime_func_t
                      func_ptr = castPtr of_ptr
                  func <- Func <$> peek func_ptr
                  pure $ Just $ extern func
                else pure Nothing
            else pure Nothing

--------------------------------------------------------------------------------
-- Errors
--------------------------------------------------------------------------------

-- | Exceptions that can be thrown from WASM operations.
data WasmException
  = -- | Thrown if a WASM object (like an 'Engine' or 'Store') could not be allocated.
    AllocationFailed
  deriving (Show, Typeable)

instance Exception WasmException

checkAllocation :: Ptr a -> IO ()
checkAllocation ptr = when (ptr == nullPtr) $ throwIO AllocationFailed

-- | Errors generated by Wasmtime.
newtype WasmtimeError = WasmtimeError {unWasmtimeError :: ForeignPtr C'wasmtime_error_t}

newWasmtimeErrorFromPtr :: Ptr C'wasmtime_error_t -> IO WasmtimeError
newWasmtimeErrorFromPtr = fmap WasmtimeError . newForeignPtr p'wasmtime_error_delete

checkWasmtimeError :: Ptr C'wasmtime_error_t -> IO ()
checkWasmtimeError error_ptr = when (error_ptr /= nullPtr) $ do
  wasmtimeError <- newWasmtimeErrorFromPtr error_ptr
  throwIO wasmtimeError

withWasmtimeError :: WasmtimeError -> (Ptr C'wasmtime_error_t -> IO a) -> IO a
withWasmtimeError wasmtimeError = withForeignPtr (unWasmtimeError wasmtimeError)

instance Exception WasmtimeError

instance Show WasmtimeError where
  show wasmtimeError = unsafePerformIO $
    withWasmtimeError wasmtimeError $ \error_ptr ->
      alloca $ \(wasm_name_ptr :: Ptr C'wasm_name_t) -> do
        c'wasmtime_error_message error_ptr wasm_name_ptr
        let p :: Ptr C'wasm_byte_vec_t
            p = castPtr wasm_name_ptr
        data_ptr <- peek $ p'wasm_byte_vec_t'data p
        size <- peek $ p'wasm_byte_vec_t'size p
        peekCStringLen (data_ptr, fromIntegral size)
