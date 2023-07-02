{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ViewPatterns #-}

-- | High-level Haskell API to the wasmtime C API.
module Wasmtime
  ( -- * Engine
    Engine,
    newEngine,
    newEngineWithConfig,
    incrementEngineEpoch,

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
    setParallelCompilation,
    setCraneliftDebugVerifier,
    setCaneliftNanCanonicalization,
    -- setStaticMemoryForced, -- seems absent
    setStaticMemoryMaximumSize,
    setStaticMemoryGuardSize,
    setDynamicMemoryGuardSize,
    loadCacheConfig,

    -- ** Compilation Strategy
    setStrategy,
    Strategy,
    autoStrategy,
    craneliftStrategy,

    -- ** Optimization Level
    setCraneliftOptLevel,
    OptLevel,
    noneOptLevel,
    speedOptLevel,
    speedAndSizeOptLevel,

    -- ** Profiling Strategy
    setProfiler,
    ProfilingStrategy,
    noneProfilingStrategy,
    jitDumpProfilingStrategy,
    vTuneProfilingStrategy,
    perfMapProfilingStrategy,

    -- * WASM Conversion
    Wasm,
    wasmToBytes,
    wasmFromBytes,
    unsafeWasmFromBytes,
    wat2wasm,

    -- * Modules
    Module,
    newModule,
    serializeModule,
    deserializeModule,

    -- ** Imports
    moduleImports,
    ImportType,
    newImportType,
    importTypeModule,
    importTypeName,
    importTypeType,

    -- ** Exports
    moduleExports,
    ExportType,
    newExportType,
    exportTypeName,
    exportTypeType,

    -- ** Extern Types
    ExternType (..),

    -- * Monads (IO & ST)
    -- $monads

    -- * Stores
    Store,
    newStore,
    addFuel,
    fuelConsumed,
    consumeFuel,

    -- * Types of WASM values
    ValType (..),
    Val,

    -- * Functions

    -- ** FuncTypes
    FuncType,
    newFuncType,
    (.->.),
    funcTypeParams,
    funcTypeResults,
    Vals,
    Funcable (..),
    HListable (..),
    List (..),
    Foldr,
    Curry (..),
    Len (..),

    -- ** Funcs
    Func,
    getFuncType,
    newFunc,
    funcToFunction,

    -- * Globals

    -- ** GlobalType
    GlobalType,
    newGlobalType,
    Mutability (..),
    globalTypeValType,
    globalTypeMutability,

    -- ** Global
    Global,
    getGlobalType,

    -- ** TypedGlobal
    TypedGlobal,
    toTypedGlobal,
    unTypedGlobal,
    newTypedGlobal,

    -- ** Global Operations
    typedGlobalGet,
    typedGlobalSet,

    -- * Tables

    -- ** TableType
    TableType,
    TableRefType (..),
    TableLimits (..),
    newTableType,
    tableTypeElement,
    tableTypeLimits,

    -- ** Table
    Table,
    TableValue (..),
    newTable,

    -- ** Table operations
    growTable,
    tableGet,
    tableSet,
    getTableType,

    -- * Memory

    -- ** MemoryType
    WordLength (..),
    MemoryType,
    newMemoryType,
    getMin,
    getMax,
    is64Memory,
    wordLength,

    -- ** Memory
    Memory,
    newMemory,
    getMemoryType,
    getMemorySizeBytes,
    getMemorySizePages,

    -- ** Memory Operations
    growMemory,
    Size,
    Offset,
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

    -- ** Exports
    getExport,
    getExportedFunction,
    getExportedMemory,
    getExportedTable,
    getExportedTypedGlobal,
    getExportAtIndex,

    -- * Linker
    Linker,
    newLinker,
    linkerAllowShadowing,
    ModuleName,
    Name,
    linkerDefine,
    linkerDefineFunc,
    linkerDefineInstance,
    linkerDefineWasi,
    linkerGet,
    linkerGetDefault,
    linkerInstantiate,
    linkerModule,

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
import Bindings.Wasmtime.Engine
import Bindings.Wasmtime.Error
import Bindings.Wasmtime.Extern
import Bindings.Wasmtime.Func
import Bindings.Wasmtime.Global
import Bindings.Wasmtime.Instance
import Bindings.Wasmtime.Linker
import Bindings.Wasmtime.Memory
import Bindings.Wasmtime.Module
import Bindings.Wasmtime.Store
import Bindings.Wasmtime.Table
import Bindings.Wasmtime.Trap
import Bindings.Wasmtime.Val
import Control.Applicative ((<|>))
import Control.Exception (Exception, bracket, mask_, onException, throwIO, try)
import Control.Monad (guard, when, (>=>))
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Primitive (MonadPrim, PrimBase, unsafeIOToPrim, unsafePrimToIO)
import Control.Monad.ST (ST)
import Control.Monad.Trans.Maybe (MaybeT (MaybeT), runMaybeT)
import qualified Data.ByteString as B
import qualified Data.ByteString.Internal as BI
import Data.Functor (($>))
import Data.IORef (IORef, atomicModifyIORef, newIORef, readIORef)
import Data.Int (Int32, Int64)
import Data.Kind (Type)
import Data.List (intercalate)
import Data.Maybe (fromMaybe)
import Data.Proxy (Proxy (..))
import Data.Vector (Vector)
import qualified Data.Vector as V
import Data.WideWord.Word128 (Word128)
import Data.Word (Word32, Word64, Word8)
import Foreign.C.String (peekCStringLen, withCString, withCStringLen)
import Foreign.C.Types (CChar, CSize)
import qualified Foreign.Concurrent
import Foreign.ForeignPtr (ForeignPtr, mallocForeignPtr, newForeignPtr, withForeignPtr)
import Foreign.Marshal.Alloc (alloca)
import Foreign.Marshal.Array (advancePtr, allocaArray)
import Foreign.Marshal.Utils (with)
import Foreign.Ptr (FunPtr, Ptr, castFunPtr, castPtr, freeHaskellFunPtr, nullFunPtr, nullPtr)
import Foreign.Storable (Storable, peek, peekElemOff, poke)
import System.IO.Unsafe (unsafePerformIO)

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
withEngine = withForeignPtr . unEngine

-- | Create an 'Engine' by modifying the default 'Config'.
newEngineWithConfig :: Config -> IO Engine
newEngineWithConfig cfg = mask_ $ do
  -- Config will be deallocated by Engine
  cfg_ptr <- c'wasm_config_new
  unConfig cfg cfg_ptr `onException` c'wasm_config_delete cfg_ptr
  engine_ptr <- c'wasm_engine_new_with_config cfg_ptr
  checkAllocation engine_ptr `onException` c'wasm_config_delete cfg_ptr
  Engine <$> newForeignPtr p'wasm_engine_delete engine_ptr

-- | Increments the engine-local epoch variable.
--
-- This function will increment the engine's current epoch which can be used to
-- force WebAssembly code to trap if the current epoch goes beyond the 'Store'
-- configured epoch deadline.
incrementEngineEpoch :: Engine -> IO ()
incrementEngineEpoch engine = withEngine engine c'wasmtime_engine_increment_epoch

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

-- | Configures whether execution of WebAssembly will “consume fuel” to either
-- halt or yield execution as desired.
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

-- | Configures whether the WebAssembly bulk memory operations proposal will be
-- enabled for compilation.
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

-- Seems absent

-- | Indicates that the “static” style of memory should always be used.
-- setStaticMemoryForced :: Bool -> Config -> Config
-- setStaticMemoryForced = setConfig c'wasmtime_config_static_memory_forced_set

-- | Configures the maximum size, in bytes, where a linear memory is considered
-- static, above which it’ll be considered dynamic.
--
-- The default value for this property depends on the host platform. For 64-bit
-- platforms there’s lots of address space available, so the default configured
-- here is 4GB. WebAssembly linear memories currently max out at 4GB which means
-- that on 64-bit platforms Wasmtime by default always uses a static
-- memory. This, coupled with a sufficiently sized guard region, should produce
-- the fastest JIT code on 64-bit platforms, but does require a large address
-- space reservation for each wasm memory.  For 32-bit platforms this value
-- defaults to 1GB. This means that wasm memories whose maximum size is less
-- than 1GB will be allocated statically, otherwise they’ll be considered
-- dynamic.
setStaticMemoryMaximumSize :: Word64 -> Config
setStaticMemoryMaximumSize = setConfig c'wasmtime_config_static_memory_maximum_size_set

-- | Configures the size, in bytes, of the guard region used at the end of a
-- static memory’s address space reservation.
--
-- The default value for this property is 2GB on 64-bit platforms. This allows
-- eliminating almost all bounds checks on loads/stores with an immediate offset
-- of less than 2GB. On 32-bit platforms this defaults to 64KB.
setStaticMemoryGuardSize :: Word64 -> Config
setStaticMemoryGuardSize = setConfig c'wasmtime_config_static_memory_guard_size_set

-- | Configures the size, in bytes, of the guard region used at the end of a
-- dynamic memory’s address space reservation.
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

--------------------------------------------------------------------------------
-- Compilation Strategy
--------------------------------------------------------------------------------

-- | Configures which compilation strategy will be used for wasm modules.
--
-- Defaults to 'autoStrategy'
setStrategy :: Strategy -> Config
setStrategy (Strategy s) = setConfig c'wasmtime_config_strategy_set s

-- | Configures which compilation strategy will be used for wasm modules.
newtype Strategy = Strategy C'wasmtime_strategy_t

-- | Select compilation strategy automatically (currently defaults to cranelift)
autoStrategy :: Strategy
autoStrategy = Strategy c'WASMTIME_STRATEGY_AUTO

-- | Cranelift aims to be a reasonably fast code generator which generates high
-- quality machine code
craneliftStrategy :: Strategy
craneliftStrategy = Strategy c'WASMTIME_STRATEGY_CRANELIFT

--------------------------------------------------------------------------------
-- Optimization Level
--------------------------------------------------------------------------------

-- | Configures the Cranelift code generator optimization level.
--
-- Defaults to 'noneOptLevel'
setCraneliftOptLevel :: OptLevel -> Config
setCraneliftOptLevel (OptLevel ol) = setConfig c'wasmtime_config_cranelift_opt_level_set ol

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

--------------------------------------------------------------------------------
-- Profiling Strategy
--------------------------------------------------------------------------------

-- | Creates a default profiler based on the profiling strategy chosen.
setProfiler :: ProfilingStrategy -> Config
setProfiler (ProfilingStrategy ps) = setConfig c'wasmtime_config_profiler_set ps

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
-- WASM Conversion
--------------------------------------------------------------------------------

-- | WebAssembly binary code.
newtype Wasm = Wasm
  { -- | Return the WebAssembly binary as bytes.
    wasmToBytes :: B.ByteString
  }

-- | Unsafely convert bytes into WASM.
--
-- This function doesn't check if the bytes are actual WASM code hence it's
-- unsafe. Use 'wasmFromBytes' instead if you're not sure the bytes are actual
-- WASM.
unsafeWasmFromBytes :: B.ByteString -> Wasm
unsafeWasmFromBytes = Wasm

-- | This function will validate the provided 'B.ByteString' to determine if it
-- is a valid WebAssembly binary within the context of the 'Engine' provided.
wasmFromBytes :: Engine -> B.ByteString -> Either WasmtimeError Wasm
wasmFromBytes engine inp@(BI.BS inp_fp inp_size) =
  unsafePerformIO $
    withEngine engine $ \engine_ptr ->
      withForeignPtr inp_fp $ \(inp_ptr :: Ptr Word8) ->
        try $ do
          c'wasmtime_module_validate engine_ptr inp_ptr (fromIntegral inp_size)
            >>= checkWasmtimeError
          pure $ Wasm inp

-- | Converts from the text format of WebAssembly to the binary format.
--
-- Throws a 'WasmtimeError' in case conversion fails.
wat2wasm :: B.ByteString -> Either WasmtimeError Wasm
wat2wasm (BI.BS inp_fp inp_size) =
  unsafePerformIO $
    try $
      fmap Wasm $
        withForeignPtr inp_fp $ \(inp_ptr :: Ptr Word8) ->
          withByteVecToByteString $
            c'wasmtime_wat2wasm (castPtr inp_ptr :: Ptr CChar) (fromIntegral inp_size)
              >=> checkWasmtimeError

--------------------------------------------------------------------------------
-- Module
--------------------------------------------------------------------------------

-- | A compiled Wasmtime module.
--
-- This type represents a compiled WebAssembly module. The compiled module is
-- ready to be instantiated and can be inspected for imports/exports.
newtype Module = Module {unModule :: ForeignPtr C'wasmtime_module_t}

newModuleFromPtr :: Ptr C'wasmtime_module_t -> IO Module
newModuleFromPtr = fmap Module . newForeignPtr p'wasmtime_module_delete

-- | Compiles a WebAssembly binary into a 'Module'.
newModule :: Engine -> Wasm -> Either WasmtimeError Module
newModule engine (Wasm (BI.BS inp_fp inp_size)) = unsafePerformIO $
  try $
    withForeignPtr inp_fp $ \(inp_ptr :: Ptr Word8) ->
      withEngine engine $ \engine_ptr ->
        allocaNullPtr $ \module_ptr_ptr -> mask_ $ do
          c'wasmtime_module_new
            engine_ptr
            inp_ptr
            (fromIntegral inp_size)
            module_ptr_ptr
            >>= checkWasmtimeError
          peek module_ptr_ptr >>= newModuleFromPtr

withModule :: Module -> (Ptr C'wasmtime_module_t -> IO a) -> IO a
withModule = withForeignPtr . unModule

-- | This function serializes compiled module artifacts as blob data.
serializeModule :: Module -> Either WasmtimeError B.ByteString
serializeModule m =
  unsafePerformIO $
    try $
      withModule m $ \module_ptr ->
        withByteVecToByteString $
          c'wasmtime_module_serialize module_ptr >=> checkWasmtimeError

-- | Build a module from serialized data.
--
-- This function is not safe to receive arbitrary user input. See the Rust
-- documentation for more information on what inputs are safe to pass in here
-- (e.g. only that of 'serializeModule').
deserializeModule :: Engine -> B.ByteString -> Either WasmtimeError Module
deserializeModule engine (BI.BS inp_fp inp_size) =
  unsafePerformIO $
    try $
      withEngine engine $ \engine_ptr ->
        withForeignPtr inp_fp $ \(inp_ptr :: Ptr Word8) ->
          allocaNullPtr $ \module_ptr_ptr -> mask_ $ do
            c'wasmtime_module_deserialize
              engine_ptr
              inp_ptr
              (fromIntegral inp_size)
              module_ptr_ptr
              >>= checkWasmtimeError
            peek module_ptr_ptr >>= newModuleFromPtr

--------------------------------------------------------------------------------
-- Module Imports
--------------------------------------------------------------------------------

-- | Type of an import.
newtype ImportType = ImportType {unImportType :: ForeignPtr C'wasm_importtype_t}

instance Show ImportType where
  showsPrec p it =
    showParen (p > appPrec) $
      showString "newImportType "
        . showsArg (importTypeModule it)
        . showString " "
        . showsArg (importTypeName it)
        . showString " "
        . showsArg (importTypeType it)
    where
      appPrec = 10

      showsArg :: forall a. Show a => a -> ShowS
      showsArg = showsPrec (appPrec + 1)

withImportType :: ImportType -> (Ptr C'wasm_importtype_t -> IO a) -> IO a
withImportType = withForeignPtr . unImportType

newImportTypeFromPtr :: Ptr C'wasm_importtype_t -> IO ImportType
newImportTypeFromPtr = fmap ImportType . newForeignPtr p'wasm_importtype_delete

-- | Returns a vector of imports that this module expects.
moduleImports :: Module -> Vector ImportType
moduleImports m =
  unsafePerformIO $
    withModule m $ \mod_ptr ->
      alloca $ \(importtype_vec_ptr :: Ptr C'wasm_importtype_vec_t) -> mask_ $ do
        -- Ownership of the wasm_importtype_vec_t is passed to the caller
        -- so we have to copy the contained wasm_importtype_t elements
        -- and finally delete the wasm_importtype_vec_t:
        c'wasmtime_module_imports mod_ptr importtype_vec_ptr
        sz :: CSize <- peek $ p'wasm_importtype_vec_t'size importtype_vec_ptr
        dt :: Ptr (Ptr C'wasm_importtype_t) <-
          peek $ p'wasm_importtype_vec_t'data importtype_vec_ptr
        vec <-
          V.generateM (fromIntegral sz) $
            peekElemOff dt >=> c'wasm_importtype_copy >=> newImportTypeFromPtr
        c'wasm_importtype_vec_delete importtype_vec_ptr
        pure vec

-- | Creates a new import type.
newImportType ::
  -- | Module
  ModuleName ->
  -- | Optional name (in the module linking proposal the import name can be omitted).
  Maybe String ->
  ExternType ->
  ImportType
newImportType modName mbName externType =
  unsafePerformIO $
    withNameFromString modName $ \mod_name_ptr ->
      maybeWithNameFromString mbName $ \name_ptr -> mask_ $ do
        externtype_ptr <- externTypeToPtr externType
        c'wasm_importtype_new mod_name_ptr name_ptr externtype_ptr
          >>= newImportTypeFromPtr

-- | Marshal a Haskell 'String' to a "C'wasm_name_t". Note that the continuation
-- should take ownership of the (contents of) "C'wasm_name_t".
withNameFromString :: String -> (Ptr C'wasm_name_t -> IO a) -> IO a
withNameFromString name f =
  withCStringLen name $ \(inp_name_ptr, name_sz) ->
    alloca $ \(name_ptr :: Ptr C'wasm_name_t) -> do
      c'wasm_byte_vec_new name_ptr (fromIntegral name_sz) $ castPtr inp_name_ptr
      f name_ptr

maybeWithNameFromString :: Maybe String -> (Ptr C'wasm_name_t -> IO a) -> IO a
maybeWithNameFromString Nothing f = f nullPtr
maybeWithNameFromString (Just name) f = withNameFromString name f

-- | Returns the module this import is importing from.
importTypeModule :: ImportType -> String
importTypeModule importType =
  unsafePerformIO $
    withImportType importType $
      c'wasm_importtype_module >=> peekByteVecAsString

-- | Returns the name this import is importing from.
importTypeName :: ImportType -> Maybe String
importTypeName importType =
  unsafePerformIO $
    withImportType importType $ \importtype_ptr -> do
      name_ptr <- c'wasm_importtype_name importtype_ptr
      if name_ptr == nullPtr
        then pure Nothing
        else Just <$> peekByteVecAsString name_ptr

-- | Returns the type of item this import is importing.
importTypeType :: ImportType -> ExternType
importTypeType importType =
  unsafePerformIO $
    withImportType importType $
      c'wasm_importtype_type >=> newExternTypeFromPtr

--------------------------------------------------------------------------------
-- Module Exports
--------------------------------------------------------------------------------

-- | Type of an export.
newtype ExportType = ExportType {unExportType :: ForeignPtr C'wasm_exporttype_t}

instance Show ExportType where
  showsPrec p et =
    showParen (p > appPrec) $
      showString "newExportType "
        . showsArg (exportTypeName et)
        . showString " "
        . showsArg (exportTypeType et)
    where
      appPrec = 10

      showsArg :: forall a. Show a => a -> ShowS
      showsArg = showsPrec (appPrec + 1)

withExportType :: ExportType -> (Ptr C'wasm_exporttype_t -> IO a) -> IO a
withExportType = withForeignPtr . unExportType

newExportTypeFromPtr :: Ptr C'wasm_exporttype_t -> IO ExportType
newExportTypeFromPtr = fmap ExportType . newForeignPtr p'wasm_exporttype_delete

-- | Returns the list of exports that this module provides.
moduleExports :: Module -> Vector ExportType
moduleExports m =
  unsafePerformIO $
    withModule m $ \mod_ptr ->
      alloca $ \(exporttype_vec_ptr :: Ptr C'wasm_exporttype_vec_t) -> mask_ $ do
        -- Ownership of the wasm_exporttype_vec_t is passed to the caller
        -- so we have to copy the contained wasm_exporttype_t elements
        -- and finally delete the wasm_exporttype_vec_t:
        c'wasmtime_module_exports mod_ptr exporttype_vec_ptr
        sz :: CSize <- peek $ p'wasm_exporttype_vec_t'size exporttype_vec_ptr
        dt :: Ptr (Ptr C'wasm_exporttype_t) <-
          peek $ p'wasm_exporttype_vec_t'data exporttype_vec_ptr
        vec <-
          V.generateM (fromIntegral sz) $
            peekElemOff dt >=> c'wasm_exporttype_copy >=> newExportTypeFromPtr
        c'wasm_exporttype_vec_delete exporttype_vec_ptr
        pure vec

-- | Creates a new export type.
newExportType ::
  -- | name
  String ->
  ExternType ->
  ExportType
newExportType name externType =
  unsafePerformIO $
    withNameFromString name $ \name_ptr -> mask_ $ do
      externtype_ptr <- externTypeToPtr externType
      c'wasm_exporttype_new name_ptr externtype_ptr
        >>= newExportTypeFromPtr

-- | Returns the name of this export.
exportTypeName :: ExportType -> String
exportTypeName exportType =
  unsafePerformIO $
    withExportType exportType $
      c'wasm_exporttype_name >=> peekByteVecAsString

-- | Returns the type of this export.
exportTypeType :: ExportType -> ExternType
exportTypeType exportType =
  unsafePerformIO $
    withExportType exportType $
      c'wasm_exporttype_type >=> newExternTypeFromPtr

--------------------------------------------------------------------------------
-- Extern Types
--------------------------------------------------------------------------------

-- | Possible types which can be externally referenced from a WebAssembly module.
--
-- These can be retrieved from 'importTypeType' or 'exportTypeType'.
data ExternType
  = ExternFuncType FuncType
  | ExternGlobalType GlobalType
  | ExternTableType TableType
  | ExternMemoryType MemoryType
  deriving (Show)

externTypeToPtr :: ExternType -> IO (Ptr C'wasm_externtype_t)
externTypeToPtr = \case
  ExternFuncType funcType ->
    withFuncType funcType $ c'wasm_functype_as_externtype >=> c'wasm_externtype_copy
  ExternGlobalType globalType ->
    withGlobalType globalType $ c'wasm_globaltype_as_externtype >=> c'wasm_externtype_copy
  ExternTableType tableType ->
    withTableType tableType $ c'wasm_tabletype_as_externtype >=> c'wasm_externtype_copy
  ExternMemoryType memoryType ->
    withMemoryType memoryType $ c'wasm_memorytype_as_externtype >=> c'wasm_externtype_copy

newExternTypeFromPtr :: Ptr C'wasm_externtype_t -> IO ExternType
newExternTypeFromPtr externtype_ptr = do
  k <- c'wasm_externtype_kind externtype_ptr
  if
      | k == c'WASM_EXTERN_FUNC ->
          ExternFuncType
            <$> asSubType
              c'wasm_externtype_as_functype
              c'wasm_functype_copy
              newFuncTypeFromPtr
      | k == c'WASM_EXTERN_GLOBAL ->
          ExternGlobalType
            <$> asSubType
              c'wasm_externtype_as_globaltype
              c'wasm_globaltype_copy
              newGlobalTypeFromPtr
      | k == c'WASM_EXTERN_TABLE ->
          ExternTableType
            <$> asSubType
              c'wasm_externtype_as_tabletype
              c'wasm_tabletype_copy
              newTableTypeFromPtr
      | k == c'WASM_EXTERN_MEMORY ->
          ExternMemoryType
            <$> asSubType
              c'wasm_externtype_as_memorytype
              c'wasm_memorytype_copy
              newMemoryTypeFromPtr
      | otherwise -> error $ "Unknown wasm_externkind_t " ++ show k ++ "!"
  where
    asSubType ::
      forall sub_ptr sub.
      (Ptr C'wasm_externtype_t -> IO (Ptr sub_ptr)) ->
      (Ptr sub_ptr -> IO (Ptr sub_ptr)) ->
      (Ptr sub_ptr -> IO sub) ->
      IO sub
    asSubType as_sub copy new = mask_ $ as_sub externtype_ptr >>= (copy >=> new)

--------------------------------------------------------------------------------
-- Monads (IO & ST)
--------------------------------------------------------------------------------

-- $monads
--
-- All side-effectful operations below happen in the Monad @m@ for all @m@ which
-- have an instance for @'MonadPrim' s m@. This means they can be executed in
-- both 'IO' and 'ST'.
--
-- The former allows you to import WASM functions that can do I/O like firing
-- the missles. The latter allows you to run side-effectful WASM operations in
-- pure code as long as the side-effects are contained within the 'ST'
-- computation.
--
-- All (mutable) objects ('Store', 'Func', 'Global', 'TypedGlobal',
-- 'Table' and 'Memory') have a phantom type @s@ that ensures that when executed
-- within:
--
-- @
-- 'runST' :: (forall s. 'ST' s a) -> a
-- @
--
-- The (mutable) object can't leak outside the 'ST' computation and thus can't
-- violate referential transparency.
--
-- In 'IO' the @s@ phantom type will be set to 'RealWorld'.

--------------------------------------------------------------------------------
-- Stores
--------------------------------------------------------------------------------

-- | A collection of instances and wasm global items.
--
-- All WebAssembly instances and items will be attached to and refer to a
-- 'Store'. For example @'Instance's@, @'Func'tions@, @'Global's@, and
-- @'Table's@ are all attached to a 'Store'. @'Instance's@ are created by
-- instantiating a 'Module' within a 'Store' ('newInstance').
--
-- A 'Store' is intended to be a short-lived object in a program. No form of GC
-- is implemented at this time within the 'Store' so once an instance is created
-- within a 'Store' it will not be deallocated until the 'Store' itself is
-- garbage collected. This makes 'Store' unsuitable for creating an unbounded
-- number of instances in it because 'Store' will never release this
-- memory. It’s recommended to have a 'Store' correspond roughly to the lifetime
-- of a “main instance” that an embedding is interested in executing.
data Store s = Store
  { storeFunPtrs :: !(IORef [FunPtr ()]),
    storeForeignPtr :: !(ForeignPtr C'wasmtime_store_t),
    storeCtxPtr :: Ptr C'wasmtime_context_t
  }

-- | Creates a new store within the specified engine.
newStore :: MonadPrim s m => Engine -> m (Store s)
newStore engine = unsafeIOToPrim $ withEngine engine $ \engine_ptr -> mask_ $ do
  wasmtime_store_ptr <- c'wasmtime_store_new engine_ptr nullPtr nullFunPtr
  checkAllocation wasmtime_store_ptr
  wasmtime_ctx_ptr <- c'wasmtime_store_context wasmtime_store_ptr
  funPtrsRef <- newIORef []
  storeFP <- Foreign.Concurrent.newForeignPtr wasmtime_store_ptr $ do
    c'wasmtime_store_delete wasmtime_store_ptr
    readIORef funPtrsRef >>= mapM_ freeHaskellFunPtr
  pure
    Store
      { storeFunPtrs = funPtrsRef,
        storeCtxPtr = wasmtime_ctx_ptr,
        storeForeignPtr = storeFP
      }

withStore :: Store s -> (Ptr C'wasmtime_context_t -> IO a) -> IO a
withStore store f = withForeignPtr (storeForeignPtr store) $ \_store_ptr ->
  f $ storeCtxPtr store

-- | Adds fuel to this 'Store' for wasm to consume while executing.
--
-- For this method to work fuel consumption must be enabled via
-- 'setConsumeFuel'. By default a 'Store' starts with 0 fuel for wasm to execute
-- with (meaning it will immediately 'Trap'). This function must be called for
-- the store to have some fuel to allow WebAssembly to execute.
--
-- Most WebAssembly instructions consume 1 unit of fuel. Some instructions, such
-- as @nop@, @drop@, @block@, and @loop@, consume 0 units, as any execution cost
-- associated with them involves other instructions which do consume fuel.
--
-- Note that at this time when fuel is entirely consumed it will cause wasm to
-- trap. More usages of fuel are planned for the future.
--
-- This function will return an error if fuel consumption is not enabled via
-- 'setConsumeFuel'.
addFuel :: MonadPrim s m => Store s -> Word64 -> m (Either WasmtimeError ())
addFuel store amount = unsafeIOToPrim $ withStore store $ \ctx_ptr -> try $ do
  error_ptr <- c'wasmtime_context_add_fuel ctx_ptr amount
  checkWasmtimeError error_ptr

-- | Returns the amount of fuel consumed by this store’s execution so far.
--
-- If fuel consumption is not enabled via 'setConsumeFuel' then this function
-- will return 'Nothing'. Also note that fuel, if enabled, must be originally
-- configured via 'addFuel'.
fuelConsumed :: MonadPrim s m => Store s -> m (Maybe Word64)
fuelConsumed store = unsafeIOToPrim $ withStore store $ \ctx_ptr ->
  alloca $ \amount_ptr -> do
    res <- c'wasmtime_context_fuel_consumed ctx_ptr amount_ptr
    if not res
      then pure Nothing
      else Just <$> peek amount_ptr

-- | Synthetically consumes fuel from this 'Store'.
--
-- For this method to work fuel consumption must be enabled via 'setConsumeFuel'.
--
-- WebAssembly execution will automatically consume fuel but if so desired the
-- embedder can also consume fuel manually to account for relative costs of host
-- functions, for example.
--
-- This function will attempt to consume @fuel@ units of fuel from within this
-- store. If the remaining amount of fuel allows this then @'Just' n@ is
-- returned where @n@ is the amount of remaining fuel. Otherwise an error is
-- returned and no fuel is consumed.
--
-- This function will return an error either if fuel consumption is not enabled
-- via 'setConsumeFuel' or if fuel exceeds the amount of remaining fuel within
-- this store.
consumeFuel ::
  MonadPrim s m =>
  Store s ->
  -- | Amount of @fuel@ to consume.
  Word64 ->
  m (Either WasmtimeError Word64)
consumeFuel store amount = unsafeIOToPrim $ withStore store $ \ctx_ptr ->
  alloca $ \remaining_ptr -> try $ do
    error_ptr <- c'wasmtime_context_consume_fuel ctx_ptr amount remaining_ptr
    checkWasmtimeError error_ptr
    peek remaining_ptr

--------------------------------------------------------------------------------
-- Function Types
--------------------------------------------------------------------------------

-- | A descriptor for a function in a WebAssembly module.
--
-- WebAssembly functions can have 0 or more parameters and results.
newtype FuncType = FuncType {unFuncType :: ForeignPtr C'wasm_functype_t}

-- | Two @'FuncType's@ are considered equal if their 'funcTypeParams' and
-- 'funcTypeResults' are equal.
instance Eq FuncType where
  ft1 == ft2 =
    funcTypeParams ft1 == funcTypeParams ft2
      && funcTypeResults ft1 == funcTypeResults ft2

instance Show FuncType where
  showsPrec p ft =
    showParen (p > arrowPrec) $
      showValTypes (funcTypeParams ft)
        . showString " .->. "
        . showValTypes (funcTypeResults ft)
    where
      arrowPrec = 0

      showValTypes :: V.Vector ValType -> ShowS
      showValTypes kinds =
        showString "Proxy @'["
          . showString (intercalate ", " $ map kindToHaskellTypeStr $ V.toList kinds)
          . showString "]"

withFuncType :: FuncType -> (Ptr C'wasm_functype_t -> IO a) -> IO a
withFuncType = withForeignPtr . unFuncType

newFuncTypeFromPtr :: Ptr C'wasm_functype_t -> IO FuncType
newFuncTypeFromPtr = fmap FuncType . newForeignPtr p'wasm_functype_delete

-- | Creates a new function type with the parameter and result types of the
-- Haskell function @f@.
--
-- For example the following:
--
-- @
-- let funcType = 'newFuncType' $
--       'Proxy' @(Int32 -> Float -> IO (Either 'Trap' (Word128, Double, Int64)))
-- print funcType
-- @
--
-- Prints: @Proxy @'[Int32, Float] '.->.' Proxy @'[Word128, Double, Int64]@
newFuncType ::
  forall f (params :: [Type]) m r (results :: [Type]).
  ( Funcable f,
    Params f ~ params,
    HListable r,
    Types r ~ results,
    Result f ~ m (Either Trap r),
    Vals params,
    Vals results,
    Len params,
    Len results
  ) =>
  -- | Proxy of the Haskell function type @f@.
  Proxy f ->
  FuncType
newFuncType _proxy = Proxy @params .->. Proxy @results

infixr 0 .->.

-- | Creates a new function type with the given parameter and result types.
--
-- See 'newFuncType' for creating a 'FuncType' from a Haskell function.
(.->.) ::
  forall (params :: [Type]) (results :: [Type]).
  (Vals params, Vals results, Len params, Len results) =>
  -- | Parameter kinds
  Proxy params ->
  -- | Result kinds
  Proxy results ->
  FuncType
params .->. results = unsafePerformIO $
  mask_ $
    withValTypeVec params $ \(params_ptr :: Ptr C'wasm_valtype_vec_t) ->
      withValTypeVec results $ \(results_ptr :: Ptr C'wasm_valtype_vec_t) ->
        c'wasm_functype_new params_ptr results_ptr >>= newFuncTypeFromPtr

withValTypeVec ::
  forall types a.
  (Vals types, Len types) =>
  Proxy types ->
  (Ptr C'wasm_valtype_vec_t -> IO a) ->
  IO a
withValTypeVec types f =
  allocaArray n $ \(valtypes_ptr_ptr :: Ptr (Ptr C'wasm_valtype_t)) -> do
    pokeValTypes valtypes_ptr_ptr types
    alloca $ \(valtype_vec_ptr :: Ptr C'wasm_valtype_vec_t) -> do
      c'wasm_valtype_vec_new valtype_vec_ptr (fromIntegral n) valtypes_ptr_ptr
      f valtype_vec_ptr
  where
    n = len $ Proxy @types

-- | Returns the vector of parameters of this function type.
funcTypeParams :: FuncType -> V.Vector ValType
funcTypeParams funcType =
  unsafePerformIO $ withFuncType funcType $ c'wasm_functype_params >=> unmarshalValTypeVec

-- | Returns the vector of results of this function type.
funcTypeResults :: FuncType -> V.Vector ValType
funcTypeResults funcType =
  unsafePerformIO $ withFuncType funcType $ c'wasm_functype_results >=> unmarshalValTypeVec

unmarshalValTypeVec :: Ptr C'wasm_valtype_vec_t -> IO (V.Vector ValType)
unmarshalValTypeVec valtype_vec_ptr = do
  sz :: CSize <- peek $ p'wasm_valtype_vec_t'size valtype_vec_ptr
  dt :: Ptr (Ptr C'wasm_valtype_t) <- peek $ p'wasm_valtype_vec_t'data valtype_vec_ptr
  V.generateM (fromIntegral sz) $ \ix -> do
    cur_valtype_ptr <- peekElemOff dt ix
    fromWasmKind <$> c'wasm_valtype_kind cur_valtype_ptr

-- | Class of Haskell functions / actions that can be imported into and exported
-- from WASM modules.
class Funcable f where
  type Params f :: [Type]
  type Result f :: Type

instance Funcable b => Funcable (a -> b) where
  type Params (a -> b) = a ': Params b
  type Result (a -> b) = Result b

instance (HListable r, Types r ~ results, Vals results) => Funcable (IO (Either Trap r)) where
  type Params (IO (Either Trap r)) = '[]
  type Result (IO (Either Trap r)) = IO (Either Trap r)

instance (HListable r, Types r ~ results, Vals results) => Funcable (ST s (Either Trap r)) where
  type Params (ST s (Either Trap r)) = '[]
  type Result (ST s (Either Trap r)) = ST s (Either Trap r)

-- | Type of values that:
--
-- * WASM @'Func'tions@ can take as parameters or return as results.
-- * can be retrieved from and set to @'Global's@.
data ValType
  = ValTypeI32
  | ValTypeI64
  | ValTypeF32
  | ValTypeF64
  | ValTypeV128
  | ValTypeFuncRef
  | ValTypeExternRef
  deriving (Show, Eq)

fromWasmKind :: C'wasm_valkind_t -> ValType
fromWasmKind k
  | k == c'WASMTIME_I32 = ValTypeI32
  | k == c'WASMTIME_I64 = ValTypeI64
  | k == c'WASMTIME_F32 = ValTypeF32
  | k == c'WASMTIME_F64 = ValTypeF64
  | k == c'WASMTIME_V128 = ValTypeV128
  | k == c'WASMTIME_FUNCREF = ValTypeFuncRef
  | k == c'WASMTIME_EXTERNREF = ValTypeExternRef
  | otherwise = error $ "Unknown wasm_valkind_t " ++ show k ++ "!"

toWasmKind :: ValType -> C'wasm_valkind_t
toWasmKind = \case
  ValTypeI32 -> c'WASMTIME_I32
  ValTypeI64 -> c'WASMTIME_I64
  ValTypeF32 -> c'WASMTIME_F32
  ValTypeF64 -> c'WASMTIME_F64
  ValTypeV128 -> c'WASMTIME_V128
  ValTypeFuncRef -> c'WASMTIME_FUNCREF
  ValTypeExternRef -> c'WASMTIME_EXTERNREF

kindToHaskellTypeStr :: ValType -> String
kindToHaskellTypeStr = \case
  ValTypeI32 -> "Int32"
  ValTypeI64 -> "Int64"
  ValTypeF32 -> "Float"
  ValTypeF64 -> "Double"
  ValTypeV128 -> "Word128"
  ValTypeFuncRef -> "(Func s)"
  ValTypeExternRef -> "(Ptr C'wasmtime_externref_t)" -- FIXME !!!

-- | Class of Haskell types that WASM @'Func'tions@ can take as parameters or
-- return as results or which can be retrieved from and set to @'Global's@.
class Val a where
  kind :: Proxy a -> C'wasm_valkind_t

  pokeVal :: Ptr C'wasmtime_val_t -> a -> IO ()
  default pokeVal :: (Storable a) => Ptr C'wasmtime_val_t -> a -> IO ()
  pokeVal val_ptr x = do
    poke (p'wasmtime_val'kind val_ptr) $ kind $ Proxy @a
    let p :: Ptr C'wasmtime_valunion_t
        p = p'wasmtime_val'of val_ptr
    poke (castPtr p) x

instance Val Int32 where kind _proxy = c'WASMTIME_I32

instance Val Int64 where kind _proxy = c'WASMTIME_I64

instance Val Float where kind _proxy = c'WASMTIME_F32

instance Val Double where kind _proxy = c'WASMTIME_F64

instance Val Word128 where kind _proxy = c'WASMTIME_V128

instance Val C'wasmtime_func_t where kind _proxy = c'WASMTIME_FUNCREF

instance Val (Func s) where
  kind _proxy = kind $ Proxy @C'wasmtime_func_t
  pokeVal val_ptr = pokeVal val_ptr . getWasmtimeFunc

instance Val (Ptr C'wasmtime_externref_t) where kind _proxy = c'WASMTIME_EXTERNREF

-- | Class of types (of kind list of types) that can be passed and returned from
-- WASM functions.
class Vals (v :: [Type]) where
  pokeValTypes :: Ptr (Ptr C'wasm_valtype_t) -> Proxy v -> IO ()
  pokeVals :: Ptr C'wasmtime_val_t -> List v -> IO ()
  peekVals :: Ptr C'wasmtime_val_t -> MaybeT IO (List v)
  pokeRawVals :: Ptr C'wasmtime_val_raw_t -> List v -> IO ()
  peekRawVals :: Ptr C'wasmtime_val_raw_t -> IO (List v)

instance Vals '[] where
  pokeValTypes _valtypes_ptr_ptr _proxy = pure ()
  pokeVals _vals_ptr Nil = pure ()
  peekVals _vals_ptr = pure Nil
  pokeRawVals _raw_vals_ptr Nil = pure ()
  peekRawVals _raw_vals_ptr = pure Nil

instance (Val v, Storable v, Vals vs) => Vals (v ': vs) where
  pokeValTypes valtypes_ptr_ptr _proxy = do
    valtype_ptr <- c'wasm_valtype_new $ kind $ Proxy @v
    poke valtypes_ptr_ptr valtype_ptr
    pokeValTypes (advancePtr valtypes_ptr_ptr 1) (Proxy @vs)

  pokeVals vals_ptr (v :. vs) = do
    pokeVal vals_ptr v
    pokeVals (advancePtr vals_ptr 1) vs

  peekVals vals_ptr = do
    k :: C'wasmtime_valkind_t <- liftIO $ peek $ p'wasmtime_val'kind vals_ptr
    guard $ kind (Proxy @v) == k

    let valunion_ptr :: Ptr C'wasmtime_valunion_t
        valunion_ptr = p'wasmtime_val'of vals_ptr

        val_ptr :: Ptr v
        val_ptr = castPtr valunion_ptr

    (:.)
      <$> liftIO (peek val_ptr)
      <*> peekVals (advancePtr vals_ptr 1)

  pokeRawVals raw_vals_ptr (v :. vs) = do
    poke (castPtr raw_vals_ptr) v
    pokeRawVals (advancePtr raw_vals_ptr 1) vs

  peekRawVals raw_vals_ptr =
    (:.)
      <$> peek (castPtr raw_vals_ptr)
      <*> peekRawVals (advancePtr raw_vals_ptr 1)

uncheckedPeekVal :: forall r. (Val r, Storable r) => Ptr C'wasmtime_val_t -> IO r
uncheckedPeekVal val_ptr = peek (castPtr of_ptr :: Ptr r)
  where
    of_ptr :: Ptr C'wasmtime_valunion_t
    of_ptr = p'wasmtime_val'of val_ptr

peekTableVal :: Ptr C'wasmtime_val_t -> IO TableValue
peekTableVal val_ptr = do
  k <- peek kind_ptr
  if
      | k == c'WASMTIME_FUNCREF ->
          FuncRefValue . MkFunc
            <$> peek (castPtr of_ptr :: Ptr C'wasmtime_func_t)
      | k == c'WASMTIME_EXTERNREF ->
          ExternRefValue
            <$> peek (castPtr of_ptr :: Ptr (Ptr C'wasmtime_externref_t))
      | otherwise -> error $ "unsupported valkind " ++ show k
  where
    kind_ptr = p'wasmtime_val'kind val_ptr
    of_ptr = p'wasmtime_val'of val_ptr

--------------------------------------------------------------------------------
-- Functions
--------------------------------------------------------------------------------

-- | Representation of a function in Wasmtime.
--
-- Functions are represented with a 64-bit identifying integer in Wasmtime. They
-- do not have any destructor associated with them. Functions cannot
-- interoperate between 'Store' instances and if the wrong function is passed to
-- the wrong store then it may trigger an assertion to abort the process.
newtype Func s = MkFunc {getWasmtimeFunc :: C'wasmtime_func_t}
  deriving (Show)

withFunc :: Func s -> (Ptr C'wasmtime_func_t -> IO a) -> IO a
withFunc = with . getWasmtimeFunc

-- | Returns the type of the given function.
getFuncType :: MonadPrim s m => Store s -> Func s -> m FuncType
getFuncType store func =
  unsafeIOToPrim $
    withStore store $ \ctx_ptr ->
      withFunc func $ \func_ptr ->
        mask_ $
          c'wasmtime_func_type ctx_ptr func_ptr >>= newFuncTypeFromPtr

type FuncCallback =
  Ptr () -> -- env
  Ptr C'wasmtime_caller_t -> -- caller
  Ptr C'wasmtime_val_t -> -- args
  CSize -> -- nargs
  Ptr C'wasmtime_val_t -> -- results
  CSize -> -- nresults
  IO (Ptr C'wasm_trap_t)

newFuncCallbackFunPtr :: IORef [FunPtr ()] -> FuncCallback -> IO (FunPtr FuncCallback)
newFuncCallbackFunPtr ioRef callback = mask_ $ do
  funPtr <- mk'wasmtime_func_callback_t callback
  atomicModifyIORef ioRef $ \(existingFunPtrs :: [FunPtr ()]) ->
    (castFunPtr funPtr : existingFunPtrs, ())
  pure funPtr

-- | Insert a new function into the 'Store'.
newFunc ::
  forall f (params :: [Type]) m s r (results :: [Type]).
  ( Funcable f,
    Params f ~ params,
    HListable r,
    Types r ~ results,
    Result f ~ m (Either Trap r),
    Foldr (->) (m (Either Trap r)) params ~ f,
    Curry params,
    Vals params,
    Vals results,
    Len params,
    Len results,
    MonadPrim s m,
    PrimBase m
  ) =>
  Store s ->
  -- | 'Funcable' Haskell function.
  f ->
  m (Func s)
newFunc store f =
  unsafeIOToPrim $
    withStore store $ \ctx_ptr ->
      withFuncType funcType $ \functype_ptr -> do
        callback_funptr :: FunPtr FuncCallback <-
          newFuncCallbackFunPtr (storeFunPtrs store) callback
        alloca $ \(func_ptr :: Ptr C'wasmtime_func_t) -> do
          c'wasmtime_func_new
            ctx_ptr
            functype_ptr
            callback_funptr
            nullPtr
            nullFunPtr
            func_ptr
          MkFunc <$> peek func_ptr
  where
    funcType :: FuncType
    funcType = newFuncType $ Proxy @f

    callback :: FuncCallback
    callback = mkCallback f

mkCallback ::
  forall f (params :: [Type]) m s r (results :: [Type]).
  ( Funcable f,
    Params f ~ params,
    HListable r,
    Types r ~ results,
    Result f ~ m (Either Trap r),
    Foldr (->) (m (Either Trap r)) params ~ f,
    Curry params,
    Vals params,
    Vals results,
    Len params,
    Len results,
    MonadPrim s m,
    PrimBase m
  ) =>
  f ->
  FuncCallback
mkCallback f _env _caller params_ptr nargs result_ptr nresults = do
  let actualNrOfArgs = fromIntegral nargs
  if actualNrOfArgs /= expectedNrOfArgs
    then
      error $
        "Expected "
          ++ show expectedNrOfArgs
          ++ " number of arguments but got "
          ++ show actualNrOfArgs
          ++ "!"
    else do
      mbParams <- runMaybeT $ peekVals params_ptr
      case mbParams of
        Nothing -> error "ValType mismatch!"
        Just (params :: List params) -> do
          e <- unsafePrimToIO $ (uncurryList f :: List params -> m (Either Trap r)) params
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
                then pokeVals result_ptr (toHList r) $> nullPtr
                else do
                  -- TODO: use throwIO or trap!
                  error $
                    "Expected the number of results to be "
                      ++ show expectedNrOfResults
                      ++ " but got "
                      ++ show n
                      ++ "!"
  where
    expectedNrOfArgs = len $ Proxy @params
    expectedNrOfResults = len $ Proxy @results

-- | Converts a 'Func' into the Haskell function @f@.
--
-- 'Nothing' will be returned if the type of the 'Func' ('getFuncType') doesn't
-- match the type of @f@ (@'newFuncType' $ Proxy \@f@).
--
-- Example:
--
-- @
-- mbGCD <- 'funcToFunction' store someExportedGcdFunc
-- case mbGCD of
--   Nothing -> error "gcd did not have the expected type!"
--   Just (wasmGCD :: Int32 -> Int32 -> IO (Either Trap Int32)) -> do
--     -- Call gcd on its two Int32 arguments:
--     r <- wasmGCD 6 27
--     print r -- prints "Right 3"
-- @
funcToFunction ::
  forall f (params :: [Type]) m s r (results :: [Type]).
  ( Funcable f,
    Params f ~ params,
    HListable r,
    Types r ~ results,
    Result f ~ m (Either Trap r),
    Foldr (->) (m (Either Trap r)) params ~ f,
    Curry params,
    Vals params,
    Vals results,
    Len params,
    Len results,
    MonadPrim s m,
    PrimBase m
  ) =>
  Store s ->
  -- | WASM function.
  Func s ->
  m (Maybe f)
funcToFunction store func = do
  actualFuncType <- getFuncType store func
  pure $
    if actualFuncType == expectedFuncType
      then Just $ callFunc store func
      else Nothing
  where
    expectedFuncType = newFuncType $ Proxy @f

callFunc ::
  forall f (params :: [Type]) m s r (results :: [Type]).
  ( Funcable f,
    Params f ~ params,
    HListable r,
    Types r ~ results,
    Result f ~ m (Either Trap r),
    Foldr (->) (m (Either Trap r)) params ~ f,
    Curry params,
    Vals params,
    Vals results,
    Len params,
    Len results,
    MonadPrim s m,
    PrimBase m
  ) =>
  Store s ->
  -- | See 'funcToFunction'.
  Func s ->
  f
callFunc store func = curryList callFuncOnParams
  where
    callFuncOnParams :: List params -> m (Either Trap r)
    callFuncOnParams params =
      unsafeIOToPrim $
        withStore store $ \ctx_ptr ->
          withFunc func $ \func_ptr ->
            allocaArray n $ \(args_and_results_ptr :: Ptr C'wasmtime_val_raw_t) -> do
              pokeRawVals args_and_results_ptr params
              allocaNullPtr $ \(trap_ptr_ptr :: Ptr (Ptr C'wasm_trap_t)) -> mask_ $ do
                error_ptr <-
                  c'wasmtime_func_call_unchecked
                    ctx_ptr
                    func_ptr
                    args_and_results_ptr
                    (fromIntegral n)
                    trap_ptr_ptr
                checkWasmtimeError error_ptr
                trap_ptr <- peek trap_ptr_ptr
                if trap_ptr == nullPtr
                  then do
                    results :: List results <- peekRawVals args_and_results_ptr
                    let r = fromHList results :: r
                    pure $ Right r
                  else Left <$> newTrapFromPtr trap_ptr

    n :: Int
    n = max (len $ Proxy @params) (len $ Proxy @results)

--------------------------------------------------------------------------------
-- Globals
--------------------------------------------------------------------------------

-- | The type of a global.
newtype GlobalType = GlobalType {unGlobalType :: ForeignPtr C'wasm_globaltype_t}

instance Eq GlobalType where
  gt1 == gt2 =
    globalTypeValType gt1 == globalTypeValType gt2
      && globalTypeMutability gt1 == globalTypeMutability gt2

instance Show GlobalType where
  showsPrec p gt =
    showParen (p > appPrec) $
      showString "newGlobalType "
        . showString ("(Proxy @" ++ ty ++ ") ")
        . shows mut
    where
      appPrec = 10

      ty = kindToHaskellTypeStr $ globalTypeValType gt
      mut = globalTypeMutability gt

withGlobalType :: GlobalType -> (Ptr C'wasm_globaltype_t -> IO a) -> IO a
withGlobalType = withForeignPtr . unGlobalType

-- | Returns a new 'GlobalType' with the kind of the given Haskell type and the
-- specified 'Mutability'.
newGlobalType :: Val a => Proxy a -> Mutability -> GlobalType
newGlobalType proxy mutability = unsafePerformIO $ do
  globaltype_ptr <- newGlobalTypePtr proxy mutability
  newGlobalTypeFromPtr globaltype_ptr

newGlobalTypeFromPtr :: Ptr C'wasm_globaltype_t -> IO GlobalType
newGlobalTypeFromPtr globaltype_ptr =
  GlobalType <$> newForeignPtr p'wasm_globaltype_delete globaltype_ptr

newGlobalTypePtr :: forall a. Val a => Proxy a -> Mutability -> IO (Ptr C'wasm_globaltype_t)
newGlobalTypePtr _proxy mutability = do
  valtype_ptr <- c'wasm_valtype_new $ kind $ Proxy @a
  c'wasm_globaltype_new valtype_ptr $ toWasmMutability mutability

-- TODO: think about whether we should reflect Mutability on the type-level
-- such that we can only use `globalSet` on mutable globals.

-- | Specifies wether a global can be mutated or not.
data Mutability
  = -- | The global can not be mutated.
    Immutable
  | -- | The global can be mutated via 'globalSet'.
    Mutable
  deriving (Show, Eq)

toWasmMutability :: Mutability -> C'wasm_mutability_t
toWasmMutability Immutable = 0
toWasmMutability Mutable = 1

fromWasmMutability :: C'wasm_mutability_t -> Mutability
fromWasmMutability 0 = Immutable
fromWasmMutability 1 = Mutable
fromWasmMutability m = error $ "Unknown wasm_mutability_t " ++ show m ++ "!"

-- | Returns the 'ValType' of the given 'GlobalType'.
globalTypeValType :: GlobalType -> ValType
globalTypeValType globalType = unsafePerformIO $
  withGlobalType globalType $ \globalType_ptr -> do
    valtype_ptr <- c'wasm_globaltype_content globalType_ptr
    fromWasmKind <$> c'wasm_valtype_kind valtype_ptr

-- | Returns the 'Mutability' of the given 'GlobalType'.
globalTypeMutability :: GlobalType -> Mutability
globalTypeMutability globalType =
  unsafePerformIO $
    withGlobalType globalType $
      fmap fromWasmMutability . c'wasm_globaltype_mutability

-- | A WebAssembly global value which can be read and written to.
--
-- A global in WebAssembly is sort of like a global variable within an
-- 'Instance'. The 'globalGet' and 'globalSet' instructions will modify and read
-- global values in a wasm module. Globals can either be imported or exported
-- from wasm modules.
--
-- A Global “belongs” to the store that it was originally created within (either
-- via 'newGlobal' or via instantiating a 'Module'). Operations on a Global only
-- work with the store it belongs to, and if another store is passed in by
-- accident then methods will panic.
newtype Global s = MkGlobal {getWasmtimeGlobal :: C'wasmtime_global_t}
  deriving (Show)

withGlobal :: Global s -> (Ptr C'wasmtime_global_t -> IO a) -> IO a
withGlobal = with . getWasmtimeGlobal

-- | Returns the wasm type of the specified global.
getGlobalType :: (MonadPrim s m) => Store s -> Global s -> m GlobalType
getGlobalType store global =
  unsafeIOToPrim $
    withStore store $ \ctx_ptr ->
      withGlobal global $ \global_ptr -> mask_ $ do
        globaltype_ptr <- c'wasmtime_global_type ctx_ptr global_ptr
        newGlobalTypeFromPtr globaltype_ptr

-- | Retrieves the type of the given 'Global' from the 'Store' and checks if it
-- matches the desired type @a@ of the returned 'TypedGlobal'.
toTypedGlobal ::
  forall s m a.
  (MonadPrim s m, Val a) =>
  Store s ->
  Global s ->
  m (Maybe (TypedGlobal s a))
toTypedGlobal store global = do
  globalType <- getGlobalType store global
  let actualKind = toWasmKind $ globalTypeValType globalType
      expectedKind = kind $ Proxy @a
  if actualKind == expectedKind
    then pure $ Just $ TypedGlobal global
    else pure Nothing

-- | A 'Global' with a phantom type of the value in the global.
newtype TypedGlobal s a = TypedGlobal
  { -- | Get the 'Global' out of a 'TypedGlobal'.
    unTypedGlobal :: Global s
  }

withTypedGlobal :: TypedGlobal s a -> (Ptr C'wasmtime_global_t -> IO b) -> IO b
withTypedGlobal = with . getWasmtimeGlobal . unTypedGlobal

-- | Creates a new WebAssembly global value with the 'GlobalType' corresponding
-- to the type of the given Haskell value and the specified 'Mutability'. The
-- global will be initialised with the given Haskell value.
--
-- The 'Store' argument will be the owner of the 'Global' returned. Using the
-- returned Global other items in the store may access this global. For example
-- this could be provided as an argument to 'newInstance'.
--
-- Returns an error if the value comes from a different store than the specified
-- store ('Store').
newTypedGlobal ::
  forall s m a.
  (MonadPrim s m, Val a, Storable a) =>
  Store s ->
  -- | Specifies whether the global can be mutated or not.
  Mutability ->
  -- | Initialise the global with this Haskell value.
  a ->
  m (Either WasmtimeError (TypedGlobal s a))
newTypedGlobal store mutability x =
  unsafeIOToPrim $
    try $
      withStore store $ \ctx_ptr ->
        withNewGlobalTypePtr $ \(globaltype_ptr :: Ptr C'wasm_globaltype_t) ->
          alloca $ \(val_ptr :: Ptr C'wasmtime_val_t) -> do
            pokeVal val_ptr x
            alloca $ \(global_ptr :: Ptr C'wasmtime_global_t) -> do
              error_ptr <- c'wasmtime_global_new ctx_ptr globaltype_ptr val_ptr global_ptr
              checkWasmtimeError error_ptr
              TypedGlobal . MkGlobal <$> peek global_ptr
  where
    withNewGlobalTypePtr =
      bracket (newGlobalTypePtr (Proxy @a) mutability) c'wasm_globaltype_delete

-- | Returns the current value of the given typed global.
typedGlobalGet ::
  (MonadPrim s m, Val a, Storable a) =>
  Store s ->
  TypedGlobal s a ->
  m a
typedGlobalGet store typedGlobal =
  unsafeIOToPrim $
    withStore store $ \ctx_ptr ->
      withTypedGlobal typedGlobal $ \global_ptr ->
        alloca $ \(val_ptr :: Ptr C'wasmtime_val_t) -> do
          c'wasmtime_global_get ctx_ptr global_ptr val_ptr
          uncheckedPeekVal val_ptr

-- | Attempts to set the current value of this typed global.
--
-- Returns an error if it’s not a mutable global, or if value comes from a
-- different store than the one provided.
typedGlobalSet ::
  (MonadPrim s m, Val a, Storable a) =>
  Store s ->
  TypedGlobal s a ->
  a ->
  m (Either WasmtimeError ())
typedGlobalSet store typedGlobal x =
  unsafeIOToPrim $
    try $
      withStore store $ \ctx_ptr ->
        withTypedGlobal typedGlobal $ \global_ptr ->
          alloca $ \(val_ptr :: Ptr C'wasmtime_val_t) -> do
            pokeVal val_ptr x
            error_ptr <- c'wasmtime_global_set ctx_ptr global_ptr val_ptr
            checkWasmtimeError error_ptr

--------------------------------------------------------------------------------
-- Tables
--------------------------------------------------------------------------------

-- | A descriptor for a table in a WebAssembly module.
--
-- Tables are contiguous chunks of a specific element, typically a funcref or an
-- externref.  The most common use for tables is a function table through which
-- call_indirect can invoke other functions.
newtype TableType = TableType {getWasmtimeTableType :: ForeignPtr C'wasm_tabletype_t}

instance Eq TableType where
  tt1 == tt2 =
    tableTypeElement tt1 == tableTypeElement tt2
      && tableTypeLimits tt1 == tableTypeLimits tt2

instance Show TableType where
  showsPrec p tt =
    showParen (p > appPrec) $
      showString "newTableType "
        . showsArg tableRefType
        . showString " "
        . showsArg tableLimits
    where
      appPrec = 10

      showsArg :: forall a. Show a => a -> ShowS
      showsArg = showsPrec (appPrec + 1)

      tableRefType = tableTypeElement tt
      tableLimits = tableTypeLimits tt

withTableType :: TableType -> (Ptr C'wasm_tabletype_t -> IO a) -> IO a
withTableType = withForeignPtr . getWasmtimeTableType

newTableTypeFromPtr :: Ptr C'wasm_tabletype_t -> IO TableType
newTableTypeFromPtr = fmap TableType . newForeignPtr p'wasm_tabletype_delete

-- | The type of a table.
data TableRefType = FuncRef | ExternRef
  deriving (Show, Eq)

-- TODO: make table limit maximum optional

-- | Specifies a minimum and maximum size for a 'Table'
data TableLimits = TableLimits {tableMin :: Int32, tableMax :: Int32}
  deriving (Show, Eq)

-- | Creates a new 'Table' descriptor which will contain the specified element
-- type and have the limits applied to its length.
newTableType ::
  TableRefType ->
  TableLimits ->
  TableType
newTableType tableRefType limits = unsafePerformIO $
  alloca $ \(limits_ptr :: Ptr C'wasm_limits_t) -> mask_ $ do
    let (valkind :: C'wasm_valkind_t) = case tableRefType of
          FuncRef -> c'WASMTIME_FUNCREF
          ExternRef -> c'WASMTIME_EXTERNREF
        limits' =
          C'wasm_limits_t
            { c'wasm_limits_t'min = fromIntegral $ tableMin limits,
              c'wasm_limits_t'max = fromIntegral $ tableMax limits
            }
    valtype_ptr <- c'wasm_valtype_new valkind
    poke limits_ptr limits'
    c'wasm_tabletype_new valtype_ptr limits_ptr >>= newTableTypeFromPtr

-- | Returns the element type of this table
tableTypeElement :: TableType -> TableRefType
tableTypeElement tt = unsafePerformIO $
  withTableType tt $ \tt_ptr -> do
    valtype_ptr <- c'wasm_tabletype_element tt_ptr
    valkind <- c'wasm_valtype_kind valtype_ptr
    if
        | valkind == c'WASMTIME_FUNCREF -> pure FuncRef
        | valkind == c'WASMTIME_EXTERNREF -> pure ExternRef
        | otherwise ->
            error $
              "Got invalid valkind "
                ++ show valkind
                ++ " from c'wasm_valtype_kind."

-- | Returns the minimum and maximum size of this tabletype
tableTypeLimits :: TableType -> TableLimits
tableTypeLimits tt = unsafePerformIO $
  withTableType tt $ \tt_ptr -> do
    limits_ptr <- c'wasm_tabletype_limits tt_ptr
    limits' <- peek limits_ptr
    pure
      TableLimits
        { tableMin = fromIntegral (c'wasm_limits_t'min limits'),
          tableMax = fromIntegral (c'wasm_limits_t'max limits')
        }

-- TODO: typed tables

-- | A WebAssembly table, or an array of values.
--
-- For more information, see <https://docs.rs/wasmtime/latest/wasmtime/struct.Table.html>.
newtype Table s = MkTable {getWasmtimeTable :: C'wasmtime_table_t}
  deriving (Show)

withTable :: Table s -> (Ptr C'wasmtime_table_t -> IO a) -> IO a
withTable = with . getWasmtimeTable

-- | Tables can contain function references or extern references
data TableValue = forall s. FuncRefValue (Func s) | ExternRefValue (Ptr C'wasmtime_externref_t)

withTableValue :: TableValue -> (Ptr C'wasmtime_val_t -> IO a) -> IO a
withTableValue (FuncRefValue func) f =
  alloca $ \val_ptr -> do
    pokeVal val_ptr (getWasmtimeFunc func :: C'wasmtime_func_t)
    f val_ptr
withTableValue (ExternRefValue _) _f = error "not implemented: ExternRefValue Tables"

-- | Create a new table
newTable ::
  MonadPrim s m =>
  Store s ->
  TableType ->
  -- | An optional initial value which will be used to fill in the table,
  -- if its initial size is > 0.
  Maybe TableValue ->
  m (Either WasmtimeError (Table s))
newTable store tt mbVal = unsafeIOToPrim $
  try $
    withStore store $ \ctx_ptr ->
      withTableType tt $ \tt_ptr ->
        alloca $ \table_ptr -> do
          error_ptr <- case mbVal of
            Nothing -> do
              c'wasmtime_table_new ctx_ptr tt_ptr nullPtr table_ptr
            Just (FuncRefValue (MkFunc func_t)) -> do
              alloca $ \val_ptr -> do
                pokeVal val_ptr func_t
                c'wasmtime_table_new ctx_ptr tt_ptr val_ptr table_ptr
            Just (ExternRefValue _todo) -> do
              error "not implemented: ExternRefValue Tables"
          checkWasmtimeError error_ptr
          MkTable <$> peek table_ptr

-- | Grow the table by delta elements.
growTable ::
  MonadPrim s m =>
  Store s ->
  Table s ->
  -- | Delta
  Word32 ->
  -- | Optional element to fill in the new space.
  Maybe TableValue ->
  m (Either WasmtimeError Word32)
growTable store table delta mbVal = unsafeIOToPrim $
  try $
    withStore store $ \ctx_ptr ->
      withTable table $ \table_ptr ->
        alloca $ \prev_size_ptr -> do
          error_ptr <- case mbVal of
            Nothing ->
              c'wasmtime_table_grow ctx_ptr table_ptr (fromIntegral delta) nullPtr prev_size_ptr
            Just val ->
              withTableValue val $ \val_ptr ->
                c'wasmtime_table_grow ctx_ptr table_ptr (fromIntegral delta) val_ptr prev_size_ptr
          checkWasmtimeError error_ptr
          peek prev_size_ptr

-- | Get value at index from table. If index > length table, Nothing is returned.
tableGet ::
  MonadPrim s m =>
  Store s ->
  Table s ->
  -- | Index into table
  Word32 ->
  m (Maybe TableValue)
tableGet store table ix = unsafeIOToPrim $
  withStore store $ \ctx_ptr ->
    withTable table $ \table_ptr ->
      alloca $ \val_ptr -> do
        success <- c'wasmtime_table_get ctx_ptr table_ptr ix val_ptr
        if not success
          then pure Nothing
          else Just <$> peekTableVal val_ptr

-- | Set an element at the given index.
--
-- This function will return an error if the index is too large.
tableSet ::
  MonadPrim s m =>
  Store s ->
  Table s ->
  -- | Index
  Word32 ->
  -- | The new value
  TableValue ->
  m (Either WasmtimeError ())
tableSet store table ix val = unsafeIOToPrim $
  try $
    withStore store $ \ctx_ptr ->
      withTable table $ \table_ptr ->
        withTableValue val $ \val_ptr -> do
          error_ptr <- c'wasmtime_table_set ctx_ptr table_ptr ix val_ptr
          checkWasmtimeError error_ptr

-- | Return the 'TableType' with which this table was created.
getTableType :: Store s -> Table s -> TableType
getTableType store table = unsafePerformIO $
  withStore store $ \ctx_ptr ->
    withTable table $ \table_ptr ->
      mask_ $
        c'wasmtime_table_type ctx_ptr table_ptr >>= newTableTypeFromPtr

--------------------------------------------------------------------------------
-- Memory
--------------------------------------------------------------------------------

-- | A descriptor for a WebAssembly memory type.
--
-- Memories are described in units of pages (64KB) and represent contiguous
-- chunks of addressable memory.
newtype MemoryType = MemoryType {unMemoryType :: ForeignPtr C'wasm_memorytype_t}

instance Eq MemoryType where
  mt1 == mt2 =
    getMin mt1 == getMin mt2
      && getMax mt1 == getMax mt2
      && wordLength mt1 == wordLength mt2

instance Show MemoryType where
  showsPrec p mt =
    showParen (p > appPrec) $
      showString "newMemoryType "
        . showsArg mini
        . showString " "
        . showsArg mbMax
        . showString " "
        . showsArg wordLen
    where
      appPrec = 10

      showsArg :: forall a. Show a => a -> ShowS
      showsArg = showsPrec (appPrec + 1)

      mini = getMin mt
      mbMax = getMax mt
      wordLen = wordLength mt

newMemoryTypeFromPtr :: Ptr C'wasm_memorytype_t -> IO MemoryType
newMemoryTypeFromPtr = fmap MemoryType . newForeignPtr p'wasm_memorytype_delete

-- | Creates a descriptor for a WebAssembly 'Memory' with the specified minimum
-- number of memory pages, an optional maximum of memory pages, and a specifier
-- for the 'WordLength' (32 bit / 64 bit memory).
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
  newMemoryTypeFromPtr mem_type_ptr
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
newtype Memory s = MkMemory {getWasmtimeMemory :: C'wasmtime_memory_t}
  deriving (Show)

-- | Create new memory with the properties described in the 'MemoryType' argument.
newMemory :: MonadPrim s m => Store s -> MemoryType -> m (Either WasmtimeError (Memory s))
newMemory store memtype = unsafeIOToPrim $
  try $
    withStore store $ \ctx_ptr ->
      withMemoryType memtype $ \memtype_ptr ->
        alloca $ \mem_ptr -> do
          error_ptr <- c'wasmtime_memory_new ctx_ptr memtype_ptr mem_ptr
          checkWasmtimeError error_ptr
          MkMemory <$> peek mem_ptr

withMemory :: Memory s -> (Ptr C'wasmtime_memory_t -> IO a) -> IO a
withMemory = with . getWasmtimeMemory

-- | Returns the 'MemoryType' descriptor for this memory.
getMemoryType :: Store s -> Memory s -> MemoryType
getMemoryType store mem = unsafePerformIO $
  withStore store $ \ctx_ptr ->
    withMemory mem $ \mem_ptr -> mask_ $ do
      memtype_ptr <- c'wasmtime_memory_type ctx_ptr mem_ptr
      MemoryType <$> newForeignPtr p'wasm_memorytype_delete memtype_ptr

-- | Returns the linear memory size in bytes. Always a multiple of 64KB (65536).
getMemorySizeBytes :: MonadPrim s m => Store s -> Memory s -> m Word64
getMemorySizeBytes store mem = unsafeIOToPrim $
  withStore store $ \ctx_ptr ->
    withMemory mem (fmap fromIntegral . c'wasmtime_memory_data_size ctx_ptr)

-- | Returns the length of the linear memory in WebAssembly pages
getMemorySizePages :: MonadPrim s m => Store s -> Memory s -> m Word64
getMemorySizePages store mem = unsafeIOToPrim $
  withStore store $ \ctx_ptr ->
    withMemory mem $ \mem_ptr ->
      c'wasmtime_memory_size ctx_ptr mem_ptr

-- | Grow the linar memory by delta number of pages. Return the size before.
growMemory ::
  MonadPrim s m =>
  Store s ->
  Memory s ->
  -- | Delta
  Word64 ->
  m (Either WasmtimeError Word64)
growMemory store mem delta = unsafeIOToPrim $
  try $
    withStore store $ \ctx_ptr ->
      withMemory mem $ \mem_ptr ->
        alloca $ \before_size_ptr -> do
          error_ptr <- c'wasmtime_memory_grow ctx_ptr mem_ptr delta before_size_ptr
          checkWasmtimeError error_ptr
          peek before_size_ptr

-- | Takes a continuation which can mutate the linear memory. The continuation
-- is provided with a pointer to the beginning of the memory and its maximum
-- length. Do not write outside the bounds!
--
-- This function is unsafe, because we do not restrict the continuation in any
-- way.  DO NOT call exported wasm functions, grow the memory or do anything
-- similar in the continuation!
unsafeWithMemory :: Store s -> Memory s -> (Ptr Word8 -> Size -> IO a) -> IO a
unsafeWithMemory store mem f =
  withStore store $ \ctx_ptr ->
    withMemory mem $ \mem_ptr -> do
      mem_size <- fromIntegral <$> c'wasmtime_memory_data_size ctx_ptr mem_ptr
      mem_data_ptr <- c'wasmtime_memory_data ctx_ptr mem_ptr
      f mem_data_ptr mem_size

-- | Returns a copy of the whole linear memory as a bytestring.
readMemory :: MonadPrim s m => Store s -> Memory s -> m B.ByteString
readMemory store mem = unsafeIOToPrim $
  unsafeWithMemory store mem $ \mem_data_ptr mem_size ->
    BI.create (fromIntegral mem_size) $ \dst_ptr ->
      BI.memcpy dst_ptr mem_data_ptr (fromIntegral mem_size)

-- | Takes an offset and a length, and returns a copy of the memory starting at
-- offset until offset + length.
--
-- Returns @Left MemoryAccessError@ if offset + length exceeds the length of the
-- memory.
readMemoryAt ::
  MonadPrim s m =>
  Store s ->
  Memory s ->
  -- | Offset
  Offset ->
  -- | Number of bytes to read
  Size ->
  m (Either MemoryAccessError B.ByteString)
readMemoryAt store mem offset sz = do
  max_sz <- getMemorySizeBytes store mem
  unsafeIOToPrim $ do
    if offset + sz > max_sz
      then pure $ Left MemoryAccessError
      else do
        res <- unsafeWithMemory store mem $ \mem_data_ptr mem_size ->
          BI.create (fromIntegral mem_size) $ \dst_ptr ->
            BI.memcpy
              dst_ptr
              (advancePtr mem_data_ptr (fromIntegral offset))
              (fromIntegral mem_size)
        pure $ Right res

-- | Safely writes a 'ByteString' to this memory at the given offset.
--
-- If the @offset@ + the length of the @ByteString@ exceeds the
-- current memory capacity, then none of the @ByteString@ is written
-- to memory and @'Left' 'MemoryAccessError'@ is returned.
writeMemory ::
  MonadPrim s m =>
  Store s ->
  Memory s ->
  -- | Offset
  Int ->
  B.ByteString ->
  m (Either MemoryAccessError ())
writeMemory store mem offset (BI.BS fp n) =
  unsafeIOToPrim $ unsafeWithMemory store mem $ \dst sz ->
    if offset + n > fromIntegral sz
      then pure $ Left MemoryAccessError
      else withForeignPtr fp $ \src ->
        Right <$> BI.memcpy (advancePtr dst offset) src n

-- | Error for out of bounds 'Memory' access.
data MemoryAccessError = MemoryAccessError deriving (Show)

instance Exception MemoryAccessError

--------------------------------------------------------------------------------
-- Externs
--------------------------------------------------------------------------------

-- | Container for different kinds of extern items (like @'Func's@) that can be
-- imported into new @'Instance's@ using 'newInstance' and exported from
-- existing instances using 'getExport'.
data Extern (s :: Type)
  = Func (Func s)
  | Global (Global s)
  | Table (Table s)
  | Memory (Memory s)
  deriving (Show)

-- | Class of types that can be imported and exported from @'Instance's@.
class (Storable (CType e)) => Externable (e :: Type -> Type) where
  type CType e :: Type

  -- | Turn any externable value (like a 'Func') into the 'Extern' container.
  toExtern :: e s -> Extern s

  -- | Converts an 'Extern' object back into an ordinary Haskell value (like a 'Func')
  -- of the correct type.
  fromExtern :: Extern s -> Maybe (e s)

  toCExtern :: e s -> CType e
  externKind :: Proxy e -> C'wasmtime_extern_kind_t

instance Externable Func where
  type CType Func = C'wasmtime_func

  toExtern = Func

  fromExtern (Func func) = Just func
  fromExtern _ = Nothing

  toCExtern = getWasmtimeFunc
  externKind _proxy = c'WASMTIME_EXTERN_FUNC

instance Externable Memory where
  type CType Memory = C'wasmtime_memory_t

  toExtern = Memory

  fromExtern (Memory mem) = Just mem
  fromExtern _ = Nothing

  toCExtern = getWasmtimeMemory
  externKind _proxy = c'WASMTIME_EXTERN_MEMORY

instance Externable Table where
  type CType Table = C'wasmtime_table_t

  toExtern = Table

  fromExtern (Table table) = Just table
  fromExtern _ = Nothing

  toCExtern = getWasmtimeTable
  externKind _proxy = c'WASMTIME_EXTERN_TABLE

instance Externable Global where
  type CType Global = C'wasmtime_global_t

  toExtern = Global

  fromExtern (Global global) = Just global
  fromExtern _ = Nothing

  toCExtern = getWasmtimeGlobal
  externKind _proxy = c'WASMTIME_EXTERN_GLOBAL

withExtern :: Extern s -> (Ptr C'wasmtime_extern_t -> IO a) -> IO a
withExtern extern f = alloca $ \(extern_ptr :: Ptr C'wasmtime_extern_t) -> do
  pokeExtern extern_ptr extern
  f extern_ptr

withExterns :: Vector (Extern s) -> (Ptr C'wasmtime_extern_t -> CSize -> IO a) -> IO a
withExterns externs f = allocaArray n $ \externs_ptr0 ->
  let pokeExternsFrom ix
        | ix == n = f externs_ptr0 $ fromIntegral n
        | otherwise = do
            pokeExtern (advancePtr externs_ptr0 ix) $ V.unsafeIndex externs ix
            pokeExternsFrom (ix + 1)
   in pokeExternsFrom 0
  where
    n = V.length externs

pokeExtern :: Ptr C'wasmtime_extern -> Extern s -> IO ()
pokeExtern externs_ptr extern =
  case extern of
    Func func -> pokeExternable func
    Global global -> pokeExternable global
    Table table -> pokeExternable table
    Memory memory -> pokeExternable memory
  where
    pokeExternable :: forall e s. Externable e => e s -> IO ()
    pokeExternable e = do
      poke (p'wasmtime_extern'kind externs_ptr) $ externKind (Proxy @e)
      poke (castPtr $ p'wasmtime_extern'of externs_ptr) $ toCExtern e

--------------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------------

-- | Representation of a instance in Wasmtime.
newtype Instance s = Instance {instanceForeignPtr :: ForeignPtr C'wasmtime_instance_t}

-- | Instantiate a wasm module.
--
-- This function will instantiate a WebAssembly module with the provided
-- imports, creating a WebAssembly instance. The returned instance can then
-- afterwards be inspected for exports.
newInstance ::
  MonadPrim s m =>
  Store s ->
  Module ->
  -- | This function requires that this `imports` vector has the same size as
  -- the imports of the given 'Module'. Additionally the `imports` must be 1:1
  -- lined up with the imports of the specified module. This is intended to be
  -- relatively low level, and 'newInstanceLinked' is provided for a more
  -- ergonomic name-based resolution API.
  Vector (Extern s) ->
  m (Either Trap (Instance s))
-- TODO: don't throw the WasmtimeError but return it via Either
newInstance store m externs = unsafeIOToPrim $
  withStore store $ \ctx_ptr ->
    withModule m $ \mod_ptr ->
      withExterns externs $ \externs_ptr n -> do
        inst_frgn_ptr :: ForeignPtr C'wasmtime_instance_t <- mallocForeignPtr
        withForeignPtr inst_frgn_ptr $ \(inst_ptr :: Ptr C'wasmtime_instance_t) ->
          allocaNullPtr $ \(trap_ptr_ptr :: Ptr (Ptr C'wasm_trap_t)) -> do
            c'wasmtime_instance_new
              ctx_ptr
              mod_ptr
              externs_ptr
              n
              inst_ptr
              trap_ptr_ptr
              >>= checkWasmtimeError
            trap_ptr <- peek trap_ptr_ptr
            if trap_ptr == nullPtr
              then pure $ Right $ Instance inst_frgn_ptr
              else Left <$> newTrapFromPtr trap_ptr

withInstance :: Instance s -> (Ptr C'wasmtime_instance_t -> IO a) -> IO a
withInstance = withForeignPtr . instanceForeignPtr

-- | Get an export by name from an instance.
getExport :: MonadPrim s m => Store s -> Instance s -> String -> m (Maybe (Extern s))
getExport store inst name = unsafeIOToPrim $
  withStore store $ \ctx_ptr ->
    withInstance inst $ \(inst_ptr :: Ptr C'wasmtime_instance_t) ->
      withCStringLen name $ \(name_ptr, sz) ->
        alloca $ \(extern_ptr :: Ptr C'wasmtime_extern) -> do
          found <-
            c'wasmtime_instance_export_get
              ctx_ptr
              inst_ptr
              name_ptr
              (fromIntegral sz)
              extern_ptr
          if not found
            then pure Nothing
            else Just <$> fromExternPtr extern_ptr

fromExternPtr :: Ptr C'wasmtime_extern -> IO (Extern s)
fromExternPtr extern_ptr = do
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

  fmap (fromMaybe $ error "Unknown extern!") $
    runMaybeT $
      fromCExtern MkFunc
        <|> fromCExtern MkMemory
        <|> fromCExtern MkTable
        <|> fromCExtern MkGlobal
  where
    kind_ptr :: Ptr C'wasmtime_extern_kind_t
    kind_ptr = p'wasmtime_extern'kind extern_ptr

    of_ptr :: Ptr C'wasmtime_extern_union_t
    of_ptr = p'wasmtime_extern'of extern_ptr

-- | Convenience function which gets the named export from the store
-- ('getExport'), checks if it's a 'Func' ('fromExtern') and finally converts
-- the 'Func' to the Haskell function @f@ in case their types match
-- ('funcToFunction').
getExportedFunction ::
  forall f (params :: [Type]) m s r (results :: [Type]).
  ( Funcable f,
    Params f ~ params,
    HListable r,
    Types r ~ results,
    Result f ~ m (Either Trap r),
    Foldr (->) (m (Either Trap r)) params ~ f,
    Curry params,
    Vals params,
    Vals results,
    Len params,
    Len results,
    MonadPrim s m,
    PrimBase m
  ) =>
  Store s ->
  Instance s ->
  -- | Name of the export.
  String ->
  m (Maybe f)
getExportedFunction store inst name = runMaybeT $ do
  extern <- MaybeT $ getExport store inst name
  (func :: Func s) <- MaybeT $ pure $ fromExtern extern
  MaybeT $ funcToFunction store func

-- | Convenience function which gets the named export from the store
-- ('getExport') and checks if it's a 'Memory' ('fromExtern').
getExportedMemory ::
  forall s m.
  (MonadPrim s m) =>
  Store s ->
  Instance s ->
  -- | Name of the export.
  String ->
  m (Maybe (Memory s))
getExportedMemory store inst name = (>>= fromExtern) <$> getExport store inst name

-- | Convenience function which gets the named export from the store
-- ('getExport') and checks if it's a 'Table' ('fromExtern').
getExportedTable ::
  forall s m.
  (MonadPrim s m) =>
  Store s ->
  Instance s ->
  -- | Name of the export.
  String ->
  m (Maybe (Table s))
getExportedTable store inst name = (>>= fromExtern) <$> getExport store inst name

-- | Convenience function which gets the named export from the store
-- ('getExport'), checks if it's a 'Global' ('fromExtern') and finally checks if
-- the type of the global matches the desired type @a@ ('toTypedGlobal').
getExportedTypedGlobal ::
  forall s m a.
  (MonadPrim s m, Val a) =>
  Store s ->
  Instance s ->
  -- | Name of the export.
  String ->
  m (Maybe (TypedGlobal s a))
getExportedTypedGlobal store inst name = runMaybeT $ do
  extern <- MaybeT $ getExport store inst name
  (global :: Global s) <- MaybeT $ pure $ fromExtern extern
  MaybeT $ toTypedGlobal store global

-- | Get an export by index from an instance.
getExportAtIndex ::
  MonadPrim s m =>
  Store s ->
  Instance s ->
  -- | Index of the export within the module.
  Word64 ->
  m (Maybe (String, Extern s))
getExportAtIndex store inst ix =
  unsafeIOToPrim $
    withStore store $ \ctx_ptr ->
      withInstance inst $ \inst_ptr ->
        alloca $ \(name_ptr_ptr :: Ptr (Ptr CChar)) ->
          alloca $ \(name_len_ptr :: Ptr CSize) ->
            alloca $ \(extern_ptr :: Ptr C'wasmtime_extern) -> do
              found <-
                c'wasmtime_instance_export_nth
                  ctx_ptr
                  inst_ptr
                  (fromIntegral ix)
                  name_ptr_ptr
                  name_len_ptr
                  extern_ptr
              if not found
                then pure Nothing
                else do
                  extern <- fromExternPtr extern_ptr

                  name_ptr <- peek name_ptr_ptr
                  name_len <- peek name_len_ptr
                  name <- peekCStringLen (name_ptr, fromIntegral name_len)

                  pure $ Just (name, extern)

--------------------------------------------------------------------------------
-- Linker
--------------------------------------------------------------------------------

-- | Object used to conveniently link together and instantiate wasm modules.
data Linker s = Linker
  { linkerForeignPtr :: ForeignPtr C'wasmtime_linker_t,
    -- We keep a mutable list of reference-counted finalizers of the
    -- FuncCallback FunPtrs. See 'linkerDefineFunc' which adds to this list.
    --
    -- The reason the FunPtrs need to be reference counted is that they need to
    -- stay alive for the lifetime of the 'Instance' returned from
    -- 'linkerInstantiate'. Because that instance may invoke the associated host
    -- functions.
    --
    -- So 'linkerInstantiate' will call 'incArc' for all the Arcs in the linker
    -- to increment their reference counts then add a finalizer to the
    -- ForeignPtr of the instance which calls 'freeArc' on all the Arcs to
    -- finalize them.
    --
    -- In the finalizer of the 'linkerForeignPtr' we call 'freeArc' on each of
    -- the Arcs in the list causing the FunPtr to be finalized when its
    -- reference count reaches 0.
    linkerFunPtrArcs :: IORef [Arc]
  }

newFuncCallbackFunPtrArc :: IORef [Arc] -> FuncCallback -> IO (FunPtr FuncCallback)
newFuncCallbackFunPtrArc ioRef callback = mask_ $ do
  funPtr <- mk'wasmtime_func_callback_t callback
  arc <- newArc $ freeHaskellFunPtr funPtr
  atomicModifyIORef ioRef $ \(arcs :: [Arc]) -> (arc : arcs, ())
  pure funPtr

withLinker :: Linker s -> (Ptr C'wasmtime_linker_t -> IO a) -> IO a
withLinker = withForeignPtr . linkerForeignPtr

-- | Creates a new linker for the specified engine.
newLinker :: MonadPrim s m => Engine -> m (Linker s)
newLinker engine =
  unsafeIOToPrim $
    withEngine engine $ \engine_ptr ->
      mask_ $ do
        linker_ptr <- c'wasmtime_linker_new engine_ptr
        funPtrArcsRef <- newIORef []
        linkerFP <- Foreign.Concurrent.newForeignPtr linker_ptr $ do
          c'wasmtime_linker_delete linker_ptr
          readIORef funPtrArcsRef >>= mapM_ freeArc
        pure
          Linker
            { linkerForeignPtr = linkerFP,
              linkerFunPtrArcs = funPtrArcsRef
            }

-- | Configures whether this linker allows later definitions to shadow previous
-- definitions.
--
-- By default this setting is 'False'.
linkerAllowShadowing :: MonadPrim s m => Linker s -> Bool -> m ()
linkerAllowShadowing linker allowShadowing =
  unsafeIOToPrim $
    withLinker linker $ \linker_ptr ->
      c'wasmtime_linker_allow_shadowing linker_ptr allowShadowing

type ModuleName = String

type Name = String

-- | Defines a new item in this linker.
--
-- For more information about name resolution consult the
-- <https://docs.wasmtime.dev/api/wasmtime/struct.Linker.html#name-resolution Rust documentation>.
linkerDefine ::
  MonadPrim s m =>
  -- | The linker the name is being defined in.
  Linker s ->
  -- | The store that the item is owned by.
  Store s ->
  -- | The module name the item is defined under.
  ModuleName ->
  -- | The field name the item is defined under
  Name ->
  -- | The item that is being defined in this linker.
  Extern s ->
  m (Either WasmtimeError ())
linkerDefine linker store modName name extern =
  unsafeIOToPrim $
    withLinker linker $ \linker_ptr ->
      withStore store $ \ctx_ptr ->
        withCStringLen modName $ \(mod_name_ptr, mod_name_sz) ->
          withCStringLen name $ \(name_ptr, name_sz) ->
            withExtern extern $ \extern_ptr ->
              c'wasmtime_linker_define
                linker_ptr
                ctx_ptr
                mod_name_ptr
                (fromIntegral mod_name_sz)
                name_ptr
                (fromIntegral name_sz)
                extern_ptr
                >>= try . checkWasmtimeError

-- | Defines a new function in this linker.
--
-- Note that this function does not create a 'Func'. This creates a
-- 'Store'-independent function within the 'Linker', allowing this function
-- definition to be used with multiple stores.
--
-- For more information about name resolution consult the
-- <https://docs.wasmtime.dev/api/wasmtime/struct.Linker.html#name-resolution Rust documentation>.
linkerDefineFunc ::
  forall f (params :: [Type]) m s r (results :: [Type]).
  ( Funcable f,
    Params f ~ params,
    HListable r,
    Types r ~ results,
    Result f ~ m (Either Trap r),
    Foldr (->) (m (Either Trap r)) params ~ f,
    Curry params,
    Vals params,
    Vals results,
    Len params,
    Len results,
    MonadPrim s m,
    PrimBase m
  ) =>
  -- | The linker the name is being defined in.
  Linker s ->
  -- | The module name the item is defined under.
  ModuleName ->
  -- | The field name the item is defined under
  Name ->
  f ->
  m (Either WasmtimeError ())
linkerDefineFunc linker modName name f =
  unsafeIOToPrim $
    withLinker linker $ \linker_ptr ->
      withCStringLen modName $ \(mod_name_ptr, mod_name_sz) ->
        withCStringLen name $ \(name_ptr, name_sz) ->
          withFuncType funcType $ \functype_ptr -> do
            callback_funptr :: FunPtr FuncCallback <-
              newFuncCallbackFunPtrArc (linkerFunPtrArcs linker) callback
            c'wasmtime_linker_define_func
              linker_ptr
              mod_name_ptr
              (fromIntegral mod_name_sz)
              name_ptr
              (fromIntegral name_sz)
              functype_ptr
              callback_funptr
              nullPtr
              nullFunPtr
              >>= try . checkWasmtimeError
  where
    funcType :: FuncType
    funcType = newFuncType $ Proxy @f

    callback :: FuncCallback
    callback = mkCallback f

-- | Defines an instance under the specified name in this linker.
--
-- This function will take all of the exports of the given 'Instance' and define
-- them under a module with the given name with a field name as the export's own
-- name.
--
-- For more information about name resolution consult the
-- <https://docs.wasmtime.dev/api/wasmtime/struct.Linker.html#name-resolution Rust documentation>.
linkerDefineInstance ::
  MonadPrim s m =>
  -- | The linker the name is being defined in.
  Linker s ->
  -- | The store that owns the given 'Instance'.
  Store s ->
  -- | The module name to define the given 'Instance' under.
  ModuleName ->
  -- | A previously-created 'Instance'.
  Instance s ->
  m (Either WasmtimeError ())
linkerDefineInstance linker store name inst =
  unsafeIOToPrim $
    withLinker linker $ \linker_ptr ->
      withStore store $ \ctx_ptr ->
        withCStringLen name $ \(name_ptr, name_sz) ->
          withInstance inst $ \inst_ptr ->
            c'wasmtime_linker_define_instance
              linker_ptr
              ctx_ptr
              name_ptr
              (fromIntegral name_sz)
              inst_ptr
              >>= try . checkWasmtimeError

-- TODO: Bind wasmtime_context_set_wasi

-- | Defines WASI functions in this linker.
--
-- This function will provide WASI function names in the specified linker. Note
-- that when an instance is created within a store then the store also needs to
-- have its WASI settings configured with @wasmtime_context_set_wasi@ for WASI
-- functions to work, otherwise an assert will be tripped that will abort the
-- process.
--
-- For more information about name resolution consult the
-- <https://docs.wasmtime.dev/api/wasmtime/struct.Linker.html#name-resolution Rust documentation>.
linkerDefineWasi :: MonadPrim s m => Linker s -> m (Either WasmtimeError ())
linkerDefineWasi linker =
  unsafeIOToPrim $
    withLinker linker $
      c'wasmtime_linker_define_wasi
        >=> try . checkWasmtimeError

-- | Loads an item by name from this linker.
linkerGet ::
  MonadPrim s m =>
  -- | The linker to load from.
  Linker s ->
  -- | The store to load the item into.
  Store s ->
  -- | The name of the module to get.
  ModuleName ->
  -- | The name of the field to get.
  Name ->
  m (Maybe (Extern s))
linkerGet linker store modName name =
  unsafeIOToPrim $
    withLinker linker $ \linker_ptr ->
      withStore store $ \ctx_ptr ->
        withCStringLen modName $ \(mod_name_ptr, mod_name_sz) ->
          withCStringLen name $ \(name_ptr, name_sz) ->
            alloca $ \(extern_ptr :: Ptr C'wasmtime_extern) -> do
              found <-
                c'wasmtime_linker_get
                  linker_ptr
                  ctx_ptr
                  mod_name_ptr
                  (fromIntegral mod_name_sz)
                  name_ptr
                  (fromIntegral name_sz)
                  extern_ptr
              if not found
                then pure Nothing
                else Just <$> fromExternPtr extern_ptr

-- | Acquires the \"default export\" of the named module in this linker.
--
-- For more information see the
-- <https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Linker.html#method.get_default Rust documentation>.
linkerGetDefault ::
  MonadPrim s m =>
  -- | The linker to load from.
  Linker s ->
  -- | The store to load the item into.
  Store s ->
  -- | The name of the field to get.
  Name ->
  m (Either WasmtimeError (Func s))
linkerGetDefault linker store name =
  unsafeIOToPrim $
    withLinker linker $ \linker_ptr ->
      withStore store $ \ctx_ptr ->
        withCStringLen name $ \(name_ptr, name_sz) ->
          alloca $ \(func_ptr :: Ptr C'wasmtime_func_t) -> try $ do
            c'wasmtime_linker_get_default
              linker_ptr
              ctx_ptr
              name_ptr
              (fromIntegral name_sz)
              func_ptr
              >>= checkWasmtimeError
            MkFunc <$> peek func_ptr

-- | Instantiates a 'Module' with the items defined in the given 'Linker'.
--
-- This function will attempt to satisfy all of the imports of the module
-- provided with items previously defined in the given linker. If any name isn't
-- defined in the linker than an error is returned. (or if the previously
-- defined item is of the wrong type).
linkerInstantiate ::
  MonadPrim s m =>
  -- | The linker used to instantiate the provided module.
  Linker s ->
  -- | The store that is used to instantiate within.
  Store s ->
  -- | The module that is being instantiated.
  Module ->
  m (Either Trap (Instance s))
-- TODO: don't throw the WasmtimeError but return it via Either
linkerInstantiate linker store m =
  unsafeIOToPrim $
    withLinker linker $ \linker_ptr ->
      withStore store $ \ctx_ptr ->
        withModule m $ \mod_ptr -> do
          inst_frgn_ptr :: ForeignPtr C'wasmtime_instance_t <- mallocForeignPtr
          mask_ $ do
            arcs <- readIORef $ linkerFunPtrArcs linker
            mapM_ incArc arcs
            Foreign.Concurrent.addForeignPtrFinalizer inst_frgn_ptr $
              mapM_ freeArc arcs
          withForeignPtr inst_frgn_ptr $ \(inst_ptr :: Ptr C'wasmtime_instance_t) ->
            allocaNullPtr $ \(trap_ptr_ptr :: Ptr (Ptr C'wasm_trap_t)) -> do
              c'wasmtime_linker_instantiate
                linker_ptr
                ctx_ptr
                mod_ptr
                inst_ptr
                trap_ptr_ptr
                >>= checkWasmtimeError
              trap_ptr <- peek trap_ptr_ptr
              if trap_ptr == nullPtr
                then pure $ Right $ Instance inst_frgn_ptr
                else Left <$> newTrapFromPtr trap_ptr

-- | Defines automatic instantiations of a 'Module' in the given 'Linker'.
--
-- This function automatically handles
-- <https://github.com/WebAssembly/WASI/blob/main/legacy/application-abi.md#current-unstable-abi Commands and Reactors>
-- instantiation and initialization.
--
-- For more information see the
-- <https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Linker.html#method.module Rust documentation>.
linkerModule ::
  MonadPrim s m =>
  -- | The linker the module is being added to.
  Linker s ->
  -- | The store that is used to instantiate the given module.
  Store s ->
  -- | The name of the module within the linker.
  ModuleName ->
  -- | The module that's being instantiated.
  Module ->
  m (Either WasmtimeError ())
linkerModule linker store modName m =
  unsafeIOToPrim $
    withLinker linker $ \linker_ptr ->
      withStore store $ \ctx_ptr ->
        withCStringLen modName $ \(mod_name_ptr, mod_name_sz) ->
          withModule m $ \mod_ptr ->
            c'wasmtime_linker_module
              linker_ptr
              ctx_ptr
              mod_name_ptr
              (fromIntegral mod_name_sz)
              mod_ptr
              >>= try . checkWasmtimeError

--------------------------------------------------------------------------------
-- Arcs
--------------------------------------------------------------------------------

-- | A thread-safe reference count paired with a finalizer.
data Arc = Arc
  { arcRcRef :: IORef Int,
    arcFinalizer :: IO ()
  }

-- | Returns a new 'Arc' with a reference count of 1 and the given finalizer.
newArc :: IO () -> IO Arc
newArc finalize = do
  rcRef <- newIORef 1
  pure
    Arc
      { arcRcRef = rcRef,
        arcFinalizer = finalize
      }

-- | Atomically increment the reference count in the given 'Arc'.
incArc :: Arc -> IO ()
incArc arc =
  atomicModifyIORef (arcRcRef arc) $ \rc ->
    let !rc' = rc + 1 in (rc', ())

-- | Atomically decrement the reference count in the given 'Arc'
-- and when it reaches 0 run the associated finalizer.
freeArc :: Arc -> IO ()
freeArc (Arc rcRef finalize) = do
  rc' <- atomicModifyIORef rcRef $ \rc ->
    let !rc' = rc - 1 in (rc', rc')
  when (rc' == 0) finalize

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
withTrap = withForeignPtr . unTrap

instance Show Trap where
  show trap = unsafePerformIO $
    withTrap trap $ \trap_ptr ->
      alloca $ \(wasm_msg_ptr :: Ptr C'wasm_message_t) -> do
        c'wasm_trap_message trap_ptr wasm_msg_ptr
        peekByteVecAsString wasm_msg_ptr

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
trapOrigin trap =
  unsafePerformIO $
    mask_ $
      withTrap trap $
        c'wasm_trap_origin >=> withNonNullPtr newFrameFromPtr

-- | Returns the trace of wasm frames for this trap.
--
-- Frames are listed in order of increasing depth, with the most recently called
-- function at the front of the vector and the base function on the stack at the
-- end.
trapTrace :: Trap -> Vector Frame
trapTrace trap = unsafePerformIO $ withTrap trap $ \trap_ptr ->
  alloca $ \(frame_vec_ptr :: Ptr C'wasm_frame_vec_t) -> mask_ $ do
    c'wasm_trap_trace trap_ptr frame_vec_ptr
    sz :: CSize <- peek $ p'wasm_frame_vec_t'size frame_vec_ptr
    dt :: Ptr (Ptr C'wasm_frame_t) <- peek $ p'wasm_frame_vec_t'data frame_vec_ptr
    vec <-
      V.generateM (fromIntegral sz) $
        peekElemOff dt >=> c'wasm_frame_copy >=> newFrameFromPtr
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
withFrame = withForeignPtr . unFrame

-- | Returns 'Just' a human-readable name for this frame's function.
--
-- This function will attempt to load a human-readable name for the function
-- this frame points to. This function may return 'Nothing'.
frameFuncName :: Frame -> Maybe String
frameFuncName frame =
  unsafePerformIO $
    withFrame frame $
      c'wasmtime_frame_func_name
        >=> withNonNullPtr peekByteVecAsString

-- | Returns 'Just' a human-readable name for this frame's module.
--
-- This function will attempt to load a human-readable name for the module this
-- frame points to. This function may return 'Nothing'.
frameModuleName :: Frame -> Maybe String
frameModuleName frame =
  unsafePerformIO $
    withFrame frame $
      c'wasmtime_frame_module_name
        >=> withNonNullPtr peekByteVecAsString

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
  deriving (Show)

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
        msg <- peekByteVecAsString wasm_name_ptr
        c'wasm_byte_vec_delete wasm_name_ptr
        pure msg

--------------------------------------------------------------------------------
-- Utils
--------------------------------------------------------------------------------

peekByteVecAsString :: Ptr C'wasm_byte_vec_t -> IO String
peekByteVecAsString p = do
  data_ptr <- peek $ p'wasm_byte_vec_t'data p
  size <- peek $ p'wasm_byte_vec_t'size p
  peekCStringLen (data_ptr, fromIntegral size)

withByteVecToByteString :: (Ptr C'wasm_byte_vec_t -> IO ()) -> IO B.ByteString
withByteVecToByteString f =
  alloca $ \(wasm_byte_vec_ptr :: Ptr C'wasm_byte_vec_t) -> mask_ $ do
    f wasm_byte_vec_ptr
    data_ptr :: Ptr CChar <- peek $ p'wasm_byte_vec_t'data wasm_byte_vec_ptr
    size <- peek $ p'wasm_byte_vec_t'size wasm_byte_vec_ptr
    out_fp <-
      Foreign.Concurrent.newForeignPtr (castPtr data_ptr :: Ptr Word8) $
        c'wasm_byte_vec_delete wasm_byte_vec_ptr
    pure $ BI.fromForeignPtr0 out_fp $ fromIntegral size

withNonNullPtr :: (Ptr a -> IO b) -> Ptr a -> IO (Maybe b)
withNonNullPtr f ptr
  | ptr == nullPtr = pure Nothing
  | otherwise = Just <$> f ptr

-- | Allocate a pointer to a pointer and initialise it with NULL before calling
-- the continuation on it.
allocaNullPtr :: (Ptr (Ptr a) -> IO b) -> IO b
allocaNullPtr f = alloca $ \ptr_ptr -> do
  poke ptr_ptr nullPtr
  f ptr_ptr

--------------------------------------------------------------------------------
-- HList
--------------------------------------------------------------------------------

infixr 5 :.

-- | Heterogeneous list that is used to return results from WASM functions.
-- (Internally it's also used to pass parameters to WASM functions).
--
-- See the documentation of 'funcToFunction' for an example.
data List (as :: [Type]) where
  Nil :: List '[]
  (:.) :: a -> List as -> List (a ': as)

instance Eq (List '[]) where
  Nil == Nil = True

instance (Eq a, Eq (List as)) => Eq (List (a ': as)) where
  x :. xs == y :. ys = x == y && xs == ys

instance Ord (List '[]) where
  Nil `compare` Nil = EQ

instance (Ord a, Ord (List as)) => Ord (List (a ': as)) where
  (x :. xs) `compare` (y :. ys) = x `compare` y <> xs `compare` ys

-- | Fold a type constructor through a list of types.
type family Foldr (f :: Type -> Type -> Type) (z :: Type) (xs :: [Type]) where
  Foldr f z '[] = z
  Foldr f z (x ': xs) = f x (Foldr f z xs)

-- | Curry and uncurry Haskell functions with arbitrary number of arguments to
-- and from functions on heterogeneous lists.
class Curry (as :: [Type]) where
  uncurryList :: Foldr (->) b as -> (List as -> b)
  curryList :: (List as -> b) -> Foldr (->) b as

instance Curry '[] where
  uncurryList f _ = f
  curryList f = f Nil

instance Curry as => Curry (a ': as) where
  uncurryList f (x :. xs) = uncurryList (f x) xs
  curryList f x = curryList $ f . (x :.)

-- | The length of a type of kind list of types.
class Len (l :: [Type]) where
  len :: Proxy l -> Int

instance Len '[] where
  len _proxy = 0

instance Len as => Len (a ': as) where
  len _proxy = 1 + len (Proxy @as)

-- | WASM functions can return zero or more results of different types. These
-- results are represented using heterogeneous lists via the 'List' type.
--
-- Working with @'List's@ can be cumbersome because you need to enable the
-- @DataKinds@ and @GADTs@ language extensions.
--
-- For this reason functions like 'newFunc' and `funcToFunction` use this
-- 'HListable' type class to automatically convert @'List's@ to \"normal\"
-- Haskell types like @()@, primitive types like @Int32@ or to tuples of
-- primitive types.
--
-- Note there also exists an identity instance for @'List's@ themselves so if
-- you want to use heterogeneous lists you can.
class HListable a where
  type Types a :: [Type]
  fromHList :: List (Types a) -> a
  toHList :: a -> List (Types a)

instance HListable (List as) where
  type Types (List as) = as
  fromHList = id
  toHList = id

instance HListable () where
  type Types () = '[]
  fromHList Nil = ()
  toHList () = Nil

instance HListable Int32 where
  type Types Int32 = '[Int32]
  fromHList (x :. Nil) = x
  toHList x = x :. Nil

instance HListable Int64 where
  type Types Int64 = '[Int64]
  fromHList (x :. Nil) = x
  toHList x = x :. Nil

instance HListable Float where
  type Types Float = '[Float]
  fromHList (x :. Nil) = x
  toHList x = x :. Nil

instance HListable Double where
  type Types Double = '[Double]
  fromHList (x :. Nil) = x
  toHList x = x :. Nil

instance HListable Word128 where
  type Types Word128 = '[Word128]
  fromHList (x :. Nil) = x
  toHList x = x :. Nil

instance HListable (Func s) where
  type Types (Func s) = '[Func s]
  fromHList (x :. Nil) = x
  toHList x = x :. Nil

instance HListable (Ptr C'wasmtime_externref_t) where
  type Types (Ptr C'wasmtime_externref_t) = '[Ptr C'wasmtime_externref_t]
  fromHList (x :. Nil) = x
  toHList x = x :. Nil

instance HListable (a, b) where
  type
    Types (a, b) =
      '[a, b]
  fromHList (x :. y :. Nil) =
    (x, y)
  toHList (x, y) =
    x :. y :. Nil

instance HListable (a, b, c) where
  type
    Types (a, b, c) =
      '[a, b, c]
  fromHList (a :. b :. c :. Nil) =
    (a, b, c)
  toHList (a, b, c) =
    a :. b :. c :. Nil

instance HListable (a, b, c, d) where
  type
    Types (a, b, c, d) =
      '[a, b, c, d]
  fromHList (a :. b :. c :. d :. Nil) =
    (a, b, c, d)
  toHList (a, b, c, d) =
    a :. b :. c :. d :. Nil

instance HListable (a, b, c, d, e) where
  type
    Types (a, b, c, d, e) =
      '[a, b, c, d, e]
  fromHList (a :. b :. c :. d :. e :. Nil) =
    (a, b, c, d, e)
  toHList (a, b, c, d, e) =
    a :. b :. c :. d :. e :. Nil

instance HListable (a, b, c, d, e, f) where
  type
    Types (a, b, c, d, e, f) =
      '[a, b, c, d, e, f]
  fromHList (a :. b :. c :. d :. e :. f :. Nil) =
    (a, b, c, d, e, f)
  toHList (a, b, c, d, e, f) =
    a :. b :. c :. d :. e :. f :. Nil

instance HListable (a, b, c, d, e, f, g) where
  type
    Types (a, b, c, d, e, f, g) =
      '[a, b, c, d, e, f, g]
  fromHList (a :. b :. c :. d :. e :. f :. g :. Nil) =
    (a, b, c, d, e, f, g)
  toHList (a, b, c, d, e, f, g) =
    a :. b :. c :. d :. e :. f :. g :. Nil

instance HListable (a, b, c, d, e, f, g, h) where
  type
    Types (a, b, c, d, e, f, g, h) =
      '[a, b, c, d, e, f, g, h]
  fromHList (a :. b :. c :. d :. e :. f :. g :. h :. Nil) =
    (a, b, c, d, e, f, g, h)
  toHList (a, b, c, d, e, f, g, h) =
    a :. b :. c :. d :. e :. f :. g :. h :. Nil

instance HListable (a, b, c, d, e, f, g, h, i) where
  type
    Types (a, b, c, d, e, f, g, h, i) =
      '[a, b, c, d, e, f, g, h, i]
  fromHList (a :. b :. c :. d :. e :. f :. g :. h :. i :. Nil) =
    (a, b, c, d, e, f, g, h, i)
  toHList (a, b, c, d, e, f, g, h, i) =
    a :. b :. c :. d :. e :. f :. g :. h :. i :. Nil

instance HListable (a, b, c, d, e, f, g, h, i, j) where
  type
    Types (a, b, c, d, e, f, g, h, i, j) =
      '[a, b, c, d, e, f, g, h, i, j]
  fromHList (a :. b :. c :. d :. e :. f :. g :. h :. i :. j :. Nil) =
    (a, b, c, d, e, f, g, h, i, j)
  toHList (a, b, c, d, e, f, g, h, i, j) =
    a :. b :. c :. d :. e :. f :. g :. h :. i :. j :. Nil

instance HListable (a, b, c, d, e, f, g, h, i, j, k) where
  type
    Types (a, b, c, d, e, f, g, h, i, j, k) =
      '[a, b, c, d, e, f, g, h, i, j, k]
  fromHList (a :. b :. c :. d :. e :. f :. g :. h :. i :. j :. k :. Nil) =
    (a, b, c, d, e, f, g, h, i, j, k)
  toHList (a, b, c, d, e, f, g, h, i, j, k) =
    a :. b :. c :. d :. e :. f :. g :. h :. i :. j :. k :. Nil

instance HListable (a, b, c, d, e, f, g, h, i, j, k, l) where
  type
    Types (a, b, c, d, e, f, g, h, i, j, k, l) =
      '[a, b, c, d, e, f, g, h, i, j, k, l]
  fromHList (a :. b :. c :. d :. e :. f :. g :. h :. i :. j :. k :. l :. Nil) =
    (a, b, c, d, e, f, g, h, i, j, k, l)
  toHList (a, b, c, d, e, f, g, h, i, j, k, l) =
    a :. b :. c :. d :. e :. f :. g :. h :. i :. j :. k :. l :. Nil

instance HListable (a, b, c, d, e, f, g, h, i, j, k, l, m) where
  type
    Types (a, b, c, d, e, f, g, h, i, j, k, l, m) =
      '[a, b, c, d, e, f, g, h, i, j, k, l, m]
  fromHList (a :. b :. c :. d :. e :. f :. g :. h :. i :. j :. k :. l :. m :. Nil) =
    (a, b, c, d, e, f, g, h, i, j, k, l, m)
  toHList (a, b, c, d, e, f, g, h, i, j, k, l, m) =
    a :. b :. c :. d :. e :. f :. g :. h :. i :. j :. k :. l :. m :. Nil

instance HListable (a, b, c, d, e, f, g, h, i, j, k, l, m, n) where
  type
    Types (a, b, c, d, e, f, g, h, i, j, k, l, m, n) =
      '[a, b, c, d, e, f, g, h, i, j, k, l, m, n]
  fromHList (a :. b :. c :. d :. e :. f :. g :. h :. i :. j :. k :. l :. m :. n :. Nil) =
    (a, b, c, d, e, f, g, h, i, j, k, l, m, n)
  toHList (a, b, c, d, e, f, g, h, i, j, k, l, m, n) =
    a :. b :. c :. d :. e :. f :. g :. h :. i :. j :. k :. l :. m :. n :. Nil

instance HListable (a, b, c, d, e, f, g, h, i, j, k, l, m, n, o) where
  type
    Types (a, b, c, d, e, f, g, h, i, j, k, l, m, n, o) =
      '[a, b, c, d, e, f, g, h, i, j, k, l, m, n, o]
  fromHList (a :. b :. c :. d :. e :. f :. g :. h :. i :. j :. k :. l :. m :. n :. o :. Nil) =
    (a, b, c, d, e, f, g, h, i, j, k, l, m, n, o)
  toHList (a, b, c, d, e, f, g, h, i, j, k, l, m, n, o) =
    a :. b :. c :. d :. e :. f :. g :. h :. i :. j :. k :. l :. m :. n :. o :. Nil
