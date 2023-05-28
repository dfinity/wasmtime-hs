Haskell binding to wasmtime
===========================

The `wasmtime` Haskell package provides a binding to
[wasmtime](https://wasmtime.dev/). It's implemented by binding to the C API of
wasmtime.

Notes
=====

As explaind in the [wasmtime C API](https://docs.wasmtime.dev/c-api/index.html)
wasmtime imlements the [wasm-c-api](https://github.com/WebAssembly/wasm-c-api).
This means that this haskkell binding could relatively easily target different
wasm engines that support the WASM C API:

* V8 natively (both C and C++)
* Wabt (only C?)
* Wasmtime (only C?)
* Wasmer (only C, C++ coming soon)
