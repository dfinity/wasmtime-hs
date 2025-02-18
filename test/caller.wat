(module
  (func $some_func (import "" "some_func") (param i32) (result i32))
  (func (export "double") (param i32) (result i32) (local.get 0) (i32.const 2) (i32.mul))
  (func (export "run") (param i32) (result i32) (local.get 0) (i32.const 1) (i32.add) (call $someFunc))
)