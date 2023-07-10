Haskell binding to wasmtime
===========================

<img src="wasmtime-hs.png" alt="wasmtime-hs logo" />

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
