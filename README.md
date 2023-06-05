Haskell binding to wasmtime
===========================

This `wasmtime` Haskell package provides a binding to
[wasmtime](https://wasmtime.dev/) via its C API.

Contributions
=============

This is an opensource repository licensed under the BSD-2-Clause license.
See the LICENSE file for details.

We're happy to accept your Pull Requests!

Developing
==========

First install [Nix](https://nixos.org/download.html) then bring the development
environment into scope using either:

* [direnv](https://direnv.net/) and
  [nix-direnv](https://github.com/nix-community/nix-direnv).
* `nix develop`.

finally `cabal test`.

Notes
=====

As explained in the [wasmtime C API](https://docs.wasmtime.dev/c-api/index.html)
wasmtime imlements the [wasm-c-api](https://github.com/WebAssembly/wasm-c-api).
This means that this haskell binding could relatively easily target different
wasm engines that support the WASM C API:

* V8 natively (both C and C++)
* Wabt (only C?)
* Wasmtime (only C?)
* Wasmer (only C, C++ coming soon)
