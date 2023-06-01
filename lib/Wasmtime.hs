{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

-- | High-level Haskell API to the wasmtime C API.
module Wasmtime
  ( -- * Engine
    Engine,
    newEngine,

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

    -- * Externs
    Extern,
    Externable,
    extern,

    -- * Instances
    Instance,
    newInstance,

    -- * Errors
    WasmException (..),
    WasmtimeError,
  )
where

import Bindings.Wasm
import Bindings.Wasmtime
import Bindings.Wasmtime.Error
import Bindings.Wasmtime.Extern
import Bindings.Wasmtime.Func
import Bindings.Wasmtime.Instance
import Bindings.Wasmtime.Module
import Bindings.Wasmtime.Store
import Bindings.Wasmtime.Val
import Control.Exception (Exception, mask_, throwIO)
import Control.Monad (when)
import qualified Data.ByteString as B
import qualified Data.ByteString.Internal as BI
import Data.Foldable (for_)
import Data.Int (Int32, Int64)
import Data.Kind (Type)
import Data.Proxy (Proxy (..))
import Data.Typeable (Typeable)
import Data.WideWord.Word128 (Word128)
import Data.Word (Word8)
import Foreign.C.String (peekCStringLen)
import Foreign.C.Types (CChar, CSize)
import qualified Foreign.Concurrent
import Foreign.ForeignPtr (ForeignPtr, mallocForeignPtr, newForeignPtr, withForeignPtr)
import Foreign.Marshal.Alloc (alloca, malloc)
import Foreign.Marshal.Array
import Foreign.Ptr (Ptr, castPtr, nullFunPtr, nullPtr)
import Foreign.Storable (Storable, peek, poke, pokeElemOff)
import System.IO.Unsafe (unsafePerformIO)

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
wat2wasm :: B.ByteString -> IO Wasm
wat2wasm (BI.BS inp_fp inp_size) = withForeignPtr inp_fp $ \(inp_ptr :: Ptr Word8) ->
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

instance Results () where
  results _proxy = []

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

instance Results Int32 where results proxy = [kind proxy]

instance Results Int64 where results proxy = [kind proxy]

instance Results Float where results proxy = [kind proxy]

instance Results Double where results proxy = [kind proxy]

instance Results Word128 where results proxy = [kind proxy]

instance (Kind a, Kind b) => Results (a, b) where
  results _proxy = [kind (Proxy @a), kind (Proxy @b)]

instance (Kind a, Kind b, Kind c) => Results (a, b, c) where
  results _proxy = [kind (Proxy @a), kind (Proxy @b), kind (Proxy @c)]

instance (Kind a, Kind b, Kind c, Kind d) => Results (a, b, c, d) where
  results _proxy = [kind (Proxy @a), kind (Proxy @b), kind (Proxy @c), kind (Proxy @d)]

--------------------------------------------------------------------------------
-- Functions
--------------------------------------------------------------------------------

-- | Representation of a function in Wasmtime.
--
-- Functions are represented with a 64-bit identifying integer in Wasmtime. They
-- do not have any destructor associated with them. Functions cannot
-- interoperate between 'Store' instances and if the wrong function is passed to
-- the wrong store then it may trigger an assertion to abort the process.
newtype Func = Func {unFunc :: C'wasmtime_func_t} deriving (Show)

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
-- Externs
--------------------------------------------------------------------------------

data Extern = forall extern. (Externable extern) => Extern extern

class (Storable (CType extern)) => Externable extern where
  type CType extern :: Type
  getCExtern :: extern -> CType extern
  externKind :: Proxy extern -> C'wasmtime_extern_kind_t

instance Externable Func where
  type CType Func = C'wasmtime_func
  getCExtern = unFunc
  externKind _proxy = c'WASMTIME_EXTERN_FUNC

extern :: (Externable extern) => extern -> Extern
extern = Extern

withExterns :: [Extern] -> (Ptr C'wasmtime_extern -> CSize -> IO a) -> IO a
withExterns externs f = allocaArray n $ \externs_ptr0 ->
  let go _externs_ptr [] = f externs_ptr0 $ fromIntegral n
      go externs_ptr ((Extern (extern :: extern)) : es) = do
        poke (p'wasmtime_extern'kind externs_ptr) $ externKind (Proxy @extern)
        poke (castPtr (p'wasmtime_extern'of externs_ptr)) $ getCExtern extern
        go (advancePtr externs_ptr 1) es
   in go externs_ptr0 externs
  where
    n = length externs

--------------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------------

newtype Instance = Instance {_unInstance :: C'wasmtime_instance_t}

newInstance :: Context -> Module -> [Extern] -> IO Instance
newInstance ctx m externs =
  withContext ctx $ \ctx_ptr ->
    withModule m $ \mod_ptr ->
      withExterns externs $ \externs_ptr n ->
        alloca $ \(instance_ptr :: Ptr C'wasmtime_instance_t) ->
          alloca $ \(trap_ptr :: Ptr (Ptr C'wasm_trap_t)) -> do
            error_ptr <-
              c'wasmtime_instance_new
                ctx_ptr
                mod_ptr
                externs_ptr
                n
                instance_ptr
                trap_ptr
            checkWasmtimeError error_ptr
            -- TODO: handle traps!!!
            Instance <$> peek instance_ptr

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
