{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
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
import Bindings.Wasmtime.Val
import Control.Exception (Exception, mask_, onException, throwIO, try)
import Control.Monad (when)
import Control.Monad.Primitive (MonadPrim, PrimBase, unsafeIOToPrim, unsafePrimToIO)
import Control.Monad.ST (ST)
import qualified Data.ByteString as B
import qualified Data.ByteString.Internal as BI
import Data.Foldable (for_)
import Data.Int (Int32, Int64)
import Data.Kind (Type)
import Data.Proxy (Proxy (..))
import Data.Typeable (Typeable)
import Data.WideWord.Word128 (Word128)
import Data.Word (Word64, Word8)
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
import Text.ParserCombinators.ReadP (get)
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

newFuncType :: forall f. Funcable f => Proxy f -> IO FuncType
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
  results :: Proxy r -> [C'wasm_valkind_t]
  numResults :: Proxy r -> Int
  writeResults :: Ptr C'wasmtime_val_t -> r -> IO ()
  readResults :: Ptr C'wasmtime_val_raw_t -> IO r

instance Results () where
  results _proxy = []
  numResults _proxy = 0
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
  results proxy = [kind proxy]
  numResults _proxy = 1
  writeResults = pokeVal
  readResults = peekRawVal

instance Results Int64 where
  results proxy = [kind proxy]
  numResults _proxy = 1
  writeResults = pokeVal
  readResults = peekRawVal

instance Results Float where
  results proxy = [kind proxy]
  numResults _proxy = 1
  writeResults = pokeVal
  readResults = peekRawVal

instance Results Double where
  results proxy = [kind proxy]
  numResults _proxy = 1
  writeResults = pokeVal
  readResults = peekRawVal

instance Results Word128 where
  results proxy = [kind proxy]
  numResults _proxy = 1
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
  results _proxy = [kind (Proxy @a), kind (Proxy @b)]
  numResults _proxy = 2
  writeResults result_ptr (a, b) = do
    pokeVal result_ptr a
    pokeVal (advancePtr result_ptr 1) b
  readResults result_ptr =
    (,)
      <$> peekRawVal result_ptr
      <*> peekRawVal (advancePtr result_ptr 1)

instance (Kind a, Kind b, Kind c) => Results (a, b, c) where
  results _proxy = [kind (Proxy @a), kind (Proxy @b), kind (Proxy @c)]
  numResults _proxy = 3
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
  results _proxy = [kind (Proxy @a), kind (Proxy @b), kind (Proxy @c), kind (Proxy @d)]
  numResults _proxy = 4
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
    Result f ~ m r,
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
        Nothing -> error "TODO"
        Just (action :: m r) -> do
          r <- unsafePrimToIO action
          let n = fromIntegral nresults
          if n == expected
            then writeResults result_ptr r
            else -- TODO: use throwIO

              error $
                "Expected the number of results to be "
                  ++ show expected
                  ++ " but got "
                  ++ show n

      -- TODO
      pure nullPtr

    expected :: Int
    expected = numResults $ Proxy @r

-- | Class of Haskell functions / actions that can be imported into and exported
-- from WASM modules.
class Funcable f where
  type Result f :: Type

  params :: Proxy f -> [C'wasm_valkind_t]
  result :: Proxy f -> [C'wasm_valkind_t]

  paramsLen :: Proxy f -> Int
  resultLen :: Proxy f -> Int

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

  params _proxy = kind (Proxy @a) : params (Proxy @b)
  result _proxy = result (Proxy @b)

  paramsLen _proxy = 1 + paramsLen (Proxy @b)
  resultLen _proxy = resultLen (Proxy @b)

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

instance Results r => Funcable (IO r) where
  type Result (IO r) = IO r

  params _proxy = []
  result _proxy = results (Proxy @r)

  paramsLen _proxy = 0
  resultLen _proxy = numResults (Proxy @r)

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
            -- TODO: handle traps properly!!!
            when (trap_ptr /= nullPtr) $
              alloca $ \(message_ptr :: Ptr C'wasm_message_t) -> do
                c'wasm_trap_message trap_ptr message_ptr
                message_vec :: C'wasm_message_t <- peek message_ptr
                message <-
                  peekCStringLen
                    ( c'wasm_byte_vec_t'data message_vec,
                      fromIntegral $ c'wasm_byte_vec_t'size message_vec
                    )
                putStrLn $ "TRAP: " ++ message

            readResults args_and_results_ptr

instance Results r => Funcable (ST s r) where
  type Result (ST s r) = ST s r

  params _proxy = []
  result _proxy = results (Proxy @r)

  paramsLen _proxy = 0
  resultLen _proxy = numResults (Proxy @r)

  importCall x _ 0 = pure $ Just x
  importCall _ _ _ = pure Nothing

  exportCall args_and_results_fp ix len ctx func =
    unsafeIOToPrim $
      exportCall args_and_results_fp ix len ctx func

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
  forall s m f.
  (MonadPrim s m, Funcable f) =>
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
      (actual_params :: [C'wasm_valkind_t]) <- kindsOf func_params
      (actual_results :: [C'wasm_valkind_t]) <- kindsOf func_results
      if desired_params == actual_params
        && desired_results == actual_results
        then pure $ Just $ TypedFunc func
        else pure Nothing
  where
    desired_params = params $ Proxy @f
    desired_results = result $ Proxy @f

    kindsOf :: C'wasm_valtype_vec_t -> IO [C'wasm_valkind_t]
    kindsOf valtype_vec = go s []
      where
        s :: Int
        s = fromIntegral $ c'wasm_valtype_vec_t'size valtype_vec

        p :: Ptr (Ptr C'wasm_valtype_t)
        p = c'wasm_valtype_vec_t'data valtype_vec

        go :: Int -> [C'wasm_valkind_t] -> IO [C'wasm_valkind_t]
        go 0 acc = pure acc
        go n acc = do
          let ix = n - 1
          cur_valtype_ptr <- peekElemOff p ix
          valkind <- c'wasm_valtype_kind cur_valtype_ptr
          go ix (valkind : acc)

-- | Call an exported 'TypedFunc'.
callFunc ::
  forall f r s m.
  (Funcable f, Result f ~ m r, MonadPrim s m, PrimBase m) =>
  Context s ->
  -- | See 'toTypedFunc'.
  TypedFunc s f ->
  f
callFunc ctx typedFunc = unsafePerformIO $ mask_ $ do
  args_and_results_ptr :: Ptr C'wasmtime_val_raw_t <- mallocArray len
  args_and_results_fp <- newForeignPtr finalizerFree args_and_results_ptr
  pure $ exportCall args_and_results_fp 0 (fromIntegral len) ctx (fromTypedFunc typedFunc)
  where
    nargs = paramsLen $ Proxy @f
    nres = resultLen $ Proxy @f
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
  getCExtern :: e s -> CType e
  externKind :: Proxy e -> C'wasmtime_extern_kind_t

instance Externable Func where
  type CType Func = C'wasmtime_func
  getCExtern = getWasmtimeFunc
  externKind _proxy = c'WASMTIME_EXTERN_FUNC

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

withExterns :: [Extern s] -> (Ptr C'wasmtime_extern -> CSize -> IO a) -> IO a
withExterns externs f = allocaArray n $ \externs_ptr0 ->
  let go _externs_ptr [] = f externs_ptr0 $ fromIntegral n
      go externs_ptr ((Extern _typeRep (e :: e s)) : es) = do
        poke (p'wasmtime_extern'kind externs_ptr) $ externKind (Proxy @e)
        poke (castPtr (p'wasmtime_extern'of externs_ptr)) $ getCExtern e
        go (advancePtr externs_ptr 1) es
   in go externs_ptr0 externs
  where
    n = length externs

--------------------------------------------------------------------------------
-- Memory
--------------------------------------------------------------------------------

newtype MemoryType = MemoryType {unMemoryType :: ForeignPtr C'wasm_memorytype_t}

newMemoryType :: Word64 -> Maybe Word64 -> Bool -> MemoryType
newMemoryType mini mbMax is64 = unsafePerformIO $ mask_ $ do
  mem_type_ptr <- c'wasmtime_memorytype_new mini max_present maxi is64
  MemoryType <$> newForeignPtr p'wasm_memorytype_delete mem_type_ptr
  where
    (max_present, maxi) = maybe (False, 0) (True,) mbMax

-- TODO: typeclass for these withXs

withMemoryType :: MemoryType -> (Ptr C'wasm_memorytype_t -> IO a) -> IO a
withMemoryType = withForeignPtr . unMemoryType

getMin :: MemoryType -> Word64
getMin mt = unsafePerformIO $ withMemoryType mt c'wasmtime_memorytype_minimum

getMax :: MemoryType -> Maybe Word64
getMax mt = unsafePerformIO $
  withMemoryType mt $ \mem_type_ptr ->
    alloca $ \(max_ptr :: Ptr Word64) -> do
      maxPresent <- c'wasmtime_memorytype_maximum mem_type_ptr max_ptr
      if not maxPresent
        then pure Nothing
        else Just <$> peek max_ptr

is64Memory :: MemoryType -> Bool
is64Memory mt = unsafePerformIO $ withMemoryType mt c'wasmtime_memorytype_is64

newtype Memory s = Memory {getMemory :: C'wasmtime_memory_t}

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
withMemory = with . getMemory

getMemoryType :: Context s -> Memory s -> MemoryType
getMemoryType ctx mem = unsafePerformIO $
  withContext ctx $ \ctx_ptr ->
    withMemory mem $ \mem_ptr -> mask_ $ do
      memtype_ptr <- c'wasmtime_memory_type ctx_ptr mem_ptr
      MemoryType <$> newForeignPtr p'wasm_memorytype_delete memtype_ptr

-- | Returns the length of the linear memory in WebAssembly pages
getMemorySizePages :: Context s -> Memory s -> Word64
getMemorySizePages ctx mem = unsafePerformIO $
  withContext ctx $ \ctx_ptr ->
    withMemory mem $ \mem_ptr ->
      c'wasmtime_memory_size ctx_ptr mem_ptr

growMemory :: MonadPrim s m => Context s -> Memory s -> Word64 -> m (Either WasmtimeError Word64)
growMemory ctx mem delta = unsafeIOToPrim $
  try $
    withContext ctx $ \ctx_ptr ->
      withMemory mem $ \mem_ptr ->
        alloca $ \before_size_ptr -> do
          error_ptr <- c'wasmtime_memory_grow ctx_ptr mem_ptr delta before_size_ptr
          checkWasmtimeError error_ptr
          peek before_size_ptr

unsafeWithMemory :: Context s -> Memory s -> (Ptr Word8 -> Int -> IO a) -> IO a
unsafeWithMemory ctx mem f =
  withContext ctx $ \ctx_ptr ->
    withMemory mem $ \mem_ptr -> do
      mem_size <- fromIntegral <$> c'wasmtime_memory_data_size ctx_ptr mem_ptr
      mem_data_ptr <- c'wasmtime_memory_data ctx_ptr mem_ptr
      f mem_data_ptr mem_size

freezeMemory :: MonadPrim s m => Context s -> Memory s -> m B.ByteString
freezeMemory ctx mem = unsafeIOToPrim $
  unsafeWithMemory ctx mem $ \mem_data_ptr mem_size ->
    BI.create mem_size $ \dst_ptr ->
      BI.memcpy dst_ptr mem_data_ptr mem_size

-- have to get the length of the data and the data pointer
-- unsafeGetMemoryData :: Context s -> Memory s -> IO B.ByteString
-- unsafeGetMemoryData ctx mem =
--   withContext ctx $ \ctx_ptr ->
--     withMemory mem $ \mem_ptr -> do
--       mem_size <- c'wasmtime_memory_data_size ctx_ptr mem_ptr
--       mem_data_ptr <- c'wasmtime_memory_data ctx_ptr mem_ptr

--       undefined

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
newInstance :: MonadPrim s m => Context s -> Module -> [Extern s] -> m (Instance s)
newInstance ctx m externs = unsafeIOToPrim $
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
                  (func :: Func s) <- Func <$> peek func_ptr
                  pure $ Just $ toExtern func
                else pure Nothing
            else pure Nothing

-- | Convenience function which gets the named export from the store
-- ('getExport'), checks if it's a 'Func' ('fromExtern') and finally checks if
-- the type of the function matches the desired type @f@ ('toTypedFunc').
getExportedTypedFunc ::
  forall s m f.
  (MonadPrim s m, Funcable f) =>
  Context s ->
  Instance s ->
  String ->
  m (Maybe (TypedFunc s f))
getExportedTypedFunc ctx inst name = do
  mbExtern <- getExport ctx inst name
  case mbExtern >>= fromExtern of
    Nothing -> pure Nothing
    Just (func :: Func s) -> toTypedFunc ctx func

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
        let p :: Ptr C'wasm_byte_vec_t
            p = castPtr wasm_name_ptr
        data_ptr <- peek $ p'wasm_byte_vec_t'data p
        size <- peek $ p'wasm_byte_vec_t'size p
        peekCStringLen (data_ptr, fromIntegral size)
