(module
    (import "" "msg_reply" (func $msg_reply))
    (func $inc
        ;; Increment a counter.
        (i32.store
            (i32.const 0)
            (i32.add (i32.load (i32.const 0)) (i32.const 4))))
    (func $read
        (call $msg_reply))
    (func $canister_init
        ;; Increment the counter by 41 in canister_init.
        (i32.store
            (i32.const 0)
            (i32.add (i32.load (i32.const 0)) (i32.const 41))))
    ;; (start $inc)    ;; Increments counter by 1 in canister_start
    (memory $memory 1)
    ;;(global $__stack_pointer (mut i32) (i32.const 1048576))
    ;;(global (;1;) i32 (i32.const 1123520))
    ;;(global (;2;) i32 (i32.const 1123520))
    (export "canister_update read" (func $read))
    (export "canister_query get" (func $read))
    (export "canister_init" (func $canister_init))
)