(module

  (func $io_imp (import "" "io_imp"))
  (func $pure_imp (import "" "pure_imp") (param i32) (result i32))

  (memory (export "memory") 2 3)
  (func (export "size") (result i32) (memory.size))
  (func (export "load") (param i32) (result i32)
    (i32.load8_s (local.get 0))
  )
  (func (export "store") (param i32 i32)
    (i32.store8 (local.get 0) (local.get 1))
  )
  (func (export "call_imported_pure") (param $i i32) (result i32)
    local.get $i
    call $pure_imp
  )
  (func (export "call_imported_io") 
    call $io_imp 
  )
  
  
  (data (i32.const 0x1000) "\01\02\03\04")
)