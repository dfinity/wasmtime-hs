{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
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

    -- * Functions
    Func,
    newFunc,
    Funcable,
    Kind,
    Result,
    Results,
    TypedFunc,
    toTypedFunc,
    fromTypedFunc,
    callFunc,

    -- * Memory
    WordLength (..),
    MemoryType,
    newMemoryType,
    getMin,
    getMax,
    is64Memory,
    wordLength,
    Memory,
    newMemory,
    getMemoryType,
    getMemorySizeBytes,
    getMemorySizePages,
    growMemory,
    unsafeWithMemory,
    readMemory,
    readMemoryAt,
    writeMemory,
    MemoryAccessError (..),

    -- * Externs
    Extern,
    Externable,
    toExtern,
    fromExtern,

    -- * Instances
    Instance,
    newInstance,
    getExport,
    getExportedTypedFunc,
    getExportedMemory,

    -- * Traps
    Trap,
    newTrap,
    trapCode,
    TrapCode (..),
    trapOrigin,
    trapTrace,

    -- * Frames
    Frame,
    frameFuncName,
    frameModuleName,
    frameFuncIndex,
    frameFuncOffset,
    frameModuleOffset,

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
import Bindings.Wasmtime.Memory
import Bindings.Wasmtime.Module
import Bindings.Wasmtime.Store
import Bindings.Wasmtime.Table
import Bindings.Wasmtime.Trap
import Bindings.Wasmtime.Val
import Control.Applicative ((<|>))
import Control.Exception (Exception, mask_, onException, throwIO, try)
import Control.Monad (guard, when)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Primitive (MonadPrim, PrimBase, unsafeIOToPrim, unsafePrimToIO)
import Control.Monad.ST (ST, runST)
import Control.Monad.Trans.Maybe (MaybeT, runMaybeT)
import qualified Data.ByteString as B
import qualified Data.ByteString.Internal as BI
import Data.Functor (($>))
import Data.Int (Int32, Int64)
import Data.Kind (Type)
import Data.Proxy (Proxy (..))
import Data.Typeable (Typeable)
import Data.Vector (Vector)
import qualified Data.Vector as V
import qualified Data.Vector.Unboxed as VU
import qualified Data.Vector.Unboxed.Mutable as VUM
import Data.WideWord.Word128 (Word128)
import Data.Word (Word32, Word64, Word8)
import Foreign.C.String (peekCStringLen, withCString, withCStringLen)
import Foreign.C.Types (CChar, CSize)
import qualified Foreign.Concurrent
import Foreign.ForeignPtr (ForeignPtr, mallocForeignPtr, newForeignPtr, withForeignPtr)
import Foreign.Marshal.Alloc (alloca, finalizerFree, malloc)
import Foreign.Marshal.Array
import Foreign.Marshal.Utils (with)
import Foreign.Ptr (Ptr, castPtr, nullFunPtr, nullPtr)
import Foreign.Storable (Storable, peek, peekElemOff, poke, pokeElemOff)
import System.IO.Unsafe (unsafePerformIO)
import Type.Reflection (TypeRep, eqTypeRep, typeRep, (:~~:) (HRefl))

--------------------------------------------------------------------------------
-- Typedefs
--------------------------------------------------------------------------------

type Offset = Word64

type Size = Word64

data WordLength = Bit32 | Bit64
  deriving (Show, Eq)

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
newEngineWithConfig :: Config -> IO Engine
newEngineWithConfig cfg = mask_ $ do
  -- Config will be deallocated by Engine
  cfg_ptr <- c'wasm_config_new
  unConfig cfg cfg_ptr `onException` c'wasm_config_delete cfg_ptr
  engine_ptr <- c'wasm_engine_new_with_config cfg_ptr
  checkAllocation engine_ptr `onException` c'wasm_config_delete cfg_ptr
  Engine <$> newForeignPtr p'wasm_engine_delete engine_ptr

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

-- | Global 'Engine' configuration.
--
-- 'mempty' is the default configuration where the flags default to 'False'
-- unless noted otherwise.
--
-- Configurations can be combined using @cfg1 '<>' cfg2@
-- where @cfg2@ overrides @cfg1@.
--
-- For details, see <https://docs.wasmtime.dev/api/wasmtime/struct.Config.html>
newtype Config = Config {unConfig :: Ptr C'wasm_config_t -> IO ()}

instance Semigroup Config where
  cfg1 <> cfg2 = Config $ \cfg_ptr -> do
    unConfig cfg1 cfg_ptr
    unConfig cfg2 cfg_ptr

instance Monoid Config where
  mempty = Config $ \_cfg_ptr -> pure ()
  mappend = (<>)

setConfig :: (Ptr C'wasm_config_t -> a -> IO ()) -> a -> Config
setConfig f x = Config $ \cfg_ptr -> f cfg_ptr x

-- | Configures whether DWARF debug information will be emitted during compilation.
setDebugInfo :: Bool -> Config
setDebugInfo = setConfig c'wasmtime_config_debug_info_set

-- | Configures whether execution of WebAssembly will “consume fuel” to either halt or yield execution as desired.
setConsumeFuel :: Bool -> Config
setConsumeFuel = setConfig c'wasmtime_config_consume_fuel_set

-- | Enables epoch-based interruption.
setEpochInterruption :: Bool -> Config
setEpochInterruption = setConfig c'wasmtime_config_epoch_interruption_set

-- | Configures the maximum amount of stack space available for executing WebAssembly code.
--
-- Defaults to 512 KiB.
setMaxWasmStack :: Word64 -> Config
setMaxWasmStack n = setConfig c'wasmtime_config_max_wasm_stack_set (fromIntegral n)

-- | Configures whether the WebAssembly threads proposal will be enabled for compilation.
setWasmThreads :: Bool -> Config
setWasmThreads = setConfig c'wasmtime_config_wasm_threads_set

-- | Configures whether the WebAssembly reference types proposal will be enabled for compilation.
--
-- Defaults to True.
setWasmReferenceTypes :: Bool -> Config
setWasmReferenceTypes = setConfig c'wasmtime_config_wasm_reference_types_set

-- | Configures whether the WebAssembly SIMD proposal will be enabled for compilation.
--
-- Defaults to True.
setWasmSimd :: Bool -> Config
setWasmSimd = setConfig c'wasmtime_config_wasm_simd_set

-- | Configures whether the WebAssembly Relaxed SIMD proposal will be enabled for compilation.
setWasmRelaxedSimd :: Bool -> Config
setWasmRelaxedSimd = setConfig c'wasmtime_config_wasm_relaxed_simd_set

-- | This option can be used to control the behavior of the relaxed SIMD proposal’s instructions.
setWasmRelaxedSimdDeterministic :: Bool -> Config
setWasmRelaxedSimdDeterministic = setConfig c'wasmtime_config_wasm_relaxed_simd_deterministic_set

-- | Configures whether the WebAssembly bulk memory operations proposal will be enabled for compilation.
--
-- Defaults to True.
setWasmBulkMemory :: Bool -> Config
setWasmBulkMemory = setConfig c'wasmtime_config_wasm_bulk_memory_set

-- | Configures whether the WebAssembly multi-value proposal will be enabled for compilation.
--
-- Defaults to True.
setWasmMultiValue :: Bool -> Config
setWasmMultiValue = setConfig c'wasmtime_config_wasm_multi_value_set

-- | Configures whether the WebAssembly multi-memory proposal will be enabled for compilation.
setWasmMultiMemory :: Bool -> Config
setWasmMultiMemory = setConfig c'wasmtime_config_wasm_multi_memory_set

-- | Configures whether the WebAssembly memory64 proposal will be enabled for compilation.
setWasmMemory64 :: Bool -> Config
setWasmMemory64 = setConfig c'wasmtime_config_wasm_memory64_set

-- | Configures which compilation strategy will be used for wasm modules.
--
-- Defaults to 'autoStrategy'
setStrategy :: Strategy -> Config
setStrategy (Strategy s) = setConfig c'wasmtime_config_strategy_set s

-- | Configure wether wasmtime should compile a module using multiple threads.
--
-- Defaults to True.
setParallelCompilation :: Bool -> Config
setParallelCompilation = setConfig c'wasmtime_config_parallel_compilation_set

-- | Configures whether the debug verifier of Cranelift is enabled or not.
setCraneliftDebugVerifier :: Bool -> Config
setCraneliftDebugVerifier = setConfig c'wasmtime_config_cranelift_debug_verifier_set

-- | Configures whether Cranelift should perform a NaN-canonicalization pass.
setCaneliftNanCanonicalization :: Bool -> Config
setCaneliftNanCanonicalization = setConfig c'wasmtime_config_cranelift_nan_canonicalization_set

-- | Configures the Cranelift code generator optimization level.
--
-- Defaults to 'noneOptLevel'
setCraneliftOptLevel :: OptLevel -> Config
setCraneliftOptLevel (OptLevel ol) = setConfig c'wasmtime_config_cranelift_opt_level_set ol

-- | Creates a default profiler based on the profiling strategy chosen.
setProfilerSet :: ProfilingStrategy -> Config
setProfilerSet (ProfilingStrategy ps) = setConfig c'wasmtime_config_profiler_set ps

-- Seems absent

-- | Indicates that the “static” style of memory should always be used.
-- setStaticMemoryForced :: Bool -> Config -> Config
-- setStaticMemoryForced = setConfig c'wasmtime_config_static_memory_forced_set

-- | Configures the maximum size, in bytes, where a linear memory is considered static, above which it’ll be considered dynamic.
--
-- The default value for this property depends on the host platform. For 64-bit platforms there’s lots of address space available, so the default configured here is 4GB. WebAssembly linear memories currently max out at 4GB which means that on 64-bit platforms Wasmtime by default always uses a static memory. This, coupled with a sufficiently sized guard region, should produce the fastest JIT code on 64-bit platforms, but does require a large address space reservation for each wasm memory.
-- For 32-bit platforms this value defaults to 1GB. This means that wasm memories whose maximum size is less than 1GB will be allocated statically, otherwise they’ll be considered dynamic.
setStaticMemoryMaximumSize :: Word64 -> Config
setStaticMemoryMaximumSize = setConfig c'wasmtime_config_static_memory_maximum_size_set

-- | Configures the size, in bytes, of the guard region used at the end of a static memory’s address space reservation.
--
-- The default value for this property is 2GB on 64-bit platforms. This allows eliminating almost all bounds checks on loads/stores with an immediate offset of less than 2GB. On 32-bit platforms this defaults to 64KB.
setStaticMemoryGuardSize :: Word64 -> Config
setStaticMemoryGuardSize = setConfig c'wasmtime_config_static_memory_guard_size_set

-- | Configures the size, in bytes, of the guard region used at the end of a dynamic memory’s address space reservation.
--
-- Defaults to 64KB
setDynamicMemoryGuardSize :: Word64 -> Config
setDynamicMemoryGuardSize = setConfig c'wasmtime_config_dynamic_memory_guard_size_set

-- | Enables Wasmtime's cache and loads configuration from the specified path.
--
-- The path should point to a file on the filesystem with TOML configuration -
-- <https://bytecodealliance.github.io/wasmtime/cli-cache.html>.
--
-- A 'WasmtimeError' is thrown if the cache configuration could not be loaded or
-- if the cache could not be enabled.
loadCacheConfig :: FilePath -> Config
loadCacheConfig = setConfig $ \cfg_ptr filePath -> withCString filePath $ \str_ptr -> do
  error_ptr <- c'wasmtime_config_cache_config_load cfg_ptr str_ptr
  checkWasmtimeError error_ptr

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
newtype Store s = Store {unStore :: ForeignPtr C'wasmtime_store_t}

newStore :: MonadPrim s m => Engine -> m (Store s)
newStore engine = unsafeIOToPrim $ withEngine engine $ \engine_ptr -> mask_ $ do
  wasmtime_store_ptr <- c'wasmtime_store_new engine_ptr nullPtr nullFunPtr
  checkAllocation wasmtime_store_ptr
  Store <$> newForeignPtr p'wasmtime_store_delete wasmtime_store_ptr

withStore :: Store s -> (Ptr C'wasmtime_store_t -> IO a) -> IO a
withStore = withForeignPtr . unStore

data Context s = Context
  { -- | Usage of a @wasmtime_context_t@ must not outlive the original @wasmtime_store_t@
    -- so we keep a reference to a 'Store' to ensure it's not garbage collected.
    storeContextStore :: !(Store s),
    storeContextPtr :: !(Ptr C'wasmtime_context_t)
  }

storeContext :: MonadPrim s m => Store s -> m (Context s)
storeContext store =
  unsafeIOToPrim $ withStore store $ \wasmtime_store_ptr -> do
    wasmtime_ctx_ptr <- c'wasmtime_store_context wasmtime_store_ptr
    pure
      Context
        { storeContextStore = store,
          storeContextPtr = wasmtime_ctx_ptr
        }

withContext :: Context s -> (Ptr C'wasmtime_context_t -> IO a) -> IO a
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

newModule :: Engine -> Wasm -> Either WasmtimeError Module
newModule engine (Wasm (BI.BS inp_fp inp_size)) = unsafePerformIO $
  try $
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
withModule = withForeignPtr . unModule

--------------------------------------------------------------------------------
-- Function Types
--------------------------------------------------------------------------------

newtype FuncType = FuncType {unFuncType :: ForeignPtr C'wasm_functype_t}

withFuncType :: FuncType -> (Ptr C'wasm_functype_t -> IO a) -> IO a
withFuncType = withForeignPtr . unFuncType

newFuncType ::
  forall f m r.
  ( Funcable f,
    Result f ~ m (Either Trap r),
    Results r
  ) =>
  Proxy f ->
  IO FuncType
newFuncType _proxy = mask_ $ do
  withKinds (paramKinds $ Proxy @f) $ \(params_ptr :: Ptr C'wasm_valtype_vec_t) ->
    withKinds (resultKinds $ Proxy @r) $ \(result_ptr :: Ptr C'wasm_valtype_vec_t) -> do
      functype_ptr <- c'wasm_functype_new params_ptr result_ptr
      FuncType <$> newForeignPtr p'wasm_functype_delete functype_ptr

withKinds :: VU.Vector C'wasm_valkind_t -> (Ptr C'wasm_valtype_vec_t -> IO a) -> IO a
withKinds kinds f =
  allocaArray n $ \(valtypes_ptr :: Ptr (Ptr C'wasm_valtype_t)) -> do
    VU.iforM_ kinds $ \ix k -> do
      -- FIXME: is the following a memory leak?
      valtype_ptr <- c'wasm_valtype_new k
      pokeElemOff valtypes_ptr ix valtype_ptr
    (valtype_vec_ptr :: Ptr C'wasm_valtype_vec_t) <- malloc
    c'wasm_valtype_vec_new valtype_vec_ptr (fromIntegral n) valtypes_ptr
    f valtype_vec_ptr
  where
    n = VU.length kinds

class Storable a => Kind a where
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
  resultKinds :: Proxy r -> VU.Vector C'wasm_valkind_t
  nrOfResults :: Proxy r -> Int
  writeResults :: Ptr C'wasmtime_val_t -> r -> IO ()
  readResults :: Ptr C'wasmtime_val_raw_t -> IO r

instance Results () where
  resultKinds _proxy = []
  nrOfResults _proxy = 0
  writeResults _result_ptr () = pure ()
  readResults _result_ptr = pure ()

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
  resultKinds proxy = [kind proxy]
  nrOfResults _proxy = 1
  writeResults = pokeVal
  readResults = peekRawVal

instance Results Int64 where
  resultKinds proxy = [kind proxy]
  nrOfResults _proxy = 1
  writeResults = pokeVal
  readResults = peekRawVal

instance Results Float where
  resultKinds proxy = [kind proxy]
  nrOfResults _proxy = 1
  writeResults = pokeVal
  readResults = peekRawVal

instance Results Double where
  resultKinds proxy = [kind proxy]
  nrOfResults _proxy = 1
  writeResults = pokeVal
  readResults = peekRawVal

instance Results Word128 where
  resultKinds proxy = [kind proxy]
  nrOfResults _proxy = 1
  writeResults = pokeVal
  readResults = peekRawVal

pokeVal :: forall r. (Kind r) => Ptr C'wasmtime_val_t -> r -> IO ()
pokeVal result_ptr r = do
  poke (p'wasmtime_val'kind result_ptr) $ kind $ Proxy @r
  let p :: Ptr C'wasmtime_valunion_t
      p = p'wasmtime_val'of result_ptr
  poke (castPtr p) r

peekRawVal :: Storable r => Ptr C'wasmtime_val_raw_t -> IO r
peekRawVal = peek . castPtr

instance (Kind a, Kind b) => Results (a, b) where
  resultKinds _proxy = [kind (Proxy @a), kind (Proxy @b)]
  nrOfResults _proxy = 2
  writeResults result_ptr (a, b) = do
    pokeVal result_ptr a
    pokeVal (advancePtr result_ptr 1) b
  readResults result_ptr =
    (,)
      <$> peekRawVal result_ptr
      <*> peekRawVal (advancePtr result_ptr 1)

instance (Kind a, Kind b, Kind c) => Results (a, b, c) where
  resultKinds _proxy = [kind (Proxy @a), kind (Proxy @b), kind (Proxy @c)]
  nrOfResults _proxy = 3
  writeResults result_ptr (a, b, c) = do
    pokeVal result_ptr a
    pokeVal (advancePtr result_ptr 1) b
    pokeVal (advancePtr result_ptr 2) c
  readResults result_ptr =
    (,,)
      <$> peekRawVal result_ptr
      <*> peekRawVal (advancePtr result_ptr 1)
      <*> peekRawVal (advancePtr result_ptr 2)

instance (Kind a, Kind b, Kind c, Kind d) => Results (a, b, c, d) where
  resultKinds _proxy = [kind (Proxy @a), kind (Proxy @b), kind (Proxy @c), kind (Proxy @d)]
  nrOfResults _proxy = 4
  writeResults result_ptr (a, b, c, d) = do
    pokeVal result_ptr a
    pokeVal (advancePtr result_ptr 1) b
    pokeVal (advancePtr result_ptr 2) c
    pokeVal (advancePtr result_ptr 3) d
  readResults result_ptr =
    (,,,)
      <$> peekRawVal result_ptr
      <*> peekRawVal (advancePtr result_ptr 1)
      <*> peekRawVal (advancePtr result_ptr 2)
      <*> peekRawVal (advancePtr result_ptr 3)

--------------------------------------------------------------------------------
-- Functions
--------------------------------------------------------------------------------

-- | Representation of a function in Wasmtime.
--
-- Functions are represented with a 64-bit identifying integer in Wasmtime. They
-- do not have any destructor associated with them. Functions cannot
-- interoperate between 'Store' instances and if the wrong function is passed to
-- the wrong store then it may trigger an assertion to abort the process.
newtype Func s = Func {getWasmtimeFunc :: C'wasmtime_func_t}
  deriving (Show, Typeable)

type FuncCallback =
  Ptr () -> -- env
  Ptr C'wasmtime_caller_t -> -- caller
  Ptr C'wasmtime_val_t -> -- args
  CSize -> -- nargs
  Ptr C'wasmtime_val_t -> -- results
  CSize -> -- nresults
  IO (Ptr C'wasm_trap_t)

-- | Insert a new function into the 'Store'.
newFunc ::
  forall f r s m.
  ( Funcable f,
    Result f ~ m (Either Trap r),
    Results r,
    MonadPrim s m,
    PrimBase m
  ) =>
  Context s ->
  -- | 'Funcable' Haskell function.
  f ->
  m (Func s)
newFunc ctx f = unsafeIOToPrim $ withContext ctx $ \ctx_ptr -> do
  funcType :: FuncType <- newFuncType (Proxy @f)
  withFuncType funcType $ \functype_ptr -> do
    -- TODO: We probably need to extend the Store with a mutable set of FunPtrs
    -- that need to be freed using freeHaskellFunPtr when the Store is collected!!!
    callback_funptr <- mk'wasmtime_func_callback_t callback
    alloca $ \(func_ptr :: Ptr C'wasmtime_func_t) -> do
      c'wasmtime_func_new ctx_ptr functype_ptr callback_funptr nullPtr nullFunPtr func_ptr
      Func <$> peek func_ptr
  where
    callback :: FuncCallback
    callback _env _caller args_ptr nargs result_ptr nresults = do
      mbResult <- importCall f args_ptr (fromIntegral nargs)
      case mbResult of
        Nothing -> do
          -- TODO: use throwIO or trap!
          error "The type of the imported WASM function doesn't match the desired Haskell type!"
        Just (action :: m (Either Trap r)) -> do
          e <- unsafePrimToIO action
          case e of
            Left trap ->
              -- As the docs of <wasmtime_func_callback_t> mention:
              --
              -- > This callback can optionally return a wasm_trap_t indicating
              -- > that a trap should be raised in WebAssembly. It's expected
              -- > that in this case the caller relinquishes ownership of the
              -- > trap and it is passed back to the engine.
              --
              -- Since trap is a ForeignPtr which will be garbage collected
              -- later we need to copy the trap to safely hand it to the engine.
              withTrap trap c'wasm_trap_copy
            Right r -> do
              let n = fromIntegral nresults
              if n == expectedNrOfResults
                then writeResults result_ptr r $> nullPtr
                else do
                  -- TODO: use throwIO or trap!
                  error $
                    "Expected the number of results to be "
                      ++ show expectedNrOfResults
                      ++ " but got "
                      ++ show n
                      ++ "!"

    expectedNrOfResults :: Int
    expectedNrOfResults = nrOfResults $ Proxy @r

-- | Class of Haskell functions / actions that can be imported into and exported
-- from WASM modules.
class Funcable f where
  type Result f :: Type

  -- | Write the parameter kinds to the given mutable vector starting from the given index.
  writeParamKinds :: Proxy f -> VUM.MVector s C'wasm_valkind_t -> Int -> ST s ()

  -- | The number of parameters.
  nrOfParams :: Proxy f -> Int

  -- | Call the given Haskell function / action @f@ on the arguments stored in
  -- the given 'C'wasmtime_val_t' array.
  importCall ::
    -- | Haskell function / action.
    f ->
    -- | Array of parameters of the function.
    Ptr C'wasmtime_val_t ->
    -- | Number of parameters.
    Int ->
    IO (Maybe (Result f))

  -- | Returns a Haskell function / action of type @f@ which, when applied to
  -- parameters, will call the given exported 'Func' on those parameters.
  exportCall ::
    -- | Array where to poke the parameters of the function.
    ForeignPtr C'wasmtime_val_raw_t ->
    -- | Index where to poke the next parameter in the previous array.
    Int ->
    -- | Total number of parameters.
    CSize ->
    Context s ->
    Func s ->
    f

instance (Kind a, Funcable b) => Funcable (a -> b) where
  type Result (a -> b) = Result b

  writeParamKinds _proxy mutVec ix = do
    VUM.unsafeWrite mutVec ix $ kind (Proxy @a)
    writeParamKinds (Proxy @b) mutVec (ix + 1)

  nrOfParams _proxy = 1 + nrOfParams (Proxy @b)

  importCall _ _ 0 = pure Nothing
  importCall f p n = do
    k :: C'wasmtime_valkind_t <- peek $ p'wasmtime_val'kind p
    if kind (Proxy @a) == k
      then do
        let valunion_ptr :: Ptr C'wasmtime_valunion_t
            valunion_ptr = p'wasmtime_val'of p

            val_ptr :: Ptr a
            val_ptr = castPtr valunion_ptr
        val :: a <- peek val_ptr
        importCall (f val) (advancePtr p 1) (n - 1)
      else pure Nothing

  exportCall args_and_results_fp ix len ctx func (x :: a) = unsafePerformIO $
    withForeignPtr args_and_results_fp $ \(args_and_results_ptr :: Ptr C'wasmtime_val_raw_t) -> do
      let cur_pos = advancePtr args_and_results_ptr ix
      poke (castPtr cur_pos) x
      pure $ exportCall args_and_results_fp (ix + 1) len ctx func

instance Results r => Funcable (IO (Either Trap r)) where
  type Result (IO (Either Trap r)) = IO (Either Trap r)

  writeParamKinds _proxy _mutVec _ix = pure ()
  nrOfParams _proxy = 0

  importCall x _ 0 = pure $ Just x
  importCall _ _ _ = pure Nothing

  exportCall args_and_results_fp _ix len ctx func =
    withForeignPtr args_and_results_fp $ \(args_and_results_ptr :: Ptr C'wasmtime_val_raw_t) ->
      withContext ctx $ \ctx_ptr ->
        with (getWasmtimeFunc func) $ \func_ptr ->
          alloca $ \(trap_ptr_ptr :: Ptr (Ptr C'wasm_trap_t)) -> do
            error_ptr <-
              c'wasmtime_func_call_unchecked
                ctx_ptr
                func_ptr
                args_and_results_ptr
                len
                trap_ptr_ptr
            checkWasmtimeError error_ptr
            trap_ptr <- peek trap_ptr_ptr
            if trap_ptr == nullPtr
              then Right <$> readResults args_and_results_ptr
              else Left <$> newTrapFromPtr trap_ptr

instance Results r => Funcable (ST s (Either Trap r)) where
  type Result (ST s (Either Trap r)) = ST s (Either Trap r)

  writeParamKinds _proxy _mutVec _ix = pure ()
  nrOfParams _proxy = 0

  importCall x _ 0 = pure $ Just x
  importCall _ _ _ = pure Nothing

  exportCall args_and_results_fp ix len ctx func =
    unsafeIOToPrim $
      exportCall args_and_results_fp ix len ctx func

paramKinds :: forall f. Funcable f => Proxy f -> VU.Vector C'wasm_valkind_t
paramKinds proxy = runST $ do
  mutVec <- VUM.unsafeNew $ nrOfParams $ Proxy @f
  writeParamKinds proxy mutVec 0
  VU.unsafeFreeze mutVec

-- | A 'Func' annotated with its type.
newtype TypedFunc s f = TypedFunc {fromTypedFunc :: Func s} deriving (Show)

-- | Retrieves the type of the given 'Func' from the 'Store' and checks if it
-- matches the desired type @f@ of the returned 'TypedFunc'.
--
-- You can then call this 'TypedFunc' using 'callFunc' for example:
--
-- @
-- mbTypedFunc <- toTypedFunc ctx someExportedGcdFunc
-- case mbTypedFunc of
--   Nothing -> error "gcd did not have the expected type!"
--   Just (gcdTypedFunc :: TypedFunc RealWorld (Int32 -> Int32 -> IO Int32)) -> do
--     -- Call gcd on its two Int32 arguments:
--     r <- callFunc ctx gcdTypedFunc 6 27
--     print r -- prints "3"
-- @
toTypedFunc ::
  forall s m f r.
  (MonadPrim s m, Funcable f, Result f ~ m (Either Trap r), Results r) =>
  Context s ->
  Func s ->
  m (Maybe (TypedFunc s f))
toTypedFunc ctx func = unsafeIOToPrim $ do
  withContext ctx $ \ctx_ptr ->
    with (getWasmtimeFunc func) $ \(func_ptr :: Ptr C'wasmtime_func_t) -> do
      (functype_ptr :: Ptr C'wasm_functype_t) <- c'wasmtime_func_type ctx_ptr func_ptr
      (func_params_ptr :: Ptr C'wasm_valtype_vec_t) <- c'wasm_functype_params functype_ptr
      (func_results_ptr :: Ptr C'wasm_valtype_vec_t) <- c'wasm_functype_results functype_ptr
      func_params :: C'wasm_valtype_vec_t <- peek func_params_ptr
      func_results :: C'wasm_valtype_vec_t <- peek func_results_ptr
      (actual_params :: VU.Vector C'wasm_valkind_t) <- kindsOf func_params
      (actual_results :: VU.Vector C'wasm_valkind_t) <- kindsOf func_results
      if desired_params == actual_params
        && desired_results == actual_results
        then pure $ Just $ TypedFunc func
        else pure Nothing
  where
    desired_params = paramKinds $ Proxy @f
    desired_results = resultKinds $ Proxy @r

    kindsOf :: C'wasm_valtype_vec_t -> IO (VU.Vector C'wasm_valkind_t)
    kindsOf valtype_vec = VU.generateM s $ \ix -> do
      cur_valtype_ptr <- peekElemOff p ix
      c'wasm_valtype_kind cur_valtype_ptr
      where
        s :: Int
        s = fromIntegral $ c'wasm_valtype_vec_t'size valtype_vec

        p :: Ptr (Ptr C'wasm_valtype_t)
        p = c'wasm_valtype_vec_t'data valtype_vec

-- | Call an exported 'TypedFunc'.
callFunc ::
  forall f r s m.
  ( Funcable f,
    Result f ~ m (Either Trap r),
    Results r,
    MonadPrim s m,
    PrimBase m
  ) =>
  Context s ->
  -- | See 'toTypedFunc'.
  TypedFunc s f ->
  f
callFunc ctx typedFunc = unsafePerformIO $ mask_ $ do
  args_and_results_ptr :: Ptr C'wasmtime_val_raw_t <- mallocArray len
  args_and_results_fp <- newForeignPtr finalizerFree args_and_results_ptr
  pure $ exportCall args_and_results_fp 0 (fromIntegral len) ctx (fromTypedFunc typedFunc)
  where
    nargs = nrOfParams $ Proxy @f
    nres = nrOfResults $ Proxy @r
    len = max nargs nres

--------------------------------------------------------------------------------
-- Externs
--------------------------------------------------------------------------------

-- | Container for different kinds of extern items (like @'Func's@) that can be
-- imported into new @'Instance's@ using 'newInstance' and exported from
-- existing instances using 'getExport'.
data Extern s where
  Extern :: forall e s. (Externable e) => TypeRep e -> e s -> Extern s

-- | Class of types that can be imported and exported from @'Instance's@.
class (Storable (CType e), Typeable e) => Externable (e :: Type -> Type) where
  type CType e :: Type
  toCExtern :: e s -> CType e
  externKind :: Proxy e -> C'wasmtime_extern_kind_t

instance Externable Func where
  type CType Func = C'wasmtime_func
  toCExtern = getWasmtimeFunc
  externKind _proxy = c'WASMTIME_EXTERN_FUNC

instance Externable Memory where
  type CType Memory = C'wasmtime_memory_t
  toCExtern = getWasmtimeMemory
  externKind _proxy = c'WASMTIME_EXTERN_MEMORY

-- | Turn any externable value (like a 'Func') into the 'Extern' container.
toExtern :: forall e s. Externable e => e s -> Extern s
toExtern = Extern (typeRep :: TypeRep e)

-- | Converts an 'Extern' object back into an ordinary Haskell value (like a 'Func')
-- of the correct type.
fromExtern :: forall e s. Externable e => Extern s -> Maybe (e s)
fromExtern (Extern t v)
  | Just HRefl <- t `eqTypeRep` rep = Just v
  | otherwise = Nothing
  where
    rep = typeRep :: TypeRep e

withExterns :: Vector (Extern s) -> (Ptr C'wasmtime_extern -> CSize -> IO a) -> IO a
withExterns externs f = allocaArray n $ \externs_ptr0 ->
  let pokeExternsFrom ix
        | ix == n = f externs_ptr0 $ fromIntegral n
        | otherwise =
            case V.unsafeIndex externs ix of
              Extern _typeRep (e :: e s) -> do
                let externs_ptr = advancePtr externs_ptr0 ix
                poke (p'wasmtime_extern'kind externs_ptr) $ externKind (Proxy @e)
                poke (castPtr $ p'wasmtime_extern'of externs_ptr) $ toCExtern e
                pokeExternsFrom (ix + 1)
   in pokeExternsFrom 0
  where
    n = V.length externs

--------------------------------------------------------------------------------
-- Memory
--------------------------------------------------------------------------------

-- | A descriptor for a WebAssembly memory type.
--
-- Memories are described in units of pages (64KB) and represent contiguous chunks of addressable memory.
newtype MemoryType = MemoryType {unMemoryType :: ForeignPtr C'wasm_memorytype_t}

-- | Creates a descriptor for a WebAssembly 'Memory' with the specified minimum number of memory pages,
-- an optional maximum of memory pages, and a 64 bit flag, where false defaults to 32 bit memory.
newMemoryType ::
  -- | Minimum number of memory pages.
  Word64 ->
  -- | Optional maximum of memory pages.
  Maybe Word64 ->
  -- | 'WordLength', either Bit32 or Bit64
  WordLength ->
  MemoryType
newMemoryType mini mbMax wordLen = unsafePerformIO $ mask_ $ do
  mem_type_ptr <- c'wasmtime_memorytype_new mini max_present maxi is64
  MemoryType <$> newForeignPtr p'wasm_memorytype_delete mem_type_ptr
  where
    (max_present, maxi) = maybe (False, 0) (True,) mbMax
    is64 = wordLen == Bit64

withMemoryType :: MemoryType -> (Ptr C'wasm_memorytype_t -> IO a) -> IO a
withMemoryType = withForeignPtr . unMemoryType

-- | Returns the minimum number of pages of this memory descriptor.
getMin :: MemoryType -> Word64
getMin mt = unsafePerformIO $ withMemoryType mt c'wasmtime_memorytype_minimum

-- | Returns the maximum number of pages of this memory descriptor, if one was set.
getMax :: MemoryType -> Maybe Word64
getMax mt = unsafePerformIO $
  withMemoryType mt $ \mem_type_ptr ->
    alloca $ \(max_ptr :: Ptr Word64) -> do
      maxPresent <- c'wasmtime_memorytype_maximum mem_type_ptr max_ptr
      if not maxPresent
        then pure Nothing
        else Just <$> peek max_ptr

-- | Returns false if the memory is 32 bit and true if it is 64 bit.
is64Memory :: MemoryType -> Bool
is64Memory mt = unsafePerformIO $ withMemoryType mt c'wasmtime_memorytype_is64

-- | Returns Bit32 or Bit64 :: 'WordLength'
wordLength :: MemoryType -> WordLength
wordLength mt = if is64Memory mt then Bit64 else Bit32

-- | A WebAssembly linear memory.
--
-- WebAssembly memories represent a contiguous array of bytes that have a size
-- that is always a multiple of the WebAssembly page size, currently 64 kilobytes.
--
-- WebAssembly memory is used for global data (not to be confused with
-- wasm global items), statics in C/C++/Rust, shadow stack memory, etc.
-- Accessing wasm memory is generally quite fast.
--
-- Memories, like other wasm items, are owned by a 'Store'.
newtype Memory s = Memory {getWasmtimeMemory :: C'wasmtime_memory_t}
  deriving (Show)

-- | Create new memory with the properties described in the 'MemoryType' argument.
newMemory :: MonadPrim s m => Context s -> MemoryType -> m (Either WasmtimeError (Memory s))
newMemory ctx memtype = unsafeIOToPrim $
  try $
    withContext ctx $ \ctx_ptr ->
      withMemoryType memtype $ \memtype_ptr ->
        alloca $ \mem_ptr -> do
          error_ptr <- c'wasmtime_memory_new ctx_ptr memtype_ptr mem_ptr
          checkWasmtimeError error_ptr
          Memory <$> peek mem_ptr

withMemory :: Memory s -> (Ptr C'wasmtime_memory_t -> IO a) -> IO a
withMemory = with . getWasmtimeMemory

-- | Returns the 'MemoryType' descriptor for this memory.
getMemoryType :: Context s -> Memory s -> MemoryType
getMemoryType ctx mem = unsafePerformIO $
  withContext ctx $ \ctx_ptr ->
    withMemory mem $ \mem_ptr -> mask_ $ do
      memtype_ptr <- c'wasmtime_memory_type ctx_ptr mem_ptr
      MemoryType <$> newForeignPtr p'wasm_memorytype_delete memtype_ptr

-- | Returns the linear memory size in bytes. Always a multiple of 64KB (65536).
getMemorySizeBytes :: MonadPrim s m => Context s -> Memory s -> m Word64
getMemorySizeBytes ctx mem = unsafeIOToPrim $
  withContext ctx $ \ctx_ptr ->
    withMemory mem (fmap fromIntegral . c'wasmtime_memory_data_size ctx_ptr)

-- | Returns the length of the linear memory in WebAssembly pages
getMemorySizePages :: MonadPrim s m => Context s -> Memory s -> m Word64
getMemorySizePages ctx mem = unsafeIOToPrim $
  withContext ctx $ \ctx_ptr ->
    withMemory mem $ \mem_ptr ->
      c'wasmtime_memory_size ctx_ptr mem_ptr

-- | Grow the linar memory by a number of pages.
growMemory :: MonadPrim s m => Context s -> Memory s -> Word64 -> m (Either WasmtimeError Word64)
growMemory ctx mem delta = unsafeIOToPrim $
  try $
    withContext ctx $ \ctx_ptr ->
      withMemory mem $ \mem_ptr ->
        alloca $ \before_size_ptr -> do
          error_ptr <- c'wasmtime_memory_grow ctx_ptr mem_ptr delta before_size_ptr
          checkWasmtimeError error_ptr
          peek before_size_ptr

-- | Takes a continuation which can mutate the linear memory. The continuation is provided with
-- a pointer to the beginning of the memory and its maximum length. Do not write outside the bounds!
--
-- This function is unsafe, because we do not restrict the continuation in any way.
-- DO NOT call exported wasm functions, grow the memory or do anything similar in the continuation!
unsafeWithMemory :: Context s -> Memory s -> (Ptr Word8 -> Size -> IO a) -> IO a
unsafeWithMemory ctx mem f =
  withContext ctx $ \ctx_ptr ->
    withMemory mem $ \mem_ptr -> do
      mem_size <- fromIntegral <$> c'wasmtime_memory_data_size ctx_ptr mem_ptr
      mem_data_ptr <- c'wasmtime_memory_data ctx_ptr mem_ptr
      f mem_data_ptr mem_size

-- | Returns a copy of the whole linear memory as a bytestring.
readMemory :: MonadPrim s m => Context s -> Memory s -> m B.ByteString
readMemory ctx mem = unsafeIOToPrim $
  unsafeWithMemory ctx mem $ \mem_data_ptr mem_size ->
    BI.create (fromIntegral mem_size) $ \dst_ptr ->
      BI.memcpy dst_ptr mem_data_ptr (fromIntegral mem_size)

-- | Takes an offset and a length, and returns a copy of the memory starting at offset until offset + length.
-- Returns @Left MemoryAccessError@ if offset + length exceeds the length of the memory.
readMemoryAt :: MonadPrim s m => Context s -> Memory s -> Offset -> Size -> m (Either MemoryAccessError B.ByteString)
readMemoryAt ctx mem offset len = do
  max_len <- getMemorySizeBytes ctx mem
  unsafeIOToPrim $ do
    if offset + len > max_len
      then pure $ Left MemoryAccessError
      else do
        res <- unsafeWithMemory ctx mem $ \mem_data_ptr mem_size ->
          BI.create (fromIntegral mem_size) $ \dst_ptr ->
            BI.memcpy dst_ptr (advancePtr mem_data_ptr (fromIntegral offset)) (fromIntegral mem_size)
        pure $ Right res

-- | Safely writes a 'ByteString' to this memory at the given offset.
--
-- If the @offset@ + the length of the @ByteString@ exceeds the
-- current memory capacity, then none of the @ByteString@ is written
-- to memory and @'Left' 'MemoryAccessError'@ is returned.
writeMemory ::
  MonadPrim s m =>
  Context s ->
  Memory s ->
  -- | Offset
  Int ->
  B.ByteString ->
  m (Either MemoryAccessError ())
writeMemory ctx mem offset (BI.BS fp n) =
  unsafeIOToPrim $ unsafeWithMemory ctx mem $ \dst sz ->
    if offset + n > fromIntegral sz
      then pure $ Left MemoryAccessError
      else withForeignPtr fp $ \src ->
        Right <$> BI.memcpy (advancePtr dst offset) src n

-- | Error for out of bounds 'Memory' access.
data MemoryAccessError = MemoryAccessError deriving (Show)

instance Exception MemoryAccessError

--------------------------------------------------------------------------------
-- Tables
--------------------------------------------------------------------------------
newtype TableType = TableType {unTableType :: ForeignPtr C'wasm_tabletype_t}

data TableRefType = FuncRef | ExternRef
  deriving (Show, Eq)

newTableType :: TableRefType -> C'wasm_limits_t -> IO TableType
newTableType valtype limits =
  alloca $ \valtype_ptr ->
    alloca $ \(limits_ptr :: Ptr C'wasm_limits_t) -> do
      poke valtype_ptr valtype
      poke limits_ptr limits
      tabletype_ptr <- c'wasm_tabletype_new valtype_ptr limits_ptr
      TableType <$> newForeignPtr p'wasm_tabletype_delete tabletype_ptr

type A = C'wasm_limits_t

--------------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------------

-- | Representation of a instance in Wasmtime.
newtype Instance s = Instance {unInstance :: ForeignPtr C'wasmtime_instance_t}

-- | Instantiate a wasm module.
--
-- This function will instantiate a WebAssembly module with the provided
-- imports, creating a WebAssembly instance. The returned instance can then
-- afterwards be inspected for exports.
newInstance ::
  MonadPrim s m =>
  Context s ->
  Module ->
  -- | This function requires that this `imports` vector has the same size as
  -- the imports of the given 'Module'. Additionally the `imports` must be 1:1
  -- lined up with the imports of the specified module. This is intended to be
  -- relatively low level, and 'newInstanceLinked' is provided for a more
  -- ergonomic name-based resolution API.
  Vector (Extern s) ->
  m (Either Trap (Instance s))
newInstance ctx m externs = unsafeIOToPrim $
  withContext ctx $ \ctx_ptr ->
    withModule m $ \mod_ptr ->
      withExterns externs $ \externs_ptr n -> do
        inst_fp <- mallocForeignPtr
        withForeignPtr inst_fp $ \(inst_ptr :: Ptr C'wasmtime_instance_t) ->
          alloca $ \(trap_ptr_ptr :: Ptr (Ptr C'wasm_trap_t)) -> do
            error_ptr <-
              c'wasmtime_instance_new
                ctx_ptr
                mod_ptr
                externs_ptr
                n
                inst_ptr
                trap_ptr_ptr
            checkWasmtimeError error_ptr
            trap_ptr <- peek trap_ptr_ptr
            if trap_ptr == nullPtr
              then pure $ Right $ Instance inst_fp
              else Left <$> newTrapFromPtr trap_ptr

withInstance :: Instance s -> (Ptr C'wasmtime_instance_t -> IO a) -> IO a
withInstance = withForeignPtr . unInstance

-- | Get an export by name from an instance.
getExport :: MonadPrim s m => Context s -> Instance s -> String -> m (Maybe (Extern s))
getExport ctx inst name = unsafeIOToPrim $
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
          if not found
            then pure Nothing
            else do
              let kind_ptr :: Ptr C'wasmtime_extern_kind_t
                  kind_ptr = p'wasmtime_extern'kind extern_ptr

                  of_ptr :: Ptr C'wasmtime_extern_union_t
                  of_ptr = p'wasmtime_extern'of extern_ptr

              k <- peek kind_ptr

              let fromCExtern ::
                    forall e s.
                    (Externable e) =>
                    (CType e -> e s) ->
                    MaybeT IO (Extern s)
                  fromCExtern constr = do
                    guard $ k == externKind (Proxy @e)
                    liftIO $ do
                      let ex_ptr = castPtr of_ptr
                      ex <- constr <$> peek ex_ptr
                      pure $ toExtern ex

              runMaybeT $ fromCExtern Func <|> fromCExtern Memory

-- | Convenience function which gets the named export from the store
-- ('getExport'), checks if it's a 'Func' ('fromExtern') and finally checks if
-- the type of the function matches the desired type @f@ ('toTypedFunc').
getExportedTypedFunc ::
  forall s m f r.
  (MonadPrim s m, Funcable f, Result f ~ m (Either Trap r), Results r) =>
  Context s ->
  Instance s ->
  String ->
  m (Maybe (TypedFunc s f))
getExportedTypedFunc ctx inst name = do
  mbExtern <- getExport ctx inst name
  case mbExtern >>= fromExtern of
    Nothing -> pure Nothing
    Just (func :: Func s) -> toTypedFunc ctx func

getExportedMemory ::
  forall s m.
  (MonadPrim s m) =>
  Context s ->
  Instance s ->
  String ->
  m (Maybe (Memory s))
getExportedMemory ctx inst name = (>>= fromExtern) <$> getExport ctx inst name

--------------------------------------------------------------------------------
-- Traps
--------------------------------------------------------------------------------

-- | Under some conditions, certain WASM instructions may produce a
-- trap, which immediately aborts execution. Traps cannot be handled
-- by WebAssembly code, but are reported to the outside environment,
-- where they will be caught.
newtype Trap = Trap {unTrap :: ForeignPtr C'wasm_trap_t}

-- | A trap with a given message.
newTrap :: String -> Trap
newTrap msg = unsafePerformIO $ withCStringLen msg $ \(p, n) ->
  mask_ $ c'wasmtime_trap_new p (fromIntegral n) >>= newTrapFromPtr

newTrapFromPtr :: Ptr C'wasm_trap_t -> IO Trap
newTrapFromPtr = fmap Trap . newForeignPtr p'wasm_trap_delete

withTrap :: Trap -> (Ptr C'wasm_trap_t -> IO a) -> IO a
withTrap trap = withForeignPtr (unTrap trap)

instance Show Trap where
  show trap = unsafePerformIO $
    withTrap trap $ \trap_ptr ->
      alloca $ \(wasm_msg_ptr :: Ptr C'wasm_message_t) -> do
        c'wasm_trap_message trap_ptr wasm_msg_ptr
        let p = castPtr wasm_msg_ptr :: Ptr C'wasm_byte_vec_t
        peekByteVecAsString p

instance Exception Trap

-- | Attempts to extract the trap code from the given trap.
--
-- Returns 'Just' the trap code if the trap is an instruction trap
-- triggered while executing Wasm. Returns 'Nothing' otherwise,
-- i.e. when the trap was created using 'newTrap' for example.
trapCode :: Trap -> Maybe TrapCode
trapCode trap = unsafePerformIO $ withTrap trap $ \trap_ptr ->
  alloca $ \code_ptr -> do
    isInstructionTrap <- c'wasmtime_trap_code trap_ptr code_ptr
    if isInstructionTrap
      then Just . toTrapCode <$> peek code_ptr
      else pure Nothing

toTrapCode :: C'wasmtime_trap_code_t -> TrapCode
toTrapCode code
  | code == c'WASMTIME_TRAP_CODE_STACK_OVERFLOW = TRAP_CODE_STACK_OVERFLOW
  | code == c'WASMTIME_TRAP_CODE_MEMORY_OUT_OF_BOUNDS = TRAP_CODE_MEMORY_OUT_OF_BOUNDS
  | code == c'WASMTIME_TRAP_CODE_HEAP_MISALIGNED = TRAP_CODE_HEAP_MISALIGNED
  | code == c'WASMTIME_TRAP_CODE_TABLE_OUT_OF_BOUNDS = TRAP_CODE_TABLE_OUT_OF_BOUNDS
  | code == c'WASMTIME_TRAP_CODE_INDIRECT_CALL_TO_NULL = TRAP_CODE_INDIRECT_CALL_TO_NULL
  | code == c'WASMTIME_TRAP_CODE_BAD_SIGNATURE = TRAP_CODE_BAD_SIGNATURE
  | code == c'WASMTIME_TRAP_CODE_INTEGER_OVERFLOW = TRAP_CODE_INTEGER_OVERFLOW
  | code == c'WASMTIME_TRAP_CODE_INTEGER_DIVISION_BY_ZERO = TRAP_CODE_INTEGER_DIVISION_BY_ZERO
  | code == c'WASMTIME_TRAP_CODE_BAD_CONVERSION_TO_INTEGER = TRAP_CODE_BAD_CONVERSION_TO_INTEGER
  | code == c'WASMTIME_TRAP_CODE_UNREACHABLE_CODE_REACHED = TRAP_CODE_UNREACHABLE_CODE_REACHED
  | code == c'WASMTIME_TRAP_CODE_INTERRUPT = TRAP_CODE_INTERRUPT
  | code == c'WASMTIME_TRAP_CODE_OUT_OF_FUEL = TRAP_CODE_OUT_OF_FUEL
  | otherwise = error $ "Unknown trap code " ++ show code

-- | Trap codes for instruction traps.
data TrapCode
  = -- | The current stack space was exhausted.
    TRAP_CODE_STACK_OVERFLOW
  | -- | An out-of-bounds memory access.
    TRAP_CODE_MEMORY_OUT_OF_BOUNDS
  | -- | A wasm atomic operation was presented with a not-naturally-aligned
    -- linear-memory address.
    TRAP_CODE_HEAP_MISALIGNED
  | -- | An out-of-bounds access to a table.
    TRAP_CODE_TABLE_OUT_OF_BOUNDS
  | -- | Indirect call to a null table entry.
    TRAP_CODE_INDIRECT_CALL_TO_NULL
  | -- | Signature mismatch on indirect call.
    TRAP_CODE_BAD_SIGNATURE
  | -- | An integer arithmetic operation caused an overflow.
    TRAP_CODE_INTEGER_OVERFLOW
  | -- | An integer division by zero.
    TRAP_CODE_INTEGER_DIVISION_BY_ZERO
  | -- | Failed float-to-int conversion.
    TRAP_CODE_BAD_CONVERSION_TO_INTEGER
  | -- | Code that was supposed to have been unreachable was reached.
    TRAP_CODE_UNREACHABLE_CODE_REACHED
  | -- | Execution has potentially run too long and may be interrupted.
    TRAP_CODE_INTERRUPT
  | -- | Execution has run out of the configured fuel amount.
    TRAP_CODE_OUT_OF_FUEL
  deriving (Show, Eq)

-- | Returns 'Just' the top frame of the wasm stack responsible for this trap.
--
-- This function may return 'Nothing', for example, for traps created when there
-- wasn't anything on the wasm stack.
trapOrigin :: Trap -> Maybe Frame
trapOrigin trap = unsafePerformIO $ withTrap trap $ \trap_ptr -> mask_ $ do
  frame_ptr <- c'wasm_trap_origin trap_ptr
  if frame_ptr == nullPtr
    then pure Nothing
    else Just <$> newFrameFromPtr frame_ptr

-- | Returns the trace of wasm frames for this trap.
--
-- Frames are listed in order of increasing depth, with the most recently called
-- function at the front of the vector and the base function on the stack at the
-- end.
trapTrace :: Trap -> Vector Frame
trapTrace trap = unsafePerformIO $ withTrap trap $ \trap_ptr ->
  alloca $ \(frame_vec_ptr :: Ptr C'wasm_frame_vec_t) -> mask_ $ do
    c'wasm_trap_trace trap_ptr frame_vec_ptr
    frame_vec <- peek frame_vec_ptr
    let sz = fromIntegral $ c'wasm_frame_vec_t'size frame_vec :: Int
    let dt = c'wasm_frame_vec_t'data frame_vec :: Ptr (Ptr C'wasm_frame_t)
    vec <- V.generateM sz $ \ix -> do
      frame_ptr <- peekElemOff dt ix
      newFrameFromPtr frame_ptr
    c'wasm_frame_vec_delete frame_vec_ptr
    pure vec

--------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------

-- | A frame of a wasm stack trace.
--
-- Can be retrieved using 'trapOrigin' or 'trapTrace'.
newtype Frame = Frame {unFrame :: ForeignPtr C'wasm_frame_t}

newFrameFromPtr :: Ptr C'wasm_frame_t -> IO Frame
newFrameFromPtr = fmap Frame . newForeignPtr p'wasm_frame_delete

withFrame :: Frame -> (Ptr C'wasm_frame_t -> IO a) -> IO a
withFrame frame = withForeignPtr (unFrame frame)

-- | Returns 'Just' a human-readable name for this frame's function.
--
-- This function will attempt to load a human-readable name for the function
-- this frame points to. This function may return 'Nothing'.
frameFuncName :: Frame -> Maybe String
frameFuncName frame = unsafePerformIO $ withFrame frame $ \frame_ptr -> do
  name_ptr <- c'wasmtime_frame_func_name frame_ptr
  if name_ptr == nullPtr
    then pure Nothing
    else do
      let p = castPtr name_ptr :: Ptr C'wasm_byte_vec_t
      Just <$> peekByteVecAsString p

-- | Returns 'Just' a human-readable name for this frame's module.
--
-- This function will attempt to load a human-readable name for the module this
-- frame points to. This function may return 'Nothing'.
frameModuleName :: Frame -> Maybe String
frameModuleName frame = unsafePerformIO $ withFrame frame $ \frame_ptr -> do
  name_ptr <- c'wasmtime_frame_module_name frame_ptr
  if name_ptr == nullPtr
    then pure Nothing
    else do
      let p = castPtr name_ptr :: Ptr C'wasm_byte_vec_t
      Just <$> peekByteVecAsString p

-- | Returns the function index in the original wasm module that this
-- frame corresponds to.
frameFuncIndex :: Frame -> Word32
frameFuncIndex frame = unsafePerformIO $ withFrame frame c'wasm_frame_func_index

-- | Returns the byte offset from the beginning of the function in the
-- original wasm file to the instruction this frame points to.
frameFuncOffset :: Frame -> Word32
frameFuncOffset frame = unsafePerformIO $ withFrame frame c'wasm_frame_func_offset

-- | Returns the byte offset from the beginning of the original wasm
-- file to the instruction this frame points to.
frameModuleOffset :: Frame -> Word32
frameModuleOffset frame = unsafePerformIO $ withFrame frame c'wasm_frame_module_offset

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
withWasmtimeError = withForeignPtr . unWasmtimeError

instance Exception WasmtimeError

instance Show WasmtimeError where
  show wasmtimeError = unsafePerformIO $
    withWasmtimeError wasmtimeError $ \error_ptr ->
      alloca $ \(wasm_name_ptr :: Ptr C'wasm_name_t) -> do
        c'wasmtime_error_message error_ptr wasm_name_ptr
        let p = castPtr wasm_name_ptr :: Ptr C'wasm_byte_vec_t
        peekByteVecAsString p

--------------------------------------------------------------------------------
-- Utils
--------------------------------------------------------------------------------

peekByteVecAsString :: Ptr C'wasm_byte_vec_t -> IO String
peekByteVecAsString p = do
  data_ptr <- peek $ p'wasm_byte_vec_t'data p
  size <- peek $ p'wasm_byte_vec_t'size p
  peekCStringLen (data_ptr, fromIntegral size)
