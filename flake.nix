{
  description = "wasmtime-hs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              wasmtime = prev.wasmtime.overrideAttrs (oldAttrs: {
                postInstall =
                  (oldAttrs.postInstall or "") +
                    final.lib.optionalString final.stdenv.isDarwin ''
                      install_name_tool -id $dev/lib/libwasmtime.dylib $dev/lib/libwasmtime.dylib
                    '';
              });
            })
          ];
        };

        wasmtime = pkgs.wasmtime;

        # TODO: filter source to only include files added to git and strip flake.* files.
        src = ./.;
        wasmtime-hs = pkgs.haskellPackages.callCabal2nix "wasmtime" src {};
      in
      {
        packages.default = wasmtime-hs;
        packages.wasmtime = pkgs.wasmtime.dev;
        devShells.default = wasmtime-hs.envFunc {};
      }
    );
}
